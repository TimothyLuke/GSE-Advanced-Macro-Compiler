-- The keys of action bar buttons a sequence is on (GSE/API/OverrideKeys.lua):
-- GSE says in chat when one is cleared or bound to something else, so the
-- sequence no longer runs from it.
--
-- Run: busted spec/overridekeys_spec.lua   /   lua5.1 spec/run51.lua
describe("Keys of the buttons a sequence is on", function()
  local GLOBALS = { "GetBindingKey", "GetBindingAction", "GetBindingText", "C_Timer", "CreateFrame", "GSEOptions",
    "ActionButton3", "BT4Button1", "DominosActionButton2", "BINDING_NAME_ACTIONBUTTON3", "BINDING_NAME_JUMP" }
  local GSE, printed, timers, bindings, events

  local function runTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
  end

  local function load()
    local saved = {}
    for _, name in ipairs(GLOBALS) do saved[name] = _G[name] end
    printed, timers, bindings, events = {}, {}, {}, {}
    _G.GetBindingKey = function(command)
      local keys = {}
      for key, bound in pairs(bindings) do if bound == command then keys[#keys + 1] = key end end
      table.sort(keys)
      return keys[1], keys[2]
    end
    _G.GetBindingAction = function(key) return bindings[key] or "" end
    _G.GetBindingText = function(key) return key end
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.CreateFrame = function()
      return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(self, _, fn) self.onEvent = fn; events.frame = self end,
      }
    end
    _G.GSEOptions = {}
    _G.BINDING_NAME_ACTIONBUTTON3 = "Action Button 3"
    _G.BINDING_NAME_JUMP = "Jump"
    local function frame(name, fields)
      local f = fields or {}
      f.GetName = function() return name end
      f.GetAttribute = f.GetAttribute or function() return nil end
      _G[name] = f
    end
    -- Blizzard's, LibActionButton's (Bartender) and Dominos'.
    frame("ActionButton3", { bindingAction = "ACTIONBUTTON3" })
    frame("BT4Button1", { config = {}, GetBindingAction = function() return "CLICK BT4Button1:Keybind" end })
    frame("DominosActionButton2", {
      GetAttribute = function(_, key) return key == "commandName" and "CLICK DominosActionButton2:HOTKEY" or nil end,
    })
    GSE = {
      L = setmetatable({}, { __index = function(_, k) return k end }),
      Print = function(text) printed[#printed + 1] = text end,
      SequenceName = function(id) return ({ seqA = "Fire Opener", seqB = "AoE" })[id] end,
      ButtonOverrides = {},
    }
    assert(loadfile("GSE/API/OverrideKeys.lua"))("GSE", GSE)
    return function()
      for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
    end
  end

  local restore
  local function bindingsChanged()
    events.frame.onEvent(events.frame, "UPDATE_BINDINGS")
    runTimers()
  end
  -- Put back what the last test faked first: Lua 5.1's runner has no after_each.
  local function start()
    if restore then restore() end
    restore = load()
    bindings["3"] = "ACTIONBUTTON3"
    bindings["Q"] = "CLICK BT4Button1:Keybind"
    bindings["E"] = "CLICK DominosActionButton2:HOTKEY"
    GSE.ButtonOverrides = { ActionButton3 = "seqA", BT4Button1 = "seqB", DominosActionButton2 = "seqB" }
    GSE.CheckOverrideKeys()
    runTimers()
  end

  after_each(function()
    if restore then restore() end
    restore = nil
  end)

  it("says when a button's key is cleared", function()
    start()
    bindings["3"] = nil
    bindingsChanged()
    assert.are.same({ "Fire Opener (Action Button 3) has no key now. It was on 3." }, printed)
  end)

  it("says where a button's key moved, and what the old key runs now", function()
    start()
    bindings["3"] = "JUMP"
    bindings["4"] = "ACTIONBUTTON3"
    bindingsChanged()
    assert.are.same({ "Fire Opener (Action Button 3) is now on 4. It was on 3. 3 now runs Jump." }, printed)
  end)

  it("names a sequence a lost key now clicks", function()
    start()
    bindings["Q"] = "CLICK seqA:LeftButton"
    bindingsChanged()
    assert.are.same({ "AoE (BT4Button1) has no key now. It was on Q. Q now runs Fire Opener." }, printed)
  end)

  it("watches Dominos' and LibActionButton's keys", function()
    start()
    bindings["E"], bindings["Q"] = nil, nil
    bindingsChanged()
    table.sort(printed)
    assert.are.same({ "AoE (BT4Button1) has no key now. It was on Q.",
      "AoE (DominosActionButton2) has no key now. It was on E." }, printed)
  end)

  it("says nothing of a key added, or a button that only just got its sequence", function()
    start()
    bindings["SHIFT-3"] = "ACTIONBUTTON3"
    bindingsChanged()
    assert.are.equal(0, #printed)
    GSE.ButtonOverrides.ActionButton3 = "seqB"
    bindings["3"] = nil
    bindingsChanged()
    assert.are.equal(0, #printed)
  end)

  it("says nothing of a key unbound and bound again in one go", function()
    start()
    events.frame.onEvent(events.frame, "UPDATE_BINDINGS")
    bindings["3"] = nil
    events.frame.onEvent(events.frame, "UPDATE_BINDINGS")
    bindings["3"] = "ACTIONBUTTON3"
    runTimers()
    assert.are.equal(0, #printed)
  end)

  it("says nothing with the switch off, and starts again from the keys then", function()
    start()
    GSEOptions.actionBarReportKeyChanges = false
    bindings["3"] = nil
    bindingsChanged()
    assert.are.equal(0, #printed)
    GSEOptions.actionBarReportKeyChanges = nil
    bindingsChanged()
    assert.are.equal(0, #printed)
  end)

  it("watches WoW's bindings, and loads after the overrides", function()
    start()
    assert.is_true(events.UPDATE_BINDINGS)
    assert.is_true(events.PLAYER_ENTERING_WORLD)
    local fh = assert(io.open("GSE/GSE.toc", "r"))
    local toc = fh:read("*a"):gsub("\r\n", "\n"):gsub("\r", "\n")
    fh:close()
    assert.truthy(toc:find("\nAPI\\Events.lua\nAPI\\OverrideKeys.lua\n", 1, true))
  end)
end)
