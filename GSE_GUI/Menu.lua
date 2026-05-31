local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

---------------------------------------------------------
-- 1. Configuration & Layout Engine
---------------------------------------------------------
local dirConfigs = {
    UP    = { x = 0,  y = 1,  w = 25,  h = 280, logoAnchor = "BOTTOM", logoOffsetX = 0, logoOffsetY = 0 },
    DOWN  = { x = 0,  y = -1, w = 25,  h = 280, logoAnchor = "TOP",    logoOffsetX = 0, logoOffsetY = 0 },
    LEFT  = { x = -1, y = 0,  w = 280, h = 25,  logoAnchor = "RIGHT",  logoOffsetX = 0, logoOffsetY = 0 },
    RIGHT = { x = 1,  y = 0,  w = 280, h = 25,  logoAnchor = "LEFT",   logoOffsetX = 0, logoOffsetY = 0 },
}

-- Logo artwork padding within the 50x50 rendered icon. Measured from the
-- visible (non-transparent) bounding box of the logo PNG. If you swap the
-- logo for one with different artwork padding, update these two numbers and
-- the BUTTON_START_GAP values below will recompute to keep the visible
-- spacing between logo and first icon identical in all four directions.
local LOGO_PADDING_VERTICAL    = 10   -- transparent space above & below artwork (UP/DOWN-relevant)
local LOGO_PADDING_HORIZONTAL  = 0    -- transparent space left & right of artwork (LEFT/RIGHT-relevant)
local LESSER_LOGO_PADDING      = math.min(LOGO_PADDING_VERTICAL, LOGO_PADDING_HORIZONTAL)

-- Baseline gap (logo center → first icon center) measured for the *lesser*
-- padding axis. The other axis's gap shrinks by the padding difference so
-- both directions show the same visible gap between artwork edges.
local BASE_BUTTON_START_GAP       = 45

-- Per-axis manual padding tweaks added on top of the dynamic LOGO_PADDING
-- formula. Use these to nudge one orientation independently when the visual
-- balance differs between vertical and horizontal menus (e.g., the icon next
-- to the logo feels too tight in UP/DOWN but right in LEFT/RIGHT).
local VERTICAL_EXTRA_GAP          = 3   -- UP / DOWN: extra space between logo and first icon
local HORIZONTAL_EXTRA_GAP        = 0   -- LEFT / RIGHT: extra space between logo and first icon

local BUTTON_START_GAP            = BASE_BUTTON_START_GAP - (LOGO_PADDING_VERTICAL   - LESSER_LOGO_PADDING) + VERTICAL_EXTRA_GAP
local HORIZONTAL_BUTTON_START_GAP = BASE_BUTTON_START_GAP - (LOGO_PADDING_HORIZONTAL - LESSER_LOGO_PADDING) + HORIZONTAL_EXTRA_GAP
local BUTTON_STEP                 = 33
-- Regular icons are 30x30; the close icon at the end of the menu is a
-- larger bookend matching the GSE logo (50x50). Centered on the icon stack
-- axis, so 10px (= (50-30)/2) of the close icon overhangs on each side
-- compared to where a 30x30 icon would sit at the same center point.
local REGULAR_ICON_SIZE           = 30
local REGULAR_ICON_HALF           = REGULAR_ICON_SIZE / 2
local CLOSE_ICON_SIZE             = 30
local CLOSE_ICON_HALF             = CLOSE_ICON_SIZE / 2
local CLOSE_ICON_EXTRA_OFFSET     = CLOSE_ICON_HALF - REGULAR_ICON_HALF  -- = 0
-- Hover highlight alpha for the close icon, matching the addon's standard
-- button highlight (see ASSET_HIGHLIGHT_ALPHA in NativeUI.lua).
local CLOSE_ICON_HIGHLIGHT_ALPHA  = 0.35
local DOUBLE_CLICK_SECONDS        = 0.35
local TOOLTIP_GAP                 = 8
local TOOLTIP_EDGE_WIDTH          = 260
local TOOLTIP_EDGE_HEIGHT         = 110

-- Frame-strata options surfaced in the right-click context menu. The user
-- picks one and the choice persists in GSEOptions.MenuOptions.strata.
-- Order matters: rendered top→bottom in the submenu in this order.
local STRATA_OPTIONS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
local STRATA_DEFAULT = "MEDIUM"

-- Forward-declared so helper functions defined above the Main Frame Setup
-- section (e.g. setMenuStrata) capture these as upvalues rather than binding
-- to nil globals. Assigned in the Main Frame Setup section below.
local frame, logo, modernBackdropFrame, logoBorder
local STRATA_LABELS  = {
    BACKGROUND = "Background",
    LOW        = "Low",
    MEDIUM     = "Medium  (default)",
    HIGH       = "High",
    DIALOG     = "Dialog",
}
local MODERN_BACKDROP_INSET_TOP    = 3
local MODERN_BACKDROP_INSET_RIGHT  = 4
local MODERN_BACKDROP_INSET_BOTTOM = 3
-- Negative inset = backdrop extends OUTWARD past the frame's left edge by
-- that many pixels. -2 pulls the left end 2px further left so it sits
-- aligned with the center of the S in the GSE logo when docked right.
local MODERN_BACKDROP_INSET_LEFT   = -2

local MENU_BACKDROP = {
    bgFile   = "Interface/CHARACTERFRAME/UI-Party-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local MODERN_MENU_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local function shouldUseModernMenuSkin()
    if GSE.ShouldUseModernSkin then
        return GSE.ShouldUseModernSkin()
    end
    return GSE.ShouldUseElvUISkin and GSE.ShouldUseElvUISkin()
end

local MODERN_MENU_CLASS_COLORS = {
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

local function getMenuClassColor(alpha)
    if GSE.ShouldUseModernCustomColor and GSE.ShouldUseModernCustomColor() and GSE.GetModernCustomColor then
        return GSE.GetModernCustomColor(alpha)
    end
    if not (GSE.ShouldUseModernClassColors and GSE.ShouldUseModernClassColors()) then return nil end
    if not UnitClass then return nil end
    local localizedClass, classFile = UnitClass("player")
    classFile = classFile or localizedClass
    if type(classFile) == "string" then
        classFile = classFile:upper():gsub("%s+", "")
    end
    local color = classFile and MODERN_MENU_CLASS_COLORS[classFile]
    if not color then return nil end
    return { color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, alpha or color.a or color[4] or 1 }
end

local function getMenuOpts()
    if GSE.isEmpty(GSEOptions.frameLocations) then
        GSEOptions.frameLocations = {}
    end
    if GSE.isEmpty(GSEOptions.frameLocations.menu) then
        GSEOptions.frameLocations.menu = {}
    end
    return GSEOptions.frameLocations.menu
end


-- Temporary override applied when the pop-out animation is about to expand
-- but the user's preferred direction would push icons off-screen. Set by
-- UpdateMenuDirection(dir, true) and cleared by UpdateMenuDirection(dir)
-- without the dontPersist flag (i.e., when the user explicitly picks a
-- direction, or when the collapse animation completes and we restore the
-- preferred direction).
local _directionOverride = nil

local function getDirection()
    if _directionOverride and dirConfigs[_directionOverride] then
        return _directionOverride
    end
    local d = getMenuOpts().direction
    return (d and dirConfigs[d]) and d or "DOWN"
end

local function isLocked()
    return getMenuOpts().locked == true
end

local function isCollapsed()
    return getMenuOpts().collapsed == true
end

local function getMenuStrata()
    local s = getMenuOpts().strata
    -- Validate against the allowed list — fall back to default for any
    -- legacy/unknown value so we never set the frame to a bogus strata.
    for _, v in ipairs(STRATA_OPTIONS) do
        if s == v then return s end
    end
    return STRATA_DEFAULT
end

local function setMenuStrata(strata)
    -- Reject anything not in the allowed list.
    local valid = false
    for _, v in ipairs(STRATA_OPTIONS) do
        if strata == v then valid = true; break end
    end
    if not valid then return end
    getMenuOpts().strata = strata
    if frame and frame.SetFrameStrata then frame:SetFrameStrata(strata) end
end

local function anchorMenuTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()

    local dir = getDirection()
    if not isCollapsed() and (dir == "LEFT" or dir == "RIGHT") then
        local top = owner:GetTop()
        local screenHeight = UIParent:GetHeight()
        if top and screenHeight and top > (screenHeight - TOOLTIP_EDGE_HEIGHT) then
            GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -TOOLTIP_GAP)
        else
            GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, TOOLTIP_GAP)
        end
    elseif not isCollapsed() and (dir == "UP" or dir == "DOWN") then
        local right = owner:GetRight()
        local screenWidth = UIParent:GetWidth()
        if right and screenWidth and right > (screenWidth - TOOLTIP_EDGE_WIDTH) then
            GameTooltip:SetPoint("RIGHT", owner, "LEFT", -TOOLTIP_GAP, 0)
        else
            GameTooltip:SetPoint("LEFT", owner, "RIGHT", TOOLTIP_GAP, 0)
        end
    elseif dir == "LEFT" then
        GameTooltip:SetPoint("LEFT", owner, "RIGHT", TOOLTIP_GAP, 0)
    elseif dir == "RIGHT" then
        GameTooltip:SetPoint("RIGHT", owner, "LEFT", -TOOLTIP_GAP, 0)
    elseif dir == "UP" then
        GameTooltip:SetPoint("TOP", owner, "BOTTOM", 0, -TOOLTIP_GAP)
    else
        GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, TOOLTIP_GAP)
    end
end

---------------------------------------------------------
-- 2. Main Frame Setup
---------------------------------------------------------
frame = CreateFrame("Frame", "GSEMenuFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

local function getModernBackdropFrame()
    if modernBackdropFrame then return modernBackdropFrame end

    modernBackdropFrame = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    modernBackdropFrame:EnableMouse(false)
    if modernBackdropFrame.SetFrameLevel and frame.GetFrameLevel then
        modernBackdropFrame:SetFrameLevel(frame:GetFrameLevel())
    end
    return modernBackdropFrame
end

local function anchorModernBackdropFrame()
    local backdrop = getModernBackdropFrame()
    backdrop:ClearAllPoints()

    -- The MODERN_BACKDROP_INSET_LEFT (-2) overhang was calibrated for the
    -- RIGHT direction so the backdrop's left edge sits centered on the S of
    -- the GSE logo (which is anchored to the frame's left side in RIGHT mode).
    -- For LEFT direction, the logo is on the frame's RIGHT — so the overhang
    -- needs to live on the right side. Swap the LEFT/RIGHT insets in that
    -- case so the toward-logo overhang follows the logo. UP/DOWN don't need
    -- a swap because their logo is on the perpendicular (TOP/BOTTOM) axis
    -- and the LEFT/RIGHT insets there just frame the narrow icon column.
    local leftInset, rightInset = MODERN_BACKDROP_INSET_LEFT, MODERN_BACKDROP_INSET_RIGHT
    if getDirection() == "LEFT" then
        leftInset, rightInset = rightInset, leftInset
    end

    backdrop:SetPoint("TOPLEFT",     frame, "TOPLEFT",      leftInset, -MODERN_BACKDROP_INSET_TOP)
    backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightInset, MODERN_BACKDROP_INSET_BOTTOM)
end

local function applyMenuBackdrop()
    local _accent = getMenuClassColor(1)
    if shouldUseModernMenuSkin() then
        frame:SetBackdrop(nil)
        local backdrop = getModernBackdropFrame()
        backdrop:SetBackdrop(MODERN_MENU_BACKDROP)
        backdrop:SetBackdropColor(0.02, 0.025, 0.028, 0.94)
        backdrop:SetBackdropBorderColor(0.22, 0.24, 0.25, 0.95)
        anchorModernBackdropFrame()
        backdrop:Show()
        -- The dark Modern backdrop already frames the logo, so hide the
        -- warm-gold Native bezel to avoid a doubled border.
        if logoBorder then logoBorder:Hide() end
    else
        if modernBackdropFrame then modernBackdropFrame:Hide() end
        frame:SetBackdrop(MENU_BACKDROP)
        frame:SetBackdropColor(0, 0, 0, 1)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
        -- Show the warm-gold bezel around the logo for the Native skin look.
        if logoBorder then logoBorder:Show() end
    end
end

local function setMenuTopLeft(left, top)
    if not left or not top then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function saveMenuPosition()
    local opts = getMenuOpts()
    opts.left = frame:GetLeft()
    opts.top  = frame:GetTop()
end

local function clampMenuToScreen()
    if not logo then return end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local frameLeft, frameRight, frameTop, frameBottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local logoLeft, logoRight, logoTop, logoBottom = logo:GetLeft(), logo:GetRight(), logo:GetTop(), logo:GetBottom()
    if not (screenWidth and screenHeight and frameLeft and frameRight and frameTop and frameBottom
            and logoLeft and logoRight and logoTop and logoBottom) then
        return
    end

    -- Strict clamp: require the UNION of the frame and the logo to stay on
    -- screen. The logo overhangs past the frame on its anchor side (e.g., in
    -- UP direction the logo's bottom half sits below the frame), so checking
    -- only one wouldn't catch the other. This matches the editor's screen
    -- bounds — earlier the clamp was relaxed to "logo only" but that allowed
    -- the menu strip to slide off-screen leaving very little to grab onto.
    local visualLeft   = math.min(frameLeft,   logoLeft)
    local visualRight  = math.max(frameRight,  logoRight)
    local visualTop    = math.max(frameTop,    logoTop)
    local visualBottom = math.min(frameBottom, logoBottom)

    local dx, dy = 0, 0
    if visualLeft < 0 then
        dx = -visualLeft
    elseif visualRight > screenWidth then
        dx = screenWidth - visualRight
    end
    if visualBottom < 0 then
        dy = -visualBottom
    elseif visualTop > screenHeight then
        dy = screenHeight - visualTop
    end

    if dx ~= 0 or dy ~= 0 then
        setMenuTopLeft(frameLeft + dx, frameTop + dy)
    end
end

local function startMenuMove()
    if isLocked() then return end
    frame:StartMoving()
    frame:SetScript("OnUpdate", clampMenuToScreen)
end

local function stopMenuMove()
    frame:StopMovingOrSizing()
    frame:SetScript("OnUpdate", nil)
    clampMenuToScreen()
    saveMenuPosition()
end

frame:SetFrameStrata(getMenuStrata())
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
if GSE.RegisterMenuUIScaleFrame then
    GSE.RegisterMenuUIScaleFrame(frame)
elseif GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(frame)
end
applyMenuBackdrop()
frame:Hide()
frame:HookScript("OnShow", function(self)
    if GSE.ApplyMenuScaleToFrame then
        GSE.ApplyMenuScaleToFrame(self)
    elseif GSE.ApplyScaleToFrame then
        GSE.ApplyScaleToFrame(self)
    end
end)

frame:SetScript("OnDragStart", function(self)
    startMenuMove()
end)
frame:SetScript("OnDragStop", stopMenuMove)

---------------------------------------------------------
-- 3. Logo Setup
---------------------------------------------------------
logo = CreateFrame("Button", "GSEMenuLogo", frame)
logo:SetSize(50, 50)
logo:RegisterForClicks("LeftButtonUp", "RightButtonUp")
logo:RegisterForDrag("LeftButton")

-- Native-style warm-gold border around the logo. Drawn via a child frame
-- with the same edge texture the Native skin uses for panels (UI-Tooltip-Border).
-- Anchored to the *visible* artwork bounds (not the full 50x50 logo frame),
-- so the bezel sits tight against the GSE letters with consistent breathing
-- room on every side. Toggled by applyMenuBackdrop — shown when the Native
-- skin is active, hidden under Modern skin (where the dark backdrop already
-- provides framing).
local LOGO_BORDER_OUTSET_X = 3   -- horizontal breathing room around the visible artwork
local LOGO_BORDER_OUTSET_Y = 3   -- vertical breathing room around the visible artwork
-- Compute the SetPoint offsets that put the border OUTSET_X/Y pixels beyond
-- the visible artwork bounds. For our current logo (PAD_H = 0, PAD_V = 10)
-- this places the border 3px outside the logo horizontally and 7px INSIDE
-- the logo vertically (skipping the transparent space above/below the GSE
-- letters). If the artwork is swapped for one with different padding, just
-- update LOGO_PADDING_HORIZONTAL/VERTICAL at the top of this file — these
-- offsets recompute automatically.
local LOGO_BORDER_TL_X =   LOGO_PADDING_HORIZONTAL - LOGO_BORDER_OUTSET_X
local LOGO_BORDER_TL_Y =   LOGO_BORDER_OUTSET_Y    - LOGO_PADDING_VERTICAL
local LOGO_BORDER_BR_X =   LOGO_BORDER_OUTSET_X    - LOGO_PADDING_HORIZONTAL
local LOGO_BORDER_BR_Y =   LOGO_PADDING_VERTICAL   - LOGO_BORDER_OUTSET_Y
local LOGO_BORDER_BACKDROP = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}
local logoBorder_frame = CreateFrame(
    "Frame",
    nil,
    logo,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
logoBorder = logoBorder_frame  -- assign to the module-level forward-declared upvalue
logoBorder:SetPoint("TOPLEFT",     logo, "TOPLEFT",     LOGO_BORDER_TL_X, LOGO_BORDER_TL_Y)
logoBorder:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", LOGO_BORDER_BR_X, LOGO_BORDER_BR_Y)
logoBorder:SetFrameLevel((logo:GetFrameLevel() or 1) + 1)  -- above logo so the bezel reads on top
logoBorder:EnableMouse(false)
logoBorder:SetBackdrop(LOGO_BORDER_BACKDROP)
-- Warm gold/brown tint matching the addon's Native-skin border color from skinPanel.
logoBorder:SetBackdropBorderColor(0.48, 0.48, 0.46, 0.95)
logoBorder:Hide()  -- applyMenuBackdrop controls visibility based on skin

local logoTex = logo:CreateTexture(nil, "OVERLAY")
logoTex:SetAllPoints()
-- Pick the skin-aware menu logo. RefreshLogoTexture below re-picks it whenever
-- the user changes skin, so the icon swaps live without a /reload.
local function RefreshLogoTexture()
    local path = (GSE.GUI and GSE.GUI.GetMenuLogoTexture and GSE.GUI.GetMenuLogoTexture())
        or Statics.Icons.MenuLogo
    logoTex:SetTexture(path)
    -- Re-apply the backdrop so the warm-gold logo bezel and the modern dark
    -- panel toggle correctly when the user switches skins from Options.
    applyMenuBackdrop()
end
RefreshLogoTexture()
-- Expose so the skin-change callback (and anything else that wants to force a
-- repaint) can poke it from outside Menu.lua.
GSE.GUI = GSE.GUI or {}
GSE.GUI.RefreshMenuLogo = RefreshLogoTexture

local logoDragging = false

logo:SetScript("OnDragStart", function()
    logoDragging = true
    startMenuMove()
end)
logo:SetScript("OnDragStop", stopMenuMove)

logo:SetScript("OnEnter", function(self)
    if isCollapsed() then
        GameTooltip:Hide()
        return
    end

    anchorMenuTooltip(self)
    GameTooltip:SetText("GSE v" .. (GSE.VersionString or "Unknown"))
    GameTooltip:AddLine(L["Right-Click for Options"], 0, 1, 0)
    GameTooltip:AddLine(L["Shift + Right-Click to copy version"], 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Double Click to Hide Bar", 0.75, 0.75, 0.75)
    if isLocked() then
        GameTooltip:AddLine(L["Position Locked"], 1, 0, 0)
    end
    GameTooltip:Show()
end)
logo:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------
-- 4. Button Creation
---------------------------------------------------------
local iconButtons = {}

local function createIconButton(index, icon, labelText, onClickFunc, isCloseButton)
    local button = CreateFrame("Button", nil, frame)
    local size = isCloseButton and CLOSE_ICON_SIZE or REGULAR_ICON_SIZE
    button:SetSize(size, size)
    button:RegisterForClicks("AnyUp")

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(icon)

    button:SetScript("OnClick", onClickFunc)

    if isCloseButton then
        -- Close icon uses an additive highlight texture instead of a scale-up
        -- on hover — matches the addon's standard button highlight pattern.
        -- Tooltip behaviour is unchanged.
        button:SetHighlightTexture(icon, "ADD")
        local hl = button:GetHighlightTexture()
        if hl and hl.SetAlpha then hl:SetAlpha(CLOSE_ICON_HIGHLIGHT_ALPHA) end
        button:SetScript("OnEnter", function(self)
            anchorMenuTooltip(self)
            GameTooltip:SetText(labelText, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        button:SetScript("OnEnter", function(self)
            self:SetSize(35, 35)
            anchorMenuTooltip(self)
            GameTooltip:SetText(labelText, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            self:SetSize(REGULAR_ICON_SIZE, REGULAR_ICON_SIZE)
            GameTooltip:Hide()
        end)
    end

    return button
end

local iconData = {
    { Statics.Icons.Sequences,   L["Sequences"],   GSE.ShowSequences   },
    { Statics.Icons.Keybindings, L["Keybindings"], GSE.ShowKeyBindings },
    { Statics.Icons.Variables,   L["Variables"],   GSE.ShowVariables   },
    { Statics.Icons.Import,      L["Import"],      function()
        if GSE.ShowImport then
            GSE.ShowImport()
        else
            GSE.Print("Import window is not available. Reload GSE_GUI.", "Error")
        end
    end },
    { Statics.Icons.Macros,      L["Macros"],      GSE.ShowMacros      },
    { Statics.Icons.Options,     L["Options"],     GSE.OpenOptionsPanel},
    {
        Statics.Icons.Close,
        L["Close"],
        function()
            local opts = getMenuOpts()
            opts.left  = frame:GetLeft()
            opts.top   = frame:GetTop()
            opts.open  = false
            frame:Hide()
        end
    },
}

for i, data in ipairs(iconData) do
    iconButtons[i] = createIconButton(i, data[1], data[2], data[3], i == #iconData)
end

-- Combat-aware Options icon. The Options panel is opened via
-- Settings.OpenToCategory, which goes through Blizzard's protected
-- OpenSettingsPanel() — that's a hard combat-lockdown call, and pcall
-- can't rescue it because the lockdown enforcement fires at the C level
-- before Lua catches the error. So we swallow the click during combat
-- with a friendly Print (so it doesn't dispatch to GSE.OpenOptionsPanel
-- and trip the protected call, which would either spam BugSack with
-- ADDON_ACTION_BLOCKED or just silently no-op depending on the user's
-- error settings). GSE.OpenRegisteredOptionsPanel itself ALSO checks
-- InCombatLockdown() for the same reason — the OnClick wrap here is the
-- "stop it at the source" layer, that check is the backstop for other
-- callers (slash command, debug-window button, toolbar tree icon).
--
-- The icon stays at its normal alpha/colour at all times by design — no
-- visual greying. Users find a darkened icon ambiguous (is it disabled?
-- is it broken? is another addon doing it?), and the visual state can
-- get stuck "greyed" if PLAYER_REGEN_ENABLED doesn't fire cleanly after
-- a reload or zone-in. The click-time print is the single source of
-- feedback when Options is unavailable.
--
-- Identifies the Options entry by its icon path (Statics.Icons.Options)
-- rather than L["Options"] so this doesn't break if iconData order is
-- ever rearranged or the locale string changes.
do
    local optionsButton
    for i, data in ipairs(iconData) do
        if data[1] == Statics.Icons.Options then
            optionsButton = iconButtons[i]
            break
        end
    end

    if optionsButton then
        -- Wrap OnClick so combat clicks are swallowed before reaching
        -- the protected call. Out-of-combat clicks fall through to the
        -- original GSE.OpenOptionsPanel handler exactly as before.
        local origOnClick = optionsButton:GetScript("OnClick")
        optionsButton:SetScript("OnClick", function(self, btn, down)
            if InCombatLockdown and InCombatLockdown() then
                if GSE and GSE.Print then
                    GSE.Print(L["Cannot Open Options during Combat"]
                        or "Cannot Open Options during Combat")
                end
                return
            end
            if origOnClick then return origOnClick(self, btn, down) end
        end)
    end
end

local function keepLogoCenter(logoCenterX, logoCenterY, frameLeft, frameTop)
    local newLogoCenterX, newLogoCenterY = logo:GetCenter()
    if logoCenterX and logoCenterY and newLogoCenterX and newLogoCenterY and frameLeft and frameTop then
        frame:ClearAllPoints()
        frame:SetPoint(
            "TOPLEFT",
            UIParent,
            "BOTTOMLEFT",
            frameLeft + (logoCenterX - newLogoCenterX),
            frameTop + (logoCenterY - newLogoCenterY)
        )

        local opts = getMenuOpts()
        opts.left = frame:GetLeft()
        opts.top = frame:GetTop()
    end
end

---------------------------------------------------------
-- 5. Layout Update
---------------------------------------------------------
local menuLaidOut = false

-- Position every icon in the stack based on expandProgress. progress = 1
-- means icons are at their full rest positions (the normal static layout);
-- progress = 0 means all icons are sitting on top of the logo (collapsed,
-- about to slide out, or just slid back in). Used by both the static layout
-- path in UpdateMenuDirection and by the mouseover pop-out slide animation.
-- Returns nothing — caller is responsible for ensuring the logo's center is
-- already at the right anchor.
local function applyIconLayout(progress)
    progress = progress or 1
    -- Use getDirection() (not opts.direction directly) so the icons respect
    -- the pop-out auto-flip override. Without this, the frame and backdrop
    -- would flip to the new direction but icons would stay positioned per
    -- the user's preferred direction — visible as icons hanging off the
    -- wrong end of the menu strip during pop-out.
    local dir = getDirection()
    local cfg = dirConfigs[dir]
    if not cfg then return end
    local iconCount = #iconButtons
    for i, button in ipairs(iconButtons) do
        local startGap = cfg.x ~= 0 and HORIZONTAL_BUTTON_START_GAP or BUTTON_START_GAP
        local offset = startGap + (BUTTON_STEP * (i - 1))
        if i == iconCount then
            offset = offset + CLOSE_ICON_EXTRA_OFFSET
        end
        offset = offset * progress
        button:ClearAllPoints()
        button:SetPoint("CENTER", logo, "CENTER", offset * cfg.x, offset * cfg.y)
        if progress > 0 then
            button:Show()
        else
            button:Hide()
        end
    end

    -- Fade the menu's dark backdrop alongside the icon slide so the whole
    -- "menu strip" appears/disappears together. The logoBorder is part of
    -- the logo's visual identity (not the menu backdrop) and stays visible
    -- regardless of progress — the logo itself is also always visible.
    if shouldUseModernMenuSkin() then
        -- Modern skin uses a dedicated child frame for the backdrop, so we
        -- can fade just that frame's alpha without affecting anything else.
        if modernBackdropFrame then
            modernBackdropFrame:SetAlpha(progress)
        end
    else
        -- Native skin's backdrop lives on the main frame via SetBackdrop, so
        -- we fade it by tinting the color/border to alpha=progress. Hidden at
        -- 0, fully drawn at 1. applyMenuBackdrop resets these on skin/direction
        -- change but applyIconLayout always runs after it, so the right alpha
        -- is re-applied on every layout pass.
        if frame.SetBackdropColor then
            frame:SetBackdropColor(0, 0, 0, progress)
            frame:SetBackdropBorderColor(1, 1, 1, progress)
        end
    end
end

function GSE.UpdateMenuDirection(newDirection, dontPersist)
    local dir = newDirection and newDirection:upper() or "DOWN"
    if not dirConfigs[dir] then return end
    local cfg = dirConfigs[dir]
    local hadLayout = menuLaidOut
    local logoCenterX, logoCenterY = logo:GetCenter()
    local frameLeft, frameTop = frame:GetLeft(), frame:GetTop()

    -- dontPersist = true is used by the pop-out auto-flip-to-fit logic. It
    -- sets a temporary direction override that getDirection() reads while
    -- leaving the user's saved opts.direction untouched. Any other call
    -- (e.g., right-click radio) clears the override and saves the new dir
    -- as the new user preference.
    if dontPersist then
        _directionOverride = dir
    else
        _directionOverride = nil
        getMenuOpts().direction = dir
    end

    -- Compute the long-axis dimension to fit the icon stack tightly. The icon
    -- stack starts at startGap (logo-center → first-icon-center) and extends
    -- BUTTON_STEP per additional icon. We add the icon half-width and a small
    -- end-pad so the backdrop has a few pixels of breathing room past the last
    -- icon. This replaces the previously hardcoded h=280/w=280 in dirConfigs
    -- which left ~26px of empty space above (or beside) the last icon for the
    -- current 7-icon menu.
    local iconCount = #iconButtons
    local startGap = (dir == "UP" or dir == "DOWN") and BUTTON_START_GAP or HORIZONTAL_BUTTON_START_GAP
    local END_PAD = -15
    -- The last icon in the stack is the close icon (now 30x30). Its center sits
    -- CLOSE_ICON_EXTRA_OFFSET farther from the logo than a regular icon would
    -- (currently 0 since close is the same size as regular icons), and its
    -- far edge extends CLOSE_ICON_HALF from that center. END_PAD adjusts how
    -- far past (or short of) the close icon's far edge the frame extends —
    -- negative values pull the frame in, letting the close icon's outer half
    -- stick out past the backdrop end (mirrors the logo's bookend behaviour).
    local longAxis = startGap
        + math.max(0, iconCount - 1) * BUTTON_STEP
        + CLOSE_ICON_EXTRA_OFFSET
        + CLOSE_ICON_HALF
        + END_PAD
    local frameW, frameH = cfg.w, cfg.h
    if dir == "UP" or dir == "DOWN" then
        frameH = longAxis
    else
        frameW = longAxis
    end

    frame:SetMovable(not isLocked())

    if isCollapsed() then
        if not hadLayout then
            frame:SetSize(frameW, frameH)
            logo:ClearAllPoints()
            logo:SetPoint("CENTER", frame, cfg.logoAnchor, cfg.logoOffsetX or 0, cfg.logoOffsetY or 0)
            menuLaidOut = true
        end

        frame:SetBackdrop(nil)
        if modernBackdropFrame then modernBackdropFrame:Hide() end
        frame:EnableMouse(true)
        logo:Show()
        logo:EnableMouse(true)

        for _, button in ipairs(iconButtons) do
            button:Hide()
        end

        return
    end

    frame:EnableMouse(true)
    frame:SetSize(frameW, frameH)
    applyMenuBackdrop()
    logo:Show()
    logo:ClearAllPoints()
    logo:SetPoint("CENTER", frame, cfg.logoAnchor, cfg.logoOffsetX or 0, cfg.logoOffsetY or 0)
    menuLaidOut = true

    -- Layout icons. Default to fully expanded; refreshMouseoverPopOutState
    -- below (called from frame:OnShow and on option toggle) overrides this
    -- with the live animation progress when the user has pop-out mode on.
    applyIconLayout(getMenuOpts().mouseoverPopOut and 0 or 1)

    if hadLayout then
        -- Keep the logo at the same screen position across direction changes.
        -- This runs for every direction change after the initial layout:
        -- right-click radio picks, pop-out auto-flips (dontPersist=true), and
        -- the collapse-completion override restore. Without it the logo would
        -- jump by the long-axis length whenever the logoAnchor swaps (e.g.,
        -- UP→DOWN flips the anchor from BOTTOM to TOP).
        keepLogoCenter(logoCenterX, logoCenterY, frameLeft, frameTop)
        clampMenuToScreen()
        saveMenuPosition()
    end
end

local function toggleMenuCollapsed()
    local opts = getMenuOpts()
    opts.collapsed = not opts.collapsed
    GameTooltip:Hide()
    GSE.UpdateMenuDirection(getDirection())
end

---------------------------------------------------------
-- 5b. Mouseover Pop-Out Mode
---------------------------------------------------------
-- When opts.mouseoverPopOut is true the icons start hidden at the logo's
-- center and slide out to their rest positions when the user mouses over
-- the logo or any icon. They slide back when the cursor leaves the menu
-- region (logo + icons). When the option is off everything behaves as a
-- normal static menu.

local POPOUT_ANIM_DURATION = 0.18  -- seconds, slide-out / slide-in length
local POPOUT_COLLAPSE_DELAY = 0.12 -- seconds, grace period after mouse leaves before collapsing

local popoutProgress = 1.0   -- 0 = collapsed at logo, 1 = fully expanded
local popoutAnimFrom, popoutAnimTo, popoutAnimStart
local popoutHoverCount = 0
local popoutCollapseTimer

local function isMouseoverPopOut()
    return getMenuOpts().mouseoverPopOut == true
end


-- Dedicated frame for the slide animation OnUpdate. Using a separate frame
-- avoids competing with the drag-clamp OnUpdate that the main menu frame
-- swaps onto its own SetScript during drags.
local popoutAnimFrame = CreateFrame("Frame", nil, UIParent)
popoutAnimFrame:Hide()
popoutAnimFrame:SetScript("OnUpdate", function(self)
    if not popoutAnimStart then self:Hide(); return end
    local elapsed = GetTime() - popoutAnimStart
    local t = elapsed / POPOUT_ANIM_DURATION
    if t >= 1 then
        popoutProgress = popoutAnimTo
        popoutAnimStart = nil
        self:Hide()
        -- If we just finished a slide-IN (collapse) and a temporary direction
        -- override was active, restore the user's preferred direction now
        -- that the icons are hidden. The next slide-out will re-check fit
        -- from the current logo position and pick the best direction fresh.
        if popoutAnimTo == 0 and _directionOverride then
            GSE.UpdateMenuDirection(getMenuOpts().direction)
        end
    else
        -- Ease-out cubic — fast start, gentle finish.
        local eased = 1 - (1 - t) * (1 - t) * (1 - t)
        popoutProgress = popoutAnimFrom + (popoutAnimTo - popoutAnimFrom) * eased
    end
    applyIconLayout(popoutProgress)
end)

local function animatePopout(target)
    if popoutProgress == target and not popoutAnimStart then return end
    popoutAnimFrom = popoutProgress
    popoutAnimTo = target
    popoutAnimStart = GetTime()
    popoutAnimFrame:Show()
end

-- Reset the menu to the correct visual state for the current option value.
-- Called on option toggle and after frame:Show so first appearance is right.
local function refreshMouseoverPopOutState(animate)
    if popoutCollapseTimer then
        popoutCollapseTimer:Cancel()
        popoutCollapseTimer = nil
    end
    popoutHoverCount = 0
    if isCollapsed() then return end  -- collapse mode handles its own visibility
    local target = isMouseoverPopOut() and 0 or 1
    if animate then
        animatePopout(target)
    else
        popoutProgress = target
        popoutAnimStart = nil
        popoutAnimFrame:Hide()
        applyIconLayout(popoutProgress)
    end
end

-- Hover counter — bumped when cursor enters the logo or any icon, dropped
-- when it leaves. When the count returns to 0 we schedule a collapse with
-- a small grace period so the cursor can travel from logo to first icon
-- (or between icons) without triggering a slide-in.
local function popoutBumpHover()
    if not isMouseoverPopOut() then return end
    if isCollapsed() then return end
    popoutHoverCount = popoutHoverCount + 1
    if popoutCollapseTimer then
        popoutCollapseTimer:Cancel()
        popoutCollapseTimer = nil
    end
    if popoutAnimTo ~= 1 or popoutProgress < 1 then
        -- Always slide out in the user's chosen direction. The earlier
        -- auto-flip-to-fit behaviour was removed (too buggy); pick the
        -- pop-out direction from the right-click menu instead.
        animatePopout(1)
    end
end

local function popoutDropHover()
    if not isMouseoverPopOut() then return end
    if isCollapsed() then return end
    popoutHoverCount = math.max(0, popoutHoverCount - 1)
    if popoutHoverCount > 0 then return end
    if popoutCollapseTimer then popoutCollapseTimer:Cancel() end
    popoutCollapseTimer = C_Timer.NewTimer(POPOUT_COLLAPSE_DELAY, function()
        popoutCollapseTimer = nil
        if popoutHoverCount == 0 and isMouseoverPopOut() and not isCollapsed() then
            animatePopout(0)
        end
    end)
end

-- Attach hover handlers to the logo and every icon. HookScript is used so
-- we don't override the existing OnEnter/OnLeave handlers (tooltip on logo,
-- tooltip + scale on regular icons, tooltip + highlight on close icon).
logo:HookScript("OnEnter", popoutBumpHover)
logo:HookScript("OnLeave", popoutDropHover)
for _, button in ipairs(iconButtons) do
    button:HookScript("OnEnter", popoutBumpHover)
    button:HookScript("OnLeave", popoutDropHover)
end

-- On every menu show, snap to the right state for the current option. No
-- animation on first show — the user shouldn't see icons slide in just from
-- opening the menu, only from their own hover gesture.
frame:HookScript("OnShow", function()
    refreshMouseoverPopOutState(false)
end)

-- Expose the pop-out refresh and strata setter so the Options panel (and any
-- other code) can drive them. Both keep the right-click context menu and the
-- Options panel in sync — they're thin wrappers around the module-local
-- helpers defined above.
GSE.RefreshMenuMouseoverState = function(animate)
    refreshMouseoverPopOutState(animate)
end
GSE.SetMenuStrata = function(strata)
    setMenuStrata(strata)
end

---------------------------------------------------------
-- 6. Right-Click Context Menu
---------------------------------------------------------

local dirLabels = {
    UP    = function() return L["Up"]    end,
    DOWN  = function() return L["Down"]  end,
    LEFT  = function() return L["Left"]  end,
    RIGHT = function() return L["Right"] end,
}

local function showContextMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L["Growth Direction"])
        for _, dir in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
            rootDescription:CreateRadio(
                dirLabels[dir](),
                function() return getDirection() == dir end,
                function() GSE.UpdateMenuDirection(dir) end
            )
        end
        rootDescription:CreateDivider()
        -- Bar mode toggle — label shows the CURRENT mode, and the checkbox is
        -- ticked when in Static mode (the default). Checking ON = Static,
        -- ticking OFF = Slide Out. So a fresh install displays "Static Toolbar"
        -- with a tick; unticking switches to "Slide Out Toolbar" mode.
        rootDescription:CreateCheckbox(
            isMouseoverPopOut() and "Slide Out Toolbar" or "Static Toolbar",
            function() return not isMouseoverPopOut() end,  -- checked when Static is active
            function()
                getMenuOpts().mouseoverPopOut = not isMouseoverPopOut()
                refreshMouseoverPopOutState(true)  -- animate the transition
            end
        )
        rootDescription:CreateDivider()
        -- Strata submenu — lets the user choose how the menu layers against
        -- other UI. Selection persists in GSEOptions.MenuOptions.strata and
        -- is applied to the frame immediately on click.
        local strataDesc = rootDescription:CreateButton(L["Strata"] or "Strata")
        for _, strata in ipairs(STRATA_OPTIONS) do
            strataDesc:CreateRadio(
                STRATA_LABELS[strata] or strata,
                function() return getMenuStrata() == strata end,
                function() setMenuStrata(strata) end
            )
        end
        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox(
            L["Lock Position"],
            function() return isLocked() end,
            function()
                local opts = getMenuOpts()
                opts.locked = not opts.locked
                frame:SetMovable(not opts.locked)
            end
        )
    end)
end

local lastLogoLeftClick = 0
logo:SetScript("OnMouseUp", function(self, button)
    if logoDragging then
        logoDragging = false
        return
    end

    if button == "LeftButton" then
        local now = GetTime()
        if (now - lastLogoLeftClick) <= DOUBLE_CLICK_SECONDS then
            lastLogoLeftClick = 0
            toggleMenuCollapsed()
        else
            lastLogoLeftClick = now
        end
        return
    end

    if button == "RightButton" then
        if IsShiftKeyDown() then
            -- Shift+Right-Click: open the shared version copy popup.
            if GSE.GUIShowVersionCopyWindow then
                GSE.GUIShowVersionCopyWindow()
            end
        else
            showContextMenu(self)
        end
    end
end)

---------------------------------------------------------
-- 7. Initialise Position & Direction
---------------------------------------------------------
GSE.UpdateMenuDirection(getDirection())

local loc = getMenuOpts()
if loc.left and loc.top then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", loc.left, loc.top)
else
    frame:SetPoint("CENTER")
end

frame:SetMovable(not isLocked())

if loc.open then
    frame:Show()
end

function GSE.ShowMenu()
    getMenuOpts().open = true
    frame:Show()
end

GSE.MenuFrame = frame
