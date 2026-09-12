---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field

-- StringFunctions: the text half.
--
-- Everything a sequence carries -- macro bodies, notes, variable code -- goes
-- through here on the way in from an import, the editor, or another client's
-- locale. There is no game state involved: a string goes in and a string comes
-- out, so every branch is reachable from a spec.
--
-- Run: busted spec/stringmarkup_spec.lua   /   lua5.1 spec/run51.lua
describe("StringFunctions: text", function()
  local Statics

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    Statics = GSE.Static
  end)

  describe("GSE.UnEscapeString", function()
    it("passes a non-string straight back", function()
      assert.equals(7, GSE.UnEscapeString(7))
      assert.is_nil(GSE.UnEscapeString(nil))
    end)

    it("strips colour markup", function()
      assert.equals("/cast Alpha", GSE.UnEscapeString("|cff00ff00/cast Alpha|r"))
      assert.equals("/cast Alpha", GSE.UnEscapeString("|CFF00FF00/cast Alpha|r"), "upper case too")
    end)

    it("strips markup that has been doubled by a round trip through SetText", function()
      -- An editor that re-escapes what it was given turns |c into ||c. Stripping
      -- the doubled form first matters: collapsing || to | on the way past would
      -- otherwise leave a bare |cff00ff00 behind.
      assert.equals("/cast Alpha", GSE.UnEscapeString("||cff00ff00/cast Alpha||r"))
    end)

    it("keeps the text of a link and drops the link itself", function()
      assert.equals("Alpha", GSE.UnEscapeString("|Hspell:123|hAlpha|h"))
    end)

    it("drops inline textures and raid target icons", function()
      assert.equals(" Go", GSE.UnEscapeString("|TInterface\\Icons\\x:0|t Go"))
      assert.equals(" Go", GSE.UnEscapeString("{star} Go"))
    end)

    it("collapses a doubled pipe to the single pipe it stands for", function()
      assert.equals("a|b", GSE.UnEscapeString("a||b"))
    end)
  end)

  describe("GSE.UnEscapeTableRecursive", function()
    it("cleans strings at every depth, in the hash part and the array part", function()
      local t = {name = "|cff00ff00Alpha|r", {"|cff00ff00One|r"}, nested = {deep = {"|cff00ff00Two|r"}}}
      GSE.UnEscapeTableRecursive(t)
      assert.equals("Alpha", t.name)
      assert.equals("One", t[1][1])
      assert.equals("Two", t.nested.deep[1])
    end)

    it("leaves non-strings alone", function()
      local t = {n = 1, b = true}
      GSE.UnEscapeTableRecursive(t)
      assert.equals(1, t.n)
      assert.is_true(t.b)
    end)

    it("is what the two deprecated names now do", function()
      -- GSE.UnEscapeSequence and GSE.UnEscapeTable are kept for older callers.
      assert.equals("Alpha", GSE.UnEscapeTable({"|cff00ff00Alpha|r"})[1])
      assert.equals("Alpha", GSE.UnEscapeSequence({"|cff00ff00Alpha|r"})[1])
    end)
  end)

  describe("GSE.DecodeEditorText", function()
    it("passes a non-string straight back", function()
      assert.equals(42, GSE.DecodeEditorText(42))
    end)

    it("returns text with no markup in it untouched", function()
      -- The fast path matters: this runs over every string in a sequence.
      assert.equals("/cast Alpha", GSE.DecodeEditorText("/cast Alpha"))
    end)

    it("strips colour markup, doubled or not", function()
      assert.equals("/cast Alpha", GSE.DecodeEditorText("|cff00ff00/cast Alpha|r"))
      assert.equals("/cast Alpha", GSE.DecodeEditorText("||cff00ff00/cast Alpha||r"))
    end)

    it("collapses doubled pipes", function()
      assert.equals("a|b", GSE.DecodeEditorText("a||b"))
    end)

    describe("when IndentationLib can decode", function()
      local prev
      before_each(function() prev = IndentationLib.decode end)
      after_each(function() IndentationLib.decode = prev end)

      it("uses its answer", function()
        IndentationLib.decode = function() return "/cast Decoded" end
        assert.equals("/cast Decoded", GSE.DecodeEditorText("|cff00ff00anything|r"))
      end)

      it("falls back to stripping when it throws", function()
        -- IndentationLib is a third-party addon; whatever it does to a string
        -- it did not produce is not allowed to take the editor down.
        IndentationLib.decode = function() error("boom") end
        assert.equals("/cast Alpha", GSE.DecodeEditorText("|cff00ff00/cast Alpha|r"))
      end)

      it("falls back to stripping when it hands back something that is not a string", function()
        IndentationLib.decode = function() return {} end
        assert.equals("/cast Alpha", GSE.DecodeEditorText("|cff00ff00/cast Alpha|r"))
      end)
    end)
  end)

  describe("GSE.DecodeMacroEditorText", function()
    it("repairs a slash command whose slash was eaten on a later line", function()
      assert.equals("/cast A\n/cast B", GSE.DecodeMacroEditorText("/cast A\n|cast B"))
    end)

    it("repairs one that is indented", function()
      assert.equals("/cast A\n  /cast B", GSE.DecodeMacroEditorText("/cast A\n  |cast B"))
    end)

    it("repairs the first line too", function()
      -- The first-line pattern used to read (^[ \t]*), where the ^ sits inside a
      -- capture group and so is a LITERAL caret, not an anchor -- it only ever
      -- matched text that really began with "^". A one-line macro that lost its
      -- slash therefore stayed broken while every line below it was repaired.
      assert.equals("/cast Alpha", GSE.DecodeMacroEditorText("|cast Alpha"))
      assert.equals("  /cast Alpha", GSE.DecodeMacroEditorText("  |cast Alpha"))
    end)

    it("leaves a pipe that is not leading a command", function()
      assert.equals("/cast [mod:shift] A", GSE.DecodeMacroEditorText("/cast [mod:shift] A"))
    end)

    it("passes a non-string straight back", function()
      assert.equals(42, GSE.DecodeMacroEditorText(42))
    end)
  end)

  describe("GSE.GetMacroEditorTextLength", function()
    -- The macro character limit is what this feeds, and a note line costs the
    -- author nothing in game, so it must not count against them.
    it("counts the text", function()
      assert.equals(15, GSE.GetMacroEditorTextLength("/cast A\n/cast B"))
    end)

    it("does not count whole-line Lua notes", function()
      assert.equals(7, GSE.GetMacroEditorTextLength("-- note\n/cast A"))
      assert.equals(7, GSE.GetMacroEditorTextLength("   -- indented note\n/cast A"))
    end)

    it("counts a trailing comment that is not the whole line", function()
      assert.equals(#"/cast A -- why", GSE.GetMacroEditorTextLength("/cast A -- why"))
    end)

    it("is zero for nothing at all", function()
      assert.equals(0, GSE.GetMacroEditorTextLength(""))
      assert.equals(0, GSE.GetMacroEditorTextLength(nil))
    end)
  end)

  describe("GSE.StoreMacroEditorText", function()
    local prevCompile
    before_each(function() prevCompile = GSE.CompileMacroText end)
    after_each(function() GSE.CompileMacroText = prevCompile end)

    it("is empty for anything that is not text", function()
      GSE.CompileMacroText = nil
      assert.equals("", GSE.StoreMacroEditorText(nil))
    end)

    it("runs a macro body through the translator", function()
      local seen
      GSE.CompileMacroText = function(text, mode) seen = mode; return text .. " (compiled)" end
      assert.equals("/cast Alpha (compiled)", GSE.StoreMacroEditorText("/cast Alpha"))
      assert.equals(Statics.TranslatorMode.ID, seen, "IDs by default")
    end)

    it("passes the caller's translator mode through", function()
      GSE.CompileMacroText = function(text, mode) return text .. "|" .. tostring(mode) end
      assert.is_truthy(GSE.StoreMacroEditorText("/cast Alpha", Statics.TranslatorMode.String)
        :find(tostring(Statics.TranslatorMode.String), 1, true))
    end)

    it("leaves a body that is not macro text alone", function()
      -- The NAME of an in-game macro, or a "=" GSE variable. Neither is a list
      -- of slash commands, so there is nothing for the translator to resolve.
      GSE.CompileMacroText = function() error("must not be called") end
      assert.equals("MyMacroName", GSE.StoreMacroEditorText("MyMacroName"))
      assert.equals("=variable", GSE.StoreMacroEditorText("=variable"))
    end)
  end)

  describe("GSE.SanitizeSequenceEditorMarkup", function()
    it("says no for anything that is not a table", function()
      assert.is_false(GSE.SanitizeSequenceEditorMarkup("string"))
      assert.is_false(GSE.SanitizeSequenceEditorMarkup(nil))
    end)

    it("repairs macro keys wherever they sit", function()
      local node = {macrotext = "|cff00ff00/cast Alpha|r"}
      assert.is_true(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("/cast Alpha", node.macrotext)
    end)

    it("treats every string inside KeyPress and KeyRelease as macro text", function()
      -- Those two are arrays of raw command lines, so the key names are indexes
      -- rather than anything this could recognise.
      local node = {KeyPress = {"|cff00ff00/cast Alpha|r"}, KeyRelease = {"/cast A\n|cast B"}}
      assert.is_true(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("/cast Alpha", node.KeyPress[1])
      assert.equals("/cast A\n/cast B", node.KeyRelease[1])
    end)

    it("repairs a variable's code as editor text, not as macro text", function()
      -- A GSE variable is Lua. Putting a slash back on a line that starts with
      -- a pipe would be wrong there.
      local node = {funct = "|cff00ff00return true|r"}
      assert.is_true(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("return true", node.funct)
    end)

    it("leaves strings it has no rule for", function()
      local node = {Author = "|cff00ff00Someone|r"}
      assert.is_false(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("|cff00ff00Someone|r", node.Author)
    end)

    it("says no when there was nothing to repair", function()
      assert.is_false(GSE.SanitizeSequenceEditorMarkup({macrotext = "/cast Alpha"}))
    end)

    it("reaches all the way down a sequence", function()
      local node = {Actions = {{Type = Statics.Actions.Action, macrotext = "|cff00ff00/cast Alpha|r"}}}
      assert.is_true(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("/cast Alpha", node.Actions[1].macrotext)
    end)

    it("strips a #showtooltip once the markup is out of the way", function()
      -- Order matters: the directive match has to see plain text, so the markup
      -- repair above has to have happened first.
      local node = {Type = Statics.Actions.Action, macrotext = "|cff00ff00#showtooltip\n/cast Alpha|r"}
      assert.is_true(GSE.SanitizeSequenceEditorMarkup(node))
      assert.equals("/cast Alpha", node.macrotext)
    end)
  end)

  describe("GSE.SplitMeIntoLines", function()
    it("splits on both line ending styles", function()
      assert.are.same({"a", "b"}, GSE.SplitMeIntoLines("a\nb"))
      assert.are.same({"a", "b"}, GSE.SplitMeIntoLines("a\r\nb"))
    end)

    it("is an empty list for nothing", function()
      assert.are.same({}, GSE.SplitMeIntoLines(nil))
    end)

    it("describes a non-string rather than erroring on it", function()
      assert.are.same({"42"}, GSE.SplitMeIntoLines(42))
    end)
  end)

  describe("GSE.lines", function()
    it("appends to a table the caller owns", function()
      local t = {"existing"}
      GSE.lines(t, "a\nb")
      assert.are.same({"existing", "a", "b"}, t)
    end)

    it("describes a non-string rather than erroring on it", function()
      local t = {}
      GSE.lines(t, 42)
      assert.are.same({"42"}, t)
      local u = {}
      GSE.lines(u, nil)
      assert.are.same({""}, u)
    end)
  end)

  describe("GSE.SplitCastSequence", function()
    it("splits on commas", function()
      assert.are.same({"A", "B", "C"}, GSE.SplitCastSequence("A,B,C"))
    end)

    it("does not split inside a conditional, where commas separate conditions", function()
      -- This is the whole reason it exists: a plain split on "," tears
      -- [mod:shift,@focus] into two useless halves.
      assert.are.same({"[mod:shift,@focus]A", "B"}, GSE.SplitCastSequence("[mod:shift,@focus]A,B"))
    end)

    it("handles several conditionals in one sequence", function()
      assert.are.same({"[mod:alt,@focus]A", "[mod:shift,@mouseover]B"},
        GSE.SplitCastSequence("[mod:alt,@focus]A,[mod:shift,@mouseover]B"))
    end)

    it("gives back the whole string when there is nothing to split", function()
      assert.are.same({"A"}, GSE.SplitCastSequence("A"))
      assert.are.same({""}, GSE.SplitCastSequence(""))
    end)
  end)

  describe("GSE.FixQuotes", function()
    it("replaces the quotes a word processor substitutes", function()
      -- Pasted from a forum post or a document, these are not valid Lua and the
      -- import fails to load with no useful message.
      assert.equals("'a'", GSE.FixQuotes("\226\128\152a\226\128\153"))
      assert.equals('a"', GSE.FixQuotes("a\226\128\157"))
    end)

    it("leaves straight quotes alone", function()
      assert.equals([[a'b"c]], GSE.FixQuotes([[a'b"c]]))
    end)
  end)

  describe("GSE.CleanStrings", function()
    it("removes the sound and error-frame boilerplate GSE never needed", function()
      assert.equals("\n/cast A", GSE.CleanStrings("/console Sound_EnableSFX 0\n/cast A"))
      assert.equals("\n/cast A", GSE.CleanStrings("/script UIErrorsFrame:Hide()\n/cast A"))
    end)

    it("empties a line that is nothing but an empty quoted string", function()
      assert.equals("", GSE.CleanStrings([[""]]))
    end)

    it("leaves a real command alone", function()
      assert.equals("/cast Alpha", GSE.CleanStrings("/cast Alpha"))
    end)
  end)

  describe("GSE.CleanStringsArray and GSE.CleanMacroVersion", function()
    it("cleans every line of an array", function()
      local t = {"/console Sound_EnableSFX 0", "/cast Alpha"}
      GSE.CleanStringsArray(t)
      assert.equals("", t[1])
      assert.equals("/cast Alpha", t[2])
    end)

    it("cleans both halves of a version", function()
      local version = {KeyPress = {"/console Sound_EnableSFX 1"}, KeyRelease = {"/script UIErrorsFrame:Clear()"}}
      GSE.CleanMacroVersion(version)
      assert.equals("", version.KeyPress[1])
      assert.equals("", version.KeyRelease[1])
    end)

    it("leaves a version with neither half alone", function()
      assert.are.same({}, GSE.CleanMacroVersion({}))
    end)
  end)

  describe("GSE.StripControlandExtendedCodes", function()
    it("keeps ordinary text", function()
      assert.equals("/cast Alpha", GSE.StripControlandExtendedCodes("/cast Alpha"))
    end)

    it("keeps accented and non-Latin characters", function()
      -- Sequence names and spell names arrive in every client locale.
      assert.equals("Fl\195\169au", GSE.StripControlandExtendedCodes("Fl\195\169au"))
    end)

    it("turns a tab into a space", function()
      assert.equals("a b", GSE.StripControlandExtendedCodes("a\tb"))
    end)

    it("keeps newlines", function()
      assert.equals("a\nb", GSE.StripControlandExtendedCodes("a\nb"))
    end)

    it("keeps a carriage return without duplicating what follows it", function()
      -- The CR branch used to read str:sub(i, str:byte(10)) -- the BYTE VALUE at
      -- position 10 used as an end index -- so everything from the CR to that
      -- arbitrary offset was copied in, and then walked again by the loop. A
      -- CRLF import came back with a duplicate of its own tail.
      assert.equals("a\rb", GSE.StripControlandExtendedCodes("a\rb"))
      assert.equals("/cast Alpha\r\n/cast Beta",
        GSE.StripControlandExtendedCodes("/cast Alpha\r\n/cast Beta"))
    end)

    it("turns a non-breaking space into a space", function()
      -- Pasted from a browser, where it is invisible and breaks the parse.
      assert.equals("a  b", GSE.StripControlandExtendedCodes("a\194\160b"))
    end)

    it("turns other control characters into spaces", function()
      assert.equals("a b", GSE.StripControlandExtendedCodes("a\001b"))
    end)
  end)

  describe("GSE.TrimWhiteSpace", function()
    it("trims both ends and nothing in between", function()
      assert.equals("a b", GSE.TrimWhiteSpace("  a b  "))
      assert.equals("", GSE.TrimWhiteSpace("   "))
    end)
  end)

  describe("GSE.RemoveComments", function()
    it("drops whole-line comments and blank lines", function()
      assert.equals("/cast A\n/cast B", GSE.RemoveComments("-- note\n/cast A\n\n  -- more\n/cast B"))
    end)

    it("keeps a trailing comment, which is part of a working line", function()
      assert.equals("/cast A -- why", GSE.RemoveComments("/cast A -- why"))
    end)

    it("sees through markup to find the comment", function()
      -- A variable edited in the GUI comes back coloured; the -- is still a
      -- comment underneath it.
      assert.equals("", GSE.RemoveComments("|cff00ff00-- note|r"))
    end)

    it("takes a table of lines as well as a string", function()
      assert.equals("/cast A", GSE.RemoveComments({"-- note", "/cast A"}))
    end)

    it("gives nothing back for nothing", function()
      assert.equals("", GSE.RemoveComments(""))
      assert.is_nil(GSE.RemoveComments(nil))
    end)
  end)

  describe("GSE.DecodeTimeStamp", function()
    it("cuts a 14-digit stamp into its parts", function()
      local t = GSE.DecodeTimeStamp("20260912013000")
      assert.equals("2026", t.year)
      assert.equals("09", t.month)
      assert.equals("12", t.day)
      assert.equals("01", t.hour)
      assert.equals("30", t.minute)
      assert.equals("00", t.sec)
    end)
  end)

  describe("GSE.GUIGetColour", function()
    it("reads the rgb out of an aarrggbb escape", function()
      local r, g, b = GSE.GUIGetColour("|cff00ff00")
      assert.equals(0, r)
      assert.equals(1, g)
      assert.equals(0, b)
    end)

    it("scales to 0-1, which is what SetTextColor wants", function()
      local r, g, b = GSE.GUIGetColour("|cff8040c0")
      assert.equals(128 / 255, r)
      assert.equals(64 / 255, g)
      assert.equals(192 / 255, b)
    end)
  end)

  describe("GSE.GetMacroStringFormat", function()
    local prevCVar, prevState
    before_each(function()
      prevCVar, prevState = _G.C_CVar, GSEOptions.CvarActionButtonState
      _G.C_CVar = {GetCVar = function() return "0" end}
      GSEOptions.CvarActionButtonState = nil
    end)
    after_each(function()
      _G.C_CVar = prevCVar
      GSEOptions.CvarActionButtonState = prevState
    end)

    it("prefers the stored state when there is one", function()
      GSEOptions.CvarActionButtonState = "UP"
      assert.equals("UP", GSE.GetMacroStringFormat())
    end)

    it("falls back to the CVar", function()
      -- Note what this actually asks: GetCVar returns the STRING "0" or "1",
      -- and both are truthy in Lua, so any answer at all reads as DOWN. Only an
      -- unset CVar produces UP. Pinned as it behaves today.
      assert.equals("DOWN", GSE.GetMacroStringFormat())
      _G.C_CVar = {GetCVar = function() return "1" end}
      assert.equals("DOWN", GSE.GetMacroStringFormat())
      _G.C_CVar = {GetCVar = function() return nil end}
      assert.equals("UP", GSE.GetMacroStringFormat())
    end)
  end)
end)
