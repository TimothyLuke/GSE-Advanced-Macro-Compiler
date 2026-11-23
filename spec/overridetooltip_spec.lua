-- The tooltip on an action button that runs a sequence (GSE/API/Events.lua,
-- showGSEButtonTooltip) is the tooltip of the spell the sequence is on, and
-- where that step has no spell (a macro step), the sequence's name. A
-- sequence's button is called by the sequence's id, so the name is looked up:
-- the id itself was shown (Larry, 2026-11-22, Burning Crusade: "mouse over
-- tooltip is showing the code name").
--
-- Events.lua cannot be loaded here, so this reads the function as text.
describe("the tooltip on a sequence's action button", function()
  local fh = assert(io.open("GSE/API/Events.lua", "r"))
  local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
  fh:close()
  local tooltip = assert(src:match("\nlocal function showGSEButtonTooltip%(btn%)\n(.-)\nend\n"), "showGSEButtonTooltip not found")

  it("names the sequence by its name, not its id, where the step has no spell", function()
    assert.truthy(tooltip:find("GameTooltip:SetText(GSE.SequenceName(seqName) or seqName, 1, 1, 1)", 1, true))
    assert.is_nil(tooltip:find("GameTooltip:SetText(seqName, 1, 1, 1)", 1, true), "the id is shown")
    assert.truthy(tooltip:find('GameTooltip:AddLine(L["GSE Sequence"], 0.6, 0.6, 0.6)', 1, true))
  end)
end)
