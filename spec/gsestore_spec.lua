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

    it("hands the rest of the Mod the same shapes it has always used", function()
      firstRun({
        GSESequences = { [2] = { Alpha = SEQ_A } },
        GSEVariables = { V = "VARBODY" },
        GSEMacros = { Pull = { text = "/cast Charge", value = 3 } },
      })
      assert.equals(SEQ_A, GSE.Store("sequence")[2].Alpha)
      assert.equals("VARBODY", GSE.Store("variable").V)
      assert.equals("/cast Charge", GSE.Store("macro").Pull.text)
      assert.equals(3, GSE.Store("macro").Pull.value)
      for classid = 0, 13 do
        assert.equals("table", type(GSE.Store("sequence")[classid]), "class " .. classid .. " table")
      end
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
      GSE.Store("sequence")[2].Alpha = edited
      reload()
      assert.equals(edited, envs("sequence", 2)["pidA000000000000000000aa"].Body)
      assert.equals(edited, GSE.Store("sequence")[2].Alpha)
    end)

    it("stores a new sequence under a local id, then moves it to its PlatformID", function()
      firstRun({})
      GSE.Store("sequence")[3] = GSE.Store("sequence")[3] or {}
      GSE.Store("sequence")[3].Gamma = "SEQ|Gamma|Tim@Realm|"
      reload()
      local id = onlyId(envs("sequence", 3))
      assert.is_true(isLocal(id))
      -- The round trip to GSE.Tools comes back through the sidecar.
      GSE.Store("sequencePid")["Gamma|Tim@Realm"] = "newpid000000000000000001"
      reload()
      assert.is_nil(envs("sequence", 3)[id], "the local key is gone")
      assert.equals("Gamma", envs("sequence", 3)["newpid000000000000000001"].Name)
    end)

    it("drops a deleted sequence", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.Store("sequence")[2].Alpha = nil
      reload()
      assert.equals(0, count(envs("sequence", 2)))
    end)

    it("keeps the id across a rename (the editor moves the sidecar key)", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } },
                 GSEPlatformIDs = { ["Alpha|Tim@Realm"] = "pidA000000000000000000aa" } })
      local v = GSE.Store("sequence")[2]
      v.Omega, v.Alpha = "SEQ|Omega|Tim@Realm|", nil
      local pids = GSE.Store("sequencePid")
      pids["Omega|Tim@Realm"], pids["Alpha|Tim@Realm"] = pids["Alpha|Tim@Realm"], nil
      reload()
      local env = envs("sequence", 2)["pidA000000000000000000aa"]
      assert.is_not_nil(env, "same record on GSE.Tools, same key here")
      assert.equals("Omega", env.Name)
      assert.equals(1, count(envs("sequence", 2)), "not a copy plus a delete")
    end)

    it("keeps the id when a sequence moves to another class", function()
      firstRun({ GSESequences = { [2] = { Alpha = SEQ_A } } })
      GSE.Store("sequence")[2].Alpha = nil
      GSE.Store("sequence")[5].Alpha = SEQ_A
      reload()
      assert.equals(0, count(envs("sequence", 2)))
      assert.is_not_nil(envs("sequence", 5)["pidA000000000000000000aa"])
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
      GSE.Store("sequence")[3].Fresh = "SEQ|Fresh|Tim@Realm|"
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
end)
