local GSE = GSE
local L = GSE.L
local AceGUI = LibStub("AceGUI-3.0")
local Statics = GSE.Static

local frame = AceGUI:Create("Frame")
local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
local font = CreateFont("seqPanelFont")
font:SetFontObject(GameFontNormal)
local origjustificationH = font:GetJustifyH()
local origjustificationV = font:GetJustifyV()
font:SetJustifyH("LEFT")
font:SetJustifyV("MIDDLE")
if GSE.isEmpty(fontFlags) then
    fontFlags = "OUTLINE"
end
frame:SetLayout("Flow")
frame:SetTitle(L["GSE: Main Menu"])
frame:Hide()
frame.frame:SetFrameStrata("MEDIUM")
frame.frame:SetClampedToScreen(true)
frame:SetCallback(
    "OnClose",
    function(widget)
        frame:Hide()
    end
)
frame:SetStatusText(GSE.VersionString)

frame:SetWidth(650)
frame:SetHeight(100)

local texture = frame.frame:CreateTexture(nil, "BACKGROUND")
texture:SetTexture("Interface\\Addons\\GSE_GUI\\Assets\\menubackground.png")
texture:SetAllPoints()

if GSEOptions.frameLocations and GSEOptions.frameLocations.menu then
    frame.frame:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.menu.left,
        GSEOptions.frameLocations.menu.top
    )
end

frame.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        frame:SetWidth(650)
        frame:SetHeight(100)
    end
)

local sequencebutton = AceGUI:Create("InteractiveLabel")
sequencebutton:SetFont(fontName, fontHeight, fontFlags)
sequencebutton:SetText("|T" .. Statics.ActionsIcons.Repeat .. ":15:15|t" .. L["Sequences"])
sequencebutton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.ShowSequences()
    end
)
sequencebutton:SetCallback(
    "OnEnter",
    function(self, button, down)
        sequencebutton:SetText("|T" .. Statics.ActionsIcons.Repeat .. ":15:15|t|cFF13b9b9" .. L["Sequences"])
    end
)
sequencebutton:SetCallback(
    "OnLeave",
    function(self, button, down)
        sequencebutton:SetText("|T" .. Statics.ActionsIcons.Repeat .. ":15:15|t" .. L["Sequences"])
    end
)
sequencebutton:SetWidth(100)

local variablebutton = AceGUI:Create("InteractiveLabel")
variablebutton:SetFont(fontName, fontHeight, fontFlags)
variablebutton:SetText("|T" .. Statics.ActionsIcons.If .. ":15:15|t" .. L["Variables"])
variablebutton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.ShowVariables()
    end
)
variablebutton:SetWidth(100)
variablebutton:SetCallback(
    "OnEnter",
    function(self, button, down)
        variablebutton:SetText("|T" .. Statics.ActionsIcons.If .. ":15:15|t|cFF13b9b9" .. L["Variables"])
    end
)
variablebutton:SetCallback(
    "OnLeave",
    function(self, button, down)
        variablebutton:SetText("|T" .. Statics.ActionsIcons.If .. ":15:15|t" .. L["Variables"])
    end
)

local macrobutton = AceGUI:Create("InteractiveLabel")
macrobutton:SetFont(fontName, fontHeight, fontFlags)
macrobutton:SetText("|T" .. Statics.ActionsIcons.Action .. ":15:15|t" .. L["Macros"])
macrobutton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.ShowMacros()
    end
)
macrobutton:SetWidth(100)
macrobutton:SetCallback(
    "OnEnter",
    function(self, button, down)
        macrobutton:SetText("|T" .. Statics.ActionsIcons.Action .. ":15:15|t|cFF13b9b9" .. L["Macros"])
    end
)
macrobutton:SetCallback(
    "OnLeave",
    function(self, button, down)
        macrobutton:SetText("|T" .. Statics.ActionsIcons.Action .. ":15:15|t" .. L["Macros"])
    end
)

local keybindButton = AceGUI:Create("InteractiveLabel")
keybindButton:SetFont(fontName, fontHeight, fontFlags)
keybindButton:SetText("|T" .. Statics.ActionsIcons.Key .. ":15:15|t" .. L["Keybindings"])
keybindButton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.ShowKeyBindings()
    end
)
keybindButton:SetWidth(100)
keybindButton:SetCallback(
    "OnEnter",
    function(self, button, down)
        keybindButton:SetText("|T" .. Statics.ActionsIcons.Key .. ":15:15|t|cFF13b9b9" .. L["Keybindings"])
    end
)
keybindButton:SetCallback(
    "OnLeave",
    function(self, button, down)
        keybindButton:SetText("|T" .. Statics.ActionsIcons.Key .. ":15:15|t" .. L["Keybindings"])
    end
)

local importbutton = AceGUI:Create("InteractiveLabel")
importbutton:SetFont(fontName, fontHeight, fontFlags)
importbutton:SetText("|T" .. Statics.ActionsIcons.Down .. ":15:15|t" .. L["Import"])
importbutton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.GUIImportFrame:Show()
    end
)
importbutton:SetWidth(100)
importbutton:SetCallback(
    "OnEnter",
    function(self, button, down)
        importbutton:SetText("|T" .. Statics.ActionsIcons.Down .. ":15:15|t|cFF13b9b9" .. L["Import"])
    end
)
importbutton:SetCallback(
    "OnLeave",
    function(self, button, down)
        importbutton:SetText("|T" .. Statics.ActionsIcons.Down .. ":15:15|t" .. L["Import"])
    end
)

local optionsbutton = AceGUI:Create("InteractiveLabel")
optionsbutton:SetFont(fontName, fontHeight, fontFlags)
optionsbutton:SetText("|T" .. Statics.ActionsIcons.Settings .. ":15:15|t" .. L["Options"])
optionsbutton:SetCallback(
    "OnClick",
    function(self, button, down)
        GSE.OpenOptionsPanel()
    end
)
optionsbutton:SetWidth(100)
optionsbutton:SetCallback(
    "OnEnter",
    function(self, button, down)
        optionsbutton:SetText("|T" .. Statics.ActionsIcons.Settings .. ":15:15|t|cFF13b9b9" .. L["Options"])
    end
)
optionsbutton:SetCallback(
    "OnLeave",
    function(self, button, down)
        optionsbutton:SetText("|T" .. Statics.ActionsIcons.Settings .. ":15:15|t" .. L["Options"])
    end
)

frame:AddChild(sequencebutton)
frame:AddChild(variablebutton)
frame:AddChild(keybindButton)
frame:AddChild(importbutton)
frame:AddChild(macrobutton)
frame:AddChild(optionsbutton)

function GSE.ShowMenu()
    frame:Show()
end

GSE.MenuFrame = frame
