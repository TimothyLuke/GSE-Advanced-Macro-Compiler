local GSE = GSE
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

local MAX_GLOBAL_MACROS = MAX_ACCOUNT_MACROS or 120

-- Names of macros this module has added to GSEMacros. Used to detect deletions
-- without accidentally removing Companion-installed macros that may not exist
-- locally on this character.
local syncTrackedNames = {}

--- Capture the current state of all WoW macros on this character.
-- Returns { [name] = { body, icon, character } }
local function captureWoWMacros()
    if not GetNumMacros then return {} end
    local t = {}
    local numGlobal, numChar = GetNumMacros()
    for i = 1, numGlobal do
        local name, icon, body = GetMacroInfo(i)
        if name and name ~= "" then
            t[name] = { body = body or "", icon = icon, character = false }
        end
    end
    for i = 1, (numChar or 0) do
        local name, icon, body = GetMacroInfo(MAX_GLOBAL_MACROS + i)
        if name and name ~= "" then
            t[name] = { body = body or "", icon = icon, character = true }
        end
    end
    return t
end

--- Diff current WoW macros against GSEMacros and apply additions, updates,
-- and removals for macros this module is tracking.
function GSE.SyncWoWMacrosToGSE()
    if not GSEOptions.SyncWoWMacros then return end
    if GSE.isEmpty(GSEMacros) then GSEMacros = {} end

    local current = captureWoWMacros()

    -- Add / update: any WoW macro whose body differs from what we have stored
    for name, data in pairs(current) do
        syncTrackedNames[name] = true
        local stored = GSEMacros[name]
        local storedBody = ""
        if type(stored) == "table" then
            storedBody = stored.manageMacro or stored.text or ""
        end
        if storedBody ~= data.body then
            GSEMacros[name] = {
                name        = name,
                icon        = data.icon,
                value       = GetMacroIndexByName(name),
                manageMacro = data.body,
            }
        end
    end

    -- Remove: tracked macros that have been deleted from WoW
    for name in pairs(syncTrackedNames) do
        if not current[name] then
            GSEMacros[name] = nil
            syncTrackedNames[name] = nil
        end
    end
end

--- Perform a full initial import of all WoW macros (called on enable or login).
function GSE.SyncAllWoWMacros()
    if not GSEOptions.SyncWoWMacros then return end
    -- Reset tracking so we correctly manage any macros from a previous session.
    syncTrackedNames = {}
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
