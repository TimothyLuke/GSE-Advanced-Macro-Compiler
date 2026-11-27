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
-- Zoom and drag (Larry, 2026-11-24: "when the user mouses over it when its
-- small they can zoom in on the image parts and move it around as needed"):
-- the wheel over the picture zooms about the point under the cursor, and the
-- left button drags it while zoomed. Zoomed in, the picture spreads across
-- the page's room before it is cut, so a wide page has no black sides
-- (Larry, 2026-11-24: "the black sides should go way when small"). Zoomed,
-- it is drawn from the larger file, as far in as one of that file's pixels
-- to a screen pixel.
local KEYBIND_GUIDE_ZOOM_STEP = 1.25   -- each turn of the wheel
-- zoom: the page's units to one of the file's pixels, nil for the whole
-- picture fitted (fitSide square, fitZoom). view: the part of the picture
-- that shows, in the file's pixels. room: what the page has for it.
local zoom, fitZoom, mostZoom, fitSide = nil, 1, 1, 1
local view = { left = 0, top = 0, width = KEYBIND_GUIDE_PIXELS, height = KEYBIND_GUIDE_PIXELS }
local roomWidth, roomHeight, pictureFile, dragFrom = 1, 1, nil, nil

local function keybindLineBox(step)
    local list = KEYBIND_GUIDE_LINES
    return list.left, list.top + (step - 1) * list.height, list.right, list.top + step * list.height
end

-- Put a region over a box of the picture, at the size the picture is shown,
-- cut to the part of the picture that shows. The box is in the picture's
-- pixels. Returns the part of it that shows, or hides the region and returns
-- nil when none does.
local function placeOnPicture(region, left, top, right, bottom)
    left, top = math.max(left, view.left), math.max(top, view.top)
    right, bottom = math.min(right, view.left + view.width), math.min(bottom, view.top + view.height)
    if right <= left or bottom <= top then
        region:Hide()
        return nil
    end
    local scale = picture:GetWidth() / view.width
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", picture, "TOPLEFT", (left - view.left) * scale, -(top - view.top) * scale)
    region:SetSize((right - left) * scale, (bottom - top) * scale)
    return left, top, right, bottom
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

-- Draw a box of a file over the picture, moved by dx, dy: the part of it that
-- shows.
local function lightKeybindSpot(spot, texture, pixels, left, top, right, bottom, dx, dy)
    left, top, right, bottom = placeOnPicture(spot, left + dx, top + dy, right + dx, bottom + dy)
    if not left then return end
    spot:SetTexture(texture)
    spot:SetTexCoord((left - dx) / pixels, (right - dx) / pixels, (top - dy) / pixels, (bottom - dy) / pixels)
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

-- The picture's size on the page at a zoom: the fitted square, or as much
-- of the zoomed picture as the room holds each way.
local function keybindPictureSize(z)
    if not z then return fitSide, fitSide end
    return math.min(roomWidth, KEYBIND_GUIDE_PIXELS * z), math.min(roomHeight, KEYBIND_GUIDE_PIXELS * z)
end

-- Show the part of the picture in view, and put what lies over it there too.
local function setKeybindView(z, left, top)
    z = z and math.min(mostZoom, z)
    if z and z <= fitZoom then z = nil end
    zoom = z
    local whole = KEYBIND_GUIDE_PIXELS
    local width, height = keybindPictureSize(z)
    picture:SetSize(width, height)
    if z then
        view.width, view.height = width / z, height / z
    else
        view.width, view.height = whole, whole
    end
    view.left = math.max(0, math.min(left, whole - view.width))
    view.top = math.max(0, math.min(top, whole - view.height))
    local file = z and KEYBIND_GUIDE_LARGE_TEXTURE or KEYBIND_GUIDE_TEXTURE
    if file ~= pictureFile then
        pictureFile = file
        picture:SetTexture(file)
    end
    picture:SetTexCoord(view.left / whole, (view.left + view.width) / whole,
        view.top / whole, (view.top + view.height) / whole)
    for _, zone in ipairs(zones) do
        if placeOnPicture(zone, unpack(zone.box)) then zone:Show() end
    end
    if litStep then lightKeybindStep(litStep) end
end

-- The picture's own size where it fits, else as large as the page has room
-- for.
local function fitKeybindGuide()
    local side = KEYBIND_GUIDE_PIXELS
    if GetPhysicalScreenSize then
        local _, screenHeight = GetPhysicalScreenSize()
        side = side * 768 / screenHeight / guide:GetEffectiveScale()
    end
    roomWidth = math.max(1, guide:GetWidth() - KEYBIND_GUIDE_PAD * 2)
    roomHeight = math.max(1, guide:GetHeight() - KEYBIND_GUIDE_PAD * 2)
    fitSide = math.max(1, math.min(side, roomWidth, roomHeight))
    fitZoom = fitSide / KEYBIND_GUIDE_PIXELS
    -- side is the whole picture one small-file pixel to a screen pixel; the
    -- larger file goes a quarter further.
    mostZoom = math.max(fitZoom, side / KEYBIND_GUIDE_PIXELS * KEYBIND_GUIDE_LARGE_PIXELS / KEYBIND_GUIDE_PIXELS)
    setKeybindView(zoom, view.left, view.top)
end

-- The picture's top left corner on the page, at a width: it hangs from the
-- middle of the page's top.
local function keybindPictureCorner(width)
    local left, top = guide:GetLeft(), guide:GetTop()
    if not (left and top) then return nil end
    return left + (guide:GetWidth() - width) / 2, top - KEYBIND_GUIDE_PAD
end

-- The cursor in the page's units; nil off the picture.
local function cursorOnPicture()
    local width, height = picture:GetWidth(), picture:GetHeight()
    local left, top = keybindPictureCorner(width)
    if not left then return nil end
    local x, y = GetCursorPosition()
    local scale = guide:GetEffectiveScale()
    x, y = x / scale, y / scale
    if x < left or x > left + width or y > top or y < top - height then return nil end
    return x, y
end

-- The point under the cursor stays under it, the picture's size and all.
local function zoomKeybindGuide(_, delta)
    local x, y = cursorOnPicture()
    if not x then return end
    local now = zoom or fitZoom
    local left, top = keybindPictureCorner(picture:GetWidth())
    local fileX, fileY = view.left + (x - left) / now, view.top + (top - y) / now
    local new = math.max(fitZoom, math.min(mostZoom, now * KEYBIND_GUIDE_ZOOM_STEP ^ delta))
    local newLeft = keybindPictureCorner((keybindPictureSize(new > fitZoom and new or nil)))
    setKeybindView(new, fileX - (x - newLeft) / new, fileY - (top - y) / new)
end

local function stopDraggingKeybindGuide()
    dragFrom = nil
    guide:SetScript("OnUpdate", nil)
end

local function dragKeybindGuide()
    if not (zoom and IsMouseButtonDown("LeftButton")) then return stopDraggingKeybindGuide() end
    local x, y = GetCursorPosition()
    -- Screen units to the file's pixels.
    local perUnit = 1 / zoom / guide:GetEffectiveScale()
    setKeybindView(zoom, dragFrom.left - (x - dragFrom.x) * perUnit, dragFrom.top + (y - dragFrom.y) * perUnit)
end

local function startDraggingKeybindGuide(_, button)
    if button ~= "LeftButton" or not zoom or not cursorOnPicture() then return end
    local x, y = GetCursorPosition()
    dragFrom = { x = x, y = y, left = view.left, top = view.top }
    guide:SetScript("OnUpdate", dragKeybindGuide)
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
            -- It takes the mouse, so it drags the picture too.
            zone:SetScript("OnMouseDown", startDraggingKeybindGuide)
            zone:SetScript("OnMouseUp", stopDraggingKeybindGuide)
            table.insert(zones, zone)
        end
        for step = 1, #KEYBIND_GUIDE_STEPS do addZone(step, keybindLineBox(step)) end
        for step, boxes in ipairs(KEYBIND_GUIDE_STEPS) do
            for _, box in ipairs(boxes) do addZone(step, unpack(box)) end
        end
        guide:EnableMouse(true)
        guide:EnableMouseWheel(true)
        guide:SetScript("OnMouseWheel", zoomKeybindGuide)
        guide:SetScript("OnMouseDown", startDraggingKeybindGuide)
        guide:SetScript("OnMouseUp", stopDraggingKeybindGuide)
        guide:SetScript("OnSizeChanged", fitKeybindGuide)
        -- The picture is in memory only while it shows, and it comes back
        -- whole.
        guide:SetScript("OnShow", fitKeybindGuide)
        guide:SetScript("OnHide", function()
            stopDraggingKeybindGuide()
            zoom, view.left, view.top = nil, 0, 0
            pictureFile = nil
            picture:SetTexture(nil)
            lightKeybindStep(nil)
            for _, spot in ipairs(spots) do spot:SetTexture(nil) end
        end)
    end
    guide:SetParent(parent)
    guide:ClearAllPoints()
    guide:SetAllPoints(parent)
    guide:SetFrameLevel(parent:GetFrameLevel() + 1)
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
