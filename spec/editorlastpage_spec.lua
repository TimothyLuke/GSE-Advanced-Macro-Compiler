-- After a /reload the editor comes back where it was left: the last sequence,
-- or the page of a variable or macro (GSE_GUI/Editor_Tree.lua SaveLastAreaNode,
-- GSE_GUI/Editor.lua RestoreSequenceEditorIfNeeded).
--
-- A click on the Variables node itself opens no page -- the sequence stays in
-- the pane -- but it was remembered as the place to come back to, so the
-- editor came back on Variables with an empty pane (Larry, 2026-11-23: "on
-- Reload the Editor didnt open to last open area"). Only a node that opens a
-- page of its own is remembered now.
--
-- The editor's files cannot be loaded here, so this reads the pieces as text.
describe("where the editor comes back after a reload", function()
  local function readSource(path)
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
  end
  local compile = loadstring or load
  local tree = readSource("GSE_GUI/Editor_Tree.lua")
  local editor = readSource("GSE_GUI/Editor.lua")

  local function split(path)
    local parts = {}
    for part in (path .. "\001"):gmatch("(.-)\001") do parts[#parts + 1] = part end
    return parts
  end

  -- The area code as the editor has it, over one saved-options table.
  local function world()
    local s = assert(tree:find("local AREA_OPEN_MODE = {", 1, true), "AREA_OPEN_MODE not found")
    local e = assert(tree:find("-- ---------------------------------------------------------------------------\n"
      .. "-- Right-click context menus", s, true), "end of the area code not found")
    local opts, GSE = {}, { GUI = {} }
    local chunk = assert(compile("local GSE, GetSequenceEditorOptions, splitElementPath = ...\n"
      .. tree:sub(s, e - 1) .. "\nreturn SaveLastAreaNode"))
    return GSE, opts, chunk(GSE, function() return opts end, split)
  end

  it("remembers nothing for a node that opens no page", function()
    local _, opts, save = world()
    for _, node in ipairs({ { "VARIABLES" }, { "VARIABLES", "NEWVARIABLES" }, { "VARIABLES", "myvar" },
      { "Macro" }, { "Macro", "A" }, { "Macro", "A", "5" } }) do
      save(node)
      assert.is_nil(opts.openMode, table.concat(node, " > "))
      assert.is_nil(opts.lastNodeByArea, table.concat(node, " > "))
    end
  end)

  it("remembers a variable's or a macro's page", function()
    local GSE, opts, save = world()
    save({ "VARIABLES", "myvar", "config" })
    assert.are.equal("variables", opts.openMode)
    assert.are.equal("VARIABLES\001myvar\001config", opts.lastNodeByArea.VARIABLES)
    assert.is_true(GSE.GUI.HasLastAreaPage("VARIABLES"))
    assert.is_false(GSE.GUI.HasLastAreaPage("Macro"))
    save({ "Macro", "A", "5", "notes" })
    assert.are.equal("macros", opts.openMode)
    assert.are.equal("Macro\001A\0015\001notes", opts.lastNodeByArea.Macro)
    assert.is_true(GSE.GUI.HasLastAreaPage("Macro"))
  end)

  it("leaves an area with one kind of page as it was", function()
    local _, opts, save = world()
    save({ "KEYBINDINGS" })
    assert.are.equal("keybindings", opts.openMode)
    assert.are.equal("KEYBINDINGS", opts.lastNodeByArea.KEYBINDINGS)
  end)

  it("drops a node with no page that an older build remembered", function()
    local GSE, opts = world()
    opts.lastNodeByArea = { VARIABLES = "VARIABLES" }
    assert.is_false(GSE.GUI.HasLastAreaPage("VARIABLES"))
    local frame = { treeContainer = { tree = { { value = "VARIABLES" } } } }
    assert.is_nil(GSE.GUI.GetLastAreaNode(frame, "VARIABLES"))
    assert.is_nil(opts.lastNodeByArea.VARIABLES)
  end)

  it("gives back a remembered page the tree still has", function()
    local GSE, opts = world()
    opts.lastNodeByArea = { VARIABLES = "VARIABLES\001myvar\001config" }
    local has = { treeContainer = { tree = { { value = "VARIABLES",
      children = { { value = "myvar", children = { { value = "config" } } } } } } } }
    assert.are.equal("VARIABLES\001myvar\001config", GSE.GUI.GetLastAreaNode(has, "VARIABLES"))
    local gone = { treeContainer = { tree = { { value = "VARIABLES" } } } }
    assert.is_nil(GSE.GUI.GetLastAreaNode(gone, "VARIABLES"), "the variable was deleted")
  end)

  -- RestoreSequenceEditorIfNeeded as the editor has it.
  local function reopen(saved, pages)
    local body = assert(editor:match("\nlocal function RestoreSequenceEditorIfNeeded%(%)\n(.-)\nend\n"),
      "RestoreSequenceEditorIfNeeded not found")
    local opened
    local GSE = { GUI = { HasLastAreaPage = function(area) return pages[area] == true end } }
    for _, name in ipairs({ "ShowSequences", "ShowVariables", "ShowMacros", "ShowKeyBindings" }) do
      GSE[name] = function() opened = name end
    end
    assert(compile("local GSE, EnsureSequenceEditorRestoreOptions = ...\n" .. body))(GSE, function() return saved end)
    return opened
  end

  it("reopens Variables or Macros only on a page they were left on, else the last sequence", function()
    assert.are.equal("ShowSequences", reopen({ open = true, openMode = "variables" }, {}))
    assert.are.equal("ShowVariables", reopen({ open = true, openMode = "variables" }, { VARIABLES = true }))
    assert.are.equal("ShowSequences", reopen({ open = true, openMode = "macros" }, { VARIABLES = true }))
    assert.are.equal("ShowMacros", reopen({ open = true, openMode = "macros" }, { Macro = true }))
    assert.are.equal("ShowSequences", reopen({ open = true, openMode = "sequences" }, {}))
    assert.are.equal("ShowKeyBindings", reopen({ open = true, openMode = "keybindings" }, {}))
    assert.is_nil(reopen({ open = false, openMode = "variables" }, { VARIABLES = true }), "closed stays closed")
  end)

  -- New Version shows its node before any Save. Close the Editor without saving
  -- and the node, and the last page remembered for it, are still there, but the
  -- sequence that loads has no such version (Lua error at Editor.lua
  -- GUIDrawMacroEditor, seen on release 3.3.40 and by Larry 2026-11-26).
  local function missingVersion(saved, key)
    local body = assert(tree:match("\nlocal function leaveMissingVersion%(editframe, classid, id, path, key%)\n(.-)\nend\n"),
      "leaveMissingVersion not found")
    local did = { rebuilt = 0 }
    local GSE = { GUI = {}, Library = { [7] = { abc = { Versions = { {}, {}, {} } } } } }
    function GSE.EnsureSequenceLoaded(classid, id)
      if not GSE.Library[classid][id] then GSE.Library[classid][id] = { Versions = { {}, {} } } end
    end
    function GSE.GUI.SelectEditorTreePath(_, path) did.selected = path end
    local timer = { After = function(_, fn) fn() end }
    local frame = { Sequence = saved, ManageTree = function() did.rebuilt = did.rebuilt + 1 end }
    local fn = assert(compile("local GSE, C_Timer = ...\nreturn function(editframe, classid, id, path, key)\n"
      .. body .. "\nend"))(GSE, timer)
    did.left = fn(frame, "7", "abc", { "Sequences", "7", "7,1,abc" }, key)
    did.library = GSE.Library[7].abc
    return did
  end

  it("draws a version the loaded sequence has", function()
    local did = missingVersion({ Versions = { {}, {} } }, "2")
    assert.is_false(did.left)
    assert.is_nil(did.selected)
    assert.are.equal(0, did.rebuilt)
    assert.are.equal(3, #did.library.Versions, "the tree's copy is left alone")
  end)

  it("opens Configuration for a version that was never saved, and drops its node", function()
    local did = missingVersion({ Versions = { {}, {} } }, "3")
    assert.is_true(did.left)
    assert.are.equal("Sequences\0017\0017,1,abc\001config", did.selected)
    assert.are.equal(1, did.rebuilt)
    assert.are.equal(2, #did.library.Versions, "the tree is back on what is saved")
  end)

  it("opens Configuration when no sequence loaded at all", function()
    assert.is_true(missingVersion(nil, "1").left)
    assert.is_true(missingVersion({}, "1").left)
  end)
end)
