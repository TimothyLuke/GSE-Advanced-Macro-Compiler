local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

local SequenceIcons = {}

GSE.SequenceIconFrame = CreateFrame("Frame", "GSEIconFrame", UIParent, "BackdropTemplate")

if GSE.isEmpty(GSEOptions.SequenceIconFrame) then
    GSEOptions.SequenceIconFrame = {
        Enabled = false,
        IconSize = 64,
        Orientation = "HORIZONTAL"
    }
end

local SequenceIconFrame = GSE.SequenceIconFrame

if not GSEOptions.SequenceIconFrame.Enabled then
    SequenceIconFrame:Hide()
end
SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize, GSEOptions.SequenceIconFrame.IconSize)

SequenceIconFrame:SetPoint("CENTER")
SequenceIconFrame:SetMovable(true)
SequenceIconFrame:EnableMouse(true)
SequenceIconFrame:RegisterForDrag("LeftButton")
SequenceIconFrame:SetScript("OnDragStart", function(self, button)
	self:StartMoving()
	-- print("OnDragStart", button)
end)
SequenceIconFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	-- print("OnDragStop")
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
            SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1)), GSEOptions.SequenceIconFrame.IconSize)
            SequenceIcons[sequence]:SetPoint("LEFT", SequenceIconFrame, nil, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1), 0)
        else
            SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize, GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1)))
            SequenceIcons[sequence]:SetPoint("LEFT", SequenceIconFrame, nil, 0, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
        end
    else
        SequenceIcons[sequence]:SetTexture(spellinfo.iconID)
    end
end

local function showModKeys(event, payload)
    --DevTools_Dump(payload)
end

function GSE.IconFrameResize(newSize)
    if GSEOptions.SequenceIconFrame.Orientation == "HORIZONTAL" then
        SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1)), GSEOptions.SequenceIconFrame.IconSize)
        for _, v in pairs(SequenceIcons) do
            v:SetPoint("LEFT", SequenceIconFrame, nil, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1), 0)
        end
    else
        SequenceIconFrame:SetSize(GSEOptions.SequenceIconFrame.IconSize, GSEOptions.SequenceIconFrame.IconSize + (GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1)))
        for _, v in pairs(SequenceIcons) do
            v:SetPoint("LEFT", SequenceIconFrame, nil, 0, GSEOptions.SequenceIconFrame.IconSize*(GSE.CountTableLength(SequenceIcons) - 1))
        end
    end
end
GSE:RegisterMessage(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, showSequenceIcon)
GSE:RegisterMessage(Statics.Messages.GSE_MODS_VISIBLE, showModKeys)