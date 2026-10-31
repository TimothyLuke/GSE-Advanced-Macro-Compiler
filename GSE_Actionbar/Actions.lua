local _, ns = ...
ns.deferred = ns.deferred or {}

-- ── What a GSE Action Bar button holds ──────────────────────────────────────
--
-- A button holds a spell, item, toy, macro or equipment set as any action bar
-- button does: dropped on it, or picked up off it (Shift-drag while WoW's
-- action bars are locked). WoW has no action slot to spare for it -- every one
-- belongs to a Blizzard bar -- so GSE keeps it, per character and spec, in
-- GSE_C.ActionBarActions[spec][button], and casts it through the button's own
-- secure attributes.
--
-- An action on a button wins over the button's Button Binding, as an action in
-- its slot does on any other bar: GSE leaves the sequence unarmed
-- (GSE.ActionBarButtonHasAction, Events.lua) and it is back once the action is
-- taken off.

-- The type each kind casts through, and the attribute naming what it casts
-- (SECURE_ACTIONS, SecureTemplates.lua).
local ATTRIBUTES = {
    spell = "spell",
    mount = "spell",
    item = "item",
    toy = "toy",
    macro = "macro",
    equipmentset = "equipmentset",
}

--- What the cursor holds, as a button keeps it -- { kind, id } or { kind,
--- name } -- or nil for anything a button cannot hold. Takes GetCursorInfo().
function ns.ActionFromCursor(kind, info1, info2, info3, info4)
    if kind == "spell" then
        -- The base spell where WoW gives it, so a talent's override follows.
        local id = tonumber(info4) or tonumber(info3)
        return id and { kind = "spell", id = id } or nil
    elseif kind == "mount" then
        -- The mount journal's id (as Blizzard's icon picker reads it).
        local id = tonumber(info1)
        return id and { kind = "mount", id = id } or nil
    elseif kind == "companion" then
        -- Mounts and pets on clients that keep them as companions: kept by
        -- their summon spell, cast as a mount is.
        if not GetCompanionInfo then return nil end
        local _, _, spellID = GetCompanionInfo(info2, info1)
        return spellID and { kind = "mount", spell = spellID } or nil
    elseif kind == "item" or kind == "toy" then
        local id = tonumber(info1)
        if not id then return nil end
        if kind == "toy" or (PlayerHasToy and PlayerHasToy(id)) then return { kind = "toy", id = id } end
        return { kind = "item", id = id }
    elseif kind == "macro" then
        local name = GetMacroInfo(info1)
        return name and { kind = "macro", name = name } or nil
    elseif kind == "equipmentset" then
        local name = info1
        if tonumber(info1) and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
            name = C_EquipmentSet.GetEquipmentSetInfo(tonumber(info1))
        end
        return type(name) == "string" and { kind = "equipmentset", name = name } or nil
    end
    return nil
end

-- A mount's summon spell.
local function mountSpell(action)
    if action.spell then return action.spell end
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return nil end
    local _, spellID = C_MountJournal.GetMountInfoByID(action.id)
    return spellID
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

--- The secure type, attribute and value that cast an action.
function ns.ActionAttributes(action)
    local attribute = action and ATTRIBUTES[action.kind]
    if not attribute then return nil end
    if action.kind == "item" then return "item", attribute, "item:" .. action.id end
    if action.kind == "mount" then
        -- By name: a summon spell is not in the spellbook, and SECURE_ACTIONS
        -- casts a number with CastSpellByID, which does nothing for it; a
        -- name goes through CastSpellByName, as /cast does.
        local spellID = mountSpell(action)
        local name = spellID and spellName(spellID)
        if not name then return nil end
        return "spell", attribute, name
    end
    return action.kind, attribute, action.id or action.name
end

--- This character's actions for a spec (the current one by default),
--- button index -> action.
function ns.Actions(specKey)
    if type(GSE_C) ~= "table" then return {} end
    GSE_C.ActionBarActions = GSE_C.ActionBarActions or {}
    local key = tostring(specKey or ns.GSE.CurrentSpecKey())
    GSE_C.ActionBarActions[key] = GSE_C.ActionBarActions[key] or {}
    return GSE_C.ActionBarActions[key]
end

function ns.ActionOf(button)
    return button and button.gseIndex and ns.Actions()[button.gseIndex] or nil
end

-- ── Reading an action ───────────────────────────────────────────────────────

local function spellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

-- The spell a talent or form has put in place of id, as WoW's bars show it.
local function currentSpell(id)
    if C_Spell and C_Spell.GetOverrideSpell then return C_Spell.GetOverrideSpell(id) or id end
    if FindSpellOverrideByID then return FindSpellOverrideByID(id) or id end
    return id
end

local function itemIcon(id)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
    return GetItemIcon and GetItemIcon(id)
end

-- What a macro casts or uses now: a spell id, or an item id.
local function macroTarget(name)
    local spellID = GetMacroSpell and tonumber((GetMacroSpell(name)))
    if spellID then return spellID, nil end
    if not GetMacroItem then return nil, nil end
    local _, link = GetMacroItem(name)
    local itemID = link and (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant)(link)
    return nil, itemID
end

-- The spell and item behind an action, for its cooldown, count and so on.
local function targetsOf(action)
    if action.kind == "spell" then return currentSpell(action.id), nil end
    if action.kind == "mount" then return mountSpell(action), nil end
    if action.kind == "item" or action.kind == "toy" then return nil, action.id end
    if action.kind == "macro" then return macroTarget(action.name) end
    return nil, nil
end

local function iconOf(action)
    if action.kind == "spell" then return spellTexture(currentSpell(action.id)) end
    if action.kind == "mount" then
        if action.id and C_MountJournal then
            local _, _, icon = C_MountJournal.GetMountInfoByID(action.id)
            if icon then return icon end
        end
        local spellID = mountSpell(action)
        return spellID and spellTexture(spellID)
    end
    if action.kind == "item" then return itemIcon(action.id) end
    if action.kind == "toy" then
        local icon
        if C_ToyBox then _, _, icon = C_ToyBox.GetToyInfo(action.id) end
        return icon or itemIcon(action.id)
    end
    if action.kind == "macro" then
        local _, icon = GetMacroInfo(action.name)
        return icon
    end
    if action.kind == "equipmentset" and C_EquipmentSet then
        local id = C_EquipmentSet.GetEquipmentSetID(action.name)
        if not id then return nil end
        local _, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        return icon
    end
end

--- Put an action back on the cursor, as picking it off a bar does.
function ns.PickupAction(action)
    if action.kind == "spell" then
        if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(action.id) else PickupSpell(action.id) end
    elseif action.kind == "mount" then
        -- The journal picks a mount up by where it is listed, not by its id.
        if action.id and C_MountJournal and C_MountJournal.GetNumDisplayedMounts then
            for index = 1, C_MountJournal.GetNumDisplayedMounts() do
                if C_MountJournal.GetDisplayedMountID(index) == action.id then
                    C_MountJournal.Pickup(index)
                    return
                end
            end
        end
        local spellID = mountSpell(action)
        if spellID then
            if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(spellID) else PickupSpell(spellID) end
        end
    elseif action.kind == "item" then
        if C_Item and C_Item.PickupItem then C_Item.PickupItem(action.id) else PickupItem(action.id) end
    elseif action.kind == "toy" then
        if C_ToyBox and C_ToyBox.PickupToyBoxItem then C_ToyBox.PickupToyBoxItem(action.id) end
    elseif action.kind == "macro" then
        PickupMacro(action.name)
    elseif action.kind == "equipmentset" and C_EquipmentSet then
        local id = C_EquipmentSet.GetEquipmentSetID(action.name)
        if id then C_EquipmentSet.PickupEquipmentSet(id) end
    end
end

local function setup()
local GSE = ns.GSE

local function region(button, key, suffix)
    return button[key] or _G[button:GetName() .. suffix]
end

--- Does this GSE Action Bar button hold an action in the current spec? Its
--- Button Binding then waits (Events.lua, overrideActionButton).
function GSE.ActionBarButtonHasAction(button)
    return button ~= nil and button.gseActionBarButton == true and ns.ActionOf(button) ~= nil
end

--- A spell, item, macro or sequence on the button.
function ns.HasContent(button)
    return button:GetAttribute("gse-button") ~= nil or ns.ActionOf(button) ~= nil
end

-- The button casts its action. A sequence GSE armed on it is GSE's (type
-- "click"), and is never there while the button holds an action.
local function applyAttributes(button)
    if InCombatLockdown() or button:GetAttribute("gse-button") then return end
    for _, attribute in pairs(ATTRIBUTES) do button:SetAttribute(attribute, nil) end
    local actionType, attribute, value = ns.ActionAttributes(ns.ActionOf(button))
    if actionType then button:SetAttribute(attribute, value) end
    button:SetAttribute("type", actionType)
end

-- Cooldown, count and usability, as WoW's bars show them. In combat on
-- Retail these can be secret values, which addon code may pass on to a
-- widget but not test, so each part is on its own and may simply not show.
local function paintState(button, action)
    local spellID, itemID = targetsOf(action)
    local cooldown = region(button, "cooldown", "Cooldown")
    if cooldown then
        pcall(function()
            -- A spell's through GSE's override path: on Retail the start and
            -- duration can be secret, which SetCooldown refuses from an addon,
            -- so the duration object goes to the frame instead.
            if spellID and GSE.SetSpellCooldown then
                return GSE.SetSpellCooldown(cooldown, spellID, region(button, "chargeCooldown", "ChargeCooldown"))
            end
            local start, duration, modRate = 0, 0, nil
            if spellID then
                local info = GSE.GetSpellCooldown(spellID)
                if info then start, duration, modRate = info.startTime, info.duration, info.modRate end
            elseif itemID then
                local getItemCooldown = C_Container and C_Container.GetItemCooldown or GetItemCooldown
                start, duration = getItemCooldown(itemID)
            end
            cooldown:SetCooldown(start or 0, duration or 0, modRate)
        end)
    end
    local count = region(button, "Count", "Count")
    if count then
        count:SetText("")
        pcall(function()
            if itemID and action.kind ~= "toy" then
                local isConsumable = C_Item and C_Item.IsConsumableItem or IsConsumableItem
                if isConsumable(itemID) then
                    local getCount = C_Item and C_Item.GetItemCount or GetItemCount
                    count:SetText(getCount(itemID, false, true))
                end
            elseif spellID then
                local current, max
                if C_Spell and C_Spell.GetSpellCharges then
                    local charges = C_Spell.GetSpellCharges(spellID)
                    if charges then current, max = charges.currentCharges, charges.maxCharges end
                elseif GetSpellCharges then
                    current, max = GetSpellCharges(spellID)
                end
                if max and max > 1 then count:SetText(current) end
            end
        end)
    end
    local icon = region(button, "icon", "Icon")
    if icon then
        icon:SetVertexColor(1, 1, 1)
        pcall(function()
            local usable, noMana = true, false
            if spellID then
                usable, noMana = (C_Spell and C_Spell.IsSpellUsable or IsUsableSpell)(spellID)
            elseif itemID and action.kind == "item" then
                usable, noMana = (C_Item and C_Item.IsUsableItem or IsUsableItem)(itemID)
            end
            if usable then
                icon:SetVertexColor(1, 1, 1)
            elseif noMana then
                icon:SetVertexColor(0.5, 0.5, 1)
            else
                icon:SetVertexColor(0.4, 0.4, 0.4)
            end
        end)
    end
end

-- A spell's proc glow, as WoW's bars show it.
local function setGlow(button, shown)
    pcall(function()
        if ActionButtonSpellAlertManager then
            if shown then
                ActionButtonSpellAlertManager:ShowAlert(button)
            else
                ActionButtonSpellAlertManager:HideAlert(button)
            end
        elseif shown and ActionButton_ShowOverlayGlow then
            ActionButton_ShowOverlayGlow(button)
        elseif not shown and ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(button)
        end
    end)
end

local function isOverlayed(spellID)
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        return C_SpellActivationOverlay.IsSpellOverlayed(spellID)
    end
    return IsSpellOverlayed and IsSpellOverlayed(spellID)
end

-- The button shows its action. With none, a sequence's icon is GSE's
-- (Events.lua paints it); with neither, the button is empty.
-- Blizzard's assisted highlight: the blue ring on the spell its rotation
-- helper would cast next, for players who turned that on. Blizzard lights
-- only buttons with an action slot, so a spell dropped here is given the
-- same frame through its own call, on every repaint; the manager's events
-- and combat's edges repaint (below). Sized to the button, as for an
-- override (Events.lua): Blizzard shrinks the glow for a slotless button.
local function paintAssist(button, spellID)
    local manager = _G.AssistedCombatManager
    if not (manager and manager.SetAssistedHighlightFrameShown and manager.IsAssistedHighlightActive) then return end
    local nextSpell = manager.lastNextCastSpellID
    local ok, shown = pcall(function()
        return spellID ~= nil and nextSpell ~= nil and manager:IsAssistedHighlightActive() and spellID == nextSpell
    end)
    shown = ok and shown or false
    if not shown and not button.gseAssisted then return end
    button.gseAssisted = shown or nil
    pcall(manager.SetAssistedHighlightFrameShown, manager, button, shown)
    local glow = shown and button.AssistedCombatHighlightFrame
    if glow and glow.Flipbook and button.GetWidth then
        local size = (button:GetWidth() or 45) * 66 / 45
        glow.Flipbook:SetSize(size, size)
    end
end

local function paint(button)
    local action = ns.ActionOf(button)
    if not action and button:GetAttribute("gse-button") then return end
    local icon = region(button, "icon", "Icon")
    local name = region(button, "Name", "Name")
    if not action then
        if icon then
            icon:SetTexture(nil)
            icon:Hide()
        end
        local cooldown = region(button, "cooldown", "Cooldown")
        if cooldown then cooldown:Clear() end
        local chargeCooldown = region(button, "chargeCooldown", "ChargeCooldown")
        if chargeCooldown then chargeCooldown:Clear() end
        local count = region(button, "Count", "Count")
        if count then count:SetText("") end
        if name then name:SetText("") end
        setGlow(button, false)
        paintAssist(button, nil)
        return
    end
    if icon then
        local texture = iconOf(action)
        icon:SetTexture(texture)
        icon:SetShown(texture ~= nil)
    end
    if name then name:SetText(action.kind == "macro" and action.name or "") end
    paintState(button, action)
    local spellID = targetsOf(action)
    local ok, glow = pcall(function() return spellID and isOverlayed(spellID) and true or false end)
    setGlow(button, ok and glow)
    paintAssist(button, spellID)
end

--- Every button casts and shows what it holds in the current spec. Out of
--- combat: the attributes are protected.
function ns.ApplyActions()
    if InCombatLockdown() or not ns.buttons then return end
    for _, button in ipairs(ns.buttons) do
        applyAttributes(button)
        paint(button)
    end
end

-- GSE took a sequence off a button (Events.lua, LoadOverrides): it casts and
-- shows its own action again, or is empty.
function GSE.ActionBarButtonCleared(button)
    applyAttributes(button)
    paint(button)
end

-- An action went on or came off: the button's sequence gives way to it, or
-- is back. LoadOverrides clears and re-arms every override, then the bar
-- lays itself out again (ACTIONBAR_OVERRIDES_UPDATED).
local function changed(button)
    if GSE.ReloadOverrides then
        GSE.ReloadOverrides()
    else
        GSE.ActionBarButtonCleared(button)
    end
end

-- A drop and the click that makes it can both arrive; the second finds the
-- action it swapped out on the cursor and must not put that back.
local placedAt = {}

-- The button an action was last picked off, while that action is on the
-- cursor: dropped on a button holding a sequence, the sequence comes back to
-- it, so the two swap.
local pickedFrom, pickedAction

local function sameAction(a, b)
    return a and b and a.kind == b.kind and a.id == b.id and a.name == b.name
end

--- Swap what two GSE Action Bar buttons hold (Events.lua, a sequence dropped
--- on a button with an action).
function GSE.ActionBarSwapActions(a, b)
    local actions = ns.Actions()
    actions[a.gseIndex], actions[b.gseIndex] = actions[b.gseIndex], actions[a.gseIndex]
end

local function place(button)
    if InCombatLockdown() then return end
    local action = ns.ActionFromCursor(GetCursorInfo())
    if not action or placedAt[button] == GetTime() then return end
    placedAt[button] = GetTime()
    local actions = ns.Actions()
    local old = actions[button.gseIndex]
    actions[button.gseIndex] = action
    ClearCursor()
    if old then ns.PickupAction(old) end
    local from, picked = pickedFrom, pickedAction
    pickedFrom, pickedAction = nil, nil
    if not old and button:GetAttribute("gse-button") and from and from ~= button
        and not ns.ActionOf(from) and sameAction(action, picked) and GSE.MoveActionBarOverride then
        GSE.MoveActionBarOverride(button:GetName(), from:GetName())
        return
    end
    changed(button)
end

local function pickup(button)
    if InCombatLockdown() or GetCursorInfo() then return end
    if GetCVarBool("lockActionBars") and not IsModifiedClick("PICKUPACTION") then return end
    local actions = ns.Actions()
    local old = actions[button.gseIndex]
    if not old then
        -- A sequence: GSE's own drag, as from the editor (Events.lua).
        local sequenceId = button:GetAttribute("gse-button")
        if sequenceId and GSE.BeginSequenceDrag then GSE.BeginSequenceDrag(sequenceId, button) end
        return
    end
    actions[button.gseIndex] = nil
    pickedFrom, pickedAction = button, old
    ns.PickupAction(old)
    changed(button)
end

-- Put down anywhere else, or dropped: the action is no longer the one picked
-- off a button here.
local cursorWatch = CreateFrame("Frame")
cursorWatch:RegisterEvent("CURSOR_CHANGED")
cursorWatch:SetScript("OnEvent", function()
    if not GetCursorInfo() then pickedFrom, pickedAction = nil, nil end
end)

local function actionTooltip(button)
    local action = ns.ActionOf(button)
    if not action then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local shown = pcall(function()
        if action.kind == "spell" then
            GameTooltip:SetSpellByID(currentSpell(action.id))
        elseif action.kind == "mount" then
            GameTooltip:SetSpellByID(mountSpell(action))
        elseif action.kind == "toy" and GameTooltip.SetToyByItemID then
            GameTooltip:SetToyByItemID(action.id)
        elseif action.kind == "item" or action.kind == "toy" then
            GameTooltip:SetItemByID(action.id)
        elseif action.kind == "equipmentset" then
            GameTooltip:SetEquipmentSet(action.name)
        else
            local spellID, itemID = macroTarget(action.name)
            if spellID then
                GameTooltip:SetSpellByID(spellID)
            elseif itemID then
                GameTooltip:SetItemByID(itemID)
            else
                GameTooltip:SetText(action.name)
            end
        end
    end)
    if not shown then GameTooltip:SetText(action.name or tostring(action.id)) end
    GameTooltip:Show()
end

-- With something on the cursor a click puts it on the button, and casts
-- nothing: the secure pre-click turns it away (returning false stops the
-- click), and the click's PostClick, or the drop, places it.
local clickGuard = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
local CURSOR_CLICK = [[ if kind then return false end ]]
-- WoW's own bars act on a mouse click's release whatever Cast on Key Down
-- says, telling a click from a key press as addon buttons cannot; so here
-- the button acts on release while the mouse is over it (set and cleared
-- securely, so it holds in combat), and keys get the edge the setting
-- names. Otherwise, with Cast on Key Down, the press that starts a drag
-- fired the sequence.
local MOUSE_OVER = [[ self:SetAttribute("useOnKeyDown", false) ]]
local MOUSE_OFF = [[ self:SetAttribute("useOnKeyDown", nil) ]]

--- Make a new button hold actions (ActionBar.lua, as it creates each).
function ns.SetupActionButton(button)
    -- Wraps first: wrapping sets the script, which drops hooks already on it.
    clickGuard:WrapScript(button, "OnEnter", MOUSE_OVER)
    clickGuard:WrapScript(button, "OnLeave", MOUSE_OFF)
    button:RegisterForDrag("LeftButton")
    button:HookScript("OnReceiveDrag", place)
    button:HookScript("OnDragStart", pickup)
    button:HookScript("PostClick", function(self)
        if GetCursorInfo() then place(self) end
    end)
    button:HookScript("OnEnter", actionTooltip)
    clickGuard:WrapScript(button, "OnClick", CURSOR_CLICK)
end

-- What changes how an action shows. Repainted together on the next frame.
local paintPending = false
local function paintAll()
    paintPending = false
    if not (ns.buttons and GSE.ActionBarActive()) then return end
    for _, button in ipairs(ns.buttons) do
        if ns.ActionOf(button) then paint(button) end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES", "SPELLS_CHANGED",
    "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "UPDATE_MACROS", "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_USABLE", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SETS_CHANGED", "PLAYER_TARGET_CHANGED",
    "UNIT_POWER_FREQUENT", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_ENABLED",
}) do
    -- Not every client has every event.
    pcall(events.RegisterEvent, events, event)
end
-- The assisted highlight's suggestion changing, and combat's edges (the
-- ring animates in combat only): a repaint, a frame after Blizzard's own.
if _G.EventRegistry and _G.EventRegistry.RegisterCallback and _G.AssistedCombatManager then
    local owner = {}
    local function repaint() C_Timer.After(0, paintAll) end
    _G.EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", repaint, owner)
    _G.EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", repaint, owner)
    pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
end

-- A spec change swaps which actions the buttons hold. WoW reports the new
-- spec a little after its events, and the change waits out combat.
local specPending = false
local function reloadForSpec()
    if InCombatLockdown() then
        specPending = true
        return
    end
    specPending = false
    if GSE.ActionBarActive() and GSE.ReloadOverrides then GSE.ReloadOverrides() end
end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_POWER_FREQUENT" and unit ~= "player" then return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
        C_Timer.After(0.5, reloadForSpec)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and specPending then reloadForSpec() end
    if not paintPending then
        paintPending = true
        C_Timer.After(0, paintAll)
    end
end)

-- Out of range, the key goes red, as on WoW's bars.
local RANGE_INTERVAL, sinceRange = 0.2, 0
local function hotkeyColour(hotkey, outOfRange)
    if outOfRange then
        hotkey:SetVertexColor(1, 0.1, 0.1)
    elseif ACTIONBAR_HOTKEY_FONT_COLOR then
        hotkey:SetVertexColor(ACTIONBAR_HOTKEY_FONT_COLOR:GetRGB())
    else
        hotkey:SetVertexColor(0.6, 0.6, 0.6)
    end
end
local function inRange(action)
    local spellID, itemID = targetsOf(action)
    if spellID then
        if C_Spell and C_Spell.IsSpellInRange then return C_Spell.IsSpellInRange(spellID, "target") end
        local name = GetSpellInfo and GetSpellInfo(spellID)
        local result = name and IsSpellInRange and IsSpellInRange(name, "target")
        if result == nil then return nil end
        return result == 1
    elseif itemID and C_Item and C_Item.IsItemInRange then
        return C_Item.IsItemInRange(itemID, "target")
    end
end
events:SetScript("OnUpdate", function(_, elapsed)
    sinceRange = sinceRange + elapsed
    if sinceRange < RANGE_INTERVAL then return end
    sinceRange = 0
    if not (ns.buttons and GSE.ActionBarActive()) then return end
    for _, button in ipairs(ns.buttons) do
        local action = button:IsVisible() and ns.ActionOf(button)
        local hotkey = region(button, "HotKey", "HotKey")
        if action and hotkey then
            pcall(function()
                hotkeyColour(hotkey, inRange(action) == false)
            end)
        end
    end
end)
end
table.insert(ns.deferred, setup)
