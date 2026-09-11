---@diagnostic disable: undefined-global, duplicate-set-field
-- The compiler: a sequence's blocks -> the ordered list the button fires.
--
-- This is the most load-bearing logic in the addon. Everything else stores,
-- syncs or displays a sequence; this decides what actually happens when the key
-- is pressed, and in what order. A StepFunction that expands wrongly is not a
-- cosmetic fault -- it is somebody's rotation silently doing something else.
--
-- It is also pure table-building, so it is measurable without the game: give it
-- blocks, read back the list.
--
-- Run: busted spec/storagecompile_spec.lua   /   lua5.1 spec/run51.lua
describe("Sequence compiler", function()
  local Statics

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/translator")
    Statics = GSE.Static
    -- Pause blocks convert milliseconds to clicks through the live click rate.
    GSE.GetGCD = function() return 1.5 end
    GSE.GetClickRate = function() return 100 end
    -- The compiler runs macro text through the translator on the way out, which
    -- asks the client to resolve spell names. Answer as a client with no such
    -- spell: the translator then passes the text through unchanged, which is
    -- what keeps these assertions about ORDER rather than about localisation.
    GSE.GetSpellInfo = function() return nil end
    GSE.GetSpellId = function() return nil end
  end)

  -- A macro block, identified by its text so the compiled order is readable.
  local function A(macro) return {Type = Statics.Actions.Action, type = "macro", macro = macro} end

  local function loop(stepFunction, repeatCount, ...)
    local l = {Type = Statics.Actions.Loop, StepFunction = stepFunction, Repeat = repeatCount}
    for _, a in ipairs({...}) do table.insert(l, a) end
    return l
  end

  -- The compiled output is a flat list of action tables; read the macro text
  -- out of each so an assertion says what the rotation actually does.
  --
  -- Two field names on purpose: processAction hands back blocks still carrying
  -- `macro`, and CompileTemplate's last pass runs them through the translator,
  -- which emits `macrotext`. Reading both lets one helper describe the order at
  -- either stage.
  local function macros(compiled)
    local out = {}
    for _, v in ipairs(compiled or {}) do out[#out + 1] = v.macrotext or v.macro end
    return out
  end

  describe("GSE.CompileTemplate", function()
    it("compiles nothing from a sequence with no actions", function()
      assert.are.same({}, GSE.CompileTemplate({Actions = {}}))
    end)

    it("keeps sequential order", function()
      local compiled = GSE.CompileTemplate({Actions = {A("/cast One"), A("/cast Two"), A("/cast Three")}})
      assert.are.same({"/cast One", "/cast Two", "/cast Three"}, macros(compiled))
    end)

    it("does not mutate the sequence it was given", function()
      -- CompileTemplate clones first. If it did not, compiling would rewrite
      -- the stored sequence -- buildAction infers and WRITES action.type.
      local seq = {Actions = {{Type = Statics.Actions.Action, macro = "/cast One"}}}
      local before = seq.Actions[1].type
      GSE.CompileTemplate(seq)
      assert.are.equal(before, seq.Actions[1].type, "the stored block is untouched")
    end)
  end)

  describe("StepFunction expansion", function()
    it("Sequential runs each block once, in order", function()
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 1, A("a"), A("b"), A("c")), {}, nil)
      assert.are.same({"a", "b", "c"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("Priority front-loads: 1, then 1-2, then 1-2-3", function()
      -- The triangular expansion is the whole point of Priority -- the first
      -- block gets the most attempts, the last the fewest.
      local compiled = GSE.processAction(
        loop(Statics.Priority, 1, A("a"), A("b"), A("c")), {}, nil)
      assert.are.same({"a", "a", "b", "a", "b", "c"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("ReversePriority mirrors it", function()
      local compiled = GSE.processAction(
        loop(Statics.ReversePriority, 1, A("a"), A("b"), A("c")), {}, nil)
      local got = macros(GSE.FlattenTable(compiled))
      assert.are.equal(6, #got, "same triangular length as Priority")
      assert.are.equal("a", got[1])
    end)

    it("Random uses every block exactly once", function()
      -- Random draws without replacement -- table.remove after each pick -- so
      -- a block cannot be skipped or fire twice in one pass.
      local realRandom = math.random
      math.random = function(_, hi) return hi end -- always take the last
      local compiled = GSE.processAction(
        loop(Statics.Random, 1, A("a"), A("b"), A("c")), {}, nil)
      math.random = realRandom
      local got = macros(GSE.FlattenTable(compiled))
      table.sort(got)
      assert.are.same({"a", "b", "c"}, got)
    end)

    it("Repeat multiplies the whole expansion", function()
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 3, A("a"), A("b")), {}, nil)
      assert.are.same({"a", "b", "a", "b", "a", "b"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("treats a missing or nonsense Repeat as one pass", function()
      for _, r in ipairs({"0", "-4", "notanumber"}) do
        local compiled = GSE.processAction(
          loop(Statics.Sequential, r, A("a"), A("b")), {}, nil)
        assert.are.same({"a", "b"}, macros(GSE.FlattenTable(compiled)),
          "Repeat=" .. tostring(r) .. " should still run once")
      end
    end)
  end)

  describe("blocks that are skipped or nested", function()
    it("a disabled block compiles to nothing", function()
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 1,
          A("a"),
          {Type = Statics.Actions.Action, type = "macro", macro = "b", Disabled = true},
          A("c")), {}, nil)
      assert.are.same({"a", "c"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("a disabled LOOP takes its children with it", function()
      local inner = loop(Statics.Sequential, 1, A("x"), A("y"))
      inner.Disabled = true
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 1, A("a"), inner, A("c")), {}, nil)
      assert.are.same({"a", "c"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("expands a loop inside a loop", function()
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 1,
          A("a"),
          loop(Statics.Sequential, 2, A("x"), A("y")),
          A("c")), {}, nil)
      assert.are.same({"a", "x", "y", "x", "y", "c"}, macros(GSE.FlattenTable(compiled)))
    end)

    it("a nested Priority expands inside a sequential parent", function()
      local compiled = GSE.processAction(
        loop(Statics.Sequential, 1,
          A("a"),
          loop(Statics.Priority, 1, A("x"), A("y"))), {}, nil)
      assert.are.same({"a", "x", "x", "y"}, macros(GSE.FlattenTable(compiled)))
    end)
  end)

  describe("block type inference", function()
    -- A block saved without an explicit type still has to compile to something
    -- castable. The order of these checks is the contract: macro, item, pet,
    -- toy, spell, and an empty macro as the floor.
    local function typeOf(block)
      local compiled = GSE.FlattenTable(
        GSE.processAction(loop(Statics.Sequential, 1, block), {}, nil))
      return compiled[1] and compiled[1].type
    end

    it("infers from whichever field is populated", function()
      assert.are.equal("macro", typeOf({Type = Statics.Actions.Action, macro = "/cast X"}))
      assert.are.equal("item",  typeOf({Type = Statics.Actions.Action, item = "Healthstone"}))
      assert.are.equal("toy",   typeOf({Type = Statics.Actions.Action, toy = "Hearthstone"}))
      assert.are.equal("spell", typeOf({Type = Statics.Actions.Action, spell = "Judgment"}))
    end)

    it("falls back to an empty macro when the block names nothing", function()
      local block = {Type = Statics.Actions.Action}
      assert.are.equal("macro", typeOf(block))
    end)

    it("demotes a spell block with no spell to a macro", function()
      -- Otherwise the button is built to cast a nil spell.
      assert.are.equal("macro", typeOf({Type = Statics.Actions.Action, type = "spell", spell = nil}))
    end)
  end)
end)
