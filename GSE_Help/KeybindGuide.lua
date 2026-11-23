local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local Statics = GSE.Static

-- The keybind guide: one picture of the steps that put a sequence on an
-- action button and a key on it, in Blizzard's own portrait window (border,
-- title bar, close button). Built the first time it is asked for, so the
-- picture is not loaded until then; asked for again, it closes.
local KEYBIND_GUIDE_TEXTURE = "Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png"
-- The file's own pixels. It is shown one for one, never resized by the game
-- where it fits: a picture the game shrinks goes soft. To change its size,
-- resize the file and this number together.
local KEYBIND_GUIDE_PIXELS  = 800
local KEYBIND_GUIDE_PAD     = 16   -- each side of the picture
local KEYBIND_GUIDE_CHROME  = 44   -- title bar above it, border below
local keybindGuide

function GSE.ToggleKeybindGuide()
    if keybindGuide then
        keybindGuide:SetShown(not keybindGuide:IsShown())
        return
    end

    -- The picture's own size where the screen has room for it, else as tall
    -- as fits under the title bar.
    local side = KEYBIND_GUIDE_PIXELS
    if GetPhysicalScreenSize then
        local _, screenHeight = GetPhysicalScreenSize()
        side = side * 768 / screenHeight / UIParent:GetEffectiveScale()
    end
    side = math.min(side, UIParent:GetHeight() * 0.9 - KEYBIND_GUIDE_CHROME)

    keybindGuide = CreateFrame("Frame", "GSEKeybindGuideFrame", UIParent, "PortraitFrameTemplate")
    keybindGuide:SetFrameStrata("DIALOG")
    keybindGuide:SetToplevel(true)
    keybindGuide:SetSize(side + KEYBIND_GUIDE_PAD * 2, side + KEYBIND_GUIDE_CHROME)
    keybindGuide:SetPoint("CENTER")
    keybindGuide:SetClampedToScreen(true)
    keybindGuide:EnableMouse(true)
    keybindGuide:SetMovable(true)
    keybindGuide:RegisterForDrag("LeftButton")
    keybindGuide:SetScript("OnDragStart", keybindGuide.StartMoving)
    keybindGuide:SetScript("OnDragStop", keybindGuide.StopMovingOrSizing)
    -- The template's methods differ by client, so each is asked for.
    if keybindGuide.SetPortraitToAsset then keybindGuide:SetPortraitToAsset(Statics.Icons.Keybindings) end
    -- The template's round window is not the middle of the portrait, so the
    -- icon's art is moved in it, by eye (Larry, 2026-11-21, on Forever): up
    -- 4.66 and left 1.64 of the portrait's 62.
    local up, left = 4.66 / 62, 1.64 / 62
    if keybindGuide.SetPortraitTexCoord then keybindGuide:SetPortraitTexCoord(left, 1 + left, up, 1 + up) end
    if keybindGuide.SetTitleOffsets then keybindGuide:SetTitleOffsets(24, -24) end
    if keybindGuide.SetTitle then keybindGuide:SetTitle(L["Keybindings"]) end
    if keybindGuide.CloseButton then
        keybindGuide.CloseButton:SetScript("OnClick", function() keybindGuide:Hide() end)
    end

    local picture = keybindGuide:CreateTexture(nil, "ARTWORK")
    picture:SetPoint("TOP", 0, -28)
    picture:SetSize(side, side)
    picture:SetTexture(KEYBIND_GUIDE_TEXTURE)
    -- The picture is in memory only while the window is open.
    keybindGuide:SetScript("OnShow", function() picture:SetTexture(KEYBIND_GUIDE_TEXTURE) end)
    keybindGuide:SetScript("OnHide", function() picture:SetTexture(nil) end)

    -- Escape closes it.
    tinsert(UISpecialFrames, "GSEKeybindGuideFrame")
end
end
table.insert(ns.deferred, setup)
