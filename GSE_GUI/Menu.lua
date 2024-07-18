local GSE = GSE
local L = GSE.L

local frame = CreateFrame("frame", "GSE_Menu", UIParent, BackdropTemplateMixin and "BasicFrameTemplate")
frame:SetMovable(true)
frame:EnableMouse(true)

frame:SetPoint("CENTER")
frame:Hide()
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
frame.text:SetText(L["GSE: Main Menu"])
frame:SetSize(500, 60)
if GSEOptions.frameLocations and GSEOptions.frameLocations.menu then
    frame:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.menu.left,
        GSEOptions.frameLocations.menu.top
    )
end

local sequencebutton = CreateFrame("button", nil, frame, "UIPanelButtonTemplate")
sequencebutton:SetPoint("BOTTOMLEFT")
sequencebutton:SetSize(100, 40)
sequencebutton:SetText(L["Sequences"])
sequencebutton:SetScript(
    "OnClick",
    function(self, button, down)
        GSE.ShowSequences()
    end
)
sequencebutton:RegisterForClicks("AnyDown", "AnyUp")

local variablebutton = CreateFrame("button", nil, frame, "UIPanelButtonTemplate")
variablebutton:SetPoint("BOTTOMLEFT", sequencebutton, "BOTTOMLEFT", 100, 0)
variablebutton:SetSize(100, 40)
variablebutton:SetText(L["Variables"])
variablebutton:SetScript(
    "OnClick",
    function(self, button, down)
        GSE.ShowVariables()
    end
)
variablebutton:RegisterForClicks("AnyDown", "AnyUp")

local macrobutton = CreateFrame("button", nil, frame, "UIPanelButtonTemplate")
macrobutton:SetPoint("BOTTOMLEFT", variablebutton, "BOTTOMLEFT", 100, 0)
macrobutton:SetSize(100, 40)
macrobutton:SetText(L["Macros"])
macrobutton:SetScript(
    "OnClick",
    function(self, button, down)
        GSE.ShowMacros()
    end
)
macrobutton:RegisterForClicks("AnyDown", "AnyUp")

local keybindButton = CreateFrame("button", nil, frame, "UIPanelButtonTemplate")
keybindButton:SetPoint("BOTTOMLEFT", macrobutton, "BOTTOMLEFT", 100, 0)
keybindButton:SetSize(100, 40)
keybindButton:SetText(L["Keybindings"])
keybindButton:SetScript(
    "OnClick",
    function(self, button, down)
        GSE.ShowKeyBindings()
    end
)
keybindButton:RegisterForClicks("AnyDown", "AnyUp")

local importbutton = CreateFrame("button", nil, frame, "UIPanelButtonTemplate")
importbutton:SetPoint("BOTTOMLEFT", keybindButton, "BOTTOMLEFT", 100, 0)
importbutton:SetSize(100, 40)
importbutton:SetText(L["Import"])
importbutton:SetScript(
    "OnClick",
    function(self, button, down)
        GSE.GUIImportFrame:Show()
    end
)
importbutton:RegisterForClicks("AnyDown", "AnyUp")
