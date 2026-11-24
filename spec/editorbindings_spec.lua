-- The editor's Bindings area (Timothy, 2026-11-24): the Button Bindings page
-- is back, beside the buttons' own right-click menu (GSE_Utils, Utils.lua),
-- which Larry's change of 2026-11-20 had made the only way.
--
-- Bindings is a tab of the Editor with a tree of its own (editortabs_spec):
-- Button Bindings, and a Keybindings section. Where GSE still binds keys to
-- sequences itself that section has its spec pages; it does not on any client
-- now, and there the section shows the keybind guide, a picture of the steps,
-- while GSE's help is turned on (GSE_Help; helpkeybindguide_spec), and is
-- left out while it is not.
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

describe("the editor's Bindings area", function()
  local keybind = readSource("GSE_GUI/Editor_Keybind.lua")
  local tree = readSource("GSE_GUI/Editor_Tree.lua")
  local editor = readSource("GSE_GUI/Editor.lua")

  it("always has Button Bindings, and a Keybindings section for the guide where GSE binds no keys", function()
    local build = body(keybind, "local function buildKeybindMenu()", "\nend\n")
    assert.is_nil(build:find("table.remove(tree, 1)", 1, true), "Button Bindings is taken out")
    assert.is_nil(build:find("return nil", 1, true), "no Bindings area")
    assert.truthy(build:find("    if not GSE.KeybindingsEnabled() then\n        if GSE.HelpEnabled() then\n"
      .. "            tree[2].children = nil\n        else\n            table.remove(tree, 2)\n        end\n    end\n", 1, true),
      "no spec pages under Keybindings; no section at all without the help")
  end)

  it("asks whether GSE's help is turned on without loading it", function()
    local events = readSource("GSE/API/Events.lua")
    local enabled = body(events, "function GSE.HelpEnabled()", "\nend\n")
    local world = { exists = true, state = 2 }
    local env = {
      UnitName = function() return "Me" end,
      C_AddOns = {
        DoesAddOnExist = function(name) return name == "GSE_Help" and world.exists end,
        GetAddOnEnableState = function() return world.state end,
        LoadAddOn = function() error("it must not load the help") end,
      },
      GSE = {},
    }
    local chunk
    if loadstring then
      chunk = assert(loadstring(enabled .. "\nreturn GSE.HelpEnabled"))
      setfenv(chunk, env)
    else
      chunk = assert(load(enabled .. "\nreturn GSE.HelpEnabled", "help", "t", env))
    end
    local helpEnabled = chunk()
    assert.is_true(helpEnabled())
    world.state = 0
    assert.is_false(helpEnabled(), "turned off in the AddOns list")
    world.exists, world.state = false, 2
    assert.is_false(helpEnabled(), "not installed")
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

  it("opens Button Bindings where GSE binds no keys, and the guide from the Keybindings section", function()
    local click = body(tree, "local function onClick_KEYBINDINGS(editframe, container, group, unique)", "\nend\n")
    assert.is_nil(click:find("if not GSE.KeybindingsEnabled() then return end", 1, true), "no page at all")
    local gate = assert(click:find('if not GSE.KeybindingsEnabled() and (#unique == 1 or unique[2] == "KB") then', 1, true))
    local guide = assert(click:find('if unique[2] == "KB" and GSE.HelpEnabled() then', gate, true))
    local draw = assert(click:find("GSE.GUI.DrawKeybindGuide(container)", guide, true))
    local page = assert(click:find('SelectByValue(GSE.GUI.BindingsPath("AO", GSE.CurrentSpecKey()))', draw, true),
      "the Bindings node, and a keybind page from a past session, land on Button Bindings")
    assert.is_true(page < assert(click:find('if #unique == 2 or #unique == 3', 1, true)))
    assert.truthy(click:find('editframe.showKeybind(nil, nil, specialization, loadout, "AO", rc)', 1, true))
  end)

  it("opens the Bindings tab on its own window, down to Button Bindings", function()
    local show = body(editor, "function GSE.ShowKeyBindings(existing)", "\nend\n")
    assert.truthy(show:find("local editor = editorFor(existing)", 1, true))
    assert.truthy(show:find('GSE.GUI.SetEditorTab(editor, "bindings", true)', 1, true))
    assert.truthy(show:find('GSE.GUI.ExpandBindingsPath(editor, GSE.GUI.BindingsPath("AO"))', 1, true))
    assert.is_nil(show:find("OpenEditorPage", 1, true), "the guide is a section of the tab, not the tab")
    assert.truthy(tree:find('rootDescription:CreateButton(L["Bindings"], function()\n                GSE.ShowKeyBindings(editframe)', 1, true),
      "a sequence's right-click menu")
  end)

  -- The right-click menu puts a sequence on a button on every bar the page
  -- lists. Button Forge's were on the page alone (cross-check of the bar
  -- addons, 2026-11-20).
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
