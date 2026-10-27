local _, GSE = ...

local L = GSE.L

local frameTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
local whatsnewframe = CreateFrame("Frame", "GSEWhatsNewFrame", UIParent, frameTemplate)

whatsnewframe:SetSize(700, 500)
whatsnewframe:Hide()

-- Set up here, as GSE.UI.MakePopup would: GSE_GUI loads on demand, so at
-- login MakePopup isn't there and a window left to it had no anchor and never
-- showed.
whatsnewframe:SetFrameStrata("TOOLTIP")
whatsnewframe:SetToplevel(true)
whatsnewframe:SetClampedToScreen(true)
whatsnewframe:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
whatsnewframe:SetMovable(true)
whatsnewframe:EnableMouse(true)
whatsnewframe:RegisterForDrag("LeftButton")
whatsnewframe:SetScript("OnDragStart", function(self) self:StartMoving() end)
whatsnewframe:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

if whatsnewframe.SetBackdrop then
    whatsnewframe:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 11, right = 12, top = 12, bottom = 11}
        }
    )
end

local title = whatsnewframe:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -18)
title:SetText(L["GSE: Whats New in "] .. (C_AddOns.GetAddOnMetadata("GSE", "Version") or GSE.VersionString or ""))

local status = whatsnewframe:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
status:SetPoint("BOTTOMLEFT", 20, 16)
status:SetPoint("BOTTOMRIGHT", -20, 16)
status:SetJustifyH("LEFT")
status:SetText(L["Changes Left Side, Changes Right Side, Many Changes!!!! Handle It!"])

local closeButton = CreateFrame("Button", nil, whatsnewframe, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

local scroll = CreateFrame("ScrollFrame", "GSEWhatsNewScrollFrame", whatsnewframe, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 24, -52)
scroll:SetPoint("BOTTOMRIGHT", -36, 48)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(620, 1)
scroll:SetScrollChild(content)

local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
label:SetPoint("TOPLEFT", 0, 0)
label:SetJustifyH("LEFT")
label:SetJustifyV("TOP")
label:SetWidth(620)

local shownew = CreateFrame("CheckButton", "GSEWhatsNewShowNextLogin", content, "UICheckButtonTemplate")
shownew:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -4, -12)
GSEWhatsNewShowNextLoginText:SetText(L["Show next time you login."])
shownew:SetScript(
    "OnClick",
    function(self)
        GSEOptions.shownew = self:GetChecked()
    end
)

function GSE.ShowUpdateNotes()
    label:SetText(L["WhatsNew"] .. "\n\n")
    label:SetHeight(label:GetStringHeight())
    shownew:SetChecked(GSEOptions.shownew)
    shownew:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -4, -12)
    content:SetHeight(label:GetStringHeight() + shownew:GetHeight() + 24)
    whatsnewframe:Show()
end
