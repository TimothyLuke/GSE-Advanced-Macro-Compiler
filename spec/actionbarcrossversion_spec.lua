-- Stance, form and stealth bars on every WoW version GSE supports and on every
-- action bar addon it puts sequences on.
--
-- The rule (actionbarstances_spec.lua): a sequence's Default row stays off a
-- bar a stance, form or stealth turns to, and a row pinned to one runs there.
-- Two things carry it and must always agree: the button's own secure click
-- (BAR_SWAP_ONCLICK, Events.lua), which decides what a press does, and
-- GSE.ButtonOverrideSequence (Profiles.lua), which decides the icon, the
-- watermark and what the right-click menu offers. This runs both, as the addon
-- has them, against buttons shaped as each bar addon builds them, in every
-- stance each class has on each client.
--
-- Which stances turn the bar is Blizzard's data, SpellShapeshiftForm's
-- BonusActionBar column, read per client from wago.tools on 2026-11-20
-- (Classic Era 1.15.9, TBC Anniversary 2.5.6, MoP Classic 5.5.4, WoW Forever
-- 1.60.1, Retail 12.1.5); Bartender4 4.19.2, Dominos 12.0.4 and ElvUI list the
-- same. The button shapes are read from the addons' own code: Dominos 12.0.4,
-- EllesmereUI 9.9.1, DaylightUI 2.1.3, Bartender4 4.19.2 (LibActionButton).
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function between(src, startText, endText)
  local s = src:find(startText, 1, true)
  assert(s, "start not found: " .. startText)
  local e = src:find(endText, s, true)
  assert(e, "end not found: " .. endText)
  return src:sub(s, e - 1)
end

local function compile(code, name, env)
  if loadstring then
    local chunk = assert(loadstring(code, name))
    setfenv(chunk, env)
    return chunk
  end
  return assert(load(code, name, "t", env))
end

local events = readSource("GSE/API/Events.lua")
local profiles = readSource("GSE/API/Profiles.lua")

-- The stance code as the addon has it: the page drivers, names and states
-- (Profiles.lua), and the state a button is in (Events.lua).
local STANCE_CODE = between(profiles, "function GSE.LABDefaultState(buttonName)",
    "--- Whether an overridden button runs sequence in any of its states.")
  .. between(events, "local function isBonusPaged(button)", "-- asDefault: the button's Default row")
  .. between(events, "local function getButtonEffectiveSlot(btn)", "function GSE.ActionBarSlotHasForeignAction(button)")
  .. "\nGSE.TestIsBonusPaged = isBonusPaged\n"

local ONCLICK
do
  local resolve = assert(events:match("local BAR_SWAP_RESOLVE = %[%[(.-)%]%]"), "BAR_SWAP_RESOLVE not found")
  local head, tail = events:match("local BAR_SWAP_ONCLICK = %[%[(.-)%]%] %.%. BAR_SWAP_RESOLVE %.%. %[%[(.-)%]%]")
  assert(head and tail, "BAR_SWAP_ONCLICK not built from BAR_SWAP_RESOLVE")
  ONCLICK = head .. resolve .. tail
end

-- Each client: how GSE knows it, the spells it has (a page is named by its
-- spell), and the bonus bar each class's stances bring up.
local SPELLS = {
  [768] = "Cat Form", [5487] = "Bear Form", [24858] = "Moonkin Form", [33891] = "Tree of Life",
  [1784] = "Stealth", [51713] = "Shadow Dance", [2457] = "Battle Stance", [71] = "Defensive Stance",
  [2458] = "Berserker Stance", [15473] = "Shadowform", [103985] = "Stance of the Fierce Tiger",
  [115069] = "Stance of the Sturdy Ox", [115070] = "Stance of the Wise Serpent",
}
local CLIENTS = {
  { name = "Classic Era", gameMode = 1,
    has = { 768, 5487, 24858, 1784, 2457, 71, 2458, 15473 },
    bonus = { WARRIOR = { 1, 2, 3 }, DRUID = { 1, 3 }, ROGUE = { 1 }, PRIEST = {}, MAGE = {} } },
  { name = "TBC Anniversary", gameMode = 2,
    has = { 768, 5487, 24858, 33891, 1784, 2457, 71, 2458, 15473 },
    bonus = { WARRIOR = { 1, 2, 3 }, DRUID = { 1, 2, 3, 4 }, ROGUE = { 1 }, PRIEST = { 1 }, MAGE = {} } },
  { name = "MoP Classic", gameMode = 5,
    has = { 768, 5487, 24858, 33891, 1784, 51713, 2457, 71, 2458, 15473, 103985, 115069, 115070 },
    bonus = { WARRIOR = {}, DRUID = { 1, 3, 4 }, ROGUE = { 1, 2 }, PRIEST = { 1 }, MONK = { 1, 2, 3 }, MAGE = {} } },
  { name = "WoW Forever", gameMode = 12, forever = true,
    has = { 768, 5487, 24858, 1784, 2457, 71, 2458, 15473 },
    bonus = { WARRIOR = { 1, 2, 3 }, DRUID = { 1, 3 }, ROGUE = { 1 }, PRIEST = {}, MAGE = {} } },
  { name = "Retail", gameMode = 12,
    has = { 768, 5487, 24858, 33891, 1784 },
    bonus = { WARRIOR = {}, DRUID = { 1, 3, 4 }, ROGUE = { 1 }, PRIEST = {}, MONK = {}, MAGE = {} } },
}

-- A client with one character logged in: the stance code loaded into it.
local function login(client, classfile)
  local has = {}
  for _, id in ipairs(client.has) do has[id] = true end
  local env
  env = setmetatable({
    GSE = {
      GameMode = client.gameMode, IsForever = client.forever or nil,
      L = setmetatable({}, { __index = function(_, k) return k end }),
      GetSpellInfo = function(id) return has[id] and { name = SPELLS[id] } or nil end,
      GetCurrentClassID = function() return 1 end,
      ButtonOverrides = {}, ButtonOverrideDefaults = {}, ButtonOverrideStates = {},
    },
    GetClassInfo = function() return classfile, classfile end,
    UnitClass = function() return classfile, classfile end,
    RegisterStateDriver = function() end,
    UnregisterStateDriver = function() end,
  }, { __index = { string = string, table = table, math = math, pairs = pairs, ipairs = ipairs, type = type,
    tostring = tostring, tonumber = tonumber, select = select, setmetatable = setmetatable, pcall = pcall,
    rawget = rawget, next = next } })
  env._G = env
  env.TEST_CLIENT, env.TEST_CLASS = client, classfile
  -- hooksecurefunc as WoW has it: the global is replaced, so a caller holding
  -- the function from before (EllesmereUI) is not seen.
  env.hooksecurefunc = function(name, hook)
    local original = env[name]
    env[name] = function(...) original(...) hook(...) end
  end
  compile(STANCE_CODE, "stance code", env)()
  return env
end

-- A button as its bar addon builds it. bonus: the bonus bar the player's
-- stance has up now (0: none).
local function newButton(env, name, shape)
  local b = { attrs = shape.attrs or {} }
  function b:GetName() return name end
  function b:GetID() return shape.id or 0 end
  function b:GetAttribute(k) return self.attrs[k] end
  function b:GetParent() return shape.parent end
  if shape.dominos then b.SetShowGridInsecure = function() end end
  if shape.lab then b.SetState = function() end b.state_types = shape.lab end
  b.shape = shape
  env[name] = b
  return b
end
local function slotOnBonus(bonus) return 1 + (6 + bonus - 1) * 12 end

-- Blizzard's main bar: paged in C, the slot it shows in the .action field,
-- its page from the bar (actionpage, 1).
local function blizzardMainBar(env)
  return newButton(env, "ActionButton1", { id = 1, attrs = { actionpage = 1 },
    turn = function(b, bonus) b.action = bonus > 0 and slotOnBonus(bonus) or 1 end })
end
-- Blizzard's Action Bar 2: slots 61-72, whatever the stance.
local function blizzardBar2(env)
  return newButton(env, "MultiBarBottomLeftButton1", { id = 1, attrs = { actionpage = 6 },
    turn = function(b) b.action = 61 end })
end
-- Dominos' first bar (button.lua, bar.lua): id 0, the slot in the "action"
-- attribute, the bar paging by a driver of states Dominos names itself.
local function dominosMainBar(env)
  local bar = {}
  env.RegisterStateDriver(bar, "page", "[bonusbar:1,stealth]prowl;[bonusbar:1]cat;[bonusbar:3]bear;base")
  return newButton(env, "DominosActionButton1", { dominos = true, parent = bar, attrs = { ["action-base"] = 1 },
    turn = function(b, bonus) b.attrs.action = bonus > 0 and slotOnBonus(bonus) or 1 end })
end
-- A Dominos bar set on the bonus-bar slots (addressMap.lua: addresses 109-156
-- are slots 73-120): an ordinary bar that never turns.
local function dominosBarOnBonusSlots(env)
  return newButton(env, "DominosActionButton109", { dominos = true, parent = {}, attrs = { ["action-base"] = 73 },
    turn = function(b) b.attrs.action = 73 end })
end
-- EllesmereUI's main-bar conditions (GetClassPagingConditions,
-- EUI_ActionBars_Paging.lua): every bonus bar on WoW Forever, whatever the
-- class; a druid's and a rogue's on Retail.
local function ellesmereConditions(client, classfile)
  local c = "[overridebar] 18; [vehicleui][possessbar] 16; [shapeshift] 17; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
  if client.forever then
    c = c .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "
  elseif classfile == "DRUID" then
    c = c .. "[bonusbar:1,stealth] 7; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10; "
  elseif classfile == "ROGUE" then
    c = c .. "[bonusbar:1] 7; "
  end
  return c .. "[bonusbar:5] 11; 1"
end
-- The page a driver gives with this bonus bar up (out of stealth, no
-- modifier, on page 1).
local function drivenPage(conditions, bonus)
  for clause in (conditions .. ";"):gmatch("([^;]*);") do
    local n, page = clause:match("^%s*%[bonusbar:(%d)%]%s*(%d+)%s*$")
    if n and tonumber(n) == bonus then return tonumber(page) end
    if not clause:find("[", 1, true) then return tonumber(clause:match("%d+")) end
  end
  return 1
end
-- EllesmereUI's main bar (EUI_ActionBars_Secure.lua, EUI_ActionBars_Bars.lua):
-- id 0, the slot in the "action" attribute, rewritten as the bar's driver
-- turns the page. The driver is registered through a RegisterStateDriver
-- EllesmereUI took before GSE loaded (EUI_ActionBars_Bars.lua:15), which
-- GSE's hook never sees; the conditions are kept on the bar
-- (_eabPagingConds: false for a bar on one page). conditions: the bar's,
-- where they are not the class's own.
local function ellesmereMainBar(env, conditions)
  if conditions == nil then conditions = ellesmereConditions(env.TEST_CLIENT, env.TEST_CLASS) end
  local bar = { _eabPagingConds = conditions }
  return newButton(env, "EABButton1", { parent = bar, attrs = {},
    turn = function(b, bonus)
      local page = type(bar._eabPagingConds) == "string" and drivenPage(bar._eabPagingConds, bonus) or 1
      b.attrs.action = 1 + (page - 1) * 12
    end })
end
-- DaylightUI's first bar (Buttons.lua): id 0, the slot in the "action"
-- attribute. Its driver is set up before GSE loads; unseen, and with a
-- DaylightUI that cannot be asked for it, its stances are on Blizzard's pages
-- (GSE.ButtonPagesWithForms).
local function daylightMainBar(env)
  return newButton(env, "DaylightUIBar1Button1", { parent = {}, attrs = {},
    turn = function(b, bonus) b.attrs.action = bonus > 0 and slotOnBonus(bonus) or 1 end })
end
-- DaylightUI as it is to another addon (WoW Forever only): the global, its
-- action bar module with the module's own tables (Module.lua: ns = ns), the
-- bars' holders, and the rule builders it registers its drivers from
-- (Paging.Rule, Paging.BarRule). Its drivers are registered while it loads,
-- before GSE is there: none goes through the hook. rules: { main = bar 1's
-- rule, bar2 = a rule of the player's for bar 2 }. A druid's stance bar here:
-- Bear 1, Aquatic 2, Cat 3, Travel 4, Moonkin 5, and the bar pages by form.
local DRUID_FORMS = { [1] = 5487, [3] = 768, [5] = 24858 }
local FORM_OF_BONUS = { [1] = 3, [3] = 1, [4] = 5 }
local function daylightUI(env, rules)
  local holders = { main = {}, bar2 = {} }
  local ns = {
    Bars = { holders = holders,
      DEFS = { { key = "main", num = 1, page = 1 }, { key = "bar2", num = 2, page = 6 } } },
    Paging = { Rule = function() return rules.main end, BarRule = function(def) return rules[def.key] end },
  }
  local mod = { enabled = true, ns = ns }
  env.DaylightUI = { GetModule = function(_, name) return name == "ActionBars" and mod or nil end }
  env.GetShapeshiftFormInfo = function(i)
    local id = env.TEST_CLASS == "DRUID" and DRUID_FORMS[i]
    if id then return nil, false, true, id end
  end
  -- The page a rule gives in a stance: stance is its bonus bar, and for a
  -- druid or a priest the form DaylightUI counts instead.
  local function page(rule, stance, own)
    local form = env.TEST_CLASS == "DRUID" and FORM_OF_BONUS[stance] or (env.TEST_CLASS == "PRIEST" and stance or nil)
    for clause in (rule .. ";"):gmatch("([^;]*);") do
      local kind, n, to = clause:match("^%s*%[(%a+):(%d)%]%s*(%d+)")
      if kind == "bonusbar" and tonumber(n) == stance and stance > 0 then return tonumber(to) end
      if kind == "form" and tonumber(n) == form and stance > 0 then return tonumber(to) end
    end
    return own
  end
  local function button(name, key, own, index)
    return newButton(env, name, { parent = holders[key], attrs = {},
      turn = function(b, stance)
        local to = rules[key] and page(rules[key], stance, own) or own
        b.attrs.action = index + (to - 1) * 12
      end })
  end
  return button("DaylightUIBar1Button1", "main", 1, 1), button("DaylightUIBar2Button1", "bar2", 6, 1), mod, holders
end
-- Bar 1's rule as Paging.Rule builds it (Paging.lua): every bonus bar by its
-- number; a druid's forms by their place on the stance bar; a priest's
-- Shadowform as form 1.
local DAYLIGHT_HEAD = "[overridebar] 33; [vehicleui] 31; [possessbar] 31; [shapeshift] 32; "
  .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
local DAYLIGHT_RULES = {
  WARRIOR = DAYLIGHT_HEAD .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; [bonusbar:5] 11; 1",
  DRUID = DAYLIGHT_HEAD .. "[form:3] 7; [form:1] 9; [form:5] 10; [bonusbar:5] 11; 1",
  PRIEST = DAYLIGHT_HEAD .. "[form:1] 7; [bonusbar:5] 11; 1",
}
-- A bar whose page driver GSE does see, pages 7-10 for the bonus bars.
local function driverPagedBar(env)
  local bar = {}
  env.RegisterStateDriver(bar, "page", "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1")
  return newButton(env, "EABButton1", { parent = bar, attrs = {},
    turn = function(b, bonus) b.attrs.action = bonus > 0 and slotOnBonus(bonus) or 1 end })
end

-- Put rows on a button as GSE does, and press it: what GSE says runs on it
-- now, and what the press does. rows: { default = true, pinned = { page } }.
local function press(env, button, bonus, rows)
  local GSE, name = env.GSE, button:GetName()
  button.shape.turn(button, bonus)
  GSE.ButtonOverrides[name] = rows.default and "DEFAULT" or "PINNED"
  GSE.ButtonOverrideDefaults[name] = rows.default or nil
  GSE.ButtonOverrideStates[name] = nil
  local attrs = button.attrs
  for k in pairs(attrs) do if k:find("^gse%-") or k == "type" then attrs[k] = nil end end
  attrs["gse-secure"] = true
  if GSE.TestIsBonusPaged(button) then attrs["gse-bonus-paged"] = true end
  for _, page in ipairs(rows.pinned or {}) do
    GSE.ButtonOverrideStates[name] = GSE.ButtonOverrideStates[name] or {}
    GSE.ButtonOverrideStates[name][tostring(page)] = "PINNED" .. page
    attrs["gse-page-" .. page] = true
  end
  if rows.default then
    -- armRow: the Default row, and the marks GSE.ButtonStancePages gives it.
    attrs["gse-default"] = true
    for page in pairs(GSE.ButtonStancePages(name)) do attrs["gse-stance-" .. page] = true end
  end
  local shown = GSE.ButtonOverrideSequence(name)
  local renamed = compile(ONCLICK, "BAR_SWAP_ONCLICK", {
    floor = math.floor, tonumber = tonumber,
    GetBonusBarOffset = function() return bonus end,
    GetActionInfo = function() return nil end,
    self = {
      GetID = function() return button:GetID() end,
      GetEffectiveAttribute = function(_, k) return attrs[k] end,
      GetAttribute = function(_, k) return attrs[k] end,
      SetAttribute = function(_, k, v) attrs[k] = v end,
    },
  })()
  local pressed
  if attrs.type == "click" then pressed = renamed and ("PINNED" .. renamed:match("^gse(%d+)$")) or "DEFAULT" end
  return shown, pressed
end

describe("Stance bars on every client and bar addon", function()
  it("arms the Default row with GSE.ButtonStancePages, the pages what GSE shows reads too", function()
    local arm = between(events, "local function armRow(button, buttonName, sequenceName, state)", "\nend\n")
    assert.truthy(arm:find("GSE.ButtonStancePages(buttonName)", 1, true))
    assert.truthy(arm:find("secureArmGSEButton(button, sequenceName, true, stancePages)", 1, true))
    local armed = between(events, "local function secureArmGSEButton(button, sequenceName, asDefault, stancePages)", "\nend\n")
    assert.truthy(armed:find('for page = 1, 10 do b:SetAttribute("gse-stance-" .. page, nil) end', 1, true),
      "marks from before go when the row is armed again")
    local now = between(profiles, "function GSE.ButtonOverrideSequence(buttonName)", "\nend\n")
    assert.truthy(now:find("GSE.ButtonStancePages(buttonName)[tonumber(st)]", 1, true))
  end)

  for _, client in ipairs(CLIENTS) do
    describe(client.name, function()
      for classfile, bonuses in pairs(client.bonus) do
        it(classfile .. ": every stance bar it has is a State to choose, on Blizzard's bar and Dominos'", function()
          for _, build in ipairs({ blizzardMainBar, dominosMainBar }) do
            local env = login(client, classfile)
            local states = env.GSE.OverrideStatesFor(build(env):GetName())
            for _, bonus in ipairs(bonuses) do
              local page = tostring(6 + bonus)
              assert.truthy(states and states[page] and states[page] ~= page,
                classfile .. " bonus bar " .. bonus .. " has no name on " .. client.name)
            end
          end
        end)

        it(classfile .. ": no State for a form that brings up no bar", function()
          local env = login(client, classfile)
          local states, order = env.GSE.OverrideStatesFor(blizzardMainBar(env):GetName())
          local turns = {}
          for _, bonus in ipairs(bonuses) do turns[tostring(6 + bonus)] = true end
          for _, k in ipairs(order or {}) do
            if k ~= "Default" and states[k] ~= k then
              assert.truthy(turns[k], states[k] .. " is a State on " .. client.name .. " but brings up no bar")
            end
          end
        end)

        it(classfile .. ": an upgrade puts Default rows on the stances of a class never out of one, and no other", function()
          local env = login(client, classfile)
          local b = blizzardMainBar(env)
          local rows = { ActionButton1 = { Bind = "ActionButton1", Sequence = "SEQ" } }
          env.GSE.SpecOverrides = function() return rows end
          local always = (classfile == "WARRIOR" or classfile == "MONK") and #bonuses > 0
          assert.are.equal(always and #bonuses or 0, env.GSE.CopyDefaultRowsToStances("spec"))
          for _, bonus in ipairs(bonuses) do
            local page = tostring(6 + bonus)
            local row = rows["ActionButton1-" .. page]
            if always then
              assert.are.same({ Bind = "ActionButton1", State = page, Sequence = "SEQ" }, row)
              -- And it runs there: the press and what GSE shows.
              local shown, pressed = press(env, b, bonus, { default = true, pinned = { 6 + bonus } })
              assert.are.equal("PINNED" .. page, shown)
              assert.are.equal(shown, pressed)
            else
              assert.is_nil(row, classfile .. " is not always in a stance on " .. client.name)
            end
          end
          assert.are.equal("SEQ", rows.ActionButton1.Sequence, "the Default row stays")
        end)

        it(classfile .. ": a press and what GSE shows agree, on every bar, in every stance", function()
          -- What turns to a stance bar: the Default row stays off it there.
          local turning = { blizzardMainBar, dominosMainBar, daylightMainBar, driverPagedBar }
          -- EllesmereUI's bar too, on the clients it runs on.
          if client.forever or client.name == "Retail" then turning[#turning + 1] = ellesmereMainBar end
          -- What does not: the Default row runs whatever the stance.
          local still = { blizzardBar2, dominosBarOnBonusSlots }
          local stances = { 0 }
          for _, bonus in ipairs(bonuses) do stances[#stances + 1] = bonus end
          for _, bonus in ipairs(stances) do
            local page = 6 + bonus
            for _, build in ipairs(turning) do
              local env = login(client, classfile)
              local b = build(env)
              local where = b:GetName() .. " bonus " .. bonus
              local shown, pressed = press(env, b, bonus, { default = true })
              assert.are.equal(tostring(shown), tostring(pressed), "Default only, " .. where)
              if bonus == 0 then
                assert.are.equal("DEFAULT", shown, "the bar itself, " .. where)
              else
                assert.is_nil(shown, "the stance bar is its own, " .. where)
                shown, pressed = press(env, b, bonus, { default = true, pinned = { page } })
                assert.are.equal("PINNED" .. page, shown, "its own row, " .. where)
                assert.are.equal(shown, pressed, "its own row, " .. where)
                shown, pressed = press(env, b, 0, { default = true, pinned = { page } })
                assert.are.equal("DEFAULT", shown, "out of it again, " .. where)
                assert.are.equal(shown, pressed, "out of it again, " .. where)
                shown, pressed = press(env, b, 0, { pinned = { page } })
                assert.is_nil(shown, "a stance's row is not the bar's, " .. where)
                assert.is_nil(pressed, "a stance's row is not the bar's, " .. where)
              end
            end
            for _, build in ipairs(still) do
              local env = login(client, classfile)
              local b = build(env)
              local where = b:GetName() .. " bonus " .. bonus
              local shown, pressed = press(env, b, bonus, { default = true })
              assert.are.equal("DEFAULT", shown, "a bar that turns to no other, " .. where)
              assert.are.equal(shown, pressed, "a bar that turns to no other, " .. where)
            end
          end
        end)
      end

      it("keeps the Default row in every state of a LibActionButton bar (Bartender4, ElvUI, NDui, ConsolePort)", function()
        local env = login(client, "DRUID")
        local b = newButton(env, "BT4Button1", { lab = { ["0"] = "action", ["7"] = "action", ["9"] = "action" },
          attrs = { state = "7" }, turn = function() end })
        env.GSE.ButtonOverrides.BT4Button1, env.GSE.ButtonOverrideDefaults.BT4Button1 = "DEFAULT", true
        assert.are.same({}, env.GSE.ButtonStancePages("BT4Button1"))
        assert.are.equal("DEFAULT", env.GSE.ButtonOverrideSequence("BT4Button1"))
        env.GSE.ButtonOverrideStates.BT4Button1 = { ["7"] = "CAT" }
        assert.are.equal("CAT", env.GSE.ButtonOverrideSequence("BT4Button1"))
        b.attrs.state = "9"
        assert.are.equal("DEFAULT", env.GSE.ButtonOverrideSequence("BT4Button1"))
      end)
    end)
  end

  -- EllesmereUI's stance bars follow the rule the others do (Larry,
  -- 2026-11-21): GSE reads the conditions EllesmereUI keeps on the bar.
  describe("EllesmereUI's own paging", function()
    local forever, retail = CLIENTS[4], CLIENTS[5]

    it("is seen, though registered where GSE's hook is not, and as it is now", function()
      local env = login(forever, "DRUID")
      local b = ellesmereMainBar(env)
      assert.are.equal(ellesmereConditions(forever, "DRUID"), env.GSE.ButtonPageDriver("EABButton1"))
      -- The player changes the bar's paging in EllesmereUI's options.
      b:GetParent()._eabPagingConds = "[bonusbar:1] 5; 1"
      assert.are.equal("[bonusbar:1] 5; 1", env.GSE.ButtonPageDriver("EABButton1"))
    end)

    it("names a State for each stance bar the class has on the client, and no other", function()
      local env = login(forever, "DRUID")
      local states = env.GSE.OverrideStatesFor(ellesmereMainBar(env):GetName())
      assert.are.equal("Cat Form", states["7"])
      assert.are.equal("Bear Form", states["9"])
      assert.is_nil(states["8"], "Tree of Life: no bar on WoW Forever")
      assert.is_nil(states["10"], "Moonkin Form: no bar on WoW Forever, though EllesmereUI sends bonus bar 4 to page 10")
      env = login(forever, "WARRIOR")
      states = env.GSE.OverrideStatesFor(ellesmereMainBar(env):GetName())
      assert.are.same({ "Battle Stance", "Defensive Stance", "Berserker Stance" }, { states["7"], states["8"], states["9"] })
      env = login(forever, "PRIEST")
      assert.is_nil(env.GSE.OverrideStatesFor(ellesmereMainBar(env):GetName()), "Shadowform: no bar on WoW Forever")
      env = login(retail, "DRUID")
      states = env.GSE.OverrideStatesFor(ellesmereMainBar(env):GetName())
      assert.are.same({ "Cat Form", "Bear Form", "Moonkin Form" }, { states["7"], states["9"], states["10"] })
      env = login(retail, "WARRIOR")
      assert.is_nil(env.GSE.OverrideStatesFor(ellesmereMainBar(env):GetName()), "stances turn no bar on Retail")
    end)

    it("follows a form the player put on a page of their own", function()
      local env = login(forever, "DRUID")
      local b = ellesmereMainBar(env, "[bonusbar:1] 5; [bonusbar:3] 9; 1")
      assert.are.equal("Cat Form", env.GSE.OverrideStatesFor("EABButton1")["5"])
      assert.is_true(env.GSE.ButtonStancePages("EABButton1")[5])
      local shown, pressed = press(env, b, 1, { default = true })
      assert.is_nil(shown, "Cat Form's page is its own")
      assert.is_nil(pressed)
      shown, pressed = press(env, b, 1, { default = true, pinned = { 5 } })
      assert.are.equal("PINNED5", shown)
      assert.are.equal(shown, pressed)
      shown, pressed = press(env, b, 0, { default = true, pinned = { 5 } })
      assert.are.equal("DEFAULT", shown)
      assert.are.equal(shown, pressed)
    end)

    it("leaves a LibActionButton bar's states named as its driver has them", function()
      -- Bartender4 on WoW Forever: the state is the bar's own, whether or not
      -- its form brings up a bar there.
      local env = login(forever, "DRUID")
      local bar = {}
      env.RegisterStateDriver(bar, "page", "[bonusbar:1] 7; [bonusbar:4] 10; 0")
      newButton(env, "BT4Button1", { parent = bar, attrs = { state = "0" },
        lab = { ["0"] = "action", ["7"] = "action", ["10"] = "action" } })
      local states = env.GSE.OverrideStatesFor("BT4Button1")
      assert.are.equal("Cat Form", states["7"])
      assert.are.equal("Moonkin Form", states["10"])
    end)

    it("keeps the Default row on a bar EllesmereUI holds to one page", function()
      local env = login(forever, "DRUID")
      local b = ellesmereMainBar(env, false)
      assert.is_nil(env.GSE.ButtonPageDriver("EABButton1"))
      assert.are.same({}, env.GSE.ButtonStancePages("EABButton1"))
      local shown, pressed = press(env, b, 1, { default = true })
      assert.are.equal("DEFAULT", shown)
      assert.are.equal(shown, pressed)
    end)
  end)

  -- DaylightUI's stance bars by the rule it pages with (Larry, 2026-11-21):
  -- asked of its action bar module, since no driver of its is seen.
  describe("DaylightUI's own paging", function()
    local forever = CLIENTS[4]

    it("is asked of DaylightUI, and a rule registered since is the one in use", function()
      local env = login(forever, "WARRIOR")
      local rules = { main = DAYLIGHT_RULES.WARRIOR }
      local _, _, _, holders = daylightUI(env, rules)
      assert.are.equal(DAYLIGHT_RULES.WARRIOR, env.GSE.ButtonPageDriver("DaylightUIBar1Button1"))
      -- The player changes bar 1's paging: DaylightUI registers the new rule.
      env.RegisterStateDriver(holders.main, "page", "[mod:shift] 2; 1")
      assert.are.equal("[mod:shift] 2; 1", env.GSE.ButtonPageDriver("DaylightUIBar1Button1"))
    end)

    it("is asked by the button's name: one DaylightUI has parked off its bar is still on it", function()
      local env = login(forever, "WARRIOR")
      local b = daylightUI(env, { main = DAYLIGHT_RULES.WARRIOR })
      b.shape.parent = {}
      assert.are.equal(DAYLIGHT_RULES.WARRIOR, env.GSE.ButtonPageDriver("DaylightUIBar1Button1"))
    end)

    it("a druid's Moonkin Form is a bar of its own there, by form", function()
      local env = login(forever, "DRUID")
      local b = daylightUI(env, { main = DAYLIGHT_RULES.DRUID })
      local states = env.GSE.OverrideStatesFor("DaylightUIBar1Button1")
      assert.are.same({ "Cat Form", "Bear Form", "Moonkin Form" }, { states["7"], states["9"], states["10"] })
      assert.is_nil(states["8"])
      for _, stance in ipairs({ 1, 3, 4 }) do
        local page = 6 + stance
        local shown, pressed = press(env, b, stance, { default = true })
        assert.is_nil(shown, "the form's bar is its own, page " .. page)
        assert.is_nil(pressed)
        shown, pressed = press(env, b, stance, { default = true, pinned = { page } })
        assert.are.equal("PINNED" .. page, shown)
        assert.are.equal(shown, pressed)
      end
      local shown, pressed = press(env, b, 0, { default = true, pinned = { 10 } })
      assert.are.equal("DEFAULT", shown, "out of form")
      assert.are.equal(shown, pressed)
    end)

    it("a priest's Shadowform is a State there, named though it has no place on the stance bar", function()
      local env = login(forever, "PRIEST")
      local b = daylightUI(env, { main = DAYLIGHT_RULES.PRIEST })
      assert.are.equal("Shadowform", env.GSE.OverrideStatesFor("DaylightUIBar1Button1")["7"])
      local shown, pressed = press(env, b, 1, { default = true })
      assert.is_nil(shown)
      assert.is_nil(pressed)
      shown, pressed = press(env, b, 1, { default = true, pinned = { 7 } })
      assert.are.equal("PINNED7", shown)
      assert.are.equal(shown, pressed)
    end)

    it("a warrior's three stances, and no fourth", function()
      local env = login(forever, "WARRIOR")
      daylightUI(env, { main = DAYLIGHT_RULES.WARRIOR })
      local states = env.GSE.OverrideStatesFor("DaylightUIBar1Button1")
      assert.are.same({ "Battle Stance", "Defensive Stance", "Berserker Stance" }, { states["7"], states["8"], states["9"] })
      assert.is_nil(states["10"])
    end)

    it("a prowling cat's own bar is Prowl", function()
      local env = login(forever, "DRUID")
      local spell = env.GSE.GetSpellInfo
      env.GSE.GetSpellInfo = function(id) return id == 5215 and { name = "Prowl" } or spell(id) end
      daylightUI(env, { main = "[form:3,stealth] 8; [form:3] 7; [form:1] 9; 1" })
      local states = env.GSE.OverrideStatesFor("DaylightUIBar1Button1")
      assert.are.equal("Prowl", states["8"])
      assert.are.equal("Cat Form", states["7"])
    end)

    it("with Change with forms and stances off, the bar is one bar", function()
      local env = login(forever, "WARRIOR")
      local b = daylightUI(env, { main = DAYLIGHT_HEAD .. "[bonusbar:1] 1:f1; [bonusbar:2] 1:f2; [bonusbar:3] 1:f3; 1" })
      assert.is_nil(env.GSE.OverrideStatesFor("DaylightUIBar1Button1"))
      assert.are.same({}, env.GSE.ButtonStancePages("DaylightUIBar1Button1"))
      local shown, pressed = press(env, b, 2, { default = true })
      assert.are.equal("DEFAULT", shown)
      assert.are.equal(shown, pressed)
    end)

    it("a bar 2-8 pages where the player set it to, until the paging is removed", function()
      local env = login(forever, "WARRIOR")
      local rules = { main = DAYLIGHT_RULES.WARRIOR }
      local _, bar2, _, holders = daylightUI(env, rules)
      assert.is_nil(env.GSE.ButtonPageDriver("DaylightUIBar2Button1"), "no paging set: the bar's own page")
      local shown, pressed = press(env, bar2, 1, { default = true })
      assert.are.equal("DEFAULT", shown)
      assert.are.equal(shown, pressed)
      -- Battle Stance sent to page 3 in DaylightUI's options.
      rules.bar2 = "[bonusbar:1] 3; 6"
      assert.are.equal("Battle Stance", env.GSE.OverrideStatesFor("DaylightUIBar2Button1")["3"])
      shown, pressed = press(env, bar2, 1, { default = true })
      assert.is_nil(shown, "Battle Stance's page is its own")
      assert.is_nil(pressed)
      shown, pressed = press(env, bar2, 2, { default = true })
      assert.are.equal("DEFAULT", shown, "Defensive Stance leaves the bar where it is")
      assert.are.equal(shown, pressed)
      -- Removed again: DaylightUI takes the driver off.
      rules.bar2 = nil
      env.UnregisterStateDriver(holders.bar2, "page")
      assert.is_nil(env.GSE.ButtonPageDriver("DaylightUIBar2Button1"))
    end)

    it("falls back to Blizzard's pages when DaylightUI cannot be asked", function()
      for _, broken in ipairs({ "off", "no module", "errors" }) do
        local env = login(forever, "WARRIOR")
        local b, _, mod = daylightUI(env, { main = DAYLIGHT_RULES.WARRIOR })
        if broken == "off" then mod.enabled = false end
        if broken == "no module" then env.DaylightUI.GetModule = function() return nil end end
        if broken == "errors" then mod.ns.Paging.Rule = function() error("not built yet") end end
        assert.is_nil(env.GSE.ButtonPageDriver("DaylightUIBar1Button1"), broken)
        assert.are.equal("Battle Stance", env.GSE.OverrideStatesFor("DaylightUIBar1Button1")["7"], broken)
        b.shape.turn = function(btn, bonus) btn.attrs.action = bonus > 0 and slotOnBonus(bonus) or 1 end
        local shown, pressed = press(env, b, 1, { default = true })
        assert.is_nil(shown, broken)
        assert.is_nil(pressed, broken)
      end
    end)
  end)

  -- A sequence stays on the bars through a change of bar addon (Larry,
  -- 2026-11-21: "swapping UI Addons removes GSE Sequences from the ActionBars
  -- > the Sequence and Binds should stay"). A row is saved under a button's
  -- name, which is the bar addon's own; the action slot the button holds is
  -- the same in all of them.
  describe("A change of bar addon", function()
    local forever = CLIENTS[4]
    -- The bars as a bar addon leaves them: Blizzard's buttons are always
    -- there (hidden under a bar addon), with the bar addon's own beside them.
    local function bars(...)
      local env = login(forever, "ROGUE")
      for _, name in ipairs({ "ActionButton1", "ActionButton2", "MultiBarBottomLeftButton3", ... }) do
        newButton(env, name, { attrs = {} })
      end
      return env
    end
    local function binds(rows)
      local out = {}
      for key, row in pairs(rows) do
        assert.are.equal(key, row.Bind .. (row.State and ("-" .. row.State) or ""), "a row is filed under its button and State")
        out[#out + 1] = key .. "=" .. row.Sequence
      end
      table.sort(out)
      return out
    end

    it("knows each bar addon's button by the slot it holds", function()
      local GSE = bars().GSE
      local same = {
        [1] = { Blizzard = "ActionButton1", EllesmereUI = "EABButton1", DaylightUI = "DaylightUIBar1Button1",
          ElvUI = "ElvUI_Bar1Button1", Bartender4 = "BT4Button1", NDui = "NDui_ActionBar1Button1" },
        -- Blizzard's Action Bar 2 is page 6: ElvUI's and Bartender4's bar 6.
        [63] = { Blizzard = "MultiBarBottomLeftButton3", EllesmereUI = "EABButton63", DaylightUI = "DaylightUIBar2Button3",
          ElvUI = "ElvUI_Bar6Button3", Bartender4 = "BT4Button63", NDui = "NDui_ActionBar2Button3" },
        -- Action Bar 8 is page 15.
        [180] = { Blizzard = "MultiBar7Button12", EllesmereUI = "EABButton180", DaylightUI = "DaylightUIBar8Button12",
          ElvUI = "ElvUI_Bar15Button12", Bartender4 = "BT4Button180", NDui = "NDui_ActionBar8Button12" },
      }
      for slot, names in pairs(same) do
        for family, name in pairs(names) do
          local f, s = GSE.ButtonHomeSlot(name)
          assert.are.equal(family, f, name)
          assert.are.equal(slot, s, name)
        end
      end
      for _, other in ipairs({ "GSEButton1", "CPB_PAD1", "ButtonForge12", "DaylightUIBar9Button1", "ActionButton13",
        "MultiBarBottomLeftButton0", "ElvUI_Bar1Button13", "PetActionButton1" }) do
        assert.is_nil(GSE.ButtonHomeSlot(other), other)
      end
    end)

    it("moves a sequence and its stance rows to the bar addon now running, and back", function()
      -- As saved on Larry's rogue under EllesmereUI; ElvUI is running.
      local rows = {
        EABButton1 = { Bind = "EABButton1", Sequence = "SEQ" },
        ["EABButton1-7"] = { Bind = "EABButton1", State = "7", Sequence = "SEQ" },
        GSEButton1 = { Bind = "GSEButton1", Sequence = "OWN" },
      }
      local env = bars("ElvUI_Bar1Button1")
      assert.are.equal(2, env.GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "ElvUI_Bar1Button1-7=SEQ", "ElvUI_Bar1Button1=SEQ", "GSEButton1=OWN" }, binds(rows))
      assert.are.equal(0, env.GSE.MoveRowsToActiveBars(rows), "nothing left to move")
      -- DaylightUI the next day, EllesmereUI again after it, then no bar addon.
      assert.are.equal(2, bars("DaylightUIBar1Button1").GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "DaylightUIBar1Button1-7=SEQ", "DaylightUIBar1Button1=SEQ", "GSEButton1=OWN" }, binds(rows))
      assert.are.equal(2, bars("EABButton1").GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "EABButton1-7=SEQ", "EABButton1=SEQ", "GSEButton1=OWN" }, binds(rows))
      assert.are.equal(2, bars().GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "ActionButton1-7=SEQ", "ActionButton1=SEQ", "GSEButton1=OWN" }, binds(rows))
    end)

    it("keeps a row's every field: it is the same row", function()
      local row = { Bind = "ActionButton2", State = "7", Sequence = "SEQ", StancesCopied = true }
      local rows = { ["ActionButton2-7"] = row }
      bars("BT4Button1", "BT4Button2").GSE.MoveRowsToActiveBars(rows)
      assert.are.equal(row, rows["BT4Button2-7"])
      assert.are.same({ Bind = "BT4Button2", State = "7", Sequence = "SEQ", StancesCopied = true }, row)
    end)

    it("moves a bar 2 row to the bar on the same slots", function()
      for _, name in ipairs({ "EABButton63", "DaylightUIBar2Button3", "ElvUI_Bar6Button3", "BT4Button63", "NDui_ActionBar2Button3" }) do
        local rows = { [name] = { Bind = name, Sequence = "SEQ" } }
        assert.are.equal(1, bars().GSE.MoveRowsToActiveBars(rows), name)
        assert.are.same({ "MultiBarBottomLeftButton3=SEQ" }, binds(rows), name)
      end
    end)

    it("leaves a row whose slot has no button here, for the day its bar addon is back", function()
      -- ElvUI's bar 2 is page 2, which no Blizzard bar shows.
      local rows = { ElvUI_Bar2Button1 = { Bind = "ElvUI_Bar2Button1", Sequence = "SEQ" } }
      assert.are.equal(0, bars().GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "ElvUI_Bar2Button1=SEQ" }, binds(rows))
      -- EllesmereUI has not built this bar's buttons (the bar is hidden).
      rows = { MultiBarBottomLeftButton3 = { Bind = "MultiBarBottomLeftButton3", Sequence = "SEQ" } }
      assert.are.equal(0, bars("EABButton1").GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "MultiBarBottomLeftButton3=SEQ" }, binds(rows))
    end)

    it("never writes over a row the button here already has", function()
      local rows = {
        EABButton1 = { Bind = "EABButton1", Sequence = "OLD" },
        ElvUI_Bar1Button1 = { Bind = "ElvUI_Bar1Button1", Sequence = "MINE" },
        ["EABButton1-7"] = { Bind = "EABButton1", State = "7", Sequence = "STEALTH" },
      }
      assert.are.equal(1, bars("ElvUI_Bar1Button1").GSE.MoveRowsToActiveBars(rows))
      assert.are.same({ "EABButton1=OLD", "ElvUI_Bar1Button1-7=STEALTH", "ElvUI_Bar1Button1=MINE" }, binds(rows))
    end)

    it("leaves the rows alone where the bar addon is the one they were saved under", function()
      local rows = { ElvUI_Bar1Button1 = { Bind = "ElvUI_Bar1Button1", Sequence = "SEQ" } }
      assert.are.equal(0, bars("ElvUI_Bar1Button1").GSE.MoveRowsToActiveBars(rows))
      -- Dominos keeps Blizzard's names: nothing to move with it, or without.
      rows = { ActionButton1 = { Bind = "ActionButton1", Sequence = "SEQ" } }
      assert.are.equal(0, bars("DominosActionButton13").GSE.MoveRowsToActiveBars(rows))
      assert.are.equal(0, bars().GSE.MoveRowsToActiveBars(nil), "no rows at all")
    end)

    it("is done as the overrides are loaded, for the spec's rows and the loadout's, before they go on", function()
      local load = between(events, "local function LoadOverrides(force)", "\nfunction GSE.ReloadOverrides(force)")
      local spec = assert(load:find("GSE.MoveRowsToActiveBars(GSE.SpecOverrides(GetSpec(), false))", 1, true))
      local loadout = assert(load:find("GSE.MoveRowsToActiveBars(loadoutRows)", 1, true))
      local copy = assert(load:find("GSE.CopyDefaultRowsToStances(GetSpec())", 1, true))
      local apply = assert(load:find("GSE.OverridesToApply(GSE.SpecOverrides(GetSpec(), false), loadoutRows)", 1, true))
      assert.is_true(spec < copy and loadout < copy and copy < apply)
    end)

    it("an ElvUI bar's own state is its own page, so a sequence put on it is the bar's Default", function()
      local env = bars()
      assert.are.equal("1", env.GSE.LABDefaultState("ElvUI_Bar1Button1"))
      assert.are.equal("3", env.GSE.LABDefaultState("ElvUI_Bar3Button12"))
      assert.are.equal("13", env.GSE.LABDefaultState("ElvUI_Bar13Button1"))
      assert.are.equal("0", env.GSE.LABDefaultState("BT4Button25"))
      local lab = {}
      for k = 1, 18 do lab[tostring(k)] = "action" end
      local b = newButton(env, "ElvUI_Bar3Button1", { parent = {}, attrs = { state = "3" }, lab = lab })
      assert.is_nil(env.GSE.OverrideStateFor(b))
    end)
  end)

  -- The upgrade, for a class that is never out of a stance (a warrior on
  -- Classic Era here): its Default rows ran in every stance with no row of its
  -- own, and after the update would never run.
  describe("Default rows on an upgrade", function()
    local era = CLIENTS[1]
    local function world(build)
      local env = login(era, "WARRIOR")
      local b = build and build(env)
      local rows = {}
      env.GSE.SpecOverrides = function() return rows end
      return env, rows, b
    end

    it("leaves a stance's own row as it is, and fills the others", function()
      local env, rows = world(blizzardMainBar)
      rows.ActionButton1 = { Bind = "ActionButton1", Sequence = "SEQ" }
      rows["ActionButton1-8"] = { Bind = "ActionButton1", State = "8", Sequence = "TANK" }
      assert.are.equal(2, env.GSE.CopyDefaultRowsToStances("spec"))
      assert.are.equal("TANK", rows["ActionButton1-8"].Sequence)
      assert.are.equal("SEQ", rows["ActionButton1-7"].Sequence)
      assert.are.equal("SEQ", rows["ActionButton1-9"].Sequence)
    end)

    it("is done once: a stance unticked afterwards stays unticked", function()
      local env, rows = world(blizzardMainBar)
      rows.ActionButton1 = { Bind = "ActionButton1", Sequence = "SEQ" }
      assert.are.equal(3, env.GSE.CopyDefaultRowsToStances("spec"))
      rows["ActionButton1-9"] = nil
      assert.are.equal(0, env.GSE.CopyDefaultRowsToStances("spec"))
      assert.is_nil(rows["ActionButton1-9"])
    end)

    it("waits for a button that is not there yet", function()
      local env, rows = world()
      rows.ActionButton1 = { Bind = "ActionButton1", Sequence = "SEQ" }
      assert.are.equal(0, env.GSE.CopyDefaultRowsToStances("spec"))
      assert.is_nil(rows.ActionButton1.StancesCopied, "not looked at: its bar addon is off this login")
      blizzardMainBar(env)
      assert.are.equal(3, env.GSE.CopyDefaultRowsToStances("spec"))
    end)

    it("adds nothing on a bar that turns to no stance bar", function()
      for _, build in ipairs({ blizzardBar2, dominosBarOnBonusSlots }) do
        local env, rows, b = world(build)
        rows[b:GetName()] = { Bind = b:GetName(), Sequence = "SEQ" }
        assert.are.equal(0, env.GSE.CopyDefaultRowsToStances("spec"), b:GetName())
        assert.is_true(rows[b:GetName()].StancesCopied)
      end
      local env, rows = world()
      newButton(env, "BT4Button1", { lab = { ["0"] = "action", ["7"] = "action" }, attrs = { state = "7" } })
      rows.BT4Button1 = { Bind = "BT4Button1", Sequence = "SEQ" }
      assert.are.equal(0, env.GSE.CopyDefaultRowsToStances("spec"), "a LibActionButton bar keeps its Default row")
    end)

    it("fills Dominos' first bar as it does Blizzard's", function()
      local env, rows, b = world(dominosMainBar)
      rows[b:GetName()] = { Bind = b:GetName(), Sequence = "SEQ" }
      assert.are.equal(3, env.GSE.CopyDefaultRowsToStances("spec"))
    end)

    it("marks a Default row made after it as the player's own, and runs before the rows go on", function()
      assert.truthy(profiles:find("if state == nil and alwaysStancePages() then bind.StancesCopied = true end", 1, true))
      local load = between(events, "local function LoadOverrides(force)", "\nfunction GSE.ReloadOverrides(force)")
      local copy = assert(load:find("GSE.CopyDefaultRowsToStances(GetSpec())", 1, true))
      local apply = assert(load:find("GSE.OverridesToApply(GSE.SpecOverrides(GetSpec(), false), loadoutRows)", 1, true))
      assert.is_true(copy < apply)
    end)
  end)

  it("a Dominos bar set on the bonus-bar slots keeps its Default row, and a row pinned there", function()
    local env = login(CLIENTS[5], "ROGUE")
    local b = dominosBarOnBonusSlots(env)
    assert.are.same({ [8] = true, [9] = true, [10] = true }, env.GSE.ButtonStancePages(b:GetName()),
      "its own page (7) is no stance page of its")
    local shown, pressed = press(env, b, 1, { default = true, pinned = { 7 } })
    assert.are.equal("PINNED7", shown)
    assert.are.equal(shown, pressed)
  end)
end)
