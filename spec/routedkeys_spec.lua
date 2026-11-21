-- EllesmereUI, DaylightUI and Dominos send a button's key somewhere other
-- than the button frame, so GSE routes the key back through the frame for a
-- button a sequence is on (GSE_EABBindOwner, Events.lua). The routes follow
-- WoW's Key Bindings as they change: a key bound there runs the sequence at
-- once, and a key cleared there stops at once. They were only laid when the
-- overrides were rebuilt, so a change took hold "after an event" (Larry,
-- EllesmereUI, 2026-11-21).
--
-- The routing code is run as Events.lua has it, in a world with bindings,
-- override bindings that fire UPDATE_BINDINGS as WoW's do, and a clock.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("keys routed through a bar addon's button", function()
  local events = readSource("GSE/API/Events.lua")

  local function world()
    local s = assert(events:find('local GSE_EABBindOwner = CreateFrame("Frame", "GSE_EABBindOwner", UIParent)', 1, true))
    local e = assert(events:find("-- pinnedStates:", s, true))
    local code = events:sub(s, e - 1) .. "\nreturn routeButtonKeys, GSE_EABBindOwner"
    local w = { keys = {}, routes = {}, sets = 0, clears = 0, combat = false, timers = {}, buttons = {} }
    local owner
    local function fire()
      if owner and owner.events.UPDATE_BINDINGS and owner.onEvent then owner.onEvent(owner, "UPDATE_BINDINGS") end
    end
    local env = {
      ipairs = ipairs, pairs = pairs, next = next,
      _G = w.buttons,
      UIParent = {},
      CreateFrame = function()
        owner = { events = {} }
        function owner:RegisterEvent(name) self.events[name] = true end
        function owner:SetScript(_, fn) self.onEvent = fn end
        return owner
      end,
      InCombatLockdown = function() return w.combat end,
      GetBindingKey = function(cmd)
        local k = w.keys[cmd] or {}
        return k[1], k[2]
      end,
      SetOverrideBindingClick = function(_, priority, key, button)
        assert(priority == true, "a priority route, over the bar addon's own")
        assert(not w.combat, "routed in combat")
        w.sets = w.sets + 1
        w.routes[key] = button
        fire()
      end,
      ClearOverrideBindings = function()
        assert(not w.combat, "cleared in combat")
        w.clears = w.clears + 1
        w.routes = {}
        fire()
      end,
      C_Timer = { After = function(_, fn) w.timers[#w.timers + 1] = fn end },
    }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "routes", "t", env))
    end
    w.route, w.owner = chunk()
    -- WoW's Key Bindings changing a key: the binding, then the event.
    function w.bind(cmd, ...)
      w.keys[cmd] = { ... }
      fire()
    end
    -- The next frames, until nothing is waiting (or it never settles).
    function w.frames()
      for _ = 1, 20 do
        local due = w.timers
        if #due == 0 then return end
        w.timers = {}
        for _, fn in ipairs(due) do fn() end
      end
      error("the routes never settle: laying one fires UPDATE_BINDINGS again")
    end
    return w
  end

  local function ellesmere(w, name, cmd)
    w.buttons[name] = { commandName = cmd, GetAttribute = function() return nil end }
  end

  it("listens for a change in WoW's Key Bindings", function()
    local w = world()
    assert.is_true(w.owner.events.UPDATE_BINDINGS)
  end)

  it("routes a key bound after the sequence went on, with no rebuild", function()
    local w = world()
    ellesmere(w, "EABButton1", "ACTIONBUTTON1")
    assert.is_true(w.route("EABButton1"))
    w.frames()
    assert.are.same({}, w.routes, "no key yet")
    w.bind("ACTIONBUTTON1", "F")
    w.frames()
    assert.are.same({ F = "EABButton1" }, w.routes)
  end)

  it("stops a key cleared in WoW's Key Bindings, and follows one that moves", function()
    local w = world()
    ellesmere(w, "EABButton1", "ACTIONBUTTON1")
    ellesmere(w, "EABButton2", "ACTIONBUTTON2")
    w.keys.ACTIONBUTTON1 = { "1", "SHIFT-1" }
    w.keys.ACTIONBUTTON2 = { "2" }
    w.route("EABButton1")
    w.route("EABButton2")
    w.frames()
    assert.are.same({ ["1"] = "EABButton1", ["SHIFT-1"] = "EABButton1", ["2"] = "EABButton2" }, w.routes)
    w.bind("ACTIONBUTTON1")
    w.frames()
    assert.are.same({ ["2"] = "EABButton2" }, w.routes, "the cleared keys run the sequence no more")
    w.bind("ACTIONBUTTON2", "G")
    w.frames()
    assert.are.same({ G = "EABButton2" }, w.routes)
  end)

  it("touches nothing when no key has moved", function()
    local w = world()
    ellesmere(w, "EABButton1", "ACTIONBUTTON1")
    w.keys.ACTIONBUTTON1 = { "1" }
    w.route("EABButton1")
    w.frames()
    local sets, clears = w.sets, w.clears
    w.bind("JUMP", "SPACE")
    w.frames()
    assert.are.equal(sets, w.sets)
    assert.are.equal(clears, w.clears)
    assert.are.equal(0, #w.timers)
  end)

  it("waits out combat, where nothing can be routed", function()
    local w = world()
    ellesmere(w, "EABButton1", "ACTIONBUTTON1")
    w.route("EABButton1")
    w.frames()
    w.combat = true
    w.bind("ACTIONBUTTON1", "F")
    w.frames()
    assert.are.same({}, w.routes)
    -- The overrides are rebuilt when combat ends (PLAYER_REGEN_ENABLED).
    assert.truthy(events:find("function GSE:PLAYER_REGEN_ENABLED(unit, event, addon)\n    GSE:UnregisterEvent(\"PLAYER_REGEN_ENABLED\")", 1, true))
  end)

  it("reads a Dominos button's command from its attribute", function()
    local w = world()
    w.buttons.DominosActionButton1 = { GetAttribute = function(_, name) return name == "commandName" and "CLICK DominosActionButton1Hotkey:HOTKEY" or nil end }
    w.keys["CLICK DominosActionButton1Hotkey:HOTKEY"] = { "Q" }
    assert.is_true(w.route("DominosActionButton1", true))
    w.bind("CLICK DominosActionButton1Hotkey:HOTKEY", "E")
    w.frames()
    assert.are.same({ E = "DominosActionButton1" }, w.routes)
  end)

  it("a button with no binding command is not routed", function()
    local w = world()
    w.buttons.EABButton9 = { GetAttribute = function() return nil end }
    assert.is_false(w.route("EABButton9"))
  end)

  it("is the one way the overrides lay a route, and a rebuild starts from none", function()
    assert.truthy(events:find("if not routeButtonKeys(Button) then", 1, true), "EllesmereUI and DaylightUI")
    assert.truthy(events:find("if isDominosButton then routeButtonKeys(Button, true) end", 1, true), "Dominos")
    assert.truthy(events:find("ClearOverrideBindings(GSE_EABBindOwner)\n        routedButtons, routedKeys = {}, {}", 1, true))
    local _, direct = events:gsub("SetOverrideBindingClick%(GSE_EABBindOwner,", "")
    assert.are.equal(2, direct, "in routeButtonKeys and rerouteButtonKeys only")
  end)
end)
