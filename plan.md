# Plan: Variable Event Callback Feature

## Context
Variables in GSE are Lua functions stored in `GSEVariables`, compiled at load time into `GSE.V[name]`. Currently they are only called on demand via `=GSE.V.varname()` in macro sequences. The request is to allow a variable to also be **registered as a callback on one or more WoW events or internal AceEvent messages**, so it fires automatically when those events fire — while remaining callable normally.

The binding is persisted on the variable object and registered/unregistered at load/update time.

---

## Variable Object: New Fields

```lua
variable = {
    ["funct"]        = "function() ... end",  -- existing
    ["comments"]     = "",                     -- existing
    ["Author"]       = "",                     -- existing
    ["LastUpdated"]  = timestamp,              -- existing
    ["eventEnabled"] = false,                  -- NEW: master toggle
    ["eventNames"]   = {},                     -- NEW: array of event/message name strings (multi-select)
}
```

---

## AceEvent Registration Approach

CallbackHandler (the engine behind AceEvent) stores handlers as `events[eventname][self]` where `self` can be a table, string, or thread. Using a **unique string self-key per variable** (`"GSEVar_<name>"`) lets each variable independently register on any event without conflicting with GSE's own handlers or other variables registered on the same event.

```lua
-- Register a WoW event:
GSE:RegisterEvent(eventName, selfKey, handlerFunc)
-- Unregister:
GSE:UnregisterEvent(eventName, selfKey)

-- Register an Ace message:
GSE:RegisterMessage(eventName, selfKey, handlerFunc)
-- Unregister:
GSE:UnregisterMessage(eventName, selfKey)
```

The `Statics.AceMessages` table is used to determine which API to use.

---

## Files to Modify

| File | Change |
|------|--------|
| `GSE/API/Statics.lua` | Add `Statics.VariableEventList` (full WoW+GSE event list) and `Statics.AceMessages` set |
| `GSE/API/Storage.lua` | Add `GSE.RegisterVariableEvents()` / `GSE.UnregisterVariableEvents()`; update `LoadVariables()` and `UpdateVariable()` |
| `GSE_GUI/Editor.lua` | Add toggle CheckBox + multi-select Dropdown in `showVariable()` |
| `GSE/Localization/ModL_enUS.lua` | Add new L[] strings |

---

## 1. Statics.lua — Event Lists (add after line ~541)

```lua
-- Full WoW + GSE event list for variable event callbacks
-- Flat key=value table for AceGUI Dropdown:SetList()
-- Display values prefixed with "[GSE]" for internal messages
Statics.VariableEventList = {
    -- GSE Internal Messages
    ["GSE_SEQUENCE_UPDATED"]          = "[GSE] GSE_SEQUENCE_UPDATED",
    ["GSE_VARIABLE_UPDATED"]          = "[GSE] GSE_VARIABLE_UPDATED",
    ["GSE_COLLECTION_IMPORTED"]       = "[GSE] GSE_COLLECTION_IMPORTED",
    ["GSE_SEQUENCE_ICON_UPDATE"]      = "[GSE] GSE_SEQUENCE_ICON_UPDATE",
    ["GSE_MODS_VISIBLE"]              = "[GSE] GSE_MODS_VISIBLE",
    -- ActionBar
    ["ACTION_RANGE_CHECK_UPDATE"]     = "ACTION_RANGE_CHECK_UPDATE",
    ["ACTIONBAR_PAGE_CHANGED"]        = "ACTIONBAR_PAGE_CHANGED",
    ["ACTIONBAR_SLOT_CHANGED"]        = "ACTIONBAR_SLOT_CHANGED",
    ["ACTIONBAR_UPDATE_COOLDOWN"]     = "ACTIONBAR_UPDATE_COOLDOWN",
    ["ACTIONBAR_UPDATE_STATE"]        = "ACTIONBAR_UPDATE_STATE",
    ["ACTIONBAR_UPDATE_USABLE"]       = "ACTIONBAR_UPDATE_USABLE",
    ["UPDATE_BONUS_ACTIONBAR"]        = "UPDATE_BONUS_ACTIONBAR",
    -- AddOns
    ["ADDON_LOADED"]                  = "ADDON_LOADED",
    -- ChallengeModeInfo
    ["CHALLENGE_MODE_COMPLETED"]      = "CHALLENGE_MODE_COMPLETED",
    ["CHALLENGE_MODE_RESET"]          = "CHALLENGE_MODE_RESET",
    ["CHALLENGE_MODE_START"]          = "CHALLENGE_MODE_START",
    -- ClassTalents
    ["ACTIVE_COMBAT_CONFIG_CHANGED"]  = "ACTIVE_COMBAT_CONFIG_CHANGED",
    ["SELECTED_LOADOUT_CHANGED"]      = "SELECTED_LOADOUT_CHANGED",
    -- CombatLog
    ["COMBAT_LOG_EVENT_UNFILTERED"]   = "COMBAT_LOG_EVENT_UNFILTERED",
    -- CombatText
    ["COMBAT_TEXT_UPDATE"]            = "COMBAT_TEXT_UPDATE",
    -- CurrencySystem
    ["CURRENCY_DISPLAY_UPDATE"]       = "CURRENCY_DISPLAY_UPDATE",
    ["PLAYER_MONEY"]                  = "PLAYER_MONEY",
    -- DeathInfo
    ["PLAYER_ALIVE"]                  = "PLAYER_ALIVE",
    ["PLAYER_DEAD"]                   = "PLAYER_DEAD",
    ["PLAYER_UNGHOST"]                = "PLAYER_UNGHOST",
    ["RESURRECT_REQUEST"]             = "RESURRECT_REQUEST",
    -- EncounterInfo
    ["BOSS_KILL"]                     = "BOSS_KILL",
    ["ENCOUNTER_END"]                 = "ENCOUNTER_END",
    ["ENCOUNTER_START"]               = "ENCOUNTER_START",
    ["RAID_TARGET_UPDATE"]            = "RAID_TARGET_UPDATE",
    ["UPDATE_INSTANCE_INFO"]          = "UPDATE_INSTANCE_INFO",
    -- EquipmentSet
    ["EQUIPMENT_SETS_CHANGED"]        = "EQUIPMENT_SETS_CHANGED",
    ["EQUIPMENT_SWAP_FINISHED"]       = "EQUIPMENT_SWAP_FINISHED",
    -- FriendList
    ["FRIENDLIST_UPDATE"]             = "FRIENDLIST_UPDATE",
    -- Group/Party/Raid
    ["GROUP_ROSTER_UPDATE"]           = "GROUP_ROSTER_UPDATE",
    ["PARTY_LEADER_CHANGED"]          = "PARTY_LEADER_CHANGED",
    ["PARTY_MEMBERS_CHANGED"]         = "PARTY_MEMBERS_CHANGED",
    ["RAID_ROSTER_UPDATE"]            = "RAID_ROSTER_UPDATE",
    -- GuildInfo
    ["GUILD_ROSTER_UPDATE"]           = "GUILD_ROSTER_UPDATE",
    -- Item/Bag
    ["BAG_UPDATE"]                    = "BAG_UPDATE",
    ["BAG_UPDATE_COOLDOWN"]           = "BAG_UPDATE_COOLDOWN",
    ["ITEM_LOCK_CHANGED"]             = "ITEM_LOCK_CHANGED",
    -- Map/Zone
    ["ZONE_CHANGED"]                  = "ZONE_CHANGED",
    ["ZONE_CHANGED_NEW_AREA"]         = "ZONE_CHANGED_NEW_AREA",
    ["PLAYER_DIFFICULTY_CHANGED"]     = "PLAYER_DIFFICULTY_CHANGED",
    -- Player State
    ["PLAYER_ENTERING_WORLD"]         = "PLAYER_ENTERING_WORLD",
    ["PLAYER_LEAVING_WORLD"]          = "PLAYER_LEAVING_WORLD",
    ["PLAYER_LEVEL_UP"]               = "PLAYER_LEVEL_UP",
    ["PLAYER_LOGIN"]                  = "PLAYER_LOGIN",
    ["PLAYER_LOGOUT"]                 = "PLAYER_LOGOUT",
    ["PLAYER_XP_UPDATE"]              = "PLAYER_XP_UPDATE",
    -- Player Combat
    ["PLAYER_REGEN_DISABLED"]         = "PLAYER_REGEN_DISABLED",
    ["PLAYER_REGEN_ENABLED"]          = "PLAYER_REGEN_ENABLED",
    -- Player Faction/PVP
    ["UNIT_FACTION"]                  = "UNIT_FACTION",
    ["PLAYER_PVP_KILLS_CHANGED"]      = "PLAYER_PVP_KILLS_CHANGED",
    ["PLAYER_PVP_RANK_CHANGED"]       = "PLAYER_PVP_RANK_CHANGED",
    -- Player Spec/Talents
    ["ACTIVE_TALENT_GROUP_CHANGED"]   = "ACTIVE_TALENT_GROUP_CHANGED",
    ["CHARACTER_POINTS_CHANGED"]      = "CHARACTER_POINTS_CHANGED",
    ["PLAYER_PVP_TALENT_UPDATE"]      = "PLAYER_PVP_TALENT_UPDATE",
    ["PLAYER_SPECIALIZATION_CHANGED"] = "PLAYER_SPECIALIZATION_CHANGED",
    ["PLAYER_TALENT_UPDATE"]          = "PLAYER_TALENT_UPDATE",
    ["SPEC_INVOLUNTARILY_CHANGED"]    = "SPEC_INVOLUNTARILY_CHANGED",
    ["TRAIT_CONFIG_UPDATED"]          = "TRAIT_CONFIG_UPDATED",
    -- Spells/Cooldowns
    ["SPELL_UPDATE_CHARGES"]          = "SPELL_UPDATE_CHARGES",
    ["SPELL_UPDATE_COOLDOWN"]         = "SPELL_UPDATE_COOLDOWN",
    ["SPELLS_CHANGED"]                = "SPELLS_CHANGED",
    ["UNIT_SPELLCAST_FAILED"]         = "UNIT_SPELLCAST_FAILED",
    ["UNIT_SPELLCAST_INTERRUPTED"]    = "UNIT_SPELLCAST_INTERRUPTED",
    ["UNIT_SPELLCAST_START"]          = "UNIT_SPELLCAST_START",
    ["UNIT_SPELLCAST_STOP"]           = "UNIT_SPELLCAST_STOP",
    ["UNIT_SPELLCAST_SUCCEEDED"]      = "UNIT_SPELLCAST_SUCCEEDED",
    -- Target
    ["PLAYER_TARGET_CHANGED"]         = "PLAYER_TARGET_CHANGED",
    -- Unit
    ["UNIT_AURA"]                     = "UNIT_AURA",
    ["UNIT_HEALTH"]                   = "UNIT_HEALTH",
    ["UNIT_MAXHEALTH"]                = "UNIT_MAXHEALTH",
    ["UNIT_POWER_UPDATE"]             = "UNIT_POWER_UPDATE",
    ["UNIT_DISPLAYPOWER"]             = "UNIT_DISPLAYPOWER",
}

-- Lookup set: keys in this set are Ace messages → use RegisterMessage/UnregisterMessage
Statics.AceMessages = {
    ["GSE_SEQUENCE_UPDATED"]     = true,
    ["GSE_VARIABLE_UPDATED"]     = true,
    ["GSE_COLLECTION_IMPORTED"]  = true,
    ["GSE_SEQUENCE_ICON_UPDATE"] = true,
    ["GSE_MODS_VISIBLE"]         = true,
}
```

---

## 2. Storage.lua — Registration Helpers + Integration

### New functions (add after `LoadVariables`, ~line 134)

```lua
-- Track active variable event registrations keyed by variable name
GSE.VariableEventHandlers = GSE.VariableEventHandlers or {}

function GSE.RegisterVariableEvents(name, eventNames)
    GSE.UnregisterVariableEvents(name)  -- clean up prior bindings first
    if GSE.isEmpty(eventNames) then return end

    local selfKey = "GSEVar_" .. name
    GSE.VariableEventHandlers[name] = { selfKey = selfKey, events = {} }

    for _, eventName in ipairs(eventNames) do
        local isMessage = Statics.AceMessages[eventName] == true
        local handler = function(evt, ...)
            if GSE.V[name] and type(GSE.V[name]) == "function" then
                pcall(GSE.V[name], evt, ...)
            end
        end
        if isMessage then
            GSE:RegisterMessage(eventName, selfKey, handler)
        else
            GSE:RegisterEvent(eventName, selfKey, handler)
        end
        table.insert(GSE.VariableEventHandlers[name].events,
            { name = eventName, isMessage = isMessage })
    end
end

function GSE.UnregisterVariableEvents(name)
    if not GSE.VariableEventHandlers or not GSE.VariableEventHandlers[name] then
        return
    end
    local binding = GSE.VariableEventHandlers[name]
    for _, entry in ipairs(binding.events) do
        if entry.isMessage then
            GSE:UnregisterMessage(entry.name, binding.selfKey)
        else
            GSE:UnregisterEvent(entry.name, binding.selfKey)
        end
    end
    GSE.VariableEventHandlers[name] = nil
end
```

### `LoadVariables()` — add inside the pcall after `GSE.V[k]` is set (~line 122)

```lua
if uncompressedVersion.eventEnabled
    and not GSE.isEmpty(uncompressedVersion.eventNames) then
    GSE.RegisterVariableEvents(k, uncompressedVersion.eventNames)
end
```

### `UpdateVariable()` — add after `BooleanVariables` block (~line 1275)

```lua
if variable.eventEnabled and not GSE.isEmpty(variable.eventNames) then
    GSE.RegisterVariableEvents(name, variable.eventNames)
else
    GSE.UnregisterVariableEvents(name)
end
```

---

## 3. Editor.lua — `showVariable()` UI (~line 3563)

Insert **after** `container:AddChild(commentsEditBox)` and **before** the `valueEditBox` block:

```lua
-- Event Callback Section
local eventCallbackGroup = AceGUI:Create("SimpleGroup")
eventCallbackGroup:SetLayout("Flow")
eventCallbackGroup:SetFullWidth(true)

local eventToggle = AceGUI:Create("CheckBox")
eventToggle:SetLabel(L["Execute on Event"])
eventToggle:SetWidth(180)
local isEventEnabled = variable.eventEnabled or false
eventToggle:SetValue(isEventEnabled)
eventToggle:SetCallback("OnEnter", function()
    GSE.CreateToolTip(L["Execute on Event"],
        L["When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."],
        editframe)
end)
eventToggle:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

local eventDropdown = AceGUI:Create("Dropdown")
eventDropdown:SetLabel(L["Trigger Events"])
eventDropdown:SetRelativeWidth(0.75)
eventDropdown:SetMultiselect(true)
eventDropdown:SetList(Statics.VariableEventList)
eventDropdown:SetDisabled(not isEventEnabled)

-- Pre-populate from saved variable.eventNames
if not GSE.isEmpty(variable.eventNames) then
    for _, evtName in ipairs(variable.eventNames) do
        eventDropdown:SetItemValue(evtName, true)
    end
end

eventToggle:SetCallback("OnValueChanged", function(obj, event, val)
    variable.eventEnabled = val
    eventDropdown:SetDisabled(not val)
    if not val then
        variable.eventNames = {}
        for key, _ in pairs(Statics.VariableEventList) do
            eventDropdown:SetItemValue(key, false)
        end
    end
end)

eventDropdown:SetCallback("OnValueChanged", function(obj, event, key, checked)
    if GSE.isEmpty(variable.eventNames) then variable.eventNames = {} end
    if checked then
        local found = false
        for _, v in ipairs(variable.eventNames) do
            if v == key then found = true; break end
        end
        if not found then table.insert(variable.eventNames, key) end
    else
        for i, v in ipairs(variable.eventNames) do
            if v == key then table.remove(variable.eventNames, i); break end
        end
    end
end)
eventDropdown:SetCallback("OnEnter", function()
    GSE.CreateToolTip(L["Trigger Events"],
        L["The WoW events or GSE messages that will trigger this variable's function. Multiple events can be selected."],
        editframe)
end)
eventDropdown:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)

eventCallbackGroup:AddChild(eventToggle)
eventCallbackGroup:AddChild(eventDropdown)
container:AddChild(eventCallbackGroup)
```

---

## 4. Localization — ModL_enUS.lua

```lua
L["Execute on Event"] = true
L["Trigger Events"] = true
L["When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."] = true
L["The WoW events or GSE messages that will trigger this variable's function. Multiple events can be selected."] = true
```

---

## Implementation Order

1. `GSE/Localization/ModL_enUS.lua` — L[] strings
2. `GSE/API/Statics.lua` — event list + AceMessages set
3. `GSE/API/Storage.lua` — helpers + LoadVariables + UpdateVariable hooks
4. `GSE_GUI/Editor.lua` — UI widgets in showVariable()

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **String self-key** `"GSEVar_<name>"` | Lets each variable independently register on events without clashing with GSE or other variables on the same event |
| **`eventNames` array (multi-select)** | User asked for multiple events per variable |
| **`pcall` in handler** | Buggy variable function won't break other event listeners |
| **`GSE.VariableEventHandlers` tracking table** | Required to cleanly unregister old bindings on update/rename/delete |
| **Unregister-first in `RegisterVariableEvents`** | Prevents duplicate handlers on re-save |
| **`Statics.AceMessages` lookup** | Cleanly routes to RegisterMessage vs RegisterEvent |
| **Full event list in Statics** | AceEvent registry is a closure — not safely queryable; wiki-sourced list is the authoritative approach |
| **Multi-select pre-population via `SetItemValue`** | Restores checked state when reopening the variable editor |

---

## Verification

1. Create variable with `function(evt, ...) print("fired:", evt, ...) end`
2. Enable toggle, select `PLAYER_TARGET_CHANGED` + `UNIT_AURA`, save
3. Reopen variable → both events still checked
4. Change target in-game → prints to chat; trigger an aura → also prints
5. Disable toggle, save → neither event fires any more
6. Select `GSE_SEQUENCE_UPDATED`, save a sequence → variable fires
7. `/reload` → bindings restored from saved data
8. Delete variable → no orphaned handler errors
9. Rename variable, re-save → old `GSEVar_oldname` cleaned up, new `GSEVar_newname` registered
