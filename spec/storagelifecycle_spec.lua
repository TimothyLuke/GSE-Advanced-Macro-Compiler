---@diagnostic disable: undefined-global, duplicate-set-field
-- Storage.lua lifecycle: deleting, cloning, and the repack request.
--
-- packedatrest_spec covers the WRITE side -- which branch a save takes when the
-- record is protected. This covers what happens to a record on the way out, and
-- the request the addon files when it cannot seal something itself. Both are
-- paths where getting it wrong loses somebody's work rather than inconveniencing
-- them: a delete that leaves a fork behind means the next install under the same
-- PlatformID silently inherits a stranger's edits.
--
-- Run: busted spec/storagelifecycle_spec.lua   /   lua5.1 spec/run51.lua
describe("Storage lifecycle", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/SequenceDelta")

    GSE.ComputeSequenceDependencies = function() end
    GSE.SnapshotDependentMacros = function() end
    if not GSE.SendMessage then GSE.SendMessage = function() end end
    _G.GetServerTime = _G.GetServerTime or function() return 1700000000 end
    _G.InCombatLockdown = _G.InCombatLockdown or function() return false end
    GSE.Library = GSE.Library or {}
    -- Deleting re-arms the actionbar overrides once it has pruned them; the
    -- mock has no secure bindings to re-arm.
    GSE.ReloadOverrides = GSE.ReloadOverrides or function() end
    -- AceLocale returns nil for a key the mock locale has not been given, and
    -- string.format on nil is an error rather than a missing translation.
    local L = GSE.L
    L["Corrupt sequence '%s' (class %d) deleted."] = "Corrupt sequence '%s' (class %d) deleted." 
  end)

  before_each(function()
    _G.GSESequences = {[1] = {}}
    _G.GSEDeltas = {}
    _G.GSERepackQueue = {}
    _G.GSE_C = {}
    GSE.Library = {[1] = {}}
    GSE.CorruptSequences = {}
  end)

  local function seq(name, pid)
    return {
      MetaData = {Name = name, Default = 1, PlatformID = pid, noExport = true},
      Versions = {{Actions = {}}},
    }
  end
  local function forkFor(pid)
    return {b = "!GSE3!+1BASE", d = "delta", t = "sequence", src = pid}
  end

  -- ── deleting ──────────────────────────────────────────────────────────────
  describe("GSE.DeleteSequence", function()
    it("forgets the record's delta fork", function()
      -- The id has to be read BEFORE the record goes: once the library entry is
      -- nil there is nothing left to key the fork by, and it would sit in
      -- GSEDeltas forever waiting to be adopted by the next thing installed
      -- under that PlatformID.
      GSE.Library[1]["GONE"] = seq("GONE", "pid-gone")
      GSESequences[1]["GONE"] = "!GSE3!+1SEALED"
      GSEDeltas["pid-gone"] = forkFor("pid-gone")

      GSE.DeleteSequence(1, "GONE")

      assert.is_nil(GSEDeltas["pid-gone"], "the fork went with the record")
      assert.is_nil(GSE.Library[1]["GONE"])
      assert.is_nil(GSESequences[1]["GONE"])
    end)

    it("leaves another sequence's fork alone", function()
      GSE.Library[1]["GONE"] = seq("GONE", "pid-gone")
      GSE.Library[1]["STAYS"] = seq("STAYS", "pid-stays")
      GSEDeltas["pid-gone"] = forkFor("pid-gone")
      GSEDeltas["pid-stays"] = forkFor("pid-stays")

      GSE.DeleteSequence(1, "GONE")

      assert.is_nil(GSEDeltas["pid-gone"])
      assert.is_not_nil(GSEDeltas["pid-stays"], "a neighbour's edits are not collateral")
    end)

    it("survives a record that never had a fork", function()
      GSE.Library[1]["PLAIN"] = seq("PLAIN", nil)
      GSESequences[1]["PLAIN"] = {}
      assert.has_no.errors(function() GSE.DeleteSequence(1, "PLAIN") end)
      assert.is_nil(GSE.Library[1]["PLAIN"])
    end)

    it("drops actionbar overrides that pointed at it", function()
      GSE.Library[1]["GONE"] = seq("GONE", "pid-gone")
      GSE_C["ActionBarBinds"] = {
        Specialisations = {
          ["1"] = {
            ActionButton1 = {Bind = "ActionButton1", Sequence = "GONE"},
            ActionButton2 = {Bind = "ActionButton2", Sequence = "KEEP"},
          },
        },
      }
      GSE.DeleteSequence(1, "GONE")
      local binds = GSE_C["ActionBarBinds"]["Specialisations"]["1"]
      assert.is_nil(binds.ActionButton1, "a bind to a sequence that no longer exists is dead")
      assert.is_not_nil(binds.ActionButton2, "and the others are untouched")
    end)
  end)

  describe("GSE.DeleteCorruptSequence", function()
    it("forgets the fork when the body did load", function()
      GSE.Library[1]["BAD"] = seq("BAD", "pid-bad")
      GSESequences[1]["BAD"] = "!GSE3!+1SEALED"
      GSEDeltas["pid-bad"] = forkFor("pid-bad")

      GSE.DeleteCorruptSequence(1, "BAD")

      assert.is_nil(GSEDeltas["pid-bad"])
      assert.is_nil(GSESequences[1]["BAD"])
      assert.is_nil(GSE.Library[1]["BAD"])
    end)

    -- Documenting a real limit, not asserting it is desirable. The PlatformID
    -- is read from GSE.Library, and a sequence is usually ON the corrupt list
    -- BECAUSE loadOneClass could not decode it and set that entry to nil. So
    -- for the common case the fork cannot be keyed and survives the delete.
    -- GSEPlatformIDs is no help: it is keyed name|author, and the author is in
    -- the body we could not read.
    it("cannot forget the fork when the body never loaded", function()
      GSESequences[1]["BAD"] = "!GSE3!+1SEALED"
      GSE.Library[1]["BAD"] = nil
      GSEDeltas["pid-bad"] = forkFor("pid-bad")

      GSE.DeleteCorruptSequence(1, "BAD")

      assert.is_nil(GSESequences[1]["BAD"], "the record still goes")
      assert.is_not_nil(GSEDeltas["pid-bad"],
        "but its fork is stranded -- nothing links the name to the id once the body is unreadable")
    end)
  end)

  -- ── the repack request ────────────────────────────────────────────────────
  describe("GSE.QueueRepack", function()
    it("carries identity only, never a body", function()
      -- The whole point of the queue. Putting the decoded body in the request
      -- would recreate the plaintext-at-rest exposure in a second place.
      local s = seq("SEALED_ONE", "pid-1")
      s.Versions = {{Actions = {{macro = "/cast Secret"}}}}
      GSE.QueueRepack("sequence", 1, "SEALED_ONE", s, "edit-needs-repack")

      local entry
      for _, v in pairs(GSERepackQueue) do entry = v end
      assert.is_not_nil(entry)
      assert.are.equal("pid-1", entry.platformId)
      assert.are.equal("sequence", entry.t)
      assert.are.equal("SEALED_ONE", entry.name)
      assert.are.equal("edit-needs-repack", entry.reason)
      for _, banned in ipairs({"Versions", "MetaData", "body", "obj", "sequence"}) do
        assert.is_nil(entry[banned], banned .. " must not ride along in the request")
      end
      assert.is_false(tostring(entry):find("Secret") ~= nil)
    end)

    it("is idempotent -- ten logins leave one entry", function()
      local s = seq("SAME", "pid-same")
      for _ = 1, 10 do GSE.QueueRepack("sequence", 1, "SAME", s, "plaintext-at-rest") end
      local n = 0
      for _ in pairs(GSERepackQueue) do n = n + 1 end
      assert.are.equal(1, n)
    end)

    it("refuses a request it cannot key", function()
      assert.is_false(GSE.QueueRepack("sequence", 1, nil, seq("X", "p"), "r"))
      assert.is_false(GSE.QueueRepack("sequence", 1, "", seq("X", "p"), "r"))
    end)

    it("clears on request", function()
      GSE.QueueRepack("sequence", 1, "CLEARME", seq("CLEARME", "pid-c"), "r")
      GSE.ClearRepackRequest("sequence", 1, "CLEARME")
      local n = 0
      for _ in pairs(GSERepackQueue) do n = n + 1 end
      assert.are.equal(0, n)
    end)
  end)

  -- ── cloning ───────────────────────────────────────────────────────────────
  describe("GSE.CloneSequence", function()
    it("copies deeply, so the copy cannot write through to the original", function()
      -- Every save path clones before handing a sequence to the library. A
      -- shallow copy here means the editor's working table and the stored one
      -- are the same Actions table.
      local orig = seq("DEEP", "pid-deep")
      orig.Versions = {{Actions = {{macro = "/cast Alpha"}}}}
      local copy = GSE.CloneSequence(orig)
      copy.Versions[1].Actions[1].macro = "/cast Bravo"
      copy.MetaData.Name = "CHANGED"
      assert.are.equal("/cast Alpha", orig.Versions[1].Actions[1].macro)
      assert.are.equal("DEEP", orig.MetaData.Name)
    end)

    it("returns scalars unchanged and handles an empty table", function()
      assert.are.equal(7, GSE.CloneSequence(7))
      assert.are.equal("x", GSE.CloneSequence("x"))
      assert.is_nil(GSE.CloneSequence(nil))
      assert.are.same({}, GSE.CloneSequence({}))
    end)
  end)
end)
