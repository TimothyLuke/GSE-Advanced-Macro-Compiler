---@diagnostic disable: undefined-global, duplicate-set-field
-- Tests for GSE.ApplySequenceDelta() — the Lua port of the Node delta codec
-- (api/src/lib/seqDelta.js). Run with: busted spec/sequencedelta_spec.lua
--
-- Base tables use NUMBER keys (GSE/Codec native); deltas use STRING version
-- keys and 0-based `from` indices (as a CBOR delta from the server would), so
-- these also exercise the tonumber()/+1 reconciliation in the port.

require("../spec/mockGSE")
require("../GSE/API/SequenceDelta")

describe("Sequence Delta apply", function()
  -- A fresh base each time (apply must not mutate it).
  local function baseSD()
    return {
      LastUpdated = "20260101000000",
      Default = 1,
      VersionLabels = { [1] = "main" },
      MetaData = { Notes = "hi", ClassID = 1 },
      Versions = {
        [1] = {
          InbuiltVariables = { x = 1 },
          Actions = {
            [1] = { Type = "Action", type = "macro", macro = "/cast A", Icon = 1, target = " " },
            [2] = { Type = "Loop", [1] = { Type = "Action", macro = "/cast B" }, [2] = { Type = "Action", macro = "/cast C" } },
            [3] = { Type = "If", [1] = { { Type = "Action", macro = "/cast T" } }, [2] = { { Type = "Action", macro = "/cast F" } } },
          },
        },
      },
    }
  end

  it("identity (empty delta) returns equal content", function()
    local base = baseSD()
    assert.are.same(base, GSE.ApplySequenceDelta(base, { v = 1 }))
  end)

  it("field edit (set macro + Icon)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0, set = { macro = "/cast EDIT", Icon = 999 } }, { from = 1 }, { from = 2 },
    } } } })
    assert.are.equal("/cast EDIT", out.Versions[1].Actions[1].macro)
    assert.are.equal(999, out.Versions[1].Actions[1].Icon)
    assert.are.equal(" ", out.Versions[1].Actions[1].target) -- untouched field preserved
  end)

  it("field removal (unset target)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0, unset = { "target" } }, { from = 1 }, { from = 2 },
    } } } })
    assert.is_nil(out.Versions[1].Actions[1].target)
    assert.are.equal("/cast A", out.Versions[1].Actions[1].macro)
  end)

  it("add block (new at end)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0 }, { from = 1 }, { from = 2 }, { ["new"] = { Type = "Action", macro = "/cast NEW" } },
    } } } })
    assert.are.equal(4, #out.Versions[1].Actions)
    assert.are.equal("/cast NEW", out.Versions[1].Actions[4].macro)
  end)

  it("remove block (drop the Loop and If, keep action 1)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0 },
    } } } })
    assert.are.equal(1, #out.Versions[1].Actions)
    assert.are.equal("/cast A", out.Versions[1].Actions[1].macro)
  end)

  it("reorder (swap 1 and 3 via from indices)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 2 }, { from = 1 }, { from = 0 },
    } } } })
    assert.are.equal("If", out.Versions[1].Actions[1].Type)
    assert.are.equal("/cast A", out.Versions[1].Actions[3].macro)
  end)

  it("loop child edit (nested overlay)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0 },
      { from = 1, children = { { from = 0, set = { macro = "/cast B2" } }, { from = 1 } } },
      { from = 2 },
    } } } })
    assert.are.equal("/cast B2", out.Versions[1].Actions[2][1].macro)
    assert.are.equal("/cast C", out.Versions[1].Actions[2][2].macro)
    assert.are.equal("Loop", out.Versions[1].Actions[2].Type)
  end)

  it("if branch edit (true branch)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { actions = {
      { from = 0 }, { from = 1 },
      { from = 2, branch1 = { { from = 0, set = { macro = "/cast T2" } } } },
    } } } })
    assert.are.equal("/cast T2", out.Versions[1].Actions[3][1][1].macro)
    assert.are.equal("/cast F", out.Versions[1].Actions[3][2][1].macro) -- false branch untouched
  end)

  it("inbuiltVariables replace", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = { ["1"] = { inbuiltVariables = { x = 2, y = 3 } } } })
    assert.are.same({ x = 2, y = 3 }, out.Versions[1].InbuiltVariables)
  end)

  it("top-level fields (set LastUpdated, change MetaData, Default)", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, top = {
      LastUpdated = "20260202000000", Default = 2, MetaData = { Notes = "changed", ClassID = 1 },
    } })
    assert.are.equal("20260202000000", out.LastUpdated)
    assert.are.equal(2, out.Default)
    assert.are.equal("changed", out.MetaData.Notes)
  end)

  it("top-level field removal", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, topUnset = { "LastUpdated" } })
    assert.is_nil(out.LastUpdated)
  end)

  it("add + remove version", function()
    local out = GSE.ApplySequenceDelta(baseSD(), { v = 1, versions = {
      ["2"] = { op = "add", value = { Actions = { [1] = { Type = "Action", macro = "/cast V2" } } } },
      ["1"] = { op = "remove" },
    } })
    assert.is_nil(out.Versions[1])
    assert.are.equal("/cast V2", out.Versions[2].Actions[1].macro)
  end)

  it("does not mutate the base", function()
    local base = baseSD()
    GSE.ApplySequenceDelta(base, { v = 1, versions = { ["1"] = { actions = { { from = 0, set = { macro = "X" } } } } } })
    assert.are.equal("/cast A", base.Versions[1].Actions[1].macro) -- base unchanged
  end)

  -- Parity (feedback_gse_parity): variables / macros / collections have no
  -- Versions and reconstruct via the generic `top` path — must NOT gain a
  -- spurious Versions table.
  it("variable delta (no Versions injected)", function()
    local out = GSE.ApplyDelta({ Variable = "x", value = "/cast A", MetaData = { Name = "v" } },
      { v = 1, top = { value = "/cast B" } })
    assert.are.equal("/cast B", out.value)
    assert.is_nil(out.Versions)
  end)

  it("macro delta (no Versions injected)", function()
    local out = GSE.ApplyDelta({ macro = "/cast A", icon = 1, MetaData = { Name = "m" } },
      { v = 1, top = { macro = "/cast A\n/cast B", icon = 2 } })
    assert.are.equal("/cast A\n/cast B", out.macro)
    assert.are.equal(2, out.icon)
    assert.is_nil(out.Versions)
  end)
end)


-- ---------------------------------------------------------------------------
-- Parked updates and the three-way merge.
--
-- A local change is meant to survive the author's next version: SLG ships
-- [mod:shift], you change it to [mod:alt], SLG publishes an update -- your
-- [mod:alt] belongs on the new version.
--
-- But not at load time. ApplyStoredDeltaFork runs from loadOneClass and
-- EnsureSequenceLoaded, so a player logging in mid-pull would have the
-- sequence in their hands change shape. The update is parked and the old
-- version keeps running until the user accepts it.
-- ---------------------------------------------------------------------------
describe("Delta fork updates", function()
  -- The real DecodeMessage returns (ok, decoded); the mock returns just the
  -- table, so these carry the real contract. Deltas live in a registry rather
  -- than being serialised -- C_EncodingUtil is in-game only, and the codec is
  -- not what is under test. DiffDelta/ApplyDelta/matchBlocks are the real ones.
  local function withStubs(fn)
    local rDecode, rEncodeD, rDecodeD = GSE.DecodeMessage, GSE.EncodeDelta, GSE.DecodeDelta
    local blobs, deltas, n = {}, {}, 0
    GSE.DecodeMessage = function(b)
      if not blobs[b] then return false, nil end
      return true, blobs[b]
    end
    GSE.EncodeDelta = function(t)
      if type(t) ~= "table" then return nil end
      n = n + 1; deltas["delta#" .. n] = t; return "delta#" .. n
    end
    GSE.DecodeDelta = function(k) return deltas[k] end
    local function blob(name, obj)
      local key = "!GSE3!+" .. name
      blobs[key] = {name, obj}
      return key
    end
    local ok, err = pcall(fn, blob)
    GSE.DecodeMessage, GSE.EncodeDelta, GSE.DecodeDelta = rDecode, rEncodeD, rDecodeD
    if not ok then error(err, 0) end
  end

  local function seq(actions, notes)
    return {
      MetaData = { PlatformID = "pid1", Name = "SLG_Seq", Notes = notes or "v1" },
      Versions = { [1] = { Actions = actions } },
    }
  end
  local function act(macro) return { Type = "Action", type = "macro", macro = macro } end
  -- Through _G on purpose. busted runs the spec chunk in a proxy environment,
  -- so a bare `GSEDeltas = ...` here is written somewhere SequenceDelta.lua --
  -- required into the outer environment -- cannot see, and every call reads a
  -- nil GSEDeltas and bails. run51 shares _G, so it passed there and only
  -- busted showed it. Reads still resolve normally through the proxy.
  local function fork(blob, base, edited)
    _G.GSEDeltas = { pid1 = { b = blob, t = "sequence", src = "pid1",
      d = GSE.EncodeDelta(GSE.DiffDelta(base, edited)) } }
  end

  describe("at load", function()
    it("keeps the running version and parks the update", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        local mine = seq({ act("/cast [mod:alt] Alpha") })
        fork(blob("v1", v1), v1, mine)

        local v2 = seq({ act("/cast [mod:shift] Alpha"), act("/cast Bravo") }, "v2")
        local b2 = blob("v2", v2)
        local out = GSE.ApplyStoredDeltaFork(v2, b2)

        -- What the player had, unchanged. Nothing new appears mid-combat.
        assert.are.equal("/cast [mod:alt] Alpha", out.Versions[1].Actions[1].macro)
        assert.is_nil(out.Versions[1].Actions[2], "the author's new block waits")
        assert.are.equal(b2, GSE.PendingDeltaUpdate("pid1"), "and is parked")
        assert.are.equal(blob("v1", v1), GSEDeltas.pid1.b, "base not moved yet")
      end)
    end)

    it("clears the park once the blob matches again", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        local b1 = blob("v1", v1)
        fork(b1, v1, seq({ act("/cast [mod:alt] Alpha") }))
        GSEDeltas.pid1.pending = "!GSE3!+stale"
        GSE.ApplyStoredDeltaFork(v1, b1)
        assert.is_nil(GSE.PendingDeltaUpdate("pid1"))
      end)
    end)

    it("reconstructs as before when no blob is offered", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        fork(blob("v1", v1), v1, seq({ act("/cast [mod:alt] Alpha") }))
        local out = GSE.ApplyStoredDeltaFork(v1)
        assert.are.equal("/cast [mod:alt] Alpha", out.Versions[1].Actions[1].macro)
        assert.is_nil(GSE.PendingDeltaUpdate("pid1"))
      end)
    end)
  end)

  describe("on accept", function()
    it("carries the local edit onto the author's new version", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        fork(blob("v1", v1), v1, seq({ act("/cast [mod:alt] Alpha") }))
        local v2 = seq({ act("/cast [mod:shift] Alpha"), act("/cast Bravo") }, "v2")
        local b2 = blob("v2", v2)
        GSE.ApplyStoredDeltaFork(v2, b2)

        local merged, conflicts = GSE.RebaseDeltaFork("pid1")   -- takes the parked blob
        assert.are.equal("/cast [mod:alt] Alpha", merged.Versions[1].Actions[1].macro,
          "the override survived the update")
        assert.are.equal("/cast Bravo", merged.Versions[1].Actions[2].macro,
          "the author's new action arrived")
        assert.are.equal("v2", merged.MetaData.Notes, "the author's other changes arrived")
        assert.are.equal(0, #conflicts)
        assert.are.equal(b2, GSEDeltas.pid1.b, "rebased onto the new blob")
        assert.is_nil(GSEDeltas.pid1.pending, "park cleared")
      end)
    end)

    it("keeps the edit on its block when the author inserts one above", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast Alpha"), act("/cast [mod:shift] Bravo") })
        fork(blob("v1", v1), v1, seq({ act("/cast Alpha"), act("/cast [mod:alt] Bravo") }))
        local v2 = seq({ act("/cast Opener"), act("/cast Alpha"), act("/cast [mod:shift] Bravo") })
        local merged = GSE.RebaseDeltaFork("pid1", blob("v2", v2))

        assert.are.equal("/cast Opener", merged.Versions[1].Actions[1].macro)
        assert.are.equal("/cast Alpha", merged.Versions[1].Actions[2].macro)
        assert.are.equal("/cast [mod:alt] Bravo", merged.Versions[1].Actions[3].macro,
          "the edit followed its block, not its old index")
      end)
    end)

    it("keeps the local value on a clash and reports it", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        fork(blob("v1", v1), v1, seq({ act("/cast [mod:alt] Alpha") }))
        -- The author changed the very thing that was overridden.
        local v2 = seq({ act("/cast [mod:ctrl] Alpha") })
        local merged, conflicts = GSE.RebaseDeltaFork("pid1", blob("v2", v2))

        assert.are.equal("/cast [mod:alt] Alpha", merged.Versions[1].Actions[1].macro,
          "an override an update can silently revert is not an override")
        assert.are.equal(1, #conflicts)
        assert.are.equal("macro", conflicts[1].field)
        assert.are.equal("/cast [mod:shift] Alpha", conflicts[1].base)
        assert.are.equal("/cast [mod:alt] Alpha", conflicts[1].ours)
        assert.are.equal("/cast [mod:ctrl] Alpha", conflicts[1].theirs,
          "so the editor can offer theirs")
      end)
    end)

    it("takes the author's change to a field nobody overrode", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast [mod:shift] Alpha") })
        fork(blob("v1", v1), v1, seq({ act("/cast [mod:alt] Alpha") }))  -- Notes untouched
        local v2 = seq({ act("/cast [mod:shift] Alpha") }, "v2")
        local merged, conflicts = GSE.RebaseDeltaFork("pid1", blob("v2", v2))
        assert.are.equal("v2", merged.MetaData.Notes)
        assert.are.equal("/cast [mod:alt] Alpha", merged.Versions[1].Actions[1].macro)
        assert.are.equal(0, #conflicts)
      end)
    end)

    it("keeps a block the author added and one we added", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast Alpha") })
        fork(blob("v1", v1), v1, seq({ act("/cast Alpha"), act("/cast Mine") }))
        local v2 = seq({ act("/cast Alpha"), act("/cast Theirs") })
        local merged = GSE.RebaseDeltaFork("pid1", blob("v2", v2))
        local macros = {}
        for _, a in ipairs(merged.Versions[1].Actions) do macros[#macros + 1] = a.macro end
        assert.are.same({"/cast Alpha", "/cast Theirs", "/cast Mine"}, macros)
      end)
    end)

    it("refuses what it cannot decode, leaving the fork alone", function()
      withStubs(function(blob)
        local v1 = seq({ act("/cast Alpha") })
        local b1 = blob("v1", v1)
        fork(b1, v1, seq({ act("/cast Mine") }))
        local d1 = GSEDeltas.pid1.d
        assert.is_nil(GSE.RebaseDeltaFork("pid1", "!GSE3!+never-registered"))
        assert.are.equal(b1, GSEDeltas.pid1.b)
        assert.are.equal(d1, GSEDeltas.pid1.d)
        assert.is_nil(GSE.RebaseDeltaFork("nosuchpid", b1))
        assert.is_nil(GSE.RebaseDeltaFork(nil, b1))
      end)
    end)
  end)
end)
