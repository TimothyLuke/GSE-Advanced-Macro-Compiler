local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local onpause = false

-- Layout / dimension constants grouped into one table. Collapsing ~36
-- file-scope locals into a single local frees register slots in this
-- chunk, which was sitting on Lua 5.1's 200-local-per-function ceiling.
local DEBUG_UI = {
    MIN_DEBUGGER_HEIGHT = 500,
    MIN_DEBUGGER_WIDTH = 800,
    MAX_DEBUGGER_HEIGHT = 2000,
    MAX_DEBUGGER_WIDTH = 3000,
    DEBUGGER_SCREEN_MARGIN = 20,
    BUTTON_WIDTH = 108,
    RESOURCE_BUTTON_WIDTH = 145,
    BUTTON_HEIGHT = 24,
    BUTTON_GAP = 6,
    FRAME_PADDING = 14,
    HEADER_HEIGHT = 24,
    HEADER_GAP = 3,
    ROW_HEIGHT = 18,
    COLUMN_GAP = 3,
    COLUMN_HANDLE_WIDTH = 8,
    COLUMN_MENU_WIDTH = 16,
    DROPDOWN_ROW_HEIGHT = 18,
    DROPDOWN_CHECK_SIZE = 14,
    DROPDOWN_TEXT_LEFT = 28,
    DROPDOWN_INSET = 10,
    DROPDOWN_PRECREATE_ROWS = 256,
    STATS_WIDGET_WIDTH = 360,
    STATS_WIDGET_MIN_WIDTH = 360,
    STATS_WIDGET_MIN_HEIGHT = 220,
    STATS_WIDGET_MAX_WIDTH = 900,
    STATS_WIDGET_MAX_HEIGHT = 1200,
    STATS_WIDGET_ROW_HEIGHT = 18,
    STATS_WIDGET_HEADER_HEIGHT = 78,
    STATS_WIDGET_VISIBLE_ROWS = 18,
    STATS_COLUMN_GAP = 6,
    STATS_WIDGET_ANCHOR_X = -4,
    HARDWARE_WIDGET_WIDTH = 360,
    HARDWARE_WIDGET_ANCHOR_X = 4,
    HARDWARE_BUTTON_WIDTH = 126,
    DEBUG_COLUMN_SCHEMA_VERSION = 4,
    DEBUGGER_DEFAULT_STRATA = "MEDIUM",
}
GSE.DEBUGGER_SIDE_SNAP_TOLERANCE = 28
GSE.DEBUG_CLOSE_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\close.png"
GSE.DEBUG_MINIMIZE_UP_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\minimizearrowup.png"
GSE.DEBUG_MINIMIZE_DOWN_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\minimizearrowdown.png"

local DEFAULT_DEBUG_COLUMNS = {
    {label = "Timestamp", width = 76, min = 65},
    {label = "Step", width = 40, min = 34},
    {label = "Block", width = 64, min = 42},
    {label = "Sequence", width = 104, min = 70},
    {label = "GCD Status", width = 76, min = 60},
    {label = "Action / Spellbook", width = 204, min = 130},
    {label = "Castable", width = 76, min = 60},
    {label = "Resources", width = 90, min = 70},
    {label = "Casting", width = 112, min = 75}
}
-- "Suggested - Spell Assist" is the Assisted-Highlight recommendation, which
-- only exists on Retail builds that expose C_AssistedCombat. Gate the column
-- here so MoP-Classic / Anniversary / etc. don't render an empty column.
-- Keep this in sync with GSE.SequenceDebugColumns the same way.
if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
    DEFAULT_DEBUG_COLUMNS[#DEFAULT_DEBUG_COLUMNS + 1] = {label = "Suggested - Spell Assist", width = 150, min = 110}
end

function GSE.DebugUsesModernSkin()
    -- When an external skin provider (ElvUI / EllesmereUI) is active we want
    -- the debugger's in-file dark-fill button system to kick in instead of
    -- the buttons falling back to Blizzard's red UIPanelButtonTemplate. The
    -- external provider's painters layer on top via Skin.Button calls added
    -- to each button site below.
    if GSE.Skin and GSE.Skin.IsExternalProviderActive and GSE.Skin.IsExternalProviderActive() then
        return true
    end
    return (GSE.ShouldUseModernSkin and GSE.ShouldUseModernSkin()) or
        (GSE.ShouldUseElvUISkin and GSE.ShouldUseElvUISkin())
end

function GSE.GetDebugButtonTextColor()
    if GSE.ShouldUseModernCustomColor and GSE.ShouldUseModernCustomColor() and GSE.GetModernCustomColor then
        return GSE.GetModernCustomColor(1)
    end
    if GSE.ShouldUseModernClassColors and GSE.ShouldUseModernClassColors() and UnitClass then
        local localizedClass, classFile = UnitClass("player")
        classFile = classFile or localizedClass
        if type(classFile) == "string" then classFile = classFile:upper():gsub("%s+", "") end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if not color then
            color = ({
                DEATHKNIGHT = {0.77, 0.12, 0.23, 1},
                DEMONHUNTER = {0.64, 0.19, 0.79, 1},
                DRUID = {1.00, 0.49, 0.04, 1},
                EVOKER = {0.20, 0.58, 0.50, 1},
                HUNTER = {0.67, 0.83, 0.45, 1},
                MAGE = {0.25, 0.78, 0.92, 1},
                MONK = {0.00, 1.00, 0.59, 1},
                PALADIN = {0.96, 0.55, 0.73, 1},
                PRIEST = {1.00, 1.00, 1.00, 1},
                ROGUE = {1.00, 0.96, 0.41, 1},
                SHAMAN = {0.00, 0.44, 0.87, 1},
                WARLOCK = {0.53, 0.53, 0.93, 1},
                WARRIOR = {0.78, 0.61, 0.43, 1}
            })[classFile]
        end
        if color then return {color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1} end
    end
    if GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin() then return {0.92, 0.92, 0.92, 1} end
    return nil
end

function GSE.SetDebugControlTextureState(texture, active)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(not active) end
    if texture.SetVertexColor then
        if active then
            texture:SetVertexColor(1, 1, 1, 1)
        else
            texture:SetVertexColor(0.36, 0.36, 0.36, 0.78)
        end
    end
end

function GSE.GetDebugControlTexture(texturePath, useModern)
    -- Always returns the colored texture; subduing for Modern skin is now done
    -- at runtime in SetDebugControlTextureState (SetDesaturated + dark grey tint).
    -- The useModern arg is kept for backwards-compatibility with existing callers.
    return texturePath
end

function GSE.StyleDebugIconButton(button, texturePath, useModern)
    if not button then return end
    texturePath = GSE.GetDebugControlTexture(texturePath, useModern)
    button:SetNormalTexture(texturePath)
    button:SetPushedTexture(texturePath)
    button:SetHighlightTexture(texturePath, useModern and "BLEND" or "ADD")
    if useModern then
        GSE.SetDebugControlTextureState(button:GetNormalTexture(), false)
        GSE.SetDebugControlTextureState(button:GetPushedTexture(), true)
        GSE.SetDebugControlTextureState(button:GetHighlightTexture(), true)
        if not button.GSEDebugIconStateHooked and button.HookScript then
            button.GSEDebugIconStateHooked = true
            button:HookScript("OnEnter", function(self) if self.GSEDebugOverlayTexture then GSE.SetDebugControlTextureState(self.GSEDebugOverlayTexture, true) end end)
            button:HookScript("OnLeave", function(self) if self.GSEDebugOverlayTexture then GSE.SetDebugControlTextureState(self.GSEDebugOverlayTexture, false) end end)
            button:HookScript("OnMouseDown", function(self) if self.GSEDebugOverlayTexture then GSE.SetDebugControlTextureState(self.GSEDebugOverlayTexture, true) end end)
            button:HookScript("OnMouseUp", function(self) if self.GSEDebugOverlayTexture then GSE.SetDebugControlTextureState(self.GSEDebugOverlayTexture, self.IsMouseOver and self:IsMouseOver()) end end)
        end
    end
    if button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAlpha(useModern and 1 or 0.35)
    end
end

function GSE.UpdateDebugTextButtonState(button, hovered)
    if not button then return end

    local enabled = not (button.IsEnabled and not button:IsEnabled())

    if button.GSEDebugButtonFill then
        if enabled then
            if hovered then
                button.GSEDebugButtonFill:SetColorTexture(0.10, 0.10, 0.10, 0.96)
            else
                button.GSEDebugButtonFill:SetColorTexture(0.055, 0.055, 0.055, 0.92)
            end
        else
            button.GSEDebugButtonFill:SetColorTexture(0.035, 0.035, 0.035, 0.72)
        end

        if button.GSEDebugButtonBorderTop then
            local shade = enabled and 0.18 or 0.08
            button.GSEDebugButtonBorderTop:SetColorTexture(shade, shade, shade, 1)
            button.GSEDebugButtonBorderBottom:SetColorTexture(shade, shade, shade, 1)
            button.GSEDebugButtonBorderLeft:SetColorTexture(shade, shade, shade, 1)
            button.GSEDebugButtonBorderRight:SetColorTexture(shade, shade, shade, 1)
        end
    end

    local text = button.GetFontString and button:GetFontString()
    if text and text.SetTextColor then
        if not enabled then
            text:SetTextColor(0.45, 0.45, 0.45, 1)
        else
            local color = GSE.GetDebugButtonTextColor and GSE.GetDebugButtonTextColor()
            if color then
                text:SetTextColor(unpack(color))
            elseif not (GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin()) then
                text:SetTextColor(1, 0.82, 0, 1)
            end
        end
    end
end

function GSE.StyleDebugTextButton(button)
    if not button then return end
    local useModern = GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin()

    if button.GetRegions then
        for _, region in ipairs({button:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.SetAlpha and not region.GSEDebugOwned then
                region:SetAlpha(useModern and 0 or 1)
            end
        end
    end

    if not useModern then
        if button.GSEDebugButtonFill then button.GSEDebugButtonFill:Hide() end
        if button.GSEDebugButtonBorderTop then button.GSEDebugButtonBorderTop:Hide() end
        if button.GSEDebugButtonBorderBottom then button.GSEDebugButtonBorderBottom:Hide() end
        if button.GSEDebugButtonBorderLeft then button.GSEDebugButtonBorderLeft:Hide() end
        if button.GSEDebugButtonBorderRight then button.GSEDebugButtonBorderRight:Hide() end
        if not button.GSEDebugTextButtonHooked and button.HookScript then
            button.GSEDebugTextButtonHooked = true
            button:HookScript("OnEnter", function(self) GSE.UpdateDebugTextButtonState(self, true) end)
            button:HookScript("OnLeave", function(self) GSE.UpdateDebugTextButtonState(self, false) end)
            button:HookScript("OnEnable", function(self) GSE.UpdateDebugTextButtonState(self, self.IsMouseOver and self:IsMouseOver()) end)
            button:HookScript("OnDisable", function(self) GSE.UpdateDebugTextButtonState(self, false) end)
        end
        GSE.UpdateDebugTextButtonState(button, button.IsMouseOver and button:IsMouseOver())
        return
    end

    if not button.GSEDebugButtonFill then
        button.GSEDebugButtonFill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        button.GSEDebugButtonFill.GSEDebugOwned = true
    end
    button.GSEDebugButtonFill:ClearAllPoints()
    button.GSEDebugButtonFill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.GSEDebugButtonFill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.GSEDebugButtonFill:Show()

    if not button.GSEDebugButtonBorderTop then
        button.GSEDebugButtonBorderTop = button:CreateTexture(nil, "BORDER")
        button.GSEDebugButtonBorderBottom = button:CreateTexture(nil, "BORDER")
        button.GSEDebugButtonBorderLeft = button:CreateTexture(nil, "BORDER")
        button.GSEDebugButtonBorderRight = button:CreateTexture(nil, "BORDER")
        button.GSEDebugButtonBorderTop.GSEDebugOwned = true
        button.GSEDebugButtonBorderBottom.GSEDebugOwned = true
        button.GSEDebugButtonBorderLeft.GSEDebugOwned = true
        button.GSEDebugButtonBorderRight.GSEDebugOwned = true
    end

    button.GSEDebugButtonBorderTop:ClearAllPoints()
    button.GSEDebugButtonBorderTop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.GSEDebugButtonBorderTop:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.GSEDebugButtonBorderTop:SetHeight(1)
    button.GSEDebugButtonBorderBottom:ClearAllPoints()
    button.GSEDebugButtonBorderBottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.GSEDebugButtonBorderBottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.GSEDebugButtonBorderBottom:SetHeight(1)
    button.GSEDebugButtonBorderLeft:ClearAllPoints()
    button.GSEDebugButtonBorderLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.GSEDebugButtonBorderLeft:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.GSEDebugButtonBorderLeft:SetWidth(1)
    button.GSEDebugButtonBorderRight:ClearAllPoints()
    button.GSEDebugButtonBorderRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.GSEDebugButtonBorderRight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.GSEDebugButtonBorderRight:SetWidth(1)
    button.GSEDebugButtonBorderTop:Show()
    button.GSEDebugButtonBorderBottom:Show()
    button.GSEDebugButtonBorderLeft:Show()
    button.GSEDebugButtonBorderRight:Show()

    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "BLEND")
    if button.GetHighlightTexture and button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAlpha(1)
        button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.10)
    end

    if not button.GSEDebugTextButtonHooked and button.HookScript then
        button.GSEDebugTextButtonHooked = true
        button:HookScript("OnEnter", function(self) GSE.UpdateDebugTextButtonState(self, true) end)
        button:HookScript("OnLeave", function(self) GSE.UpdateDebugTextButtonState(self, false) end)
        button:HookScript("OnEnable", function(self) GSE.UpdateDebugTextButtonState(self, self.IsMouseOver and self:IsMouseOver()) end)
        button:HookScript("OnDisable", function(self) GSE.UpdateDebugTextButtonState(self, false) end)
    end
    GSE.UpdateDebugTextButtonState(button, button.IsMouseOver and button:IsMouseOver())

    -- When an external skin provider (ElvUI / EllesmereUI) is active, layer
    -- its border + backdrop on top of our dark-grey fill. The provider's
    -- Skin.Button blanks UIPanelButtonTemplate's red textures (no-op here
    -- since modern mode already alpha=0'd them) and paints the EUI accent
    -- border so the debugger matches the rest of EUI panels.
    if GSE.Skin and GSE.Skin.IsExternalProviderActive and GSE.Skin.IsExternalProviderActive() and GSE.Skin.Button then
        GSE.Skin.Button(button)
    end
end

local STATS_COLUMNS = {
    {label = "Event", width = 166, min = 120, justify = "LEFT"},
    {label = "Amount", width = 70, min = 60, justify = "LEFT"},
    {label = "Percent", width = 72, min = 60, justify = "LEFT"}
}

local HARDWARE_EVENT_ROWS = {
    {label = "Current Mouse Button", key = "MOUSEBUTTON"},
    {label = "LeftButton", mouseButton = "LeftButton"},
    {label = "RightButton", mouseButton = "RightButton"},
    {label = "MiddleButton", mouseButton = "MiddleButton"},
    {label = "Button4", mouseButton = "Button4"},
    {label = "Button5", mouseButton = "Button5"},
    {label = "Right Alt Key", key = "RALT", api = "IsRightAltKeyDown"},
    {label = "Left Alt Key", key = "LALT", api = "IsLeftAltKeyDown"},
    {label = "Any Alt Key", key = "AALT", api = "IsAltKeyDown"},
    {label = "Right Control Key", key = "RCTRL", api = "IsRightControlKeyDown"},
    {label = "Left Control Key", key = "LCTRL", api = "IsLeftControlKeyDown"},
    {label = "Any Control Key", key = "ACTRL", api = "IsControlKeyDown"},
    {label = "Right Shift Key", key = "RSHIFT", api = "IsRightShiftKeyDown"},
    {label = "Left Shift Key", key = "LSHIFT", api = "IsLeftShiftKeyDown"},
    {label = "Any Shift Key", key = "ASHIFT", api = "IsShiftKeyDown"},
    {label = "Any Modifier Key", key = "AMOD", api = "IsModifierKeyDown"}
}

local function DebuggerLabel(key)
    local value = L and L[key]
    if type(value) == "string" then return value end
    return key
end

function GSE.SetDebuggerButtonText(button, label)
    if not button then return end
    local text = DebuggerLabel(label)
    if button.GetText and button:GetText() == text then return end
    button:SetText(text)
end

local function DebuggerWindowTitle(text)
    if GSE.UI and GSE.UI.FormatWindowTitle then return GSE.UI.FormatWindowTitle(text) end
    return "|cFFFFFFFFGS|r|cFF00FFFFE|r: " .. tostring(text or "")
end

local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback or minimum
    if value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return math.floor(value + 0.5)
end

local function GetDebuggerPopupStrata()
    return "DIALOG"
end

local function GetMaxDebuggerWidth()
    local screenWidth = GetScreenWidth and GetScreenWidth()
    if screenWidth and screenWidth > 0 then
        return math.max(DEBUG_UI.MIN_DEBUGGER_WIDTH, math.min(DEBUG_UI.MAX_DEBUGGER_WIDTH, screenWidth - DEBUG_UI.DEBUGGER_SCREEN_MARGIN))
    end
    return DEBUG_UI.MAX_DEBUGGER_WIDTH
end

local function GetMaxDebuggerHeight()
    local screenHeight = GetScreenHeight and GetScreenHeight()
    if screenHeight and screenHeight > 0 then
        return math.max(DEBUG_UI.MIN_DEBUGGER_HEIGHT, math.min(DEBUG_UI.MAX_DEBUGGER_HEIGHT, screenHeight - DEBUG_UI.DEBUGGER_SCREEN_MARGIN))
    end
    return DEBUG_UI.MAX_DEBUGGER_HEIGHT
end

local function GetMaxStatsWidgetWidth()
    local screenWidth = GetScreenWidth and GetScreenWidth()
    if screenWidth and screenWidth > 0 then
        return math.max(DEBUG_UI.STATS_WIDGET_MIN_WIDTH, math.min(DEBUG_UI.STATS_WIDGET_MAX_WIDTH, screenWidth - DEBUG_UI.DEBUGGER_SCREEN_MARGIN))
    end
    return DEBUG_UI.STATS_WIDGET_MAX_WIDTH
end

local function GetMaxStatsWidgetHeight()
    local screenHeight = GetScreenHeight and GetScreenHeight()
    if screenHeight and screenHeight > 0 then
        return math.max(DEBUG_UI.STATS_WIDGET_MIN_HEIGHT, math.min(DEBUG_UI.STATS_WIDGET_MAX_HEIGHT, screenHeight - DEBUG_UI.DEBUGGER_SCREEN_MARGIN))
    end
    return DEBUG_UI.STATS_WIDGET_MAX_HEIGHT
end

local function EnsureDebuggerLocation()
    if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
    if GSE.isEmpty(GSEOptions.frameLocations.debug) then GSEOptions.frameLocations.debug = {} end
    return GSEOptions.frameLocations.debug
end

local function Trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function StripDebugColor(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:gsub("\r", " "):gsub("\n", " ")
end

local function CopyDebugColumns(location)
    local savedWidths = location and location.columnWidths
    local savedVisibility = location and location.columnVisibility
    if location and location.columnVersion ~= DEBUG_UI.DEBUG_COLUMN_SCHEMA_VERSION then
        savedWidths = nil
        savedVisibility = nil
        location.columnVersion = DEBUG_UI.DEBUG_COLUMN_SCHEMA_VERSION
    end
    local columns = {}
    for i, column in ipairs(GSE.SequenceDebugColumns or DEFAULT_DEBUG_COLUMNS) do
        local defaultWidth = column.pixelWidth or column.widthPx or DEFAULT_DEBUG_COLUMNS[i] and DEFAULT_DEBUG_COLUMNS[i].width or 80
        local minimumWidth = column.min or DEFAULT_DEBUG_COLUMNS[i] and DEFAULT_DEBUG_COLUMNS[i].min or 40
        columns[i] = {
            label = column.label or DEFAULT_DEBUG_COLUMNS[i] and DEFAULT_DEBUG_COLUMNS[i].label or ("Column " .. i),
            width = ClampNumber(savedWidths and savedWidths[i], minimumWidth, 400, defaultWidth),
            min = minimumWidth,
            visible = not (savedVisibility and savedVisibility[i] == false)
        }
    end
    return columns
end

local function CopyDebugColumnOrder(location, columns)
    local savedOrder = location and location.columnOrder
    local order, seen = {}, {}
    if type(savedOrder) == "table" then
        for _, columnIndex in ipairs(savedOrder) do
            columnIndex = tonumber(columnIndex)
            if columnIndex and columns[columnIndex] and not seen[columnIndex] then
                order[#order + 1] = columnIndex
                seen[columnIndex] = true
            end
        end
    end
    for columnIndex in ipairs(columns) do
        if not seen[columnIndex] then
            order[#order + 1] = columnIndex
            seen[columnIndex] = true
        end
    end
    return order
end

local frameTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
function GSE.CreateDebuggerEditorFrame(name, parent)
    for _, templateName in ipairs({"ButtonFrameTemplate", "BasicFrameTemplateWithInset"}) do
        local frame
        local ok = pcall(
            function()
                frame = CreateFrame("Frame", name, parent or UIParent, templateName)
            end
        )
        if ok and frame then
            frame.GSEUsesBlizzardPanelTemplate = true
            return frame
        end
    end

    return CreateFrame("Frame", name, parent or UIParent, frameTemplate)
end

local DebugFrame = GSE.CreateDebuggerEditorFrame("GSEGUIDebugFrame", UIParent)
DebugFrame.frame = DebugFrame
function DebugFrame:ApplyNativeWindowSkin(titleText, closeButton)
    if GSE.UI and GSE.UI.ApplyNativeWindowSkin then GSE.UI.ApplyNativeWindowSkin(self, self, titleText, closeButton) end
end

function DebugFrame.ApplyNativeInsetSkin(frame)
    if GSE.UI and GSE.UI.ApplyNativeInsetSkin then GSE.UI.ApplyNativeInsetSkin(frame) end
end

function DebugFrame.ApplyEditorWindowStyle(frame, titleText, closeButton)
    if not frame then return end

    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, frame) end
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, frame) end

    if not (GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin()) then
        if frame.GSEElvUIOuterShell then frame.GSEElvUIOuterShell:Hide() end
        if frame.GSEElvUIOuterClassBorder then frame.GSEElvUIOuterClassBorder:Hide() end
        if frame.GSENormalAccentBorderOverlay then frame.GSENormalAccentBorderOverlay:Hide() end
        if frame.GSEEditorTitleBar then frame.GSEEditorTitleBar:Hide() end
    end

    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -1)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -1)
        frame.TitleContainer:SetHeight(20)
    end

    if frame.TitleText then
        frame.TitleText:ClearAllPoints()
        if frame.TitleContainer then
            frame.TitleText:SetPoint("LEFT", frame.TitleContainer, "LEFT", 0, 1)
            frame.TitleText:SetPoint("RIGHT", frame.TitleContainer, "RIGHT", 0, 1)
        else
            frame.TitleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -4)
            frame.TitleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -4)
        end
        frame.TitleText:SetFontObject(GameFontNormal)
        frame.TitleText:SetJustifyH("CENTER")
        frame.TitleText:SetJustifyV("MIDDLE")
        if titleText and frame.TitleText ~= titleText then frame.TitleText:Hide() end
    end

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -4, -24)
        frame.Inset:SetHeight(1)
        frame.Inset:Hide()
    end

    if not frame.GSEBodyFill then
        frame.GSEBodyFill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame.GSEBodyFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -24)
        frame.GSEBodyFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
        frame.GSEBodyFill:SetColorTexture(0, 0, 0, 1)
    end
    frame.GSEBodyFill:Show()

    if titleText then
        titleText:ClearAllPoints()
        titleText:SetParent(frame.TitleContainer or frame)
        if frame.TitleContainer then
            titleText:SetPoint("LEFT", frame.TitleContainer, "LEFT", 0, 1)
            titleText:SetPoint("RIGHT", frame.TitleContainer, "RIGHT", 0, 1)
        else
            titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -4)
            titleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -4)
        end
        titleText:SetJustifyH("CENTER")
        titleText:SetJustifyV("MIDDLE")
        if titleText.SetFontObject then titleText:SetFontObject(GameFontNormal) end
        titleText:Show()
    end

    closeButton = closeButton or frame.CloseButton
    if GSE.UI and GSE.UI.ApplyNativeWindowSkin then
        GSE.UI.ApplyNativeWindowSkin(frame, frame.TitleContainer or frame, titleText or frame.TitleText, closeButton)
    end
    if GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin() and frame.GSEBodyFill then frame.GSEBodyFill:Hide() end

    if closeButton then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 3)
        closeButton:SetSize(32, 30)
        GSE.StyleDebugIconButton(closeButton, GSE.DEBUG_CLOSE_TEXTURE, GSE.DebugUsesModernSkin())
        if closeButton.SetFrameLevel and frame.GetFrameLevel then closeButton:SetFrameLevel((frame:GetFrameLevel() or 0) + 20) end
    end
end

function DebugFrame.SetDebuggerSideResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    if not frame then return end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    elseif frame.SetMinResize and frame.SetMaxResize then
        frame:SetMinResize(minWidth, minHeight)
        frame:SetMaxResize(maxWidth, maxHeight)
    end
end

function DebugFrame.CreateDebuggerSideResizeButton(frame)
    if not frame or frame.GSESideResizeButton then return end
    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    if resizeButton.SetFrameLevel and frame.GetFrameLevel then resizeButton:SetFrameLevel((frame:GetFrameLevel() or 0) + 80) end
    resizeButton:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        DebugFrame.DetachDebuggerSideWindow(frame)
        if frame.StartSizing then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resizeButton:SetScript("OnMouseUp", function()
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        if frame.GSESideLayout then frame.GSESideLayout() end
        if frame.GSESideSave then frame.GSESideSave() end
    end)
    resizeButton:Hide()
    frame.GSESideResizeButton = resizeButton
end

function DebugFrame.EnsureDebuggerSideCloseButton(frame)
    if not frame then return end
    if frame.SetClipsChildren then frame:SetClipsChildren(false) end

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end

    frame.CloseButton:ClearAllPoints()
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 3)
    frame.CloseButton:SetSize(32, 30)
    GSE.StyleDebugIconButton(frame.CloseButton, GSE.DEBUG_CLOSE_TEXTURE, GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin())
    if frame.CloseButton.SetFrameStrata and frame.GetFrameStrata then frame.CloseButton:SetFrameStrata(frame:GetFrameStrata()) end
    if frame.CloseButton.SetFrameLevel and frame.GetFrameLevel then frame.CloseButton:SetFrameLevel((frame:GetFrameLevel() or 0) + 500) end
    frame.CloseButton:SetScript(
        "OnClick",
        function()
            local click = frame.closeButton and frame.closeButton.GetScript and frame.closeButton:GetScript("OnClick")
            if click then
                click(frame.closeButton)
            else
                frame:Hide()
            end
        end
    )
    frame.CloseButton:Show()
end

function DebugFrame.SetDebuggerSideCloseButtonVisible(frame, visible)
    if not frame then return end
    if not frame.CloseButton then DebugFrame.EnsureDebuggerSideCloseButton(frame) end
    if frame.CloseButton then
        frame.CloseButton:Show()
    end
end

function DebugFrame.SyncDebuggerSideSkinLayers(frame)
    if not frame then return end

    local strata = frame.GetFrameStrata and frame:GetFrameStrata()
    local frameLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 0
    local function syncLayer(layer, offset)
        if not layer then return end
        if strata and layer.SetFrameStrata then layer:SetFrameStrata(strata) end
        if layer.SetFrameLevel then layer:SetFrameLevel(math.max(0, frameLevel + (offset or 0))) end
    end

    syncLayer(frame.GSEElvUIOuterShell, 0)
    syncLayer(frame.GSEElvUIOuterClassBorder, 100)
    syncLayer(frame.GSENormalAccentBorderOverlay, 100)
    syncLayer(frame.TitleContainer, 90)
    syncLayer(frame.GSESideVisibleTitleBar, 520)
end

function DebugFrame.PositionDebuggerSideTitle(frame, title, text)
    if not (frame and title) then return end
    if not frame.GSESideVisibleTitleBar then
        frame.GSESideVisibleTitleBar = CreateFrame("Frame", nil, frame, frameTemplate)
        frame.GSESideVisibleTitleBar:EnableMouse(false)
    end

    frame.GSESideVisibleTitleBar:ClearAllPoints()
    frame.GSESideVisibleTitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -1)
    frame.GSESideVisibleTitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -1)
    frame.GSESideVisibleTitleBar:SetHeight(20)
    if frame.GSESideVisibleTitleBar.SetFrameStrata and frame.GetFrameStrata then frame.GSESideVisibleTitleBar:SetFrameStrata(frame:GetFrameStrata()) end
    if frame.GSESideVisibleTitleBar.SetFrameLevel and frame.GetFrameLevel then frame.GSESideVisibleTitleBar:SetFrameLevel((frame:GetFrameLevel() or 0) + 520) end
    frame.GSESideVisibleTitleBar:Show()

    title:SetParent(frame.GSESideVisibleTitleBar)
    title:ClearAllPoints()
    title:SetPoint("LEFT", frame.GSESideVisibleTitleBar, "LEFT", 0, 1)
    title:SetPoint("RIGHT", frame.GSESideVisibleTitleBar, "RIGHT", 0, 1)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    if title.SetFontObject then title:SetFontObject(GameFontNormal) end
    if title.SetDrawLayer then title:SetDrawLayer("OVERLAY", 7) end
    if title.SetAlpha then title:SetAlpha(1) end
    title:SetText(text or "")
    title:Show()
end

function DebugFrame.RaiseDebuggerSideChrome(frame)
    if not frame then return end
    if frame.GSESideDetached == false or (DebugFrame.IsDebuggerSideWindowAttached and DebugFrame.IsDebuggerSideWindowAttached(frame)) then
        if frame.SetFrameStrata and DebugFrame.GetFrameStrata then frame:SetFrameStrata(DebugFrame:GetFrameStrata()) end
        if frame.SetFrameLevel and DebugFrame.GetFrameLevel then frame:SetFrameLevel(DebugFrame:GetFrameLevel() or 0) end
        if frame.SetToplevel then frame:SetToplevel(true) end
        if frame.Raise then frame:Raise() end
    elseif frame.SetToplevel then
        frame:SetToplevel(true)
    end
    if frame.SetClipsChildren then frame:SetClipsChildren(true) end
    DebugFrame.SyncDebuggerSideSkinLayers(frame)
    if frame.CloseButton then
        if frame.CloseButton.SetFrameStrata and frame.GetFrameStrata then frame.CloseButton:SetFrameStrata(frame:GetFrameStrata()) end
        if frame.CloseButton.SetFrameLevel and frame.GetFrameLevel then frame.CloseButton:SetFrameLevel((frame:GetFrameLevel() or 0) + 500) end
        if frame.CloseButton.Raise then frame.CloseButton:Raise() end
        frame.CloseButton:Show()
    end
    if frame.GSESideResizeButton and frame.GSESideResizeButton.SetFrameLevel and frame.GetFrameLevel then
        frame.GSESideResizeButton:SetFrameLevel((frame:GetFrameLevel() or 0) + 110)
    end
    DebugFrame.SyncDebuggerSideSkinLayers(frame)
end

function DebugFrame.UpdateDebuggerWindowLevels()
    local activeWindow = DebugFrame.GSEActiveDebuggerWindow or DebugFrame

    if activeWindow and activeWindow.Raise then activeWindow:Raise() end
    if DebugFrame.titleHitBox and DebugFrame.titleHitBox.SetFrameLevel then DebugFrame.titleHitBox:SetFrameLevel((DebugFrame:GetFrameLevel() or 0) + 80) end
    if DebugFrame.versionHitBox and DebugFrame.versionHitBox.SetFrameLevel then DebugFrame.versionHitBox:SetFrameLevel((DebugFrame:GetFrameLevel() or 0) + 80) end
    if DebugFrame.RaiseDebuggerControls then DebugFrame.RaiseDebuggerControls() end
    if DebugFrame.GSEDebuggerManagedWindows then
        for _, frame in ipairs(DebugFrame.GSEDebuggerManagedWindows) do
            if frame and (frame.GSESideDetached == false or (DebugFrame.IsDebuggerSideWindowAttached and DebugFrame.IsDebuggerSideWindowAttached(frame))) then
                DebugFrame.RaiseDebuggerSideChrome(frame)
            end
            -- Show inactive overlay on non-active windows
            if frame and frame.GSEInactiveOverlay then
                local isActive = (frame == activeWindow)
                if isActive then
                    frame.GSEInactiveOverlay:Hide()
                else
                    frame.GSEInactiveOverlay:Show()
                end
            end
        end
    end
    if activeWindow and activeWindow ~= DebugFrame then DebugFrame.RaiseDebuggerSideChrome(activeWindow) end
end

function DebugFrame.ActivateDebuggerWindow(frame)
    frame = frame or DebugFrame
    if frame ~= DebugFrame and (frame.GSESideDetached == false or (DebugFrame.IsDebuggerSideWindowAttached and DebugFrame.IsDebuggerSideWindowAttached(frame))) then frame = DebugFrame end
    DebugFrame.GSEActiveDebuggerWindow = frame
    DebugFrame.UpdateDebuggerWindowLevels()
end

function DebugFrame.RegisterDebuggerWindow(frame)
    if not frame or frame.GSEDebuggerWindowRegistered then return end
    frame.GSEDebuggerWindowRegistered = true
    frame.GSEDebuggerLevelManaged = true
    DebugFrame.GSEDebuggerManagedWindows = DebugFrame.GSEDebuggerManagedWindows or {}
    table.insert(DebugFrame.GSEDebuggerManagedWindows, frame)

    if frame.HookScript then
        frame:HookScript("OnMouseDown", function(self) DebugFrame.ActivateDebuggerWindow(self) end)
    end
    if frame.TitleContainer and frame.TitleContainer.HookScript then
        frame.TitleContainer:HookScript("OnMouseDown", function() DebugFrame.ActivateDebuggerWindow(frame) end)
    end

    -- Create an inactive overlay matching the editor pattern
    local parentFrame = frame.frame or frame
    if parentFrame and parentFrame.CreateFontString then
        local overlay = CreateFrame("Button", nil, parentFrame)
        overlay:SetAllPoints(parentFrame)
        overlay:SetFrameLevel(((parentFrame.GetFrameLevel and parentFrame:GetFrameLevel()) or 0) + 80)
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("AnyDown")
        overlay:SetScript("OnMouseDown", function() DebugFrame.ActivateDebuggerWindow(frame) end)
        overlay:Hide()
        frame.GSEInactiveOverlay = overlay
    end

    DebugFrame.UpdateDebuggerWindowLevels()
end

function DebugFrame.MaybeSnapDebuggerSideWindow(frame)
    if not (frame and frame.GSESideDetached and DebugFrame:IsShown()) then return false end
    if not (frame.GetLeft and frame.GetRight and frame.GetTop and DebugFrame.GetLeft and DebugFrame.GetRight and DebugFrame.GetTop) then return false end

    local frameLeft, frameRight, frameTop = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    local debugLeft, debugRight, debugTop = DebugFrame:GetLeft(), DebugFrame:GetRight(), DebugFrame:GetTop()
    if not (frameLeft and frameRight and frameTop and debugLeft and debugRight and debugTop) then return false end

    local offset = frame.GSESideDockOffset or 0
    local side = frame.GSESideDockSide or "RIGHT"
    local horizontalDistance
    if side == "LEFT" then
        horizontalDistance = math.abs(frameRight - (debugLeft + offset))
    else
        horizontalDistance = math.abs(frameLeft - (debugRight + offset))
    end

    if horizontalDistance <= GSE.DEBUGGER_SIDE_SNAP_TOLERANCE and math.abs(frameTop - debugTop) <= GSE.DEBUGGER_SIDE_SNAP_TOLERANCE then
        DebugFrame.DockDebuggerSideWindow(frame)
        if frame.GSESideSave then frame.GSESideSave() end
        return true
    end

    return false
end

function DebugFrame.IsDebuggerSideWindowAttached(frame)
    if not (frame and frame:IsShown()) then return false end
    if frame.GSESideDetached == false then return true end
    if not (frame.GetLeft and frame.GetRight and frame.GetTop and DebugFrame.GetLeft and DebugFrame.GetRight and DebugFrame.GetTop) then return false end

    local frameLeft, frameRight, frameTop = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    local debugLeft, debugRight, debugTop = DebugFrame:GetLeft(), DebugFrame:GetRight(), DebugFrame:GetTop()
    if not (frameLeft and frameRight and frameTop and debugLeft and debugRight and debugTop) then return false end

    local offset = frame.GSESideDockOffset or 0
    local side = frame.GSESideDockSide or "RIGHT"
    local horizontalDistance
    if side == "LEFT" then
        horizontalDistance = math.abs(frameRight - (debugLeft + offset))
    else
        horizontalDistance = math.abs(frameLeft - (debugRight + offset))
    end

    return horizontalDistance <= GSE.DEBUGGER_SIDE_SNAP_TOLERANCE and math.abs(frameTop - debugTop) <= GSE.DEBUGGER_SIDE_SNAP_TOLERANCE
end

function DebugFrame.DetachDebuggerSideWindow(frame)
    if not frame then return end
    if frame.GSESideDetached then
        if frame.GSESideResizeButton then frame.GSESideResizeButton:Show() end
        DebugFrame.SetDebuggerSideCloseButtonVisible(frame, true)
        return
    end

    local left, top = frame:GetLeft(), frame:GetTop()
    frame.GSESideDetached = true
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.GSESideResizeButton then frame.GSESideResizeButton:Show() end
    DebugFrame.SetDebuggerSideCloseButtonVisible(frame, true)
    DebugFrame.RaiseDebuggerSideChrome(frame)
    frame:ClearAllPoints()
    if left and top then
        if GSE.SetFrameScreenPoint then
            GSE.SetFrameScreenPoint(frame, "TOPLEFT", left, top)
        else
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if frame.GSESideLocation then frame.GSESideLocation.detached = true end
    if frame.GSESideLayout then frame.GSESideLayout() end
    DebugFrame.RaiseDebuggerSideChrome(frame)
    if frame.GSESideSave then frame.GSESideSave() end
end

function DebugFrame.DockDebuggerSideWindow(frame)
    if not frame then return end
    frame.GSESideDetached = false
    frame:SetMovable(true)
    frame:SetResizable(false)
    if frame.GSESideResizeButton then frame.GSESideResizeButton:Hide() end
    DebugFrame.SetDebuggerSideCloseButtonVisible(frame, true)
    DebugFrame.RaiseDebuggerSideChrome(frame)
    if frame.GSESideLocation then frame.GSESideLocation.detached = false end
    if frame.GSESideAnchor then frame.GSESideAnchor() end
    if frame.GSESideLayout then frame.GSESideLayout() end
    DebugFrame.RaiseDebuggerSideChrome(frame)
end

function DebugFrame.ConfigureDebuggerSideWindow(frame, location, minWidth, minHeight, maxWidth, maxHeight)
    if not frame then return end
    frame.GSESideLocation = location
    frame:SetMovable(true)
    frame:SetResizable(false)
    frame:RegisterForDrag("LeftButton")
    DebugFrame.SetDebuggerSideResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    DebugFrame.CreateDebuggerSideResizeButton(frame)
    DebugFrame.EnsureDebuggerSideCloseButton(frame)
    DebugFrame.SetDebuggerSideCloseButtonVisible(frame, true)
    DebugFrame.RaiseDebuggerSideChrome(frame)
    frame:SetScript("OnDragStart", function(self)
        DebugFrame.ActivateDebuggerWindow(self)
        DebugFrame.DetachDebuggerSideWindow(self)
        if self.StartMoving then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        if DebugFrame.MaybeSnapDebuggerSideWindow(self) then
            if self.GSESideLayout then self.GSESideLayout() end
            if self.GSESideSave then self.GSESideSave() end
            return
        end
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
        if self.GSESideLayout then self.GSESideLayout() end
        if self.GSESideSave then self.GSESideSave() end
    end)
    if frame.TitleContainer then
        frame.TitleContainer:EnableMouse(true)
        frame.TitleContainer:RegisterForDrag("LeftButton")
        frame.TitleContainer:SetScript("OnDragStart", function()
            DebugFrame.ActivateDebuggerWindow(frame)
            DebugFrame.DetachDebuggerSideWindow(frame)
            if frame.StartMoving then frame:StartMoving() end
        end)
        frame.TitleContainer:SetScript("OnDragStop", function()
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
            if DebugFrame.MaybeSnapDebuggerSideWindow(frame) then
                if frame.GSESideLayout then frame.GSESideLayout() end
                if frame.GSESideSave then frame.GSESideSave() end
                return
            end
            if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(frame) end
            if frame.GSESideLayout then frame.GSESideLayout() end
            if frame.GSESideSave then frame.GSESideSave() end
        end)
    end
end

DebugFrame:SetFrameStrata(DEBUG_UI.DEBUGGER_DEFAULT_STRATA)
DebugFrame:SetClampedToScreen(true)
DebugFrame:SetMovable(true)
DebugFrame:SetResizable(true)
DebugFrame:EnableMouse(true)
DebugFrame:RegisterForDrag("LeftButton")
DebugFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
DebugFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if self.SaveDebuggerLocation then self:SaveDebuggerLocation() end
end)
if DebugFrame.SetResizeBounds then
    DebugFrame:SetResizeBounds(DEBUG_UI.MIN_DEBUGGER_WIDTH, DEBUG_UI.MIN_DEBUGGER_HEIGHT, GetMaxDebuggerWidth(), GetMaxDebuggerHeight())
elseif DebugFrame.SetMinResize and DebugFrame.SetMaxResize then
    DebugFrame:SetMinResize(DEBUG_UI.MIN_DEBUGGER_WIDTH, DEBUG_UI.MIN_DEBUGGER_HEIGHT)
    DebugFrame:SetMaxResize(GetMaxDebuggerWidth(), GetMaxDebuggerHeight())
end
if DebugFrame.SetToplevel then DebugFrame:SetToplevel(true) end
if DebugFrame.SetClampRectInsets then DebugFrame:SetClampRectInsets(10, -10, -10, 10) end
if not DebugFrame.GSEUsesBlizzardPanelTemplate and DebugFrame.SetBackdrop then
    DebugFrame:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 8, right = 8, top = 8, bottom = 8}
        }
    )
    DebugFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.94)
    DebugFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

-- Under EUI / ElvUI, repaint the DebugFrame's chrome through the active skin
-- provider so the debugger panel matches host UI panels instead of showing
-- Blizzard's gold ornate DialogBox-Border edge texture.
if GSE.Skin and GSE.Skin.IsExternalProviderActive and GSE.Skin.IsExternalProviderActive() and GSE.Skin.Frame then
    GSE.Skin.Frame(DebugFrame)
end

GSE.GUIDebugFrame = DebugFrame
function GSE.GUIDebugIsOpenOrMinimized()
    local frame = GSE.GUIDebugFrame
    if not frame then return false end
    if frame.IsShown and frame:IsShown() then return true end
    local widget = frame.minimizedWidget
    return widget and widget.IsShown and widget:IsShown()
end

local debugLocation = EnsureDebuggerLocation()
local currentDebuggerStrata = DEBUG_UI.DEBUGGER_DEFAULT_STRATA
debugLocation.strata = nil
DebugFrame:SetFrameStrata(currentDebuggerStrata)
DebugFrame.Height = ClampNumber(debugLocation.height or GSEOptions.debugHeight, DEBUG_UI.MIN_DEBUGGER_HEIGHT, GetMaxDebuggerHeight(), DEBUG_UI.MIN_DEBUGGER_HEIGHT)
DebugFrame.Width = ClampNumber(debugLocation.width or GSEOptions.debugWidth, DEBUG_UI.MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), DEBUG_UI.MIN_DEBUGGER_WIDTH)
local debugColumns = CopyDebugColumns(debugLocation)
local debugColumnOrder = CopyDebugColumnOrder(debugLocation, debugColumns)
GSEOptions.debugHeight = DebugFrame.Height
GSEOptions.debugWidth = DebugFrame.Width
DebugFrame:SetSize(DebugFrame.Width, DebugFrame.Height)

if debugLocation.left and debugLocation.top then
    DebugFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", debugLocation.left, debugLocation.top)
else
    DebugFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function DebugFrame.HideDebuggerStockTitle()
    if DebugFrame.GSEStockTitleContainer then return end

    DebugFrame.GSEStockTitleContainer = DebugFrame.TitleContainer
    DebugFrame.GSEStockTitleText = DebugFrame.TitleText

    if DebugFrame.GSEStockTitleText then
        DebugFrame.GSEStockTitleText:SetText("")
        DebugFrame.GSEStockTitleText:Hide()
    end
    if DebugFrame.GSEStockTitleContainer then
        DebugFrame.GSEStockTitleContainer:Hide()
    end
end

function DebugFrame.EnsureDebuggerEditorTitle()
    DebugFrame.HideDebuggerStockTitle()

    if not DebugFrame.GSEDebuggerTitleBar then
        DebugFrame.GSEDebuggerTitleBar = CreateFrame("Frame", nil, DebugFrame, frameTemplate)
        DebugFrame.GSEDebuggerTitleBar:EnableMouse(true)
        if DebugFrame.GSEDebuggerTitleBar.RegisterForDrag then DebugFrame.GSEDebuggerTitleBar:RegisterForDrag("LeftButton") end
    end

    if not DebugFrame.GSEDebuggerTitleText then
        DebugFrame.GSEDebuggerTitleText = DebugFrame.GSEDebuggerTitleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    end

    DebugFrame.TitleContainer = DebugFrame.GSEDebuggerTitleBar
    DebugFrame.TitleText = DebugFrame.GSEDebuggerTitleText
    return DebugFrame.GSEDebuggerTitleBar, DebugFrame.GSEDebuggerTitleText
end

local title = select(2, DebugFrame.EnsureDebuggerEditorTitle())
DebugFrame.debuggerTitleText = DebuggerWindowTitle(DebuggerLabel("Sequence Debugger"))
title:SetText(DebugFrame.debuggerTitleText)
DebugFrame.title = title
local closeButton

local ShowDebugOutputColumnMenu
local RaiseDebuggerPopup
local debugExportFrame, debugExportBox
local debugColumnMenu
local filterMenu  -- forward-declared (assigned in the popup-menu setup section below) so the dropdown-hide closure above captures the upvalue, not a nil global

local titleHitBox = CreateFrame("Button", nil, DebugFrame)
titleHitBox:EnableMouse(false)
titleHitBox:RegisterForClicks("LeftButtonUp")
titleHitBox:RegisterForDrag("LeftButton")
if titleHitBox.SetFrameLevel then titleHitBox:SetFrameLevel((DebugFrame:GetFrameLevel() or 0) + 10) end
local lastTitleClick = 0

local function PositionDebuggerTitleText()
    if not title then return end

    local titleContainer
    titleContainer, title = DebugFrame.EnsureDebuggerEditorTitle()
    titleContainer:ClearAllPoints()
    titleContainer:SetPoint("TOPLEFT", DebugFrame, "TOPLEFT", 24, -1)
    titleContainer:SetPoint("TOPRIGHT", DebugFrame, "TOPRIGHT", -64, -1)
    titleContainer:SetHeight(20)
    if titleContainer.SetFrameStrata and DebugFrame.GetFrameStrata then titleContainer:SetFrameStrata(DebugFrame:GetFrameStrata()) end
    if titleContainer.SetFrameLevel then
        local closeLevel = closeButton and closeButton.GetFrameLevel and closeButton:GetFrameLevel()
        titleContainer:SetFrameLevel(math.max((DebugFrame:GetFrameLevel() or 0) + 520, (closeLevel or 0) + 10))
    end
    titleContainer:Show()

    if title.SetParent then title:SetParent(titleContainer) end
    title:ClearAllPoints()
    title:SetPoint("LEFT", titleContainer, "LEFT", 0, 1)
    title:SetPoint("RIGHT", titleContainer, "RIGHT", 0, 1)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    if title.SetFontObject then title:SetFontObject(GameFontNormal) end
    if title.SetDrawLayer then title:SetDrawLayer("OVERLAY", 7) end
    if GSE.Skin and GSE.Skin.PaintBodyText then
        GSE.Skin.PaintBodyText(title, 1, 0.82, 0, 1)
    elseif title.SetTextColor then
        title:SetTextColor(1, 0.82, 0, 1)
    end
    if title.SetAlpha then title:SetAlpha(1) end
    title:SetText(DebugFrame.debuggerTitleText)
    title:Show()
    DebugFrame.title = title
end

local function StartDebuggerTitleMove(button, checkDoubleClick)
    DebugFrame.ActivateDebuggerWindow(DebugFrame)
    if button ~= "LeftButton" then return end
    if checkDoubleClick then
        local now = GetTime and GetTime() or 0
        if now > 0 and now - lastTitleClick <= 0.35 then
            lastTitleClick = 0
            if DebugFrame.StopMovingOrSizing then DebugFrame:StopMovingOrSizing() end
            if DebugFrame.CollapseToMinimizedWidget then DebugFrame:CollapseToMinimizedWidget() end
            return
        end
        lastTitleClick = now
        return
    end
    if DebugFrame.SetMovable then DebugFrame:SetMovable(true) end
    if DebugFrame.StartMoving then
        DebugFrame:StartMoving()
    end
end

local function StopDebuggerTitleMove(button)
    if button and button ~= "LeftButton" then return end
    if DebugFrame.StopMovingOrSizing then DebugFrame:StopMovingOrSizing() end
    if DebugFrame.SaveDebuggerLocation then DebugFrame:SaveDebuggerLocation() end
end

local function IsCursorOverDebuggerTitleBar()
    local titleBar = DebugFrame.TitleContainer or DebugFrame.GSEDebuggerTitleBar or DebugFrame
    local left = titleBar and titleBar.GetLeft and titleBar:GetLeft()
    local right = titleBar and titleBar.GetRight and titleBar:GetRight()
    local top = titleBar and titleBar.GetTop and titleBar:GetTop()
    local bottom = titleBar and titleBar.GetBottom and titleBar:GetBottom()

    if not (left and right and top and bottom) then
        left = DebugFrame:GetLeft()
        right = DebugFrame:GetRight()
        top = DebugFrame:GetTop()
        bottom = top and (top - 28)
    end
    if not (left and right and top and bottom) then return false end

    local x, y = GetCursorPosition()
    local scale = (titleBar and titleBar.GetEffectiveScale and titleBar:GetEffectiveScale()) or
        (DebugFrame.GetEffectiveScale and DebugFrame:GetEffectiveScale()) or
        (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or
        1
    x, y = x / scale, y / scale
    return x >= left and x <= right and y <= top and y >= bottom
end

titleHitBox:SetScript("OnMouseDown", function(_, button) StartDebuggerTitleMove(button, true) end)
titleHitBox:SetScript("OnDragStart", function() if DebugFrame.StartMoving then DebugFrame:StartMoving() end end)
titleHitBox:SetScript(
    "OnDragStop",
    function()
        StopDebuggerTitleMove("LeftButton")
    end
)
titleHitBox:SetScript("OnMouseUp", function(_, button) StopDebuggerTitleMove(button) end)
titleHitBox:SetScript(
    "OnEnter",
    function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Sequence Debugger")
        GameTooltip:AddLine("Drag to move debugger", 1, 1, 1)
        GameTooltip:AddLine("Double-click: Minimize debugger", 1, 1, 1)
        GameTooltip:Show()
    end
)
titleHitBox:SetScript(
    "OnLeave",
    function()
        if GameTooltip then GameTooltip:Hide() end
    end
)
DebugFrame.titleHitBox = titleHitBox

closeButton = DebugFrame.CloseButton or CreateFrame("Button", nil, DebugFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", DebugFrame, "TOPRIGHT", -5, -5)
local function SetDebuggerOpenPreference(isOpen)
    local location = EnsureDebuggerLocation()
    location.open = isOpen and true or false
end

function GSE.GUICloseDebugWindow()
    SetDebuggerOpenPreference(false)
    if DebugFrame.minimizedWidget and DebugFrame.minimizedWidget:IsShown() and DebugFrame.CloseMinimizedWidget then
        DebugFrame:CloseMinimizedWidget()
        return
    end
    if DebugFrame.CloseAttachedDebuggerSideWindows then DebugFrame.CloseAttachedDebuggerSideWindows() end
    DebugFrame:Hide()
end

closeButton:SetScript(
    "OnClick",
    function()
        GSE.GUICloseDebugWindow()
    end
)
DebugFrame.closebutton = closeButton
DebugFrame.ApplyEditorWindowStyle(DebugFrame, title, closeButton)
if DebugFrame.TitleContainer then
    DebugFrame.TitleContainer:EnableMouse(true)
    if DebugFrame.TitleContainer.RegisterForDrag then DebugFrame.TitleContainer:RegisterForDrag("LeftButton") end
    DebugFrame.TitleContainer:SetScript("OnMouseDown", function(_, button) StartDebuggerTitleMove(button, true) end)
    DebugFrame.TitleContainer:SetScript("OnDragStart", function() StartDebuggerTitleMove("LeftButton", false) end)
    DebugFrame.TitleContainer:SetScript("OnDragStop", function() StopDebuggerTitleMove("LeftButton") end)
    DebugFrame.TitleContainer:SetScript("OnMouseUp", function(_, button) StopDebuggerTitleMove(button) end)
    DebugFrame.TitleContainer:SetScript(
        "OnEnter",
        function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText("Sequence Debugger")
            GameTooltip:AddLine("Drag to move debugger", 1, 1, 1)
            GameTooltip:AddLine("Double-click: Minimize debugger", 1, 1, 1)
            GameTooltip:Show()
        end
    )
    DebugFrame.TitleContainer:SetScript(
        "OnLeave",
        function()
            if GameTooltip then GameTooltip:Hide() end
        end
    )
end
DebugFrame:HookScript("OnMouseDown", function(_, button)
    if not IsCursorOverDebuggerTitleBar() then return end
    StartDebuggerTitleMove(button, true)
end)
DebugFrame:HookScript("OnUpdate", function()
    if not GameTooltip then return end
    if IsCursorOverDebuggerTitleBar() then
        if not DebugFrame.titleTooltipShown then
            GameTooltip:SetOwner(DebugFrame, "ANCHOR_CURSOR")
            GameTooltip:SetText("Sequence Debugger")
            GameTooltip:AddLine("Drag to move debugger", 1, 1, 1)
            GameTooltip:AddLine("Double-click: Minimize debugger", 1, 1, 1)
            GameTooltip:Show()
            DebugFrame.titleTooltipShown = true
        end
    elseif DebugFrame.titleTooltipShown then
        if GameTooltip.GetOwner and GameTooltip:GetOwner() == DebugFrame then
            GameTooltip:Hide()
        end
        DebugFrame.titleTooltipShown = nil
    end
end)
DebugFrame:HookScript("OnLeave", function()
    if not DebugFrame.titleTooltipShown then return end
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == DebugFrame then
        GameTooltip:Hide()
    end
    DebugFrame.titleTooltipShown = nil
end)
PositionDebuggerTitleText()
DebugFrame.RegisterDebuggerWindow(DebugFrame)

local outputLabel = CreateFrame("Button", nil, DebugFrame)
outputLabel:SetSize(110, 20)
outputLabel:SetPoint("TOPLEFT", DebugFrame, "TOPLEFT", DEBUG_UI.FRAME_PADDING + 5, -39)
outputLabel.text = outputLabel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
outputLabel.text:SetPoint("LEFT", outputLabel, "LEFT", 0, 0)
outputLabel.text:SetText("Output Selection")
outputLabel.arrow = outputLabel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
outputLabel.arrow:SetPoint("LEFT", outputLabel.text, "RIGHT", 6, 0)
outputLabel.arrow:SetText("v")
outputLabel:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
outputLabel:SetScript(
    "OnClick",
    function(self)
        if debugColumnMenu and debugColumnMenu:IsShown() then
            debugColumnMenu:Hide()
        elseif ShowDebugOutputColumnMenu then
            ShowDebugOutputColumnMenu(self)
        end
    end
)

local headerBackground = CreateFrame("Frame", nil, DebugFrame, frameTemplate)
if headerBackground.SetBackdrop then
    headerBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        }
    )
    headerBackground:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    if GSE.Skin and GSE.Skin.PaintAccentBorder then
        GSE.Skin.PaintAccentBorder(headerBackground, 0.7, 0.62, 0.12, 1)
    else
        headerBackground:SetBackdropBorderColor(0.7, 0.62, 0.12, 1)
    end
end
DebugFrame.ApplyNativeInsetSkin(headerBackground)

local headerScrollFrame = CreateFrame("ScrollFrame", nil, headerBackground)
local headerContent = CreateFrame("Frame", nil, headerScrollFrame)
headerContent:SetSize(1, DEBUG_UI.HEADER_HEIGHT)
headerScrollFrame:SetScrollChild(headerContent)
if headerScrollFrame.SetClipsChildren then headerScrollFrame:SetClipsChildren(true) end

local scrollBackground = CreateFrame("Frame", nil, DebugFrame, frameTemplate)
if scrollBackground.SetBackdrop then
    scrollBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        }
    )
    scrollBackground:SetBackdropColor(0.03, 0.03, 0.03, 0.42)
    scrollBackground:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
end
DebugFrame.ApplyNativeInsetSkin(scrollBackground)

local scrollFrame = CreateFrame("ScrollFrame", "GSEGUIDebugOutputScrollFrame", DebugFrame, "UIPanelScrollFrameTemplate")
local rowContent = CreateFrame("Frame", nil, scrollFrame)
rowContent:SetSize(1, 1)
scrollFrame:SetScrollChild(rowContent)
scrollFrame:EnableMouseWheel(true)
scrollBackground:Show()
headerBackground:Show()
headerScrollFrame:Show()
scrollFrame:Show()

-- Route the debugger's main scrollbar through NativeUI's slim modern painter
-- so it matches the editor's outer scrollbar instead of Blizzard's gold default.
-- The slim painter handles both EUI and the modern theme; outside of those it
-- no-ops and Blizzard's default scrollbar stays.
if GSE.UI and GSE.UI.ApplyModernSlimScrollBar then
    local debugScrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() .. "ScrollBar"]
    if debugScrollBar then GSE.UI.ApplyModernSlimScrollBar(debugScrollBar, scrollBackground, -6, 0, 0) end
end

local headerLabels = {}
local headerHandles = {}
local headerMenuButtons = {}
local headerDragButtons = {}
local rowPool = {}
local debugRows = {}
local visibleRows = {}
local debugErrorTimestamps = {}
local statsResetDebugIndex = 1
local activeColumnFilters = {}
local activeStatsFilters = {}
local activeDebugSort = {column = nil, direction = nil}
local activeStatsSort = {column = nil, direction = nil}
local statsSortScrollToTop = false
local activeSearchText = ""
local UpdateRows
local ApplyColumnLayout
local SetDebuggerStatusText
local RefreshStatsWidget
DebugFrame.DebugRows = debugRows

local function ApplyDebuggerDropdownBackdrop(frame)
    if not (frame and frame.SetBackdrop) then return end
    if GSE.UI and GSE.UI.ApplyNativeDropdownSkin then
        GSE.UI.ApplyNativeDropdownSkin(frame)
        return
    end
    frame:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 11, right = 12, top = 12, bottom = 11}
        }
    )
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
end

local function EnsureDropdownRowVisuals(button)
    if not button.text then
        button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    end
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", button, "LEFT", DEBUG_UI.DROPDOWN_TEXT_LEFT, 1)
    button.text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button:SetFontString(button.text)

    if not button.check then
        button.check = button:CreateTexture(nil, "ARTWORK")
    end
    button.check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
    button.check:SetSize(DEBUG_UI.DROPDOWN_CHECK_SIZE, DEBUG_UI.DROPDOWN_CHECK_SIZE)
    button.check:ClearAllPoints()
    button.check:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.check:SetTexCoord(0, 0.5, 0.5, 1)

    if not button.uncheck then
        button.uncheck = button:CreateTexture(nil, "ARTWORK")
    end
    button.uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
    button.uncheck:SetSize(DEBUG_UI.DROPDOWN_CHECK_SIZE, DEBUG_UI.DROPDOWN_CHECK_SIZE)
    button.uncheck:ClearAllPoints()
    button.uncheck:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.uncheck:SetTexCoord(0.5, 1, 0.5, 1)
end

local function ConfigureDropdownRow(button, index, text, checked, onClick, textColor)
    button:ClearAllPoints()
    button:EnableMouse(true)
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
    button:SetHeight(DEBUG_UI.DROPDOWN_ROW_HEIGHT)
    button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", 0, -((index - 1) * DEBUG_UI.DROPDOWN_ROW_HEIGHT))
    button:SetPoint("RIGHT", button:GetParent(), "RIGHT", 0, 0)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontNormalSmall")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    EnsureDropdownRowVisuals(button)
    button.text:SetText(tostring(text or ""))
    if checked then
        button.check:Show()
        button.uncheck:Hide()
    else
        button.check:Hide()
        button.uncheck:Show()
    end
    button.check:SetVertexColor(1, 1, 1, 1)
    button.uncheck:SetVertexColor(1, 1, 1, 1)
    if textColor then
        button.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    elseif checked then
        button.text:SetTextColor(1, 0.82, 0, 1)
    else
        button.text:SetTextColor(1, 1, 1, 1)
    end
    button:SetScript("OnClick", onClick)
    button:Show()
end

local function HideDropdownScrollBar(scrollFrame)
    if not scrollFrame then return end
    local scrollBar = scrollFrame.ScrollBar
    local name = scrollFrame.GetName and scrollFrame:GetName()
    if not scrollBar and name then scrollBar = _G[name .. "ScrollBar"] end
    if scrollBar then scrollBar:Hide() end
end

local function IsDebugColumnVisible(index)
    local column = debugColumns[index]
    return column and column.visible ~= false
end

local function GetVisibleDebugColumnOrder()
    local visible = {}
    for _, columnIndex in ipairs(debugColumnOrder) do
        if IsDebugColumnVisible(columnIndex) then visible[#visible + 1] = columnIndex end
    end
    return visible
end

local function GetDebugColumnOrderPosition(columnIndex)
    for position, orderedColumnIndex in ipairs(debugColumnOrder) do
        if orderedColumnIndex == columnIndex then return position end
    end
end

local function MoveDebugColumnBefore(columnIndex, beforeColumnIndex)
    if not columnIndex or columnIndex == beforeColumnIndex then return false end
    local oldPosition = GetDebugColumnOrderPosition(columnIndex)
    if not oldPosition then return false end
    if beforeColumnIndex == debugColumnOrder[oldPosition + 1] then return false end
    if not beforeColumnIndex and oldPosition == #debugColumnOrder then return false end
    table.remove(debugColumnOrder, oldPosition)
    local insertPosition = beforeColumnIndex and GetDebugColumnOrderPosition(beforeColumnIndex) or nil
    if insertPosition then
        table.insert(debugColumnOrder, insertPosition, columnIndex)
    else
        debugColumnOrder[#debugColumnOrder + 1] = columnIndex
    end
    return true
end

local function GetVisibleDebugColumnCount()
    local count = 0
    for i in ipairs(debugColumns) do
        if IsDebugColumnVisible(i) then count = count + 1 end
    end
    return count
end

local function GetColumnTotalWidth()
    local width = 0
    for i, column in ipairs(debugColumns) do
        if IsDebugColumnVisible(i) then
            if width > 0 then width = width + DEBUG_UI.COLUMN_GAP end
            width = width + (column.width or 0)
        end
    end
    return width
end

local function SaveColumnWidths()
    local location = EnsureDebuggerLocation()
    location.columnVersion = DEBUG_UI.DEBUG_COLUMN_SCHEMA_VERSION
    location.columnWidths = {}
    location.columnVisibility = {}
    location.columnOrder = {}
    for i, column in ipairs(debugColumns) do
        location.columnWidths[i] = column.width
        location.columnVisibility[i] = column.visible ~= false
    end
    for orderIndex, columnIndex in ipairs(debugColumnOrder) do
        location.columnOrder[orderIndex] = columnIndex
    end
end

local function TextWidthFromPixels(column)
    return math.max(string.len(column.label or ""), math.floor((column.width or 80) / 7))
end

local function ExportColumnText(text, width)
    local value = StripDebugColor(text)
    return value .. string.rep(" ", math.max(0, width - string.len(value)))
end

DebugFrame.LegacyExportValue = function(text)
    return StripDebugColor(text):gsub("\t", " "):gsub("\r", " "):gsub("\n", " ")
end

DebugFrame.SplitLegacyActionAndSpellbook = function(actionSpellbook)
    local clean = DebugFrame.LegacyExportValue(actionSpellbook)
    local action, spellbook = string.match(clean, "^(.-)%s+%-%s+(.*)$")
    if action then return Trim(action), Trim(spellbook) end
    return clean, ""
end

local function PercentText(count, total)
    if not total or total <= 0 then return "0.00%" end
    return string.format("%.2f%%", (count / total) * 100)
end

local function HasActiveFilters()
    for _, value in pairs(activeColumnFilters) do
        if value ~= nil then return true end
    end
    return false
end

local function HasActiveSearch()
    return activeSearchText and activeSearchText ~= ""
end

local function IsFilterableColumn(columnIndex)
    return columnIndex and columnIndex > 2
end

local function GetDebugColumnIndex(label)
    for index, column in ipairs(debugColumns) do
        if column.label == label then return index end
    end
end

local function IsDebugSortableColumn(columnIndex)
    local column = columnIndex and debugColumns[columnIndex]
    local label = column and column.label
    return label == "Timestamp" or label == "Step"
end

local function HasDebugColumnMenu(columnIndex)
    return IsFilterableColumn(columnIndex) or IsDebugSortableColumn(columnIndex)
end

local function GetDebugRowTimestamp(row)
    local timestampIndex = GetDebugColumnIndex("Timestamp")
    local timestamp = timestampIndex and row and row.values and StripDebugColor(row.values[timestampIndex] or "") or nil
    if timestamp and timestamp ~= "" then return timestamp end
end

local function RowHasSpellbookNotFound(row)
    local spellbookIndex = GetDebugColumnIndex("Action / Spellbook")
    local value = spellbookIndex and row and row.values and StripDebugColor(row.values[spellbookIndex] or "") or ""
    return string.find(string.lower(value), "not found in spell book", 1, true) ~= nil
end

local function MarkSpellbookErrorTimestamp(row)
    if not RowHasSpellbookNotFound(row) then return end
    local timestamp = GetDebugRowTimestamp(row)
    if timestamp then debugErrorTimestamps[timestamp] = true end
end

local function RowUsesSpellbookErrorTimestamp(row)
    local timestamp = GetDebugRowTimestamp(row)
    return timestamp and debugErrorTimestamps[timestamp] == true
end

local SUCCESSFUL_CAST_FALLBACK_WINDOW = 8

local function MarkSuccessfulCastRow(row, timestampIndex, castingIndex, castDisplayName)
    if not (row and row.values) then return false end
    row.successfulCastTimestamp = true
    row.values[timestampIndex] = "|cFFFFD100" .. StripDebugColor(row.values[timestampIndex] or "") .. "|r"
    if castingIndex and castDisplayName ~= "" then
        row.values[castingIndex] = "|cFF00D1FFCasting " .. castDisplayName .. "|r"
    end
    return true
end

local function IsSuccessfulCastFallbackRow(row, now)
    if not (row and row.values) then return false end
    if row.successfulCastTimestamp then return false end
    if row.createdAt and now then return (now - row.createdAt) <= SUCCESSFUL_CAST_FALLBACK_WINDOW end
    return false
end

function GSE.GUIDebugMarkSuccessfulCast(spellID, spellName)
    local actionIndex = GetDebugColumnIndex("Action / Spellbook")
    local timestampIndex = GetDebugColumnIndex("Timestamp")
    local castingIndex = GetDebugColumnIndex("Casting")
    if not actionIndex or not timestampIndex then return false end

    local spellIDText = spellID and tostring(spellID) or ""
    local spellNameText = spellName and string.lower(StripDebugColor(spellName)) or ""
    if spellIDText == "" and spellNameText == "" then return false end

    local castDisplayName = StripDebugColor(spellName or "")
    if castDisplayName == "" and spellIDText ~= "" and GSE.GetSpellInfo then
        local spellInfo = GSE.GetSpellInfo(spellID)
        if spellInfo and spellInfo.name then castDisplayName = spellInfo.name end
    end
    if castDisplayName == "" then castDisplayName = spellIDText end
    if spellNameText == "" and castDisplayName ~= "" then spellNameText = string.lower(castDisplayName) end

    local fallbackRow
    local now = GetTime and GetTime() or nil
    for rowIndex = #debugRows, math.max(1, #debugRows - 100), -1 do
        local row = debugRows[rowIndex]
        if not fallbackRow and IsSuccessfulCastFallbackRow(row, now) then fallbackRow = row end
        local actionText = row and row.values and StripDebugColor(row.values[actionIndex] or "") or ""
        local actionLower = string.lower(actionText)
        local matched = (spellIDText ~= "" and string.find(actionText, spellIDText, 1, true) ~= nil)
            or (spellNameText ~= "" and string.find(actionLower, spellNameText, 1, true) ~= nil)

        if matched then
            MarkSuccessfulCastRow(row, timestampIndex, castingIndex, castDisplayName)
            UpdateRows(false)
            return true
        end
    end

    if MarkSuccessfulCastRow(fallbackRow, timestampIndex, castingIndex, castDisplayName) then
        UpdateRows(false)
        return true
    end

    return false
end

local function RowSearchText(row)
    if not row then return "" end
    if row.message then return StripDebugColor(row.message) end
    local values = {}
    for i = 1, #debugColumns do
        values[#values + 1] = StripDebugColor(row.values and row.values[i] or "")
    end
    return table.concat(values, " ")
end

local function RowMatchesSearch(row)
    if not HasActiveSearch() then return true end
    local haystack = string.lower(RowSearchText(row))
    local needle = string.lower(activeSearchText)
    return string.find(haystack, needle, 1, true) ~= nil
end

local function RowMatchesFilters(row)
    if not RowMatchesSearch(row) then return false end
    if not HasActiveFilters() then return true end
    if row and row.message then return false end
    for columnIndex, filterValue in pairs(activeColumnFilters) do
        local value = row and row.values and StripDebugColor(row.values[columnIndex] or "") or ""
        if value ~= filterValue then return false end
    end
    return true
end

local function ParseDebugTimestampSeconds(value)
    local hour, minute, second = tostring(value or ""):match("^(%d+):(%d+):(%d+)$")
    if not hour then return nil end
    return (tonumber(hour) or 0) * 3600 + (tonumber(minute) or 0) * 60 + (tonumber(second) or 0)
end

local function GetDebugSortValue(row, columnIndex)
    if not (row and row.values and columnIndex) then return nil end
    local value = StripDebugColor(row.values[columnIndex] or "")
    local column = debugColumns[columnIndex]
    if column and column.label == "Timestamp" then
        return ParseDebugTimestampSeconds(value) or value
    elseif column and column.label == "Step" then
        return tonumber(value) or value
    end
    return value
end

local function ApplyDebugVisibleSort()
    if not activeDebugSort.column then return end
    local sortColumn = activeDebugSort.column
    local sortDirection = activeDebugSort.direction == "DESC" and "DESC" or "ASC"
    table.sort(
        visibleRows,
        function(left, right)
            local leftValue = GetDebugSortValue(left, sortColumn)
            local rightValue = GetDebugSortValue(right, sortColumn)
            if leftValue ~= nil and rightValue ~= nil and leftValue ~= rightValue then
                if type(leftValue) ~= type(rightValue) then
                    leftValue = tostring(leftValue)
                    rightValue = tostring(rightValue)
                end
                if sortDirection == "DESC" then return leftValue > rightValue end
                return leftValue < rightValue
            end
            local leftIndex = left and left.debugIndex or 0
            local rightIndex = right and right.debugIndex or 0
            if sortDirection == "DESC" then return leftIndex > rightIndex end
            return leftIndex < rightIndex
        end
    )
end

local function RebuildVisibleRows()
    for i = #visibleRows, 1, -1 do
        visibleRows[i] = nil
    end
    for _, row in ipairs(debugRows) do
        if RowMatchesFilters(row) then visibleRows[#visibleRows + 1] = row end
    end
    ApplyDebugVisibleSort()
end

local function FindSearchSuggestion(prefix)
    prefix = Trim(StripDebugColor(prefix or ""))
    if prefix == "" then return nil end

    local lowerPrefix = string.lower(prefix)
    local seen = {}
    local function CheckCandidate(candidate)
        candidate = Trim(StripDebugColor(candidate or ""))
        if candidate == "" or seen[candidate] then return nil end
        seen[candidate] = true
        if string.sub(string.lower(candidate), 1, string.len(lowerPrefix)) == lowerPrefix then return candidate end
        return nil
    end

    for _, row in ipairs(debugRows) do
        if row and row.values then
            for i = 2, #debugColumns do
                local suggestion = CheckCandidate(row.values[i])
                if suggestion then return suggestion end
            end
        elseif row and row.message then
            local suggestion = CheckCandidate(row.message)
            if suggestion then return suggestion end
        end
    end
    return nil
end

local function ApplySearchFilter(scrollToTop)
    RebuildVisibleRows()
    if scrollToTop and scrollFrame and scrollFrame.SetVerticalScroll then scrollFrame:SetVerticalScroll(0) end
    UpdateRows(false)
    if RefreshStatsWidget then RefreshStatsWidget() end
    if SetDebuggerStatusText then SetDebuggerStatusText() end
end

local function BuildStatsData()
    local eventCounts, eventLabels, eventsByColumn, total = {}, {}, {}, 0
    local stepColumnIndex = GetDebugColumnIndex("Step")
    local blockColumnIndex = GetDebugColumnIndex("Block")
    for i = 2, #debugColumns do
        if IsDebugColumnVisible(i) then eventsByColumn[i] = {} end
    end

    for _, row in ipairs(visibleRows) do
        if row and not row.message and row.values then
            local rowIndex = tonumber(row.debugIndex) or 0
            if rowIndex >= statsResetDebugIndex then
                total = total + 1
                for i = 2, #debugColumns do
                    if IsDebugColumnVisible(i) then
                        local value = StripDebugColor(row.values[i] or "")
                        if value ~= "" then
                            local eventKey = tostring(i) .. "\t" .. value
                            if not eventCounts[eventKey] then
                                eventCounts[eventKey] = 0
                                if i == stepColumnIndex then
                                    eventLabels[eventKey] = "|cFFFFD100Step:|r|cFFFFFFFF" .. value .. "|r"
                                elseif i == blockColumnIndex then
                                    eventLabels[eventKey] = "|cFFFFD100Blk:" .. value .. "|r"
                                else
                                    eventLabels[eventKey] = row.values[i] or value
                                end
                                eventsByColumn[i][#eventsByColumn[i] + 1] = eventKey
                            end
                            eventCounts[eventKey] = eventCounts[eventKey] + 1
                        end
                    end
                end
            end
        end
    end

    local events = {}
    for i = 2, #debugColumns do
        if eventsByColumn[i] then
            for _, eventKey in ipairs(eventsByColumn[i]) do
                events[#events + 1] = eventKey
            end
        end
    end
    return events, eventCounts, total, eventLabels
end

local function HasActiveStatsFilters()
    for _, value in pairs(activeStatsFilters) do
        if value ~= nil then return true end
    end
    return false
end

local function StatsRowMatchesFilters(row, ignoredColumnIndex)
    if not HasActiveStatsFilters() then return true end
    for columnIndex, filterValue in pairs(activeStatsFilters) do
        if columnIndex ~= ignoredColumnIndex and row.values[columnIndex] ~= filterValue then return false end
    end
    return true
end

local function BuildStatsRows(ignoredFilterColumn)
    local events, eventCounts, total, eventLabels = BuildStatsData()
    local rows = {}
    for _, eventKey in ipairs(events) do
        local count = eventCounts[eventKey] or 0
        local label = eventLabels[eventKey] or eventKey
        local row = {
            eventKey = eventKey,
            label = label,
            count = count,
            percentage = PercentText(count, total),
            percentValue = total > 0 and (count / total) * 100 or 0,
            values = {
                StripDebugColor(label),
                tostring(count),
                PercentText(count, total)
            }
        }
        if StatsRowMatchesFilters(row, ignoredFilterColumn) then rows[#rows + 1] = row end
    end
    if activeStatsSort.column == 2 or activeStatsSort.column == 3 then
        local sortColumn = activeStatsSort.column
        local sortDirection = activeStatsSort.direction == "DESC" and "DESC" or "ASC"
        table.sort(
            rows,
            function(left, right)
                local leftValue = sortColumn == 3 and (left.percentValue or 0) or (left.count or 0)
                local rightValue = sortColumn == 3 and (right.percentValue or 0) or (right.count or 0)
                if leftValue == rightValue then
                    return tostring(left.label or "") < tostring(right.label or "")
                end
                if sortDirection == "DESC" then return leftValue > rightValue end
                return leftValue < rightValue
            end
        )
    end
    return rows, total
end

local function AddFilterSummary()
    local lines = {"Filters:"}
    for _, i in ipairs(debugColumnOrder) do
        local column = debugColumns[i]
        if IsFilterableColumn(i) then
            local filterValue = activeColumnFilters[i]
            local checked = filterValue and "[x]" or "[ ]"
            lines[#lines + 1] =
                checked .. " " .. tostring(column.label or ("Column " .. i)) .. ": " .. tostring(filterValue or "All Events")
        end
    end
    lines[#lines + 1] = ""
    return lines
end

local function DebugRowsToExport()
    local exportLines = {}
    local widths = {}
    for _, i in ipairs(debugColumnOrder) do
        local column = debugColumns[i]
        if IsDebugColumnVisible(i) then
            widths[i] = TextWidthFromPixels(column)
            exportLines[#exportLines + 1] = ExportColumnText(column.label, widths[i])
        end
    end

    local lines = AddFilterSummary()
    lines[#lines + 1] = table.concat(exportLines, " | ")
    for _, row in ipairs(visibleRows) do
        if row.message then
            lines[#lines + 1] = StripDebugColor(row.message)
        else
            local values = {}
            for _, i in ipairs(debugColumnOrder) do
                if IsDebugColumnVisible(i) then
                    values[#values + 1] = ExportColumnText(row.values and row.values[i] or "", widths[i])
                end
            end
            lines[#lines + 1] = table.concat(values, " | ")
        end
    end
    return table.concat(lines, "\n")
end

DebugFrame.BuildLegacyExportLineFromValues = function(values)
    if not values then return nil end
    local action, spellbook = DebugFrame.SplitLegacyActionAndSpellbook(values[6])
    local block = DebugFrame.LegacyExportValue(values[3])
    if block == "" or string.lower(block) == "none" then
        block = ""
    else
        block = "block:" .. block
    end
    return table.concat(
        {
            DebugFrame.LegacyExportValue(values[4]),
            DebugFrame.LegacyExportValue(values[2]),
            DebugFrame.LegacyExportValue(values[1]),
            action,
            spellbook,
            DebugFrame.LegacyExportValue(values[7]),
            DebugFrame.LegacyExportValue(values[8]),
            DebugFrame.LegacyExportValue(values[5]),
            DebugFrame.LegacyExportValue(values[9]),
            DebugFrame.LegacyExportValue(values[10]),
            block
        },
        ","
    )
end

DebugFrame.DebugRowsToLegacyExport = function()
    local lines = {}
    for _, row in ipairs(debugRows) do
        if row.legacyLine and row.legacyLine ~= "" then
            lines[#lines + 1] = row.legacyLine
        elseif row.values then
            local line = DebugFrame.BuildLegacyExportLineFromValues(row.values)
            if line and line ~= "" then lines[#lines + 1] = line end
        elseif row.message and (string.find(row.message, "\t", 1, true) or string.find(row.message, ",", 1, true)) then
            lines[#lines + 1] = DebugFrame.LegacyExportValue(row.message)
        end
    end
    return table.concat(lines, "\n")
end

local function DebugRowsToStats()
    local statsRowsData, total = BuildStatsRows()
    local lines = {"Debugger Event Statistics", "Total Events Logged: " .. tostring(DebugFrame:GetTotalDebugEventsLogged()), ""}
    local filterLines = AddFilterSummary()
    for _, line in ipairs(filterLines) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = "Event | Amount | Percentage %"
    for _, row in ipairs(statsRowsData) do
        lines[#lines + 1] = string.format("%s | %d | %s", row.values[1] or "", row.count or 0, row.percentage or "0.00%")
    end
    if #statsRowsData == 0 then lines[#lines + 1] = "No matching events." end
    return table.concat(lines, "\n")
end

local function EnsureStatsWidgetLocation()
    if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
    if GSE.isEmpty(GSEOptions.frameLocations.debugStats) then GSEOptions.frameLocations.debugStats = {} end
    return GSEOptions.frameLocations.debugStats
end

local function EnsureHardwareWidgetLocation()
    if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
    if GSE.isEmpty(GSEOptions.frameLocations.debugHardware) then GSEOptions.frameLocations.debugHardware = {} end
    return GSEOptions.frameLocations.debugHardware
end

local function CopyStatsColumns(location)
    local savedWidths = location and location.columnWidths
    local columns = {}
    for i, column in ipairs(STATS_COLUMNS) do
        columns[i] = {
            label = column.label,
            width = ClampNumber(savedWidths and savedWidths[i], column.min or 30, 900, column.width or 80),
            min = column.min or 30,
            justify = column.justify or "LEFT"
        }
    end
    local maxWidth = DEBUG_UI.STATS_WIDGET_WIDTH - 32
    local totalWidth = 8
    for i, column in ipairs(columns) do
        totalWidth = totalWidth + (column.width or 0)
        if i < #columns then totalWidth = totalWidth + DEBUG_UI.STATS_COLUMN_GAP end
    end
    if totalWidth > maxWidth then
        for _, column in ipairs(columns) do
            local extraWidth = math.max(0, (column.width or 0) - (column.min or 30))
            local reduction = math.min(totalWidth - maxWidth, extraWidth)
            column.width = (column.width or 0) - reduction
            totalWidth = totalWidth - reduction
            if totalWidth <= maxWidth then break end
        end
    end
    return columns
end

local statsLocation = EnsureStatsWidgetLocation()
local statsColumns = CopyStatsColumns(statsLocation)
local statsWidget = GSE.CreateDebuggerEditorFrame("GSEGUIDebugStatsWidget", UIParent)
statsWidget:SetFrameStrata(currentDebuggerStrata)
statsWidget:SetClampedToScreen(false)
statsWidget:SetMovable(true)
statsWidget:SetResizable(false)
statsWidget:EnableMouse(true)
local defaultStatsHeight = DEBUG_UI.STATS_WIDGET_HEADER_HEIGHT + (DEBUG_UI.STATS_WIDGET_VISIBLE_ROWS * DEBUG_UI.STATS_WIDGET_ROW_HEIGHT) + 12
statsWidget:SetSize(DEBUG_UI.STATS_WIDGET_WIDTH, DebugFrame:GetHeight() or defaultStatsHeight)
if statsWidget.SetClipsChildren then statsWidget:SetClipsChildren(true) end
statsWidget:SetPoint("TOPLEFT", DebugFrame, "TOPRIGHT", DEBUG_UI.STATS_WIDGET_ANCHOR_X, -10)
if not statsWidget.GSEUsesBlizzardPanelTemplate and statsWidget.SetBackdrop then
    statsWidget:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 8, right = 8, top = 8, bottom = 8}
        }
    )
    statsWidget:SetBackdropColor(0.03, 0.03, 0.03, 0.94)
    statsWidget:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

if GSE.Skin and GSE.Skin.IsExternalProviderActive and GSE.Skin.IsExternalProviderActive() and GSE.Skin.Frame then
    GSE.Skin.Frame(statsWidget)
end

local function SaveStatsWidgetLocation()
    local location = EnsureStatsWidgetLocation()
    location.width = ClampNumber(statsWidget:GetWidth(), DEBUG_UI.STATS_WIDGET_MIN_WIDTH, GetMaxStatsWidgetWidth(), DEBUG_UI.STATS_WIDGET_WIDTH)
    location.height = ClampNumber(statsWidget:GetHeight(), DEBUG_UI.STATS_WIDGET_MIN_HEIGHT, GetMaxStatsWidgetHeight(), defaultStatsHeight)
    location.detached = statsWidget.GSESideDetached == true
    location.columnWidths = {}
    for i, column in ipairs(statsColumns) do
        location.columnWidths[i] = column.width
    end
end

local function AnchorStatsWidget()
    if statsWidget.GSESideDetached then return end
    statsWidget:ClearAllPoints()
    statsWidget:SetPoint("TOPLEFT", DebugFrame, "TOPRIGHT", DEBUG_UI.STATS_WIDGET_ANCHOR_X, -10)
end

local function UpdateStatsButtonText()
    if DebugFrame.DebugStatsViewButton then
        GSE.SetDebuggerButtonText(DebugFrame.DebugStatsViewButton, statsWidget:IsShown() and "Stats: On" or "Stats: Off")
    end
end

local statsTitle = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
statsTitle:SetPoint("TOPLEFT", statsWidget, "TOPLEFT", 36, -20)
statsTitle:SetPoint("TOPRIGHT", statsWidget, "TOPRIGHT", -36, -20)
statsTitle:SetJustifyH("CENTER")
statsTitle:SetText(DebuggerWindowTitle("Debug Stats"))
DebugFrame.ApplyEditorWindowStyle(statsWidget, statsTitle)
DebugFrame.PositionDebuggerSideTitle(statsWidget, statsTitle, DebuggerWindowTitle("Debug Stats"))

local statsFilterMenu
local LayoutStatsWidget

statsWidget.closeButton = CreateFrame("Button", nil, statsWidget, "UIPanelButtonTemplate")
statsWidget.closeButton:SetSize(90, DEBUG_UI.BUTTON_HEIGHT)
statsWidget.closeButton:SetText("Close")
GSE.StyleDebugTextButton(statsWidget.closeButton)
statsWidget.closeButton:SetScript(
    "OnClick",
    function()
        local location = EnsureStatsWidgetLocation()
        location.open = false
        if statsFilterMenu then statsFilterMenu:Hide() end
        statsWidget:Hide()
        UpdateStatsButtonText()
    end
)
if statsWidget.CloseButton then statsWidget.CloseButton:SetScript("OnClick", statsWidget.closeButton:GetScript("OnClick")) end

local statsSummary = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statsSummary:SetPoint("TOPLEFT", statsWidget, "TOPLEFT", 12, -44)
statsSummary:SetPoint("TOPRIGHT", statsWidget, "TOPRIGHT", -12, -44)
statsSummary:SetJustifyH("CENTER")

local statsMatchText = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statsMatchText:SetWidth(160)
statsMatchText:SetJustifyH("CENTER")

statsWidget.statustext = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statsWidget.statustext:SetJustifyH("CENTER")
statsWidget.eventsLoggedText = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statsWidget.eventsLoggedText:SetJustifyH("CENTER")
statsWidget.logTimerText = statsWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statsWidget.logTimerText:SetJustifyH("CENTER")

local statsCombatStart
local statsCombatElapsed = 0
local function FormatStatsCombatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function UpdateStatsCombatTimer()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        if not statsCombatStart then statsCombatStart = GetTime and GetTime() or 0 end
        if DebugFrame.DebugCombatTimer then
            DebugFrame.DebugCombatTimer:SetText("|cFFFFD100Status:|r |cFFFF2626Combat " .. FormatStatsCombatTime((GetTime and GetTime() or 0) - statsCombatStart) .. "|r")
            DebugFrame.DebugCombatTimer:SetTextColor(1, 1, 1, 1)
        end
    else
        statsCombatStart = nil
        if DebugFrame.DebugCombatTimer then
            DebugFrame.DebugCombatTimer:SetText("|cFFFFD100Status:|r |cFF59FF59No Combat|r")
            DebugFrame.DebugCombatTimer:SetTextColor(1, 1, 1, 1)
        end
    end
end

local function UpdateStatsMatchText()
    statsMatchText:SetText("")
    statsMatchText:Hide()
end

function DebugFrame:FormatDebugLogTimer(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

function DebugFrame:GetDebugLogElapsed()
    local elapsed = tonumber(GSE.GUIDebugLogElapsed) or 0
    if GSE.GUIDebugLogStartedAt and GSE.UnsavedOptions and GSE.UnsavedOptions["DebugSequenceExecution"] and not GSE.GUIDebugPaused then
        elapsed = elapsed + ((GetTime and GetTime() or 0) - GSE.GUIDebugLogStartedAt)
    end
    return math.max(0, elapsed)
end

function DebugFrame:GetTotalDebugEventsLogged()
    local eventCount = 0
    for _, row in ipairs(debugRows) do
        if row and row.values then eventCount = eventCount + 1 end
    end
    return eventCount
end

function DebugFrame:UpdateStatsFooter()
    if statsSummary then statsSummary:SetText("|cffffd100Total Events Logged:|r " .. tostring(self:GetTotalDebugEventsLogged())) end
    if statsWidget.eventsLoggedText then statsWidget.eventsLoggedText:Hide() end
    if statsWidget.logTimerText then
        statsWidget.logTimerText:SetText("|cffffd100Log Timer:|r " .. self:FormatDebugLogTimer(self:GetDebugLogElapsed()))
    end
end

statsWidget:RegisterEvent("PLAYER_REGEN_DISABLED")
statsWidget:RegisterEvent("PLAYER_REGEN_ENABLED")
statsWidget:SetScript(
    "OnEvent",
    function(_, event)
        if UnitAffectingCombat and UnitAffectingCombat("player") then
            statsCombatStart = GetTime and GetTime() or 0
            if event == "PLAYER_REGEN_DISABLED" then
                statsResetDebugIndex = #debugRows + 1
                if RefreshStatsWidget then RefreshStatsWidget() end
            end
        else
            statsCombatStart = nil
        end
        UpdateStatsCombatTimer()
    end
)
statsWidget:SetScript(
    "OnUpdate",
    function(_, elapsed)
        statsCombatElapsed = (statsCombatElapsed or 0) + (elapsed or 0)
        if statsCombatElapsed < 0.2 then return end
        statsCombatElapsed = 0
        UpdateStatsCombatTimer()
        UpdateStatsMatchText()
    end
)
DebugFrame:SetScript(
    "OnUpdate",
    function(_, elapsed)
        DebugFrame.debugCombatElapsed = (DebugFrame.debugCombatElapsed or 0) + (elapsed or 0)
        if DebugFrame.debugCombatElapsed < 0.2 then return end
        DebugFrame.debugCombatElapsed = 0
        UpdateStatsCombatTimer()
    end
)
UpdateStatsCombatTimer()
UpdateStatsMatchText()

local statsScrollBackground = CreateFrame("Frame", nil, statsWidget, frameTemplate)
if statsScrollBackground.SetBackdrop then
    statsScrollBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        }
    )
    statsScrollBackground:SetBackdropColor(0.03, 0.03, 0.03, 0.42)
    statsScrollBackground:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
end
DebugFrame.ApplyNativeInsetSkin(statsScrollBackground)

local statsHeaderBackground = CreateFrame("Frame", nil, statsScrollBackground, frameTemplate)
statsHeaderBackground:SetHeight(20)
if statsHeaderBackground.SetClipsChildren then statsHeaderBackground:SetClipsChildren(true) end
if statsHeaderBackground.SetBackdrop then
    statsHeaderBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        }
    )
    statsHeaderBackground:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    if GSE.Skin and GSE.Skin.PaintAccentBorder then
        GSE.Skin.PaintAccentBorder(statsHeaderBackground, 0.7, 0.62, 0.12, 1)
    else
        statsHeaderBackground:SetBackdropBorderColor(0.7, 0.62, 0.12, 1)
    end
end
DebugFrame.ApplyNativeInsetSkin(statsHeaderBackground)

local statsRowsScrollFrame = CreateFrame("ScrollFrame", "GSEGUIDebugStatsRowsScrollFrame", statsScrollBackground, "UIPanelScrollFrameTemplate")
local statsRowsContent = CreateFrame("Frame", nil, statsRowsScrollFrame)
statsRowsContent:SetSize(1, 1)
statsRowsScrollFrame:SetScrollChild(statsRowsContent)
statsRowsScrollFrame:EnableMouseWheel(true)
if statsRowsScrollFrame.SetClipsChildren then statsRowsScrollFrame:SetClipsChildren(true) end

local statsHeaderMenuButtons = {}
statsFilterMenu = CreateFrame("Frame", "GSEGUIDebugStatsFilterMenu", UIParent, frameTemplate)
statsFilterMenu:SetFrameStrata(GetDebuggerPopupStrata())
statsFilterMenu:SetClampedToScreen(true)
statsFilterMenu:EnableMouse(true)
statsFilterMenu:Hide()
if statsFilterMenu.SetBackdrop then
    ApplyDebuggerDropdownBackdrop(statsFilterMenu)
end

local statsFilterScroll = CreateFrame("ScrollFrame", nil, statsFilterMenu, "UIPanelScrollFrameTemplate")
statsFilterScroll:SetPoint("TOPLEFT", statsFilterMenu, "TOPLEFT", DEBUG_UI.DROPDOWN_INSET, -DEBUG_UI.DROPDOWN_INSET)
statsFilterScroll:SetPoint("BOTTOMRIGHT", statsFilterMenu, "BOTTOMRIGHT", -DEBUG_UI.DROPDOWN_INSET, DEBUG_UI.DROPDOWN_INSET)
HideDropdownScrollBar(statsFilterScroll)
local statsFilterContent = CreateFrame("Frame", nil, statsFilterScroll)
statsFilterContent:SetSize(1, 1)
statsFilterScroll:SetScrollChild(statsFilterContent)
local statsFilterButtons = {}

local function UpdateStatsFilterIndicators()
    for i, button in ipairs(statsHeaderMenuButtons) do
        button:SetText("v")
        local fontString = button:GetFontString()
        if fontString then
            if activeStatsFilters[i] or activeStatsSort.column == i then
                fontString:SetTextColor(1, 0.82, 0.15, 1)
            else
                fontString:SetTextColor(0.75, 0.75, 0.75, 1)
            end
        end
    end
end

local function GetStatsFilterValuesForColumn(columnIndex)
    local values, seen, displayValues = {}, {}, {}
    local rows = BuildStatsRows(columnIndex)
    for _, row in ipairs(rows) do
        local value = row.values and row.values[columnIndex]
        if value and value ~= "" and not seen[value] then
            seen[value] = true
            displayValues[value] = columnIndex == 1 and row.label or value
            values[#values + 1] = value
        end
    end
    return values, displayValues
end

local function EnsureStatsFilterButton(index)
    if statsFilterButtons[index] then return statsFilterButtons[index] end
    local button = CreateFrame("Button", nil, statsFilterContent)
    EnsureDropdownRowVisuals(button)
    button:Hide()
    statsFilterButtons[index] = button
    return button
end

for i = 1, DEBUG_UI.DROPDOWN_PRECREATE_ROWS do
    EnsureStatsFilterButton(i)
end

local function ApplyStatsFilters()
    UpdateStatsFilterIndicators()
    if RefreshStatsWidget then RefreshStatsWidget() end
end

local function ApplyStatsSort(columnIndex, direction)
    if columnIndex ~= 2 and columnIndex ~= 3 then return end
    activeStatsFilters[2] = nil
    activeStatsFilters[3] = nil
    activeStatsSort.column = columnIndex
    activeStatsSort.direction = direction == "DESC" and "DESC" or "ASC"
    statsSortScrollToTop = true
    ApplyStatsFilters()
end

local function ShowStatsFilterMenu(columnIndex, anchor)
    local isSortColumn = columnIndex == 2 or columnIndex == 3
    local values, displayValues = {}, {}
    if not isSortColumn then
        values, displayValues = GetStatsFilterValuesForColumn(columnIndex)
    end

    local valueCount = math.min(#values, DEBUG_UI.DROPDOWN_PRECREATE_ROWS - 1)
    local rowCount = isSortColumn and 2 or math.max(1, valueCount + 1)
    local menuWidth = math.max(180, statsColumns[columnIndex] and statsColumns[columnIndex].width or 120)
    local menuHeight = rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT + (DEBUG_UI.DROPDOWN_INSET * 2)
    statsFilterMenu:SetSize(menuWidth, menuHeight)
    statsFilterContent:SetSize(menuWidth - (DEBUG_UI.DROPDOWN_INSET * 2), rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT)

    if isSortColumn then
        ConfigureDropdownRow(
            EnsureStatsFilterButton(1),
            1,
            "L > H",
            activeStatsSort.column == columnIndex and activeStatsSort.direction == "ASC",
            function()
                statsFilterMenu:Hide()
                ApplyStatsSort(columnIndex, "ASC")
            end
        )
        ConfigureDropdownRow(
            EnsureStatsFilterButton(2),
            2,
            "H > L",
            activeStatsSort.column == columnIndex and activeStatsSort.direction == "DESC",
            function()
                statsFilterMenu:Hide()
                ApplyStatsSort(columnIndex, "DESC")
            end
        )
        for i = 3, #statsFilterButtons do
            statsFilterButtons[i]:Hide()
        end
        statsFilterScroll:SetVerticalScroll(0)
        HideDropdownScrollBar(statsFilterScroll)
        statsFilterMenu:ClearAllPoints()
        RaiseDebuggerPopup(statsFilterMenu, anchor)
        statsFilterMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
        if DebugFrame.ShowDebuggerDropdownClickAway then DebugFrame.ShowDebuggerDropdownClickAway(statsFilterMenu) end
        statsFilterMenu:Show()
        return
    end

    local function ConfigureButton(button, index, text, value, checked, isAllEvents)
        ConfigureDropdownRow(
            button,
            index,
            text,
            checked,
            function()
                if isAllEvents then
                    for filterIndex in pairs(activeStatsFilters) do
                        activeStatsFilters[filterIndex] = nil
                    end
                    activeStatsSort.column = nil
                    activeStatsSort.direction = nil
                    statsSortScrollToTop = true
                else
                    activeStatsFilters[columnIndex] = value
                end
                statsFilterMenu:Hide()
                ApplyStatsFilters()
            end,
            isAllEvents and {1, 0.82, 0, 1} or nil
        )
    end

    ConfigureButton(
        EnsureStatsFilterButton(1),
        1,
        "All Events in Column Order",
        nil,
        not HasActiveStatsFilters() and not activeStatsSort.column,
        true
    )
    for i = 1, valueCount do
        local value = values[i]
        ConfigureButton(
            EnsureStatsFilterButton(i + 1),
            i + 1,
            displayValues[value] or value,
            value,
            activeStatsFilters[columnIndex] == value
        )
    end
    for i = valueCount + 2, #statsFilterButtons do
        statsFilterButtons[i]:Hide()
    end

    statsFilterScroll:SetVerticalScroll(0)
    HideDropdownScrollBar(statsFilterScroll)
    statsFilterMenu:ClearAllPoints()
    RaiseDebuggerPopup(statsFilterMenu, anchor)
    statsFilterMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    if DebugFrame.ShowDebuggerDropdownClickAway then DebugFrame.ShowDebuggerDropdownClickAway(statsFilterMenu) end
    statsFilterMenu:Show()
end

local function GetStatsColumnTotalWidth()
    local width = 8
    for i, column in ipairs(statsColumns) do
        width = width + (column.width or 0)
        if i < #statsColumns then width = width + DEBUG_UI.STATS_COLUMN_GAP end
    end
    return width
end

local function PositionStatsColumns(parent, labels, reserveMenuSpace)
    local left = 4
    for i, column in ipairs(statsColumns) do
        local label = labels[i]
        label:ClearAllPoints()
        label:SetPoint("LEFT", parent, "LEFT", left, 0)
        local menuWidth = reserveMenuSpace and DEBUG_UI.COLUMN_MENU_WIDTH or 0
        label:SetWidth(math.max(1, (column.width or 0) - menuWidth - 4))
        label:SetHeight(DEBUG_UI.STATS_WIDGET_ROW_HEIGHT)
        label:SetJustifyH(reserveMenuSpace and "LEFT" or column.justify or "LEFT")
        label:SetWordWrap(false)
        left = left + column.width + DEBUG_UI.STATS_COLUMN_GAP
    end
end

local statsHeaderLabels = {}
for i, column in ipairs(statsColumns) do
    local label = statsHeaderBackground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(column.label)
    statsHeaderLabels[i] = label
end
PositionStatsColumns(statsHeaderBackground, statsHeaderLabels, true)

for i, _ in ipairs(statsColumns) do
    local columnIndex = i
    local menuButton = CreateFrame("Button", nil, statsHeaderBackground)
    menuButton:SetSize(DEBUG_UI.COLUMN_MENU_WIDTH, DEBUG_UI.STATS_WIDGET_ROW_HEIGHT - 2)
    if menuButton.SetFrameLevel then menuButton:SetFrameLevel((statsHeaderBackground:GetFrameLevel() or 0) + 20) end
    local arrow = menuButton:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    arrow:SetPoint("CENTER", menuButton, "CENTER", 0, 0)
    arrow:SetJustifyH("CENTER")
    menuButton:SetFontString(arrow)
    menuButton:SetText("v")
    menuButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    menuButton:SetScript(
        "OnClick",
        function(self)
            if statsFilterMenu:IsShown() and statsFilterMenu.columnIndex == columnIndex then
                statsFilterMenu:Hide()
                return
            end
            statsFilterMenu.columnIndex = columnIndex
            ShowStatsFilterMenu(columnIndex, self)
        end
    )
    statsHeaderMenuButtons[columnIndex] = menuButton
end

local statsHeaderHandles = {}
local function PositionStatsHeaderMenus()
    local left = 4
    for i, column in ipairs(statsColumns) do
        local button = statsHeaderMenuButtons[i]
        if button then
            button:ClearAllPoints()
            button:SetPoint("LEFT", statsHeaderBackground, "LEFT", left + (column.width or 0) - DEBUG_UI.COLUMN_MENU_WIDTH - 2, 1)
            button:SetSize(DEBUG_UI.COLUMN_MENU_WIDTH, DEBUG_UI.STATS_WIDGET_ROW_HEIGHT - 2)
        end
        left = left + (column.width or 0) + DEBUG_UI.STATS_COLUMN_GAP
    end
end

local function PositionStatsHeaderHandles()
    local left = 4
    for i, column in ipairs(statsColumns) do
        left = left + (column.width or 0)
        local handle = statsHeaderHandles[i]
        if handle then
            handle:ClearAllPoints()
            handle:SetPoint("LEFT", statsHeaderBackground, "LEFT", left - 2, 0)
            handle:SetHeight(20)
        end
        left = left + DEBUG_UI.STATS_COLUMN_GAP
    end
end

local statsRows = {}
local function RefreshStatsColumnLayout()
    PositionStatsColumns(statsHeaderBackground, statsHeaderLabels, true)
    PositionStatsHeaderMenus()
    PositionStatsHeaderHandles()
    for _, row in ipairs(statsRows) do
        if row.labels then PositionStatsColumns(row, row.labels) end
    end
    UpdateStatsFilterIndicators()
end

for i = 1, #statsColumns - 1 do
    local columnIndex = i
    local handle = CreateFrame("Frame", nil, statsHeaderBackground)
    handle:SetWidth(DEBUG_UI.COLUMN_HANDLE_WIDTH)
    handle:EnableMouse(true)
    local texture = handle:CreateTexture(nil, "OVERLAY")
    texture:SetPoint("TOP", handle, "TOP", 0, -3)
    texture:SetPoint("BOTTOM", handle, "BOTTOM", 0, 3)
    texture:SetWidth(1)
    texture:SetColorTexture(0.7, 0.62, 0.12, 0.8)
    handle.texture = texture
    handle:SetScript("OnEnter", function(self) self.texture:SetColorTexture(1, 0.82, 0.15, 1) end)
    handle:SetScript("OnLeave", function(self) self.texture:SetColorTexture(0.7, 0.62, 0.12, 0.8) end)
    handle:SetScript(
        "OnMouseDown",
        function(self, button)
            if button ~= "LeftButton" then return end
            local cursorX = GetCursorPosition()
            local scale = UIParent and UIParent:GetEffectiveScale() or 1
            self.startCursorX = cursorX / scale
            self.startWidth = statsColumns[columnIndex].width or 0
            self.maxDragDelta = math.max(0, (statsHeaderBackground:GetRight() or self.startCursorX) - self.startCursorX)
            self:SetScript(
                "OnUpdate",
                function(dragHandle)
                    local currentCursorX = GetCursorPosition()
                    local currentScale = UIParent and UIParent:GetEffectiveScale() or 1
                    local delta = (currentCursorX / currentScale) - (dragHandle.startCursorX or 0)
                    if dragHandle.maxDragDelta then delta = math.min(delta, dragHandle.maxDragDelta) end
                    local newWidth = ClampNumber(
                        (dragHandle.startWidth or 0) + delta,
                        statsColumns[columnIndex].min or 30,
                        900,
                        statsColumns[columnIndex].width or 80
                    )
                    if newWidth ~= statsColumns[columnIndex].width then
                        statsColumns[columnIndex].width = newWidth
                        if LayoutStatsWidget then
                            LayoutStatsWidget()
                        else
                            RefreshStatsColumnLayout()
                        end
                    end
                end
            )
        end
    )
    handle:SetScript(
        "OnMouseUp",
        function(self)
            self:SetScript("OnUpdate", nil)
            self.maxDragDelta = nil
            SaveStatsWidgetLocation()
        end
    )
    statsHeaderHandles[columnIndex] = handle
end
PositionStatsHeaderHandles()

LayoutStatsWidget = function()
    if not statsWidget.GSESideDetached then
        local targetHeight = (DebugFrame:GetHeight() or defaultStatsHeight) - 10
        if math.abs((statsWidget:GetWidth() or 0) - DEBUG_UI.STATS_WIDGET_WIDTH) > 0.5 then statsWidget:SetWidth(DEBUG_UI.STATS_WIDGET_WIDTH) end
        if math.abs((statsWidget:GetHeight() or 0) - targetHeight) > 0.5 then statsWidget:SetHeight(targetHeight) end
    end
    statsScrollBackground:ClearAllPoints()
    statsScrollBackground:SetPoint("TOPLEFT", statsWidget, "TOPLEFT", 12, -66)
    statsScrollBackground:SetPoint("BOTTOMRIGHT", statsWidget, "BOTTOMRIGHT", -12, 88)
    statsMatchText:ClearAllPoints()
    statsMatchText:SetPoint("TOPLEFT", statsScrollBackground, "BOTTOMLEFT", 0, -4)
    statsMatchText:SetPoint("TOPRIGHT", statsScrollBackground, "BOTTOMRIGHT", 0, -4)
    statsMatchText:Hide()
    statsHeaderBackground:ClearAllPoints()
    statsHeaderBackground:SetPoint("TOPLEFT", statsScrollBackground, "TOPLEFT", 4, -4)
    statsHeaderBackground:SetPoint("TOPRIGHT", statsScrollBackground, "TOPRIGHT", -4, -4)
    statsHeaderBackground:SetHeight(20)
    statsRowsScrollFrame:ClearAllPoints()
    statsRowsScrollFrame:SetPoint("TOPLEFT", statsHeaderBackground, "BOTTOMLEFT", 0, -4)
    statsRowsScrollFrame:SetPoint("BOTTOMRIGHT", statsScrollBackground, "BOTTOMRIGHT", -4, 4)
    statsRowsContent:SetWidth(math.max(GetStatsColumnTotalWidth(), statsRowsScrollFrame:GetWidth() or 1))
    statsWidget.closeButton:ClearAllPoints()
    statsWidget.closeButton:SetPoint("BOTTOM", statsWidget, "BOTTOM", 0, 32)
    statsWidget.statustext:ClearAllPoints()
    statsWidget.statustext:SetPoint("BOTTOMLEFT", statsWidget, "BOTTOMLEFT", 14, 11)
    statsWidget.statustext:SetPoint("BOTTOMRIGHT", statsWidget, "BOTTOMRIGHT", -36, 11)
    statsWidget.eventsLoggedText:ClearAllPoints()
    statsWidget.eventsLoggedText:SetPoint("TOPLEFT", statsWidget, "BOTTOMLEFT", 0, 0)
    statsWidget.eventsLoggedText:SetPoint("TOPRIGHT", statsWidget, "BOTTOMRIGHT", 0, 0)
    statsWidget.eventsLoggedText:Hide()
    statsWidget.logTimerText:ClearAllPoints()
    statsWidget.logTimerText:SetPoint("TOPLEFT", statsScrollBackground, "BOTTOMLEFT", 0, -4)
    statsWidget.logTimerText:SetPoint("TOPRIGHT", statsScrollBackground, "BOTTOMRIGHT", 0, -4)
    RefreshStatsColumnLayout()
    DebugFrame.RaiseDebuggerSideChrome(statsWidget)
end

statsWidget:SetScript("OnSizeChanged", function()
    if statsWidget:IsShown() and not statsWidget.GSESideDetached then AnchorStatsWidget() end
    if LayoutStatsWidget then LayoutStatsWidget() end
end)

local function EnsureStatsRow(index)
    if statsRows[index] then return statsRows[index] end
    local row = CreateFrame("Frame", nil, statsRowsContent)
    row:SetHeight(DEBUG_UI.STATS_WIDGET_ROW_HEIGHT)
    if row.SetClipsChildren then row:SetClipsChildren(true) end
    row.labels = {}
    for i in ipairs(statsColumns) do
        row.labels[i] = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end
    PositionStatsColumns(row, row.labels)
    statsRows[index] = row
    return row
end

RefreshStatsWidget = function()
    if not statsWidget:IsShown() then return end

    local rows = BuildStatsRows()
    statsSummary:SetText("|cffffd100Total Events Logged:|r " .. tostring(DebugFrame:GetTotalDebugEventsLogged()))
    statsWidget.statustext:SetText("")
    UpdateStatsCombatTimer()
    UpdateStatsMatchText()
    DebugFrame:UpdateStatsFooter()
    UpdateStatsFilterIndicators()
    if LayoutStatsWidget then LayoutStatsWidget() end

    local rowCount = math.max(1, #rows)
    statsRowsContent:SetHeight(math.max(statsRowsScrollFrame:GetHeight() or 1, rowCount * DEBUG_UI.STATS_WIDGET_ROW_HEIGHT))
    if statsSortScrollToTop then
        statsRowsScrollFrame:SetVerticalScroll(0)
        statsSortScrollToTop = false
    end

    for i, statsRow in ipairs(rows) do
        local row = EnsureStatsRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", statsRowsContent, "TOPLEFT", 0, -((i - 1) * DEBUG_UI.STATS_WIDGET_ROW_HEIGHT))
        row:SetPoint("RIGHT", statsRowsContent, "RIGHT", 0, 0)
        row:SetHeight(DEBUG_UI.STATS_WIDGET_ROW_HEIGHT)
        PositionStatsColumns(row, row.labels)
        row.labels[1]:SetText(statsRow.label or statsRow.values[1] or "")
        row.labels[2]:SetText(tostring(statsRow.count or 0))
        row.labels[3]:SetText(statsRow.percentage or "0.00%")
        row:Show()
    end

    if #rows == 0 then
        local row = EnsureStatsRow(1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", statsRowsContent, "TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", statsRowsContent, "RIGHT", 0, 0)
        row:SetHeight(DEBUG_UI.STATS_WIDGET_ROW_HEIGHT)
        PositionStatsColumns(row, row.labels)
        row.labels[1]:SetText("No matching events.")
        row.labels[2]:SetText("0")
        row.labels[3]:SetText("0.00%")
        row:Show()
    end

    for i = math.max(1, #rows) + 1, #statsRows do
        statsRows[i]:Hide()
    end
end

function GSE.GUIShowDebugStatsWidget()
    local location = EnsureStatsWidgetLocation()
    location.open = true
    DebugFrame.DockDebuggerSideWindow(statsWidget)
    statsWidget:Show()
    UpdateStatsButtonText()
    RefreshStatsWidget()
end

function GSE.GUIToggleDebugStatsWidget()
    local location = EnsureStatsWidgetLocation()
    if statsWidget:IsShown() then
        location.open = false
        if statsFilterMenu then statsFilterMenu:Hide() end
        statsWidget:Hide()
        UpdateStatsButtonText()
        return false
    end
    GSE.GUIShowDebugStatsWidget()
    return true
end

statsWidget:Hide()
statsWidget.GSESideDockSide = "RIGHT"
statsWidget.GSESideDockOffset = DEBUG_UI.STATS_WIDGET_ANCHOR_X
statsWidget.GSESideAnchor = AnchorStatsWidget
statsWidget.GSESideLayout = function() if LayoutStatsWidget then LayoutStatsWidget() end end
statsWidget.GSESideSave = SaveStatsWidgetLocation
DebugFrame.ConfigureDebuggerSideWindow(statsWidget, statsLocation, DEBUG_UI.STATS_WIDGET_MIN_WIDTH, DEBUG_UI.STATS_WIDGET_MIN_HEIGHT, GetMaxStatsWidgetWidth(), GetMaxStatsWidgetHeight())
DebugFrame.RegisterDebuggerWindow(statsWidget)
if GSE.RegisterUIScaleFrame then GSE.RegisterDebugUIScaleFrame(statsWidget) end
DebugFrame:HookScript(
    "OnHide",
    function()
        if DebugFrame.isMinimizing then return end
        if DebugFrame.HideDebuggerDropdowns then
            DebugFrame.HideDebuggerDropdowns()
        else
            if filterMenu then filterMenu:Hide() end
            if statsFilterMenu then statsFilterMenu:Hide() end
            if debugColumnMenu then debugColumnMenu:Hide() end
        end
        if DebugFrame.IsDebuggerSideWindowAttached(statsWidget) then
            EnsureStatsWidgetLocation().open = false
            if statsFilterMenu then statsFilterMenu:Hide() end
            statsWidget:Hide()
        end
        UpdateStatsButtonText()
    end
)

local hardwareWidget, AnchorHardwareWidget, LayoutHardwareWidget
do
local hardwareLocation = EnsureHardwareWidgetLocation()
local hardwareState = {mods = {}, modifierLog = {}, mouseButton = nil, sequenceName = "None", spamKey = "None", lastUpdate = "None", lastSeen = 0, activeTimeout = 0.75}
DebugFrame.IsHardwareStateActive = function()
    local now = GetTime and GetTime() or 0
    return hardwareState.lastSeen and hardwareState.lastSeen > 0 and now >= hardwareState.lastSeen and (now - hardwareState.lastSeen) <= hardwareState.activeTimeout
end
hardwareWidget = GSE.CreateDebuggerEditorFrame("GSEGUIDebugHardwareWidget", UIParent)
hardwareWidget:SetFrameStrata(currentDebuggerStrata)
hardwareWidget:SetClampedToScreen(false)
hardwareWidget:SetMovable(true)
hardwareWidget:SetResizable(false)
hardwareWidget:EnableMouse(true)
hardwareWidget:SetSize(DEBUG_UI.HARDWARE_WIDGET_WIDTH, DebugFrame:GetHeight() or DEBUG_UI.MIN_DEBUGGER_HEIGHT)
if hardwareWidget.SetClipsChildren then hardwareWidget:SetClipsChildren(true) end
if not hardwareWidget.GSEUsesBlizzardPanelTemplate and hardwareWidget.SetBackdrop then
    hardwareWidget:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 8, right = 8, top = 8, bottom = 8}
        }
    )
    hardwareWidget:SetBackdropColor(0.03, 0.03, 0.03, 0.94)
    hardwareWidget:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

if GSE.Skin and GSE.Skin.IsExternalProviderActive and GSE.Skin.IsExternalProviderActive() and GSE.Skin.Frame then
    GSE.Skin.Frame(hardwareWidget)
end

AnchorHardwareWidget = function()
    if hardwareWidget.GSESideDetached then return end
    hardwareWidget:ClearAllPoints()
    hardwareWidget:SetPoint("TOPRIGHT", DebugFrame, "TOPLEFT", DEBUG_UI.HARDWARE_WIDGET_ANCHOR_X, -10)
end

local function UpdateHardwareButtonText()
    if DebugFrame.DebugHardwareViewButton then
        GSE.SetDebuggerButtonText(DebugFrame.DebugHardwareViewButton, hardwareWidget:IsShown() and "Hardware: On" or "Hardware: Off")
    end
end
hardwareWidget.GSEUpdateButtonText = UpdateHardwareButtonText

local hardwareTitle = hardwareWidget:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hardwareTitle:SetPoint("TOPLEFT", hardwareWidget, "TOPLEFT", 36, -20)
hardwareTitle:SetPoint("TOPRIGHT", hardwareWidget, "TOPRIGHT", -36, -20)
hardwareTitle:SetJustifyH("CENTER")
hardwareTitle:SetText(DebuggerWindowTitle("Hardware Events"))
DebugFrame.ApplyEditorWindowStyle(hardwareWidget, hardwareTitle)
DebugFrame.PositionDebuggerSideTitle(hardwareWidget, hardwareTitle, DebuggerWindowTitle("Hardware Events"))

local hardwareSummary = hardwareWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hardwareSummary:SetPoint("TOPLEFT", hardwareWidget, "TOPLEFT", 12, -44)
hardwareSummary:SetPoint("TOPRIGHT", hardwareWidget, "TOPRIGHT", -12, -44)
hardwareSummary:SetJustifyH("CENTER")

hardwareWidget.inputSummary = hardwareWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hardwareWidget.inputSummary:SetJustifyH("CENTER")

hardwareWidget.statustext = hardwareWidget:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hardwareWidget.statustext:SetJustifyH("LEFT")

hardwareWidget.closeButton = CreateFrame("Button", nil, hardwareWidget, "UIPanelButtonTemplate")
hardwareWidget.closeButton:SetSize(90, DEBUG_UI.BUTTON_HEIGHT)
hardwareWidget.closeButton:SetText("Close")
GSE.StyleDebugTextButton(hardwareWidget.closeButton)
hardwareWidget.closeButton:SetScript(
    "OnClick",
    function()
        local location = EnsureHardwareWidgetLocation()
        location.open = false
        hardwareWidget:Hide()
        UpdateHardwareButtonText()
    end
)
if hardwareWidget.CloseButton then hardwareWidget.CloseButton:SetScript("OnClick", hardwareWidget.closeButton:GetScript("OnClick")) end

local hardwareScrollBackground = CreateFrame("Frame", nil, hardwareWidget, frameTemplate)
if hardwareScrollBackground.SetBackdrop then
    hardwareScrollBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        }
    )
    hardwareScrollBackground:SetBackdropColor(0.03, 0.03, 0.03, 0.42)
    hardwareScrollBackground:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
end
DebugFrame.ApplyNativeInsetSkin(hardwareScrollBackground)

local hardwareHeaderBackground = CreateFrame("Frame", nil, hardwareScrollBackground, frameTemplate)
if hardwareHeaderBackground.SetClipsChildren then hardwareHeaderBackground:SetClipsChildren(true) end
hardwareHeaderBackground:SetHeight(20)
if hardwareHeaderBackground.SetBackdrop then
    hardwareHeaderBackground:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        }
    )
    hardwareHeaderBackground:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    if GSE.Skin and GSE.Skin.PaintAccentBorder then
        GSE.Skin.PaintAccentBorder(hardwareHeaderBackground, 0.7, 0.62, 0.12, 1)
    else
        hardwareHeaderBackground:SetBackdropBorderColor(0.7, 0.62, 0.12, 1)
    end
end
DebugFrame.ApplyNativeInsetSkin(hardwareHeaderBackground)

local hardwareHeaderEvent = hardwareHeaderBackground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hardwareHeaderEvent:SetText("Hardware Event")
hardwareHeaderEvent:SetJustifyH("LEFT")
local hardwareHeaderValue = hardwareHeaderBackground:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hardwareHeaderValue:SetText("Value")
hardwareHeaderValue:SetJustifyH("RIGHT")

local hardwareRowsScrollFrame = CreateFrame("ScrollFrame", "GSEGUIDebugHardwareRowsScrollFrame", hardwareScrollBackground, "UIPanelScrollFrameTemplate")
if hardwareRowsScrollFrame.SetClipsChildren then hardwareRowsScrollFrame:SetClipsChildren(true) end
hardwareRowsScrollFrame:EnableMouseWheel(true)
local hardwareRowsContent = CreateFrame("Frame", nil, hardwareRowsScrollFrame)
if hardwareRowsContent.SetClipsChildren then hardwareRowsContent:SetClipsChildren(true) end
hardwareRowsContent:SetSize(1, 1)
hardwareRowsScrollFrame:SetScrollChild(hardwareRowsContent)
-- Forward mouse-wheel on the background panel to the row scroll frame
hardwareScrollBackground:EnableMouseWheel(true)
hardwareScrollBackground:SetScript("OnMouseWheel", function(_, delta)
    local current = hardwareRowsScrollFrame:GetVerticalScroll() or 0
    local range = math.max(0, hardwareRowsScrollFrame:GetVerticalScrollRange() or 0)
    hardwareRowsScrollFrame:SetVerticalScroll(math.min(math.max(current - delta * (DEBUG_UI.STATS_WIDGET_ROW_HEIGHT * 3), 0), range))
end)
hardwareRowsScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    local current = hardwareRowsScrollFrame:GetVerticalScroll() or 0
    local range = math.max(0, hardwareRowsScrollFrame:GetVerticalScrollRange() or 0)
    hardwareRowsScrollFrame:SetVerticalScroll(math.min(math.max(current - delta * (DEBUG_UI.STATS_WIDGET_ROW_HEIGHT * 3), 0), range))
end)
local hardwareRows = {}

hardwareWidget.modifierLogTitleFrame = CreateFrame("Frame", nil, hardwareWidget)
if hardwareWidget.modifierLogTitleFrame.SetClipsChildren then hardwareWidget.modifierLogTitleFrame:SetClipsChildren(true) end
hardwareWidget.modifierLogTitleFrame:EnableMouse(false)
hardwareWidget.modifierLogTitle = hardwareWidget.modifierLogTitleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hardwareWidget.modifierLogTitle:SetText("|cFFFFD100Print Active Modifiers on Click:|r |cFFFFFFFFOff|r")
hardwareWidget.modifierLogTitle:SetJustifyH("CENTER")
hardwareWidget.modifierLogTitle:SetJustifyV("MIDDLE")

hardwareWidget.modifierLogFrame = CreateFrame("Frame", nil, hardwareWidget, frameTemplate)
if hardwareWidget.modifierLogFrame.SetClipsChildren then hardwareWidget.modifierLogFrame:SetClipsChildren(true) end
if hardwareWidget.modifierLogFrame.SetBackdrop then
    hardwareWidget.modifierLogFrame:SetBackdrop(
        {
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        }
    )
    hardwareWidget.modifierLogFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.42)
    hardwareWidget.modifierLogFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
end
DebugFrame.ApplyNativeInsetSkin(hardwareWidget.modifierLogFrame)

hardwareWidget.modifierLogScrollFrame = CreateFrame("ScrollFrame", "GSEGUIDebugHardwareModifierLogScrollFrame", hardwareWidget.modifierLogFrame, "UIPanelScrollFrameTemplate")
if hardwareWidget.modifierLogScrollFrame.SetClipsChildren then hardwareWidget.modifierLogScrollFrame:SetClipsChildren(true) end
hardwareWidget.modifierLogContent = CreateFrame("Frame", nil, hardwareWidget.modifierLogScrollFrame)
if hardwareWidget.modifierLogContent.SetClipsChildren then hardwareWidget.modifierLogContent:SetClipsChildren(true) end
hardwareWidget.modifierLogContent:SetSize(1, 1)
hardwareWidget.modifierLogScrollFrame:SetScrollChild(hardwareWidget.modifierLogContent)
hardwareWidget.modifierLogScrollFrame:EnableMouseWheel(true)
local hardwareModifierLogRows = {}

local function HardwareCurrentMouseButton()
    if not DebugFrame.IsHardwareStateActive() then return "None" end
    local button = hardwareState.mouseButton
    if GSE.isEmpty(button) then return "None" end
    return button
end

local function HardwareBooleanText(value)
    return value and "|cFF59FF59true|r" or "|cFFAAAAAAfalse|r"
end

local function HardwareRowValue(row)
    if not DebugFrame.IsHardwareStateActive() then
        if row.key == "MOUSEBUTTON" then return "|cFFFFFFFFNone|r" end
        return HardwareBooleanText(false)
    end
    if row.mouseButton then return HardwareBooleanText(HardwareCurrentMouseButton() == row.mouseButton) end
    if row.key == "MOUSEBUTTON" then return "|cFFFFFFFF" .. HardwareCurrentMouseButton() .. "|r" end
    local value = hardwareState.mods and hardwareState.mods[row.key]
    return HardwareBooleanText(value == true)
end

local function HardwareRowIsTrue(row)
    if not DebugFrame.IsHardwareStateActive() then return false end
    if row.mouseButton then return HardwareCurrentMouseButton() == row.mouseButton end
    if row.key and row.key ~= "MOUSEBUTTON" then return hardwareState.mods and hardwareState.mods[row.key] == true end
    return false
end

local function EnsureHardwareRow(index)
    if hardwareRows[index] then return hardwareRows[index] end
    local row = CreateFrame("Frame", nil, hardwareRowsContent)
    row:SetHeight(DEBUG_UI.STATS_WIDGET_ROW_HEIGHT)
    row.event = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.event:SetJustifyH("LEFT")
    row.event:SetWordWrap(false)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)
    hardwareRows[index] = row
    return row
end

local function EnsureHardwareModifierLogRow(index)
    if hardwareModifierLogRows[index] then return hardwareModifierLogRows[index] end

    local row = hardwareWidget.modifierLogContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetJustifyH("LEFT")
    row:SetJustifyV("MIDDLE")
    row:SetWordWrap(false)
    hardwareModifierLogRows[index] = row
    return row
end

local function HardwareModifierLogLine(prefix, label, value)
    local line = prefix .. label .. " " .. tostring(value)
    if value == true then
        return "|cFF59FF59" .. line .. "|r"
    end
    return line
end

function DebugFrame:AppendHardwareModifierLog(payload)
    if not (GSEOptions and GSEOptions.DebugPrintModConditionsOnKeyPress) then return end

    local timestamp = string.format(
        "%02dh:%02dm:%02ds",
        tonumber(date and date("%H") or 0) or 0,
        tonumber(date and date("%M") or 0) or 0,
        tonumber(date and date("%S") or 0) or 0
    )
    local prefix = "[" .. timestamp .. "] "
    hardwareState.modifierLog = hardwareState.modifierLog or {}
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Right alt key", hardwareState.mods and hardwareState.mods.RALT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Left alt key", hardwareState.mods and hardwareState.mods.LALT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Any alt key", hardwareState.mods and hardwareState.mods.AALT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Right ctrl key", hardwareState.mods and hardwareState.mods.RCTRL == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Left ctrl key", hardwareState.mods and hardwareState.mods.LCTRL == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Any ctrl key", hardwareState.mods and hardwareState.mods.ACTRL == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Right shft key", hardwareState.mods and hardwareState.mods.RSHIFT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Left shft key", hardwareState.mods and hardwareState.mods.LSHIFT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Any shft key", hardwareState.mods and hardwareState.mods.ASHIFT == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = HardwareModifierLogLine(prefix, "Any mod key", hardwareState.mods and hardwareState.mods.AMOD == true)
    hardwareState.modifierLog[#hardwareState.modifierLog + 1] = prefix .. "GetMouseButtonClicked() " .. tostring(hardwareState.mouseButton or "None")

    while #hardwareState.modifierLog > 600 do
        table.remove(hardwareState.modifierLog, 1)
    end
    hardwareState.modifierLogDirty = true
end

function DebugFrame:UpdateHardwareModifierLog()
    if not (hardwareWidget and hardwareWidget.modifierLogContent) then return end

    local enabled = GSEOptions and GSEOptions.DebugPrintModConditionsOnKeyPress
    if hardwareWidget.modifierLogTitle then
        hardwareWidget.modifierLogTitle:SetText("|cFFFFD100Print Active Modifiers on Click:|r |cFFFFFFFF" .. (enabled and "On" or "Off") .. "|r")
    end

    local lines
    if not enabled then
        lines = {"|cFFAAAAAAPrint Active Modifiers on Click is off.|r"}
    elseif hardwareState.modifierLog and #hardwareState.modifierLog > 0 then
        lines = hardwareState.modifierLog
    else
        lines = {"|cFFAAAAAAWaiting for active modifier clicks...|r"}
    end

    local rowHeight = 16
    local width = math.max(1, (hardwareWidget.modifierLogScrollFrame:GetWidth() or 1) - 2)
    hardwareWidget.modifierLogContent:SetWidth(width)
    hardwareWidget.modifierLogContent:SetHeight(math.max(hardwareWidget.modifierLogScrollFrame:GetHeight() or 1, (#lines * rowHeight) + 4))

    for i, line in ipairs(lines) do
        local row = EnsureHardwareModifierLogRow(i)
        row:ClearAllPoints()
        row:SetPoint("BOTTOMLEFT", hardwareWidget.modifierLogContent, "BOTTOMLEFT", 0, ((#lines - i) * rowHeight) + 2)
        row:SetWidth(width)
        row:SetHeight(rowHeight)
        row:SetText(line)
        row:Show()
    end
    for i = #lines + 1, #hardwareModifierLogRows do
        hardwareModifierLogRows[i]:Hide()
    end

    if hardwareState.modifierLogDirty and hardwareWidget.modifierLogScrollFrame.SetVerticalScroll then
        hardwareState.modifierLogDirty = false
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if hardwareWidget and hardwareWidget.modifierLogScrollFrame then
                    hardwareWidget.modifierLogScrollFrame:SetVerticalScroll(math.max(0, hardwareWidget.modifierLogScrollFrame:GetVerticalScrollRange() or 0))
                end
            end)
        else
            hardwareWidget.modifierLogScrollFrame:SetVerticalScroll(math.max(0, hardwareWidget.modifierLogScrollFrame:GetVerticalScrollRange() or 0))
        end
    end
end

LayoutHardwareWidget = function()
    if not hardwareWidget.GSESideDetached then
        local targetHeight = (DebugFrame:GetHeight() or DEBUG_UI.MIN_DEBUGGER_HEIGHT) - 10
        if math.abs((hardwareWidget:GetWidth() or 0) - DEBUG_UI.HARDWARE_WIDGET_WIDTH) > 0.5 then hardwareWidget:SetWidth(DEBUG_UI.HARDWARE_WIDGET_WIDTH) end
        if math.abs((hardwareWidget:GetHeight() or 0) - targetHeight) > 0.5 then hardwareWidget:SetHeight(targetHeight) end
    end
    local tableHeight = math.max(0, (hardwareWidget:GetHeight() or 0) - 66 - ((11 * 16) + 160))
    hardwareScrollBackground:ClearAllPoints()
    if tableHeight >= 40 then
        hardwareScrollBackground:SetPoint("TOPLEFT", hardwareWidget, "TOPLEFT", 12, -66)
        hardwareScrollBackground:SetPoint("TOPRIGHT", hardwareWidget, "TOPRIGHT", -12, -66)
        hardwareScrollBackground:SetHeight(tableHeight)
        hardwareScrollBackground:Show()
    else
        hardwareScrollBackground:Hide()
    end
    hardwareHeaderBackground:ClearAllPoints()
    hardwareHeaderBackground:SetPoint("TOPLEFT", hardwareScrollBackground, "TOPLEFT", 4, -4)
    hardwareHeaderBackground:SetPoint("TOPRIGHT", hardwareScrollBackground, "TOPRIGHT", -4, -4)
    hardwareHeaderEvent:ClearAllPoints()
    hardwareHeaderEvent:SetPoint("LEFT", hardwareHeaderBackground, "LEFT", 4, 0)
    hardwareHeaderEvent:SetWidth(210)
    hardwareHeaderValue:ClearAllPoints()
    hardwareHeaderValue:SetPoint("RIGHT", hardwareHeaderBackground, "RIGHT", -4, 0)
    hardwareHeaderValue:SetWidth(110)
    hardwareRowsScrollFrame:ClearAllPoints()
    hardwareRowsScrollFrame:SetPoint("TOPLEFT", hardwareHeaderBackground, "BOTTOMLEFT", 0, -4)
    hardwareRowsScrollFrame:SetPoint("BOTTOMRIGHT", hardwareScrollBackground, "BOTTOMRIGHT", -20, 4)
    local totalHardwareRowsHeight = #HARDWARE_EVENT_ROWS * DEBUG_UI.STATS_WIDGET_ROW_HEIGHT
    local hwScrollAvail = math.max(1, hardwareRowsScrollFrame:GetHeight() or 1)
    hardwareRowsContent:SetWidth(math.max(1, (hardwareRowsScrollFrame:GetWidth() or 1)))
    hardwareRowsContent:SetHeight(math.max(hwScrollAvail, totalHardwareRowsHeight))
    hardwareWidget.modifierLogTitle:ClearAllPoints()
    hardwareWidget.modifierLogFrame:ClearAllPoints()
    hardwareWidget.modifierLogFrame:SetPoint("BOTTOMLEFT", hardwareWidget, "BOTTOMLEFT", 12, 88)
    hardwareWidget.modifierLogFrame:SetPoint("RIGHT", hardwareWidget, "RIGHT", -12, 0)
    hardwareWidget.modifierLogFrame:SetHeight((11 * 16) + 12)
    hardwareWidget.modifierLogTitleFrame:ClearAllPoints()
    hardwareWidget.modifierLogTitleFrame:SetPoint("BOTTOMLEFT", hardwareWidget.modifierLogFrame, "TOPLEFT", 0, 12)
    hardwareWidget.modifierLogTitleFrame:SetPoint("BOTTOMRIGHT", hardwareWidget.modifierLogFrame, "TOPRIGHT", 0, 12)
    hardwareWidget.modifierLogTitleFrame:SetHeight(20)
    if hardwareWidget.modifierLogTitleFrame.SetFrameStrata and hardwareWidget.GetFrameStrata then hardwareWidget.modifierLogTitleFrame:SetFrameStrata(hardwareWidget:GetFrameStrata()) end
    if hardwareWidget.modifierLogTitleFrame.SetFrameLevel and hardwareWidget.modifierLogFrame.GetFrameLevel then hardwareWidget.modifierLogTitleFrame:SetFrameLevel((hardwareWidget.modifierLogFrame:GetFrameLevel() or 0) + 20) end
    hardwareWidget.modifierLogTitle:SetAllPoints(hardwareWidget.modifierLogTitleFrame)
    if hardwareWidget.modifierLogTitle.SetDrawLayer then hardwareWidget.modifierLogTitle:SetDrawLayer("OVERLAY", 7) end
    hardwareWidget.modifierLogScrollFrame:ClearAllPoints()
    hardwareWidget.modifierLogScrollFrame:SetPoint("TOPLEFT", hardwareWidget.modifierLogFrame, "TOPLEFT", 6, -6)
    hardwareWidget.modifierLogScrollFrame:SetPoint("BOTTOMRIGHT", hardwareWidget.modifierLogFrame, "BOTTOMRIGHT", -24, 6)
    hardwareWidget.modifierLogContent:ClearAllPoints()
    hardwareWidget.modifierLogContent:SetPoint("TOPLEFT", hardwareWidget.modifierLogScrollFrame, "TOPLEFT", 0, 0)
    hardwareWidget.inputSummary:ClearAllPoints()
    hardwareWidget.inputSummary:SetPoint("TOPLEFT", hardwareWidget, "BOTTOMLEFT", 12, 84)
    hardwareWidget.inputSummary:SetPoint("TOPRIGHT", hardwareWidget, "BOTTOMRIGHT", -12, 84)
    hardwareWidget.statustext:ClearAllPoints()
    hardwareWidget.statustext:SetPoint("BOTTOMLEFT", hardwareWidget, "BOTTOMLEFT", 14, 11)
    hardwareWidget.statustext:SetPoint("BOTTOMRIGHT", hardwareWidget, "BOTTOMRIGHT", -36, 11)
    hardwareWidget.closeButton:ClearAllPoints()
    hardwareWidget.closeButton:SetPoint("BOTTOM", hardwareWidget, "BOTTOM", 0, 32)
    for i, rowData in ipairs(HARDWARE_EVENT_ROWS) do
        local row = EnsureHardwareRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", hardwareRowsContent, "TOPLEFT", 0, -((i - 1) * DEBUG_UI.STATS_WIDGET_ROW_HEIGHT))
        row:SetPoint("RIGHT", hardwareRowsContent, "RIGHT", 0, 0)
        row.event:ClearAllPoints()
        row.event:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.event:SetWidth(210)
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.value:SetWidth(110)
        row.event:SetText(rowData.label)
        row.value:SetText(HardwareRowValue(rowData))
        if HardwareRowIsTrue(rowData) then
            row.event:SetTextColor(0.35, 1, 0.35, 1)
        else
            row.event:SetTextColor(1, 1, 1, 1)
        end
        row:Show()
    end
    DebugFrame:UpdateHardwareModifierLog()
    DebugFrame.RaiseDebuggerSideChrome(hardwareWidget)
end

local function RefreshHardwareWidget()
    if not hardwareWidget:IsShown() then return end
    local active = DebugFrame.IsHardwareStateActive()
    hardwareSummary:SetText("|cffffd100Sequence:|r " .. tostring(active and hardwareState.sequenceName or "None"))
    hardwareWidget.inputSummary:SetText("|cffffd100Activation Key:|r " .. tostring(active and hardwareState.spamKey or "None") .. "   |cffffd100Last:|r " .. tostring(hardwareState.lastUpdate or "None"))
    hardwareWidget.statustext:SetText("")
    LayoutHardwareWidget()
end
hardwareWidget.GSERefresh = RefreshHardwareWidget

function DebugFrame:ResetHardwareEventsState()
    for key in pairs(hardwareState.mods) do
        hardwareState.mods[key] = nil
    end
    hardwareState.mouseButton = nil
    hardwareState.sequenceName = "None"
    hardwareState.spamKey = "None"
    hardwareState.lastUpdate = "None"
    hardwareState.lastSeen = 0
    hardwareState.modifierLog = {}
    hardwareState.modifierLogDirty = true
    RefreshHardwareWidget()
end

local function UpdateHardwareStateFromPayload(_, payload, mods)
    local modSource = type(payload) == "table" and payload.Mods or mods
    if type(modSource) ~= "table" then return end
    for key in pairs(hardwareState.mods) do
        hardwareState.mods[key] = nil
    end
    for _, rowData in ipairs(HARDWARE_EVENT_ROWS) do
        if rowData.key and rowData.key ~= "MOUSEBUTTON" then
            hardwareState.mods[rowData.key] = false
        end
    end
    for key, value in pairs(modSource) do
        hardwareState.mods[key] = value == true
    end
    hardwareState.mouseButton = (type(payload) == "table" and payload.HardwareEvent) or modSource.MOUSEBUTTON
    hardwareState.sequenceName = (type(payload) == "table" and (payload.SequenceName or payload.ButtonName)) or tostring(payload or "None")
    hardwareState.spamKey = (type(payload) == "table" and payload.SpamKey) or "None"
    hardwareState.lastUpdate = date and date("%H:%M:%S") or "Now"
    hardwareState.lastSeen = GetTime and GetTime() or 0
    DebugFrame:AppendHardwareModifierLog(payload)
    RefreshHardwareWidget()
end

if GSE.RegisterMessage and GSE.Static and GSE.Static.Messages and GSE.Static.Messages.GSE_MODS_VISIBLE then
    -- AceEvent signature: :RegisterMessage(name, methodNameOrFunc). The 1914
    -- Native.lua reimplementation accepted an extra "key" arg between name
    -- and the callback; AceEvent does not, so pass the function directly.
    GSE:RegisterMessage(GSE.Static.Messages.GSE_MODS_VISIBLE, UpdateHardwareStateFromPayload)
end

hardwareWidget:SetScript(
    "OnUpdate",
    function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < 0.2 then return end
        self.elapsed = 0
        RefreshHardwareWidget()
    end
)

function GSE.GUIShowDebugHardwareWidget()
    local location = EnsureHardwareWidgetLocation()
    location.open = true
    DebugFrame.DockDebuggerSideWindow(hardwareWidget)
    hardwareWidget:Show()
    UpdateHardwareButtonText()
    RefreshHardwareWidget()
end

function GSE.GUIToggleDebugHardwareWidget()
    local location = EnsureHardwareWidgetLocation()
    if hardwareWidget:IsShown() then
        location.open = false
        hardwareWidget:Hide()
        UpdateHardwareButtonText()
        return false
    end
    GSE.GUIShowDebugHardwareWidget()
    return true
end

AnchorHardwareWidget()
hardwareWidget:Hide()
hardwareWidget.GSESideDockSide = "LEFT"
hardwareWidget.GSESideDockOffset = DEBUG_UI.HARDWARE_WIDGET_ANCHOR_X
hardwareWidget.GSESideAnchor = AnchorHardwareWidget
hardwareWidget.GSESideLayout = function() if LayoutHardwareWidget then LayoutHardwareWidget() end end
hardwareWidget.GSESideSave = function()
    local location = EnsureHardwareWidgetLocation()
    location.width = ClampNumber(hardwareWidget:GetWidth(), 320, 900, DEBUG_UI.HARDWARE_WIDGET_WIDTH)
    location.height = ClampNumber(hardwareWidget:GetHeight(), 360, 1200, DEBUG_UI.MIN_DEBUGGER_HEIGHT)
    location.detached = hardwareWidget.GSESideDetached == true
end
DebugFrame.ConfigureDebuggerSideWindow(hardwareWidget, hardwareLocation, 320, 360, 900, 1200)
DebugFrame.RegisterDebuggerWindow(hardwareWidget)
if GSE.RegisterUIScaleFrame then GSE.RegisterDebugUIScaleFrame(hardwareWidget) end
hardwareWidget:HookScript("OnSizeChanged", function()
    if LayoutHardwareWidget then LayoutHardwareWidget() end
end)
DebugFrame:HookScript(
    "OnHide",
    function()
        if DebugFrame.isMinimizing then return end
        if DebugFrame.IsDebuggerSideWindowAttached(hardwareWidget) then
            EnsureHardwareWidgetLocation().open = false
            hardwareWidget:Hide()
        end
        UpdateHardwareButtonText()
    end
)
end

function DebugFrame.CloseAttachedDebuggerSideWindows()
    if statsWidget and DebugFrame.IsDebuggerSideWindowAttached(statsWidget) then
        EnsureStatsWidgetLocation().open = false
        if statsFilterMenu then statsFilterMenu:Hide() end
        statsWidget:Hide()
        UpdateStatsButtonText()
    end
    if hardwareWidget and DebugFrame.IsDebuggerSideWindowAttached(hardwareWidget) then
        EnsureHardwareWidgetLocation().open = false
        hardwareWidget:Hide()
        -- hardwareWidget.GSEUpdateButtonText is assigned unconditionally where the
        -- widget is built, so this is the only path; the previous bare
        -- UpdateHardwareButtonText() fallback referenced a not-yet-in-scope local
        -- (it would have bound to a nil global on this branch).
        if hardwareWidget.GSEUpdateButtonText then
            hardwareWidget.GSEUpdateButtonText()
        end
    end
end

DebugFrame.minimizeButton = CreateFrame("Button", nil, DebugFrame)
DebugFrame.minimizeButton:SetSize(24, 24)
DebugFrame.minimizeButton:EnableMouse(true)
DebugFrame.minimizeButton:RegisterForClicks("LeftButtonUp")
DebugFrame.minimizeButton:SetPoint("RIGHT", closeButton, "LEFT", 2, 0)
DebugFrame.minimizeButton.usesModern = GSE.DebugUsesModernSkin and GSE.DebugUsesModernSkin()
GSE.StyleDebugIconButton(DebugFrame.minimizeButton, GSE.DEBUG_MINIMIZE_UP_TEXTURE, DebugFrame.minimizeButton.usesModern)
if DebugFrame.minimizeButton.SetFrameLevel then DebugFrame.minimizeButton:SetFrameLevel(((closeButton and closeButton.GetFrameLevel and closeButton:GetFrameLevel()) or DebugFrame:GetFrameLevel() or 0) + 2) end
DebugFrame.minimizeButton.icon = DebugFrame.minimizeButton:CreateTexture(nil, "OVERLAY")
DebugFrame.minimizeButton.icon:SetAllPoints(DebugFrame.minimizeButton)
DebugFrame.minimizeButton.icon:SetTexture(GSE.GetDebugControlTexture(GSE.DEBUG_MINIMIZE_UP_TEXTURE, DebugFrame.minimizeButton.usesModern))
DebugFrame.minimizeButton.GSEDebugOverlayTexture = DebugFrame.minimizeButton.icon
GSE.SetDebugControlTextureState(DebugFrame.minimizeButton.icon, not DebugFrame.minimizeButton.usesModern)
DebugFrame.minimizeButton:Show()

DebugFrame.minimizedWidget = CreateFrame("Button", "GSEGUIDebugMinimizedWidget", UIParent, frameTemplate)
DebugFrame.minimizedWidget.usesModern = GSE.DebugUsesModernSkin()
DebugFrame.minimizedWidget:SetSize(220, DebugFrame.minimizedWidget.usesModern and 30 or 34)
DebugFrame.minimizedWidget:SetFrameStrata(currentDebuggerStrata)
DebugFrame.minimizedWidget:SetMovable(true)
DebugFrame.minimizedWidget:EnableMouse(true)
DebugFrame.minimizedWidget:RegisterForDrag("LeftButton")
DebugFrame.minimizedWidget:SetClampedToScreen(false)
if GSE.RegisterUIScaleFrame then GSE.RegisterDebugUIScaleFrame(DebugFrame.minimizedWidget) end

DebugFrame.minimizedWidget.skinClip = CreateFrame("Frame", nil, DebugFrame.minimizedWidget)
DebugFrame.minimizedWidget.skinClip:SetPoint(
    "TOPLEFT",
    DebugFrame.minimizedWidget,
    "TOPLEFT",
    DebugFrame.minimizedWidget.usesModern and 0 or 15,
    (DebugFrame.minimizedWidget.usesModern and 0 or 3) - 1 - (DebugFrame.minimizedWidget.usesModern and 0 or 2)
)
DebugFrame.minimizedWidget.skinClip:SetPoint(
    "TOPRIGHT",
    DebugFrame.minimizedWidget,
    "TOPRIGHT",
    0,
    (DebugFrame.minimizedWidget.usesModern and 0 or 3) - 1 - (DebugFrame.minimizedWidget.usesModern and 0 or 2)
)
DebugFrame.minimizedWidget.skinClip:SetHeight(DebugFrame.minimizedWidget.usesModern and 24 or 25)
DebugFrame.minimizedWidget.skinClip:SetFrameLevel(DebugFrame.minimizedWidget:GetFrameLevel())
if DebugFrame.minimizedWidget.skinClip.SetClipsChildren then DebugFrame.minimizedWidget.skinClip:SetClipsChildren(true) end

DebugFrame.minimizedWidget.backdrop = CreateFrame("Frame", nil, DebugFrame.minimizedWidget.skinClip, frameTemplate)
DebugFrame.minimizedWidget.backdrop:SetAllPoints(DebugFrame.minimizedWidget.skinClip)
DebugFrame.minimizedWidget.backdrop:SetFrameLevel(DebugFrame.minimizedWidget.skinClip:GetFrameLevel())
DebugFrame.minimizedWidget.backdrop:EnableMouse(false)
if DebugFrame.minimizedWidget.backdrop.SetBackdrop then
    if DebugFrame.minimizedWidget.usesModern then
        DebugFrame.minimizedWidget.backdrop:SetBackdrop(
            {
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = {left = 0, right = 0, top = 0, bottom = 0}
            }
        )
        DebugFrame.minimizedWidget.backdrop:SetBackdropColor(0.02, 0.025, 0.028, 0.94)
        DebugFrame.minimizedWidget.backdrop:SetBackdropBorderColor(0.22, 0.24, 0.25, 0.95)
    else
        DebugFrame.minimizedWidget.backdrop:SetBackdrop(
            {
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = {left = 4, right = 4, top = 4, bottom = 4}
            }
        )
        DebugFrame.minimizedWidget.backdrop:SetBackdropColor(0, 0, 0, 0.85)
        DebugFrame.minimizedWidget.backdrop:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
end

DebugFrame.minimizedWidget.content = CreateFrame("Frame", nil, DebugFrame.minimizedWidget)
DebugFrame.minimizedWidget.content:SetAllPoints(DebugFrame.minimizedWidget)
DebugFrame.minimizedWidget.content:SetFrameLevel(DebugFrame.minimizedWidget.backdrop:GetFrameLevel() + 1)

DebugFrame.minimizedWidget.title = DebugFrame.minimizedWidget.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DebugFrame.minimizedWidget.title:SetPoint(
    "LEFT",
    DebugFrame.minimizedWidget,
    "LEFT",
    DebugFrame.minimizedWidget.usesModern and 8 or 22,
    DebugFrame.minimizedWidget.usesModern and 2 or 5
)
DebugFrame.minimizedWidget.title:SetPoint(
    "RIGHT",
    DebugFrame.minimizedWidget,
    "RIGHT",
    DebugFrame.minimizedWidget.usesModern and -58 or -64,
    DebugFrame.minimizedWidget.usesModern and 2 or 5
)
DebugFrame.minimizedWidget.title:SetJustifyH("LEFT")
DebugFrame.minimizedWidget.title:SetWordWrap(false)
DebugFrame.minimizedWidget.title:SetText("|cFFFFFFFFGS|r|cFF00FFFFE|r: Sequence Debugger")
DebugFrame.minimizedWidget.closeButton = CreateFrame("Button", nil, DebugFrame.minimizedWidget)
DebugFrame.minimizedWidget.closeButton:SetSize(32, 30)
DebugFrame.minimizedWidget.closeButton:SetFrameLevel(DebugFrame.minimizedWidget.backdrop:GetFrameLevel() + 2)
DebugFrame.minimizedWidget.closeButton:SetPoint("TOPRIGHT", DebugFrame.minimizedWidget, "TOPRIGHT", 2, 3)
GSE.StyleDebugIconButton(DebugFrame.minimizedWidget.closeButton, GSE.DEBUG_CLOSE_TEXTURE, DebugFrame.minimizedWidget.usesModern)
DebugFrame.minimizedWidget.expandButton = CreateFrame("Button", nil, DebugFrame.minimizedWidget)
DebugFrame.minimizedWidget.expandButton:SetSize(24, 24)
DebugFrame.minimizedWidget.expandButton:EnableMouse(true)
DebugFrame.minimizedWidget.expandButton:RegisterForClicks("LeftButtonUp")
DebugFrame.minimizedWidget.expandButton:SetFrameLevel((DebugFrame.minimizedWidget.closeButton:GetFrameLevel() or DebugFrame.minimizedWidget.backdrop:GetFrameLevel()) + 1)
DebugFrame.minimizedWidget.expandButton:SetPoint("RIGHT", DebugFrame.minimizedWidget.closeButton, "LEFT", 2, 0)
GSE.StyleDebugIconButton(DebugFrame.minimizedWidget.expandButton, GSE.DEBUG_MINIMIZE_DOWN_TEXTURE, DebugFrame.minimizedWidget.usesModern)
DebugFrame.minimizedWidget.expandButton:Show()
DebugFrame.minimizedWidget:Hide()

DebugFrame.minimizedWidget:SetScript("OnDragStart", function(self) self:StartMoving() end)
DebugFrame.minimizedWidget:SetScript(
    "OnDragStop",
    function(self)
        self:StopMovingOrSizing()
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
    end
)
DebugFrame.minimizedWidget:SetScript(
    "OnShow",
    function(self)
        if GSE.ApplyDebugScaleToFrame then GSE.ApplyDebugScaleToFrame(self) end
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
    end
)

function DebugFrame:CollapseToMinimizedWidget()
    if self.minimizedWidget and self.minimizedWidget:IsShown() then return end
    if self.StopMovingOrSizing then self:StopMovingOrSizing() end
    self.minimizedStatsWasShown = statsWidget and statsWidget:IsShown()
    self.minimizedHardwareWasShown = hardwareWidget and hardwareWidget:IsShown()
    self.minimizedStatsWasDocked = self.minimizedStatsWasShown and not statsWidget.GSESideDetached
    self.minimizedHardwareWasDocked = self.minimizedHardwareWasShown and not hardwareWidget.GSESideDetached
    if statsFilterMenu then statsFilterMenu:Hide() end
    if debugColumnMenu then debugColumnMenu:Hide() end

    self.minimizedWidget:ClearAllPoints()
    if GSE.ApplyDebugScaleToFrame then GSE.ApplyDebugScaleToFrame(self.minimizedWidget) end
    if self.GetRight and self.GetTop and self:GetRight() and self:GetTop() then
        if GSE.SetFrameScreenPoint then
            GSE.SetFrameScreenPoint(self.minimizedWidget, "TOPRIGHT", self:GetRight(), self:GetTop())
        else
            self.minimizedWidget:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", self:GetRight(), self:GetTop())
        end
    else
        self.minimizedWidget:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self.isMinimizing = true
    if self.minimizedStatsWasDocked then
        statsWidget:Hide()
        UpdateStatsButtonText()
    end
    if self.minimizedHardwareWasDocked then
        hardwareWidget:Hide()
        if hardwareWidget.GSEUpdateButtonText then hardwareWidget.GSEUpdateButtonText() end
    end
    self:Hide()
    self.isMinimizing = nil
    self.minimizedWidget:Show()
    if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self.minimizedWidget) end
end

function DebugFrame:ExpandFromMinimizedWidget()
    if not (self.minimizedWidget and self.minimizedWidget:IsShown()) then return end
    if self.minimizedWidget.StopMovingOrSizing then self.minimizedWidget:StopMovingOrSizing() end
    if self.minimizedWidget.GetRight and self.minimizedWidget.GetTop and self.minimizedWidget:GetRight() and self.minimizedWidget:GetTop() then
        if GSE.SetFrameScreenPoint then
            GSE.SetFrameScreenPoint(self, "TOPRIGHT", self.minimizedWidget:GetRight(), self.minimizedWidget:GetTop())
        else
            self:ClearAllPoints()
            self:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", self.minimizedWidget:GetRight(), self.minimizedWidget:GetTop())
        end
    end
    self.minimizedWidget:Hide()
    SetDebuggerOpenPreference(true)
    self:Show()
    if self.minimizedStatsWasDocked then
        EnsureStatsWidgetLocation().open = true
        DebugFrame.DockDebuggerSideWindow(statsWidget)
        statsWidget:Show()
        UpdateStatsButtonText()
        if RefreshStatsWidget then RefreshStatsWidget() end
    end
    if self.minimizedHardwareWasDocked then
        EnsureHardwareWidgetLocation().open = true
        DebugFrame.DockDebuggerSideWindow(hardwareWidget)
        hardwareWidget:Show()
        if hardwareWidget.GSEUpdateButtonText then hardwareWidget.GSEUpdateButtonText() end
        if hardwareWidget.GSERefresh then
            hardwareWidget.GSERefresh()
        elseif hardwareWidget.GSESideLayout then
            hardwareWidget.GSESideLayout()
        end
        DebugFrame.RaiseDebuggerSideChrome(hardwareWidget)
    end
    self.minimizedStatsWasShown = nil
    self.minimizedHardwareWasShown = nil
    self.minimizedStatsWasDocked = nil
    self.minimizedHardwareWasDocked = nil
    if self.UpdateDebuggerLayout then self.UpdateDebuggerLayout() end
    if self.Raise then self:Raise() end
end

function DebugFrame:CloseMinimizedWidget()
    local minimizedStatsWasDocked = self.minimizedStatsWasDocked
    local minimizedHardwareWasDocked = self.minimizedHardwareWasDocked

    SetDebuggerOpenPreference(false)
    if self.minimizedWidget then self.minimizedWidget:Hide() end
    self.minimizedStatsWasShown = nil
    self.minimizedHardwareWasShown = nil
    self.minimizedStatsWasDocked = nil
    self.minimizedHardwareWasDocked = nil
    if minimizedStatsWasDocked then
        EnsureStatsWidgetLocation().open = false
        if statsFilterMenu then statsFilterMenu:Hide() end
        if statsWidget then statsWidget:Hide() end
    elseif statsWidget and statsWidget:IsShown() then
        DebugFrame.DetachDebuggerSideWindow(statsWidget)
    end
    if minimizedHardwareWasDocked then
        EnsureHardwareWidgetLocation().open = false
        if hardwareWidget then hardwareWidget:Hide() end
    elseif hardwareWidget and hardwareWidget:IsShown() then
        DebugFrame.DetachDebuggerSideWindow(hardwareWidget)
    end
    UpdateStatsButtonText()
    if self.DebugHardwareViewButton then GSE.SetDebuggerButtonText(self.DebugHardwareViewButton, hardwareWidget and hardwareWidget:IsShown() and "Hardware: On" or "Hardware: Off") end
end

DebugFrame.minimizeButton:SetScript("OnClick", function() DebugFrame:CollapseToMinimizedWidget() end)
DebugFrame.minimizedWidget.closeButton:SetScript("OnClick", function() DebugFrame:CloseMinimizedWidget() end)
DebugFrame.minimizedWidget.expandButton:SetScript("OnClick", function() DebugFrame:ExpandFromMinimizedWidget() end)
DebugFrame.minimizedWidget:SetScript(
    "OnClick",
    function(self, button)
        if button ~= "LeftButton" then return end
        local now = GetTime and GetTime() or 0
        if now - (self.lastClick or 0) <= 0.35 then
            self.lastClick = 0
            DebugFrame:ExpandFromMinimizedWidget()
        else
            self.lastClick = now
        end
    end
)

local function EnsureRowLabel(rowFrame, columnIndex)
    local label = rowFrame.labels[columnIndex]
    if not label then
        label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        rowFrame.labels[columnIndex] = label
    end
    return label
end

local function PositionRowLabels(rowFrame, row)
    local totalWidth = GetColumnTotalWidth()
    local useErrorColor = RowUsesSpellbookErrorTimestamp(row)
    rowFrame:SetWidth(totalWidth)

    if row and row.message then
        local messageShown = false
        for _, columnIndex in ipairs(debugColumnOrder) do
            local label = EnsureRowLabel(rowFrame, columnIndex)
            label:ClearAllPoints()
            if not messageShown and IsDebugColumnVisible(columnIndex) then
                label:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
                label:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
                label:SetText(tostring(row.message or ""))
                if useErrorColor then
                    label:SetTextColor(1, 0.15, 0.15, 1)
                else
                    label:SetTextColor(1, 1, 1, 1)
                end
                label:Show()
                messageShown = true
            else
                label:SetText("")
                label:Hide()
            end
        end
        return
    end

    local left = 0
    for _, columnIndex in ipairs(debugColumnOrder) do
        local column = debugColumns[columnIndex]
        local label = EnsureRowLabel(rowFrame, columnIndex)
        if IsDebugColumnVisible(columnIndex) then
            label:ClearAllPoints()
            label:SetPoint("LEFT", rowFrame, "LEFT", left + 4, 0)
            label:SetWidth(math.max(1, (column.width or 0) - 8))
            label:SetHeight(DEBUG_UI.ROW_HEIGHT)
            label:SetText(tostring(row and row.values and row.values[columnIndex] or ""))
            if useErrorColor then
                label:SetTextColor(1, 0.15, 0.15, 1)
            else
                label:SetTextColor(1, 1, 1, 1)
            end
            label:Show()
            left = left + (column.width or 0) + DEBUG_UI.COLUMN_GAP
        else
            label:SetText("")
            label:Hide()
        end
    end
end

filterMenu = CreateFrame("Frame", "GSEGUIDebugFilterMenu", DebugFrame, frameTemplate)
filterMenu:SetFrameStrata(GetDebuggerPopupStrata())
filterMenu:SetClampedToScreen(true)
filterMenu:EnableMouse(true)
filterMenu:Hide()
if filterMenu.SetBackdrop then
    ApplyDebuggerDropdownBackdrop(filterMenu)
end

local function SetFrameStrataIfPossible(frame, strata)
    if frame and frame.SetFrameStrata then frame:SetFrameStrata(strata) end
end

RaiseDebuggerPopup = function(frame, anchor)
    if not frame then return end
    SetFrameStrataIfPossible(frame, GetDebuggerPopupStrata())
    if frame.SetToplevel then frame:SetToplevel(true) end
    if frame.SetFrameLevel then
        local debugLevel = (DebugFrame and DebugFrame.GetFrameLevel and DebugFrame:GetFrameLevel()) or 0
        local anchorLevel = (anchor and anchor.GetFrameLevel and anchor:GetFrameLevel()) or 0
        frame:SetFrameLevel(math.max(debugLevel, anchorLevel, 20) + 80)
    end
end

local function IsDebuggerDropdownShown()
    return (filterMenu and filterMenu.IsShown and filterMenu:IsShown()) or
        (statsFilterMenu and statsFilterMenu.IsShown and statsFilterMenu:IsShown()) or
        (debugColumnMenu and debugColumnMenu.IsShown and debugColumnMenu:IsShown())
end

function DebugFrame.HideDebuggerDropdowns()
    if filterMenu then filterMenu:Hide() end
    if statsFilterMenu then statsFilterMenu:Hide() end
    if debugColumnMenu then debugColumnMenu:Hide() end
    if DebugFrame.dropdownClickAwayFrame then DebugFrame.dropdownClickAwayFrame:Hide() end
end

local function HideDebuggerClickAwayWhenIdle()
    if DebugFrame.dropdownClickAwayFrame and not IsDebuggerDropdownShown() then
        DebugFrame.dropdownClickAwayFrame:Hide()
    end
end

local function HookDebuggerDropdown(frame)
    if not (frame and frame.HookScript) or frame.GSEDebuggerClickAwayHooked then return end
    frame.GSEDebuggerClickAwayHooked = true
    frame:HookScript("OnHide", HideDebuggerClickAwayWhenIdle)
end

function DebugFrame.ShowDebuggerDropdownClickAway(menu)
    if not menu then return end
    if not DebugFrame.dropdownClickAwayFrame then
        local clickAway = CreateFrame("Button", "GSEGUIDebugDropdownClickAwayFrame", UIParent)
        clickAway:SetAllPoints(UIParent)
        clickAway:EnableMouse(true)
        clickAway:RegisterForClicks("AnyDown")
        clickAway:SetScript("OnMouseDown", function() DebugFrame.HideDebuggerDropdowns() end)
        clickAway:Hide()
        DebugFrame.dropdownClickAwayFrame = clickAway
    end
    local clickAway = DebugFrame.dropdownClickAwayFrame
    clickAway:SetFrameStrata((menu.GetFrameStrata and menu:GetFrameStrata()) or GetDebuggerPopupStrata())
    if clickAway.SetFrameLevel then
        clickAway:SetFrameLevel(math.max(((menu.GetFrameLevel and menu:GetFrameLevel()) or 1) - 1, 0))
    end
    clickAway:Show()
end

HookDebuggerDropdown(filterMenu)
HookDebuggerDropdown(statsFilterMenu)

local filterScroll = CreateFrame("ScrollFrame", nil, filterMenu, "UIPanelScrollFrameTemplate")
filterScroll:SetPoint("TOPLEFT", filterMenu, "TOPLEFT", DEBUG_UI.DROPDOWN_INSET, -DEBUG_UI.DROPDOWN_INSET)
filterScroll:SetPoint("BOTTOMRIGHT", filterMenu, "BOTTOMRIGHT", -DEBUG_UI.DROPDOWN_INSET, DEBUG_UI.DROPDOWN_INSET)
HideDropdownScrollBar(filterScroll)
local filterContent = CreateFrame("Frame", nil, filterScroll)
filterContent:SetSize(1, 1)
filterScroll:SetScrollChild(filterContent)
local filterButtons = {}
local debugColumnButtons = {}

local function EnsureDebugOutputColumnMenu()
    if debugColumnMenu then return debugColumnMenu end

    debugColumnMenu = CreateFrame("Frame", "GSEGUIDebugOutputColumnMenu", UIParent, frameTemplate)
    debugColumnMenu:SetFrameStrata(GetDebuggerPopupStrata())
    debugColumnMenu:SetClampedToScreen(true)
    debugColumnMenu:EnableMouse(true)
    debugColumnMenu:SetSize(220, (#debugColumns * DEBUG_UI.DROPDOWN_ROW_HEIGHT) + (DEBUG_UI.DROPDOWN_INSET * 2))
    debugColumnMenu:Hide()
    ApplyDebuggerDropdownBackdrop(debugColumnMenu)

    local content = CreateFrame("Frame", nil, debugColumnMenu)
    content:SetPoint("TOPLEFT", debugColumnMenu, "TOPLEFT", DEBUG_UI.DROPDOWN_INSET, -DEBUG_UI.DROPDOWN_INSET)
    content:SetPoint("RIGHT", debugColumnMenu, "RIGHT", -DEBUG_UI.DROPDOWN_INSET, 0)
    content:SetHeight(#debugColumns * DEBUG_UI.DROPDOWN_ROW_HEIGHT)
    debugColumnMenu.content = content

    for index in ipairs(debugColumns) do
        local button = CreateFrame("Button", nil, content)
        EnsureDropdownRowVisuals(button)
        button:SetScript(
            "OnClick",
            function()
                local column = debugColumns[index]
                if not column then return end
                if column.visible ~= false and GetVisibleDebugColumnCount() <= 1 then return end
                column.visible = column.visible == false
                SaveColumnWidths()
                if ApplyColumnLayout then ApplyColumnLayout() end
                if UpdateRows then UpdateRows(false) end
                if RefreshStatsWidget then RefreshStatsWidget() end
                if ShowDebugOutputColumnMenu then ShowDebugOutputColumnMenu(outputLabel) end
            end
        )
        debugColumnButtons[index] = button
    end

    HookDebuggerDropdown(debugColumnMenu)
    return debugColumnMenu
end

local function RefreshDebugOutputColumnMenu()
    for rowIndex, index in ipairs(debugColumnOrder) do
        local column = debugColumns[index]
        local button = debugColumnButtons[index]
        if button then
            ConfigureDropdownRow(button, rowIndex, column.label or ("Column " .. index), IsDebugColumnVisible(index), button:GetScript("OnClick"))
        end
    end
end

ShowDebugOutputColumnMenu = function(anchor)
    local menu = EnsureDebugOutputColumnMenu()
    RefreshDebugOutputColumnMenu()
    RaiseDebuggerPopup(menu, anchor)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor or DebugFrame, "BOTTOMLEFT", 0, -2)
    DebugFrame.ShowDebuggerDropdownClickAway(menu)
    menu:Show()
    if menu.Raise then menu:Raise() end
end

EnsureDebugOutputColumnMenu()

local function UpdateFilterIndicators()
    for i, button in ipairs(headerMenuButtons) do
        button:SetText("v")
        local fontString = button:GetFontString()
        if fontString then
            if activeColumnFilters[i] or activeDebugSort.column == i then
                fontString:SetTextColor(1, 0.82, 0.15, 1)
            else
                fontString:SetTextColor(0.75, 0.75, 0.75, 1)
            end
        end
    end
end

local function GetFilterValuesForColumn(columnIndex)
    local values, seen, displayValues = {}, {}, {}
    for _, row in ipairs(debugRows) do
        local rawValue = row.values and row.values[columnIndex] or nil
        local value = rawValue and StripDebugColor(rawValue) or nil
        if value and value ~= "" and not seen[value] then
            seen[value] = true
            displayValues[value] = rawValue
            values[#values + 1] = value
        end
    end
    return values, displayValues
end

local function EnsureFilterButton(index)
    if filterButtons[index] then return filterButtons[index] end
    local button = CreateFrame("Button", nil, filterContent)
    EnsureDropdownRowVisuals(button)
    button:Hide()
    filterButtons[index] = button
    return button
end

for i = 1, DEBUG_UI.DROPDOWN_PRECREATE_ROWS do
    EnsureFilterButton(i)
end

local function ApplyColumnFilters(scrollToBottom)
    RebuildVisibleRows()
    UpdateFilterIndicators()
    UpdateRows(scrollToBottom)
    if RefreshStatsWidget then RefreshStatsWidget() end
    if HasActiveFilters() then
        local filterText = {}
        for columnIndex, value in pairs(activeColumnFilters) do
            local column = debugColumns[columnIndex]
            filterText[#filterText + 1] = tostring(column and column.label or columnIndex) .. " = " .. tostring(value)
        end
        table.sort(filterText)
        local suffix = ". Events remain in timestamp order."
        if activeDebugSort.column then
            local sortColumn = debugColumns[activeDebugSort.column]
            suffix = ". Events are sorted by " .. tostring(sortColumn and sortColumn.label or activeDebugSort.column) .. " " .. tostring(activeDebugSort.direction or "ASC") .. "."
        end
        GSE.GUIDebugAppendLine("Filter enabled: " .. table.concat(filterText, ", ") .. suffix)
    elseif SetDebuggerStatusText then
        SetDebuggerStatusText()
    else
        GSE.GUIDebugAppendLine("Filters disabled. Showing all events.")
    end
end

local function ApplyDebugColumnSort(columnIndex, direction)
    if not direction then
        activeDebugSort.column = nil
        activeDebugSort.direction = nil
    else
        activeDebugSort.column = columnIndex
        activeDebugSort.direction = direction == "DESC" and "DESC" or "ASC"
    end
    RebuildVisibleRows()
    UpdateFilterIndicators()
    UpdateRows(false)
    if SetDebuggerStatusText then
        if activeDebugSort.column then
            local column = debugColumns[activeDebugSort.column]
            DebugFrame:SetStatusText("Sorted by " .. tostring(column and column.label or activeDebugSort.column) .. " " .. activeDebugSort.direction)
        else
            SetDebuggerStatusText()
        end
    end
end

local function ShowFilterMenu(columnIndex, anchor)
    if IsDebugSortableColumn(columnIndex) then
        local column = debugColumns[columnIndex]
        local columnLabel = column and column.label or "Column"
        local menuWidth = math.max(180, column and column.width or 120)
        local rowCount = 3
        filterMenu:SetSize(menuWidth, rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT + (DEBUG_UI.DROPDOWN_INSET * 2))
        filterContent:SetSize(menuWidth - (DEBUG_UI.DROPDOWN_INSET * 2), rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT)

        local firstLabel = columnLabel == "Timestamp" and "Oldest First" or "Step Ascending"
        local secondLabel = columnLabel == "Timestamp" and "Newest First" or "Step Descending"
        ConfigureDropdownRow(
            EnsureFilterButton(1),
            1,
            firstLabel,
            activeDebugSort.column == columnIndex and activeDebugSort.direction == "ASC",
            function()
                filterMenu:Hide()
                ApplyDebugColumnSort(columnIndex, "ASC")
            end,
            {1, 0.82, 0, 1}
        )
        ConfigureDropdownRow(
            EnsureFilterButton(2),
            2,
            secondLabel,
            activeDebugSort.column == columnIndex and activeDebugSort.direction == "DESC",
            function()
                filterMenu:Hide()
                ApplyDebugColumnSort(columnIndex, "DESC")
            end,
            {1, 0.82, 0, 1}
        )
        ConfigureDropdownRow(
            EnsureFilterButton(3),
            3,
            "Clear Sort",
            not activeDebugSort.column,
            function()
                filterMenu:Hide()
                ApplyDebugColumnSort(nil, nil)
            end
        )
        for i = 4, #filterButtons do
            filterButtons[i]:Hide()
        end

        filterScroll:SetVerticalScroll(0)
        HideDropdownScrollBar(filterScroll)
        filterMenu:ClearAllPoints()
        RaiseDebuggerPopup(filterMenu, anchor)
        filterMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
        DebugFrame.ShowDebuggerDropdownClickAway(filterMenu)
        filterMenu:Show()
        return
    end

    if not IsFilterableColumn(columnIndex) then return end

    local values, displayValues = GetFilterValuesForColumn(columnIndex)
    local valueCount = math.min(#values, DEBUG_UI.DROPDOWN_PRECREATE_ROWS - 1)
    local rowCount = math.max(1, valueCount + 1)
    local menuWidth = math.max(180, debugColumns[columnIndex] and debugColumns[columnIndex].width or 120)
    local menuHeight = rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT + (DEBUG_UI.DROPDOWN_INSET * 2)
    filterMenu:SetSize(menuWidth, menuHeight)
    filterContent:SetSize(menuWidth - (DEBUG_UI.DROPDOWN_INSET * 2), rowCount * DEBUG_UI.DROPDOWN_ROW_HEIGHT)

    local function ConfigureButton(button, index, text, value, checked, isAllEvents)
        ConfigureDropdownRow(
            button,
            index,
            text,
            checked,
            function()
                activeColumnFilters[columnIndex] = value
                filterMenu:Hide()
                ApplyColumnFilters(false)
            end,
            isAllEvents and {1, 0.82, 0, 1} or nil
        )
    end

    ConfigureButton(EnsureFilterButton(1), 1, "All Events", nil, not activeColumnFilters[columnIndex], true)
    for i = 1, valueCount do
        local value = values[i]
        ConfigureButton(
            EnsureFilterButton(i + 1),
            i + 1,
            displayValues[value] or value,
            value,
            activeColumnFilters[columnIndex] == value
        )
    end
    for i = valueCount + 2, #filterButtons do
        filterButtons[i]:Hide()
    end

    filterScroll:SetVerticalScroll(0)
    HideDropdownScrollBar(filterScroll)
    filterMenu:ClearAllPoints()
    RaiseDebuggerPopup(filterMenu, anchor)
    filterMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    DebugFrame.ShowDebuggerDropdownClickAway(filterMenu)
    filterMenu:Show()
end

ApplyColumnLayout = function()
    local totalWidth = GetColumnTotalWidth()
    rowContent:SetWidth(math.max(totalWidth, scrollFrame:GetWidth() or 1))
    headerContent:SetSize(math.max(totalWidth, headerScrollFrame:GetWidth() or 1), DEBUG_UI.HEADER_HEIGHT)
    if headerScrollFrame.SetHorizontalScroll then headerScrollFrame:SetHorizontalScroll(0) end

    local left = 0
    local visibleOrder = GetVisibleDebugColumnOrder()
    local lastVisibleColumnIndex = visibleOrder[#visibleOrder]
    for _, i in ipairs(debugColumnOrder) do
        local column = debugColumns[i]
        local label = headerLabels[i]
        if label then
            if IsDebugColumnVisible(i) then
                label:ClearAllPoints()
                label:SetPoint("LEFT", headerContent, "LEFT", left + 4, 0)
                local menuWidth = HasDebugColumnMenu(i) and DEBUG_UI.COLUMN_MENU_WIDTH or 0
                label:SetWidth(math.max(1, (column.width or 0) - menuWidth - 8))
                label:SetHeight(DEBUG_UI.HEADER_HEIGHT)
                label:SetText(column.label or "")
                label:Show()
            else
                label:Hide()
            end
        end

        local dragButton = headerDragButtons[i]
        if dragButton then
            if IsDebugColumnVisible(i) then
                local menuWidth = HasDebugColumnMenu(i) and DEBUG_UI.COLUMN_MENU_WIDTH or 0
                dragButton:ClearAllPoints()
                dragButton:SetPoint("LEFT", headerContent, "LEFT", left, 0)
                dragButton:SetSize(math.max(1, (column.width or 0) - menuWidth - DEBUG_UI.COLUMN_HANDLE_WIDTH), DEBUG_UI.HEADER_HEIGHT)
                dragButton:Show()
            else
                dragButton:Hide()
            end
        end

        local menuButton = headerMenuButtons[i]
        if menuButton then
            if IsDebugColumnVisible(i) and HasDebugColumnMenu(i) then
                menuButton:ClearAllPoints()
                menuButton:SetPoint("LEFT", headerContent, "LEFT", left + (column.width or 0) - DEBUG_UI.COLUMN_MENU_WIDTH - 2, 2)
                menuButton:SetSize(DEBUG_UI.COLUMN_MENU_WIDTH, DEBUG_UI.HEADER_HEIGHT - 4)
                menuButton:Show()
            else
                menuButton:Hide()
            end
        end

        local handle = headerHandles[i]
        if handle then
            if IsDebugColumnVisible(i) and i ~= lastVisibleColumnIndex then
                handle:ClearAllPoints()
                handle:SetPoint("LEFT", headerContent, "LEFT", left + (column.width or 0) - 2, 0)
                handle:SetHeight(DEBUG_UI.HEADER_HEIGHT)
                handle:Show()
            else
                handle:Hide()
            end
        end
        if IsDebugColumnVisible(i) then left = left + (column.width or 0) + DEBUG_UI.COLUMN_GAP end
    end

    for _, rowFrame in ipairs(rowPool) do
        PositionRowLabels(rowFrame, rowFrame.debugRow)
    end
end

local function GetDebugHeaderCursorX()
    local cursorX = GetCursorPosition()
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    local headerLeft = headerContent:GetLeft() or 0
    return (cursorX / scale) - headerLeft
end

local function GetDebugColumnBeforeCursor(cursorX, movingColumnIndex)
    local left = 0
    for _, columnIndex in ipairs(debugColumnOrder) do
        if IsDebugColumnVisible(columnIndex) then
            local column = debugColumns[columnIndex]
            local columnWidth = column and column.width or 0
            if columnIndex ~= movingColumnIndex and cursorX < left + (columnWidth / 2) then return columnIndex end
            left = left + columnWidth + DEBUG_UI.COLUMN_GAP
        end
    end
end

local function UpdateDebugHeaderDrag(dragButton)
    local columnIndex = dragButton and dragButton.columnIndex
    if not columnIndex then return end
    local beforeColumnIndex = GetDebugColumnBeforeCursor(GetDebugHeaderCursorX(), columnIndex)
    if MoveDebugColumnBefore(columnIndex, beforeColumnIndex) then
        dragButton.dragMoved = true
        SaveColumnWidths()
        ApplyColumnLayout()
    end
end

local function EnsureHeaderColumns()
    for i, _ in ipairs(debugColumns) do
        if not headerLabels[i] then
            local label = headerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            headerLabels[i] = label
        end

        if not headerDragButtons[i] then
            local columnIndex = i
            local dragButton = CreateFrame("Button", nil, headerContent)
            dragButton.columnIndex = columnIndex
            dragButton:EnableMouse(true)
            if dragButton.SetFrameLevel then dragButton:SetFrameLevel((headerContent:GetFrameLevel() or 0) + 10) end
            dragButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            dragButton:SetScript(
                "OnMouseDown",
                function(self, button)
                    if button ~= "LeftButton" then return end
                    if DebugFrame.HideDebuggerDropdowns then DebugFrame.HideDebuggerDropdowns() end
                    self.dragMoved = false
                    self:SetScript("OnUpdate", UpdateDebugHeaderDrag)
                end
            )
            dragButton:SetScript(
                "OnMouseUp",
                function(self)
                    self:SetScript("OnUpdate", nil)
                    if self.dragMoved then
                        SaveColumnWidths()
                        if RefreshStatsWidget then RefreshStatsWidget() end
                    end
                    self.dragMoved = false
                end
            )
            headerDragButtons[columnIndex] = dragButton
        end

        if HasDebugColumnMenu(i) and not headerMenuButtons[i] then
            local columnIndex = i
            local menuButton = CreateFrame("Button", nil, headerContent)
            menuButton:SetSize(DEBUG_UI.COLUMN_MENU_WIDTH, DEBUG_UI.HEADER_HEIGHT - 4)
            if menuButton.SetFrameLevel then menuButton:SetFrameLevel((headerContent:GetFrameLevel() or 0) + 20) end
            local arrow = menuButton:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            arrow:SetPoint("CENTER", menuButton, "CENTER", 0, 0)
            arrow:SetJustifyH("CENTER")
            menuButton:SetFontString(arrow)
            menuButton:SetText("v")
            menuButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            menuButton:SetScript(
                "OnClick",
                function(self)
                    if filterMenu:IsShown() and filterMenu.columnIndex == columnIndex then
                        filterMenu:Hide()
                        return
                    end
                    filterMenu.columnIndex = columnIndex
                    ShowFilterMenu(columnIndex, self)
                end
            )
            headerMenuButtons[columnIndex] = menuButton
        end

        if not headerHandles[i] then
            local columnIndex = i
            local handle = CreateFrame("Frame", nil, headerContent)
            handle:SetWidth(DEBUG_UI.COLUMN_HANDLE_WIDTH)
            handle:EnableMouse(true)
            if handle.SetFrameLevel then handle:SetFrameLevel((headerContent:GetFrameLevel() or 0) + 30) end
            local texture = handle:CreateTexture(nil, "OVERLAY")
            texture:SetPoint("TOP", handle, "TOP", 0, -3)
            texture:SetPoint("BOTTOM", handle, "BOTTOM", 0, 3)
            texture:SetWidth(1)
            texture:SetColorTexture(0.7, 0.62, 0.12, 0.8)
            handle.texture = texture
            handle:SetScript("OnEnter", function(self) self.texture:SetColorTexture(1, 0.82, 0.15, 1) end)
            handle:SetScript("OnLeave", function(self) self.texture:SetColorTexture(0.7, 0.62, 0.12, 0.8) end)
            handle:SetScript(
                "OnMouseDown",
                function(self, button)
                    if button ~= "LeftButton" then return end
                    local cursorX = GetCursorPosition()
                    local scale = UIParent and UIParent:GetEffectiveScale() or 1
                    self.startCursorX = cursorX / scale
                    self.startWidth = debugColumns[columnIndex].width or 0
                    self.maxDragDelta = math.max(0, (headerScrollFrame:GetRight() or self.startCursorX) - self.startCursorX)
                    self:SetScript(
                        "OnUpdate",
                        function(dragHandle)
                            local currentCursorX = GetCursorPosition()
                            local currentScale = UIParent and UIParent:GetEffectiveScale() or 1
                            local delta = (currentCursorX / currentScale) - (dragHandle.startCursorX or 0)
                            if dragHandle.maxDragDelta then delta = math.min(delta, dragHandle.maxDragDelta) end
                            local newWidth = ClampNumber(
                                (dragHandle.startWidth or 0) + delta,
                                debugColumns[columnIndex].min or 35,
                                600,
                                debugColumns[columnIndex].width or 80
                            )
                            if newWidth ~= debugColumns[columnIndex].width then
                                debugColumns[columnIndex].width = newWidth
                                SaveColumnWidths()
                                ApplyColumnLayout()
                            end
                        end
                    )
                end
            )
            handle:SetScript(
                "OnMouseUp",
                function(self)
                    self:SetScript("OnUpdate", nil)
                    self.maxDragDelta = nil
                    SaveColumnWidths()
                end
            )
            headerHandles[columnIndex] = handle
        end
    end
end

local function EnsureRowPool(visibleRows)
    for i = #rowPool + 1, visibleRows do
        local rowFrame = CreateFrame("Frame", nil, rowContent)
        rowFrame:SetHeight(DEBUG_UI.ROW_HEIGHT)
        rowFrame.labels = {}
        rowFrame:Hide()
        rowPool[i] = rowFrame
    end
end

UpdateRows = function(scrollToBottom)
    local viewportHeight = math.max(1, scrollFrame:GetHeight() or 1)
    local totalHeight = math.max(1, #visibleRows * DEBUG_UI.ROW_HEIGHT)
    local visibleRowCount = math.ceil(viewportHeight / DEBUG_UI.ROW_HEIGHT) + 2
    rowContent:SetHeight(totalHeight)
    rowContent:SetWidth(math.max(GetColumnTotalWidth(), scrollFrame:GetWidth() or 1))
    EnsureRowPool(visibleRowCount)
    if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end

    local maxScroll = math.max(0, totalHeight - viewportHeight)
    if scrollToBottom then
        scrollFrame:SetVerticalScroll(maxScroll)
    elseif (scrollFrame:GetVerticalScroll() or 0) > maxScroll then
        scrollFrame:SetVerticalScroll(maxScroll)
    end

    local offset = scrollFrame:GetVerticalScroll() or 0
    local firstRow = math.floor(offset / DEBUG_UI.ROW_HEIGHT) + 1
    for i, rowFrame in ipairs(rowPool) do
        local rowIndex = firstRow + i - 1
        local row = visibleRows[rowIndex]
        rowFrame.debugRow = row
        if row then
            rowFrame:ClearAllPoints()
            rowFrame:SetPoint("TOPLEFT", rowContent, "TOPLEFT", 0, -((rowIndex - 1) * DEBUG_UI.ROW_HEIGHT))
            rowFrame:SetHeight(DEBUG_UI.ROW_HEIGHT)
            PositionRowLabels(rowFrame, row)
            rowFrame:Show()
        else
            rowFrame:Hide()
        end
    end
end

local function AddDebugRow(row, scrollToBottom)
    if GetTime and not row.createdAt then row.createdAt = GetTime() end
    row.debugIndex = #debugRows + 1
    MarkSpellbookErrorTimestamp(row)
    debugRows[#debugRows + 1] = row
    if RowMatchesFilters(row) then
        visibleRows[#visibleRows + 1] = row
        ApplyDebugVisibleSort()
    end
    UpdateRows((scrollToBottom ~= false) and not activeDebugSort.column)
    if RefreshStatsWidget then RefreshStatsWidget() end
end

local function ParseDebugLine(line)
    local cleaned = StripDebugColor(line)
    if GSE.SequenceDebugColumnHeader and cleaned == StripDebugColor(GSE.SequenceDebugColumnHeader()) then return end
    if cleaned == "" then return end

    local values = {}
    for part in string.gmatch(cleaned, "([^|]+)") do
        values[#values + 1] = Trim(part)
    end
    if #values == #debugColumns then
        AddDebugRow({values = values})
    else
        AddDebugRow({message = cleaned})
    end
end

local function ScrollDebugFrame(delta)
    local range = math.max(0, (#visibleRows * DEBUG_UI.ROW_HEIGHT) - math.max(1, scrollFrame:GetHeight() or 1))
    local current = scrollFrame:GetVerticalScroll() or 0
    local target = current - ((delta or 0) * (DEBUG_UI.ROW_HEIGHT * 3))
    scrollFrame:SetVerticalScroll(math.min(math.max(target, 0), range))
    UpdateRows(false)
end

scrollFrame:SetScript("OnVerticalScroll", function() UpdateRows(false) end)
scrollFrame:SetScript("OnMouseWheel", function(_, delta) ScrollDebugFrame(delta) end)
scrollBackground:EnableMouseWheel(true)
scrollBackground:SetScript("OnMouseWheel", function(_, delta) ScrollDebugFrame(delta) end)

DebugFrame.DebugOutputBoxData = {}
function DebugFrame.DebugOutputBoxData:GetText()
    return DebugRowsToExport()
end

function DebugFrame.DebugOutputBoxData:SetText(text)
    for i = #debugRows, 1, -1 do
        debugRows[i] = nil
    end
    for i = #visibleRows, 1, -1 do
        visibleRows[i] = nil
    end
    for timestamp in pairs(debugErrorTimestamps) do
        debugErrorTimestamps[timestamp] = nil
    end
    statsResetDebugIndex = 1
    if not GSE.isEmpty(text) then
        for line in string.gmatch(text .. "\n", "(.-)\n") do
            if line and line ~= "" then ParseDebugLine(line) end
        end
    end
    RebuildVisibleRows()
    UpdateRows(true)
    if RefreshStatsWidget then RefreshStatsWidget() end
end

function DebugFrame.DebugOutputBoxData:SetNumLines()
end

function DebugFrame.DebugOutputBoxData:SetHeight(height)
    scrollBackground:SetHeight(height)
end

function DebugFrame.DebugOutputBoxData:SetLabel()
end

function DebugFrame.DebugOutputBoxData:DisableButton()
end

function DebugFrame.DebugOutputBoxData:SetFullWidth()
end

DebugFrame.DebugOutputBoxData.frame = scrollBackground
DebugFrame.DebugOutputBoxData.headerFrame = headerBackground
DebugFrame.DebugOutputBoxData.scrollFrame = scrollFrame
DebugFrame.DebugOutputBoxData.rows = debugRows
DebugFrame.DebugOutputTextbox = DebugFrame.DebugOutputBoxData
EnsureHeaderColumns()

DebugFrame.statustext = DebugFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
DebugFrame.statustext:SetPoint("BOTTOMLEFT", DebugFrame, "BOTTOMLEFT", DEBUG_UI.FRAME_PADDING, 11)
DebugFrame.statustext:SetPoint("BOTTOMRIGHT", DebugFrame, "BOTTOMRIGHT", -DEBUG_UI.FRAME_PADDING, 11)
DebugFrame.statustext:SetJustifyH("CENTER")
function DebugFrame:SetVersionTextHover(hovered)
    if not self.statustext then return end
    if self.statustext.GetFont and self.statustext.SetFont then
        if not self.versionTextBaseFont then
            local fontFile, fontSize, fontFlags = self.statustext:GetFont()
            if fontFile and fontSize then self.versionTextBaseFont = {fontFile, fontSize, fontFlags} end
        end
        if self.versionTextBaseFont then
            self.statustext:SetFont(
                self.versionTextBaseFont[1],
                hovered and math.floor((self.versionTextBaseFont[2] * 1.14) + 0.5) or self.versionTextBaseFont[2],
                self.versionTextBaseFont[3]
            )
            return
        end
    end
    if self.statustext.SetScale then self.statustext:SetScale(hovered and 1.08 or 1) end
end
function DebugFrame:UpdateVersionHitBox()
    if not (self.versionHitBox and self.statustext) then return end
    local textWidth = self.statustext.GetStringWidth and self.statustext:GetStringWidth() or 0
    local textHeight = self.statustext.GetStringHeight and self.statustext:GetStringHeight() or 0
    self.versionHitBox:ClearAllPoints()
    self.versionHitBox:SetSize(math.max(1, math.ceil(textWidth)), math.max(12, math.ceil(textHeight) + 6))
    self.versionHitBox:SetPoint("CENTER", self.statustext, "CENTER", 0, 0)
end
DebugFrame.versionHitBox = CreateFrame("Button", nil, DebugFrame)
DebugFrame.versionHitBox:RegisterForClicks("LeftButtonUp")
DebugFrame.versionHitBox:EnableMouse(true)
if DebugFrame.versionHitBox.SetFrameLevel then DebugFrame.versionHitBox:SetFrameLevel((DebugFrame:GetFrameLevel() or 0) + 80) end
DebugFrame.versionHitBox:SetScript(
    "OnMouseDown",
    function()
        local now = GetTime and GetTime() or 0
        if now - (DebugFrame.lastVersionClick or 0) <= 0.35 then
            DebugFrame.lastVersionClick = 0
            if GSE.GUIShowVersionCopyWindow then GSE.GUIShowVersionCopyWindow() end
            return
        end
        DebugFrame.lastVersionClick = now
    end
)
DebugFrame.versionHitBox:SetScript(
    "OnEnter",
    function(self)
        DebugFrame:SetVersionTextHover(true)
        DebugFrame:UpdateVersionHitBox()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("GSE Version")
        GameTooltip:AddLine("Double-click: Copy version", 1, 1, 1)
        GameTooltip:Show()
    end
)
DebugFrame.versionHitBox:SetScript(
    "OnLeave",
    function()
        DebugFrame:SetVersionTextHover(false)
        DebugFrame:UpdateVersionHitBox()
        if GameTooltip then GameTooltip:Hide() end
    end
)
DebugFrame:UpdateVersionHitBox()

DebugFrame.DebugSearchLabel = DebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
DebugFrame.DebugSearchLabel:SetText("")
DebugFrame.DebugSearchLabel:SetJustifyH("RIGHT")
DebugFrame.DebugSearchLabel:Hide()

DebugFrame.DebugSearchBox = CreateFrame("EditBox", "GSEGUIDebugSearchBox", DebugFrame, "InputBoxTemplate")
DebugFrame.DebugSearchBox:SetAutoFocus(false)
DebugFrame.DebugSearchBox:SetFontObject("GameFontHighlightSmall")
DebugFrame.DebugSearchBox:SetHeight(20)
DebugFrame.DebugSearchSuggestion = DebugFrame.DebugSearchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
DebugFrame.DebugSearchSuggestion:SetPoint("LEFT", DebugFrame.DebugSearchBox, "LEFT", 7, 0)
DebugFrame.DebugSearchSuggestion:SetPoint("RIGHT", DebugFrame.DebugSearchBox, "RIGHT", -6, 0)
DebugFrame.DebugSearchSuggestion:SetHeight(20)
DebugFrame.DebugSearchSuggestion:SetJustifyH("LEFT")
DebugFrame.DebugSearchSuggestion:SetTextColor(0.55, 0.55, 0.55, 0.7)
DebugFrame.DebugSearchSuggestion:SetText("")

function DebugFrame:RefreshSearchSuggestion(searchBox)
    local typedText = Trim(StripDebugColor(searchBox:GetText() or ""))
    self.PendingSearchSuggestion = nil
    DebugFrame.DebugSearchSuggestion:SetText("")
    if typedText == "" then return typedText end

    local suggestion = FindSearchSuggestion(typedText)
    if suggestion and string.lower(suggestion) ~= string.lower(typedText) then
        self.PendingSearchSuggestion = suggestion
        local suffix = string.sub(suggestion, string.len(typedText) + 1)
        DebugFrame.DebugSearchSuggestion:SetText(string.rep(" ", string.len(typedText)) .. suffix)
    end
    return typedText
end

DebugFrame.DebugSearchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    DebugFrame.PendingSearchSuggestion = nil
    DebugFrame.DebugSearchSuggestion:SetText("")
    activeSearchText = ""
    ApplySearchFilter(true)
    self:ClearFocus()
end)
DebugFrame.DebugSearchBox:SetScript("OnEnterPressed", function(self)
    local typedText = Trim(StripDebugColor(self:GetText() or ""))
    activeSearchText = DebugFrame.PendingSearchSuggestion or typedText
    if DebugFrame.PendingSearchSuggestion and DebugFrame.PendingSearchSuggestion ~= typedText then
        self:SetText(DebugFrame.PendingSearchSuggestion)
        self:SetCursorPosition(string.len(DebugFrame.PendingSearchSuggestion))
    end
    DebugFrame.PendingSearchSuggestion = nil
    DebugFrame.DebugSearchSuggestion:SetText("")
    self:HighlightText(0, 0)
    self:ClearFocus()
    ApplySearchFilter(true)
end)
DebugFrame.DebugSearchBox:SetScript(
    "OnTextChanged",
    function(self)
        local typedText = DebugFrame:RefreshSearchSuggestion(self)
        if typedText == "" and activeSearchText ~= "" then
            activeSearchText = ""
            ApplySearchFilter(true)
        end
    end
)

DebugFrame.DebugCombatTimer = DebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
DebugFrame.DebugCombatTimer:SetWidth(240)
DebugFrame.DebugCombatTimer:SetJustifyH("RIGHT")

function DebugFrame.DebugSetButtonDisabled(button, disabled)
    if disabled then
        button:Disable()
    else
        button:Enable()
    end
    GSE.StyleDebugTextButton(button)
end

function DebugFrame.DebugCreateButton(label)
    local button = CreateFrame("Button", nil, DebugFrame, "UIPanelButtonTemplate")
    button:SetSize(DEBUG_UI.BUTTON_WIDTH, DEBUG_UI.BUTTON_HEIGHT)
    GSE.SetDebuggerButtonText(button, label)
    button.SetDisabled = DebugFrame.DebugSetButtonDisabled
    GSE.StyleDebugTextButton(button)
    return button
end

function GSE.SetDebuggerButtonTooltip(button, title, tip)
    if not button then return end
    button:SetScript(
        "OnEnter",
        function(self)
            local tooltipTitle = type(title) == "function" and title(self) or title
            local tooltipTip = type(tip) == "function" and tip(self) or tip
            if GSE.CreateToolTip then GSE.CreateToolTip(tostring(tooltipTitle or ""), tostring(tooltipTip or ""), DebugFrame) end
        end
    )
    button:SetScript("OnLeave", function() if GSE.ClearTooltip then GSE.ClearTooltip(DebugFrame) end end)
end

DebugFrame.DebugEnableViewButton = DebugFrame.DebugCreateButton("Enable")
DebugFrame.DebugPauseViewButton = DebugFrame.DebugCreateButton("Pause")
DebugFrame.DebugClearViewButton = DebugFrame.DebugCreateButton("Clear")
DebugFrame.DebugHardwareViewButton = DebugFrame.DebugCreateButton("Hardware: Off")
DebugFrame.DebugHardwareViewButton:SetSize(DEBUG_UI.HARDWARE_BUTTON_WIDTH, DEBUG_UI.BUTTON_HEIGHT)
DebugFrame.DebugExportOutputButton = DebugFrame.DebugCreateButton("Export")
DebugFrame.DebugStatsViewButton = DebugFrame.DebugCreateButton("Stats: Off")
DebugFrame.DebugOptionsViewButton = DebugFrame.DebugCreateButton("Options")
DebugFrame.DebugReloadViewButton = DebugFrame.DebugCreateButton("Reload")
DebugFrame.DebugResourcesViewButton = DebugFrame.DebugCreateButton("|cFFFFFFFFGS|r|cFF00FFFFE|r|cFFFFFFFF:|r |cFFFFD100Resources|r")
DebugFrame.DebugResourcesViewButton:SetSize(DEBUG_UI.RESOURCE_BUTTON_WIDTH, DEBUG_UI.BUTTON_HEIGHT)
DebugFrame.DebugTrackerViewButton = DebugFrame.DebugCreateButton("Tracker: On")
DebugFrame.DebugTrackerViewButton:SetSize(DEBUG_UI.HARDWARE_BUTTON_WIDTH, DEBUG_UI.BUTTON_HEIGHT)

GSE.SetDebuggerButtonTooltip(
    DebugFrame.DebugEnableViewButton,
    function() return GSE.UnsavedOptions["DebugSequenceExecution"] and DebuggerLabel("Disable") or DebuggerLabel("Enable") end,
    function()
        return GSE.UnsavedOptions["DebugSequenceExecution"] and
            "Stops logging sequence debugger events." or
            "Starts logging sequence debugger events."
    end
)
GSE.SetDebuggerButtonTooltip(
    DebugFrame.DebugPauseViewButton,
    function() return onpause and DebuggerLabel("Resume") or DebuggerLabel("Pause") end,
    function()
        return onpause and
            "Resumes logging sequence debugger events." or
            "Pauses logging without clearing the current debugger output."
    end
)
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugClearViewButton, DebuggerLabel("Clear"), "Clears all debugger output.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugExportOutputButton, DebuggerLabel("Export"), "Opens a copy window for the current debugger output.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugOptionsViewButton, DebuggerLabel("Options"), DebuggerLabel("Opens the GSE Options window"))
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugResourcesViewButton, "Resources", "All GSE Support, Tools, Sequences, Community, Patreon Links.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugTrackerViewButton, "Tracker", "Master on/off switch for the GSE Tracker (sequence icons, text panel, successful cast, assisted highlight). Mirrors the Options panel Tracker toggle.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugHardwareViewButton, "Hardware Events", "Opens or closes the Hardware Events window.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugReloadViewButton, DebuggerLabel("Reload"), "Reloads the user interface.")
GSE.SetDebuggerButtonTooltip(DebugFrame.DebugStatsViewButton, "Debug Stats", "Opens or closes the Debug Stats window.")

DebugFrame.DebugResizeButton = CreateFrame("Button", nil, DebugFrame)
DebugFrame.DebugResizeButton:SetSize(16, 16)
DebugFrame.DebugResizeButton:SetPoint("BOTTOMRIGHT", DebugFrame, "BOTTOMRIGHT", -8, 8)
DebugFrame.DebugResizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
DebugFrame.DebugResizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
DebugFrame.DebugResizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
DebugFrame.DebugResizeButton:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then DebugFrame:StartSizing("BOTTOMRIGHT") end
end)
DebugFrame.DebugResizeButton:SetScript("OnMouseUp", function()
    DebugFrame:StopMovingOrSizing()
    if DebugFrame.SaveDebuggerLocation then DebugFrame:SaveDebuggerLocation() end
end)

function DebugFrame.RaiseDebugControl(parent, control, offset)
    if not (control and parent) then return end
    if control.SetFrameStrata and parent.GetFrameStrata then
        control:SetFrameStrata(parent:GetFrameStrata())
    end
    if control.SetFrameLevel and parent.GetFrameLevel then
        control:SetFrameLevel((parent:GetFrameLevel() or 0) + (offset or 80))
    end
end

function DebugFrame.RaiseDebuggerControls()
    DebugFrame.RaiseDebugControl(DebugFrame, closeButton, 500)
    if DebugFrame.minimizeButton and closeButton and DebugFrame.minimizeButton.SetFrameLevel then
        DebugFrame.minimizeButton:SetFrameLevel(((closeButton and closeButton.GetFrameLevel and closeButton:GetFrameLevel()) or DebugFrame:GetFrameLevel() or 0) + 2)
    end
    if DebugFrame.TitleContainer and DebugFrame.TitleContainer.SetFrameLevel then
        local closeLevel = closeButton and closeButton.GetFrameLevel and closeButton:GetFrameLevel()
        DebugFrame.TitleContainer:SetFrameLevel(math.max((DebugFrame:GetFrameLevel() or 0) + 90, (closeLevel or 0) - 4))
    end
    PositionDebuggerTitleText()
    if DebugFrame.minimizeButton and DebugFrame.minimizeButton.icon then
        DebugFrame.minimizeButton.icon:Show()
    end
    if closeButton and closeButton.Raise then closeButton:Raise() end
    if DebugFrame.minimizeButton and DebugFrame.minimizeButton.Raise then DebugFrame.minimizeButton:Raise() end
end

function DebugFrame.UpdateDebuggerLayout()
    local width = DebugFrame:GetWidth()
    local height = DebugFrame:GetHeight()
    local primaryButtonTop = 58
    local secondaryButtonTop = 30
    local outputBottom = 88
    local outputTop = 66

    titleHitBox:ClearAllPoints()
    titleHitBox:SetPoint("TOPLEFT", DebugFrame, "TOPLEFT", 24, -1)
    titleHitBox:SetPoint("TOPRIGHT", DebugFrame, "TOPRIGHT", -24, -1)
    titleHitBox:SetHeight(20)
    PositionDebuggerTitleText()

    DebugFrame.minimizeButton:ClearAllPoints()
    DebugFrame.minimizeButton:SetPoint("RIGHT", closeButton, "LEFT", 2, 0)

    outputLabel:ClearAllPoints()
    outputLabel:SetPoint("TOPLEFT", DebugFrame, "TOPLEFT", DEBUG_UI.FRAME_PADDING + 5, -39)
    outputLabel:SetSize(170, 22)

    scrollBackground:ClearAllPoints()
    scrollBackground:SetPoint("TOPLEFT", DebugFrame, "TOPLEFT", DEBUG_UI.FRAME_PADDING, -outputTop)
    scrollBackground:SetPoint("BOTTOMRIGHT", DebugFrame, "BOTTOMRIGHT", -36, outputBottom)

    headerBackground:ClearAllPoints()
    headerBackground:SetPoint("TOPLEFT", scrollBackground, "TOPLEFT", 4, -4)
    headerBackground:SetPoint("TOPRIGHT", scrollBackground, "TOPRIGHT", -4, -4)
    headerBackground:SetHeight(DEBUG_UI.HEADER_HEIGHT)

    headerScrollFrame:ClearAllPoints()
    headerScrollFrame:SetPoint("TOPLEFT", headerBackground, "TOPLEFT", 0, 0)
    headerScrollFrame:SetPoint("BOTTOMRIGHT", headerBackground, "BOTTOMRIGHT", 0, 0)

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", headerBackground, "BOTTOMLEFT", 0, -DEBUG_UI.HEADER_GAP)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollBackground, "BOTTOMRIGHT", -4, 4)

    local searchWidth = math.min(360, math.max(240, width * 0.32))
    DebugFrame.DebugSearchBox:ClearAllPoints()
    DebugFrame.DebugSearchBox:SetPoint("TOP", DebugFrame, "TOP", 0, -42)
    DebugFrame.DebugSearchBox:SetSize(searchWidth, 20)
    DebugFrame.DebugSearchLabel:ClearAllPoints()
    DebugFrame.DebugSearchLabel:Hide()

    DebugFrame.DebugCombatTimer:ClearAllPoints()
    DebugFrame.DebugCombatTimer:SetPoint("TOPRIGHT", DebugFrame, "TOPRIGHT", -48, -42)
    DebugFrame.DebugCombatTimer:SetWidth(240)

    if statsWidget:IsShown() then
        AnchorStatsWidget()
        if LayoutStatsWidget then LayoutStatsWidget() end
    end
    if hardwareWidget:IsShown() then
        AnchorHardwareWidget()
        if LayoutHardwareWidget then LayoutHardwareWidget() end
    end
    if DebugFrame.DebugStatsViewButton then GSE.SetDebuggerButtonText(DebugFrame.DebugStatsViewButton, statsWidget:IsShown() and "Stats: On" or "Stats: Off") end
    if DebugFrame.DebugHardwareViewButton then GSE.SetDebuggerButtonText(DebugFrame.DebugHardwareViewButton, hardwareWidget:IsShown() and "Hardware: On" or "Hardware: Off") end
    if DebugFrame.DebugTrackerViewButton then GSE.SetDebuggerButtonText(DebugFrame.DebugTrackerViewButton, (GSEOptions and GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Enabled) and "Tracker: On" or "Tracker: Off") end

    ApplyColumnLayout()
    UpdateRows(false)

    local function PositionCenteredButtonRow(buttons, bottomOffset)
        local totalWidth = 0
        for index, button in ipairs(buttons) do
            totalWidth = totalWidth + (button:GetWidth() or DEBUG_UI.BUTTON_WIDTH)
            if index > 1 then totalWidth = totalWidth + DEBUG_UI.BUTTON_GAP end
        end
        -- Anchor each button's BOTTOMLEFT to the frame's BOTTOM (middle of the
        -- bottom edge). cursorX starts at -totalWidth/2 (the row's left edge
        -- relative to frame center) and advances right with each button. WoW's
        -- anchor system keeps this aligned with the frame center automatically,
        -- so resizing the debugger no longer leaves the row off-center even if
        -- a layout pass reads a stale GetWidth value.
        local cursorX = -math.floor(totalWidth / 2 + 0.5)
        local roundedBottom = math.floor(bottomOffset + 0.5)
        for _, button in ipairs(buttons) do
            local roundedCursor = math.floor(cursorX + 0.5)
            if button:GetNumPoints() == 0 or button.GSEDebugRowCenterX ~= roundedCursor or button.GSEDebugRowBottom ~= roundedBottom then
                button:ClearAllPoints()
                button:SetPoint("BOTTOMLEFT", DebugFrame, "BOTTOM", roundedCursor, roundedBottom)
                button.GSEDebugRowCenterX = roundedCursor
                button.GSEDebugRowBottom = roundedBottom
            end
            cursorX = cursorX + (button:GetWidth() or DEBUG_UI.BUTTON_WIDTH) + DEBUG_UI.BUTTON_GAP
        end
    end

    local primaryButtons = {
        DebugFrame.DebugEnableViewButton,
        DebugFrame.DebugPauseViewButton,
        DebugFrame.DebugClearViewButton,
        DebugFrame.DebugExportOutputButton,
        DebugFrame.DebugOptionsViewButton,
        DebugFrame.DebugResourcesViewButton
    }
    PositionCenteredButtonRow(primaryButtons, primaryButtonTop)

    local secondaryButtons = {
        DebugFrame.DebugHardwareViewButton,
        DebugFrame.DebugTrackerViewButton,
        DebugFrame.DebugReloadViewButton,
        DebugFrame.DebugStatsViewButton
    }
    PositionCenteredButtonRow(secondaryButtons, secondaryButtonTop)
    DebugFrame.RaiseDebuggerControls()
end

function DebugFrame:SetTitle(text)
    DebugFrame.debuggerTitleText = DebuggerWindowTitle(text or DebuggerLabel("Sequence Debugger"))
    PositionDebuggerTitleText()
end

function DebugFrame:SetStatusText(text)
    self.statustext:SetText(text or "")
    if self.UpdateVersionHitBox then self:UpdateVersionHitBox() end
end

function DebugFrame:RefreshLayout()
    DebugFrame.UpdateDebuggerLayout()
end

function DebugFrame:SaveDebuggerLocation()
    local location = EnsureDebuggerLocation()
    location.top = self:GetTop()
    location.left = self:GetLeft()
    location.width = ClampNumber(self:GetWidth(), DEBUG_UI.MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), DEBUG_UI.MIN_DEBUGGER_WIDTH)
    location.height = ClampNumber(self:GetHeight(), DEBUG_UI.MIN_DEBUGGER_HEIGHT, GetMaxDebuggerHeight(), DEBUG_UI.MIN_DEBUGGER_HEIGHT)
    GSEOptions.debugWidth = location.width
    GSEOptions.debugHeight = location.height
    SaveColumnWidths()
end

SetDebuggerStatusText = function()
    DebugFrame:SetStatusText("GSE: " .. tostring(GSE.VersionString or ""))
end

function GSE.GUIUpdateOutput()
    if GSE.isEmpty(GSE.DebugOutput) then return end
    for line in string.gmatch(GSE.DebugOutput .. "\n", "(.-)\n") do
        if line and line ~= "" then ParseDebugLine(line) end
    end
    GSE.DebugOutput = ""
end

function GSE.GUIDebugAppendLine(text)
    if not (GSE.GUIDebugFrame and GSE.GUIDebugFrame.DebugOutputTextbox) then return end
    AddDebugRow({message = tostring(text or "")})
end

function GSE.GUIDebugAppendEvent(values, legacyLine)
    if not (GSE.GUIDebugFrame and GSE.GUIDebugFrame.DebugOutputTextbox) then return end
    if GSE.GUIDebugPaused then return end
    AddDebugRow({values = values, legacyLine = legacyLine})
end

function GSE.GUIStopDebugTimer()
    if GSE.GUIUpdateTimer then
        GSE.GUIUpdateTimer:Cancel()
        GSE.GUIUpdateTimer = nil
    end
    if GSE.GUIDebugLogStartedAt then
        GSE.GUIDebugLogElapsed = (tonumber(GSE.GUIDebugLogElapsed) or 0) + ((GetTime and GetTime() or 0) - GSE.GUIDebugLogStartedAt)
        GSE.GUIDebugLogStartedAt = nil
    end
end

function GSE.GUIStartDebugTimer()
    GSE.GUIStopDebugTimer()
    GSE.GUIDebugLogStartedAt = GetTime and GetTime() or 0
    GSE.GUIUpdateTimer = C_Timer.NewTicker(1, function()
        if RefreshStatsWidget then RefreshStatsWidget() end
    end)
end

function GSE.GUIResetDebugTimer()
    GSE.GUIDebugLogElapsed = 0
    if GSE.UnsavedOptions and GSE.UnsavedOptions["DebugSequenceExecution"] and not GSE.GUIDebugPaused then
        GSE.GUIDebugLogStartedAt = GetTime and GetTime() or 0
    else
        GSE.GUIDebugLogStartedAt = nil
    end
    if DebugFrame.UpdateStatsFooter then DebugFrame:UpdateStatsFooter() end
    if RefreshStatsWidget then RefreshStatsWidget() end
end

function GSE.GUIEnableDebugView()
    if GSE.UnsavedOptions["DebugSequenceExecution"] then
        GSE.UnsavedOptions["DebugSequenceExecution"] = false
        GSE.GUIDebugPaused = false
        GSE.GUIDebugFrame.DebugEnableViewButton:SetText(DebuggerLabel("Enable"))
        GSE.GUIDebugFrame.DebugPauseViewButton:SetText(DebuggerLabel("Pause"))
        GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(true)
        GSE.GUIStopDebugTimer()
        onpause = false
        GSE.GUIDebugAppendLine("Debugger disabled.")
    else
        GSE.UnsavedOptions["DebugSequenceExecution"] = true
        GSE.GUIDebugPaused = false
        GSE.GUIDebugLogElapsed = 0
        GSE.GUIDebugLogStartedAt = nil
        GSE.GUIDebugFrame.DebugEnableViewButton:SetText(DebuggerLabel("Disable"))
        GSE.GUIDebugFrame.DebugPauseViewButton:SetDisabled(false)
        GSE.GUIStartDebugTimer()
        GSE.GUIDebugAppendLine("Debugger enabled. Waiting for GSE sequence events.")
        GSE.GUIUpdateOutput()
        onpause = false
    end
end

function GSE.GUIPauseDebugView()
    if onpause then
        GSE.GUIDebugFrame.DebugPauseViewButton:SetText(DebuggerLabel("Pause"))
        GSE.GUIDebugPaused = false
        GSE.GUIStartDebugTimer()
        GSE.GUIUpdateOutput()
        onpause = false
        GSE.GUIDebugAppendLine("Debugger resumed.")
    else
        GSE.GUIDebugFrame.DebugPauseViewButton:SetText(DebuggerLabel("Resume"))
        GSE.GUIStopDebugTimer()
        GSE.GUIDebugPaused = true
        onpause = true
        GSE.GUIDebugAppendLine("Debugger paused.")
    end
end

function GSE.GUIShowDebugExportWindow(text, titleText, labelText, statusText)
    local UI = GSE.UI
    if not UI then
        local output = GSE.GUIDebugFrame and GSE.GUIDebugFrame.DebugOutputTextbox
        local box = output and output.editBox
        if box then
            box:SetFocus()
            box:HighlightText()
        end
        return
    end

    if not debugExportFrame then
        debugExportFrame = UI:Create("Frame")
        debugExportFrame:SetSize(900, 600)
        debugExportFrame:Hide()
        debugExportFrame.frame:SetFrameStrata(currentDebuggerStrata)
        debugExportFrame.frame:SetClampedToScreen(true)
        debugExportFrame.frame:ClearAllPoints()
        debugExportFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        debugExportFrame:SetCallback(
            "OnClose",
            function()
                debugExportFrame:Hide()
            end
        )
        debugExportFrame:SetLayout("List")

        debugExportBox = UI:Create("MultiLineEditBox")
        debugExportBox:SetNumLines(30)
        debugExportBox:DisableButton(true)
        debugExportBox:SetFullWidth(true)
        debugExportFrame:AddChild(debugExportBox)

        debugExportFrame.copyButton = CreateFrame("Button", nil, debugExportFrame.frame, "UIPanelButtonTemplate")
        debugExportFrame.copyButton:SetSize(90, DEBUG_UI.BUTTON_HEIGHT)
        debugExportFrame.copyButton:SetPoint("BOTTOMRIGHT", debugExportFrame.frame, "BOTTOMRIGHT", -24, 8)
        debugExportFrame.copyButton:SetText("Copy")
        GSE.StyleDebugTextButton(debugExportFrame.copyButton)
        debugExportFrame.copyButton:SetScript(
            "OnClick",
            function()
                local edit = debugExportBox and (debugExportBox.editBox or debugExportBox.editbox)
                if edit then
                    edit:SetFocus()
                    edit:HighlightText()
                end
                if debugExportFrame and debugExportFrame.SetStatusText then
                    debugExportFrame:SetStatusText("Debugger output selected. Press Ctrl+C to copy.")
                end
            end
        )
    end

    debugExportFrame:SetTitle(titleText or "GSE: Debugger Export")
    debugExportFrame:SetStatusText(statusText or "Debugger output selected. Press Ctrl+C to copy.")
    debugExportBox:SetLabel(labelText or "Debugger Output")
    debugExportFrame:SetSize(900, 600)
    debugExportFrame.frame:ClearAllPoints()
    debugExportFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    debugExportBox:SetText(text or "")
    debugExportFrame:Show()
    if debugExportFrame.copyButton then debugExportFrame.copyButton:Show() end
    if debugExportFrame.frame.Raise then debugExportFrame.frame:Raise() end
    local function FocusExportText()
        local edit = debugExportBox and (debugExportBox.editBox or debugExportBox.editbox)
        if edit then
            edit:SetFocus()
            edit:HighlightText()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, FocusExportText)
    else
        FocusExportText()
    end
end

DebugFrame.DebugEnableViewButton:SetScript("OnClick", GSE.GUIEnableDebugView)
DebugFrame.DebugPauseViewButton:SetScript("OnClick", GSE.GUIPauseDebugView)
DebugFrame.DebugClearViewButton:SetScript("OnClick", function()
    GSE.GUIDebugFrame.DebugOutputTextbox:SetText("")
    GSE.DebugOutput = ""
    if GSE.GUIResetDebugTimer then GSE.GUIResetDebugTimer() end
    if DebugFrame.ResetHardwareEventsState then DebugFrame:ResetHardwareEventsState() end
    GSE.GUIDebugAppendLine("Debugger output cleared.")
end)
DebugFrame.DebugExportOutputButton:SetScript("OnClick", function()
    if type(GSE.GUIUpdateOutput) == "function" then GSE.GUIUpdateOutput() end
    local text = DebugFrame.DebugRowsToLegacyExport()
    if GSE.isEmpty(text) then text = "No debugger output to export." end
    GSE.GUIShowDebugExportWindow(
        text,
        "GSE: Debugger Export",
        "Old Debugger Output",
        "Excel-ready debugger output selected. Press Ctrl+C to copy."
    )
    GSE.GUIDebugAppendLine("Debugger export opened.")
    SetDebuggerStatusText()
end)
DebugFrame.DebugStatsViewButton:SetScript("OnClick", function()
    local isOpen = GSE.GUIToggleDebugStatsWidget and GSE.GUIToggleDebugStatsWidget()
    if isOpen then
        GSE.GUIDebugAppendLine("Debugger statistics widget opened.")
    else
        GSE.GUIDebugAppendLine("Debugger statistics widget closed.")
    end
    SetDebuggerStatusText()
end)
DebugFrame.DebugHardwareViewButton:SetScript("OnClick", function()
    local isOpen = GSE.GUIToggleDebugHardwareWidget and GSE.GUIToggleDebugHardwareWidget()
    if isOpen then
        GSE.GUIDebugAppendLine("Hardware events widget opened.")
    else
        GSE.GUIDebugAppendLine("Hardware events widget closed.")
    end
    SetDebuggerStatusText()
end)
DebugFrame.DebugOptionsViewButton:SetScript("OnClick", function()
    if GSE.OpenOptionsPanel then GSE.OpenOptionsPanel() end
    GSE.GUIDebugAppendLine("Debugger options opened.")
end)
DebugFrame.DebugReloadViewButton:SetScript("OnClick", function()
    GSE.GUIDebugAppendLine("Reload requested from debugger.")
    if ReloadUI then ReloadUI() end
end)
DebugFrame.DebugResourcesViewButton:SetScript("OnClick", function()
    if GSE.GUI and GSE.GUI.ShowResourcesPopup then GSE.GUI.ShowResourcesPopup(DebugFrame) end
    GSE.GUIDebugAppendLine("GSE resources opened.")
end)

DebugFrame.DebugTrackerViewButton:SetScript("OnClick", function()
    -- Toggle the same GSEOptions.SequenceIconFrame.Enabled flag the Options
    -- panel "Tracker On / Off" checkbox uses, via the same GSE.SetSequenceIconFrameEnabled
    -- setter, so the two controls mirror each other.
    GSEOptions.SequenceIconFrame = GSEOptions.SequenceIconFrame or {}
    local enabled = not GSEOptions.SequenceIconFrame.Enabled
    GSEOptions.SequenceIconFrame.Enabled = enabled
    if GSE.SetSequenceIconFrameEnabled then
        GSE.SetSequenceIconFrameEnabled(enabled)
    end
    GSE.SetDebuggerButtonText(DebugFrame.DebugTrackerViewButton, enabled and "Tracker: On" or "Tracker: Off")
    GSE.GUIDebugAppendLine(enabled and "GSE Tracker enabled." or "GSE Tracker disabled.")
end)

if GSE.UnsavedOptions["DebugSequenceExecution"] then
    DebugFrame.DebugEnableViewButton:SetText(DebuggerLabel("Disable"))
    DebugFrame.DebugPauseViewButton:SetDisabled(false)
    GSE.GUIStartDebugTimer()
else
    DebugFrame.DebugEnableViewButton:SetText(DebuggerLabel("Enable"))
    DebugFrame.DebugPauseViewButton:SetDisabled(true)
end

DebugFrame:SetScript("OnSizeChanged", function(self, width, height)
    local clampedWidth = ClampNumber(width, DEBUG_UI.MIN_DEBUGGER_WIDTH, GetMaxDebuggerWidth(), DEBUG_UI.MIN_DEBUGGER_WIDTH)
    local clampedHeight = ClampNumber(height, DEBUG_UI.MIN_DEBUGGER_HEIGHT, GetMaxDebuggerHeight(), DEBUG_UI.MIN_DEBUGGER_HEIGHT)
    if clampedWidth ~= width or clampedHeight ~= height then
        self:SetSize(clampedWidth, clampedHeight)
        return
    end
    self.Width = clampedWidth
    self.Height = clampedHeight
    GSEOptions.debugWidth = clampedWidth
    GSEOptions.debugHeight = clampedHeight
    DebugFrame.UpdateDebuggerLayout()
end)

DebugFrame:SetScript("OnHide", function(self)
    self:SaveDebuggerLocation()
end)

local function RefreshDebuggerTitleChrome()
    PositionDebuggerTitleText()
    if C_Timer and C_Timer.After then
        C_Timer.After(
            0,
            function()
                if DebugFrame:IsShown() then PositionDebuggerTitleText() end
            end
        )
        C_Timer.After(
            0.1,
            function()
                if DebugFrame:IsShown() then PositionDebuggerTitleText() end
            end
        )
    end
end

function GSE.GUIShowDebugWindow()
    if DebugFrame.minimizedWidget and DebugFrame.minimizedWidget:IsShown() and DebugFrame.ExpandFromMinimizedWidget then
        DebugFrame:ExpandFromMinimizedWidget()
        return
    end
    if DebugFrame:GetNumPoints() == 0 then
        DebugFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    SetDebuggerOpenPreference(true)
    SetDebuggerStatusText()
    DebugFrame.UpdateDebuggerLayout()
    UpdateStatsCombatTimer()
    DebugFrame:Show()
    if DebugFrame.Raise then DebugFrame:Raise() end
    RefreshDebuggerTitleChrome()
end

DebugFrame:HookScript("OnShow", function(self)
    if self.minimizedWidget then self.minimizedWidget:Hide() end
    RefreshDebuggerTitleChrome()
end)

DebugFrame:Hide()
DebugFrame.UpdateDebuggerLayout()
if GSE.RegisterUIScaleFrame then GSE.RegisterDebugUIScaleFrame(DebugFrame) end
if debugLocation.open then
    if C_Timer and C_Timer.After then
        C_Timer.After(
            0,
            function()
                if GSE.GUIShowDebugWindow then GSE.GUIShowDebugWindow() end
            end
        )
    else
        if GSE.GUIShowDebugWindow then GSE.GUIShowDebugWindow() end
    end
end
if statsLocation.open then
    if C_Timer and C_Timer.After then
        C_Timer.After(
            0,
            function()
                if GSE.GUIShowDebugStatsWidget then GSE.GUIShowDebugStatsWidget() end
            end
        )
    else
        if GSE.GUIShowDebugStatsWidget then GSE.GUIShowDebugStatsWidget() end
    end
end
if EnsureHardwareWidgetLocation().open then
    if C_Timer and C_Timer.After then
        C_Timer.After(
            0,
            function()
                if GSE.GUIShowDebugHardwareWidget then GSE.GUIShowDebugHardwareWidget() end
            end
        )
    else
        if GSE.GUIShowDebugHardwareWidget then GSE.GUIShowDebugHardwareWidget() end
    end
end
end
table.insert(ns.deferred, setup)
