-- GSE's right-click menu on an empty action button needs a button to click.
-- The classic clients' default Edit Mode layout has "Always Show Buttons" off
-- on every bar, so an empty button there is hidden and only its slot art shows
-- (Larry, 2026-11-22, Burning Crusade: "right click Menu doesnt pop up"). So
-- where the menu is on, GSE shows Blizzard's empty buttons itself on those
-- clients (GSE/API/Events.lua, GSE.UpdateEmptyButtons).
--
-- Events.lua cannot be loaded here, so this reads the functions out of it as
-- text and runs them against stand-in buttons.
describe("empty action buttons on the classic clients", function()
  local GLOBALS = { "GSE", "GSEOptions", "InCombatLockdown", "EMPTY_BUTTON_BAR", "GSE_FORCE_SHOWGRID_REASON", "SHBT",
    "SHOWGRID_EMPTY", "setOverrideButtonForcedShown", "ActionButton1", "ActionButton2", "ActionButton3",
    "MultiBarLeftButton4" }
  local BIT = 262144
  local saved, src, update, showsEmpty
  local combat, executed, released

  local function button(fields)
    local b = { index = 1, shown = false, attributes = {}, bar = { numButtonsShowable = 12, UpdateShownButtons = function() end } }
    for key, value in pairs(fields or {}) do b[key] = value end
    b.GetShowGrid = function() end
    b.GetAttribute = function(self, name) return self.attributes[name] end
    b.IsShown = function(self) return self.shown end
    return b
  end

  setup(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local body = assert(src:match("\nfunction GSE%.UpdateEmptyButtons%(%)\n(.-)\nend\n"), "GSE.UpdateEmptyButtons not found")
    update = assert((loadstring or load)("return function()\n" .. body .. "\nend"))()
    local rule = assert(src:match("\nfunction GSE%.ShowsEmptyButtons%(%)\n(.-)\nend\n"), "GSE.ShowsEmptyButtons not found")
    showsEmpty = assert((loadstring or load)("return function()\n" .. rule .. "\nend"))()
  end)

  teardown(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  before_each(function()
    combat, executed, released = false, {}, {}
    _G.GSE = { GameMode = 2, ShowsEmptyButtons = showsEmpty }
    _G.GSEOptions = {}
    _G.InCombatLockdown = function() return combat end
    _G.GSE_FORCE_SHOWGRID_REASON = BIT
    _G.SHOWGRID_EMPTY = "SHOWGRID_EMPTY"
    _G.EMPTY_BUTTON_BAR = { ActionButton1 = true, ActionButton2 = true, ActionButton3 = true, MultiBarLeftButton4 = true }
    local ref, show
    _G.SHBT = {
      SetFrameRef = function(_, _, frame) ref = frame end,
      SetAttribute = function(_, name, value) if name == "gseGridShow" then show = value end end,
      Execute = function(_, snippet) table.insert(executed, { button = ref, show = show, snippet = snippet }) end,
    }
    _G.setOverrideButtonForcedShown = function(btn, shown) table.insert(released, { button = btn, shown = shown }) end
    _G.ActionButton1, _G.ActionButton2, _G.ActionButton3, _G.MultiBarLeftButton4 = nil, nil, nil, nil
  end)

  it("is for the clients whose default hides them, while the menu is on", function()
    assert.is_true(showsEmpty())
    _G.GSEOptions.actionBarOverridePopup = true
    assert.is_true(showsEmpty())
    _G.GSEOptions.actionBarOverridePopup = false
    assert.is_false(showsEmpty())
    _G.GSEOptions.actionBarOverridePopup = nil
    for _, mode in ipairs({ 1, 2, 5 }) do
      _G.GSE.GameMode = mode
      assert.is_true(showsEmpty(), "Classic Era, Burning Crusade and Mists")
    end
    for _, mode in ipairs({ 11, 12 }) do
      _G.GSE.GameMode = mode
      assert.is_false(showsEmpty(), "Retail and Forever show them by default")
    end
  end)

  it("shows an empty button the bar has in use", function()
    _G.ActionButton1 = button()
    update()
    assert.are.equal(1, #executed)
    assert.are.equal(_G.ActionButton1, executed[1].button)
    assert.is_true(executed[1].show)
    assert.are.equal("SHOWGRID_EMPTY", executed[1].snippet)
  end)

  it("gives a button the bar is not showing the bit alone", function()
    _G.ActionButton1 = button({ index = 7, bar = { numButtonsShowable = 6, UpdateShownButtons = function() end } })
    _G.ActionButton2 = button({ attributes = { statehidden = true } })
    update()
    assert.are.equal(2, #executed)
    assert.is_false(executed[1].show)
    assert.is_false(executed[2].show)
  end)

  it("leaves a button alone that has the bit and is shown, or has it and is not in use", function()
    _G.ActionButton1 = button({ shown = true, attributes = { showgrid = BIT + 1 } })
    _G.ActionButton2 = button({ attributes = { showgrid = BIT, statehidden = true } })
    update()
    assert.are.equal(0, #executed)
  end)

  it("shows one again that has the bit, is in use and is hidden", function()
    _G.ActionButton1 = button({ attributes = { showgrid = BIT } })
    update()
    assert.are.equal(1, #executed)
    assert.is_true(executed[1].show)
  end)

  it("touches nothing in combat, on Retail or Forever, or on a bar addon's buttons", function()
    _G.ActionButton1 = button()
    combat = true
    update()
    combat = false
    _G.GSE.GameMode = 12
    update()
    _G.GSE.GameMode = 2
    _G.ActionButton1 = { GetAttribute = function() end }   -- no bar of Blizzard's
    update()
    assert.are.equal(0, #executed)
    assert.are.equal(0, #released)
  end)

  it("lets go of the ones it showed once the menu is turned off, but not a sequence's button", function()
    _G.GSEOptions.actionBarOverridePopup = false
    _G.ActionButton1 = button({ attributes = { showgrid = BIT } })
    _G.ActionButton2 = button({ attributes = { showgrid = BIT, ["gse-button"] = "seqA" } })
    update()
    assert.are.equal(0, #executed)
    assert.are.same({ { button = _G.ActionButton1, shown = false } }, released)
  end)

  it("sets the bit in a secure snippet and shows the button only when told to", function()
    local snippet = assert(src:match("\nlocal SHOWGRID_EMPTY = %[%[\n(.-)\n%]%]\n"), "SHOWGRID_EMPTY not found")
    assert.truthy(snippet:find('if math.floor(grid / 262144) % 2 == 0 then b:SetAttribute("showgrid", grid + 262144) end', 1, true))
    assert.truthy(snippet:find('if self:GetAttribute("gseGridShow") then b:Show() end', 1, true))
    assert.truthy(src:find("\nlocal GSE_FORCE_SHOWGRID_REASON = 262144 ", 1, true))
  end)

  it("covers every Blizzard bar the menu is on", function()
    local bars = assert(src:match("\nlocal EMPTY_BUTTON_BAR = {}\nfor _, prefix in ipairs%({(.-)}%) do\n"))
    for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
      "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }) do
      assert.truthy(bars:find('"' .. prefix .. '"', 1, true), prefix)
    end
  end)

  it("keeps the bit when a sequence comes off a button it shows anyway", function()
    local forced = assert(src:match("\nlocal function setOverrideButtonForcedShown%(buttonOrName, shown%)\n(.-)\nend\n"))
    assert.truthy(forced:find('if not shown and EMPTY_BUTTON_BAR[btn:GetName() or ""] and GSE.ShowsEmptyButtons() then return end', 1, true))
  end)

  it("runs at login, when combat ends, and when the menu's switch changes", function()
    assert.truthy(src:find("    loadActionBar()\n    LoadOverrides()\n    GSE.UpdateEmptyButtons()\n", 1, true))
    assert.truthy(src:find("    if actionBarWaiting then GSE.StartActionBar() end\n    LoadOverrides()\n    GSE.UpdateEmptyButtons()\n", 1, true))
    local fh = assert(io.open("GSE_Options/Options.lua", "r"))
    local options = fh:read("*a"):gsub("\r\n", "\n")
    fh:close()
    assert.truthy(options:find("setting:SetValueChangedCallback(function() GSE.UpdateEmptyButtons() end)", 1, true))
  end)
end)
