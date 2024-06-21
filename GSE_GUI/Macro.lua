local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local macroframe = AceGUI:Create("Frame")
macroframe:Hide()
macroframe.panels = {}

macroframe.frame:SetFrameStrata("MEDIUM")
if
    GSEOptions.frameLocations and GSEOptions.frameLocations.macroframe and GSEOptions.frameLocations.macroframe.left and
        GSEOptions.frameLocations.macroframe.top
 then
    macroframe:SetPoint(
        "TOPLEFT",
        UIParent,
        "BOTTOMLEFT",
        GSEOptions.frameLocations.macroframe.left,
        GSEOptions.frameLocations.macroframe.top
    )
end
GSE.GUIMacroFrame = macroframe

if GSE.isEmpty(GSEOptions.macroHeight) then
    GSEOptions.macroHeight = 500
end
if GSE.isEmpty(GSEOptions.macroWidth) then
    GSEOptions.macroWidth = 700
end
macroframe.Height = GSEOptions.macroHeight
macroframe.Width = GSEOptions.macroWidth
if macroframe.Height < 500 then
    macroframe.Height = 500
    GSEOptions.macroHeight = macroframe.Height
end
if macroframe.Width < 700 then
    macroframe.Width = 700
    GSEOptions.macroWidth = macroframe.Width
end
macroframe.frame:SetClampRectInsets(-10, -10, -10, -10)
macroframe.frame:SetHeight(GSEOptions.editorHeight)
macroframe.frame:SetWidth(GSEOptions.editorWidth)

macroframe:SetTitle(L["Macros"])
macroframe:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(macroframe)
        macroframe:Hide()
    end
)

macroframe:SetLayout("Flow")
macroframe:SetAutoAdjustHeight(false)

local basecontainer = AceGUI:Create("SimpleGroup")
basecontainer:SetLayout("Flow")
basecontainer:SetAutoAdjustHeight(false)
basecontainer:SetHeight(macroframe.Height - 100)
basecontainer:SetFullWidth(true)
macroframe:AddChild(basecontainer)

local leftScrollContainer = AceGUI:Create("SimpleGroup")
leftScrollContainer:SetWidth(200)

leftScrollContainer:SetHeight(macroframe.Height - 90)
leftScrollContainer:SetLayout("Fill") -- important!

basecontainer:AddChild(leftScrollContainer)

local leftscroll = AceGUI:Create("ScrollFrame")
leftscroll:SetLayout("List") -- probably?
leftscroll:SetWidth(200)
leftScrollContainer:AddChild(leftscroll)

local spacer = AceGUI:Create("Label")
spacer:SetWidth(10)
basecontainer:AddChild(spacer)

local rightContainer = AceGUI:Create("SimpleGroup")
rightContainer:SetWidth(macroframe.Width - 290)

rightContainer:SetLayout("List")
rightContainer:SetHeight(macroframe.Height - 90)
basecontainer:AddChild(rightContainer)

local function showMacro(node)
end

local function buildMacroHeader(node)
    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    local origjustification = font:GetJustifyH()
    font:SetJustifyH("LEFT")

    local selpanel = AceGUI:Create("SelectablePanel")

    selpanel:SetKey(node.value)
    selpanel:SetFullWidth(true)
    selpanel:SetHeight(20)
    selpanel:SetAutoAdjustHeight(false)
    selpanel:SetLayout("List")

    macroframe.panels[node.value] = selpanel
    selpanel:SetCallback(
        "OnClick",
        function(widget, _, selected, button)
            macroframe:clearpanels(widget, selected)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(
                    selpanel,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Sequence Editor"])
                        rootDescription:CreateButton(
                            L["New"],
                            function()
                                GSE.GUILoadEditor()
                            end
                        )
                        rootDescription:CreateButton(
                            L["Import"],
                            function()
                                macroframe:Hide()
                                GSE.GUIImportFrame:Show()
                            end
                        )
                        -- rootDescription:CreateButton(
                        --     L["Delete"],
                        --     function()
                        --         GSE.GUIDeleteSequence(classid, sequencename)
                        --     end
                        -- )
                    end
                )
            else
                showMacro(node)
            end
        end
    )

    local hlabel = AceGUI:Create("Label")

    hlabel:SetText(node.name)
    hlabel:SetWidth(200)
    hlabel:SetFontObject(font)
    hlabel:SetImage(node.icon)
    hlabel:SetImageSize(19, 19)

    selpanel:AddChild(hlabel)

    leftscroll:AddChild(selpanel)
    font:SetJustifyH(origjustification)
end

local function buildMacroMenu()
    leftscroll:ReleaseChildren()

    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    local accountlabelflag = false
    local personallabelflag = false
    local fontName, fontHeight, fontFlags = GameFontNormal:GetFont()
    for macid = 1, maxmacros do
        local mname, micon, mtext = GetMacroInfo(macid)
        if mname then
            if macid <= MAX_ACCOUNT_MACROS and accountlabelflag == false then
                local sectionheader = AceGUI:Create("Label")
                sectionheader:SetText(L["Account Macros"])
                sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
                sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
                leftscroll:AddChild(sectionheader)
                accountlabelflag = true
            elseif macid > MAX_ACCOUNT_MACROS and personallabelflag == false then
                local sectionheader = AceGUI:Create("Label")
                sectionheader:SetText(L["Character Macros"])
                sectionheader:SetFont(fontName, fontHeight + 4, fontFlags)
                sectionheader:SetColor(GSE.GUIGetColour(GSEOptions.COMMENT))
                leftscroll:AddChild(sectionheader)
                personallabelflag = true
            end

            buildMacroHeader(
                {
                    value = macid,
                    name = mname,
                    icon = micon,
                    text = mtext
                }
            )
        end
    end
end

function macroframe:clearpanels(widget, selected)
    for k, _ in pairs(macroframe.panels) do
        if k == widget:GetKey() then
            if selected then
                --macroframe.showMacro(widget.node)
                macroframe.panels[k]:SetClicked(true)
            else
                macroframe.panels[k]:SetClicked(false)
            end
        else
            macroframe.panels[k]:SetClicked(false)
        end
    end
end

function GSE.ShowMacros()
    buildMacroMenu()
    macroframe:Show()
end
