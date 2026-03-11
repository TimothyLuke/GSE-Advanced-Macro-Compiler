local GSE = GSE
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
frame:SetBackdrop({
    bgFile   = "Interface/CHARACTERFRAME/UI-Party-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
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
logoTex:SetTexture(Statics.Icons.MenuLogo)

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

local iconData = {
    { Statics.Icons.Sequences,   L["Sequences"],   GSE.ShowSequences   },
    { Statics.Icons.Keybindings, L["Keybindings"], GSE.ShowKeyBindings },
    { Statics.Icons.Variables,   L["Variables"],   GSE.ShowVariables   },
    { Statics.Icons.Import,      L["Import"],      GSE.ShowImport      },
    { Statics.Icons.Macros,      L["Macros"],      GSE.ShowMacros      },
    { Statics.Icons.Options,     L["Options"],     GSE.OpenOptionsPanel},
    {
        Statics.Icons.Close,
        L["Close"],
        function()
            local opts = getMenuOpts()
            opts.left = frame:GetLeft()
            opts.top  = frame:GetTop()
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
    frame:Show()
end

GSE.MenuFrame = frame
