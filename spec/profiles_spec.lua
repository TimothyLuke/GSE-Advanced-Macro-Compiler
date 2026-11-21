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
    it("is per class on a client without specialisations, as its one spec group", function()
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = nil
      loginAs({ ["1"] = { ["CTRL-1"] = "seqA" } })
      GSE.MigrateToProfiles()
      assert.are.same({ ["CTRL-1"] = "seqA" }, GSEStore.profile[2][1].KeyBindings)
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
      -- A profile is kept by its spec group: 1 Primary, 2 Secondary.
      assert.are.equal(1, GSE.SpecIDForKey("1"))
      assert.are.equal(2, GSE.SpecIDForKey("2"))
    end)

    it("WoW Forever: Primary is 1 and Secondary 2, without asking the spec API", function()
      dualSpec(1, 1)
      _G.GetNumSpecializations = nil
      C_SpecializationInfo.GetSpecializationInfo = nil
      GSE.IsForever = true
      local ok, err = pcall(function()
        assert.are.equal(1, GSE.SpecIDForKey("1"))
        assert.are.equal(2, GSE.SpecIDForKey("2"))
        assert.are.equal("table", type(GSE.Profile("1", true)), "a profile from the first login pass, not nil")
        assert.are.equal(GSEStore.profile[2][1], GSE.Profile("1"))
      end)
      GSE.IsForever = nil
      if not ok then error(err, 0) end
    end)

    -- #2225: a spec-group client's profiles are kept by the group -- 1 Primary,
    -- 2 Secondary. They were kept by the class (2, "2:2"), and on WoW Forever
    -- until 3.3.39 by the class-level specialisation (1486, "1486:2"), which
    -- that update stopped reading: every bind saved before it was lost.
    describe("profiles onto their spec groups, once (#2225)", function()
      local function onForever(fn)
        dualSpec(1, 1)
        -- Early in a login: the spec API answers nothing.
        C_SpecializationInfo.GetSpecializationInfo = function() return nil end
        GSE.IsForever = true
        local ok, err = pcall(fn)
        GSE.IsForever = nil
        if not ok then error(err, 0) end
      end
      local function saved(key, sequence)
        return { KeyBindings = { [key] = sequence },
          ActionBarBinds = { B1 = { Bind = "B1", Sequence = sequence } }, Settings = { msClickRate = 100 } }
      end

      it("Forever: what 3.3.38 saved is read again, Primary and Secondary", function()
        onForever(function()
          GSEStore.profile = { [9] = { [1490] = saved("F", "seqA"), ["1490:2"] = saved("G", "seqB") } }
          _G.UnitClass = function() return "Warlock", "WARLOCK", 9 end
          assert.is_true(GSE.MoveProfilesToSpecGroups())
          assert.are.same({ F = "seqA" }, GSE.SpecKeyBinds("1"))
          assert.are.equal("seqA", GSE.SpecOverrides("1").B1.Sequence)
          assert.are.equal(100, GSEStore.profile[9][1].Settings.msClickRate)
          assert.are.same({ G = "seqB" }, GSE.SpecKeyBinds("2"))
          local keys = {}
          for k in pairs(GSEStore.profile[9]) do keys[#keys + 1] = tostring(k) end
          table.sort(keys)
          assert.are.same({ "1", "2" }, keys)
        end)
      end)

      it("Forever: what was set up again on 3.3.39 stays, the older fills in the rest", function()
        onForever(function()
          GSEStore.profile = { [9] = {
            [1490] = { KeyBindings = { F = "seqA", G = "seqOld" }, ActionBarBinds = { B1 = { Bind = "B1", Sequence = "seqA" } } },
            [9] = { KeyBindings = { G = "seqNew" }, Settings = { msClickRate = 80 } },
          } }
          GSE.MoveProfilesToSpecGroups()
          local p = GSEStore.profile[9][1]
          assert.are.same({ F = "seqA", G = "seqNew" }, p.KeyBindings)
          assert.are.equal("seqA", p.ActionBarBinds.B1.Sequence)
          assert.are.equal(80, p.Settings.msClickRate)
          assert.is_nil(GSEStore.profile[9][1490])
          assert.is_nil(GSEStore.profile[9][9])
        end)
      end)

      -- Reading a table setting on 3.3.39 copied the account's into the
      -- class's profile. That copy is nobody's choice; the one under the id
      -- 3.3.38 saved by is.
      it("Forever: a table setting chosen on 3.3.38 beats the account's copy 3.3.39 made", function()
        onForever(function()
          GSEOptions.SkyRidingBinds = {}
          GSE.InstallProfileSettings()
          GSEStore.profile = { [9] = {
            [1490] = { Settings = { MacroResetModifiers = { LeftShift = true }, SkyRidingBinds = { X = "old" } } },
            [9] = { Settings = { MacroResetModifiers = { LeftShift = false }, SkyRidingBinds = { X = "edited" } } },
          } }
          GSE.MoveProfilesToSpecGroups()
          local s = GSEStore.profile[9][1].Settings
          assert.is_true(s.MacroResetModifiers.LeftShift, "the one chosen on 3.3.38")
          assert.are.equal("edited", s.SkyRidingBinds.X, "one changed since 3.3.39 is kept")
        end)
      end)

      it("every class in the one pass, whoever logs in", function()
        onForever(function()
          GSEStore.profile = { [9] = { [1490] = saved("F", "seqA") }, [8] = { [1482] = saved("H", "seqM") },
            [11] = { [11] = saved("J", "seqD"), ["11:2"] = saved("K", "seqE") } }
          GSE.MoveProfilesToSpecGroups()
          assert.are.same({ F = "seqA" }, GSEStore.profile[9][1].KeyBindings)
          assert.are.same({ H = "seqM" }, GSEStore.profile[8][1].KeyBindings)
          assert.are.same({ J = "seqD" }, GSEStore.profile[11][1].KeyBindings)
          assert.are.same({ K = "seqE" }, GSEStore.profile[11][2].KeyBindings)
          assert.is_nil(GSEStore.profile[11][11])
          assert.is_nil(GSEStore.profile[11]["11:2"])
        end)
      end)

      -- Classes 1 and 2 are kept by a number that is also a spec group.
      it("a Warrior's Primary stays at 1, and a Paladin's leaves 2 for its Secondary", function()
        dualSpec(3, 1)
        GSEStore.profile = {
          [1] = { [1] = saved("F", "warPrimary"), ["1:2"] = saved("G", "warSecondary") },
          [2] = { [2] = saved("H", "palPrimary"), ["2:2"] = saved("J", "palSecondary") },
        }
        assert.is_true(GSE.MoveProfilesToSpecGroups())
        assert.are.same({ F = "warPrimary" }, GSEStore.profile[1][1].KeyBindings)
        assert.are.same({ G = "warSecondary" }, GSEStore.profile[1][2].KeyBindings)
        assert.are.same({ H = "palPrimary" }, GSEStore.profile[2][1].KeyBindings)
        assert.are.same({ J = "palSecondary" }, GSEStore.profile[2][2].KeyBindings)
        assert.is_nil(GSEStore.profile[1]["1:2"])
        assert.is_nil(GSEStore.profile[2]["2:2"])
      end)

      it("a Paladin with no Secondary saved leaves 2 empty", function()
        dualSpec(3, 1)
        GSEStore.profile = { [2] = { [2] = saved("H", "palPrimary") } }
        GSE.MoveProfilesToSpecGroups()
        assert.are.same({ H = "palPrimary" }, GSEStore.profile[2][1].KeyBindings)
        assert.is_nil(GSEStore.profile[2][2])
      end)

      it("Forever, two old ids for a class: the one the client names, the other left", function()
        onForever(function()
          GSEStore.profile = { [9] = { [1490] = saved("F", "seqA"), [70] = saved("H", "seqR") } }
          C_SpecializationInfo.GetSpecializationInfoForClassID = function(classID) return classID == 9 and 1490 or nil end
          GSE.MoveProfilesToSpecGroups()
          C_SpecializationInfo.GetSpecializationInfoForClassID = nil
          assert.are.same({ F = "seqA" }, GSEStore.profile[9][1].KeyBindings)
          assert.are.same({ H = "seqR" }, GSEStore.profile[9][70].KeyBindings)
        end)
      end)

      it("only Forever has an old id: another client's other numbers are left", function()
        dualSpec(3, 1)
        GSEStore.profile = { [9] = { [9] = saved("F", "seqA"), [1490] = saved("H", "seqX") } }
        GSE.MoveProfilesToSpecGroups()
        assert.are.same({ F = "seqA" }, GSEStore.profile[9][1].KeyBindings)
        assert.are.same({ H = "seqX" }, GSEStore.profile[9][1490].KeyBindings)
      end)

      it("Retail keeps its profiles by specialisation: nothing moves", function()
        GSEStore.profile = { [2] = { [70] = saved("F", "seqA") } }
        assert.is_false(GSE.MoveProfilesToSpecGroups())
        assert.are.same({ F = "seqA" }, GSEStore.profile[2][70].KeyBindings)
      end)

      -- OneOffEvents.lua cannot be loaded here, so this reads the gate out of
      -- it: one flag for the account, set whether or not anything moved, as a
      -- second run would take a Paladin's Secondary for its Primary.
      it("is run once for the account, not once a character", function()
        local fh = assert(io.open("GSE/API/OneOffEvents.lua", "r"))
        local src = fh:read("*a"):gsub("\r\n", "\n")
        fh:close()
        assert.truthy(src:find('    if GSE.isEmpty(GSEOptions.Updates["profileSpecGroups"]) then\n'
          .. '        GSE.MoveProfilesToSpecGroups()\n'
          .. '        GSEOptions.Updates["profileSpecGroups"] = true\n', 1, true))
        assert.is_nil(src:find("GSE_C.Updates.profileSpecGroups", 1, true))
      end)
    end)

    it("spec API answering nothing early in a login: Primary, not no profile", function()
      dualSpec(1, 1)
      C_SpecializationInfo.GetSpecializationInfo = function() return nil end
      assert.are.equal(1, GSE.SpecIDForKey("1"))
    end)

    it("Cata to WoD (MoP): spec groups too, though it has three specialisations", function()
      dualSpec(3, 1)
      assert.are.equal("1", GSE.CurrentSpecKey())
      assert.are.equal(2, #GSE.BindingSpecs())
      assert.are.equal(1, GSE.SpecIDForKey("1"), "the spec group, not a specialisation")
      assert.are.equal(2, GSE.SpecIDForKey("2"))
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
        assert.are.equal(1, GSE.SpecIDForKey("1"))
        assert.are.equal(2, GSE.SpecIDForKey("2"))
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
      assert.are.equal(1, GSE.SpecIDForKey("1"))
    end)

    it("MoP with three specialisations and one group: still Primary, not the specialisation", function()
      dualSpec(3, 1, 1)
      assert.are.equal("1", GSE.CurrentSpecKey(), "not \"3\" -- learning dual spec must not move the binds")
      assert.are.equal(1, #GSE.BindingSpecs())
      assert.are.equal(1, GSE.SpecIDForKey("1"))
    end)

    it("a client with one spec group and no specialisations: one", function()
      _G.GetNumSpecializations = nil
      _G.C_SpecializationInfo = nil
      assert.are.equal("1", GSE.CurrentSpecKey())
      assert.are.equal(1, #GSE.BindingSpecs())
      assert.are.equal(1, GSE.SpecIDForKey("1"))
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

    -- The right-click menu's Loadout > State > sequence.
    it("a named loadout takes the row, and the active one's and the spec's stay", function()
      withLoadout("111", function()
        GSE.SetOverrideData("ActionButton1", "seqA", "spec")
        GSE.SetOverrideData("ActionButton1", "seqL", "loadout")
        assert.are.equal("loadout", GSE.SetOverrideData("ActionButton1", "seqO", "loadout", "7", 222))
        assert.are.same(inState("7", "seqO"), GSE.SpecLoadoutOverrides("3", "222")["ActionButton1-7"])
        assert.are.same(onButton("seqL"), GSE.SpecLoadoutOverrides("3", "111").ActionButton1)
        assert.are.same(onButton("seqA"), GSE.SpecOverrides("3").ActionButton1)
      end)
    end)

    it("a named loadout is the spec's on a client without loadouts", function()
      C_SpecializationInfo.SetActiveSpecGroup = function() end
      assert.are.equal("spec", GSE.SetOverrideData("ActionButton1", "seqA", "loadout", nil, 222))
    end)

    it("lists the spec's saved loadouts by name, in WoW's order", function()
      withLoadout("111", function()
        C_ClassTalents.GetConfigIDsBySpecID = function(specID) return specID == 70 and { 222, 111 } or {} end
        _G.C_Traits = { GetConfigInfo = function(id) return id == 111 and { name = "Raid" } or nil end }
        local ok, err = pcall(function()
          assert.are.same({ { id = "222", name = "222" }, { id = "111", name = "Raid" } }, GSE.BindingLoadouts())
        end)
        _G.C_Traits = nil
        if not ok then error(err, 0) end
      end)
      assert.are.same({}, GSE.BindingLoadouts())
    end)

    it("a button's states: Default and its form pages, or none at all", function()
      local saved = GSE.ButtonPagesWithForms
      _G.ActionButton1 = { SetShowGridInsecure = function() end }
      _G.GSEButton1 = {}
      GSE.ButtonPagesWithForms = function(name) return name == "ActionButton1" end
      local ok, err = pcall(function()
        local states, order = GSE.OverrideStatesFor("ActionButton1")
        assert.are.same({ "Default", "7", "8", "9", "10" }, order)
        assert.are.equal("Default", states.Default)
        assert.is_nil(GSE.OverrideStatesFor("GSEButton1"))
      end)
      GSE.ButtonPagesWithForms = saved
      _G.ActionButton1, _G.GSEButton1 = nil, nil
      if not ok then error(err, 0) end
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
