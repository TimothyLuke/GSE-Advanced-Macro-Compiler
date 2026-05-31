local GSE = GSE
local Statics = GSE.Static
if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("End Patrons") end
-- These are overridden when the saved variables are loaded in

local MODERN_CUSTOM_COLOR_DEFAULT = {r = 0.00, g = 0.44, b = 0.87}

local function ClampColorComponent(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback or 1 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

function GSE.resetMacroResetModifiers()
    GSEOptions.MacroResetModifiers = {}
    GSEOptions.MacroResetModifiers["LeftButton"] = false
    GSEOptions.MacroResetModifiers["RightButton"] = false
    GSEOptions.MacroResetModifiers["MiddleButton"] = false
    GSEOptions.MacroResetModifiers["Button4"] = false
    GSEOptions.MacroResetModifiers["Button5"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["Alt"] = false
    GSEOptions.MacroResetModifiers["LeftControl"] = false
    GSEOptions.MacroResetModifiers["RightControl"] = false
    GSEOptions.MacroResetModifiers["Control"] = false
    GSEOptions.MacroResetModifiers["LeftShift"] = false
    GSEOptions.MacroResetModifiers["RightShift"] = false
    GSEOptions.MacroResetModifiers["Shift"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["AnyMod"] = false
end

function GSE.SetDefaultOptions()
    GSEOptions.saveAllMacrosLocal = true
    GSEOptions.initialised = true
    GSEOptions.deleteOrphansOnLogout = false
    GSEOptions.debug = false
    GSEOptions.sendDebugOutputToChat = nil
    GSEOptions.sendDebugOutputToChatWindow = false
    GSEOptions.sendDebugOutputToDebugOutput = false
    GSEOptions.setDefaultIconQuestionMark = true
    GSEOptions.TitleColour = "|cFFFF0000"
    GSEOptions.AuthorColour = "|cFF00D1FF"
    GSEOptions.CommandColour = "|cFF00FF00"
    GSEOptions.NormalColour = "|cFFFFFFFF"
    GSEOptions.EmphasisColour = "|cFFFFFF00"
    GSEOptions.KEYWORD = "|cff88bbdd"
    GSEOptions.UNKNOWN = "|cffff6666"
    GSEOptions.CONCAT = "|cffcc7777"
    GSEOptions.NUMBER = "|cffffaa00"
    GSEOptions.STRING = "|cff888888"
    GSEOptions.COMMENT = "|cff55cc55"
    GSEOptions.EQUALS = "|cffccddee"
    GSEOptions.STANDARDFUNCS = "|cff55ddcc"
    GSEOptions.WOWSHORTCUTS = "|cffddaaff"
    GSEOptions.overflowPersonalMacros = false
    -- Editor spell translation; see GSE.ShouldTranslateLive(). false (default) =
    -- translate/colour live as you type while editing; true = always defer to
    -- focus-loss, to reduce editor lag on older machines. Exposed as the "Delayed
    -- Spell Translations" checkbox under Options > Tools & Diagnostics. Read live
    -- by the editor, so no reload is needed.
    GSEOptions.DelayedSpellTranslations = false
    -- Legacy flag for the old AceGUI parser (GSE.GUIParseText); superseded by
    -- DelayedSpellTranslations above and otherwise unused.
    GSEOptions.RealtimeParse = false
    GSEOptions.ActiveSequenceVersions = {}
    GSEOptions.DisabledSequences = {}
    GSEOptions.DebugModules = {}
    GSEOptions.shownew = true
    if GSEOptions.ToolbarEnabled == nil then GSEOptions.ToolbarEnabled = true end

    GSEOptions.DebugModules[Statics.DebugModules["Translator"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Editor"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Viewer"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Storage"]] = false
    GSEOptions.DebugModules[Statics.DebugModules[Statics.SourceTransmission]] = false
    GSEOptions.DebugModules[Statics.DebugModules["API"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["GUI"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Versions"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Startup"]] = false

    GSEOptions.filterList = {}
    GSEOptions.filterList[Statics.Spec] = true
    GSEOptions.filterList[Statics.Class] = true
    GSEOptions.filterList[Statics.All] = true
    GSEOptions.filterList[Statics.Global] = true
    GSEOptions.autoCreateMacroStubsClass = true
    GSEOptions.autoCreateMacroStubsGlobal = false
    GSEOptions.resetOOC = true
    GSEOptions.DefaultDisabledMacroIcon = "Interface\\Icons\\INV_MISC_BOOK_08"
    GSEOptions.CreateGlobalButtons = false
    GSEOptions.HideLoginMessage = false
    GSEOptions.DebugPrintModConditionsOnKeyPress = false
    GSEOptions.showGSEUsers = false
    GSEOptions.showGSEoocqueue = true
    GSEOptions.UseVerboseExportFormat = false
    GSEOptions.DefaultImportAction = "MERGE"
    GSEOptions.DefaultHumanReadableExportFormat = true
    GSEOptions.PromptSample = true
    GSEOptions.msClickRate = 250
    GSEOptions.showMiniMap = {
        hide = true
    }
    GSEOptions.showCurrentSpells = true
    -- FocusHighlightTint: master toggle for the 10%-opacity rail-color fill
    -- on the currently-focused block. When false, only the proc-pulsed
    -- border lines remain; when true, the block's empty areas (outside the
    -- macro edit box, which has its own opaque backdrop) get a soft tint
    -- in the rail color. Independent from FocusHighProc / Brightness — the
    -- tint is constant, not animated.
    GSEOptions.FocusHighlightTint = true
    -- FocusHighProc: proc-style animation TYPE on the four border lines around
    -- the focused Loop/Action block in the editor. Each type bakes its own
    -- alpha range, cycle duration and smoothing curve so users can pick a
    -- distinct visual feel rather than just an intensity. Valid values:
    -- "OFF", "PULSE" (default, matches the original baseline pulse),
    -- "FLASH" (sharp fast), "THROB" (slow heavy), "BREATHE" (slow gentle),
    -- "STROBE" (very fast). Border colors are hard-coded per action type and
    -- are NOT changed by this option.
    GSEOptions.FocusHighProc = "PULSE"
    -- FocusHighProcBrightness: dimming intensity modifier applied on top of
    -- whichever proc TYPE is selected above. Shifts the low-alpha bound of
    -- the animation — LOW raises it (subtler swing), MEDIUM uses the type's
    -- baseline, HIGH lowers it (more dramatic swing). Final low alpha is
    -- clamped to [0.05, 0.95] so no combination can render the border fully
    -- invisible or freeze it solid. Valid values: "LOW", "MEDIUM" (default),
    -- "HIGH". Has no effect when FocusHighProc is "OFF".
    GSEOptions.FocusHighProcBrightness = "MEDIUM"
    GSEOptions.OOCQueueDelay = 7
    GSE.resetMacroResetModifiers()
    GSEOptions.frameLocations = {
        sequenceeditor = {height = 800, width = 800, treeWidth = 165}
    }
    GSEOptions.Multiclick = true
    GSEOptions.SyncWoWMacros = false
    GSEOptions.UseModernSkin = false
    GSEOptions.UseModernClassColors = false
    GSEOptions.UseModernCustomColor = false
    GSEOptions.ModernCustomColor = {
        r = MODERN_CUSTOM_COLOR_DEFAULT.r,
        g = MODERN_CUSTOM_COLOR_DEFAULT.g,
        b = MODERN_CUSTOM_COLOR_DEFAULT.b
    }
    -- Modifier-held "pause" toggles. When enabled, holding the matching
    -- modifier while pressing the GSE sequence button sends an empty
    -- macro and does NOT advance the step — letting the user stall the
    -- rotation without breaking it.
    GSEOptions.ShiftPause = false
    GSEOptions.AltPause = false
    GSEOptions.CtrlPause = false
end

if GSE.isEmpty(GSEOptions) then
    GSEOptions = {}
end

if not GSEOptions.DebugModules then
    GSE.SetDefaultOptions()
end

if GSEOptions.UseModernSkin == nil then
    GSEOptions.UseModernSkin = GSEOptions.UseElvUISkin == true
end

if GSEOptions.UseModernClassColors == nil then
    GSEOptions.UseModernClassColors = false
end

if GSEOptions.UseModernCustomColor == nil then
    GSEOptions.UseModernCustomColor = false
end

if GSEOptions.UseModernCustomColor == true then
    GSEOptions.UseModernClassColors = false
end

if type(GSEOptions.ModernCustomColor) ~= "table" then
    GSEOptions.ModernCustomColor = {
        r = MODERN_CUSTOM_COLOR_DEFAULT.r,
        g = MODERN_CUSTOM_COLOR_DEFAULT.g,
        b = MODERN_CUSTOM_COLOR_DEFAULT.b
    }
end

function GSE.ShouldUseModernSkin()
    return GSEOptions and GSEOptions.UseModernSkin == true
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

function GSE.ShouldUseElvUISkin()
    return GSE.ShouldUseModernSkin()
end

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

-- Migrate editor dimensions from old flat keys to frameLocations.sequenceeditor.
do
    if GSE.isEmpty(GSEOptions.frameLocations) then
        GSEOptions.frameLocations = {}
    end
    if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
        GSEOptions.frameLocations.sequenceeditor = {}
    end
    local se = GSEOptions.frameLocations.sequenceeditor
    if GSEOptions.editorHeight and GSE.isEmpty(se.height) then
        se.height = GSEOptions.editorHeight
        GSEOptions.editorHeight = nil
    end
    if GSEOptions.editorWidth and GSE.isEmpty(se.width) then
        se.width = GSEOptions.editorWidth
        GSEOptions.editorWidth = nil
    end
    if GSEOptions.editorTreeWidth and GSE.isEmpty(se.treeWidth) then
        se.treeWidth = GSEOptions.editorTreeWidth
        GSEOptions.editorTreeWidth = nil
    end
    -- Ensure defaults are always stored explicitly so the sliders always
    -- reflect a real saved value rather than a scattered fallback.
    if GSE.isEmpty(se.height)    then se.height    = 800 end
    if GSE.isEmpty(se.width)     then se.width     = 800 end
    if se.width < 800 then se.width = 800 end
    if GSE.isEmpty(se.treeWidth) then se.treeWidth = 165 end
    if se.treeWidth < 165 then se.treeWidth = 165 end
    if se.treeWidth > 300 then se.treeWidth = 300 end
end

GSE.OOCQueue = {}
GSE.UnsavedOptions = {}
GSE.UnsavedOptions["DebugSequenceExecution"] = false
GSE.TranslatorLanguageTables = {}
GSE.AdditionalLanguagesAvailable = false

local Translator = GSE.TranslatorLanguageTables

Translator[Statics.TranslationKey] = {}
Translator[Statics.TranslationHash] = {}
Translator[Statics.TranslationShadow] = {}

GSE.PrintAvailable = false
GSE.StandardAddInPacks = {}
GSE.UsedSequences = {}
GSE.SequencesExec = {}
GSE.UnsavedOptions["PartyUsers"] = {}
GSE.UnsavedOptions["GUI"] = false

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("InitialOptions") end


-- ── Debugger UI Scale ────────────────────────────────────────────────────────
local GSE_DEBUGGER_SCALE_DEFAULT = 1
local GSE_DEBUGGER_SCALE_MIN     = 0.5
local GSE_DEBUGGER_SCALE_MAX     = 2.0
local GSE_DEBUGGER_SCALE_ROUND   = 100

local function ClampDebugScale(value)
    value = tonumber(value) or GSE_DEBUGGER_SCALE_DEFAULT
    if value < GSE_DEBUGGER_SCALE_MIN then value = GSE_DEBUGGER_SCALE_MIN end
    if value > GSE_DEBUGGER_SCALE_MAX then value = GSE_DEBUGGER_SCALE_MAX end
    return math.floor((value * GSE_DEBUGGER_SCALE_ROUND) + 0.5) / GSE_DEBUGGER_SCALE_ROUND
end

function GSE.GetDebugUIScale()
    return ClampDebugScale(GSEOptions and GSEOptions.debugUIScale)
end

function GSE.SetDebugUIScale(value)
    if not GSEOptions then GSEOptions = {} end
    GSEOptions.debugUIScale = ClampDebugScale(value)
    if GSE.ApplyDebugUIScale then GSE.ApplyDebugUIScale() end
end

function GSE.ApplyDebugScaleToFrame(frame)
    if not (frame and frame.SetScale) then return end
    frame:SetScale(ClampDebugScale(GSE.GetDebugUIScale()))
end

function GSE.RegisterDebugUIScaleFrame(frame)
    if not frame then return end
    GSE.DebugUIScaleFrames = GSE.DebugUIScaleFrames or setmetatable({}, {__mode = "k"})
    GSE.DebugUIScaleFrames[frame] = true
    GSE.ApplyDebugScaleToFrame(frame)
end

function GSE.ApplyDebugUIScale()
    if GSE.DebugUIScaleFrames then
        for frame in pairs(GSE.DebugUIScaleFrames) do
            if frame and frame.SetScale then
                GSE.ApplyDebugScaleToFrame(frame)
            else
                GSE.DebugUIScaleFrames[frame] = nil
            end
        end
    end
end
