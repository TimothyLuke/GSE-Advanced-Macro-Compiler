-- The action buttons' right-click menu has a Keybind row that opens WoW's Key
-- Bindings at the button's section.
--
-- The menu is in GSE_Utils, which is always loaded; the code that opens the
-- page is in GSE_GUI, which loads on demand, so the menu calls it by name
-- through GSE.GUICall -- which does nothing, silently, for a name that is not
-- there. This holds the two ends to the same name. Read as text (line endings
-- normalised): neither file loads here.
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("action button right-click menu: Keybind", function()
  local menu = readSource("GSE_Utils/Utils.lua")
  local page = readSource("GSE_GUI/Editor_Keybind.lua")

  it("calls a function the Button Bindings page file defines", function()
    local name = assert(menu:match('L%["Keybind"%], function%(%)%s+GSE%.GUICall%("([%w_]+)", buttonName%)'),
      "the Keybind row's call not found")
    assert.truthy(page:find("function GSE." .. name .. "(buttonName)", 1, true), name .. " is not defined")
  end)

  it("opens Key Bindings at the button's own binding", function()
    local s = assert(page:find("function GSE.GUIOpenButtonKeyBindings(buttonName)", 1, true))
    local e = assert(page:find("\nend\n", s, true))
    assert.truthy(page:sub(s, e):find("openWoWKeyBindingsFor(bindingActionFor(buttonName))", 1, true))
  end)

  it("a cleared or moved sequence puts the States ticked for the next one back to Default", function()
    local events = readSource("GSE/API/Events.lua")
    local s = assert(events:find("local function forgetMenuStates()", 1, true))
    local forget = events:sub(s, assert(events:find("\nend\n", s, true)))
    assert.truthy(forget:find('if type(GSE_C) == "table" then GSE_C.ActionBarMenuStates = nil end', 1, true))
    for _, name in ipairs({ "function GSE.RemoveActionBarOverride(buttonName)", "function GSE.MoveActionBarOverride(fromName, toName)" }) do
      local from = assert(events:find(name, 1, true))
      local body = events:sub(from, assert(events:find("\nend\n", from, true)))
      local dropped = assert(body:find("forgetMenuStates()", 1, true), name .. " keeps the ticks")
      assert.is_true(dropped < assert(body:find("GSE.ReloadOverrides()", 1, true)))
    end
    -- The menu's Clear Override goes through the first of them.
    assert.truthy(menu:find('rootDescription:CreateButton(L["Clear Override"], function()\n                    GSE.RemoveActionBarOverride(buttonName)', 1, true))
    -- With none remembered, an empty button opens on the state it is in alone.
    assert.truthy(menu:find("toStates = { [first] = true }", 1, true))
    assert.truthy(menu:find('if type(last) == "table" and last[k] then toStates[k] = true end', 1, true))
  end)

  it("shows the row with and without sequences to list", function()
    local _, rows = menu:gsub("addKeybindRow%(rootDescription%)", "")
    assert.are.equal(2, rows, "after the pickers, and where the button has a sequence but none are left to pick")
  end)

  it("has its strings", function()
    local strings = readSource("GSE/Localization/ModL_enUS.lua")
    assert.truthy(strings:find('L["Keybind"] = true', 1, true))
    assert.truthy(strings:find('L["Open WoW\'s Key Bindings at this button, to set its key."] = true', 1, true))
  end)
end)

-- The menu's State pick takes more than one state (Larry, 2026-11-20: "a
-- Warrior can choice all 3 if they want"): the sequence goes on each ticked
-- state, a row apiece.
describe("action button right-click menu: more than one state", function()
  local menu = readSource("GSE_Utils/Utils.lua")
  local events = readSource("GSE/API/Events.lua")

  -- GSE.CreateActionBarOverrides as Events.lua has it, against a recorder.
  local function assign(states, inCombat)
    local calls = {}
    local GSE = {
      SetOverrideData = function(button, id, layer, state, loadout)
        calls[#calls + 1] = { "data", button, id, layer, state == nil and "nil" or state, loadout }
      end,
      CreateActionBarOverride = function(button, id, layer, state, loadout)
        calls[#calls + 1] = { "apply", button, id, layer, state == nil and "nil" or state, loadout }
        return layer
      end,
    }
    local s = assert(events:find("function GSE.CreateActionBarOverrides(buttonName, sequenceId, layer, states, loadout)", 1, true))
    local _, e = events:find("\nend\n", s, true)
    local code = events:sub(s, e) .. "\nreturn GSE.CreateActionBarOverrides"
    local env = { GSE = GSE, InCombatLockdown = function() return inCombat or false end }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "CreateActionBarOverrides", "t", env))
    end
    return chunk()("ActionButton1", "seq", "spec", states, "L1"), calls
  end

  it("writes a row for each ticked state, and applies once", function()
    local written, calls = assign({ "Default", "7", "9" })
    assert.are.equal("spec", written)
    assert.are.same({
      { "data", "ActionButton1", "seq", "spec", "nil", "L1" },
      { "data", "ActionButton1", "seq", "spec", "7", "L1" },
      { "apply", "ActionButton1", "seq", "spec", "9", "L1" },
    }, calls)
  end)

  it("writes the one state as before", function()
    local _, calls = assign({ "7" })
    assert.are.same({ { "apply", "ActionButton1", "seq", "spec", "7", "L1" } }, calls)
  end)

  it("puts it on the state the button is in where the button has no states to tick", function()
    local _, calls = assign({})
    assert.are.same({ { "apply", "ActionButton1", "seq", "spec", "nil", "L1" } }, calls)
  end)

  it("writes nothing in combat", function()
    local written, calls = assign({ "Default", "7" }, true)
    assert.is_nil(written)
    assert.are.same({}, calls)
  end)

  it("opens with every state that holds the sequence shown ticked", function()
    assert.truthy(menu:find("if holds == existingSequence then toStates[k] = true end", 1, true))
  end)

  it("opens an empty button with the states ticked at the last assignment, beside its own", function()
    assert.truthy(menu:find("local last = type(GSE_C) == \"table\" and GSE_C.ActionBarMenuStates", 1, true))
    assert.truthy(menu:find("for _, k in ipairs(pickedStates()) do GSE_C.ActionBarMenuStates[k] = true end", 1, true))
  end)

  it("changes a button that shows a sequence as its boxes are ticked and unticked", function()
    local s0 = assert(menu:find("select = function()", 1, true))
    local e0 = assert(menu:find("toStates[k] = not toStates[k] or nil", s0, true))
    local pick = menu:sub(s0, e0)
    assert.truthy(pick:find("if existingSequence then", 1, true))
    assert.truthy(pick:find("if InCombatLockdown() then return end", 1, true), "not in combat")
    assert.truthy(pick:find("GSE.ClearOverrideData(buttonName, state)", 1, true), "unticked: off that state")
    assert.truthy(pick:find("if tostring(saved) == tostring(state) then", 1, true), "its own row only, never the Default's")
    assert.truthy(pick:find("GSE.SetOverrideData(buttonName, existingSequence,", 1, true), "ticked: on that state")
    -- Saved at once, put on the buttons when the menu has closed: the menu
    -- stays open for the next tick (Larry, 2026-11-20).
    assert.is_nil(pick:find("GSE.ReloadOverrides()", 1, true), "putting it on at once closes the menu")
    assert.is_nil(pick:find("MenuResponse.CloseAll", 1, true))
    local _, later = pick:gsub("applyWhenMenuCloses%(self%)", "")
    assert.are.equal(2, later, "after a tick and after an untick")
    assert.truthy(menu:find("return choice.select() or MenuResponse.Refresh", 1, true))
  end)

  -- applyWhenMenuCloses / applyStateTicks as Utils.lua has them, with a menu
  -- that can be open or closed and a clock that ticks when told to.
  local function ticks()
    local s = assert(menu:find("    local applyTicker\n", 1, true))
    local e = assert(menu:find("    -- Shared handler:", s, true))
    local code = menu:sub(s, e - 1) .. "\nreturn applyWhenMenuCloses, applyStateTicks"
    local w = { applied = 0, combat = false, open = nil, tickers = 0 }
    local env = {
      GSE = { ReloadOverrides = function() w.applied = w.applied + 1 end },
      InCombatLockdown = function() return w.combat end,
      Menu = { GetManager = function() return { GetOpenMenu = function()
        return w.open and { GetOwnerRegion = function() return w.open end } or nil
      end } end },
      C_Timer = { NewTicker = function(_, fn)
        w.tickers = w.tickers + 1
        w.tick = fn
        return { Cancel = function() w.tick = nil end }
      end },
    }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "ticks", "t", env))
    end
    w.later, w.now = chunk()
    return w
  end

  it("puts the ticks on the buttons once the button's menu has closed, and once", function()
    local w, button = ticks(), {}
    w.open = button
    w.later(button)
    w.later(button)
    assert.are.equal(1, w.tickers, "one watch for any number of ticks")
    w.tick()
    assert.are.equal(0, w.applied, "the menu is still open")
    w.open = {}
    w.tick()
    assert.are.equal(1, w.applied, "another button's menu is not this one's")
    assert.is_nil(w.tick, "and the watch is over")
  end)

  it("holds the ticks through combat, and puts them on first when a menu is opened again", function()
    local w, button = ticks(), {}
    w.later(button)
    w.combat = true
    w.tick()
    assert.are.equal(0, w.applied)
    w.combat = false
    assert.is_true(w.now())
    assert.are.equal(1, w.applied)
    assert.is_false(w.now(), "nothing waiting")
    local handler = menu:sub(assert(menu:find("local function gseEmptyButtonHandler(self, mousebutton, down)", 1, true)))
    local first = assert(handler:find("if applyStateTicks() then", 1, true))
    local reads = assert(handler:find('local existingSequence = self:GetAttribute("gse-button")', 1, true))
    assert.is_true(first < reads, "before the menu reads what is on the buttons")
  end)

  -- watchMenuState / rebuildOpenMenu / placeReopenedMenu as Utils.lua has
  -- them, with a menu that can be open or closed, a button whose state can
  -- change, and a clock.
  local function watch()
    local s = assert(menu:find("    local stateWatch, reopenPlace, inPlaceMenu\n", 1, true))
    local e = assert(menu:find("    -- Shared handler:", s, true))
    local code = menu:sub(s, e - 1) .. "\nreturn watchMenuState, placeReopenedMenu, rebuildOpenMenu, PICKER_TAG"
    local w = { combat = false, open = nil, state = nil, time = 100, closed = 0, reopened = {}, left = 300, top = 500,
      tags = {}, built = {}, populated = {} }
    local function openMenu()
      if not w.open then return nil end
      if not (w.menu and w.menu.owner == w.open) then
        w.menu = {
          owner = w.open,
          GetOwnerRegion = function(self) return self.owner end,
          GetLeft = function() return w.left end,
          GetTop = function() return w.top end,
          SetMenuDescription = function(_, description)
            if w.failBuild then error("no") end
            w.built[#w.built + 1] = description
          end,
        }
      end
      return w.menu
    end
    local env = {
      tostring = tostring, pcall = pcall, ipairs = ipairs, pairs = pairs, error = error,
      GSE = { OverrideStateFor = function() return w.state end },
      InCombatLockdown = function() return w.combat end,
      GetTime = function() return w.time end,
      UIParent = "UIParent",
      MenuUtil = { CreateRootMenuDescription = function(mixin) return { mixin = mixin } end },
      MenuVariants = { GetDefaultContextMenuMixin = function() return "defaultMixin" end },
      Menu = {
        GetManager = function() return {
          GetOpenMenu = openMenu,
          CloseMenus = function() w.closed = w.closed + 1 w.open = nil end,
        } end,
        GetOpenMenuTags = function() return w.tags end,
        PopulateDescription = function(generator, owner, description)
          w.populated[#w.populated + 1] = { generator, owner, description }
        end,
      },
      C_Timer = { NewTicker = function(_, fn)
        w.tick = fn
        return { Cancel = function() w.tick = nil end }
      end },
    }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "watch", "t", env))
    end
    w.watch, w.place, w.rebuild, w.tag = chunk()
    w.reopen = function(owner, mousebutton) w.reopened[#w.reopened + 1] = { owner, mousebutton } end
    return w
  end
  local function menuFrame()
    local m = { points = {} }
    function m:ClearAllPoints() self.points = {} end
    function m:SetPoint(...) self.points[#self.points + 1] = { ... } end
    return m
  end
  local function pickerRow()
    local row = { opened = 0 }
    function row:ForceOpenSubmenu() self.opened = self.opened + 1 end
    return row
  end

  it("builds the menu again inside the open one when the button's state changes under it", function()
    local w, button = watch(), { gseABMenuOpenedAt = 99.9, menuMixin = "buttonMixin" }
    local generator = function() end
    local stateRow, loadoutRow = pickerRow(), pickerRow()
    local took
    w.reopen = function(owner, mousebutton)
      w.reopened[#w.reopened + 1] = { owner, mousebutton }
      took = w.rebuild(owner, generator, { State = stateRow, Loadout = loadoutRow })
      owner.gseABMenuOpenedAt = w.time
    end
    w.open = button
    w.watch(button, nil, w.reopen)
    w.tick()
    assert.are.same({}, w.reopened, "the same state: left alone")
    w.tags = { w.tag .. "State" }
    w.state = "7"
    w.tick()
    assert.are.same({ { button, "RightButton" } }, w.reopened)
    assert.is_true(took)
    assert.are.equal(0, w.closed, "the menu under the mouse stays open")
    assert.are.equal(1, #w.built, "with a new description on the same frame")
    assert.are.equal("buttonMixin", w.built[1].mixin)
    assert.are.same({ generator, button, w.built[1] }, w.populated[1])
    assert.are.equal(1, stateRow.opened, "and the State picker, open before, open again")
    assert.are.equal(0, loadoutRow.opened)
    assert.is_nil(w.tick, "the handler sets the next watch")
  end)

  it("builds in no menu but the one the watch handed over", function()
    local w, button = watch(), {}
    assert.is_false(w.rebuild(button, function() end, {}), "a menu opened by a click")
    w.open = button
    local took
    w.reopen = function(owner) took = w.rebuild({}, function() end, {}) owner.gseABMenuOpenedAt = w.time end
    w.watch(button, nil, w.reopen)
    w.state = "7"
    w.tick()
    assert.is_false(took, "another button's handler")
    w.open = button
    w.reopen = function(owner) w.rebuild(owner, function() end, {}) took = w.rebuild(owner, function() end, {}) end
    w.watch(button, "7", w.reopen)
    w.state = nil
    w.tick()
    assert.is_false(took, "once")
    assert.are.equal("defaultMixin", w.built[#w.built].mixin, "a button with no menu style of its own")
  end)

  it("opens a menu as a click does, where the old one was, when it cannot be built in place", function()
    local w, button = watch(), {}
    w.failBuild = true
    local took
    w.reopen = function(owner) took = w.rebuild(owner, function() end, {}) owner.gseABMenuOpenedAt = w.time end
    w.open = button
    w.watch(button, nil, w.reopen)
    w.state = "7"
    w.tick()
    assert.is_false(took)
    local m = menuFrame()
    w.place(button, m)
    assert.are.same({ { "TOPLEFT", "UIParent", "BOTTOMLEFT", 300, 500 } }, m.points)
    local again = menuFrame()
    w.place(button, again)
    assert.are.same({}, again.points, "once: the next menu opens at the mouse")
  end)

  it("closes the menu when the button has none in the new state, and not while ticks wait", function()
    local w, button = watch(), { gseABMenuOpenedAt = 99.9 }
    w.open = button
    w.watch(button, nil, w.reopen)
    w.state = "7"
    w.tick()
    assert.are.equal(1, w.closed, "the handler opened nothing: the stale menu goes")
    assert.is_nil(button.gseABMenuOpenedAt)
    w.open = button
    w.reopen = function(owner) owner.gseABMenuOpenedAt = w.time end
    w.watch(button, "7", w.reopen)
    w.state = nil
    w.tick()
    assert.are.equal(1, w.closed, "the handler opens it a moment later, ticks on the buttons first")
    assert.is_false(w.rebuild(button, function() end, {}), "as a click does, not in the old one")
  end)

  it("leaves a menu opened by hand, another button's, or a late one at the mouse", function()
    local w, button = watch(), {}
    local m = menuFrame()
    w.place(button, m)
    assert.are.same({}, m.points, "no state changed")
    w.open = button
    w.watch(button, "7", w.reopen)
    w.state = nil
    w.tick()
    w.place({}, m)
    assert.are.same({}, m.points, "another button's menu")
    w.open = button
    w.watch(button, nil, w.reopen)
    w.state = "7"
    w.tick()
    w.time = w.time + 1
    w.place(button, m)
    assert.are.same({}, m.points, "the handler opened nothing then; this one is a new click")
  end)

  it("stops watching when the menu is closed, and waits out combat", function()
    local w, button = watch(), {}
    w.open = button
    w.watch(button, nil, w.reopen)
    w.state, w.combat = "7", true
    w.tick()
    assert.are.same({}, w.reopened, "no menu opens in combat")
    assert.is_not_nil(w.tick)
    w.combat = false
    w.open = {}
    w.tick()
    assert.are.same({}, w.reopened, "another button's menu is open now")
    assert.is_nil(w.tick, "the watch is over")
    assert.are.equal(0, w.closed)
  end)

  it("watches a menu that offers States, from the state it opened in, and tags its pickers", function()
    local handler = menu:sub(assert(menu:find("local function gseEmptyButtonHandler(self, mousebutton, down)", 1, true)))
    assert.truthy(handler:find("        local function generator(ownerRegion, rootDescription)\n", 1, true))
    assert.truthy(handler:find("        if not rebuildOpenMenu(self, generator, pickerRows) then\n"
      .. "            placeReopenedMenu(self, MenuUtil.CreateContextMenu(self, generator))\n"
      .. "        end\n        if states then\n"
      .. "            watchMenuState(self, GSE.OverrideStateFor and GSE.OverrideStateFor(self), gseEmptyButtonHandler)\n"
      .. "        end\n    end\n", 1, true))
    assert.truthy(handler:find("            row:SetTag(PICKER_TAG .. title)\n            pickerRows[title] = row\n", 1, true))
  end)

  -- The ticks the menu opens on, as Utils.lua works them out: the names the
  -- fragment reads are given here, and toStates is read back.
  local function openTicks(w)
    local s = assert(menu:find("            local now = GSE.OverrideStateFor and GSE.OverrideStateFor(self)\n", 1, true))
    local last = 'if first ~= "Default" then toStates.Default = nil end\n'
    local e = assert(menu:find(last, s, true))
    local env = {
      ipairs = ipairs, tostring = tostring, type = type,
      self = {}, buttonName = "ActionButton1", stateOrder = { "Default", "7", "9" },
      existingSequence = w.shown,
      GSE = {
        OverrideStateFor = function() return w.state end,
        ButtonOverrideStates = { ActionButton1 = w.pinned or {} },
        ButtonOverrideDefaults = { ActionButton1 = w.default ~= nil },
        ButtonOverrides = { ActionButton1 = w.default },
      },
      GSE_C = { ActionBarMenuStates = w.last },
    }
    local code = menu:sub(s, e + #last - 1) .. " end"
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "ticks", "t", env))
    end
    chunk()
    return env.toStates
  end

  it("opens out of a stance with every state that holds the sequence ticked, Default too", function()
    assert.are.same({ Default = true, ["7"] = true },
      openTicks({ state = nil, shown = "seqA", default = "seqA", pinned = { ["7"] = "seqA", ["9"] = "seqB" } }))
    assert.are.same({ Default = true, ["7"] = true }, openTicks({ state = nil, last = { Default = true, ["7"] = true } }),
      "an empty button: the ticks of the last assignment")
  end)

  it("opens in a stance with every state holding its sequence ticked, Default only when it holds the same", function()
    assert.are.same({ Default = true, ["7"] = true },
      openTicks({ state = "7", shown = "seqA", default = "seqA", pinned = { ["7"] = "seqA", ["9"] = "seqB" } }),
      "Default holds the same sequence: Default, Stealth")
    assert.are.same({ ["7"] = true, ["9"] = true },
      openTicks({ state = 7, shown = "seqA", default = "seqB", pinned = { ["7"] = "seqA", ["9"] = "seqA" } }),
      "Default holds another: unticked, and the other state with the same sequence is ticked")
    assert.are.same({ ["7"] = true },
      openTicks({ state = "7", shown = "seqA", pinned = { ["7"] = "seqA" }, last = { Default = true } }),
      "ticks of the last assignment are for an empty button")
    assert.are.same({ ["7"] = true, ["9"] = true },
      openTicks({ state = "7", last = { Default = true, ["9"] = true } }),
      "an empty button: Default ticked last time is not carried into a stance")
  end)

  it("ticks states with boxes, keeps the last tick, and hands every ticked state on", function()
    assert.truthy(menu:find("local create = multi and row.CreateCheckbox or row.CreateRadio", 1, true))
    assert.truthy(menu:find("if toStates[k] and #pickedStates() == 1 then return end", 1, true), "never none ticked")
    assert.truthy(menu:find('GSE.CreateActionBarOverrides(buttonName, entryId,\n'
      .. '                            toLoadout and "loadout" or "spec", pickedStates(), toLoadout and toLoadout.id)', 1, true))
  end)
end)
