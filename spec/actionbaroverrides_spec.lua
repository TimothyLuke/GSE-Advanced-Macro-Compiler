-- The GSE Action Bar's keys under another binding's override
-- (GSE_Actionbar/Overrides.lua): GSE does not take the key back, it says in
-- chat when an override takes a button's key, who took it, and when it is
-- back.
--
-- Run: busted spec/actionbaroverrides_spec.lua   /   lua5.1 spec/run51.lua
describe("GSE Action Bar keys under an override", function()
  local GLOBALS = { "GetBindingKey", "GetBindingAction", "GetBindingText", "C_Timer", "hooksecurefunc",
    "debugstack", "CreateFrame", "GSEOptions", "SetOverrideBinding", "SetOverrideBindingClick",
    "SetOverrideBindingSpell", "SetOverrideBindingItem", "SetOverrideBindingMacro", "ClearOverrideBindings",
    "GSE_Actionbar_Initialize" }
  local ns, printed, timers, bindings, overrides, stack, events, active

  -- WoW's bindings: key -> command, and the overrides laid over them, by owner.
  local function effective(key)
    for _, laid in pairs(overrides) do
      if laid[key] then return laid[key] end
    end
    return bindings[key]
  end

  local function runTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
  end

  local function load(options)
    local saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    printed, timers, bindings, overrides, events, active = {}, {}, {}, {}, {}, true
    stack = "Interface/AddOns/GSE_Actionbar/Overrides.lua:1: in function\n"
    _G.GetBindingKey = function(command)
      local keys = {}
      for key, bound in pairs(bindings) do if bound == command then keys[#keys + 1] = key end end
      table.sort(keys)
      return keys[1], keys[2]
    end
    _G.GetBindingAction = function(key, checkOverride)
      return (checkOverride and effective(key) or bindings[key]) or ""
    end
    _G.GetBindingText = function(key) return key end
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.debugstack = function() return stack end
    _G.hooksecurefunc = function(t, key, hook)
      if type(t) == "string" then t, key, hook = _G, t, key end
      local own = t[key]
      t[key] = function(...) own(...); hook(...) end
    end
    _G.CreateFrame = function()
      return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(self, _, fn) self.onEvent = fn; events.frame = self end,
      }
    end
    _G.GSEOptions = { ActionBar = options or {}, SkyRidingBinds = {} }
    local function lay(owner, _, key, action)
      overrides[owner] = overrides[owner] or {}
      overrides[owner][key] = action
    end
    _G.SetOverrideBinding = lay
    _G.SetOverrideBindingClick = function(owner, priority, key, button)
      lay(owner, priority, key, button and ("CLICK " .. button .. ":LeftButton"))
    end
    _G.SetOverrideBindingSpell, _G.SetOverrideBindingItem, _G.SetOverrideBindingMacro = lay, lay, lay
    _G.ClearOverrideBindings = function(owner) overrides[owner] = nil end
    ns = {
      deferred = {},
      Refresh = function() end,
      GSE = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        ActionBarActive = function() return active end,
        Print = function(text) printed[#printed + 1] = text end,
      },
    }
    assert(loadfile("GSE_Actionbar/Bootstrap.lua"))("GSE_Actionbar", ns)
    assert(loadfile("GSE_Actionbar/Overrides.lua"))("GSE_Actionbar", ns)
    ns.deferred[1]()
    -- The hooked override functions stay for the test; the rest goes back.
    local hooked = {}
    for _, name in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings" }) do
      hooked[name] = _G[name]
    end
    return function()
      for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
    end, hooked
  end

  local restore, wow
  -- Put back what the last test faked first: Lua 5.1's runner has no after_each.
  local function start(options)
    if restore then restore() end
    restore, wow = load(options)
    bindings["F"] = "CLICK GSEButton3:LeftButton"
    bindings["SHIFT-2"] = "CLICK GSEButton14:LeftButton"
  end

  after_each(function()
    if restore then restore() end
    restore = nil
  end)

  it("says when another addon's override takes a button's key, and when it is back", function()
    start()
    local owner = {}
    stack = stack .. "Interface/AddOns/Dominos/bindings.lua:5: in function\n"
    wow.SetOverrideBinding(owner, false, "F", "JUMP")
    runTimers()
    assert.are.same({ "F (GSE Action Bar 1, button 3) is overridden by Dominos. It won't run the GSE button until that ends." },
      printed)
    wow.ClearOverrideBindings(owner)
    runTimers()
    assert.are.equal("F is back on GSE Action Bar 1, button 3.", printed[2])
    assert.are.equal(2, #printed)
  end)

  it("says nothing for an override laid and taken off again in one go", function()
    start()
    local owner = {}
    wow.SetOverrideBinding(owner, false, "F", "JUMP")
    wow.ClearOverrideBindings(owner)
    runTimers()
    assert.are.equal(0, #printed)
  end)

  it("names GSE's own Skyriding / Vehicle Keybinds when they take the key", function()
    start()
    GSEOptions.SkyRidingBinds = { [1] = "shift-2" }
    -- Laid from secure code: no call to see.
    overrides.vehicle = { ["SHIFT-2"] = "CLICK ActionButton1:LeftButton" }
    events.frame.onEvent(events.frame, "UPDATE_BINDINGS")
    runTimers()
    assert.are.same({ "SHIFT-2 (GSE Action Bar 2, button 2) is overridden by GSE's Skyriding / Vehicle Keybinds. It won't run the GSE button until that ends." },
      printed)
  end)

  it("says 'another binding' where it cannot tell whose override it is", function()
    start()
    overrides.unknown = { F = "JUMP" }
    events.frame.onEvent(events.frame, "UPDATE_BINDINGS")
    runTimers()
    assert.truthy(printed[1]:find("overridden by another binding", 1, true))
  end)

  it("says nothing with the switch off, or the module not running", function()
    start({ ReportOverrides = false })
    wow.SetOverrideBinding({}, false, "F", "JUMP")
    runTimers()
    assert.are.equal(0, #printed)
    start()
    active = false
    wow.SetOverrideBinding({}, false, "F", "JUMP")
    runTimers()
    assert.are.equal(0, #printed)
  end)

  it("says nothing of a key moved off the button while it was overridden", function()
    start()
    local owner = {}
    wow.SetOverrideBinding(owner, false, "F", "JUMP")
    runTimers()
    bindings["F"] = "MOVEFORWARD"
    wow.ClearOverrideBindings(owner)
    runTimers()
    assert.are.equal(1, #printed)
  end)

  it("watches WoW's bindings, and loads after the bar", function()
    start()
    assert.is_true(events.UPDATE_BINDINGS)
    assert.is_true(events.PLAYER_ENTERING_WORLD)
    local fh = assert(io.open("GSE_Actionbar/GSE_Actionbar.toc", "r"))
    local toc = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    assert.truthy(toc:find("\nActionBar.lua\nEditMode.lua\nOverrides.lua\n", 1, true))
  end)
end)
