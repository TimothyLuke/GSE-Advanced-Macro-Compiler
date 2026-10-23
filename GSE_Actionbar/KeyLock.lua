local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local Statics = GSE.Static

-- ── Lock Keys to GSE ────────────────────────────────────────────────────────
--
-- A GSE button's key is an ordinary WoW binding, so WoW's Key Bindings keeps
-- it from being bound twice. What that screen never shows is a priority
-- override (SetOverrideBinding*), which another addon can lay over the key
-- at any time and which beats the binding. With the option on (the bars'
-- LockKeys setting, on by default) every key bound to a GSE button also
-- gets a priority override onto the button, so the key reaches it whatever
-- else binds it. Between two priority overrides the one set last wins, so
-- when another addon's lands after GSE's, a popup names that addon and asks
-- whether to take the key back or let it go. The answer is kept per
-- character and key (GSE_C.ActionBarKeyLockAnswers) until the key is bound
-- to a GSE button again (GSE.ActionBarKeyRebound), so an addon that takes the key at
-- every login is asked about once. A key is taken back at most LOCK_RETAKES
-- times a session; past that GSE says so and leaves it.
--
-- WoW fires no event when an override is set (measured on MoP for #2156), so
-- the calls that set them are watched too. Binds are blocked in combat;
-- leaving combat comes back to whatever was left.

local LOCK_RETAKES = 3
local owner = CreateFrame("Frame", "GSEActionBarKeyLockOwner")
local lockedKeys = {} -- key -> button index, from the last apply
local retakes = {} -- key -> times taken back this session
local takenBy = {} -- key -> the addon whose override call was last seen on it
local beatenWarned = {} -- key -> true once the player was told it could not be held
local letGo = {} -- key -> true: left to its taker this session
local asking -- the key the popup is up for

local function answers()
    if GSE.isEmpty(GSE_C) then GSE_C = {} end
    GSE_C.ActionBarKeyLockAnswers = GSE_C.ActionBarKeyLockAnswers or {}
    return GSE_C.ActionBarKeyLockAnswers
end

--- Whether the bar's keys are locked: the bar on and the option on.
function ns.KeysLocked()
    return GSE.ActionBarActive() and ns.Options().LockKeys ~= false
end

local function buttonLabel(index)
    return _G["BINDING_NAME_" .. ns.BindingCommand(index)] or ns.ButtonName(index)
end
local function effectiveAction(key)
    return GetBindingAction(key, true) or ""
end
local function held(key, index)
    return effectiveAction(key) == ns.BindingCommand(index)
end
local function lock(key, index)
    SetOverrideBindingClick(owner, true, key, ns.ButtonName(index), "LeftButton")
end

local function beaten(key, effective, label)
    if beatenWarned[key] then return end
    beatenWarned[key] = true
    GSE.Print(string.format(L["Another addon's override has %s (%s), and Lock Keys to GSE could not take it back for %s."],
        key, effective, label), L["Lock Keys to GSE"])
end
-- Take a locked key back from another override; says how it went.
local function retake(key, index, effective, label)
    retakes[key] = (retakes[key] or 0) + 1
    lock(key, index)
    if held(key, index) then
        GSE.Print(string.format(L["Lock Keys to GSE took %s back for %s."], key, label), L["Lock Keys to GSE"])
    else
        beaten(key, effective, label)
    end
end

local recheck -- below
StaticPopupDialogs["GSE_ACTIONBAR_KEY_OVERRIDDEN"] = {
    text = "%s",
    button1 = L["Take it back"],
    button2 = L["Let it go"],
    OnAccept = function(_, data)
        asking = nil
        answers()[data.key] = {addon = data.addon or "", take = true}
        if not InCombatLockdown() then retake(data.key, data.index, data.effective, data.label) end
        recheck()
    end,
    OnCancel = function(_, data)
        asking = nil
        answers()[data.key] = {addon = data.addon or "", take = false}
        letGo[data.key] = true
        GSE.Print(string.format(L["%s is left with %s. GSE will remember that; bind %s again in GSE to take it back."],
            data.key, data.effective, data.key), L["Lock Keys to GSE"])
        recheck()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}

-- A locked key that no longer reaches its button: take it back, or ask.
local function hold(key, index)
    local effective = effectiveAction(key)
    if held(key, index) or InCombatLockdown() or asking or letGo[key] then return end
    local label = buttonLabel(index)
    if (retakes[key] or 0) >= LOCK_RETAKES then
        beaten(key, effective, label)
        return
    end
    local answer = answers()[key]
    if answer and answer.take == false then return end
    -- Answered "take it back" for this addon before: no need to ask again.
    if answer and answer.take and answer.addon == (takenBy[key] or "") then
        retake(key, index, effective, label)
        return
    end
    asking = key
    StaticPopup_Show("GSE_ACTIONBAR_KEY_OVERRIDDEN",
        GSEOptions.TitleColour .. L["GSE: Lock Keys to GSE"] .. Statics.StringReset .. "\n\n"
            .. string.format(L["%s took %s with an override:\n%s\n\nGSE has %s locked to %s. Take it back?"],
                takenBy[key] or L["Another addon"], key, effective, key, label),
        nil, {key = key, index = index, effective = effective, label = label, addon = takenBy[key]})
end

-- Every key bound to a GSE button gets its override; a key the player let
-- go keeps none. Out of combat only (WoW blocks the binds in combat).
local function apply()
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    lockedKeys = {}
    if not ns.KeysLocked() then return end
    for index = 1, ns.BUTTON_COUNT do
        for _, key in ipairs({GetBindingKey(ns.BindingCommand(index))}) do
            lockedKeys[key] = index
            local answer = answers()[key]
            if not (answer and answer.take == false) then lock(key, index) end
        end
    end
    recheck()
end
GSE.ActionBarKeyLockRefresh = apply

--- The key was bound again in GSE (Button Bindings' Save): what was answered
--- about it no longer stands, so it is locked again and asked about afresh.
function GSE.ActionBarKeyRebound(key)
    if GSE.isEmpty(key) then return end
    answers()[key] = nil
    letGo[key] = nil
    retakes[key] = nil
    beatenWarned[key] = nil
end

do
    local watcher, queued = CreateFrame("Frame"), false
    recheck = function()
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            if not ns.KeysLocked() then return end
            for key, index in pairs(lockedKeys) do hold(key, index) end
        end)
    end
    -- Bindings changed (WoW's Key Bindings, GSE's Save, LoadBindings): the
    -- keys on the buttons may be new. Leaving combat: a bind that waited.
    watcher:RegisterEvent("UPDATE_BINDINGS")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", apply)
    for _, setter in ipairs({"SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell",
        "SetOverrideBindingItem", "SetOverrideBindingMacro"}) do
        if type(_G[setter]) == "function" then
            hooksecurefunc(setter, function(caller, _, key)
                if caller == owner or type(key) ~= "string" or not lockedKeys[key] then return end
                -- Whose call it was, for the popup: the first addon on the
                -- stack that is not GSE itself.
                if _G.debugstack then
                    for addon in string.gmatch(_G.debugstack(2, 6, 0) or "", "AddOns[/\\]([^/\\]+)[/\\]") do
                        if string.sub(addon, 1, 3) ~= "GSE" then
                            takenBy[key] = addon
                            break
                        end
                    end
                end
                recheck()
            end)
        end
    end
end

-- A key bound again to a GSE button -- GSE's Button Bindings or WoW's Key
-- Bindings, both through SetBinding -- starts clean.
hooksecurefunc("SetBinding", function(key, command)
    if type(key) == "string" and ns.ButtonForCommand(command) then GSE.ActionBarKeyRebound(key) end
end)

-- The bar turned on or off (GSE.StartActionBar) locks or frees its keys.
hooksecurefunc(GSE, "StartActionBar", apply)
apply()
end
table.insert(ns.deferred, setup)
