-- The Editor's tabs (Larry, 2026-11-23): what GSE's toolbar opened is a tab
-- down the Editor's right edge, and the left tree shows the open tab's part
-- only -- Editor the sequences, Variables the variables, Macros the macros,
-- Bindings the bindings -- with the tab's own "New" row at its top. Import is
-- a tab, not a row.
--
-- Two settings, each its own (Timothy, 2026-11-24: "there should be a show
-- full tree independant of showing tabs. showing tabs should just hide / show
-- the tabs"). GSEOptions.EditorFullTree: the tree is whole, and a tab opens
-- its part of it. On for an install from before the tabs, off for a new one
-- ("show full tree should be the default for people migrating from earlier
-- versions of GSE"). GSEOptions.HideEditorTabs: the tabs go; with none to
-- turn the tree by it is whole then too, and has its Import row.
--
-- The editor's files cannot be loaded here, so this reads the pieces as text.
describe("the Editor's tabs", function()
  local function readSource(path)
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
  end
  local compile = loadstring or load
  local tree = readSource("GSE_GUI/Editor_Tree.lua")
  local editor = readSource("GSE_GUI/Editor.lua")
  local GROUP = "GROUP:"

  -- narrowTreeToTab and GSE.GUI.TabOfTreePath as the editor has them.
  local function world()
    local s = assert(tree:find("local TAB_OF_AREA = {", 1, true), "TAB_OF_AREA not found")
    local e = assert(tree:find("\n--- Ask for a name and make a WoW macro of it", s, true), "end of the tab code not found")
    local GSE = { GUI = {} }
    local L = setmetatable({}, { __index = function(_, k) return k end })
    local Statics = { ActionsIcons = { Add = "add" } }
    local function stripGroup(path)
      local parts = {}
      for part in (path .. "\001"):gmatch("(.-)\001") do
        if part:sub(1, #GROUP) ~= GROUP then parts[#parts + 1] = part end
      end
      return table.concat(parts, "\001")
    end
    local chunk = assert(compile("local GSE, L, Statics, GROUP_PREFIX, stripGroup = ...\n"
      .. tree:sub(s, e) .. "\nreturn narrowTreeToTab"))
    return GSE, chunk(GSE, L, Statics, GROUP, stripGroup)
  end
  local function byType()
    return {
      { value = "NewSequence" },
      { value = "Sequences", children = { { value = 4 } } },
      { value = "VARIABLES", children = { { value = "NEWVARIABLES" }, { value = "FOLDER:4" } } },
      { value = "Macro", children = { { value = "A" }, { value = "P" } } },
      { value = "KEYBINDINGS", children = { { value = "AO" }, { value = "KB" } } },
    }
  end
  local function values(nodes)
    local out = {}
    for i, node in ipairs(nodes) do out[i] = tostring(node.value) end
    return out
  end

  it("shows each tab its own part of the tree, under its New row", function()
    local _, narrow = world()
    assert.are.same({ "NewSequence", "Sequences" }, values(narrow(byType(), "sequences")))
    assert.are.same({ "VARIABLES\001NEWVARIABLES", "VARIABLES" }, values(narrow(byType(), "variables")))
    assert.are.same({ "Macro\001NEWMACRO", "Macro" }, values(narrow(byType(), "macros")))
    assert.are.same({ "KEYBINDINGS" }, values(narrow(byType(), "bindings")))
  end)

  -- Larry, 2026-11-23: "remove import from left tree menu".
  -- With the tabs turned off there is no Import tab, and the row is back.
  it("has no Import row: Import is a tab; with the tabs off the tree has the row", function()
    assert.truthy(tree:find('    if not GSE.GUI.EditorTreeWhole() then\n        tree = narrowTreeToTab(tree, editframe.editorTab or "sequences")\n'
      .. '    elseif GSE.GUI.EditorTabsHidden() then\n', 1, true), "whole with the tabs showing: no row, the tab has it")
    local whole = assert(tree:match("\n    elseif GSE%.GUI%.EditorTabsHidden%(%) then\n(.-)\n    end\n    treeContainer:SetTree"),
      "the tabs-off branch not found")
    assert.truthy(whole:find('table.insert(tree, at, { value = "Import", text = L["Import"], icon = Statics.Icons.Import })', 1, true))
    local _, count = tree:gsub('value = "Import"', "")
    assert.are.equal(1, count, "the row is made in that branch alone")
    local _, narrow = world()
    assert.are.same({ "NewSequence", "Sequences" }, values(narrow({ { value = "NewSequence" }, { value = "Import" },
      { value = "Sequences" } }, "sequences")), "one handed in is not shown")
  end)

  it("has the New Variable row once: at the top, not under Variables as well", function()
    local _, narrow = world()
    local variables = narrow(byType(), "variables")[2]
    assert.are.same({ "FOLDER:4" }, values(variables.children))
  end)

  it("keeps a grouped tree's groups, each with the tab's members only", function()
    local _, narrow = world()
    local function grouped()
      return {
        { value = "NewSequence" }, { value = "VARIABLES\001NEWVARIABLES" },
        { value = GROUP .. "class:4", children = { { value = "Sequences\0014\0014,259,id,0" },
          { value = "VARIABLES\001myvar" }, { value = "Macro\001A\0015" } } },
        { value = GROUP .. "class:0", children = { { value = "VARIABLES\001other" } } },
      }
    end
    local t = narrow(grouped(), "sequences")
    assert.are.same({ "NewSequence", GROUP .. "class:4" }, values(t))
    assert.are.same({ "Sequences\0014\0014,259,id,0" }, values(t[2].children))
    t = narrow(grouped(), "variables")
    assert.are.same({ "VARIABLES\001NEWVARIABLES", GROUP .. "class:4", GROUP .. "class:0" }, values(t))
    assert.are.same({ "VARIABLES\001myvar" }, values(t[2].children))
    t = narrow(grouped(), "macros")
    assert.are.same({ "Macro\001NEWMACRO", GROUP .. "class:4" }, values(t))
    assert.are.same({ "Macro\001A\0015" }, values(t[2].children))
  end)

  it("knows which tab a node is on, grouped or not", function()
    local GSE = world()
    assert.are.equal("sequences", GSE.GUI.TabOfTreePath("Sequences\0014\0014,259,id,0\0011"))
    assert.are.equal("sequences", GSE.GUI.TabOfTreePath("NewSequence"))
    assert.are.equal("variables", GSE.GUI.TabOfTreePath("VARIABLES\001myvar\001config"))
    assert.are.equal("macros", GSE.GUI.TabOfTreePath(GROUP .. "class:4\001Macro\001A\0015\001config"))
    assert.are.equal("bindings", GSE.GUI.TabOfTreePath("KEYBINDINGS\001AO\0014\0011"))
    assert.is_nil(GSE.GUI.TabOfTreePath("Import"), "no tab's")
    assert.is_nil(GSE.GUI.TabOfTreePath(nil))
  end)

  it("narrows the tree as it is built, and turns to a node's tab before selecting it", function()
    assert.truthy(tree:find('    if not GSE.GUI.EditorTreeWhole() then\n        tree = narrowTreeToTab(tree, editframe.editorTab or "sequences")\n', 1, true))
    assert.truthy(tree:find("local tab = GSE.GUI.TabOfTreePath(path)", 1, true))
    assert.truthy(tree:find('if tab and (tab ~= (editframe.editorTab or "sequences") or editframe.editorPage) and GSE.GUI.SetEditorTab then', 1, true),
      "also off the Import page")
    assert.truthy(tree:find("GSE.GUI.SetEditorTab(editframe, tab)", 1, true))
    assert.truthy(tree:find('if unique[2] == "NEWMACRO" then\n        GSE.GUINewMacroPrompt(editframe)', 1, true))
  end)

  -- GSE.GUI.SetEditorTab as the editor has it.
  -- hidden: a table whose .on says whether the tree is whole.
  local function setTab(hidden)
    hidden = hidden or {}
    local body = assert(editor:match("\nfunction GSE%.GUI%.SetEditorTab%(editframe, tab, quiet%)\n(.-)\nend\n"),
      "GSE.GUI.SetEditorTab not found")
    local all = assert(editor:match("\nlocal EDITOR_TAB_ALL = (%b{})\n"), "EDITOR_TAB_ALL not found")
    local root = assert(editor:match("\nlocal EDITOR_TAB_ROOT = (%b{})\n"), "EDITOR_TAB_ROOT not found")
    return assert(compile("local L, GSE = ...\nlocal EDITOR_TAB_ROOT = " .. root .. "\n"
      .. "local EDITOR_TAB_ALL = " .. all .. "\n"
      .. "local EDITOR_TAB_TITLE = " .. assert(editor:match("\nlocal EDITOR_TAB_TITLE = (%b{})\n"), "EDITOR_TAB_TITLE not found") .. "\n"
      .. "return function(editframe, tab, quiet)\n" .. body .. "\nend"))(setmetatable({}, { __index = function(_, k) return k end }),
      { GUI = { EditorTreeWhole = function() return hidden.on == true end } })
  end
  local function window()
    local w = { built = 0, lit = {}, tabButtons = {}, treeContainer = { status = {} } }
    for _, key in ipairs({ "sequences", "bindings", "import", "variables", "macros", "options" }) do
      w.tabButtons[key] = { SetTabChecked = function(_, on) w.lit[key] = on end }
    end
    w.ManageTree = function() w.built = w.built + 1 end
    return w
  end

  it("lights the open tab, opens its part of the tree, and builds the tree again only on a change", function()
    local set, w = setTab(), window()
    set(w, "variables")
    assert.are.equal("variables", w.editorTab)
    assert.is_true(w.lit.variables)
    assert.is_false(w.lit.sequences)
    assert.is_true(w.treeContainer.status.groups.VARIABLES)
    assert.are.equal(1, w.built)
    set(w, "variables")
    assert.are.equal(1, w.built, "already on it")
    set(w, "macros", true)
    assert.are.equal(1, w.built, "quiet: the caller builds the tree")
    assert.are.equal("macros", w.editorTab)
    set(w, "import")
    assert.are.equal("macros", w.editorTab, "a tab with no tree of its own leaves the tree's tab alone")
    set(w, "bindings")
    assert.are.equal("bindings", w.editorTab)
    assert.is_true(w.lit.bindings)
    assert.is_true(w.treeContainer.status.groups.KEYBINDINGS)
    assert.are.equal(2, w.built)
  end)

  it("leaves a whole tree whole: no title, the sequences' box, the tab lit and its part opened, nothing built again", function()
    local hidden = { on = true }
    local set, w = setTab(hidden), window()
    local title, box
    w.treeContainer.navWindowFrame = {
      GSESetTitle = function(text) title = text end,
      GSESetAllCheckbox = function(text, key, default) box = text and { text, key, default } or "none" end,
    }
    set(w, "macros")
    assert.are.equal("", title)
    assert.are.same({ "All Sequences", "All", false }, box)
    assert.are.equal(0, w.built, "the whole tree has every tab's part already")
    assert.is_true(w.treeContainer.status.groups.Macro, "its part is still opened")
    assert.is_true(w.lit.macros, "and its tab lit")
    hidden.on = false
    set(w, "variables")
    assert.are.equal("Variables", title)
    assert.are.equal(1, w.built)
  end)

  it("keeps the two settings apart: the full tree with the tabs showing, and the tabs off with the tree whole", function()
    local hiddenFn = assert(editor:match("\nfunction GSE%.GUI%.EditorTabsHidden%(%)\n(.-)\nend\n"), "EditorTabsHidden not found")
    local wholeFn = assert(editor:match("\nfunction GSE%.GUI%.EditorTreeWhole%(%)\n(.-)\nend\n"), "EditorTreeWhole not found")
    local options = {}
    local GSE = { GUI = {} }
    GSE.GUI.EditorTabsHidden = assert(compile("local GSEOptions = ...\nreturn function()\n" .. hiddenFn .. "\nend"))(options)
    local whole = assert(compile("local GSE, GSEOptions = ...\nreturn function()\n" .. wholeFn .. "\nend"))(GSE, options)
    assert.is_true(whole(), "never chosen: an install from before the tabs keeps its whole tree")
    assert.is_false(GSE.GUI.EditorTabsHidden(), "the full tree leaves the tabs showing")
    options.EditorFullTree = false
    assert.is_false(whole(), "turned off, and on a new install: the tabs, each with its own part of the tree")
    options.EditorFullTree = true
    assert.is_true(whole())
    options.EditorFullTree, options.HideEditorTabs = false, true
    assert.is_true(GSE.GUI.EditorTabsHidden())
    assert.is_true(whole(), "no tab to turn the tree by")
    local defaults = assert(readSource("GSE/API/InitialOptions.lua"):match("\nfunction GSE%.SetDefaultOptions%(%)\n(.-)\nend\n"))
    assert.truthy(defaults:find("    GSEOptions.EditorFullTree = false\n", 1, true), "a new install starts on the tabs' own trees")
    local options_lua = readSource("GSE_Options/Options.lua")
    assert.truthy(options_lua:find("local function GetValue() return GSEOptions.EditorFullTree ~= false end", 1, true))
    assert.truthy(options_lua:find("GSEOptions.EditorFullTree = value and true or false\n"
      .. "                if GSE.GUI and GSE.GUI.RefreshEditorTabsHidden then GSE.GUI.RefreshEditorTabsHidden() end", 1, true))
  end)

  it("hides the tabs and gives back their room at the screen's edge, and shows them again", function()
    local hiddenFn = assert(editor:match("\nfunction GSE%.GUI%.EditorTabsHidden%(%)\n(.-)\nend\n"), "EditorTabsHidden not found")
    local apply = assert(editor:match("\nfunction GSE%.GUI%.ApplyEditorTabsHidden%(editframe%)\n(.-)\nend\n"), "ApplyEditorTabsHidden not found")
    local options = {}
    local GSE = { GUI = {} }
    GSE.GUI.EditorTabsHidden = assert(compile("local GSEOptions = ...\nreturn function()\n" .. hiddenFn .. "\nend"))(options)
    local run = assert(compile("local GSE = ...\nreturn function(editframe)\n" .. apply .. "\nend"))(GSE)
    local shown, insets = {}, nil
    local w = { tabRoom = 36, tabButtons = {}, frame = { SetClampRectInsets = function(_, l, r) insets = { l, r } end } }
    for _, key in ipairs({ "sequences", "bindings" }) do
      w.tabButtons[key] = { SetShown = function(_, on) shown[key] = on end }
    end
    run(w)
    assert.are.same({ sequences = true, bindings = true }, shown, "never chosen: the tabs show")
    assert.are.same({ 10, 36 }, insets)
    options.HideEditorTabs = true
    run(w)
    assert.are.same({ sequences = false, bindings = false }, shown)
    assert.are.same({ 10, 0 }, insets)
    assert.truthy(editor:find("    editframe.tabRoom = room\n    GSE.GUI.ApplyEditorTabsHidden(editframe)\nend\n", 1, true), "as the tabs are made")
    local options_lua = readSource("GSE_Options/Options.lua")
    assert.truthy(options_lua:find("GSEOptions.HideEditorTabs = value and true or nil\n"
      .. "                if GSE.GUI and GSE.GUI.RefreshEditorTabsHidden then GSE.GUI.RefreshEditorTabsHidden() end", 1, true),
      "the setting turns every open editor at once")
  end)

  -- The box under the tree is the open tab's (Larry, 2026-11-23: "these should
  -- reflect the page its on IE: All Variables / All Macros"), each with a
  -- setting of its own. Macros have no class to filter by, so their tab has
  -- no box (Larry, the same day: "All Macros have no Class Filter > remove it").
  it("names the box under the tree for the open tab, and shows none on Macros", function()
    local set, w = setTab(), window()
    local box
    w.treeContainer.navWindowFrame = { GSESetAllCheckbox = function(text, key, default)
      box = text and { text, key, default } or "none"
    end }
    set(w, "variables", true)
    assert.are.same({ "All Variables", "AllVariables", true }, box)
    set(w, "macros", true)
    assert.are.equal("none", box)
    set(w, "sequences", true)
    assert.are.same({ "All Sequences", "All", false }, box)
    local native = readSource("GSE_GUI/NativeUI.lua")
    assert.truthy(native:find("        GSEOptions.filterList[allKey] = self:GetChecked() and true or false\n", 1, true))
    assert.truthy(native:find("    navWindow.GSESetAllCheckbox = function(text, key, default)\n        allSeqCheckbox:SetShown(text ~= nil)\n", 1, true))
    local enUS = readSource("GSE/Localization/ModL_enUS.lua")
    assert.truthy(enUS:find('\nL["All Variables"] = true\n', 1, true))
    assert.is_nil(enUS:find("All Macros", 1, true))
  end)

  -- Larry, 2026-11-23: "top of left tree place the Title Labels of what the
  -- tree is".
  it("titles the tree with what it lists", function()
    local set, w = setTab(), window()
    local title
    w.treeContainer.navWindowFrame = { GSESetTitle = function(text) title = text end }
    set(w, "variables", true)
    assert.are.equal("Variables", title)
    set(w, "macros", true)
    assert.are.equal("Macros", title)
    set(w, "sequences", true)
    assert.are.equal("Sequences", title)
    local native = readSource("GSE_GUI/NativeUI.lua")
    local setter = assert(native:match("\n    navWindow%.GSESetTitle = function%(text%)\n(.-)\n    end\n"), "GSESetTitle not found")
    assert.truthy(setter:find("local title = navWindow.TitleText or (container and container.TitleText) or navWindow.GSETitleText", 1, true),
      "the template's own title text, on the panel (Classic) or in its title container (Retail, WoW Forever)")
    assert.truthy(setter:find("local host = container or navWindow", 1, true), "one made for it goes above the border art")
    assert.truthy(setter:find('title:SetText(text or "")', 1, true))
  end)

  it("lists another class's variables only while All Variables is ticked, and every macro always", function()
    local body = assert(editor:match("\nfunction GSE%.GUI%.TreeShowsVariable%(classid%)\n(.-)\nend\n"), "TreeShowsVariable not found")
    local options = {}
    local hidden = false
    local shows = assert(compile("local GSE, GSEOptions = ...\nreturn function(classid)\n" .. body .. "\nend"))(
      { GetCurrentClassID = function() return 4 end, GUI = { EditorTreeWhole = function() return hidden end } }, options)
    assert.is_true(shows(8), "never chosen: all of them, as before the box was theirs")
    options.filterList = { AllVariables = false }
    assert.is_false(shows(8))
    assert.is_true(shows(4), "the player's own class")
    assert.is_true(shows(0), "Global")
    assert.is_true(shows(nil))
    hidden = true
    assert.is_true(shows(8), "the whole tree has no All Variables box to untick")
    hidden = false
    options.filterList.AllVariables = true
    assert.is_true(shows(8))
    for _, file in ipairs({ "GSE_GUI/Editor_Variable.lua", "GSE_GUI/Editor_Tree.lua" }) do
      assert.truthy(readSource(file):find("GSE.GUI.TreeShowsVariable(classid)", 1, true), file)
    end
    assert.is_nil(readSource("GSE_GUI/Editor_Macro.lua"):find("TreeShows", 1, true), "macros are not filtered")
  end)

  it("has the six tabs in order, each opening its own place", function()
    local list = assert(editor:match("\nlocal function editorTabList%(%)\n(.-)\nend\n"), "editorTabList not found")
    local order = {}
    for key in list:gmatch('{ key = "(%a+)"') do order[#order + 1] = key end
    -- Under Macros (Larry, 2026-11-23); Bindings, not the guide alone (Timothy, 2026-11-24).
    assert.are.same({ "sequences", "import", "variables", "macros", "bindings", "options" }, order)
    assert.truthy(list:find('{ key = "bindings", icon = Statics.Icons.Keybindings, text = L["Bindings"],', 1, true))
    for _, call in ipairs({ "GSE.ShowSequences(editframe)", "GSE.ShowKeyBindings(editframe)",
      'GSE.GUI.OpenEditorPage(editframe, "import")', "GSE.ShowVariables(editframe)", "GSE.ShowMacros(editframe)",
      "GSE.OpenOptionsPanel()" }) do
      assert.truthy(list:find(call, 1, true), call)
    end
    assert.truthy(editor:find("    editframe.treeContainer = treeContainer\n    GSE.GUI.CreateEditorTabs(editframe)\n", 1, true))
    for _, tab in ipairs({ "sequences", "variables", "macros" }) do
      assert.truthy(editor:find('GSE.GUI.SetEditorTab(editframe, "' .. tab .. '", true)', 1, true)
        or editor:find('GSE.GUI.SetEditorTab(editor, "' .. tab .. '", true)', 1, true), tab)
    end
  end)

  -- Where more than one editor window is allowed (GSE_QoL), GSE.CreateEditor
  -- makes a new one each time: a tab works on its own window (Larry,
  -- 2026-11-23: "varibles and macros are opening new windows").
  it("works on its own window, never a new one", function()
    local body = assert(editor:match("\nlocal function editorFor%(existing%)\n(.-)\nend\n"), "editorFor not found")
    local made = 0
    local GSE = { CreateEditor = function() made = made + 1 return { made = made } end }
    local editorFor = assert(compile("local GSE = ...\nreturn function(existing)\n" .. body .. "\nend"))(GSE)
    local mine = { treeContainer = {}, ManageTree = function() end }
    assert.are.equal(mine, editorFor(mine))
    assert.are.equal(0, made)
    assert.are.equal(1, editorFor(nil).made)
    assert.are.equal(2, editorFor({ GetName = function() end }).made, "a button handed in by a click handler")
    for _, show in ipairs({ "ShowSequences", "ShowVariables", "ShowMacros", "ShowKeyBindings" }) do
      local fn = assert(editor:match("\nfunction GSE%." .. show .. "%(existing%)\n(.-)\nend\n"), show)
      assert.truthy(fn:find("editorFor(existing)", 1, true), show)
      assert.is_nil(fn:find("GSE.CreateEditor()", 1, true), show)
    end
  end)

  -- A tab opens no window of its own (Larry, 2026-11-23): Import is a page in
  -- the Editor, beside the tree, which stays (Timothy, 2026-11-24: "the left
  -- hand tree shouldnt be disappearing"). The guide, which was one too, is
  -- the Bindings tab's Keybindings section (Timothy, 2026-11-24).
  describe("the Import tab and the keybind guide", function()
    local function page(hidden)
      local body = assert(editor:match("\nfunction GSE%.GUI%.OpenEditorPage%(editframe, page%)\n(.-)\nend\n"),
        "GSE.GUI.OpenEditorPage not found")
      local drawn, saved = {}, {}
      local GSE = { GUI = { DrawImportPage = function(_, room) drawn[#drawn + 1] = "import " .. tostring(room) end,
        EditorTabsHidden = function() return hidden == true end },
        ShowImport = function() drawn[#drawn + 1] = "import window" end }
      local open = assert(compile("local GSE, L, SetSequenceEditorOpenPreference = ...\n"
        .. "return function(editframe, page)\n" .. body .. "\nend"))(GSE,
        setmetatable({}, { __index = function(_, k) return k end }),
        function(isOpen, mode) saved[#saved + 1] = mode end)
      return open, drawn, saved
    end
    local function paged()
      local w = window()
      w.released, w.shows, w.tucked = 0, 0, nil
      w.treeContainer.SetNavTucked = function(tucked) w.tucked = tucked end
      w.treeContainer.ReleaseChildren = function() w.released = w.released + 1 end
      w.Show = function() w.shows = w.shows + 1 end
      w.SetTitle = function(_, title) w.title = title end
      w.GetScrollAreaHeight = function() return 480 end
      return w
    end

    it("draws its page in the Editor and lights its tab, the tree left where it was", function()
      local open, drawn, saved = page()
      local w = paged()
      open(w, "import")
      assert.are.same({ "import 480" }, drawn)
      assert.is_nil(w.tucked, "the tree is not put away for the page")
      assert.are.equal(1, w.released)
      assert.is_true(w.lit.import)
      assert.is_false(w.lit.sequences)
      assert.are.equal("GSE: Import", w.title)
      assert.are.same({ "import" }, saved, "the Editor comes back on it after a reload")
      open(w, "import")
      assert.are.same({ "import 480" }, drawn, "already on it")
      open(w, "keybind")
      open(w, "options")
      assert.are.same({ "import 480" }, drawn)
      assert.are.equal("import", w.editorPage, "not pages")
    end)

    it("is the Import window with the tabs turned off, where no tab would lead back from the page", function()
      local open, drawn, saved = page(true)
      local w = paged()
      open(w, "import")
      assert.are.same({ "import window" }, drawn)
      assert.is_nil(w.tucked)
      assert.is_nil(w.editorPage)
      assert.are.same({}, saved)
      assert.truthy(tree:find('if group == "Import" and GSE.ShowImport then GSE.ShowImport() end', 1, true), "the tree's row")
    end)

    it("gives the tree back, and clears its page, when a tab with a tree is opened", function()
      local set, w = setTab(), paged()
      w.editorPage, w.loaded = "import", true
      set(w, "sequences", true)
      assert.is_nil(w.editorPage)
      assert.is_false(w.tucked)
      assert.are.equal(1, w.released)
      assert.is_nil(w.loaded)
      assert.is_true(w.lit.sequences)
    end)

    it("is where a reload goes; a reload on the guide's old page goes to Bindings", function()
      assert.truthy(editor:find('    if mode == "import" and not GSE.GUI.EditorTabsHidden() then\n        GSE.GUI.OpenEditorPage(GSE.CreateEditor(), mode)\n', 1, true))
      assert.truthy(editor:find('    elseif mode == "keybindings" or mode == "keybind" then\n        GSE.ShowKeyBindings()\n', 1, true))
    end)

    it("shows the guide from GSE's help in a group that takes it away with the page", function()
      local draw = assert(editor:match("\nfunction GSE%.GUI%.DrawKeybindGuide%(container%)\n(.-)\nend\n"))
      assert.truthy(draw:find("if GSE.CheckHelp() and GSE.ShowKeybindGuideIn then GSE.ShowKeybindGuideIn(outer.frame) end", 1, true))
      assert.truthy(draw:find('outer:SetCallback("OnRelease", function()\n        if GSE.HideKeybindGuide then GSE.HideKeybindGuide() end', 1, true))
    end)

    it("draws the import page's paste box in the Editor, leaving the Import window to the rest", function()
      local import = readSource("GSE_GUI/Import.lua")
      assert.truthy(import:find("function GSE.GUI.DrawImportPage(container, room)", 1, true))
      assert.truthy(import:find("local function LandingPage(host, room)", 1, true))
      assert.truthy(import:find("  host:AddChild(pastePanel)\n", 1, true))
      assert.truthy(import:find("          if not inEditor then importframe:Hide() end\n", 1, true))
      assert.truthy(import:find("          GSE.GUIShowCollectionImport(actiontable.payload)\n", 1, true), "a collection's review page")
      assert.truthy(import:find("      inWindow(processQueue)\n", 1, true), "the platform queue")
      assert.truthy(import:find("function GSE.ShowImport()", 1, true), "the Import window is still there")
    end)

    it("hide the tree whatever the player chose, without changing that choice", function()
      local native = readSource("GSE_GUI/NativeUI.lua")
      assert.truthy(native:find("        if not navVisible or navTucked then\n", 1, true))
      assert.truthy(native:find("        if detached or navTucked then\n", 1, true), "its arrow goes with it")
      local tuck = assert(native:match("\n    widget%.SetNavTucked = function%(tucked%)\n(.-)\n    end\n"))
      assert.is_nil(tuck:find("opts.navVisible", 1, true), "the saved choice is written")
      assert.is_nil(tuck:find("navVisible =", 1, true))
    end)
  end)

  -- The toolbar is gone and /gse opens the Editor (Larry, 2026-11-23: "remove
  -- the old toolbar /gse should open the editor").
  describe("with the toolbar gone", function()
    local ADDONS = { "GSE", "GSE_GUI", "GSE_Utils", "GSE_Options", "GSE_LDB", "GSE_QoL" }
    local FILES = { "GSE/API/Events.lua", "GSE/API/InitialOptions.lua", "GSE_Utils/Utils.lua", "GSE_Utils/Appearance.lua",
      "GSE_Options/Options.lua", "GSE_GUI/Editor.lua", "GSE_GUI/Editor_Tree.lua", "GSE_GUI/NativeUI.lua",
      "GSE_LDB/LDBProvider.lua", "GSE_QoL/QoL.lua" }

    it("the toolbar's file is not there and is not loaded", function()
      assert.is_nil(io.open("GSE_GUI/Menu.lua", "r"))
      assert.is_nil(readSource("GSE_GUI/GSE_GUI.toc"):find("Menu.lua", 1, true))
      assert.are.equal(6, #ADDONS)
    end)

    it("nothing opens it, places it or switches it on", function()
      for _, file in ipairs(FILES) do
        local src = readSource(file)
        for _, name in ipairs({ "GSE.ShowMenu", "GSE.MenuFrame", 'GSE["MenuFrame"]', "ToolbarEnabled", "UpdateMenuDirection",
          "frameLocations.menu" }) do
          assert.is_nil(src:find(name, 1, true), name .. " in " .. file)
        end
      end
    end)

    it("/gse opens the Editor", function()
      local utils = readSource("GSE_Utils/Utils.lua")
      local s = assert(utils:find("            -- /gse opens the Editor.", 1, true))
      local slash = utils:sub(s, s + 2600)
      assert.truthy(slash:find("            if GSE.ShowSequences then GSE.ShowSequences() end\n        end\n    end\nend\n", 1, true))
      assert.truthy(slash:find("            if restorePending then\n                return\n", 1, true), "one being brought back at login is left to open")
    end)

    -- The toolbar's return at login was what loaded GSE_GUI, and loading it is
    -- what reopens the Editor. With the toolbar gone the Editor stayed shut
    -- after a /reload (Larry, 2026-11-23: "the editor is not reopening after a
    -- reload to its last state").
    it("the Editor still comes back after a reload when it was left open", function()
      local events = readSource("GSE/API/Events.lua")
      assert.truthy(events:find("    local editorOpts = not GSE.isEmpty(GSEOptions.frameLocations) and GSEOptions.frameLocations.sequenceeditor\n"
        .. "    if editorOpts and editorOpts.open then\n"
        .. "        C_Timer.After(0, function() GSE.CheckGUI() end)\n"
        .. "    end\nend\n", 1, true))
      local login = assert(events:match("\nfunction GSE:PLAYER_ENTERING_WORLD%(%)\n(.-)\nend\n"))
      assert.truthy(login:find("editorOpts.open", 1, true), "at login")
    end)

    it("the options have no rows for it", function()
      local options = readSource("GSE_Options/Options.lua")
      assert.is_nil(options:find('L["Toolbar"]', 1, true))
      assert.is_nil(options:find("GSE Toolbar Scale", 1, true))
      assert.is_nil(options:find("menuLocked", 1, true))
      assert.truthy(options:find('{name = L["Sequence Editor"], tooltip = L["Sequence Editor"]}', 1, true), "the Editor's rows stay")
    end)
  end)

  -- The Editor tab's flyout (Larry, 2026-11-23: "the Editor Tab needs a Flyout
  -- with a + to create a second Editor Window").
  describe("the Editor tab's flyout", function()
    local function flyout()
      local body = assert(editor:match("\nlocal function addEditorTabFlyout%(tab, flat%)\n(.-)\nend\n"),
        "addEditorTabFlyout not found")
      local timers, opened, over = {}, {}, {}
      local function button(name)
        local b = { name = name, shown = true, scripts = {}, hooks = {} }
        function b:SetPoint() end
        function b:Show() self.shown = true end
        function b:Hide() self.shown = false end
        function b:IsMouseOver() return over[name] == true end
        function b:SetScript(event, fn) self.scripts[event] = fn end
        function b:HookScript(event, fn) self.hooks[event] = fn end
        function b:PaintTab() end
        return b
      end
      local tab, plus = button("tab"), button("plus")
      local tip = { SetOwner = function() end, SetText = function(_, text) opened.tip = text end,
        Show = function() end, Hide = function() end }
      local add = assert(compile("local EDITOR_FLYOUT_ICON_INSET = 5 local GSE, L, Statics, C_Timer, GameTooltip, newEditorTabButton, EDITOR_FLYOUT_GAP, "
        .. "EDITOR_FLYOUT_LINGER = ...\nreturn function(tab, flat)\n" .. body .. "\nend"))(
        { ShowSequences = function(existing) opened[#opened + 1] = existing == nil and "new" or "given" end },
        setmetatable({}, { __index = function(_, k) return k end }), { ActionsIcons = { Add = "add" } },
        { After = function(_, fn) timers[#timers + 1] = fn end }, tip,
        function(parent, icon, _, inset) plus.parent, plus.icon, plus.inset = parent, icon, inset return plus end, 6, 0.2)
      add(tab, false)
      return tab, plus, over, timers, opened
    end
    local function runTimers(timers)
      for i = 1, #timers do timers[i]() end
      for i = #timers, 1, -1 do timers[i] = nil end
    end

    it("is a + beside the tab, out of sight until the mouse is on the tab", function()
      local tab, plus = flyout()
      assert.are.equal(tab, plus.parent)
      assert.are.equal("add", plus.icon)
      assert.are.equal(5, plus.inset, "the + sits in from its button's edges")
      assert.is_false(plus.shown)
      tab.hooks.OnEnter()
      assert.is_true(plus.shown)
    end)

    it("stays while the mouse is on the tab or on the +, and goes once it has left both", function()
      local tab, plus, over, timers = flyout()
      tab.hooks.OnEnter()
      over.plus = true
      tab.hooks.OnLeave()
      runTimers(timers)
      assert.is_true(plus.shown, "crossed to the +")
      over.plus = false
      plus.scripts.OnLeave(plus)
      runTimers(timers)
      assert.is_false(plus.shown)
    end)

    it("opens another Editor window, and names what it does", function()
      local _, plus, _, _, opened = flyout()
      plus.scripts.OnEnter(plus)
      assert.are.equal("New Editor Window", opened.tip)
      plus.shown = true
      plus.scripts.OnClick(plus)
      assert.are.same({ "new" }, { opened[1] })
      assert.is_false(plus.shown)
    end)

    it("is only there where more than one Editor window can be open", function()
      local tabs = assert(editor:match("\nfunction GSE%.GUI%.CreateEditorTabs%(editframe%)\n(.-)\nend\n"))
      assert.truthy(tabs:find("    if GSE.CanMultiWindow and GSE.CanMultiWindow() then\n"
        .. "        editframe.tabFlyout = addEditorTabFlyout(editframe.tabButtons.sequences, flat)\n", 1, true))
      assert.truthy(readSource("GSE/Localization/ModL_enUS.lua"):find('\nL["New Editor Window"] = true\n', 1, true))
    end)
  end)

  it("draws the Native tab from the spellbook side tab's own sizes and art", function()
    local make = assert(editor:match("\nlocal function newEditorTabButton%(parent, iconTexture, flat, inset%)\n(.-)\nend\n"))
    assert.truthy(editor:find("local EDITOR_TAB_SIZE = 32 ", 1, true))
    assert.truthy(editor:find("local EDITOR_TAB_GAP = 12 ", 1, true), "closer than the spellbook's 17")
    assert.truthy(make:find('back:SetTexture("Interface\\\\SpellBook\\\\SpellBook-SkillLineTab")', 1, true))
    assert.truthy(make:find("back:SetSize(64, 64)", 1, true))
    assert.truthy(make:find('back:SetPoint("TOPLEFT", -3, 11)', 1, true))
    assert.truthy(make:find('tab:SetHighlightTexture("Interface\\\\Buttons\\\\ButtonHilight-Square", "ADD")', 1, true))
    assert.truthy(make:find('checked:SetTexture("Interface\\\\Buttons\\\\CheckButtonHilight")', 1, true))
  end)
end)
