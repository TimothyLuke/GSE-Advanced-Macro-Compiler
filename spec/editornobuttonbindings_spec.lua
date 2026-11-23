-- The editor has no Button Bindings page (Larry, 2026-11-20: "the Keybind Area
-- can now go away and its all handled in the Right Click Menu").
--
-- A sequence goes on a button from the button's own right-click menu: the
-- talent loadout, the stance, and the button's key (GSE_Utils, Utils.lua). So
-- the editor's Bindings area keeps only the Keybindings pages, and only where
-- GSE still binds keys to sequences itself; anywhere else the editor has no
-- Bindings node and nothing that opens one, and the Keybindings icon on GSE's
-- menu opens the keybind guide, a picture of the steps (Larry, 2026-11-21: "I
-- want the Keybind Button back on the bar but just linked to a Pop up of this
-- image"). The guide itself is in GSE's help (GSE_Help; helpkeybindguide_spec).
-- The GSE_GUI files cannot be loaded here, so this reads them as text (line
-- endings normalised).
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function body(src, startText, endText)
  local s = assert(src:find(startText, 1, true), "start not found: " .. startText)
  local _, e = src:find(endText, s, true)
  assert(e, "end not found: " .. endText)
  return src:sub(s, e)
end

describe("editor without a Button Bindings page", function()
  local keybind = readSource("GSE_GUI/Editor_Keybind.lua")
  local tree = readSource("GSE_GUI/Editor_Tree.lua")
  local editor = readSource("GSE_GUI/Editor.lua")
  local menu = readSource("GSE_GUI/Menu.lua")

  it("leaves Button Bindings out of the tree, and the whole area where GSE binds no keys", function()
    local build = body(keybind, "local function buildKeybindMenu()", "\nend\n")
    local dropAO = assert(build:find("table.remove(tree, 1)", 1, true), "Button Bindings is taken out")
    local noArea = assert(build:find("if not GSE.KeybindingsEnabled() then return nil end", 1, true))
    assert.is_true(dropAO < noArea)
    assert.is_nil(build:find("table.remove(tree, 2)", 1, true), "the Keybindings pages were the ones dropped")
  end)

  it("binds no keys itself on any client, so no client has the Keybindings pages", function()
    local init = readSource("GSE/API/Init.lua")
    assert.truthy(init:find("\nGSE.DirectKeybindsRetired = true\n", 1, true))
    assert.is_nil(init:find("120107", 1, true), "retired by client version again")
    local enabled = body(readSource("GSE/API/CharacterFunctions.lua"), "function GSE.KeybindingsEnabled()", "\nend\n")
    assert.truthy(enabled:find("return not GSE.DirectKeybindsRetired and not GSE.ActionBarEnabled()", 1, true))
    local notes = readSource("GSE/Localization/ModL_enUS.lua")
    assert.is_nil(notes:find("your GSE keybinds still work", 1, true), "What's New says some clients keep them")
  end)

  it("adds the Bindings node to the tree only where there is one", function()
    assert.truthy(tree:find("if bindings then table.insert(tree, bindings) end", 1, true))
    assert.truthy(tree:find('if grouping ~= "class" and bindings then table.insert(tree, bindings) end', 1, true))
    assert.is_nil(tree:find("table.insert(tree, editframe.buildKeybindMenu())", 1, true), "a nil node")
  end)

  it("opens no Button Bindings page from a click or a past session", function()
    local click = body(tree, "local function onClick_KEYBINDINGS(editframe, container, group, unique)", "\nend\n")
    assert.truthy(click:find("if not GSE.KeybindingsEnabled() then return end", 1, true))
    assert.truthy(click:find('if #unique == 1 or unique[2] == "AO" then', 1, true))
    assert.is_nil(click:find('GSE.GUI.BindingsPath("AO"', 1, true))
  end)

  it("offers Keybindings only where the editor has them", function()
    local show = body(editor, "function GSE.ShowKeyBindings()", "\nend\n")
    assert.truthy(show:find("if not GSE.KeybindingsEnabled() then return GSE.ShowSequences() end", 1, true))
    assert.is_nil(show:find('GSE.GUI.BindingsPath("AO")', 1, true))
    assert.truthy(tree:find('if GSE.KeybindingsEnabled() then\n                rootDescription:CreateButton(L["Keybindings"]', 1, true),
      "a sequence's right-click menu")
  end)

  it("keeps the Keybindings icon on GSE's menu, on the guide where the editor has no Bindings area", function()
    local click = body(menu, "        Statics.Icons.Keybindings,\n", "\n    },\n")
    local pages = assert(click:find("if GSE.KeybindingsEnabled() then\n                GSE.ShowKeyBindings()", 1, true))
    local guide = assert(click:find("elseif GSE.CheckHelp() and GSE.ToggleKeybindGuide then\n                GSE.ToggleKeybindGuide()", 1, true))
    assert.is_true(pages < guide)
    assert.is_nil(menu:find("table.remove(iconData", 1, true), "the icon is taken off the menu")
    assert.is_nil(menu:find("iconsLeftOut", 1, true), "the strip is shortened for a missing icon")
    assert.truthy(menu:find("    frame:SetSize(cfg.w, cfg.h)\n", 1, true))
  end)

  -- With the page gone the right-click menu is the one way to put a sequence
  -- on a button, so it has to be on every bar the page listed. Button Forge's
  -- were on the page alone (cross-check of the bar addons, 2026-11-20).
  it("has the right-click menu on every bar the page listed", function()
    local utils = readSource("GSE_Utils/Utils.lua")
    local listed = body(keybind, "local function actionButtonNames()", "\nend\n")
    local hooks = body(utils, "local function hookMenu(button)", "local function hookGamepadActionBars()")
    for _, family in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
      "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiBarLeftButton", "MultiBarRightButton",
      "ElvUI_Bar", "NDui_ActionBar", "CPB_", "BT4Button", "DominosActionButton", "MultiBarRightActionButton",
      "ButtonForge", "EABButton", "DaylightUIBar" }) do
      assert.truthy(listed:find('"' .. family, 1, true), family .. " was on the page")
      assert.truthy(hooks:find('"' .. family, 1, true), family .. " has no right-click menu")
    end
  end)

  it("opens the menu on an empty Button Forge button: one with no mode, as it holds no action slot", function()
    local utils = readSource("GSE_Utils/Utils.lua")
    local handler = body(utils, "local function gseEmptyButtonHandler(self, mousebutton, down)", "local classIconText")
    local forge = assert(handler:find('if string.sub(self:GetName() or "", 1, 11) == "ButtonForge" then', 1, true))
    local slot = assert(handler:find("local action = self.action or self:GetAttribute(\"action\")", 1, true))
    assert.is_true(forge < slot, "before the slot test, which a Button Forge button has no slot for")
    assert.truthy(handler:find('if type(owner) ~= "table" or owner.Mode ~= nil then return end', 1, true))
  end)
end)
