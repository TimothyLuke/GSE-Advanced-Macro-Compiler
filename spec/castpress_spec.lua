-- A press of a sequence shows on the Blizzard action buttons that hold the
-- spell that press fired (GSE/API/Events.lua, showCastPress and
-- GSE.SequenceStepShown): the pushed art, shown and hidden again, on every
-- shown button whose slot holds the spell -- the same id, the one a talent
-- replaced, or the same spell by name where the bar holds another rank --
-- never on a button a sequence is on, never for a spell the block's
-- conditions rule out at the press (a /stopmacro that holds, a cast sequence
-- on another step), and never an error on a value Midnight
-- keeps secret.
--
-- Events.lua cannot be loaded here, so this reads the functions out of it as
-- text and runs them against stand-in buttons.
--
-- Run: busted spec/castpress_spec.lua   /   lua5.1 spec/run51.lua
describe("A sequence's press shown as a button press", function()
  local GLOBALS = { "GSE", "GSEOptions", "GetActionInfo", "GetTime", "C_Timer", "FindBaseSpellByID", "UnitIsDeadOrGhost",
    "UnitExists", "UnitIsUnit", "C_Spell", "QueryCastSequence", "InCombatLockdown",
    "ActionButton1", "ActionButton2", "MultiBar5Button3" }
  local saved, showCastPress, stepShown, timers, secret, now, dead, target, onSelf, held, combat

  local function button(slot, fields)
    local b = fields or {}
    b.shown, b.state = 0, "NORMAL"
    local pushed = { Show = function() b.shown = b.shown + 1 end, Hide = function() b.shown = 0 end }
    b.IsVisible = function() return not b.hidden end
    b.GetAttribute = function(_, name) return name == "gse-button" and b.sequence or nil end
    b.GetPushedTexture = function() return pushed end
    b.GetButtonState = function() return b.state end
    b.slot = slot
    return b
  end

  -- The game's globals go on _G itself: busted runs each spec file in its own
  -- environment, and code loaded from Events.lua as text reads the real one.
  setup(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local bars = assert(src:match("\nlocal CAST_PRESS_BARS = (%b{})\n"), "CAST_PRESS_BARS not found")
    local holds = assert(src:match("\nlocal function slotHoldsSpell%(slot, spellID, base, name%)\n(.-)\nend\n"),
      "slotHoldsSpell not found")
    local commands = assert(src:match("\nlocal CAST_PRESS_COMMANDS = (%b{})\n"), "CAST_PRESS_COMMANDS not found")
    local casts = assert(src:match("\nlocal function macroCastsSpell%(macrotext, spellID, name%)\n(.-)\nend\n"),
      "macroCastsSpell not found")
    local body = assert(src:match("\nlocal function showCastPress%(spellID, name, macrotext%)\n(.-)\nend\n"),
      "showCastPress not found")
    local shown = assert(src:match(
      "\nfunction GSE%.SequenceStepShown%(sequenceId, spellID, name, pressed, macrotext%)\n(.-)\nend\n"),
      "GSE.SequenceStepShown not found")
    secret = {}
    showCastPress, stepShown = assert((loadstring or load)(
      "local isSecretValue, getButtonEffectiveSlot, PRESS_FLASH_SECONDS = ...\n"
      .. "local CAST_PRESS_BARS = " .. bars .. "\n"
      .. "local function slotHoldsSpell(slot, spellID, base, name)\n" .. holds .. "\nend\n"
      .. "local CAST_PRESS_COMMANDS = " .. commands .. "\n"
      .. "local function macroCastsSpell(macrotext, spellID, name)\n" .. casts .. "\nend\n"
      .. "local pressShownUntil = {}\n"
      .. "local function showCastPress(spellID, name, macrotext)\n" .. body .. "\nend\n"
      .. "local pressNext = {}\n"
      .. "return showCastPress, function(sequenceId, spellID, name, pressed, macrotext)\n" .. shown .. "\nend"))(
      function(value) return value == secret end,
      function(b) return b.slot end,
      0.1)
    _G.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { due = now + delay, fn = fn } end }
    _G.GetTime = function() return now end
    _G.UnitIsDeadOrGhost = function(unit) return unit == "player" and dead end
    _G.UnitExists = function(unit) return unit == "target" and target end
    _G.InCombatLockdown = function() return combat end
    _G.UnitIsUnit = function(a, b) return a == "target" and b == "player" and onSelf end
    -- 100 only harms, 200 harms and helps (as a spell that heals a friend
    -- and hurts an enemy does), 300 only helps.
    _G.C_Spell = {
      IsSpellHarmful = function(spell) return spell == 100 or spell == 200 end,
      IsSpellHelpful = function(spell) return spell == 200 or spell == 300 end,
    }
    -- Slots 1 and 147 hold spell 100; slot 2 holds 200, the base of 201 and
    -- another rank of 529; slot 3 holds an item with a spell's number.
    local slots = { [1] = { "spell", 100 }, [147] = { "spell", 100 }, [2] = { "spell", 200 }, [3] = { "item", 100 } }
    _G.GetActionInfo = function(slot)
      local held = slots[slot]
      if held then return held[1], held[2] end
    end
    local names = { [100] = "Kill Command", [200] = "Lightning Bolt", [201] = "Tempest", [529] = "Lightning Bolt" }
    local byName = { ["Lightning Bolt(Rank 2)"] = 529 }
    local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    local idOf = {}
    for id, n in pairs(names) do if not byName[n] and (not idOf[n] or id < idOf[n]) then idOf[n] = id end end
    _G.GSE = {
      GetSpellInfo = function(spell)
        local id = byName[spell] or idOf[spell] or spell
        return names[id] and { name = names[id], spellID = id } or nil
      end,
      -- The game's parser, for conditions made of words in `held`: the first
      -- clause whose [..] all hold, without its conditions; nil when none does.
      SafeSecureCmdOptionParse = function(options)
        if options == "secret" then return secret end
        for clause in (options .. ";"):gmatch("([^;]*);") do
          local ok, rest = true, trim(clause)
          while rest:sub(1, 1) == "[" do
            local cond, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
            if cond ~= "" and not held[cond] then ok = false end
            rest = after
          end
          if ok then return rest end
        end
      end,
      SplitCastSequence = function(str)
        local out = {}
        for part in (str .. ","):gmatch("([^,]*),") do out[#out + 1] = part end
        return out
      end,
      GetMacroClauseTarget = function(str)
        local s = trim(str):gsub("^reset=%S+%s*", "")
        return (trim(s):gsub("^!%s*", ""))
      end,
    }
    _G.GSEOptions = { actionBarShowCastPress = true }
    _G.FindBaseSpellByID = function(spellID) return spellID == 201 and 200 or spellID end
  end)

  teardown(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  before_each(function()
    timers, now, dead, target, onSelf, held, combat = {}, 10, false, true, false, {}, true
    _G.QueryCastSequence = nil
    GSEOptions.actionBarShowCastPress = true
    _G.ActionButton1, _G.ActionButton2, _G.MultiBar5Button3 = button(1), button(2), button(147)
  end)

  -- Every timer due by then, as the game would run them.
  local function runTimers(at)
    now = at
    local waiting = timers
    timers = {}
    for _, timer in ipairs(waiting) do
      if timer.due <= at + 1e-9 then timer.fn() else timers[#timers + 1] = timer end
    end
  end

  it("shows the pushed art on every button holding the spell, then hides it", function()
    showCastPress(100)
    assert.are.equal(1, ActionButton1.shown)
    assert.are.equal(1, MultiBar5Button3.shown)
    assert.are.equal(0, ActionButton2.shown)
    runTimers(10.1)
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("keeps the art up when the next press comes before it would go", function()
    showCastPress(100)
    now = 10.05
    showCastPress(100)
    runTimers(10.1) -- the first press's timer: the second still holds it up
    assert.is_true(ActionButton1.shown > 0)
    runTimers(10.15)
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("leaves the art up for a button held down when the flash ends", function()
    showCastPress(100)
    ActionButton1.state = "PUSHED"
    runTimers(10.1)
    assert.are.equal(1, ActionButton1.shown)
  end)

  it("finds the button holding the spell a talent replaced", function()
    showCastPress(201)
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("finds the button holding another rank of the spell, by its name", function()
    showCastPress(529)
    assert.are.equal(1, ActionButton2.shown)
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("finds the button from a spell's name alone, rank and all", function()
    showCastPress(nil, "Lightning Bolt(Rank 2)")
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("leaves a slot holding an item with the spell's number alone", function()
    ActionButton1.slot = 3
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("skips a hidden button and one a sequence is on", function()
    ActionButton1.hidden = true
    MultiBar5Button3.sequence = "seqA"
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown)
    assert.are.equal(0, MultiBar5Button3.shown)
  end)

  it("does nothing for a spell on no bar, a secret spell, or no spell", function()
    showCastPress(999)
    showCastPress(secret)
    showCastPress(nil, nil)
    assert.are.equal(0, ActionButton1.shown + ActionButton2.shown + MultiBar5Button3.shown)
  end)

  it("shows nothing while the player is dead", function()
    dead = true
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown + MultiBar5Button3.shown)
  end)

  -- Larry, 2026-11-23: "Stream mode should not work when out of combat".
  it("shows nothing out of combat, and shows again once combat starts", function()
    combat = false
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown + MultiBar5Button3.shown)
    assert.are.equal(0, #timers)
    combat = true
    showCastPress(100)
    assert.are.equal(1, ActionButton1.shown)
  end)

  it("shows nothing without a target", function()
    target = false
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown + MultiBar5Button3.shown)
  end)

  it("shows nothing for a spell that only harms while the player targets themself", function()
    onSelf = true
    showCastPress(100)
    assert.are.equal(0, ActionButton1.shown + MultiBar5Button3.shown)
    showCastPress(200) -- harms and helps: it lands on the player
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("shows the press where the game keeps who the target is secret", function()
    onSelf = secret
    showCastPress(100)
    assert.are.equal(1, ActionButton1.shown)
  end)

  it("shows a press on the spell of the step that press fired, not the next one", function()
    stepShown("seqA", 100, "Kill Command", false) -- at rest: the first press fires 100
    assert.are.equal(0, ActionButton1.shown)
    stepShown("seqA", 200, "Lightning Bolt", true) -- pressed: 100 fired, 200 is next
    assert.are.equal(1, ActionButton1.shown)
    assert.are.equal(0, ActionButton2.shown)
    stepShown("seqA", 100, "Kill Command", true) -- pressed: 200 fired
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("shows nothing when the block's conditions rule the spell out", function()
    showCastPress(100, nil, "/cast [mod:shift] Kill Command")
    assert.are.equal(0, ActionButton1.shown)
    held["mod:shift"] = true
    showCastPress(100, nil, "/cast [mod:shift] Kill Command")
    assert.are.equal(1, ActionButton1.shown)
  end)

  it("reads the clause the conditions pick, not the first one", function()
    showCastPress(200, nil, "/cast [mod:shift] Lightning Bolt; Kill Command")
    assert.are.equal(0, ActionButton2.shown)
    showCastPress(100, nil, "/cast [mod:shift] Lightning Bolt; Kill Command")
    assert.are.equal(1, ActionButton1.shown)
  end)

  it("reads every cast line, a ! guard, and a castsequence's clause", function()
    showCastPress(100, nil, "/startattack\n/cast [combat] Lightning Bolt\n/cast !Kill Command")
    assert.are.equal(1, ActionButton1.shown)
    local seq = "/castsequence [combat] reset=target Kill Command, Lightning Bolt"
    showCastPress(200, nil, seq)
    assert.are.equal(0, ActionButton2.shown)
    held.combat = true
    showCastPress(200, nil, seq)
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("reads only the step a cast sequence is on", function()
    local steps = { ["reset=combat Kill Command, nil"] = "kill command" }
    _G.QueryCastSequence = function(sequence) return 1, nil, steps[sequence] end
    local seq = "/castsequence [combat] reset=combat Kill Command, nil"
    held.combat = true
    showCastPress(100, nil, seq)
    assert.are.equal(1, ActionButton1.shown)
    steps["reset=combat Kill Command, nil"] = "nil" -- cast once: on its nil step until combat resets it
    ActionButton1.shown = 0
    showCastPress(100, nil, seq)
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("shows nothing past a /stopmacro whose conditions hold", function()
    local block = "/stopmacro [dead]\n/cast Kill Command"
    showCastPress(100, nil, block)
    assert.are.equal(1, ActionButton1.shown)
    held.dead = true
    ActionButton1.shown = 0
    showCastPress(100, nil, block)
    assert.are.equal(0, ActionButton1.shown)
    held.dead = nil
    showCastPress(100, nil, "/stopmacro\n/cast Kill Command")
    assert.are.equal(0, ActionButton1.shown)
  end)

  it("takes a block with no cast line at its word, and shows nothing for a secret pick", function()
    showCastPress(100, nil, "/startattack")
    assert.are.equal(1, ActionButton1.shown)
    showCastPress(200, nil, "/cast secret")
    assert.are.equal(0, ActionButton2.shown)
  end)

  it("checks the macro text of the step the press fired", function()
    stepShown("seqA", 100, "Kill Command", false, "/cast [mod:shift] Kill Command")
    stepShown("seqA", 200, "Lightning Bolt", true, "/cast Lightning Bolt")
    assert.are.equal(0, ActionButton1.shown) -- no Shift: the fired step cast nothing
    stepShown("seqA", 100, "Kill Command", true, "/cast [mod:shift] Kill Command")
    assert.are.equal(1, ActionButton2.shown)
  end)

  it("keeps each sequence's own step, and shows nothing with the option off", function()
    stepShown("seqA", 100, "Kill Command", false)
    stepShown("seqB", 200, "Lightning Bolt", false)
    GSEOptions.actionBarShowCastPress = false
    stepShown("seqA", 100, "Kill Command", true)
    assert.are.equal(0, ActionButton1.shown)
    GSEOptions.actionBarShowCastPress = true
    stepShown("seqB", 200, "Lightning Bolt", true)
    assert.are.equal(1, ActionButton2.shown)
    assert.are.equal(0, ActionButton1.shown)
  end)

  -- The switch is GSE Streamer Mode in GSE's options, off unless ticked.
  it("is switched by GSE Streamer Mode in GSE's options, off by default", function()
    local function read(path)
      local fh = assert(io.open(path, "r"))
      local text = fh:read("*a"):gsub("\r\n", "\n")
      fh:close()
      return text
    end
    local options = read("GSE_Options/Options.lua")
    assert.truthy(options:find('Settings.RegisterProxySetting(optionsCategory, "actionBarShowCastPress", '
      .. 'Settings.VarType.Boolean, L["GSE Streamer Mode"], false, GetValue, SetValue)', 1, true))
    assert.truthy(options:find("return GSEOptions.actionBarShowCastPress == true", 1, true))
    assert.truthy(options:find("AddActionBarCastPressOption(generalOptions)", 1, true))
    local enUS = read("GSE/Localization/ModL_enUS.lua")
    assert.truthy(enUS:find('\nL["GSE Streamer Mode"] = true\n', 1, true))
  end)
end)
