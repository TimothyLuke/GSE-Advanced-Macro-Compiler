-- Where a Tab-menu spell pick lands.
--
-- The rule is the one every editor has: the pick goes AT THE CARET. It does
-- not hop out of a word the caret was left inside, and it does not fall back
-- to the line end from inside a bracket group.
--
-- Splitting a word is a safe thing to allow because the editor already tells
-- the author it happened. A comma list is /castsequence -- /cast takes a
-- single action -- and the translator splits a castsequence on its commas and
-- resolves each element separately, so the two halves of a split word come
-- back in GSEOptions.UNKNOWN. "Bra" and "vo" show red, which is a true
-- statement about them: they are not spells. The author sees it and fixes it.
-- A pick that quietly ignores the caret produces no such signal.
--
-- The functions under test are nested locals inside attachMacroLineBuilder, so
-- they cannot be required. This slices the REAL bodies out of QoL.lua and runs
-- them under stubs, rather than testing a copy that drifts the first time
-- somebody edits the addon and not the spec.
local function readFile(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end

local src = readFile("GSE_QoL/QoL.lua")

-- Each of these is declared at 8-space indent inside the closure, so its own
-- terminating `end` is the first one at that indent. Deeper `end`s (12 spaces
-- and in) belong to the blocks within it.
local function slice(header)
  local s = src:find(header, 1, true)
  assert(s, "not found in QoL.lua: " .. header)
  local e = src:find("\n        end\n", s, true)
  assert(e, "no terminating end for: " .. header)
  return src:sub(s, e + 12) .. "\n"
end

local PRELUDE = [[
local state = ...
local text, cursor, sessionLine = state.text, state.cursor, state.line
local boxIsPlaceholder = false
local widget = {}
local editBox = {
  SetText = function(_, t) text = t end,
  SetCursorPosition = function(_, p) cursor = p end,
}
local function plainFull() return text end
local function touchSession() end
local function pushHistory() end
local function resetGroup() end
local function commitRecolour() end
local function openMenu() end
local MenuResponse = {Close = "Close", Refresh = "Refresh"}
local C_Timer = {After = function() end}
local currentLineText
]]

local BODY = slice("        local function lineBounds()")
  .. slice("        local function lineEndPos()")
  .. slice("        currentLineText = function()")
  .. slice("        local function clauseEndsWithSpell(line)")
  .. slice("        local function isCastSequenceRow(row)")
  .. slice("        local function splice(at, replacing, text)")
  .. slice("        local function pickSpell(name)")

local EPILOGUE = [[
return function(name) pickSpell(name) return text, cursor end
]]

-- 5.1 has loadstring and a `load` that takes a READER function; 5.4 has only
-- load. Picking loadstring first is what makes this run on the CI interpreter.
local loadchunk = loadstring or load

-- `text` with the caret written as | -- easier to read than an integer, and
-- the offset cannot drift out of step with the string it indexes.
local function pick(marked, name, line)
  local caret = marked:find("|", 1, true)
  assert(caret, "mark the caret with | in: " .. marked)
  local plain = marked:sub(1, caret - 1) .. marked:sub(caret + 1)
  local chunk = assert(loadchunk(PRELUDE .. BODY .. EPILOGUE, "=tabharness"))
  local run = chunk({text = plain, cursor = caret - 1, line = line or 0})
  return run(name)
end

describe("Tab menu spell placement", function()
  describe("lands at the caret", function()
    -- The change this spec exists for. A caret parked inside a word splits it;
    -- it does not get quietly moved to the front of that word. Both halves
    -- come back red from the translator, which is a true statement about them.
    it("splits a word rather than stepping around it", function()
      assert.equals("/castsequence Alpha, Bra, Pick, vo",
        (pick("/castsequence Alpha, Bra|vo", "Pick")))
    end)

    it("drops between two spells", function()
      assert.equals("/castsequence Alpha, Pick, Bravo",
        (pick("/castsequence Alpha, |Bravo", "Pick")))
    end)

    -- Deliberate. A caret inside a conditional produces nonsense, and the
    -- author is the one who put it there. The old behaviour hid the mistake by
    -- silently appending at the line end instead, which is the failure this
    -- spec guards against coming back.
    --
    -- The separator is a comma here, because inside a condition that is what a
    -- comma is: the conditional separator. A ';' would end the clause instead
    -- -- the row splits into alternatives on ';' before the brackets are read
    -- -- leaving "[com" unterminated. The insert still happens exactly where
    -- the caret was.
    it("splits a bracket group, because that is where the caret was", function()
      assert.equals("/cast [com, Pick, bat] Foo", (pick("/cast [com|bat] Foo", "Pick")))
    end)

    it("leaves the caret just after the name it inserted", function()
      local _, caret = pick("/castsequence Alpha, |Bravo", "Pick")
      assert.equals(#"/castsequence Alpha, Pick", caret)
    end)
  end)

  describe("the line end is the fallback, not the destination", function()
    it("appends when the caret is already at the end", function()
      assert.equals("/castsequence Alpha, Pick", (pick("/castsequence Alpha|", "Pick")))
    end)

    it("starts a blank row with the command", function()
      assert.equals("/cast Pick", (pick("|", "Pick")))
    end)

    it("does not add a second command to a row that has one", function()
      assert.equals("/cast Pick", (pick("/cast |", "Pick")))
    end)

    it("stays in front of a , nil ender", function()
      assert.equals("/castsequence Alpha, Pick, nil",
        (pick("/castsequence Alpha, nil|", "Pick")))
    end)

    it("spaces after a bracket group instead of running into it", function()
      assert.equals("/cast [combat] Pick", (pick("/cast [combat]|", "Pick")))
    end)
  end)

  -- A comma list is /castsequence syntax. Every other command casts one thing
  -- per clause, so a comma there is not two casts -- it is a single spell name
  -- that cannot resolve, and because the translator only splits castsequence
  -- on commas, nothing ever tells the author. ';' is the else, and it is how a
  -- /cast row legitimately holds more than one spell.
  describe("joins with the syntax the command actually has", function()
    it("uses an else on a /cast row", function()
      assert.equals("/cast Alpha; Pick", (pick("/cast Alpha|", "Pick")))
    end)

    it("uses an else on any other non-sequence command", function()
      assert.equals("/use Alpha; Pick", (pick("/use Alpha|", "Pick")))
    end)

    it("elses in front of the spell it was dropped before", function()
      assert.equals("/cast [combat] Pick; Foo", (pick("/cast [combat] |Foo", "Pick")))
    end)

    -- Nothing for a ';' to be the else OF until there is a command.
    it("does not else in front of the command word", function()
      assert.equals("Pick /cast Foo", (pick("|/cast Foo", "Pick")))
    end)

    it("still honours a comma the author typed themselves", function()
      assert.equals("/cast Alpha, Pick", (pick("/cast Alpha, |", "Pick")))
    end)

    it("a reset= castsequence still reads as a castsequence row", function()
      assert.equals("/castsequence reset=combat Alpha, Pick",
        (pick("/castsequence reset=combat Alpha|", "Pick")))
    end)
  end)

  describe("multi-row text", function()
    it("acts on the session's row, not the first one", function()
      assert.equals("row zero\n/castsequence Alpha, Pick, Bravo\nrow two",
        (pick("row zero\n/castsequence Alpha, |Bravo\nrow two", "Pick", 1)))
    end)

    it("does not spill onto the next row", function()
      assert.equals("/cast Alpha; Pick\nrow one", (pick("/cast Alpha|\nrow one", "Pick", 0)))
    end)
  end)
end)
