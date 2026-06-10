local GNOME, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local Statics = GSE.Static

-- =========================================================================
-- SECTION 1 -- Helper / utility functions
--
-- Small reusable text formatters, safe-cast helpers, and "open the
-- registered options panel" entry point. Everything below this header
-- through ~L80 is pure utility shared across the rest of the file.
-- =========================================================================

local function SafeOptionText(value, fallback)
    if type(value) == "string" then return value end
    if type(value) == "number" then return tostring(value) end
    if type(fallback) == "string" then return fallback end
    if type(fallback) == "number" then return tostring(fallback) end
    return ""
end

local function FormatSequenceNames(names)
    local returnstring = ""
    for _, v in ipairs(names) do
        returnstring = returnstring .. " - " .. v .. ",\n"
    end
    returnstring = returnstring:sub(1, -3)
    return returnstring
end

local addonName = "|cFFFFFFFFGS|r|cFF00FFFFE|r"

local registered = false
local HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B = 1, 0.82, 0
local MIN_EDITOR_HEIGHT = 500
local MAX_EDITOR_HEIGHT = 2000
local MIN_EDITOR_WIDTH = 800
local MAX_EDITOR_WIDTH = 3000
local EDITOR_SCREEN_MARGIN = 20
local MIN_TREE_WIDTH = 165
local MAX_TREE_WIDTH = 300
local MIN_DEBUGGER_HEIGHT = 500
local MAX_DEBUGGER_HEIGHT = 2000
local MIN_DEBUGGER_WIDTH = 700
local MAX_DEBUGGER_WIDTH = 3000
local settingsButtonFixInstalled = false
local settingsLabelButtonFixInstalled = false
local settingsModernColorRowFixInstalled = false
local settingsExclusiveRowFixInstalled = false
local exclusiveOptionRows = {}
local ABOUT_LOGO_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\GSE_Menu_Logo.png"
local ABOUT_LOGO_WIDTH = 120
local ABOUT_LOGO_HEIGHT = 120
local SETTINGS_BUTTON_WIDTH = 200
local SETTINGS_BUTTON_HEIGHT = 22
local MODERN_COLOR_SWATCH_SIZE = 16
local MODERN_COLOR_POPUP_WIDTH = 360
local MODERN_COLOR_POPUP_HEIGHT = 150
local MIN_GSE_UI_SCALE = 0.50
local MAX_GSE_UI_SCALE = 1.50
-- GSE Window Scale uses its own tighter range, independent of the Menu Scale above.
local MIN_GSE_WINDOW_SCALE = 0.50
local MAX_GSE_WINDOW_SCALE = 1.50
local modernColorPopup
local RESOURCES_BUTTON_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\classbar.png"
local RESOURCES_BUTTON_TEXTURE_WIDTH = 680
local RESOURCES_BUTTON_TEXTURE_HEIGHT = 53
local RESOURCES_BUTTON_TEXTURE_ALPHA = 0.25
local RESOURCES_BUTTON_TEXT_SCALE = 1.5
local RESOURCES_BUTTON_TEXT_HOVER_SCALE = RESOURCES_BUTTON_TEXT_SCALE * 1.25
local RESOURCES_BUTTON_TEXT_HORIZONTAL_PADDING = 48
local RESOURCES_BUTTON_TEXT_VERTICAL_PADDING = 10
local RESOURCES_BUTTON_MIN_WIDTH = 190
local RESOURCES_BUTTON_TEXT = addonName .. "|cFFFFFFFF:|r |cFFFFD100Resources|r"
local RESOURCES_BUTTON_TEXT_HOVER = RESOURCES_BUTTON_TEXT

local function BringSettingsPanelForward()
    if not SettingsPanel then return end

    if ShowUIPanel then pcall(ShowUIPanel, SettingsPanel) end
    if SettingsPanel.Open then pcall(SettingsPanel.Open, SettingsPanel) end
    if SettingsPanel.Show and (not SettingsPanel.IsShown or not SettingsPanel:IsShown()) then
        pcall(SettingsPanel.Show, SettingsPanel)
    end
    if SettingsPanel.SetFrameStrata then SettingsPanel:SetFrameStrata("FULLSCREEN_DIALOG") end
    if SettingsPanel.Raise then SettingsPanel:Raise() end
end

function GSE.OpenRegisteredOptionsPanel(editor)
    if GSE.GUI then GSE.GUI.optionsEditor = editor end

    -- Combat-lockdown guard. Settings.OpenToCategory (and the legacy
    -- InterfaceOptionsFrame_OpenToCategory) call into Blizzard's protected
    -- OpenSettingsPanel() function. Under combat lockdown that protected
    -- call fires ADDON_ACTION_BLOCKED with a chunky three-line error in
    -- BugSack/BugGrabber, *even though* we wrap the call in pcall — the
    -- lockdown enforcement happens at the C level *before* the Lua error
    -- propagates to our pcall, so pcall never gets to swallow it. The
    -- only safe fix is to refuse the call ourselves before touching any
    -- protected API.
    --
    -- This guard covers every caller: the toolbar Options icon
    -- (GSE_GUI/Menu.lua), the debug window's Options button
    -- (GSE_GUI/DebugWindow.lua), the tree pane's editOptions button
    -- (GSE_GUI/Editor_Tree.lua), the slash-command Options handler
    -- (GSE_Utils/Utils.lua), and the event-driven open in
    -- GSE/API/Events.lua. The toolbar icon ALSO greys itself out during
    -- combat so the user sees it's disabled — but this guard is the
    -- belt-and-suspenders backstop for everything else.
    if InCombatLockdown and InCombatLockdown() then
        GSE.Print(L["Cannot Open Options during Combat"]
            or "Cannot Open Options during Combat")
        return false
    end

    if not GSE.MenuCategoryID then
        GSE.Print(L["Options Not Enabled"])
        return false
    end

    if GSE.LegacyOptionsPanel and InterfaceOptionsFrame_OpenToCategory then
        pcall(InterfaceOptionsFrame_OpenToCategory, GSE.LegacyOptionsPanel)
        pcall(InterfaceOptionsFrame_OpenToCategory, GSE.LegacyOptionsPanel)
        BringSettingsPanelForward()
        return true
    end

    if Settings and Settings.OpenToCategory then
        local opened = pcall(Settings.OpenToCategory, GSE.MenuCategoryID)
        BringSettingsPanelForward()
        if SettingsPanel and SettingsPanel.OpenToCategory then
            pcall(SettingsPanel.OpenToCategory, SettingsPanel, GSE.MenuCategoryID)
        end
        return opened
    end

    return false
end

GSE.OpenOptionsPanel = GSE.OpenRegisteredOptionsPanel

local MODERN_CLASS_COLOR_FALLBACKS = {
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    DEMONHUNTER = {0.64, 0.19, 0.79},
    DRUID = {1.00, 0.49, 0.04},
    EVOKER = {0.20, 0.58, 0.50},
    HUNTER = {0.67, 0.83, 0.45},
    MAGE = {0.25, 0.78, 0.92},
    MONK = {0.00, 1.00, 0.59},
    PALADIN = {0.96, 0.55, 0.73},
    PRIEST = {1.00, 1.00, 1.00},
    ROGUE = {1.00, 0.96, 0.41},
    SHAMAN = {0.00, 0.44, 0.87},
    WARLOCK = {0.53, 0.53, 0.93},
    WARRIOR = {0.78, 0.61, 0.43}
}
local MODERN_CLASS_FILE_BY_ID = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [10] = "MONK",
    [11] = "DRUID",
    [12] = "DEMONHUNTER",
    [13] = "EVOKER"
}

-- =========================================================================
-- SECTION 2 -- Blizzard Settings panel patching / shim layer
--
-- The Blizzard Settings panel has a few rough edges that GSE works
-- around: a missing "Open this panel from chat" button on Classic /
-- BoA / MoP (InstallSettingsButtonFix), the lack of native exclusive
-- (radio-style) checkbox groups (RegisterExclusiveOptionRow /
-- InstallSettingsExclusiveRowFix), and the absence of a label+button
-- row template (InstallSettingsLabelButtonFix). All three are
-- installed once at GSE init and provide the building blocks for the
-- option panels further down.
-- =========================================================================

local function InstallSettingsButtonFix()
    if settingsButtonFixInstalled or not SettingsButtonControlMixin or not SettingsButtonControlMixin.Init then return end

    local originalInit = SettingsButtonControlMixin.Init
    SettingsButtonControlMixin.Init = function(self, initializer)
        local data = initializer and initializer.GetData and initializer:GetData()
        if data and data.gseSettingsButton and self.Button and self.Button.ClearAllPoints then
            self.Button:ClearAllPoints()
        end

        local result = originalInit(self, initializer)

        if data and data.gseSettingsButton and self.Button then
            self.Button:ClearAllPoints()
            if data.name == "" then
                self.Button:SetPoint("LEFT", self.Text, "LEFT", 0, 0)
                if self.Tooltip then self.Tooltip:Hide() end
            else
                self.Button:SetPoint("LEFT", self, "CENTER", -40, 0)
                if self.Tooltip then self.Tooltip:Show() end
            end
            self.Button:SetWidth(SETTINGS_BUTTON_WIDTH)
            self.Button:SetHeight(SETTINGS_BUTTON_HEIGHT)
            self.Button:SetText(data.buttonText)
            self.Button:SetScript("OnClick", function(button, ...)
                if data.buttonClick then
                    data.buttonClick(button, ...)
                end
            end)
            self.Button:Enable()
            self.Button:Show()
        end

        return result
    end
    settingsButtonFixInstalled = true
end

local function RunAfterOptionsUpdate(func)
    C_Timer.After(0, func)
end

local function SkinGSESettingsButton(button)
    if not button or button.GSEElvUISkinned then return end
    -- Respect the user's skin choice: in Native mode leave this button on
    -- Blizzard's default look instead of force-applying ElvUI's button skin.
    if GSE.ShouldHonorExternalSkin and not GSE.ShouldHonorExternalSkin() then return end
    local E = ElvUI and ElvUI[1]
    local S = E and E.GetModule and E:GetModule("Skins", true)
    if S and S.HandleButton and pcall(S.HandleButton, S, button) then
        button.GSEElvUISkinned = true
    end
end

local function GetOptionRowCheckbox(row)
    return row and (row.Checkbox or row.CheckBox or row.CheckButton or row.Check)
end

local function RefreshExclusiveOptionRow(row)
    local data = row and row.GSEExclusiveOptionData
    local checkbox = GetOptionRowCheckbox(row)
    if not (data and checkbox and checkbox.SetChecked and data.gseExclusiveGetValue) then return end
    checkbox:SetChecked(data.gseExclusiveGetValue() == true)
end

local function RefreshExclusiveOptionRows(group)
    local rows = group and exclusiveOptionRows[group]
    if not rows then return end

    for row in pairs(rows) do
        RefreshExclusiveOptionRow(row)
        if row.GSEModernRefreshColorRow then row:GSEModernRefreshColorRow() end
    end
end

local function RegisterExclusiveOptionRow(row, data)
    if not row then return end

    if row.GSEExclusiveOptionGroup and exclusiveOptionRows[row.GSEExclusiveOptionGroup] then
        exclusiveOptionRows[row.GSEExclusiveOptionGroup][row] = nil
    end
    row.GSEExclusiveOptionGroup = nil
    row.GSEExclusiveOptionData = nil

    if not (data and data.gseExclusiveOptionGroup) then return end

    local group = data.gseExclusiveOptionGroup
    exclusiveOptionRows[group] = exclusiveOptionRows[group] or {}
    exclusiveOptionRows[group][row] = true
    row.GSEExclusiveOptionGroup = group
    row.GSEExclusiveOptionData = data
    RefreshExclusiveOptionRow(row)

    local checkbox = GetOptionRowCheckbox(row)
    if checkbox and checkbox.HookScript and not checkbox.GSEExclusiveOptionHooked then
        checkbox:HookScript("OnClick", function()
            local owner = checkbox:GetParent()
            local optionGroup = owner and owner.GSEExclusiveOptionGroup
            RefreshExclusiveOptionRows(optionGroup)
            RunAfterOptionsUpdate(function() RefreshExclusiveOptionRows(optionGroup) end)
        end)
        checkbox.GSEExclusiveOptionHooked = true
    end
end

local function InstallSettingsExclusiveRowFix()
    if settingsExclusiveRowFixInstalled or not SettingsCheckboxControlMixin or not SettingsCheckboxControlMixin.Init then return end

    local originalInit = SettingsCheckboxControlMixin.Init
    SettingsCheckboxControlMixin.Init = function(self, initializer)
        local data = initializer and initializer.GetData and initializer:GetData()
        if data then
            data.name = SafeOptionText(data.name)
            data.tooltip = SafeOptionText(data.tooltip)
        end
        local result = originalInit(self, initializer)
        RegisterExclusiveOptionRow(self, data)
        return result
    end

    settingsExclusiveRowFixInstalled = true
end

local function MarkExclusiveCheckboxInitializer(initializer, group, getValue)
    InstallSettingsExclusiveRowFix()
    local data = initializer and initializer.GetData and initializer:GetData()
    if data then
        data.gseExclusiveOptionGroup = group
        data.gseExclusiveGetValue = getValue
    end
    return initializer
end

-- -------------------------------------------------------------------------
-- 2.1 - Label + button row template
--
-- The Blizzard Settings panel doesn't ship a "label on the left, action
-- button on the right" row template. The functions below install one
-- under the name SettingsListLabelAndButtonControlTemplate (mimicking
-- Blizzard's own template-naming convention so it slots in cleanly).
-- Used for the various "Open the X window" rows -- Sequence Editor,
-- Debug Window, GSE Toolbar -- without having to compose a checkbox +
-- button hack each time.
-- -------------------------------------------------------------------------

local function InstallSettingsLabelButtonFix()
    if settingsLabelButtonFixInstalled or not SettingsCheckboxWithButtonControlMixin or
        not SettingsCheckboxWithButtonControlMixin.Init then return end

    local originalInit = SettingsCheckboxWithButtonControlMixin.Init
    local function HideCheckboxFrame(row, frame)
        if not frame or frame == row or frame == row.GSELabelButton then return end
        if frame.Hide then frame:Hide() end
        if frame.SetShown then frame:SetShown(false) end
        if frame.EnableMouse then frame:EnableMouse(false) end
        if frame.SetAlpha then frame:SetAlpha(0) end
        if frame.Text and frame.Text.Hide then frame.Text:Hide() end
    end

    SettingsCheckboxWithButtonControlMixin.Init = function(self, initializer)
        local data = initializer and initializer.GetData and initializer:GetData()
        local result = originalInit(self, initializer)

        if not (data and data.gseLabelButton) then
            if self.GSELabelText then self.GSELabelText:Hide() end
            if self.GSELabelButton then
                self.GSELabelButton:Hide()
                self.GSELabelButton:EnableMouse(false)
            end
            if self.Button then
                if self.Button.SetAlpha then self.Button:SetAlpha(1) end
                if self.Button.EnableMouse then self.Button:EnableMouse(true) end
                if self.Button.Text and self.Button.Text.Show then self.Button.Text:Show() end
                if self.Button.Show then self.Button:Show() end
            end
            local checkbox = self.Checkbox or self.CheckBox or self.CheckButton or self.Check
            if checkbox then
                if checkbox.Show then checkbox:Show() end
                if checkbox.SetShown then checkbox:SetShown(true) end
                if checkbox.EnableMouse then checkbox:EnableMouse(true) end
                if checkbox.SetAlpha then checkbox:SetAlpha(1) end
                if checkbox.Text and checkbox.Text.Show then checkbox.Text:Show() end
            end
            if self.Text then
                self.Text:SetText(SafeOptionText(data and data.name))
                self.Text:Show()
            end
            return result
        end

        HideCheckboxFrame(self, self.Checkbox or self.CheckBox or self.CheckButton or self.Check)
        HideCheckboxFrame(self, self.Button)
        for _, child in ipairs({self:GetChildren()}) do
            if child ~= self.GSELabelButton and child.GetObjectType then
                local objectType = child:GetObjectType()
                if child == self.Button or objectType == "CheckButton" then HideCheckboxFrame(self, child) end
            end
        end
        if self.Text then
            self.Text:Hide()
        end
        if self.Checkbox and self.Checkbox.Text then
            self.Checkbox.Text:Hide()
        end

        if not self.GSELabelText then
            self.GSELabelText = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            self.GSELabelText:SetJustifyH("LEFT")
            self.GSELabelText:SetJustifyV("MIDDLE")
        end
        self.GSELabelText:ClearAllPoints()
        self.GSELabelText:SetPoint("LEFT", self, "LEFT", 35, 0)
        self.GSELabelText:SetText(data.gseLabelText or data.name or "")
        self.GSELabelText:Show()

        if not self.GSELabelButton then
            self.GSELabelButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        end
        self.GSELabelButton:ClearAllPoints()
        self.GSELabelButton:SetPoint("LEFT", self, "CENTER", -40, 0)
        self.GSELabelButton:SetWidth(SETTINGS_BUTTON_WIDTH)
        self.GSELabelButton:SetHeight(SETTINGS_BUTTON_HEIGHT)
        self.GSELabelText:SetPoint("RIGHT", self.GSELabelButton, "LEFT", -20, 0)

        local buttonText = data.gseButtonText or data.buttonText or ""
        self.GSELabelButton:SetText(buttonText)
        if self.GSELabelButton.Text then
            self.GSELabelButton.Text:SetText(buttonText)
            self.GSELabelButton.Text:Show()
        end
        self.GSELabelButton:SetScript("OnClick", function(button, ...)
            if data.gseButtonClick then
                data.gseButtonClick(button, ...)
            end
        end)
        self.GSELabelButton:SetScript("OnEnter", function(button)
            local tooltip = SafeOptionText(data.tooltip)
            if tooltip ~= "" and GameTooltip then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(data.gseLabelText or data.name or "", HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B)
                GameTooltip:AddLine(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        self.GSELabelButton:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        self.GSELabelButton:Enable()
        self.GSELabelButton:EnableMouse(true)
        self.GSELabelButton:Show()
        SkinGSESettingsButton(self.GSELabelButton)
        RunAfterOptionsUpdate(function() SkinGSESettingsButton(self.GSELabelButton) end)

        return result
    end
    settingsLabelButtonFixInstalled = true
end

local function CreateGSESettingsLabelButtonInitializer(category, settingID, label, buttonText, buttonClick, tooltip)
    InstallSettingsLabelButtonFix()

    local function getValue()
        return false
    end
    local function setValue()
    end

    local setting = Settings.RegisterProxySetting(category, settingID, Settings.VarType.Boolean, label, false, getValue, setValue)
    local initializer
    if GSE.GameMode > 10 then
        initializer = CreateSettingsCheckboxWithButtonInitializer(setting, buttonText, buttonClick, nil, false, tooltip)
    else
        initializer = CreateSettingsCheckboxWithButtonInitializer(setting, buttonText, buttonClick, false, tooltip)
    end

    local data = initializer and initializer.GetData and initializer:GetData()
    if data then
        data.gseLabelButton = true
        data.gseLabelText = label
        data.gseButtonText = buttonText
        data.gseButtonClick = buttonClick
    end
    if initializer and initializer.AddSearchTags then
        initializer:AddSearchTags(label)
    end
    return initializer
end

local function SetControlEnabled(control, enabled)
    if not control then return end
    if enabled then
        if control.Enable then control:Enable() end
    else
        if control.Disable then control:Disable() end
    end
    if control.SetAlpha then
        control:SetAlpha(enabled and 1 or 0.45)
    end
end

-- =========================================================================
-- SECTION 3 -- Modern accent-color picker subsystem
--
-- The "Modern Skin" feature lets the user pick a custom accent colour
-- (one of class colour / preset / custom RGB) that GSE then applies
-- across its frames. This subsystem implements the colour-picker popup
-- itself (separate from Blizzard's), the class-colour resolver, the
-- text-to-RGB parser for the manual hex input, and the swatch row
-- rendering used in the Options panel. The hardest bits live in
-- GetModernColorPopup (constructs and caches the popup frame on first
-- use) and FindColorPickerOkayButtonRecursive (Blizzard's button is
-- named differently across game flavours so we walk the frame tree).
-- =========================================================================

local function GetModernCustomColor()
    local color = GSE.GetModernCustomColor and GSE.GetModernCustomColor(1) or {0.00, 0.44, 0.87, 1}
    return color[1] or 0, color[2] or 0.44, color[3] or 0.87
end

local function SetModernCustomColor(r, g, b)
    if GSE.SetModernCustomColor then
        GSE.SetModernCustomColor(r, g, b)
    else
        GSEOptions.ModernCustomColor = {r = r, g = g, b = b}
    end
end

local function ClampColorComponent(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback or 1 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function NormalizeModernClassFile(classFile)
    if type(classFile) == "string" then
        return classFile:upper():gsub("%s+", "")
    end
    return nil
end

local function GetCurrentPlayerClassFile()
    local classID = GSE.GetCurrentClassID and GSE.GetCurrentClassID()
    if type(classID) == "number" and MODERN_CLASS_FILE_BY_ID[classID] then
        return MODERN_CLASS_FILE_BY_ID[classID]
    end

    if classID and GetClassInfo then
        local className, classFile = GetClassInfo(classID)
        classFile = NormalizeModernClassFile(classFile or className)
        if classFile and MODERN_CLASS_COLOR_FALLBACKS[classFile] then return classFile end
    end

    if UnitClass then
        local localizedClass, classFile = UnitClass("player")
        classFile = NormalizeModernClassFile(classFile or localizedClass)
        if classFile and MODERN_CLASS_COLOR_FALLBACKS[classFile] then return classFile end
    end
end

local function GetCurrentPlayerClassColor()
    local classFile = GetCurrentPlayerClassFile()
    if not classFile then return nil end

    local color = MODERN_CLASS_COLOR_FALLBACKS[classFile] or
        (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or
        (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
    if not color then return nil end

    return ClampColorComponent(color.r or color[1], 1),
        ClampColorComponent(color.g or color[2], 1),
        ClampColorComponent(color.b or color[3], 1)
end

local function ColorComponentToByte(value)
    return math.floor((ClampColorComponent(value, 0) * 255) + 0.5)
end

local function ColorToHex(r, g, b)
    return string.format("#%02X%02X%02X", ColorComponentToByte(r), ColorComponentToByte(g), ColorComponentToByte(b))
end

local function ParseModernColorText(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local hex = text:gsub("^#", ""):gsub("^0[xX]", "")
    if hex:match("^[%x][%x][%x]$") then
        hex = hex:sub(1, 1) .. hex:sub(1, 1) .. hex:sub(2, 2) .. hex:sub(2, 2) .. hex:sub(3, 3) .. hex:sub(3, 3)
    end
    if hex:match("^[%x][%x][%x][%x][%x][%x]$") then
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    end

    local r, g, b = text:match("^([%d%.]+)%s*[, ]%s*([%d%.]+)%s*[, ]%s*([%d%.]+)$")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if r and g and b then
        if r > 1 or g > 1 or b > 1 then
            r, g, b = r / 255, g / 255, b / 255
        end
        return ClampColorComponent(r, 0), ClampColorComponent(g, 0), ClampColorComponent(b, 0)
    end

    return nil
end

local function UpdateModernColorSwatch(swatch)
    if not swatch then return end
    local r, g, b = GetModernCustomColor()
    if swatch.SetBackdropColor then
        swatch:SetBackdropColor(r, g, b, 1)
    end
end

local function SetModernPopupPendingColor(popup, r, g, b, updateText)
    if not popup then return end
    popup.pendingR = ClampColorComponent(r, 0)
    popup.pendingG = ClampColorComponent(g, 0.44)
    popup.pendingB = ClampColorComponent(b, 0.87)
    if popup.swatch and popup.swatch.SetBackdropColor then
        popup.swatch:SetBackdropColor(popup.pendingR, popup.pendingG, popup.pendingB, 1)
    end
    if popup.editBox and updateText then
        popup.suppressColorTextUpdate = true
        popup.editBox:SetText(ColorToHex(popup.pendingR, popup.pendingG, popup.pendingB))
        popup.editBox:SetTextColor(1, 1, 1, 1)
        popup.suppressColorTextUpdate = false
    end
end

local function UpdateModernPopupFromText(popup)
    if not popup or popup.suppressColorTextUpdate or not popup.editBox then return end
    local r, g, b = ParseModernColorText(popup.editBox:GetText())
    if r then
        SetModernPopupPendingColor(popup, r, g, b, false)
        popup.editBox:SetTextColor(1, 1, 1, 1)
    else
        popup.editBox:SetTextColor(1, 0.25, 0.25, 1)
    end
end

local function RefreshModernColorOwnerRow(popup)
    local row = popup and popup.ownerRow
    if row and row.GSEModernRefreshColorRow then
        row:GSEModernRefreshColorRow()
    end
end

local function ApplyModernColorPopup(popup)
    if not popup then return false end
    local r, g, b = popup.pendingR, popup.pendingG, popup.pendingB
    if popup.editBox then
        local typedR, typedG, typedB = ParseModernColorText(popup.editBox:GetText())
        if typedR then
            r, g, b = typedR, typedG, typedB
        elseif not r then
            popup.editBox:SetTextColor(1, 0.25, 0.25, 1)
            return false
        end
    end

    SetModernCustomColor(r, g, b)
    GSEOptions.UseModernCustomColor = true
    GSEOptions.UseModernClassColors = false
    RefreshModernColorOwnerRow(popup)
    RefreshExclusiveOptionRows("modernColor")
    popup:Hide()
    return true
end

-- -------------------------------------------------------------------------
-- 3.1 - Color picker popup management
--
-- The functions below construct (lazily, on first open), refresh, and
-- close the modal popup that lets the user enter an RGB / hex colour
-- by hand. The popup itself is built once and re-shown thereafter,
-- with pending colour state held on the popup frame between opens.
-- OpenBlizzardColorPickerForPopup wires the popup's "Pick" button into
-- the underlying Blizzard ColorPickerFrame for the visual picker UI.
-- -------------------------------------------------------------------------

local HookModernColorPickerClassButton, CreateModernColorSwatch  -- forward-declared (defined later; callers above the defs would otherwise bind nil)

local function OpenBlizzardColorPickerForPopup(popup)
    if not (popup and ColorPickerFrame) then return end
    local previousR = popup.pendingR or select(1, GetModernCustomColor())
    local previousG = popup.pendingG or select(2, GetModernCustomColor())
    local previousB = popup.pendingB or select(3, GetModernCustomColor())

    local function applyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        SetModernPopupPendingColor(popup, r, g, b, true)
    end

    local function applyClassColor()
        local r, g, b = GetCurrentPlayerClassColor()
        if not r then return end
        if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(r, g, b) end
        SetModernPopupPendingColor(popup, r, g, b, true)
    end

    local function cancelColor(previousValues)
        local previous = type(previousValues) == "table" and previousValues or nil
        SetModernPopupPendingColor(
            popup,
            previous and (previous.r or previous[1]) or previousR,
            previous and (previous.g or previous[2]) or previousG,
            previous and (previous.b or previous[3]) or previousB,
            true
        )
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previousR,
            g = previousG,
            b = previousB,
            hasOpacity = false,
            swatchFunc = applyColor,
            cancelFunc = cancelColor
        })
    else
        ColorPickerFrame.func = applyColor
        ColorPickerFrame.cancelFunc = cancelColor
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = {r = previousR, g = previousG, b = previousB}
        ColorPickerFrame:SetColorRGB(previousR, previousG, previousB)
        ColorPickerFrame:Show()
    end

    HookModernColorPickerClassButton(applyClassColor)
    C_Timer.After(0, function() HookModernColorPickerClassButton(applyClassColor) end)
end

local function GetModernColorPopup()
    if modernColorPopup then return modernColorPopup end

    local popup = CreateFrame("Frame", "GSEModernColorPickerPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(MODERN_COLOR_POPUP_WIDTH, MODERN_COLOR_POPUP_HEIGHT)
    GSE.UI.MakePopup(popup, {movable = true})
    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        popup:SetBackdropColor(0.02, 0.025, 0.028, 0.96)
        popup:SetBackdropBorderColor(0.22, 0.24, 0.25, 1)
    end

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Modern Custom Color")

    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local label = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, -45)
    label:SetText("Hex / RGB")

    popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.editBox:SetSize(120, 22)
    popup.editBox:SetPoint("LEFT", label, "RIGHT", 18, 0)
    popup.editBox:SetAutoFocus(false)
    popup.editBox:SetMaxLetters(20)
    popup.editBox:SetScript("OnEnterPressed", function(self)
        if ApplyModernColorPopup(popup) then
            self:ClearFocus()
        end
    end)
    popup.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)
    popup.editBox:SetScript("OnTextChanged", function()
        UpdateModernPopupFromText(popup)
    end)

    popup.swatch = CreateModernColorSwatch(popup)
    popup.swatch:SetSize(26, 26)
    popup.swatch:SetPoint("LEFT", popup.editBox, "RIGHT", 14, 0)
    popup.swatch:SetScript("OnClick", function()
        OpenBlizzardColorPickerForPopup(popup)
    end)

    local pickButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    pickButton:SetSize(82, SETTINGS_BUTTON_HEIGHT)
    pickButton:SetPoint("LEFT", popup.swatch, "RIGHT", 12, 0)
    pickButton:SetText("Picker")
    pickButton:SetScript("OnClick", function()
        OpenBlizzardColorPickerForPopup(popup)
    end)

    local applyButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    applyButton:SetSize(82, SETTINGS_BUTTON_HEIGHT)
    applyButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 16)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", function()
        ApplyModernColorPopup(popup)
    end)

    local cancelButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancelButton:SetSize(82, SETTINGS_BUTTON_HEIGHT)
    cancelButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    popup:Hide()
    modernColorPopup = popup
    return popup
end

local function RefreshModernColorRow(row)
    if not row then return end
    local customEnabled = GSEOptions.UseModernCustomColor == true

    local rowCheckbox = row.Checkbox or row.CheckBox or row.CheckButton or row.Check
    if rowCheckbox and rowCheckbox.SetChecked then
        rowCheckbox:SetChecked(customEnabled)
    end
    if row.GSEModernCustomCheck then
        row.GSEModernCustomCheck:SetChecked(customEnabled)
        SetControlEnabled(row.GSEModernCustomCheck, true)
    end
    if row.GSEModernCustomLabel then
        row.GSEModernCustomLabel:SetTextColor(1, 0.82, 0, 1)
    end
    if row.GSEModernColorSwatch then
        UpdateModernColorSwatch(row.GSEModernColorSwatch)
        row.GSEModernColorSwatch:SetAlpha(customEnabled and 1 or 0.65)
        row.GSEModernColorSwatch:EnableMouse(true)
    end
    if row.Button then
        row.Button:Hide()
        row.Button:EnableMouse(false)
    end
end

local function FindModernCustomColorRow(owner)
    local row = owner
    while row and row.GetParent and not row.GSEModernRefreshColorRow do
        row = row:GetParent()
    end
    return row
end

local function FindColorPickerOkayButton(parent)
    if not parent then return nil end
    return parent.OkayButton or
        parent.OKButton or
        (parent.Footer and (parent.Footer.OkayButton or parent.Footer.OKButton or parent.Footer.AcceptButton)) or
        _G.ColorPickerOkayButton or
        _G.ColorPickerFrameOkayButton or
        _G.ColorPickerFrameOKButton
end

local function FindColorPickerOkayButtonRecursive(parent)
    local direct = FindColorPickerOkayButton(parent)
    if direct then return direct end
    if not (parent and parent.GetChildren) then return nil end

    for _, child in ipairs({parent:GetChildren()}) do
        local text = child.GetText and child:GetText()
        if text == OKAY or text == OK or text == "Okay" or text == "OK" or text == ACCEPT then
            return child
        end
        local found = FindColorPickerOkayButtonRecursive(child)
        if found then return found end
    end
end

local function GetColorPickerButtonText(button)
    if not button then return nil end

    local text = button.GetText and button:GetText()
    if text and text ~= "" then return text end

    local fontString = button.GetFontString and button:GetFontString()
    text = fontString and fontString.GetText and fontString:GetText()
    if text and text ~= "" then return text end

    text = button.Text and button.Text.GetText and button.Text:GetText()
    if text and text ~= "" then return text end
end

local function FindColorPickerTextButtonRecursive(parent, buttonText)
    if not (parent and parent.GetChildren) then return nil end

    for _, child in ipairs({parent:GetChildren()}) do
        local text = GetColorPickerButtonText(child)
        if text == buttonText then
            return child
        end
        local found = FindColorPickerTextButtonRecursive(child, buttonText)
        if found then return found end
    end
end

function HookModernColorPickerClassButton(applyFunc)
    local classButton = FindColorPickerTextButtonRecursive(ColorPickerFrame, "Class")
    if not classButton then return false end

    classButton.GSEModernClassColorApply = applyFunc
    if not classButton.GSEModernClassColorHooked and classButton.HookScript then
        classButton:HookScript("OnClick", function(self)
            local func = self.GSEModernClassColorApply
            if func then
                func()
                RunAfterOptionsUpdate(func)
            end
        end)
        classButton.GSEModernClassColorHooked = true
    end
    return true
end

local function HookModernColorPickerOkayButton(applyFunc)
    local okButton = FindColorPickerOkayButtonRecursive(ColorPickerFrame)
    if not okButton then return false end

    okButton.GSEModernCustomColorApply = applyFunc
    if not okButton.GSEModernCustomColorHooked and okButton.HookScript then
        okButton:HookScript("OnClick", function(self)
            local func = self.GSEModernCustomColorApply
            self.GSEModernCustomColorApply = nil
            if func then func() end
        end)
        okButton.GSEModernCustomColorHooked = true
    end
    return true
end

local function OpenModernCustomColorPicker(owner)
    if not ColorPickerFrame then return end

    local row = FindModernCustomColorRow(owner)
    local previousR, previousG, previousB = GetModernCustomColor()
    local pendingR, pendingG, pendingB = previousR, previousG, previousB
    local applied = false

    local function previewColor()
        pendingR, pendingG, pendingB = ColorPickerFrame:GetColorRGB()
        if row and row.GSEModernColorSwatch and row.GSEModernColorSwatch.SetBackdropColor then
            row.GSEModernColorSwatch:SetBackdropColor(pendingR, pendingG, pendingB, 1)
            row.GSEModernColorSwatch:SetAlpha(1)
        end
    end

    local function previewClassColor()
        local r, g, b = GetCurrentPlayerClassColor()
        if not r then return end
        if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(r, g, b) end
        pendingR, pendingG, pendingB = r, g, b
        if row and row.GSEModernColorSwatch and row.GSEModernColorSwatch.SetBackdropColor then
            row.GSEModernColorSwatch:SetBackdropColor(pendingR, pendingG, pendingB, 1)
            row.GSEModernColorSwatch:SetAlpha(1)
        end
    end

    local function applyColor()
        if applied then return end
        applied = true
        if ColorPickerFrame and ColorPickerFrame.GetColorRGB then
            pendingR, pendingG, pendingB = ColorPickerFrame:GetColorRGB()
        end
        SetModernCustomColor(pendingR, pendingG, pendingB)
        GSEOptions.UseModernCustomColor = true
        GSEOptions.UseModernClassColors = false
        if row and row.GSEModernRefreshColorRow then
            row:GSEModernRefreshColorRow()
        end
        RefreshExclusiveOptionRows("modernColor")
    end

    local function cancelColor()
        if row and row.GSEModernRefreshColorRow then
            row:GSEModernRefreshColorRow()
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previousR,
            g = previousG,
            b = previousB,
            hasOpacity = false,
            swatchFunc = previewColor,
            cancelFunc = cancelColor
        })
    else
        ColorPickerFrame.func = previewColor
        ColorPickerFrame.cancelFunc = cancelColor
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = {r = previousR, g = previousG, b = previousB}
        ColorPickerFrame:SetColorRGB(previousR, previousG, previousB)
        ColorPickerFrame:Show()
    end

    HookModernColorPickerOkayButton(applyColor)
    HookModernColorPickerClassButton(previewClassColor)
    C_Timer.After(0, function()
        HookModernColorPickerOkayButton(applyColor)
        HookModernColorPickerClassButton(previewClassColor)
    end)
end

function CreateModernColorSwatch(parent)
    local swatch = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    swatch:SetSize(MODERN_COLOR_SWATCH_SIZE, MODERN_COLOR_SWATCH_SIZE)
    if swatch.SetBackdrop then
        swatch:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        swatch:SetBackdropBorderColor(0.08, 0.08, 0.08, 1)
    end
    UpdateModernColorSwatch(swatch)
    return swatch
end

local function InstallSettingsModernColorRowFix()
    if settingsModernColorRowFixInstalled or not SettingsCheckboxWithButtonControlMixin or
        not SettingsCheckboxWithButtonControlMixin.Init then return end

    local originalInit = SettingsCheckboxWithButtonControlMixin.Init
    SettingsCheckboxWithButtonControlMixin.Init = function(self, initializer)
        local data = initializer and initializer.GetData and initializer:GetData()
        local result = originalInit(self, initializer)

        if not (data and data.gseModernCustomColorRow) then
            self.GSEModernColorData = nil
            self.GSEModernRefreshColorRow = nil
            if self.GSEModernCustomCheck then self.GSEModernCustomCheck:Hide() end
            if self.GSEModernCustomLabel then self.GSEModernCustomLabel:Hide() end
            if self.GSEModernColorSwatch then self.GSEModernColorSwatch:Hide() end
            return result
        end

        RegisterExclusiveOptionRow(self, data)
        self.GSEModernColorData = data
        self.GSEModernRefreshColorRow = RefreshModernColorRow

        if self.GSELabelText then self.GSELabelText:Hide() end
        if self.Text then
            self.Text:SetText(data.gseCustomColorText or "Custom Color")
            self.Text:Show()
        end
        if self.GSEModernCustomCheck then self.GSEModernCustomCheck:Hide() end
        if self.GSEModernCustomLabel then self.GSEModernCustomLabel:Hide() end

        if self.Button then
            self.Button:ClearAllPoints()
            self.Button:SetPoint("RIGHT", self, "RIGHT", -16, 0)
            self.Button:SetWidth(1)
            self.Button:SetHeight(SETTINGS_BUTTON_HEIGHT)
            self.Button:SetText("")
            self.Button:EnableMouse(false)
            self.Button:Hide()
        end

        if not self.GSEModernColorSwatch then
            self.GSEModernColorSwatch = CreateModernColorSwatch(self)
            self.GSEModernColorSwatch:SetScript("OnClick", function(button)
                OpenModernCustomColorPicker(button)
            end)
        end
        self.GSEModernColorSwatch:ClearAllPoints()
        local checkbox = GetOptionRowCheckbox(self)
        if checkbox then
            self.GSEModernColorSwatch:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
        else
            self.GSEModernColorSwatch:SetPoint("RIGHT", self, "RIGHT", -16, 0)
        end
        self.GSEModernColorSwatch:Show()

        if self.Checkbox and not self.GSEModernMainCheckboxHooked then
            self.Checkbox:HookScript("OnClick", function()
                if self.GSEModernRefreshColorRow then
                    self:GSEModernRefreshColorRow()
                end
                RefreshExclusiveOptionRows("modernColor")
                RunAfterOptionsUpdate(function() RefreshExclusiveOptionRows("modernColor") end)
            end)
            self.GSEModernMainCheckboxHooked = true
        end

        self:GSEModernRefreshColorRow()
        return result
    end
    settingsModernColorRowFixInstalled = true
end

local function CreateGSEModernCustomColorInitializer(category, setting, tooltip)
    InstallSettingsModernColorRowFix()

    local initializer
    if GSE.GameMode > 10 then
        initializer = CreateSettingsCheckboxWithButtonInitializer(setting, "Pick Color", OpenModernCustomColorPicker, nil, false, tooltip)
    else
        initializer = CreateSettingsCheckboxWithButtonInitializer(setting, "Pick Color", OpenModernCustomColorPicker, false, tooltip)
    end

    local data = initializer and initializer.GetData and initializer:GetData()
    if data then
        data.gseModernCustomColorRow = true
        data.gseCustomColorText = "Custom Color"
        data.gseButtonText = ""
    end
    if initializer and initializer.AddSearchTags then
        initializer:AddSearchTags("Custom Color")
    end
    return initializer
end

local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback or minimum
    if value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return math.floor(value + 0.5)
end

local function ClampScale(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback or minimum
    if value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return math.floor((value * 100) + 0.5) / 100
end

local function GetMaxSequenceEditorWidth()
    local screenWidth = GetScreenWidth and GetScreenWidth()
    if screenWidth and screenWidth > 0 then
        return math.max(MIN_EDITOR_WIDTH, math.min(MAX_EDITOR_WIDTH, screenWidth - EDITOR_SCREEN_MARGIN))
    end
    return MAX_EDITOR_WIDTH
end

local function GetMaxDebuggerWidth()
    local screenWidth = GetScreenWidth and GetScreenWidth()
    if screenWidth and screenWidth > 0 then
        return math.max(MIN_DEBUGGER_WIDTH, math.min(MAX_DEBUGGER_WIDTH, screenWidth - EDITOR_SCREEN_MARGIN))
    end
    return MAX_DEBUGGER_WIDTH
end

-- =========================================================================
-- SECTION 4 -- Tracker / Sequence-Icon-Frame option helpers
--
-- The Tracker frame (Sequence Icon Frame, Tracker Text, Successful
-- Casts indicator, Assisted Highlight) has a large per-character
-- option block under GSEOptions.SequenceIconFrame. This section
-- defines:
--   * EnsureSequenceIconFrameOptions -- mirror of Tracker.lua's own
--     version; backfills defaults on every call so the option panel
--     and the tracker itself agree on what's set
--   * ResetTrackerToDefaultLayout -- exposed via GSE.* (used by the
--     /gseresettracker slash command and the OnDefault button)
--   * AttachTrackerDefaultsHandler -- wires the "Restore Defaults"
--     button on the Tools & Diagnostics subcategory to call the reset
-- =========================================================================

local function EnsureSequenceIconFrameOptions()
    if not GSEOptions then GSEOptions = {} end
    if GSE.isEmpty(GSEOptions.SequenceIconFrame) then
        GSEOptions.SequenceIconFrame = {}
    end

    local opts = GSEOptions.SequenceIconFrame
    opts.Enabled = opts.Enabled == true
    opts.IconSize = 100
    opts.IconCount = ClampNumber(opts.IconCount, 1, 10, 10)
    opts.Scale = 0.50
    opts.Orientation = (opts.Orientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
    if opts.ShowSequenceName == nil then opts.ShowSequenceName = Statics.TrackerConfig.DefaultShowSequenceName end
    if opts.ShowSuccessfulCasts == nil then opts.ShowSuccessfulCasts = true end
    if opts.TextLocked == nil then opts.TextLocked = true end
    if opts.SuccessfulCastsLocked == nil then opts.SuccessfulCastsLocked = true end
    if opts.AssistedSuccessLocked == nil then opts.AssistedSuccessLocked = true end
    -- Default widget position. Mirrors Tracker.lua's DefaultWidgetX/Y so the
    -- tracker has a defined home even if this function runs before Tracker.lua's
    -- own EnsureSequenceIconFrameOptions (observed on Classic / BoA / MoP where
    -- the position wasn't being persisted on a fresh character). "Only if nil"
    -- so existing saved positions aren't clobbered.
    if opts.WidgetPoint         == nil then opts.WidgetPoint         = "LEFT" end
    if opts.WidgetRelativePoint == nil then opts.WidgetRelativePoint = "LEFT" end
    if opts.WidgetX             == nil then opts.WidgetX             = 1126 end
    if opts.WidgetY             == nil then opts.WidgetY             = 285  end
    return opts
end

local function ResetTrackerToDefaultLayout()
    local opts = EnsureSequenceIconFrameOptions()
    opts.Enabled = true
    opts.IconSize = 100
    opts.IconCount = 10
    opts.Scale = 0.50
    opts.Orientation = "HORIZONTAL"
    opts.TextMoved = false
    opts.TextX = nil
    opts.TextY = nil
    opts.TextWidth = 902
    opts.TextHeight = 593
    opts.WidgetPoint = "LEFT"
    opts.WidgetRelativePoint = "LEFT"
    opts.WidgetX = 1126
    opts.WidgetY = 285
    opts.BaseVerticalLayoutVersion = 3
    opts.ShowSuccessfulCasts = true
    opts.ShowSequenceName = Statics.TrackerConfig.DefaultShowSequenceName

    if GSE.SetSequenceIconFrameEnabled then GSE.SetSequenceIconFrameEnabled(true) end
    if GSE.SetSuccessfulCastFrameEnabled then GSE.SetSuccessfulCastFrameEnabled(true) end
    if GSE.ResetSequenceIconFramePosition then GSE.ResetSequenceIconFramePosition() end
    if GSE.ResetSequenceTextFramePosition then GSE.ResetSequenceTextFramePosition() end
    if GSE.ResetSuccessfulCastFramePosition then GSE.ResetSuccessfulCastFramePosition() end
    if GSE.ResetAssistedSuccessFramePosition then GSE.ResetAssistedSuccessFramePosition() end
    if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
end

-- Expose ResetTrackerToDefaultLayout on the GSE namespace so external
-- callers (the /gseresettracker slash command registered in
-- GSE_Utils/SlashCommands.lua, as well as plugins or layered builds that
-- want to reuse it) can invoke
-- it. The local reference above remains the canonical implementation;
-- the local AttachTrackerDefaultsHandler / OnDefault wiring continues to
-- use it directly so internal Options behaviour stays stable even if
-- GSE.ResetTrackerToDefaultLayout is later replaced from outside.
GSE.ResetTrackerToDefaultLayout = ResetTrackerToDefaultLayout

local function AttachTrackerDefaultsHandler(target)
    if not target then return end
    pcall(function() target.OnDefault = ResetTrackerToDefaultLayout end)
    pcall(function()
        if target.SetDefaultCallback then target:SetDefaultCallback(ResetTrackerToDefaultLayout) end
    end)
end

local function RefreshOpenEditorTrees()
    for _, editor in ipairs((GSE.GUI and GSE.GUI.editors) or {}) do
        if editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown() and editor.ManageTree then
            local treeStatus = editor.treeContainer and (editor.treeContainer.status or editor.treeContainer.localstatus)
            local selected = treeStatus and treeStatus.selected
            editor.ManageTree()
            if selected and editor.treeContainer and editor.treeContainer.SelectByValue then
                editor.forceTreeSelection = true
                editor.treeContainer:SelectByValue(selected)
            end
        end
    end
end

-- Public alias so NativeUI's in-tree "All Sequences" checkbox can trigger
-- a tree rebuild after toggling the underlying filter setting.
if not GSE.GUI then GSE.GUI = {} end
GSE.GUI.RefreshOpenEditorTrees = RefreshOpenEditorTrees

local function RefreshOpenEditorContent()
    for _, editor in ipairs((GSE.GUI and GSE.GUI.editors) or {}) do
        if editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown()
            and editor.RefreshCurrentVersion then
            editor.RefreshCurrentVersion()
        end
    end
end

local function ApplyDebuggerOptionsToCurrentWindow()
    if not GSE.GUIDebugFrame then return end
    GSEOptions.debugHeight = ClampNumber(GSEOptions.debugHeight, MIN_DEBUGGER_HEIGHT, MAX_DEBUGGER_HEIGHT, MIN_DEBUGGER_HEIGHT)
    GSEOptions.debugWidth = ClampNumber(GSEOptions.debugWidth, MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), MIN_DEBUGGER_WIDTH)

    if GSE.GUIDebugFrame.SetWidth then GSE.GUIDebugFrame:SetWidth(GSEOptions.debugWidth) end
    if GSE.GUIDebugFrame.SetHeight then GSE.GUIDebugFrame:SetHeight(GSEOptions.debugHeight) end
    if GSE.GUIDebugFrame.RefreshLayout then
        GSE.GUIDebugFrame:RefreshLayout()
    elseif GSE.GUIDebugFrame.DebugOutputTextbox then
        GSE.GUIDebugFrame.DebugOutputTextbox:SetNumLines(math.floor(GSEOptions.debugHeight / 18))
    end
    if GSE.GUIDebugFrame.DoLayout then GSE.GUIDebugFrame:DoLayout() end
end

-- -------------------------------------------------------------------------
-- 4.1 - Frame location + sequence editor option helpers
--
-- GSEOptions.frameLocations stores per-frame anchor/position data for
-- the Toolbar, Editor, Debug Window, and various trackers. The
-- EnsureFrameLocations / EnsureSequenceEditorOptions backfill missing
-- subtables so accessors elsewhere never have to nil-check. The
-- editor option group (RefreshOpenEditorTrees / GetOptionsEditor /
-- ApplySequenceEditorOptionsToCurrentEditor) hooks into the editor
-- lifecycle so option changes take effect on the currently-open
-- editor frame without requiring a /reload.
-- -------------------------------------------------------------------------

local function EnsureFrameLocations()
    if not GSEOptions then GSEOptions = {} end
    if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
    return GSEOptions.frameLocations
end

local function EnsureSequenceEditorOptions()
    local frameLocations = EnsureFrameLocations()
    if GSE.isEmpty(frameLocations.sequenceeditor) then frameLocations.sequenceeditor = {} end
    local se = frameLocations.sequenceeditor
    se.height = ClampNumber(se.height, MIN_EDITOR_HEIGHT, MAX_EDITOR_HEIGHT, MIN_EDITOR_HEIGHT)
    se.width = ClampNumber(se.width, MIN_EDITOR_WIDTH, GetMaxSequenceEditorWidth(), MIN_EDITOR_WIDTH)
    se.treeWidth = ClampNumber(se.treeWidth, MIN_TREE_WIDTH, MAX_TREE_WIDTH, MIN_TREE_WIDTH)
    -- Apply saved scroll speed to NativeUI's live runtime variable so it survives
    -- /reload and persists across sessions. Clamped to the same range as the slider.
    if GSE.GUI and GSE.GUI.SetScrollStep then
        local defaultStep = (GSE.GUI.GetScrollStepDefault and GSE.GUI.GetScrollStepDefault()) or 280
        se.scrollSpeed = ClampNumber(se.scrollSpeed, 50, 800, defaultStep)
        GSE.GUI.SetScrollStep(se.scrollSpeed)
    end
    return se
end

local function GetOptionsEditor()
    local editor = GSE.GUI and GSE.GUI.optionsEditor
    if editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown() then return editor end

    editor = GSE.GUI and GSE.GUI.activeEditor
    if editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown() then
        GSE.GUI.optionsEditor = editor
        return editor
    end

    for _, openEditor in ipairs((GSE.GUI and GSE.GUI.editors) or {}) do
        if openEditor and openEditor.frame and openEditor.frame.IsShown and openEditor.frame:IsShown() then
            GSE.GUI.optionsEditor = openEditor
            return openEditor
        end
    end

    return nil
end

local function ApplySequenceEditorOptionsToCurrentEditor()
    local editor = GetOptionsEditor()
    if not editor then return end

    local se = EnsureSequenceEditorOptions()
    if editor.treeContainer and editor.treeContainer.SetTreeWidth then
        editor.treeContainer:SetTreeWidth(se.treeWidth, true)
        if editor.treeContainer.DoLayout then editor.treeContainer:DoLayout() end
    end
    if editor.SetWidth then editor:SetWidth(ClampNumber(se.width, MIN_EDITOR_WIDTH, GetMaxSequenceEditorWidth(), MIN_EDITOR_WIDTH)) end
    if editor.SetHeight then editor:SetHeight(se.height) end
    if editor.DoLayout then editor:DoLayout() end
end

local AddEditorSequenceListOptions

-- -------------------------------------------------------------------------
-- 4.2 - Add* option group builders
--
-- Each AddXxxOptions(optionsCategory) function appends one labelled
-- group of related controls (a section header + N checkboxes /
-- sliders / dropdowns / proxy settings) to the given category panel.
-- They run during createBlizzOptions below. Pulled into separate
-- functions so the createBlizzOptions body stays readable and so
-- groups can be conditionally included (e.g. AddDebuggerWindowSizeOptions
-- depends on the dev-debug-window feature being present).
-- -------------------------------------------------------------------------

local function AddAppearanceOptions(optionsCategory)
    if GSE.isEmpty(GSE_C) then GSE_C = {} end

    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Skin", ["tooltip"] = "Skin"}))
    end
    -- Native Skin
    do
        local function GetValue()
            return GSEOptions.UseModernSkin ~= true
        end
        local function SetValue(val)
            local wasModern = (GSEOptions.UseModernSkin == true)
            local nowModern = (val ~= true)
            -- Show the reload prompt in the present (pre-swap) skin, then just
            -- record the new setting. We do NOT live-swap the skin here:
            -- re-skinning frames that are already open mid-session drops some of
            -- them, so instead we wait for the reload, which rebuilds every
            -- frame in the new skin cleanly and all at once. Prompt only when
            -- the skin actually flips (not on panel-sync/init or the unclicked
            -- half of the exclusive pair).
            if nowModern ~= wasModern and GSE.GUIConfirmReloadUI then GSE.GUIConfirmReloadUI() end
            GSEOptions.UseModernSkin = nowModern
            RefreshExclusiveOptionRows("skin")
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "charUseClassicSkin", Settings.VarType.Boolean, "Native Skin", true, GetValue, SetValue)
        MarkExclusiveCheckboxInitializer(
            Settings.CreateCheckbox(optionsCategory, setting, "Use GSE's Native (Blizzard) interface skin. Ignores ElvUI/EllesmereUI even when they are loaded. A /reload fully repaints any windows already open."),
            "skin",
            GetValue
        )
    end

    -- Modern Skin
    do
        local function GetValue()
            return GSEOptions.UseModernSkin == true
        end
        local function SetValue(val)
            local wasModern = (GSEOptions.UseModernSkin == true)
            local nowModern = (val == true)
            -- Show the reload prompt in the present (pre-swap) skin, then just
            -- record the new setting. We do NOT live-swap the skin here:
            -- re-skinning frames that are already open mid-session drops some of
            -- them, so instead we wait for the reload, which rebuilds every
            -- frame in the new skin cleanly and all at once. Prompt only when
            -- the skin actually flips (not on panel-sync/init or the unclicked
            -- half of the exclusive pair).
            if nowModern ~= wasModern and GSE.GUIConfirmReloadUI then GSE.GUIConfirmReloadUI() end
            GSEOptions.UseModernSkin = nowModern
            RefreshExclusiveOptionRows("skin")
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "charUseModernSkin", Settings.VarType.Boolean, "Modern Skin", false, GetValue, SetValue)
        MarkExclusiveCheckboxInitializer(
            Settings.CreateCheckbox(optionsCategory, setting, L["Use GSE's Modern interface skin. This does not require ElvUI."]),
            "skin",
            GetValue
        )
    end

    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Accent Color", ["tooltip"] = "Accent Color"}))
    end
    -- Modern Skin Class Colors
    do
        local function GetValue()
            return GSEOptions.UseModernClassColors == true and GSEOptions.UseModernCustomColor ~= true
        end
        local function SetValue(val)
            GSEOptions.UseModernClassColors = val == true
            if GSEOptions.UseModernClassColors then
                GSEOptions.UseModernCustomColor = false
            end
            RefreshExclusiveOptionRows("modernColor")
        end
        local tooltip = "Use your class color for Modern skin white text, a subtle surface tint, and the outer frame border."
        local setting = Settings.RegisterProxySetting(optionsCategory, "charUseModernClassColors", Settings.VarType.Boolean, "Class Color", false, GetValue, SetValue)
        MarkExclusiveCheckboxInitializer(
            Settings.CreateCheckbox(optionsCategory, setting, tooltip),
            "modernColor",
            GetValue
        )
    end

    -- Modern Skin Custom Color
    do
        local function GetValue()
            return GSEOptions.UseModernCustomColor == true
        end
        local function SetValue(val)
            GSEOptions.UseModernCustomColor = val == true
            if GSEOptions.UseModernCustomColor then
                GSEOptions.UseModernClassColors = false
            end
            RefreshExclusiveOptionRows("modernColor")
        end
        local tooltip = "Use the selected custom color instead of your class color. Click the color square to choose the custom color."
        local setting = Settings.RegisterProxySetting(optionsCategory, "charUseModernCustomColor", Settings.VarType.Boolean, "Custom Color", false, GetValue, SetValue)
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(MarkExclusiveCheckboxInitializer(
            CreateGSEModernCustomColorInitializer(optionsCategory, setting, tooltip),
            "modernColor",
            GetValue
        ))
    end

    AddEditorSequenceListOptions(optionsCategory)

    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Scaling", ["tooltip"] = "Scaling"}))
    end
    -- GSE Menu Scale
    do
        local function GetValue()
            return GSE.GetMenuUIScale and GSE.GetMenuUIScale() or 1
        end
        local function SetValue(value)
            value = ClampScale(value, MIN_GSE_UI_SCALE, MAX_GSE_UI_SCALE, 1)
            if GSE.SetMenuUIScale then
                GSE.SetMenuUIScale(value)
            else
                GSE_C.MenuUIScale = value
            end
        end

        local setting = Settings.RegisterProxySetting(optionsCategory, "charGSEMenuUIScale", Settings.VarType.Number, "GSE Toolbar Scale", 1, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(MIN_GSE_UI_SCALE, MAX_GSE_UI_SCALE)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%.2f", ClampScale(value, MIN_GSE_UI_SCALE, MAX_GSE_UI_SCALE, 1))
        end)
        Settings.CreateSlider(optionsCategory, setting, options, "Scale the GSE Toolbar independently of GSE windows and Blizzard UI Scale.")
    end
    -- GSE Editor Scale
    do
        local function GetValue()
            return GSE.GetUIScale and GSE.GetUIScale() or 1
        end
        local function SetValue(value)
            value = ClampScale(value, MIN_GSE_WINDOW_SCALE, MAX_GSE_WINDOW_SCALE, 1)
            if GSE.SetUIScale then
                GSE.SetUIScale(value)
            else
                GSE_C.UIScale = value
            end
        end

        local setting = Settings.RegisterProxySetting(optionsCategory, "charGSEUIScale", Settings.VarType.Number, "GSE Editor Scale", 1, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(MIN_GSE_WINDOW_SCALE, MAX_GSE_WINDOW_SCALE)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%.2f", ClampScale(value, MIN_GSE_WINDOW_SCALE, MAX_GSE_WINDOW_SCALE, 1))
        end)
        Settings.CreateSlider(optionsCategory, setting, options, "Scale the GSE editor and addon windows independently of Blizzard UI Scale. Does not affect the Debugger windows or the GSE Menu.")
    end
    -- GSE Debugger Scale (Debugger, Hardware Events, Debug Stats windows)
    do
        local MIN_DBG_SCALE = 0.5
        local MAX_DBG_SCALE = 1.5
        local function GetValue()
            return GSE.GetDebugUIScale and GSE.GetDebugUIScale() or 1
        end
        local function SetValue(value)
            if GSE.SetDebugUIScale then GSE.SetDebugUIScale(value) end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "debuggerUIScale", Settings.VarType.Number, "GSE Debugger Scale", 1, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(MIN_DBG_SCALE, MAX_DBG_SCALE)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%.2f", value)
        end)
        Settings.CreateSlider(optionsCategory, setting, options, "Scale the GSE Debug windows independently.")
    end
end

local function AddDebuggerWindowSizeOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Sequence Debugger"], tooltip = L["Sequence Debugger"]}))
    end
    do
        local function GetValue()
            GSEOptions.debugHeight = ClampNumber(GSEOptions.debugHeight, MIN_DEBUGGER_HEIGHT, MAX_DEBUGGER_HEIGHT, MIN_DEBUGGER_HEIGHT)
            return GSEOptions.debugHeight
        end
        local function SetValue(val)
            GSEOptions.debugHeight = ClampNumber(val, MIN_DEBUGGER_HEIGHT, MAX_DEBUGGER_HEIGHT, MIN_DEBUGGER_HEIGHT)
            ApplyDebuggerOptionsToCurrentWindow()
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "debugWindowHeight", Settings.VarType.Number, L["Default Debugger Height"], MIN_DEBUGGER_HEIGHT, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(MIN_DEBUGGER_HEIGHT, MAX_DEBUGGER_HEIGHT, 10)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, "How many pixels high should the Debugger start at. Defaults to 500")
    end
    do
        local function GetValue()
            GSEOptions.debugWidth = ClampNumber(GSEOptions.debugWidth, MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), MIN_DEBUGGER_WIDTH)
            return GSEOptions.debugWidth
        end
        local function SetValue(val)
            GSEOptions.debugWidth = ClampNumber(val, MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), MIN_DEBUGGER_WIDTH)
            ApplyDebuggerOptionsToCurrentWindow()
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "debugWindowWidth", Settings.VarType.Number, L["Default Debugger Width"], MIN_DEBUGGER_WIDTH, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), 10)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["How many pixels wide should the Debugger start at.  Defaults to 700"])
    end
end

local function AddActionBarWatermarkOption(optionsCategory)
    do
        local function GetValue()
            return GSEOptions.showActionBarWatermark ~= false
        end
        local function SetValue(val)
            GSEOptions.showActionBarWatermark = val == true
            if GSE.SetActionBarWatermarkEnabled then
                GSE.SetActionBarWatermarkEnabled(GSEOptions.showActionBarWatermark ~= false)
            end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "actionBarWatermark", Settings.VarType.Boolean, L["Show Actionbar Override Watermark"], true, GetValue, SetValue)
        Settings.CreateCheckbox(optionsCategory, setting, L["Show the GSE logo as a small watermark on actionbar override buttons."])
    end
end

local function AddActionBarLabelOption(optionsCategory)
    do
        local function GetValue()
            return GSEOptions.showActionBarLabel ~= false
        end
        local function SetValue(val)
            GSEOptions.showActionBarLabel = val == true
            if GSE.SetActionBarLabelEnabled then
                GSE.SetActionBarLabelEnabled()
            end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "actionBarLabel", Settings.VarType.Boolean, L["Show Actionbar Override Label"], true, GetValue, SetValue)
        Settings.CreateCheckbox(optionsCategory, setting, L["Show the sequence name as a text label on actionbar override buttons."])
    end
end

local function AddActionBarClickBehaviorOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "Action Button CVar", tooltip = L["CVar Settings"]}))
    end
    do
        local function GetValue()
            local value = C_CVar.GetCVar("ActionButtonUseKeyDown")
            return tonumber(value) == 1
        end
        local function SetValue(val)
            local ok, err = pcall(function()
                return C_CVar.SetCVar("ActionButtonUseKeyDown", val and 1 or 0)
            end)
            if not ok then
                GSE.PrintDebugMessage("SetCVar ActionButtonUseKeyDown error: " .. tostring(err), "Options")
                return
            end
            -- Rebind keys so the key-down relay (GSE.GetKeybindClickTarget) is
            -- built or dropped to match the new CVar state without a manual
            -- /reload. Combat-safe: LoadKeyBindings guards its SetBindingClick
            -- calls with InCombatLockdown(), so a toggle mid-combat simply takes
            -- effect on the next out-of-combat rebind.
            if GSE.ReloadKeyBindings then
                GSE.ReloadKeyBindings()
            end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "GSE_ActionButtonUseKeyDown", Settings.VarType.Boolean, L["ActionButtonUseKeyDown"], false, GetValue, SetValue)
        Settings.CreateCheckbox(optionsCategory, setting, L["This is a common WoW setting used by all addons; it controls when your action buttons respond.  On: they react when you press the key (key-down).  Off: they react when you release it (key-up).  GSE now works either way -- Actionbar Overrides and keybinds fire a single step in both states.  With this on, GSE keybinds also fire on key-down for a faster response.  Changes apply immediately out of combat (or on your next rebind if toggled mid-combat)."])
    end
end

local function AddOutOfCombatQueueOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Out of Combat Queue" , ["tooltip"]= "Out of Combat Queue" }))
    end
    do
        local function GetValue()
            GSEOptions.OOCQueueDelay = ClampNumber(GSEOptions.OOCQueueDelay, 1, 60, 7)
            return GSEOptions.OOCQueueDelay
        end

        local function SetValue(value)
            GSEOptions.OOCQueueDelay = ClampNumber(value, 1, 60, 7)
        end

        local setting = Settings.RegisterProxySetting(optionsCategory, "defaultOOCTimerDelay", Settings.VarType.Number, L["OOC Queue Delay"], 7, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(1, 60, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."])
    end
end

local function AddMSClickTimingHeader(optionsCategory)
    if not (GSE.Patron or GSE.Developer) then return end

    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "MS Click Timing" , ["tooltip"]= "Used for PAUSE Block Calculations" }))
    end
end

local function AddGlobalClickTimingOptions(optionsCategory)
    if not (GSE.Patron or GSE.Developer) then return end

    do
        local function GetValue()
            GSEOptions.msClickRate = ClampNumber(GSEOptions.msClickRate, 100, 1000, 250)
            return GSEOptions.msClickRate
        end

        local function SetValue(value)
            GSEOptions.msClickRate = ClampNumber(value, 100, 1000, 250)
        end

        local setting = Settings.RegisterProxySetting(optionsCategory, "msClickRate", Settings.VarType.Number, "Global Default - MS Click Rate", 250, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(100, 1000, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["The milliseconds being used in key click delay."])
    end
end

local function AddCharacterClickTimingOptions(optionsCategory)
    if not (GSE.Patron or GSE.Developer) then return end
    if GSE.isEmpty(GSE_C) then GSE_C = {} end

    do
        local function GetValue()
            GSE_C.msClickRate = ClampNumber(GSE_C.msClickRate, 100, 1000, 250)
            return GSE_C.msClickRate
        end

        local function SetValue(value)
            GSE_C.msClickRate = ClampNumber(value, 100, 1000, 250)
        end

        local setting = Settings.RegisterProxySetting(optionsCategory, "charmsClickRate", Settings.VarType.Number, "This Character - MS Click Rate", 250, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(100, 1000, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["The milliseconds being used in key click delay."])
    end
end

local function AddCompanionAppOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Companion App", ["tooltip"]= L["GSE Companion"]}))
    end
    -- Auto Accept Companion Updates
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "companionAutoAccept", "CompanionAutoAccept", GSEOptions, Settings.VarType.Boolean, L["Auto Accept Companion Updates"], false)
        Settings.CreateCheckbox(optionsCategory, setting, L["Automatically import sequences pushed from the GSE Companion app without showing the import dialog. Deletes will still require confirmation."])
    end
    -- Sync WoW Macros to GSEMacros
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "syncWoWMacros", "SyncWoWMacros", GSEOptions, Settings.VarType.Boolean, L["Sync WoW Macros to GSE.Tools"], false)
        Settings.CreateCheckbox(optionsCategory, setting, L["When enabled, all of your WoW macros are imported into GSE.Tools and kept in sync via the GSE Companion App. Changes made via the /macro dialog are reflected in GSE's Managed Macro Section, and incoming changes from GSE.Tools are written back to your WoW macros."])
        setting:SetValueChangedCallback(function()
            if GSEOptions.SyncWoWMacros and GSE.SyncAllWoWMacros then
                C_Timer.After(0, GSE.SyncAllWoWMacros)
            end
        end)
    end
end

local function AddImportExportOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Import & Export" , ["tooltip"]= "Import & Export" }))
    end
    -- Human readable exports
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "UseVerboseExportFormat", "DefaultHumanReadableExportFormat", GSEOptions, Settings.VarType.Boolean, L["Create Human Readable Exports"], true)
        Settings.CreateCheckbox(optionsCategory, setting, L["When exporting from GSE create a descriptive export for Discord/Discource forums."])
    end
    -- Default Import Action: pre-selected value in the import compare
    -- dialog (MacroCompare.lua) when an incoming sequence collides with
    -- a local one. Used to live in the old options panel; lost in the
    -- migration. Backing field GSEOptions.DefaultImportAction is read
    -- by MacroCompare.lua and Utils.lua already.
    do
        local function GetValue()
            local v = GSEOptions and GSEOptions.DefaultImportAction
            if v == "MERGE" or v == "REPLACE" or v == "IGNORE" or v == "RENAME" then return v end
            return "MERGE"
        end
        local function SetValue(val)
            GSEOptions.DefaultImportAction = val
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "defaultImportAction", Settings.VarType.String, L["Default Import Action"], "MERGE", GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add("MERGE",   L["Merge"])
            container:Add("REPLACE", L["Replace"])
            container:Add("IGNORE",  L["Ignore"])
            container:Add("RENAME",  L["Rename New Macro"])
            return container:GetData()
        end
        Settings.CreateDropdown(optionsCategory, setting, GetOptions, L["Pre-selected action when an imported sequence collides with one you already have. Merge appends new versions to the existing sequence; Replace overwrites it; Ignore skips the import; Rename brings the new sequence in under a different name."])
    end
end

function AddEditorSequenceListOptions(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Editor Sequence List", ["tooltip"]= L["Filter Sequence Selection"]}))
    end
    -- Show All Sequences
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "showAllMacros", Statics.All, GSEOptions.filterList, Settings.VarType.Boolean, L["Show All Sequences in Editor"], true)
        setting:SetValueChangedCallback(RefreshOpenEditorTrees)
        Settings.CreateCheckbox(optionsCategory, setting, "Show every sequence available to this character in the editor tree.")
    end
    -- showClassMacros
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "showClassMacros", Statics.Class, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Class Sequences in Editor"], true)
        setting:SetValueChangedCallback(RefreshOpenEditorTrees)
        Settings.CreateCheckbox(optionsCategory, setting, L["By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."])
    end
    -- showGlobalMacros
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "showGlobalMacros", Statics.Global, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Global Sequences in Editor"], true)
        setting:SetValueChangedCallback(RefreshOpenEditorTrees)
        Settings.CreateCheckbox(optionsCategory, setting, L["This shows the Global Sequences available as well as those for your class."])
    end
    -- showCurrentSpells
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "showCurrentSpells", "showCurrentSpells", GSEOptions, Settings.VarType.Boolean, L["Show Current Spells"], true)
        setting:SetValueChangedCallback(RefreshOpenEditorContent)
        Settings.CreateCheckbox(optionsCategory, setting, L["GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."])
    end
    -- Focus Highlight Tint (master toggle for the rail-color fill on the
    -- focused block — sits above Focus Highlight Proc because it gates
    -- whether the tint shows at all; the Proc + Brightness controls below
    -- only affect the border-pulse animation, which is independent).
    do
        local setting = Settings.RegisterAddOnSetting(optionsCategory, "focusHighlightTint", "FocusHighlightTint", GSEOptions, Settings.VarType.Boolean, L["Focus Highlight Tint"] or "Focus Highlight Tint", true)
        setting:SetValueChangedCallback(function()
            if GSE.GUI and GSE.GUI.RefreshFocusHighProc then GSE.GUI.RefreshFocusHighProc() end
        end)
        Settings.CreateCheckbox(optionsCategory, setting, L["When enabled, the focused block's empty areas (outside the macro text box) get a soft fill in the rail color so you can spot it at a glance. Disable to keep only the proc-pulsed border around the focused block — useful if the tint feels distracting while reading or editing."] or "When enabled, the focused block's empty areas (outside the macro text box) get a soft fill in the rail color so you can spot it at a glance. Disable to keep only the proc-pulsed border around the focused block — useful if the tint feels distracting while reading or editing.")
    end
    -- FocusHighProc + FocusHighProcBrightness: pick a proc-style animation
    -- TYPE for the focused-block highlight border and a brightness modifier
    -- stacked on top. Each Proc type has its own alpha range, cycle duration
    -- and smoothing curve (configured in Editor.lua's FOCUS_HIGH_PROC_TYPES
    -- table); Brightness shifts the low-alpha bound (Low → subtler swing,
    -- High → bigger swing). Border color is hard-coded per action type and
    -- is NOT changed here — only the animation behaviour of the four border
    -- lines (plus the unrelated rail-color tint, which lives in Editor.lua).
    --
    -- Rendered as Settings dropdowns to keep the L/R-arrow + center-label
    -- visual the user expects, but the popout-on-click is disabled via the
    -- DisableDropdownPopout helper below. The popout menu was overflowing
    -- the Settings panel and rendering behind subsequent rows; keeping just
    -- the steppers (which are separate widgets from the popout button)
    -- gives the same cycling behaviour without that visual bug.
    local function DisableDropdownPopout(frameWidget)
        if not frameWidget then return end
        -- The control's central popout button lives at frame.DropDown.Button
        -- in modern WoW (Dragonflight/TWW). Lower-case alias guarded for
        -- older clients. Increment/Decrement buttons (the L/R steppers) are
        -- siblings, so they remain interactive after this call.
        local dd = frameWidget.DropDown or frameWidget.Dropdown
        if not dd then return end
        local popoutBtn = dd.Button or dd.button
        if popoutBtn and popoutBtn.SetScript then
            popoutBtn:SetScript("OnClick",     function() end)
            popoutBtn:SetScript("OnMouseDown", function() end)
            popoutBtn:SetScript("OnMouseUp",   function() end)
            popoutBtn:SetScript("PreClick",    function() end)
        end
    end

    -- Tag-and-wrap helper: takes an initializer returned by
    -- Settings.CreateDropdown and wraps its InitFrame hook so the popout is
    -- disabled the moment the widget is bound to a list row. pcall-guarded
    -- so a future API shape change can't crash addon load — worst case,
    -- the popup re-appears (the steppers still work).
    local function NoPopoutDropdown(initializer)
        if not initializer then return initializer end
        local origInitFrame = initializer.InitFrame
        initializer.InitFrame = function(self, frameWidget)
            if origInitFrame then pcall(origInitFrame, self, frameWidget) end
            pcall(DisableDropdownPopout, frameWidget)
        end
        return initializer
    end

    -- Focus Highlight Proc
    do
        local VALID_TYPES = { OFF=true, PULSE=true, FLASH=true, THROB=true, BREATHE=true, STROBE=true }
        local LEGACY_MIGRATION = { LOW = "BREATHE", MEDIUM = "PULSE", HIGH = "THROB" }
        local function GetValue()
            local v = GSEOptions and GSEOptions.FocusHighProc
            if type(v) == "string" then
                local up = v:upper()
                if LEGACY_MIGRATION[up] then up = LEGACY_MIGRATION[up] end
                if VALID_TYPES[up] then return up end
            end
            return "PULSE"
        end
        local function SetValue(val)
            GSEOptions.FocusHighProc = val
            if GSE.GUI and GSE.GUI.RefreshFocusHighProc then GSE.GUI.RefreshFocusHighProc() end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "focusHighProc", Settings.VarType.String, L["Focus Highlight Proc"] or "Focus Highlight Proc", "PULSE", GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            -- Just the type names — matches the Strata / Growth Direction
            -- dropdowns elsewhere in the Options panel where the center
            -- label is a single short word. The popout is still disabled
            -- via NoPopoutDropdown below, so the L/R stepper buttons are
            -- the only way to cycle through these.
            container:Add("OFF",     L["Off"]     or "Off")
            container:Add("PULSE",   L["Pulse"]   or "Pulse")
            container:Add("FLASH",   L["Flash"]   or "Flash")
            container:Add("THROB",   L["Throb"]   or "Throb")
            container:Add("BREATHE", L["Breathe"] or "Breathe")
            container:Add("STROBE",  L["Strobe"]  or "Strobe")
            return container:GetData()
        end
        NoPopoutDropdown(Settings.CreateDropdown(optionsCategory, setting, GetOptions, L["Proc-style animation type for the focused-block highlight border in the Sequence Editor. Step left/right with the arrow buttons to cycle through styles — Pulse is the default smooth fade; Flash is sharp fast on/off; Throb is a slow heavy fade; Breathe is a slow gentle ripple; Strobe is very fast alternation; Off keeps the border solid. Border color stays the per-action-type default."] or "Proc-style animation type for the focused-block highlight border in the Sequence Editor. Step left/right with the arrow buttons to cycle through styles — Pulse is the default smooth fade; Flash is sharp fast on/off; Throb is a slow heavy fade; Breathe is a slow gentle ripple; Strobe is very fast alternation; Off keeps the border solid. Border color stays the per-action-type default."))
    end
    -- Focus Highlight Brightness
    do
        local VALID_LEVELS = { LOW=true, MEDIUM=true, HIGH=true }
        local function GetValue()
            local v = GSEOptions and GSEOptions.FocusHighProcBrightness
            if type(v) == "string" then
                local up = v:upper()
                if VALID_LEVELS[up] then return up end
            end
            return "MEDIUM"
        end
        local function SetValue(val)
            GSEOptions.FocusHighProcBrightness = val
            if GSE.GUI and GSE.GUI.RefreshFocusHighProc then GSE.GUI.RefreshFocusHighProc() end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "focusHighProcBrightness", Settings.VarType.String, L["Focus Highlight Brightness"] or "Focus Highlight Brightness", "MEDIUM", GetValue, SetValue)
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add("LOW",    L["Low"]    or "Low")
            container:Add("MEDIUM", L["Medium"] or "Medium")
            container:Add("HIGH",   L["High"]   or "High")
            return container:GetData()
        end
        NoPopoutDropdown(Settings.CreateDropdown(optionsCategory, setting, GetOptions, L["Dimming intensity of the focused-block highlight pulse, stacked on top of the Focus Highlight Proc type. Step left/right with the arrow buttons — Low is subtler (smaller alpha swing), Medium uses the type's baseline, High is more dramatic (bigger alpha swing). Has no effect when Focus Highlight Proc is set to Off."] or "Dimming intensity of the focused-block highlight pulse, stacked on top of the Focus Highlight Proc type. Step left/right with the arrow buttons — Low is subtler (smaller alpha swing), Medium uses the type's baseline, High is more dramatic (bigger alpha swing). Has no effect when Focus Highlight Proc is set to Off."))
    end
    -- Editor Scroll Speed (live) — sits at the bottom of this section so the
    -- focus-highlight pair stays grouped under the "Show Current Spells"
    -- toggles above it. Moving this block changes only its visual order;
    -- the proxy setting and live SetScrollStep wiring are unchanged.
    do
        local SCROLL_MIN, SCROLL_MAX, SCROLL_STEP_GRAIN = 50, 800, 10
        local SCROLL_DEFAULT = (GSE.GUI and GSE.GUI.GetScrollStepDefault and GSE.GUI.GetScrollStepDefault()) or 280
        local function GetValue()
            local se = EnsureSequenceEditorOptions()
            return ClampNumber(se.scrollSpeed, SCROLL_MIN, SCROLL_MAX, SCROLL_DEFAULT)
        end
        local function SetValue(val)
            local se = EnsureSequenceEditorOptions()
            se.scrollSpeed = ClampNumber(val, SCROLL_MIN, SCROLL_MAX, SCROLL_DEFAULT)
            if GSE.GUI and GSE.GUI.SetScrollStep then GSE.GUI.SetScrollStep(se.scrollSpeed) end
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "editorScrollSpeed", Settings.VarType.Number, L["Editor Scroll Speed"], SCROLL_DEFAULT, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(SCROLL_MIN, SCROLL_MAX, SCROLL_STEP_GRAIN)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["Pixels scrolled per mouse-wheel notch in the Sequence Editor. Higher = faster scrolling. Default 280."])
    end
end

-- =========================================================================
-- SECTION 5 -- Resources popup integration
--
-- Bridge from the Options panel to the existing Resources popup
-- (managed by Editor_Tree.lua). The popup is the same one the
-- in-editor "Resources" button opens -- showing Discord / GitHub /
-- Patreon / Companion App links. Calling
-- ShowResourcesPopupFromOptions from the About page's "GSE: Resources"
-- button means we don't duplicate the link list.
-- =========================================================================

local function ShowResourcesPopupFromOptions(owner)
    local loaded = GSE.CheckGUI and GSE.CheckGUI()

    if (loaded or (GSE.UnsavedOptions and GSE.UnsavedOptions["GUI"])) and GSE.GUI and GSE.GUI.ShowResourcesPopup then
        GSE.GUI.ShowResourcesPopup(owner)
    elseif GSE.Print then
        GSE.Print("The GSE_GUI Module needs to be enabled to open Resources.", L["Options"])
    end
end

-- =========================================================================
-- SECTION 6 -- About / Resources canvas page builders
--
-- The About panel is the GSE entry's main page in the Blizzard
-- Settings sidebar (canvas-layout, not vertical list). createAboutPanel
-- builds the credits / version / patron-list / changelog / resources
-- buttons content. The Resources subcategory (registered separately)
-- shares the version-link hitbox helper from Editor_Tree.lua.
-- =========================================================================

local function createAboutPanel()
    local panel = CreateFrame("Frame")
    panel.OnCommit = function() end
    panel.OnDefault = ResetTrackerToDefaultLayout
    panel.OnRefresh = function() end

    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true

        local padding = 20
        local pw = self:GetWidth()
        if pw < 100 then pw = 600 end

        -- ScrollFrame fills the panel, leaving room for the scrollbar
        local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -26, 0)

        local cw = pw - 26  -- content width (panel minus scrollbar)
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(cw)
        content:SetHeight(1)
        scrollFrame:SetScrollChild(content)

        -- Logo (top-left of content)
        local logo = content:CreateTexture(nil, "ARTWORK")
        logo:SetTexture(ABOUT_LOGO_TEXTURE)
        logo:SetSize(ABOUT_LOGO_WIDTH, ABOUT_LOGO_HEIGHT)
        logo:SetPoint("TOPLEFT", content, "TOPLEFT", padding, -padding)

        -- History header (right of logo, aligned to top)
        local histHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        histHeader:SetPoint("TOPLEFT", logo, "TOPRIGHT", padding, 0)
        histHeader:SetTextColor(HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B)
        histHeader:SetText(L["History"])

        -- About description text (beside logo)
        local textWidth = cw - 120 - padding * 3
        local aboutDesc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        aboutDesc:SetWidth(textWidth)
        aboutDesc:SetJustifyH("LEFT")
        aboutDesc:SetWordWrap(true)
        aboutDesc:SetPoint("TOPLEFT", histHeader, "BOTTOMLEFT", 0, -6)
        aboutDesc:SetText(L["GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community."])

        -- Version (anchored below logo)
        local versionHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        versionHeader:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -padding)
        versionHeader:SetTextColor(HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B)
        versionHeader:SetText(L["Version"])

        local versionText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        versionText:SetPoint("TOPLEFT", versionHeader, "BOTTOMLEFT", 0, -6)
        versionText:SetText("GSE: " .. GSE.VersionString)

        -- Resources button
        local resourcesBannerWidth = cw - padding * 2
        local resourcesBannerHeight = math.max(1, math.floor((resourcesBannerWidth / RESOURCES_BUTTON_TEXTURE_WIDTH) * RESOURCES_BUTTON_TEXTURE_HEIGHT + 0.5))
        local resourcesBanner = CreateFrame("Frame", nil, content)
        resourcesBanner:SetSize(resourcesBannerWidth, resourcesBannerHeight)
        resourcesBanner:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -padding)

        local resourcesTexture = resourcesBanner:CreateTexture(nil, "ARTWORK")
        resourcesTexture:SetTexture(RESOURCES_BUTTON_TEXTURE)
        resourcesTexture:SetAlpha(RESOURCES_BUTTON_TEXTURE_ALPHA)
        resourcesTexture:SetAllPoints(resourcesBanner)

        local firstBtn = CreateFrame("Button", nil, resourcesBanner, "UIPanelButtonTemplate")
        firstBtn:SetText("")
        SkinGSESettingsButton(firstBtn)

        local pushedTexture = firstBtn:CreateTexture(nil, "ARTWORK")
        pushedTexture:SetAllPoints(firstBtn)
        pushedTexture:SetColorTexture(0, 0, 0, 0.25)
        firstBtn:SetPushedTexture(pushedTexture)

        local resourcesText = firstBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        resourcesText:SetPoint("CENTER", firstBtn, "CENTER", 0, 1)
        resourcesText:SetJustifyH("CENTER")
        resourcesText:SetJustifyV("MIDDLE")
        resourcesText:SetTextColor(HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B)
        resourcesText:SetShadowColor(0, 0, 0, 1)
        resourcesText:SetShadowOffset(1, -1)
        firstBtn:SetFontString(resourcesText)
        local resourcesFont, resourcesFontSize, resourcesFontFlags = resourcesText:GetFont()
        local function SetResourcesButtonText(isHover)
            resourcesText:SetFont(resourcesFont, resourcesFontSize * (isHover and RESOURCES_BUTTON_TEXT_HOVER_SCALE or RESOURCES_BUTTON_TEXT_SCALE), resourcesFontFlags)
            resourcesText:ClearAllPoints()
            resourcesText:SetPoint("CENTER", firstBtn, "CENTER", 0, 1)
            resourcesText:SetText(isHover and RESOURCES_BUTTON_TEXT_HOVER or RESOURCES_BUTTON_TEXT)
        end

        SetResourcesButtonText(false)
        local normalTextWidth = resourcesText:GetStringWidth() or 0
        SetResourcesButtonText(true)
        local hoverTextWidth = resourcesText:GetStringWidth() or normalTextWidth
        local resourcesButtonWidth = math.max(RESOURCES_BUTTON_MIN_WIDTH, math.ceil(math.max(normalTextWidth, hoverTextWidth) + RESOURCES_BUTTON_TEXT_HORIZONTAL_PADDING))
        local resourcesButtonHeight = math.min(resourcesBannerHeight, math.max(28, math.ceil(resourcesFontSize * RESOURCES_BUTTON_TEXT_HOVER_SCALE + RESOURCES_BUTTON_TEXT_VERTICAL_PADDING)))
        firstBtn:SetSize(resourcesButtonWidth, resourcesButtonHeight)
        firstBtn:SetPoint("CENTER", resourcesBanner, "CENTER", 0, 0)
        SetResourcesButtonText(false)
        firstBtn:SetScript("OnEnter", function()
            SetResourcesButtonText(true)
        end)
        firstBtn:SetScript("OnLeave", function()
            SetResourcesButtonText(false)
        end)
        firstBtn:SetScript("OnClick", function()
            -- Open the floating Resources popup directly. (Previously this
            -- routed through the Settings panel's Resources subcategory,
            -- but that subcategory was removed once the popup itself was
            -- pinned to TOOLTIP strata and reliably draws above the Settings
            -- panel — the popup is now the single source of truth for
            -- Resources, so there's no longer a reason to detour through
            -- a Settings canvas.)
            ShowResourcesPopupFromOptions(firstBtn)
        end)

        -- Supporters section (anchored to first button's bottom-left, not last)
        local supHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        supHeader:SetPoint("TOPLEFT", resourcesBanner, "BOTTOMLEFT", 0, -padding)
        supHeader:SetTextColor(HEADER_GOLD_R, HEADER_GOLD_G, HEADER_GOLD_B)
        supHeader:SetText(L["Supporters"])

        local supDesc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        supDesc:SetWidth(cw - padding * 2)
        supDesc:SetJustifyH("LEFT")
        supDesc:SetWordWrap(true)
        supDesc:SetPoint("TOPLEFT", supHeader, "BOTTOMLEFT", 0, -8)
        supDesc:SetText(L["The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."])

        local patronList = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        patronList:SetWidth(cw - padding * 2)
        patronList:SetJustifyH("LEFT")
        patronList:SetWordWrap(true)
        patronList:SetPoint("TOPLEFT", supDesc, "BOTTOMLEFT", 0, -6)
        patronList:SetText(table.concat(Statics.Patrons, ", "))

        local function stringHeight(fontString, fallback)
            local height = fontString and fontString.GetStringHeight and fontString:GetStringHeight()
            return (height and height > 0) and height or fallback
        end

        local contentHeight =
            padding + 120 + padding +
            stringHeight(versionHeader, 18) + 6 +
            stringHeight(versionText, 14) + padding +
            resourcesButtonHeight + padding +
            stringHeight(supHeader, 18) + 8 +
            stringHeight(supDesc, 14) + 6 +
            stringHeight(patronList, 14) + padding
        content:SetHeight(math.max(1, contentHeight))
    end)

    return panel
end

-- =========================================================================
-- SECTION 7 -- Sub-page builders: Windows & Layout, Tools & Diagnostics, Plugins
--
-- createBlizzOptions registers the three vertical-layout subcategories
-- that hang off the main GSE entry:
--   * Windows & Layout -- Toolbar / Editor scale, Debug window size,
--     watermark toggle, button-behaviour CVar (ActionButtonUseKeyDown),
--     MS Click Timing, Companion App, Import & Export defaults, Editor
--     sequence-list filters, and the GSE Toolbar / Editor open
--     buttons.
--   * Tools & Diagnostics -- the "Modifier Hold to Pause" section
--     (added in upstream 3.3.19-10), Spell Cache controls, Tracker /
--     Keybind Diagnostics with the sequence icon frame and successful
--     cast frame toggles, master tracker enable, and the Plugins
--     sub-subcategory for any registered plugins.
--   * Plugins -- placeholder list, populated by GSE.RegisterPlugin
--     calls from external addons; shows "No plugins are currently
--     registered." when empty.
-- =========================================================================

local function createBlizzOptions(category, pluginOptions, colourOptions)
    local windowOptions = Settings.RegisterVerticalLayoutSubcategory(category, "Windows & Layout")
    local troubleOptions = Settings.RegisterVerticalLayoutSubcategory(category, "Tools & Diagnostics")
    AttachTrackerDefaultsHandler(troubleOptions)
    local debugOptions = GSE.Developer and Settings.RegisterVerticalLayoutSubcategory(troubleOptions, "Developer Debug") or nil
    colourOptions = colourOptions or Settings.RegisterVerticalLayoutSubcategory(troubleOptions, "Text Colors")
    pluginOptions = pluginOptions or Settings.RegisterVerticalLayoutSubcategory(category, L["Plugins"])

    -- ---------------------------------------------------------------------
    -- 7.1 - Tools & Diagnostics subcategory body (troubleshooting controls)
    --
    -- Populates the "Tools & Diagnostics" left-rail entry with the
    -- following groups in order: Modifier Hold to Pause (Shift / Alt /
    -- Ctrl checkboxes), Spell Cache, Tracker / Keybind Diagnostics
    -- (sequence icon frame + successful cast frame toggles, master
    -- tracker enable, Linked checkbox, the various Lock checkboxes),
    -- and a per-sequence reset list (one row per loaded sequence).
    -- ---------------------------------------------------------------------
    -- Troubleshooting
    do
        -- Modifier-held pause toggles. The reload prompt is required: the
        -- value is read inside a secure OnClick handler attribute that's
        -- stamped at button-build time, so a live toggle only takes effect
        -- after CreateGSE3Button reruns (which happens on UI reload).
        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "Modifier Hold to Pause", tooltip = L["When enabled, holding the matching modifier sends an empty macro instead of advancing the sequence step."]}))
        end
        do
            local function GetValue() return GSEOptions.ShiftPause == true end
            local function SetValue(val)
                GSEOptions.ShiftPause = val
                StaticPopup_Show("GSE_ConfirmReloadUIDialog")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "pauseOnShift", Settings.VarType.Boolean, L["Pause Sequences While Shift Is Held"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["When enabled, holding Shift makes GSE send an empty macro and stops the sequence from advancing until Shift is released."])
        end
        do
            local function GetValue() return GSEOptions.AltPause == true end
            local function SetValue(val)
                GSEOptions.AltPause = val
                StaticPopup_Show("GSE_ConfirmReloadUIDialog")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "pauseOnAlt", Settings.VarType.Boolean, L["Pause Sequences While Alt Is Held"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["When enabled, holding Alt makes GSE send an empty macro and stops the sequence from advancing until Alt is released."])
        end
        do
            local function GetValue() return GSEOptions.CtrlPause == true end
            local function SetValue(val)
                GSEOptions.CtrlPause = val
                StaticPopup_Show("GSE_ConfirmReloadUIDialog")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "pauseOnCtrl", Settings.VarType.Boolean, L["Pause Sequences While Ctrl Is Held"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["When enabled, holding Ctrl makes GSE send an empty macro and stops the sequence from advancing until Ctrl is released."])
        end
        do
            -- Section header so the spell-translation control reads as its own
            -- group, between "Modifier Hold to Pause" and "Spell Cache".
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "Spell Translations", tooltip = L["How the macro editor turns spell IDs into spell names as you edit."]}))
        end
        do
            -- Delayed spell translation toggle (GSEOptions.DelayedSpellTranslations),
            -- read live by the editor via GSE.ShouldTranslateLive() (no reload):
            --   off (default) - translate/colour live as you type while editing.
            --   on            - always defer translation to focus-loss, to reduce
            --     editor lag on older machines.
            -- The authored macro is always stored as you type either way; only the
            -- derived translation/colouring is deferred. Editor only - nothing is
            -- translated during normal gameplay.
            local function GetValue() return GSEOptions.DelayedSpellTranslations == true end
            local function SetValue(val) GSEOptions.DelayedSpellTranslations = val end
            local setting = Settings.RegisterProxySetting(troubleOptions, "delayedSpellTranslations", Settings.VarType.Boolean, L["Delayed Spell Translations"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Delay spell translations to reduce lag for users with older machines. When on, the macro editor waits until you click out of a box to translate and colour spell IDs and names instead of doing it as you type. Off by default (live as you type while editing). This only affects the editor; nothing is translated during normal gameplay."])
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "Spell Cache", tooltip = L["Common Solutions to game quirks that seem to affect some people."]}))
        end
        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(CreateGSESettingsLabelButtonInitializer(
                troubleOptions,
                "gseClearSpellCache",
                L["Clear Spell Cache"],
                "Clear",
                function()
                    GSESpellCache = {}
                    GSESpellCache["enUS"] = {}
                    if GSE.isEmpty(GSESpellCache[GetLocale()]) then
                        GSESpellCache[GetLocale()] = {}
                    end
                end,
                L["This function will clear the spell cache and any mappings between individual spellIDs and spellnames."]
            ))
        end
        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(CreateGSESettingsLabelButtonInitializer(
                troubleOptions,
                "gseEditSpellCache",
                L["Edit Spell Cache"],
                L["Edit"],
                function()
                    local loaded = GSE.CheckGUI()
                    if (loaded or GSE.UnsavedOptions["GUI"]) and GSE.GUIShowSpellCacheWindow then
                        GSE.GUIShowSpellCacheWindow()
                    else
                        GSE.Print(L["The GSE_GUI Module needs to be enabled to edit the spell cache."], L["Options"])
                    end
                end,
                L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."]
            ))
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "Tracker / Keybind Diagnostics", tooltip = L["Keybinding Tools"]}))
        end
        do
            local function GetValue()
                return EnsureSequenceIconFrameOptions().Enabled
            end
            local function SetValue(val)
                local opts = EnsureSequenceIconFrameOptions()
                opts.Enabled = val == true
                if GSE.SetSequenceIconFrameEnabled then
                    GSE.SetSequenceIconFrameEnabled(opts.Enabled)
                elseif GSE.SequenceIconFrame then
                    if opts.Enabled then
                        GSE.SequenceIconFrame:Show()
                    else
                        GSE.SequenceIconFrame:Hide()
                    end
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSequenceIcons", Settings.VarType.Boolean, "Tracker On / Off", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Master on/off switch for the GSE Tracker (sequence icons, text panel, successful cast, assisted highlight). Turning this off hides every tracker frame.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().SingleIcon == true end
            local function SetValue(val)
                local opts = EnsureSequenceIconFrameOptions()
                opts.SingleIcon = val == true
                if opts.SingleIcon and opts.IconCount and opts.IconCount > 1 then
                    if GSE.SetSequenceIconFrameIconCount then
                        GSE.SetSequenceIconFrameIconCount(1)
                    else
                        opts.IconCount = 1
                    end
                end
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "trackerSingleIcon", Settings.VarType.Boolean, "Single Icon", false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Lock the Tracker preview to a single icon (the next upcoming spell). When OFF the preview shows up to 10 icons.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().PreserveScaleOnZoom == true end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().PreserveScaleOnZoom = val == true
                if GSE.SequenceIconApplyTrackerFrameScale then GSE.SequenceIconApplyTrackerFrameScale() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "trackerPreserveScaleOnZoom", Settings.VarType.Boolean, "Preserve Scale On Zoom", false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "When the Tracker Frame Scale slider changes, keep each tracker frame centred on its current on-screen position instead of letting it shift. Off uses the default scale-only behaviour.")
        end
        do
            local function GetValue()
                return EnsureSequenceIconFrameOptions().ShowSuccessfulCasts
            end
            local function SetValue(val)
                local opts = EnsureSequenceIconFrameOptions()
                opts.ShowSuccessfulCasts = val == true
                if GSE.SetSuccessfulCastFrameEnabled then
                    GSE.SetSuccessfulCastFrameEnabled(opts.ShowSuccessfulCasts)
                elseif GSE.SuccessfulCastFrame then
                    if opts.ShowSuccessfulCasts then
                        GSE.SuccessfulCastFrame:Show()
                    else
                        GSE.SuccessfulCastFrame:Hide()
                    end
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSuccessfulCasts", Settings.VarType.Boolean, "GSE Successful Casts", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the assisted highlight icon and the successful cast icon.")
        end
        do
            local function GetValue()
                local opts = EnsureSequenceIconFrameOptions()
                return opts.ShowTrackerText ~= false
            end
            local function SetValue(val)
                local opts = EnsureSequenceIconFrameOptions()
                opts.ShowTrackerText = val == true
                if GSE.SetSequenceIconTextFrameEnabled then
                    GSE.SetSequenceIconTextFrameEnabled(opts.ShowTrackerText)
                elseif GSE.SequenceIconTextFrame then
                    if opts.ShowTrackerText and opts.Enabled then
                        GSE.SequenceIconTextFrame:Show()
                    else
                        GSE.SequenceIconTextFrame:Hide()
                    end
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showTrackerText", Settings.VarType.Boolean, "GSE Tracker Text", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Tracker text panel (Status / Sequence Name / Activation Key / ModKey / Casts / Step / Blk / Hardware Events).")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowSequenceName ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowSequenceName = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSequenceName", Settings.VarType.Boolean, "Sequence Name", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Sequence Name line in the Tracker text panel.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowHardwareEvents ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowHardwareEvents = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showHardwareEvents", Settings.VarType.Boolean, "Hardware Events", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Hardware Events line (mouse buttons / modifier keys that are currently TRUE) in the Tracker text panel.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowActivationKey ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowActivationKey = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showActivationKey", Settings.VarType.Boolean, "Activation Key", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Activation Key line (the spam key registered for this sequence) in the Tracker text panel.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowClientModKey ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowClientModKey = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showClientModKey", Settings.VarType.Boolean, "Client ModKey", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Client ModKey line (modifier keys the client passed to the sequence at click time) in the Tracker text panel.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowBlock ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowBlock = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showBlock", Settings.VarType.Boolean, "Block", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Block line (last sequence block path executed) in the Tracker text panel.")
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().ShowStep ~= false end
            local function SetValue(val)
                EnsureSequenceIconFrameOptions().ShowStep = val == true
                if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showStep", Settings.VarType.Boolean, "Step", true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, "Show the Step line (last sequence step index executed) in the Tracker text panel.")
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(CreateGSESettingsLabelButtonInitializer(
                troubleOptions,
                "gseSwapLayout",
                "Swap Layout X / Y",
                "Swap",
                function()
                    if GSE.SequenceIconSwapTrackerLayout then
                        GSE.SequenceIconSwapTrackerLayout()
                    end
                end,
                "Toggle between Tracker Layout X and Layout Y in one click. If the target slot is empty, captures the current positions into it."
            ))
        end

        do
            local function GetValue() return GSEOptions.DebugPrintModConditionsOnKeyPress end
            local function SetValue(val)
                GSEOptions.DebugPrintModConditionsOnKeyPress = val
                GSE.GUICall("GUIConfirmReloadUI")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "printKeyPressModifiers", Settings.VarType.Boolean, L["Print Active Modifiers on Click"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."])
        end
        do
            local function GetValue() return EnsureSequenceIconFrameOptions().IconCount end
            local function SetValue(val)
                if GSE.SetSequenceIconFrameIconCount then
                    GSE.SetSequenceIconFrameIconCount(val)
                else
                    EnsureSequenceIconFrameOptions().IconCount = ClampNumber(val, 1, 10, 10)
                    if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "iconPreviewCount", Settings.VarType.Number, "Preview Icon Count", 10, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(1, 10, 1)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(troubleOptions, setting, options, "How many recent sequence icons to keep visible.")
        end
        -- Tracker Frame Scale: scales the three on-screen tracker frames
        -- (SC Icon, Sequence Icon Scroll, Tracker Text) together as one
        -- group. Independent of GSE Editor Scale. Range 0.50 -- 1.50 (1.00 centered).
        do
            local MIN_TRK = 0.50
            local MAX_TRK = 1.50
            local function GetValue()
                return GSE.SequenceIconGetTrackerFrameScale and GSE.SequenceIconGetTrackerFrameScale() or 1
            end
            local function SetValue(value)
                if GSE.SequenceIconSetTrackerFrameScale then
                    GSE.SequenceIconSetTrackerFrameScale(value)
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "gseTrackerFrameScale", Settings.VarType.Number, "Tracker Frame Scale", 1.0, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(MIN_TRK, MAX_TRK)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string.format("%.2f", math.max(MIN_TRK, math.min(MAX_TRK, value)))
            end)
            Settings.CreateSlider(troubleOptions, setting, options, "Scale the SC Icon, Sequence Icon Scroll, and Tracker Text frames together. Does not affect the GSE editor windows.")
        end
    end


    -- Colour
    do
        local function colourByte(value)
            value = tonumber(value) or 0
            return math.max(0, math.min(255, math.floor((value * 255) + 0.5)))
        end

        -- r,g,b (0-1) → |cffRRGGBB
        local function toHex(r, g, b)
            return string.format("|c%02x%02x%02x%02x", 255, colourByte(r), colourByte(g), colourByte(b))
        end

        -- Label text rendered in its own colour — acts as the swatch
        local function colouredLabel(label, r, g, b)
            label = label == nil and "" or tostring(label)
            return string.format("|cff%02x%02x%02x%s|r", colourByte(r), colourByte(g), colourByte(b), label)
        end

        local colours = {
            { header = "General Text" },
            { label = L["Title Colour"],              desc = L["Picks a Custom Colour for the Mod Names."],
              get = function() return GSE.GUIGetColour(GSEOptions.TitleColour) end,
              set = function(r,g,b) GSEOptions.TitleColour    = toHex(r,g,b) end },
            { label = L["Info Colour"],               desc = L["Picks a Custom Colour for informational and debug output."],
              get = function() return GSE.GUIGetColour(GSEOptions.AuthorColour) end,
              set = function(r,g,b) GSEOptions.AuthorColour   = toHex(r,g,b) end },
            { label = L["Command Colour"],            desc = L["Picks a Custom Colour for the Commands."],
              get = function() return GSE.GUIGetColour(GSEOptions.CommandColour) end,
              set = function(r,g,b) GSEOptions.CommandColour  = toHex(r,g,b) end },
            { label = L["Emphasis Colour"],           desc = L["Picks a Custom Colour for emphasis."],
              get = function() return GSE.GUIGetColour(GSEOptions.EmphasisColour) end,
              set = function(r,g,b) GSEOptions.EmphasisColour = toHex(r,g,b) end },
            { label = L["Normal Colour"],             desc = L["Picks a Custom Colour to be used normally."],
              get = function() return GSE.GUIGetColour(GSEOptions.NormalColour) end,
              set = function(r,g,b) GSEOptions.NormalColour   = toHex(r,g,b) end },
            { header = "Macro Editor Syntax" },
            { label = L["Slash Commands"],            desc = L["Picks a Custom Colour for WoW macro slash commands like /cast and /use."],
              get = function() return GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS) end,
              set = function(r,g,b) GSEOptions.WOWSHORTCUTS   = toHex(r,g,b) end },
            { label = L["Modifiers & Functions"],     desc = L["Picks a Custom Colour for conditional modifiers and standard functions."],
              get = function() return GSE.GUIGetColour(GSEOptions.STANDARDFUNCS) end,
              set = function(r,g,b) GSEOptions.STANDARDFUNCS  = toHex(r,g,b) end },
            { label = L["Conditionals & Comments"],   desc = L["Picks a Custom Colour for macro conditionals eg [mod:shift] and comments."],
              get = function() return GSE.GUIGetColour(GSEOptions.COMMENT) end,
              set = function(r,g,b) GSEOptions.COMMENT        = toHex(r,g,b) end },
            { label = L["Spells & Action Labels"],    desc = L["Picks a Custom Colour for spell names and action block type labels."],
              get = function() return GSE.GUIGetColour(GSEOptions.KEYWORD) end,
              set = function(r,g,b) GSEOptions.KEYWORD        = toHex(r,g,b) end },
            { label = L["Logic & Comparison"],        desc = L["Picks a Custom Colour for logic and comparison operators such as == and or."],
              get = function() return GSE.GUIGetColour(GSEOptions.EQUALS) end,
              set = function(r,g,b) GSEOptions.EQUALS         = toHex(r,g,b) end },
            { label = L["Table Operators"],           desc = L["Picks a Custom Colour for table operators such as { } and ..."],
              get = function() return GSE.GUIGetColour(GSEOptions.CONCAT) end,
              set = function(r,g,b) GSEOptions.CONCAT         = toHex(r,g,b) end },
            { label = L["Numbers & Operators"],       desc = L["Picks a Custom Colour for numbers and arithmetic operators."],
              get = function() return GSE.GUIGetColour(GSEOptions.NUMBER) end,
              set = function(r,g,b) GSEOptions.NUMBER         = toHex(r,g,b) end },
            { label = L["Bracket Operators"],         desc = L["Picks a Custom Colour for array bracket operators [ ]."],
              get = function() return GSE.GUIGetColour(GSEOptions.STRING) end,
              set = function(r,g,b) GSEOptions.STRING         = toHex(r,g,b) end },
            { label = L["Unknown Colour"],            desc = L["Picks a Custom Colour to be used for unknown terms."],
              get = function() return GSE.GUIGetColour(GSEOptions.UNKNOWN) end,
              set = function(r,g,b) GSEOptions.UNKNOWN        = toHex(r,g,b) end },
        }

        local colourInits = {}

        for _, entry in ipairs(colours) do
            if entry.header then
                do
                    local layout = SettingsPanel:GetLayout(colourOptions)
                    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
                        name = entry.header, tooltip = "",
                    }))
                end
            else
                local colEntry = entry
                do
                    local layout = SettingsPanel:GetLayout(colourOptions)
                    local r, g, b = colEntry.get()
                    local init = CreateSettingsButtonInitializer(
                        colouredLabel(colEntry.label, r, g, b),
                        L["Change"],
                        function(btnArg)
                            local btn = btnArg
                            if not btn then return end
                            local cr, cg, cb = colEntry.get()
                            local function updateLabel(nr, ng, nb)
                                local newName = colouredLabel(colEntry.label, nr, ng, nb)
                                local ci = colourInits[colEntry]
                                if ci then
                                    local d = ci:GetData()
                                    if d then d.name = newName end
                                end
                                local labelFrame = btn:GetParent()
                                if labelFrame and labelFrame.Text then
                                    labelFrame.Text:SetText(newName)
                                end
                            end
                            ColorPickerFrame:SetupColorPickerAndShow({
                                swatchFunc = function()
                                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                                    colEntry.set(nr, ng, nb)
                                    updateLabel(nr, ng, nb)
                                end,
                                cancelFunc = function(prev)
                                    colEntry.set(prev.r, prev.g, prev.b)
                                    updateLabel(prev.r, prev.g, prev.b)
                                end,
                                r = cr, g = cg, b = cb,
                                hasOpacity = false,
                            })
                        end,
                        colEntry.desc,
                        false
                    )
                    colourInits[colEntry] = init
                    layout:AddInitializer(init)
                end
            end
        end
    end

    -- ---------------------------------------------------------------------
    -- 7.2 - Plugins subcategory body
    --
    -- Populates the "Plugins" left-rail entry. Lists any plugins
    -- registered via GSE.RegisterPlugin / GSE.AddInPacks; renders
    -- "No plugins are currently registered." if empty. Plugin names
    -- come from the registration table; nothing is hard-coded here.
    -- ---------------------------------------------------------------------
    -- Plugins
    do
        do
            local layout = SettingsPanel:GetLayout(pluginOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Registered Addons"], tooltip = L["GSE Plugins"]}))
        end
        if GSE.isEmpty(GSE.AddInPacks) then
            do
                local layout = SettingsPanel:GetLayout(pluginOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["No plugins are currently registered."], tooltip = ""}))
            end
        else
            for _, v in pairs(GSE.AddInPacks) do
                local packName = v.Name
                local displayName = C_AddOns.GetAddOnMetadata(packName, "Title") or packName
                local desc = C_AddOns.GetAddOnMetadata(packName, "Notes") or
                    string.format(L["Addin Version %s contained versions for the following sequences:"], packName) ..
                    string.format("\n%s", FormatSequenceNames(v.SequenceNames))
                local layout = SettingsPanel:GetLayout(pluginOptions)
                local capturedPackName = packName
                local capturedV = v

                -- Section header per plugin so each one is visually separated.
                -- This also acts as the closing boundary for the previous plugin's
                -- individual sequence items, preventing them from bleeding into the
                -- next plugin's Reload All button.
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
                    name = displayName,
                    tooltip = desc,
                }))

                layout:AddInitializer(CreateSettingsButtonInitializer(
                    L["Reload All"],
                    L["Reload All"],
                    function()
                        if capturedV.Sequences then
                            GSE.LoadPluginSequences(capturedV.Sequences)
                        else
                            GSE:SendMessage(Statics.ReloadMessage, capturedPackName)
                        end
                    end,
                    desc,
                    false
                ))

                -- Per-sequence restore buttons (only available when the plugin passes its Sequences table)
                if not GSE.isEmpty(v.Sequences) and v.SequenceNames then
                    for _, seqName in ipairs(v.SequenceNames) do
                        local encodedSeq = v.Sequences[seqName]
                        local status = GSE.GetPluginSequenceStatus(encodedSeq)

                        local compatText
                        if status.compatible then
                            compatText = L["Compatible with this version of GSE"]
                        else
                            local verStr = status.GSEVersion and tostring(status.GSEVersion) or L["unknown"]
                            compatText = string.format(L["Not compatible with this version of GSE (sequence version: %s)"], verStr)
                        end

                        local checksumText
                        if status.checksum == "valid" then
                            checksumText = L["Checksum valid"]
                        elseif status.checksum == "invalid" then
                            checksumText = L["Checksum invalid - sequence may have been modified"]
                        else
                            checksumText = L["No checksum"]
                        end

                        local seqDesc = compatText .. "\n" .. checksumText
                        local capturedSeqName = seqName
                        layout:AddInitializer(CreateSettingsButtonInitializer(
                            capturedSeqName,
                            L["Restore"],
                            function()
                                local seq = capturedV.Sequences and capturedV.Sequences[capturedSeqName]
                                if seq then
                                    GSE.ImportSerialisedSequence(seq, false)
                                    GSE.PerformReloadSequences()
                                end
                            end,
                            seqDesc,
                            false
                        ))
                    end
                end
            end
        end
    end

    -- ---------------------------------------------------------------------
    -- 7.3 - Windows & Layout subcategory body (frame positioning + toolbar)
    --
    -- Populates the "Windows & Layout" left-rail entry. Composed by
    -- calling the Add* option group builders defined in Section 4
    -- (AddAppearanceOptions, AddDebuggerWindowSizeOptions, etc.) for
    -- the upper rows, then renders the GSE Toolbar section with the
    -- ON/OFF toggle, scale slider, grow-direction dropdown, Static /
    -- Slide Out mode, Lock Toolbar Position, and the Sequence Editor
    -- open button row. This is the longest subcategory in the panel.
    -- ---------------------------------------------------------------------
    -- Frame Locations
    do
        AddAppearanceOptions(windowOptions)

        do
            local layout = SettingsPanel:GetLayout(windowOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = "GSE " .. L["Toolbar"], tooltip = "GSE " .. L["Toolbar Options"]}))
        end
        do
            -- 0. Toolbar ON / OFF — primary kill-switch for the toolbar.
            -- When OFF, /gse opens the Sequence Editor instead of the toolbar
            -- (see Utils.lua's GSSlash default branch). Label swaps between
            -- "GSE Toolbar ON" / "GSE Toolbar OFF" so the current state is
            -- always self-describing.
            local setting  -- forward-declared for SetValue's SetName call
            local function getLabel()
                local on = (GSEOptions.ToolbarEnabled ~= false)
                return on and "GSE Toolbar ON" or "GSE Toolbar OFF"
            end
            local function GetValue()
                return GSEOptions.ToolbarEnabled ~= false
            end
            local function SetValue(val)
                GSEOptions.ToolbarEnabled = val and true or false
                if val then
                    -- GSE_GUI is LoadOnDemand and owns GSE.ShowMenu / GSE.MenuFrame.
                    -- On a session where the Toolbar started OFF, GSE_GUI is not
                    -- loaded yet, so GSE.ShowMenu would be nil and the toggle would
                    -- flip to ON without the Toolbar ever appearing (and without
                    -- setting menu.open, so it would not return on next login
                    -- either). Force-load it first, the same way /gse toolbar does.
                    if GSE.CheckGUI then GSE.CheckGUI() end
                    -- Turned ON: bring up the toolbar immediately so the user
                    -- sees the result of toggling on. GSE.ShowMenu sets
                    -- menu.open = true so the toolbar also auto-shows on next
                    -- login.
                    if GSE.ShowMenu then GSE.ShowMenu() end
                else
                    -- Turned OFF: hide the toolbar live if visible and clear
                    -- the persisted open flag so it won't auto-show on login.
                    if GSE.MenuFrame and GSE.MenuFrame:IsShown() then
                        GSE.MenuFrame:Hide()
                    end
                    if GSEOptions.frameLocations and GSEOptions.frameLocations.menu then
                        GSEOptions.frameLocations.menu.open = false
                    end
                end
                if setting and setting.SetName then setting:SetName(getLabel()) end
            end
            setting = Settings.RegisterProxySetting(windowOptions, "toolbarEnabled", Settings.VarType.Boolean,
                getLabel(), true, GetValue, SetValue)
            Settings.CreateCheckbox(windowOptions, setting,
                "When ON, /gse opens the GSE Toolbar (the floating menu of icons). When OFF, /gse opens the Sequence Editor directly.")
        end
        do
            -- 1. Strata dropdown: how the toolbar layers against other UI.
            -- Same backing storage as the right-click submenu (GSE.SetMenuStrata).
            local STRATA_OPTIONS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
            local function GetValue()
                local s = GSEOptions.frameLocations and GSEOptions.frameLocations.menu and GSEOptions.frameLocations.menu.strata
                for _, v in ipairs(STRATA_OPTIONS) do
                    if s == v then return s end
                end
                return "MEDIUM"
            end
            local function SetValue(val)
                if GSE.SetMenuStrata then GSE.SetMenuStrata(val) end
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "menuStrata", Settings.VarType.String, L["Strata"], "MEDIUM", GetValue, SetValue)
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add("BACKGROUND", L["Background"] or "Background")
                container:Add("LOW",        L["Low"]        or "Low")
                container:Add("MEDIUM",     L["Medium"]     or "Medium  (default)")
                container:Add("HIGH",       L["High"]       or "High")
                container:Add("DIALOG",     L["Dialog"]     or "Dialog")
                return container:GetData()
            end
            Settings.CreateDropdown(windowOptions, setting, GetOptions, "Frame strata controls how the toolbar layers against other UI elements.")
        end
        do
            -- 2. Growth Direction dropdown.
            local function GetValue()
                local d = GSEOptions.frameLocations and GSEOptions.frameLocations.menu and GSEOptions.frameLocations.menu.direction
                return (d and d ~= "") and d or "DOWN"
            end
            local function SetValue(val)
                if GSE.UpdateMenuDirection then GSE.UpdateMenuDirection(val) end
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "menuDirection", Settings.VarType.String, L["Growth Direction"], "DOWN", GetValue, SetValue)
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add("UP",    L["Up"])
                container:Add("DOWN",  L["Down"])
                container:Add("LEFT",  L["Left"])
                container:Add("RIGHT", L["Right"])
                return container:GetData()
            end
            Settings.CreateDropdown(windowOptions, setting, GetOptions, "Direction the toolbar grows from the logo button.")
        end
        do
            -- 3. Static / Slide Out toggle — checked = Static (the default),
            -- unchecked = Slide Out (icons hidden until mouseover the logo).
            -- The label swaps between "Static Toolbar" and "Slide Out Toolbar"
            -- via setting:SetName whenever the value changes, so it always
            -- names the current mode. Same opts.mouseoverPopOut storage as the
            -- right-click menu — flipping either UI updates the other live.
            local setting  -- forward-declared so SetValue can reference it
            local function getLabel()
                local m = GSEOptions.frameLocations and GSEOptions.frameLocations.menu
                local inSlideOut = m and m.mouseoverPopOut == true
                return inSlideOut and L["Slide Out Toolbar"] or L["Static Toolbar"]
            end
            local function GetValue()
                -- Checked when Static mode is active (the default).
                local m = GSEOptions.frameLocations and GSEOptions.frameLocations.menu
                return not (m and m.mouseoverPopOut == true)
            end
            local function SetValue(val)
                -- val == true means user wants Static, so mouseoverPopOut = false.
                local frameLocations = EnsureFrameLocations()
                if GSE.isEmpty(frameLocations.menu) then frameLocations.menu = {} end
                frameLocations.menu.mouseoverPopOut = (not val) and true or false
                if GSE.RefreshMenuMouseoverState then GSE.RefreshMenuMouseoverState(true) end
                -- Swap the label to match the new mode. Some Settings panel
                -- versions repaint immediately, others on next open — either
                -- way the label is correct.
                if setting and setting.SetName then setting:SetName(getLabel()) end
            end
            setting = Settings.RegisterProxySetting(windowOptions, "menuMouseoverPopOut", Settings.VarType.Boolean,
                getLabel(), true, GetValue, SetValue)
            Settings.CreateCheckbox(windowOptions, setting,
                L["When checked, the toolbar icons stay always visible (Static Toolbar). When unchecked, icons stay hidden until you mouseover the logo, then slide out."])
        end
        do
            -- 4. Lock Toolbar Position.
            local function GetValue()
                return GSEOptions.frameLocations and GSEOptions.frameLocations.menu and GSEOptions.frameLocations.menu.locked == true
            end
            local function SetValue(val)
                local frameLocations = EnsureFrameLocations()
                if GSE.isEmpty(frameLocations.menu) then frameLocations.menu = {} end
                frameLocations.menu.locked = val
                if GSE.MenuFrame then GSE.MenuFrame:SetMovable(not val) end
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "menuLocked", Settings.VarType.Boolean, L["Lock Toolbar Position"], false, GetValue, SetValue)
            Settings.CreateCheckbox(windowOptions, setting, "Prevent the toolbar from being dragged to a new position.")
        end

        do
            local layout = SettingsPanel:GetLayout(windowOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Sequence Editor"], tooltip = L["Sequence Editor"]}))
        end
        do
            local function GetValue()
                return EnsureSequenceEditorOptions().height
            end
            local function SetValue(val)
                local se = EnsureSequenceEditorOptions()
                se.height = ClampNumber(val, MIN_EDITOR_HEIGHT, MAX_EDITOR_HEIGHT, MIN_EDITOR_HEIGHT)
                ApplySequenceEditorOptionsToCurrentEditor()
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "editorHeight", Settings.VarType.Number, L["Default Editor Height"], MIN_EDITOR_HEIGHT, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(MIN_EDITOR_HEIGHT, MAX_EDITOR_HEIGHT, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels high should the Editor start at.  Defaults to 700"])
        end
        do
            local function GetValue()
                return EnsureSequenceEditorOptions().width
            end
            local function SetValue(val)
                local se = EnsureSequenceEditorOptions()
                se.width = ClampNumber(val, MIN_EDITOR_WIDTH, GetMaxSequenceEditorWidth(), MIN_EDITOR_WIDTH)
                ApplySequenceEditorOptionsToCurrentEditor()
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "editorWidth", Settings.VarType.Number, L["Default Editor Width"], MIN_EDITOR_WIDTH, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(MIN_EDITOR_WIDTH, GetMaxSequenceEditorWidth(), 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels wide should the Editor start at.  Defaults to 1050"])
        end

        AddDebuggerWindowSizeOptions(windowOptions)
    end

    -- Debug (Developer only)
    if debugOptions then
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Debug Mode Options"], tooltip = L["Debug Mode Options"]}))
        end
        do
            local function GetValue() return GSEOptions.debug end
            local function SetValue(val)
                GSEOptions.debug = val
                GSE.PrintDebugMessage("Debug Mode Enabled", GNOME)
            end
            local setting = Settings.RegisterProxySetting(debugOptions, "enableDebugMode", Settings.VarType.Boolean, L["Enable Mod Debug Mode"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"])
        end
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Debug Output Options"], tooltip = L["Debug Output Options"]}))
        end
        do
            local function GetValue() return GSEOptions.sendDebugOutputToChatWindow end
            local function SetValue(val) GSEOptions.sendDebugOutputToChatWindow = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "debugChat", Settings.VarType.Boolean, L["Display debug messages in Chat Window"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This will display debug messages in the Chat window."])
        end
        do
            local function GetValue() return GSEOptions.sendDebugOutputToDebugOutput end
            local function SetValue(val) GSEOptions.sendDebugOutputToDebugOutput = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "storeDebugOutput", Settings.VarType.Boolean, L["Store Debug Messages"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["Store output of debug messages in a Global Variable that can be referrenced by other mods."])
        end
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Enable Debug for the following Modules"], tooltip = L["Enable Debug for the following Modules"]}))
        end
        for k, _ in pairs(Statics.DebugModules) do
            local modKey = k
            local function GetValue() return GSEOptions.DebugModules[modKey] end
            local function SetValue(val) GSEOptions.DebugModules[modKey] = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "debug_" .. modKey, Settings.VarType.Boolean, modKey, false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This will display debug messages for the "] .. modKey)
        end
    end
end

-- =========================================================================
-- SECTION 8 -- Registration / entry-point
--
-- Final wire-up: registerLegacyOptionsPanel runs at GSE init to attach
-- all the pages above to the Blizzard Settings system, capture the
-- main category ID for slash command navigation, and (if the
-- Settings API isn't available, e.g. very old clients) fall back to
-- the legacy Interface Options behaviour.
-- =========================================================================

local function registerLegacyOptionsPanel()
    local panel = createAboutPanel()
    panel.name = "GSE"
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    GSE.LegacyOptionsPanel = panel
    GSE.MenuCategoryID = panel.name
end

function GSE:CreateConfigPanels()
    if not registered then
        registered = true

        if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory and
            Settings.RegisterVerticalLayoutSubcategory and SettingsPanel) then
            registerLegacyOptionsPanel()
            return
        end

        local aboutPanel = createAboutPanel()
        local category = Settings.RegisterCanvasLayoutCategory(aboutPanel, addonName)
        AttachTrackerDefaultsHandler(category)
        Settings.RegisterAddOnCategory(category)
        GSE.MenuCategoryID = category:GetID()

        local generalOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["General"])

        local pluginOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Plugins"])
        local ResetOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Sequence Reset"])
        local importExportOptions = Settings.RegisterVerticalLayoutSubcategory(category, "Import & Export")

        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Launcher & Login" , ["tooltip"]= L["General"] }))
        end
        -- Hide Login Message
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "hideLogin", "HideLoginMessage", GSEOptions, Settings.VarType.Boolean, L["Hide Login Message"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Hides the message that GSE is loaded."])
        end
        -- Hide Minimap icon
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "minimapIcon", "hide", GSEOptions.showMiniMap, Settings.VarType.Boolean, L["Hide Minimap Icon"], true)
            setting:SetValueChangedCallback(function ()
                if GSE.LDB then
                    GSE.MiniMapControl(GSEOptions.showMiniMap.hide)
                end
            end)
            Settings.CreateCheckbox(generalOptions, setting, L["Hide Minimap Icon for LibDataBroker (LDB) data text."])
        end
        -- Show Other Users
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showothergseusersintooltip", "showGSEUsers", GSEOptions, Settings.VarType.Boolean, L["Show GSE Users in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."])
        end
        -- Show OOC Queue
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showoocqueueintooltip", "showGSEoocqueue", GSEOptions, Settings.VarType.Boolean, L["Show OOC Queue in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."])
        end
        AddActionBarClickBehaviorOptions(generalOptions)
        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Action Bar Overrides" , ["tooltip"]= "Action Bar Overrides" }))
        end
        -- Actionbar Override Popup (Retail only - Classic requires a different menu API)
        if GSE.GameMode > 10 then
            local setting = Settings.RegisterAddOnSetting(generalOptions, "actionbaroverpopup", "actionBarOverridePopup", GSEOptions, Settings.VarType.Boolean, L["Enable Actionbar Override Popup"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."])
        end
        AddActionBarWatermarkOption(generalOptions)
        AddActionBarLabelOption(generalOptions)
        AddCompanionAppOptions(importExportOptions)
        AddImportExportOptions(importExportOptions)
        AddOutOfCombatQueueOptions(generalOptions)
        AddMSClickTimingHeader(generalOptions)
        AddCharacterClickTimingOptions(generalOptions)
        AddGlobalClickTimingOptions(generalOptions)

        do
            if GSE.isEmpty(GSEOptions.MacroResetModifiers) then GSE.resetMacroResetModifiers() end

            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Out of Combat Reset", ["tooltip"] = L["Reset Sequences when out of combat"]}))
            end
            do
                if GSE.isEmpty(GSE_C) then GSE_C = {} end
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "charresetOOC", "resetOOC", GSE_C, Settings.VarType.Boolean, "This Character - Reset Sequences when out of combat", true)
                Settings.CreateCheckbox(ResetOptions, setting, "This character setting overrides the global default.")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetOOC", "resetOOC", GSEOptions, Settings.VarType.Boolean, "Global Default - Reset Sequences when out of combat", true)
                Settings.CreateCheckbox(ResetOptions, setting, "Default reset behavior used when this character does not have its own setting.")
            end

            local function AddResetOption(settingID, optionKey, label)
                label = SafeOptionText(label, optionKey)
                local setting = Settings.RegisterAddOnSetting(ResetOptions, settingID, optionKey, GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, label, false)
                setting:SetValueChangedCallback(function()
                    GSE.GUICall("GUIConfirmReloadUI")
                end)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end

            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Mouse Buttons" , ["tooltip"]= L["These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] }))
            end
            -- Reset OOC Queue
            AddResetOption("resetLeftButton", "LeftButton", L["Left Mouse Button"])
            AddResetOption("resetRightButton", "RightButton", L["Right Mouse Button"])
            AddResetOption("resetMiddleButton", "MiddleButton", L["Middle Mouse Button"])
            AddResetOption("resetButton4", "Button4", L["Mouse Button 4"])
            AddResetOption("resetButton5", "Button5", L["Mouse Button 5"])
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Alt Keys", ["tooltip"]= L["Alt Keys."] }))
            end
            AddResetOption("resetAnyAltKey", "Alt", L["Any Alt Key"])
            AddResetOption("resetLeftAltKey", "LeftAlt", L["Left Alt Key"])
            AddResetOption("resetRightAltKey", "RightAlt", L["Right Alt Key"])
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Control Keys", ["tooltip"]= L["Control Keys."] }))
            end
            AddResetOption("resetAnyControlKey", "Control", L["Any Control Key"])
            AddResetOption("resetLeftControlKey", "LeftControl", L["Left Control Key"])
            AddResetOption("resetRightControlKey", "RightControl", L["Right Control Key"])
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "Shift Keys", ["tooltip"]= L["Shift Keys."] }))
            end
            AddResetOption("resetAnyShiftKey", "Shift", L["Any Shift Key"])
            AddResetOption("resetLeftShiftKey", "LeftShift", L["Left Shift Key"])
            AddResetOption("resetRightShiftKey", "RightShift", L["Right Shift Key"])
        end

        createBlizzOptions(category, pluginOptions)

        -- Skyriding / Vehicle Keybinds subcategory is registered natively
        -- by GSE_QoL/QoL.lua via Settings.RegisterVerticalLayoutSubcategory
        -- + CreateSettingsButtonInitializer (matching the master-branch
        -- pattern that pre-dated the AceGUI removal regression). Doing it
        -- there avoids the NativeUI canvas dance we used here previously,
        -- which only rendered on first OnShow and failed to refresh the
        -- displayed binding text after a user rebound a slot.

    end

end
GSE:CreateConfigPanels()
end
table.insert(ns.deferred, setup)
