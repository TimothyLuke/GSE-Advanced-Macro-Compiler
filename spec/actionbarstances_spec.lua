-- Stance, form and stealth bars.
--
-- Blizzard's main bar turns to another bar for a stance, form or stealth, and
-- a sequence can be pinned to one (State). These hold the rules for what runs
-- and shows on each. The GSE Action Bar never turns and has no states (Tim:
-- Blizzard's stance bar is enough).
--
-- The addon files cannot be loaded here, so this reads them as text (line
-- endings normalised) and runs the pieces against a button.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function body(src, startPattern, endPattern)
  local s = assert(src:find(startPattern), "start not found: " .. startPattern)
  local _, e = src:find(endPattern, s)
  assert(e, "end not found: " .. endPattern)
  return src:sub(s, e)
end

local function compile(code, name, env)
  if loadstring then
    local chunk = assert(loadstring(code, name))
    setfenv(chunk, env)
    return chunk
  end
  return assert(load(code, name, "t", env))
end

-- A stance, form or stealth bar is a bar of its own. A Default row took every
-- page no pinned row held, so a sequence put on Blizzard's main bar also
-- showed and ran on its empty stealth bar (Larry, 2026-11-20: "its showing an
-- assigned Icon when I do NOT have a Sequence assigned to 1 on the Stance
-- bar"). Now the Default row stays off the stance pages of a bar that turns to
-- them.
describe("A Default row stays off a stance bar", function()
  local events = readSource("GSE/API/Events.lua")
  local profiles = readSource("GSE/API/Profiles.lua")

  -- BAR_SWAP_ONCLICK as Events.lua builds it, run against a main-bar button.
  local function onClick(attributes, world)
    local resolve = assert(events:match("local BAR_SWAP_RESOLVE = %[%[(.-)%]%]"), "BAR_SWAP_RESOLVE not found")
    local head, tail = events:match("local BAR_SWAP_ONCLICK = %[%[(.-)%]%] %.%. BAR_SWAP_RESOLVE %.%. %[%[(.-)%]%]")
    assert(head and tail, "BAR_SWAP_ONCLICK not built from BAR_SWAP_RESOLVE")
    local env = {
      floor = math.floor, tonumber = tonumber,
      GetBonusBarOffset = function() return world.bonus or 0 end,
      GetActionInfo = function(slot) return world.slots and world.slots[slot] end,
      self = {
        GetID = function() return 1 end,
        GetEffectiveAttribute = function(_, name) return attributes[name] end,
        GetAttribute = function(_, name) return attributes[name] end,
        SetAttribute = function(_, name, value) attributes[name] = value end,
      },
    }
    return compile(head .. resolve .. tail, "BAR_SWAP_ONCLICK", env)()
  end
  local function mainBar(extra)
    local a = { ["gse-secure"] = true, ["gse-bonus-paged"] = true, actionpage = 1,
      ["gse-stance-7"] = true, ["gse-stance-8"] = true, ["gse-stance-9"] = true, ["gse-stance-10"] = true }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
  end

  it("leaves the stealth bar's button its own when only the Default row is on it", function()
    local a = mainBar({ ["gse-default"] = true })
    assert.is_nil(onClick(a, { bonus = 1 }))
    assert.are.equal("action", a.type)
    assert.are.equal(73, a["gse-eff-action"], "the stealth bar's slot shows")
  end)

  it("runs the Default row on the main bar, and on a page turned to by hand", function()
    local a = mainBar({ ["gse-default"] = true })
    assert.is_nil(onClick(a, { bonus = 0 }))
    assert.are.equal("click", a.type)
    a.actionpage = 2
    assert.is_nil(onClick(a, { bonus = 0 }))
    assert.are.equal("click", a.type)
  end)

  it("runs a row pinned to the stance there, beside the Default row", function()
    local a = mainBar({ ["gse-default"] = true, ["gse-page-7"] = true })
    assert.are.equal("gse7", onClick(a, { bonus = 1 }))
    assert.are.equal("click", a.type)
    assert.is_nil(onClick(a, { bonus = 3 }), "Bear: no row, and not the Default's")
    assert.are.equal("action", a.type)
  end)

  it("keeps the Default row on every page of a bar that has no stance pages", function()
    local a = { ["gse-secure"] = true, ["gse-default"] = true, actionpage = 1 }
    assert.is_nil(onClick(a, { bonus = 1 }))
    assert.are.equal("click", a.type)
  end)

  it("marks a button's stance pages with its Default row, and takes the marks off again", function()
    local arm = body(events, "local function armRow%(button, buttonName, sequenceName, state%)", "\nend\n")
    assert.truthy(arm:find("GSE.ButtonStancePages(buttonName)", 1, true), "the pages a stance turns the button to")
    assert.truthy(arm:find("secureArmGSEButton(button, sequenceName, true, stancePages)", 1, true))
    local pages = body(profiles, "function GSE.ButtonStancePages%(buttonName%)", "\nend\n")
    -- One list for both: the pages the button's State choices are made from.
    assert.truthy(pages:find("statePages(buttonName, frame)", 1, true))
    local choices = body(profiles, "function GSE.OverrideStatesFor%(buttonName, saved%)", "\nend\n")
    assert.truthy(choices:find("statePages(buttonName, frame)", 1, true), "the State choices the button is given")
    local armed = body(events, "local function secureArmGSEButton%(button, sequenceName, asDefault, stancePages%)", "\nend\n")
    assert.truthy(armed:find("gse-stance-", 1, true))
    local disarm = body(events, "local function secureDisarmGSEButton%(button, pages%)", "\nend\n")
    assert.truthy(disarm:find('b:SetAttribute("gse-stance-" .. page, nil)', 1, true))
  end)

  -- GSE.ButtonOverrideSequence as Profiles.lua has it, for a button in a
  -- state. The button's stance pages are GSE.ButtonStancePages': the same ones
  -- its click is marked with (actionbarcrossversion_spec.lua runs both).
  local function sequenceNow(button, state, rows)
    local GSE = {
      ButtonOverrides = { TheButton = "default" }, ButtonOverrideDefaults = { TheButton = true },
      ButtonOverrideStates = rows and { TheButton = rows } or {},
      OverrideStateFor = function() return state end,
      ButtonStancePages = function() return button.stancePages end,
    }
    local code = body(profiles, "function GSE.ButtonOverrideSequence%(buttonName%)", "\nend\n")
      .. "\nreturn GSE.ButtonOverrideSequence"
    local env = { GSE = GSE, type = type, tostring = tostring, tonumber = tonumber, _G = { TheButton = button } }
    return compile(code, "ButtonOverrideSequence", env)()("TheButton")
  end
  local mainBarButton = { GetAttribute = function() return nil end,
    stancePages = { [7] = true, [8] = true, [9] = true, [10] = true } }
  local labButton = { GetAttribute = function() return nil end, SetState = function() end, stancePages = {} }

  it("shows nothing on a stance bar's button that has only the Default row", function()
    assert.is_nil(sequenceNow(mainBarButton, "7"))
    assert.are.equal("default", sequenceNow(mainBarButton, nil), "the main bar itself")
    assert.are.equal("stealth", sequenceNow(mainBarButton, "7", { ["7"] = "stealth" }))
    assert.is_nil(sequenceNow(mainBarButton, "9", { ["7"] = "stealth" }), "another stance's row is not this one's")
  end)

  it("keeps the Default row in every state of a LibActionButton bar", function()
    assert.are.equal("default", sequenceNow(labButton, "7"))
  end)

  it("gives the GSE Action Bar no states: one sequence, whatever the stance", function()
    local pages = body(events, "function GSE.ButtonPagesWithForms%(buttonName%)", "\nend\n")
    assert.truthy(pages:find('if type(button) ~= "table" or button.gseActionBarButton then return false end', 1, true))
    local state = body(events, "function GSE.OverrideStateFor%(button%)", "\nend\n")
    assert.truthy(state:find("or button.gseActionBarButton then return nil end", 1, true))
    local actions = readSource("GSE_Actionbar/Actions.lua")
    assert.is_nil(actions:find("gse-page-", 1, true), "its click picks no row by stance")
  end)

  it("paints a sequence's icon only on a button that runs it now", function()
    local storage = readSource("GSE/API/Storage.lua")
    assert.is_nil(storage:find("GSE.ButtonOverrideSequence(k) or v", 1, true),
      "the button's sequence in a state it has no row for")
    assert.truthy(storage:find("if GSE.ButtonOverrideSequence then runs = GSE.ButtonOverrideSequence(k) end", 1, true))
  end)

  it("draws no cooldown, count or glow of the override where nothing runs on the button", function()
    local showing = body(events, "local function overrideShowing%(button%)", "GSE.ActionBarOverrideShowing = overrideShowing")
    assert.truthy(showing:find("if not overrideSequence(button) then return false end", 1, true))
    local repaint = body(events, "local function repaintStanceRows%(%)", "function GSE:UPDATE_BONUS_ACTIONBAR")
    assert.truthy(repaint:find("if not runs and overrideSpell[button] then", 1, true))
    assert.truthy(repaint:find("button.cooldown:Clear()", 1, true))
  end)

  it("has the menu assign, not change, where nothing runs on the button", function()
    local menu = readSource("GSE_Utils/Utils.lua")
    assert.truthy(menu:find("existingSequence = GSE.ButtonOverrideSequence(self:GetName())", 1, true))
  end)
end)
