-- Dragging off a GSE Action Bar button (GSE_Actionbar/Actions.lua, pickup)
-- follows WoW's own bars: with Lock Action Bars on, only with the Pick Up
-- Action key held (Shift by default); with the bars unlocked, a plain drag.
-- Never in combat, and never while the cursor already holds something.
--
-- pickup reads locals of Actions.lua, so this reads the function out of it as
-- text and runs it with stand-ins for them, as overridedrag_spec does for the
-- override drag.
--
-- Run: busted spec/actionbardrag_spec.lua   /   lua5.1 spec/run51.lua
describe("Dragging off a GSE Action Bar button", function()
  local GLOBALS = { "GSE", "InCombatLockdown", "GetCursorInfo", "GetCVarBool", "IsModifiedClick" }
  local saved, pickup, actions, picked, began, changedButton
  local combat, cursor, locked, modifier

  local function button(sequenceId)
    return {
      gseIndex = 1,
      SetChecked = function() end,
      GetAttribute = function(_, name) if name == "gse-button" then return sequenceId end end,
    }
  end

  setup(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    local fh = assert(io.open("GSE_Actionbar/Actions.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local body = assert(src:match("\nlocal function pickup%(button%)\n(.-)\nend\n"), "pickup not found")
    assert.truthy(src:find('HookScript("OnDragStart", pickup)', 1, true))
    local make = assert((loadstring or load)(
      "local ns, changed = ...\nlocal pickedFrom, pickedAction\nreturn function(button)\n" .. body .. "\nend"))
    local ns = {
      Actions = function() return actions end,
      PickupAction = function(action) picked = action end,
    }
    pickup = make(ns, function(b) changedButton = b end)
    _G.InCombatLockdown = function() return combat end
    _G.GetCursorInfo = function() return cursor end
    _G.GetCVarBool = function(name) return name == "lockActionBars" and locked end
    _G.IsModifiedClick = function(name) return name == "PICKUPACTION" and modifier end
    _G.GSE = { BeginSequenceDrag = function(sequenceId, from) began = { sequenceId, from } end }
  end)

  teardown(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  before_each(function()
    actions = { { kind = "spell", id = 100 } }
    picked, began, changedButton = nil, nil, nil
    combat, cursor, locked, modifier = false, nil, true, false
  end)

  it("leaves the action on the button with the bars locked and no key", function()
    pickup(button())
    assert.is_nil(picked)
    assert.are.same({ kind = "spell", id = 100 }, actions[1])
  end)

  it("picks the action up with the bars locked and the Pick Up Action key held", function()
    modifier = true
    local b = button()
    pickup(b)
    assert.are.same({ kind = "spell", id = 100 }, picked)
    assert.is_nil(actions[1])
    assert.are.equal(b, changedButton)
  end)

  it("picks the action up with a plain drag when the bars are unlocked", function()
    locked = false
    pickup(button())
    assert.truthy(picked)
    assert.is_nil(actions[1])
  end)

  it("drags a sequence off only under the same rule", function()
    actions = {}
    pickup(button("seqA"))
    assert.falsy(began)
    modifier = true
    local b = button("seqA")
    pickup(b)
    assert.are.same({ "seqA", b }, began)
  end)

  it("does nothing in combat, even with the key held", function()
    combat, modifier = true, true
    pickup(button())
    assert.is_nil(picked)
    assert.truthy(actions[1])
  end)

  it("does nothing while the cursor already holds something", function()
    cursor, modifier = "item", true
    pickup(button())
    assert.is_nil(picked)
    assert.truthy(actions[1])
  end)
end)
