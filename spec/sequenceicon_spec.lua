-- The icon a sequence's step shows (GSE/API/Storage.lua, GSE/API/Events.lua):
-- the block's own icon where it has one, else the first macro line that names
-- a spell or item -- a /castsequence line included -- and the same icon at
-- rest as when the step comes round.
--
-- Run: busted spec/sequenceicon_spec.lua   /   lua5.1 spec/run51.lua
describe("Sequence step icon", function()
  local known = {
    ["Survival of the Fittest"] = { name = "Survival of the Fittest", iconID = 101 },
    ["Exhilaration"] = { name = "Exhilaration", iconID = 102 },
    ["Fortitude of the Bear"] = { name = "Fortitude of the Bear", iconID = 103 },
    ["Spirit Mend"] = { name = "Spirit Mend", iconID = 104 },
    ["Barbed Shot"] = { name = "Barbed Shot", iconID = 105 },
    ["Kill Command"] = { name = "Kill Command", iconID = 106 },
    ["Cat Form"] = { name = "Cat Form", iconID = 107, spellID = 768 },
    ["Call Pet 1"] = { name = "Call Pet 1", iconID = 108, spellID = 883 },
    ["Wailing Arrow"] = { name = "Wailing Arrow", iconID = 109, spellID = 466930 },
    ["Sprint"] = { name = "Sprint", iconID = 110, spellID = 2983 },
    -- Sprint's second rank, by its number alone: a client in another language.
    ["Sprinten"] = { name = "Sprinten", iconID = 111, spellID = 8696 },
  }
  local byID = {}
  for _, info in pairs(known) do
    info.spellID = info.spellID or info.iconID + 1000
    byID[info.spellID] = info
  end
  for id, info in pairs(byID) do known[id] = info end
  local GLOBALS = { "SecureCmdOptionParse", "C_Item", "gmatch", "strlower", "IsPlayerSpell", "QueryCastSequence" }
  local saved, savedGetSpellInfo, savedExec

  -- WoW's parser out of combat: a clause needing combat is false, the rest
  -- give what follows their conditions.
  local function parseOutOfCombat(options)
    for clause in string.gmatch(options .. ";", "([^;]*);") do
      local conditions, rest = clause:match("^%s*(%b[])%s*(.*)$")
      if not conditions then return (clause:gsub("^%s+", "")) end
      if not conditions:find("combat", 1, true) then
        return (rest:gsub("^%[[^%]]*%]%s*", ""))
      end
    end
  end

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/Native")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    require("../GSE/API/translator")
  end)

  -- Put back what the last test faked first: Lua 5.1's runner has no after_each.
  local function start()
    if saved then
      for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
      GSE.GetSpellInfo, GSE.SequencesExec = savedGetSpellInfo, savedExec
    end
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    savedGetSpellInfo, savedExec = GSE.GetSpellInfo, GSE.SequencesExec
    _G.SecureCmdOptionParse = parseOutOfCombat
    -- No item by any of these names: /use falls through to the spell.
    _G.C_Item = { GetItemInfo = function() return nil end }
    _G.gmatch = _G.gmatch or string.gmatch
    _G.strlower = _G.strlower or string.lower
    -- A fresh table each time, as C_Spell.GetSpellInfo gives: the button
    -- writes a block's own icon into the one it gets.
    GSE.GetSpellInfo = function(spell)
      local info = known[tonumber(spell) or spell]
      if not info then return nil end
      local copy = {}
      for k, v in pairs(info) do copy[k] = v end
      return copy
    end
    _G.IsPlayerSpell = nil
  end

  -- This character knows these spells, and only these.
  local function knows(...)
    local ids = {}
    for _, name in ipairs({ ... }) do
      ids[known[name].spellID] = true
    end
    _G.IsPlayerSpell = function(id) return ids[id] == true end
  end

  local function icon(...)
    return GSE.GetMacroTextIconInfo(table.concat({ ... }, "\n")).iconID
  end

  after_each(function()
    if not saved then return end
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
    GSE.GetSpellInfo, GSE.SequencesExec = savedGetSpellInfo, savedExec
    saved = nil
  end)

  local function button(name)
    return {
      GetAttribute = function() return 1 end,
      GetName = function() return name end,
    }
  end

  local SURVIVAL = table.concat({
    "/castsequence [combat] reset=3/combat Survival of the Fittest, Exhilaration",
    "/use [known:Fortitude of the Bear,combat] Fortitude of the Bear",
    "/use [@focus,help,exists,nodead][@player] Spirit Mend",
  }, "\n")

  it("takes a /castsequence line's icon, not the next line's (#2188)", function()
    start()
    assert.are.equal(101, GSE.GetMacroTextIconInfo(SURVIVAL).iconID)
  end)

  it("shows a /castsequence step's icon on the button (#2188)", function()
    start()
    GSE.SequencesExec = { seqA = { { type = "macro", macrotext = SURVIVAL } } }
    assert.are.equal(101, GSE.GetCurrentButtonIconInfo(button("seqA"), false).iconID)
  end)

  -- Larry, 2026-11-25: "a castsequence lines icon should advance the same as
  -- if the sequence was moving to a new Block".
  it("moves a /castsequence line's icon on as WoW moves the line on", function()
    start()
    local asked = {}
    local at = 1
    _G.QueryCastSequence = function(sequence)
      asked[#asked + 1] = sequence
      return at
    end
    assert.are.equal(101, GSE.GetMacroTextIconInfo(SURVIVAL).iconID, "at the start")
    assert.are.equal("reset=3/combat Survival of the Fittest, Exhilaration", asked[1], "asked by the text after the conditions")
    at = 2
    assert.are.equal(102, GSE.GetMacroTextIconInfo(SURVIVAL).iconID, "once the first has gone off")
    GSE.SequencesExec = { seqA = { { type = "macro", macrotext = SURVIVAL } } }
    assert.are.equal(102, GSE.GetCurrentButtonIconInfo(button("seqA"), false).iconID, "on the button")
    assert.are.equal(102, icon("/castsequence Survival of the Fittest, !Exhilaration"), "a ! is not the spell's name")
    at = 5
    assert.are.equal(101, GSE.GetMacroTextIconInfo(SURVIVAL).iconID, "past its end: the start")
    _G.QueryCastSequence = function() error("no") end
    assert.are.equal(101, GSE.GetMacroTextIconInfo(SURVIVAL).iconID, "an error: the start")
    _G.QueryCastSequence = nil
  end)

  it("looks at the icons again as a /castsequence line moves on or starts again", function()
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local events = fh:read("*a"):gsub("\r\n", "\n")
    fh:close()
    assert.truthy(events:find('castSequenceWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")', 1, true))
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD" }) do
      assert.truthy(events:find('castSequenceWatcher:RegisterEvent("' .. event .. '")', 1, true), event)
    end
    assert.truthy(events:find('castSequenceWatcher:SetScript("OnEvent", function() queueCurrentSpellIconRefresh() end)', 1, true))
  end)

  it("shows the block's own icon over what its macro resolves to (#2187)", function()
    start()
    GSE.SequencesExec = { seqB = { { type = "macro", Icon = 105,
      macrotext = "/startattack\n/cast [@pet,exists] Kill Command" } } }
    assert.are.equal(105, GSE.GetCurrentButtonIconInfo(button("seqB"), false).iconID)
  end)

  it("ranks a spell with no modifier above one under a modifier, wherever it is", function()
    start()
    knows("Exhilaration", "Kill Command")
    assert.are.equal(106, icon("/cast [mod:shift] Exhilaration", "/cast Kill Command"))
    assert.are.equal(106, icon("/cast [mod:shift] Exhilaration; Kill Command"))
    assert.are.equal(102, icon("/cast [mod:shift] Kill Command; [nomod] Exhilaration"))
  end)

  it("ranks a modifier's spell above a form, and a form above a pet", function()
    start()
    knows("Barbed Shot", "Cat Form", "Call Pet 1")
    assert.are.equal(105, icon("/cast Cat Form", "/cast [mod:alt] Barbed Shot"))
    assert.are.equal(107, icon("/cast Call Pet 1", "/cast Cat Form"))
    assert.are.equal(108, icon("/cast Call Pet 1"))
  end)

  it("ranks Sprint with the forms: below a modifier's spell, above a pet", function()
    start()
    knows("Sprint", "Sprinten", "Barbed Shot", "Kill Command", "Call Pet 1")
    assert.are.equal(106, icon("/cast Sprint", "/cast Kill Command"))
    assert.are.equal(105, icon("/cast Sprint", "/cast [mod:alt] Barbed Shot"))
    assert.are.equal(110, icon("/cast Call Pet 1", "/cast Sprint"))
    assert.are.equal(110, icon("/cast Sprint"), "alone, it is still the block's icon")
    assert.are.equal(106, icon("/cast Sprinten", "/cast Kill Command"), "by its spell, whatever it is called")
  end)

  it("ranks a spell this character can cast above one it can't", function()
    start()
    knows("Kill Command", "Exhilaration")
    assert.are.equal(106, icon("/cast Wailing Arrow", "/cast Kill Command"))
    assert.are.equal(102, icon("/cast Wailing Arrow", "/cast [mod] Exhilaration"))
    -- A known: that fails is a clause that can't cast.
    assert.are.equal(106, icon("/cast [known:466930] Exhilaration", "/cast Kill Command"))
    -- Nothing castable: the ranks alone.
    assert.are.equal(109, icon("/cast [mod] Spirit Mend", "/cast Wailing Arrow"))
  end)

  it("follows the clause a line would fire now, within a rank", function()
    start()
    knows("Barbed Shot", "Kill Command", "Cat Form")
    local stealthed = false
    _G.SecureCmdOptionParse = function(options)
      local conditions, rest = options:match("^%s*%[([^%]]*)%]%s*(.*)$")
      if not conditions then return options end
      local holds = { stealth = stealthed, nostealth = not stealthed }
      if holds[conditions] == false then return nil end
      return rest
    end
    assert.are.equal(106, icon("/cast [stealth] Barbed Shot; Kill Command"))
    stealthed = true
    assert.are.equal(105, icon("/cast [stealth] Barbed Shot; Kill Command"))
    -- A form that would fire now still ranks below a spell.
    stealthed = false
    assert.are.equal(106, icon("/cast [nostealth] Cat Form; Kill Command"))
  end)

  it("follows the stance, form or stealth across lines (Larry, 2026-11-21)", function()
    start()
    knows("Barbed Shot", "Kill Command", "Exhilaration", "Call Pet 1")
    local stealthed, combat = false, false
    _G.SecureCmdOptionParse = function(options)
      local conditions, rest = options:match("^%s*%[([^%]]*)%]%s*(.*)$")
      if not conditions then return options end
      local holds = { stealth = stealthed, nostealth = not stealthed, stance = stealthed, nostance = not stealthed,
        ["form:1"] = stealthed, combat = combat, ["mod:shift"] = false }
      for condition in conditions:gmatch("[^,]+") do
        if holds[condition] == false then return nil end
      end
      return rest
    end
    -- "/cast [stance] Ambush" over "/cast [nostealth] Kingsbane".
    local block = { "/cast [stance] Barbed Shot", "/cast [nostealth] Kill Command" }
    assert.are.equal(106, icon((unpack or table.unpack)(block)), "out of stealth: the line that fires there")
    stealthed = true
    assert.are.equal(105, icon((unpack or table.unpack)(block)), "in stealth: the stealth line")
    assert.are.equal(105, icon("/cast [nostealth] Kill Command", "/cast [stealth] Barbed Shot"), "and with the lines the other way round")
    -- Whichever way round the lines are, and for a form by its number.
    stealthed = false
    assert.are.equal(106, icon("/cast [nostealth] Kill Command", "/cast [stealth] Barbed Shot"))
    assert.are.equal(106, icon("/cast [form:1] Barbed Shot", "/cast Kill Command"))
    -- A line for another stance comes after what can be cast as the character
    -- stands, a modifier's spell and a pet among them...
    assert.are.equal(102, icon("/cast [stealth] Barbed Shot", "/cast [mod:shift] Exhilaration"))
    assert.are.equal(108, icon("/cast [stealth] Barbed Shot", "/cast Call Pet 1"))
    -- ...and before what the character cannot cast at all.
    assert.are.equal(105, icon("/cast [stealth] Barbed Shot", "/cast Wailing Arrow"))
    -- Alone, it is still the block's icon.
    assert.are.equal(105, icon("/cast [stealth] Barbed Shot"))
    -- A clause with a way to fire in this stance is not for another one.
    assert.are.equal(105, icon("/cast [stealth][combat] Barbed Shot", "/cast [nostealth] Kill Command"))
    -- Combat is not a stance: a line waiting on combat still shows at rest,
    -- over a line below it (#2188), in the stance it asks for.
    assert.are.equal(105, icon("/cast [combat] Barbed Shot", "/cast Kill Command"))
    assert.are.equal(105, icon("/cast [combat,nostealth] Barbed Shot", "/cast Kill Command"))
    assert.are.equal(106, icon("/cast [combat,stealth] Barbed Shot", "/cast Kill Command"))
    -- Within a line, as before: the clause for this stance.
    assert.are.equal(106, icon("/cast [stealth] Barbed Shot; [combat] Kill Command"))
    -- And that clause is the line's, waiting on combat, over a line below it.
    assert.are.equal(106, icon("/cast [stealth] Barbed Shot; [combat] Kill Command", "/cast Exhilaration"))
  end)

  it("looks at the icons again as a stance, form or stealth changes", function()
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local events = fh:read("*a"):gsub("\r\n", "\n")
    fh:close()
    local s = assert(events:find("local function stanceChanged()", 1, true))
    local body = events:sub(s, assert(events:find("\nend\n", s, true)))
    assert.truthy(body:find("queueCurrentSpellIconRefresh(true)", 1, true), "at once")
    assert.truthy(body:find("\n    queueCurrentSpellIconRefresh()\n", 1, true), "and once the form has caught up")
    for _, event in ipairs({ "UPDATE_STEALTH", "UPDATE_SHAPESHIFT_FORM" }) do
      assert.truthy(events:find("GSE." .. event .. " = stanceChanged", 1, true), event)
      assert.truthy(events:find('GSE:RegisterEvent("' .. event .. '")', 1, true), event .. " not registered")
    end
  end)

  it("shows the block's own icon even when its spells can't be cast", function()
    start()
    knows("Kill Command")
    GSE.SequencesExec = { seqC = { { type = "macro", Icon = 109, macrotext = "/cast Kill Command" } } }
    assert.are.equal(109, GSE.GetCurrentButtonIconInfo(button("seqC"), false).iconID)
  end)

  it("asks a sequence at rest for its icon as the running button does (#2187)", function()
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local body = src:match("\nlocal function getGSESequenceIcon%(seq%)\n(.-)\nend\n")
    assert.truthy(body)
    assert.truthy(body:find("GSE.GetCurrentButtonIconInfo(_G[seq], false)", 1, true))
    assert.falsy(body:find("GetMacroTextIconInfo", 1, true))
  end)
end)
