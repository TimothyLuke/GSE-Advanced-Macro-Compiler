local _, GSE = ...

local L = GSE.L

-- ── Keys of the buttons a sequence is on ────────────────────────────────────
--
-- A sequence put on an action bar button (GSE.ButtonOverrides: Blizzard's
-- bars, a bar addon's, the GSE Action Bar) runs from that button's key in
-- WoW's Key Bindings. Clear that key, or bind it to something else, and the
-- sequence quietly stops running from it. GSE says so in chat: which sequence,
-- which button, the key it had and the one it has now, and what the key it
-- lost runs instead (actionBarReportKeyChanges, GSE's options).
--
-- Only a key lost is reported. A key added to the button loses nothing, and a
-- button that only just got its sequence has nothing to compare against yet.

-- button name -> { sequence, keys }, as last seen.
local known = {}
local pending = false

-- The binding commands a button's keys can be under, as each kind of bar
-- names them: Blizzard's (bindingAction), the GSE Action Bar's and
-- EllesmereUI's (commandName), Dominos' (the commandName attribute),
-- LibActionButton's (GetBindingAction), and a click on the button itself.
local function commandsFor(button)
    local commands, seen = {}, {}
    local function add(command)
        if type(command) == "string" and command ~= "" and not seen[command] then
            seen[command] = true
            commands[#commands + 1] = command
        end
    end
    add(button.bindingAction)
    add(button.commandName)
    if button.GetAttribute then add(button:GetAttribute("commandName")) end
    if type(button.GetBindingAction) == "function" and type(button.config) == "table" then
        add(button:GetBindingAction())
    end
    if button.GetName and button:GetName() then add("CLICK " .. button:GetName() .. ":LeftButton") end
    return commands
end

local function keysFor(button)
    local keys, seen = {}, {}
    for _, command in ipairs(commandsFor(button)) do
        for _, key in ipairs({ GetBindingKey(command) }) do
            if not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end
    table.sort(keys)
    return keys
end

local function keyText(key)
    return GetBindingText and GetBindingText(key) or key
end

local function keyList(keys)
    local shown = {}
    for i, key in ipairs(keys) do shown[i] = keyText(key) end
    return table.concat(shown, ", ")
end

-- What a binding command is called in WoW's Key Bindings, a sequence's name
-- for a click on a sequence's button, else the command itself.
local function commandText(command)
    local named = _G["BINDING_NAME_" .. command]
    if type(named) == "string" then return named end
    local clicked = command:match("^CLICK ([^:]+):")
    return clicked and GSE.SequenceName(clicked) or clicked or command
end

local function buttonText(button, name)
    for _, command in ipairs(commandsFor(button)) do
        local named = _G["BINDING_NAME_" .. command]
        if type(named) == "string" then return named end
    end
    return name
end

local function report(name, button, sequence, was, now)
    local still = {}
    for _, key in ipairs(now) do still[key] = true end
    local lost = {}
    for _, key in ipairs(was) do
        if not still[key] then lost[#lost + 1] = key end
    end
    if #lost == 0 then return end
    local label = GSE.SequenceName(sequence) or sequence
    local where = buttonText(button, name)
    local text
    if #now == 0 then
        text = string.format(L["%s (%s) has no key now. It was on %s."], label, where, keyList(was))
    else
        text = string.format(L["%s (%s) is now on %s. It was on %s."], label, where, keyList(now), keyList(was))
    end
    for _, key in ipairs(lost) do
        local action = GetBindingAction(key)
        if action and action ~= "" then
            text = text .. " " .. string.format(L["%s now runs %s."], keyText(key), commandText(action))
        end
    end
    GSE.Print(text, L["Button Bindings"])
end

local function check()
    pending = false
    local on = GSEOptions.actionBarReportKeyChanges ~= false
    local now = {}
    for name, sequence in pairs(GSE.ButtonOverrides or {}) do
        local button = _G[name]
        if button then
            local keys = keysFor(button)
            local last = known[name]
            if on and last and last.sequence == sequence then
                report(name, button, sequence, last.keys, keys)
            end
            now[name] = { sequence = sequence, keys = keys }
        end
    end
    known = now
end

-- A moment after the last change: a bar addon or WoW's Key Bindings window
-- moving a key does it as an unbind and a bind, and only where it ends up
-- counts.
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.5, check)
end

--- Look again at the keys of the buttons sequences are on (after the
--- overrides are rebuilt: a button given a sequence starts from its keys now).
GSE.CheckOverrideKeys = schedule

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", schedule)
