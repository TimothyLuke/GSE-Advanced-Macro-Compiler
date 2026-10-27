-- Action-bar overrides on LibActionButton bars (Bartender4, ElvUI, NDui, CPB_).
--
-- GSE takes over EVERY paging state of a LAB button (0-18 on Bartender4), but
-- clearing restored only state "0" and left gse-button set, so a cleared
-- override stayed live on every other page, form and stance. And the drag
-- scan walked the UI under one pcall, so the first frame that errored ended
-- the walk and Bartender4's bars -- created late -- were never drop targets.
--
-- Events.lua cannot be loaded here, so this reads it as text (line endings
-- normalised, CLAUDE.md) and checks the two rules hold.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function body(src, startPattern, endPattern)
  local s = assert(src:find(startPattern), "start not found: " .. startPattern)
  local e = assert(src:find(endPattern, s), "end not found: " .. endPattern)
  return src:sub(s, e)
end

describe("LAB action-bar overrides", function()
  local src = readSource("GSE/API/Events.lua")

  it("records each state's original before taking it over", function()
    local apply = body(src, "local function applyGSEState%(st%)", "_G%[Button%]:SetState%(st, \"custom\"")
    assert.truthy(apply:find("rememberState(st)", 1, true), "applyGSEState records the state first")
  end)

  it("restores every recorded state on clear, un-marking the button first", function()
    local revert = body(src, "local original = btn.gseLabOriginal", "removeGSEWatermark%(k%)")
    local unGSE = revert:find('btn:SetAttribute("gse-button", nil)', 1, true)
    local unmark = revert:find("gse-lab-state-", 1, true)
    local restore = revert:find("btn:SetState(r[1], r[2].kind, r[2].action)", 1, true)
    assert.truthy(unGSE, "gse-button is cleared")
    assert.truthy(unmark, "the per-state marks are cleared")
    assert.truthy(restore, "each recorded state is set back")
    assert.is_true(unGSE < restore and unmark < restore,
      "cleared before the states are restored, or a restored custom state is captured again")
    assert.truthy(revert:find("for st, was in pairs(original)", 1, true), "every recorded state, not one")
  end)

  it("guards each frame of the drag scan on its own", function()
    local scan = body(src, "local function collectOverrideTargets", "\nend\n")
    assert.truthy(scan:find("pcall(function()", 1, true), "per-frame pcall inside the walk")
  end)
end)

-- A button on a LibActionButton bar pages with stance, form or stealth: a
-- pinned row (State) puts a sequence on one state, a Default row on the
-- bar's default state (#1717, 3.2.18). Since June a Default row took EVERY
-- state, running over the pinned ones; and clickbutton, one per button, sent
-- every state to whichever sequence was applied last. Now a Default row takes
-- every state no pinned row holds, and each state clicks its own sequence.
describe("LAB states with their own sequences", function()
  local src = readSource("GSE/API/Events.lua")

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/Profiles")
  end)

  -- Put back what the last test faked first: Lua 5.1's runner has no after_each.
  local savedButton, savedOverrides, savedStates
  local function start()
    if savedOverrides ~= nil then
      _G.BT4Button1, GSE.ButtonOverrides, GSE.ButtonOverrideStates = savedButton, savedOverrides, savedStates
    end
    savedButton, savedOverrides, savedStates = _G.BT4Button1, GSE.ButtonOverrides or false, GSE.ButtonOverrideStates
  end
  after_each(function()
    if savedOverrides == nil then return end
    _G.BT4Button1, GSE.ButtonOverrides, GSE.ButtonOverrideStates = savedButton, savedOverrides or nil, savedStates
    savedOverrides = nil
  end)

  it("knows each bar addon's default state, NDui's included", function()
    assert.are.equal("0", GSE.LABDefaultState("BT4Button1"))
    assert.are.equal("1", GSE.LABDefaultState("ElvUI_Bar1Button1"))
    assert.are.equal("", GSE.LABDefaultState("CPB_PAD2"))
    assert.are.equal("2", GSE.LABDefaultState("NDui_ActionBar1Button1"))
  end)

  it("applies a button's pinned states before its Default row, and says which states they hold", function()
    local rows, pinned = GSE.OverridesToApply({
      BT4Button1 = { Bind = "BT4Button1", Sequence = "caster" },
      ["BT4Button1-7"] = { Bind = "BT4Button1", State = "7", Sequence = "cat" },
      ["BT4Button1-9"] = { Bind = "BT4Button1", State = "9", Sequence = "bear" },
    })
    assert.are.equal(3, #rows)
    assert.are.equal("caster", rows[3].Sequence, "the Default row goes on last")
    assert.are.same({ BT4Button1 = { ["7"] = true, ["9"] = true } }, pinned)
  end)

  it("lets a talent loadout's row replace the spec's for the same button and state only", function()
    local rows, pinned = GSE.OverridesToApply({
      BT4Button1 = { Bind = "BT4Button1", Sequence = "caster" },
      ["BT4Button1-7"] = { Bind = "BT4Button1", State = "7", Sequence = "cat" },
    }, {
      ["BT4Button1-7"] = { Bind = "BT4Button1", State = "7", Sequence = "catPvP" },
    })
    local bySeq = {}
    for _, v in ipairs(rows) do bySeq[v.Sequence] = true end
    assert.are.same({ caster = true, catPvP = true }, bySeq)
    assert.are.same({ BT4Button1 = { ["7"] = true } }, pinned)
  end)

  it("names the sequence for the state the button is in", function()
    start()
    local state = "7"
    _G.BT4Button1 = { GetAttribute = function(_, name) if name == "state" then return state end end }
    GSE.ButtonOverrides = { BT4Button1 = "caster" }
    GSE.ButtonOverrideStates = { BT4Button1 = { ["0"] = "caster", ["7"] = "cat" } }
    assert.are.equal("cat", GSE.ButtonOverrideSequence("BT4Button1"))
    state = "0"
    assert.are.equal("caster", GSE.ButtonOverrideSequence("BT4Button1"))
    state = "3" -- a state GSE did not take: the button's own
    assert.are.equal("caster", GSE.ButtonOverrideSequence("BT4Button1"))
    assert.is_true(GSE.ButtonRunsSequence("BT4Button1", "cat"))
    assert.is_false(GSE.ButtonRunsSequence("BT4Button1", "bear"))
  end)

  it("leaves the pinned states out of a Default row's take-over", function()
    local default = body(src, "elseif type%(stateTypes%) == \"table\" and next%(stateTypes%) then", "\n            else\n")
    assert.truthy(default:find("not (pinnedStates and pinnedStates[tostring(st)])", 1, true))
    local load = body(src, "local function LoadOverrides%(force%)", "GSE.CheckOverrideKeys%(%)")
    assert.truthy(load:find("GSE.OverridesToApply(", 1, true))
    assert.truthy(load:find("overrideActionButton(v, force, pinned[v.Bind])", 1, true))
  end)

  it("gives each state its own click target, and takes them off again", function()
    local apply = body(src, "local function applyGSEState%(st%)", "_G%[Button%]:SetState%(st, \"custom\"")
    assert.truthy(apply:find('SetAttribute("clickbutton-gse" .. tostring(st), _G[Sequence])', 1, true))
    assert.truthy(src:find('SHBT:WrapScript(_G[Button], "OnClick", LAB_STATE_ONCLICK)', 1, true))
    local revert = body(src, "local original = btn.gseLabOriginal", "removeGSEWatermark%(k%)")
    assert.truthy(revert:find('btn:SetAttribute("clickbutton-gse" .. tostring(r[1]), nil)', 1, true))
  end)

  -- The secure OnClick pre-handler, run as written against a button.
  local function runSnippet(attributes)
    local snippet = src:match("local LAB_STATE_ONCLICK = %[%[(.-)%]%]")
    assert(snippet, "LAB_STATE_ONCLICK not found")
    local env = { self = { GetAttribute = function(_, name) return attributes[name] end } }
    local chunk
    if loadstring then
      chunk = assert(loadstring(snippet))
      setfenv(chunk, env)
    else
      chunk = assert(load(snippet, "LAB_STATE_ONCLICK", "t", env))
    end
    return chunk()
  end

  it("renames the click for a state GSE marked, so it reads that state's target", function()
    assert.are.equal("gse7", runSnippet({ state = "7", ["gse-lab-state-7"] = true }))
  end)

  it("leaves the click alone on a state that is not GSE's", function()
    assert.is_nil(runSnippet({ state = "3", ["gse-lab-state-7"] = true }))
    assert.is_nil(runSnippet({ ["gse-lab-state-7"] = true }), "no state attribute (ConsolePort)")
  end)

  it("gates on the secure mark, never the insecure gse-button string (#1931)", function()
    local snippet = src:match("local LAB_STATE_ONCLICK = %[%[(.-)%]%]")
    assert.falsy(snippet:find("gse-button", 1, true))
  end)
end)

-- Blizzard's main bar and Dominos have no LibActionButton states, but a
-- stance, form or stealth puts them on a page of their own (7-10): a row can
-- be pinned to that page as to a LAB state, and dropping a sequence on the
-- stealth bar puts it on the stealth bar.
describe("Stance, form and stealth pages on other bars", function()
  local src = readSource("GSE/API/Events.lua")

  -- BAR_SWAP_ONCLICK as Events.lua builds it, run against a button.
  local function onClick(button, world)
    local resolve = assert(src:match("local BAR_SWAP_RESOLVE = %[%[(.-)%]%]"), "BAR_SWAP_RESOLVE not found")
    local head, tail = src:match("local BAR_SWAP_ONCLICK = %[%[(.-)%]%] %.%. BAR_SWAP_RESOLVE %.%. %[%[(.-)%]%]")
    assert(head and tail, "BAR_SWAP_ONCLICK not built from BAR_SWAP_RESOLVE")
    local attributes = button.attributes
    local env = {
      floor = math.floor, tonumber = tonumber,
      GetBonusBarOffset = function() return world.bonus or 0 end,
      GetActionInfo = function(slot) return world.slots and world.slots[slot] end,
      self = {
        GetID = function() return button.id or 0 end,
        GetEffectiveAttribute = function(_, name) return attributes[name] end,
        GetAttribute = function(_, name) return attributes[name] end,
        SetAttribute = function(_, name, value) attributes[name] = value end,
      },
    }
    local snippet = head .. resolve .. tail
    local chunk
    if loadstring then
      chunk = assert(loadstring(snippet))
      setfenv(chunk, env)
    else
      chunk = assert(load(snippet, "BAR_SWAP_ONCLICK", "t", env))
    end
    return chunk()
  end

  local function mainBarButton(extra)
    local a = { ["gse-secure"] = true, ["gse-bonus-paged"] = true, actionpage = 1 }
    for k, v in pairs(extra or {}) do a[k] = v end
    return { id = 1, attributes = a }
  end

  it("runs the stealth row on the stealth bar of Blizzard's main bar", function()
    local button = mainBarButton({ ["gse-default"] = true, ["gse-page-7"] = true })
    assert.are.equal("gse7", onClick(button, { bonus = 1 }))
    assert.are.equal("click", button.attributes.type)
  end)

  it("runs the Default row out of stealth", function()
    local button = mainBarButton({ ["gse-default"] = true, ["gse-page-7"] = true })
    assert.is_nil(onClick(button, { bonus = 0 }))
    assert.are.equal("click", button.attributes.type)
  end)

  it("is a plain action button where only another page has a row", function()
    local button = mainBarButton({ ["gse-page-7"] = true })
    assert.is_nil(onClick(button, { bonus = 0 }))
    assert.are.equal("action", button.attributes.type)
    assert.is_nil(onClick(button, { bonus = 3 }), "Bear: page 9, no row")
    assert.are.equal("action", button.attributes.type)
  end)

  it("lets a real action on the stealth bar win", function()
    local button = mainBarButton({ ["gse-default"] = true, ["gse-page-7"] = true })
    assert.is_nil(onClick(button, { bonus = 1, slots = { [73] = "spell" } }))
    assert.are.equal("action", button.attributes.type)
    assert.are.equal(73, button.attributes["gse-eff-action"])
  end)

  it("reads a Dominos page from the slot it fires", function()
    local button = { id = 0, attributes = { ["gse-secure"] = true, ["gse-page-7"] = true, action = 79 } }
    assert.are.equal("gse7", onClick(button, { bonus = 1 }))
  end)

  it("runs a row on a page a bar addon's own driver chose (EllesmereUI: Cat Form on 5)", function()
    local button = { id = 1, attributes = { ["gse-secure"] = true, ["gse-default"] = true, ["gse-page-5"] = true,
      actionpage = 5 } }
    assert.are.equal("gse5", onClick(button, { bonus = 1 }))
    button.attributes.actionpage = 1
    assert.is_nil(onClick(button, { bonus = 0 }))
    assert.are.equal("click", button.attributes.type)
  end)

  it("never takes skyriding's page (bonus bar 5) for a form's", function()
    local button = mainBarButton({ ["gse-page-7"] = true, ["gse-page-10"] = true })
    assert.is_nil(onClick(button, { bonus = 5 }))
  end)

  it("drops, moves and clears in the state the button is in", function()
    local create = body(src, "function GSE.CreateActionBarOverride", "\nend\n")
    assert.truthy(create:find("GSE.OverrideStateFor(_G[buttonName])", 1, true))
    assert.truthy(create:find("GSE.SetOverrideData(buttonName, sequenceId, layer, state)", 1, true))
    local move = body(src, "function GSE.MoveActionBarOverride", "\nend\n")
    assert.truthy(move:find("GSE.OverrideStateFor(from)", 1, true))
    assert.truthy(move:find("GSE.OverrideStateFor(to)", 1, true))
    assert.truthy(move:find("GSE.ButtonOverrideSequence(fromName)", 1, true), "what shows there moves")
    local remove = body(src, "function GSE.RemoveActionBarOverride", "\nend\n")
    assert.truthy(remove:find("GSE.ClearOverrideData(buttonName, GSE.OverrideStateFor(_G[buttonName]))", 1, true))
  end)
end)

describe("A bar's pages by name", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/Profiles")
  end)

  local SPELLS = { [768] = "Cat Form", [33891] = "Tree of Life", [5487] = "Bear Form", [24858] = "Moonkin Form",
    [5215] = "Prowl", [1784] = "Stealth" }
  -- Put back what the last test faked first: Lua 5.1's runner has no after_each.
  local saved
  local function restore()
    if not saved then return end
    GSE.GetSpellInfo, _G.SHIFT_KEY_TEXT, _G.BT4Button1, _G.ElvUI_Bar1Button1 =
      saved.spell, saved.shift, saved.bt4, saved.elv
    saved = nil
  end
  local function start()
    restore()
    saved = { spell = GSE.GetSpellInfo, shift = _G.SHIFT_KEY_TEXT, bt4 = _G.BT4Button1, elv = _G.ElvUI_Bar1Button1 }
    GSE.GetSpellInfo = function(id) return SPELLS[id] and { name = SPELLS[id] } end
    _G.SHIFT_KEY_TEXT = "Shift"
  end
  after_each(restore)

  local function named(driver, page)
    local names = GSE.PageDriverNames(driver, "DRUID")[page]
    return names and table.concat(names, " / ")
  end

  it("names a Bartender4 bar's pages as the player set them", function()
    start()
    local driver = "[overridebar][possessbar][shapeshift]possess;[bonusbar:5]dragon;"
      .. "[bonusbar:3]9;[bonusbar:1,stealth:1]5;[bonusbar:1]5;0"
    assert.are.equal("Bear Form", named(driver, "9"))
    assert.are.equal("Prowl / Cat Form", named(driver, "5"))
    assert.is_nil(named(driver, "10"))
    assert.is_nil(named(driver, "0"))
  end)

  it("names ElvUI's own pages, two forms on one page included", function()
    start()
    local driver = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 10; [bonusbar:3] 9; [bonusbar:4] 10; 1"
    assert.are.equal("Cat Form", named(driver, "7"))
    assert.are.equal("Prowl", named(driver, "8"))
    assert.are.equal("Bear Form", named(driver, "9"))
    assert.are.equal("Tree of Life / Moonkin Form", named(driver, "10"))
  end)

  it("names a modifier's page, and no vehicle, Skyriding or hand-switched page", function()
    start()
    local driver = "[overridebar] 18; [vehicleui][possessbar] 16; [mod:shift,bonusbar:3] 6; [mod:shift] 5; "
      .. "[bar:2] 2; [bonusbar:5] 11; 1"
    assert.are.equal("Shift + Bear Form", named(driver, "6"))
    assert.are.equal("Shift", named(driver, "5"))
    for _, page in ipairs({ "18", "16", "2", "11", "1" }) do assert.is_nil(named(driver, page)) end
  end)

  it("counts a page as a state only where the driver sends a form or modifier", function()
    start()
    local savedUnitClass = _G.UnitClass
    _G.UnitClass = function() return "Druid", "DRUID" end
    local bar = { GetAttribute = function(_, key)
      return key == "page" and "[bar:2] 2; [bonusbar:1,stealth] 5; [bonusbar:1] 5; [bonusbar:3] 9; [bonusbar:5] 11; 1" or nil
    end }
    _G.ElvUI_Bar1Button1 = { GetParent = function() return bar end }
    local states = {}
    for page = 1, 12 do states[#states + 1] = GSE.DriverStateForPage("ElvUI_Bar1Button1", page) end
    _G.UnitClass = savedUnitClass
    assert.are.same({ "5", "9" }, states)
  end)

  it("reads the driver from the bar a button is on", function()
    start()
    local elvBar = { GetAttribute = function(_, key) return key == "page" and "[bonusbar:3] 9; 1" or nil end }
    _G.ElvUI_Bar1Button1 = { GetParent = function() return elvBar end }
    assert.are.equal("[bonusbar:3] 9; 1", GSE.ButtonPageDriver("ElvUI_Bar1Button1"))
    local options = { enabled = true }
    local bt4Bar = {
      GetStateOption = function(_, key) return options[key] end,
      UpdateStates = function(_, returnOnly) return returnOnly and "[bonusbar:1]5;0" or nil end,
    }
    _G.BT4Button1 = { GetParent = function() return bt4Bar end }
    assert.are.equal("[bonusbar:1]5;0", GSE.ButtonPageDriver("BT4Button1"))
    options.customEnabled, options.custom = true, "[bonusbar:3]9;0"
    assert.are.equal("[bonusbar:3]9;0", GSE.ButtonPageDriver("BT4Button1"))
    -- Paging off: no driver, and the bar is not asked to build one.
    options.enabled = false
    assert.is_nil(GSE.ButtonPageDriver("BT4Button1"))
  end)
end)
