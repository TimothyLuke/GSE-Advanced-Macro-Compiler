local _, ns = ...
ns.deferred = ns.deferred or {}

-- =========================================================================
-- GSE front-end appearance helpers.
--
-- These used to live in GSE/API/InitialOptions.lua (core GSE), but the macro
-- engine never calls any of them -- every consumer is a front-end addon
-- (GSE_GUI, GSE_Options, and GSE_Utils/Tracker). They are gathered here in
-- GSE_Utils because that is the lowest shared front-end dependency:
-- GSE_Options -> GSE_Utils and GSE_GUI -> GSE + GSE_Utils, so every caller can
-- reach them, whereas GSE_GUI is LoadOnDemand and may never load.
--
-- Two concerns live together here:
--   1. Skin selection -- which interface skin GSE should paint (Native, the
--      built-in Modern dark skin, or an installed UI addon's skin: ElvUI /
--      EllesmereUI). See GSE.GetEffectiveSkinMode below for the resolution.
--   2. UI scaling + frame positioning -- the per-window / menu scale sliders
--      and the absolute-pixel reposition math the editor, debugger and
--      tracker windows use.
-- =========================================================================

local function setup()
local GSE = ns.GSE

-- ─── Skin selection ────────────────────────────────────────────────────
--
-- GSEOptions.SkinMode is a tri-state string: "NATIVE", "MODERN", "ADDON".
-- Unset (nil) means AUTO -- the default -- which resolves to the installed
-- UI addon's skin when one is present, otherwise Native. An explicit value
-- is always obeyed (so picking Native gives a true native look even with
-- ElvUI installed). Modern is never an auto value; it only applies when the
-- user explicitly selects it.
--
-- The saved-variable default + migration from the old boolean
-- GSEOptions.UseModernSkin lives in GSE/API/InitialOptions.lua (core owns
-- GSEOptions normalisation). This file only reads the resolved value.

local MODERN_CUSTOM_COLOR_DEFAULT = {r = 0.00, g = 0.44, b = 0.87}

-- Local copy of core's clamp (GSE/API/InitialOptions.lua) so GetModernCustomColor
-- does not have to widen core's public surface for one small helper.
local function ClampColorComponent(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback or 1 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Returns the name of the installed external skin provider as GSE labels it
--- ("ElvUI" or "EllesmereUI"), or nil when neither is present. ElvUI takes
--- priority, mirroring GSE_GUI/Skin.lua's provider selection. Used both to
--- resolve the AUTO default and to label / show the addon entry in the Skin
--- dropdown (GSE_Options).
function GSE.GetInstalledSkinProviderName()
    if type(_G.ElvUI) == "table" and type(_G.ElvUI[1]) == "table" then
        return "ElvUI"
    end
    if GSE.IsEllesmereUILoaded and GSE.IsEllesmereUILoaded() then
        return "EllesmereUI"
    end
    return nil
end

--- Resolves GSEOptions.SkinMode to one of "NATIVE" / "MODERN" / "ADDON".
--- An explicit stored value is returned verbatim; nil (AUTO) becomes "ADDON"
--- when a provider is installed, else "NATIVE".
function GSE.GetEffectiveSkinMode()
    local mode = GSEOptions and GSEOptions.SkinMode
    if mode == "NATIVE" or mode == "MODERN" or mode == "ADDON" then
        return mode
    end
    return GSE.GetInstalledSkinProviderName() and "ADDON" or "NATIVE"
end

--- True only when the user has explicitly chosen the Modern skin. Modern is
--- never the auto default, so this is simply SkinMode == "MODERN". Provider
--- gating in GSE_GUI/Skin.lua guarantees no external provider is active in
--- this case, so the Modern painters in GSE_GUI/NativeUI.lua run.
function GSE.ShouldUseModernSkin()
    return GSEOptions and GSEOptions.SkinMode == "MODERN"
end

function GSE.ShouldUseModernClassColors()
    return GSEOptions and GSEOptions.UseModernClassColors == true and GSEOptions.UseModernCustomColor ~= true
end

function GSE.ShouldUseModernCustomColor()
    return GSEOptions and GSEOptions.UseModernCustomColor == true
end

function GSE.GetModernCustomColor(alpha)
    local color = GSEOptions and GSEOptions.ModernCustomColor or MODERN_CUSTOM_COLOR_DEFAULT
    local r = ClampColorComponent(color.r or color[1], MODERN_CUSTOM_COLOR_DEFAULT.r)
    local g = ClampColorComponent(color.g or color[2], MODERN_CUSTOM_COLOR_DEFAULT.g)
    local b = ClampColorComponent(color.b or color[3], MODERN_CUSTOM_COLOR_DEFAULT.b)
    local a = alpha or ClampColorComponent(color.a or color[4], 1)
    return {r, g, b, a}
end

function GSE.SetModernCustomColor(r, g, b)
    if not GSEOptions then GSEOptions = {} end
    GSEOptions.ModernCustomColor = {
        r = ClampColorComponent(r, MODERN_CUSTOM_COLOR_DEFAULT.r),
        g = ClampColorComponent(g, MODERN_CUSTOM_COLOR_DEFAULT.g),
        b = ClampColorComponent(b, MODERN_CUSTOM_COLOR_DEFAULT.b)
    }
end

-- Backward-compatibility alias. Older GSE_GUI paths fall back to this when
-- GSE.ShouldUseModernSkin is unavailable; the modern skin is the in-house
-- successor to the old ElvUI skin, so it maps straight through.
function GSE.ShouldUseElvUISkin()
    return GSE.ShouldUseModernSkin()
end

-- ─── UI scaling + frame positioning ────────────────────────────────────

local GSE_UI_SCALE_MIN = 0.50
local GSE_UI_SCALE_MAX = 2.00
local GSE_WINDOW_SCALE_MIN = 0.75
local GSE_WINDOW_SCALE_MAX = 1.50
local GSE_UI_SCALE_DEFAULT = 1.00
local GSE_UI_SCALE_ROUNDING = 100
local GSE_UI_SCREEN_BUFFER = 4

local function ClampUIScale(value)
    value = tonumber(value) or GSE_UI_SCALE_DEFAULT
    if value < GSE_UI_SCALE_MIN then value = GSE_UI_SCALE_MIN end
    if value > GSE_UI_SCALE_MAX then value = GSE_UI_SCALE_MAX end
    return math.floor((value * GSE_UI_SCALE_ROUNDING) + 0.5) / GSE_UI_SCALE_ROUNDING
end

local function ClampWindowScale(value)
    value = tonumber(value) or GSE_UI_SCALE_DEFAULT
    if value < GSE_WINDOW_SCALE_MIN then value = GSE_WINDOW_SCALE_MIN end
    if value > GSE_WINDOW_SCALE_MAX then value = GSE_WINDOW_SCALE_MAX end
    return math.floor((value * GSE_UI_SCALE_ROUNDING) + 0.5) / GSE_UI_SCALE_ROUNDING
end

local function GetUIParentRect()
    if not UIParent then return 0, 0, 0, 0 end

    local parentLeft, parentBottom, parentWidth, parentHeight = UIParent:GetRect()
    if parentLeft and parentBottom and parentWidth and parentHeight then
        return parentLeft, parentBottom, parentWidth, parentHeight
    end

    return 0, 0, UIParent.GetWidth and UIParent:GetWidth() or 0, UIParent.GetHeight and UIParent:GetHeight() or 0
end

local function GetFrameScreenPoint(frame, point)
    if not (frame and frame.GetRect) then return nil end

    local left, bottom, width, height = frame:GetRect()
    if not (left and bottom and width and height) then return nil end

    point = point or "CENTER"
    if point == "TOPLEFT" then return left, bottom + height end
    if point == "TOPRIGHT" then return left + width, bottom + height end
    if point == "BOTTOMLEFT" then return left, bottom end
    if point == "BOTTOMRIGHT" then return left + width, bottom end
    if point == "TOP" then return left + (width / 2), bottom + height end
    if point == "BOTTOM" then return left + (width / 2), bottom end
    if point == "LEFT" then return left, bottom + (height / 2) end
    if point == "RIGHT" then return left + width, bottom + (height / 2) end
    return left + (width / 2), bottom + (height / 2)
end

function GSE.SetFrameScreenPoint(frame, point, screenX, screenY)
    if not (frame and frame.SetPoint and frame.ClearAllPoints and UIParent and screenX and screenY) then return end

    point = point or "CENTER"
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or parentScale
    local scaleRatio = parentScale > 0 and frameScale / parentScale or 1
    if not scaleRatio or scaleRatio <= 0 then scaleRatio = 1 end

    local offsetX, offsetY = screenX, screenY
    for _ = 1, 4 do
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, "BOTTOMLEFT", offsetX, offsetY)

        local actualX, actualY = GetFrameScreenPoint(frame, point)
        if not actualX or not actualY then return end

        local dx, dy = screenX - actualX, screenY - actualY
        if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end

        offsetX = offsetX + (dx / scaleRatio)
        offsetY = offsetY + (dy / scaleRatio)
    end
end

function GSE.GetUIScale()
    return ClampWindowScale(GSE_C and GSE_C.UIScale)
end

function GSE.SetUIScale(value)
    if not GSE_C then GSE_C = {} end
    GSE_C.UIScale = ClampWindowScale(value)
    if GSE.ApplyUIScale then GSE.ApplyUIScale() end
end

function GSE.GetMenuUIScale()
    if not GSE_C then return GSE_UI_SCALE_DEFAULT end
    if GSE_C.MenuUIScale == nil then
        GSE_C.MenuUIScale = ClampUIScale(GSE_C.UIScale)
    end
    return ClampUIScale(GSE_C.MenuUIScale)
end

function GSE.SetMenuUIScale(value)
    if not GSE_C then GSE_C = {} end
    if GSE_C.MenuUIScale == nil then
        GSE_C.MenuUIScale = ClampUIScale(GSE_C.UIScale)
    end
    GSE_C.MenuUIScale = ClampUIScale(value)
    if GSE.ApplyMenuUIScale then GSE.ApplyMenuUIScale() end
end

GSE.UIScaleFrames = GSE.UIScaleFrames or setmetatable({}, {__mode = "k"})
GSE.MenuUIScaleFrames = GSE.MenuUIScaleFrames or setmetatable({}, {__mode = "k"})

function GSE.ClampFrameToScreen(frame)
    if not (frame and frame.GetRect and frame.SetPoint and frame.ClearAllPoints and UIParent) then return end

    local parentLeft, parentBottom, parentWidth, parentHeight = GetUIParentRect()

    local left, bottom, width, height = frame:GetRect()
    if not (left and bottom and width and height and parentWidth > 0 and parentHeight > 0) then return end

    local minLeft = parentLeft + GSE_UI_SCREEN_BUFFER
    local minBottom = parentBottom + GSE_UI_SCREEN_BUFFER
    local maxLeft = parentLeft + parentWidth - width - GSE_UI_SCREEN_BUFFER
    local maxBottom = parentBottom + parentHeight - height - GSE_UI_SCREEN_BUFFER
    local clampedLeft = width > (parentWidth - (GSE_UI_SCREEN_BUFFER * 2)) and
        (parentLeft + ((parentWidth - width) / 2)) or
        math.min(math.max(left, minLeft), maxLeft)
    local clampedBottom = height > (parentHeight - (GSE_UI_SCREEN_BUFFER * 2)) and
        (parentBottom + ((parentHeight - height) / 2)) or
        math.min(math.max(bottom, minBottom), maxBottom)

    if math.abs(clampedLeft - left) < 0.5 and math.abs(clampedBottom - bottom) < 0.5 then return end

    GSE.SetFrameScreenPoint(frame, "BOTTOMLEFT", clampedLeft, clampedBottom)
end

function GSE.ApplyScaleToFrame(frame, scale)
    if not (frame and frame.SetScale) then return end

    scale = ClampUIScale(scale or GSE.GetUIScale())
    local preserveCenter = frame.IsShown and frame:IsShown() and frame.GetCenter and frame.ClearAllPoints and frame.SetPoint
        and not frame.GSESkipScaleRecenter
    local centerX, centerY
    if preserveCenter then
        centerX, centerY = frame:GetCenter()
        preserveCenter = centerX and centerY and UIParent
    end

    frame:SetScale(scale)

    if preserveCenter then
        GSE.SetFrameScreenPoint(frame, "CENTER", centerX, centerY)
        GSE.ClampFrameToScreen(frame)
    end
end

function GSE.ApplyMenuScaleToFrame(frame)
    if not (frame and frame.SetScale) then return end
    GSE.ApplyScaleToFrame(frame, GSE.GetMenuUIScale())
end

function GSE.RegisterUIScaleFrame(frame)
    if not frame then return end
    GSE.UIScaleFrames = GSE.UIScaleFrames or setmetatable({}, {__mode = "k"})
    GSE.UIScaleFrames[frame] = true
    GSE.ApplyScaleToFrame(frame)
end

function GSE.RegisterMenuUIScaleFrame(frame)
    if not frame then return end
    GSE.MenuUIScaleFrames = GSE.MenuUIScaleFrames or setmetatable({}, {__mode = "k"})
    GSE.MenuUIScaleFrames[frame] = true
    GSE.ApplyMenuScaleToFrame(frame)
end

function GSE.ApplyUIScale()
    if GSE.UIScaleFrames then
        for frame in pairs(GSE.UIScaleFrames) do
            if frame and frame.SetScale then
                GSE.ApplyScaleToFrame(frame)
            else
                GSE.UIScaleFrames[frame] = nil
            end
        end
    end
end

function GSE.ApplyMenuUIScale()
    if GSE.MenuUIScaleFrames then
        for frame in pairs(GSE.MenuUIScaleFrames) do
            if frame and frame.SetScale then
                GSE.ApplyMenuScaleToFrame(frame)
            else
                GSE.MenuUIScaleFrames[frame] = nil
            end
        end
    end
    if GSE.MenuFrame then
        GSE.ApplyMenuScaleToFrame(GSE.MenuFrame)
    end
end

end
table.insert(ns.deferred, setup)
