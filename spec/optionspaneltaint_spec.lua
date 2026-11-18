-- GSE opens WoW's Options window on its own page through
-- Settings.OpenToCategory. That asks the client to open the panel from its own
-- event, so the panel's code runs untainted.
--
-- GSE also used to call SettingsPanel:OpenToCategory itself. That ran the same
-- panel code as GSE_Options: an action bar shown or hidden from Options
-- afterwards was changed tainted, and in combat WoW blocked the bar's buttons
-- (ADDON_ACTION_BLOCKED 'GSE_Options' ...:SetAttribute(), and SetCooldown
-- refusing secret values).
--
-- Options.lua cannot be loaded here, so this reads it as text.
local function readCode(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  src = src:gsub("\r\n", "\n"):gsub("\r", "\n")
  -- Comments may name the call; only code may not make it.
  return (src:gsub("%-%-[^\n]*", ""))
end

describe("opening the Options window", function()
  local code = readCode("GSE_Options/Options.lua")

  it("goes through Settings.OpenToCategory", function()
    assert.is_truthy(code:find("Settings.OpenToCategory", 1, true))
  end)

  it("never calls the Settings panel's own methods", function()
    assert.is_nil(code:find("SettingsPanel[%.:]OpenToCategory"))
    assert.is_nil(code:find("SettingsPanel[%.:]Open%f[%W]"))
    assert.is_nil(code:find("SettingsPanel[%.:]SelectCategory"))
  end)
end)
