local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local Statics = GSE.Static

---------------------------------------------------------
-- 1. Configuration & Layout Engine
---------------------------------------------------------
local dirConfigs = {
    UP    = { x = 0,  y = 1,  w = 50,  h = 280, logoAnchor = "BOTTOM" },
    DOWN  = { x = 0,  y = -1, w = 50,  h = 280, logoAnchor = "TOP"    },
    LEFT  = { x = -1, y = 0,  w = 280, h = 50,  logoAnchor = "RIGHT"  },
    RIGHT = { x = 1,  y = 0,  w = 280, h = 50,  logoAnchor = "LEFT"   },
}

local BUTTON_START_GAP = 51
local BUTTON_STEP      = 34

local function getMenuOpts()
    if GSE.isEmpty(GSEOptions.frameLocations) then
        GSEOptions.frameLocations = {}
    end
    if GSE.isEmpty(GSEOptions.frameLocations.menu) then
        GSEOptions.frameLocations.menu = {}
    end
    return GSEOptions.frameLocations.menu
end

local function getDirection()
    local d = getMenuOpts().direction
    return (d and dirConfigs[d]) and d or "DOWN"
end

local function isLocked()
    return getMenuOpts().locked == true
end

---------------------------------------------------------
-- 2. Main Frame Setup
---------------------------------------------------------
local frame = CreateFrame("Frame", "GSEMenuFrame", UIParent, "BackdropTemplate")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
-- Solid black backdrop. The original used Interface/CHARACTERFRAME/UI-Party-Background
-- with forward slashes which silently failed to render in some environments
-- (Wine + retail asset case-sensitivity), leaving the toolbar visually
-- transparent. WHITE8X8 tinted black always renders.
frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 1)
frame:Hide()

frame:SetScript("OnDragStart", function(self)
    if not isLocked() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local opts = getMenuOpts()
    opts.left = self:GetLeft()
    opts.top  = self:GetTop()
end)

---------------------------------------------------------
-- 3. Logo Setup
---------------------------------------------------------
local logo = CreateFrame("Button", "GSEMenuLogo", frame)
logo:SetSize(64, 64)
logo:RegisterForClicks("LeftButtonUp", "RightButtonUp")
logo:RegisterForDrag("LeftButton")

local logoTex = logo:CreateTexture(nil, "OVERLAY")
logoTex:SetAllPoints()
logoTex:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\GSE-Logo.png")

logo:SetScript("OnDragStart", function()
    if not isLocked() then frame:StartMoving() end
end)
logo:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local opts = getMenuOpts()
    opts.left = frame:GetLeft()
    opts.top  = frame:GetTop()
end)

logo:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("GSE v" .. (GSE.VersionString or "Unknown"))
    GameTooltip:AddLine(L["Right-Click for Options"], 0, 1, 0)
    GameTooltip:AddLine(L["Shift + Right-Click to copy version"], 0.75, 0.75, 0.75)
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

local function createIconButton(index, icon, labelText, onClickFunc)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(30, 30)

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(icon)

    button:SetScript("OnClick", onClickFunc)
    button:SetScript("OnEnter", function(self)
        self:SetSize(35, 35)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(labelText, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self:SetSize(30, 30)
        GameTooltip:Hide()
    end)

    return button
end

-- The keybind guide: one picture of the steps that put a sequence on an
-- action button and a key on it, in Blizzard's own portrait window (border,
-- title bar, close button). Built on the first click, so the picture is not
-- loaded until it is asked for; a second click closes it.
local KEYBIND_GUIDE_TEXTURE = "Interface\\AddOns\\GSE_GUI\\Assets\\KeybindGuide.png"
-- The file's own pixels. It is shown one for one, never resized by the game
-- where it fits: a picture the game shrinks goes soft. To change its size,
-- resize the file and this number together.
local KEYBIND_GUIDE_PIXELS  = 800
local KEYBIND_GUIDE_PAD     = 16   -- each side of the picture
local KEYBIND_GUIDE_CHROME  = 44   -- title bar above it, border below
local keybindGuide

local function showKeybindGuide()
    if keybindGuide then
        keybindGuide:SetShown(not keybindGuide:IsShown())
        return
    end

    -- The picture's own size where the screen has room for it, else as tall
    -- as fits under the title bar.
    local side = KEYBIND_GUIDE_PIXELS
    if GetPhysicalScreenSize then
        local _, screenHeight = GetPhysicalScreenSize()
        side = side * 768 / screenHeight / UIParent:GetEffectiveScale()
    end
    side = math.min(side, UIParent:GetHeight() * 0.9 - KEYBIND_GUIDE_CHROME)

    keybindGuide = CreateFrame("Frame", "GSEKeybindGuideFrame", UIParent, "PortraitFrameTemplate")
    keybindGuide:SetFrameStrata("DIALOG")
    keybindGuide:SetToplevel(true)
    keybindGuide:SetSize(side + KEYBIND_GUIDE_PAD * 2, side + KEYBIND_GUIDE_CHROME)
    keybindGuide:SetPoint("CENTER")
    keybindGuide:SetClampedToScreen(true)
    keybindGuide:EnableMouse(true)
    keybindGuide:SetMovable(true)
    keybindGuide:RegisterForDrag("LeftButton")
    keybindGuide:SetScript("OnDragStart", keybindGuide.StartMoving)
    keybindGuide:SetScript("OnDragStop", keybindGuide.StopMovingOrSizing)
    -- The template's methods differ by client, so each is asked for.
    if keybindGuide.SetPortraitToAsset then keybindGuide:SetPortraitToAsset(Statics.Icons.Keybindings) end
    -- The template's round window is not the middle of the portrait, so the
    -- icon's art is moved in it, by eye (Larry, 2026-11-21, on Forever): up
    -- 4.66 and left 1.64 of the portrait's 62.
    local up, left = 4.66 / 62, 1.64 / 62
    if keybindGuide.SetPortraitTexCoord then keybindGuide:SetPortraitTexCoord(left, 1 + left, up, 1 + up) end
    if keybindGuide.SetTitleOffsets then keybindGuide:SetTitleOffsets(24, -24) end
    if keybindGuide.SetTitle then keybindGuide:SetTitle(L["Keybindings"]) end
    if keybindGuide.CloseButton then
        keybindGuide.CloseButton:SetScript("OnClick", function() keybindGuide:Hide() end)
    end

    local picture = keybindGuide:CreateTexture(nil, "ARTWORK")
    picture:SetPoint("TOP", 0, -28)
    picture:SetSize(side, side)
    picture:SetTexture(KEYBIND_GUIDE_TEXTURE)
    -- The picture is in memory only while the window is open.
    keybindGuide:SetScript("OnShow", function() picture:SetTexture(KEYBIND_GUIDE_TEXTURE) end)
    keybindGuide:SetScript("OnHide", function() picture:SetTexture(nil) end)

    -- Escape closes it.
    tinsert(UISpecialFrames, "GSEKeybindGuideFrame")
end

local iconData = {
    { Statics.Icons.Sequences,   L["Sequences"],   GSE.ShowSequences   },
    -- The Keybindings pages where GSE binds keys to sequences itself
    -- (Editor_Keybind.lua, buildKeybindMenu); anywhere else the guide.
    {
        Statics.Icons.Keybindings,
        L["Keybindings"],
        function()
            if GSE.KeybindingsEnabled() then
                GSE.ShowKeyBindings()
            else
                showKeybindGuide()
            end
        end
    },
    { Statics.Icons.Variables,   L["Variables"],   GSE.ShowVariables   },
    { Statics.Icons.Import,      L["Import"],      GSE.ShowImport      },
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
    iconButtons[i] = createIconButton(i, data[1], data[2], data[3])
end

---------------------------------------------------------
-- 5. Layout Update
---------------------------------------------------------
function GSE.UpdateMenuDirection(newDirection)
    local dir = newDirection and newDirection:upper() or "DOWN"
    if not dirConfigs[dir] then return end
    local cfg = dirConfigs[dir]

    getMenuOpts().direction = dir

    frame:SetSize(cfg.w, cfg.h)
    frame:SetMovable(not isLocked())

    logo:ClearAllPoints()
    logo:SetPoint("CENTER", frame, cfg.logoAnchor, 0, 0)

    for i, button in ipairs(iconButtons) do
        local offset = BUTTON_START_GAP + (BUTTON_STEP * (i - 1))
        button:ClearAllPoints()
        button:SetPoint("CENTER", logo, "CENTER", offset * cfg.x, offset * cfg.y)
    end
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

logo:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        if IsShiftKeyDown() then
            -- Shift+Right-Click: open a copyable version string popup
            local popup = CreateFrame("Frame", "GSEVersionPopup", UIParent, "DialogBoxFrame")
            popup:SetPoint("CENTER")
            popup:SetSize(300, 100)
            popup:SetBackdrop({
                bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            popup:SetBackdropColor(0, 0, 0, 1)
            popup:SetFrameStrata("DIALOG")
            local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
            editBox:SetSize(250, 30)
            editBox:SetPoint("CENTER", 0, 20)
            editBox:SetAutoFocus(true)
            editBox:SetText("GSE v" .. (GSE.VersionString or "Unknown"))
            editBox:HighlightText()
            editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
            popup:Show()
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
end
table.insert(ns.deferred, setup)
