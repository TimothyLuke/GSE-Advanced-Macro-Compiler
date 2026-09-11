local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static

-- ---------------------------------------------------------------------------
-- WoW Macro ↔ GSEMacros bidirectional sync
--
-- When GSEOptions.SyncWoWMacros is true:
--   * On login / enable: all WoW macros are imported into GSEMacros.
--   * On UPDATE_MACROS: new or edited WoW macros are reflected in GSEMacros.
--   * On CompanionImportEncoded (MACRO): already handled — GSE.UpdateMacro
--     calls CreateMacro/EditMacro so incoming site changes write to WoW.
--   * When a macro disappears from WoW: its GSEMacros entry is removed (only
--     for macros we added via sync, tracked in syncTrackedNames below).
-- ---------------------------------------------------------------------------

local MAX_GLOBAL_MACROS = GSE.GetMaxAccountMacros() or 120

-- Names of macros this module has added to GSEMacros, per store. Used to
-- detect deletions without accidentally removing Companion-installed macros
-- that may not exist locally on this character.
local syncTrackedNames = { account = {}, character = {} }

--- Capture the current state of all WoW macros on this character.
-- Returns two tables, account and character, each { [name] = { body, icon, slot } }.
-- Two tables, not one keyed by name: an account macro and a character macro
-- can share a name, and one table let the character copy overwrite the other.
local function captureWoWMacros()
    if not GetNumMacros then return {}, {} end
    local account, character = {}, {}
    local numGlobal, numChar = GetNumMacros()
    for i = 1, numGlobal do
        local name, icon, body = GetMacroInfo(i)
        if name and name ~= "" then
            account[name] = { body = body or "", icon = icon, slot = i }
        end
    end
    for i = 1, (numChar or 0) do
        local name, icon, body = GetMacroInfo(MAX_GLOBAL_MACROS + i)
        if name and name ~= "" then
            character[name] = { body = body or "", icon = icon, slot = MAX_GLOBAL_MACROS + i }
        end
    end
    return account, character
end

--- The GSEMacros bucket holding this character's macros. Same key, and the
-- same realm fallback, GSE.ManageMacros reads them back from.
local function characterBucket()
    local char, realm = UnitFullName("player")
    if GSE.isEmpty(realm) then
        realm = string.gsub(GetRealmName(), "%s*", "")
    end
    local key = char .. "-" .. realm
    if type(GSEMacros[key]) ~= "table" then GSEMacros[key] = {} end
    return GSEMacros[key]
end

--- Reflect one set of WoW macros into one GSEMacros store.
--
-- The entry carries `text`. GSE.ManageMacros, GSE.UpdateMacro and the
-- Companion all read the body from `text`; the Companion goes further and
-- treats any entry WITHOUT a string `text` as a character bucket, so an entry
-- holding only `manageMacro` had its own fields read back as macros.
local function syncInto(store, current, tracked)
    for name, data in pairs(current) do
        tracked[name] = true
        local stored = store[name]
        local storedBody = ""
        if type(stored) == "table" then
            storedBody = stored.manageMacro or stored.text or ""
        end
        if storedBody ~= data.body then
            store[name] = {
                name        = name,
                icon        = data.icon,
                value       = data.slot,
                text        = data.body,
                manageMacro = data.body,
            }
        end
    end

    -- Remove: tracked macros that have been deleted from WoW
    for name in pairs(tracked) do
        if not current[name] then
            store[name] = nil
            tracked[name] = nil
        end
    end
end

--- Diff current WoW macros against GSEMacros and apply additions, updates,
-- and removals for macros this module is tracking.
--
-- Character macros go to the character's bucket, never to account level. At
-- account level they uploaded without category "p", and came back down
-- through GSE.ImportMacro into General Macros on every character.
function GSE.SyncWoWMacrosToGSE()
    if not GSEOptions.SyncWoWMacros then return end
    if GSE.isEmpty(GSEMacros) then GSEMacros = {} end

    local account, character = captureWoWMacros()
    syncInto(GSEMacros, account, syncTrackedNames.account)
    syncInto(characterBucket(), character, syncTrackedNames.character)
end

--- Perform a full initial import of all WoW macros (called on enable or login).
function GSE.SyncAllWoWMacros()
    if not GSEOptions.SyncWoWMacros then return end
    -- Reset tracking so we correctly manage any macros from a previous session.
    syncTrackedNames = { account = {}, character = {} }
    GSE.SyncWoWMacrosToGSE()
    local numGlobal, numChar = GetNumMacros()
    GSE.Print(
        "|cff00ccffGSE:|r WoW macro sync enabled — " ..
        (numGlobal + numChar) .. " macro(s) synced to GSEMacros."
    )
end

-- ---------------------------------------------------------------------------
-- Hook ManageMacros so every UPDATE_MACROS event also syncs WoW → GSEMacros.
-- UpdateMacro already unregisters/re-registers UPDATE_MACROS around its own
-- CreateMacro/EditMacro calls, so this hook will not fire for GSE-initiated
-- WoW macro writes — only for external changes from /macro.
-- ---------------------------------------------------------------------------
local origManageMacros = GSE.ManageMacros
function GSE.ManageMacros()
    origManageMacros()
    GSE.SyncWoWMacrosToGSE()
end

-- ---------------------------------------------------------------------------
-- On login: do an initial full sync if the option was persisted as enabled.
-- Delayed slightly to let PLAYER_ENTERING_WORLD setup finish first.
-- ---------------------------------------------------------------------------
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if GSEOptions.SyncWoWMacros then
            C_Timer.After(5, GSE.SyncAllWoWMacros)
        end
    end
end)
end
table.insert(ns.deferred, setup)
