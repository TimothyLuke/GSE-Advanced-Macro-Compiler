-- A sequence's notes are edited as a macro's and a variable's are (#2128).
--
-- GSE.Tools keeps MetaData.Notes (markdown) as the notes and rebuilds
-- MetaData.Help, their rendering, from them on every write. A sequence's box
-- typed into Help, so once a sequence had Notes an edit in game was thrown
-- away, and the editor hid that by locking the box whenever Notes were there.
-- Now the box edits Notes, locks only on notes GSE.Tools has rendered (Help
-- and Notes both there), and a sequence from before Notes starts from the Help
-- typed in game.
local function readSource(path)
  local fh = assert(io.open(path, "rb"), path .. " is missing")
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function isEmpty(value) return value == nil or value == "" end

describe("A sequence's notes", function()
  local editor = readSource("GSE_GUI/Editor_Metadata.lua")
  local saved

  before_each(function()
    saved = { GSE = _G.GSE, GameFontNormalSmall = _G.GameFontNormalSmall }
    _G.GSE = { isEmpty = isEmpty, CreateToolTip = function() end, ClearTooltip = function() end }
    _G.GameFontNormalSmall = { GetFont = function() return "font", 10, "" end }
  end)
  after_each(function()
    _G.GSE, _G.GameFontNormalSmall = saved.GSE, saved.GameFontNormalSmall
  end)

  describe("shown read-only", function()
    local rendered
    before_each(function()
      local body = assert(editor:match("\nlocal function renderedNotesText%(sequence%)\n(.-)\nend\n"),
        "renderedNotesText not found")
      rendered = assert((loadstring or load)("return function(sequence)\n" .. body .. "\nend"))()
    end)

    it("only once GSE.Tools has rendered them: Help and Notes both there", function()
      assert.are.equal("|cffffd100Rendered|r", rendered({ MetaData = { Notes = "**Rendered**", Help = "|cffffd100Rendered|r" } }))
    end)

    it("not for notes with no rendering yet, so they can still be typed", function()
      assert.is_nil(rendered({ MetaData = { Notes = "typed in game" } }))
      assert.is_nil(rendered({ MetaData = { Notes = "typed in game", Help = "" } }))
    end)

    it("not for a sequence from before Notes, with only the Help typed in game", function()
      assert.is_nil(rendered({ MetaData = { Help = "old help" } }))
      assert.is_nil(rendered({ MetaData = { Help = "old help", Notes = "" } }))
    end)

    it("not for a sequence with neither, or none", function()
      assert.is_nil(rendered({ MetaData = {} }))
      assert.is_nil(rendered({}))
      assert.is_nil(rendered(nil))
    end)
  end)

  it("page edits Notes, starts from the Help typed in game, and drops Help on an edit", function()
    local page = assert(editor:match("\nlocal function GUIDrawNotesEditor%(editframe, container%)\n(.-)\nend\n"),
      "GUIDrawNotesEditor not found")
    assert.truthy(page:find('        key = "Notes",\n', 1, true))
    assert.truthy(page:find("        seed = editframe.Sequence.MetaData.Help,\n", 1, true))
    assert.truthy(page:find('        stale = "Help",\n', 1, true))
    assert.truthy(page:find("        readOnly = renderedNotesText(editframe.Sequence),\n", 1, true))
    assert.is_nil(editor:find('key = "Help"', 1, true), "something still types into Help")
    assert.is_nil(editor:find("websiteNotesText", 1, true), "the old rule, Notes there = read-only, is still about")
  end)

  describe("box", function()
    local addBox, box, added

    before_each(function()
      local body = assert(editor:match(
        "\nlocal function addHelpInformationBox%(editframe, container, height, opts%)\n(.-)\nend\n"),
        "addHelpInformationBox not found")
      box = { callbacks = {} }
      function box:SetLabel() end
      function box:SetNumLines(lines) self.lines = lines end
      function box:SetFullWidth() end
      function box:DisableButton() end
      function box:SetText(text) self.text = text end
      function box:SetCallback(name, fn) self.callbacks[name] = fn end
      local UI = { Create = function(_, kind) assert(kind == "MultiLineEditBox") return box end }
      addBox = assert((loadstring or load)(
        "local UI, T, HELP_MIN_LINES, HELP_PANEL_LABEL_HEIGHT = ...\n"
        .. "return function(editframe, container, height, opts)\n" .. body .. "\nend"))(
        UI, function(text) return text end, 6, 22)
      added = {}
    end)

    local function draw(opts)
      return addBox({}, { AddChild = function(_, child) added[#added + 1] = child end }, 400, opts)
    end

    it("of a sequence from before Notes shows its Help, and writes nothing until it is typed in", function()
      local meta = { Help = "old help" }
      draw({ meta = meta, key = "Notes", seed = meta.Help, stale = "Help" })
      assert.are.equal("old help", box.text)
      assert.are.same({ Help = "old help" }, meta)
      assert.are.equal(box, added[1])
    end)

    it("typed in writes Notes and drops the Help that no longer says it", function()
      local meta = { Help = "old help" }
      draw({ meta = meta, key = "Notes", seed = meta.Help, stale = "Help" })
      box.callbacks.OnTextChanged(box, "OnTextChanged", "old help, and more")
      assert.are.same({ Notes = "old help, and more" }, meta)
    end)

    it("shows the Notes where there are some, whatever Help says", function()
      local meta = { Notes = "the notes", Help = "" }
      draw({ meta = meta, key = "Notes", seed = meta.Help, stale = "Help" })
      assert.are.equal("the notes", box.text)
    end)

    it("is empty for a sequence with neither", function()
      draw({ meta = {}, key = "Notes", stale = "Help" })
      assert.are.equal("", box.text)
    end)

    it("of a macro or a variable is as it was: Notes typed, nothing else touched", function()
      local meta = { Notes = "macro notes", Helplink = "https://example.com" }
      draw({ meta = meta, key = "Notes" })
      assert.are.equal("macro notes", box.text)
      box.callbacks.OnTextChanged(box, "OnTextChanged", "changed")
      assert.are.same({ Notes = "changed", Helplink = "https://example.com" }, meta)
    end)
  end)
end)

describe("An element's help in the list another player is sent", function()
  local serialisation = readSource("GSE/API/Serialisation.lua")
  local summaryHelp, saved

  before_each(function()
    saved = _G.GSE
    _G.GSE = { isEmpty = isEmpty }
    local body = assert(serialisation:match("\nlocal function summaryHelp%(meta%)\n(.-)\nend\n"), "summaryHelp not found")
    summaryHelp = assert((loadstring or load)("return function(meta)\n" .. body .. "\nend"))()
  end)
  after_each(function() _G.GSE = saved end)

  it("is what GSE.Tools rendered, else the notes as typed", function()
    assert.are.equal("rendered", summaryHelp({ Help = "rendered", Notes = "**typed**" }))
    assert.are.equal("typed", summaryHelp({ Notes = "typed" }))
    assert.are.equal("typed", summaryHelp({ Notes = "typed", Help = "" }))
    assert.are.equal("old help", summaryHelp({ Help = "old help" }))
    assert.is_nil(summaryHelp({}))
    assert.is_nil(summaryHelp(nil))
  end)

  it("is read the same way for a sequence, a variable and a macro", function()
    local summary = assert(serialisation:match("\nfunction GSE%.GetShareableSummary%(%)\n(.-)\nend\n"),
      "GSE.GetShareableSummary not found")
    assert.truthy(summary:find("Help = summaryHelp(seq.MetaData),", 1, true))
    assert.truthy(summary:find("Help = summaryHelp(v.MetaData),", 1, true))
    assert.truthy(summary:find("Help = summaryHelp(m.MetaData),", 1, true))
    assert.is_nil(summary:find("MetaData.Help", 1, true))
    assert.is_nil(summary:find("MetaData.Notes", 1, true))
  end)
end)
