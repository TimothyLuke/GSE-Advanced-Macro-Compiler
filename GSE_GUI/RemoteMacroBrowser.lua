local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor or {}
local L = GSE.L

local remoteFrame = UI:Create("Frame")
remoteFrame.frame:SetFrameStrata("MEDIUM")
remoteFrame:Hide()
remoteFrame.GSEUser = ""
remoteFrame.SequenceList = {}
remoteFrame.frame:SetClampedToScreen(true)
remoteFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

remoteFrame:SetStatusText(L["Select a Sequence"])
remoteFrame:SetCallback(
    "OnClose",
    function(widget)
        remoteFrame:Hide()
    end
)
remoteFrame:SetLayout("List")

remoteFrame.Height = seOpts.height or 500
remoteFrame.Width = seOpts.width or 700
-- These two fields drive every width below, but nothing ever applied them to
-- the frame, which stayed at UI:Create("Frame")'s default 500x400. The table
-- was therefore sized for a 700px window and drawn inside a 500px one -- worth
-- ~200px of overflow before any of the column arithmetic even ran.
remoteFrame.frame:SetHeight(remoteFrame.Height)
remoteFrame.frame:SetWidth(remoteFrame.Width)

local layoutcontainer = UI:Create("SimpleGroup")
layoutcontainer:SetFullWidth(true)
layoutcontainer:SetHeight(remoteFrame.Height - 320)
layoutcontainer:SetLayout("Flow") -- Important!

local scrollcontainer = UI:Create("SimpleGroup") -- "InlineGroup" is also good
scrollcontainer:SetFullWidth(true)
-- scrollcontainer:SetFullHeight(true) -- Probably?
-- scrollcontainer:SetWidth(remoteFrame.Width )
scrollcontainer:SetHeight(remoteFrame.Height - 320)
scrollcontainer:SetLayout("Fill") -- Important!

local contentcontainer = UI:Create("ScrollFrame")
scrollcontainer:AddChild(contentcontainer)
layoutcontainer:AddChild(scrollcontainer)
remoteFrame:AddChild(layoutcontainer)

-- One column model for the header row AND every data row. They used to
-- disagree twice over: the headings were sized 0.25/0.75 of two DIFFERENT
-- bases ((columnWidth - 25) and (columnWidth - 45)) while the cells below used
-- columnWidth - 70, so no column sat under its heading; and neither total left
-- room for the Flow layout's own 10px gap between every child plus 6px of
-- padding each side, so both rows overflowed and wrapped.
local COLUMN_GAP = 8
local ACTION_ICON_SIZE = 20
-- Flow wraps a child when x + width > contentWidth, so a row that adds up to
-- EXACTLY its container is decided by float rounding. Keep a few pixels back.
local ROW_SLACK = 6

local function remoteColumnWidths(rowWidth)
    local usable = rowWidth - ACTION_ICON_SIZE - (COLUMN_GAP * 2) - ROW_SLACK
    if usable < 160 then
        usable = 160
    end
    local nameWidth = math.floor(usable * 0.3)
    return nameWidth, math.floor(usable - nameWidth)
end

-- Flow's defaults (10px between children, 6px each side) are tuned for forms,
-- not tables: they add width no column model can predict. Zero the padding and
-- own the gap so a row is exactly its own columns. No explicit height -- a
-- SimpleGroup without one auto-sizes, which lets long help text wrap and the
-- row grow with it instead of being clipped.
local function newRemoteRow(rowWidth)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetWidth(rowWidth)
    if row.SetFlowGap then
        row:SetFlowGap(COLUMN_GAP)
    end
    if row.SetFlowPadding then
        row:SetFlowPadding(0, 0, 0, 0)
    end
    return row
end

local function addKeyPairRow(container, rowWidth, SequenceName, Help, ClassID)
    local nameWidth, helpWidth = remoteColumnWidths(rowWidth)
    local linegroup1 = newRemoteRow(rowWidth)

    local keyEditBox = UI:Create("Label")
    keyEditBox:SetText(SequenceName)
    keyEditBox:SetWidth(nameWidth)

    linegroup1:AddChild(keyEditBox)

    local helpLabel = UI:Create("Label")
    helpLabel:SetText(Help)
    helpLabel:SetWidth(helpWidth)
    linegroup1:AddChild(helpLabel)

    local testRowButton = UI:Create("Icon")
    testRowButton:SetImageSize(ACTION_ICON_SIZE, ACTION_ICON_SIZE)
    testRowButton:SetWidth(ACTION_ICON_SIZE)
    testRowButton:SetHeight(ACTION_ICON_SIZE)
    testRowButton:SetImage("Interface\\Icons\\inv_misc_punchcards_blue")
    -- Pinned to the row's right edge. layoutFlow exempts right-aligned children
    -- from the wrap test entirely, so however the columns round, the request
    -- button cannot be pushed onto a second line.
    if testRowButton.SetFlowRightAlign then
        testRowButton:SetFlowRightAlign(true)
    end

    testRowButton:SetCallback(
        "OnClick",
        function()
            GSE.RequestSequence(ClassID, SequenceName, remoteFrame.GSEUser, remoteFrame.Channel)
        end
    )
    testRowButton:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Request Sequence"],
                L["Request that the user sends you a copy of this sequence."],
                remoteFrame
            )
        end
    )
    testRowButton:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(remoteFrame)
        end
    )
    linegroup1:AddChild(testRowButton)

    -- local deleteRowButton = UI:Create("Icon")
    -- deleteRowButton:SetImageSize(20, 20)
    -- deleteRowButton:SetWidth(20)
    -- deleteRowButton:SetHeight(20)
    -- deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")

    -- deleteRowButton:SetCallback("OnClick", function()
    --     editframe.Sequence.Variables[keyEditBox:GetText()] = nil
    --     linegroup1:ReleaseChildren()
    -- end)
    -- deleteRowButton:SetCallback('OnEnter', function()
    --     GSE.CreateToolTip(L["Delete Variable"], L["Delete this variable from the sequence."], editframe)
    -- end)
    -- deleteRowButton:SetCallback('OnLeave', function()
    --     GSE.ClearTooltip(editframe)
    -- end)
    -- linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
end

function GSE.ShowRemoteWindow(SequenceList, GSEUser, channel)
    -- Start from empty. Only OnClose cleared the list, so a second
    -- ShowRemoteWindow while the window was already open -- another player's
    -- sequences arriving, or the same player re-sending -- appended a whole
    -- second copy underneath the first.
    contentcontainer:ReleaseChildren()

    local columnWidth = remoteFrame.Width - 55
    local nameWidth, helpWidth = remoteColumnWidths(columnWidth)

    -- Two headings, not three: the request button is self-explanatory and an
    -- "Actions" title over a single icon earns nothing.
    local classlinegroup = newRemoteRow(columnWidth)

    local nameLabel = UI:Create("Heading")
    nameLabel:SetText(L["Name"])
    nameLabel:SetWidth(nameWidth)
    classlinegroup:AddChild(nameLabel)

    local valueLabel = UI:Create("Heading")
    valueLabel:SetText(L["Help Information"])
    valueLabel:SetWidth(helpWidth)
    classlinegroup:AddChild(valueLabel)

    contentcontainer:AddChild(classlinegroup)

    remoteFrame.SequenceList = SequenceList
    remoteFrame.GSEUser = GSEUser
    remoteFrame.Channel = channel
    for ClassID, v in ipairs(remoteFrame.SequenceList) do
        local lClassID = tonumber(ClassID)
        local linegroup1 = newRemoteRow(columnWidth)
        if lClassID > 0 then
            local classbutton = UI:Create("Icon")
            classbutton:SetImageSize(ACTION_ICON_SIZE, ACTION_ICON_SIZE)
            classbutton:SetWidth(ACTION_ICON_SIZE)
            classbutton:SetHeight(ACTION_ICON_SIZE)
            classbutton:SetImage(GSE.GetClassIcon(lClassID))
            linegroup1:AddChild(classbutton)
        end
        local classLabel = UI:Create("Label")
        classLabel:SetText(Statics.SpecIDList[lClassID])
        linegroup1:AddChild(classLabel)
        contentcontainer:AddChild(linegroup1)
        -- Sorted, not pairs(): hash order meant the same player's sequence
        -- list came back in a different order every time it was opened.
        local names = {}
        for name in pairs(v) do
            names[#names + 1] = name
        end
        table.sort(
            names,
            function(a, b)
                return tostring(a) < tostring(b)
            end
        )
        for _, name in ipairs(names) do
            local value = v[name]
            local desc = value.Help

            if GSE.isEmpty(value.Help) then
                desc = L["No Help Information "]
            end

            addKeyPairRow(contentcontainer, columnWidth, name, desc, lClassID)
        end
    end
    remoteFrame:SetTitle(string.format(L["GSE - %s's Sequences"], remoteFrame.GSEUser))

    remoteFrame:Show()
end

remoteFrame:SetCallback(
    "OnClose",
    function(self)
        GSE.ClearTooltip(remoteFrame)
        contentcontainer:ReleaseChildren()
        remoteFrame:Hide()
    end
)

if remoteFrame and remoteFrame.frame and GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(remoteFrame.frame)
end
end
table.insert(ns.deferred, setup)
