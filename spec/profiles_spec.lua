---@diagnostic disable: undefined-global
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

    it("is per class before WoD, with the class for a spec", function()
      GSE.GameMode = 5
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

  -- WoW Forever (#2109): keybinding is a switch, off unless turned on; a
  -- character that already binds keys turns it on.
  describe("keybinding on WoW Forever", function()
    local toc
    before_each(function()
      toc = 16001
      _G.GetBuildInfo = function() return "1.60.1", "69893", "", toc end
      GSE.TOCFlavour = function(t) return t == 16001 and "forever" or "exp12" end
      require("../GSE/API/OneOffEvents")
      -- Every earlier one-off already done, so only this one runs.
      GSEOptions.Updates = { ["3200"] = true, ["3304"] = true, ["3310"] = true,
        actionBarOverridePopupDefault = true, MacroResetModifiers = true, modifierPause = true, showMiniMap = true }
    end)

    local function loginAs(binds)
      _G.GSE_C = { KeyBindings = binds or {}, ActionBarBinds = {},
        Updates = { ["3201"] = true, ["3202"] = true, ["3212"] = true, ["3218"] = true } }
    end

    it("is always on elsewhere", function()
      toc = 120001
      assert.is_true(GSE.KeybindingsEnabled())
    end)

    it("is off on Forever until turned on", function()
      assert.is_false(GSE.KeybindingsEnabled())
      GSEOptions.ForeverKeybindings = true
      assert.is_true(GSE.KeybindingsEnabled())
    end)

    it("is turned on for a character that already binds keys", function()
      loginAs({ ["1"] = { ["CTRL-1"] = "seqA" } })
      GSE.PerformOneOffEvents()
      assert.is_true(GSE.KeybindingsEnabled())
      assert.is_true(GSE_C.Updates.foreverKeybinds)
    end)

    it("stays off for a character with none, and never turns it off", function()
      loginAs({})
      GSE.PerformOneOffEvents()
      assert.is_false(GSE.KeybindingsEnabled())
      GSEOptions.ForeverKeybindings = true
      loginAs({})
      GSE.PerformOneOffEvents()
      assert.is_true(GSE.KeybindingsEnabled(), "another character's binds keep it on")
    end)
  end)
end)
