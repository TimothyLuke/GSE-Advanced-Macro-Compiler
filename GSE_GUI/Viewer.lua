local GNOME, _ = ...

local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()
local editkey = ""

local viewframe = AceGUI:Create("Frame")
viewframe:SetTitle(L["Sequence Menu"])
-- viewframe.frame:SetBackdrop({
--   bgFile="Interface\\Addons\\GSE_GUI\\GSE2_Logo_Dark_512.tga",
--   edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
--   tile=false,
--   edgeSize=10,
--   insets={left=3, right=3, top=3, bottom=3}
-- });

GSE.GUIViewFrame = viewframe
if GSE.isEmpty(GSEOptions.menuHeight) then
	GSEOptions.menuHeight = 500
end
if GSE.isEmpty(GSEOptions.menuWidth) then
	GSEOptions.menuWidth = 700
end

viewframe.Height = GSEOptions.menuHeight
viewframe.Width = GSEOptions.menuWidth
viewframe:SetWidth(viewframe.Width)
viewframe:SetHeight(viewframe.Height)

viewframe:Hide()
-- local sequenceboxtext = AceGUI:Create("MultiLineEditBox")
-- local remotesequenceboxtext = AceGUI:Create("MultiLineEditBox")

viewframe.panels = {}
viewframe.SequenceName = ""
viewframe.ClassID = 0

function viewframe:clearpanels(widget, selected)
	GSE.PrintDebugMessage("widget = " .. widget:GetKey(), "GUI")
	for k, _ in pairs(viewframe.panels) do
		GSE.PrintDebugMessage("k " .. k, "GUI")
		if k == widget:GetKey() then
			GSE.PrintDebugMessage("matching key", "GUI")
			local elements = GSE.split(widget:GetKey(), ",")
			if selected then
				viewframe.ClassID = elements[1]
				viewframe.SequenceName = elements[2]
				viewframe.EditButton:SetDisabled(false)
				viewframe.ExportButton:SetDisabled(false)
				editkey = k
				viewframe.EditButton:SetText(L["Edit"])
				viewframe.editbuttonaction = 0
			else
				viewframe.ClassID = 0
				viewframe.SequenceName = ""
				viewframe.EditButton:SetDisabled(true)
				viewframe.ExportButton:SetDisabled(true)
				editkey = ""
			end

			viewframe.panels[k]:SetClicked(true)
		else
			GSE.PrintDebugMessage("other widget key", "GUI")
			GSE.PrintDebugMessage("reprinting k " .. k, "GUI")
			local wid = viewframe.panels[k]
			wid:SetClicked(false)
		end
	end

	GSE.GUIConfigureMacroButton(viewframe.MacroIconButton)
end

function GSE.GUICreateSequencePanels(frame, container, key)
	local elements = GSE.split(key, ",")
	local classid = tonumber(elements[1])
	local sequencename = elements[2]
	local readonly = elements[3]
	local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
	local font = CreateFont("seqPanelFont")
	font:SetFontObject(GameFontNormal)
	local fontlarge = CreateFont("seqLargePanelFont")
	fontlarge:SetFontObject(GameFontNormalLarge)
	local origjustifyV = font:GetJustifyV()
	local origjustifyH = font:GetJustifyH()
	font:SetJustifyV("BOTTOM")

	local selpanel = AceGUI:Create("SelectablePanel")

	selpanel:SetKey(key)
	selpanel:SetFullWidth(true)
	selpanel:SetHeight(300)
	viewframe.panels[key] = selpanel
	selpanel:SetCallback(
		"OnClick",
		function(widget, _, selected, button)
			viewframe:clearpanels(widget, selected)
			if button == "RightButton" then
				GSE.GUILoadEditor(widget:GetKey(), viewframe)
			end
			if button == "LeftButton" and IsShiftKeyDown() then
				StaticPopupDialogs["GSE_ChatLink"].link = GSE.SequenceChatPattern(elements[2], elements[1])
				StaticPopup_Show("GSE_ChatLink")
			end
		end
	)

	-- Workaround for vanishing label ace3 bug
	local label = AceGUI:Create("Label")
	label:SetFontObject(fontlarge)
	selpanel:AddChild(label)

	local hlabel = AceGUI:Create("Label")
	hlabel:SetText(sequencename)
	if readonly == "1" then
		hlabel:SetText(sequencename .. "( " .. L["Restricted"] .. ")")
	end

	--hlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
	hlabel:SetFontObject(fontlarge)
	hlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
	selpanel:AddChild(hlabel)

	local columngroup = AceGUI:Create("KeyGroup")
	columngroup:SetFullWidth(true)
	columngroup:SetLayout("Flow")

	local column1 = AceGUI:Create("KeyGroup")
	column1:SetWidth(viewframe.Width - 140)
	column1:SetLayout("List")

	columngroup:AddChild(column1)

	local helplabel = AceGUI:Create("Label")
	local helptext = L["No Help Information Available"]
	if not GSE.isEmpty(GSE.Library[classid][sequencename].MetaData.Help) then
		helptext = GSE.Library[classid][sequencename].MetaData.Help
	end
	helplabel:SetFullWidth(true)
	helplabel:SetFontObject(font)
	helplabel:SetText(helptext)
	column1:AddChild(helplabel)

	local row2 = AceGUI:Create("KeyGroup")
	row2:SetLayout("Flow")
	row2:SetFullWidth(true)

	local talentsHead = AceGUI:Create("Label")
	talentsHead:SetFont(fontName, fontHeight + 2, fontFlags)
	talentsHead:SetText(L["Talents"] .. ":")
	talentsHead:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
	talentsHead:SetWidth(60)
	row2:AddChild(talentsHead)

	local talentslabel = AceGUI:Create("Label")
	if not GSE.isEmpty(GSE.Library[classid][sequencename].MetaData.Talents) then
		talentslabel:SetText(GSE.Library[classid][sequencename].MetaData.Talents)
	end
	talentslabel:SetWidth(80)
	talentslabel:SetFontObject(font)
	row2:AddChild(talentslabel)

	local spacerlabel1 = AceGUI:Create("Label")
	spacerlabel1:SetText("")
	spacerlabel1:SetWidth(5)
	row2:AddChild(spacerlabel1)

	local urlHead = AceGUI:Create("Label")
	urlHead:SetFont(fontName, fontHeight + 2, fontFlags)
	urlHead:SetText(L["Help URL"] .. ":")
	urlHead:SetColor(GSE.GUIGetColour(GSEOptions.EmphasisColour))
	urlHead:SetWidth(70)
	row2:AddChild(urlHead)

	local urlval = "https://wowlazymacros.com"
	local urllabel = AceGUI:Create("InteractiveLabel")
	if not GSE.isEmpty(GSE.Library[classid][sequencename].MetaData.Helplink) then
		urlval = GSE.Library[classid][sequencename].MetaData.Helplink
	end
	urllabel:SetFontObject(font)
	urllabel:SetText(urlval)
	urllabel:SetCallback(
		"OnClick",
		function()
			StaticPopupDialogs["GSE_SEQUENCEHELP"].url = urlval
			StaticPopup_Show("GSE_SEQUENCEHELP")
		end
	)
	urllabel:SetColor(GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS))
	urllabel:SetWidth(280)
	row2:AddChild(urllabel)

	local column2 = AceGUI:Create("KeyGroup")
	column2:SetWidth(60)
	column2:SetLayout("List")
	columngroup:AddChild(column2)

	local viewiconpicker = AceGUI:Create("Icon")

	viewiconpicker.frame:RegisterForDrag("LeftButton")
	viewiconpicker.frame:SetScript(
		"OnDragStart",
		function()
			PickupMacro(sequencename)
		end
	)
	--viewiconpicker.frame:SetBackdrop(nil)

	selpanel.Icon = viewiconpicker
	viewiconpicker:SetImage(GSE.GetMacroIcon(classid, sequencename))
	viewiconpicker:SetImageSize(50, 50)
	viewiconpicker:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(
				L["Macro Icon"],
				L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."],
				viewframe
			)
		end
	)
	viewiconpicker:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	column2:AddChild(viewiconpicker)

	selpanel:AddChild(columngroup)
	selpanel:AddChild(row2)

	container:AddChild(selpanel)
	font:SetJustifyV(origjustifyV)
	font:SetJustifyH(origjustifyH)
end

function GSE.GUIViewerToolbar(container)
	local buttonGroup = AceGUI:Create("KeyGroup")
	buttonGroup:SetFullWidth(true)
	buttonGroup:SetLayout("Flow")

	local newbutton = AceGUI:Create("Button")
	newbutton:SetText(L["New"])
	newbutton:SetWidth(150)
	newbutton:SetCallback(
		"OnClick",
		function()
			GSE.GUILoadEditor(nil, viewframe)
			viewframe:Hide()
		end
	)
	newbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(L["New"], L["Create a new macro."], viewframe)
		end
	)
	newbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	buttonGroup:AddChild(newbutton)

	local updbutton = AceGUI:Create("Button")
	updbutton:SetText(L["Edit"])
	updbutton:SetWidth(150)
	updbutton:SetCallback(
		"OnClick",
		function()
			if viewframe.editbuttonaction == 1 then
				GSE.GUIDeleteSequence(viewframe.ClassID, viewframe.SequenceName)
			else
				GSE.GUILoadEditor(editkey, viewframe)
				viewframe:Hide()
			end
		end
	)
	updbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(
				L["Edit"],
				L["Edit this macro.  To delete a macro, choose this edit option and then from inside hit the delete button."],
				viewframe
			)
		end
	)
	updbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)

	updbutton:SetDisabled(true)
	buttonGroup:AddChild(updbutton)
	viewframe.EditButton = updbutton

	local impbutton = AceGUI:Create("Button")
	impbutton:SetText(L["Import"])
	impbutton:SetWidth(150)
	impbutton:SetCallback(
		"OnClick",
		function()
			GSE.GUIViewFrame:Hide()
			GSE.GUIImportFrame:Show()
		end
	)
	impbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(L["Import"], L["Import Macro from Forums"], viewframe)
		end
	)
	impbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	buttonGroup:AddChild(impbutton)

	local expbutton = AceGUI:Create("Button")
	expbutton:SetText(L["Export"])
	expbutton:SetWidth(150)
	expbutton:SetCallback(
		"OnClick",
		function()
			GSE.GUIExportSequence(viewframe.ClassID, viewframe.SequenceName)
		end
	)
	buttonGroup:AddChild(expbutton)
	expbutton:SetDisabled(true)
	expbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(L["Export"], L["Export this Macro."], viewframe)
		end
	)
	expbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	viewframe.ExportButton = expbutton

	local tranbutton = AceGUI:Create("Button")
	tranbutton:SetText(L["Send"])
	tranbutton:SetWidth(150)
	tranbutton:SetCallback(
		"OnClick",
		function()
			GSE.GUIShowTransmissionGui(viewframe.ClassID .. "," .. viewframe.SequenceName)
		end
	)
	tranbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(
				L["Send"],
				L["Send this macro to another GSE player who is on the same server as you are."],
				viewframe
			)
		end
	)
	tranbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	buttonGroup:AddChild(tranbutton)

	local disableSeqbutton = AceGUI:Create("Button")
	disableSeqbutton:SetDisabled(true)
	disableSeqbutton:SetText(L["Create Icon"])
	disableSeqbutton:SetWidth(150)
	disableSeqbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(
				L["Create Icon"],
				L[
					"Create or remove a Macro stub in /macro that can be dragged to your action bar so that you can use this macro.\nGSE can store an unlimited number of macros however WOW's /macro interface can only store a limited number of macros."
				],
				viewframe
			)
		end
	)
	disableSeqbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)

	buttonGroup:AddChild(disableSeqbutton)
	viewframe.MacroIconButton = disableSeqbutton
	local eOptionsbutton = AceGUI:Create("Button")
	eOptionsbutton:SetText(L["Options"])
	eOptionsbutton:SetWidth(150)
	eOptionsbutton:SetCallback(
		"OnClick",
		function()
			GSE.OpenOptionsPanel()
		end
	)
	eOptionsbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(L["Options"], L["Opens the GSE Options window"], viewframe)
		end
	)
	eOptionsbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)
	buttonGroup:AddChild(eOptionsbutton)

	local recordwindowbutton = AceGUI:Create("Button")
	recordwindowbutton:SetText(L["Record Macro"])
	recordwindowbutton:SetWidth(150)
	recordwindowbutton:SetCallback(
		"OnClick",
		function()
			GSE.GUIViewFrame:Hide()
			GSE.GUIRecordFrame:Show()
		end
	)
	recordwindowbutton:SetCallback(
		"OnEnter",
		function()
			GSE.CreateToolTip(L["Record Macro"], L["Record the spells and items you use into a new macro."], viewframe)
		end
	)
	recordwindowbutton:SetCallback(
		"OnLeave",
		function()
			GSE.ClearTooltip(viewframe)
		end
	)

	buttonGroup:AddChild(recordwindowbutton)
	container:AddChild(buttonGroup)
	-- sequenceboxtext = sequencebox
end

function GSE.GUIViewerLayout(mcontainer)
	mcontainer:SetStatusText("GSE: " .. GSE.VersionString)
	mcontainer:SetCallback(
		"OnClose",
		function(widget)
			GSE.ClearTooltip(viewframe)
			viewframe:Hide()
		end
	)
	mcontainer:SetLayout("List")

	local scrollcontainer = AceGUI:Create("KeyGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetLayout("Fill")
	scrollcontainer:SetHeight(viewframe.Height - 130)

	mcontainer:AddChild(scrollcontainer)
	local contentcontainer = AceGUI:Create("ScrollFrame")
	contentcontainer:SetLayout("list")
	scrollcontainer:AddChild(contentcontainer)
	viewframe.ScrollContainer = contentcontainer

	GSE.GUIViewerToolbar(mcontainer)
end

function GSE.GUIShowViewer()
	local names = GSE.GetSequenceNames()

	viewframe:ReleaseChildren()
	GSE.GUIViewerLayout(viewframe)
	local cclassid = -1
	for k, _ in GSE.pairsByKeys(names) do
		local elements = GSE.split(k, ",")
		local tclassid = tonumber(elements[1])
		if tclassid ~= cclassid then
			cclassid = tclassid
			local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
			local sectionspacer1 = AceGUI:Create("Label")
			sectionspacer1:SetText(" ")
			sectionspacer1:SetFont(fontName, 4, fontFlags)
			viewframe.ScrollContainer:AddChild(sectionspacer1)
			local sectionheader = AceGUI:Create("Label")
			sectionheader:SetText(Statics.SpecIDList[cclassid])
			sectionheader:SetFont(fontName, fontHeight + 6, fontFlags)
			sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
			viewframe.ScrollContainer:AddChild(sectionheader)
			local sectionspacer2 = AceGUI:Create("Label")
			sectionspacer2:SetText(" ")
			sectionspacer2:SetFont(fontName, 2, fontFlags)
			viewframe.ScrollContainer:AddChild(sectionspacer2)
		end
		GSE.GUICreateSequencePanels(viewframe, viewframe.ScrollContainer, k)
	end
	viewframe:Show()
end

function GSE.GUIConfigureMacroButton(button)
	if GSE.OOCCheckMacroCreated(GSE.GUIViewFrame.SequenceName) then
		button:SetText(L["Delete Icon"])
		button:SetCallback(
			"OnClick",
			function()
				GSE.DeleteMacroStub(GSE.GUIViewFrame.SequenceName)
				GSE.GUIConfigureMacroButton(button)
				GSE.GUIViewFrame.panels[
					viewframe.ClassID .. "," .. GSE.GUIViewFrame.SequenceName .. "," .. GSE.GUIViewFrame.editbuttonaction
				].Icon:SetImage(GSE.GetMacroIcon(tonumber(GSE.GUIViewFrame.ClassID), GSE.GUIViewFrame.SequenceName))
			end
		)
	else
		button:SetText(L["Create Icon"])
		button:SetCallback(
			"OnClick",
			function()
				GSE.OOCCheckMacroCreated(GSE.GUIViewFrame.SequenceName, true)
				GSE.GUIConfigureMacroButton(button)
				GSE.GUIViewFrame.panels[
					viewframe.ClassID .. "," .. GSE.GUIViewFrame.SequenceName .. "," .. GSE.GUIViewFrame.editbuttonaction
				].Icon:SetImage(GSE.GetMacroIcon(tonumber(GSE.GUIViewFrame.ClassID), GSE.GUIViewFrame.SequenceName))
			end
		)
	end
	if GSE.isEmpty(GSE.GUIViewFrame.SequenceName) then
		button:SetDisabled(true)
	else
		button:SetDisabled(false)
	end
	if GSE.GUIViewFrame.ClassID == 0 or GSE.GUIViewFrame.ClassID == GSE.GetCurrentClassID() then
		button:SetDisabled(true)
	end
end

viewframe.frame:SetScript(
	"OnSizeChanged",
	function(_, width, height)
		viewframe.Height = height
		viewframe.Width = width
		if viewframe.Height > GetScreenHeight() then
			viewframe.Height = GetScreenHeight() - 10
			viewframe:SetHeight(viewframe.Height)
		end
		if viewframe.Height < 500 then
			viewframe.Height = 500
			viewframe:SetHeight(viewframe.Height)
		end
		if viewframe.Width < 700 then
			viewframe.Width = 700
			viewframe:SetWidth(viewframe.Width)
		end
		GSEOptions.menuHeight = viewframe.Height
		GSEOptions.menuWidth = viewframe.Width
		if viewframe:IsVisible() then
			GSE.GUIShowViewer()
		end
	end
)
