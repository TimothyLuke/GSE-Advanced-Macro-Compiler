local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE

GSE.UI = GSE.UI or {}

local UI = GSE.UI
local L = GSE.L
local origToggle = nil
local widgetId = 0
local layoutSuspended = 0
local layoutResumeScheduled = false
local frameTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil


UI.ButtonAlignment = UI.ButtonAlignment or {
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT"
}

local STYLE = {
    padTiny = 1,
    padXXS = 2,
    padInset = 3,
    padSmall = 5,
    pad = 6,
    padLarge = 10,
    padXL = 10,
    padXXL = 12,
    controlHeight = 24,
    compactControlHeight = 22,
    defaultIconSize = 24,
    checkBoxSize = 26,
    closeButtonOffsetX = 2,
    closeButtonOffsetY = 3,
    labelHeight = 12,
    labelControlOffset = 14,
    labelBoxGap = 2,
    titleInsetX = 24,
    titleHeight = 20,
    frameEdge = 5,
    frameBodyInset = 5,
    frameContentX = 12,
    frameContentTop = 28,
    frameContentBottom = 28,
    listPadX = 5,
    listPadTop = 5,
    listPadBottom = 5,
    listGap = 6,
    flowPadX = 6,
    flowPadY = 5,
    flowGap = 10,
    flowRowGap = 6,
    scrollBarReserve = 24,
    scrollBarWidth = 16,
    scrollBarVisibleReserve = 18,
    scrollArrowInset = 18,
    panelTabWidth = 120,
    tabBarHeight = 28,
    tabContentOffset = 32,
    tabSideWidth = 20,
    tabTextLeft = 14,
    dropdownListRowHeight = 18,
    dropdownListInset = 5,
    dropdownListScrollInset = 10,
    dropdownListScrollReserve = 20,
    dropdownCheckSize = 14,
    dropdownTextLeft = 28,
    dropdownArrowSize = 22,
    keyBindButtonReserve = 20,
    treeContentPad = 10,
    treeContentPadX = 3,
    treeContentPadY = 10,
    treeContentPadTop = 5,
    treeRowPadTop = 5,
    treeContentPadBottom = 2,
    treeScrollReserve = 22,
    treeScrollInsetX = 10,
    treeScrollInsetY = 26,
    treeIndentBase = 10,
    treeIndentStep = 12,
    treeToggleGap = 2,
    treeIconGap = 5,
    treeDraggerWidth = 8,
    buttonRowAlignment = UI.ButtonAlignment.CENTER,
    buttonRowGap = 6,
    buttonRowVerticalGap = 5,
    modernScrollBarWidth = 10,
    modernScrollBarTrackWidth = 2,
    modernScrollBarThumbWidth = 5
}

UI.NativeStyle = STYLE
local DEFAULT_TREE_WIDTH = 175
local MIN_TREE_WIDTH = 165
local MAX_TREE_WIDTH = 500
local MIN_TREE_CONTENT_WIDTH = 620
local DEFAULT_TREE_RESIZABLE = true
local TREE_ROW_HEIGHT = 20
local TREE_ROW_ICON_SIZE = 14
local TREE_ROW_TOGGLE_SIZE = 18
local TREE_ROW_EXPAND_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\expand.png"
local TREE_ROW_COLLAPSE_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\collapse.png"
local SCROLL_STEP_DEFAULT = 280   -- pixels per wheel notch (was 140 - doubled per user request)
local SCROLL_STEP = SCROLL_STEP_DEFAULT  -- mutable runtime value; updated via GSE.GUI.SetScrollStep from Options
local SCROLL_SMOOTH_DURATION = 0.08  -- smooth animation length (was 0.12 - kept smooth but more responsive)

-- Public live setters/getters for the scroll-speed slider in the Options panel.
-- The Options module calls SetScrollStep on every slider change and on addon
-- load (from EnsureSequenceEditorOptions); MoveScroll reads SCROLL_STEP each
-- wheel notch, so updates take effect immediately without reopening the editor.
if not GSE then GSE = {} end
if not GSE.GUI then GSE.GUI = {} end
GSE.GUI.SetScrollStep = function(value)
    local v = tonumber(value)
    if not v then return end
    if v < 50 then v = 50 end
    if v > 800 then v = 800 end
    SCROLL_STEP = v
end
GSE.GUI.GetScrollStep = function() return SCROLL_STEP end
GSE.GUI.GetScrollStepDefault = function() return SCROLL_STEP_DEFAULT end

-- Menu logo resolver. Currently returns a single unified texture for both
-- Native and Modern skins (per user spec). The function is kept (rather than
-- inlining the constant) so callers don't have to change if we ever go back
-- to skin-specific variants. RefreshMenuLogo can still be called to repaint
-- after skin changes — it's just a no-op in terms of changing the asset.
local MENU_LOGO_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\GSE-Menu.png"
GSE.GUI.GetMenuLogoTexture = function()
    return MENU_LOGO_TEXTURE
end

-- Ruler FontString: measures unconstrained natural text width.
-- Parented to UIParent so it works regardless of navWindow visibility.
local treeTextRuler
local function getTreeTextWidth(fontString)
    if not fontString then return 0 end
    if not treeTextRuler then
        treeTextRuler = UIParent:CreateFontString(nil, "ARTWORK")
        treeTextRuler:Hide()
    end
    treeTextRuler:SetFontObject(fontString:GetFontObject() or "GameFontHighlight")
    treeTextRuler:SetText(fontString:GetText() or "")
    return treeTextRuler:GetStringWidth()
end
local WINDOW_SCREEN_BUFFER = 0
local WINDOW_LEFT_VISUAL_ALLOWANCE = 0

local function normalizeButtonAlignment(align)
    align = align and tostring(align):upper() or STYLE.buttonRowAlignment
    if align == UI.ButtonAlignment.LEFT or align == UI.ButtonAlignment.RIGHT then return align end
    return UI.ButtonAlignment.CENTER
end
local CLOSE_BUTTON_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\close.png"
local CLOSE_BUTTON_WIDTH = 32
local CLOSE_BUTTON_HEIGHT = 30
local ASSET_HIGHLIGHT_ALPHA = 0.35
local ELVUI_TEXT_BUTTON_HOVER_SCALE = 1.12
local activeTreeDrag
local activeDropdownList

local function nextName(prefix)
    widgetId = widgetId + 1
    return ("GSEUI%s%d"):format(prefix, widgetId)
end

local function textValue(value)
    if value == nil or type(value) == "boolean" then return "" end
    return tostring(value)
end

local GSE_WINDOW_TITLE_PREFIX = "|cFFFFFFFFGS|r|cFF00FFFFE|r"

local function formatWindowTitle(text)
    local title = textValue(text):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then return GSE_WINDOW_TITLE_PREFIX end

    if title:sub(1, #GSE_WINDOW_TITLE_PREFIX) == GSE_WINDOW_TITLE_PREFIX then
        title = title:sub(#GSE_WINDOW_TITLE_PREFIX + 1)
        title = title:gsub("^%s*:%s*", ""):gsub("^%s*%-%s*", "")
    end
    title = title:gsub("^GSE%s*:%s*", ""):gsub("^GSE%s*%-%s*", "")

    if title == "" then return GSE_WINDOW_TITLE_PREFIX end
    return GSE_WINDOW_TITLE_PREFIX .. ": " .. title
end

UI.FormatWindowTitle = formatWindowTitle

local function prepareNativeTitleBar(frame, minimumFrameLevel)
    if not frame then return nil end

    local titleBar = frame.TitleContainer or frame
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.padTiny)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.padTiny)
        frame.TitleContainer:SetHeight(STYLE.titleHeight)
        frame.TitleContainer:Show()
    end

    if titleBar ~= frame then
        if titleBar.SetFrameStrata and frame.GetFrameStrata then titleBar:SetFrameStrata(frame:GetFrameStrata()) end
        if titleBar.SetFrameLevel then
            local titleLevel = titleBar.GetFrameLevel and titleBar:GetFrameLevel()
            local frameLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 0
            local targetLevel = titleLevel or frameLevel
            if minimumFrameLevel then targetLevel = math.max(targetLevel, minimumFrameLevel - 2) end
            titleBar:SetFrameLevel(targetLevel)
        end
    end

    return titleBar
end

function UI.ApplyNativeWindowTitleText(frame, text, minimumFrameLevel)
    if not frame then return nil end

    local titleBar = prepareNativeTitleBar(frame, minimumFrameLevel)
    if frame.TitleText then
        if frame.GSENativeTitleOverlay then frame.GSENativeTitleOverlay:Hide() end

        local title = frame.TitleText
        title:ClearAllPoints()
        if title.SetParent and titleBar ~= frame then title:SetParent(titleBar) end
        if titleBar ~= frame then
            title:SetPoint("LEFT", titleBar, "LEFT", 0, STYLE.padTiny)
            title:SetPoint("RIGHT", titleBar, "RIGHT", 0, STYLE.padTiny)
        else
            title:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.frameEdge)
            title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.frameEdge)
        end
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
        if title.SetFontObject then title:SetFontObject(GameFontNormal) end
        if title.SetDrawLayer then title:SetDrawLayer("OVERLAY", 7) end
        if title.SetAlpha then title:SetAlpha(1) end
        title:SetText(formatWindowTitle(text))
        title:Show()

        return title
    end

    return nil
end

function UI.ApplyNativeWindowTitleContainerText(frame, text, minimumFrameLevel)
    if not frame then return nil end

    local titleBar = prepareNativeTitleBar(frame, minimumFrameLevel)
    if frame.GSENativeTitleOverlay then frame.GSENativeTitleOverlay:Hide() end
    if frame.TitleText then
        frame.TitleText:SetText("")
        frame.TitleText:Hide()
    end

    if not frame.GSENativeTitleContainerText then
        frame.GSENativeTitleContainerText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end

    local title = frame.GSENativeTitleContainerText
    if title.SetParent and title.GetParent and titleBar ~= title:GetParent() then title:SetParent(titleBar) end
    title:ClearAllPoints()
    if titleBar ~= frame then
        title:SetPoint("LEFT", titleBar, "LEFT", 0, STYLE.padTiny)
        title:SetPoint("RIGHT", titleBar, "RIGHT", 0, STYLE.padTiny)
    else
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.frameEdge)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.frameEdge)
    end
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    if title.SetFontObject then title:SetFontObject(GameFontNormal) end
    if title.SetDrawLayer then title:SetDrawLayer("OVERLAY", 7) end
    if title.SetAlpha then title:SetAlpha(1) end
    title:SetText(formatWindowTitle(text))
    title:Show()

    return title
end

function UI.ApplyNativeWindowTitle(frame, text, minimumFrameLevel)
    if not frame then return nil end

    local nativeTitle = UI.ApplyNativeWindowTitleText(frame, text, minimumFrameLevel)
    if nativeTitle then return nativeTitle end

    local titleBar = prepareNativeTitleBar(frame, minimumFrameLevel)
    if not frame.GSENativeTitleOverlay then
        frame.GSENativeTitleOverlay = CreateFrame("Frame", nil, frame)
        frame.GSENativeTitleOverlay:EnableMouse(false)
        frame.GSENativeTitleText = frame.GSENativeTitleOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end

    local overlay = frame.GSENativeTitleOverlay
    local title = frame.GSENativeTitleText

    overlay:ClearAllPoints()
    if overlay.SetFrameStrata and frame.GetFrameStrata then overlay:SetFrameStrata(frame:GetFrameStrata()) end
    if overlay.SetFrameLevel then
        local titleLevel = titleBar and titleBar.GetFrameLevel and titleBar:GetFrameLevel()
        local frameLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 0
        local overlayLevel = (titleLevel or frameLevel) + 2
        if minimumFrameLevel then overlayLevel = math.max(overlayLevel, minimumFrameLevel) end
        overlay:SetFrameLevel(overlayLevel)
    end

    if titleBar ~= frame then
        overlay:SetAllPoints(titleBar)
    else
        overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.frameEdge)
        overlay:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.frameEdge)
        overlay:SetHeight(STYLE.titleHeight)
    end
    overlay:Show()
    if overlay.Raise then overlay:Raise() end

    if title.SetParent then title:SetParent(overlay) end
    title:ClearAllPoints()
    title:SetPoint("LEFT", overlay, "LEFT", 0, STYLE.padTiny)
    title:SetPoint("RIGHT", overlay, "RIGHT", 0, STYLE.padTiny)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    if title.SetFontObject then title:SetFontObject(GameFontNormal) end
    if title.SetDrawLayer then title:SetDrawLayer("OVERLAY", 7) end
    title:SetText(formatWindowTitle(text))
    title:Show()

    return title
end

local function styleCloseButton(button, parent)
    if not button then return end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", STYLE.closeButtonOffsetX, STYLE.closeButtonOffsetY)
    button:SetSize(CLOSE_BUTTON_WIDTH, CLOSE_BUTTON_HEIGHT)
    button:SetNormalTexture(CLOSE_BUTTON_TEXTURE)
    button:SetPushedTexture(CLOSE_BUTTON_TEXTURE)
    button:SetHighlightTexture(CLOSE_BUTTON_TEXTURE, "ADD")
    if button.GetHighlightTexture and button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAlpha(ASSET_HIGHLIGHT_ALPHA)
    end
end

local function applyAssetHighlight(button, texturePath)
    if not button then return end

    if not texturePath then
        if button.gseAssetHighlight then button.gseAssetHighlight:Hide() end
        return
    end

    if not button.gseAssetHighlight then
        button.gseAssetHighlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.gseAssetHighlight:SetAllPoints(button)
        button.gseAssetHighlight:SetBlendMode("ADD")
        button:SetHighlightTexture(button.gseAssetHighlight)
    end

    button.gseAssetHighlight:SetTexture(texturePath)
    button.gseAssetHighlight:SetAlpha(ASSET_HIGHLIGHT_ALPHA)
    button.gseAssetHighlight:Show()
end

local function safeWidth(frame, fallback)
    local width = frame and frame.GetWidth and frame:GetWidth()
    if not width or width <= 0 then return fallback or 0 end
    return width
end

local function safeHeight(frame, fallback)
    local height = frame and frame.GetHeight and frame:GetHeight()
    if not height or height <= 0 then return fallback or 0 end
    return height
end

local function applyFrameScreenBuffer(frame)
    if not frame then return end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    if frame.SetClampRectInsets then
        frame:SetClampRectInsets(
            WINDOW_LEFT_VISUAL_ALLOWANCE - WINDOW_SCREEN_BUFFER,
            WINDOW_SCREEN_BUFFER,
            WINDOW_SCREEN_BUFFER,
            -WINDOW_SCREEN_BUFFER
        )
    end
end

local function bringFrameToFront(frame)
    if frame and frame.Raise then frame:Raise() end
end

local function applyBackdrop(frame, backdrop, bg, border)
    if not (frame and frame.SetBackdrop) then return end
    frame:SetBackdrop(backdrop)
    if bg and frame.SetBackdropColor then frame:SetBackdropColor(unpack(bg)) end
    if border and frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(unpack(border)) end
end

local ELVUI_SKIN = {
    backdrop = {bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1},
    panelBg = {0.045, 0.045, 0.045, 0.74},
    insetBg = {0.025, 0.025, 0.025, 0.86},
    titleBg = {0.045, 0.045, 0.045, 0.74},
    buttonBg = {0.065, 0.065, 0.065, 0.92},
    buttonSelectedBg = {0.08, 0.08, 0.08, 0.92},
    border = {0.18, 0.18, 0.18, 1},
    mutedBorder = {0.10, 0.10, 0.10, 1},
    text = {0.92, 0.92, 0.92, 1},
    accentText = {0.00, 0.92, 0.92, 1},
    fieldLabelText = {1.00, 0.82, 0.00, 1}
}

local GSE_MODERN_CLASS_COLORS = {
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
}
-- Returns true when an external skin provider (ElvUI / EllesmereUI) is
-- driving the look. Both `shouldUseElvUISkin` (gates the apply*ElvUI*
-- helpers) AND `getNormalAccentColor` (gates the apply*NormalAccent*
-- helpers) check this; the modern theme has two colour modes (ElvUI-style
-- and normal-accent), so we have to step aside from both, not just one.
local function hasExternalSkinProvider()
    if GSE.Skin and GSE.Skin.providerName then
        local provider = GSE.Skin.providerName
        if provider == "ElvUI" or provider == "EllesmereUI" then return true end
    end
    return false
end

local function shouldUseElvUISkin()
    if hasExternalSkinProvider() then return false end
    if GSE.ShouldUseModernSkin then
        return GSE.ShouldUseModernSkin()
    end
    return GSE.ShouldUseElvUISkin and GSE.ShouldUseElvUISkin()
end

local function getModernClassColor(alpha)
    if GSE.ShouldUseModernCustomColor and GSE.ShouldUseModernCustomColor() and GSE.GetModernCustomColor then
        return GSE.GetModernCustomColor(alpha)
    end

    if not (GSE.ShouldUseModernClassColors and GSE.ShouldUseModernClassColors()) then
        return nil
    end

    local classFile
    if UnitClass then
        local localizedClass
        localizedClass, classFile = UnitClass("player")
        classFile = classFile or localizedClass
    end

    if type(classFile) == "string" then
        classFile = classFile:upper():gsub("%s+", "")
    end

    local color = classFile and GSE_MODERN_CLASS_COLORS[classFile]
    if not color then
        return nil
    end

    return { color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, alpha or color.a or color[4] or 1 }
end

local function getNormalAccentColor(alpha)
    if hasExternalSkinProvider() then return nil end
    if shouldUseElvUISkin() then return nil end
    return getModernClassColor(alpha or 1)
end

local function getElvUITextColor()
    return getModernClassColor(1) or ELVUI_SKIN.text
end

local function getElvUIBorderColor(fallback)
    return fallback or ELVUI_SKIN.border
end

local function getElvUITintedColor(base, amount)
    if not base then
        return base
    end

    local classColor = getModernClassColor(base[4] or 1)
    if not classColor then
        return base
    end

    amount = amount or 0.06
    return {
        (base[1] or 0) * (1 - amount) + (classColor[1] or 1) * amount,
        (base[2] or 0) * (1 - amount) + (classColor[2] or 1) * amount,
        (base[3] or 0) * (1 - amount) + (classColor[3] or 1) * amount,
        base[4] or classColor[4] or 1
    }
end

local function colorTexture(texture, color)
    if texture and texture.SetColorTexture and color then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

local function applyElvUIBackdrop(frame, bg, border, useClassTint)
    local resolvedBg = bg or ELVUI_SKIN.panelBg
    if useClassTint ~= false then
        resolvedBg = getElvUITintedColor(resolvedBg)
    end
    applyBackdrop(frame, ELVUI_SKIN.backdrop, resolvedBg, border or ELVUI_SKIN.border)
end

local function hideFrameTextures(frame)
    if not frame then return end
    if frame.NineSlice and frame.NineSlice.Hide then frame.NineSlice:Hide() end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.SetAlpha then
                region:SetAlpha(0)
            end
        end
    end
end

local function getNamedChild(frame, suffix)
    local name = frame and frame.GetName and frame:GetName()
    return name and _G[name .. suffix] or nil
end

local function getScrollBarThumb(scrollbar)
    return scrollbar and (
        (scrollbar.GetThumbTexture and scrollbar:GetThumbTexture()) or
        scrollbar.ThumbTexture or
        getNamedChild(scrollbar, "ThumbTexture")
    )
end

local function colorScrollBarTexture(texture, color)
    if not (texture and color) then return end
    if texture.SetColorTexture then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    elseif texture.SetTexture then
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        if texture.SetVertexColor then texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    end
    if texture.SetAlpha then texture:SetAlpha(color[4] or 1) end
    if texture.Show then texture:Show() end
end

local function suppressModernScrollBarButton(button)
    if not button then return end
    if button.Disable then button:Disable() end
    if button.EnableMouse then button:EnableMouse(false) end
    if button.SetAlpha then button:SetAlpha(0) end
    if button.SetWidth then button:SetWidth(1) end
    if button.SetHeight then button:SetHeight(1) end
    if button.Hide then button:Hide() end
end

local function anchorModernSlimScrollBar(scrollbar, anchorFrame, rightOffset, topInset, bottomInset)
    if not (scrollbar and anchorFrame and scrollbar.ClearAllPoints and scrollbar.SetPoint) then return end

    -- Reparent to the anchor frame. UIPanelScrollFrameTemplate creates
    -- scrollFrame.ScrollBar as a CHILD of scrollFrame. createScrollFrame
    -- calls scrollFrame:SetClipsChildren(true), which clips child rendering
    -- to scrollFrame's rectangle. Since the slim scrollbar is anchored
    -- outside scrollFrame's right edge (in the scrollBarReserve gap), it
    -- gets clipped to nothing and renders invisible. Reparenting to the
    -- anchor frame (the outer wrapper) takes the scrollbar out of the
    -- clip region. Inner text-box scrollFrames don't SetClipsChildren so
    -- this is a no-op there.
    if scrollbar.SetParent and scrollbar.GetParent and scrollbar:GetParent() ~= anchorFrame then
        scrollbar:SetParent(anchorFrame)
    end
    scrollbar:ClearAllPoints()
    scrollbar:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", rightOffset or 0, -(topInset or 0))
    scrollbar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", rightOffset or 0, bottomInset or 0)
end

local function setModernSlimScrollBarState(scrollbar, state)
    if not scrollbar then return end
    if not (shouldUseElvUISkin() or hasExternalSkinProvider()) then return end

    local thumb = scrollbar.GSEModernScrollBarThumb or getScrollBarThumb(scrollbar)

    -- Pull the thumb accent from EllesmereUI.ELLESMERE_GREEN (the user's
    -- chosen accent) when EUI is driving the look; fall back to the modern
    -- skin's class colour otherwise. Without this branch the scrollbars
    -- showed up blue against EUI's accent green / class teal.
    local function euiAccent(alpha)
        local EUI = _G.EllesmereUI
        if type(EUI) == "table" and type(EUI.ELLESMERE_GREEN) == "table" then
            local c = EUI.ELLESMERE_GREEN
            return {c.r or 0, c.g or 0.55, c.b or 0.55, alpha}
        end
        return nil
    end

    local thumbColor = (hasExternalSkinProvider() and euiAccent(0.86))
        or getModernClassColor(0.86) or {0.00, 0.55, 0.90, 0.86}
    local trackColor = {0.36, 0.38, 0.40, 0.68}
    if state == "hover" then
        thumbColor = (hasExternalSkinProvider() and euiAccent(0.98))
            or getModernClassColor(0.98) or {0.00, 0.62, 1.00, 0.98}
        trackColor = {0.44, 0.46, 0.48, 0.80}
    elseif state == "active" then
        thumbColor = (hasExternalSkinProvider() and euiAccent(1))
            or getModernClassColor(1) or {0.00, 0.68, 1.00, 1}
        trackColor = {0.50, 0.52, 0.54, 0.88}
    end

    colorScrollBarTexture(scrollbar.GSEModernScrollBarTrack, trackColor)
    colorScrollBarTexture(thumb, thumbColor)
end

local function applyModernSlimScrollBar(scrollbar, anchorFrame, rightOffset, topInset, bottomInset)
    -- Apply the slim scrollbar look under the modern skin OR an external
    -- skin provider — both want minimal scrollbar chrome over Blizzard's
    -- gold textured default. Without this, EUI sessions left scrollbars
    -- either invisible (regions alpha-stripped elsewhere) or in Blizzard
    -- gold which clashed with the dark editor.
    if not scrollbar then return end
    if not (shouldUseElvUISkin() or hasExternalSkinProvider()) then return end

    suppressModernScrollBarButton(scrollbar.ScrollUpButton or getNamedChild(scrollbar, "ScrollUpButton"))
    suppressModernScrollBarButton(scrollbar.ScrollDownButton or getNamedChild(scrollbar, "ScrollDownButton"))
    anchorModernSlimScrollBar(scrollbar, anchorFrame, rightOffset, topInset, bottomInset)

    if scrollbar.SetWidth then scrollbar:SetWidth(STYLE.modernScrollBarWidth) end
    if scrollbar.SetThumbTexture then pcall(scrollbar.SetThumbTexture, scrollbar, "Interface\\Buttons\\WHITE8X8") end

    local thumb = getScrollBarThumb(scrollbar)
    scrollbar.GSEModernScrollBarThumb = thumb
    if thumb then
        if thumb.SetTexture then thumb:SetTexture("Interface\\Buttons\\WHITE8X8") end
        if thumb.SetTexCoord then thumb:SetTexCoord(0, 1, 0, 1) end
        if thumb.SetWidth then thumb:SetWidth(STYLE.modernScrollBarThumbWidth) end
        if thumb.SetHeight then thumb:SetHeight(24) end
        if thumb.SetAlpha then thumb:SetAlpha(1) end
    end

    if scrollbar.GetRegions then
        for _, region in ipairs({scrollbar:GetRegions()}) do
            if region ~= thumb and region.SetAlpha then region:SetAlpha(0) end
        end
    end

    if not scrollbar.GSEModernScrollBarTrack and scrollbar.CreateTexture then
        scrollbar.GSEModernScrollBarTrack = scrollbar:CreateTexture(nil, "BACKGROUND")
        scrollbar.GSEModernScrollBarTrack:SetPoint("TOP", scrollbar, "TOP", 0, 0)
        scrollbar.GSEModernScrollBarTrack:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 0)
    end
    if scrollbar.GSEModernScrollBarTrack then
        scrollbar.GSEModernScrollBarTrack:SetWidth(STYLE.modernScrollBarTrackWidth)
    end

    if not scrollbar.GSEModernScrollBarHooked and scrollbar.HookScript then
        scrollbar.GSEModernScrollBarHooked = true
        scrollbar:HookScript("OnEnter", function(self)
            self.GSEModernScrollBarHover = true
            setModernSlimScrollBarState(self, self.GSEModernScrollBarActive and "active" or "hover")
        end)
        scrollbar:HookScript("OnLeave", function(self)
            self.GSEModernScrollBarHover = false
            setModernSlimScrollBarState(self, self.GSEModernScrollBarActive and "active" or "normal")
        end)
        scrollbar:HookScript("OnMouseDown", function(self)
            self.GSEModernScrollBarActive = true
            setModernSlimScrollBarState(self, "active")
        end)
        scrollbar:HookScript("OnMouseUp", function(self)
            self.GSEModernScrollBarActive = false
            setModernSlimScrollBarState(self, self.GSEModernScrollBarHover and "hover" or "normal")
        end)
        scrollbar:HookScript("OnHide", function(self)
            self.GSEModernScrollBarHover = false
            self.GSEModernScrollBarActive = false
        end)
    end

    setModernSlimScrollBarState(scrollbar, (scrollbar.IsMouseOver and scrollbar:IsMouseOver()) and "hover" or "normal")
end

-- Public entry point so files outside NativeUI (e.g. DebugWindow) can route
-- their UIPanelScrollFrameTemplate scrollbars through the same slim painter
-- the editor / multi-line editboxes use. Same signature as the local helper.
UI.ApplyModernSlimScrollBar = applyModernSlimScrollBar

local function ensureElvUIWindowBand(frame, key, pointA, relativePointA, xA, yA, pointB, relativePointB, xB, yB, height, bg, border)
    if not frame then return end
    if not frame[key] then
        frame[key] = CreateFrame("Frame", nil, frame, frameTemplate)
        frame[key]:EnableMouse(false)
        if frame[key].CreateTexture then
            frame[key].GSEElvUIBandFill = frame[key]:CreateTexture(nil, "BACKGROUND", nil, -8)
            frame[key].GSEElvUIBandFill:SetAllPoints(frame[key])
        end
    end

    local band = frame[key]
    band:ClearAllPoints()
    band:SetPoint(pointA, frame, relativePointA, xA, yA)
    band:SetPoint(pointB, frame, relativePointB, xB, yB)
    if height and band.SetHeight then band:SetHeight(height) end
    if band.SetFrameStrata and frame.GetFrameStrata then band:SetFrameStrata(frame:GetFrameStrata()) end
    if band.SetFrameLevel and frame.GetFrameLevel then
        band:SetFrameLevel(math.max(0, frame:GetFrameLevel() or 1))
    end
    if band.GSEElvUIBandFill then
        colorTexture(band.GSEElvUIBandFill, bg or ELVUI_SKIN.titleBg)
        band.GSEElvUIBandFill:Show()
    end
    applyElvUIBackdrop(band, bg or ELVUI_SKIN.titleBg, border or ELVUI_SKIN.mutedBorder, false)
    band:Show()
    return band
end
local function ensureElvUIChrome(owner, key, target, bg, border, inset)
    if not (owner and target and frameTemplate) then return end
    if not owner[key] then
        owner[key] = CreateFrame("Frame", nil, owner, frameTemplate)
        owner[key]:EnableMouse(false)
    end
    local chrome = owner[key]
    inset = inset or 0
    chrome:ClearAllPoints()
    chrome:SetPoint("TOPLEFT", target, "TOPLEFT", inset, -inset)
    chrome:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -inset, inset)
    if chrome.SetFrameLevel and target.GetFrameLevel then
        chrome:SetFrameLevel(math.max(0, (target:GetFrameLevel() or 1) - 1))
    end
    applyElvUIBackdrop(chrome, bg or ELVUI_SKIN.buttonBg, border or ELVUI_SKIN.mutedBorder)
    chrome:Show()
    return chrome
end

local function isGSEAssetTexture(path)
    if type(path) ~= "string" then return false end
    path = path:lower():gsub("/", "\\")
    return path:find("interface\\addons\\gse_gui\\assets", 1, true) ~= nil
end

local function applyElvUISubduedIconState(button, texture, active)
    if not (button and texture) then return end
    if button.GSEElvUISubduedHighlight then button.GSEElvUISubduedHighlight:Hide() end
    if button.gseAssetHighlight then button.gseAssetHighlight:Hide() end

    if active then
        if texture.SetDesaturated then texture:SetDesaturated(false) end
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
    else
        if texture.SetDesaturated then texture:SetDesaturated(true) end
        if texture.SetVertexColor then texture:SetVertexColor(0.55, 0.55, 0.55, 0.82) end
    end
end

local function shouldSubdueElvUIAssetIcon(button, path)
    local iconPath = type(path) == "string" and path:lower():gsub("/", "\\") or ""
    if iconPath:find("interface\\addons\\gse_gui\\assets\\drag.png", 1, true) then return false end
    if iconPath:find("interface\\addons\\gse_gui\\assets\\macro.png", 1, true) then return false end
    if iconPath:find("interface\\addons\\gse_gui\\assets\\variables.png", 1, true) then return false end
    if button and button.GSEElvUIKeepIconFullColor then return false end
    return button and shouldUseElvUISkin() and isGSEAssetTexture(path) and button.GSEElvUISubduedIcon ~= false
end

local function applyElvUIIconAssetSkin(button, texture, path)
    if button and button.GSEElvUIIconChromeSuppressed then
        if shouldSubdueElvUIAssetIcon(button, path) then
            applyElvUISubduedIconState(button, texture, button.GSEElvUISubduedIconMouseOver)
        else
            if texture and texture.SetDesaturated then texture:SetDesaturated(false) end
            if texture and texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
        end
        if button.GSEElvUIIconChrome then button.GSEElvUIIconChrome:Hide() end
        return
    end
    if not (button and texture and shouldUseElvUISkin() and isGSEAssetTexture(path)) then
        if texture and texture.SetDesaturated then texture:SetDesaturated(false) end
        if texture and texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
        if button and button.GSEElvUIIconChrome then button.GSEElvUIIconChrome:Hide() end
        return
    end

    ensureElvUIChrome(button, "GSEElvUIIconChrome", button, ELVUI_SKIN.buttonBg, ELVUI_SKIN.mutedBorder)
    if shouldSubdueElvUIAssetIcon(button, path) then
        applyElvUISubduedIconState(button, texture, button.GSEElvUISubduedIconMouseOver)
    else
        if texture.SetDesaturated then texture:SetDesaturated(false) end
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
    end
end

local function setElvUICheckBoxHover(check, hovered)
    if not (check and shouldUseElvUISkin()) then return end
    if check.IsEnabled and not check:IsEnabled() then hovered = false end

    if not check.GSEElvUICheckHover then
        check.GSEElvUICheckHover = check:CreateTexture(nil, "HIGHLIGHT")
        check.GSEElvUICheckHover:SetPoint("TOPLEFT", check, "TOPLEFT", 4, -4)
        check.GSEElvUICheckHover:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", -4, 4)
        check.GSEElvUICheckHover:SetColorTexture(1, 1, 1, 0.18)
    end

    if hovered then
        check.GSEElvUICheckHover:Show()
        if check.GSEElvUICheckChrome and check.GSEElvUICheckChrome.SetBackdropBorderColor then
            check.GSEElvUICheckChrome:SetBackdropBorderColor(unpack(getElvUIBorderColor(ELVUI_SKIN.accentText)))
        end
    else
        check.GSEElvUICheckHover:Hide()
        if check.GSEElvUICheckChrome and check.GSEElvUICheckChrome.SetBackdropBorderColor then
            check.GSEElvUICheckChrome:SetBackdropBorderColor(unpack(getElvUIBorderColor(ELVUI_SKIN.mutedBorder)))
        end
    end
end

local function applyElvUICheckBoxSkin(check, text)
    if not (check and shouldUseElvUISkin()) then return end

    local normal = check.GetNormalTexture and check:GetNormalTexture()
    local pushed = check.GetPushedTexture and check:GetPushedTexture()
    local disabled = check.GetDisabledTexture and check:GetDisabledTexture()
    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end
    if disabled and disabled.SetAlpha then disabled:SetAlpha(0) end

    ensureElvUIChrome(check, "GSEElvUICheckChrome", check, ELVUI_SKIN.insetBg, ELVUI_SKIN.mutedBorder, 4)
    local checkTexture = check:GetCheckedTexture()
    if checkTexture and checkTexture.SetVertexColor then checkTexture:SetVertexColor(unpack(ELVUI_SKIN.accentText)) end
    if text and text.SetTextColor then text:SetTextColor(unpack(getElvUITextColor())) end
    if not check.GSEElvUICheckHoverHooked and check.HookScript then
        check.GSEElvUICheckHoverHooked = true
        check:HookScript("OnEnter", function(self) setElvUICheckBoxHover(self, true) end)
        check:HookScript("OnLeave", function(self) setElvUICheckBoxHover(self, false) end)
        check:HookScript("OnHide", function(self) setElvUICheckBoxHover(self, false) end)
    end
    setElvUICheckBoxHover(check, check.IsMouseOver and check:IsMouseOver())
end

local function getElvUITextButtonFontString(button)
    if not button then return nil end
    local text = button.GetFontString and button:GetFontString()
    return text or button.text or button.label or button.Text
end

local function setElvUITextButtonHover(button, hovered)
    local text = getElvUITextButtonFontString(button)
    if not text then return end
    if button and button.IsEnabled and not button:IsEnabled() then hovered = false end
    if button and button.disabled then hovered = false end

    if text.GetFont and text.SetFont then
        if not text.GSETextButtonBaseFont then
            local fontFile, fontSize, fontFlags = text:GetFont()
            if fontFile and fontSize then
                text.GSETextButtonBaseFont = {fontFile, fontSize, fontFlags}
            end
        end
        local base = text.GSETextButtonBaseFont
        if base then
            text:SetFont(base[1], hovered and (base[2] * ELVUI_TEXT_BUTTON_HOVER_SCALE) or base[2], base[3])
            return
        end
    end

    if text.SetScale then
        text:SetScale(hovered and ELVUI_TEXT_BUTTON_HOVER_SCALE or 1)
    end
end

local function applyElvUITextButtonHover(button)
    if not button then return end
    if not button.GSEElvUITextHoverHooked and button.HookScript then
        button.GSEElvUITextHoverHooked = true
        button:HookScript("OnEnter", function(self) setElvUITextButtonHover(self, true) end)
        button:HookScript("OnLeave", function(self) setElvUITextButtonHover(self, false) end)
        button:HookScript("OnHide", function(self) setElvUITextButtonHover(self, false) end)
    end
    setElvUITextButtonHover(button, button.IsMouseOver and button:IsMouseOver())
end

local function applyNormalAccentButtonText(button)
    local accent = getNormalAccentColor(1)
    if not accent then return end

    local text = getElvUITextButtonFontString(button)
    if text and text.SetTextColor then
        text:SetTextColor(unpack(accent))
    end
end

local function applyNormalAccentCheckBoxText(check, text)
    local accent = getNormalAccentColor(1)
    if not accent then return end

    text = text or (check and (check.text or check.label))
    if text and text.SetTextColor then
        text:SetTextColor(unpack(accent))
    end
end
local function applyElvUIButtonSkin(button, selected)
    if not (button and shouldUseElvUISkin()) then return end
    hideFrameTextures(button)
    applyElvUITextButtonHover(button)

    if button.GSEElvUIButtonChromeSuppressed then
        if button.GSEElvUIChrome then button.GSEElvUIChrome:Hide() end
        local text = button.GetFontString and button:GetFontString()
        if text and text.SetTextColor then text:SetTextColor(unpack(getElvUITextColor())) end
        return
    end

    local chrome = ensureElvUIChrome(
        button,
        "GSEElvUIChrome",
        button,
        selected and ELVUI_SKIN.buttonSelectedBg or ELVUI_SKIN.buttonBg,
        selected and ELVUI_SKIN.border or ELVUI_SKIN.mutedBorder
    )
    if chrome then chrome:SetShown(true) end
    if not button.GSEElvUIHighlight then
        button.GSEElvUIHighlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.GSEElvUIHighlight:SetAllPoints(button)
        button.GSEElvUIHighlight:SetColorTexture(0, 0.78, 0.78, 0.16)
        button:SetHighlightTexture(button.GSEElvUIHighlight)
    end
    local text = button.GetFontString and button:GetFontString()
    if text and text.SetTextColor then
        text:SetTextColor(unpack(selected and ELVUI_SKIN.accentText or getElvUITextColor()))
    end
end

local function subdueElvUICloseTexture(texture, alpha, shade)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    shade = shade or 0.36
    if texture.SetVertexColor then texture:SetVertexColor(shade, shade, shade, alpha or 0.78) end
end

local function fullColorElvUIHighlightTexture(texture, alpha)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(false) end
    if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, alpha or 1) end
end

local function applyElvUICloseButtonSkin(button)
    if not (button and shouldUseElvUISkin()) then return end
    button:ClearAllPoints()
    if button.GetParent and button:GetParent() then
        button:SetPoint("TOPRIGHT", button:GetParent(), "TOPRIGHT", STYLE.closeButtonOffsetX, STYLE.closeButtonOffsetY)
    end
    button:SetSize(CLOSE_BUTTON_WIDTH, CLOSE_BUTTON_HEIGHT)
    button:SetNormalTexture(CLOSE_BUTTON_TEXTURE)
    button:SetPushedTexture(CLOSE_BUTTON_TEXTURE)
    button:SetHighlightTexture(CLOSE_BUTTON_TEXTURE, "BLEND")
    subdueElvUICloseTexture(button.GetNormalTexture and button:GetNormalTexture(), 0.78, 0.36)
    subdueElvUICloseTexture(button.GetPushedTexture and button:GetPushedTexture(), 0.95, 0.70)
    fullColorElvUIHighlightTexture(button.GetHighlightTexture and button:GetHighlightTexture(), 1)
    if button.GetHighlightTexture and button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAlpha(1)
    end
    if button.GSEElvUIChrome then button.GSEElvUIChrome:Hide() end
    if button.GSEElvUICloseText then button.GSEElvUICloseText:Hide() end
end
local function applyElvUIWindowSkin(frame, titleBar, title)
    if not shouldUseElvUISkin() then return end
    hideFrameTextures(frame)
    applyBackdrop(frame, ELVUI_SKIN.backdrop, {0, 0, 0, 0}, {0, 0, 0, 0})

    ensureElvUIWindowBand(
        frame,
        "GSEElvUIOuterShell",
        "TOPLEFT",
        "TOPLEFT",
        0,
        STYLE.padInset,
        "BOTTOMRIGHT",
        "BOTTOMRIGHT",
        0,
        -STYLE.padInset,
        nil,
        ELVUI_SKIN.panelBg,
        ELVUI_SKIN.border
    )

    local outerClassBorder = getModernClassColor(1)
    if outerClassBorder then
        ensureElvUIWindowBand(
            frame,
            "GSEElvUIOuterClassBorder",
            "TOPLEFT",
            "TOPLEFT",
            0,
            0,
            "BOTTOMRIGHT",
            "BOTTOMRIGHT",
            0,
            0,
            nil,
            {0, 0, 0, 0},
            outerClassBorder
        )
    elseif frame.GSEElvUIOuterClassBorder then
        frame.GSEElvUIOuterClassBorder:Hide()
    end

    if frame.GSEBodyFill then
        frame.GSEBodyFill:Hide()
    end

    if titleBar and titleBar ~= frame then
        hideFrameTextures(titleBar)
        if titleBar.SetBackdrop then
            applyBackdrop(titleBar, ELVUI_SKIN.backdrop, {0, 0, 0, 0}, {0, 0, 0, 0})
        elseif titleBar.GSEElvUITitleFill then
            titleBar.GSEElvUITitleFill:Hide()
        end
    end

    if title and title.SetTextColor then
        title:SetTextColor(unpack(ELVUI_SKIN.accentText))
    end

    applyElvUICloseButtonSkin(frame.CloseButton)
end

local function applyNormalAccentWindowSkin(frame)
    if not frame then return end

    -- When an external skin provider is driving the look, defer to it so
    -- the host UI's frame chrome (EUI dark fill + accent border) takes
    -- the place of our own accent-overlay border AND the Blizzard panel
    -- template's gold chrome that would otherwise show through.
    if hasExternalSkinProvider() and GSE.Skin and GSE.Skin.Frame then
        if frame.GSENormalAccentOuterBorder then frame.GSENormalAccentOuterBorder:Hide() end
        if frame.GSENormalAccentBorderOverlay then frame.GSENormalAccentBorderOverlay:Hide() end
        GSE.Skin.Frame(frame)
        return
    end

    local accent = getNormalAccentColor(1)
    if accent then
        if frame.GSENormalAccentOuterBorder then frame.GSENormalAccentOuterBorder:Hide() end

        local overlay = frame.GSENormalAccentBorderOverlay
        if not overlay then
            overlay = CreateFrame("Frame", nil, frame)
            overlay:EnableMouse(false)
            frame.GSENormalAccentBorderOverlay = overlay

            overlay.top = overlay:CreateTexture(nil, "OVERLAY")
            overlay.bottom = overlay:CreateTexture(nil, "OVERLAY")
            overlay.left = overlay:CreateTexture(nil, "OVERLAY")
            overlay.right = overlay:CreateTexture(nil, "OVERLAY")
        end

        local leftOffset = frame.GSEUsesBlizzardPanelTemplate and (WINDOW_LEFT_VISUAL_ALLOWANCE - 7) or -1
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT",     frame, "TOPLEFT",     leftOffset,   1)
        overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -leftOffset, -1)
        if overlay.SetFrameStrata and frame.GetFrameStrata then overlay:SetFrameStrata(frame:GetFrameStrata()) end
        if overlay.SetFrameLevel and frame.GetFrameLevel then overlay:SetFrameLevel((frame:GetFrameLevel() or 1) + 12) end

        local borderSize = 2
        overlay.top:ClearAllPoints()
        overlay.top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
        overlay.top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
        overlay.top:SetHeight(borderSize)

        overlay.bottom:ClearAllPoints()
        overlay.bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
        overlay.bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
        overlay.bottom:SetHeight(borderSize)

        overlay.left:ClearAllPoints()
        overlay.left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
        overlay.left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
        overlay.left:SetWidth(borderSize)

        overlay.right:ClearAllPoints()
        overlay.right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
        overlay.right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
        overlay.right:SetWidth(borderSize)

        colorTexture(overlay.top, accent)
        colorTexture(overlay.bottom, accent)
        colorTexture(overlay.left, accent)
        colorTexture(overlay.right, accent)
        overlay:Show()
        return
    end

    if frame.GSENormalAccentOuterBorder then
        frame.GSENormalAccentOuterBorder:Hide()
    end
    if frame.GSENormalAccentBorderOverlay then
        frame.GSENormalAccentBorderOverlay:Hide()
    end
end
local function skinPanel(frame)
    if shouldUseElvUISkin() then
        applyElvUIBackdrop(frame, ELVUI_SKIN.panelBg, ELVUI_SKIN.border)
        return
    end
    -- Under an external skin provider (EUI / ElvUI), delegate frame painting
    -- to the provider so GSE panels match the host UI's chrome. Otherwise we'd
    -- paint Blizzard's UI-DialogBox-Background + Tooltips-Border textures
    -- below, which is the gold ornate frame that visibly clashes with EUI's
    -- flat dark panels (the tree sidebar / debugger window were both stuck
    -- on this fallback under EUI before this branch existed).
    if hasExternalSkinProvider() and GSE.Skin and GSE.Skin.Frame then
        GSE.Skin.Frame(frame)
        return
    end
    applyBackdrop(
        frame,
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 14,
            insets = {left = STYLE.padSmall, right = STYLE.padSmall, top = STYLE.padSmall, bottom = STYLE.padSmall}
        },
        {0.02, 0.025, 0.025, 1},
        {0.48, 0.48, 0.46, 0.95}
    )
end

local function skinInset(frame)
    if shouldUseElvUISkin() then
        applyElvUIBackdrop(frame, ELVUI_SKIN.insetBg, ELVUI_SKIN.mutedBorder)
        return
    end
    if hasExternalSkinProvider() and GSE.Skin and GSE.Skin.InsetFrame then
        GSE.Skin.InsetFrame(frame)
        return
    end
    applyBackdrop(
        frame,
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = STYLE.padInset, right = STYLE.padInset, top = STYLE.padInset, bottom = STYLE.padInset}
        },
        {0.02, 0.025, 0.025, 1},
        {0.46, 0.46, 0.44, 0.92}
    )
end

function UI.ApplyNativeWindowSkin(frame, titleBar, title, closeButton)
    if not frame then return end
    skinPanel(frame)
    applyElvUIWindowSkin(frame, titleBar or frame, title)
    applyNormalAccentWindowSkin(frame)
    if closeButton then styleCloseButton(closeButton, frame) end
    if title and title.SetText then title:SetText(formatWindowTitle(title:GetText())) end
end

function UI.ApplyNativeInsetSkin(frame)
    skinInset(frame)
end

function UI.ApplyNativeDropdownSkin(frame)
    skinInset(frame)
end

local function createBlizzardPanelFrame(name)
    local templateNames = {"ButtonFrameTemplate", "BasicFrameTemplateWithInset"}

    for _, templateName in ipairs(templateNames) do
        local frame
        local ok = pcall(
            function()
                frame = CreateFrame("Frame", name, UIParent, templateName)
            end
        )

        if ok and frame then
            frame.GSEUsesBlizzardPanelTemplate = true
            return frame
        end
    end

    return CreateFrame("Frame", name, UIParent, frameTemplate)
end

local function styleBlizzardPanelFrame(frame)
    if not (frame and frame.GSEUsesBlizzardPanelTemplate) then return false end

    if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, frame) end
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, frame) end

    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.padTiny)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.padTiny)
        frame.TitleContainer:SetHeight(STYLE.titleHeight)
    end

    if frame.TitleText then
        frame.TitleText:ClearAllPoints()
        if frame.TitleContainer then
            frame.TitleText:SetPoint("LEFT", frame.TitleContainer, "LEFT", 0, STYLE.padTiny)
            frame.TitleText:SetPoint("RIGHT", frame.TitleContainer, "RIGHT", 0, STYLE.padTiny)
        else
            frame.TitleText:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.frameEdge)
            frame.TitleText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.frameEdge)
        end
        frame.TitleText:SetFontObject(GameFontNormal)
        frame.TitleText:SetJustifyH("CENTER")
        frame.TitleText:SetJustifyV("MIDDLE")
    end

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.frameEdge, -STYLE.controlHeight)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -STYLE.frameEdge, -STYLE.controlHeight)
        frame.Inset:SetHeight(STYLE.padTiny)
        frame.Inset:Hide()
    end

    if frame.CloseButton then
        styleCloseButton(frame.CloseButton, frame)
        if frame.CloseButton.SetFrameLevel and frame.GetFrameLevel then
            local titleLevel = frame.TitleContainer and frame.TitleContainer.GetFrameLevel and frame.TitleContainer:GetFrameLevel()
            frame.CloseButton:SetFrameLevel((titleLevel or frame:GetFrameLevel()) + 20)
        end
    end

    if not frame.GSEBodyFill then
        local bodyFill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        bodyFill:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.frameBodyInset, -STYLE.controlHeight)
        bodyFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.frameBodyInset, STYLE.frameBodyInset)
        bodyFill:SetColorTexture(0, 0, 0, 1)
        frame.GSEBodyFill = bodyFill
    end

    applyElvUIWindowSkin(frame, frame.TitleContainer, frame.TitleText)

    return true
end

local function callCallback(widget, event, ...)
    local callback = widget.callbacks and widget.callbacks[event]
    if callback then return callback(widget, event, ...) end
end

local function setFrameResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    if not frame then return end

    minWidth = minWidth or 1
    minHeight = minHeight or 1

    if frame.SetResizeBounds then
        if maxWidth and maxHeight then
            frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
        else
            frame:SetResizeBounds(minWidth, minHeight)
        end
    else
        if frame.SetMinResize then frame:SetMinResize(minWidth, minHeight) end
        if maxWidth and maxHeight and frame.SetMaxResize then frame:SetMaxResize(maxWidth, maxHeight) end
    end
end

local function autoHeightGroup(child)
    return child and not child.fullHeight and (child.autoAdjustHeight or
        (not child.explicitHeight and (child.type == "SimpleGroup" or child.type == "InlineGroup")))
end

local function setChildSize(child, width, height)
    if width and width > 0 then
        child.width = width
        child.frame:SetWidth(width)
        if child.OnWidthSet then child:OnWidthSet(width) end
    end
    if height and height > 0 and not autoHeightGroup(child) then
        child.height = height
        child.frame:SetHeight(height)
        if child.OnHeightSet then child:OnHeightSet(height) end
    end
end

local function actualChildHeight(child, fallback)
    if child.height == 0 then return 0 end
    return child.height or safeHeight(child.frame, fallback or STYLE.controlHeight)
end

local function childWidth(parent, child, contentWidth)
    if child.fullWidth then
        return math.max(1, contentWidth - (STYLE.listPadX * 2))
    elseif child.relativeWidth then
        return math.max(1, (contentWidth - (STYLE.listPadX * 2)) * child.relativeWidth)
    end
    return child.width or safeWidth(child.frame, 200)
end

local function childHeight(parent, child, contentHeight)
    if child.fullHeight then
        return math.max(1, contentHeight - (STYLE.flowPadY * 2))
    end
    return child.height or safeHeight(child.frame, STYLE.controlHeight)
end

local function normalizeLayout(layout)
    layout = layout or "List"
    layout = tostring(layout)
    if layout:lower() == "fill" then return "Fill" end
    if layout:lower() == "flow" then return "Flow" end
    return "List"
end

local doLayout

local function finishLayout(container, content, height)
    local autoSizing =
        (container.autoAdjustHeight or
            (not container.explicitHeight and (container.type == "SimpleGroup" or container.type == "InlineGroup"))) and
        not container.fullHeight
    local layoutHeight = autoSizing and math.max(height or 1, 1) or math.max(height or 1, safeHeight(container.frame, 1))
    if content and content ~= container.frame and content.SetHeight then
        content:SetHeight(layoutHeight)
    end
    if autoSizing and container.frame and container.frame.SetHeight then
        local extra = container.autoHeightExtra
        if extra == nil then extra = content ~= container.frame and 30 or 0 end
        container.height = layoutHeight + extra
        container.frame:SetHeight(container.height)
    end
    if container.UpdateScroll then container:UpdateScroll() end
end

local function layoutFill(container)
    local content = container.content or container.frame
    local child = container.children and container.children[1]
    if not child then return finishLayout(container, content, safeHeight(container.frame, 1)) end

    child.frame:ClearAllPoints()
    child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    child.frame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    setChildSize(child, safeWidth(content, container.width), safeHeight(content, container.height))
    child.frame:Show()
    if child.DoLayout then child:DoLayout() end
    finishLayout(container, content, safeHeight(content, container.height))
end

local function layoutList(container)
    local content = container.content or container.frame
    local contentWidth = safeWidth(content, container.width or safeWidth(container.frame, 300))
    local contentHeight = safeHeight(content, container.height or safeHeight(container.frame, 1))
    local padLeft = container.listPadLeft
    local padTop = container.listPadTop
    local padRight = container.listPadRight
    local padBottom = container.listPadBottom
    local rowGap = container.listGap
    if padLeft == nil then padLeft = STYLE.listPadX end
    if padTop == nil then padTop = STYLE.listPadTop end
    if padRight == nil then padRight = STYLE.listPadX end
    if padBottom == nil then padBottom = STYLE.listPadBottom end
    if rowGap == nil then rowGap = STYLE.listGap end
    local y = -padTop
    local visualBottom = 0

    for _, child in ipairs(container.children or {}) do
        local width = childWidth(container, child, contentWidth)
        local height = childHeight(container, child, contentHeight)
        local xOffset = child.flowXOffset or 0
        local yOffset = child.flowYOffset or 0
        local visualY = y + yOffset
        child.frame:ClearAllPoints()

        if child.fullWidth then
            local leftInset = padLeft + xOffset
            local rightInset = child.listRightInset
            if rightInset == nil then rightInset = padRight end
            width = math.max(1, contentWidth - leftInset - math.max(0, rightInset))
            child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", leftInset, visualY)
            child.frame:SetWidth(width)
        else
            child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", padLeft + xOffset, visualY)
            child.frame:SetWidth(width)
        end

        if child.fullHeight then
            child.frame:SetPoint("BOTTOM", content, "BOTTOM", 0, padBottom)
        elseif not autoHeightGroup(child) then
            child.frame:SetHeight(height)
        end

        setChildSize(child, width, height)
        child.frame:Show()
        if child.DoLayout then child:DoLayout() end
        local actualHeight = actualChildHeight(child, height)
        visualBottom = math.max(visualBottom, -visualY + actualHeight)
        y = y - actualHeight - (actualHeight > 0 and rowGap or 0)
    end

    finishLayout(container, content, math.max(1, visualBottom > 0 and (visualBottom + padBottom) or (-y + padBottom)))
end

local function layoutFlow(container)
    local content = container.content or container.frame
    local contentWidth = safeWidth(content, container.width or safeWidth(container.frame, 300))
    local gap = container.flowGap or STYLE.flowGap
    local rowGap = container.flowRowGap or STYLE.flowRowGap
    local padLeft = container.flowPadLeft
    local padTop = container.flowPadTop
    local padRight = container.flowPadRight
    local padBottom = container.flowPadBottom
    if padLeft == nil then padLeft = STYLE.flowPadX end
    if padTop == nil then padTop = STYLE.flowPadY end
    if padRight == nil then padRight = STYLE.flowPadX end
    if padBottom == nil then padBottom = STYLE.flowPadY end
    local x = padLeft
    local y = -padTop
    local totalHeight = STYLE.controlHeight
    local rows = {}
    local row = {children = {}, height = 0, y = y, rightX = contentWidth - padRight}

    -- Total horizontal space claimed by right-aligned children (each pinned to
    -- the row's right edge). flowFillRemaining children subtract this so a fill
    -- body and a right-aligned control can share one row without overlapping.
    local reservedRight = 0
    for _, child in ipairs(container.children or {}) do
        if child.flowRightAlign or child.flowRightAligned then
            reservedRight = reservedRight + childWidth(container, child, contentWidth) + gap
        end
    end

    for _, child in ipairs(container.children or {}) do
        local width = childWidth(container, child, contentWidth)
        if child.flowFillRemaining then
            width = math.max(1, contentWidth - x - padRight - reservedRight)
        end
        local height = childHeight(container, child, safeHeight(content, container.height or 1))
        local rightAligned = child.flowRightAlign or child.flowRightAligned
        if not rightAligned and x > padLeft and (x + width) > (contentWidth - padRight) then
            rows[#rows + 1] = row
            y = y - row.height - rowGap
            x = padLeft
            row = {children = {}, height = 0, y = y, rightX = contentWidth - padRight}
            if child.flowFillRemaining then
                width = math.max(1, contentWidth - x - padRight - reservedRight)
            end
        end

        local childHeightValue = actualChildHeight(child, height)
        if rightAligned then
            row.rightX = math.max(padLeft, row.rightX - width)
            row.children[#row.children + 1] = {child = child, x = row.rightX, width = width, height = height, childHeight = childHeightValue}
            row.rightX = row.rightX - gap
        else
            row.children[#row.children + 1] = {child = child, x = x, width = width, height = height, childHeight = childHeightValue}
            x = x + width + gap
        end
        row.height = math.max(row.height, childHeightValue)
    end

    if #row.children > 0 then
        rows[#rows + 1] = row
    end

    for _, flowRow in ipairs(rows) do
        -- Optional horizontal alignment of the row's left-flowed children.
        -- Default (nil) keeps the existing left-aligned behaviour untouched.
        local hOffset = 0
        if container.flowHAlign == "CENTER" or container.flowHAlign == "RIGHT" then
            local used = 0
            for _, entry in ipairs(flowRow.children) do
                if not (entry.child.flowRightAlign or entry.child.flowRightAligned) then
                    used = math.max(used, entry.x + entry.width)
                end
            end
            used = used - padLeft
            local avail = (contentWidth - padRight) - padLeft
            if container.flowHAlign == "CENTER" then
                hOffset = math.max(0, math.floor((avail - used) / 2))
            else
                hOffset = math.max(0, avail - used)
            end
        end
        for _, entry in ipairs(flowRow.children) do
            local child = entry.child
            local rightAligned = child.flowRightAlign or child.flowRightAligned
            local verticalOffset = 0
            if container.flowVAlign == "CENTER" or container.flowVAlign == "MIDDLE" then
                verticalOffset = -math.floor(math.max(0, flowRow.height - entry.childHeight) / 2)
            elseif container.flowVAlign == "BOTTOM" then
                verticalOffset = -math.max(0, flowRow.height - entry.childHeight)
            end

            local extraX = (not rightAligned) and hOffset or 0
            child.frame:ClearAllPoints()
            child.frame:SetPoint("TOPLEFT", content, "TOPLEFT", entry.x + extraX + (child.flowXOffset or 0), flowRow.y + verticalOffset + (child.flowYOffset or 0))
            setChildSize(child, entry.width, entry.height)
            child.frame:Show()
            if child.DoLayout then child:DoLayout() end

            totalHeight = math.max(totalHeight, -flowRow.y + flowRow.height + padBottom)
        end
    end

    finishLayout(container, content, totalHeight)
end

doLayout = function(container)
    if container.layout == "Fill" then
        layoutFill(container)
    elseif container.layout == "Flow" then
        layoutFlow(container)
    else
        layoutList(container)
    end
end

local baseMethods = {}

function baseMethods:SetCallback(event, callback)
    self.callbacks[event] = callback
end

function baseMethods:Fire(event, ...)
    return callCallback(self, event, ...)
end

function baseMethods:SetWidth(width)
    self.width = width
    self.frame:SetWidth(width)
    if self.OnWidthSet then self:OnWidthSet(width) end
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetHeight(height)
    self.height = height
    self.explicitHeight = true
    self.frame:SetHeight(height)
    if self.OnHeightSet then self:OnHeightSet(height) end
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetSize(width, height)
    self.width = width
    self.height = height
    self.explicitHeight = true
    self.frame:SetSize(width, height)
    if self.OnWidthSet then self:OnWidthSet(width) end
    if self.OnHeightSet then self:OnHeightSet(height) end
    self:DoLayout()
end

function baseMethods:SetFullWidth(value)
    self.fullWidth = value
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFullHeight(value)
    self.fullHeight = value
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetRelativeWidth(value)
    self.relativeWidth = value
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFlowFillRemaining(value)
    self.flowFillRemaining = value
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFlowOffset(x, y)
    self.flowXOffset = x or 0
    self.flowYOffset = y or 0
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFlowPadding(left, top, right, bottom)
    self.flowPadLeft = left
    self.flowPadTop = top
    self.flowPadRight = right
    self.flowPadBottom = bottom
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetLeftBorderColor(r, g, b, a, width, bottomBump)
    if not self.leftBorder then return end
    self.leftBorder:SetWidth(width or STYLE.padInset)
    self.leftBorder:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    -- Optional per-pixel bump on the rail's BOTTOM anchor — nudges the rail
    -- to terminate this many pixels higher above the frame's bottom inset.
    -- Used by nested action blocks (depth-based) so the L-shaped corners of
    -- stacked rails don't pile up at the same y-coordinate. bump <= 0 keeps
    -- the original anchoring, so callers that don't pass anything see the
    -- same layout as before this parameter existed.
    local bump = tonumber(bottomBump) or 0
    if bump < 0 then bump = 0 end
    if self.frame then
        self.leftBorder:ClearAllPoints()
        self.leftBorder:SetPoint("TOPLEFT",    self.frame, "TOPLEFT",    STYLE.padInset, -STYLE.padInset)
        self.leftBorder:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", STYLE.padInset,  STYLE.padInset + bump)
    end
    self.leftBorder:Show()
end

function baseMethods:SetFlowGap(gap)
    self.flowGap = tonumber(gap) or STYLE.flowGap
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFlowVAlign(align)
    self.flowVAlign = align and tostring(align):upper() or nil
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetFlowRightAlign(value)
    self.flowRightAlign = value and true or false
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetListRightInset(value)
    self.listRightInset = tonumber(value)
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetListPadding(left, top, right, bottom)
    self.listPadLeft = left
    self.listPadTop = top
    self.listPadRight = right
    self.listPadBottom = bottom
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetListGap(value)
    self.listGap = tonumber(value)
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetAutoAdjustHeight(value)
    self.autoAdjustHeight = value and true or false
    self.explicitHeight = self.autoAdjustHeight and false or self.explicitHeight
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetAutoHeightExtra(value)
    self.autoHeightExtra = tonumber(value)
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:SetTitle(text)
    self.titleText = textValue(text)
    if self.title then
        self.title:SetText(self.titleText)
        if self.titleText ~= "" then
            self.title:Show()
        else
            self.title:Hide()
        end
    end
end

function baseMethods:SetLayout(layout)
    self.layout = normalizeLayout(layout)
    self:DoLayout()
end

function baseMethods:AddChild(child)
    self.children = self.children or {}
    child.parent = self
    child.frame:SetParent(self.content or self.frame)
    table.insert(self.children, child)
    self:DoLayout()
    if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
end

function baseMethods:ReleaseChildren()
    local children = self.children or {}
    self.children = {}
    for _, child in ipairs(children) do
        child.parent = nil
        if child.Release then
            child:Release()
        elseif child.frame then
            child.frame:Hide()
            child.frame:ClearAllPoints()
            child.frame:SetParent(UIParent)
        end
    end
    self:DoLayout()
end

function baseMethods:Release()
    self:Fire("OnRelease")
    self:ReleaseChildren()
    self.parent = nil
    self.frame:Hide()
    self.frame:ClearAllPoints()
    self.frame:SetParent(UIParent)
end

function baseMethods:DoLayout()
    if layoutSuspended > 0 then return end
    doLayout(self)
end

function UI:SuspendLayout()
    layoutSuspended = layoutSuspended + 1
    if C_Timer and C_Timer.After and not layoutResumeScheduled then
        layoutResumeScheduled = true
        C_Timer.After(0, function()
            layoutResumeScheduled = false
            layoutSuspended = 0
        end)
    end
end

function UI:ResumeLayout()
    if layoutSuspended > 0 then
        layoutSuspended = layoutSuspended - 1
    end
end

function baseMethods:Show()
    self.frame:Show()
    self:DoLayout()
end

function baseMethods:Hide()
    self.frame:Hide()
end

function baseMethods:IsShown()
    return self.frame:IsShown()
end

function baseMethods:IsVisible()
    return self.frame:IsVisible()
end

function baseMethods:SetPoint(...)
    self.frame:SetPoint(...)
end

function baseMethods:ClearAllPoints()
    self.frame:ClearAllPoints()
end

function baseMethods:SetDisabled(disabled)
    self.disabled = disabled
    if self.frame.EnableMouse then self.frame:EnableMouse(not disabled) end
    if self.frame.Disable and self.frame.Enable then
        if disabled then
            self.frame:Disable()
        else
            self.frame:Enable()
        end
    end
end

local function wrap(typeName, frame)
    local widget = {
        type = typeName,
        frame = frame,
        callbacks = {},
        children = {},
        layout = "List"
    }
    frame.obj = widget
    return setmetatable(widget, {__index = baseMethods})
end

local function createContainer(typeName)
    local frame = CreateFrame("Frame", nextName(typeName), UIParent, frameTemplate)
    frame:SetSize(200, typeName == "Spacer" and STYLE.padXL or STYLE.controlHeight)

    local widget = wrap(typeName, frame)
    widget.content = frame

    if typeName == "InlineGroup" and frameTemplate then
        skinInset(frame)
        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", STYLE.padXXL, -STYLE.frameBodyInset)
        title:SetJustifyH("LEFT")
        title:Hide()
        widget.title = title
        local leftBorder = frame:CreateTexture(nil, "OVERLAY")
        leftBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.padInset, -STYLE.padInset)
        leftBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", STYLE.padInset, STYLE.padInset)
        leftBorder:SetWidth(STYLE.padInset)
        leftBorder:Hide()
        widget.leftBorder = leftBorder
        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", STYLE.padLarge, -STYLE.labelControlOffset)
        content:SetPoint("BOTTOMRIGHT", -STYLE.padLarge, STYLE.padLarge)
        if content.SetClipsChildren then content:SetClipsChildren(true) end
        widget.content = content
        frame:SetHeight(60)
    end

    return widget
end

local function createFrame()
    local frame = createBlizzardPanelFrame(nextName("Frame"))
    frame:SetSize(500, 400)
    frame:SetFrameStrata("MEDIUM")
    if frame.SetToplevel then frame:SetToplevel(true) end
    applyFrameScreenBuffer(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        bringFrameToFront(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:HookScript("OnMouseDown", bringFrameToFront)
    frame:HookScript("OnShow", function(self)
        if GSE.ApplyScaleToFrame then GSE.ApplyScaleToFrame(self) end
        applyNormalAccentWindowSkin(self)
        bringFrameToFront(self)
    end)
    local usesStockPanel = styleBlizzardPanelFrame(frame)
    if not usesStockPanel then skinPanel(frame) end

    local titleBar = frame.TitleContainer or frame
    local closeButton = frame.CloseButton
    local title = frame.TitleText

    if not usesStockPanel then
        titleBar = CreateFrame("Frame", nil, frame, frameTemplate)
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.frameEdge, -STYLE.frameEdge)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.frameEdge, -STYLE.frameEdge)
        titleBar:SetHeight(STYLE.titleHeight)
        titleBar:EnableMouse(false)
        applyBackdrop(
            titleBar,
            {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 10,
                insets = {left = STYLE.padXXS, right = STYLE.padXXS, top = STYLE.padXXS, bottom = STYLE.padXXS}
            },
            {0.16, 0.155, 0.14, 0.92},
            {0.46, 0.46, 0.43, 0.95}
        )

        local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
        titleBarBg:SetPoint("TOPLEFT", titleBar, "TOPLEFT", STYLE.padInset, -STYLE.padInset)
        titleBarBg:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -STYLE.padInset, STYLE.padInset)
        titleBarBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
        titleBarBg:SetHorizTile(true)
        titleBarBg:SetVertTile(true)
        titleBarBg:SetVertexColor(0.42, 0.40, 0.35, 0.62)

        local titleBarTop = titleBar:CreateTexture(nil, "BORDER")
        titleBarTop:SetPoint("TOPLEFT", titleBar, "TOPLEFT", STYLE.frameBodyInset, -STYLE.padInset)
        titleBarTop:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -STYLE.frameBodyInset, -STYLE.padInset)
        titleBarTop:SetHeight(STYLE.padTiny)
        titleBarTop:SetColorTexture(0.74, 0.73, 0.68, 0.50)

        local titleBarBottom = titleBar:CreateTexture(nil, "BORDER")
        titleBarBottom:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", STYLE.frameBodyInset, STYLE.padInset)
        titleBarBottom:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -STYLE.frameBodyInset, STYLE.padInset)
        titleBarBottom:SetHeight(STYLE.padTiny)
        titleBarBottom:SetColorTexture(0.03, 0.03, 0.03, 0.82)

        local titleBarShadow = titleBar:CreateTexture(nil, "BACKGROUND", nil, -1)
        titleBarShadow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
        titleBarShadow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
        titleBarShadow:SetHeight(10)
        titleBarShadow:SetColorTexture(0, 0, 0, 0.48)

        title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("LEFT", titleBar, "LEFT", STYLE.titleInsetX + STYLE.padXXS, STYLE.padTiny)
        title:SetPoint("RIGHT", titleBar, "RIGHT", -(STYLE.titleInsetX + STYLE.padXXS), STYLE.padTiny)
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
    elseif titleBar ~= frame and titleBar.EnableMouse then
        titleBar:EnableMouse(false)
    end

    if not closeButton then
        closeButton = CreateFrame("Button", nil, frame)
    end
    styleCloseButton(closeButton, frame)
    if closeButton.SetFrameLevel then
        local titleLevel = titleBar and titleBar.GetFrameLevel and titleBar:GetFrameLevel()
        local frameLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 0
        closeButton:SetFrameLevel((titleLevel or frameLevel) + 20)
    end

    if not title then
        title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        if titleBar ~= frame then
            title:SetPoint("LEFT", titleBar, "LEFT", 0, STYLE.padTiny)
            title:SetPoint("RIGHT", titleBar, "RIGHT", 0, STYLE.padTiny)
        else
            title:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.titleInsetX, -STYLE.frameEdge)
            title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.titleInsetX, -STYLE.frameEdge)
        end
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
    end

    applyElvUIWindowSkin(frame, titleBar, title)
    applyNormalAccentWindowSkin(frame)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetHeight(STYLE.labelControlOffset)
    status:SetPoint("BOTTOMLEFT", STYLE.labelControlOffset, STYLE.pad)
    status:SetPoint("BOTTOMRIGHT", -STYLE.padXXL, STYLE.pad)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("MIDDLE")

    local content = CreateFrame("Frame", nil, frame)
    -- Right inset matches visual left: frameContentX + Blizzard chrome allowance = equal margins
    local frameRightInset = STYLE.frameContentX + WINDOW_LEFT_VISUAL_ALLOWANCE
    content:SetPoint("TOPLEFT", STYLE.frameContentX, -STYLE.frameContentTop)
    content:SetPoint("BOTTOMRIGHT", -frameRightInset, STYLE.frameContentBottom)
    if content.SetClipsChildren then content:SetClipsChildren(true) end

    local widget = wrap("Frame", frame)
    widget.content = content
    widget.closebutton = closeButton
    widget.titlebar = titleBar
    widget.titletext = title
    widget.statustext = status

    local footer = CreateFrame("Frame", nil, frame)
    footer:Hide()
    widget.footer = footer
    widget.footerChildren = {}

    local function updateFooterAnchors()
        local footerHeight = widget.footerHeight or STYLE.controlHeight
        local footerBottom = widget.footerBottomOffset or (STYLE.frameContentBottom + STYLE.pad)
        footer:ClearAllPoints()
        footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", STYLE.frameContentX, footerBottom)
        footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -frameRightInset, footerBottom)
        footer:SetHeight(footerHeight)
        if footer.SetFrameLevel and frame.GetFrameLevel then footer:SetFrameLevel((frame:GetFrameLevel() or 0) + 70) end

        local contentBottom = STYLE.frameContentBottom
        if widget.footerShown then
            contentBottom = math.max(contentBottom, footerBottom + footerHeight + (widget.footerContentGap or STYLE.padLarge))
        end

        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", STYLE.frameContentX, -STYLE.frameContentTop)
        content:SetPoint("BOTTOMRIGHT", -frameRightInset, contentBottom)
    end

    local function layoutFooterChildren()
        updateFooterAnchors()
        local children = widget.footerChildren or {}
        if #children == 0 or not widget.footerShown then
            footer:Hide()
            return
        end

        footer:Show()
        local gap = widget.footerGap or STYLE.buttonRowGap
        local rowGap = widget.footerRowGap or STYLE.buttonRowVerticalGap
        local rows = {}
        local rowOrder = {}
        for _, child in ipairs(children) do
            local childFrame = child.frame
            if childFrame then
                local rowIndex = math.floor(tonumber(child.footerRow) or 1)
                if rowIndex < 1 then rowIndex = 1 end

                local row = rows[rowIndex]
                if not row then
                    row = { items = {}, width = 0, height = 0 }
                    rows[rowIndex] = row
                    rowOrder[#rowOrder + 1] = rowIndex
                end

                local childWidth = childFrame:GetWidth() or child.width or 100
                local childHeight = childFrame:GetHeight() or child.height or STYLE.controlHeight
                if childWidth <= 0 then childWidth = child.width or 100 end
                if childHeight <= 0 then childHeight = child.height or STYLE.controlHeight end

                if #row.items > 0 then row.width = row.width + gap end
                row.width = row.width + childWidth
                row.height = math.max(row.height, childHeight)
                row.items[#row.items + 1] = { child = child, width = childWidth, height = childHeight }
            end
        end

        if #rowOrder == 0 then
            footer:Hide()
            return
        end

        table.sort(rowOrder)

        local totalHeight = 0
        for index, rowIndex in ipairs(rowOrder) do
            totalHeight = totalHeight + rows[rowIndex].height
            if index > 1 then totalHeight = totalHeight + rowGap end
        end

        local footerWidth = footer.GetWidth and footer:GetWidth() or math.max(1, (widget.width or 300) - (STYLE.frameContentX * 2))
        local footerHeight = footer.GetHeight and footer:GetHeight() or (widget.footerHeight or totalHeight)
        if footerHeight <= 0 then footerHeight = widget.footerHeight or totalHeight end
        local align = normalizeButtonAlignment(widget.footerAlignment)
        local footerLevel = footer.GetFrameLevel and footer:GetFrameLevel() or 0
        local rowTop = math.min(footerHeight, (footerHeight + totalHeight) / 2)

        for _, rowIndex in ipairs(rowOrder) do
            local row = rows[rowIndex]
            local left = 0
            if align == UI.ButtonAlignment.RIGHT then
                left = math.max(0, footerWidth - row.width)
            elseif align == UI.ButtonAlignment.CENTER then
                left = math.max(0, math.floor((footerWidth - row.width) / 2))
            end

            local rowY = rowTop - (row.height / 2) - (footerHeight / 2)
            for _, item in ipairs(row.items) do
                local child = item.child
                local childFrame = child.frame
                childFrame:SetParent(footer)
                childFrame:ClearAllPoints()
                childFrame:SetPoint("LEFT", footer, "LEFT", left, rowY)
                if childFrame.SetFrameLevel then childFrame:SetFrameLevel(footerLevel + 10) end
                childFrame:Show()
                if child.DoLayout then child:DoLayout() end
                left = left + item.width + gap
            end

            rowTop = rowTop - row.height - rowGap
        end
    end

    updateFooterAnchors()

    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(STYLE.labelControlOffset, STYLE.labelControlOffset)
    resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.pad, STYLE.pad)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    resizeButton:Hide()
    widget.resizeButton = resizeButton

    closeButton:SetScript("OnClick", function() frame:Hide() end)

    -- Live resize is driven by an OnUpdate on the resize button itself, throttled
    -- to ~50fps in code. This avoids C_Timer.After indirection (which can be
    -- preempted during input) and runs independent of Editor.lua's own scheduler.
    local LIVE_RESIZE_INTERVAL = 0.02
    local liveResizeAccum = 0

    resizeButton:SetScript(
        "OnMouseDown",
        function(_, button)
            if button == "LeftButton" and widget.resizable then
                widget.resizing = true
                liveResizeAccum = 0
                widget:Fire("OnResizeStart", widget.width, widget.height)
                frame:StartSizing("BOTTOMRIGHT")
                resizeButton:SetScript("OnUpdate", function(_, delta)
                    if not widget.resizing then
                        resizeButton:SetScript("OnUpdate", nil)
                        return
                    end
                    liveResizeAccum = liveResizeAccum + (delta or 0)
                    if liveResizeAccum < LIVE_RESIZE_INTERVAL then return end
                    liveResizeAccum = 0
                    -- Pull the live size off the WoW frame (StartSizing is moving it).
                    local w, h = frame:GetWidth(), frame:GetHeight()
                    widget.width = w
                    widget.height = h
                    if widget.frame and widget.frame:IsShown() then
                        widget:DoLayout()
                    end
                end)
            end
        end
    )
    resizeButton:SetScript(
        "OnMouseUp",
        function()
            resizeButton:SetScript("OnUpdate", nil)
            frame:StopMovingOrSizing()
            widget.resizing = nil
            widget.liveResizeLayoutPending = nil
            widget.width = frame:GetWidth()
            widget.height = frame:GetHeight()
            widget:DoLayout()
            widget:Fire("OnResizeStop", widget.width, widget.height)
        end
    )

    frame:SetScript(
        "OnHide",
        function()
            resizeButton:SetScript("OnUpdate", nil)
            frame:StopMovingOrSizing()
            widget.resizing = nil
            widget.liveResizeLayoutPending = nil
            widget:Fire("OnClose")
        end
    )
    frame:HookScript(
        "OnSizeChanged",
        function(_, width, height)
            widget.width = width
            widget.height = height
            -- Outside of a live drag, lay out immediately. During a drag the OnUpdate
            -- pump above is driving DoLayout; skip here so we don't double-layout.
            if widget.resizing then return end
            widget:DoLayout()
        end
    )

    function widget:SetTitle(text)
        self.titleText = formatWindowTitle(text)
        title:SetText(self.titleText)
    end

    function widget:SetStatusText(text)
        status:SetText(textValue(text))
    end

    function widget:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        setFrameResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    end

    function widget:SetResizable(enabled)
        self.resizable = enabled and true or false
        frame:SetResizable(self.resizable)
        resizeButton:SetShown(self.resizable)
    end

    function widget:SetFooterShown(shown)
        self.footerShown = shown and true or false
        updateFooterAnchors()
        self:DoLayout()
    end

    function widget:SetFooterHeight(height)
        self.footerHeight = tonumber(height) or STYLE.controlHeight
        updateFooterAnchors()
        layoutFooterChildren()
    end

    function widget:SetFooterBottomOffset(offset)
        self.footerBottomOffset = tonumber(offset) or (STYLE.frameContentBottom + STYLE.pad)
        updateFooterAnchors()
        layoutFooterChildren()
    end

    function widget:SetFooterContentGap(gap)
        self.footerContentGap = tonumber(gap) or STYLE.padLarge
        updateFooterAnchors()
        self:DoLayout()
    end

    function widget:SetFooterGap(gap)
        self.footerGap = tonumber(gap) or STYLE.buttonRowGap
        layoutFooterChildren()
    end

    function widget:SetFooterRowGap(gap)
        self.footerRowGap = tonumber(gap) or STYLE.buttonRowVerticalGap
        layoutFooterChildren()
    end

    function widget:SetFooterAlignment(align)
        self.footerAlignment = normalizeButtonAlignment(align)
        layoutFooterChildren()
    end

    function widget:AddFooterChild(child, row)
        if not (child and child.frame) then return end
        self.footerChildren = self.footerChildren or {}
        local rowIndex = math.floor(tonumber(row) or 1)
        if rowIndex < 1 then rowIndex = 1 end
        child.parent = self
        child.footerRow = rowIndex
        child.frame:SetParent(footer)
        table.insert(self.footerChildren, child)
        layoutFooterChildren()
    end

    function widget:ReleaseFooterChildren()
        local children = self.footerChildren or {}
        self.footerChildren = {}
        for _, child in ipairs(children) do
            child.parent = nil
            child.footerRow = nil
            if child.Release then
                child:Release()
            elseif child.frame then
                child.frame:Hide()
                child.frame:ClearAllPoints()
                child.frame:SetParent(UIParent)
            end
        end
        layoutFooterChildren()
    end

    function widget:DoFooterLayout()
        layoutFooterChildren()
    end

    function widget:DoLayout()
        doLayout(self)
        layoutFooterChildren()
    end

    widget:SetResizeBounds(200, 120)
    if GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(frame) end

    if GSE.Skin and GSE.Skin.Frame then GSE.Skin.Frame(frame) end
    return widget
end

local function createButton()
    local button = CreateFrame("Button", nextName("Button"), UIParent, "UIPanelButtonTemplate")
    button:SetSize(120, STYLE.controlHeight)
    button:RegisterForClicks("AnyUp")
    local widget = wrap("Button", button)
    widget.text = button:GetFontString()

    button:SetScript("OnClick", function(_, mouseButton) widget:Fire("OnClick", mouseButton) end)
    button:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    button:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
    applyElvUITextButtonHover(button)
    applyElvUIButtonSkin(button)
    applyNormalAccentButtonText(button)

    function widget:SetText(text)
        button:SetText(textValue(text))
        applyNormalAccentButtonText(button)
    end

    function widget:GetText()
        return button:GetText()
    end

    function widget:SetElvUIBackgroundShown(shown)
        button.GSEElvUIButtonChromeSuppressed = shown == false
        if shouldUseElvUISkin() then applyElvUIButtonSkin(button) else applyNormalAccentButtonText(button) end
    end

    if GSE.Skin and GSE.Skin.Button then GSE.Skin.Button(button) end
    return widget
end

local function createPanelTabButton()
    local button = CreateFrame("Button", nextName("PanelTabButton"), UIParent)
    button.gseTabWidth = STYLE.panelTabWidth
    button.gseTabHeight = STYLE.tabBarHeight
    button:SetSize(button.gseTabWidth, button.gseTabHeight)
    button:RegisterForClicks("AnyUp")

    local widget = wrap("PanelTabButton", button)
    widget.text = button:CreateFontString(button:GetName() .. "Text", "ARTWORK")
    button:SetFontString(widget.text)
    button:SetNormalFontObject(GameFontNormalSmall or GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlightSmall or GameFontHighlight)
    button:SetDisabledFontObject(GameFontHighlightSmall or GameFontHighlight)

    local tabFont, _, tabFontFlags = widget.text:GetFont()
    local tabFontSize = 11

    local function createTabTexture(suffix, texturePath, layer, leftTex, rightTex)
        local texture = button:CreateTexture(button:GetName() .. suffix, layer or "BORDER")
        texture:SetTexture(texturePath)
        texture:SetTexCoord(leftTex, rightTex, 0, 1)
        button[suffix] = texture
        return texture
    end

    local inactiveTexture = "Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab"
    local activeTexture = "Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab"
    button.Left = createTabTexture("Left", inactiveTexture, "BORDER", 0, 0.15625)
    button.Middle = createTabTexture("Middle", inactiveTexture, "BORDER", 0.15625, 0.84375)
    button.Right = createTabTexture("Right", inactiveTexture, "BORDER", 0.84375, 1)
    button.LeftDisabled = createTabTexture("LeftDisabled", activeTexture, "BORDER", 0, 0.15625)
    button.MiddleDisabled = createTabTexture("MiddleDisabled", activeTexture, "BORDER", 0.15625, 0.84375)
    button.RightDisabled = createTabTexture("RightDisabled", activeTexture, "BORDER", 0.84375, 1)
    button.HighlightTexture = button:CreateTexture(button:GetName() .. "HighlightTexture", "HIGHLIGHT")
    button.HighlightTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    button.HighlightTexture:SetBlendMode("ADD")
    button:SetHighlightTexture(button.HighlightTexture)

    local function normalizeClassicTab()
        local width = button.gseTabWidth or button:GetWidth() or STYLE.panelTabWidth
        local height = button.gseTabHeight or button:GetHeight() or STYLE.tabBarHeight
        local middleWidth = math.max(1, width - (STYLE.tabSideWidth * 2))
        button:SetSize(width, height)

        button.Left:ClearAllPoints()
        button.Left:SetSize(STYLE.tabSideWidth, height)
        button.Left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.Middle:ClearAllPoints()
        button.Middle:SetSize(middleWidth, height)
        button.Middle:SetPoint("LEFT", button.Left, "RIGHT", 0, 0)
        button.Right:ClearAllPoints()
        button.Right:SetSize(STYLE.tabSideWidth, height)
        button.Right:SetPoint("LEFT", button.Middle, "RIGHT", 0, 0)

        button.LeftDisabled:ClearAllPoints()
        button.LeftDisabled:SetSize(STYLE.tabSideWidth, height)
        button.LeftDisabled:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, -STYLE.padInset)
        button.MiddleDisabled:ClearAllPoints()
        button.MiddleDisabled:SetSize(middleWidth, height)
        button.MiddleDisabled:SetPoint("LEFT", button.LeftDisabled, "RIGHT", 0, 0)
        button.RightDisabled:ClearAllPoints()
        button.RightDisabled:SetSize(STYLE.tabSideWidth, height)
        button.RightDisabled:SetPoint("LEFT", button.MiddleDisabled, "RIGHT", 0, 0)

        button.HighlightTexture:ClearAllPoints()
        button.HighlightTexture:SetPoint("LEFT", button, "LEFT", STYLE.padXL, -STYLE.frameEdge)
        button.HighlightTexture:SetPoint("RIGHT", button, "RIGHT", -STYLE.padXL, -STYLE.frameEdge)
        button.HighlightTexture:SetHeight(height)
    end

    local function showTextures(textures, show)
        for _, texture in ipairs(textures) do
            texture:SetShown(show)
        end
    end

    local function resetButtonTint()
        local textures = {
            button.Left, button.Middle, button.Right,
            button.LeftDisabled, button.MiddleDisabled, button.RightDisabled,
            button.HighlightTexture
        }
        for _, texture in ipairs(textures) do
            if texture and texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
        end
    end

    local function styleTabText(active)
        widget.text:SetFontObject(GameFontNormal)
        if tabFont then widget.text:SetFont(tabFont, tabFontSize, tabFontFlags) end
        widget.text:SetTextColor(1, active and 1 or 0.82, active and 1 or 0, 1)
        widget.text:ClearAllPoints()
        widget.text:SetPoint("LEFT", button, "LEFT", STYLE.tabTextLeft, active and -STYLE.padTiny or -STYLE.padInset)
        widget.text:SetPoint("RIGHT", button, "RIGHT", -STYLE.padXXL, active and -STYLE.padTiny or -STYLE.padInset)
        widget.text:SetJustifyH("CENTER")
        widget.text:SetJustifyV("MIDDLE")
        if widget.text.SetWordWrap then widget.text:SetWordWrap(false) end
    end

    local function applySelected(selected)
        widget.selected = selected and true or false
        resetButtonTint()

        if shouldUseElvUISkin() then
            showTextures({
                button.Left, button.Middle, button.Right,
                button.LeftDisabled, button.MiddleDisabled, button.RightDisabled,
                button.HighlightTexture
            }, false)
            applyElvUIButtonSkin(button, widget.selected)
            if widget.selected then
                button:Disable()
            else
                button:Enable()
            end
            button:SetAlpha(1)
            normalizeClassicTab()
            styleTabText(widget.selected)
            widget.text:SetTextColor(unpack(widget.selected and ELVUI_SKIN.accentText or getElvUITextColor()))
            return
        end

        if widget.selected then
            showTextures({button.Left, button.Middle, button.Right}, false)
            showTextures({button.LeftDisabled, button.MiddleDisabled, button.RightDisabled}, true)
            button:Disable()
        else
            showTextures({button.Left, button.Middle, button.Right}, true)
            showTextures({button.LeftDisabled, button.MiddleDisabled, button.RightDisabled}, false)
            button:Enable()
        end
        button:SetAlpha(1)
        normalizeClassicTab()
        styleTabText(widget.selected)
        applyNormalAccentButtonText(button)
    end

    button:SetScript("OnClick", function(_, mouseButton) widget:Fire("OnClick", mouseButton) end)
    button:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    button:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
    applyElvUIButtonSkin(button)

    function widget:SetText(text)
        button:SetText(textValue(text))
        normalizeClassicTab()
        styleTabText(widget.selected)
        applyNormalAccentButtonText(button)
    end

    function widget:SetWidth(width)
        button.gseTabWidth = tonumber(width) or button.gseTabWidth or STYLE.panelTabWidth
        self.width = button.gseTabWidth
        normalizeClassicTab()
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end

    function widget:SetHeight(height)
        button.gseTabHeight = tonumber(height) or button.gseTabHeight or STYLE.tabBarHeight
        self.height = button.gseTabHeight
        normalizeClassicTab()
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end

    function widget:GetText()
        return button:GetText()
    end

    function widget:SetElvUIBackgroundShown(shown)
        button.GSEElvUIButtonChromeSuppressed = shown == false
        if shouldUseElvUISkin() then applyElvUIButtonSkin(button) else applyNormalAccentButtonText(button) end
    end

    function widget:SetSelected(selected)
        applySelected(selected)
    end

    applySelected(false)
    normalizeClassicTab()
    if GSE.Skin and GSE.Skin.Tab then GSE.Skin.Tab(button) end
    return widget
end

local function createLabel(typeName, fontObject)
    local isInteractive = typeName == "InteractiveLabel"
    local frame = isInteractive and CreateFrame("Button", nextName(typeName), UIParent) or
        CreateFrame("Frame", nextName(typeName), UIParent)
    frame:SetSize(200, 20)
    if isInteractive then
        frame:EnableMouse(true)
        frame:RegisterForClicks("AnyUp")
    end

    local text = frame:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
    text:SetPoint("TOPLEFT")
    text:SetPoint("BOTTOMRIGHT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    local widget = wrap(typeName, frame)
    widget.label = text
    widget.text = text
    frame.text = text

    if isInteractive then
        frame:SetScript("OnClick", function(_, button) widget:Fire("OnClick", button) end)
        frame:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        frame:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
        applyElvUITextButtonHover(frame)
    end

    function widget:SetText(value)
        text:SetText(textValue(value))
        local height = math.max(20, text:GetStringHeight() + 4)
        self.height = height
        frame:SetHeight(height)
    end

    function widget:GetText()
        return text:GetText()
    end

    function widget:SetFont(...)
        text:SetFont(...)
    end

    function widget:SetFontObject(font)
        text:SetFontObject(font)
    end

    function widget:SetJustifyH(value)
        text:SetJustifyH(value)
    end

    function widget:SetJustifyV(value)
        text:SetJustifyV(value)
    end

    function widget:SetColor(r, g, b, a)
        text:SetTextColor(r, g, b, a or 1)
    end

    return widget
end

local function createEditBox()
    local labelHeight = STYLE.labelHeight
    local frame = CreateFrame("Frame", nextName("EditBox"), UIParent)
    frame:SetSize(250, STYLE.controlHeight * 2)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetPoint("TOPRIGHT")
    label:SetHeight(labelHeight)
    label:SetJustifyH("LEFT")

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", STYLE.padSmall, -STYLE.labelControlOffset)
    editBox:SetPoint("RIGHT", -STYLE.padSmall, 0)
    editBox:SetHeight(STYLE.compactControlHeight)
    editBox:SetAutoFocus(false)

    local gseNativeSetNumeric = editBox.SetNumeric
    if gseNativeSetNumeric then
        function editBox:SetNumeric(value)
            gseNativeSetNumeric(self, value)
            self:SetJustifyH(value and "CENTER" or "LEFT")
        end
    end

    if shouldUseElvUISkin() then
        hideFrameTextures(editBox)
        ensureElvUIChrome(frame, "GSEElvUIEditChrome", editBox, ELVUI_SKIN.insetBg, ELVUI_SKIN.mutedBorder)
        label:SetTextColor(unpack(ELVUI_SKIN.fieldLabelText))
    elseif hasExternalSkinProvider() and GSE.Skin and GSE.Skin.PaintBodyText then
        -- External provider (EUI/ElvUI) is active. The label otherwise
        -- inherits GameFontNormalSmall's gold default, which clashes with
        -- the host UI's neutral text. Paint TEXT_WHITE so the label looks
        -- like every other EUI-panel label.
        GSE.Skin.PaintBodyText(label, 1, 1, 1, 1)
    end

    local widget = wrap("EditBox", frame)
    widget.label = label
    widget.editbox = editBox
    widget.editBox = editBox
    widget.labelHeight = labelHeight

    editBox:SetScript("OnTextChanged", function(self) widget:Fire("OnTextChanged", self:GetText()) end)
    editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); widget:Fire("OnEnterPressed", self:GetText()) end)
    editBox:SetScript("OnEditFocusLost", function(self) widget:Fire("OnEditFocusLost", self:GetText()) end)
    editBox:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    editBox:SetScript("OnLeave", function() widget:Fire("OnLeave") end)

    local function positionEditBox()
        editBox:ClearAllPoints()
        if widget.compactNoLabel then
            label:Hide()
            editBox:SetPoint("LEFT", frame, "LEFT", STYLE.padSmall, 0)
            editBox:SetPoint("RIGHT", frame, "RIGHT", -STYLE.padSmall, 0)
        else
            label:Show()
            editBox:SetPoint("TOPLEFT", STYLE.padSmall, -((widget.labelHeight or labelHeight) + (widget.labelBoxPadding or STYLE.labelBoxGap)))
            editBox:SetPoint("RIGHT", -STYLE.padSmall, 0)
        end
    end

    function widget:SetLabel(text)
        label:SetText(textValue(text))
    end

    function widget:SetLabelBoxPadding(padding)
        self.labelBoxPadding = tonumber(padding) or STYLE.labelBoxGap
        positionEditBox()
    end

    function widget:SetText(text)
        editBox:SetText(textValue(text))
    end

    function widget:GetText()
        return editBox:GetText()
    end

    function widget:SetFocus()
        editBox:SetFocus()
    end

    function widget:DisableButton()
    end

    function widget:SetCompactNoLabel(value)
        self.compactNoLabel = value and true or false
        positionEditBox()
    end

    function widget:SetNumeric(value)
        editBox:SetNumeric(value)
    end

    function widget:SetMaxLetters(value)
        editBox:SetMaxLetters(value)
    end

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        editBox:EnableMouse(not disabled)
        if disabled then
            editBox:SetTextColor(0.5, 0.5, 0.5)
        else
            editBox:SetTextColor(1, 1, 1)
        end
    end

    if GSE.Skin and GSE.Skin.EditBox then GSE.Skin.EditBox(editBox) end
    return widget
end

local function createMultiLineEditBox()
    local verticalOffset = STYLE.labelBoxGap
    local leftOffset = STYLE.padSmall
    local rightOffset = STYLE.padSmall
    local scrollBarReserve = STYLE.scrollBarReserve
    local labelHeight = STYLE.labelHeight
    local frame = CreateFrame("Frame", nextName("MultiLineEditBox"), UIParent)
    frame:SetSize(300, 180)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetPoint("TOPRIGHT")
    label:SetHeight(labelHeight)
    label:SetJustifyH("LEFT")

    local scrollBG = CreateFrame("Frame", nil, frame, frameTemplate)
    scrollBG:SetPoint("TOPLEFT", 0, -(labelHeight + verticalOffset))
    scrollBG:SetPoint("BOTTOMRIGHT", -scrollBarReserve, 0)
    scrollBG:EnableMouse(true)
    applyBackdrop(
        scrollBG,
        {bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1},
        {0.04, 0.04, 0.04, 0.85},
        {0.25, 0.25, 0.25, 1}
    )
    if shouldUseElvUISkin() then
        applyElvUIBackdrop(scrollBG, ELVUI_SKIN.insetBg, ELVUI_SKIN.mutedBorder)
        label:SetTextColor(unpack(ELVUI_SKIN.fieldLabelText))
    elseif hasExternalSkinProvider() and GSE.Skin then
        if GSE.Skin.PaintBodyText then GSE.Skin.PaintBodyText(label, 1, 1, 1, 1) end
        -- Pure black fill, NO inner EUI border — the outer panel's border
        -- already defines the editbox edge, and an additional accent
        -- border on scrollBG reads as a faint inner stripe.
        if scrollBG.SetBackdrop then
            scrollBG:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                insets = {left = 0, right = 0, top = 0, bottom = 0},
            })
            scrollBG:SetBackdropColor(0, 0, 0, 1)
        end
    end

    local scrollFrame = CreateFrame("ScrollFrame", nextName("MultiLineScroll"), frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", leftOffset, -verticalOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -rightOffset, verticalOffset)
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(260)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    scrollFrame:SetScrollChild(editBox)

    local widget = wrap("MultiLineEditBox", frame)
    widget.label = label
    widget.scrollBG = scrollBG
    widget.scrollFrame = scrollFrame
    widget.scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"] or scrollFrame.ScrollBar
    applyModernSlimScrollBar(widget.scrollBar, scrollBG, STYLE.scrollBarReserve - STYLE.padXL, 0, 0)
    widget.editBox = editBox
    widget.editbox = editBox
    widget.verticalOffset = verticalOffset
    widget.leftOffset = leftOffset
    widget.rightOffset = rightOffset
    widget.scrollBarReserve = scrollBarReserve
    widget.labelHeight = labelHeight

    local function updateEditBoxSize(width, height)
        width = width or widget.width or safeWidth(frame, 300)
        height = height or widget.height or safeHeight(frame, 180)
        editBox:SetWidth(math.max(40, width - scrollBarReserve - leftOffset - rightOffset - STYLE.padLarge))
        editBox:SetHeight(math.max(40, height - labelHeight - (verticalOffset * 3)))
    end

    local function focusEditBox()
        editBox:SetFocus()
    end

    scrollBG:SetScript("OnMouseDown", focusEditBox)
    scrollFrame:SetScript("OnMouseDown", focusEditBox)

    editBox:SetScript("OnTextChanged", function(self) widget:Fire("OnTextChanged", self:GetText()) end)
    editBox:SetScript("OnEditFocusLost", function(self) widget:Fire("OnEditFocusLost", self:GetText()) end)
    scrollFrame:SetScript(
        "OnMouseWheel",
        function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            local current = self:GetVerticalScroll() or 0
            local target = current - ((delta or 0) * SCROLL_STEP)
            self:SetVerticalScroll(math.min(math.max(target, 0), range))
        end
    )

    function widget:SetLabel(text)
        label:SetText(textValue(text))
    end

    function widget:SetText(text)
        editBox:SetText(textValue(text))
    end

    function widget:GetText()
        return editBox:GetText()
    end

    function widget:SetWidth(width)
        self.width = width
        frame:SetWidth(width)
        updateEditBoxSize(width, self.height)
    end

    function widget:SetHeight(height)
        self.height = height
        frame:SetHeight(height)
        updateEditBoxSize(self.width, height)
    end

    function widget:OnWidthSet(width)
        updateEditBoxSize(width, self.height)
    end

    function widget:OnHeightSet(height)
        updateEditBoxSize(self.width, height)
    end

    function widget:SetNumLines(lines)
        self:SetHeight(math.max(60, (lines or 4) * 16 + STYLE.frameContentTop))
    end

    function widget:DisableButton()
    end

    function widget:Insert(text)
        editBox:Insert(text)
    end

    function widget:SetFocus()
        editBox:SetFocus()
    end

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        editBox:EnableMouse(not disabled)
        editBox:SetTextColor(disabled and 0.5 or 1, disabled and 0.5 or 1, disabled and 0.5 or 1)
    end

    if GSE.Skin and GSE.Skin.EditBox then GSE.Skin.EditBox(editBox) end
    return widget
end

local function createCheckBox()
    local check = CreateFrame("CheckButton", nextName("CheckBox"), UIParent, "UICheckButtonTemplate")
    check:SetSize(STYLE.checkBoxSize, STYLE.checkBoxSize)
    local widget = wrap("CheckBox", check)
    widget.check = check:GetCheckedTexture()
    widget.checkbg = check
    widget.highlight = check:GetHighlightTexture()

    local text = _G[check:GetName() .. "Text"]
    widget.text = text
    check.text = text
    check.label = text
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", check, "RIGHT", 0, 0)
        text:SetJustifyV("MIDDLE")
    end

    check:SetScript("OnClick", function(self) widget:Fire("OnValueChanged", self:GetChecked()) end)
    check:SetScript("OnEnter", function(self) setElvUITextButtonHover(self, true); setElvUICheckBoxHover(self, true); widget:Fire("OnEnter") end)
    check:SetScript("OnLeave", function(self) setElvUITextButtonHover(self, false); setElvUICheckBoxHover(self, false); widget:Fire("OnLeave") end)
    applyElvUICheckBoxSkin(check, text)
    applyNormalAccentCheckBoxText(check, text)
    -- Under an external skin provider both apply* helpers above bail out,
    -- leaving the checkbox text at UICheckButtonTemplate's gold default.
    -- Paint TEXT_WHITE so the label matches the rest of the EUI panel.
    if hasExternalSkinProvider() and GSE.Skin and GSE.Skin.PaintBodyText then
        GSE.Skin.PaintBodyText(text, 1, 1, 1, 1)
    end

    function widget:SetLabel(value)
        text:SetText(textValue(value))
        if not self.disabled then applyNormalAccentCheckBoxText(check, text) end
        if hasExternalSkinProvider() and GSE.Skin and GSE.Skin.PaintBodyText then
            GSE.Skin.PaintBodyText(text, 1, 1, 1, 1)
        end
    end

    function widget:SetWidth(width)
        self.width = width
        check:SetWidth(self.height or check:GetHeight() or STYLE.checkBoxSize)
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end

    function widget:SetHeight(height)
        self.height = height
        check:SetSize(height, height)
        if self.parent and self.parent.DoLayout then self.parent:DoLayout() end
    end

    function widget:OnWidthSet()
        check:SetWidth(self.height or check:GetHeight() or STYLE.checkBoxSize)
    end

    function widget:SetValue(value)
        check:SetChecked(value)
    end

    function widget:GetValue()
        return check:GetChecked()
    end

    function widget:SetType(value)
        self.checkType = value or "checkbox"
    end

    function widget:SetTriState(value)
        self.tristate = value and true or false
    end

    function widget:SetText(value)
        self:SetLabel(value)
    end

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        if disabled then
            check:Disable()
            text:SetTextColor(0.5, 0.5, 0.5)
        else
            check:Enable()
            text:SetTextColor(1, 1, 1)
            applyNormalAccentCheckBoxText(check, text)
        end
    end

    if GSE.Skin and GSE.Skin.Checkbox then GSE.Skin.Checkbox(check) end
    return widget
end

local function createIcon()
    local button = CreateFrame("Button", nextName("Icon"), UIParent)
    button:SetSize(STYLE.defaultIconSize, STYLE.defaultIconSize)
    button:RegisterForClicks("AnyUp")
    local texture = button:CreateTexture(nil, "ARTWORK")
    local widget = wrap("Icon", button)
    widget.image = texture
    local normalImageWidth = STYLE.defaultIconSize
    local normalImageHeight = STYLE.defaultIconSize
    local hoverImageWidth
    local hoverImageHeight
    local hoverLocked = false
    local hovered = false
    local squareIcon = false

    local function setIconVisualSize(width, height)
        width = tonumber(width) or STYLE.defaultIconSize
        height = tonumber(height) or width

        if squareIcon then
            local size = math.min(width, height)
            width = size
            height = size
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        elseif button.GSESquareIconBackdrop then
            texture:SetTexCoord(0, 1, 0, 1)
        end

        texture:ClearAllPoints()
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        texture:SetSize(width, height)

        if squareIcon then
            if not button.GSESquareIconBackdrop then
                button.GSESquareIconBackdrop = button:CreateTexture(nil, "BACKGROUND")
                button.GSESquareIconBackdrop:SetColorTexture(0, 0, 0, 1)
            end
            button.GSESquareIconBackdrop:ClearAllPoints()
            button.GSESquareIconBackdrop:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.GSESquareIconBackdrop:SetSize(width, height)
            button.GSESquareIconBackdrop:Show()
        elseif button.GSESquareIconBackdrop then
            button.GSESquareIconBackdrop:Hide()
        end

        if button.gseAssetHighlight then
            button.gseAssetHighlight:ClearAllPoints()
            button.gseAssetHighlight:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.gseAssetHighlight:SetSize(width, height)
        end
    end

    local function refreshIconVisualSize()
        if hoverImageWidth and hoverImageHeight and not widget.disabled and (hovered or hoverLocked) then
            setIconVisualSize(hoverImageWidth, hoverImageHeight)
        else
            setIconVisualSize(normalImageWidth, normalImageHeight)
        end
    end
    refreshIconVisualSize()

    button:SetScript("OnClick", function(_, mouseButton) widget:Fire("OnClick", mouseButton) end)
    button:SetScript(
        "OnEnter",
        function()
            hovered = true
            refreshIconVisualSize()
            if shouldSubdueElvUIAssetIcon(button, button.GSELastIconPath) then
                button.GSEElvUISubduedIconMouseOver = true
                applyElvUIIconAssetSkin(button, texture, button.GSELastIconPath)
            end
            widget:Fire("OnEnter")
        end
    )
    button:SetScript(
        "OnLeave",
        function()
            hovered = false
            refreshIconVisualSize()
            if shouldSubdueElvUIAssetIcon(button, button.GSELastIconPath) then
                button.GSEElvUISubduedIconMouseOver = false
                applyElvUIIconAssetSkin(button, texture, button.GSELastIconPath)
            end
            widget:Fire("OnLeave")
        end
    )

    function widget:SetSquareIcon(enabled)
        squareIcon = enabled and true or false
        refreshIconVisualSize()
    end

    function widget:SetElvUIIconBackgroundShown(shown)
        button.GSEElvUIIconChromeSuppressed = shown == false
        if button.GSEElvUIIconChromeSuppressed and button.GSEElvUIIconChrome then
            button.GSEElvUIIconChrome:Hide()
        elseif shouldUseElvUISkin() then
            applyElvUIIconAssetSkin(button, texture, button.GSELastIconPath)
        end
    end

    function widget:SetElvUISubduedIcon(enabled)
        button.GSEElvUISubduedIcon = enabled and true or false
        if shouldUseElvUISkin() then
            applyElvUIIconAssetSkin(button, texture, button.GSELastIconPath)
        end
    end
    function widget:SetImage(path)
        button.GSELastIconPath = path
        texture:SetTexture(path)
        applyAssetHighlight(button, path)
        applyElvUIIconAssetSkin(button, texture, path)
        refreshIconVisualSize()
    end

    function widget:SetImageSize(width, height)
        normalImageWidth = tonumber(width) or normalImageWidth
        normalImageHeight = tonumber(height) or tonumber(width) or normalImageHeight
        button:SetSize(normalImageWidth, normalImageHeight)
        refreshIconVisualSize()
    end

    function widget:SetHoverImageSize(width, height)
        hoverImageWidth = tonumber(width)
        hoverImageHeight = tonumber(height) or tonumber(width)
        refreshIconVisualSize()
    end

    function widget:SetHoverLocked(locked)
        hoverLocked = locked and true or false
        refreshIconVisualSize()
    end

    function widget:SetText()
    end

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        button:EnableMouse(not disabled)
        texture:SetDesaturated(disabled and true or false)
        refreshIconVisualSize()
    end

    -- Skin.Icon's contract is (carrierFrame, iconTexture). ElvUI uses the
    -- texture (its HandleIcon calls SetTexCoord); EllesmereUI uses the
    -- frame (its skinFrame applies a SetBackdrop + NineSlice border, which
    -- only works on a real Frame, not a Texture). Pass both; the active
    -- provider's Icon entry picks the one it can use.
    if GSE.Skin and GSE.Skin.Icon then GSE.Skin.Icon(button, texture) end
    return widget
end

local function getScrollBar(scrollFrame)
    return _G[scrollFrame:GetName() .. "ScrollBar"] or scrollFrame.ScrollBar
end

local function createScrollFrame()
    local frame = CreateFrame("Frame", nextName("ScrollFrame"), UIParent)
    frame:SetSize(300, 220)

    local scrollFrame = CreateFrame("ScrollFrame", nextName("Scroll"), frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -STYLE.scrollBarReserve, 0)
    scrollFrame:EnableMouseWheel(true)
    if scrollFrame.SetClipsChildren then scrollFrame:SetClipsChildren(true) end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(260, 1)
    if content.SetClipsChildren then content:SetClipsChildren(true) end
    scrollFrame:SetScrollChild(content)

    local widget = wrap("ScrollFrame", frame)
    widget.content = content
    widget.scrollframe = scrollFrame
    widget.scrollbar = getScrollBar(scrollFrame)
    -- The scrollFrame above calls SetClipsChildren(true), which clips child rendering
    -- to its own rectangle. UIPanelScrollFrameTemplate parents its ScrollBar to the
    -- scrollFrame and anchors it just outside the right edge -- inside the
    -- scrollBarReserve gap -- so the bar is clipped to nothing and never appears.
    -- applyModernSlimScrollBar already reparents the bar out of the clip region, but it
    -- only runs under the modern / ElvUI skins (UseModernSkin defaults to false), so on
    -- the default Blizzard skin the bar stayed clipped and the editor's right-hand
    -- scrollbar was permanently hidden. Lift it out of the clip unconditionally here so
    -- the bar is visible on every skin, then let applyModernSlimScrollBar layer on the
    -- slim styling only when a themed skin is active.
    --
    -- On the default Blizzard skin the bar keeps its ScrollUp/ScrollDownButton,
    -- which UIPanelScrollFrameTemplate anchors just above the bar top and just
    -- below the bar bottom. With a zero bottom inset the down arrow overhangs the
    -- frame's bottom edge and is clipped by the editor window border (the reported
    -- "bottom scroll arrow hidden"). Inset the bar bottom by the arrow-button
    -- height so the down arrow sits inside the frame. Measure the real button
    -- (robust across client/skin) and fall back to STYLE.scrollArrowInset. The top
    -- is left flush: its up arrow already sits behind the editor header, and the
    -- modern / ElvUI path suppresses the arrow buttons and re-anchors flush (0,0)
    -- in applyModernSlimScrollBar below, so this inset is default-skin only.
    local arrowInset = STYLE.scrollArrowInset
    local downArrow = widget.scrollbar and (widget.scrollbar.ScrollDownButton
        or getNamedChild(widget.scrollbar, "ScrollDownButton"))
    if downArrow and downArrow.GetHeight then
        local downArrowHeight = downArrow:GetHeight()
        if downArrowHeight and downArrowHeight > 0 then arrowInset = downArrowHeight end
    end
    anchorModernSlimScrollBar(widget.scrollbar, frame, -STYLE.padXL, 0, arrowInset)
    applyModernSlimScrollBar(widget.scrollbar, frame, -STYLE.padXL, 0, 0)
    widget.localstatus = {scrollvalue = 0}
    widget.scrollBarShown = false
    widget.scrollBarEnabled = true

    local function scrollBarInset()
        return widget.scrollBarEnabled == false and 0 or -STYLE.scrollBarReserve
    end

    local function contentWidth(width)
        return math.max(1, (width or safeWidth(frame, widget.width or 300)) - (widget.scrollBarEnabled == false and 0 or STYLE.scrollBarVisibleReserve))
    end

    local function updateScrollFrameInset()
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", scrollBarInset(), 0)
    end

    local function getScrollRange()
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        local contentHeight = safeHeight(content, 1)
        local viewportHeight = safeHeight(scrollFrame, safeHeight(frame, 1))
        local manualRange = math.max(0, contentHeight - viewportHeight)
        local nativeRange = scrollFrame.GetVerticalScrollRange and (scrollFrame:GetVerticalScrollRange() or 0) or 0
        if nativeRange > 0 and manualRange > 0 then return math.min(nativeRange, manualRange) end
        return math.max(nativeRange, manualRange)
    end

    -- knownRange lets callers pass a scroll range they have already computed for
    -- the current gesture so the per-frame smooth-scroll pump does not re-run
    -- getScrollRange() -> scrollFrame:UpdateScrollChildRect() on every OnUpdate
    -- tick. Content size is fixed during a glide, so the gesture-start range is
    -- valid for the whole animation; recomputing it each frame was forcing two
    -- scroll-child-rect rebuilds per frame and made scrolling choppy on long
    -- sequences. knownRange is optional -- callers that may have just changed the
    -- content height (drag, SetScroll) omit it and a fresh range is computed.
    local function clampScrollPixels(value, knownRange)
        return math.min(math.max(value or 0, 0), knownRange or getScrollRange())
    end

    local function syncScrollbar(value, knownRange)
        if not widget.scrollbar then return end
        widget.noupdate = true
        widget.scrollbar:SetValue(clampScrollPixels(value, knownRange))
        widget.noupdate = nil
    end

    local function setScrollPixels(value, knownRange)
        local range = knownRange or getScrollRange()
        local target = math.min(math.max(value or 0, 0), range)
        local status = widget.status or widget.localstatus
        scrollFrame:SetVerticalScroll(target)
        status.scrollvalue = target
        syncScrollbar(target, range)
    end

    local function stopSmoothScroll()
        frame:SetScript("OnUpdate", nil)
        widget.scrollStart = nil
        widget.scrollTarget = nil
        widget.scrollElapsed = nil
    end

    local function smoothScrollTo(value)
        local range = getScrollRange()
        local target = math.min(math.max(value or 0, 0), range)
        local start = math.min(math.max(scrollFrame:GetVerticalScroll() or 0, 0), range)

        stopSmoothScroll()
        if math.abs(target - start) < 0.5 then
            setScrollPixels(target, range)
            return
        end

        widget.scrollStart = start
        widget.scrollTarget = target
        widget.scrollElapsed = 0
        -- range is captured once here and reused for every frame of the glide;
        -- the OnUpdate pump never calls getScrollRange()/UpdateScrollChildRect().
        frame:SetScript("OnUpdate", function(_, elapsed)
            widget.scrollElapsed = (widget.scrollElapsed or 0) + (elapsed or 0)
            local progress = math.min(widget.scrollElapsed / SCROLL_SMOOTH_DURATION, 1)
            local eased = 1 - ((1 - progress) * (1 - progress))
            setScrollPixels(widget.scrollStart + ((widget.scrollTarget - widget.scrollStart) * eased), range)
            if progress >= 1 then stopSmoothScroll() end
        end)
    end

    local function setScrollbarValue(value)
        if widget.noupdate then return end
        stopSmoothScroll()
        -- Dragging the thumb fires OnValueChanged every frame the mouse moves.
        -- The scrollbar's max value is kept equal to the scroll range by
        -- UpdateScroll, and content height does not change mid-drag, so reuse it
        -- as the known range instead of recomputing getScrollRange() ->
        -- scrollFrame:UpdateScrollChildRect() on every tick -- that per-tick
        -- layout rebuild is what made dragging the scrollbar laggy. The mouse
        -- wheel already avoids this via the gesture range cached in smoothScrollTo;
        -- the drag path was the one still rebuilding the child rect per tick.
        local knownRange
        if widget.scrollbar and widget.scrollbar.GetMinMaxValues then
            local _, maxVal = widget.scrollbar:GetMinMaxValues()
            if maxVal and maxVal > 0 then knownRange = maxVal end
        end
        setScrollPixels(value, knownRange)
    end

    if widget.scrollbar then
        widget.scrollbar:SetMinMaxValues(0, 0)
        widget.scrollbar:SetValueStep(1)
        widget.scrollbar:SetScript("OnValueChanged", function(_, value) setScrollbarValue(value) end)
    end

    scrollFrame:SetScript("OnMouseWheel", function(_, delta) widget:MoveScroll(delta) end)

    function widget:SetStatusTable(status)
        self.status = status
        if not status.scrollvalue then status.scrollvalue = 0 end
        self:UpdateScroll()
    end

    function widget:SetScroll(value)
        stopSmoothScroll()
        setScrollPixels(value)
    end

    function widget:SetScrollStep(value)
        self.scrollStep = tonumber(value) or nil
    end

    function widget:MoveScroll(delta)
        local range = getScrollRange()
        local status = self.status or self.localstatus
        if range <= 0 then
            scrollFrame:SetVerticalScroll(0)
            status.scrollvalue = 0
            syncScrollbar(0, range)
            return
        end
        local wheelDelta = delta or 0
        if wheelDelta > 0 then
            wheelDelta = 1
        elseif wheelDelta < 0 then
            wheelDelta = -1
        end
        -- Use the configured per-notch step directly. Earlier versions capped
        -- this to range/4 or range/10 "to prevent overshoot", but the smoothScroll
        -- target is already clamped to [0, range] downstream — so an oversized
        -- step just snaps to the edge gracefully and the user's slider value
        -- (from the Options panel) is honoured as-is. Without this, the slider
        -- silently had no effect on editors with small/moderate scroll ranges.
        local step = math.max(1, self.scrollStep or SCROLL_STEP)
        local current = math.min(math.max(scrollFrame:GetVerticalScroll() or 0, 0), range)
        local target = math.min(math.max(current - (wheelDelta * step), 0), range)
        smoothScrollTo(target)
    end

    function widget:UpdateScroll()
        content:SetWidth(contentWidth(safeWidth(frame, self.width or 300)))
        local range = getScrollRange()
        local status = self.status or self.localstatus

        local current = math.min(math.max(scrollFrame:GetVerticalScroll() or 0, 0), range)
        if current ~= (scrollFrame:GetVerticalScroll() or 0) then
            stopSmoothScroll()
            scrollFrame:SetVerticalScroll(current)
        end
        status.scrollvalue = current
        self.scrollBarShown = range > 0 and self.scrollBarEnabled ~= false
        if self.scrollbar then
            if range > 0 and self.scrollBarEnabled ~= false then
                self.scrollbar:SetMinMaxValues(0, range)
                syncScrollbar(status.scrollvalue, range)
                self.scrollbar:Show()
            else
                syncScrollbar(0, range)
                self.scrollbar:Hide()
            end
        end
    end

    function widget:SetScrollBarEnabled(enabled)
        self.scrollBarEnabled = enabled ~= false
        updateScrollFrameInset()
        self:UpdateScroll()
    end

    function widget:OnWidthSet(width)
        updateScrollFrameInset()
        content:SetWidth(contentWidth(width))
    end

    if GSE.Skin and GSE.Skin.ScrollBar then
        local sb = getScrollBar(scrollFrame)
        if sb then GSE.Skin.ScrollBar(sb) end
    end
    return widget
end

local function sortedKeys(list, order)
    if order then return order end
    local keys = {}
    for key in pairs(list or {}) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function createDropdown()
    local frame = CreateFrame("Frame", nextName("Dropdown"), UIParent)
    frame:SetSize(200, STYLE.controlHeight * 2)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetPoint("TOPRIGHT")
    label:SetJustifyH("LEFT")
    if shouldUseElvUISkin() then
        label:SetTextColor(unpack(ELVUI_SKIN.fieldLabelText))
    elseif hasExternalSkinProvider() and GSE.Skin and GSE.Skin.PaintBodyText then
        GSE.Skin.PaintBodyText(label, 1, 1, 1, 1)
    end

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", 0, -STYLE.labelControlOffset)
    button:SetPoint("RIGHT", 0, 0)
    button:SetHeight(STYLE.controlHeight)

    local widget = wrap("Dropdown", frame)
    widget.label = label
    widget.button = button
    widget.list = {}
    widget.order = {}
    widget.disabledItems = {}
    widget.buttonTextMap = {}
    widget.value = nil
    widget.multiselect = false
    widget.useDropdownList = false
    widget.maxVisibleItems = nil

    local function valueText()
        if widget.multiselect then
            local count = 0
            for _, selected in pairs(widget.value or {}) do
                if selected then count = count + 1 end
            end
            return count > 0 and (count .. " selected") or ""
        end
        return widget.buttonTextMap[widget.value] or widget.list[widget.value] or widget.value or ""
    end

    local refreshNativeDropdown

    local function refresh()
        button:SetText(textValue(valueText()))
        applyNormalAccentButtonText(button)
        if refreshNativeDropdown then refreshNativeDropdown() end
        if widget.RefreshDropdownList then widget:RefreshDropdownList() end
    end

    local function positionDropdownStyle(compact)
        button:Show()
        button:EnableMouse(true)
        button:ClearAllPoints()

        if compact then
            label:Hide()
            frame:SetHeight(STYLE.controlHeight)
            widget.height = STYLE.controlHeight
            widget.explicitHeight = true
            button:SetPoint("LEFT", frame, "LEFT", -10, 0)
            button:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            button:SetHeight(STYLE.compactControlHeight)
        else
            label:Show()
            frame:SetHeight(widget.height or (STYLE.controlHeight * 2))
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -STYLE.labelControlOffset)
            button:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            button:SetHeight(STYLE.controlHeight)
        end

        if widget.nativeDropdown then
            widget.nativeDropdown:Hide()
            widget.nativeDropdown:EnableMouse(false)
        end
    end

    local function applyDropdownStyle(compact)
        if widget.customDropdownStyleApplied then
            positionDropdownStyle(compact)
            return
        end
        widget.customDropdownStyleApplied = true
        widget.dropdownStyleApplied = true

        positionDropdownStyle(compact)

        if button.Left then button.Left:Hide() end
        if button.Middle then button.Middle:Hide() end
        if button.Right then button.Right:Hide() end

        local chrome = CreateFrame("Frame", nil, frame, frameTemplate)
        chrome:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -STYLE.padTiny)
        chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, STYLE.padTiny)
        if chrome.SetFrameLevel and button.GetFrameLevel then
            chrome:SetFrameLevel(math.max(0, (button:GetFrameLevel() or 1) - 1))
        end
        applyBackdrop(
            chrome,
            shouldUseElvUISkin() and ELVUI_SKIN.backdrop or {
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = {left = STYLE.padXXS, right = STYLE.padXXS, top = STYLE.padXXS, bottom = STYLE.padXXS}
            },
            shouldUseElvUISkin() and ELVUI_SKIN.buttonBg or {0, 0, 0, 0.86},
            shouldUseElvUISkin() and getElvUIBorderColor(ELVUI_SKIN.mutedBorder) or {0.62, 0.62, 0.62, 1}
        )
        button.dropdownChrome = chrome

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", STYLE.padInset, -STYLE.padInset)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -STYLE.padInset, STYLE.padInset)
        highlight:SetColorTexture(1, 1, 1, 0.08)
        button:SetHighlightTexture(highlight)

        local arrow = CreateFrame("Button", nil, frame)
        arrow:SetSize(STYLE.dropdownArrowSize, STYLE.dropdownArrowSize)
        arrow:SetPoint("RIGHT", button, "RIGHT", 0, 0)
        arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        arrow:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        arrow:SetScript("OnClick", function() button:Click() end)
        arrow:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        arrow:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
        button.dropdownArrow = arrow

        local text = button:GetFontString()
        if text then
            text:ClearAllPoints()
            text:SetPoint("LEFT", button, "LEFT", STYLE.padLarge, 0)
            text:SetPoint("RIGHT", arrow, "LEFT", -STYLE.padXXS, 0)
            text:SetJustifyH("LEFT")
            applyNormalAccentButtonText(button)
        end
    end

    local function choose(key)
        if widget.disabledItems[key] then return end
        if widget.multiselect then
            widget.value = widget.value or {}
            widget.value[key] = not widget.value[key]
            refresh()
            widget:Fire("OnValueChanged", key, widget.value[key])
        else
            widget.value = key
            refresh()
            widget:Fire("OnValueChanged", key)
        end
    end

    local function nativeDropdownWidth()
        local width = widget.width or safeWidth(frame, 200)
        return math.max(40, width - 40)
    end

    local function nativeDropdownMenuAnchor()
        if not widget.nativeDropdown then return nil end
        return widget.nativeDropdown.Button or _G[widget.nativeDropdown:GetName() .. "Button"] or widget.nativeDropdown
    end

    local function anchorNativeDropdownMenu()
        if not widget.nativeDropdown then return end
        local anchor = nativeDropdownMenuAnchor()
        if UIDropDownMenu_SetAnchor then
            UIDropDownMenu_SetAnchor(widget.nativeDropdown, 0, -STYLE.padXXS, "TOPRIGHT", anchor, "BOTTOMRIGHT")
        else
            widget.nativeDropdown.xOffset = 0
            widget.nativeDropdown.yOffset = -STYLE.padXXS
            widget.nativeDropdown.point = "TOPRIGHT"
            widget.nativeDropdown.relativeTo = anchor
            widget.nativeDropdown.relativePoint = "BOTTOMRIGHT"
        end
    end

    local function setNativeDropdownTextureAlpha(nativeDropdown, alpha)
        if not nativeDropdown then return end
        local name = nativeDropdown.GetName and nativeDropdown:GetName()
        if not name then return end

        for _, suffix in ipairs({"Left", "Middle", "Right"}) do
            local texture = _G[name .. suffix]
            if texture and texture.SetAlpha then texture:SetAlpha(alpha) end
        end
    end

    local ELVUI_DROPDOWN_CHEVRON = "Interface\\AddOns\\GSE_GUI\\Assets\\down-chevron.png"

    local function setNativeDropdownArrowTextureAlpha(arrowButton, alpha)
        if not arrowButton then return end
        local textures = {
            arrowButton.GetNormalTexture and arrowButton:GetNormalTexture(),
            arrowButton.GetPushedTexture and arrowButton:GetPushedTexture(),
            arrowButton.GetDisabledTexture and arrowButton:GetDisabledTexture(),
            arrowButton.GetHighlightTexture and arrowButton:GetHighlightTexture()
        }

        for _, texture in ipairs(textures) do
            if texture and texture.SetAlpha then texture:SetAlpha(alpha) end
        end
    end

    local function applyNativeDropdownArrow(arrowButton, elvui)
        setNativeDropdownArrowTextureAlpha(arrowButton, elvui and 0 or 1)
        if not arrowButton then return end

        if not elvui then
            if arrowButton.GSEElvUIDropdownChevron then arrowButton.GSEElvUIDropdownChevron:Hide() end
            return
        end

        local chevron = arrowButton.GSEElvUIDropdownChevron
        if not chevron then
            chevron = arrowButton:CreateTexture(nil, "OVERLAY")
            arrowButton.GSEElvUIDropdownChevron = chevron
        end

        chevron:SetTexture(ELVUI_DROPDOWN_CHEVRON)
        chevron:ClearAllPoints()
        chevron:SetPoint("CENTER", arrowButton, "CENTER", 0, 0)
        chevron:SetSize(14, 14)
        chevron:SetVertexColor(1, 1, 1, 1)
        chevron:SetAlpha(1)
        chevron:Show()
    end

    local function positionElvUINativeDropdownChrome(compact)
        if not widget.nativeDropdown then return end

        local nativeDropdown = widget.nativeDropdown
        local arrowButton = nativeDropdownMenuAnchor()
        local useElvUI = shouldUseElvUISkin()
        setNativeDropdownTextureAlpha(nativeDropdown, useElvUI and 0 or 1)
        applyNativeDropdownArrow(arrowButton, useElvUI)

        if not useElvUI then
            if widget.nativeDropdownChrome then widget.nativeDropdownChrome:Hide() end
            return
        end

        local chrome = widget.nativeDropdownChrome
        if not chrome then
            chrome = CreateFrame("Frame", nil, frame, frameTemplate)
            chrome:EnableMouse(false)
            widget.nativeDropdownChrome = chrome
        end

        chrome:ClearAllPoints()
        if compact then
            chrome:SetPoint("LEFT", frame, "LEFT", 0, 0)
            chrome:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            chrome:SetHeight(STYLE.compactControlHeight)
        else
            chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -STYLE.labelControlOffset)
            chrome:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            chrome:SetHeight(STYLE.controlHeight)
        end
        if chrome.SetFrameLevel and nativeDropdown.GetFrameLevel then
            chrome:SetFrameLevel(math.max(0, (nativeDropdown:GetFrameLevel() or 1) - 1))
        end
        applyElvUIBackdrop(chrome, ELVUI_SKIN.buttonBg, ELVUI_SKIN.mutedBorder)
        chrome:Show()

        local name = nativeDropdown.GetName and nativeDropdown:GetName()
        local text = name and (_G[name .. "Text"] or _G[name .. "Text"]) or nil
        if text then
            text:ClearAllPoints()
            text:SetPoint("LEFT", chrome, "LEFT", STYLE.padLarge, 0)
            text:SetPoint("RIGHT", chrome, "RIGHT", -STYLE.dropdownArrowSize - STYLE.padLarge, 0)
            text:SetJustifyH("LEFT")
            if text.SetTextColor then text:SetTextColor(unpack(getElvUITextColor())) end
        end

        if arrowButton then
            arrowButton:ClearAllPoints()
            arrowButton:SetPoint("RIGHT", chrome, "RIGHT", -STYLE.padSmall, 0)
            arrowButton:SetSize(STYLE.dropdownArrowSize, STYLE.dropdownArrowSize)
        end
    end

    local function positionNativeDropdown(compact)
        if not widget.nativeDropdown then return end
        widget.nativeDropdown:ClearAllPoints()
        if compact then
            label:Hide()
            frame:SetHeight(STYLE.controlHeight)
            widget.height = STYLE.controlHeight
            widget.explicitHeight = true
            widget.nativeDropdown:SetPoint("LEFT", frame, "LEFT", -16, -1)
        else
            label:Show()
            frame:SetHeight(widget.height or (STYLE.controlHeight * 2))
            widget.nativeDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", -16, -16)
        end
        UIDropDownMenu_SetWidth(widget.nativeDropdown, nativeDropdownWidth())
        anchorNativeDropdownMenu()
        positionElvUINativeDropdownChrome(compact)
    end

    local function applyNativeDropdownStyle(compact)
        if not (UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and UIDropDownMenu_SetWidth) then
            return false
        end
        if widget.nativeDropdownStyleApplied then
            positionNativeDropdown(compact)
            return true
        end

        widget.nativeDropdownStyleApplied = true
        widget.dropdownStyleApplied = true
        widget.useNativeDropdown = true

        button:Hide()
        button:EnableMouse(false)

        local nativeDropdown = CreateFrame("Frame", nextName("BlizzardDropdown"), frame, "UIDropDownMenuTemplate")
        nativeDropdown:SetHeight(STYLE.controlHeight)
        if UIDropDownMenu_JustifyText then UIDropDownMenu_JustifyText(nativeDropdown, "LEFT") end

        UIDropDownMenu_Initialize(
            nativeDropdown,
            function(_, level)
                for _, key in ipairs(widget.order or {}) do
                    local itemKey = key
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = textValue(widget.list[itemKey] or tostring(itemKey))
                    info.disabled = widget.disabledItems[itemKey] and true or false
                    if widget.multiselect then
                        info.checked = widget.value and widget.value[itemKey] and true or false
                        info.keepShownOnClick = true
                    else
                        info.checked = widget.value == itemKey
                    end
                    info.func = function()
                        choose(itemKey)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        )

        widget.nativeDropdown = nativeDropdown
        positionNativeDropdown(compact)
        refreshNativeDropdown = function()
            if widget.nativeDropdown and UIDropDownMenu_SetText then
                UIDropDownMenu_SetText(widget.nativeDropdown, textValue(valueText()))
            end
        end
        refreshNativeDropdown()
        return true
    end

    local function hideDropdownList()
        if widget.listFrame then widget.listFrame:Hide() end
        if widget.dropdownDismissFrame then widget.dropdownDismissFrame:Hide() end
        if activeDropdownList == widget then activeDropdownList = nil end
    end

    local function ensureDropdownDismissFrame()
        if widget.dropdownDismissFrame then return widget.dropdownDismissFrame end

        local dismissFrame = CreateFrame("Button", nextName("DropdownDismiss"), UIParent)
        dismissFrame:SetAllPoints(UIParent)
        UI.MakePopup(dismissFrame, {toplevel = false, clamp = false})
        dismissFrame:EnableMouse(true)
        dismissFrame:RegisterForClicks("AnyUp")
        dismissFrame:SetScript("OnClick", hideDropdownList)
        dismissFrame:SetScript("OnMouseWheel", hideDropdownList)
        dismissFrame:Hide()

        widget.dropdownDismissFrame = dismissFrame
        return dismissFrame
    end

    local function setDropdownListScroll(scrollFrame, offset)
        if not scrollFrame then return end

        local maxScroll = scrollFrame.maxScroll or 0
        offset = math.max(0, math.min(maxScroll, offset or 0))
        scrollFrame:SetVerticalScroll(offset)

        local scrollBar = scrollFrame.scrollBar
        if scrollBar and scrollBar.GetValue and scrollBar.SetValue and scrollBar:GetValue() ~= offset then
            scrollBar:SetValue(offset)
        end
    end

    local function ensureDropdownList()
        if widget.listFrame then return widget.listFrame end

        local listFrame = CreateFrame("Frame", nextName("DropdownList"), UIParent, frameTemplate)
        UI.MakePopup(listFrame)
        listFrame:EnableMouse(true)
        applyBackdrop(
            listFrame,
            shouldUseElvUISkin() and ELVUI_SKIN.backdrop or {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = {left = 11, right = 12, top = 12, bottom = 11}
            },
            shouldUseElvUISkin() and ELVUI_SKIN.insetBg or {0, 0, 0, 0.95},
            shouldUseElvUISkin() and getElvUIBorderColor(ELVUI_SKIN.border) or {1, 1, 1, 1}
        )
        listFrame.buttons = {}

        local scrollFrame = CreateFrame("ScrollFrame", nextName("DropdownScroll"), listFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:EnableMouseWheel(true)

        local content = CreateFrame("Frame", nextName("DropdownContent"), scrollFrame)
        content:SetPoint("TOPLEFT")
        content:SetSize(1, 1)
        scrollFrame:SetScrollChild(content)

        local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"] or scrollFrame.ScrollBar
        applyModernSlimScrollBar(scrollBar, listFrame, -STYLE.dropdownListInset, STYLE.dropdownListInset, STYLE.dropdownListInset)
        if scrollBar then scrollBar:Hide() end
        scrollFrame.scrollBar = scrollBar

        scrollFrame:SetScript(
            "OnMouseWheel",
            function(self, delta)
                local maxScroll = self.maxScroll or 0
                if maxScroll <= 0 then return end
                local rowHeight = self.rowHeight or STYLE.compactControlHeight
                local current = self:GetVerticalScroll() or 0
                setDropdownListScroll(self, current - (delta * rowHeight * 3))
            end
        )

        listFrame.scrollFrame = scrollFrame
        listFrame.scrollContent = content
        listFrame.scrollBar = scrollBar
        if scrollBar then
            scrollBar.scrollFrame = scrollFrame
            scrollBar:SetScript(
                "OnValueChanged",
                function(self, value)
                    if self.scrollFrame then self.scrollFrame:SetVerticalScroll(value or 0) end
                end
            )
        end
        listFrame:Hide()

        widget.listFrame = listFrame
        return listFrame
    end

    local function refreshDropdownList()
        if not widget.useDropdownList then return end

        local listFrame = ensureDropdownList()
        local rowHeight = STYLE.dropdownListRowHeight
        local order = widget.order or {}
        local maxVisibleItems = tonumber(widget.maxVisibleItems)
        local visibleCount = maxVisibleItems and math.min(#order, math.max(1, maxVisibleItems)) or #order
        local needsScroll = maxVisibleItems and #order > visibleCount
        local scrollbarReserve = needsScroll and STYLE.dropdownListScrollReserve or 0
        local listInset = maxVisibleItems and STYLE.dropdownListScrollInset or STYLE.dropdownListInset
        if not widget.dropdownMeasureText then
            widget.dropdownMeasureText = UIParent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        end
        local maxTextWidth = 0
        for _, key in ipairs(order) do
            widget.dropdownMeasureText:SetText(textValue(widget.list[key] or tostring(key)))
            maxTextWidth = math.max(maxTextWidth, widget.dropdownMeasureText:GetStringWidth() or 0)
        end
        local width = math.min(
            safeWidth(frame, widget.width or 200),
            math.max(170, math.ceil(maxTextWidth) + 54 + scrollbarReserve)
        )
        local anchor = (widget.nativeDropdown and nativeDropdownMenuAnchor()) or button.dropdownArrow or button
        local contentHeight = math.max(1, #order * rowHeight)
        local viewportHeight = math.max(1, visibleCount * rowHeight)

        listFrame:ClearAllPoints()
        listFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -STYLE.padXXS)
        listFrame:SetWidth(width)
        listFrame:SetHeight(math.max(1, viewportHeight + (listInset * 2)))
        listFrame:SetFrameLevel(math.max(20, button:GetFrameLevel() + 20))

        listFrame.scrollFrame:ClearAllPoints()
        listFrame.scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", listInset, -listInset)
        listFrame.scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -listInset - scrollbarReserve, listInset)
        listFrame.scrollFrame.rowHeight = rowHeight
        listFrame.scrollFrame.maxScroll = math.max(0, contentHeight - viewportHeight)
        listFrame.scrollContent:SetSize(math.max(1, width - (listInset * 2) - scrollbarReserve), contentHeight)
        if listFrame.scrollBar then
            applyModernSlimScrollBar(listFrame.scrollBar, listFrame, -listInset, listInset, listInset)
            listFrame.scrollBar:SetMinMaxValues(0, listFrame.scrollFrame.maxScroll)
            if listFrame.scrollBar.SetValueStep then listFrame.scrollBar:SetValueStep(rowHeight) end
            if listFrame.scrollBar.SetStepsPerPage then listFrame.scrollBar:SetStepsPerPage(math.max(1, visibleCount - 1)) end
            if needsScroll then
                listFrame.scrollBar:Show()
            else
                listFrame.scrollBar:SetValue(0)
                listFrame.scrollBar:Hide()
            end
        end

        local selectedIndex
        for index, key in ipairs(order) do
            local row = listFrame.buttons[index]
            if not row then
                local rowName = nextName("DropdownListButton")
                local ok, nativeRow = pcall(
                    CreateFrame,
                    "Button",
                    rowName,
                    listFrame.scrollContent,
                    "UIDropDownMenuButtonTemplate"
                )
                row = ok and nativeRow or CreateFrame("Button", rowName, listFrame.scrollContent)
                row:SetHeight(rowHeight)
                row.text = _G[rowName .. "NormalText"] or row:GetFontString()
                row.check = _G[rowName .. "Check"]
                row.uncheck = _G[rowName .. "UnCheck"]

                if not row.text then
                    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                end
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", row, "LEFT", STYLE.dropdownTextLeft, STYLE.padTiny)
                row.text:SetPoint("RIGHT", row, "RIGHT", -STYLE.pad, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)

                if not row.check then
                    row.check = row:CreateTexture(nil, "ARTWORK")
                    row.check:SetSize(STYLE.dropdownCheckSize, STYLE.dropdownCheckSize)
                    row.check:SetPoint("LEFT", row, "LEFT", STYLE.padSmall, 0)
                    row.check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
                    row.check:SetTexCoord(0, 0.5, 0.5, 1)
                end

                if not row.uncheck then
                    row.uncheck = row:CreateTexture(nil, "ARTWORK")
                    row.uncheck:SetSize(STYLE.dropdownCheckSize, STYLE.dropdownCheckSize)
                    row.uncheck:SetPoint("LEFT", row, "LEFT", STYLE.padSmall, 0)
                    row.uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
                    row.uncheck:SetTexCoord(0.5, 1, 0.5, 1)
                end

                row:SetScript("OnEnter", nil)
                row:SetScript("OnLeave", nil)

                listFrame.buttons[index] = row
            end

            local rowKey = key
            local selected =
                (widget.multiselect and widget.value and widget.value[rowKey]) or
                (not widget.multiselect and widget.value == rowKey)
            if selected then selectedIndex = index end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listFrame.scrollContent, "TOPLEFT", 0, -((index - 1) * rowHeight))
            row:SetPoint("TOPRIGHT", listFrame.scrollContent, "TOPRIGHT", 0, -((index - 1) * rowHeight))
            if row.SetText then row:SetText(textValue(widget.list[rowKey] or tostring(rowKey))) end
            row.text:SetText(textValue(widget.list[rowKey] or tostring(rowKey)))
            row.check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
            row.check:SetSize(STYLE.dropdownCheckSize, STYLE.dropdownCheckSize)
            row.check:ClearAllPoints()
            row.check:SetPoint("LEFT", row, "LEFT", STYLE.padSmall, 0)
            row.check:SetTexCoord(0, 0.5, 0.5, 1)
            row.uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
            row.uncheck:SetSize(STYLE.dropdownCheckSize, STYLE.dropdownCheckSize)
            row.uncheck:ClearAllPoints()
            row.uncheck:SetPoint("LEFT", row, "LEFT", STYLE.padSmall, 0)
            row.uncheck:SetTexCoord(0.5, 1, 0.5, 1)
            if selected then
                row.check:Show()
                row.uncheck:Hide()
            else
                row.check:Hide()
                row.uncheck:Show()
            end
            if widget.disabledItems[rowKey] then
                row:Disable()
                row.text:SetTextColor(0.45, 0.45, 0.45, 1)
                row.check:SetVertexColor(0.45, 0.45, 0.45, 1)
                row.uncheck:SetVertexColor(0.45, 0.45, 0.45, 1)
            else
                row:Enable()
                row.check:SetVertexColor(1, 1, 1, 1)
                row.uncheck:SetVertexColor(1, 1, 1, 1)
                if selected then
                    if shouldUseElvUISkin() then
                        row.text:SetTextColor(unpack(ELVUI_SKIN.accentText))
                    else
                        row.text:SetTextColor(1, 0.82, 0, 1)
                    end
                else
                    row.text:SetTextColor(1, 1, 1, 1)
                end
            end
            row:SetScript(
                "OnClick",
                function()
                    choose(rowKey)
                    if not widget.multiselect then hideDropdownList() end
                end
            )
            row:Show()
        end

        for index = #order + 1, #listFrame.buttons do
            listFrame.buttons[index]:Hide()
        end

        if listFrame.scrollFrame.UpdateScrollChildRect then listFrame.scrollFrame:UpdateScrollChildRect() end
        if not needsScroll then
            setDropdownListScroll(listFrame.scrollFrame, 0)
        else
            local currentScroll = listFrame.scrollFrame:GetVerticalScroll() or 0
            if selectedIndex then
                local selectedTop = (selectedIndex - 1) * rowHeight
                local selectedBottom = selectedTop + rowHeight
                if selectedTop < currentScroll then
                    currentScroll = selectedTop
                elseif selectedBottom > currentScroll + viewportHeight then
                    currentScroll = selectedBottom - viewportHeight
                end
            end
            currentScroll = math.max(0, math.min(listFrame.scrollFrame.maxScroll, currentScroll))
            setDropdownListScroll(listFrame.scrollFrame, currentScroll)
        end
    end

    local function showDropdownList()
        if CloseDropDownMenus then CloseDropDownMenus() end
        if activeDropdownList and activeDropdownList ~= widget and activeDropdownList.HideDropdownList then
            activeDropdownList:HideDropdownList()
        end
        activeDropdownList = widget
        refreshDropdownList()
        if widget.listFrame then
            local dismissFrame = ensureDropdownDismissFrame()
            dismissFrame:SetFrameLevel(math.max(1, (widget.listFrame:GetFrameLevel() or 20) - 1))
            dismissFrame:Show()
            widget.listFrame:Show()
        end
    end

    local function toggleDropdownList()
        if widget.listFrame and widget.listFrame:IsShown() then
            hideDropdownList()
        else
            showDropdownList()
        end
    end

    local function installNativeDropdownOverlay()
        if not widget.nativeDropdown then return end

        local overlay = widget.dropdownClickOverlay
        if not overlay then
            overlay = CreateFrame("Button", nextName("DropdownClickOverlay"), frame)
            widget.dropdownClickOverlay = overlay
        end

        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", widget.nativeDropdown, "TOPLEFT", 0, 0)
        overlay:SetPoint("BOTTOMRIGHT", widget.nativeDropdown, "BOTTOMRIGHT", 0, 0)
        if overlay.SetFrameLevel and widget.nativeDropdown.GetFrameLevel then
            overlay:SetFrameLevel((widget.nativeDropdown:GetFrameLevel() or frame:GetFrameLevel()) + 30)
        end
        overlay:EnableMouse(true)
        overlay:RegisterForClicks("LeftButtonUp")
        overlay:SetScript(
            "OnMouseDown",
            function()
                if CloseDropDownMenus then CloseDropDownMenus() end
            end
        )
        overlay:SetScript(
            "OnClick",
            function()
                if widget.disabled then return end
                if CloseDropDownMenus then CloseDropDownMenus() end
                toggleDropdownList()
            end
        )
        overlay:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
        overlay:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
        overlay:Show()
    end

    button:SetScript(
        "OnClick",
        function()
            if widget.disabled then return end
            if widget.useDropdownList then
                toggleDropdownList()
                return
            end
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(
                    button,
                    function(ownerRegion, rootDescription)
                        if label:GetText() and label:GetText() ~= "" then
                            rootDescription:CreateTitle(label:GetText())
                        end
                        for _, key in ipairs(widget.order or {}) do
                            local text = widget.list[key] or tostring(key)
                            if widget.disabledItems[key] then
                                local item = rootDescription:CreateButton(text, function() end)
                                if item.SetEnabled then item:SetEnabled(false) end
                            elseif widget.multiselect then
                                local checked = widget.value and widget.value[key]
                                local item = rootDescription:CreateCheckbox(text, function() return checked end, function() choose(key) end)
                                if item and item.SetIsSelected then item:SetIsSelected(checked and true or false) end
                            else
                                rootDescription:CreateButton(text, function() choose(key) end)
                            end
                        end
                    end
                )
            else
                -- Fallback when the dropdown menu API is unavailable: select the
                -- first configured option.
                local firstKey = (widget.order or {})[1]
                if firstKey ~= nil then choose(firstKey) end
            end
        end
    )
    button:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    button:SetScript("OnLeave", function() widget:Fire("OnLeave") end)
    frame:SetScript("OnHide", hideDropdownList)

    function widget:SetLabel(text)
        label:SetText(textValue(text))
    end

    function widget:SetList(list, order)
        self.list = list or {}
        self.order = sortedKeys(self.list, order)
        refresh()
    end

    function widget:SetButtonTextMap(map)
        self.buttonTextMap = map or {}
        refresh()
    end

    function widget:SetDropdownStyle(value)
        if value then
            self.useDropdownList = false
            if applyNativeDropdownStyle(true) then
                if self.maxVisibleItems then
                    self.useDropdownList = true
                    installNativeDropdownOverlay()
                end
            else
                self.useDropdownList = true
                applyDropdownStyle(true)
            end
        else
            self.useDropdownList = false
            hideDropdownList()
            if self.dropdownClickOverlay then self.dropdownClickOverlay:Hide() end
            if self.nativeDropdown then positionNativeDropdown(false) end
        end
    end

    function widget:OnWidthSet()
        if self.nativeDropdown then
            UIDropDownMenu_SetWidth(self.nativeDropdown, nativeDropdownWidth())
        end
        if self.listFrame and self.listFrame:IsShown() then
            refreshDropdownList()
        end
    end

    function widget:RefreshDropdownList()
        refreshDropdownList()
    end

    function widget:HideDropdownList()
        hideDropdownList()
    end

    function widget:SetMaxVisibleItems(value)
        local count = tonumber(value)
        self.maxVisibleItems = count and count > 0 and count or nil
        if self.maxVisibleItems then
            self.useDropdownList = true
            if applyNativeDropdownStyle(false) then
                installNativeDropdownOverlay()
            else
                applyDropdownStyle(false)
            end
        elseif self.dropdownClickOverlay then
            self.dropdownClickOverlay:Hide()
        end
        refresh()
    end

    function widget:AddItem(key, text)
        if key == nil then return end
        self.list[key] = text or tostring(key)
        self.order = self.order or {}
        for _, existing in ipairs(self.order) do
            if existing == key then
                refresh()
                return
            end
        end
        table.insert(self.order, key)
        refresh()
    end

    function widget:SetValue(value, checked)
        if self.multiselect then
            if type(value) == "table" then
                self.value = value
            elseif checked ~= nil then
                self.value = self.value or {}
                self.value[value] = checked
            else
                self.value = self.value or {}
                self.value[value] = true
            end
        else
            self.value = value
        end
        refresh()
    end

    function widget:GetValue()
        return self.value
    end

    function widget:SetMultiselect(value)
        self.multiselect = value and true or false
        if self.multiselect and type(self.value) ~= "table" then
            self.value = {}
        end
        refresh()
    end

    function widget:SetItemDisabled(key, disabled)
        self.disabledItems[key] = disabled
    end

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        if disabled then button:Disable() else button:Enable() end
        if self.nativeDropdown then
            if disabled and UIDropDownMenu_DisableDropDown then
                UIDropDownMenu_DisableDropDown(self.nativeDropdown)
            elseif not disabled and UIDropDownMenu_EnableDropDown then
                UIDropDownMenu_EnableDropDown(self.nativeDropdown)
            end
        end
    end

    -- Try Blizzard native dropdown first; fall back to custom implementation when
    -- UIDropDownMenu_* globals are absent (Retail 11.x+ removed them).
    if not applyNativeDropdownStyle(false) then
        applyDropdownStyle(false)
    end
    if GSE.Skin and GSE.Skin.Dropdown then GSE.Skin.Dropdown(frame) end
    return widget
end

local function createTabGroup()
    local frame = CreateFrame("Frame", nextName("TabGroup"), UIParent)
    frame:SetSize(300, 220)

    local tabbar = CreateFrame("Frame", nil, frame)
    tabbar:SetPoint("TOPLEFT")
    tabbar:SetPoint("TOPRIGHT")
    tabbar:SetHeight(STYLE.tabBarHeight)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -STYLE.tabContentOffset)
    content:SetPoint("BOTTOMRIGHT")
    if content.SetClipsChildren then content:SetClipsChildren(true) end

    local widget = wrap("TabGroup", frame)
    widget.tabbar = tabbar
    widget.content = content
    widget.tabs = {}
    widget.tabButtons = {}

    local function refreshButtons()
        for _, button in ipairs(widget.tabButtons) do button:Hide() end
        local previous
        for index, tab in ipairs(widget.tabs or {}) do
            local button = widget.tabButtons[index]
            if not button then
                button = CreateFrame("Button", nextName("TabButton"), tabbar, "UIPanelButtonTemplate")
                button:SetHeight(STYLE.controlHeight)
                widget.tabButtons[index] = button
            end
            button.value = tab.value
            button:SetText(textValue(tab.text or tab.value))
            button:SetWidth(math.max(80, button:GetFontString():GetStringWidth() + 24))
            -- TabButton hover text growth is ElvUI-only and has no effect without a font string.
            applyElvUITextButtonHover(button)
            applyNormalAccentButtonText(button)
            button:ClearAllPoints()
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", STYLE.padSmall, 0)
            else
                button:SetPoint("TOPLEFT", tabbar, "TOPLEFT", 0, -STYLE.padXXS)
            end
            button:SetScript("OnClick", function(self) widget:SelectTab(self.value) end)
            if tab.value == widget.selected then
                button:Disable()
            else
                button:Enable()
            end
            button:Show()
            previous = button
        end
    end

    function widget:SetTabs(tabs)
        self.tabs = tabs or {}
        refreshButtons()
    end

    function widget:SelectTab(value)
        self.selected = value
        refreshButtons()
        self:Fire("OnGroupSelected", value)
    end

    function widget:OnWidthSet(width)
        content:SetWidth(width)
    end

    function widget:OnHeightSet(height)
        content:SetHeight(math.max(1, height - STYLE.tabContentOffset))
    end

    if GSE.Skin and GSE.Skin.Frame then GSE.Skin.Frame(frame, false) end
    return widget
end

local ignoreKeys = {
    BUTTON1 = true,
    BUTTON2 = true,
    UNKNOWN = true,
    LSHIFT = true,
    LCTRL = true,
    LALT = true,
    RSHIFT = true,
    RCTRL = true,
    RALT = true
}

local function createControllerKeybinding()
    local frame = CreateFrame("Frame", nextName("ControllerKeybinding"), UIParent)
    frame:SetSize(200, 44)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT")
    label:SetPoint("TOPRIGHT")
    label:SetJustifyH("CENTER")
    label:SetHeight(STYLE.labelControlOffset)

    local button = CreateFrame("Button", nextName("KeyButton"), frame, "UIPanelButtonTemplate")
    button:SetPoint("BOTTOMLEFT")
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.keyBindButtonReserve, 0)
    button:SetHeight(STYLE.controlHeight)
    button:RegisterForClicks("AnyDown")
    button:EnableKeyboard(false)
    button:EnableMouseWheel(false)

    label:ClearAllPoints()
    label:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, STYLE.padXXS)
    label:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, STYLE.padXXS)

    local msgframe = CreateFrame("Frame", nil, UIParent, frameTemplate)
    msgframe:SetHeight(30)
    UI.MakePopup(msgframe, {frameLevel = 1000})
    skinInset(msgframe)
    local msg = msgframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOPLEFT", STYLE.frameBodyInset, -STYLE.frameBodyInset)
    msg:SetText("Press a key to bind, ESC to clear the binding or click the button again to cancel.")
    msgframe:SetWidth(430)
    msgframe:SetPoint("BOTTOM", button, "TOP")
    msgframe:Hide()

    local widget = wrap("ControllerKeybinding", frame)
    widget.button = button
    widget.label = label
    widget.msgframe = msgframe

    local function stopCapture()
        button:EnableKeyboard(false)
        button:EnableMouseWheel(false)
        msgframe:Hide()
        button:UnlockHighlight()
        widget.waitingForKey = nil
    end

    local function applyKey(key)
        if key == "ESCAPE" then
            key = ""
        elseif ignoreKeys[key] then
            return
        else
            if IsShiftKeyDown() then key = "SHIFT-" .. key end
            if IsControlKeyDown() then key = "CTRL-" .. key end
            if IsAltKeyDown() then key = "ALT-" .. key end
        end

        stopCapture()
        if not widget.disabled then
            widget:SetKey(key)
            widget:Fire("OnKeyChanged", key)
        end
    end

    button:SetScript(
        "OnClick",
        function(_, mouseButton)
            if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
            if widget.waitingForKey then
                stopCapture()
            else
                button:EnableKeyboard(true)
                button:EnableMouseWheel(true)
                msgframe:Show()
                button:LockHighlight()
                widget.waitingForKey = true
            end
            UI:ClearFocus()
        end
    )
    button:SetScript("OnKeyDown", function(_, key) if widget.waitingForKey then applyKey(key) end end)
    button:SetScript(
        "OnMouseDown",
        function(_, mouseButton)
            if mouseButton == "LeftButton" or mouseButton == "RightButton" then return end
            if mouseButton == "MiddleButton" then mouseButton = "BUTTON3" end
            applyKey(mouseButton)
        end
    )
    button:SetScript("OnMouseWheel", function(_, direction) applyKey(direction >= 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    button:SetScript("OnGamePadButtonDown", function(_, key) applyKey(key) end)
    button:SetScript("OnEnter", function() widget:Fire("OnEnter") end)
    button:SetScript("OnLeave", function() widget:Fire("OnLeave") end)

    function widget:SetDisabled(disabled)
        self.disabled = disabled
        if disabled then
            button:Disable()
            label:SetTextColor(0.5, 0.5, 0.5)
        else
            button:Enable()
            label:SetTextColor(1, 1, 1)
        end
    end

    function widget:SetKey(key)
        if (key or "") == "" then
            button:SetText(NOT_BOUND)
            button:SetNormalFontObject("GameFontNormal")
        else
            button:SetText(key)
            button:SetNormalFontObject("GameFontHighlight")
        end
        applyNormalAccentButtonText(button)
    end

    function widget:GetKey()
        local key = button:GetText()
        if key == NOT_BOUND then key = nil end
        return key
    end

    function widget:SetLabel(text)
        local labelText = textValue(text)
        label:SetText(labelText)
        if labelText == "" then
            self:SetHeight(STYLE.controlHeight)
        else
            self:SetHeight(44)
        end
    end

    widget:SetLabel("")
    widget:SetKey("")
    if GSE.Skin and GSE.Skin.Frame then GSE.Skin.Frame(frame, false) end
    return widget
end

local function applyElvUITreeToggleState(button, active)
    if not (button and button.toggle) then return end
    -- Under an external provider (ElvUI / EllesmereUI) the orange/pink tint
    -- of expand.png/collapse.png clashes with the host UI's neutral palette.
    -- Same treatment as the GSE modern skin's expand toggle: desaturate the
    -- texture and tint it neutral, brightening on hover.
    if hasExternalSkinProvider() then
        if button.toggle.SetDesaturated then button.toggle:SetDesaturated(true) end
        if button.toggle.SetVertexColor then
            if active then
                button.toggle:SetVertexColor(1, 1, 1, 1)
            else
                button.toggle:SetVertexColor(0.7, 0.7, 0.7, 0.9)
            end
        end
        return
    end
    if shouldUseElvUISkin() then
        if active then
            if button.toggle.SetDesaturated then button.toggle:SetDesaturated(false) end
            if button.toggle.SetVertexColor then button.toggle:SetVertexColor(1, 1, 1, 1) end
        else
            if button.toggle.SetDesaturated then button.toggle:SetDesaturated(true) end
            if button.toggle.SetVertexColor then button.toggle:SetVertexColor(0.55, 0.55, 0.55, 0.82) end
        end
    else
        if button.toggle.SetDesaturated then button.toggle:SetDesaturated(false) end
        if button.toggle.SetVertexColor then button.toggle:SetVertexColor(1, 1, 1, 1) end
    end
end

local function treeUnique(line)
    if line.parent and line.parent.value then
        return treeUnique(line.parent) .. "\001" .. line.value
    end
    return tostring(line.value)
end

local function splitUnique(value)
    local result = {}
    value = tostring(value or "")
    for part in string.gmatch(value, "([^\001]+)") do
        table.insert(result, part)
    end
    return result
end

local function buildUnique(...)
    return table.concat({...}, "\001")
end

local function createTreeButton(widget)
    local button = CreateFrame("Button", nextName("TreeButton"), widget.treeframe)
    button:SetHeight(TREE_ROW_HEIGHT)
    button:RegisterForClicks("AnyUp")
    button.obj = widget

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.18, 0.32, 0.55, 0)

    button.toggle = button:CreateTexture(nil, "ARTWORK")
    button.toggle:SetSize(TREE_ROW_TOGGLE_SIZE, TREE_ROW_TOGGLE_SIZE)
    button.toggle:SetPoint("LEFT", STYLE.padSmall, 0)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(TREE_ROW_ICON_SIZE, TREE_ROW_ICON_SIZE)

    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    button.text:SetPoint("RIGHT", -STYLE.padSmall, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)

    button:SetScript(
        "OnMouseDown",
        function(self, mouseButton)
            if mouseButton ~= "LeftButton" then return end
            local x, y = GetCursorPosition()
            activeTreeDrag = {value = self.uniquevalue, widget = widget, x = x, y = y}
        end
    )
    button:SetScript(
        "OnMouseUp",
        function(self, mouseButton)
            if mouseButton ~= "LeftButton" or not activeTreeDrag then return end
            local x, y = GetCursorPosition()
            local dx = x - activeTreeDrag.x
            local dy = y - activeTreeDrag.y
            local source = activeTreeDrag.value
            local dragWidget = activeTreeDrag.widget
            activeTreeDrag = nil
            if (dx * dx + dy * dy) < 100 then return end
            for _, candidate in ipairs(dragWidget.buttons or {}) do
                if candidate:IsShown() and candidate:IsMouseOver() and candidate.uniquevalue ~= source then
                    dragWidget:Fire("OnButtonDrop", source, candidate.uniquevalue)
                    return
                end
            end
        end
    )
    button:SetScript(
        "OnClick",
        function(self, mouseButton)
            if self.disabled then return end
            if mouseButton == "LeftButton" and self.hasChildren then
                local status = widget.status or widget.localstatus
                if status.groups[self.uniquevalue] then
                    status.groups[self.uniquevalue] = nil
                    widget:RefreshTree()
                    UI:ClearFocus()
                    return
                end
                status.groups[self.uniquevalue] = true
                if not self.selected then widget:SetSelected(self.uniquevalue) end
                widget:RefreshTree()
                UI:ClearFocus()
                return
            end
            widget:Fire("OnClick", self.uniquevalue, self.selected)
            if not self.selected then
                widget:SetSelected(self.uniquevalue)
                self.selected = true
                self.bg:SetColorTexture(0, 0, 0, 0)
                if self.hasChildren then
                    local status = widget.status or widget.localstatus
                    status.groups[self.uniquevalue] = not status.groups[self.uniquevalue]
                    widget:RefreshTree()
                end
            elseif mouseButton == "RightButton" then
                widget:Fire("OnGroupSelected", self.uniquevalue)
            elseif mouseButton == "LeftButton" then
                widget:Fire("OnGroupSelected", self.uniquevalue)
            end
            UI:ClearFocus()
        end
    )
    button:SetScript(
        "OnDoubleClick",
        function(self)
            if not self.hasChildren then return end
            local status = widget.status or widget.localstatus
            status.groups[self.uniquevalue] = not status.groups[self.uniquevalue]
            widget:RefreshTree()
        end
    )
    button:SetScript("OnEnter", function(self) self.GSEElvUITreeToggleMouseOver = true; applyElvUITreeToggleState(self, true); widget:Fire("OnButtonEnter", self.uniquevalue, self) end)
    button:SetScript("OnLeave", function(self) self.GSEElvUITreeToggleMouseOver = false; applyElvUITreeToggleState(self, false); widget:Fire("OnButtonLeave", self.uniquevalue, self) end)
    applyElvUITextButtonHover(button)

    return button
end

local function updateTreeButton(button, line, selected, expanded)
    local level = line.level or 1
    button.value = line.value
    button.uniquevalue = line.uniquevalue
    button.hasChildren = line.hasChildren
    button.disabled = line.disabled
    button.selected = selected

    -- Selection highlight: EUI / ElvUI panels paint a subtle accent-coloured
    -- band behind the currently-selected list item (e.g. inventory "All Items").
    -- Match that here when an external skin provider is active.
    if selected and hasExternalSkinProvider() then
        local euiTable = _G.EllesmereUI
        local r, g, b = 0.2, 0.5, 0.6
        if type(euiTable) == "table" and type(euiTable.ELLESMERE_GREEN) == "table" then
            local c = euiTable.ELLESMERE_GREEN
            r, g, b = c.r or r, c.g or g, c.b or b
        end
        button.bg:SetColorTexture(r, g, b, 0.22)
    else
        button.bg:SetColorTexture(0, 0, 0, 0)
    end
    button.text:SetFontObject(level <= 2 and "GameFontNormalLarge" or "GameFontHighlight")
    local lineText = textValue(line.text)
    button.text:SetText(line.disabled and ("|cff808080" .. lineText .. FONT_COLOR_CODE_CLOSE) or lineText)
    button:EnableMouse(not line.disabled)

    local x = STYLE.treeIndentBase + ((level - 1) * STYLE.treeIndentStep)
    if line.hasChildren then
        button.toggle:SetTexture(expanded and TREE_ROW_COLLAPSE_TEXTURE or TREE_ROW_EXPAND_TEXTURE)
        button.toggle:SetTexCoord(0, 1, 0, 1)
        button.toggle:SetPoint("LEFT", x, 0)
        applyElvUITreeToggleState(button, button.GSEElvUITreeToggleMouseOver)
        button.toggle:Show()
        x = x + TREE_ROW_TOGGLE_SIZE + STYLE.treeToggleGap
    else
        button.toggle:Hide()
    end

    if line.icon then
        button.icon:SetTexture(line.icon)
        button.icon:SetTexCoord(unpack(line.iconCoords or {0, 1, 0, 1}))
        button.icon:SetPoint("LEFT", x, 0)
        button.icon:Show()
        x = x + TREE_ROW_ICON_SIZE + STYLE.treeIconGap
    else
        button.icon:Hide()
    end

    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", x, 0)
    button.text:SetPoint("RIGHT", -STYLE.padSmall, 0)
end

local function shouldDisplayLevel(tree)
    for _, node in ipairs(tree or {}) do
        if node.children then
            if shouldDisplayLevel(node.children) then return true end
        elseif node.visible ~= false then
            return true
        end
    end
    return false
end

local function createTreeGroup()
    local frame = CreateFrame("Frame", nextName("TreeGroup"), UIParent)
    frame:SetSize(500, 400)

    local treeframe = CreateFrame("Frame", nil, frame, frameTemplate)
    treeframe:SetPoint("TOPLEFT", 8, 0)
    treeframe:SetPoint("BOTTOMLEFT", 8, 0)
    treeframe:SetWidth(DEFAULT_TREE_WIDTH)
    treeframe:EnableMouseWheel(true)
    treeframe:SetResizable(true)
    setFrameResizeBounds(treeframe, MIN_TREE_WIDTH, 120)
    skinInset(treeframe)

    local dragger = CreateFrame("Frame", nil, treeframe, frameTemplate)
    dragger:SetWidth(STYLE.treeDraggerWidth)
    dragger:SetPoint("TOP", treeframe, "TOPRIGHT")
    dragger:SetPoint("BOTTOM", treeframe, "BOTTOMRIGHT")
    applyBackdrop(dragger, {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"}, {1, 1, 1, 0})
    if shouldUseElvUISkin() or getModernClassColor(1) then
        dragger.GSEModernDragLine = dragger:CreateTexture(nil, "ARTWORK")
        dragger.GSEModernDragLine:SetWidth(2)
        dragger.GSEModernDragLine:SetPoint("TOP", dragger, "TOP", 0, 0)
        dragger.GSEModernDragLine:SetPoint("BOTTOM", dragger, "BOTTOM", 0, 0)
        colorTexture(dragger.GSEModernDragLine, {0.45, 0.45, 0.45, 0})
    end

    local scrollbar = CreateFrame("Slider", nextName("TreeScrollBar"), treeframe, "UIPanelScrollBarTemplate")
    scrollbar:SetScript("OnValueChanged", nil)
    if shouldUseElvUISkin() then
        scrollbar:SetPoint("TOPRIGHT", -STYLE.treeScrollInsetX, 0)
        scrollbar:SetPoint("BOTTOMRIGHT", -STYLE.treeScrollInsetX, 0)
    else
        scrollbar:SetPoint("TOPRIGHT", -STYLE.treeScrollInsetX, -STYLE.treeScrollInsetY)
        scrollbar:SetPoint("BOTTOMRIGHT", -STYLE.treeScrollInsetX, STYLE.treeScrollInsetY)
    end
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(1)
    scrollbar:SetValue(0)
    scrollbar:SetWidth(STYLE.scrollBarWidth)
    applyModernSlimScrollBar(scrollbar, treeframe, -STYLE.treeScrollInsetX, 0, 0)

    local border = CreateFrame("Frame", nil, frame, frameTemplate)
    border:SetPoint("TOPLEFT", treeframe, "TOPRIGHT")
    border:SetPoint("BOTTOMRIGHT")
    skinInset(border)

    -- ----------------------------------------------------------------
    -- Navigator Window
    -- Raw styled frame (same look as editor via styleBlizzardPanelFrame/
    -- skinPanel) but no NativeUI widget overhead — DoLayout can't reset
    -- content anchors and break dynamic width sizing.
    -- ----------------------------------------------------------------
    local navWindow = createBlizzardPanelFrame(nextName("NavWindow"))
    navWindow:SetFrameStrata("MEDIUM")
    if navWindow.SetToplevel then navWindow:SetToplevel(true) end
    applyFrameScreenBuffer(navWindow)
    if GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(navWindow) end
    navWindow:EnableMouse(true)
    navWindow:SetMovable(true)
    navWindow:SetResizable(true)
    setFrameResizeBounds(navWindow, MIN_TREE_WIDTH + 8, 150)
    navWindow:RegisterForDrag("LeftButton")
    navWindow:HookScript("OnShow", function(self)
        if GSE.ApplyScaleToFrame then GSE.ApplyScaleToFrame(self) end
        applyNormalAccentWindowSkin(self)
    end)
    -- Belt-and-braces: clear the in-drag flag if the window hides for any reason
    -- (editor close, /reload, etc) so a stale flag can't suppress auto-fit later.
    navWindow:HookScript("OnHide", function(self)
        self.GSENavResizing = nil
    end)
    local usesStockNav = styleBlizzardPanelFrame(navWindow)
    if not usesStockNav then skinPanel(navWindow) end

    -- Close button — hidden when docked, shown when detached
    local navCloseBtn = navWindow.CloseButton
    if navCloseBtn then
        navCloseBtn:ClearAllPoints()
        navCloseBtn:SetPoint("TOPLEFT", navWindow, "TOPLEFT", -STYLE.closeButtonOffsetX, STYLE.closeButtonOffsetY)
        navCloseBtn:Hide()
    end
    -- Classic / BoA / MoP with the native skin only: cover BasicFrameTemplate
    -- WithInset's leftover corner artifact at the TOPRIGHT with a 21x16 chrome
    -- tile. Skipped on retail (ButtonFrameTemplate is clean) and on ElvUI
    -- (which supplies its own chrome).
    if (GSE.GameMode or 11) < 11 and not shouldUseElvUISkin() then
        local fill = navWindow:CreateTexture(nil, "BACKGROUND", nil, 1)
        fill:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\ClassicTitleFill.png")
        fill:SetSize(21, 16)
        fill:SetPoint("TOPRIGHT", navWindow, "TOPRIGHT", -2, -3)
    end

    navWindow:Hide()
    navWindow.GSESideDetached = false

    -- Resize grip — shown only when detached
    local navResizeBtn = CreateFrame("Button", nil, navWindow)
    navResizeBtn:SetSize(16, 16)
    navResizeBtn:SetPoint("BOTTOMRIGHT", navWindow, "BOTTOMRIGHT", -8, 8)
    navResizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    navResizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    navResizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    navResizeBtn:EnableMouse(true)
    navResizeBtn:RegisterForClicks("AnyDown")
    if navResizeBtn.SetFrameLevel and navWindow.GetFrameLevel then
        navResizeBtn:SetFrameLevel((navWindow:GetFrameLevel() or 0) + 80)
    end
    navResizeBtn:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        -- Mark that the user is actively dragging the resize grip. RefreshTree's
        -- auto-fit pass checks this flag and skips its own SetSize call during
        -- the drag — otherwise StartSizing and auto-fit fight each frame.
        navWindow.GSENavResizing = true
        if navWindow.StartSizing then navWindow:StartSizing("BOTTOMRIGHT") end
    end)
    navResizeBtn:SetScript("OnMouseUp", function()
        if navWindow.StopMovingOrSizing then navWindow:StopMovingOrSizing() end
        navWindow.GSENavResizing = nil
        -- Re-anchor TOPLEFT so future height changes expand downward
        local left, top = navWindow:GetLeft(), navWindow:GetTop()
        if left and top then
            navWindow:ClearAllPoints()
            navWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        if GSE.GUI and GSE.GUI.navDetached then
            local w, h = navWindow:GetWidth(), navWindow:GetHeight()
            GSE.GUI.navDetachGeom = {
                left = navWindow:GetLeft(), top = navWindow:GetTop(),
                w = w, h = h,
                -- Mark the size as user-chosen so RefreshTree's auto-fit pass
                -- below treats it as a floor instead of shrinking back to content.
                userResized = true,
                userW = w, userH = h,
            }
        end
    end)
    navResizeBtn:Hide()
    navWindow.GSENavResizeButton = navResizeBtn

    -- Re-anchor to TOPLEFT after drag/resize so height changes always expand downward
    local function reanchorTopLeft()
        local left, top = navWindow:GetLeft(), navWindow:GetTop()
        if left and top then
            navWindow:ClearAllPoints()
            navWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
    end

    local NAV_SNAP_TOLERANCE = GSE.DEBUGGER_SIDE_SNAP_TOLERANCE or 28
    local NAV_DOCK_OFFSET_X  = 4   -- overlap amount matching debugger side windows
    local refreshNavWindow       -- forward declaration (defined later in this scope)
    local toggleNavWindow        -- forward declaration (defined later in this scope)
    local getEditorFrame         -- forward declaration (defined later in this scope)
    local updateNavControls      -- forward declaration (defined later in this scope)

    -- Persist the floating geometry globally so the active editor's tree always
    -- reappears where the user left the floating window.
    local function storeDetachGeom()
        if not (GSE.GUI and GSE.GUI.navDetached) then return end
        GSE.GUI.navDetachGeom = {
            left = navWindow:GetLeft(),
            top  = navWindow:GetTop(),
            w    = navWindow:GetWidth() or 200,
            h    = navWindow:GetHeight() or 400,
        }
    end

    local function dockNavWindow()
        navWindow.GSESideDetached = false
        if navCloseBtn then navCloseBtn:Hide() end
        if navWindow.GSENavResizeButton then navWindow.GSENavResizeButton:Hide() end
        if GSE.GUI then
            GSE.GUI.navDetached = false
            GSE.GUI.floatOwner  = nil
        end
    end

    local function detachNavWindow()
        if GSE.GUI and GSE.GUI.navDetached then return end
        local left, top = navWindow:GetLeft(), navWindow:GetTop()
        navWindow.GSESideDetached = true
        if GSE.GUI then
            -- Preserve any user-chosen size from a previous detach so re-floating
            -- the tree gives the user the size they last set, not the auto-fit default.
            local prior = GSE.GUI.navDetachGeom
            GSE.GUI.navDetached   = true
            GSE.GUI.navDetachGeom = {
                left = left, top = top,
                w = (prior and prior.userResized and prior.userW) or navWindow:GetWidth() or 200,
                h = (prior and prior.userResized and prior.userH) or 400,
                userResized = prior and prior.userResized or false,
                userW = prior and prior.userW or nil,
                userH = prior and prior.userH or nil,
            }
            -- Initial owner is the editor being detached (always the active one,
            -- since only the active editor's tree is visible to drag). While
            -- floating, SyncTrees keeps floatOwner tracking the active editor so
            -- the tree follows whichever editor becomes active.
            -- NOTE: 'widget' is undefined in this scope, so this expression has always
            -- evaluated to nil. SyncTrees re-populates GSE.GUI.floatOwner with the active
            -- editor while the tree is floating, so nil-initialisation here is the current
            -- shipped behaviour. (Flagged for review: the original intent was the detaching
            -- editor -- supply that reference here if a non-nil initial owner is wanted.)
            GSE.GUI.floatOwner    = nil
        end
        if navCloseBtn then navCloseBtn:Show() end
        if navWindow.GSENavResizeButton then navWindow.GSENavResizeButton:Show() end
        -- Use preserved height when the user has previously sized this; otherwise
        -- fall back to the compact 400px default.
        local g = GSE.GUI and GSE.GUI.navDetachGeom
        local w = (g and g.w) or navWindow:GetWidth() or 200
        local h = (g and g.h) or 400
        navWindow:SetSize(w, h)
        navWindow:ClearAllPoints()
        if left and top then
            if GSE.SetFrameScreenPoint then
                GSE.SetFrameScreenPoint(navWindow, "TOPLEFT", left, top)
            else
                navWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            end
        else
            navWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        -- One global floating tree; other editors' trees stay hidden.
        if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() end
    end

    local function maybeSnapNavWindow()
        if not navWindow.GSESideDetached then return false end
        local editorFrame = getEditorFrame and getEditorFrame()
        if not (editorFrame and editorFrame:IsShown()) then return false end
        local nLeft, nRight, nTop = navWindow:GetLeft(), navWindow:GetRight(), navWindow:GetTop()
        local eLeft, eTop = editorFrame:GetLeft(), editorFrame:GetTop()
        if not (nLeft and nRight and nTop and eLeft and eTop) then return false end
        if math.abs(nRight - (eLeft + NAV_DOCK_OFFSET_X)) <= NAV_SNAP_TOLERANCE and math.abs(nTop - eTop) <= NAV_SNAP_TOLERANCE then
            dockNavWindow()
            refreshNavWindow()
            if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() end
            return true
        end
        return false
    end

    navWindow:SetScript("OnDragStart", function(self)
        detachNavWindow()
        self:StartMoving()
    end)
    navWindow:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        reanchorTopLeft()
        if maybeSnapNavWindow() then return end
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
        -- ClampFrameToScreen re-anchors at BOTTOMLEFT; re-anchor TOPLEFT so the
        -- tree's top stays fixed and collapses/height changes expand downward
        -- (otherwise, when clamped near the top, it would collapse to the bottom).
        reanchorTopLeft()
        storeDetachGeom()
    end)

    -- TitleContainer gets the same drag hooks — it sits above the frame and
    -- consumes mouse events, so without this the frame's OnDragStart never fires.
    if navWindow.TitleContainer then
        navWindow.TitleContainer:EnableMouse(true)
        navWindow.TitleContainer:RegisterForDrag("LeftButton")
        navWindow.TitleContainer:SetScript("OnDragStart", function()
            detachNavWindow()
            navWindow:StartMoving()
        end)
        navWindow.TitleContainer:SetScript("OnDragStop", function()
            navWindow:StopMovingOrSizing()
            reanchorTopLeft()
            if maybeSnapNavWindow() then return end
            if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(navWindow) end
            reanchorTopLeft()
            storeDetachGeom()
        end)
    end

    if navCloseBtn then
        navCloseBtn:SetScript("OnClick", function()
            if navWindow.GSESideDetached then
                -- Closing the floating tree returns it to the active editor, docked,
                -- rather than turning the tree off entirely.
                dockNavWindow()
                if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() else refreshNavWindow() end
            else
                toggleNavWindow()
            end
        end)
    end

    -- Expose snap helpers for external use
    navWindow.DetachNav  = detachNavWindow
    navWindow.DockNav    = dockNavWindow
    navWindow.MaybeSnap  = maybeSnapNavWindow

    -- Content area — use standard frame insets so padding matches the editor
    local navPadX      = STYLE.frameEdge
    local navPadTop    = STYLE.controlHeight  -- skip the title bar chrome
    local navPadBottom = STYLE.frameEdge
    local navContent = CreateFrame("Frame", nil, navWindow)
    navContent:SetPoint("TOPLEFT",     navWindow, "TOPLEFT",     navPadX,  -navPadTop)
    navContent:SetPoint("BOTTOMRIGHT", navWindow, "BOTTOMRIGHT", -navPadX,  navPadBottom)

    -- "All Sequences" checkbox at the bottom of the tree frame. Anchored to
    -- navContent's BOTTOM center (with a computed X offset to account for the
    -- text label sitting to the right of the checkbox), so the combined visual
    -- is centered horizontally and follows window resizes dynamically. The Y
    -- anchor is fixed at the bottom — tree expand/collapse never moves it.
    -- Toggling this checkbox flips GSEOptions.filterList["All"] (the same
    -- backing field as the "Show All Sequences in Editor" option), then asks
    -- all open editors to rebuild their trees.
    local NAV_CHECKBOX_AREA  = 26  -- vertical space reserved for the checkbox row
    local NAV_CHECKBOX_SIZE  = 22
    local NAV_CHECKBOX_GAP   = 2   -- gap between the checkbox and its text label
    local allSeqCheckbox = CreateFrame("CheckButton", nil, navContent, "UICheckButtonTemplate")
    allSeqCheckbox:SetSize(NAV_CHECKBOX_SIZE, NAV_CHECKBOX_SIZE)
    if allSeqCheckbox.text then
        allSeqCheckbox.text:SetText(L and L["All Sequences"] or "All Sequences")
        allSeqCheckbox.text:ClearAllPoints()
        allSeqCheckbox.text:SetPoint("LEFT", allSeqCheckbox, "RIGHT", NAV_CHECKBOX_GAP, 0)
    end
    -- Centring math:
    --   combined unit = checkbox(NAV_CHECKBOX_SIZE) + gap + text(width)
    --   combined unit's center is offset to the right of the checkbox's center
    --   by (textWidth + gap) / 2. To center the unit on navContent we shift the
    --   checkbox anchor LEFT by that same amount. WoW's anchor system keeps the
    --   center dynamic as navContent resizes — no per-frame recompute needed.
    local function recenterCheckbox()
        local textWidth = (allSeqCheckbox.text and allSeqCheckbox.text:GetStringWidth()) or 0
        local xOffset = -((textWidth + NAV_CHECKBOX_GAP) / 2)
        allSeqCheckbox:ClearAllPoints()
        allSeqCheckbox:SetPoint("BOTTOM", navContent, "BOTTOM", xOffset, 2)
    end
    recenterCheckbox()
    local function syncAllSeqCheckbox()
        local val = GSEOptions and GSEOptions.filterList and GSEOptions.filterList["All"]
        allSeqCheckbox:SetChecked(val and true or false)
        -- Re-measure on show in case the FontString hadn't computed its width
        -- on first construction (some clients defer text metrics until visible).
        recenterCheckbox()
    end
    allSeqCheckbox:SetScript("OnClick", function(self)
        if not GSEOptions then GSEOptions = {} end
        if not GSEOptions.filterList then GSEOptions.filterList = {} end
        GSEOptions.filterList["All"] = self:GetChecked() and true or false
        if GSE.GUI and GSE.GUI.RefreshOpenEditorTrees then
            GSE.GUI.RefreshOpenEditorTrees()
        end
    end)
    allSeqCheckbox:HookScript("OnShow", syncAllSeqCheckbox)
    syncAllSeqCheckbox()
    navWindow.GSEAllSeqCheckbox = allSeqCheckbox
    navWindow.GSESyncAllSeqCheckbox = syncAllSeqCheckbox

    -- Move treeframe into navContent
    treeframe:SetParent(navContent)
    treeframe:ClearAllPoints()
    treeframe:SetPoint("TOPLEFT",     navContent, "TOPLEFT",     0, 2)
    -- Leave room at the bottom for the All Sequences checkbox row.
    treeframe:SetPoint("BOTTOMRIGHT", navContent, "BOTTOMRIGHT", 0, NAV_CHECKBOX_AREA)
    dragger:Hide()

    -- Content border fills the full treeGroup frame
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, 0)
    border:SetPoint("BOTTOMRIGHT",frame, "BOTTOMRIGHT",0, 0)

    local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
    local navVisible = (seOpts and seOpts.navVisible ~= nil) and seOpts.navVisible or true


    local content = CreateFrame("Frame", nil, border)
    content:SetPoint("TOPLEFT", STYLE.treeContentPadX, -STYLE.treeContentPadTop)
    content:SetPoint("BOTTOMRIGHT", -STYLE.treeContentPadX, STYLE.treeContentPadBottom)
    if content.SetClipsChildren then content:SetClipsChildren(true) end

    local widget = wrap("GSE-TreeGroup", frame)
    widget.content = content
    widget.lines = {}
    widget.buttons = {}
    widget.localstatus = {groups = {}, scrollvalue = 0, treewidth = DEFAULT_TREE_WIDTH, treesizable = DEFAULT_TREE_RESIZABLE}
    widget.treeframe = treeframe
    widget.dragger = dragger
    widget.scrollbar = scrollbar
    widget.border = border

    treeframe.obj = widget
    dragger.obj = widget
    scrollbar.obj = widget

    local function clampTreeWidth(width)
        local fullWidth = safeWidth(frame, DEFAULT_TREE_WIDTH + MIN_TREE_CONTENT_WIDTH + (STYLE.treeContentPadX * 2))
        local maxWidth = math.min(MAX_TREE_WIDTH, math.max(MIN_TREE_WIDTH, fullWidth - MIN_TREE_CONTENT_WIDTH))
        width = tonumber(width) or DEFAULT_TREE_WIDTH
        return math.min(math.max(width, MIN_TREE_WIDTH), maxWidth)
    end
    getEditorFrame = function()
        -- Traverse: treeContainer → basecontainer → editframe widget → .frame
        local p = widget and widget.parent
        local pp = p and p.parent
        return pp and pp.frame or nil
    end

    refreshNavWindow = function()
        local gui = GSE.GUI
        -- Keep the editor-edge nav controls (chevron/strip/bar) enabled only while
        -- the tree is docked; deactivate them on every editor while it floats.
        if updateNavControls then updateNavControls() end
        if not navVisible then
            navWindow.GSESideDetached = false
            navWindow:Hide()
            return
        end
        local myFrame  = getEditorFrame and getEditorFrame()
        local active   = gui and gui.activeEditor
        local nEditors = (gui and gui.editors) and #gui.editors or 0
        local detached = gui and gui.navDetached
        -- Decide whether THIS editor's tree is the one tree that shows:
        --  * Floating: it tracks the active editor (SyncTrees sets floatOwner =
        --    activeEditor), so the floating tree always works with whichever editor
        --    is currently active, reappearing at the shared float geometry.
        --  * Docked: it follows the active editor (becomes that editor's tree).
        local show
        if detached then
            local ownerFrame = gui and gui.floatOwner and gui.floatOwner.frame
            show = (nEditors <= 1)
                or (not (gui and gui.floatOwner))
                or (ownerFrame and myFrame and ownerFrame == myFrame)
        else
            show = (nEditors <= 1)
                or (active and active.frame and myFrame and active.frame == myFrame)
        end
        if not show then
            navWindow.GSESideDetached = false
            navWindow:Hide()
            return
        end
        local status = widget and (widget.status or widget.localstatus) or nil
        local tw = math.max(MIN_TREE_WIDTH, (status and status.treewidth) or DEFAULT_TREE_WIDTH)
        if detached then
            -- Floating: this editor's tree occupies the shared detach geometry.
            navWindow.GSESideDetached = true
            navWindow.GSESkipScaleRecenter = false  -- floating: keep visual position when scaled
            if navCloseBtn then navCloseBtn:Show() end
            if navWindow.GSENavResizeButton then navWindow.GSENavResizeButton:Show() end
            -- Skip the SetSize during a manual resize drag — WoW's StartSizing
            -- is controlling the window size, and clobbering it here would fight
            -- the user's drag every frame. Position/show still runs below.
            if not navWindow.GSENavResizing then
                local g = gui.navDetachGeom
                local w = (g and g.w) or (tw + 8)
                local h = (g and g.h) or (navWindow:GetHeight() or 400)
                navWindow:SetSize(w, h)
                navWindow:ClearAllPoints()
                if g and g.left and g.top then
                    if GSE.SetFrameScreenPoint then
                        GSE.SetFrameScreenPoint(navWindow, "TOPLEFT", g.left, g.top)
                    else
                        navWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", g.left, g.top)
                    end
                else
                    navWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end
        else
            -- Docked to the active editor.
            navWindow.GSESideDetached = false
            navWindow.GSESkipScaleRecenter = true  -- docked: keep the editor anchor when scaled (don't re-center)
            if navCloseBtn then navCloseBtn:Hide() end
            if navWindow.GSENavResizeButton then navWindow.GSENavResizeButton:Hide() end
            local anchorFrame = myFrame or frame
            local h = safeHeight(anchorFrame, 600)
            navWindow:SetSize(tw + 8, h)
            navWindow:ClearAllPoints()
            navWindow:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", NAV_DOCK_OFFSET_X, 0)
        end
        navWindow:Show()
        -- Keep our in-tree "All Sequences" checkbox in sync with the underlying
        -- filter setting — covers the case where the user toggled the value
        -- via the Options panel (or another editor's tree checkbox).
        if navWindow.GSESyncAllSeqCheckbox then navWindow.GSESyncAllSeqCheckbox() end
        -- content width and parent layout are handled by OnWidthSet — no
        -- parent.DoLayout() call here to avoid recursion → stack overflow.
    end

    -- Keep height in sync when either the treeGroup frame or the editor resizes
    frame:HookScript("OnSizeChanged", function()
        if navVisible then refreshNavWindow() end
    end)

    -- When the editor is dragged, check if the detached navWindow is now close
    -- enough to reattach — mirrors the navWindow's own OnDragStop snap check.
    C_Timer.After(0, function()
        local editorFrame = getEditorFrame and getEditorFrame()
        if editorFrame then
            editorFrame:HookScript("OnDragStop", function()
                if navVisible and navWindow.GSESideDetached then
                    maybeSnapNavWindow()
                end
            end)
            -- Also hook TitleContainer drag if present
            if editorFrame.TitleContainer then
                editorFrame.TitleContainer:HookScript("OnDragStop", function()
                    if navVisible and navWindow.GSESideDetached then
                        maybeSnapNavWindow()
                    end
                end)
            end
        end
    end)

    toggleNavWindow = function()
        navVisible = not navVisible
        local opts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
        if opts then opts.navVisible = navVisible end
        refreshNavWindow()
    end
    widget.ToggleNavWindow = toggleNavWindow
    widget.navWindowFrame = navWindow          -- raw frame for show/hide from Editor.lua
    widget.RefreshNavWindow = refreshNavWindow -- call to reposition/show after restore

    -- Invisible full-height click zone on the left edge — covers the visible sidebar
    -- (treeContentPadX inside border + frameContentX chrome to the left of it)
    -- navStrip parented to UIParent so its hitbox is never clipped by border
    -- (border starts at frame's left edge; anything left of that was invisible to clicks)
    -- Parented to the editor frame itself (NOT UIParent) so the strip rides the
    -- frame's Raise()/strata automatically and always sits above the frame's
    -- content. The top-level editor frame does not clip children, so anchoring
    -- the strip outside its left edge is safe.
    local navStrip = CreateFrame("Button", nil, frame)
    if navStrip.SetClipsChildren then navStrip:SetClipsChildren(false) end
    navStrip:SetWidth(50)
    navStrip:SetPoint("TOPLEFT",    frame, "TOPLEFT",    -35, 0)
    navStrip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -35, 0)
    navStrip:EnableMouse(true)
    -- Hide/show with the editor
    frame:HookScript("OnShow", function() navStrip:Show() end)
    frame:HookScript("OnHide", function() navStrip:Hide() end)
    if not frame:IsShown() then navStrip:Hide() end

    -- Chevron icon — points left when nav open (click to close), right when closed (click to open).
    -- Parented to UIParent so it is never clipped by the border frame whose left
    -- edge sits at frame's left edge (navStrip centre is ~11px outside that edge).
    local chevronSize = 20
    local CHEVRON_LEFT  = "Interface\\AddOns\\GSE_GUI\\Assets\\chevron-left.png"
    local CHEVRON_RIGHT = "Interface\\AddOns\\GSE_GUI\\Assets\\chevron-right.png"
    navStrip:SetNormalTexture("")
    navStrip:SetHighlightTexture("")
    navStrip:SetPushedTexture("")
    local chevronFrame = CreateFrame("Frame", nil, frame)
    chevronFrame:SetSize(chevronSize, chevronSize)
    chevronFrame:SetPoint("CENTER", frame, "LEFT", -11, 0)
    local chevron = chevronFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    chevron:SetAllPoints(chevronFrame)
    chevron:SetTexture(navVisible and CHEVRON_RIGHT or CHEVRON_LEFT)
    local function updateChevron()
        chevron:SetTexture(navVisible and CHEVRON_RIGHT or CHEVRON_LEFT)
    end
    -- navStrip and chevronFrame must share the same strata tier (one above the editor
    -- frame so they clear its border/backdrop children).  chevronFrame sits one level
    -- above navStrip within that tier so the icon is never covered by the hit-zone button.
    -- As children of the editor frame they inherit its strata and ride Raise().
    -- Set their level a fixed amount above the frame's current base level so they
    -- stay above the editor's own content children, while remaining in the same
    -- strata (so other windows at higher strata still draw over them).
    local function syncChevronStrata()
        -- The chevron must clear the MAIN editor window's NineSlice border
        -- (level ~500) and chrome (~532). The left nav is created inside the
        -- TreeGroup (a separate low-level frame), so re-parent the strip+chevron
        -- to the real editor window (getEditorFrame()) and level off ITS base,
        -- exactly like the working right side. Falls back to the TreeGroup frame
        -- until the editor window is wired up.
        local win = getEditorFrame() or frame
        if navStrip:GetParent() ~= win then navStrip:SetParent(win) end
        if chevronFrame:GetParent() ~= win then chevronFrame:SetParent(win) end
        local s = win:GetFrameStrata() or "MEDIUM"
        local base = win:GetFrameLevel() or 0
        navStrip:SetFrameStrata(s)
        navStrip:SetFrameLevel(base + 600)
        chevronFrame:SetFrameStrata(s)
        chevronFrame:SetFrameLevel(base + 601)
    end
    frame:HookScript("OnShow",      function()
        navStrip:Show()
        if not (GSE.GUI and GSE.GUI.navDetached) then chevronFrame:Show() end
        syncChevronStrata()
        if updateNavControls then updateNavControls() end
    end)
    frame:HookScript("OnHide",      function() navStrip:Hide(); chevronFrame:Hide() end)
    frame:HookScript("OnMouseDown", function() syncChevronStrata() end)
    if not frame:IsShown() then chevronFrame:Hide() end
    syncChevronStrata()

    origToggle = toggleNavWindow
    toggleNavWindow = function()
        origToggle()
        updateChevron()
    end
    widget.ToggleNavWindow = toggleNavWindow

    navStrip:SetScript("OnClick", function()
        -- While the tree is floating, the edge controls can't act on it.
        if GSE.GUI and GSE.GUI.navDetached then return end
        toggleNavWindow()
    end)

    -- When the Left Tree is floating (detached), the per-editor edge controls —
    -- the chevron arrow, the invisible click/hover strip, and the gold hover bar —
    -- have nothing to dock/undock, so deactivate them on every editor until the
    -- tree is reattached. Re-runs from refreshNavWindow, so detach/dock/snap and
    -- editor activation all keep it in sync.
    updateNavControls = function()
        local detached = GSE.GUI and GSE.GUI.navDetached
        if detached then
            navStrip:EnableMouse(false)
            if chevronFrame then chevronFrame:Hide() end
        else
            navStrip:EnableMouse(true)
            if chevronFrame and frame:IsShown() then chevronFrame:Show() end
            updateChevron()
        end
    end
    updateNavControls()

    refreshNavWindow()

   refreshNavWindow()

    local function setTreeScrollValue(value)
        local minValue, maxValue = scrollbar:GetMinMaxValues()
        scrollbar:SetValue(math.min(math.max(value or 0, minValue), maxValue))
    end
    if scrollbar.ScrollUpButton then
        scrollbar.ScrollUpButton:SetScript("OnClick", function() setTreeScrollValue(scrollbar:GetValue() - 1) end)
    end
    if scrollbar.ScrollDownButton then
        scrollbar.ScrollDownButton:SetScript("OnClick", function() setTreeScrollValue(scrollbar:GetValue() + 1) end)
    end

    local function buildLevel(tree, level, parent)
        local groups = (widget.status or widget.localstatus).groups
        for _, node in ipairs(tree or {}) do
            if node.children then
                if not widget.filter or shouldDisplayLevel(node.children) then
                    local line = {
                        value = node.value,
                        text = node.text,
                        icon = node.icon,
                        iconCoords = node.iconCoords,
                        disabled = node.disabled,
                        level = level,
                        parent = parent,
                        hasChildren = true,
                        visible = node.visible
                    }
                    line.uniquevalue = treeUnique(line)
                    table.insert(widget.lines, line)
                    if groups[line.uniquevalue] then buildLevel(node.children, level + 1, line) end
                end
            elseif node.visible ~= false or not widget.filter then
                local line = {
                    value = node.value,
                    text = node.text,
                    icon = node.icon,
                    iconCoords = node.iconCoords,
                    disabled = node.disabled,
                    level = level,
                    parent = parent,
                    visible = node.visible
                }
                line.uniquevalue = treeUnique(line)
                table.insert(widget.lines, line)
            end
        end
    end

    scrollbar:SetScript(
        "OnValueChanged",
        function(_, value)
            if widget.noupdate then return end
            local status = widget.status or widget.localstatus
            status.scrollvalue = math.floor((value or 0) + 0.5)
            widget:RefreshTree()
            UI:ClearFocus()
        end
    )
    treeframe:SetScript(
        "OnMouseWheel",
        function(_, delta)
            if not widget.showscroll then return end
            local minValue, maxValue = scrollbar:GetMinMaxValues()
            local value = scrollbar:GetValue()
            scrollbar:SetValue(math.min(math.max(value - delta, minValue), maxValue))
        end
    )
    treeframe:SetScript("OnSizeChanged", function() widget:RefreshTree() end)

    local function setModernTreeDraggerColor(state)
        if not (shouldUseElvUISkin() or getModernClassColor(1)) then return end

        local lineColor = {0.45, 0.45, 0.45, 0}
        if state == "hover" then
            lineColor = getModernClassColor(0.88) or {0.70, 0.70, 0.70, 0.88}
        elseif state == "active" then
            lineColor = getModernClassColor(0.95) or {0.70, 0.70, 0.70, 0.95}
        end

        if dragger.GSEModernDragLine then colorTexture(dragger.GSEModernDragLine, lineColor) end
        if dragger.SetBackdropColor then
            if state == "active" then
                local bgColor = getModernClassColor(0.16) or {1, 1, 1, 0.12}
                dragger:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.16)
            elseif state == "hover" then
                local bgColor = getModernClassColor(0.10) or {1, 1, 1, 0.08}
                dragger:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.10)
            else
                dragger:SetBackdropColor(1, 1, 1, 0)
            end
        end
    end

    dragger:SetScript("OnEnter", function(self)
        if shouldUseElvUISkin() or getModernClassColor(1) then
            setModernTreeDraggerColor(widget.treeDragging and "active" or "hover")
        elseif self.SetBackdropColor then
            self:SetBackdropColor(1, 1, 1, 0.8)
        end
    end)
    dragger:SetScript("OnLeave", function(self)
        if shouldUseElvUISkin() or getModernClassColor(1) then
            setModernTreeDraggerColor(widget.treeDragging and "active" or "normal")
        elseif self.SetBackdropColor then
            self:SetBackdropColor(1, 1, 1, 0)
        end
    end)
    local function finishTreeDrag(fireResize)
        if not widget.treeDragging then return end
        widget.treeDragging = nil
        dragger:SetScript("OnUpdate", nil)

        local status = widget.status or widget.localstatus
        status.treewidth = clampTreeWidth(treeframe:GetWidth())
        treeframe:SetWidth(status.treewidth)
        widget:OnWidthSet(status.fullwidth or safeWidth(frame, 500))
        if fireResize then widget:Fire("OnTreeResize", status.treewidth) end
        widget:DoLayout()
        setModernTreeDraggerColor((dragger.IsMouseOver and dragger:IsMouseOver()) and "hover" or "normal")
    end

    local function updateTreeDrag()
        if not widget.treeDragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            finishTreeDrag(true)
            return
        end

        local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        local cursorX = (GetCursorPosition() or 0) / scale
        local frameLeft = frame:GetLeft() or 0
        local width = clampTreeWidth(cursorX - frameLeft)
        local status = widget.status or widget.localstatus

        status.treewidth = width
        treeframe:SetWidth(width)
        widget:OnWidthSet(status.fullwidth or safeWidth(frame, 500))
        widget:DoLayout()
        widget:RefreshTree()
    end

    dragger:SetScript(
        "OnMouseDown",
        function(_, button)
            if button ~= "LeftButton" then return end
            local status = widget.status or widget.localstatus
            if status.treesizable == false then return end
            widget.treeDragging = true
            setModernTreeDraggerColor("active")
            dragger:SetScript("OnUpdate", updateTreeDrag)
            updateTreeDrag()
        end
    )
    dragger:SetScript(
        "OnMouseUp",
        function()
            finishTreeDrag(true)
        end
    )
    dragger:HookScript("OnHide", function() finishTreeDrag(false) end)

    function widget:EnableButtonTooltips(enable)
        self.enabletooltips = enable
    end

    function widget:SetStatusTable(status)
        self.status = status
        status.groups = status.groups or {}
        status.scrollvalue = status.scrollvalue or 0
        status.treewidth = status.treewidth or DEFAULT_TREE_WIDTH
        if status.treesizable == nil then status.treesizable = DEFAULT_TREE_RESIZABLE end
        self:SetTreeWidth(status.treewidth, status.treesizable)
        self:RefreshTree()
    end

    function widget:SetTree(tree, filter)
        self.filter = filter
        self.tree = tree
        self:RefreshTree()
    end

    function widget:RefreshTree(scrollToSelection)
        wipe(self.lines)
        if not self.tree then return end
        local status = self.status or self.localstatus
        local groups = status.groups
        buildLevel(self.tree, 1)

        local maxlines = math.floor((safeHeight(treeframe, safeHeight(frame, 400)) - (STYLE.treeRowPadTop + STYLE.treeContentPadBottom)) / TREE_ROW_HEIGHT)
        if maxlines <= 0 then maxlines = 1 end
        local numlines = #self.lines
        local first, last

        if numlines <= maxlines then
            status.scrollvalue = 0
            self:ShowScroll(false)
            first, last = 1, numlines
        else
            self:ShowScroll(true)
            self.noupdate = true
            scrollbar:SetMinMaxValues(0, numlines - maxlines)
            if numlines - status.scrollvalue < maxlines then
                status.scrollvalue = numlines - maxlines
            end
            self.noupdate = nil
            first = status.scrollvalue + 1
            last = status.scrollvalue + maxlines

            if scrollToSelection and status.selected then
                for i, line in ipairs(self.lines) do
                    if line.uniquevalue == status.selected then
                        if i < first then
                            status.scrollvalue = i - 1
                        elseif i > last then
                            status.scrollvalue = i - maxlines
                        end
                        first = status.scrollvalue + 1
                        last = status.scrollvalue + maxlines
                        break
                    end
                end
            end

            if scrollbar:GetValue() ~= status.scrollvalue then
                self.noupdate = true
                scrollbar:SetValue(status.scrollvalue)
                self.noupdate = nil
            end
        end

        local buttonIndex = 1
        for i = first, last do
            local line = self.lines[i]
            if line then
                local button = self.buttons[buttonIndex]
                if not button then
                    button = createTreeButton(self)
                    self.buttons[buttonIndex] = button
                end
                button:ClearAllPoints()
                button:SetParent(treeframe)
                button:SetFrameLevel(treeframe:GetFrameLevel() + 1)
                if buttonIndex == 1 then
                    button:SetPoint("TOPLEFT", 0, -STYLE.treeRowPadTop)
                    button:SetPoint("TOPRIGHT", treeframe, "TOPRIGHT", self.showscroll and -STYLE.treeScrollReserve or 0, -STYLE.treeRowPadTop)
                else
                    button:SetPoint("TOPLEFT", self.buttons[buttonIndex - 1], "BOTTOMLEFT", 0, 0)
                    button:SetPoint("TOPRIGHT", self.buttons[buttonIndex - 1], "BOTTOMRIGHT", 0, 0)
                end
                updateTreeButton(button, line, status.selected == line.uniquevalue, groups[line.uniquevalue])
                button:Show()
                buttonIndex = buttonIndex + 1
            end
        end

        for i = buttonIndex, #self.buttons do
            self.buttons[i]:Hide()
        end

        -- Auto-size navWindow to fit the widest visible tree item.
        -- Compute x offsets from line data (same logic as updateTreeButton)
        -- so measurement is accurate even before frames are on-screen.
        if refreshNavWindow then
            local maxNeeded = 0
            local visibleRows = 0
            for i, btn in ipairs(self.buttons) do
                if btn:IsShown() and btn.text then
                    visibleRows = visibleRows + 1
                    local line = self.lines[i]
                    if line then
                        local level = line.level or 1
                        local x = STYLE.treeIndentBase + ((level - 1) * STYLE.treeIndentStep)
                        if line.hasChildren then x = x + TREE_ROW_TOGGLE_SIZE + STYLE.treeToggleGap end
                        if line.icon then x = x + TREE_ROW_ICON_SIZE + STYLE.treeIconGap end
                        local needed = math.ceil(x + getTreeTextWidth(btn.text) + STYLE.padSmall + 20)
                        if self.showscroll then needed = needed + STYLE.treeScrollReserve end
                        if needed > maxNeeded then maxNeeded = needed end
                    end
                end
            end
            -- Width: follow content
            local clamped = math.min(math.max(maxNeeded, 1), MAX_TREE_WIDTH)
            local st = self.status or self.localstatus
            local widthChanged = math.abs((st.treewidth or 0) - clamped) > 2
            if widthChanged then
                st.treewidth = clamped
                treeframe:SetWidth(clamped)
            end
            -- Height: auto-fit to rows when detached, capped at editor height
            if navWindow and navWindow.GSESideDetached then
                local editorFrame = getEditorFrame and getEditorFrame()
                local maxH = editorFrame and safeHeight(editorFrame, 600) or 600
                local neededH = math.min(
                    STYLE.frameContentTop + STYLE.treeRowPadTop
                        + (visibleRows * TREE_ROW_HEIGHT)
                        + STYLE.treeContentPadBottom + STYLE.frameEdge
                        + NAV_CHECKBOX_AREA,    -- reserve space for the All Sequences checkbox row
                    maxH
                )
                -- Enforce the visible-rows dimensions as the WoW-level minimums so
                -- the user can't drag the resize grip smaller than what the rows
                -- need, even mid-drag. The bounds update every refresh, so
                -- collapsing nodes lets the window shrink and expanding nodes
                -- grows the floors (both height for rows + width for text length).
                -- 'clamped' is the widest visible row's pixel width (computed above);
                -- +8 matches the navWindow padding around the inner treeframe.
                setFrameResizeBounds(
                    navWindow,
                    math.max(MIN_TREE_WIDTH + 8, clamped + 8),
                    math.max(150, neededH)
                )

                if not navWindow.GSENavResizing then
                    local tw = math.max(MIN_TREE_WIDTH, st.treewidth or DEFAULT_TREE_WIDTH)
                    local targetW = tw + 8
                    local targetH = neededH
                    -- Honour the user's manual resize: when they've explicitly sized
                    -- the floating window, use the user's size as a floor — content
                    -- still always fits, but we never shrink below what they chose.
                    local geom = GSE.GUI and GSE.GUI.navDetachGeom
                    if geom and geom.userResized then
                        if geom.userW and geom.userW > targetW then targetW = geom.userW end
                        if geom.userH and geom.userH > targetH then targetH = geom.userH end
                    end
                    local currentW = navWindow:GetWidth() or targetW
                    local currentH = navWindow:GetHeight() or targetH
                    if math.abs(currentH - targetH) > 2 or math.abs(currentW - targetW) > 2 then
                        navWindow:SetSize(targetW, targetH)
                    end
                end
            elseif widthChanged then
                refreshNavWindow()
            end
        end
    end

    function widget:SetSelected(value)
        local status = self.status or self.localstatus
        if status.selected ~= value then
            status.selected = value
            self:Fire("OnGroupSelected", value)
        end
    end

    function widget:Select(uniquevalue, ...)
        self.filter = false
        local status = self.status or self.localstatus
        local groups = status.groups
        local parts = {...}
        for i = 1, #parts do
            groups[table.concat(parts, "\001", 1, i)] = true
        end
        status.selected = uniquevalue
        self:RefreshTree(true)
        self:Fire("OnGroupSelected", uniquevalue)
    end

    function widget:SelectByPath(...)
        self:Select(buildUnique(...), ...)
    end

    function widget:SelectByValue(uniquevalue)
        self:Select(uniquevalue, unpack(splitUnique(uniquevalue)))
    end

    -- Expand the parent groups of the currently selected node and scroll it into
    -- view WITHOUT re-firing OnGroupSelected. Used when an editor gains the tree
    -- so the tree opens to the sequence/version/page that editor is already on,
    -- rather than re-loading content or jumping to the top.
    function widget:RevealSelection()
        local status = self.status or self.localstatus
        local sel = status and status.selected
        if not sel then return end
        local groups = status.groups
        local parts = splitUnique(sel)
        for i = 1, #parts do
            groups[table.concat(parts, "\001", 1, i)] = true
        end
        self:RefreshTree(true)
    end

    function widget:ShowScroll(show)
        self.showscroll = show
        if show then
            scrollbar:Show()
        else
            scrollbar:Hide()
        end
    end

    function widget:OnWidthSet(width)
        local status = self.status or self.localstatus
        status.fullwidth = width
        -- border always fills the full frame now; navWindow floats separately
        content:SetWidth(math.max(1, width - (STYLE.treeContentPadX * 2)))
        if navVisible and not self.skipTreeRefresh then refreshNavWindow() end
    end

    function widget:OnHeightSet(height)
        content:SetHeight(math.max(1, height - (STYLE.treeContentPadTop + STYLE.treeContentPadBottom)))
        -- Skip the full tree rebuild during a resize drag (same gate as OnWidthSet).
        if not self.skipTreeRefresh then self:RefreshTree() end
    end

    function widget:SetTreeWidth(treewidth, resizable)
        if type(treewidth) == "boolean" then
            resizable = treewidth
            treewidth = DEFAULT_TREE_WIDTH
        end
        treewidth = clampTreeWidth(treewidth)
        local status = self.status or self.localstatus
        status.treewidth = treewidth
        status.treesizable = resizable ~= false
        setFrameResizeBounds(treeframe, MIN_TREE_WIDTH, 120)
        treeframe:SetWidth(treewidth)
        dragger:EnableMouse(status.treesizable)
        if status.fullwidth then self:OnWidthSet(status.fullwidth) end
    end

    function widget:GetTreeWidth()
        return (self.status or self.localstatus).treewidth or DEFAULT_TREE_WIDTH
    end

    widget:SetTreeWidth(DEFAULT_TREE_WIDTH, DEFAULT_TREE_RESIZABLE)
    if GSE.Skin and GSE.Skin.Frame then GSE.Skin.Frame(frame, false) end
    return widget
end

function UI:Create(typeName)
    if typeName == "Frame" or typeName == "Window" then
        return createFrame()
    elseif typeName == "SimpleGroup" or typeName == "InlineGroup" or typeName == "Spacer" then
        return createContainer(typeName)
    elseif typeName == "ScrollFrame" then
        return createScrollFrame()
    elseif typeName == "Button" then
        return createButton()
    elseif typeName == "PanelTabButton" then
        return createPanelTabButton()
    elseif typeName == "Label" or typeName == "InteractiveLabel" then
        return createLabel(typeName, "GameFontNormal")
    elseif typeName == "Heading" then
        return createLabel(typeName, "GameFontHighlightLarge")
    elseif typeName == "EditBox" or typeName == "EditBoxExampleAll" then
        return createEditBox()
    elseif typeName == "MultiLineEditBox" then
        return createMultiLineEditBox()
    elseif typeName == "CheckBox" then
        return createCheckBox()
    elseif typeName == "Icon" then
        return createIcon()
    elseif typeName == "Dropdown" then
        return createDropdown()
    elseif typeName == "TabGroup" then
        return createTabGroup()
    elseif typeName == "ControllerKeybinding" then
        return createControllerKeybinding()
    elseif typeName == "GSE-TreeGroup" then
        return createTreeGroup()
    end

    error(("GSE.UI does not implement widget type '%s' yet."):format(tostring(typeName)), 2)
end

function UI:Release(widget)
    if widget and widget.Release then
        widget:Release()
    end
end

function UI:ClearFocus()
    if GetCurrentKeyBoardFocus then
        local focus = GetCurrentKeyBoardFocus()
        if focus then focus:ClearFocus() end
    end
end

-- ---------------------------------------------------------------------------
-- UI.MakePopup(frame, opts)
-- Single source of truth for "this frame is a popup". Sets the strata and
-- behaviour that every GSE popup needs so individual callers don't each
-- reimplement (and drift on) the same boilerplate. Any future change to
-- popup-level defaults (strata, raise behaviour, clamp policy) lives in
-- this one function instead of being scattered across 9 files.
--
-- Defaults: TOOLTIP strata + SetToplevel(true) + SetClampedToScreen(true).
-- TOOLTIP is the highest strata available and is what GSE popups need to
-- consistently draw over the Blizzard Settings panel (which sits at
-- FULLSCREEN_DIALOG and aggressively re-raises itself).
--
-- opts (all optional):
--   strata     = override strata string (defaults to "TOOLTIP")
--   frameLevel = explicit frame level within the strata. Useful when one
--                popup needs to layer over another at the SAME strata
--                (e.g. version-copy popup over the Resources frame). Stays
--                unset by default so we don't fight WoW's natural ordering.
--   center     = true to anchor the frame to UIParent CENTER (clears any
--                existing points first). Use when the frame doesn't carry
--                a saved position.
--   movable    = true to make the frame click-and-drag movable. Sets up
--                EnableMouse + SetMovable + RegisterForDrag("LeftButton")
--                + Start/StopMoving handlers in one call.
--   clamp      = false to disable the default SetClampedToScreen. Rare —
--                a popup that intentionally extends off-screen would set
--                this; almost no GSE popup does.
--   toplevel   = false to skip SetToplevel. Default true.
--
-- Returns the frame so the call can be chained inline.
-- ---------------------------------------------------------------------------
function UI.MakePopup(frame, opts)
    opts = opts or {}
    if not frame then return frame end

    if frame.SetFrameStrata then
        frame:SetFrameStrata(opts.strata or "TOOLTIP")
    end
    if opts.toplevel ~= false and frame.SetToplevel then
        frame:SetToplevel(true)
    end
    if opts.clamp ~= false and frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
    if opts.frameLevel and frame.SetFrameLevel then
        frame:SetFrameLevel(opts.frameLevel)
    end
    if opts.center and frame.SetPoint and frame.ClearAllPoints then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if opts.movable then
        if frame.SetMovable      then frame:SetMovable(true) end
        if frame.EnableMouse     then frame:EnableMouse(true) end
        if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
        if frame.SetScript then
            frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
            frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
        end
    end

    return frame
end

-- ---------------------------------------------------------------------------
-- UI.ShowInputDialog(opts)
-- A reusable single-line text-input dialog skinned with the GSE native frame
-- (matches the editor look instead of the stock Blizzard StaticPopup). A single
-- instance is cached and reused, like ShowResourcesPopup, to avoid frame leaks.
-- opts = {
--   title      = window title text,
--   prompt     = label shown above the edit box,
--   note       = faded-grey line shown below the edit box (optional),
--   default    = pre-filled text (selected so it can be typed over),
--   acceptText = accept-button label (default "Create"),
--   maxLetters = edit-box character cap (default 60),
--   owner      = widget/frame to centre on (optional; defaults to UIParent),
--   onAccept   = function(text) called with the trimmed entry on accept,
-- }
-- ---------------------------------------------------------------------------
local inputDialog
function UI.ShowInputDialog(opts)
    opts = opts or {}
    if not inputDialog then
        local dialog = UI:Create("Frame")
        dialog:SetLayout("List")
        dialog:SetListPadding(14, 8, 14, 8)
        dialog:SetListGap(6)
        dialog:SetResizable(false)
        if dialog.frame then UI.MakePopup(dialog.frame) end

        local prompt = UI:Create("Label")
        prompt:SetFullWidth(true)
        prompt:SetJustifyH("CENTER")
        prompt:SetFontObject(GameFontNormal)
        dialog:AddChild(prompt)
        dialog.promptLabel = prompt

        local input = UI:Create("EditBox")
        input:SetFullWidth(true)
        input:SetCompactNoLabel(true)
        input:SetHeight(28)
        dialog:AddChild(input)
        dialog.input = input

        local note = UI:Create("Label")
        note:SetFullWidth(true)
        note:SetJustifyH("CENTER")
        note:SetFontObject(GameFontDisableSmall)
        note:SetColor(0.5, 0.5, 0.5)
        dialog:AddChild(note)
        dialog.noteLabel = note

        local buttons = UI:Create("SimpleGroup")
        buttons:SetFullWidth(true)
        buttons:SetLayout("Flow")
        buttons.flowHAlign  = "CENTER"   -- centre the Create/Cancel pair
        buttons.flowPadTop    = 2
        buttons.flowPadBottom = 2
        buttons:SetHeight(28)
        dialog:AddChild(buttons)

        local function doAccept()
            local text = strtrim(dialog.input:GetText() or "")
            dialog:Hide()
            if not GSE.isEmpty(text) and dialog.onAcceptFn then
                dialog.onAcceptFn(text)
            end
        end

        local acceptBtn = UI:Create("Button")
        acceptBtn:SetWidth(110)
        acceptBtn:SetCallback("OnClick", doAccept)
        buttons:AddChild(acceptBtn)
        dialog.acceptBtn = acceptBtn

        local cancelBtn = UI:Create("Button")
        cancelBtn:SetText(CANCEL)
        cancelBtn:SetWidth(110)
        cancelBtn:SetCallback("OnClick", function() dialog:Hide() end)
        buttons:AddChild(cancelBtn)

        input:SetCallback("OnEnterPressed", doAccept)

        inputDialog = dialog
    end

    local d = inputDialog
    d.onAcceptFn = opts.onAccept
    d:SetTitle(opts.title or "")
    d.promptLabel:SetText(opts.prompt or "")
    d.noteLabel:SetText(opts.note or "")
    d.acceptBtn:SetText(opts.acceptText or "Create")
    d.input:SetMaxLetters(tonumber(opts.maxLetters) or 60)
    d.input:SetText(opts.default or "")

    d:SetSize(opts.width or 360, opts.height or 196)
    d:ClearAllPoints()
    d:SetPoint("CENTER", (opts.owner and opts.owner.frame) or UIParent, "CENTER", 0, 0)
    d:Show()
    d:DoLayout()
    d.input:SetFocus()
    if not GSE.isEmpty(opts.default) and d.input.editBox and d.input.editBox.HighlightText then
        d.input.editBox:HighlightText()
    end
    return d
end

-- ---------------------------------------------------------------------------
-- UI.ShowMessageDialog(opts)
-- A reusable informational dialog skinned with the GSE native frame: a title
-- (rendered as "GSE: <title>"), an optional faded-grey note line, and a single
-- dismiss button. Cached/reused like ShowInputDialog. Used for confirmations
-- such as "Sequence Renamed".
-- opts = {
--   title      = headline shown in the title bar,
--   note       = faded-grey body line (optional),
--   buttonText = dismiss-button label (default CLOSE),
--   owner      = widget/frame to centre on (optional; defaults to UIParent),
--   onClose    = function() called when dismissed (optional),
-- }
-- ---------------------------------------------------------------------------
local messageDialog
function UI.ShowMessageDialog(opts)
    opts = opts or {}
    if not messageDialog then
        local dialog = UI:Create("Frame")
        dialog:SetLayout("List")
        dialog:SetListPadding(14, 12, 14, 12)
        dialog:SetListGap(10)
        dialog:SetResizable(false)
        if dialog.frame then UI.MakePopup(dialog.frame) end

        local note = UI:Create("Label")
        note:SetFullWidth(true)
        note:SetJustifyH("CENTER")
        note:SetFontObject(GameFontDisableSmall)
        note:SetColor(0.5, 0.5, 0.5)
        dialog:AddChild(note)
        dialog.noteLabel = note

        local buttons = UI:Create("SimpleGroup")
        buttons:SetFullWidth(true)
        buttons:SetLayout("Flow")
        buttons.flowHAlign  = "CENTER"
        buttons.flowPadTop    = 2
        buttons.flowPadBottom = 2
        buttons:SetHeight(28)
        dialog:AddChild(buttons)

        local closeBtn = UI:Create("Button")
        closeBtn:SetWidth(120)
        closeBtn:SetCallback("OnClick", function()
            dialog:Hide()
            if dialog.onCloseFn then dialog.onCloseFn() end
        end)
        buttons:AddChild(closeBtn)
        dialog.closeBtn = closeBtn

        messageDialog = dialog
    end

    local d = messageDialog
    d.onCloseFn = opts.onClose
    d:SetTitle(opts.title or "")
    d.noteLabel:SetText(opts.note or "")
    d.closeBtn:SetText(opts.buttonText or CLOSE)

    d:SetSize(opts.width or 320, opts.height or 140)
    d:ClearAllPoints()
    d:SetPoint("CENTER", (opts.owner and opts.owner.frame) or UIParent, "CENTER", 0, 0)
    d:Show()
    d:DoLayout()
    return d
end

-- ---------------------------------------------------------------------------
-- UI.ShowConfirmDialog(opts)
-- A square destructive-confirmation dialog skinned with the GSE native frame.
-- Draws an optional faded background warning image behind a centred multi-line
-- message, with confirm/cancel buttons pinned to the native footer. Cached and
-- reused like the other dialogs.
-- opts = {
--   title       = headline shown in the title bar,
--   message     = centred multi-line body text (colour codes allowed),
--   bgImage     = texture path drawn faded behind the text (optional),
--   bgAlpha     = background image opacity (default 0.5),
--   confirmText = confirm-button label (default OKAY),
--   cancelText  = cancel-button label (default CANCEL),
--   owner       = widget/frame to centre on (optional; defaults to UIParent),
--   onConfirm   = function() called when confirmed,
--   onCancel    = function() called when cancelled (optional),
--   size        = square edge length in px (default 340),
-- }
-- ---------------------------------------------------------------------------
local confirmDialog, confirmBoldFont
function UI.ShowConfirmDialog(opts)
    opts = opts or {}
    if not confirmDialog then
        local dialog = UI:Create("Frame")
        dialog:SetLayout("List")
        dialog:SetListPadding(6, 6, 6, 6)
        dialog:SetListGap(8)
        dialog:SetResizable(false)
        if dialog.frame then UI.MakePopup(dialog.frame) end

        -- Small faded warning image, centred behind the text (watermark style).
        local bg = dialog.content:CreateTexture(nil, "BACKGROUND", nil, 1)
        bg:SetPoint("CENTER", dialog.content, "CENTER", 0, 0)
        bg:SetSize(110, 110)
        bg:Hide()
        dialog.bgImage = bg

        -- Bold (outlined) version of GameFontNormal, keeping its colour, so the
        -- message reads strongly over the watermark.
        if not confirmBoldFont then
            confirmBoldFont = CreateFont("GSEConfirmBoldFont")
            local fontFile, fontSize = GameFontNormal:GetFont()
            confirmBoldFont:SetFont(fontFile, (tonumber(fontSize) or 12) + 1, "OUTLINE")
            local fr, fg, fb = GameFontNormal:GetTextColor()
            confirmBoldFont:SetTextColor(fr or 1, fg or 0.82, fb or 0)
        end

        -- Message fills the body so the text centres both horizontally and
        -- vertically (the FontString is anchored to all four edges of its frame).
        local message = UI:Create("Label")
        message.frame:SetParent(dialog.content)
        message.frame:ClearAllPoints()
        message.frame:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", 6, -6)
        message.frame:SetPoint("BOTTOMRIGHT", dialog.content, "BOTTOMRIGHT", -6, 6)
        message:SetFontObject(confirmBoldFont)
        message:SetJustifyH("CENTER")
        message:SetJustifyV("MIDDLE")
        dialog.messageLabel = message

        -- Confirm / Cancel pinned to the native footer (bottom of the frame).
        local confirmBtn = UI:Create("Button")
        confirmBtn:SetWidth(110)
        confirmBtn:SetCallback("OnClick", function()
            dialog:Hide()
            if dialog.onConfirmFn then dialog.onConfirmFn() end
        end)
        dialog.confirmBtn = confirmBtn

        local cancelBtn = UI:Create("Button")
        cancelBtn:SetWidth(110)
        cancelBtn:SetCallback("OnClick", function()
            dialog:Hide()
            if dialog.onCancelFn then dialog.onCancelFn() end
        end)
        dialog.cancelBtn = cancelBtn

        if dialog.SetFooterHeight then dialog:SetFooterHeight(30) end
        if dialog.SetFooterBottomOffset then dialog:SetFooterBottomOffset(14) end
        if dialog.SetFooterGap then dialog:SetFooterGap(12) end
        if dialog.SetFooterAlignment then dialog:SetFooterAlignment("CENTER") end
        if dialog.AddFooterChild then
            dialog:AddFooterChild(confirmBtn, 1)
            dialog:AddFooterChild(cancelBtn, 1)
        end
        if dialog.SetFooterShown then dialog:SetFooterShown(true) end

        confirmDialog = dialog
    end

    local d = confirmDialog
    d.onConfirmFn = opts.onConfirm
    d.onCancelFn  = opts.onCancel
    d:SetTitle(opts.title or "")
    d.messageLabel:SetText(opts.message or "")
    d.confirmBtn:SetText(opts.confirmText or OKAY)
    d.cancelBtn:SetText(opts.cancelText or CANCEL)

    if not GSE.isEmpty(opts.bgImage) then
        local imgSize = tonumber(opts.imageSize) or 110
        d.bgImage:SetSize(imgSize, imgSize)
        d.bgImage:SetTexture(opts.bgImage)
        d.bgImage:SetAlpha(tonumber(opts.bgAlpha) or 0.1)
        d.bgImage:Show()
    else
        d.bgImage:Hide()
    end

    local w = tonumber(opts.width) or tonumber(opts.size) or 340
    local h = tonumber(opts.height) or tonumber(opts.size) or 340
    d:SetSize(w, h)
    d:ClearAllPoints()
    d:SetPoint("CENTER", (opts.owner and opts.owner.frame) or UIParent, "CENTER", 0, 0)
    d:Show()
    d:DoLayout()
    if d.DoFooterLayout then d:DoFooterLayout() end
    return d
end

-- ---------------------------------------------------------------------------
-- UI.ShowLinkDialog(opts)
-- A copy-a-link dialog skinned with the GSE native frame: a prompt line, a
-- read-only box pre-filled with the link (auto-selected so the user can press
-- Ctrl+C immediately — WoW exposes no clipboard-write API), and a single button
-- that re-selects the text and closes. Cached/reused like the other dialogs.
-- opts = {
--   title      = headline shown in the title bar,
--   prompt     = instruction line above the box,
--   link       = text shown in the read-only box,
--   buttonText = button label (default "Copy"),
--   owner      = widget/frame to centre on (optional; defaults to UIParent),
--   onCopy     = function() called after the button is clicked (optional),
-- }
-- ---------------------------------------------------------------------------
local linkDialog
function UI.ShowLinkDialog(opts)
    opts = opts or {}
    if not linkDialog then
        local dialog = UI:Create("Frame")
        dialog:SetLayout("List")
        dialog:SetListPadding(14, 12, 14, 4)
        dialog:SetListGap(8)
        dialog:SetResizable(false)
        -- FULLSCREEN_DIALOG + high frame level so the link dialog always sits
        -- ABOVE the Resources popup (which itself is FULLSCREEN_DIALOG / level 200).
        -- DIALOG strata would put the version-copy popup underneath when launched
        -- from the Resources frame.
        if dialog.frame then UI.MakePopup(dialog.frame, {frameLevel = 250}) end

        local prompt = UI:Create("Label")
        prompt:SetFullWidth(true)
        prompt:SetJustifyH("CENTER")
        prompt:SetFontObject(GameFontNormal)
        dialog:AddChild(prompt)
        dialog.promptLabel = prompt

        local input = UI:Create("EditBox")
        input:SetFullWidth(true)
        input:SetCompactNoLabel(true)
        input:SetHeight(28)
        -- Read-only: revert any edit back to the link and keep it selected so a
        -- Ctrl+C always grabs the whole, unmodified link.
        input:SetCallback("OnTextChanged", function(widget, _, text)
            if text ~= (dialog.linkText or "") then
                widget:SetText(dialog.linkText or "")
            end
            if widget.editBox then widget.editBox:HighlightText() end
        end)
        input:SetCallback("OnEnterPressed", function() dialog:Hide() end)
        dialog:AddChild(input)
        dialog.input = input

        local buttons = UI:Create("SimpleGroup")
        buttons:SetFullWidth(true)
        buttons:SetLayout("Flow")
        buttons.flowHAlign    = "CENTER"
        buttons.flowPadTop    = 2
        buttons.flowPadBottom = 2
        buttons:SetHeight(28)
        dialog:AddChild(buttons)

        local closeBtn = UI:Create("Button")
        closeBtn:SetWidth(120)
        closeBtn:SetCallback("OnClick", function()
            dialog:Hide()
            if dialog.onCloseFn then dialog.onCloseFn() end
        end)
        buttons:AddChild(closeBtn)
        dialog.closeBtn = closeBtn

        -- Grey reminder that copying is a manual Ctrl+C (WoW has no clipboard
        -- API), shown below the button.
        local note = UI:Create("Label")
        note:SetFullWidth(true)
        note:SetJustifyH("CENTER")
        note:SetFontObject(GameFontDisableSmall)
        note:SetColor(0.5, 0.5, 0.5)
        dialog:AddChild(note)
        dialog.noteLabel = note

        linkDialog = dialog
    end

    local d = linkDialog
    d.onCloseFn = opts.onClose
    d.linkText  = opts.link or ""
    d:SetTitle(opts.title or "")
    d.promptLabel:SetText(opts.prompt or "")
    d.closeBtn:SetText(opts.buttonText or CLOSE)
    d.noteLabel:SetText(opts.note or "")
    d.input:SetText(d.linkText)

    d:SetSize(opts.width or 380, opts.height or 192)
    d:ClearAllPoints()
    d:SetPoint("CENTER", (opts.owner and opts.owner.frame) or UIParent, "CENTER", 0, 0)
    d:Show()
    d:DoLayout()
    if d.input then
        d.input:SetFocus()
        if d.input.editBox then d.input.editBox:HighlightText() end
    end
    return d
end

-- ---------------------------------------------------------------------------
-- GSE.GUIShowVersionCopyWindow()
-- Shared "copy the version string" popup. Lives here (not in DebugWindow) so
-- every entry point — the menu's Shift+Right-Click, the Editor, and the Debug
-- window — opens the same native dialog with no dependency on the debug frame.
-- Thin wrapper over UI.ShowLinkDialog (auto-selected text + manual Ctrl+C).
-- ---------------------------------------------------------------------------
function GSE.GUIShowVersionCopyWindow()
    local L = GSE.L
    local versionText = tostring(GSE.VersionString or "")
    if versionText == "" then versionText = "Unknown" end
    UI.ShowLinkDialog({
        title      = L["Version"],
        prompt     = L["Version Number"],
        link       = versionText,
        buttonText = CLOSE,
        note       = L["Text selected. Press Ctrl+C to Copy"],
    })
end

-- ===========================================================================
-- Shared GSE popups (migrated from Blizzard StaticPopupDialogs).
-- Each renders through the native dialog primitives above so every GSE popup
-- shares one look. Cross-cutting content lives here; one-off confirmations
-- (e.g. sequence/version delete) call the primitives directly from the feature.
-- ===========================================================================

-- Reload-UI confirmation (Yes / No → ReloadUI).
function GSE.GUIConfirmReloadUI()
    UI.ShowConfirmDialog({
        title       = L["Reload"],
        message     = L["You need to reload the User Interface to complete this task.  Would you like to do this now?"],
        confirmText = L["Yes"],
        cancelText  = L["No"],
        width       = 380,
        height      = 180,
        onConfirm   = function() ReloadUI() end,
    })
end

-- Macro import failed.
function GSE.GUIShowImportFailure()
    UI.ShowMessageDialog({
        title      = L["Import"],
        note       = L["Import String Not Recognised."],
        buttonText = CLOSE,
    })
end

-- Developer debug settings active warning.
function GSE.GUIShowDeveloperDebugWarning(reasons)
    UI.ShowMessageDialog({
        title      = L["Developer Debug"],
        note       = string.format(
            L["GSE Developer Debug settings are active.\n\nActive: %s\n\nThese settings can create heavy logging during gameplay or loading."],
            tostring(reasons or "")
        ),
        buttonText = OKAY,
        width      = 380,
        height     = 180,
    })
end

-- "Update available" — copyable download URL.
function GSE.GUIShowUpdateAvailable()
    UI.ShowLinkDialog({
        title      = L["Update"],
        prompt     = L["GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."],
        link       = "https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros",
        buttonText = CLOSE,
        note       = L["Text selected. Press Ctrl+C to Copy"],
        width      = 480,
    })
end

-- New-variable name prompt.
function GSE.GUINewVariablePrompt(editor)
    UI.ShowInputDialog({
        owner      = editor,
        title      = L["New"] .. " " .. L["Variable"],
        prompt     = L["Enter a name for the new variable:"],
        acceptText = L["Create"],
        maxLetters = 60,
        onAccept   = function(name)
            if not GSE.isEmpty(name) then
                GSE.GUICreateNewVariable(editor, name)
            end
        end,
    })
end

-- Corrupt-sequence recovery prompt (Delete / Skip); advances the chain either way.
function GSE.GUIConfirmCorruptSequence(classid, name, bodyText)
    UI.ShowConfirmDialog({
        title       = L["Corrupt Sequence"],
        message     = tostring(bodyText or ""),
        confirmText = L["Delete"],
        cancelText  = L["Skip"],
        width       = 420,
        height      = 220,
        onConfirm   = function()
            GSE.DeleteCorruptSequence(classid, name)
            GSE.ProcessNextCorruptSequence()
        end,
        onCancel    = function()
            GSE.ProcessNextCorruptSequence()
        end,
    })
end

-- Sequence-integrity (checksum) warning during import (Proceed / Cancel).
function GSE.GUIConfirmSequenceIntegrity(seqName, sequence, forcereplace)
    local Statics = GSE.Static
    UI.ShowConfirmDialog({
        title       = L["Import"],
        message     = L["GSE_SEQUENCE_INTEGRITY_WARNING_TEXT"],
        confirmText = L["Proceed"],
        cancelText  = CANCEL,
        width       = 420,
        height      = 240,
        onConfirm   = function()
            if forcereplace then
                GSE.PerformMergeAction("REPLACE", GSE.GetClassIDforSpec(sequence.MetaData.SpecID), seqName, sequence)
            else
                GSE.AddSequenceToCollection(seqName, sequence)
            end
            GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, seqName)
        end,
    })
end

-- Older-version warning during import (Proceed / Cancel); chains to the
-- integrity check when the sequence is new enough to carry a checksum.
function GSE.GUIConfirmSequenceOlderVersion(seqName, sequence, forcereplace)
    local Statics = GSE.Static
    UI.ShowConfirmDialog({
        title       = L["Import"],
        message     = L["GSE_SEQUENCE_OLDER_VERSION_TEXT"],
        confirmText = L["Proceed"],
        cancelText  = CANCEL,
        width       = 420,
        height      = 240,
        onConfirm   = function()
            if sequence.MetaData.GSEVersion >= Statics.ChecksumMinVersion and GSE.VerifySequenceChecksum then
                local integrity = GSE.VerifySequenceChecksum(sequence)
                if integrity ~= true then
                    GSE.GUIConfirmSequenceIntegrity(seqName, sequence, forcereplace)
                    return
                end
            end
            if forcereplace then
                GSE.PerformMergeAction("REPLACE", GSE.GetClassIDforSpec(sequence.MetaData.SpecID), seqName, sequence)
            else
                GSE.AddSequenceToCollection(seqName, sequence)
            end
            GSE:SendMessage(Statics.Messages.SEQUENCE_UPDATED, seqName)
        end,
    })
end

-- Debug-output dump — scrollable multi-line text with Update / Close.
local debugOutputDialog
function GSE.GUIShowDebugOutput()
    if not debugOutputDialog then
        local dialog = UI:Create("Frame")
        dialog:SetLayout("List")
        dialog:SetResizable(false)
        if dialog.frame then UI.MakePopup(dialog.frame) end
        dialog:SetTitle(L["Debug"])

        local box = UI:Create("MultiLineEditBox")
        box:SetLabel("")
        box.frame:SetParent(dialog.content)
        box.frame:ClearAllPoints()
        box.frame:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", 6, -6)
        box.frame:SetPoint("BOTTOMRIGHT", dialog.content, "BOTTOMRIGHT", -6, 6)
        dialog.box = box

        local updateBtn = UI:Create("Button")
        updateBtn:SetWidth(110)
        updateBtn:SetCallback("OnClick", function() dialog.box:SetText(GSE.DebugOutput or "") end)
        dialog.updateBtn = updateBtn

        local closeBtn = UI:Create("Button")
        closeBtn:SetWidth(110)
        closeBtn:SetCallback("OnClick", function() dialog:Hide() end)
        dialog.closeBtn = closeBtn

        if dialog.SetFooterHeight then dialog:SetFooterHeight(30) end
        if dialog.SetFooterBottomOffset then dialog:SetFooterBottomOffset(14) end
        if dialog.SetFooterGap then dialog:SetFooterGap(10) end
        if dialog.SetFooterAlignment then dialog:SetFooterAlignment("CENTER") end
        if dialog.AddFooterChild then
            dialog:AddFooterChild(updateBtn, 1)
            dialog:AddFooterChild(closeBtn, 1)
        end
        if dialog.SetFooterShown then dialog:SetFooterShown(true) end
        updateBtn:SetText(L["Update"])
        closeBtn:SetText(CLOSE)

        debugOutputDialog = dialog
    end
    local d = debugOutputDialog
    d:SetSize(560, 420)
    d:ClearAllPoints()
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    d.box:SetText(GSE.DebugOutput or "")
    d:Show()
    d:DoLayout()
    if d.DoFooterLayout then d:DoFooterLayout() end
end

-- ---------------------------------------------------------------------------
-- CreateEditorSidePanel  →  Right Side Window
-- A real movable/resizable window that mirrors the Left nav window's behaviour:
--   * Docked: anchored flush to the editor's RIGHT edge at full editor height.
--   * Detached: drag the title/body to float it free; resize grip + close button.
--   * Snap: drag near the editor's right edge to re-dock.
--   * Toggle: an edge chevron + invisible click strip + gold hover bar on the
--     editor's right side open/close it (persisted in rightVisible).
--   * Single shared across editors: only the ACTIVE editor shows it docked, and
--     while floating it sticks to the editor it was detached from (rightFloatOwner).
--   * Edge controls deactivate while it floats, like the left side.
-- Fill panel.content with buttons. Global state: GSE.GUI.right{Visible,Detached,
-- DetachGeom,FloatOwner}; refresh runs from GSE.GUI.SyncTrees via RefreshSidePanel.
-- ---------------------------------------------------------------------------
function UI.CreateEditorSidePanel(editorFrame, contentFrame)
    if not editorFrame then return nil end
    if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

    local SIDE_SNAP_TOLERANCE = GSE.DEBUGGER_SIDE_SNAP_TOLERANCE or 28
    -- Side-dock offset: how many pixels LEFT of the editor's right edge the
    -- docked panel's left edge sits — i.e. how much the panel's bounding
    -- box overlaps the editor's. 0 means flush bounding boxes, which LOOKS
    -- like a gap because ButtonFrameTemplate's gold trim has natural edge
    -- inset on both sides — set the two frames flush and you see two trims
    -- with several pixels of background showing between them. 5 overlaps
    -- the trims enough to eat that gap without bleeding panel content into
    -- editor content (frameBodyInset is 5, so at 5 the panel's left edge
    -- sits exactly where the editor's body content ends — visually clean).
    --
    -- IMPORTANT: line 6546 reads this value, so the docked SetPoint stays
    -- in sync; line 6351's snap detector reads it too so dragging the
    -- panel toward the editor still latches onto the same anchor. Change
    -- this in ONE place and everything downstream lines up.
    local SIDE_DOCK_OFFSET_X  = 5     -- 5px overlap so the editor + side panel trims look like one continuous frame
    local DEFAULT_SIDE_WIDTH  = 220
    local MIN_SIDE_WIDTH      = 120

    -- Persisted open/closed state (mirrors the tree's navVisible).
    local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
    local rightVisible = true
    if seOpts and seOpts.rightVisible ~= nil then rightVisible = seOpts.rightVisible end

    -- Find the editframe widget that owns this editor frame (for floatOwner).
    local function ownerEditor()
        for _, e in ipairs((GSE.GUI and GSE.GUI.editors) or {}) do
            if e and e.frame == editorFrame then return e end
        end
        return nil
    end

    local panel = createBlizzardPanelFrame(nextName("GSESideWindow"))
    panel:SetFrameStrata("MEDIUM")
    if panel.SetToplevel then panel:SetToplevel(true) end
    applyFrameScreenBuffer(panel)
    if GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(panel) end
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetResizable(true)
    setFrameResizeBounds(panel, MIN_SIDE_WIDTH, 150)
    panel:RegisterForDrag("LeftButton")
    panel:HookScript("OnShow", function(self)
        if GSE.ApplyScaleToFrame then GSE.ApplyScaleToFrame(self) end
        applyNormalAccentWindowSkin(self)
    end)
    local usesStock = styleBlizzardPanelFrame(panel)
    if not usesStock then skinPanel(panel) end

    -- Close button — hidden when docked, shown when detached
    local closeBtn = panel.CloseButton
    if closeBtn then
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", STYLE.closeButtonOffsetX, STYLE.closeButtonOffsetY)
        closeBtn:Hide()
    end
    -- Classic / BoA / MoP with the native skin only: cover BasicFrameTemplate
    -- WithInset's leftover corner artifact at the TOPRIGHT with a 21x16 chrome
    -- tile. Skipped on retail (ButtonFrameTemplate is clean) and on ElvUI
    -- (which supplies its own chrome).
    if (GSE.GameMode or 11) < 11 and not shouldUseElvUISkin() then
        local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
        fill:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\ClassicTitleFill.png")
        fill:SetSize(21, 16)
        fill:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -3)
    end

    panel:Hide()
    panel.GSESideDetached = false
    panel.sideWidth = DEFAULT_SIDE_WIDTH

    -- Resize grip — shown only when detached
    local resizeBtn = CreateFrame("Button", nil, panel)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:EnableMouse(true)
    resizeBtn:RegisterForClicks("AnyDown")
    if resizeBtn.SetFrameLevel and panel.GetFrameLevel then
        resizeBtn:SetFrameLevel((panel:GetFrameLevel() or 0) + 80)
    end
    resizeBtn:Hide()
    panel.GSESideResizeButton = resizeBtn

    -- Inner recessed inset — mirrors the left tree window, whose tree sits inside
    -- a skinInset panel. This gives the right window the same sunken inner-panel
    -- look (and ElvUI variant when that skin is active). Buttons go in panel.content,
    -- which sits inside the inset with the standard inset padding.
    local inset = CreateFrame("Frame", nil, panel, frameTemplate)
    -- Asymmetric side margins so the visible chrome is THICK on the LEFT (the docked
    -- side, against the editor) and THIN on the RIGHT (the clean outer edge). Top
    -- skips the title-bar chrome (controlHeight matches styleBlizzardPanelFrame's
    -- Inset positioning); without this, the dark recess bleeds into the title bar
    -- on Classic/MoP's BasicFrameTemplateWithInset where the title chrome is
    -- visibly textured.
    local SIDE_MARGIN_THICK = STYLE.frameEdge + 6   -- left
    local SIDE_MARGIN_THIN  = 2                      -- right
    inset:SetPoint("TOPLEFT",     panel, "TOPLEFT",      SIDE_MARGIN_THICK, -STYLE.controlHeight)
    inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -SIDE_MARGIN_THIN,   STYLE.frameEdge)
    skinInset(inset)
    panel.inset = inset

    -- Content area for the caller to fill with buttons later.
    local content = CreateFrame("Frame", nil, inset)
    content:SetPoint("TOPLEFT",     inset, "TOPLEFT",     STYLE.padInset, -STYLE.padInset)
    content:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -STYLE.padInset,  STYLE.padInset)
    panel.content = content

    -- "Under Construction" watermark. Centered in the content area at 25%
    -- opacity, BACKGROUND draw layer so it never intercepts clicks or paints
    -- over interactive widgets the caller drops in. The texture is the
    -- 256x256 source artwork capped to a square inside the content area so
    -- it stays readable on narrow side-panel widths.
    do
        local wm = content:CreateTexture(nil, "BACKGROUND")
        wm:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\UnderConstruction.png")
        wm:SetAlpha(0.25)
        wm:SetPoint("CENTER", content, "CENTER", 0, 0)
        local function resizeWatermark()
            local w = content.GetWidth and content:GetWidth() or 0
            local h = content.GetHeight and content:GetHeight() or 0
            local side = math.min(w, h)
            if side > 12 then side = math.min(192, math.max(48, side - 12)) end
            if side <= 0 then side = 128 end  -- safe fallback before first layout
            wm:SetSize(side, side)
        end
        content:HookScript("OnSizeChanged", resizeWatermark)
        -- Some panel show-paths don't fire OnSizeChanged (the frame's size is
        -- set before this script attaches). HookScript("OnShow") on the panel
        -- catches the first-show case so the watermark always has a real size.
        panel:HookScript("OnShow", resizeWatermark)
        resizeWatermark()
        panel.underConstructionWatermark = wm
    end

    -- forward declarations
    local refreshSideWindow
    local toggleSideWindow
    local updateRightControls
    local syncRightChevronStrata

    local function reanchorTopLeft()
        local l, t = panel:GetLeft(), panel:GetTop()
        if l and t then
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
        end
    end

    local function storeDetachGeom()
        if not (GSE.GUI and GSE.GUI.rightDetached) then return end
        GSE.GUI.rightDetachGeom = {
            left = panel:GetLeft(), top = panel:GetTop(),
            w = panel:GetWidth() or DEFAULT_SIDE_WIDTH, h = panel:GetHeight() or 400,
        }
    end

    local function dockSideWindow()
        panel.GSESideDetached = false
        if closeBtn then closeBtn:Hide() end
        if resizeBtn then resizeBtn:Hide() end
        if GSE.GUI then
            GSE.GUI.rightDetached   = false
            GSE.GUI.rightFloatOwner = nil
        end
    end

    local function detachSideWindow()
        if GSE.GUI and GSE.GUI.rightDetached then return end
        local left, top = panel:GetLeft(), panel:GetTop()
        -- Keep the height the window had while docked, rather than shrinking to a
        -- fixed default. The user can still resize it freely once floating.
        local curH = panel:GetHeight() or 400
        panel.GSESideDetached = true
        if GSE.GUI then
            GSE.GUI.rightDetached   = true
            GSE.GUI.rightDetachGeom = {left = left, top = top, w = panel:GetWidth() or DEFAULT_SIDE_WIDTH, h = curH}
            -- Initial owner is the editor being detached; SyncTrees then keeps
            -- rightFloatOwner tracking the active editor, like the floating tree.
            GSE.GUI.rightFloatOwner = ownerEditor()
        end
        if closeBtn then closeBtn:Show() end
        if resizeBtn then resizeBtn:Show() end
        local w = panel:GetWidth() or DEFAULT_SIDE_WIDTH
        panel:SetSize(w, curH)
        panel:ClearAllPoints()
        if left and top then
            if GSE.SetFrameScreenPoint then
                GSE.SetFrameScreenPoint(panel, "TOPLEFT", left, top)
            else
                panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            end
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() end
    end

    local function maybeSnap()
        if not (GSE.GUI and GSE.GUI.rightDetached) then return false end
        if not (editorFrame and editorFrame:IsShown()) then return false end
        local nLeft, nTop = panel:GetLeft(), panel:GetTop()
        local eRight, eTop = editorFrame:GetRight(), editorFrame:GetTop()
        if not (nLeft and nTop and eRight and eTop) then return false end
        if math.abs(nLeft - (eRight - SIDE_DOCK_OFFSET_X)) <= SIDE_SNAP_TOLERANCE
            and math.abs(nTop - eTop) <= SIDE_SNAP_TOLERANCE then
            dockSideWindow()
            if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() else refreshSideWindow() end
            return true
        end
        return false
    end

    panel:SetScript("OnDragStart", function(self) detachSideWindow(); self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        reanchorTopLeft()
        if maybeSnap() then return end
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
        reanchorTopLeft()
        storeDetachGeom()
    end)
    if panel.TitleContainer then
        panel.TitleContainer:EnableMouse(true)
        panel.TitleContainer:RegisterForDrag("LeftButton")
        panel.TitleContainer:SetScript("OnDragStart", function() detachSideWindow(); panel:StartMoving() end)
        panel.TitleContainer:SetScript("OnDragStop", function()
            panel:StopMovingOrSizing()
            reanchorTopLeft()
            if maybeSnap() then return end
            if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(panel) end
            reanchorTopLeft()
            storeDetachGeom()
        end)
    end

    resizeBtn:SetScript("OnMouseDown", function(_, b)
        if b ~= "LeftButton" then return end
        panel:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        reanchorTopLeft()
        panel.sideWidth = panel:GetWidth() or panel.sideWidth
        storeDetachGeom()
    end)

    if closeBtn then
        closeBtn:SetScript("OnClick", function()
            if GSE.GUI and GSE.GUI.rightDetached then
                -- Closing the float re-docks it (returns the window to the editor).
                dockSideWindow()
                if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() else refreshSideWindow() end
            else
                toggleSideWindow()
            end
        end)
    end

    -- Editor drag re-checks snap (mirrors the nav window)
    editorFrame:HookScript("OnDragStop", function()
        if panel:IsShown() and GSE.GUI and GSE.GUI.rightDetached then maybeSnap() end
    end)
    if editorFrame.TitleContainer then
        editorFrame.TitleContainer:HookScript("OnDragStop", function()
            if panel:IsShown() and GSE.GUI and GSE.GUI.rightDetached then maybeSnap() end
        end)
    end

    -- ── Right-edge controls: chevron, click strip, gold hover bar ───────────
    local CHEVRON_LEFT_R  = "Interface\\AddOns\\GSE_GUI\\Assets\\chevron-left.png"
    local CHEVRON_RIGHT_R = "Interface\\AddOns\\GSE_GUI\\Assets\\chevron-right.png"

    -- Invisible click strip beside the editor's right edge. Anchor it to the editor's
    -- CONTENT region (which starts below the title bar) — like the left navStrip — so
    -- it never overlaps the editor's title-bar close/detach buttons and steal their clicks.
    local stripAnchor = contentFrame or editorFrame
    local strip = CreateFrame("Button", nil, editorFrame)
    if strip.SetClipsChildren then strip:SetClipsChildren(false) end
    strip:SetWidth(50)
    strip:SetPoint("TOPRIGHT",    stripAnchor, "TOPRIGHT",    35, 0)
    strip:SetPoint("BOTTOMRIGHT", stripAnchor, "BOTTOMRIGHT", 35, 0)
    strip:EnableMouse(true)
    strip:SetNormalTexture("")
    strip:SetHighlightTexture("")
    strip:SetPushedTexture("")
    panel.hoverStrip = strip

    -- Chevron arrow: left = window open (click to close), right = closed (open)
    local chevronFrame = CreateFrame("Frame", nil, editorFrame)
    chevronFrame:SetSize(20, 20)
    chevronFrame:SetPoint("CENTER", (contentFrame or editorFrame), "RIGHT", 15, 0)
    local chevron = chevronFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    chevron:SetAllPoints(chevronFrame)
    local function updateRightChevron()
        chevron:SetTexture(rightVisible and CHEVRON_LEFT_R or CHEVRON_RIGHT_R)
    end
    updateRightChevron()

    -- Keep the chevron + strip ABOVE the docked window. Mirrors the left tree:
    -- both the chevron and the window live in the editor's strata, the window at a
    -- low level (set on dock) and the chevron at a very high level here, so the arrow
    -- always wins the same-strata layering without relying on cross-strata children.
    syncRightChevronStrata = function()
        local win = editorFrame
        local s = (win.GetFrameStrata and win:GetFrameStrata()) or "MEDIUM"
        local base = (win.GetFrameLevel and win:GetFrameLevel()) or 0
        strip:SetFrameStrata(s)
        strip:SetFrameLevel(base + 600)
        chevronFrame:SetFrameStrata(s)
        chevronFrame:SetFrameLevel(base + 601)
    end

    toggleSideWindow = function()
        rightVisible = not rightVisible
        local o = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
        if o then o.rightVisible = rightVisible end
        updateRightChevron()
        if GSE.GUI and GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() else refreshSideWindow() end
    end

    strip:SetScript("OnClick", function()
        -- While floating, the edge controls can't dock/undock the window.
        if GSE.GUI and GSE.GUI.rightDetached then return end
        toggleSideWindow()
    end)

    -- Deactivate the edge controls on every editor while the window floats.
    updateRightControls = function()
        local detached = GSE.GUI and GSE.GUI.rightDetached
        if detached then
            strip:EnableMouse(false)
            chevronFrame:Hide()
        else
            strip:EnableMouse(true)
            if editorFrame:IsShown() then chevronFrame:Show() end
            updateRightChevron()
        end
    end

    -- The single shared right window. Mirrors refreshNavWindow on the left:
    --  * Floating: tracks the active editor (rightFloatOwner = activeEditor).
    --  * Docked: follows the active editor, full height on its right edge.
    refreshSideWindow = function()
        local gui = GSE.GUI
        if updateRightControls then updateRightControls() end
        if not rightVisible then
            panel.GSESideDetached = false
            panel:Hide()
            return
        end
        local myFrame  = editorFrame
        local active   = gui and gui.activeEditor
        local nEditors = (gui and gui.editors) and #gui.editors or 0
        local detached = gui and gui.rightDetached
        local show
        if detached then
            local ownerFrame = gui and gui.rightFloatOwner and gui.rightFloatOwner.frame
            show = (nEditors <= 1)
                or (not (gui and gui.rightFloatOwner))
                or (ownerFrame and ownerFrame == myFrame)
        else
            show = (nEditors <= 1)
                or (active and active.frame and active.frame == myFrame)
        end
        if not (editorFrame.IsShown and editorFrame:IsShown()) then show = false end
        if not show then
            panel.GSESideDetached = false
            panel:Hide()
            return
        end
        if detached then
            panel.GSESideDetached = true
            panel.GSESkipScaleRecenter = false  -- floating: keep visual position when scaled
            if closeBtn then closeBtn:Show() end
            if resizeBtn then resizeBtn:Show() end
            local g = gui.rightDetachGeom
            local w = (g and g.w) or panel.sideWidth or DEFAULT_SIDE_WIDTH
            local h = (g and g.h) or (panel:GetHeight() or 400)
            panel:SetSize(w, h)
            panel:ClearAllPoints()
            if g and g.left and g.top then
                if GSE.SetFrameScreenPoint then
                    GSE.SetFrameScreenPoint(panel, "TOPLEFT", g.left, g.top)
                else
                    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", g.left, g.top)
                end
            else
                panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        else
            -- Docked to the active editor's right edge, full editor height.
            panel.GSESideDetached = false
            panel.GSESkipScaleRecenter = true  -- docked: keep the editor anchor when scaled (don't re-center)
            if closeBtn then closeBtn:Hide() end
            if resizeBtn then resizeBtn:Hide() end
            local h = safeHeight(editorFrame, 600)
            panel:SetSize(panel.sideWidth or DEFAULT_SIDE_WIDTH, h)
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", editorFrame, "TOPRIGHT", -SIDE_DOCK_OFFSET_X, 0)
            -- Pin the docked panel below the chevron so the chevron at
            -- editor+601 always draws above. Toplevel(true) (set at creation)
            -- still raises the panel on click; the OnMouseDown hook below
            -- resets the level + re-syncs the chevron after that raise.
            if panel.SetFrameStrata and editorFrame.GetFrameStrata then
                panel:SetFrameStrata(editorFrame:GetFrameStrata())
            end
            if panel.SetFrameLevel and editorFrame.GetFrameLevel then
                panel:SetFrameLevel((editorFrame:GetFrameLevel() or 0) + 1)
            end
        end
        syncRightChevronStrata()
        panel:Show()
    end

    -- Editor show/hide drives the chevron + window refresh
    editorFrame:HookScript("OnShow", function()
        strip:Show()
        if not (GSE.GUI and GSE.GUI.rightDetached) then chevronFrame:Show() end
        syncRightChevronStrata()
        refreshSideWindow()
    end)
    editorFrame:HookScript("OnHide", function()
        strip:Hide()
        chevronFrame:Hide()
        panel:Hide()
    end)
    editorFrame:HookScript("OnMouseDown", function() syncRightChevronStrata() end)

    -- Toplevel(true) raises the panel to the top of MEDIUM on every click, which would
    -- cover the chevron arrow at editor+601. The LEFT tree avoids this because clicking
    -- the tree triggers SetActiveEditor → syncSidePanel, which resets navWindow's level
    -- back to editor+1. The right panel isn't an editor and doesn't get that reset, so
    -- do the equivalent here on the panel itself: when the docked panel is clicked,
    -- drop it back to editor+1 so the chevron (editor+601) stays above it. When
    -- floating, the chevron is hidden anyway (see updateRightControls).
    panel:HookScript("OnMouseDown", function()
        if GSE.GUI and GSE.GUI.rightDetached then return end
        if panel.SetFrameLevel and editorFrame.GetFrameLevel then
            panel:SetFrameLevel((editorFrame:GetFrameLevel() or 0) + 1)
        end
        syncRightChevronStrata()
    end)
    if not editorFrame:IsShown() then
        strip:Hide(); chevronFrame:Hide(); panel:Hide()
    end
    syncRightChevronStrata()

    -- Keep docked height synced when the editor resizes
    editorFrame:HookScript("OnSizeChanged", function()
        if rightVisible and not (GSE.GUI and GSE.GUI.rightDetached) and panel:IsShown() then
            refreshSideWindow()
        end
    end)

    -- Public API — names kept stable for Editor.lua + SyncTrees
    panel.Dock              = dockSideWindow
    panel.Detach            = detachSideWindow
    panel.Snap              = maybeSnap
    panel.Toggle            = toggleSideWindow
    panel.RefreshSidePanel  = refreshSideWindow   -- SyncTrees calls this name
    panel.RefreshSideWindow = refreshSideWindow

    refreshSideWindow()
    return panel
end
end
table.insert(ns.deferred, setup)
