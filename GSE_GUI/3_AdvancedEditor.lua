local GSEGUI, _ = ...

local GSE = GSE
local GSEOptions = GSEOptions
local Statics = GSE.Static
local L = GSE.L

local AceGUI = LibStub("AceGUI-3.0")

local width = GSEOptions.editorWidth
local height = GSEOptions.editorHeight

local frame = CreateFrame("frame", "GSE3", UIParent, BackdropTemplateMixin and "BackdropTemplate" )
frame:SetSize(width, height)
frame:SetPoint("CENTER")

frame:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, .5)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize((width - 50), (height - 30))
scrollFrame:SetPoint("CENTER")


local AdvancedTextEditor = CreateFrame("EditBox", nil, scrollFrame)

AdvancedTextEditor:SetMultiLine(true)
--AdvancedTextEditor:SetText("local sequence = " .. GSE.Dump(GSE.Library[2]["SAM_PROTGOD"]))
--AdvancedTextEditor:SetText()

AdvancedTextEditor:SetFontObject(ChatFontNormal)
AdvancedTextEditor:SetWidth((width - 28))
AdvancedTextEditor:SetScript("OnEscapePressed", function()
	frame:Hide()
	GSE.GUIEditFrame:Show()
	GSE.GUIEditFrame.AdvancedEditor = false
end)

frame.TextBox = AdvancedTextEditor
frame.Version = 0

local saveButton = CreateFrame("Button", nil, frame)
saveButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, -50)
saveButton:SetWidth(150)
saveButton:SetHeight(50)
saveButton:SetText(L["Compile"])
saveButton:SetNormalFontObject(GameFontNormal)

local CancelFontObject = saveButton:GetFontString()
CancelFontObject:SetPoint("CENTER", saveButton, "CENTER", -27, 8)

saveButton:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
saveButton:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight")
saveButton:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")

saveButton:SetScript("OnClick", function(self, arg1)
	local tab
	local load = "return " .. AdvancedTextEditor:GetText()
	local func, err = loadstring(load)
	if err then
		GSE.Print(L["Unable to process content.  Fix table and try again."], L["GSE Raw Editor"])
		GSE.Print(err, L["GSE Raw Editor"])
	else
		tab = func()
		if not GSE.isEmpty(tab) then
			GSE.GUIEditFrame.Sequence.Macros[frame.Version] = tab
			GSE.GUIEditorPerformLayout(GSE.GUIEditFrame)
			GSE.GUIEditFrame.ContentContainer:SelectTab(tostring(frame.Version))
			GSE.GUIEditFrame.AdvancedEditor = false
			frame:Hide()
			GSE.GUIEditFrame:Show()
		else
			GSE.Print(L["Unable to process content.  Fix table and try again."], L["GSE Raw Editor"])
		end
	end
end)

local cancelButton = CreateFrame("Button", nil, frame)
cancelButton:SetPoint("BOTTOM", frame, "BOTTOM", width / 2 -20, -50)
cancelButton:SetWidth(150)
cancelButton:SetHeight(50)
cancelButton:SetText(L["Close"])
cancelButton:SetNormalFontObject(GameFontNormal)

local fontObject = cancelButton:GetFontString()
fontObject:SetPoint("CENTER", cancelButton, "CENTER", -27, 8)

--button:SetFontString(fontObject)

cancelButton:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
cancelButton:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight")
cancelButton:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")

cancelButton:SetScript("OnClick", function(self, arg1)
	frame:Hide()
	GSE.GUIEditFrame:Show()
end)

local colorTable = {}

local tokens = IndentationLib.tokens

colorTable[tokens.TOKEN_SPECIAL] = GSEOptions.WOWSHORTCUTS
colorTable[tokens.TOKEN_KEYWORD] = GSEOptions.KEYWORD
colorTable[tokens.TOKEN_UNKNOWN] = GSEOptions.UNKNOWN
colorTable[tokens.TOKEN_COMMENT_SHORT] = GSEOptions.COMMENT
colorTable[tokens.TOKEN_COMMENT_LONG] = GSEOptions.COMMENT

local stringColor = GSEOptions.NormalColour
colorTable[tokens.TOKEN_STRING] = stringColor
colorTable[".."] = stringColor

local tableColor = GSEOptions.CONCAT
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = GSEOptions.STRING
colorTable["]"] = GSEOptions.STRING

local arithmeticColor = GSEOptions.NUMBER
colorTable[tokens.TOKEN_NUMBER] = arithmeticColor
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor

local logicColor1 = GSEOptions.EQUALS
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1

local logicColor2 = GSEOptions.EQUALS
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2

local castColor = GSEOptions.UNKNOWN
colorTable["/cast"] = castColor

colorTable[0] = "|r"

IndentationLib.enable(AdvancedTextEditor, colorTable, 4)
scrollFrame:SetScrollChild(AdvancedTextEditor)
frame:Hide()