---@diagnostic disable: undefined-global, duplicate-set-field
-- GSEStore: migration from the old SavedVariables, and the reconcile that
-- writes this session's working views back at logout.
--
-- This is the code that decides what survives a save. Every test here is a
-- way a user's content could be lost, duplicated or cross-wired if it were
-- wrong: a sequence that loses its GSE.Tools id and uploads as a duplicate, a
-- character macro that turns up on the wrong character, a record the working
-- view could not show being treated as deleted.
--
-- Sequence Bodies are stubbed as "SEQ|name|author|pid" so a test can say what
-- a decode would find without the real codec.
--
-- Run: busted spec/gsestore_spec.lua   /   lua5.1 spec/run51.lua
describe("GSEStore", function()
  local LEGACY = { "GSESequences", "GSEVariables", "GSEMacros",
                   "GSEPlatformIDs", "GSEVariablePlatformIDs", "GSEMacroPlatformIDs" }

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
  end)

  before_each(function()
    -- No character is logged in unless a test says so.
    _G.UnitGUID = nil
    _G.UnitClass = nil
    GSE.DecodeMessage = function(body)
      if type(body) ~= "string" then return false end
      -- "VAR|<spec>|<tag>": a variable whose MetaData.SpecID is <spec> ("" for none).
      local vspec = body:match("^VAR|([^|]*)|")
      if vspec then
        return true, { funct = "function() return true end",
                       MetaData = { SpecID = tonumber(vspec) } }
      end
      local name, author, pid = body:match("^SEQ|([^|]*)|([^|]*)|([^|]*)")
      if not name then return false end
      return true, { name, { MetaData = { Name = name, Author = author,
                                          PlatformID = (pid ~= "" and pid) or nil } } }
    end
  end)

  -- Load a fresh store from the given legacy globals (a first run of the build).
  local function firstRun(legacy)
    _G.GSEStore = nil
    for _, g in ipairs(LEGACY) do _G[g] = nil end
    for g, v in pairs(legacy or {}) do _G[g] = v end
    GSE.LoadStore()
  end

  -- /reload: write back, then load again from what was written.
  local function reload()
    GSE.ReconcileStore()
    GSE.LoadStore()
  end

  local function envs(kind, classid)
    return (GSEStore[kind] or {})[classid] or {}
  end

  local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

  local function onlyId(t) local id = next(t); return id end

  local function isLocal(id) return type(id) == "string" and id:sub(1, 6) == "local-" end

  local SEQ_A = "SEQ|Alpha|Tim@Realm|pidA000000000000000000aa"

  -- The macro ids a character holds, and where a macro is filed.
  local function held(charKey)
    local rec = (GSEStore.character or {})[charKey]
    return rec and rec.Macros or {}
  end
  local function classOf(id)
    for classid, e in pairs(GSEStore.macro) do if e[id] then return classid end end
  end
  local function macroNamed(name)
    for _, e in pairs(GSEStore.macro) do
      for id, env in pairs(e) do if env.Name == name then return id, env end end
    end
  end
  -- Log a character in: its GUID and class.
  local function loginAs(guid, classId)
    _G.UnitGUID = function() return guid end
    _G.UnitClass = function() return "x", "X", classId end
  end

  describe("migration", function()
    it("keeps each sequence in its class and keys it by its PlatformID", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local e = envs("sequence", 2)
      assert.equals(1, count(e))
      local env = e["pidA000000000000000000aa"]
      assert.is_not_nil(env, "keyed by the PlatformID found in the body")
      assert.equals("Alpha", env.Name)
      assert.equals(SEQ_A, env.Body)
      assert.equals("Tim@Realm", env.Author)
    end)

    it("prefers the name|author sidecar to the id inside the body", function()
      firstRun({
        GSESequences = { [2] = { Alpha = SEQ_A } },
        GSEPlatformIDs = { ["Alpha|Tim@Realm"] = "sidecar00000000000000001" },
      })
      assert.is_not_nil(envs("sequence", 2)["sidecar00000000000000001"])
    end)

    it("gives an unsynced sequence a local id", function()
      firstRun({ GSESequences = { [2] = { Beta = "SEQ|Beta|Tim@Realm|" } } })
      assert.is_true(isLocal(onlyId(envs("sequence", 2))))
    end)

    it("files every variable and macro in class 0", function()
      firstRun({
        GSEVariables = { Prescience = "VARBODY" },
        GSEMacros = { Pull = { text = "/cast Charge", value = 3 } },
        GSEVariablePlatformIDs = { Prescience = "varpid000000000000000001" },
      })
      assert.equals("VARBODY", envs("variable", 0)["varpid000000000000000001"].Body)
      local id = onlyId(envs("macro", 0))
      assert.equals("account", envs("macro", 0)[id].Scope)
      assert.equals("Pull", envs("macro", 0)[id].Name)
    end)

    it("clears the old SavedVariables once they are moved", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } }, GSEVariables = { V = "x" } })
      for _, g in ipairs(LEGACY) do assert.is_nil(_G[g], g .. " still set") end
    end)

    it("hands variables and macros to the rest of the Mod in their old shapes", function()
      firstRun({
        GSESequences = { [2] = { Alpha = SEQ_A } },
        GSEVariables = { V = "VARBODY" },
        GSEMacros = { Pull = { text = "/cast Charge", value = 3 } },
      })
      assert.equals("VARBODY", GSE.Store("variable").V)
      assert.equals("/cast Charge", GSE.Store("macro").Pull.text)
      assert.equals(3, GSE.Store("macro").Pull.value)
      -- Sequences have no name-keyed view any more: they are reached by id.
      assert.is_false((pcall(GSE.Store, "sequence")))
      assert.equals(SEQ_A, GSE.SequenceEnvelope("pidA000000000000000000aa", 2).Body)
    end)

    -- Once this build has run, the old tables are cleared at every logout, so
    -- finding one beside GSEStore means something wrote it while WoW was
    -- closed (the Companion). That is the newer intent, and it must win.
    it("applies an old table written while WoW was closed over the store", function()
      _G.GSEStore = { v = 1, sequence = { [2] = { pidA000000000000000000aa =
        { Name = "Alpha", Body = "STALE", PlatformID = "pidA000000000000000000aa" } } },
        variable = {}, macro = {} }
      for _, g in ipairs(LEGACY) do _G[g] = nil end
      _G.GSESequences = { [2] = { Alpha = SEQ_A } }
      GSE.LoadStore()
      assert.equals(1, count(envs("sequence", 2)), "updated in place, not duplicated")
      assert.equals(SEQ_A, envs("sequence", 2)["pidA000000000000000000aa"].Body)
    end)

    it("replaces one character's macro from an external write, leaving others", function()
      _G.GSEStore = { v = 1, sequence = {}, variable = {},
        macro = { [0] = { m1 = { Name = "Burst", Scope = "character", Body = { text = "/cast X" } } } },
        character = { ["Player-1-AAA"] = { Macros = { m1 = 121 } },
                      ["Player-1-BBB"] = { Macros = { m1 = 125 } } } }
      for _, g in ipairs(LEGACY) do _G[g] = nil end
      _G.GSEMacros = { ["Player-1-AAA"] = { Burst = { text = "/cast Z", value = 121 } } }
      GSE.LoadStore()
      assert.equals(2, count(envs("macro", 0)))
      assert.equals("/cast Z", GSE.Store("macro")["Player-1-AAA"].Burst.text)
      assert.equals("/cast X", GSE.Store("macro")["Player-1-BBB"].Burst.text)
    end)

    it("makes one macro held by two characters when their copies agree", function()
      firstRun({ GSEMacros = {
        ["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } },
        ["Player-1-BBB"] = { Burst = { text = "/cast X", value = 125 } },
      } })
      local e = envs("macro", 0)
      assert.equals(1, count(e), "one macro, filed global like every migrated macro")
      local id = onlyId(e)
      assert.equals("character", e[id].Scope)
      assert.equals(121, held("Player-1-AAA")[id], "each character references it, with its own slot")
      assert.equals(125, held("Player-1-BBB")[id])
      assert.is_nil(e[id].Body.value, "the slot is per character, not part of the body")
    end)

    it("keeps two macros apart when the characters' copies differ", function()
      firstRun({ GSEMacros = {
        ["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } },
        ["Player-1-BBB"] = { Burst = { text = "/cast Y", value = 125 } },
      } })
      assert.equals(2, count(envs("macro", 0)))
      assert.equals("/cast X", GSE.Store("macro")["Player-1-AAA"].Burst.text)
      assert.equals("/cast Y", GSE.Store("macro")["Player-1-BBB"].Burst.text)
      assert.equals(125, GSE.Store("macro")["Player-1-BBB"].Burst.value)
    end)
  end)

  -- ── scope of variables and macros ───────────────────────────────────────────
  describe("scope", function()
    local function classOf(kind, name)
      for classid, envs in pairs(GSEStore[kind]) do
        for _, env in pairs(envs) do if env.Name == name then return classid end end
      end
    end
    local function asWarrior() _G.UnitClass = function() return "Warrior", "WARRIOR", 1 end end

    it("files a variable in the class its SpecID names", function()
      firstRun({ GSEVariables = { Glob = "VAR||g", Mine = "VAR|4|m", Also = "VAR|0|a" } })
      assert.equals(0, classOf("variable", "Glob"), "no SpecID: global")
      assert.equals(4, classOf("variable", "Mine"))
      assert.equals(0, classOf("variable", "Also"))
    end)

    it("files a spec-level variable in that spec's class", function()
      local saved = GSE.GetClassIDforSpec
      GSE.GetClassIDforSpec = function(spec) return spec == 71 and 1 or 0 end
      firstRun({ GSEVariables = { Arms = "VAR|71|a" } })
      GSE.GetClassIDforSpec = saved
      assert.equals(1, classOf("variable", "Arms"))
    end)

    it("re-files a variable whose SpecID changed, at the next load", function()
      firstRun({ GSEVariables = { V = "VAR||v" } })
      GSE.Store("variable").V = "VAR|6|v2"
      reload()
      assert.equals(6, classOf("variable", "V"))
      assert.equals(1, count(envs("variable", 6)), "moved, not copied")
      assert.equals(0, count(envs("variable", 0)))
    end)

    it("lets the current class's variable win over a global one of the same name", function()
      asWarrior()
      _G.GSEStore = { v = 1, sequence = {}, macro = {}, variable = {
        [0] = { ["local-g"] = { Name = "Dup", Body = "VAR||global" } },
        [1] = { ["local-w"] = { Name = "Dup", Body = "VAR|1|warrior" } },
      } }
      GSE.LoadStore()
      assert.equals("VAR|1|warrior", GSE.Store("variable").Dup)
      reload()
      assert.equals(1, count(envs("variable", 0)), "the global one is kept, not deleted")
      assert.equals(1, count(envs("variable", 1)))
    end)

    it("makes only the current class and global live", function()
      asWarrior()
      firstRun({ GSEVariables = { G = "VAR||g", W = "VAR|1|w", P = "VAR|2|p" } })
      assert.is_true(GSE.ElementAvailable("variable", "G"))
      assert.is_true(GSE.ElementAvailable("variable", "W"))
      assert.is_false(GSE.ElementAvailable("variable", "P"), "a Paladin variable is not live on a Warrior")
    end)

    it("files an account macro by its SpecID, and re-files it when that changes", function()
      firstRun({ GSEMacros = { Pull = { text = "/cast Charge", value = 3, MetaData = { SpecID = 1 } } } })
      assert.equals(1, classOf("macro", "Pull"))
      GSE.Store("macro").Pull.MetaData = { SpecID = 5 }
      reload()
      assert.equals(5, classOf("macro", "Pull"))
    end)
  end)

  describe("reconcile", function()
    it("does nothing before the store has been loaded this session", function()
      assert.has_no.errors(function() GSE.ReconcileStore() end)
    end)

    it("leaves an untouched library exactly as it was", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } }, GSEVariables = { V = "VARBODY" } })
      local before = onlyId(envs("variable", 0))
      reload()
      assert.is_not_nil(envs("sequence", 2)["pidA000000000000000000aa"])
      assert.equals(before, onlyId(envs("variable", 0)), "same id across a reload")
    end)

    it("saves an edit under the same id", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local edited = "SEQ|Alpha|Tim@Realm|pidA000000000000000000aa|v2"
      GSE.PutSequenceBody(2, "pidA000000000000000000aa", "Alpha", edited)
      reload()
      assert.equals(edited, envs("sequence", 2)["pidA000000000000000000aa"].Body)
      assert.equals(1, count(envs("sequence", 2)))
    end)

    it("files a new sequence under a local id, then moves it to its PlatformID at load", function()
      firstRun({})
      local id = GSE.NewLocalId()
      GSE.PutSequenceBody(3, id, "Gamma", "SEQ|Gamma|Tim@Realm|")
      reload()
      assert.is_not_nil(envs("sequence", 3)[id], "a local id is kept until there is a PlatformID")
      -- The round trip to GSE.Tools: the id arrives, and nothing moves mid-session.
      assert.is_true(GSE.SetStoredPlatformID("sequence", "Gamma", "newpid000000000000000001"))
      assert.is_not_nil(envs("sequence", 3)[id], "not moved while the session is running")
      reload()
      assert.is_nil(envs("sequence", 3)[id], "the local key is gone")
      assert.equals("Gamma", envs("sequence", 3)["newpid000000000000000001"].Name)
      -- Anything still holding the local id -- another character's keybind --
      -- finds it where it went.
      assert.equals("newpid000000000000000001", GSE.ResolveSequenceId(id))
      assert.equals("Gamma", GSE.SequenceName(id))
    end)

    it("never moves a sequence onto an id another sequence holds", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local id = GSE.NewLocalId()
      GSE.PutSequenceBody(2, id, "Copy", "SEQ|Copy|Tim@Realm|")
      GSE.SequenceEnvelope(id).PlatformID = "pidA000000000000000000aa"
      reload()
      assert.equals("Alpha", envs("sequence", 2)["pidA000000000000000000aa"].Name, "the holder keeps it")
      assert.equals("Copy", envs("sequence", 2)[id].Name, "the other stays where it was")
    end)

    it("never moves a sequence onto an id held in another class", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local id = GSE.NewLocalId()
      GSE.PutSequenceBody(5, id, "Other", "SEQ|Other|Tim@Realm|")
      GSE.SequenceEnvelope(id).PlatformID = "pidA000000000000000000aa"
      reload()
      assert.equals("Alpha", envs("sequence", 2)["pidA000000000000000000aa"].Name)
      assert.is_nil(envs("sequence", 5)["pidA000000000000000000aa"], "no second holder of one id")
      assert.equals("Other", envs("sequence", 5)[id].Name)
    end)

    it("will not record a PlatformID another sequence already holds", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.PutSequenceBody(5, "local-other", "Other", "SEQ|Other|Tim@Realm|")
      assert.is_false(GSE.SetStoredPlatformID("sequence", "Other", "pidA000000000000000000aa", 5))
      assert.is_nil(GSE.SequenceEnvelope("local-other").PlatformID)
    end)

    -- ── buttons ─────────────────────────────────────────────────────────────
    it("gives a sequence a short button name that a rename does not change", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local b = GSE.ButtonForSequence("pidA000000000000000000aa")
      assert.is_truthy(b:match("^GSES%d+$"))
      assert.is_true(#b <= 10, "short enough for a macro's /click line")
      GSE.PutSequenceBody(2, "pidA000000000000000000aa", "Omega", SEQ_A)
      reload()
      assert.equals(b, GSE.ButtonForSequence("pidA000000000000000000aa"), "same button after a rename and a reload")
      assert.equals("pidA000000000000000000aa", GSE.SequenceIdForButton(b))
    end)

    it("moves a sequence's button with it to its PlatformID", function()
      firstRun({})
      local id = GSE.NewLocalId()
      GSE.PutSequenceBody(3, id, "Gamma", "SEQ|Gamma|Tim@Realm|")
      local b = GSE.ButtonForSequence(id)
      GSE.SetStoredPlatformID("sequence", "Gamma", "newpid000000000000000001")
      reload()
      assert.equals(b, GSE.ButtonForSequence("newpid000000000000000001"), "binds keep clicking the same button")
      assert.equals(b, GSE.ButtonForSequence(id), "and the old id still finds it")
      assert.equals("newpid000000000000000001", GSE.SequenceIdForButton(b))
    end)

    it("retires a deleted sequence's button instead of handing it to another", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local b = GSE.ButtonForSequence("pidA000000000000000000aa")
      GSE.RemoveSequence(2, "pidA000000000000000000aa")
      assert.is_nil(GSE.SequenceIdForButton(b))
      GSE.PutSequenceBody(2, "local-new", "New", "SEQ|New|Tim@Realm|")
      assert.are_not.equal(b, GSE.ButtonForSequence("local-new"), "a stale keybind must not fire the new sequence")
    end)

    it("has no button for something that is not a stored sequence", function()
      firstRun({})
      assert.is_nil(GSE.ButtonForSequence("nope"))
      assert.is_nil(GSE.ButtonForSequence(nil))
    end)

    -- ── this character's keybinds and overrides ─────────────────────────────
    it("rewrites a character's keybinds and overrides from names and old ids to ids", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      local id = GSE.NewLocalId()
      GSE.PutSequenceBody(0, id, "Gamma", "SEQ|Gamma|Tim@Realm|")
      GSE.SequenceEnvelope(id).PlatformID = "newpid000000000000000001"
      reload()                                       -- Gamma moved; id is now an alias
      _G.UnitClass = function() return "Warrior", "WARRIOR", 2 end
      _G.GSE_C = {
        KeyBindings = { ["1"] = { F = "Alpha", G = id, H = "NoSuchThing",
                                  LoadOuts = { ["7"] = { J = "Alpha" } } } },
        ActionBarBinds = {
          Specialisations = { ["1"] = { ActionButton1 = { Bind = "ActionButton1", Sequence = "Gamma" } } },
          LoadOuts = { ["1"] = { ["7"] = { ActionButton2 = { Bind = "ActionButton2", Sequence = id } } } },
        },
      }
      GSE.UpdateCharacterSequenceRefs()
      local kb = GSE_C.KeyBindings["1"]
      assert.equals("pidA000000000000000000aa", kb.F, "a name becomes the id")
      assert.equals("newpid000000000000000001", kb.G, "an old id follows its alias")
      assert.equals("NoSuchThing", kb.H, "a reference to nothing is left alone")
      assert.equals("pidA000000000000000000aa", kb.LoadOuts["7"].J)
      assert.equals("newpid000000000000000001", GSE_C.ActionBarBinds.Specialisations["1"].ActionButton1.Sequence)
      assert.equals("newpid000000000000000001", GSE_C.ActionBarBinds.LoadOuts["1"]["7"].ActionButton2.Sequence)
    end)

    it("drops a deleted sequence", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.RemoveSequence(2, "pidA000000000000000000aa")
      reload()
      assert.equals(0, count(envs("sequence", 2)))
      assert.is_nil(GSE.FindSequenceId("Alpha", 2))
    end)

    it("keeps the id across a rename", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.PutSequenceBody(2, "pidA000000000000000000aa", "Omega", "SEQ|Omega|Tim@Realm|")
      reload()
      local env = envs("sequence", 2)["pidA000000000000000000aa"]
      assert.is_not_nil(env, "same record on GSE.Tools, same key here")
      assert.equals("Omega", env.Name)
      assert.equals(1, count(envs("sequence", 2)), "not a copy plus a delete")
      assert.equals("pidA000000000000000000aa", GSE.FindSequenceId("Omega", 2))
      assert.is_nil(GSE.FindSequenceId("Alpha", 2), "the old label finds nothing")
    end)

    it("keeps the id when a sequence moves to another class", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.PutSequenceBody(5, "pidA000000000000000000aa", "Alpha", SEQ_A)
      reload()
      assert.equals(0, count(envs("sequence", 2)))
      assert.is_not_nil(envs("sequence", 5)["pidA000000000000000000aa"])
      assert.is_nil(GSE.FindSequenceId("Alpha", 2))
      assert.equals("pidA000000000000000000aa", GSE.FindSequenceId("Alpha", 5))
    end)

    it("lets two sequences share a name, finding the same one every time", function()
      firstRun({})
      GSE.PutSequenceBody(2, "local-b", "Same", "SEQ|Same|A|")
      GSE.PutSequenceBody(2, "local-a", "Same", "SEQ|Same|B|")
      reload()
      assert.equals(2, count(envs("sequence", 2)), "both kept")
      assert.equals("local-a", GSE.FindSequenceId("Same", 2))
      GSE.RemoveSequence(2, "local-a")
      assert.equals("local-b", GSE.FindSequenceId("Same", 2), "the other is found once one goes")
    end)

    -- Two records with one name cannot both appear in a name-keyed view. The
    -- one that could not be shown must not be read as deleted.
    it("never deletes a record the view could not show", function()
      _G.GSEStore = { v = 1, variable = { [0] = {
        a = { Name = "Dup", Body = "one" },
        b = { Name = "Dup", Body = "two" },
      } }, sequence = {}, macro = {} }
      for _, g in ipairs(LEGACY) do _G[g] = nil end
      GSE.LoadStore()
      reload()
      assert.equals(2, count(envs("variable", 0)))
    end)

    it("detaches one character's copy when it is edited, leaving the other", function()
      firstRun({ GSEMacros = {
        ["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } },
        ["Player-1-BBB"] = { Burst = { text = "/cast X", value = 125 } },
      } })
      GSE.Store("macro")["Player-1-AAA"].Burst.text = "/cast Z"
      reload()
      assert.equals(2, count(envs("macro", 0)))
      assert.equals("/cast Z", GSE.Store("macro")["Player-1-AAA"].Burst.text)
      assert.equals("/cast X", GSE.Store("macro")["Player-1-BBB"].Burst.text)
    end)

    it("removes a character's slot, and the macro once no character holds it", function()
      firstRun({ GSEMacros = {
        ["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } },
        ["Player-1-BBB"] = { Burst = { text = "/cast X", value = 125 } },
      } })
      GSE.Store("macro")["Player-1-AAA"].Burst = nil
      reload()
      local e = envs("macro", 0)
      assert.equals(1, count(e))
      assert.is_nil(GSEStore.character["Player-1-AAA"], "a character left holding nothing has no record")
      assert.equals(125, held("Player-1-BBB")[onlyId(e)])
      GSE.Store("macro")["Player-1-BBB"].Burst = nil
      reload()
      assert.equals(0, count(envs("macro", 0)))
    end)

    it("follows a character's bucket from its legacy key to its GUID", function()
      firstRun({ GSEMacros = { ["Bob-Geldoff"] = { Burst = { text = "/cast X", value = 121 } } } })
      local m = GSE.Store("macro")
      m["Player-4618-00936B90"], m["Bob-Geldoff"] = m["Bob-Geldoff"], nil
      reload()
      local id = onlyId(envs("macro", 0))
      assert.equals(121, held("Player-4618-00936B90")[id])
      assert.is_nil(GSEStore.character["Bob-Geldoff"], "the legacy-keyed record is gone")
      assert.equals(1, count(envs("macro", 0)))
    end)

    it("files a macro made in game in its character's class", function()
      firstRun({})
      loginAs("Player-1-AAA", 4)
      GSE.Store("macro")["Player-1-AAA"] = { Vanish = { text = "/cast Vanish", value = 122 } }
      reload()
      local id = macroNamed("Vanish")
      assert.equals(4, classOf(id))
      assert.equals(4, GSEStore.character["Player-1-AAA"].ClassID, "the class is learned at login")
    end)

    it("moves a macro global once a character of another class holds it too", function()
      firstRun({})
      loginAs("Player-1-AAA", 4)
      GSE.Store("macro")["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } }
      reload()
      assert.equals(4, classOf(macroNamed("Burst")))
      loginAs("Player-1-BBB", 8)
      GSE.Store("macro")["Player-1-BBB"] = { Burst = { text = "/cast X", value = 125 } }
      reload()
      local id = macroNamed("Burst")
      assert.equals(0, classOf(id))
      assert.equals(121, held("Player-1-AAA")[id], "both still hold the one macro")
      assert.equals(125, held("Player-1-BBB")[id])
    end)

    it("never moves a macro out of global on its own", function()
      firstRun({ GSEMacros = { ["Bob-Geldoff"] = { Burst = { text = "/cast X", value = 121 } } } })
      loginAs("Player-4618-00936B90", 4)
      local m = GSE.Store("macro")
      m["Player-4618-00936B90"], m["Bob-Geldoff"] = m["Bob-Geldoff"], nil
      reload()
      assert.equals(0, classOf(macroNamed("Burst")), "migrated: global until an author moves it")
    end)

    -- The macro moves to its real key when GSE.Tools hands it one; every
    -- character's reference has to move with it, or the character is left
    -- pointing at an id that no longer exists and the macro drops out of its
    -- bucket.
    it("moves characters' references with a macro that gets its PlatformID", function()
      firstRun({})
      loginAs("Player-1-AAA", 4)
      GSE.Store("macro")["Player-1-AAA"] = { Vanish = { text = "/cast Vanish", value = 122 } }
      reload()
      assert.is_true(isLocal(macroNamed("Vanish")))
      GSE.Store("macroPid").Vanish = "mpid00000000000000000001"
      reload()
      assert.equals("mpid00000000000000000001", (macroNamed("Vanish")))
      assert.equals(122, held("Player-1-AAA")["mpid00000000000000000001"])
      assert.equals("/cast Vanish", GSE.Store("macro")["Player-1-AAA"].Vanish.text,
        "still in the character's bucket after the move")
    end)

    -- The sidecar is keyed by name, and two characters can hold DIFFERENT
    -- macros of one name. An id for that name cannot say which one it means,
    -- so neither takes it -- rather than both, which would give two macros one
    -- identity and let one overwrite the other.
    it("does not hand one PlatformID to two different macros of the same name", function()
      firstRun({ GSEMacros = {
        ["Player-1-AAA"] = { Burst = { text = "/cast X", value = 121 } },
        ["Player-1-BBB"] = { Burst = { text = "/cast Y", value = 125 } },
      } })
      GSE.Store("macroPid").Burst = "mpid00000000000000000002"
      reload()
      assert.equals(2, count(envs("macro", 0)), "both macros survive")
      for _, env in pairs(envs("macro", 0)) do
        assert.is_nil(env.PlatformID, "neither claims an ambiguous id")
      end
      assert.equals("/cast X", GSE.Store("macro")["Player-1-AAA"].Burst.text)
      assert.equals("/cast Y", GSE.Store("macro")["Player-1-BBB"].Burst.text)
    end)

    it("keeps an account macro's slot, which ManageMacros sets in place", function()
      firstRun({ GSEMacros = { Pull = { text = "/cast Charge", value = 3 } } })
      GSE.Store("macro").Pull.value = 7
      reload()
      assert.equals(7, GSE.Store("macro").Pull.value)
    end)

    it("records a PlatformID from the bridge without rewriting the body", function()
      -- A sealed body must come back byte for byte; the id lives in the envelope.
      local sealed = "SEQ|Sealed|Tim@Realm|"
      firstRun({ GSESequences = { [0] = { Sealed = sealed } } })
      local encoded = 0
      GSE.EncodeMessage = function() encoded = encoded + 1; return "REENCODED" end
      assert.is_true(GSE.SetStoredPlatformID("sequence", "Sealed", "pidS000000000000000000ss", 4))
      reload()
      assert.equals(0, encoded, "nothing re-encoded")
      local env = envs("sequence", 0)["pidS000000000000000000ss"]
      assert.is_not_nil(env, "global sequences get their id too")
      assert.equals(sealed, env.Body)
      assert.equals("pidS000000000000000000ss", env.PlatformID)
    end)

    it("records a PlatformID for a sequence created this session", function()
      firstRun({})
      GSE.PutSequenceBody(3, GSE.NewLocalId(), "Fresh", "SEQ|Fresh|Tim@Realm|")
      assert.is_true(GSE.SetStoredPlatformID("sequence", "Fresh", "pidF000000000000000000ff"))
      reload()
      assert.equals("Fresh", envs("sequence", 3)["pidF000000000000000000ff"].Name)
    end)

    it("records a PlatformID for a variable and a macro", function()
      firstRun({ GSEVariables = { V = "VARBODY" },
                 GSEMacros = { Pull = { text = "/cast Charge", value = 3 } } })
      assert.is_true(GSE.SetStoredPlatformID("variable", "V", "pidV000000000000000000vv"))
      assert.is_true(GSE.SetStoredPlatformID("macro", "Pull", "pidM000000000000000000mm"))
      reload()
      assert.equals("V", envs("variable", 0)["pidV000000000000000000vv"].Name)
      assert.equals("Pull", envs("macro", 0)["pidM000000000000000000mm"].Name)
    end)

    it("reports a name it does not hold, so the bridge retries later", function()
      firstRun({})
      assert.is_false(GSE.SetStoredPlatformID("sequence", "Nobody", "pidN000000000000000000nn"))
      assert.is_false(GSE.SetStoredPlatformID("variable", "Nobody", "pidN000000000000000000nn"))
      assert.is_false(GSE.SetStoredPlatformID("macro", "Nobody", "pidN000000000000000000nn"))
    end)

    it("does not let a recreated old SavedVariable be written beside the store", function()
      firstRun({})
      _G.GSESequences = { [1] = {} }
      GSE.ReconcileStore()
      assert.is_nil(_G.GSESequences)
    end)
  end)

  -- Collection provenance (#2111 phase 3): the collections an element came
  -- through, on its envelope -- recorded when an import's expectation is
  -- settled by the store, kept across a reload, sealed or not.
  describe("collection provenance", function()
    local clock
    before_each(function()
      clock = 1000
      _G.GetServerTime = function() return clock end
      _G.InCombatLockdown = _G.InCombatLockdown or function() return false end
      GSE.SendMessage = GSE.SendMessage or function() end
    end)
    after_each(function() _G.GetServerTime = nil end)

    it("records a sequence's collection when the import stores it, and keeps it", function()
      firstRun({ GSESequences = { [2] = { Alpha = "SEQ|Alpha|Tim|" } } })
      local id = GSE.FindSequenceId("Alpha", 2)
      GSE.ExpectCollection("sequence", "Alpha", "pidC000000000000000000cc", "Warrior Pack")
      GSE.PutSequenceBody(2, id, "Alpha", "SEQ|Alpha|Tim|")
      assert.are.same({ pidC000000000000000000cc = "Warrior Pack" }, GSE.ElementCollections("sequence", id, 2))
      reload()
      assert.are.same({ pidC000000000000000000cc = "Warrior Pack" },
        GSE.ElementCollections("sequence", GSE.FindSequenceId("Alpha", 2), 2))
    end)

    it("records a pasted collection by name, and replaces it with the site id later", function()
      firstRun({ GSEVariables = { V = "VAR||x" } })
      GSE.ExpectCollection("variable", "V", nil, "Pasted Pack")
      assert.is_true(GSE.StoreEncodedVariable("V", "VAR||y"))
      assert.are.same({ ["name:Pasted Pack"] = "Pasted Pack" }, GSE.ElementCollections("variable", "V"))
      GSE.AddElementCollection("variable", "V", "pidP000000000000000000pp", "Pasted Pack")
      assert.are.same({ pidP000000000000000000pp = "Pasted Pack" }, GSE.ElementCollections("variable", "V"))
      reload()
      local env = envs("variable", 0)[onlyId(envs("variable", 0))]
      assert.are.same({ pidP000000000000000000pp = "Pasted Pack" }, env.Collections, "on the envelope")
    end)

    it("records a macro's collections and lets one be forgotten", function()
      firstRun({ GSEMacros = { Pull = { text = "/cast Charge", value = 3 } } })
      assert.is_true(GSE.AddElementCollection("macro", "Pull", "pidA000000000000000000aa", "A"))
      assert.is_true(GSE.AddElementCollection("macro", "Pull", "pidB000000000000000000bb", "B"))
      reload()
      assert.are.same({ pidA000000000000000000aa = "A", pidB000000000000000000bb = "B" },
        GSE.ElementCollections("macro", "Pull"))
      GSE.RemoveElementCollection("macro", "Pull", "pidA000000000000000000aa")
      GSE.RemoveElementCollection("macro", "Pull", "pidB000000000000000000bb")
      reload()
      assert.is_nil(GSE.ElementCollections("macro", "Pull"))
      assert.is_nil(envs("macro", 0)[onlyId(envs("macro", 0))].Collections, "no empty field left behind")
    end)

    it("lets an expectation lapse -- a member the user declined takes nothing", function()
      firstRun({ GSEVariables = { V = "VAR||x" } })
      GSE.ExpectCollection("variable", "V", "pidC000000000000000000cc", "Pack")
      clock = clock + 3600
      GSE.StoreEncodedVariable("V", "VAR||y")
      assert.is_nil(GSE.ElementCollections("variable", "V"))
    end)

    it("records nothing on an element that is not stored", function()
      firstRun({})
      assert.is_false(GSE.AddElementCollection("variable", "Nope", "pidC000000000000000000cc", "Pack"))
      assert.is_nil(GSE.ElementCollections("variable", "Nope"))
    end)

    it("removes what came only through a collection, and keeps what another brought", function()
      firstRun({ GSESequences = { [2] = { Alpha = "SEQ|Alpha|Tim|", Beta = "SEQ|Beta|Tim|" } },
                 GSEVariables = { V = "VAR||x" } })
      GSE.Library = GSE.Library or {}
      local alpha, beta = GSE.FindSequenceId("Alpha", 2), GSE.FindSequenceId("Beta", 2)
      GSE.AddElementCollection("sequence", alpha, "pidC000000000000000000cc", "Pack", 2)
      GSE.AddElementCollection("sequence", beta, "pidC000000000000000000cc", "Pack", 2)
      GSE.AddElementCollection("sequence", beta, "pidD000000000000000000dd", "Other", 2)
      GSE.AddElementCollection("variable", "V", "pidC000000000000000000cc", "Pack")
      local deleted, kept = GSE.RemoveCollection("pidC000000000000000000cc", true)
      assert.are.equal(2, deleted, "Alpha and V came only through Pack")
      assert.are.equal(1, kept)
      assert.is_nil(GSE.FindSequenceId("Alpha", 2))
      assert.is_nil(GSE.Store("variable").V)
      assert.are.same({ pidD000000000000000000dd = "Other" }, GSE.ElementCollections("sequence", beta, 2),
        "Beta stays, and only forgets Pack")
      assert.is_nil(GSE.KnownCollections()["pidC000000000000000000cc"])
    end)

    it("forgets a collection without deleting anything", function()
      firstRun({ GSEVariables = { V = "VAR||x" } })
      GSE.AddElementCollection("variable", "V", "pidC000000000000000000cc", "Pack")
      GSE.RemoveCollection("pidC000000000000000000cc", false)
      assert.is_not_nil(GSE.Store("variable").V)
      assert.is_nil(GSE.ElementCollections("variable", "V"))
    end)

    it("lists what each collection brought", function()
      firstRun({ GSESequences = { [2] = { Alpha = "SEQ|Alpha|Tim|" } }, GSEVariables = { V = "VAR||x" } })
      local id = GSE.FindSequenceId("Alpha", 2)
      GSE.AddElementCollection("sequence", id, "pidC000000000000000000cc", "Pack", 2)
      GSE.AddElementCollection("variable", "V", "pidC000000000000000000cc", "Pack")
      local known = GSE.KnownCollections()["pidC000000000000000000cc"]
      assert.are.equal("Pack", known.name)
      assert.are.equal(2, known.sequence[id])
      assert.is_true(known.variable.V)
    end)
  end)
end)
