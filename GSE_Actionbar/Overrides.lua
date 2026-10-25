local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L

-- ── Keys an override takes ──────────────────────────────────────────────────
--
-- A key bound to a GSE button is an ordinary WoW binding, and any override
-- binding beats it: another addon's (SetOverrideBinding*), WoW's own for a
-- state such as a vehicle, or GSE's Skyriding / Vehicle Keybinds. Overrides
-- are meant to be temporary, so GSE does not fight them for the key: it says
-- in chat when one takes a GSE button's key, and again when the key is back
-- (ReportOverrides, GSE's options).

-- key -> { owner, name } of the last override laid on it, the name read from
-- the stack of that call: the addon that made it.
local laidBy = {}
-- key -> the button it is bound to, while an override has it.
local taken = {}
local pending = false

local function addonOnStack()
    for name in string.gmatch(debugstack(3) or "", "AddOns[/\\]([^/\\]+)[/\\]") do
        if name ~= "GSE_Actionbar" then return name end
    end
end

local function keyText(key)
    return GetBindingText and GetBindingText(key) or key
end

local function isSkyridingKey(key)
    local binds = type(GSEOptions) == "table" and GSEOptions.SkyRidingBinds
    if type(binds) ~= "table" then return false end
    for _, bound in pairs(binds) do
        if type(bound) == "string" and bound:upper() == key then return true end
    end
    return false
end

-- Who has key: the addon whose override was laid on it last, else GSE's own
-- Skyriding / Vehicle Keybinds (laid from secure code, which is not seen
-- laying them), else nobody GSE can name.
local function whoHas(key)
    local laid = laidBy[key]
    if laid and laid.name then return laid.name end
    if isSkyridingKey(key) then return L["GSE's Skyriding / Vehicle Keybinds"] end
    return L["another binding"]
end

local function check()
    pending = false
    local on = GSE.ActionBarActive() and ns.Options().ReportOverrides ~= false
    local now = {}
    if on then
        for index = 1, ns.BUTTON_COUNT do
            local command = ns.BindingCommand(index)
            for _, key in ipairs({ GetBindingKey(command) }) do
                if GetBindingAction(key, true) ~= command then now[key] = index end
            end
        end
    end
    for key, index in pairs(now) do
        if taken[key] ~= index then
            local b, slot = math.ceil(index / ns.BAR_SIZE), (index - 1) % ns.BAR_SIZE + 1
            GSE.Print(string.format(L["%s (GSE Action Bar %d, button %d) is overridden by %s. It won't run the GSE button until that ends."],
                keyText(key), b, slot, whoHas(key)))
        end
    end
    for key, index in pairs(taken) do
        -- Back on its button, rather than bound somewhere else since.
        if on and not now[key] and GetBindingAction(key) == ns.BindingCommand(index) then
            local b, slot = math.ceil(index / ns.BAR_SIZE), (index - 1) % ns.BAR_SIZE + 1
            GSE.Print(string.format(L["%s is back on GSE Action Bar %d, button %d."], keyText(key), b, slot))
        end
    end
    taken = now
end

-- A moment after the last change: an addon that clears its overrides and
-- lays them again does it in one go, and that is no change to report.
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.5, check)
end

-- After each call, only noting who made it: nothing about the call changes.
local function noteOverride(owner, _, key, action)
    if type(key) ~= "string" then return end
    key = key:upper()
    if action == nil then
        laidBy[key] = nil
    else
        laidBy[key] = { owner = owner, name = addonOnStack() or (owner and owner.GetName and owner:GetName()) }
    end
    schedule()
end
for _, name in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell",
    "SetOverrideBindingItem", "SetOverrideBindingMacro" }) do
    if _G[name] then hooksecurefunc(name, noteOverride) end
end
hooksecurefunc("ClearOverrideBindings", function(owner)
    for key, laid in pairs(laidBy) do
        if laid.owner == owner then laidBy[key] = nil end
    end
    schedule()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", schedule)
-- A setting changed, or what is on the buttons (GSE's options, the bar).
hooksecurefunc(ns, "Refresh", schedule)
end
table.insert(ns.deferred, setup)
