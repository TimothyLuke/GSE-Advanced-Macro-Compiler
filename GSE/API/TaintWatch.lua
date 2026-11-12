local _, GSE = ...

--@debug@
-- ── TaintWatch (development builds only) ────────────────────────────────────
--
-- Finds which addon code taints Blizzard's action bars and settings panel.
-- Tainted, Blizzard's own bar layout is blocked in combat
-- (MainActionBar:SetPointBase()) and the bars vanish until combat ends. It
-- found the KeybindingsOverrides.AddBindingCategories replacement (Statics.lua).
--
--  * Right after Blizzard saves a bar's anchor (SetSnappedToFrame) with taint
--    on it, it records the call stack.
--  * Every 2 seconds it records any field on the watched frames that has
--    newly become tainted.
--  * /gsetaint scan [filter] lists every Blizzard global, and the fields of
--    Blizzard's settings and action bar tables, holding a value written by an
--    addon matching the filter (default "GSE").
--
-- Results print to chat and are kept, for one session, in
-- GSEOptions.DebugTaintWatch -- written on /reload or logout.

local issecurevariable = _G.issecurevariable
local canaccesstable = _G.canaccesstable
local debugstack = _G.debugstack

local PREFIX = "|cffff4040GSE TaintWatch:|r "
local MAX_ENTRIES = 60
local FRAMES = {
    "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "PetActionBar", "StanceBar",
    "EditModeManagerFrame", "ObjectiveTrackerFrame", "ScenarioObjectiveTracker",
}
local SNAPPED = {
    "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight",
}
local SCAN_ROOTS = {
    "Settings", "SettingsPanel", "SettingsInbound", "SettingsCheckboxMixin",
    "SettingsCheckboxControlMixin", "SettingsCheckboxWithButtonControlMixin",
    "SettingsControlMixin", "SettingsListElementMixin", "CallbackRegistryMixin",
    "EventRegistry", "CVarCallbackRegistry", "ActionBarController",
    "ActionBarActionEventsFrame", "ActionBarButtonEventsFrame", "EditModeManagerFrame",
    "KeybindingsOverrides", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
    "PetActionBar", "StanceBar",
}

if not (issecurevariable and debugstack) then return end

local log
local seen = {}

local function record(kind, text, stack)
    if not log or #log.entries >= MAX_ENTRIES then return end
    table.insert(log.entries, {
        time = date("%H:%M:%S"),
        combat = InCombatLockdown() and true or false,
        level = UnitLevel("player"),
        kind = kind,
        text = text,
        stack = stack,
    })
    print(PREFIX .. text)
end

local function checkField(frameName, frame, key, withStack)
    local ok, secure, taint = pcall(issecurevariable, frame, key)
    if not ok or secure then return end
    local id = frameName .. "." .. tostring(key)
    -- A write's stack is wanted every time (up to MAX_ENTRIES); a scan's once.
    if seen[id] == taint and not withStack then return end
    seen[id] = taint
    record(withStack and "write" or "scan", string.format("%s tainted by %s", id, tostring(taint)),
        withStack and debugstack(3, 200, 200) or nil)
end

local function watchFrames()
    for _, frameName in ipairs(FRAMES) do
        local frame = _G[frameName]
        if type(frame) == "table" then
            for key in pairs(frame) do
                if type(key) == "string" and not key:find("^gse") then checkField(frameName, frame, key, false) end
            end
        end
    end
end

-- The scan ─────────────────────────────────────────────────────────────────

local function deepScan(path, tbl, filter, depth, visited, out)
    if visited[tbl] or depth < 0 then return end
    visited[tbl] = true
    -- Some of Blizzard's tables can't be read by addon code at all.
    if canaccesstable and not canaccesstable(tbl) then return end
    pcall(function()
        for key, value in pairs(tbl) do
            local ok, secure, taint = pcall(issecurevariable, tbl, key)
            local id = path .. "." .. tostring(key)
            if ok and not secure and taint and taint:find(filter) then
                out[#out + 1] = id .. "  <- " .. taint
            end
            if type(value) == "table" and not (type(key) == "string" and key:find("^GSE")) then
                deepScan(id, value, filter, depth - 1, visited, out)
            end
        end
    end)
end

local function scan(filter)
    filter = (filter and filter ~= "") and filter or "GSE"
    local out = {}
    for name in pairs(_G) do
        if type(name) == "string" and not name:find("^GSE") then
            local ok, secure, taint = pcall(issecurevariable, name)
            if ok and not secure and taint and taint:find(filter) then
                out[#out + 1] = "_G." .. name .. "  <- " .. taint
            end
        end
    end
    local visited = {}
    for _, name in ipairs(SCAN_ROOTS) do
        if type(_G[name]) == "table" then deepScan(name, _G[name], filter, 3, visited, out) end
    end
    if Settings and Settings.GetSetting then
        for i = 2, 8 do
            local setting = Settings.GetSetting("PROXY_SHOW_ACTIONBAR_" .. i)
            if type(setting) == "table" then
                deepScan("Setting[PROXY_SHOW_ACTIONBAR_" .. i .. "]", setting, filter, 3, visited, out)
            end
        end
    end
    table.sort(out)
    if log then
        log.scans = log.scans or {}
        table.insert(log.scans, { time = date("%H:%M:%S"), filter = filter, found = out })
    end
    print(string.format(PREFIX .. "scan found %d value(s) tainted by %s.", #out, filter))
    for i = 1, math.min(#out, 15) do print("   " .. out[i]) end
    if #out > 15 then print("   ... the rest are kept; /reload to write them.") end
end

-- Start ─────────────────────────────────────────────────────────────────────

local function start()
    if type(GSEOptions) ~= "table" then return end
    GSEOptions.DebugTaintWatch = { entries = {} } -- fresh each session
    log = GSEOptions.DebugTaintWatch
    for _, frameName in ipairs(SNAPPED) do
        local frame = _G[frameName]
        if type(frame) == "table" and type(frame.SetSnappedToFrame) == "function" then
            hooksecurefunc(frame, "SetSnappedToFrame", function(self)
                checkField(frameName, self, "snappedToFrame", true)
            end)
        end
    end
    watchFrames()
    C_Timer.NewTicker(2, watchFrames)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", start)

SLASH_GSETAINT1 = "/gsetaint"
SlashCmdList.GSETAINT = function(msg)
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    if cmd == "scan" then
        scan(arg)
        return
    end
    print(string.format(PREFIX .. "%d entries this session. /gsetaint scan [filter] to search.",
        log and #log.entries or 0))
end
--@end-debug@
