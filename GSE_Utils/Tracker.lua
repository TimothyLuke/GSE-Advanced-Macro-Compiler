local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

local SequenceIcons = {}

GSE.SequenceIconFrame = CreateFrame("Frame", "GSEIconFrame", UIParent, "BackdropTemplate")

if GSE.isEmpty(GSEOptions.SequenceIconFrame) then
    GSEOptions.SequenceIconFrame = {
        Enabled = false,
        IconSize = 64,
        Orientation = "HORIZONTAL",
        ShowIconModifiers = true,
        ShowSequenceName = true
    }
end

local SequenceIconFrame = GSE.SequenceIconFrame
local SequenceIconFrameHeight = GSEOptions.SequenceIconFrame.IconSize
local SequenceIconFrameWidth = GSEOptions.SequenceIconFrame.IconSize

local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameTooltipText")

if not GSEOptions.SequenceIconFrame.Enabled then
    SequenceIconFrame:Hide()
end
SequenceIconFrame:SetSize(SequenceIconFrameWidth, SequenceIconFrameHeight)

SequenceIconFrame:SetPoint("CENTER")
SequenceIconFrame:SetMovable(true)
SequenceIconFrame:EnableMouse(true)
SequenceIconFrame:RegisterForDrag("LeftButton")
SequenceIconFrame:SetScript("OnDragStart", function(self, button)
	self:StartMoving()
end)
SequenceIconFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
end)
SequenceIconFrame:SetClampedToScreen(true)


local function showSequenceIcon(event, payload)

    local sequence = payload[1]
    local spellinfo = payload[2]

    if not SequenceIcons[sequence] then
        SequenceIcons[sequence] = SequenceIconFrame:CreateTexture()
        SequenceIcons[sequence]:SetSize(GSEOptions.SequenceIconFrame.IconSize, GSEOptions.SequenceIconFrame.IconSize)
        SequenceIcons[sequence]:SetTexture(spellinfo.iconID)
        if GSEOptions.SequenceIconFrame.Orientation == "HORIZONTAL" then
            SequenceIconFrameWidth = GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
            SequenceIconFrame:SetSize(SequenceIconFrameWidth, GSEOptions.SequenceIconFrame.IconSize)
            SequenceIcons[sequence]:SetPoint("LEFT", SequenceIconFrame, nil, SequenceIconFrameWidth, 0)
        else
            SequenceIconFrameHeight = GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1)
            SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize, SequenceIconFrameHeight)
            SequenceIcons[sequence]:SetPoint("LEFT", SequenceIconFrame, nil, 0, SequenceIconFrameHeight)
        end
    else
        SequenceIcons[sequence]:SetTexture(spellinfo.iconID)
    end
    if spellinfo.iconID == Statics.Icons.GSE_Logo_Dark then
        if GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.ShowSequenceName then
            fs:SetText(sequence)
        else
            fs:SetText("")
        end
    end
end

local function showModKeys(event, payload)
    if GSEOptions.SequenceIconFrame.Enabled then
        local sequence = payload[1]
        local mods = payload[2]

        if GSEOptions.SequenceIconFrame.Orientation == "HORIZONTAL" then
            fs:SetPoint("TOPLEFT", SequenceIconFrame, 0, -SequenceIconFrameHeight - 10)
        else
            fs:SetPoint("TOPLEFT", SequenceIconFrame, SequenceIconFrameWidth + 10, 0)
        end
        local outputstring = sequence
        if GSEOptions.SequenceIconFrame.ShowIconModifiers then
            outputstring = outputstring .. "\n" .. mods.MOUSEBUTTON .. "\n"
            if mods.LALT then
                outputstring = outputstring .. L["Left Alt Key"] .. " "
            end
            if mods.RALT then
                outputstring = outputstring .. L["Right Alt Key"] .. " "
            end
            if mods.AALT then
                outputstring = outputstring .. L["Any Alt Key"] .. "\n"
            end
            if mods.LSHIFT then
                outputstring = outputstring .. L["Left Shift Key"] .. " "
            end
            if mods.RSHIFT then
                outputstring = outputstring .. L["Right Shift Key"] .. " "
            end
            if mods.ASHIFT then
                outputstring = outputstring .. L["Any Shift Key"] .. "\n"
            end
            if mods.LCTRL then
                outputstring = outputstring .. L["Left Control Key"] .. " "
            end
            if mods.RCTRL then
                outputstring = outputstring .. L["Right Control Key"] .. " "
            end
            if mods.ACTRL then
                outputstring = outputstring .. L["Any Control Key"]
            end
        end
        fs:SetText(outputstring)
    end
end

function GSE.IconFrameResize(newSize)
    if GSEOptions.SequenceIconFrame.Orientation == "HORIZONTAL" then
        SequenceIconFrameWidth = GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
        SequenceIconFrame:SetSize(SequenceIconFrameWidth, GSEOptions.SequenceIconFrame.IconSize)
        for _, v in pairs(SequenceIcons) do
            v:SetPoint("LEFT", SequenceIconFrame, nil, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1), 0)
        end
    else
        SequenceIconFrameHeight = GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
        SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize, SequenceIconFrameHeight)
        for _, v in pairs(SequenceIcons) do
            v:SetPoint("LEFT", SequenceIconFrame, nil, 0, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
        end
    end
    if GSEOptions.SequenceIconFrame.Orientation == "HORIZONTAL" then
        fs:SetPoint("TOPLEFT", SequenceIconFrame, 0, -SequenceIconFrameHeight - 10)
    else
        fs:SetPoint("TOPLEFT", SequenceIconFrame, SequenceIconFrameWidth + 10, 0)
    end
end
GSE:RegisterMessage(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, showSequenceIcon)
GSE:RegisterMessage(Statics.Messages.GSE_MODS_VISIBLE, showModKeys)