-- The editor's Bindings area (Timothy, 2026-11-24): the Button Bindings page
-- is back, beside the buttons' own right-click menu (GSE_Utils, Utils.lua),
-- which Larry's change of 2026-11-20 had made the only way.
--
-- Bindings is a tab of the Editor with a tree of its own (editortabs_spec):
-- Button Bindings, and a Keybindings section. Where GSE still binds keys to
-- sequences itself that section has its spec pages; it does not on any client
-- now, and there the section is left out of the tree (Larry, 2026-11-24).
-- The keybind guide it showed, a picture of the steps (GSE_Help;
-- helpkeybindguide_spec), is the help page: a ? beside the Bindings tab and
-- on the Button Bindings page (editortabs_spec).
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

  it("always has Button Bindings, and no Keybindings section where GSE binds no keys", function()
    local build = body(keybind, "local function buildKeybindMenu()", "\nend\n")
    assert.is_nil(build:find("table.remove(tree, 1)", 1, true), "Button Bindings is taken out")
    assert.is_nil(build:find("return nil", 1, true), "no Bindings area")
    assert.truthy(build:find("    if not GSE.KeybindingsEnabled() then table.remove(tree, 2) end\n", 1, true),
      "no Keybindings section, with the help or without")
    assert.is_nil(build:find("HelpEnabled", 1, true), "the guide is not a row of the tree")
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
    assert.truthy(tree:find("if bindings then table.insert(tree, foldBindings(bindings)) end", 1, true))
    assert.truthy(tree:find('if grouping ~= "class" and bindings then table.insert(tree, foldBindings(bindings)) end', 1, true))
    assert.truthy(tree:find("            table.insert(group.children, foldBindings(bindings))\n", 1, true), "in its class's group too")
    assert.is_nil(tree:find("table.insert(tree, editframe.buildKeybindMenu())", 1, true), "a nil node")
  end)

  -- Larry, 2026-11-24: "fold them into one row - use the Keybind Icon and not
  -- the ABO icon". Bindings held Button Bindings alone, a row inside a row.
  it("is one row where Bindings holds Button Bindings alone, by the same paths", function()
    local src = body(tree, "local function foldBindings(bindings)", "\nend\n")
    local chunk
    if loadstring then
      chunk = assert(loadstring(src .. "\nreturn foldBindings"))
    else
      chunk = assert(load(src .. "\nreturn foldBindings", "fold", "t", {}))
    end
    local fold = chunk()
    local specs = { { value = "4", text = "Rogue", children = { { value = "1", text = "Primary Talents" } } } }
    local row = fold({ value = "KEYBINDINGS", text = "Bindings", icon = "key",
      children = { { value = "AO", text = "Button Bindings", icon = "button", children = specs } } })
    assert.are.equal("KEYBINDINGS\001AO", row.value, "both levels' value: every path under it is what it was")
    assert.are.equal("Button Bindings", row.text)
    assert.are.equal("key", row.icon, "the key, not the button")
    assert.are.equal(specs, row.children)
    -- The class grouping has already put the class into the area's value.
    assert.are.equal("KEYBINDINGS\001AO\0014", fold({ value = "KEYBINDINGS", icon = "key",
      children = { { value = "AO\0014", text = "Button Bindings", children = {} } } }).value)
    -- Two areas (GSE binding keys itself): left as they are.
    local both = { value = "KEYBINDINGS", children = { { value = "AO" }, { value = "KB" } } }
    assert.are.equal(both, fold(both))
    assert.is_nil(fold(nil))
    -- The tree finds a saved path by joining values, so the folded row's is found.
    assert.truthy(tree:find('local value = prefix and (prefix .. "\\001" .. tostring(node.value)) or tostring(node.value)', 1, true))
    assert.truthy(readSource("GSE_GUI/NativeUI.lua"):find('return treeUnique(line.parent) .. "\\001" .. line.value', 1, true))
  end)

  it("opens Button Bindings where GSE binds no keys, the guide no longer a section of the tree", function()
    local click = body(tree, "local function onClick_KEYBINDINGS(editframe, container, group, unique)", "\nend\n")
    assert.is_nil(click:find("if not GSE.KeybindingsEnabled() then return end", 1, true), "no page at all")
    local gate = assert(click:find('if not GSE.KeybindingsEnabled() and (#unique == 1 or unique[2] == "KB") then', 1, true))
    assert.is_nil(click:find("DrawKeybindGuide", 1, true), "the guide is the help page (Larry, 2026-11-24)")
    local page = assert(click:find('SelectByValue(GSE.GUI.BindingsPath("AO", GSE.CurrentSpecKey()))', gate, true),
      "the Bindings node, and a keybind page from a past session, land on Button Bindings")
    assert.is_true(page < assert(click:find('if #unique == 2 or #unique == 3', 1, true)))
    assert.truthy(click:find('editframe.showKeybind(nil, nil, specialization, loadout, "AO", rc)', 1, true))
  end)

  -- Larry, 2026-11-24: "make these Buttons again - they need to be small
  -- enough where when the window is at its smallest it doesnt wrap the line".
  it("shows a button's keys as two buttons that open WoW's Key Bindings, and keeps the row one line", function()
    local cell = body(keybind, "        local function keyCell(width)", "\n        end\n")
    assert.truthy(cell:find('local cell = UI:Create("Button")', 1, true))
    assert.is_nil(cell:find("InteractiveLabel", 1, true))
    local combat = assert(cell:find("if InCombatLockdown() then", 1, true), "opening WoW's Options is protected in combat")
    local open = assert(cell:find("GSE.GUIOpenButtonKeyBindings(model.bind)", 1, true))
    assert.is_true(combat < open)
    assert.is_nil(cell:find("SetBinding", 1, true), "GSE sets no bar's key itself")
    assert.truthy(keybind:find("            key:SetDisabled(GSE.isEmpty(model.bind))\n            keys:SetDisabled(GSE.isEmpty(model.bind))\n", 1, true),
      "greyed until the row has a button")
    -- One line at any width: the row does not wrap, and its columns give
    -- width back, the key buttons down to 30.
    assert.truthy(keybind:find('{{"state"}, 120}, {{"sequence"}, 150}, {{"key", "keys"}, 50}, {{"button"}, 130}, {{"key", "keys"}, 30},', 1, true))
    assert.truthy(keybind:find("                if cells[name] then cells[name].width = width end\n", 1, true), "the buttons follow their columns")
    assert.truthy(keybind:find("            if text then text = fitText(cell.text, text, width - 12) end\n", 1, true), "their text is cut to fit")
    local notes = readSource("GSE/Localization/ModL_enUS.lua")
    assert.truthy(notes:find('\nL["Open WoW\'s Key Bindings at this button, to set its key."] = true\n', 1, true))
    assert.is_nil(notes:find("Change this in WoW's Options -> Keybindings.", 1, true), "the old read-only tip")
  end)

  -- Larry, 2026-11-24: "use s c and a for shift ctrl alt + Key".
  it("writes a key in short: s, c and a for the modifiers, then WoW's name for the key", function()
    local src = body(keybind, "local KEY_MODIFIER_LETTERS = ", "\nend\n")
    local env = { string = string, GetBindingText = function(key) return key == "NUMPAD1" and "Num Pad 1" or key end }
    local chunk
    if loadstring then
      chunk = assert(loadstring(src .. "\nreturn shortKeyText"))
      setfenv(chunk, env)
    else
      chunk = assert(load(src .. "\nreturn shortKeyText", "keys", "t", env))
    end
    local short = chunk()
    assert.are.equal("F1", short("F1"))
    assert.are.equal("s+F1", short("SHIFT-F1"))
    assert.are.equal("c+1", short("CTRL-1"))
    assert.are.equal("a+Num Pad 1", short("ALT-NUMPAD1"))
    assert.are.equal("a+c+1", short("ALT-CTRL-1"), 'Larry: "s-F1, a-c-1 > s+F1, a+c+1"')
    assert.are.equal("a+c+s+F1", short("ALT-CTRL-SHIFT-F1"))
    assert.are.equal("s+-", short("SHIFT--"), "the minus key")
    assert.are.equal("-", short("-"))
    assert.are.equal("PADDUP", short("PADDUP"))
    assert.truthy(keybind:find("    for _, key in ipairs(keys) do shown[#shown + 1] = shortKeyText(key) end\n", 1, true))
  end)

  -- Larry, 2026-11-24: the keys' tooltip is "Click to Open and Set in /
  -- Blizzards Keybind / Menu" and nothing else, every line centred.
  it("says in the tooltip what a click does, in three centred lines, and nothing else", function()
    local cell = body(keybind, "        local function keyCell(width)", "\n        end\n")
    assert.truthy(cell:find(
      'GSE.CreateToolTip("", L["Click to Open and Set in\\nBlizzard\'s Keybind\\nMenu"], editframe)', 1, true))
    assert.is_nil(cell:find('L["Main Key"]', 1, true), "no heading: the keys are on the buttons")
    assert.truthy(readSource("GSE/Localization/ModL_enUS.lua"):find(
      '\nL["Click to Open and Set in\\nBlizzard\'s Keybind\\nMenu"] = true\n', 1, true))
    -- One column, centred, and no heading row for an empty title: GSE's own tooltip.
    local tips = readSource("GSE_GUI/GUIFunctions.lua")
    assert.truthy(tips:find('local tooltip = LibQTip:AcquireTooltip("GSE", 1, "CENTER")', 1, true))
    assert.truthy(tips:find("  if not GSE.isEmpty(title) then\n    tooltip:AddHeadingRow(", 1, true))
  end)

  -- Larry, 2026-11-24: "hide the states my class cant reach" (a rogue on WoW
  -- Forever was offered 8, 9 and 10 beside Stealth).
  it("offers a row only the states something names, as the right-click menu does, and never loses a saved one", function()
    local src = body(keybind, "local function stateListFor(buttonName, saved)", "\nend\n")
    assert.is_nil(keybind:find("local FORM_PAGES", 1, true), "a list of its own, behind GSE.OverrideStatesFor's")
    assert.is_nil(keybind:find("local BONUS_PAGES", 1, true))
    local shared
    local env = { ipairs = ipairs, GSE = { OverrideStatesFor = function(name, saved)
      if not shared then return nil end
      local states, order = {}, {}
      for _, k in ipairs(shared) do states[k[1]] = k[2] order[#order + 1] = k[1] end
      if saved and not states[saved] then states[saved] = saved order[#order + 1] = saved end
      return states, order
    end } }
    local chunk
    if loadstring then
      chunk = assert(loadstring(src .. "\nreturn stateListFor"))
      setfenv(chunk, env)
    else
      chunk = assert(load(src .. "\nreturn stateListFor", "states", "t", env))
    end
    local list = chunk()
    -- A rogue on the main bar: Stealth is named, 8-10 are not.
    shared = { { "Default", "Default" }, { "7", "Stealth" }, { "8", "8" }, { "9", "9" }, { "10", "10" } }
    local states, order = list("ActionButton1")
    assert.are.same({ "Default", "7" }, order)
    assert.are.same({ Default = "Default", ["7"] = "Stealth" }, states)
    states, order = list("ActionButton1", "9")
    assert.are.same({ "Default", "7", "9" }, order, "a row saved on 9 keeps it")
    assert.are.equal("9", states["9"])
    -- A class with no form that turns the bar: no State to choose.
    shared = { { "Default", "Default" }, { "7", "7" }, { "8", "8" } }
    assert.is_nil(list("ActionButton1"))
    shared = nil
    assert.is_nil(list("ActionButton1"), "a button with only the one state")
    local utils = readSource("GSE_Utils/Utils.lua")
    assert.truthy(utils:find('if k == "Default" or states[k] ~= k then named[#named + 1] = k end', 1, true), "the menu's own rule")
  end)

  -- Larry, 2026-11-24: "single clicking any of Bindings Tree should bring
  -- the user back to that level on the page". An open row's click only closed
  -- it, and a row already selected never drew its page again.
  it("goes to a Bindings row's page on every click of the row, its +/- box left to open and close it", function()
    assert.truthy(tree:find('    treeContainer.rowClickSelects = function(path) return GSE.GUI.TabOfTreePath(path) == "bindings" end\n', 1, true))
    local native = readSource("GSE_GUI/NativeUI.lua")
    local click = body(native, "            if mouseButton == \"LeftButton\" and self.hasChildren then", "\n            end\n")
    local asked = assert(click:find("if widget.rowClickSelects and widget.rowClickSelects(self.uniquevalue)", 1, true))
    local box = assert(click:find("and not (self.toggle.IsMouseOver and self.toggle:IsMouseOver(4, -4, -4, 4)) then", asked, true),
      "the +/- box keeps opening and closing")
    local open = assert(click:find("if not status.groups[self.uniquevalue] then\n                        status.groups[self.uniquevalue] = true\n", box, true),
      "a closed row opens")
    local selected = assert(click:find("status.selected = self.uniquevalue\n", open, true))
    local fired = assert(click:find('widget:Fire("OnGroupSelected", self.uniquevalue)\n', selected, true),
      "fired every time, selected already or not")
    local closes = assert(click:find("status.groups[self.uniquevalue] = nil", 1, true))
    assert.is_true(fired < closes, "before the rule that closes an open row")
  end)

  it("opens the Bindings tab on its own window, down to Button Bindings", function()
    local show = body(editor, "function GSE.ShowKeyBindings(existing)", "\nend\n")
    assert.truthy(show:find("local editor = editorFor(existing)", 1, true))
    assert.truthy(show:find('GSE.GUI.SetEditorTab(editor, "bindings", true)', 1, true))
    assert.truthy(show:find('GSE.GUI.ExpandBindingsPath(editor, GSE.GUI.BindingsPath("AO"))', 1, true))
    assert.is_nil(show:find("OpenEditorPage", 1, true), "the guide is the tab's ? flyout, not the tab")
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
