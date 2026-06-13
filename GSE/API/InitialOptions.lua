local _, GSE = ...
local Statics = GSE.Static
if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("End Patrons") end
-- These are overridden when the saved variables are loaded in

local MODERN_CUSTOM_COLOR_DEFAULT = {r = 0.00, g = 0.44, b = 0.87}

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
    GSEOptions.SyncWoWMacros = false
    -- Skin selection: GSEOptions.SkinMode ("NATIVE"/"MODERN"/"ADDON"); the
    -- default is AUTO, represented by leaving it unset (nil). See the migration
    -- below and GSE_Utils/Appearance.lua:GSE.GetEffectiveSkinMode.
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

-- Developer Debug is a developer-only facility. Its toggles (Enable Mod Debug
-- Mode, the chat/store debug-output options and per-module debug) live in a
-- Settings subcategory that is only built when GSE.Developer is set -- and that
-- flag is set ONLY by the version-string check in Init.lua (unpackaged dev
-- checkout). A normal user therefore has no UI to turn any of these on, so a
-- persisted debug flag can only be a leftover from a prior developer/Patron
-- build. Left alone it spams heavy logging and nags the GameMenu "Developer
-- Debug settings are active" warning. Force the whole set off on every load
-- unless this build is genuinely a developer build.
if not GSE.Developer then
    GSEOptions.debug = false
    GSEOptions.sendDebugOutputToChatWindow = false
    GSEOptions.sendDebugOutputToDebugOutput = false
    if type(GSEOptions.DebugModules) == "table" then
        for moduleName in pairs(GSEOptions.DebugModules) do
            GSEOptions.DebugModules[moduleName] = false
        end
    end
end

-- Skin selection migration. The old boolean GSEOptions.UseModernSkin (and the
-- even older GSEOptions.UseElvUISkin before it) is superseded by the tri-state
-- GSEOptions.SkinMode ("NATIVE" / "MODERN" / "ADDON"; nil = AUTO = installed UI
-- addon skin if present, else native). Resolution lives in
-- GSE_Utils/Appearance.lua:GSE.GetEffectiveSkinMode.
if GSEOptions.SkinMode == nil then
    if GSEOptions.UseModernSkin == true then
        -- Preserve users who had explicitly enabled the Modern skin.
        GSEOptions.SkinMode = "MODERN"
    end
    -- UseModernSkin false/nil (and the legacy UseElvUISkin path) leaves SkinMode
    -- nil = AUTO, which keeps "installed provider wins if present" behaviour.
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

-- NOTE: The skin accessors (GSE.ShouldUseModernSkin / ShouldUseModernClassColors
-- / ShouldUseModernCustomColor / GetModernCustomColor / SetModernCustomColor /
-- ShouldUseElvUISkin) and the entire UI-scale + frame-positioning subsystem
-- (GSE.GetUIScale / SetUIScale / GetMenuUIScale / SetMenuUIScale /
-- ApplyScaleToFrame / ApplyMenuScaleToFrame / RegisterUIScaleFrame /
-- RegisterMenuUIScaleFrame / ApplyUIScale / ApplyMenuUIScale /
-- SetFrameScreenPoint / ClampFrameToScreen) used to live here. They are
-- front-end only -- the macro engine never calls them -- so they now live in
-- GSE_Utils/Appearance.lua, the lowest shared front-end addon. Core retains only
-- the saved-variable defaults + migration above.

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
