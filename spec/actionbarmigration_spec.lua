---@diagnostic disable: undefined-global
-- The GSE Action Bar (GSE_Actionbar): a character's GSE keybinds move onto the
-- bar's buttons -- each key bound in WoW's Key Bindings to a button, and the
-- button given a Button Binding to the sequence the key ran, per spec and per
-- talent loadout.
--
-- Run: busted spec/actionbarmigration_spec.lua   /   lua5.1 spec/run51.lua
describe("GSE Action Bar keybind migration", function()
  local SPECS = { [1] = 65, [2] = 66, [3] = 70 }   -- Paladin: Holy, Protection, Retribution
  local bindings, saved, printed, inCombat
  local ns

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/Profiles")
    -- Strings read as their own keys, as enUS does.
    setmetatable(GSE.L, { __index = function(_, k) return k end })
    require("../GSE_Actionbar/Bootstrap")
    require("../GSE_Actionbar/Migration")
    -- The mock hands GSE itself to a submodule as its namespace.
    ns = GSE
  end)

  before_each(function()
    GSE.GameMode = 12
    _G.UnitClass = function() return "Paladin", "PALADIN", 2 end
    _G.UnitGUID = nil
    _G.GetSpecialization = function() return 3 end
    _G.GetNumSpecializations = function() return #SPECS end
    _G.C_SpecializationInfo = {
      GetSpecialization = function() return 3 end,
      GetSpecializationInfo = function(i) return SPECS[i] end,
    }
    _G.GSEStore = nil
    GSE.LoadStore()
    _G.GSEOptions = {}
    GSE.NormalizeBindKey = function(key) return (key:gsub("Button4", "BUTTON4")) end
    printed = {}
    GSE.Print = function(text) printed[#printed + 1] = text end
    inCombat = false
    _G.InCombatLockdown = function() return inCombat end
    -- WoW's binding table: key -> command.
    bindings, saved = {}, nil
    _G.GetBindingAction = function(key) return bindings[key] or "" end
    _G.GetBindingKey = function(command)
      local keys = {}
      for key, bound in pairs(bindings) do if bound == command then keys[#keys + 1] = key end end
      table.sort(keys)
      return keys[1], keys[2]
    end
    _G.SetBinding = function(key, command) bindings[key] = command; return true end
    _G.GetCurrentBindingSet = function() return 1 end
    _G.SaveBindings = function(set) saved = set end
  end)

  local function loginAs(binds)
    _G.GSE_C = { Updates = { profiles = true }, KeyBindings = binds or {}, ActionBarBinds = {} }
  end

  it("binds each key to a button and gives the button the key's sequence", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["F"] = "seqA", ["CTRL-1"] = "seqB" } } } }
    loginAs()
    assert.is_true(ns.MigrateKeybinds())
    -- Keys in order: CTRL-1 then F.
    assert.are.equal("CLICK GSEButton1:LeftButton", bindings["CTRL-1"])
    assert.are.equal("CLICK GSEButton2:LeftButton", bindings["F"])
    local overrides = GSEStore.profile[2][70].ActionBarBinds
    assert.are.same({ Bind = "GSEButton1", Sequence = "seqB" }, overrides.GSEButton1)
    assert.are.same({ Bind = "GSEButton2", Sequence = "seqA" }, overrides.GSEButton2)
    assert.are.equal(1, saved, "saved into the set WoW is using")
    assert.is_true(GSE_C.Updates.actionBarKeys)
  end)

  it("gives a key one button across specs, bound per spec to that spec's sequence", function()
    GSEStore.profile = { [2] = {
      [65] = { KeyBindings = { ["F"] = "seqHoly" } },
      [70] = { KeyBindings = { ["F"] = "seqRet" } },
    } }
    loginAs()
    ns.MigrateKeybinds()
    assert.are.equal("CLICK GSEButton1:LeftButton", bindings["F"])
    assert.are.equal("seqHoly", GSEStore.profile[2][65].ActionBarBinds.GSEButton1.Sequence)
    assert.are.equal("seqRet", GSEStore.profile[2][70].ActionBarBinds.GSEButton1.Sequence)
  end)

  it("puts a talent loadout's keys on the loadout's own Button Bindings", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["F"] = "seqA" } } } }
    loginAs({ ["3"] = { LoadOuts = { ["111"] = { ["G"] = "seqL", ["F"] = "seqF" } } } })
    ns.MigrateKeybinds()
    assert.are.equal("CLICK GSEButton1:LeftButton", bindings["F"])
    assert.are.equal("CLICK GSEButton2:LeftButton", bindings["G"])
    local loadout = GSE_C.ActionBarBinds.LoadOuts["3"]["111"]
    assert.are.equal("seqF", loadout.GSEButton1.Sequence)
    assert.are.equal("seqL", loadout.GSEButton2.Sequence)
    assert.is_nil(GSEStore.profile[2][70].ActionBarBinds.GSEButton2, "a loadout key is not the spec's")
  end)

  it("reuses the button a key already has, and the one another character gave it", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["F"] = "seqA", ["G"] = "seqB" } } } }
    bindings["G"] = "CLICK GSEButton7:LeftButton"
    GSEOptions.ActionBar = { KeyButtons = { F = 4 } }
    loginAs()
    ns.MigrateKeybinds()
    assert.are.equal("CLICK GSEButton4:LeftButton", bindings["F"])
    assert.are.equal("CLICK GSEButton7:LeftButton", bindings["G"])
    assert.are.equal(7, GSEOptions.ActionBar.KeyButtons.G)
  end)

  it("leaves a Button Binding set since alone, and the keybinds where they were", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["F"] = "seqA" },
      ActionBarBinds = { GSEButton1 = { Bind = "GSEButton1", Sequence = "seqMine" } } } } }
    loginAs()
    ns.MigrateKeybinds()
    assert.are.equal("seqMine", GSEStore.profile[2][70].ActionBarBinds.GSEButton1.Sequence)
    assert.are.same({ ["F"] = "seqA" }, GSEStore.profile[2][70].KeyBindings, "kept for the bar turned off")
  end)

  it("says which keys found no free button", function()
    local binds = {}
    for i = 1, 26 do binds[string.format("K%02d", i)] = "seq" .. i end
    GSEStore.profile = { [2] = { [70] = { KeyBindings = binds } } }
    loginAs()
    ns.MigrateKeybinds()
    assert.are.equal("CLICK GSEButton24:LeftButton", bindings["K24"])
    assert.are.equal("", GetBindingAction("K25"))
    assert.truthy(printed[#printed]:find("K25, K26", 1, true))
  end)

  it("waits out combat, and runs once", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["F"] = "seqA" } } } }
    loginAs()
    inCombat = true
    assert.is_false(ns.MigrateKeybinds())
    assert.is_nil(bindings["F"])
    inCombat = false
    assert.is_true(ns.MigrateKeybinds())
    bindings["F"] = nil
    assert.is_true(ns.MigrateKeybinds())
    assert.is_nil(bindings["F"], "never again")
  end)

  it("normalises a stored mouse button to its binding name", function()
    GSEStore.profile = { [2] = { [70] = { KeyBindings = { ["Button4"] = "seqA" } } } }
    loginAs()
    ns.MigrateKeybinds()
    assert.are.equal("CLICK GSEButton1:LeftButton", bindings["BUTTON4"])
  end)
end)

describe("GSE keybinds", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/CharacterFunctions")
  end)

  local loaded
  before_each(function()
    loaded = false
    _G.C_AddOns = { IsAddOnLoaded = function(name) return loaded and name == "GSE_Actionbar" end }
  end)

  it("are GSE's own where WoW honours them and the bar is off", function()
    GSE.DirectKeybindsRetired = false
    _G.GSEOptions = {}
    assert.is_true(GSE.KeybindingsEnabled())
  end)

  it("are off where WoW retired them (Forever, Retail 12.1.7)", function()
    GSE.DirectKeybindsRetired = true
    assert.is_false(GSE.KeybindingsEnabled())
  end)

  it("are off with the GSE Action Bar on, which carries the keys", function()
    GSE.DirectKeybindsRetired = false
    _G.GSEOptions = { ActionBarEnabled = true }
    loaded = true
    assert.is_false(GSE.KeybindingsEnabled())
  end)

  it("are off as soon as the bar is turned on, before it has loaded", function()
    GSE.DirectKeybindsRetired = false
    _G.GSEOptions = { ActionBarEnabled = true }
    loaded = false
    assert.is_false(GSE.KeybindingsEnabled())
  end)

  it("come back with the bar turned off, though WoW still has it loaded", function()
    GSE.DirectKeybindsRetired = false
    _G.GSEOptions = { ActionBarEnabled = false }
    loaded = true
    assert.is_true(GSE.KeybindingsEnabled())
  end)
end)

-- The bar's buttons have no action slot. Given an ID, GSE's overrides read it
-- as slot N of WoW's own bar, yielded the button to whatever sat there, showed
-- that slot's icon and ran nothing.
describe("GSE Action Bar buttons", function()
  local function readSource(path)
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
  end

  it("take no ID, and the overrides look for no slot behind them", function()
    assert.is_nil(readSource("GSE_Actionbar/ActionBar.lua"):find("SetID(", 1, true))
    local events = readSource("GSE/API/Events.lua")
    local s = assert(events:find("local function getButtonEffectiveSlot(btn)", 1, true))
    local guard = events:find("if btn.gseActionBarButton then return nil end", s, true)
    assert.truthy(guard and guard < events:find("btn:GetAttribute(\"action\")", s, true))
  end)

  it("keep the secure click: its template comes after ActionButtonTemplate's flyout OnClick", function()
    local src = readSource("GSE_Actionbar/ActionBar.lua")
    assert.truthy(src:find('"ActionButtonTemplate, SecureActionButtonTemplate"', 1, true))
  end)

  it("are listed under GSE in WoW's Key Bindings", function()
    local xml = readSource("GSE_Actionbar/Bindings.xml")
    local _, count = xml:gsub('category="BINDING_HEADER_GSE"', "")
    assert.are.equal(24, count)
    -- Set by GSE, which loads first: WoW reads it as the bar loads, before the
    -- bar's deferred setup runs.
    assert.truthy(readSource("GSE/API/Statics.lua"):find('_G["BINDING_HEADER_GSE"] = Statics.GSEString', 1, true))
  end)
end)
