---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field

-- GSE.CreateGSE3Button: the compiled step list -> the secure button.
--
-- This is the last hop before the game. The compiler decides what the rotation
-- does (storagecompile_spec); this decides whether any of that survives the
-- trip onto a SecureActionButton. Everything it does is table work in disguise:
-- CreateFrame hands back a table, SetAttribute writes a key on it, and Execute
-- is handed a string of Lua that the secure environment runs to rebuild the
-- step list on the other side. So a recording frame plus a sandboxed run of
-- that string measures the whole path without the game.
--
-- The Execute payload is not mocked or re-implemented here. It is the literal
-- source the addon ships, run against the small set of globals the secure
-- environment provides (newtable, tinsert, string, tonumber, ipairs). If the
-- encoding and the snippet ever stop agreeing, the round trip breaks here.
--
-- Run: busted spec/storagebutton_spec.lua   /   lua5.1 spec/run51.lua
describe("GSE3 button build", function()
  local prevCreateFrame, prevUpdateIcon, prevPrint, prevLmeta
  local realUpdateIcon
  local frames, printed, iconCalls

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    -- WoW's own aliases. Storage.lua uses the short forms the client provides;
    -- 5.4 has no global unpack at all, so this is also what lets the same spec
    -- run on both interpreters.
    _G.tinsert = _G.tinsert or table.insert
    _G.unpack = _G.unpack or table.unpack
    string.join = string.join or function(sep, ...) return table.concat({...}, sep) end
    -- before_each replaces GSE.UpdateIcon with a recorder; keep a handle on
    -- the real one for the icon-index tests below.
    realUpdateIcon = GSE.UpdateIcon
    GSE.WagoAnalytics = GSE.WagoAnalytics or {Switch = function() end}
  end)

  -- A frame is a table; record every write rather than only the survivors, so
  -- a SetAttribute(k, nil) -- which leaves no trace in the table -- is still
  -- observable. Clearing macro when macrotext arrives is exactly that shape.
  local CLEARED = {}
  local function makeFrame(name)
    local f = {name = name, attrs = {}, sets = {}, executed = {}, wrapped = {}, clicks = nil}
    function f:SetAttribute(k, v)
      self.attrs[k] = v
      table.insert(self.sets, {key = k, value = v == nil and CLEARED or v})
    end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:GetName() return self.name end
    function f:RegisterForClicks(...) self.clicks = {...} end
    function f:Execute(s) table.insert(self.executed, s) end
    function f:WrapScript(_, handler, body) table.insert(self.wrapped, {handler = handler, body = body}) end
    function f:IsForbidden() return false end
    return f
  end

  -- Was SetAttribute(key, nil) called at any point?
  local function wasCleared(frame, key)
    for _, s in ipairs(frame.sets) do
      if s.key == key and s.value == CLEARED then return true end
    end
    return false
  end

  -- Run a chunk with a supplied environment on either interpreter. 5.1 has no
  -- load(src, name, mode, env) -- that is 5.2+ -- and 5.4 has no setfenv.
  local function runIn(src, env)
    if setfenv then
      local fn = assert(loadstring(src))
      setfenv(fn, env)
      return fn()
    end
    return assert(load(src, "executestring", "t", env))()
  end

  -- Replay the button's Execute payload through the globals the secure
  -- environment actually exposes, and hand back what it rebuilt.
  local function replay(frame)
    assert.equals(1, #frame.executed, "the step list is pushed exactly once per build")
    local env = {
      -- WoW's secure newtable(...) is a constructor: it returns a table OF its
      -- arguments. A zero-argument stub would hand back an empty payload and
      -- every round-trip assertion below would pass vacuously.
      newtable = function(...) return {...} end,
      tinsert = table.insert,
      string = string,
      tonumber = tonumber,
      ipairs = ipairs
    }
    runIn(frame.executed[1], env)
    return env.spelllist, env.maxsequences
  end

  -- The secure side sees iterations of steps; SequencesExec keeps one flat
  -- list. Flatten so an assertion can talk about step N of the rotation.
  local function flatten(iterations)
    local out = {}
    for _, iter in ipairs(iterations) do
      for _, step in ipairs(iter) do out[#out + 1] = step end
    end
    return out
  end

  local function build(spelllist, combatReset, name)
    name = name or "TESTBUTTON"
    GSE.CreateGSE3Button(spelllist, name, combatReset)
    assert.equals(0, #printed, "the build reported a broken macro: " .. table.concat(printed, " / "))
    return _G[name]
  end

  before_each(function()
    frames, printed, iconCalls = {}, {}, {}
    prevCreateFrame = _G.CreateFrame
    _G.CreateFrame = function(_, name)
      local f = makeFrame(name)
      if name then _G[name] = f end
      table.insert(frames, f)
      return f
    end
    -- UpdateIcon is the icon path and has its own concerns (SequencesExec
    -- lookups, click-serial tracking). Here it only needs to be observable.
    prevUpdateIcon = GSE.UpdateIcon
    GSE.UpdateIcon = function(self, reset) iconCalls[#iconCalls + 1] = {frame = self, reset = reset} end
    -- CreateGSE3Button swallows errors in a pcall and prints instead, so a
    -- failed build would otherwise look like a passing test with empty tables.
    -- Capture the print; `build` above fails the test if anything came out.
    prevPrint = GSE.Print
    GSE.Print = function(message, title) table.insert(printed, tostring(title) .. ": " .. tostring(message)) end
    -- AceLocale answers a missing key with the key itself. The mock's L is a
    -- bare table, and the failure message concatenates L[...] OUTSIDE the
    -- pcall, so without this a broken build errors on the error path.
    prevLmeta = getmetatable(GSE.L)
    setmetatable(GSE.L, {__index = function(_, k) return k end})
    _G.TESTBUTTON = nil
    _G.OTHERBUTTON = nil
    GSE.SequencesExec = {}
    GSEOptions.ShiftPause, GSEOptions.AltPause, GSEOptions.CtrlPause = false, false, false
  end)

  after_each(function()
    _G.CreateFrame = prevCreateFrame
    GSE.UpdateIcon = prevUpdateIcon
    GSE.Print = prevPrint
    setmetatable(GSE.L, prevLmeta)
  end)

  local function spellStep(id) return {type = "spell", spell = id} end
  local function macroStep(text) return {type = "macro", macrotext = text} end

  describe("the frame it creates", function()
    it("creates one secure button under the sequence's own name", function()
      local f = build({spellStep(100)})
      assert.equals(1, #frames)
      assert.equals("TESTBUTTON", f.name)
      assert.equals(f, _G.TESTBUTTON, "and publishes it globally, which is what keybinds click")
    end)

    it("starts at step 1 with the sequence's name on it", function()
      local f = build({spellStep(100), spellStep(200)})
      assert.equals(1, f.attrs.step)
      assert.equals("TESTBUTTON", f.attrs.name)
    end)

    it("registers the single AnyUp edge so one press advances one step", function()
      -- Registering both edges would fire the handler twice per press and skip
      -- every second step of the rotation.
      local f = build({spellStep(100)})
      assert.are.same({"AnyUp"}, f.clicks)
    end)

    it("pins useOnKeyDown false so the action-bar delegate's down=false click casts", function()
      local f = build({spellStep(100)})
      assert.is_false(f.attrs.useOnKeyDown)
    end)

    it("carries combatreset through as given", function()
      assert.is_true(build({spellStep(100)}, true).attrs.combatreset)
      _G.TESTBUTTON = nil
      assert.is_false(build({spellStep(100)}, false).attrs.combatreset)
    end)

    it("treats a missing combatReset as false rather than leaving it nil", function()
      -- The secure snippet and UpdateIcon both compare it to true; nil would
      -- read the same but only by luck of the comparison.
      assert.is_false(build({spellStep(100)}).attrs.combatreset)
    end)

    it("resets step and iteration to 1 when combatreset is on", function()
      local f = build({spellStep(100), spellStep(200)}, true)
      assert.equals(1, f.attrs.step)
      assert.equals(1, f.attrs.iteration)
    end)

    it("hands the frame its own UpdateIcon method", function()
      local f = build({spellStep(100)})
      assert.equals(GSE.UpdateIcon, f.UpdateIcon)
    end)

    it("refreshes the icon once the button is programmed", function()
      -- Without this the button keeps whatever texture it had before the
      -- rebuild, which is the wrong spell for the step it is now on.
      local f = build({spellStep(100)})
      assert.equals(1, #iconCalls)
      assert.equals(f, iconCalls[1].frame)
      assert.is_false(iconCalls[1].reset, "a rebuild is not an icon reset")
    end)

    it("wraps OnClick once, with the secure handler", function()
      local f = build({spellStep(100)})
      assert.equals(1, #f.wrapped)
      assert.equals("OnClick", f.wrapped[1].handler)
    end)
  end)

  describe("rebuilding an existing button", function()
    -- A rebuild happens in combat-adjacent paths where CreateFrame may be
    -- unavailable, so the existing frame is reused deliberately.
    it("does not create a second frame", function()
      build({spellStep(100)})
      local first = _G.TESTBUTTON
      build({spellStep(200)})
      assert.equals(1, #frames, "CreateFrame was called once across both builds")
      assert.equals(first, _G.TESTBUTTON)
    end)

    it("still pushes the new step list", function()
      local f = build({spellStep(100)})
      f.executed = {}
      build({spellStep(200), spellStep(300)})
      local steps = flatten((replay(f)))
      assert.equals(2, #steps)
      assert.equals(200, steps[1].spell)
    end)

    it("does not wrap OnClick a second time", function()
      -- Wrapping again would stack handlers and advance the step twice.
      local f = build({spellStep(100)})
      build({spellStep(200)})
      assert.equals(1, #f.wrapped)
    end)

    it("re-stamps the modifier-pause attributes from the current options", function()
      -- These cannot be read from the secure snippet, so the only way an
      -- option change reaches the button is a rebuild re-stamping them.
      local f = build({spellStep(100)})
      assert.is_false(f.attrs.shiftpause)
      GSEOptions.ShiftPause, GSEOptions.AltPause, GSEOptions.CtrlPause = true, true, true
      build({spellStep(100)})
      assert.is_true(f.attrs.shiftpause)
      assert.is_true(f.attrs.altpause)
      assert.is_true(f.attrs.ctrlpause)
    end)

    it("coerces the pause options to booleans, not whatever the option held", function()
      GSEOptions.ShiftPause = "yes"
      assert.is_true(build({spellStep(100)}).attrs.shiftpause)
      GSEOptions.ShiftPause = nil
      _G.TESTBUTTON = nil
      assert.is_false(build({spellStep(100)}).attrs.shiftpause)
    end)
  end)

  describe("the first step, transferred to the button directly", function()
    -- Step 1 is set as attributes at build time so the very first click casts
    -- without waiting for the secure handler to run.
    it("puts the step's own keys on the frame", function()
      local f = build({{type = "spell", spell = 42, unit = "target"}})
      assert.equals("spell", f.attrs.type)
      assert.equals(42, f.attrs.spell)
      assert.equals("target", f.attrs.unit)
    end)

    it("clears macro and unit when the step is macrotext", function()
      local f = build({macroStep("/cast Alpha")})
      assert.equals("/cast Alpha", f.attrs.macrotext)
      assert.is_true(wasCleared(f, "macro"))
      assert.is_true(wasCleared(f, "unit"))
    end)

    it("clears macrotext and unit when the step names a macro", function()
      local f = build({{type = "macro", macro = "MyMacro"}})
      assert.equals("MyMacro", f.attrs.macro)
      assert.is_true(wasCleared(f, "macrotext"))
      assert.is_true(wasCleared(f, "unit"))
    end)

    it("does not put blockPath on the frame", function()
      -- blockPath is editor bookkeeping: which block in the sequence this step
      -- came from. It has no meaning to the secure button.
      local f = build({{type = "spell", spell = 42, blockPath = "1/2/3"}})
      assert.is_nil(f.attrs.blockPath)
    end)

    it("drops unit from every macro step before anything else looks at them", function()
      -- A leftover unit turns /cast into a targeted cast on the macro's behalf.
      local list = {macroStep("/cast Alpha"), {type = "macro", macro = "M", unit = "player"}}
      build(list)
      assert.is_nil(list[2].unit, "the step table itself is cleaned, not just the attribute")
    end)

    it("leaves unit alone on a spell step", function()
      local list = {{type = "spell", spell = 42, unit = "player"}}
      build(list)
      assert.equals("player", list[1].unit)
    end)
  end)

  describe("the step list the secure environment rebuilds", function()
    it("round-trips every step, in order", function()
      local f = build({spellStep(100), spellStep(200), spellStep(300)})
      local iterations, maxsequences = replay(f)
      assert.equals(1, maxsequences)
      assert.equals(1, #iterations)
      local steps = flatten(iterations)
      assert.equals(3, #steps)
      assert.are.same({type = "spell", spell = 100}, steps[1])
      assert.are.same({type = "spell", spell = 200}, steps[2])
      assert.are.same({type = "spell", spell = 300}, steps[3])
    end)

    it("carries macro text through intact, separators and all", function()
      -- The encoding uses \002 between key and value and | between pairs, so
      -- macro text containing either would tear. Conditionals are full of |.
      local text = "/cast [mod:shift,@focus] Alpha; Beta"
      local steps = flatten((replay(build({macroStep(text)}))))
      assert.equals(text, steps[1].macrotext)
    end)

    it("rebuilds spell ids as numbers and everything else as strings", function()
      -- Crossing into the secure environment is a string round trip; only
      -- `spell` is converted back, because that is the one SetAttribute needs
      -- as a number.
      local steps = flatten((replay(build({{type = "spell", spell = 42, unit = "target"}}))))
      assert.equals("number", type(steps[1].spell))
      assert.equals("string", type(steps[1].unit))
    end)

    it("leaves a named spell as its name", function()
      local steps = flatten((replay(build({{type = "spell", spell = "Eye of Tyr"}}))))
      assert.equals("Eye of Tyr", steps[1].spell)
    end)

    it("does not ship blockPath across", function()
      local f = build({{type = "spell", spell = 42, blockPath = "1/2/3"}})
      local steps = flatten((replay(f)))
      assert.is_nil(steps[1].blockPath)
      assert.equals(42, steps[1].spell)
    end)

    it("keeps SequencesExec and the secure list describing the same rotation", function()
      -- UpdateIcon reads SequencesExec[name][step] to decide which icon to
      -- show, using the step number the secure side is on. If the two lists
      -- disagree the button shows a spell it is not about to cast.
      local list = {spellStep(100), macroStep("/cast Beta"), spellStep(300)}
      local f = build(list)
      local steps = flatten((replay(f)))
      assert.equals(list, GSE.SequencesExec.TESTBUTTON)
      assert.equals(#list, #steps)
      for i = 1, #list do
        assert.equals(list[i].type, steps[i].type, "step " .. i)
      end
    end)
  end)

  describe("sequences longer than one chunk", function()
    -- The payload is split because a single secure string has a length limit;
    -- the secure side calls each chunk an "iteration" and wraps from the last
    -- step of the last iteration back to the first step of the first.
    local function longList(n)
      local list = {}
      for i = 1, n do list[i] = spellStep(i) end
      return list
    end

    it("fits 253 steps in one iteration", function()
      local iterations, maxsequences = replay(build(longList(253)))
      assert.equals(1, maxsequences)
      assert.equals(253, #iterations[1])
    end)

    it("splits at 254 and reports both iterations", function()
      local iterations, maxsequences = replay(build(longList(254)))
      assert.equals(2, maxsequences)
      assert.equals(253, #iterations[1])
      assert.equals(1, #iterations[2])
    end)

    it("loses no step and reorders none across the split", function()
      local list = longList(600)
      local steps = flatten((replay(build(list))))
      assert.equals(600, #steps)
      for i = 1, 600 do
        assert.equals(i, steps[i].spell, "step " .. i .. " is where it started")
      end
    end)

    it("reports as many iterations as it built", function()
      local iterations, maxsequences = replay(build(longList(600)))
      assert.equals(#iterations, maxsequences, "the wrap-around uses maxsequences")
      assert.equals(3, maxsequences)
    end)
  end)


  describe("the step number the icon path resolves", function()
    -- GSE.UpdateIcon is handed the button mid-rotation and has to turn the
    -- secure side's (iteration, step) pair back into an index into
    -- SequencesExec, which is one flat list of every step. Getting that wrong
    -- shows the wrong spell on the button, on every action-bar override of it,
    -- and in the Step this reports to WeakAuras and the debugger.
    local resolved

    local function iconStepFor(frame, iteration, step)
      frame:SetAttribute("iteration", iteration)
      frame:SetAttribute("step", step)
      resolved = nil
      realUpdateIcon(frame, false)
      return resolved
    end

    before_each(function()
      GSE.UsedSequences = {}
      GSE.SequenceIconFrameUpdateFromButton = function(_, _, _, action) resolved = action end
      -- Answer as a client that knows none of these spells. The icon lookup
      -- then falls through to the step itself, which is what these tests are
      -- about -- the index, not the texture.
      GSE.GetSpellInfo = function() return nil end
    end)

    after_each(function()
      GSE.SequenceIconFrameUpdateFromButton = nil
      GSE.GetSpellInfo = nil
    end)

    local function longList(n)
      local list = {}
      for i = 1, n do list[i] = spellStep(i) end
      return list
    end

    it("reads the flat list straight through on the first iteration", function()
      local f = build(longList(10))
      assert.equals(4, iconStepFor(f, 1, 4).spell)
    end)

    it("offsets by the iterations already consumed, not by the iteration number", function()
      -- Iteration 2 step 1 is the 254th step of the rotation. Counting the
      -- current iteration as consumed too puts the lookup 253 steps past it,
      -- off the end of most sequences and on the wrong spell in the rest.
      local f = build(longList(600))
      assert.equals(254, iconStepFor(f, 2, 1).spell)
      assert.equals(506, iconStepFor(f, 2, 253).spell)
      assert.equals(507, iconStepFor(f, 3, 1).spell)
      assert.equals(600, iconStepFor(f, 3, 94).spell)
    end)

    it("agrees with what the secure side is actually holding at that position", function()
      -- The two lists are built by different code from the same input, so
      -- walk every step of every iteration and check they line up.
      local f = build(longList(600))
      local iterations = replay(f)
      for iteration, steps in ipairs(iterations) do
        for step = 1, #steps do
          assert.equals(steps[step].spell, iconStepFor(f, iteration, step).spell,
            "iteration " .. iteration .. " step " .. step)
        end
      end
    end)
  end)

  describe("when the build cannot be done", function()
    it("says the macro is missing rather than creating a button", function()
      GSE.CreateGSE3Button(nil, "TESTBUTTON", false)
      assert.equals(0, #frames)
      assert.is_nil(_G.TESTBUTTON)
      assert.equals(1, #printed)
      assert.is_truthy(printed[1]:find("Macro missing for TESTBUTTON", 1, true))
    end)

    it("reports a broken macro instead of erroring out of the caller", function()
      -- A step list with a hole errors inside the build. The pcall is what
      -- keeps one bad sequence from taking down whatever was iterating over
      -- the library at the time.
      assert.has_no.errors(function()
        GSE.CreateGSE3Button({[2] = spellStep(100)}, "TESTBUTTON", false)
      end)
      assert.is_true(#printed > 0, "the failure is reported, not swallowed silently")
    end)
  end)
end)
