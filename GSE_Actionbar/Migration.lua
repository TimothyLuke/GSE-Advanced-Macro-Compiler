local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L

-- ── GSE's keybinds onto the bar ─────────────────────────────────────────────
--
-- A GSE keybind was a key GSE bound to a sequence itself, never saved by WoW.
-- With the bar on, each such key is bound in WoW's own Key Bindings to a bar
-- button, and the button gets a Button Binding to the sequence the key ran:
-- the spec's for a spec's key, the talent loadout's for a loadout's. A key
-- that ran different sequences in different specs is one button, bound to
-- each spec's sequence -- a Button Binding is per spec, as the keybind was.
--
-- Once per character (GSE_C.Updates.actionBarKeys). The keybinds GSE kept are
-- left where they are: with the bar on GSE does not bind them, and with it
-- off again they work as before where WoW still allows them. A key keeps the
-- button it was given on any character (GSEOptions.ActionBar.KeyButtons), so
-- a class's characters, which share their keybinds, share their buttons too.

-- Every keybind the character has: { spec, loadout (nil for the spec's own),
-- key, sequence }, spec-level ones first, each group in key order, so the
-- buttons are handed out the same way every time.
local function collectKeybinds()
    local specLevel, loadoutLevel = {}, {}
    for _, spec in ipairs(GSE.BindingSpecs()) do
        for key, sequence in pairs(GSE.SpecKeyBinds(spec.key, false) or {}) do
            if key ~= "LoadOuts" and type(sequence) == "string" then
                specLevel[#specLevel + 1] = { spec = spec.key, key = GSE.NormalizeBindKey(key), sequence = sequence }
            end
        end
        for loadout, binds in pairs(GSE.SpecLoadoutKeyBinds(spec.key, false) or {}) do
            for key, sequence in pairs(type(binds) == "table" and binds or {}) do
                if type(sequence) == "string" then
                    loadoutLevel[#loadoutLevel + 1] = { spec = spec.key, loadout = tostring(loadout),
                        key = GSE.NormalizeBindKey(key), sequence = sequence }
                end
            end
        end
    end
    local function byKey(a, b)
        if a.key ~= b.key then return a.key < b.key end
        if a.spec ~= b.spec then return a.spec < b.spec end
        return (a.loadout or "") < (b.loadout or "")
    end
    table.sort(specLevel, byKey)
    table.sort(loadoutLevel, byKey)
    for _, entry in ipairs(loadoutLevel) do specLevel[#specLevel + 1] = entry end
    return specLevel
end

-- The button for a key: the one WoW already binds it to, else the one it was
-- given before, else the first button nothing is bound to or promised to.
local function buttonFor(key, taken, keyButtons)
    local bound = ns.ButtonForCommand(GetBindingAction(key))
    if bound and bound <= ns.BUTTON_COUNT then return bound end
    local given = keyButtons[key]
    if given and given <= ns.BUTTON_COUNT and not GetBindingKey(ns.BindingCommand(given)) then return given end
    for index = 1, ns.BUTTON_COUNT do
        if not taken[index] and not GetBindingKey(ns.BindingCommand(index)) then return index end
    end
end

--- Move this character's keybinds onto the bar. Returns false while it has
--- to wait -- combat, or WoW not yet saying which spec each key is -- and true
--- once done or there is nothing to do.
function ns.MigrateKeybinds()
    if type(GSE_C) ~= "table" then return true end
    GSE_C.Updates = GSE_C.Updates or {}
    if GSE_C.Updates.actionBarKeys then return true end
    if InCombatLockdown() then return false end
    -- The keybinds are read from the shared profiles.
    if not GSE.MigrateToProfiles() then return false end
    for _, spec in ipairs(GSE.BindingSpecs()) do
        if not GSE.SpecIDForKey(spec.key) then return false end
    end

    local options = ns.Options()
    local keyButtons = options.KeyButtons
    local taken = {} -- button -> true, once a key of this pass has it
    for _, index in pairs(keyButtons) do taken[index] = true end
    local buttonOfKey, skipped, changed, moved = {}, {}, false, 0

    for _, entry in ipairs(collectKeybinds()) do
        local index = buttonOfKey[entry.key]
        if index == nil and not skipped[entry.key] then
            index = buttonFor(entry.key, taken, keyButtons)
            if not index then
                skipped[entry.key] = true
            else
                if GetBindingAction(entry.key) ~= ns.BindingCommand(index) then
                    if SetBinding(entry.key, ns.BindingCommand(index)) then changed = true end
                end
                buttonOfKey[entry.key], keyButtons[entry.key], taken[index] = index, index, true
            end
        end
        if index then
            local name = ns.ButtonName(index)
            local overrides = entry.loadout and GSE.SpecLoadoutOverrides(entry.spec, entry.loadout, true)
                or GSE.SpecOverrides(entry.spec, true)
            -- A Button Binding already there was set since: it stays.
            if overrides and overrides[name] == nil then
                overrides[name] = { Bind = name, Sequence = entry.sequence }
                moved = moved + 1
            end
        end
    end

    if changed then
        -- The set WoW is using: the account's or this character's.
        local current = GetCurrentBindingSet and GetCurrentBindingSet()
        SaveBindings(current or 2)
    end
    GSE_C.Updates.actionBarKeys = true

    if moved > 0 then
        GSE.Print(string.format(L["Moved %d GSE keybinds onto the GSE Action Bar. Their keys are set in WoW's Key Bindings, under AddOns."], moved))
    end
    local left = {}
    for key in pairs(skipped) do left[#left + 1] = key end
    if #left > 0 then
        table.sort(left)
        GSE.Print(string.format(L["The GSE Action Bar has no free button for these keys, so they were not moved: %s"],
            table.concat(left, ", ")))
    end
    return true
end

end
table.insert(ns.deferred, setup)
