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
