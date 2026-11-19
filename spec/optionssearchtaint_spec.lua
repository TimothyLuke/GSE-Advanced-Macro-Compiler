-- WoW's Options search walks every row of every category, addon rows included,
-- and reads two things off them with no taint guard: each row's search tags,
-- on every search, and the parentInitializer of each row the search matched.
--
-- WoW creates rows, and tags them with their setting's name, through its own
-- secure path. Anything addon code adds afterwards is tainted:
--   * initializer:AddSearchTags(...)
--   * WoW's CreateSettingsCheckboxWithButtonInitializer, which adds the button
--     text as a tag while it runs as the addon
--   * initializer:SetParentInitializer(...)
--
-- With those in GSE's options the search ran as GSE_Options and left the list
-- tainted, and the Discord rows on the Social page were blocked
-- (ADDON_ACTION_FORBIDDEN 'GSE_Options' IsUserOAuthed()).
--
-- The options files cannot be loaded here, so this reads them as text.
local function readCode(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  src = src:gsub("\r\n", "\n"):gsub("\r", "\n")
  -- Comments may name the calls; only code may not make them.
  return (src:gsub("%-%-[^\n]*", ""))
end

describe("GSE's rows in WoW's Options search", function()
  for _, path in ipairs({ "GSE_Options/Options.lua", "GSE_Options/Support.lua" }) do
    local code = readCode(path)

    it(path .. " adds no search tags of its own", function()
      assert.is_nil(code:find("AddSearchTags%s*%("))
      assert.is_nil(code:find("CreateSettingsCheckboxWithButtonInitializer%s*%("))
    end)

    it(path .. " never sets a parent initializer", function()
      assert.is_nil(code:find("SetParentInitializer%s*%("))
    end)
  end

  it("asks WoW's button rows not to tag themselves", function()
    -- CreateSettingsButtonInitializer(name, buttonText, buttonClick, tooltip,
    -- addSearchTags): the fifth argument has to stay false.
    local code = readCode("GSE_Options/Options.lua") .. readCode("GSE_Options/Support.lua")
    local calls = 0
    for args in code:gmatch("CreateSettingsButtonInitializer(%b())") do
      calls = calls + 1
      assert.is_truthy(args:find(",%s*false%s*%)$"), "addSearchTags is not false in: " .. args:sub(1, 60))
    end
    assert.is_true(calls > 0)
  end)
end)
