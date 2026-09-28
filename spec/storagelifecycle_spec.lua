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
    _G.GSEStore = nil; GSE.LoadStore()
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
  -- A stored sequence: its envelope (id, label, body) and, if given, its
  -- loaded form. envelopePid is the PlatformID the envelope records.
  local function stored(id, name, body, loaded, envelopePid)
    local env = GSE.PutSequenceBody(1, id, name, body or "!GSE3!+1SEALED")
    env.PlatformID = envelopePid
    GSE.Library[1][id] = loaded
  end

  -- ── deleting ──────────────────────────────────────────────────────────────
  describe("GSE.DeleteSequence", function()
    it("forgets the record's delta fork", function()
      -- The id has to be read BEFORE the record goes: once the library entry is
      -- nil there is nothing left to key the fork by, and it would sit in
      -- GSEDeltas forever waiting to be adopted by the next thing installed
      -- under that PlatformID.
      stored("id-gone", "GONE", nil, seq("GONE", "pid-gone"))
      GSEDeltas["pid-gone"] = forkFor("pid-gone")

      GSE.DeleteSequence(1, "id-gone")

      assert.is_nil(GSEDeltas["pid-gone"], "the fork went with the record")
      assert.is_nil(GSE.Library[1]["id-gone"])
      assert.is_nil(GSE.SequenceEnvelope("id-gone"))
    end)

    it("leaves another sequence's fork alone", function()
      stored("id-gone", "GONE", nil, seq("GONE", "pid-gone"))
      stored("id-stays", "STAYS", nil, seq("STAYS", "pid-stays"))
      GSEDeltas["pid-gone"] = forkFor("pid-gone")
      GSEDeltas["pid-stays"] = forkFor("pid-stays")

      GSE.DeleteSequence(1, "id-gone")

      assert.is_nil(GSEDeltas["pid-gone"])
      assert.is_not_nil(GSEDeltas["pid-stays"], "a neighbour's edits are not collateral")
    end)

    it("survives a record that never had a fork", function()
      stored("id-plain", "PLAIN", "!GSE3!PLAIN", seq("PLAIN", nil))
      assert.has_no.errors(function() GSE.DeleteSequence(1, "id-plain") end)
      assert.is_nil(GSE.Library[1]["id-plain"])
    end)

    it("drops actionbar overrides that pointed at it", function()
      stored("id-gone", "GONE", nil, seq("GONE", "pid-gone"))
      GSE_C["ActionBarBinds"] = {
        Specialisations = {
          ["1"] = {
            -- Saved binds hold the sequence's id.
            ActionButton1 = {Bind = "ActionButton1", Sequence = "id-gone"},
            ActionButton2 = {Bind = "ActionButton2", Sequence = "id-keep"},
          },
        },
      }
      GSE.DeleteSequence(1, "id-gone")
      local binds = GSE_C["ActionBarBinds"]["Specialisations"]["1"]
      assert.is_nil(binds.ActionButton1, "a bind to a sequence that no longer exists is dead")
      assert.is_not_nil(binds.ActionButton2, "and the others are untouched")
    end)
  end)

  describe("GSE.DeleteCorruptSequence", function()
    it("forgets the fork when the body did load", function()
      stored("id-bad", "BAD", nil, seq("BAD", "pid-bad"))
      GSEDeltas["pid-bad"] = forkFor("pid-bad")

      GSE.DeleteCorruptSequence(1, "id-bad")

      assert.is_nil(GSEDeltas["pid-bad"])
      assert.is_nil(GSE.SequenceEnvelope("id-bad"))
      assert.is_nil(GSE.Library[1]["id-bad"])
    end)

    -- A sequence is usually ON the corrupt list because its body could not be
    -- decoded, so the PlatformID inside it cannot be read. This used to strand
    -- its fork; the envelope beside the body carries the PlatformID in the
    -- clear, so the fork goes with the record.
    it("forgets the fork even when the body never loaded", function()
      stored("id-bad", "BAD", nil, nil, "pid-bad")
      GSEDeltas["pid-bad"] = forkFor("pid-bad")

      GSE.DeleteCorruptSequence(1, "id-bad")

      assert.is_nil(GSE.SequenceEnvelope("id-bad"), "the record goes")
      assert.is_nil(GSEDeltas["pid-bad"], "and its fork with it")
    end)
  end)

  -- ── renaming ──────────────────────────────────────────────────────────────
  describe("GSE.RenameSequence", function()
    before_each(function()
      GSE.EncodeMessage = GSE.EncodeMessage or function(t) return "!GSE3!" .. tostring(t[1]) end
      GSE.SanitizeSequenceEditorMarkup = function() return false end
    end)

    it("keeps the id and moves the record when the rename changes class too", function()
      local s = seq("OLD", nil)
      s.MetaData.noExport = nil
      GSE.PutSequenceBody(1, "id-r", "OLD", "!GSE3!OLD")
      GSE.Library[1]["id-r"] = s
      GSE.Library[2] = {}
      assert.is_true(GSE.RenameSequence(2, "id-r", "NEW", s))
      assert.is_nil(GSE.Library[1]["id-r"], "no copy left in the old class")
      assert.are.equal(s, GSE.Library[2]["id-r"])
      local env, classid = GSE.SequenceEnvelope("id-r")
      assert.are.equal(2, classid)
      assert.are.equal("NEW", env.Name)
      assert.are.equal("id-r", GSE.FindSequenceId("NEW", 2))
    end)
  end)

  -- ── /gse movelostmacros ───────────────────────────────────────────────────
  describe("GSE.MoveMacroToClassFromGlobal", function()
    local savedClassFor, savedReload, savedStatics
    before_each(function()
      GSE.EncodeMessage = GSE.EncodeMessage or function(t) return "!GSE3!" .. tostring(t[1]) end
      GSE.SanitizeSequenceEditorMarkup = function() return false end
      savedClassFor, savedReload = GSE.GetClassIDforSpec, GSE.ReloadSequences
      GSE.GetClassIDforSpec = function(spec) return (spec <= 13) and spec or 5 end
      GSE.ReloadSequences = function() end
      savedStatics = GSE.Static.SpecIDList
      GSE.Static.SpecIDList = GSE.Static.SpecIDList or {}
      GSE.L["Moved %s to class %s."] = "Moved %s to class %s."
      require("../GSE_Utils/Utils")
    end)
    after_each(function()
      GSE.GetClassIDforSpec, GSE.ReloadSequences = savedClassFor, savedReload
      GSE.Static.SpecIDList = savedStatics
    end)

    it("moves a global sequence whose spec names a class, for good, keeping its id", function()
      local s = {MetaData = {Name = "LOST", SpecID = 258, Default = 1}, Versions = {{Actions = {}}}}
      GSE.Library[0] = {}
      GSE.PutSequenceBody(0, "id-lost", "LOST", "!GSE3!LOST")
      GSE.Library[0]["id-lost"] = s
      GSE.MoveMacroToClassFromGlobal()
      local env, classid = GSE.SequenceEnvelope("id-lost")
      assert.are.equal(5, classid, "stored in its class, not only moved in memory")
      assert.are.equal("LOST", env.Name)
      assert.is_nil(GSE.Library[0]["id-lost"])
      assert.is_not_nil(GSE.Library[5]["id-lost"])
    end)

    it("leaves a sequence that really is global", function()
      local s = {MetaData = {Name = "ALL", SpecID = 0, Default = 1}, Versions = {{Actions = {}}}}
      GSE.Library[0] = {}
      GSE.PutSequenceBody(0, "id-all", "ALL", "!GSE3!ALL")
      GSE.Library[0]["id-all"] = s
      GSE.MoveMacroToClassFromGlobal()
      local _, classid = GSE.SequenceEnvelope("id-all")
      assert.are.equal(0, classid)
    end)
  end)

  -- ── Embed blocks ──────────────────────────────────────────────────────────
  -- An Embed carries the id and the label: the id when this machine has it,
  -- the label otherwise; and what leaves the machine never carries a local id.
  describe("Embed blocks", function()
    local function embedding(block)
      return {MetaData = {Name = "OUTER"}, Versions = {{Actions = {block}}}}
    end
    local function inner(id, name, pid)
      local env = GSE.PutSequenceBody(1, id, name, "!GSE3!" .. name)
      env.PlatformID = pid
      GSE.Library[1][id] = {MetaData = {Name = name}, Versions = {{Actions = {}}}}
    end

    it("runs the embedded sequence by id, however it was renamed", function()
      inner("id-in", "RENAMED")
      local _, id = GSE.ResolveEmbed({Type = "Embed", SequenceID = "id-in", Sequence = "OLDNAME"})
      assert.are.equal("id-in", id)
    end)

    it("falls back to the label for an id this machine does not have", function()
      inner("id-in", "INNER")
      local _, id = GSE.ResolveEmbed({Type = "Embed", SequenceID = "someone-elses", Sequence = "INNER"})
      assert.are.equal("id-in", id)
    end)

    it("brings the block up to date on save: the id, and the current label", function()
      inner("id-in", "NEWNAME")
      local named = {Type = "Embed", Sequence = "NEWNAME"}
      local renamed = {Type = "Embed", SequenceID = "id-in", Sequence = "OLDNAME"}
      local seq = embedding(named)
      seq.Versions[2] = {Actions = {{Type = "Loop", renamed}}}
      GSE.NormaliseEmbeds(seq)
      assert.are.equal("id-in", named.SequenceID, "a label-only block gains the id")
      assert.are.equal("NEWNAME", renamed.Sequence, "the label follows a rename, even inside a Loop")
    end)

    it("never lets a local id leave the machine", function()
      inner("local-unsynced", "UNSYNCED")
      inner("local-synced", "SYNCED", "pid-synced0000000000000000")
      local a = {Type = "Embed", SequenceID = "local-unsynced", Sequence = "UNSYNCED"}
      local b = {Type = "Embed", SequenceID = "local-synced", Sequence = "SYNCED"}
      local seq = embedding(a)
      seq.Versions[1].Actions[2] = b
      GSE.NormaliseEmbeds(seq, true)
      assert.is_nil(a.SequenceID, "no PlatformID yet: the label decides elsewhere")
      assert.are.equal("UNSYNCED", a.Sequence)
      assert.are.equal("pid-synced0000000000000000", b.SequenceID)
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

-- ── duplicating ─────────────────────────────────────────────────────────────
-- A duplicate must become its OWN record. Inheriting the source's PlatformID
-- would have the copy and the original resolve to one server record and
-- overwrite each other on the next Companion sync (#2077 is the import-rename
-- form of the same fault).
describe("GSE.DuplicateSequence", function()
  setup(function()
    GSE.GetCurrentClassID = GSE.GetCurrentClassID or function() return 1 end
    GSE.UpdateSequence = function() end
    GSE.GetActiveSequenceVersion = function() return 1 end
    GSE.SanitizeSequenceEditorMarkup = function() return false end
    GSE.EncodeMessage = GSE.EncodeMessage or function(t) return "!GSE3!" .. tostring(t[1]) end
  end)

  before_each(function()
    _G.GSEStore = nil; GSE.LoadStore()
    GSE.Library = {[1] = {}}
  end)

  local function source(name)
    return {
      MetaData = {Name = name, Author = "Bob@Realm", Default = 1,
                  PlatformID = "pid-source", OriginKey = "SRC|Bob@Realm"},
      Versions = {{Actions = {{macro = "/cast Alpha"}}}},
    }
  end
  -- A stored, loaded sequence under id; returns the id.
  local function put(id, name)
    GSE.PutSequenceBody(1, id, name, "!GSE3!" .. name)
    GSE.Library[1][id] = source(name)
    return id
  end
  local function copyNamed(name)
    local id = GSE.FindSequenceId(name, 1)
    return id and GSE.Library[1][id], id
  end

  it("mints its own identity instead of inheriting one", function()
    put("id-src", "SRC")
    local newId, newName = GSE.DuplicateSequence(1, "id-src", "COPY")
    assert.are.equal("COPY", newName)
    assert.are_not.equal("id-src", newId, "a copy is a new record here too")
    local copy = GSE.Library[1][newId]
    assert.is_not_nil(copy)
    assert.is_nil(copy.MetaData.PlatformID, "a copy is not the record it was copied from")
    assert.are.equal("COPY|Bob@Realm", copy.MetaData.OriginKey, "and begins its own history")
    assert.are.equal("COPY", copy.MetaData.Name)
  end)

  it("leaves the source untouched", function()
    put("id-src", "SRC")
    GSE.DuplicateSequence(1, "id-src", "COPY")
    local src = GSE.Library[1]["id-src"]
    assert.are.equal("pid-source", src.MetaData.PlatformID)
    assert.are.equal("SRC|Bob@Realm", src.MetaData.OriginKey)
    assert.are.equal("SRC", src.MetaData.Name)
  end)

  it("copies the body deeply", function()
    put("id-src", "SRC")
    GSE.DuplicateSequence(1, "id-src", "COPY")
    copyNamed("COPY").Versions[1].Actions[1].macro = "/cast Bravo"
    assert.are.equal("/cast Alpha", GSE.Library[1]["id-src"].Versions[1].Actions[1].macro)
  end)

  it("normalises a supplied name the way import does", function()
    put("id-src", "SRC")
    assert.are.equal("My_New_Seq", select(2, GSE.DuplicateSequence(1, "id-src", "My New,Seq")))
  end)

  it("auto-numbers when no name is given", function()
    put("id-src", "SRC")
    assert.are.equal("SRCCopy", select(2, GSE.DuplicateSequence(1, "id-src")))
    assert.are.equal("SRCCopy2", select(2, GSE.DuplicateSequence(1, "id-src")))
    assert.are.equal("SRCCopy3", select(2, GSE.DuplicateSequence(1, "id-src")))
  end)

  it("refuses a name already in use rather than overwriting it", function()
    put("id-src", "SRC")
    put("id-taken", "TAKEN")
    assert.is_nil(GSE.DuplicateSequence(1, "id-src", "TAKEN"))
    assert.are.equal("TAKEN", GSE.Library[1]["id-taken"].MetaData.Name, "the occupant is untouched")
    assert.are.equal("id-taken", GSE.FindSequenceId("TAKEN", 1), "and still the one the name finds")
  end)

  it("refuses what it cannot find or name", function()
    assert.is_nil(GSE.DuplicateSequence(1, "id-nosuch", "X"))
    assert.is_nil(GSE.DuplicateSequence(1, nil, "X"))
  end)
end)
