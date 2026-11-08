-- Dragging an overridden action button moves its sequence (GSE/API/Events.lua,
-- overrideDragStart): only with the bars unlocked or the Lock Action Bars key
-- held, out of combat, while the button runs the sequence, and when the drag
-- picked nothing real up from the slot.
--
-- Events.lua cannot be loaded here, so this reads the function out of it as
-- text and runs it against a stand-in button.
--
-- Run: busted spec/overridedrag_spec.lua   /   lua5.1 spec/run51.lua
describe("Dragging an overridden action button", function()
  local GLOBALS = { "GSE", "InCombatLockdown", "GetCursorInfo", "GetCVarBool", "IsModifiedClick" }
  local saved, dragStart, began
  local combat, cursor, locked, modifier

  local function button(attributes, fields)
    local b = fields or {}
    b.GetAttribute = function(_, name) return attributes[name] end
    b.GetName = function() return "ActionButton1" end
    return b
  end

  -- The game's globals go on _G itself: busted runs each spec file in its own
  -- environment, and code loaded from Events.lua as text reads the real one.
  setup(function()
    saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local body = assert(src:match("\nlocal function overrideDragStart%(self%)\n(.-)\nend\n"), "overrideDragStart not found")
    dragStart = assert((loadstring or load)("return function(self)\n" .. body .. "\nend"))()
    assert.truthy(src:find('HookScript("OnDragStart", overrideDragStart)', 1, true))
    _G.InCombatLockdown = function() return combat end
    _G.GetCursorInfo = function() return cursor end
    _G.GetCVarBool = function(name) return name == "lockActionBars" and locked end
    _G.IsModifiedClick = function(name) return name == "PICKUPACTION" and modifier end
    _G.GSE = {
      ButtonOverrideSequence = function(name) return name == "ActionButton1" and "seqA" or nil end,
      BeginSequenceDrag = function(sequenceId, from) began = { sequenceId, from } end,
    }
  end)

  teardown(function()
    for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
  end)

  before_each(function()
    began, combat, cursor, locked, modifier = nil, false, nil, true, true
  end)

  local armed = { type = "click", ["gse-button"] = "seqA" }

  it("starts the drag with the Lock Action Bars key held", function()
    local b = button(armed)
    dragStart(b)
    assert.are.equal("seqA", began[1])
    assert.are.equal(b, began[2])
  end)

  it("starts the drag with the bars unlocked and no key", function()
    locked, modifier = false, false
    dragStart(button(armed))
    assert.truthy(began)
  end)

  it("does nothing with the bars locked and no key", function()
    modifier = false
    dragStart(button(armed))
    assert.falsy(began)
  end)

  it("does nothing in combat", function()
    combat = true
    dragStart(button(armed))
    assert.falsy(began)
  end)

  it("does nothing when the drag picked something up from the slot", function()
    cursor = "spell"
    dragStart(button(armed))
    assert.falsy(began)
  end)

  it("does nothing while the bar is swapped and the button runs its action", function()
    dragStart(button({ type = "action", ["gse-button"] = "seqA" }))
    assert.falsy(began)
  end)

  it("leaves the GSE Action Bar's buttons to their own drag", function()
    dragStart(button(armed, { gseActionBarButton = true }))
    assert.falsy(began)
  end)
end)

-- Taking an override off a Blizzard button (GSE/API/Events.lua,
-- setOverrideButtonForcedShown): WoW cannot add its "Always Show Buttons" bit
-- to showgrid while GSE's bit is on, so GSE puts it there before taking its
-- own off, or the bar hides the empty button until a reload.
describe("An override coming off a Blizzard action button", function()
  local function snippet(src, name)
    local body = assert(src:match("\nlocal " .. name .. " = %[%[\n(.-)\n%]%]\n"), name .. " not found")
    return assert((loadstring or load)("local self = ...\n" .. body))
  end

  it("leaves the button showing where the bar always shows its buttons", function()
    local fh = assert(io.open("GSE/API/Events.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    local attributes = { showgrid = 262144 } -- GSE's bit alone: WoW never got its own on
    local b = {
      GetAttribute = function(_, name) return attributes[name] end,
      SetAttribute = function(_, name, value) attributes[name] = value end,
    }
    local handler = { GetFrameRef = function() return b end }
    snippet(src, "SHOWGRID_ALWAYS")(handler)
    snippet(src, "SHOWGRID_OFF")(handler)
    assert.are.equal(1, attributes.showgrid)
    -- Without the bar's setting, GSE's bit comes off and nothing is added.
    attributes.showgrid = 262144
    snippet(src, "SHOWGRID_OFF")(handler)
    assert.are.equal(0, attributes.showgrid)
    -- The setting decides, and its bit goes on before GSE's comes off.
    local always = assert(src:find("if not shown and barAlwaysShowsButtons(btn.bar) then SHBT:Execute(SHOWGRID_ALWAYS) end", 1, true))
    assert.truthy(src:find("SHBT:Execute(shown and SHOWGRID_ON or SHOWGRID_OFF)", always, true))
  end)
end)
