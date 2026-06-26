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
