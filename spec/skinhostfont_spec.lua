-- GSE's windows use the font of the UI addon whose look they take
-- (GSE.Skin.HostFont, GSE_GUI/Skin.lua). Under EllesmereUI that is the font
-- the player chose on EllesmereUI's Fonts page, asked for the way EllesmereUI
-- 9 gives it: EllesmereUI.GetFontPath(). GSE read a field EllesmereUI no
-- longer has (_font) and so showed Expressway whatever was chosen (Larry,
-- 2026-11-21, Blizzard's font chosen in EllesmereUI).
--
-- HostFont is run as Skin.lua has it.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("the font GSE's windows take from the host UI", function()
  local skin = readSource("GSE_GUI/Skin.lua")

  local function hostFont(provider, globals, mode)
    local s = assert(skin:find("function GSE.Skin.HostFont()", 1, true))
    local e = assert(skin:find("\nend\n", s, true))
    local code = "local GSE, blizzardDefaultFont = ...\n" .. skin:sub(s, e + 4) .. "\nreturn GSE.Skin.HostFont()"
    local GSE = { Skin = { providerName = provider }, GetEffectiveSkinMode = function() return mode or "ADDON" end }
    local env = { type = type, pcall = pcall, _G = globals }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "hostfont", "t", env))
    end
    return chunk(GSE, function() return "Fonts\\FRIZQT__.TTF" end)
  end

  it("is the font chosen in EllesmereUI", function()
    local eui = { GetFontPath = function() return "Fonts\\FRIZQT__.TTF" end, EXPRESSWAY = "EUI\\Expressway.ttf" }
    assert.are.equal("Fonts\\FRIZQT__.TTF", hostFont("EllesmereUI", { EllesmereUI = eui }))
  end)

  it("asks EllesmereUI for its global font: no addon key", function()
    local asked = "not asked"
    local eui = { GetFontPath = function(key) asked = key; return "X.ttf" end }
    hostFont("EllesmereUI", { EllesmereUI = eui })
    assert.is_nil(asked)
  end)

  it("falls back to the older field, then EllesmereUI's bundled face", function()
    assert.are.equal("Old.ttf", hostFont("EllesmereUI", { EllesmereUI = { _font = "Old.ttf", EXPRESSWAY = "E.ttf" } }))
    assert.are.equal("E.ttf", hostFont("EllesmereUI", { EllesmereUI = { EXPRESSWAY = "E.ttf" } }))
    -- An EllesmereUI whose font call fails, or answers with nothing.
    local broken = { GetFontPath = function() error("no fonts yet") end, EXPRESSWAY = "E.ttf" }
    assert.are.equal("E.ttf", hostFont("EllesmereUI", { EllesmereUI = broken }))
    local empty = { GetFontPath = function() return nil end, EXPRESSWAY = "E.ttf" }
    assert.are.equal("E.ttf", hostFont("EllesmereUI", { EllesmereUI = empty }))
  end)

  it("leaves the Native skin and ElvUI as they were", function()
    local eui = { GetFontPath = function() return "Chosen.ttf" end }
    assert.are.equal("Fonts\\FRIZQT__.TTF", hostFont("EllesmereUI", { EllesmereUI = eui }, "NATIVE"))
    local elv = { [1] = { media = { normFont = "Elv.ttf" } } }
    assert.are.equal("Elv.ttf", hostFont("ElvUI", { ElvUI = elv, EllesmereUI = eui }))
  end)
end)
