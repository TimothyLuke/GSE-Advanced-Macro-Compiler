--[[-----------------------------------------------------------------------------
Spacer Widget
Just uses up a bit of horizontal space

-------------------------------------------------------------------------------]]
local Type, Version = "Spacer", 3
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
    return
end

local methods = {
    ["OnAcquire"] = function(self)
        self:SetFullWidth(true)
        self:SetHeight(3)
    end
    -- ["SetHeight"] = function(self, value)
    --     if value > 0 then
    --         self:SetHeight(value)
    --     end
    -- end
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    local widget = {
        frame = frame,
        type = Type
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
