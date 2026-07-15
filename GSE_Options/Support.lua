local _, ns = ...
ns.deferred = ns.deferred or {}

-- In-game "Report a Problem" form. It does NOT upload anything itself — the
-- WoW addon has no network access. It appends the user's description to the
-- GSESupportReports SavedVariable; the GSE Companion app reads that list on its
-- next sync, attaches diagnostics, and uploads it for support. The user tracks
-- status in the Companion's "Your reports".
local function setup()
local GSE = ns.GSE
local L = GSE.L

-- Persisted list of pending/sent support reports. The Companion dedupes by id
-- (its own record of what it has uploaded), so we never clear this here —
-- writing GSE.lua from the Companion would race WoW. We just cap the list.
GSESupportReports = GSESupportReports or {}

local MAX_REPORTS = 5
local reportFrame
local reportApplyGate

-- The report is uploaded by the GSE Companion, which deploys its own in-game
-- addon (GSE_Companion). If that addon isn't loaded, the Companion isn't going
-- to pick the report up — so gate the ability on it. Checked at open/submit
-- time (after all addons have loaded), not at module init.
local function companionLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("GSE_Companion") and true or false
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded("GSE_Companion") and true or false
    end
    return false
end

local function buildReportWindow()
    local UI = GSE.UI
    local frame = UI:Create("Frame")
    frame:SetTitle(L["GSE Support Report"])
    frame:SetLayout("List")
    frame:SetSize(560, 440)

    local note = UI:Create("Label")
    note:SetFullWidth(true)
    note:SetText(L["GSE_SUPPORT_NOTE"])
    frame:AddChild(note)

    local box = UI:Create("MultiLineEditBox")
    box:SetLabel(L["What is not working?"])
    box:SetNumLines(8)
    box:DisableButton(true)
    box:SetFullWidth(true)
    frame:AddChild(box)

    local modsCheck = UI:Create("CheckBox")
    modsCheck:SetType("checkbox")
    modsCheck:SetLabel(L["Include my addon list (helps diagnose addon conflicts)"])
    modsCheck:SetValue(false)
    frame:AddChild(modsCheck)

    local status = UI:Create("Label")
    status:SetFullWidth(true)
    status:SetText("")
    frame:AddChild(status)

    local submit = UI:Create("Button")
    submit:SetText(L["Create Report"])
    submit:SetFullWidth(true)
    submit:SetCallback("OnClick", function()
        if not companionLoaded() then
            status:SetText("|cFFFFBF00" .. L["GSE_SUPPORT_NEEDS_COMPANION"] .. "|r")
            return
        end
        local text = box.GetText and box:GetText() or ""
        text = strtrim(text or "")
        if text == "" then
            status:SetText("|cFFFF4F4F" .. L["Please describe what is not working."] .. "|r")
            return
        end
        local id = tostring(time()) .. "-" .. tostring(math.random(100000, 999999))
        table.insert(GSESupportReports, {
            id = id,
            text = text,
            includeMods = modsCheck:GetValue() and true or false,
            ts = time(),
            char = UnitName("player"),
            realm = GetRealmName(),
            build = select(4, GetBuildInfo()),
            gameMode = GSE.GameMode,
        })
        while #GSESupportReports > MAX_REPORTS do
            table.remove(GSESupportReports, 1)
        end
        box:SetText("")
        modsCheck:SetValue(false)
        status:SetText("|cFF00FF00" .. L["GSE_SUPPORT_CONFIRM"] .. "|r")
    end)
    frame:AddChild(submit)

    -- Reflect the Companion-loaded gate visually; re-evaluated on each open.
    reportApplyGate = function()
        if companionLoaded() then
            submit:SetDisabled(false)
            status:SetText("")
        else
            submit:SetDisabled(true)
            status:SetText("|cFFFFBF00" .. L["GSE_SUPPORT_NEEDS_COMPANION"] .. "|r")
        end
    end
    reportApplyGate()

    return frame
end

-- Lazily build the window on first open so we never depend on GSE.UI being
-- ready at module-init time (it's owned by GSE_GUI).
function GSE.OpenSupportReportWindow()
    if not (GSE.UI and GSE.UI.Create) then
        return
    end
    if not reportFrame then
        reportFrame = buildReportWindow()
    end
    if reportApplyGate then
        reportApplyGate()
    end
    reportFrame:Show()
end

-- Settings entry: a "Support" subcategory with a button that opens the form.
-- Mirrors the subcategory pattern in Options.lua and the button initializer in
-- GSE_QoL/QoL.lua. Guarded for legacy clients without the Settings API.
if Settings and Settings.RegisterVerticalLayoutSubcategory and SettingsPanel
    and CreateSettingsButtonInitializer and Settings.CreateElementInitializer
    and GSE.MenuCategoryID then
    local supportCat = GSE.SupportOptionsCategory or Settings.RegisterVerticalLayoutSubcategory(
        Settings.GetCategory(GSE.MenuCategoryID), L["Support"])
    GSE.SupportOptionsCategory = supportCat
    local layout = SettingsPanel:GetLayout(supportCat)
    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate",
        { ["name"] = L["Report a Problem"], ["tooltip"] = L["GSE_SUPPORT_NOTE"] }))
    layout:AddInitializer(CreateSettingsButtonInitializer(
        L["Report a Problem"],
        L["Open report form"],
        function()
            GSE.OpenSupportReportWindow()
        end,
        "",
        false
    ))
end

end
table.insert(ns.deferred, setup)
