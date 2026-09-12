---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field

-- StringFunctions: the table half.
--
-- Small helpers, but load-bearing ones: GSE.Dump writes the text a user copies
-- out of the export box and pastes back in, GSE.FlattenTable is what turns the
-- compiler's nested blocks into the flat step list the button fires, and the
-- sort decides the order every sequence list is shown in. None of it needs the
-- game.
--
-- Run: busted spec/stringtables_spec.lua   /   lua5.1 spec/run51.lua
describe("StringFunctions: tables", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
  end)

  -- Dump's output is Lua source. Loading it back is both the strongest
  -- assertion available and exactly what the import path does with it.
  local function reload(text)
    local chunk = loadstring or load
    local fn = assert(chunk("return " .. text))
    return fn()
  end

  local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end

  describe("GSE.Dump", function()
    it("writes a string value as a quoted string", function()
      assert.equals('{\n\t["a"] = "x"\n}', GSE.Dump({a = "x"}))
    end)

    it("writes numbers and booleans unquoted, and numeric keys in brackets", function()
      assert.equals("{\n\t[1] = true\n}", GSE.Dump({[1] = true}))
      assert.equals('{\n\t["n"] = 42\n}', GSE.Dump({n = 42}))
    end)

    it("nests to any depth", function()
      assert.equals('{\n\t["a"] = {\n\t\t["b"] = {\n\t\t\t["c"] = 1\n\t\t}\n\t}\n}',
        GSE.Dump({a = {b = {c = 1}}}))
    end)

    it("writes an empty table", function()
      assert.equals("{\n\n}", GSE.Dump({}))
    end)

    it("says nil for nothing", function()
      assert.equals("nil\n}", GSE.Dump(nil))
    end)

    it("round-trips a sequence-shaped table", function()
      -- The real contract: what comes out of the export box has to load back as
      -- the same table. This walks the stack-and-cache path with a nested table
      -- that is NOT the last key, which is where the resume logic lives.
      local seq = {
        {Type = "Action", macro = "/cast Alpha", Interval = 250},
        {Type = "Action", macro = "/cast Beta"},
        "trailing"
      }
      assert.is_true(deepEqual(seq, reload(GSE.Dump(seq))))
    end)

    it("round-trips single-line strings exactly", function()
      local t = {KeyPress = "/cast Alpha"}
      assert.equals("/cast Alpha", reload(GSE.Dump(t)).KeyPress)
    end)

    it("writes a multi-line string as a long bracket, gaining a trailing newline", function()
      -- PINNED, NOT ENDORSED. The long-bracket form is written as
      --     [[\n <value> \n]]
      -- and Lua drops the newline immediately after [[ but keeps the one before
      -- ]], so the value comes back one "\n" longer than it went in -- and one
      -- longer again on the next export/import cycle. Dump feeds the export box
      -- (Import.lua, Editor.lua, MacroCompare), so this is real drift in stored
      -- macro bodies. Changing it changes the export format, so it is recorded
      -- here rather than quietly altered.
      local body = "/cast Alpha\n/cast Beta"
      local out = reload(GSE.Dump({KeyPress = body})).KeyPress
      assert.equals(body .. "\n", out)
      assert.is_not.equals(body, out)
    end)
  end)

  describe("GSE.FindGlobalObject and GSE.ObjectExists", function()
    it("walks a dotted path through the global table", function()
      assert.equals(string.format, GSE.FindGlobalObject("string.format"))
      assert.equals(string, GSE.FindGlobalObject("string"))
    end)

    it("is nil when any step of the path is missing", function()
      assert.is_nil(GSE.FindGlobalObject("string.nosuchthing"))
      assert.is_nil(GSE.FindGlobalObject("NoSuchGlobal.at.all"))
    end)

    it("answers existence as a boolean", function()
      assert.is_true(GSE.ObjectExists("string.format"))
      assert.is_false(GSE.ObjectExists("string.nosuchthing"))
    end)
  end)

  describe("GSE.GetTimestamp", function()
    local prevDate, prevServerTime
    before_each(function() prevDate, prevServerTime = _G.date, _G.GetServerTime end)
    after_each(function() _G.date, _G.GetServerTime = prevDate, prevServerTime end)

    it("stamps UTC from the realm clock, not the player's wall clock", function()
      -- Two characters editing the same sequence from different real-world
      -- timezones have to produce comparable stamps, or newer-wins resolution
      -- picks whoever lives furthest east.
      local seenFormat, seenTime
      _G.GetServerTime = function() return 1789000000 end
      _G.date = function(fmt, t) seenFormat, seenTime = fmt, t; return "20260912013000" end
      assert.equals("20260912013000", GSE.GetTimestamp())
      assert.equals("!%Y%m%d%H%M%S", seenFormat, "the ! is what selects gmtime")
      assert.equals(1789000000, seenTime)
    end)
  end)

  describe("GSE.isNaN", function()
    it("is false only for an actual number", function()
      assert.is_false(GSE.isNaN(1))
      assert.is_false(GSE.isNaN(0))
      assert.is_true(GSE.isNaN("1"))
      assert.is_true(GSE.isNaN(nil))
      assert.is_true(GSE.isNaN({}))
    end)
  end)

  describe("GSE.ConcatIndexed", function()
    it("numbers each entry", function()
      assert.equals("1 a\n2 b\n", GSE.ConcatIndexed({"a", "b"}))
    end)

    it("takes the caller's format", function()
      assert.equals("[1]a;[2]b;", GSE.ConcatIndexed({"a", "b"}, "[%d]%s;"))
    end)

    it("is empty for an empty list", function()
      assert.equals("", GSE.ConcatIndexed({}))
    end)

    it("stops at the first hole, as the index frame implies", function()
      assert.equals("1 a\n", GSE.ConcatIndexed({"a", nil, "c"}))
    end)
  end)

  describe("GSE.TableLength and GSE.CountTableLength", function()
    it("count keys, not just the array part", function()
      -- # would say 0 for a sequence's Versions map, which is keyed "1".."n" as
      -- strings once it has been through the wire.
      assert.equals(3, GSE.TableLength({a = 1, b = 2, [1] = 3}))
      assert.equals(0, GSE.TableLength({}))
    end)

    it("are the same count under two names", function()
      local t = {a = 1, b = 2}
      assert.equals(GSE.TableLength(t), GSE.CountTableLength(t))
      assert.equals(0, GSE.CountTableLength({}))
    end)
  end)

  describe("GSE.pairsByKeys", function()
    it("walks a hash table in key order", function()
      local seen = {}
      for k, v in GSE.pairsByKeys({charlie = 3, alpha = 1, bravo = 2}) do
        table.insert(seen, k .. "=" .. v)
      end
      assert.are.same({"alpha=1", "bravo=2", "charlie=3"}, seen)
    end)

    it("takes the caller's comparator", function()
      local seen = {}
      for k in GSE.pairsByKeys({a = 1, b = 2, c = 3}, function(x, y) return x > y end) do
        table.insert(seen, k)
      end
      assert.are.same({"c", "b", "a"}, seen)
    end)

    it("walks nothing for an empty table", function()
      local count = 0
      for _ in GSE.pairsByKeys({}) do count = count + 1 end
      assert.equals(0, count)
    end)
  end)

  describe("GSE.TableDiff", function()
    it("is nil when the two agree", function()
      assert.is_nil(GSE.TableDiff({a = 1, b = "x"}, {a = 1, b = "x"}))
    end)

    it("describes a changed value both ways round", function()
      local d = GSE.TableDiff({a = 1}, {a = 2})
      assert.equals("1 -- not [2]", d.a)
    end)

    it("recurses into nested tables", function()
      local d = GSE.TableDiff({v = {KeyPress = "a"}}, {v = {KeyPress = "b"}})
      assert.equals("a -- not [b]", d.v.KeyPress)
    end)

    it("reports everything when there is nothing to compare against", function()
      local d = GSE.TableDiff({a = 1, b = 2}, nil)
      assert.equals(1, d.a)
      assert.equals(2, d.b)
    end)

    it("reports a whole subtree missing from the other side", function()
      local d = GSE.TableDiff({v = {KeyPress = "a"}}, {})
      assert.equals("a", d.v.KeyPress)
    end)
  end)

  describe("GSE.SafeConcat", function()
    it("joins the numbered entries", function()
      assert.equals("a-b-c", GSE.SafeConcat({"a", "b", "c"}, "-"))
    end)

    it("ignores named keys, which is the safe part", function()
      -- table.concat errors on a table carrying anything but 1..n; the caller
      -- here is handing over sequence data that may have metadata on it.
      assert.equals("a-b", GSE.SafeConcat({"a", "b", Name = "ignored"}, "-"))
    end)

    it("is empty for an empty table", function()
      assert.equals("", GSE.SafeConcat({}, "-"))
    end)

    it("adds no delimiter to a single entry", function()
      assert.equals("a", GSE.SafeConcat({"a"}, "-"))
    end)
  end)

  describe("GSE.NewTable", function()
    it("hands back a fresh table every time", function()
      local a, b = GSE.NewTable(), GSE.NewTable()
      assert.are.same({}, a)
      assert.is_not.equals(a, b)
    end)
  end)

  describe("GSE.FlattenTable", function()
    it("flattens nested block lists into one ordered list of actions", function()
      -- This is what turns the compiler's loop structure into the step list.
      local nested = {{{type = "spell", spell = 1}}, {{type = "spell", spell = 2},
        {{type = "spell", spell = 3}}}}
      local flat = GSE.FlattenTable(nested)
      assert.equals(3, #flat)
      assert.equals(1, flat[1].spell)
      assert.equals(2, flat[2].spell)
      assert.equals(3, flat[3].spell)
    end)

    it("treats a pause as a leaf, since it has no type of its own", function()
      local flat = GSE.FlattenTable({{Interval = 250}, {{type = "spell", spell = 1}}})
      assert.equals(2, #flat)
      assert.equals(250, flat[1].Interval)
    end)

    it("is empty for an empty list", function()
      assert.are.same({}, GSE.FlattenTable({}))
    end)

    it("wraps a single action handed in on its own", function()
      assert.equals(1, #GSE.FlattenTable({type = "spell", spell = 1}))
    end)
  end)

  describe("GSE.SortTableAlphabetical", function()
    it("sorts numbers inside names the way a person reads them", function()
      -- Plain alphabetical puts Seq10 before Seq2, which is wrong in a list of
      -- someone's sequence versions.
      assert.are.same({"Seq1", "Seq2", "Seq10"},
        GSE.SortTableAlphabetical({"Seq10", "Seq2", "Seq1"}))
    end)

    it("sorts plain names alphabetically", function()
      assert.are.same({"alpha", "bravo", "charlie"},
        GSE.SortTableAlphabetical({"charlie", "alpha", "bravo"}))
    end)

    it("sorts in place and hands the same table back", function()
      local t = {"b", "a"}
      assert.equals(t, GSE.SortTableAlphabetical(t))
    end)

    it("compares two names directly", function()
      assert.is_true(GSE.AlphabeticalTableSortAlgorithm("Seq2", "Seq10"))
      assert.is_false(GSE.AlphabeticalTableSortAlgorithm("Seq10", "Seq2"))
    end)
  end)
end)
