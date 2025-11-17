local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

local startY = -30
local spacing = -29

local SequenceIcons = {}


local function showSequenceIcon(event, payload)

    --frame:Show()
    local sequence = payload[1]
    local spellinfo = payload[2]
    
    DevTools_Dump(spellinfo.iconID)
    if not SequenceIcons[sequence] then
        SequenceIcons[sequence] = UIParent:CreateTexture()
        SequenceIcons[sequence]:SetPoint("CENTER")
        SequenceIcons[sequence]:SetSize(64, 64)
        SequenceIcons[sequence]:SetTexture(spellinfo.iconID)
        DevTools_Dump(SequenceIcons[sequence]:GetTexture())
    else
        SequenceIcons[sequence]:SetTexture(spellinfo.iconID)
        DevTools_Dump(SequenceIcons[sequence]:GetTexture())
    end

    
end

GSE:RegisterMessage(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, showSequenceIcon)