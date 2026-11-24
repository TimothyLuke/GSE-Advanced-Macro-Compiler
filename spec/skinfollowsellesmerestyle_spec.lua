-- EllesmereUI has whole-UI style packs (its Style page): EllesmereUI Style,
-- Blizzard Style, Classic WoW UI, and WoW Forever on that client. On the two
-- stock ones its windows are left as Blizzard draws them. GSE following
-- EllesmereUI follows the style chosen: Blizzard's own look on a stock style,
-- EllesmereUI's dark look on the others. It painted the dark look whatever
-- was chosen (Larry, 2026-11-21, on Classic WoW UI).
--
-- GSE.GetEffectiveSkinMode and what it reads are run as Appearance.lua has
-- them; the EllesmereUI side is as EllesmereUI 9.9.1 keeps it.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("GSE's skin follows EllesmereUI's chosen style", function()
  local appearance = readSource("GSE_Utils/Appearance.lua")

  -- opts.mode: GSEOptions.SkinMode. opts.eui / opts.db: _G.EllesmereUI and
  -- EllesmereUIDB. opts.elvui: ElvUI loaded too.
  local function skin(opts)
    local s = assert(appearance:find("function GSE.GetInstalledSkinProviderName()", 1, true))
    local e = assert(appearance:find("--- True only when the user has explicitly chosen the Modern skin.", s, true))
    local code = "local GSE = ...\n" .. appearance:sub(s, e - 1) .. "\nreturn GSE"
    local globals = { EllesmereUI = opts.eui, EllesmereUIDB = opts.db, ElvUI = opts.elvui }
    local GSE = { IsEllesmereUILoaded = function() return type(globals.EllesmereUI) == "table" end }
    local env = { type = type, pcall = pcall, _G = globals, GSEOptions = { SkinMode = opts.mode } }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "appearance", "t", env))
    end
    return chunk(GSE)
  end

  -- EllesmereUI's own resolver (EllesmereUIBlizzardSkin.lua), in short.
  local function withWindowSkins(forever)
    return { ProfileWindowSkinLook = function(prof, fonts)
      if type(prof) ~= "table" then return nil end
      local look = prof.windowSkinLook
      if look == "forever" then return forever and "forever" or "blizzard" end
      if look then return look end
      return fonts and fonts._styleSlots and fonts._styleSlots.active or nil
    end }
  end
  local function db(look, fontLook)
    return { activeProfile = "Default", profiles = { Default = { windowSkinLook = look } },
      fonts = fontLook and { _styleSlots = { active = fontLook } } or {} }
  end

  it("is Blizzard's own look on EllesmereUI's stock styles", function()
    for _, look in ipairs({ "classic", "blizzard" }) do
      local GSE = skin({ eui = withWindowSkins(), db = db(look) })
      assert.are.equal(look, GSE.EllesmereUIWindowLook())
      assert.are.equal("NATIVE", GSE.GetEffectiveSkinMode(), look)
    end
  end)

  it("is EllesmereUI's look on its own style, on WoW Forever's, and with none recorded", function()
    assert.are.equal("ADDON", skin({ eui = withWindowSkins(), db = db("eui") }).GetEffectiveSkinMode())
    assert.are.equal("ADDON", skin({ eui = withWindowSkins(true), db = db("forever") }).GetEffectiveSkinMode())
    assert.are.equal("ADDON", skin({ eui = withWindowSkins(), db = db(nil) }).GetEffectiveSkinMode())
    assert.are.equal("ADDON", skin({ eui = {}, db = nil }).GetEffectiveSkinMode(), "no saved settings yet")
  end)

  it("follows the style with EllesmereUI picked in GSE's Skin list too", function()
    assert.are.equal("NATIVE", skin({ mode = "ADDON", eui = withWindowSkins(), db = db("classic") }).GetEffectiveSkinMode())
    assert.are.equal("ADDON", skin({ mode = "ADDON", eui = withWindowSkins(), db = db("eui") }).GetEffectiveSkinMode())
  end)

  it("reads the style where EllesmereUI's window skins are switched off", function()
    assert.are.equal("NATIVE", skin({ eui = {}, db = db("classic") }).GetEffectiveSkinMode())
    assert.are.equal("NATIVE", skin({ eui = {}, db = db(nil, "blizzard") }).GetEffectiveSkinMode(), "from its font look")
    assert.are.equal("ADDON", skin({ eui = {}, db = db(nil, "eui") }).GetEffectiveSkinMode())
    local broken = { ProfileWindowSkinLook = function() error("not ready") end }
    assert.are.equal("NATIVE", skin({ eui = broken, db = db("classic") }).GetEffectiveSkinMode())
  end)

  it("leaves a Native or Modern pick, ElvUI, and no UI addon as they were", function()
    assert.are.equal("MODERN", skin({ mode = "MODERN", eui = withWindowSkins(), db = db("classic") }).GetEffectiveSkinMode())
    assert.are.equal("NATIVE", skin({ mode = "NATIVE", eui = withWindowSkins(), db = db("eui") }).GetEffectiveSkinMode())
    -- ElvUI is the provider when both are loaded: EllesmereUI's style is not asked.
    local elv = { [1] = {} }
    assert.are.equal("ADDON", skin({ elvui = elv, eui = withWindowSkins(), db = db("classic") }).GetEffectiveSkinMode())
    assert.are.equal("NATIVE", skin({}).GetEffectiveSkinMode())
    assert.are.equal("ADDON", skin({ mode = "ADDON" }).GetEffectiveSkinMode(), "a pick kept with its addon gone")
  end)
end)
