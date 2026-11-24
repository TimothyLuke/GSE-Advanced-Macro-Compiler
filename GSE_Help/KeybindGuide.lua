local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE

-- The keybind guide: one picture of the steps that put a sequence on an
-- action button and a key on it. It is shown in the page that asks for it,
-- the Editor's Keybind tab, and made the first time it is asked for, so the
-- picture is not loaded until then.
local KEYBIND_GUIDE_TEXTURE = "Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png"
-- The file's own pixels. It is shown one for one where the page has the room:
-- a picture the game shrinks goes soft. To change its size, resize the file
-- and this number together.
local KEYBIND_GUIDE_PIXELS  = 800
local KEYBIND_GUIDE_PAD     = 8    -- around the picture
-- The same picture a quarter larger, as it was drawn. A lit step is shown
-- from it, grown by as much, so it too is one file pixel to a screen pixel.
local KEYBIND_GUIDE_LARGE_TEXTURE = "Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuideLarge.png"
local KEYBIND_GUIDE_LARGE_PIXELS  = 1000
-- Where each step is in the picture, in the file's pixels (left, top, right,
-- bottom), measured from the file. Pointing at a step's line in the picture's
-- list lights that line and these, and the rest of the picture goes dark
-- (Larry, 2026-11-23: "when I mouse over a line highlight that step"). A new
-- picture needs them measured again.
local KEYBIND_GUIDE_STEPS = {
    { { 14, 152, 285, 226 } },
    { { 312, 34, 457, 222 }, { 336, 222, 392, 240 } },
    { { 466, 34, 728, 130 } },
    { { 566, 130, 765, 222 } },
    { { 436, 218, 600, 364 } },
    { { 260, 366, 405, 452 }, { 405, 372, 562, 418 } },
    { { 402, 420, 586, 482 }, { 588, 384, 740, 430 } },
    { { 488, 604, 760, 740 } },
}
-- The list's lines: one under the other, each the same height.
local KEYBIND_GUIDE_LINES = { left = 40, right = 460, top = 542, height = 27.25 }
local KEYBIND_GUIDE_DIM   = 0.6    -- how dark the rest of the picture goes
local guide, picture, dim, litStep, pointedAt
local spots, zones = {}, {}

local function keybindLineBox(step)
    local list = KEYBIND_GUIDE_LINES
    return list.left, list.top + (step - 1) * list.height, list.right, list.top + step * list.height
end

-- Put a region over a box of the picture, at the size the picture is shown.
-- The box is in the picture's pixels.
local function placeOnPicture(region, left, top, right, bottom)
    local scale = picture:GetWidth() / KEYBIND_GUIDE_PIXELS
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", picture, "TOPLEFT", left * scale, -top * scale)
    region:SetSize((right - left) * scale, (bottom - top) * scale)
end

-- A step's boxes in the larger file's pixels, and how far to move them so the
-- step grows about its middle and stays on the picture. Whole pixels all
-- through: a box drawn part way between two pixels goes soft.
local function grownKeybindBoxes(boxes)
    local grow = KEYBIND_GUIDE_LARGE_PIXELS / KEYBIND_GUIDE_PIXELS
    local function round(value) return math.floor(value + 0.5) end
    local large = {}
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    for i, box in ipairs(boxes) do
        large[i] = { round(box[1] * grow), round(box[2] * grow), round(box[3] * grow), round(box[4] * grow) }
        left, top = math.min(left, large[i][1]), math.min(top, large[i][2])
        right, bottom = math.max(right, large[i][3]), math.max(bottom, large[i][4])
    end
    local function move(low, high)
        local about = round((low + high) / 2 * (1 / grow - 1))
        return about + math.max(0, -(low + about)) - math.max(0, high + about - KEYBIND_GUIDE_PIXELS)
    end
    return large, move(left, right), move(top, bottom)
end

-- Draw a box of a file over the picture, moved by dx, dy.
local function lightKeybindSpot(spot, texture, pixels, left, top, right, bottom, dx, dy)
    spot:SetTexture(texture)
    spot:SetTexCoord(left / pixels, right / pixels, top / pixels, bottom / pixels)
    placeOnPicture(spot, left + dx, top + dy, right + dx, bottom + dy)
    spot:Show()
end

-- Light one step, or none: the picture goes dark, the step's line is drawn
-- again over it, and so are its boxes, grown, from the larger file (Larry,
-- 2026-11-23: "can we make the area grow some and bit less fuzzy?").
local function lightKeybindStep(step)
    litStep = step
    local boxes = step and KEYBIND_GUIDE_STEPS[step]
    dim:SetShown(boxes ~= nil)
    for _, spot in ipairs(spots) do spot:Hide() end
    if not boxes then return end
    local left, top, right, bottom = keybindLineBox(step)
    lightKeybindSpot(spots[1], KEYBIND_GUIDE_TEXTURE, KEYBIND_GUIDE_PIXELS, left, top, right, bottom, 0, 0)
    local large, dx, dy = grownKeybindBoxes(boxes)
    for i, box in ipairs(large) do
        lightKeybindSpot(spots[i + 1], KEYBIND_GUIDE_LARGE_TEXTURE, KEYBIND_GUIDE_LARGE_PIXELS,
            box[1], box[2], box[3], box[4], dx, dy)
    end
end

-- The picture's own size where it fits, else as large as the page has room
-- for.
local function fitKeybindGuide()
    local side = KEYBIND_GUIDE_PIXELS
    if GetPhysicalScreenSize then
        local _, screenHeight = GetPhysicalScreenSize()
        side = side * 768 / screenHeight / guide:GetEffectiveScale()
    end
    local room = math.min(guide:GetWidth(), guide:GetHeight()) - KEYBIND_GUIDE_PAD * 2
    picture:SetSize(math.max(1, math.min(side, room)), math.max(1, math.min(side, room)))
    for _, zone in ipairs(zones) do placeOnPicture(zone, unpack(zone.box)) end
    if litStep then lightKeybindStep(litStep) end
end

-- The page's way back, in its top right corner (Larry, 2026-11-24): made the
-- first time a page asks for one, and out of sight on a page that does not.
local back, backButton
local function showBackButton(parent)
    if not back then
        if backButton then backButton:Hide() end
        return
    end
    if not backButton then
        backButton = CreateFrame("Button", nil, guide)
        backButton.icon = backButton:CreateTexture(nil, "ARTWORK")
        backButton.icon:SetAllPoints()
        backButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        backButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(back.text, 1, 1, 1)
            GameTooltip:Show()
        end)
        backButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        backButton:SetScript("OnClick", function()
            GameTooltip:Hide()
            back.click()
        end)
    end
    backButton.icon:SetTexture(back.icon)
    backButton:SetSize(back.size, back.size)
    backButton:ClearAllPoints()
    backButton:SetPoint("TOPRIGHT", guide, "TOPRIGHT", -back.right, -back.top)
    -- Over the steps' parts of the picture, where the page is narrow.
    backButton:SetFrameLevel(parent:GetFrameLevel() + 6)
    backButton:Show()
end

--- Show the guide in a frame, filling it.
--- wayBack: nil, or a button for the page's top right corner that leads back
--- from it: icon, text (its tooltip), click, size, and right and top (how far
--- in from the corner).
function GSE.ShowKeybindGuideIn(parent, wayBack)
    if not guide then
        guide = CreateFrame("Frame", nil, parent)
        -- Black where the page is larger than the picture, as the picture's
        -- own ground is (Larry, 2026-11-23).
        local ground = guide:CreateTexture(nil, "BACKGROUND")
        ground:SetAllPoints()
        ground:SetColorTexture(0, 0, 0, 1)
        picture = guide:CreateTexture(nil, "ARTWORK")
        picture:SetPoint("TOP", 0, -KEYBIND_GUIDE_PAD)
        dim = guide:CreateTexture(nil, "ARTWORK", nil, 1)
        dim:SetAllPoints(picture)
        dim:SetColorTexture(0, 0, 0, KEYBIND_GUIDE_DIM)
        dim:Hide()
        -- One for the line, and one for each box of the step with the most.
        local most = 0
        for _, boxes in ipairs(KEYBIND_GUIDE_STEPS) do most = math.max(most, #boxes) end
        for i = 1, most + 1 do
            spots[i] = guide:CreateTexture(nil, "OVERLAY")
            spots[i]:Hide()
        end
        -- A step lights from its line of the list, and from its own part of
        -- the picture (Larry, 2026-11-23: "add mouseover effect also if the
        -- user mouses over that part of the image"). That part is where the
        -- step is drawn, not where it grows to.
        local function addZone(step, left, top, right, bottom)
            local zone = CreateFrame("Frame", nil, guide)
            zone.box = { left, top, right, bottom }
            zone:EnableMouse(true)
            zone:SetScript("OnEnter", function()
                pointedAt = zone
                lightKeybindStep(step)
            end)
            -- Only its own light: the next one may have been entered first.
            zone:SetScript("OnLeave", function()
                if pointedAt ~= zone then return end
                pointedAt = nil
                lightKeybindStep(nil)
            end)
            table.insert(zones, zone)
        end
        for step = 1, #KEYBIND_GUIDE_STEPS do addZone(step, keybindLineBox(step)) end
        for step, boxes in ipairs(KEYBIND_GUIDE_STEPS) do
            for _, box in ipairs(boxes) do addZone(step, unpack(box)) end
        end
        guide:SetScript("OnSizeChanged", fitKeybindGuide)
        -- The picture is in memory only while it shows.
        guide:SetScript("OnShow", function()
            picture:SetTexture(KEYBIND_GUIDE_TEXTURE)
            fitKeybindGuide()
        end)
        guide:SetScript("OnHide", function()
            picture:SetTexture(nil)
            lightKeybindStep(nil)
            for _, spot in ipairs(spots) do spot:SetTexture(nil) end
        end)
    end
    guide:SetParent(parent)
    guide:ClearAllPoints()
    guide:SetAllPoints(parent)
    guide:SetFrameLevel(parent:GetFrameLevel() + 1)
    picture:SetTexture(KEYBIND_GUIDE_TEXTURE)
    guide:Show()
    fitKeybindGuide()
    back = wayBack
    showBackButton(parent)
end

--- Take the guide off the page it was shown in.
function GSE.HideKeybindGuide()
    if not guide then return end
    guide:Hide()
    guide:SetParent(UIParent)
    guide:ClearAllPoints()
end
end
table.insert(ns.deferred, setup)
