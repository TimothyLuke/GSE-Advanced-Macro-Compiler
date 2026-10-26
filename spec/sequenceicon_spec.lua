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
  }
  local GLOBALS = { "SecureCmdOptionParse", "C_Item", "gmatch", "strlower" }
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
    GSE.GetSpellInfo = function(spell) return known[spell] end
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

  it("shows the block's own icon over what its macro resolves to (#2187)", function()
    start()
    GSE.SequencesExec = { seqB = { { type = "macro", Icon = 105,
      macrotext = "/startattack\n/cast [@pet,exists] Kill Command" } } }
    assert.are.equal(105, GSE.GetCurrentButtonIconInfo(button("seqB"), false).iconID)
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
