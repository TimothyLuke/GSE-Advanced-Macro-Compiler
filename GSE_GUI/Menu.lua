local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

-- Create the main frame
local frame = CreateFrame("Frame", "GSEMenuFrame", UIParent, "BackdropTemplate")
frame:SetSize(38, 265)
frame:SetPoint("CENTER")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop(
    {
        bgFile = "Interface/CHARACTERFRAME/UI-Party-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    }
)
frame:SetBackdropColor(0, 0, 0, 1)
frame:Hide()

-- Title image
local logo = CreateFrame("Button", nil, frame)
logo:SetSize(50, 50)
logo:SetPoint("TOP", frame, "TOP", 0, 25)

local logoTex = logo:CreateTexture(nil, "OVERLAY")
logoTex:SetAllPoints()
logoTex:SetTexture(Statics.Icons.MenuLogo)

logo:RegisterForDrag("LeftButton")
logo:SetScript(
    "OnDragStart",
    function()
        frame:StartMoving()
    end
)
logo:SetScript(
    "OnDragStop",
    function()
        frame:StopMovingOrSizing()
    end
)

-- Tooltip for logo showing version and shift-right-click to copy
logo:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("GSE v" .. (GSE.VersionString or "Unknown"))
        GameTooltip:AddLine("Shift + Right-Click to copy version", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end
)

logo:SetScript(
    "OnLeave",
    function()
        GameTooltip:Hide()
    end
)

logo:SetScript(
    "OnMouseUp",
    function(self, button)
        if IsShiftKeyDown() and button == "RightButton" then
            local versionText = GSE.VersionString or "Unknown"
            local popup = CreateFrame("Frame", "GSEVersionPopup", UIParent, "DialogBoxFrame")
            popup:SetPoint("CENTER")
            popup:SetSize(300, 100)
            popup:SetBackdrop(
                {
                    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                    tile = true,
                    tileSize = 16,
                    edgeSize = 16,
                    insets = {left = 4, right = 4, top = 4, bottom = 4}
                }
            )
            popup:SetBackdropColor(0, 0, 0, 1)
            popup:SetFrameStrata("DIALOG")

            local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
            editBox:SetSize(250, 30)
            editBox:SetPoint("CENTER", 0, 20)
            editBox:SetAutoFocus(true)
            editBox:SetText("GSE v" .. versionText)
            editBox:HighlightText()
            editBox:SetScript(
                "OnEscapePressed",
                function()
                    popup:Hide()
                end
            )

            popup:Show()
        end
    end
)

-- Restore saved position if available
if GSEOptions.frameLocations and GSEOptions.frameLocations.menu then
    frame:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.menu.left,
        GSEOptions.frameLocations.menu.top
    )
end

-- Utility function to create a button
local function createIconButton(parent, icon, labelText, onClickFunc, offsetY)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("TOP", 0, offsetY)

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture(icon)

    button:SetScript("OnClick", onClickFunc)

    button:SetScript(
        "OnEnter",
        function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 1, 1)
            GameTooltip:Show()
            button:SetSize(25, 25)
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            GameTooltip:Hide()
            button:SetSize(20, 20)
        end
    )

    return button
end

-- Create and add buttons
local iconData = {
    {Statics.Icons.Sequences, L["Sequences"], GSE.ShowSequences},
    {Statics.Icons.Keybindings, L["Keybindings"], GSE.ShowKeyBindings},
    {Statics.Icons.Variables, L["Variables"], GSE.ShowVariables},
    {Statics.Icons.Import, L["Import"], GSE.ShowImport},
    {Statics.Icons.Macros, L["Macros"], GSE.ShowMacros},
    {Statics.Icons.Options, L["Options"], GSE.OpenOptionsPanel},
    {
        Statics.Icons.Close,
        L["Close"],
        function()
            frame:Hide()
        end
    }
}

local startY = -40
local spacing = -31

for i, data in ipairs(iconData) do
    createIconButton(frame, data[1], data[2], data[3], startY + (i - 1) * spacing)
end

function GSE.ShowMenu()
    frame:Show()
end

GSE.MenuFrame = frame
