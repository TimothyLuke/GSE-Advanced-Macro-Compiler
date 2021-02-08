local GSEGUI, _ = ...

local GSE = GSE
local GSEOptions = GSEOptions
local Statics = GSE.Static
local L = GSE.L

local AceGUI = LibStub("AceGUI-3.0")

local frame = CreateFrame("frame", "GSE3", UIParent, BackdropTemplateMixin and "BackdropTemplate" )
frame:SetSize(500, 300)
frame:SetPoint("CENTER")

frame:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, .5)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(500, 300)
scrollFrame:SetPoint("CENTER")


local AdvancedTextEditor = CreateFrame("EditBox", nil, scrollFrame)

AdvancedTextEditor:SetMultiLine(true)
--AdvancedTextEditor:SetText("local sequence = " .. GSE.Dump(GSE.Library[2]["SAM_PROTGOD"]))
AdvancedTextEditor:SetText(GSE.Dump(GSE.ConvertGSE2(GSE.Library[2]["SAM_PROTGOD"], "SAM_PROTGOD")))

AdvancedTextEditor:SetFontObject(ChatFontNormal)
AdvancedTextEditor:SetWidth(500)
AdvancedTextEditor:SetScript("OnEscapePressed", function() frame:Hide() end)

frame.TextBox = AdvancedTextEditor

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