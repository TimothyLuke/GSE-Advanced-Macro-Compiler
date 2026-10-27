-- Profiles (#2111 phase 4): a class's spec setup -- keybinds, action-bar
-- overrides, settings -- shared by every character of that class, with a
-- character able to opt out of it for a spec and keep its own.
--
-- Run: busted spec/profiles_spec.lua   /   lua5.1 spec/run51.lua
describe("Profiles", function()
  local SPECS = { [1] = 65, [2] = 66, [3] = 70 }   -- Paladin: Holy, Protection, Retribution
  local currentSpec

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/Profiles")
  end)

  before_each(function()
    GSE.GameMode = 12
    currentSpec = 3
    _G.UnitClass = function() return "Paladin", "PALADIN", 2 end
    _G.UnitGUID = nil
    _G.GetSpecialization = function() return currentSpec end
    _G.GetNumSpecializations = function() return #SPECS end
    _G.C_SpecializationInfo = {
      GetSpecialization = function() return currentSpec end,
      GetSpecializationInfo = function(i) return SPECS[i] end,
    }
    _G.GSEStore = nil
    GSE.LoadStore()
    _G.GSE_C = { Updates = {} }
    _G.GSEOptions = { msClickRate = 250, ShiftPause = false, MacroResetModifiers = { LeftShift = false } }
    setmetatable(GSEOptions, nil)
  end)

  local function loginAs(binds, overrides)
    _G.GSE_C = { Updates = {}, KeyBindings = binds or {}, ActionBarBinds = { Specialisations = overrides or {} } }
  end

  describe("migration", function()
    it("the first character seeds the profile and uses it", function()
      loginAs({ ["3"] = { ["CTRL-1"] = "seqA", LoadOuts = { ["111"] = { ["F"] = "seqL" } } } },
              { ["3"] = { ActionButton1 = { Bind = "ActionButton1", Sequence = "seqA" } } })
      assert.is_true(GSE.MigrateToProfiles())
      local p = GSEStore.profile[2][70]
      assert.are.same({ ["CTRL-1"] = "seqA" }, p.KeyBindings)
      assert.are.equal("seqA", p.ActionBarBinds.ActionButton1.Sequence)
      assert.is_true(GSE.UsesSharedProfile("3"))
      assert.is_nil(GSE_C.KeyBindings["3"]["CTRL-1"], "no own copy left")
      assert.are.same({ ["F"] = "seqL" }, GSE_C.KeyBindings["3"].LoadOuts["111"], "loadouts stay on the character")
      assert.are.same({ ["CTRL-1"] = "seqA" }, GSE.SpecKeyBinds("3"))
    end)

    it("a character with the same binds just uses the profile", function()
      GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["CTRL-1"] = "seqA" }, ActionBarBinds = {} } } }
      loginAs({ ["3"] = { ["CTRL-1"] = "seqA" } })
      GSE.MigrateToProfiles()
      assert.is_true(GSE.UsesSharedProfile("3"))
      assert.is_nil(GSE_C.KeyBindings["3"]["CTRL-1"])
    end)

    it("a character with different binds keeps them, opted out -- nothing is lost", function()
      GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["CTRL-1"] = "seqA" }, ActionBarBinds = {} } } }
      loginAs({ ["3"] = { ["CTRL-1"] = "seqB" } })
      GSE.MigrateToProfiles()
      assert.is_false(GSE.UsesSharedProfile("3"))
      assert.are.equal("seqB", GSE.SpecKeyBinds("3")["CTRL-1"])
      assert.are.equal("seqA", GSEStore.profile[2][70].KeyBindings["CTRL-1"], "the profile is untouched")
    end)

    it("runs once, and waits while WoW cannot place a spec", function()
      loginAs({ ["3"] = { ["CTRL-1"] = "seqA" } })
      _G.C_SpecializationInfo.GetSpecializationInfo = function() return nil end
      assert.is_false(GSE.MigrateToProfiles(), "spec unknown yet")
      assert.is_nil(GSE_C.Updates.profiles)
      _G.C_SpecializationInfo.GetSpecializationInfo = function(i) return SPECS[i] end
      assert.is_true(GSE.MigrateToProfiles())
      GSE_C.KeyBindings["3"]["CTRL-9"] = "seqZ"
      GSE.MigrateToProfiles()
      assert.is_nil(GSEStore.profile[2][70].KeyBindings["CTRL-9"], "never again")
    end)

    -- Decided by what the client can do (Profiles.lua), not its version.
    it("is per class on a client without specialisations, with the class for a spec", function()
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = nil
      loginAs({ ["1"] = { ["CTRL-1"] = "seqA" } })
      GSE.MigrateToProfiles()
      assert.are.same({ ["CTRL-1"] = "seqA" }, GSEStore.profile[2][2].KeyBindings)
    end)
  end)

  describe("opting in and out", function()
    it("leaving copies the profile; rejoining drops the character's own", function()
      GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["CTRL-1"] = "seqA" },
        ActionBarBinds = { B1 = { Bind = "B1", Sequence = "seqA" } } } } }
      loginAs({})
      GSE.SetSharedProfile("3", false)
      assert.is_false(GSE.UsesSharedProfile("3"))
      GSE.SpecKeyBinds("3", true)["CTRL-2"] = "seqC"
      GSE.SpecOverrides("3", true).B1.Sequence = "seqC"
      assert.is_nil(GSEStore.profile[2][70].KeyBindings["CTRL-2"], "edits stay the character's")
      assert.are.equal("seqA", GSEStore.profile[2][70].ActionBarBinds.B1.Sequence)
      GSE.SetSharedProfile("3", true)
      assert.is_true(GSE.UsesSharedProfile("3"))
      assert.are.same({ ["CTRL-1"] = "seqA" }, GSE.SpecKeyBinds("3"))
      assert.is_nil(GSE_C.ActionBarBinds.Specialisations["3"])
    end)
  end)

  describe("settings", function()
    it("come from the current spec's profile, else the account", function()
      GSE.InstallProfileSettings()
      assert.is_nil(rawget(GSEOptions, "msClickRate"), "moved out of the raw table")
      assert.are.equal(250, GSEOptions.msClickRate, "the account-wide value until a profile says otherwise")
      GSEOptions.msClickRate = 100
      assert.are.equal(100, GSEOptions.msClickRate)
      assert.are.equal(100, GSEStore.profile[2][70].Settings.msClickRate, "written to Retribution's profile")
      currentSpec = 2
      assert.are.equal(250, GSEOptions.msClickRate, "Protection still has the account-wide value")
      assert.are.equal(250, GSEOptions.ProfileDefaults.msClickRate)
    end)

    it("copies a table setting into the profile before it can be edited", function()
      GSE.InstallProfileSettings()
      GSEOptions.MacroResetModifiers.LeftShift = true
      assert.is_true(GSEOptions.MacroResetModifiers.LeftShift)
      assert.is_false(GSEOptions.ProfileDefaults.MacroResetModifiers.LeftShift, "the account-wide one is untouched")
      currentSpec = 1
      assert.is_false(GSEOptions.MacroResetModifiers.LeftShift, "another spec starts from the account-wide one")
    end)

    it("leaves every other option where it was", function()
      GSEOptions.DebugModules = { x = true }
      GSE.InstallProfileSettings()
      assert.is_true(rawget(GSEOptions, "DebugModules").x)
      GSEOptions.showMiniMap = true
      assert.is_true(rawget(GSEOptions, "showMiniMap"))
    end)
  end)

  it("follows a sequence that moved", function()
    GSEStore.alias = { ["local-1"] = "pidA00000000000000000000" }
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["CTRL-1"] = "local-1" },
      ActionBarBinds = { B1 = { Bind = "B1", Sequence = "local-1" } } } } }
    GSE.UpdateProfileSequenceRefs()
    assert.are.equal("pidA00000000000000000000", GSEStore.profile[2][70].KeyBindings["CTRL-1"])
    assert.are.equal("pidA00000000000000000000", GSEStore.profile[2][70].ActionBarBinds.B1.Sequence)
  end)
  -- What the binds are split by, from what the client can do, never its
  -- version: dual spec gives Primary and Secondary (which the player knows the
  -- meaning of), else Retail's specialisations, else one.
  describe("specs the binds are kept by", function()
    local function dualSpec(specs, active, groups)
      _G.GetNumSpecializations = function() return specs end
      C_SpecializationInfo.SetActiveSpecGroup = function() end
      C_SpecializationInfo.GetNumSpecGroups = function() return groups or 2 end
      C_SpecializationInfo.GetActiveSpecGroup = function() return active end
      C_SpecializationInfo.GetSpecializationInfo = function() return 1486 end
    end

    it("Retail: the specialisation index", function()
      -- Retail still answers the spec-group getters; it has no setter.
      C_SpecializationInfo.GetNumSpecGroups = function() return 1 end
      C_SpecializationInfo.GetActiveSpecGroup = function() return 1 end
      assert.are.equal("3", GSE.CurrentSpecKey())
      local specs = GSE.BindingSpecs()
      assert.are.equal(3, #specs)
      assert.are.equal(70, GSE.SpecIDForKey("3"))
    end)

    it("Forever: the active spec group, as Primary and Secondary", function()
      dualSpec(1, 2)
      assert.are.equal("2", GSE.CurrentSpecKey())
      local specs = GSE.BindingSpecs()
      assert.are.equal(2, #specs)
      assert.are.equal("1", specs[1].key)
      assert.are.equal("Primary", specs[1].label)
      assert.are.equal("Secondary", specs[2].label)
      -- Primary keeps the profile the class always had; Secondary its own.
      assert.are.equal(1486, GSE.SpecIDForKey("1"))
      assert.are.equal("1486:2", GSE.SpecIDForKey("2"))
    end)

    it("Cata to WoD (MoP): spec groups too, though it has three specialisations", function()
      dualSpec(3, 1)
      assert.are.equal("1", GSE.CurrentSpecKey())
      assert.are.equal(2, #GSE.BindingSpecs())
      assert.are.equal(2, GSE.SpecIDForKey("1"), "the class, as before WoD")
      assert.are.equal("2:2", GSE.SpecIDForKey("2"))
    end)

    it("TBC / Wrath / Era with dual spec: talent groups, no specialisations", function()
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = nil
      _G.SetActiveTalentGroup = function() end
      _G.GetNumTalentGroups = function() return 2 end
      _G.GetActiveTalentGroup = function() return 2 end
      local ok, err = pcall(function()
        assert.are.equal("2", GSE.CurrentSpecKey())
        assert.are.equal(2, #GSE.BindingSpecs())
        assert.are.equal(2, GSE.SpecIDForKey("1"), "the class, as it always was")
        assert.are.equal("2:2", GSE.SpecIDForKey("2"))
      end)
      _G.SetActiveTalentGroup, _G.GetNumTalentGroups, _G.GetActiveTalentGroup = nil, nil, nil
      if not ok then error(err, 0) end
    end)

    it("Era: a function the client carries but does not support is skipped", function()
      -- Classic Era has SetActiveSpecGroup and the global GetNumSpecGroups,
      -- but the latter raises "API unsupported"; GetNumTalentGroups answers.
      local function unsupported() error("Script_GetNumSpecGroups: API unsupported in this version of World of Warcraft") end
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = {
        SetActiveSpecGroup = function() end,
        GetActiveSpecGroup = function() return 1 end,
        GetSpecializationInfo = function() return 0 end,
        GetSpecialization = unsupported,
      }
      _G.GetNumSpecGroups, _G.GetSpecialization = unsupported, unsupported
      _G.GetNumTalentGroups = function() return 1 end
      local ok, err = pcall(function()
        assert.are.equal("1", GSE.CurrentSpecKey())
        local specs = GSE.BindingSpecs()
        assert.are.equal(1, #specs)
        assert.are.equal("Primary", specs[1].label)
      end)
      _G.GetNumSpecGroups, _G.GetNumTalentGroups = nil, nil
      if not ok then error(err, 0) end
    end)

    it("dual spec not learned yet: Primary alone, on the key it keeps after", function()
      dualSpec(1, 1, 1)
      assert.are.equal("1", GSE.CurrentSpecKey())
      local specs = GSE.BindingSpecs()
      assert.are.equal(1, #specs)
      assert.are.equal("Primary", specs[1].label)
      assert.are.equal(1486, GSE.SpecIDForKey("1"))
    end)

    it("MoP with three specialisations and one group: still Primary, not the specialisation", function()
      dualSpec(3, 1, 1)
      assert.are.equal("1", GSE.CurrentSpecKey(), "not \"3\" -- learning dual spec must not move the binds")
      assert.are.equal(1, #GSE.BindingSpecs())
      assert.are.equal(2, GSE.SpecIDForKey("1"))
    end)

    it("a client with one spec group and no specialisations: one", function()
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = nil
      assert.are.equal("1", GSE.CurrentSpecKey())
      assert.are.equal(1, #GSE.BindingSpecs())
      assert.are.equal(2, GSE.SpecIDForKey("1"))
    end)

    it("Primary and Secondary keep separate binds; Secondary starts empty", function()
      loginAs({ ["1"] = { ["CTRL-1"] = "seqA" } }, {})
      dualSpec(1, 1)
      GSE.MigrateToProfiles()
      assert.are.same({ ["CTRL-1"] = "seqA" }, GSE.SpecKeyBinds("1"))
      assert.is_nil(next(GSE.SpecKeyBinds("2", true)), "Secondary has none until set")
      GSE.SpecKeyBinds("2", true)["CTRL-2"] = "seqB"
      assert.is_nil(GSE.SpecKeyBinds("1")["CTRL-2"], "Secondary's binds are its own")
    end)
  end)

  -- Where a right-click or a drop on an action button writes, and what Clear
  -- Override takes off: the spec's override holds for every talent loadout,
  -- the active loadout's sits on top.
  describe("action-bar override layers", function()
    -- Retail: talent loadouts, and no spec-group setter.
    local function withLoadout(key, fn)
      local saved = GSE.GetBindingLoadoutKey
      GSE.GetBindingLoadoutKey = function() return key end
      _G.C_ClassTalents = { GetLastSelectedSavedConfigID = function() end }
      local ok, err = pcall(fn)
      GSE.GetBindingLoadoutKey = saved
      _G.C_ClassTalents = nil
      if not ok then error(err, 0) end
    end

    it("a dual-spec client has no loadout layer, whatever C_ClassTalents it carries", function()
      C_SpecializationInfo.SetActiveSpecGroup = function() end
      withLoadout("111", function()
        assert.is_false(GSE.HasTalentLoadouts())
        assert.is_nil(GSE.ActiveBindingLoadout())
        assert.are.equal("spec", GSE.SetOverrideData("ActionButton1", "seqA", "loadout"))
      end)
    end)
    local function onButton(seq) return { Bind = "ActionButton1", Sequence = seq } end

    it("no saved loadout (\"nil\", every client but Retail): the spec's", function()
      withLoadout("nil", function()
        assert.is_nil(GSE.ActiveBindingLoadout())
        assert.are.equal("spec", GSE.SetOverrideData("ActionButton1", "seqA", "loadout"))
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1)
        assert.are.equal("spec", GSE.OverrideLayerFor("ActionButton1"))
      end)
    end)

    it("this loadout only leaves the spec's alone and wins over it", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqA", "spec")
        assert.are.equal("loadout", GSE.SetOverrideData("ActionButton1", "seqL", "loadout"))
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1)
        assert.are.same(onButton("seqL"), GSE.SpecLoadoutOverrides("3", "111").ActionButton1)
        assert.are.equal("loadout", GSE.OverrideLayerFor("ActionButton1"))
      end)
    end)

    it("all loadouts drops the active loadout's own, so the change shows", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqL", "loadout")
        GSE.SetOverrideData("ActionButton1", "seqB", "spec")
        assert.is_nil(GSE.SpecLoadoutOverrides("3", "111").ActionButton1)
        assert.are.same(onButton("seqB"), GSE.SpecOverrides("3").ActionButton1)
        assert.are.equal("spec", GSE.OverrideLayerFor("ActionButton1"))
      end)
    end)

    it("clear takes off the layer shown and no other", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqA", "spec")
        GSE.SetOverrideData("ActionButton1", "seqL", "loadout")
        GSE.SpecLoadoutOverrides("3", "222", true).ActionButton1 = onButton("seqM")
        assert.are.equal("loadout", GSE.ClearOverrideData("ActionButton1"))
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1, "the spec's shows again")
        assert.are.same(onButton("seqM"), GSE.SpecLoadoutOverrides("3", "222").ActionButton1, "another loadout's stays")
        assert.are.equal("spec", GSE.ClearOverrideData("ActionButton1"))
        assert.is_nil(GSE.SpecOverrides("3").ActionButton1)
        assert.are.same(onButton("seqM"), GSE.SpecLoadoutOverrides("3", "222").ActionButton1, "still there")
        assert.is_nil(GSE.ClearOverrideData("ActionButton1"), "nothing left to clear")
      end)
    end)

    -- A stance, form or stealth (a state) has a row of its own: put on the
    -- stealth bar, a sequence is on the stealth bar, and the Default row
    -- runs everywhere else.
    local function inState(state, seq) return { Bind = "ActionButton1", State = state, Sequence = seq } end

    it("puts a sequence on the state it is given, beside the Default row", function()
      withLoadout("nil", function()
        GSE.SetOverrideData("ActionButton1", "seqA", "spec")
        assert.are.equal("spec", GSE.SetOverrideData("ActionButton1", "seqS", "spec", "7"))
        assert.are.same(inState("7", "seqS"), GSE.SpecOverrides("3")["ActionButton1-7"])
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1, "the Default row stays")
      end)
    end)

    it("finds the row that runs in a state: its own, else the Default row", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqA", "loadout")
        GSE.SetOverrideData("ActionButton1", "seqS", "spec", "7")
        local layer, state = GSE.OverrideLayerFor("ActionButton1", "7")
        assert.are.equal("spec", layer, "a row for the state wins over a loadout's Default row")
        assert.are.equal("7", state)
        layer, state = GSE.OverrideLayerFor("ActionButton1", "9")
        assert.are.equal("loadout", layer)
        assert.is_nil(state, "no row for Bear: the Default row")
      end)
    end)

    it("all loadouts drops the active loadout's row for that state only", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqL", "loadout")
        GSE.SetOverrideData("ActionButton1", "seqL7", "loadout", "7")
        GSE.SetOverrideData("ActionButton1", "seqB7", "spec", "7")
        assert.is_nil(GSE.SpecLoadoutOverrides("3", "111")["ActionButton1-7"])
        assert.are.same(onButton("seqL"), GSE.SpecLoadoutOverrides("3", "111").ActionButton1)
      end)
    end)

    it("clear takes the row that runs in the state and leaves the others", function()
      withLoadout("nil", function()
        GSE.SpecOverrides("3", true).ActionButton1 = onButton("seqA")
        GSE.SpecOverrides("3")["ActionButton1-7"] = inState("7", "seqS")
        local layer, state = GSE.ClearOverrideData("ActionButton1", "7")
        assert.are.equal("spec", layer)
        assert.are.equal("7", state)
        assert.is_nil(GSE.SpecOverrides("3")["ActionButton1-7"])
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1, "the Default row stays")
        GSE.SpecOverrides("3")["ActionButton1-7"] = inState("7", "seqS")
        GSE.ClearOverrideData("ActionButton1")
        assert.is_nil(GSE.SpecOverrides("3").ActionButton1)
        assert.are.same(inState("7", "seqS"), GSE.SpecOverrides("3")["ActionButton1-7"], "the stealth row stays")
      end)
    end)

    it("clear in a state with no row of its own takes the Default row", function()
      withLoadout("nil", function()
        GSE.SpecOverrides("3", true).ActionButton1 = onButton("seqA")
        GSE.ClearOverrideData("ActionButton1", "9")
        assert.is_nil(GSE.SpecOverrides("3").ActionButton1)
      end)
    end)
  end)
end)
