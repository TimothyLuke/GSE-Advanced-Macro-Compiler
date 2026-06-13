local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static

-- Tracker tunable constants (DefaultIconCount, KeyHistoryLimit,
local lastGSEActivitySequence = nil
local assistedHighlightIconID = nil
-- MirrorIconGap, SuccessCastWindow, DefaultGCDGraceWindow,
-- ActiveSpamKeyHoldSeconds) live on Statics.TrackerConfig -- see
-- GSE/API/Statics.lua for the values and rationale. Pulling them out
-- of this file frees 6 chunk-level local slots that were previously
-- pushing this file's local count past Lua 5.1's 200-per-function
-- limit.
local FIELD_KEYS = {"gse-button", "GSESequence", "Sequence", "name"}
local ATTR_KEYS = {"gse-button", "GSESequence", "Sequence", "name"}

-- =========================================================================
-- Default Tracker Layout Presets — Layout X (horizontal) and Layout Y (vertical)
--
-- These are the factory presets for the named tracker layout slots "X" and
-- "Y". When EnsureSequenceIconFrameOptions runs on a character that has no
-- Layouts.X (or Layouts.Y) saved yet, the slot is populated by deep-copying
-- the matching entry below. After that the slot is normal user data:
-- /gsesavelayoutx overwrites it with the current tracker config,
-- /gseapplylayoutx restores from it, and an explicit `Layouts.X = nil` +
-- /reload re-pulls the shipped default again.
--
-- Values were captured from Larry's retail character (Layouts X and Y
-- already saved), with the now-retired `Config.ShowIconModifiers` flag
-- stripped (it was removed in a prior cleanup). Layout X is HORIZONTAL
-- with Linked frames; Layout Y is VERTICAL with independent (unlinked)
-- frames so each tracker piece can be positioned separately.
--
-- The pixel positions reflect Larry's retail UI; they may land off-screen
-- on Classic / MoP if the resolution or UI scale differs. The user can
-- recapture on each flavour with /gsesavelayoutx after dragging the
-- frames where they want them, then /gseapplylayoutx will use the local
-- override instead of these defaults.
--
-- The presets live on the GSE namespace (rather than a file-local) because
-- this chunk is already at Lua 5.1's hard 200-local-per-function limit; a
-- new `local` here triggers `main function has more than 200 local
-- variables` at compile time. Side benefit: callers can inspect / override
-- at runtime via `/dump GSE.TrackerLayoutPresets.X` or
-- `/run GSE.TrackerLayoutPresets.X = {...}`.
-- =========================================================================

GSE.TrackerLayoutPresets = {
    X = {
        Config = {
            SuccessfulCastsLocked = false,
            AssistedSuccessLocked = false,
            IconCount = 10,
            TextLocked = false,
            ShowTrackerText = true,
            Linked = true,
            Locked = false,
            Orientation = "HORIZONTAL",
            ShowSequenceName = Statics.TrackerConfig.DefaultShowSequenceName,
            ShowSuccessfulCasts = true,
        },
        Text = { Y = 1260.9996337891, X = 573.58557128906, Moved = true, },
        SuccessfulCasts = { Y = 1460.9996337891, X = 573.58551025391, Moved = true, },
        Widget = { Y = 285, X = 1126, Point = "LEFT", RelativePoint = "LEFT", },
        Icon = { Y = 1360.9996337891, X = 577.58581542969, Moved = true, },
    },
    Y = {
        Config = {
            SuccessfulCastsLocked = false,
            AssistedSuccessLocked = false,
            IconCount = 10,
            TextLocked = false,
            ShowTrackerText = true,
            Linked = false,
            Locked = false,
            Orientation = "VERTICAL",
            ShowSequenceName = Statics.TrackerConfig.DefaultShowSequenceName,
            ShowSuccessfulCasts = true,
        },
        Text = { Y = 1670.0001220703, X = 980.00006103516, Moved = true, },
        SuccessfulCasts = { Y = 1670.0002441406, X = 780, Moved = true, },
        Widget = { Y = 285, X = 1126, Point = "LEFT", RelativePoint = "LEFT", },
        Icon = { Y = 1670.0001220703, X = 880.00006103516, Moved = true, },
    },
    -- Deep-copy helper. Layouts are two-level (top-level subtables for
    -- Config / Text / SuccessfulCasts / Widget / Icon, each containing scalar
    -- values), so a two-level shallow copy is sufficient -- no recursion needed.
    Clone = function(src)
        local dst = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                local sub = {}
                for sk, sv in pairs(v) do sub[sk] = sv end
                dst[k] = sub
            else
                dst[k] = v
            end
        end
        return dst
    end,
}

local SequenceIconEntries = {}
local SequenceIconTextures = {}
local KeyHistoryEntries = {}
local hookedButtons = {}
local activeSequence
local lastSequenceButtonName
local lastSequenceMods
local activeSpamKeyText
local activeSpamKeySequence
local activeSpamKeyExpiresAt = 0
local activeSpamKeyClearSerial = 0
local lastCapturedClickSerials = {}
local lastModsMessageClickSerials = {}
local lastPushSequence
local lastPushIcon
local lastPushTime = 0
local lastGSEActivityTime = 0
local scrollHitSerial = 0
local lastSuccessfulCastHitTime = 0
local lastSuccessfulCastHitIconID
local successfulCastHitSerial = 0
local lastAssistedSuccessCastSerial = 0
local successfulCastCount = 0
local assistedSuccessHitCount = 0
local assistedHighlightSequence
local assistedHighlightIsFallback = false
local successfulCastIconID
local successfulCastName
local successfulCastSequence
local heldAssistedSuccessIconID
local heldAssistedSuccessName
local heldAssistedSuccessExpiresAt = 0
local pendingSuccessfulCast = false
-- GSE.SequenceIconActiveChannel: true while the player is actively channeling or
-- empowering a spell. While set, UNIT_SPELLCAST_SUCCEEDED events for sub-casts
-- (e.g. /cast Hunter's Mark fired by the same GSE macro that channeled Rapid Fire)
-- are suppressed so they do NOT override the channel/empower icon in the GSE
-- Successful Cast frame. Lives on the GSE namespace rather than as a module-local
-- because this file is close to Lua 5.1's 200-locals-per-function limit.
GSE.SequenceIconActiveChannel = false
local lastAssistedChannelSpellID
local lastAssistedChannelStartMS = 0
local moveModeEnabled = false
local sequenceTextMoveModeEnabled = false
local successfulCastMoveModeEnabled = false
local assistedSuccessMoveModeEnabled = false
local SaveSequenceTextFramePosition
local UpdateAssistedSuccessFrame
local RefreshAssistedSuccessMoveMode
local UpdateSequenceText

GSE.SequenceIconTextResize = GSE.SequenceIconTextResize or {
    DefaultWidth = 902,
    DefaultHeight = 593,
    MinWidth = 520,
    MinHeight = 80,
    MaxWidth = 1400,
    MaxHeight = 1200,
    HandleSize = 16,
    FontSize = 32,
    LineHeight = 42,
    AutoWidth = 600,
    BaseLayoutVersion = 10,
    DefaultWidgetPoint = "LEFT",
    DefaultWidgetRelativePoint = "LEFT",
    DefaultWidgetX = 1126,
    DefaultWidgetY = 285
}

GSE.SequenceIconTrackerWidget = CreateFrame("Frame", "GSEIconTrackerWidget", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
GSE.SequenceIconFrame = CreateFrame("Frame", "GSEIconFrame", GSE.SequenceIconTrackerWidget, BackdropTemplateMixin and "BackdropTemplate" or nil)
GSE.SequenceIconTextFrame = CreateFrame("Frame", "GSEIconTextFrame", GSE.SequenceIconTrackerWidget, BackdropTemplateMixin and "BackdropTemplate" or nil)
GSE.SuccessfulCastFrame = CreateFrame("Frame", "GSESuccessfulCastFrame", GSE.SequenceIconTrackerWidget, BackdropTemplateMixin and "BackdropTemplate" or nil)
GSE.AssistedSuccessFrame = CreateFrame("Frame", "GSEAssistedSuccessFrame", GSE.SequenceIconTrackerWidget, BackdropTemplateMixin and "BackdropTemplate" or nil)

local function ClampNumber(value, minimum, maximum, default)
    value = tonumber(value) or default
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

GSE.SequenceIconClampTrackerScale = GSE.SequenceIconClampTrackerScale or function(value)
    value = tonumber(value) or 1
    if value < 0.50 then return 0.50 end
    if value > 2.00 then return 2.00 end
    return math.floor((value * 100) + 0.5) / 100
end

local function EnsureSequenceIconFrameOptions()
    if not GSEOptions then GSEOptions = {} end
    if GSE.isEmpty(GSEOptions.SequenceIconFrame) then
        GSEOptions.SequenceIconFrame = {}
    end

    local opts = GSEOptions.SequenceIconFrame
    if opts.BaseVerticalLayoutVersion ~= GSE.SequenceIconTextResize.BaseLayoutVersion then
        opts.Orientation = "VERTICAL"
        opts.TextMoved = false
        opts.TextX = nil
        opts.TextY = nil
        opts.TextWidth = GSE.SequenceIconTextResize.DefaultWidth
        opts.TextHeight = GSE.SequenceIconTextResize.DefaultHeight
        opts.IconCount = Statics.TrackerConfig.DefaultIconCount
        opts.WidgetPoint = GSE.SequenceIconTextResize.DefaultWidgetPoint
        opts.WidgetRelativePoint = GSE.SequenceIconTextResize.DefaultWidgetRelativePoint
        opts.WidgetX = GSE.SequenceIconTextResize.DefaultWidgetX
        opts.WidgetY = GSE.SequenceIconTextResize.DefaultWidgetY
        -- Wipe per-frame internal positions so LayoutTrackerWidget re-anchors
        -- all three frames with the current gap setting (1 px). Saved named
        -- Layouts (e.g. Layout X) are NOT touched -- they live under opts.Layouts.
        opts.IconMoved = false
        opts.IconX = nil
        opts.IconY = nil
        opts.SuccessfulCastsMoved = false
        opts.SuccessfulCastsX = nil
        opts.SuccessfulCastsY = nil
        opts.AssistedSuccessMoved = false
        opts.AssistedSuccessX = nil
        opts.AssistedSuccessY = nil
        opts.BaseVerticalLayoutVersion = GSE.SequenceIconTextResize.BaseLayoutVersion
    end

    opts.Enabled = opts.Enabled == true
    if opts.SingleIcon == nil then opts.SingleIcon = false end
    if opts.PreserveScaleOnZoom == nil then opts.PreserveScaleOnZoom = false end
    opts.IconSize = 100
    opts.IconCount = ClampNumber(opts.IconCount, 1, (opts.SingleIcon and 1 or 10), Statics.TrackerConfig.DefaultIconCount)
    opts.Scale = 0.50
    opts.TextWidth = ClampNumber(opts.TextWidth, GSE.SequenceIconTextResize.MinWidth, GSE.SequenceIconTextResize.MaxWidth, GSE.SequenceIconTextResize.DefaultWidth)
    opts.TextHeight = ClampNumber(opts.TextHeight, GSE.SequenceIconTextResize.MinHeight, GSE.SequenceIconTextResize.MaxHeight, GSE.SequenceIconTextResize.DefaultHeight)
    -- Only initialise if missing -- saved Layouts may legitimately set this
    -- to either HORIZONTAL or VERTICAL, and force-overriding every init
    -- would defeat per-layout orientation.
    if opts.Orientation == nil then opts.Orientation = "VERTICAL" end
    if opts.ShowTrackerText == nil then opts.ShowTrackerText = true end
    if opts.Linked == nil then opts.Linked = true end
    if opts.ShowPlayerStatus == nil then opts.ShowPlayerStatus = true end
    if opts.ShowSequenceName == nil then opts.ShowSequenceName = Statics.TrackerConfig.DefaultShowSequenceName end
    if opts.ShowHardwareEvents == nil then opts.ShowHardwareEvents = true end
    if opts.ShowActivationKey == nil then opts.ShowActivationKey = true end
    if opts.ShowClientModKey == nil then opts.ShowClientModKey = true end
    if opts.ShowBlock == nil then opts.ShowBlock = true end
    if opts.ShowStep == nil then opts.ShowStep = true end
    if opts.ShowSuccessfulCasts == nil then opts.ShowSuccessfulCasts = true end
    if opts.Locked == nil then opts.Locked = true end
    if opts.TextLocked == nil then opts.TextLocked = true end
    if opts.SuccessfulCastsLocked == nil then opts.SuccessfulCastsLocked = true end
    if opts.AssistedSuccessLocked == nil then opts.AssistedSuccessLocked = true end
    if opts.TrackerFrameScale == nil then opts.TrackerFrameScale = 1.0 end
    opts.TrackerFrameScale = math.max(0.75, math.min(2.0, tonumber(opts.TrackerFrameScale) or 1.0))

    -- Always-on safety net for the widget position. Even after the version
    -- reset block above runs, certain Classic / BoA / MoP startup paths were
    -- observed to leave Widget X / Y nil after the first session (the values
    -- weren't persisted to GSEOptions). Backfilling here on every call means
    -- the next logout always saves a real number, not nil.
    if opts.WidgetPoint         == nil then opts.WidgetPoint         = GSE.SequenceIconTextResize.DefaultWidgetPoint         end
    if opts.WidgetRelativePoint == nil then opts.WidgetRelativePoint = GSE.SequenceIconTextResize.DefaultWidgetRelativePoint end
    if opts.WidgetX             == nil then opts.WidgetX             = GSE.SequenceIconTextResize.DefaultWidgetX             end
    if opts.WidgetY             == nil then opts.WidgetY             = GSE.SequenceIconTextResize.DefaultWidgetY             end

    -- Factory-preset the named tracker layout slots X and Y if a character
    -- doesn't have them yet. After this any /gseapplylayoutx or /gseapplylayouty
    -- on a fresh character finds a real layout to restore -- the shipped
    -- presets (from DEFAULT_LAYOUT_X / DEFAULT_LAYOUT_Y above). User-saved
    -- overrides via /gsesavelayoutx etc. are NOT touched -- the `or` guards
    -- below only fire when the slot is genuinely nil. To force a re-pull
    -- of the shipped default, clear the slot manually:
    --   /run GSEOptions.SequenceIconFrame.Layouts.X = nil; ReloadUI()
    opts.Layouts = opts.Layouts or {}
    if opts.Layouts.X == nil then opts.Layouts.X = GSE.TrackerLayoutPresets.Clone(GSE.TrackerLayoutPresets.X) end
    if opts.Layouts.Y == nil then opts.Layouts.Y = GSE.TrackerLayoutPresets.Clone(GSE.TrackerLayoutPresets.Y) end

    return opts
end

function GSE.GetTrackerScale()
    return EnsureSequenceIconFrameOptions().Scale
end

function GSE.ApplyTrackerScale()
    local scale = GSE.GetTrackerScale()
    if GSE.SequenceIconTrackerWidget and GSE.SequenceIconTrackerWidget.SetScale then GSE.SequenceIconTrackerWidget:SetScale(scale) end
    if GSE.SequenceIconFrame and GSE.SequenceIconFrame.SetScale then GSE.SequenceIconFrame:SetScale(1) end
    if GSE.SequenceIconTextFrame and GSE.SequenceIconTextFrame.SetScale then GSE.SequenceIconTextFrame:SetScale(1) end
    if GSE.SuccessfulCastFrame and GSE.SuccessfulCastFrame.SetScale then GSE.SuccessfulCastFrame:SetScale(1) end
    if GSE.AssistedSuccessFrame and GSE.AssistedSuccessFrame.SetScale then GSE.AssistedSuccessFrame:SetScale(1) end
    if GSE.RefreshSequenceIconFrame then GSE.RefreshSequenceIconFrame() end
    if GSE.SequenceIconLayoutTrackerWidget then
        GSE.SequenceIconLayoutTrackerWidget()
    end
end

function GSE.SetTrackerScale(value)
    EnsureSequenceIconFrameOptions().Scale = GSE.SequenceIconClampTrackerScale(value)
    GSE.ApplyTrackerScale()
end

-- ------------------------------------------------------------------------
-- Tracker frame component scale: scales SC Icon, Sequence Icon Scroll,
-- and Tracker Text together as a group. Independent of the parent widget
-- scale above; each of the 3 frames receives :SetScale(value) directly.
-- ------------------------------------------------------------------------
function GSE.SequenceIconGetTrackerFrameScale()
    return tonumber(EnsureSequenceIconFrameOptions().TrackerFrameScale) or 1.0
end

function GSE.SequenceIconApplyTrackerFrameScale()
    local scale = GSE.SequenceIconGetTrackerFrameScale()
    scale = math.max(0.75, math.min(2.0, scale))
    local currentOptions = EnsureSequenceIconFrameOptions()

    if not currentOptions.PreserveScaleOnZoom then
        if GSE.SequenceIconFrame and GSE.SequenceIconFrame.SetScale then
            GSE.SequenceIconFrame:SetScale(scale)
        end
        if GSE.SequenceIconTextFrame and GSE.SequenceIconTextFrame.SetScale then
            GSE.SequenceIconTextFrame:SetScale(scale)
        end
        if GSE.SuccessfulCastFrame and GSE.SuccessfulCastFrame.SetScale then
            GSE.SuccessfulCastFrame:SetScale(scale)
        end
        return
    end

    -- PreserveScaleOnZoom ON: keep each frame's on-screen position fixed across
    -- the scale change. Linked-layout frames anchor at zero offset and are
    -- already position-stable; only frames the user has dragged out (Moved)
    -- carry a scale-sensitive screen offset, so for those capture the centre in
    -- absolute pixels, rescale, re-anchor to the same spot and persist it --
    -- same absolute-pixel technique GSE.ApplyScaleToFrame uses for windows.
    local scaleTargets = {
        { key = "Icon",            frame = GSE.SequenceIconFrame },
        { key = "Text",            frame = GSE.SequenceIconTextFrame },
        { key = "SuccessfulCasts", frame = GSE.SuccessfulCastFrame },
    }
    for _, target in ipairs(scaleTargets) do
        local frame = target.frame
        if frame and frame.SetScale then
            local moved = currentOptions[target.key .. "Moved"] == true
            local absX, absY, preserve
            if moved and frame.IsShown and frame:IsShown() and frame.GetCenter then
                local centerX, centerY = frame:GetCenter()
                if centerX and centerY then
                    local oldEffective = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
                    if not oldEffective or oldEffective <= 0 then oldEffective = 1 end
                    absX, absY, preserve = centerX * oldEffective, centerY * oldEffective, true
                end
            end

            frame:SetScale(scale)

            if preserve and GSE.SetFrameScreenPoint then
                local newEffective = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
                if not newEffective or newEffective <= 0 then newEffective = 1 end
                GSE.SetFrameScreenPoint(frame, "CENTER", absX / newEffective, absY / newEffective)
                if GSE.SequenceIconSaveInternalFramePosition then
                    GSE.SequenceIconSaveInternalFramePosition(target.key, frame)
                end
            end
        end
    end

    -- Re-flow the widget so linked frames re-anchor and any moved frames
    -- re-apply from their (now updated) saved positions.
    if GSE.SequenceIconLayoutTrackerWidget then
        GSE.SequenceIconLayoutTrackerWidget()
    end
end

function GSE.SequenceIconSetTrackerFrameScale(value)
    local scale = math.max(0.75, math.min(2.0, tonumber(value) or 1.0))
    EnsureSequenceIconFrameOptions().TrackerFrameScale = scale
    GSE.SequenceIconApplyTrackerFrameScale()
end

function GSE.SequenceIconApplyTrackerWidgetPosition()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local point = currentOptions.WidgetPoint or GSE.SequenceIconTextResize.DefaultWidgetPoint
    local relativePoint = currentOptions.WidgetRelativePoint or GSE.SequenceIconTextResize.DefaultWidgetRelativePoint
    local x = tonumber(currentOptions.WidgetX) or GSE.SequenceIconTextResize.DefaultWidgetX
    local y = tonumber(currentOptions.WidgetY) or GSE.SequenceIconTextResize.DefaultWidgetY

    GSE.SequenceIconTrackerWidget:ClearAllPoints()
    if point == "LEFT" and relativePoint == "LEFT" then
        GSE.SequenceIconTrackerWidget:SetPoint("CENTER", UIParent, "LEFT", x, y)
    else
        GSE.SequenceIconTrackerWidget:SetPoint(point, UIParent, relativePoint, x, y)
    end
end

function GSE.SequenceIconSaveTrackerWidgetPosition()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local centerX, centerY = GSE.SequenceIconTrackerWidget:GetCenter()
    local parentHeight = UIParent.GetHeight and UIParent:GetHeight()
    if not centerX or not centerY or not parentHeight then return end

    currentOptions.WidgetPoint = GSE.SequenceIconTextResize.DefaultWidgetPoint
    currentOptions.WidgetRelativePoint = GSE.SequenceIconTextResize.DefaultWidgetRelativePoint
    currentOptions.WidgetX = centerX
    currentOptions.WidgetY = centerY - (parentHeight / 2)
end

function GSE.SequenceIconResetTrackerWidgetPosition()
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.WidgetPoint = GSE.SequenceIconTextResize.DefaultWidgetPoint
    currentOptions.WidgetRelativePoint = GSE.SequenceIconTextResize.DefaultWidgetRelativePoint
    currentOptions.WidgetX = GSE.SequenceIconTextResize.DefaultWidgetX
    currentOptions.WidgetY = GSE.SequenceIconTextResize.DefaultWidgetY
    GSE.SequenceIconApplyTrackerWidgetPosition()
end

-- ------------------------------------------------------------------------
-- Named tracker layouts (presets). Each layout snapshots the Icon/Text/
-- SuccessfulCasts internal positions and the widget anchor; the user can
-- save the current arrangement under a name and re-apply it later.
-- ------------------------------------------------------------------------
function GSE.SequenceIconSaveLayout(name)
    if type(name) ~= "string" or name == "" then return false end
    local opts = EnsureSequenceIconFrameOptions()
    opts.Layouts = opts.Layouts or {}

    local layout = {}
    -- Positions of each independently-anchored tracker frame.
    for _, prefix in ipairs({ "Icon", "Text", "SuccessfulCasts" }) do
        layout[prefix] = {
            Moved = opts[prefix .. "Moved"] == true,
            X     = tonumber(opts[prefix .. "X"]),
            Y     = tonumber(opts[prefix .. "Y"]),
        }
    end
    -- Parent widget anchor (shared root for all 3 trackers).
    layout.Widget = {
        Point         = opts.WidgetPoint,
        RelativePoint = opts.WidgetRelativePoint,
        X             = tonumber(opts.WidgetX),
        Y             = tonumber(opts.WidgetY),
    }
    -- Configuration flags (visibility, lock, link, orientation, count) so
    -- applying the layout restores the FULL visual state, not just XY.
    layout.Config = {
        Locked                = opts.Locked,
        TextLocked            = opts.TextLocked,
        SuccessfulCastsLocked = opts.SuccessfulCastsLocked,
        AssistedSuccessLocked = opts.AssistedSuccessLocked,
        Linked                = opts.Linked,
        ShowTrackerText       = opts.ShowTrackerText,
        ShowSequenceName      = opts.ShowSequenceName,
        ShowSuccessfulCasts   = opts.ShowSuccessfulCasts,
        Orientation           = opts.Orientation,
        IconCount             = tonumber(opts.IconCount),
    }

    opts.Layouts[name] = layout
    return true
end

function GSE.SequenceIconApplyLayout(name)
    if type(name) ~= "string" or name == "" then return false end
    local opts = EnsureSequenceIconFrameOptions()
    local layout = opts.Layouts and opts.Layouts[name]
    if type(layout) ~= "table" then return false end

    for _, prefix in ipairs({ "Icon", "Text", "SuccessfulCasts" }) do
        local saved = layout[prefix]
        if type(saved) == "table" then
            opts[prefix .. "Moved"] = saved.Moved == true
            opts[prefix .. "X"]     = saved.X
            opts[prefix .. "Y"]     = saved.Y
        end
    end

    -- Restore the configuration flags so visual state matches the snapshot.
    if type(layout.Config) == "table" then
        local c = layout.Config
        if c.Locked                ~= nil then opts.Locked                = c.Locked                end
        if c.TextLocked            ~= nil then opts.TextLocked            = c.TextLocked            end
        if c.SuccessfulCastsLocked ~= nil then opts.SuccessfulCastsLocked = c.SuccessfulCastsLocked end
        if c.AssistedSuccessLocked ~= nil then opts.AssistedSuccessLocked = c.AssistedSuccessLocked end
        if c.Linked                ~= nil then opts.Linked                = c.Linked                end
        if c.ShowTrackerText       ~= nil then opts.ShowTrackerText       = c.ShowTrackerText       end
        if c.ShowSequenceName      ~= nil then opts.ShowSequenceName      = c.ShowSequenceName      end
        if c.ShowSuccessfulCasts   ~= nil then opts.ShowSuccessfulCasts   = c.ShowSuccessfulCasts   end
        if c.Orientation           ~= nil then opts.Orientation           = c.Orientation           end
        if c.IconCount             ~= nil then opts.IconCount             = c.IconCount             end
    end

    if type(layout.Widget) == "table" then
        if layout.Widget.Point         then opts.WidgetPoint         = layout.Widget.Point         end
        if layout.Widget.RelativePoint then opts.WidgetRelativePoint = layout.Widget.RelativePoint end
        if layout.Widget.X             then opts.WidgetX             = layout.Widget.X             end
        if layout.Widget.Y             then opts.WidgetY             = layout.Widget.Y             end
        if GSE.SequenceIconApplyTrackerWidgetPosition then
            GSE.SequenceIconApplyTrackerWidgetPosition()
        end
    end

    if GSE.SequenceIconLayoutTrackerWidget then
        GSE.SequenceIconLayoutTrackerWidget()
    end
    return true
end

local SequenceIconFrame = GSE.SequenceIconFrame
local SequenceIconTextFrame = GSE.SequenceIconTextFrame
local SuccessfulCastFrame = GSE.SuccessfulCastFrame
local AssistedSuccessFrame = GSE.AssistedSuccessFrame
-- Load-time snapshot of the options, used by the one-time frame setup below
-- (the initial frame sizes and the initial enabled state). Every function in
-- this file deliberately re-fetches a *fresh* options table via
-- EnsureSequenceIconFrameOptions() rather than closing over this snapshot, so
-- this is named distinctly to avoid shadowing those local `opts`.
local initialOpts = EnsureSequenceIconFrameOptions()
local SequenceIconFrameHeight = initialOpts.IconSize
local SequenceIconFrameWidth = initialOpts.IconSize

GSE.SequenceIconTrackerWidget:SetSize(1, 1)
GSE.SequenceIconApplyTrackerWidgetPosition()
GSE.SequenceIconTrackerWidget:SetFrameStrata("HIGH")
GSE.SequenceIconTrackerWidget:SetFrameLevel(99)
GSE.SequenceIconTrackerWidget:SetMovable(true)
GSE.SequenceIconTrackerWidget:SetClampedToScreen(true)
GSE.SequenceIconTrackerWidget:EnableMouse(false)
GSE.SequenceIconTrackerWidget:RegisterForDrag("LeftButton")
if GSE.SequenceIconTrackerWidget.SetDontSavePosition then GSE.SequenceIconTrackerWidget:SetDontSavePosition(true) end
if SequenceIconFrame.SetDontSavePosition then SequenceIconFrame:SetDontSavePosition(true) end
if SequenceIconTextFrame.SetDontSavePosition then SequenceIconTextFrame:SetDontSavePosition(true) end
if SuccessfulCastFrame.SetDontSavePosition then SuccessfulCastFrame:SetDontSavePosition(true) end
if AssistedSuccessFrame.SetDontSavePosition then AssistedSuccessFrame:SetDontSavePosition(true) end

GSE.ApplyTrackerScale()
if GSE.SequenceIconApplyTrackerFrameScale then GSE.SequenceIconApplyTrackerFrameScale() end

SequenceIconFrame:SetSize(SequenceIconFrameWidth, SequenceIconFrameHeight)
SequenceIconFrame:SetPoint("CENTER", GSE.SequenceIconTrackerWidget, "CENTER", 0, 0)
SequenceIconFrame:SetFrameStrata("HIGH")
SequenceIconFrame:SetFrameLevel(100)
SequenceIconFrame:SetMovable(true)
SequenceIconFrame:EnableMouse(false)
SequenceIconFrame:RegisterForDrag()
SequenceIconFrame:SetScript("OnDragStart", function(self)
    if not moveModeEnabled then return end
    self.GSETrackerDragging = true
    self:StartMoving()
end)
SequenceIconFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.GSETrackerDragging = nil
    if GSE.SequenceIconSaveInternalFramePosition then GSE.SequenceIconSaveInternalFramePosition("Icon", self) end
end)
SequenceIconFrame:SetClampedToScreen(true)

SequenceIconTextFrame:SetSize(initialOpts.TextWidth, initialOpts.TextHeight)
SequenceIconTextFrame:SetPoint("TOPLEFT", SequenceIconFrame, "TOPRIGHT", 10, 0)
SequenceIconTextFrame:SetFrameStrata("HIGH")
SequenceIconTextFrame:SetFrameLevel(102)
SequenceIconTextFrame:SetMovable(true)
if SequenceIconTextFrame.SetResizable then SequenceIconTextFrame:SetResizable(true) end
if SequenceIconTextFrame.SetResizeBounds then
    SequenceIconTextFrame:SetResizeBounds(GSE.SequenceIconTextResize.MinWidth, GSE.SequenceIconTextResize.MinHeight, GSE.SequenceIconTextResize.MaxWidth, GSE.SequenceIconTextResize.MaxHeight)
else
    if SequenceIconTextFrame.SetMinResize then SequenceIconTextFrame:SetMinResize(GSE.SequenceIconTextResize.MinWidth, GSE.SequenceIconTextResize.MinHeight) end
    if SequenceIconTextFrame.SetMaxResize then SequenceIconTextFrame:SetMaxResize(GSE.SequenceIconTextResize.MaxWidth, GSE.SequenceIconTextResize.MaxHeight) end
end
SequenceIconTextFrame:EnableMouse(false)
SequenceIconTextFrame:RegisterForDrag()
SequenceIconTextFrame:SetScript("OnDragStart", function(self)
    if not sequenceTextMoveModeEnabled then return end
    self.GSETrackerDragging = true
    self:StartMoving()
end)
SequenceIconTextFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.GSETrackerDragging = nil
    if SaveSequenceTextFramePosition then SaveSequenceTextFramePosition() end
end)
SequenceIconTextFrame:SetClampedToScreen(true)

SuccessfulCastFrame:SetSize(initialOpts.IconSize, initialOpts.IconSize)
SuccessfulCastFrame:SetPoint("CENTER", GSE.SequenceIconTrackerWidget, "CENTER", -96, 0)
SuccessfulCastFrame:SetFrameStrata("HIGH")
SuccessfulCastFrame:SetFrameLevel(105)
SuccessfulCastFrame:SetMovable(true)
SuccessfulCastFrame:EnableMouse(false)
SuccessfulCastFrame:RegisterForDrag()
SuccessfulCastFrame:SetScript("OnDragStart", function(self)
    if not successfulCastMoveModeEnabled then return end
    self.GSETrackerDragging = true
    self:StartMoving()
end)
SuccessfulCastFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.GSETrackerDragging = nil
    if GSE.SequenceIconSaveInternalFramePosition then GSE.SequenceIconSaveInternalFramePosition("SuccessfulCasts", self) end
end)
SuccessfulCastFrame:SetClampedToScreen(true)

AssistedSuccessFrame:SetSize(initialOpts.IconSize, initialOpts.IconSize)
AssistedSuccessFrame:SetPoint("CENTER", GSE.SequenceIconTrackerWidget, "CENTER", 0, 96)
AssistedSuccessFrame:SetFrameStrata("HIGH")
AssistedSuccessFrame:SetFrameLevel(106)
AssistedSuccessFrame:SetMovable(true)
AssistedSuccessFrame:EnableMouse(false)
AssistedSuccessFrame:RegisterForDrag()
AssistedSuccessFrame:SetScript("OnDragStart", function(self)
    if not assistedSuccessMoveModeEnabled then return end
    self.GSETrackerDragging = true
    self:StartMoving()
end)
AssistedSuccessFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.GSETrackerDragging = nil
    if GSE.SequenceIconSaveInternalFramePosition then GSE.SequenceIconSaveInternalFramePosition("AssistedSuccess", self) end
end)
AssistedSuccessFrame:SetClampedToScreen(true)
AssistedSuccessFrame:Hide()

local sequenceTextBackground = SequenceIconTextFrame:CreateTexture(nil, "BACKGROUND")
sequenceTextBackground:SetTexture("Interface\\Buttons\\WHITE8x8")
sequenceTextBackground:SetVertexColor(0, 0, 0, 0.55)
sequenceTextBackground:SetAllPoints(SequenceIconTextFrame)
sequenceTextBackground:Hide()

local SequenceTextLines = {}
local function EnsureSequenceTextLine(index)
    if not SequenceTextLines[index] then
        -- Follow whatever font the user is using, like the rest of the addon:
        -- the face is pulled from the live GameFontHighlightSmall object on every
        -- (re)apply, so skins such as ElvUI -- which replace the GameFont* objects
        -- globally -- are picked up. A subtle drop shadow, no heavy OUTLINE. The
        -- user-resizable FontSize/LineHeight are preserved.
        local line = SequenceIconTextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetWidth(260)
        line:SetHeight(GSE.SequenceIconTextResize.LineHeight)
        if line.GetFont and line.SetFont then
            local font = (GSE.Skin and GSE.Skin.HostFont and GSE.Skin.HostFont())
                or (_G.GameFontHighlightSmall and _G.GameFontHighlightSmall:GetFont())
            if font then line:SetFont(font, GSE.SequenceIconTextResize.FontSize, "") end
        end
        if line.SetShadowOffset then line:SetShadowOffset(1, -1) end
        if line.SetShadowColor then line:SetShadowColor(0, 0, 0, 1) end
        if line.SetWordWrap then line:SetWordWrap(false) end
        if line.SetNonSpaceWrap then line:SetNonSpaceWrap(false) end
        SequenceTextLines[index] = line
    end

    return SequenceTextLines[index]
end

EnsureSequenceTextLine(1)

local placeholderIcon = SequenceIconFrame:CreateTexture(nil, "ARTWORK")
placeholderIcon:SetAlpha(0.65)
function GSE.ApplyTrackerIconTextOutline(fontString)
    if not fontString then return end
    -- Match the rest of the addon's windowed text: a subtle drop shadow, no
    -- heavy OUTLINE. (Name kept for its existing call sites.)
    if fontString.SetShadowOffset then fontString:SetShadowOffset(1, -1) end
    if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 1) end
end

local assistedHighlightTexture = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY")
assistedHighlightTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local assistedHighlightBorderTop = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 6)
local assistedHighlightBorderRight = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 6)
local assistedHighlightBorderBottom = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 6)
local assistedHighlightBorderLeft = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 6)
local assistedHighlightFlash = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 7)
assistedHighlightFlash:SetTexture("Interface\\Buttons\\WHITE8x8")
assistedHighlightFlash:SetBlendMode("ADD")
assistedHighlightFlash:SetVertexColor(1, 0.82, 0.18, 1)
assistedHighlightFlash:SetAlpha(0)
local assistedHighlightLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
assistedHighlightLabel:SetText("Assisted\nHighlight")
assistedHighlightLabel:SetTextColor(1, 0.82, 0.18, 1)
GSE.ApplyTrackerIconTextOutline(assistedHighlightLabel)
assistedHighlightLabel:SetJustifyH("CENTER")
assistedHighlightLabel:SetJustifyV("MIDDLE")
assistedHighlightTexture.matchCountLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
assistedHighlightTexture.matchCountLabel:SetTextColor(1, 1, 1, 1)
GSE.ApplyTrackerIconTextOutline(assistedHighlightTexture.matchCountLabel)
assistedHighlightTexture.matchCountLabel:SetJustifyH("CENTER")
assistedHighlightTexture.matchPercentLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
assistedHighlightTexture.matchPercentLabel:SetTextColor(1, 1, 1, 1)
GSE.ApplyTrackerIconTextOutline(assistedHighlightTexture.matchPercentLabel)
assistedHighlightTexture.matchPercentLabel:SetJustifyH("CENTER")
local successfulCastTexture = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY")
successfulCastTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local successfulCastFlash = SuccessfulCastFrame:CreateTexture(nil, "OVERLAY", nil, 7)
successfulCastFlash:SetTexture("Interface\\Buttons\\WHITE8x8")
successfulCastFlash:SetBlendMode("ADD")
successfulCastFlash:SetVertexColor(0.45, 0.9, 1, 1)
successfulCastFlash:SetAlpha(0)
local successfulCastLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
successfulCastLabel:SetText("GSE\nSuccessful\nCasts")
successfulCastLabel:SetTextColor(0.45, 0.9, 1, 1)
GSE.ApplyTrackerIconTextOutline(successfulCastLabel)
do
    -- Apply larger font size (default GameFontNormalSmall is ~10pt; 14pt
    -- gives a much more readable label across 3 lines on the 100x100 icon).
    local castFont = successfulCastLabel.GetFont and successfulCastLabel:GetFont()
    if castFont then successfulCastLabel:SetFont(castFont, 15) end
end
successfulCastLabel:SetJustifyH("CENTER")
successfulCastLabel:SetJustifyV("MIDDLE")
successfulCastTexture.blockLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
successfulCastTexture.blockLabel:SetTextColor(1, 0.82, 0.18, 1)
GSE.ApplyTrackerIconTextOutline(successfulCastTexture.blockLabel)
successfulCastTexture.blockLabel:SetJustifyH("CENTER")
successfulCastTexture.stepLabel = SuccessfulCastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
successfulCastTexture.stepLabel:SetTextColor(1, 1, 1, 1)
GSE.ApplyTrackerIconTextOutline(successfulCastTexture.stepLabel)
successfulCastTexture.stepLabel:SetJustifyH("CENTER")
local assistedSuccessTexture = AssistedSuccessFrame:CreateTexture(nil, "ARTWORK")
assistedSuccessTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local assistedSuccessGlow = AssistedSuccessFrame:CreateTexture(nil, "BACKGROUND")
assistedSuccessGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
assistedSuccessGlow:SetBlendMode("ADD")
assistedSuccessGlow:SetVertexColor(0.15, 1, 0.35, 0.35)
assistedSuccessGlow:SetAlpha(0.35)
local assistedSuccessFlash = AssistedSuccessFrame:CreateTexture(nil, "OVERLAY", nil, 7)
assistedSuccessFlash:SetTexture("Interface\\Buttons\\WHITE8x8")
assistedSuccessFlash:SetBlendMode("ADD")
assistedSuccessFlash:SetVertexColor(0.25, 1, 0.45, 1)
assistedSuccessFlash:SetAlpha(0)
local assistedSuccessLabel = AssistedSuccessFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
assistedSuccessLabel:SetText("Match")
assistedSuccessLabel:SetTextColor(0.25, 1, 0.45, 1)
assistedSuccessLabel:SetShadowOffset(1, -1)
assistedSuccessLabel:SetShadowColor(0, 0, 0, 1)
assistedSuccessLabel:SetJustifyH("CENTER")
local SequenceIconFlashes = {}

local function FlashTexture(target, flash)
    if not target or not flash then return end

    flash:ClearAllPoints()
    flash:SetAllPoints(target)
    flash:SetAlpha(0.85)
    flash:Show()
    C_Timer.After(0.08, function()
        flash:SetAlpha(0.35)
    end)
    C_Timer.After(0.16, function()
        flash:SetAlpha(0)
        flash:Hide()
    end)
end

local function SetupBorderTexture(texture)
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetVertexColor(1, 0.82, 0.18, 0.95)
end

SetupBorderTexture(assistedHighlightBorderTop)
SetupBorderTexture(assistedHighlightBorderRight)
SetupBorderTexture(assistedHighlightBorderBottom)
SetupBorderTexture(assistedHighlightBorderLeft)

local function SetAssistedHighlightBorderShown(shown)
    if shown then
        assistedHighlightBorderTop:Show()
        assistedHighlightBorderRight:Show()
        assistedHighlightBorderBottom:Show()
        assistedHighlightBorderLeft:Show()
    else
        assistedHighlightBorderTop:Hide()
        assistedHighlightBorderRight:Hide()
        assistedHighlightBorderBottom:Hide()
        assistedHighlightBorderLeft:Hide()
    end
end

local function EnsureIconFlash(index)
    if not SequenceIconFlashes[index] then
        local flash = SequenceIconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        flash:SetTexture("Interface\\Buttons\\WHITE8x8")
        flash:SetBlendMode("ADD")
        flash:SetVertexColor(1, 0.82, 0.18, 1)
        flash:SetAlpha(0)
        SequenceIconFlashes[index] = flash
    end
    return SequenceIconFlashes[index]
end

local function GetGCDGraceWindow()
    if GSE.GetGCD then
        local ok, gcd = pcall(GSE.GetGCD)
        gcd = ok and tonumber(gcd)
        if gcd and gcd > 0 then
            return math.max(0.75, math.min(2, gcd))
        end
    end

    return Statics.TrackerConfig.DefaultGCDGraceWindow
end

local function TryTriggerAssistedSuccessPing()
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled or currentOptions.ShowSuccessfulCasts == false then return end

    local sequence = successfulCastSequence
    if not sequence or assistedHighlightSequence ~= sequence then return end
    if assistedHighlightIsFallback or lastSuccessfulCastHitTime == 0 then return end
    if successfulCastHitSerial == 0 or successfulCastHitSerial == lastAssistedSuccessCastSerial then return end
    if lastSuccessfulCastHitIconID ~= assistedHighlightIconID then return end

    local now = GetTime and GetTime() or 0
    if (now - lastSuccessfulCastHitTime) > GetGCDGraceWindow() then return end

    assistedSuccessHitCount = assistedSuccessHitCount + 1
    lastAssistedSuccessCastSerial = successfulCastHitSerial
    heldAssistedSuccessIconID = lastSuccessfulCastHitIconID
    heldAssistedSuccessName = successfulCastName
    heldAssistedSuccessExpiresAt = now + (GetGCDGraceWindow() * 2)
    FlashTexture(successfulCastTexture, successfulCastFlash)
    if UpdateAssistedSuccessFrame then
        UpdateAssistedSuccessFrame()
        FlashTexture(assistedSuccessTexture, assistedSuccessFlash)
    end
end

local function SetMoveMode(enabled)
    enabled = enabled == true
    if moveModeEnabled == enabled then return end

    moveModeEnabled = enabled
    if enabled then
        SequenceIconFrame:RegisterForDrag("LeftButton")
    else
        if SequenceIconFrame.StopMovingOrSizing then
            SequenceIconFrame:StopMovingOrSizing()
        end
        SequenceIconFrame.GSETrackerDragging = nil
        SequenceIconFrame:RegisterForDrag()
    end
end

local function SetSuccessfulCastMoveMode(enabled)
    enabled = enabled == true
    if successfulCastMoveModeEnabled == enabled then return end

    successfulCastMoveModeEnabled = enabled
    if enabled then
        SuccessfulCastFrame:RegisterForDrag("LeftButton")
    else
        if SuccessfulCastFrame.StopMovingOrSizing then
            SuccessfulCastFrame:StopMovingOrSizing()
        end
        SuccessfulCastFrame.GSETrackerDragging = nil
        SuccessfulCastFrame:RegisterForDrag()
    end
end

local function SetAssistedSuccessMoveMode(enabled)
    enabled = enabled == true
    if assistedSuccessMoveModeEnabled == enabled then return end

    assistedSuccessMoveModeEnabled = enabled
    if enabled then
        AssistedSuccessFrame:RegisterForDrag("LeftButton")
    else
        if AssistedSuccessFrame.StopMovingOrSizing then
            AssistedSuccessFrame:StopMovingOrSizing()
        end
        AssistedSuccessFrame.GSETrackerDragging = nil
        AssistedSuccessFrame:RegisterForDrag()
    end
end

local function IsControlChordDown()
    return IsControlKeyDown and IsControlKeyDown() == true
end

-- The tracker's right-click chords (Shift = swap layout, Control = toggle
-- linked, Alt = toggle lock) all need the frame to be accepting mouse input.
-- While the tracker is LOCKED the frames are mouse-disabled so plain clicks
-- pass through; we re-enable ("arm") them only while one of these modifiers is
-- held so every chord can fire without breaking click-through. Previously only
-- Control armed the frame, so Alt+RightClick (lock) and Shift+RightClick (swap)
-- never reached the handler on a locked tracker.
local function IsTrackerToggleChordDown()
    return (IsAltKeyDown and IsAltKeyDown() == true)
        or (IsControlKeyDown and IsControlKeyDown() == true)
        or (IsShiftKeyDown and IsShiftKeyDown() == true)
end

local function IsSuccessfulCastFrameEnabled()
    local currentOptions = EnsureSequenceIconFrameOptions()
    return currentOptions.Enabled and currentOptions.ShowSuccessfulCasts ~= false
end

local function IsAssistedSuccessFrameEnabled()
    return false
end

function GSE.SequenceIconSetLinkedTrackerLockState(locked)
    local currentOptions = EnsureSequenceIconFrameOptions()
    locked = locked == true
    currentOptions.Locked = locked
    currentOptions.TextLocked = locked
    currentOptions.SuccessfulCastsLocked = locked
    currentOptions.AssistedSuccessLocked = locked
end

function GSE.SequenceIconAreLinkedTrackerFramesLocked()
    local currentOptions = EnsureSequenceIconFrameOptions()
    return currentOptions.Locked == true
        and currentOptions.TextLocked == true
        and currentOptions.SuccessfulCastsLocked == true
        and currentOptions.AssistedSuccessLocked == true
end

local function IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat and UnitAffectingCombat("player") == true
end

local function ApplyAssistedSuccessBackdrop()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local enabled = IsAssistedSuccessFrameEnabled() and (heldAssistedSuccessIconID ~= nil or not IsPlayerInCombat())
    local unlocked = enabled and currentOptions.AssistedSuccessLocked == false

    if not AssistedSuccessFrame.SetBackdrop then return end

    if unlocked then
        AssistedSuccessFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        AssistedSuccessFrame:SetBackdropColor(0, 0, 0, 0.45)
        AssistedSuccessFrame:SetBackdropBorderColor(0.25, 1, 0.45, 0.9)
    else
        AssistedSuccessFrame:SetBackdrop(nil)
    end
end

function GSE.SequenceIconRefreshTrackerWidgetBackdrop()
    local widget = GSE.SequenceIconTrackerWidget
    if not (widget and widget.SetBackdrop) then return end

    widget:SetBackdrop(nil)
end

SaveSequenceTextFramePosition = function()
    if GSE.SequenceIconSaveInternalFramePosition then GSE.SequenceIconSaveInternalFramePosition("Text", SequenceIconTextFrame) end
end

GSE.SequenceIconSaveInternalFramePosition = function(prefix, frame)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not (prefix and frame) then return end

    -- All tracker frames now anchor by TOP-LEFT so their top/left edge stays
    -- fixed as their contents grow or shrink. For the icon scroll specifically,
    -- this means reducing Preview Icon Count collapses icons toward the TOP
    -- (vertical) or LEFT (horizontal) of the saved position, never the center.
    if not (frame.GetLeft and frame.GetTop) then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end

    currentOptions[prefix .. "Moved"] = true
    currentOptions[prefix .. "X"] = left
    currentOptions[prefix .. "Y"] = top
    currentOptions[prefix .. "Anchor"] = "TOPLEFT"   -- migration marker
end

GSE.SequenceIconApplyInternalFramePosition = function(prefix, frame)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if frame and frame.GSETrackerDragging then return true end
    if not (prefix and frame and currentOptions[prefix .. "Moved"]) then return false end

    local x = tonumber(currentOptions[prefix .. "X"])
    local y = tonumber(currentOptions[prefix .. "Y"])
    if not (x and y) then return false end

    frame:ClearAllPoints()

    -- Text frame has always saved TOP-LEFT, so no migration needed for it.
    -- For everything else: if Anchor == "TOPLEFT" we have the new format;
    -- otherwise migrate the legacy CENTER (x, y) to TOPLEFT using the frame's
    -- current size, then save back so future loads use the new format.
    if prefix == "Text" or currentOptions[prefix .. "Anchor"] == "TOPLEFT" then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    else
        local w = frame.GetWidth and frame:GetWidth() or 0
        local h = frame.GetHeight and frame:GetHeight() or 0
        if w > 0 and h > 0 then
            -- Convert CENTER -> TOPLEFT. This preserves the current visual position:
            -- the computed TOPLEFT applied to the current size yields the same center
            -- the user had saved, so the frame does not jump on first load.
            local left = x - (w / 2)
            local top  = y + (h / 2)
            currentOptions[prefix .. "X"] = left
            currentOptions[prefix .. "Y"] = top
            currentOptions[prefix .. "Anchor"] = "TOPLEFT"
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        else
            -- Frame not sized yet; fall back to legacy CENTER for this call.
            -- Next apply (after the frame has real dimensions) will migrate.
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
    end
    return true
end

-- ------------------------------------------------------------------------
-- Snap a frame center to the nearest 10 px grid. Used at drop time so
-- dragged trackers always land on tidy multiples of 10 in screen space.
-- ------------------------------------------------------------------------
function GSE.SequenceIconSnapFrameTo10(frame)
    if not frame or not frame.GetCenter or not frame.SetPoint then return end
    local cx, cy = frame:GetCenter()
    if not cx or not cy then return end
    local sx = math.floor((cx + 5) / 10) * 10
    local sy = math.floor((cy + 5) / 10) * 10
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
end

-- ------------------------------------------------------------------------
-- Snap a dragged frame to its neighbor tracker frames if any edge is
-- within SNAP_THRESHOLD px. Checks all 4 sides plus axis-alignments:
--   X axis: this.right<->other.left, this.left<->other.right,
--           this.left<->other.left,  this.right<->other.right
--   Y axis: this.bottom<->other.top, this.top<->other.bottom,
--           this.top<->other.top,    this.bottom<->other.bottom
-- Returns true if a snap was applied. Honors the existing TOPLEFT/CENTER
-- anchor convention (Text = TOPLEFT, others = CENTER) when re-anchoring.
-- ------------------------------------------------------------------------
local TRACKER_SNAP_THRESHOLD = 10

function GSE.SequenceIconSnapFrameToNeighbors(frame)
    if not frame or not frame.GetLeft then return false end
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return false end

    local bestDX, bestDY
    local function consider(d, axis)
        if math.abs(d) > TRACKER_SNAP_THRESHOLD then return end
        if axis == "X" then
            if not bestDX or math.abs(d) < math.abs(bestDX) then bestDX = d end
        else
            if not bestDY or math.abs(d) < math.abs(bestDY) then bestDY = d end
        end
    end

    local neighbors = { SequenceIconFrame, SequenceIconTextFrame, SuccessfulCastFrame }
    for _, other in ipairs(neighbors) do
        if other and other ~= frame and other.IsShown and other:IsShown() then
            local oL, oR = other:GetLeft(), other:GetRight()
            local oT, oB = other:GetTop(), other:GetBottom()
            if oL and oR and oT and oB then
                -- X axis: 4 candidate alignments
                consider(oL - right, "X")  -- this.right touches other.left
                consider(oR - left,  "X")  -- this.left  touches other.right
                consider(oL - left,  "X")  -- left edges align
                consider(oR - right, "X")  -- right edges align
                -- Y axis: 4 candidate alignments
                consider(oT - bottom, "Y") -- this.bottom touches other.top
                consider(oB - top,    "Y") -- this.top    touches other.bottom
                consider(oT - top,    "Y") -- top edges align
                consider(oB - bottom, "Y") -- bottom edges align
            end
        end
    end

    if not bestDX and not bestDY then return false end

    local dx = bestDX or 0
    local dy = bestDY or 0
    local newLeft = left + dx
    local newTop  = top  + dy

    frame:ClearAllPoints()
    if frame == SequenceIconTextFrame then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft, newTop)
    else
        local w, h = frame:GetWidth(), frame:GetHeight()
        if not (w and h) then return false end
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newLeft + w * 0.5, newTop - h * 0.5)
    end
    return true
end

-- ------------------------------------------------------------------------
-- Toggle the linked-tracker drag mode. Bound to Ctrl+RightClick on any of
-- the three tracker frames. Linked = group drag (all three move as one);
-- Unlinked = each frame drags independently. Persists across reloads.
-- ------------------------------------------------------------------------
function GSE.SequenceIconToggleTrackerLinked()
    local opts = EnsureSequenceIconFrameOptions()
    opts.Linked = opts.Linked == false
    if GSE.Print then
        GSE.Print(opts.Linked and "GSE: Tracker frames LINKED (drag any to move all)."
                              or "GSE: Tracker frames UNLINKED (each drags independently).")
    end
end

GSE.SequenceIconLinkedDrag = GSE.SequenceIconLinkedDrag or {}
GSE.SequenceIconLinkedDrag.Frame = GSE.SequenceIconLinkedDrag.Frame or CreateFrame("Frame")
GSE.SequenceIconLinkedDrag.Moved = false

function GSE.SequenceIconGetCursorPositionInUIParent()
    if not GetCursorPosition then return nil, nil end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not cursorX or not cursorY or scale == 0 then return nil, nil end

    return cursorX / scale, cursorY / scale
end

function GSE.SequenceIconUpdateLinkedTrackerGroupDrag(skipButtonCheck)
    local drag = GSE.SequenceIconLinkedDrag
    if not drag or not drag.State then return end
    if not skipButtonCheck and IsMouseButtonDown and not IsMouseButtonDown("RightButton") then
        drag.Frame:Hide()
        drag.SuppressNextToggle = drag.Moved == true
        drag.State = nil
        drag.Moved = false
        if SaveSequenceTextFramePosition then SaveSequenceTextFramePosition() end
        return
    end

    local cursorX, cursorY = GSE.SequenceIconGetCursorPositionInUIParent()
    if not cursorX or not cursorY then return end

    local deltaX = cursorX - drag.State.cursorX
    local deltaY = cursorY - drag.State.cursorY
    if math.abs(deltaX) > 2 or math.abs(deltaY) > 2 then
        drag.Moved = true
    end

    if drag.State.widget then
        GSE.SequenceIconTrackerWidget:ClearAllPoints()
        GSE.SequenceIconTrackerWidget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", drag.State.centerX + deltaX, drag.State.centerY + deltaY)
        return
    end

    for _, entry in ipairs(drag.State.frames) do
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", entry.centerX + deltaX, entry.centerY + deltaY)
    end
end

function GSE.SequenceIconStopLinkedTrackerGroupDrag()
    local drag = GSE.SequenceIconLinkedDrag
    if not drag or not drag.State then return false end

    GSE.SequenceIconUpdateLinkedTrackerGroupDrag(true)
    drag.Frame:Hide()
    drag.State = nil
    if GSE.SequenceIconSaveTrackerWidgetPosition then GSE.SequenceIconSaveTrackerWidgetPosition() end
    if SaveSequenceTextFramePosition then SaveSequenceTextFramePosition() end
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end

    local moved = drag.Moved
    drag.Moved = false
    return moved
end

function GSE.SequenceIconStartLinkedTrackerGroupDrag()
    if not GSE.SequenceIconAreLinkedTrackerFramesLocked() then return false end

    local cursorX, cursorY = GSE.SequenceIconGetCursorPositionInUIParent()
    if not cursorX or not cursorY then return false end

    local centerX, centerY = GSE.SequenceIconTrackerWidget:GetCenter()
    if not centerX or not centerY then return false end

    local drag = GSE.SequenceIconLinkedDrag
    drag.Moved = false
    drag.SuppressNextToggle = false
    drag.State = {
        cursorX = cursorX,
        cursorY = cursorY,
        centerX = centerX,
        centerY = centerY,
        widget = true
    }
    drag.Frame:Show()
    return true
end

GSE.SequenceIconLinkedDrag.Frame:SetScript("OnUpdate", GSE.SequenceIconUpdateLinkedTrackerGroupDrag)
GSE.SequenceIconLinkedDrag.Frame:Hide()

-- ------------------------------------------------------------------------
-- Tracker Group Drag: snap-together movement for the 3 tracker frames.
-- When the user drags ANY of SuccessfulCastFrame, SequenceIconFrame, or
-- SequenceIconTextFrame with the left mouse button, the cursor delta is
-- applied to all three frames so they move as one. Each frame keeps its
-- own SetPoint anchor (independent of the parent widget) so per-frame
-- saved positions still work; the group drag just synchronises movement.
-- ------------------------------------------------------------------------
GSE.SequenceIconTrackerGroupDrag = GSE.SequenceIconTrackerGroupDrag or {
    Frame = CreateFrame("Frame")
}
GSE.SequenceIconTrackerGroupDrag.Frame:Hide()

function GSE.SequenceIconStartTrackerGroupDrag(initiator)
    -- Hybrid drag: the clicked frame uses native :StartMoving() so it tracks
    -- the cursor at engine speed (hardware-synced, no per-frame lag), and the
    -- other two frames are repositioned each OnUpdate to maintain their
    -- captured offsets from the initiator. Much smoother than manually
    -- delta-applying cursor position to every frame.
    if not initiator or not initiator.GetCenter or not initiator.StartMoving then
        return false
    end

    local initiatorCX, initiatorCY = initiator:GetCenter()
    if not initiatorCX or not initiatorCY then return false end

    local followers = {}
    for _, f in ipairs({ SequenceIconFrame, SequenceIconTextFrame, SuccessfulCastFrame }) do
        if f and f ~= initiator then
            local cx, cy = f:GetCenter()
            if cx and cy then
                followers[#followers + 1] = {
                    frame   = f,
                    offsetX = cx - initiatorCX,
                    offsetY = cy - initiatorCY,
                }
                f.GSETrackerDragging = true
            end
        end
    end

    initiator.GSETrackerDragging = true
    initiator:StartMoving()

    GSE.SequenceIconTrackerGroupDrag.State = {
        initiator = initiator,
        followers = followers,
    }
    GSE.SequenceIconTrackerGroupDrag.Frame:Show()
    return true
end

function GSE.SequenceIconStopTrackerGroupDrag()
    local state = GSE.SequenceIconTrackerGroupDrag.State
    if not state then return end

    if state.initiator and state.initiator.StopMovingOrSizing then
        state.initiator:StopMovingOrSizing()
    end

    -- Snap the initiator to the 10 px grid, then propagate the snapped
    -- center to the followers (offsets unchanged) so the whole group lands
    -- on grid coherently.
    if state.initiator then
        if GSE.SequenceIconSnapFrameTo10 then
            GSE.SequenceIconSnapFrameTo10(state.initiator)
        end
        local cx, cy = state.initiator:GetCenter()
        if cx and cy then
            for _, follower in ipairs(state.followers) do
                if follower.frame then
                    follower.frame:ClearAllPoints()
                    follower.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                        cx + follower.offsetX, cy + follower.offsetY)
                end
            end
        end
    end

    -- Persist each frame's final position so it survives /reload.
    if GSE.SequenceIconSaveInternalFramePosition then
        GSE.SequenceIconSaveInternalFramePosition("Icon", SequenceIconFrame)
        GSE.SequenceIconSaveInternalFramePosition("SuccessfulCasts", SuccessfulCastFrame)
    end
    if SaveSequenceTextFramePosition then SaveSequenceTextFramePosition() end

    if state.initiator then state.initiator.GSETrackerDragging = nil end
    for _, follower in ipairs(state.followers) do
        if follower.frame then follower.frame.GSETrackerDragging = nil end
    end

    GSE.SequenceIconTrackerGroupDrag.State = nil
    GSE.SequenceIconTrackerGroupDrag.Frame:Hide()
end

GSE.SequenceIconTrackerGroupDrag.Frame:SetScript("OnUpdate", function()
    local state = GSE.SequenceIconTrackerGroupDrag.State
    if not state or not state.initiator then return end

    -- Bail if the user released the mouse button (covers cases where
    -- OnMouseUp does not fire because the cursor left the frame).
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        GSE.SequenceIconStopTrackerGroupDrag()
        return
    end

    -- Initiator is moved by the engine (StartMoving). Each tick we
    -- read its CURRENT center and reposition the followers to maintain
    -- their captured offsets. No cursor math, no per-frame lag.
    local cx, cy = state.initiator:GetCenter()
    if not cx or not cy then return end

    for _, follower in ipairs(state.followers) do
        if follower.frame then
            follower.frame:ClearAllPoints()
            follower.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                cx + follower.offsetX, cy + follower.offsetY)
        end
    end
end)

local function ApplySequenceTextBackdrop()
    -- BG and border permanently hidden per user preference. The fontstring
    -- lines (with outline+shadow) carry their own legibility on any wallpaper.
    sequenceTextBackground:Hide()
    if SequenceIconTextFrame.SetBackdrop then
        SequenceIconTextFrame:SetBackdrop(nil)
    end
end

local function SetSequenceTextMoveMode(enabled)
    enabled = enabled == true
    if sequenceTextMoveModeEnabled == enabled then return end

    sequenceTextMoveModeEnabled = enabled
    if enabled then
        SequenceIconTextFrame:RegisterForDrag("LeftButton")
    else
        if SequenceIconTextFrame.StopMovingOrSizing then
            SequenceIconTextFrame:StopMovingOrSizing()
        end
        SequenceIconTextFrame.GSETrackerDragging = nil
        SequenceIconTextFrame:RegisterForDrag()
    end
end

local function ShowMoveTooltip()
    if not GameTooltip or not EnsureSequenceIconFrameOptions().Enabled then return end

    local currentOptions = EnsureSequenceIconFrameOptions()
    GameTooltip:SetOwner(SequenceIconFrame, "ANCHOR_CURSOR")
    GameTooltip:SetText("GSE Sequence Icons", 1, 1, 1)
    if currentOptions.Locked then
        GameTooltip:AddLine("Locked", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Unlocked: left-drag to move", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Ctrl + Right Click: Unlink / Link", 0.65, 0.85, 1)
    GameTooltip:AddLine("Alt + Right Click: Lock / Unlock Position", 0.65, 0.85, 1)
    GameTooltip:AddLine("Shift + Right Click: Toggle X / Y Layout", 0.65, 0.85, 1)
    GameTooltip:Show()
end

local function ShowSequenceTextTooltip()
    if not GameTooltip or not EnsureSequenceIconFrameOptions().Enabled then return end

    local currentOptions = EnsureSequenceIconFrameOptions()
    GameTooltip:SetOwner(SequenceIconTextFrame, "ANCHOR_CURSOR")
    GameTooltip:SetText("GSE Sequence Text Info", 1, 1, 1)
    if currentOptions.TextLocked then
        GameTooltip:AddLine("Locked", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Unlocked: left-drag to move", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag the bottom-right corner to resize", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Ctrl + Right Click: Unlink / Link", 0.65, 0.85, 1)
    GameTooltip:AddLine("Alt + Right Click: Lock / Unlock Position", 0.65, 0.85, 1)
    GameTooltip:AddLine("Shift + Right Click: Toggle X / Y Layout", 0.65, 0.85, 1)
    GameTooltip:Show()
end

local function HideSequenceTextTooltip()
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == SequenceIconTextFrame then
        GameTooltip:Hide()
    end
end

local function HideMoveTooltip()
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == SequenceIconFrame then
        GameTooltip:Hide()
    end
end

local function ShowSuccessfulCastTooltip()
    if not GameTooltip or not IsSuccessfulCastFrameEnabled() then return end

    local currentOptions = EnsureSequenceIconFrameOptions()
    GameTooltip:SetOwner(SuccessfulCastFrame, "ANCHOR_CURSOR")
    GameTooltip:SetText("GSE Successful Casts", 1, 1, 1)
    GameTooltip:AddLine("Last successful GSE cast", 0.8, 0.8, 0.8)
    if successfulCastName and successfulCastName ~= "" then
        GameTooltip:AddLine(successfulCastName, 0.45, 0.9, 1)
    end
    if currentOptions.SuccessfulCastsLocked then
        GameTooltip:AddLine("Locked", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Unlocked: left-drag to move", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Ctrl + Right Click: Unlink / Link", 0.65, 0.85, 1)
    GameTooltip:AddLine("Alt + Right Click: Lock / Unlock Position", 0.65, 0.85, 1)
    GameTooltip:AddLine("Shift + Right Click: Toggle X / Y Layout", 0.65, 0.85, 1)
    GameTooltip:Show()
end

local function HideSuccessfulCastTooltip()
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == SuccessfulCastFrame then
        GameTooltip:Hide()
    end
end

local function ShowAssistedSuccessTooltip()
    if not GameTooltip or not IsAssistedSuccessFrameEnabled() then return end

    local currentOptions = EnsureSequenceIconFrameOptions()
    GameTooltip:SetOwner(AssistedSuccessFrame, "ANCHOR_CURSOR")
    GameTooltip:SetText("GSE 2-Hit Proc", 1, 1, 1)
    if heldAssistedSuccessIconID then
        GameTooltip:AddLine("Assisted Highlight + Successful Cast", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Out of combat placement marker", 0.8, 0.8, 0.8)
    end
    if heldAssistedSuccessIconID and heldAssistedSuccessName and heldAssistedSuccessName ~= "" then
        GameTooltip:AddLine(heldAssistedSuccessName, 0.25, 1, 0.45)
    end
    if currentOptions.AssistedSuccessLocked then
        GameTooltip:AddLine("Locked", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Unlocked: left-drag to move", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function HideAssistedSuccessTooltip()
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == AssistedSuccessFrame then
        GameTooltip:Hide()
    end
end

local function RefreshMoveMode()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local unlocked = currentOptions.Enabled and currentOptions.Locked == false
    local armedForToggle = currentOptions.Enabled and currentOptions.Locked == true and IsTrackerToggleChordDown()

    SequenceIconFrame:EnableMouse(unlocked or armedForToggle)
    if unlocked then SequenceIconFrame:RegisterForDrag("LeftButton") end
    SetMoveMode(unlocked)

    if SequenceIconFrame.IsMouseOver and SequenceIconFrame:IsMouseOver() and (unlocked or armedForToggle) then
        ShowMoveTooltip()
    else
        HideMoveTooltip()
    end
end

local function RefreshSequenceTextMoveMode()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local unlocked = currentOptions.Enabled and currentOptions.TextLocked == false
    local armedForToggle = currentOptions.Enabled and currentOptions.TextLocked == true and IsTrackerToggleChordDown()

    SequenceIconTextFrame:EnableMouse(unlocked or armedForToggle)
    if unlocked then SequenceIconTextFrame:RegisterForDrag("LeftButton") end
    SetSequenceTextMoveMode(unlocked)
    ApplySequenceTextBackdrop()

    if SequenceIconTextFrame.IsMouseOver and SequenceIconTextFrame:IsMouseOver() and (unlocked or armedForToggle) then
        ShowSequenceTextTooltip()
    else
        HideSequenceTextTooltip()
    end
end

local function RefreshSuccessfulCastMoveMode()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local enabled = IsSuccessfulCastFrameEnabled()
    local unlocked = enabled and currentOptions.SuccessfulCastsLocked == false
    local armedForToggle = enabled and currentOptions.SuccessfulCastsLocked == true and IsTrackerToggleChordDown()

    SuccessfulCastFrame:EnableMouse(unlocked or armedForToggle)
    if unlocked then SuccessfulCastFrame:RegisterForDrag("LeftButton") end
    SetSuccessfulCastMoveMode(unlocked)

    if SuccessfulCastFrame.IsMouseOver and SuccessfulCastFrame:IsMouseOver() and (unlocked or armedForToggle) then
        ShowSuccessfulCastTooltip()
    else
        HideSuccessfulCastTooltip()
    end
end

RefreshAssistedSuccessMoveMode = function()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local enabled = IsAssistedSuccessFrameEnabled() and (heldAssistedSuccessIconID ~= nil or not IsPlayerInCombat())
    local unlocked = enabled and currentOptions.AssistedSuccessLocked == false
    local armedForToggle = enabled and currentOptions.AssistedSuccessLocked == true and IsTrackerToggleChordDown()

    AssistedSuccessFrame:EnableMouse(unlocked or armedForToggle)
    if unlocked then AssistedSuccessFrame:RegisterForDrag("LeftButton") end
    SetAssistedSuccessMoveMode(unlocked)
    ApplyAssistedSuccessBackdrop()

    if AssistedSuccessFrame.IsMouseOver and AssistedSuccessFrame:IsMouseOver() and (unlocked or armedForToggle) then
        ShowAssistedSuccessTooltip()
    else
        HideAssistedSuccessTooltip()
    end
end

local function RefreshMoveModes()
    RefreshMoveMode()
    RefreshSequenceTextMoveMode()
    RefreshSuccessfulCastMoveMode()
    RefreshAssistedSuccessMoveMode()
    if GSE.SequenceIconTrackerWidget then
        GSE.SequenceIconTrackerWidget:EnableMouse(false)
    end
    if GSE.SequenceIconRefreshTrackerWidgetBackdrop then GSE.SequenceIconRefreshTrackerWidgetBackdrop() end
end

function GSE.SequenceIconToggleTrackerFrameLock(optionKey, showTooltip)
    if optionKey == nil or not IsControlChordDown() then return false end
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled then return false end

    currentOptions[optionKey] = currentOptions[optionKey] == false
    RefreshMoveModes()
    if showTooltip then showTooltip() end
    return true
end

-- ------------------------------------------------------------------------
-- Toggle position-lock on all tracker frames as a single group. When
-- LOCKED, frames ignore mouse input (LeftClick passes through, drag is
-- disabled). Bound to Alt+RightClick on any of the three tracker frames.
-- ------------------------------------------------------------------------
function GSE.SequenceIconToggleTrackerLocked()
    local currentlyLocked = true
    if GSE.SequenceIconAreLinkedTrackerFramesLocked then
        currentlyLocked = GSE.SequenceIconAreLinkedTrackerFramesLocked() == true
    end
    local newLocked = not currentlyLocked
    if GSE.SequenceIconSetLinkedTrackerLockState then
        GSE.SequenceIconSetLinkedTrackerLockState(newLocked)
    end
    RefreshMoveModes()
    if GSE.Print then
        GSE.Print(newLocked and "GSE: Tracker frames LOCKED (positions fixed)."
                            or "GSE: Tracker frames UNLOCKED (LeftClick to drag).")
    end
end


GSE.SequenceIconTrackerWidget:SetScript("OnDragStart", function(self)
end)
GSE.SequenceIconTrackerWidget:SetScript("OnDragStop", function(self)
end)

SequenceIconFrame:SetScript("OnEnter", ShowMoveTooltip)
SequenceIconFrame:SetScript("OnLeave", HideMoveTooltip)
SequenceIconFrame:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
        if GSE.SequenceIconSwapTrackerLayout then GSE.SequenceIconSwapTrackerLayout() end
        return
    end
    if button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
        if GSE.SequenceIconToggleTrackerLinked then GSE.SequenceIconToggleTrackerLinked() end
        return
    end
    if button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
        if GSE.SequenceIconToggleTrackerLocked then GSE.SequenceIconToggleTrackerLocked() end
        return
    end
    if button == "LeftButton" and moveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStartTrackerGroupDrag(SequenceIconFrame)
        else
            SequenceIconFrame.GSETrackerDragging = true
            SequenceIconFrame:StartMoving()
        end
        return
    end
end)
SequenceIconFrame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and moveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStopTrackerGroupDrag()
        else
            SequenceIconFrame:StopMovingOrSizing()
            SequenceIconFrame.GSETrackerDragging = nil
            local snapped = GSE.SequenceIconSnapFrameToNeighbors
                            and GSE.SequenceIconSnapFrameToNeighbors(SequenceIconFrame)
            if not snapped and GSE.SequenceIconSnapFrameTo10 then
                GSE.SequenceIconSnapFrameTo10(SequenceIconFrame)
            end
            if GSE.SequenceIconSaveInternalFramePosition then
                GSE.SequenceIconSaveInternalFramePosition("Icon", SequenceIconFrame)
            end
        end
        ShowMoveTooltip()
        return
    end
end)

SequenceIconTextFrame:SetScript("OnEnter", ShowSequenceTextTooltip)
SequenceIconTextFrame:SetScript("OnLeave", HideSequenceTextTooltip)
SequenceIconTextFrame:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
        if GSE.SequenceIconSwapTrackerLayout then GSE.SequenceIconSwapTrackerLayout() end
        return
    end
    if button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
        if GSE.SequenceIconToggleTrackerLinked then GSE.SequenceIconToggleTrackerLinked() end
        return
    end
    if button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
        if GSE.SequenceIconToggleTrackerLocked then GSE.SequenceIconToggleTrackerLocked() end
        return
    end
    if button == "LeftButton" and sequenceTextMoveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStartTrackerGroupDrag(SequenceIconTextFrame)
        else
            SequenceIconTextFrame.GSETrackerDragging = true
            SequenceIconTextFrame:StartMoving()
        end
        return
    end
end)
SequenceIconTextFrame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and sequenceTextMoveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStopTrackerGroupDrag()
        else
            SequenceIconTextFrame:StopMovingOrSizing()
            SequenceIconTextFrame.GSETrackerDragging = nil
            local snapped = GSE.SequenceIconSnapFrameToNeighbors
                            and GSE.SequenceIconSnapFrameToNeighbors(SequenceIconTextFrame)
            if not snapped and GSE.SequenceIconSnapFrameTo10 then
                GSE.SequenceIconSnapFrameTo10(SequenceIconTextFrame)
            end
            if SaveSequenceTextFramePosition then SaveSequenceTextFramePosition() end
        end
        ShowSequenceTextTooltip()
        return
    end
end)

SuccessfulCastFrame:SetScript("OnEnter", ShowSuccessfulCastTooltip)
SuccessfulCastFrame:SetScript("OnLeave", HideSuccessfulCastTooltip)
SuccessfulCastFrame:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
        if GSE.SequenceIconSwapTrackerLayout then GSE.SequenceIconSwapTrackerLayout() end
        return
    end
    if button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
        if GSE.SequenceIconToggleTrackerLinked then GSE.SequenceIconToggleTrackerLinked() end
        return
    end
    if button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
        if GSE.SequenceIconToggleTrackerLocked then GSE.SequenceIconToggleTrackerLocked() end
        return
    end
    if button == "LeftButton" and successfulCastMoveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStartTrackerGroupDrag(SuccessfulCastFrame)
        else
            SuccessfulCastFrame.GSETrackerDragging = true
            SuccessfulCastFrame:StartMoving()
        end
        return
    end
end)
SuccessfulCastFrame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and successfulCastMoveModeEnabled then
        local opts = EnsureSequenceIconFrameOptions()
        if opts.Linked ~= false then
            GSE.SequenceIconStopTrackerGroupDrag()
        else
            SuccessfulCastFrame:StopMovingOrSizing()
            SuccessfulCastFrame.GSETrackerDragging = nil
            local snapped = GSE.SequenceIconSnapFrameToNeighbors
                            and GSE.SequenceIconSnapFrameToNeighbors(SuccessfulCastFrame)
            if not snapped and GSE.SequenceIconSnapFrameTo10 then
                GSE.SequenceIconSnapFrameTo10(SuccessfulCastFrame)
            end
            if GSE.SequenceIconSaveInternalFramePosition then
                GSE.SequenceIconSaveInternalFramePosition("SuccessfulCasts", SuccessfulCastFrame)
            end
        end
        ShowSuccessfulCastTooltip()
        return
    end
end)

AssistedSuccessFrame:SetScript("OnEnter", ShowAssistedSuccessTooltip)
AssistedSuccessFrame:SetScript("OnLeave", HideAssistedSuccessTooltip)
AssistedSuccessFrame:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and assistedSuccessMoveModeEnabled then
        AssistedSuccessFrame.GSETrackerDragging = true
        AssistedSuccessFrame:StartMoving()
        return
    end
end)
AssistedSuccessFrame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and assistedSuccessMoveModeEnabled then
        AssistedSuccessFrame:StopMovingOrSizing()
        AssistedSuccessFrame.GSETrackerDragging = nil
        if GSE.SequenceIconSaveInternalFramePosition then GSE.SequenceIconSaveInternalFramePosition("AssistedSuccess", AssistedSuccessFrame) end
        ShowAssistedSuccessTooltip()
        return
    end
end)

local function MarkGSEActivity(sequence, buttonName, mods)
    if not sequence then return end

    if activeSequence ~= sequence then
        lastSequenceButtonName = nil
        lastSequenceMods = nil
    end

    activeSequence = sequence
    if buttonName then lastSequenceButtonName = buttonName end
    if mods then lastSequenceMods = mods end
    lastGSEActivitySequence = sequence
    lastGSEActivityTime = GetTime and GetTime() or 0
    pendingSuccessfulCast = true
end

local function IsFallbackIcon(icon)
    return GSE.IsFallbackIcon(icon)
end

local function FindSequenceObject(sequence)
    if type(sequence) ~= "string" or sequence == "" then return nil end

    if GSE.Library then
        for _, bucket in pairs(GSE.Library) do
            if type(bucket) == "table" and type(bucket[sequence]) == "table" then
                return bucket[sequence]
            end
        end
    end
end

function GSE.SequenceIconGetMetadata(sequence)
    local seq = FindSequenceObject(sequence)
    if type(seq) ~= "table" then return nil end
    return seq.MetaData or seq.metadata
end

function GSE.SequenceIconIsGlobalSequence(sequence)
    if type(sequence) ~= "string" or sequence == "" then return false end
    if GSE.Library and type(GSE.Library[0]) == "table" and type(GSE.Library[0][sequence]) == "table" then return true end

    local metadata = GSE.SequenceIconGetMetadata(sequence)
    local specID = tonumber(metadata and (metadata.SpecID or metadata.specID or metadata.specid))
    return specID == 0
end

function GSE.SequenceIconIsAccountMacro(sequence)
    if type(sequence) ~= "string" or sequence == "" then return false end

    if GetMacroIndexByName and MAX_ACCOUNT_MACROS then
        local macroIndex = GetMacroIndexByName(sequence)
        if macroIndex and macroIndex > 0 and macroIndex <= MAX_ACCOUNT_MACROS then return true end
    end

    local macro = GSEMacros and GSEMacros[sequence]
    return type(macro) == "table" and macro.name == sequence
end

function GSE.SequenceIconMetadataMatchesCurrentSpec(sequence)
    if GSE.SequenceIconIsGlobalSequence(sequence) or GSE.SequenceIconIsAccountMacro(sequence) then return true end

    local metadata = GSE.SequenceIconGetMetadata(sequence)
    if type(metadata) ~= "table" then return nil end

    local specID = tonumber(metadata.SpecID or metadata.specID or metadata.specid)
    if not specID then return nil end
    if specID == 0 then return true end

    if GSE.GameMode and GSE.GameMode < 5 then
        return specID == (GSE.GetCurrentClassID and GSE.GetCurrentClassID())
    end

    local currentSpecID = GSE.GetCurrentSpecID and GSE.GetCurrentSpecID()
    return currentSpecID and specID == currentSpecID
end

local function IsValidSequence(sequence)
    if type(sequence) ~= "string" or sequence == "" then return false end
    if GSE.SequencesExec and GSE.SequencesExec[sequence] then return true end
    if _G[sequence] and _G[sequence].GetAttribute then return true end
    return FindSequenceObject(sequence) ~= nil
end

local function GetPrettySequenceName(sequence)
    local seq = FindSequenceObject(sequence)
    if type(seq) == "table" then
        local metadata = seq.MetaData or seq.metadata
        if type(metadata) == "table" then
            local name = metadata.Name or metadata.name
            if type(name) == "string" and name ~= "" then return name end
        end
    end

    return sequence
end

local function GetPrettySequenceNameWithVersion(sequence)
    if type(sequence) ~= "string" or sequence == "" then return "None" end

    local sequenceName = GetPrettySequenceName(sequence)
    local version
    if GSE.GetActiveSequenceVersion then
        local ok, result = pcall(GSE.GetActiveSequenceVersion, sequence)
        if ok and result ~= nil then version = result end
    end

    if version == nil then
        local seq = FindSequenceObject(sequence)
        local metadata = type(seq) == "table" and (seq.MetaData or seq.metadata)
        if type(metadata) == "table" and metadata.Default ~= nil then version = metadata.Default end
    end

    if version ~= nil and tostring(version) ~= "" then
        return tostring(sequenceName) .. ":" .. tostring(version)
    end

    return sequenceName
end

local function TryGetField(button, key)
    if not button then return nil end
    local value = rawget(button, key)
    if type(value) == "string" and value ~= "" then return value end
end

local function TryGetAttribute(button, attribute)
    if not (button and button.GetAttribute) then return nil end
    local ok, value = pcall(button.GetAttribute, button, attribute)
    if ok and type(value) == "string" and value ~= "" then return value end
end

local function GetCurrentSpecKey()
    if GSE.GameMode and GSE.GameMode < 7 then return "1" end

    local spec
    if GSE.GameMode and GSE.GameMode >= 12 then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        spec = getSpec and getSpec()
    elseif GetSpecialization then
        spec = GetSpecialization()
    end

    return tostring(spec or 1)
end

local function GetCurrentLoadoutKey()
    if not (C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and GSE.GetCurrentSpecID) then return nil end

    local specID = GSE.GetCurrentSpecID()
    if not specID then return nil end

    local loadoutID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if not loadoutID then return nil end

    return tostring(loadoutID)
end

local function ResolveUsedSequence(buttonName)
    if type(buttonName) ~= "string" or buttonName == "" then return nil end

    if IsValidSequence(buttonName) then
        return buttonName
    end

    if GSE.ButtonOverrides and type(GSE.ButtonOverrides[buttonName]) == "string" and IsValidSequence(GSE.ButtonOverrides[buttonName]) then
        return GSE.ButtonOverrides[buttonName]
    end

    local used = GSE.UsedSequences and GSE.UsedSequences[buttonName]
    if type(used) == "string" and IsValidSequence(used) then
        return used
    end

    if type(used) == "table" then
        local candidates = {used.Sequence, used.sequence, used.GSESequence, used.Name, used.name, used.Macro, used.macro, used[1]}
        for _, candidate in ipairs(candidates) do
            if type(candidate) == "string" and IsValidSequence(candidate) then
                return candidate
            end
        end
    end
end

local function ResolveSequenceKey(button)
    if not button then return nil end

    for _, key in ipairs(FIELD_KEYS) do
        local value = TryGetField(button, key)
        if IsValidSequence(value) then return value end
    end

    for _, attribute in ipairs(ATTR_KEYS) do
        local value = TryGetAttribute(button, attribute)
        if IsValidSequence(value) then return value end
    end

    local buttonName = button.GetName and button:GetName()
    return ResolveUsedSequence(buttonName)
end

local function AddUniqueValue(values, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then return end

    seen[value] = true
    table.insert(values, value)
end

local function BindingTargetMatches(target, sequence, buttonName)
    if type(target) ~= "string" or target == "" then return false end
    if target == sequence or target == buttonName then return true end
    if GSE.ButtonOverrides and GSE.ButtonOverrides[target] == sequence then return true end
    return false
end

local function AddMatchingGSEKeyBindings(values, seen, bindings, sequence, buttonName)
    if type(bindings) ~= "table" then return end

    for key, target in pairs(bindings) do
        if key ~= "LoadOuts" and BindingTargetMatches(target, sequence, buttonName) then
            AddUniqueValue(values, seen, key)
        end
    end
end

local function GetNativeActionCommand(buttonName)
    if type(buttonName) ~= "string" then return nil end

    local index = buttonName:match("^ActionButton(%d+)$")
    if index then return "ACTIONBUTTON" .. index end

    index = buttonName:match("^MultiBarBottomLeftButton(%d+)$")
    if index then return "MULTIACTIONBAR1BUTTON" .. index end

    index = buttonName:match("^MultiBarBottomRightButton(%d+)$")
    if index then return "MULTIACTIONBAR2BUTTON" .. index end

    index = buttonName:match("^MultiBarRightButton(%d+)$")
    if index then return "MULTIACTIONBAR3BUTTON" .. index end

    index = buttonName:match("^MultiBarLeftButton(%d+)$")
    if index then return "MULTIACTIONBAR4BUTTON" .. index end

    index = buttonName:match("^MultiBar5Button(%d+)$")
    if index then return "MULTIACTIONBAR5BUTTON" .. index end

    index = buttonName:match("^MultiBar6Button(%d+)$")
    if index then return "MULTIACTIONBAR6BUTTON" .. index end

    index = buttonName:match("^MultiBar7Button(%d+)$")
    if index then return "MULTIACTIONBAR7BUTTON" .. index end
end

local function AddBindingKeysForCommand(values, seen, command)
    if type(command) ~= "string" or command == "" or not GetBindingKey then return end

    local keys = {GetBindingKey(command)}
    for _, key in ipairs(keys) do
        AddUniqueValue(values, seen, key)
    end
end

local function AddBindingKeysForButton(values, seen, buttonName)
    if type(buttonName) ~= "string" or buttonName == "" then return end

    local button = _G[buttonName]
    if button and type(button.commandName) == "string" then
        AddBindingKeysForCommand(values, seen, button.commandName)
    end

    AddBindingKeysForCommand(values, seen, GetNativeActionCommand(buttonName))
    AddBindingKeysForCommand(values, seen, "CLICK " .. buttonName .. ":LeftButton")
    AddBindingKeysForCommand(values, seen, "CLICK " .. buttonName .. ":AnyButton")
end

local function AddActionBarOverrideKeys(values, seen, sequence, buttonName)
    if buttonName then
        AddBindingKeysForButton(values, seen, buttonName)
    end

    if GSE.ButtonOverrides then
        for overrideButton, overrideSequence in pairs(GSE.ButtonOverrides) do
            if overrideSequence == sequence then
                AddBindingKeysForButton(values, seen, overrideButton)
            end
        end
    end

    local actionBarBinds = GSE_C and GSE_C["ActionBarBinds"]
    if type(actionBarBinds) ~= "table" then return end

    local specKey = GetCurrentSpecKey()
    local specs = actionBarBinds["Specialisations"]
    if type(specs) == "table" then
        local specBinds = specs[specKey]
        if type(specBinds) == "table" then
            for _, savedBind in pairs(specBinds) do
                if type(savedBind) == "table" and savedBind.Sequence == sequence then
                    AddBindingKeysForButton(values, seen, savedBind.Bind)
                end
            end
        end
    end

    local loadoutKey = GetCurrentLoadoutKey()
    local loadouts = actionBarBinds["LoadOuts"]
    local loadoutBinds = loadoutKey and loadouts and loadouts[specKey] and loadouts[specKey][loadoutKey]
    if type(loadoutBinds) == "table" then
        for _, savedBind in pairs(loadoutBinds) do
            if type(savedBind) == "table" and savedBind.Sequence == sequence then
                AddBindingKeysForButton(values, seen, savedBind.Bind)
            end
        end
    end
end

local function FormatSpamKey(sequence, mods, explicitButtonName)
    local values = {}
    local seen = {}
    local buttonName = explicitButtonName or lastSequenceButtonName

    if sequence and GSE_C and type(GSE_C["KeyBindings"]) == "table" then
        local specKey = GetCurrentSpecKey()
        local specBinds = GSE_C["KeyBindings"][specKey]
        AddMatchingGSEKeyBindings(values, seen, specBinds, sequence, buttonName)

        local loadoutKey = GetCurrentLoadoutKey()
        local loadoutBinds = loadoutKey and specBinds and specBinds["LoadOuts"] and specBinds["LoadOuts"][loadoutKey]
        AddMatchingGSEKeyBindings(values, seen, loadoutBinds, sequence, buttonName)
    end

    if sequence then
        AddActionBarOverrideKeys(values, seen, sequence, buttonName)
    end

    if #values > 0 then return table.concat(values, ", ") end
    if mods and type(mods.MOUSEBUTTON) == "string" and mods.MOUSEBUTTON ~= "" then return mods.MOUSEBUTTON end
    return "None"
end

function GSE.SequenceIconResolveSpamKey(sequence, mods, buttonName)
    return FormatSpamKey(sequence, mods, buttonName)
end

local function PushKeyHistory(keyText, sequence)
    if type(keyText) ~= "string" or keyText == "" or keyText == "None" then return end

    local now = GetTime and GetTime() or 0
    if GSE.SequenceIconLastKeyHistoryText == keyText
        and GSE.SequenceIconLastKeyHistorySequence == sequence
        and (now - (GSE.SequenceIconLastKeyHistoryTime or 0)) < 0.08 then
        return
    end
    GSE.SequenceIconLastKeyHistoryText = keyText
    GSE.SequenceIconLastKeyHistorySequence = sequence
    GSE.SequenceIconLastKeyHistoryTime = now

    table.insert(KeyHistoryEntries, 1, keyText)
    while #KeyHistoryEntries > Statics.TrackerConfig.KeyHistoryLimit do
        table.remove(KeyHistoryEntries)
    end
end

local function FormatActualKeyPress(sequence, mods, spamKey)
    if type(spamKey) == "string" and spamKey ~= "" then return spamKey end
    return FormatSpamKey(sequence, mods)
end

local function SetActiveSpamKey(sequence, keyText)
    if not sequence then return end

    activeSpamKeyClearSerial = activeSpamKeyClearSerial + 1
    activeSpamKeySequence = sequence
    activeSpamKeyText = (type(keyText) == "string" and keyText ~= "") and keyText or "None"
    activeSpamKeyExpiresAt = (GetTime and GetTime() or 0) + Statics.TrackerConfig.ActiveSpamKeyHoldSeconds

    local serial = activeSpamKeyClearSerial
    C_Timer.After(Statics.TrackerConfig.ActiveSpamKeyHoldSeconds + 0.02, function()
        if serial ~= activeSpamKeyClearSerial then return end
        if (GetTime and GetTime() or 0) < activeSpamKeyExpiresAt then return end
        activeSpamKeyText = nil
        activeSpamKeySequence = nil
        activeSpamKeyExpiresAt = 0
        if UpdateSequenceText then
            UpdateSequenceText(sequence)
        end
    end)
end

local function IsFreshClickSerial(serials, sequence, buttonName, clickSerial)
    local serial = tonumber(clickSerial or 0) or 0
    if serial <= 0 then return false end

    local key = tostring(buttonName or sequence or "")
    if key == "" then return false end
    if serials[key] == serial then return false end

    serials[key] = serial
    return true
end

local function GetActiveSpamKey(sequence)
    if not activeSpamKeyText or activeSpamKeyText == "" then return "None", false end
    if sequence and activeSpamKeySequence ~= sequence then return "None", false end
    if (GetTime and GetTime() or 0) > activeSpamKeyExpiresAt then return "None", false end
    return activeSpamKeyText, true
end

function GSE.SequenceIconParseModifierString(rawMods)
    if type(rawMods) ~= "string" or rawMods == "" then return nil end

    local mods = {}
    for part in string.gmatch(rawMods .. "|", "([^|]*)|") do
        if part ~= "" then
            local key, value = string.match(part, "^([^=]+)=(.*)$")
            if key and key ~= "" then
                if key == "MOUSEBUTTON" then
                    mods[key] = value
                else
                    mods[key] = value == "true"
                end
            end
        end
    end

    return mods
end

function GSE.SequenceIconReadGameMods(fallbackMods, hardwareEvent)
    local mods = {}

    local function ReadMod(api, fallback)
        if type(api) == "function" then
            local ok, value = pcall(api)
            if ok then return value == true end
        end
        return fallback == true
    end

    fallbackMods = type(fallbackMods) == "table" and fallbackMods or {}
    mods.RALT = ReadMod(IsRightAltKeyDown, fallbackMods.RALT)
    mods.LALT = ReadMod(IsLeftAltKeyDown, fallbackMods.LALT)
    mods.AALT = ReadMod(IsAltKeyDown, fallbackMods.AALT)
    mods.RCTRL = ReadMod(IsRightControlKeyDown, fallbackMods.RCTRL)
    mods.LCTRL = ReadMod(IsLeftControlKeyDown, fallbackMods.LCTRL)
    mods.ACTRL = ReadMod(IsControlKeyDown, fallbackMods.ACTRL)
    mods.RSHIFT = ReadMod(IsRightShiftKeyDown, fallbackMods.RSHIFT)
    mods.LSHIFT = ReadMod(IsLeftShiftKeyDown, fallbackMods.LSHIFT)
    mods.ASHIFT = ReadMod(IsShiftKeyDown, fallbackMods.ASHIFT)
    mods.AMOD = ReadMod(IsModifierKeyDown, fallbackMods.AMOD)
    mods.MOUSEBUTTON = (type(hardwareEvent) == "string" and hardwareEvent ~= "" and hardwareEvent) or fallbackMods.MOUSEBUTTON

    return mods
end

function GSE.SequenceIconCaptureMods(sequence, mods, buttonName, spamKey, hardwareEvent, clickSerial)
    if not sequence or type(mods) ~= "table" then return nil end

    local hasFreshClick = IsFreshClickSerial(lastCapturedClickSerials, sequence, buttonName, clickSerial)
    local hasFreshInput = hasFreshClick or (type(spamKey) == "string" and spamKey ~= "") or (type(hardwareEvent) == "string" and hardwareEvent ~= "")
    if not hasFreshInput then return nil end

    mods = GSE.SequenceIconReadGameMods(mods, hardwareEvent)
    MarkGSEActivity(sequence, buttonName, mods)
    local keyText = FormatActualKeyPress(sequence, mods, spamKey or (hasFreshClick and FormatSpamKey(sequence, mods, buttonName)))
    SetActiveSpamKey(sequence, keyText)
    PushKeyHistory(hardwareEvent, sequence)
    activeSequence = sequence
    return keyText
end

function GSE.SequenceIconMatchesCurrentSpec(sequence, buttonName)
    if not sequence then return false end

    local metadataMatch = GSE.SequenceIconMetadataMatchesCurrentSpec(sequence)
    if metadataMatch ~= nil then return metadataMatch end

    local specKey = GetCurrentSpecKey()
    local loadoutKey = GetCurrentLoadoutKey()

    local function BindingTableMatches(bindings)
        if type(bindings) ~= "table" then return false end
        for key, target in pairs(bindings) do
            if key ~= "LoadOuts" and BindingTargetMatches(target, sequence, buttonName) then
                return true
            end
        end
        return false
    end

    local function ActionBarTableMatches(bindings)
        if type(bindings) ~= "table" then return false end
        for _, savedBind in pairs(bindings) do
            if type(savedBind) == "table" and savedBind.Sequence == sequence then
                return true
            end
        end
        return false
    end

    local keyBindings = GSE_C and type(GSE_C["KeyBindings"]) == "table" and GSE_C["KeyBindings"]
    local currentSpecBinds = specKey and keyBindings and keyBindings[specKey]
    if BindingTableMatches(currentSpecBinds) then return true end
    if loadoutKey and type(currentSpecBinds) == "table" and BindingTableMatches(currentSpecBinds["LoadOuts"] and currentSpecBinds["LoadOuts"][loadoutKey]) then return true end

    local actionBarBinds = GSE_C and type(GSE_C["ActionBarBinds"]) == "table" and GSE_C["ActionBarBinds"]
    local currentActionSpecBinds = actionBarBinds and actionBarBinds["Specialisations"] and specKey and actionBarBinds["Specialisations"][specKey]
    if ActionBarTableMatches(currentActionSpecBinds) then return true end
    local currentActionLoadoutBinds = actionBarBinds and actionBarBinds["LoadOuts"] and specKey and loadoutKey
        and actionBarBinds["LoadOuts"][specKey] and actionBarBinds["LoadOuts"][specKey][loadoutKey]
    if ActionBarTableMatches(currentActionLoadoutBinds) then return true end

    if type(currentSpecBinds) == "table" or type(currentActionSpecBinds) == "table" or type(currentActionLoadoutBinds) == "table" then
        return false
    end

    if keyBindings then
        for otherSpec, bindings in pairs(keyBindings) do
            if tostring(otherSpec) ~= tostring(specKey) and (BindingTableMatches(bindings)
                or (type(bindings) == "table" and bindings["LoadOuts"] and loadoutKey and BindingTableMatches(bindings["LoadOuts"][loadoutKey]))) then
                return false
            end
        end
    end

    if actionBarBinds then
        local specs = actionBarBinds["Specialisations"]
        if type(specs) == "table" then
            for otherSpec, bindings in pairs(specs) do
                if tostring(otherSpec) ~= tostring(specKey) and ActionBarTableMatches(bindings) then
                    return false
                end
            end
        end

        local loadouts = actionBarBinds["LoadOuts"]
        if type(loadouts) == "table" then
            for otherSpec, specLoadouts in pairs(loadouts) do
                if tostring(otherSpec) ~= tostring(specKey) and type(specLoadouts) == "table" then
                    for _, bindings in pairs(specLoadouts) do
                        if ActionBarTableMatches(bindings) then return false end
                    end
                end
            end
        end
    end

    if buttonName and GSE.ButtonOverrides and GSE.ButtonOverrides[buttonName] == sequence then return true end

    return true
end

function GSE.SequenceIconShouldAcceptSequence(sequence, directInput, buttonName)
    if not sequence then return false end
    if not GSE.SequenceIconMatchesCurrentSpec(sequence, buttonName) then return false end
    if directInput then return true end
    if not activeSequence or activeSequence == sequence then return true end

    local now = GetTime and GetTime() or 0
    if lastGSEActivitySequence == activeSequence and (now - lastGSEActivityTime) <= Statics.TrackerConfig.SuccessCastWindow then
        return false
    end

    return true
end

-- ------------------------------------------------------------------------
-- Smart swap between Layout X and Layout Y. Tracks the currently-active
-- slot in opts.ActiveLayout and flips to the other one on each call.
-- If the target slot has no layout saved yet, captures the current state
-- into that slot (so the first click on a fresh install becomes a save).
-- ------------------------------------------------------------------------
function GSE.SequenceIconSwapTrackerLayout()
    local opts = EnsureSequenceIconFrameOptions()
    local current = opts.ActiveLayout == "Y" and "Y" or "X"
    local target  = (current == "X") and "Y" or "X"

    if GSE.SequenceIconApplyLayout and GSE.SequenceIconApplyLayout(target) then
        opts.ActiveLayout = target
        if GSE.Print then GSE.Print("Swapped to Tracker Layout " .. target .. ".") end
        return target
    end

    -- Target slot empty -- capture current state into it.
    if GSE.SequenceIconSaveLayout and GSE.SequenceIconSaveLayout(target) then
        opts.ActiveLayout = target
        if GSE.Print then
            GSE.Print("Layout " .. target .. " was empty -- captured current positions as Layout " .. target .. ". Click again to swap back to " .. current .. ".")
        end
        return target
    end
    return nil
end

local function FormatModKeys(mods)
    if type(mods) ~= "table" then return "None" end

    local values = {}
    if mods.LCTRL then table.insert(values, "LCtrl") end
    if mods.RCTRL then table.insert(values, "RCtrl") end
    if mods.ACTRL and not mods.LCTRL and not mods.RCTRL then table.insert(values, "Ctrl") end
    if mods.LALT then table.insert(values, "LAlt") end
    if mods.RALT then table.insert(values, "RAlt") end
    if mods.AALT and not mods.LALT and not mods.RALT then table.insert(values, "Alt") end
    if mods.LSHIFT then table.insert(values, "LShift") end
    if mods.RSHIFT then table.insert(values, "RShift") end
    if mods.ASHIFT and not mods.LSHIFT and not mods.RSHIFT then table.insert(values, "Shift") end

    if #values == 0 and mods.AMOD then return "Any" end
    if #values == 0 then return "None" end
    return table.concat(values, "+")
end

local function FormatCombatState()
    if IsPlayerInCombat() then
        return "|cffff4040Combat|r"
    end

    return "|cff40ff40No Combat|r"
end

local function LayoutSequenceTextLines(textWidth)
    local previousLine
    local availableHeight = math.max(0, (SequenceIconTextFrame:GetHeight() or GSE.SequenceIconTextResize.DefaultHeight) - 2)

    for index, line in ipairs(SequenceTextLines) do
        line:SetWidth(textWidth)
        line:SetHeight(GSE.SequenceIconTextResize.LineHeight)
        if line.GetFont and line.SetFont then
            local font = (GSE.Skin and GSE.Skin.HostFont and GSE.Skin.HostFont())
                or (_G.GameFontHighlightSmall and _G.GameFontHighlightSmall:GetFont())
            if font then line:SetFont(font, GSE.SequenceIconTextResize.FontSize, "") end
        end
        if line.SetWordWrap then line:SetWordWrap(false) end
        if line.SetNonSpaceWrap then line:SetNonSpaceWrap(false) end
        line:ClearAllPoints()
        if index == 1 then
            line:SetPoint("TOPLEFT", SequenceIconTextFrame, "TOPLEFT", 2, -2)
        else
            line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -1)
        end
        if (line:GetText() or "") ~= "" and ((index - 1) * (GSE.SequenceIconTextResize.LineHeight + 1)) + GSE.SequenceIconTextResize.LineHeight <= availableHeight then
            line:Show()
        else
            line:Hide()
        end
        previousLine = line
    end
end

SequenceIconTextFrame:SetScript("OnSizeChanged", function()
    LayoutSequenceTextLines(math.max(1, (SequenceIconTextFrame:GetWidth() or GSE.SequenceIconTextResize.DefaultWidth) - 4))
end)

local function SetSequenceTextLines(lines)
    lines = lines or {}

    for index, text in ipairs(lines) do
        local line = EnsureSequenceTextLine(index)
        line:SetText(text)
        line:SetAlpha(1)
        line:Show()
    end

    for index = #lines + 1, #SequenceTextLines do
        local line = SequenceTextLines[index]
        line:SetText("")
        line:Hide()
    end
end

local function ClearSequenceTextLines()
    for _, line in ipairs(SequenceTextLines) do
        line:SetText("")
        line:Hide()
    end
end

function GSE.SequenceIconLayoutTrackerWidget()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local widget = GSE.SequenceIconTrackerWidget
    if not widget then return end

    local gap = 1
    local iconSize = currentOptions.IconSize or 100
    local iconWidth = SequenceIconFrameWidth or iconSize
    local iconHeight = SequenceIconFrameHeight or iconSize
    local textWidth = SequenceIconTextFrame:GetWidth() or currentOptions.TextWidth or GSE.SequenceIconTextResize.DefaultWidth
    local textHeight = SequenceIconTextFrame:GetHeight() or currentOptions.TextHeight or GSE.SequenceIconTextResize.DefaultHeight
    local showCastMirror = IsSuccessfulCastFrameEnabled()
    local castWidth = showCastMirror and (SuccessfulCastFrame:GetWidth() or ((iconSize * 2) + Statics.TrackerConfig.MirrorIconGap)) or 0
    local castHeight = showCastMirror and (SuccessfulCastFrame:GetHeight() or iconSize) or 0
    local castBlockHeight = castHeight > 0 and (castHeight + gap) or 0
    local widgetWidth = math.max(iconWidth, textWidth, castWidth)
    local widgetHeight = castBlockHeight + iconHeight + gap + textHeight

    widget:SetSize(widgetWidth, widgetHeight)

    if SuccessfulCastFrame and not GSE.SequenceIconApplyInternalFramePosition("SuccessfulCasts", SuccessfulCastFrame) then
        SuccessfulCastFrame:ClearAllPoints()
        SuccessfulCastFrame:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, 0)
    end

    if AssistedSuccessFrame and not GSE.SequenceIconApplyInternalFramePosition("AssistedSuccess", AssistedSuccessFrame) then
        AssistedSuccessFrame:ClearAllPoints()
        AssistedSuccessFrame:SetPoint("LEFT", SuccessfulCastFrame, "RIGHT", gap, 0)
    end

    if not GSE.SequenceIconApplyInternalFramePosition("Icon", SequenceIconFrame) then
        SequenceIconFrame:ClearAllPoints()
        SequenceIconFrame:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -castBlockHeight)
    end

    if not GSE.SequenceIconApplyInternalFramePosition("Text", SequenceIconTextFrame) then
        SequenceIconTextFrame:ClearAllPoints()
        SequenceIconTextFrame:SetPoint("TOPLEFT", SequenceIconFrame, "BOTTOMLEFT", 0, -gap)
    end

    if GSE.SequenceIconRefreshTrackerWidgetBackdrop then GSE.SequenceIconRefreshTrackerWidgetBackdrop() end
end

local function UpdateSequenceTextPosition()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local textWidth = currentOptions.Orientation == "HORIZONTAL" and math.max(GSE.SequenceIconTextResize.AutoWidth, SequenceIconFrameWidth) or GSE.SequenceIconTextResize.AutoWidth
    -- Auto-fit: exactly one line slot per visible text line.
    local textHeight = #SequenceTextLines * (GSE.SequenceIconTextResize.LineHeight + 1)

    local frameWidth = textWidth + 4
    local frameHeight = textHeight + 2
    -- Always auto-size to fit the current line count.

    frameWidth = ClampNumber(frameWidth, GSE.SequenceIconTextResize.MinWidth, GSE.SequenceIconTextResize.MaxWidth, GSE.SequenceIconTextResize.DefaultWidth)
    frameHeight = ClampNumber(frameHeight, GSE.SequenceIconTextResize.MinHeight, GSE.SequenceIconTextResize.MaxHeight, GSE.SequenceIconTextResize.DefaultHeight)
    SequenceIconTextFrame:SetSize(frameWidth, frameHeight)
    textWidth = math.max(1, frameWidth - 4)
    LayoutSequenceTextLines(textWidth)
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    ApplySequenceTextBackdrop()
end

function GSE.SequenceIconStickTrackerFrames()
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.IconMoved = false
    currentOptions.IconX = nil
    currentOptions.IconY = nil
    currentOptions.TextMoved = false
    currentOptions.TextX = nil
    currentOptions.TextY = nil
    currentOptions.SuccessfulCastsMoved = false
    currentOptions.SuccessfulCastsX = nil
    currentOptions.SuccessfulCastsY = nil
    currentOptions.AssistedSuccessMoved = false
    currentOptions.AssistedSuccessX = nil
    currentOptions.AssistedSuccessY = nil
    UpdateSequenceTextPosition()
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    if SuccessfulCastFrame then SuccessfulCastFrame:SetClampedToScreen(true) end
    if AssistedSuccessFrame then AssistedSuccessFrame:SetClampedToScreen(true) end
end

-- Count the GSE "Hardware Events" that are currently TRUE.
-- Mirrors the list from the GSE config panel: 5 mouse buttons +
-- 9 modifier-key variants (Left/Right/Any for each of Alt/Ctrl/Shift).
-- Returns an integer 0..14.
-- Return the LABEL names of every GSE "Hardware Event" that is currently
-- TRUE. Labels match the GSE: Hardware Events diagnostic panel exactly so
-- the tracker line is self-explanatory. Returns an array of strings; empty
-- when nothing is held.
function GSE.SequenceIconListTrueHardwareEvents()
    local list = {}
    if IsMouseButtonDown then
        if IsMouseButtonDown("LeftButton")   then list[#list + 1] = "LeftButton"   end
        if IsMouseButtonDown("RightButton")  then list[#list + 1] = "RightButton"  end
        if IsMouseButtonDown("MiddleButton") then list[#list + 1] = "MiddleButton" end
        if IsMouseButtonDown("Button4")      then list[#list + 1] = "Button4"      end
        if IsMouseButtonDown("Button5")      then list[#list + 1] = "Button5"      end
    end
    if IsRightAltKeyDown     and IsRightAltKeyDown()     then list[#list + 1] = "Right Alt Key"     end
    if IsLeftAltKeyDown      and IsLeftAltKeyDown()      then list[#list + 1] = "Left Alt Key"      end
    if IsAltKeyDown          and IsAltKeyDown()          then list[#list + 1] = "Any Alt Key"       end
    if IsRightControlKeyDown and IsRightControlKeyDown() then list[#list + 1] = "Right Control Key" end
    if IsLeftControlKeyDown  and IsLeftControlKeyDown()  then list[#list + 1] = "Left Control Key"  end
    if IsControlKeyDown      and IsControlKeyDown()      then list[#list + 1] = "Any Control Key"   end
    if IsRightShiftKeyDown   and IsRightShiftKeyDown()   then list[#list + 1] = "Right Shift Key"   end
    if IsLeftShiftKeyDown    and IsLeftShiftKeyDown()    then list[#list + 1] = "Left Shift Key"    end
    if IsShiftKeyDown        and IsShiftKeyDown()        then list[#list + 1] = "Any Shift Key"     end
    return list
end

UpdateSequenceText = function(sequence, mods, placeholderText)
    local currentOptions = EnsureSequenceIconFrameOptions()
    local currentSequence = sequence or activeSequence
    local lines = {}
    local spamKey = "None"
    local spamKeyActive = false

    if not placeholderText and currentSequence and currentSequence ~= "" then
        spamKey, spamKeyActive = GetActiveSpamKey(currentSequence)
    end

    if not placeholderText and currentOptions.ShowPlayerStatus ~= false then
        table.insert(lines, "|cffffd100Status:|r " .. FormatCombatState())
    end

    if currentOptions.ShowSequenceName ~= false then
        local sequenceName = placeholderText or (IsPlayerInCombat() and spamKeyActive and GetPrettySequenceNameWithVersion(currentSequence or "") or "None")
        table.insert(lines, "|cffffd100Sequence Name:|r |cffffffff" .. sequenceName .. "|r")
    end

    if not placeholderText and currentSequence and currentSequence ~= "" then
        local effectiveMods = GSE.SequenceIconReadGameMods(mods or lastSequenceMods)
        -- List the GSE "Hardware Events" that are TRUE right now by name
        -- (e.g. "LeftButton, Left Control Key, Any Control Key"). "None" if
        -- nothing is currently held. Displayed first so it sits directly
        -- under the Sequence Name line above.
        if currentOptions.ShowHardwareEvents ~= false then
            local hwList = GSE.SequenceIconListTrueHardwareEvents and
                                GSE.SequenceIconListTrueHardwareEvents() or {}
            local hwDisplay = (#hwList > 0) and table.concat(hwList, " + ") or "None"
            table.insert(lines, "|cffffd100Hardware Events:|r " .. hwDisplay)
        end
        if currentOptions.ShowActivationKey ~= false then
            table.insert(lines, "|cffffd100Activation Key:|r " .. spamKey)
        end
        if currentOptions.ShowClientModKey ~= false then
            table.insert(lines, "|cffffd100Client ModKey:|r " .. FormatModKeys(effectiveMods))
        end
        if currentOptions.ShowBlock ~= false then
            table.insert(lines, "|cffffd100Block:|r " .. (SequenceIconFrame.lastBlockPath and tostring(SequenceIconFrame.lastBlockPath):gsub("^block:", "") or "None"))
        end
        if currentOptions.ShowStep ~= false then
            table.insert(lines, "|cffffd100Step:|r " .. (SequenceIconFrame.lastStep and tostring(SequenceIconFrame.lastStep) or "None"))
        end
    end

    SetSequenceTextLines(lines)
    UpdateSequenceTextPosition()
    if currentOptions.ShowTrackerText ~= false then
        SequenceIconTextFrame:Show()
    else
        SequenceIconTextFrame:Hide()
    end
end

local function EnsureIconTexture(index)
    if not SequenceIconTextures[index] then
        SequenceIconTextures[index] = SequenceIconFrame:CreateTexture(nil, "ARTWORK")
    end
    return SequenceIconTextures[index]
end

local function UpdateCastMirrorIcons()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local iconSize = currentOptions.IconSize
    local frameWidth = iconSize

    SuccessfulCastFrame:SetSize(frameWidth, iconSize)
    assistedHighlightTexture:Hide()
    assistedHighlightLabel:Hide()
    assistedHighlightTexture.matchCountLabel:Hide()
    assistedHighlightTexture.matchPercentLabel:Hide()
    SetAssistedHighlightBorderShown(false)
    assistedHighlightFlash:Hide()
    successfulCastTexture:ClearAllPoints()
    successfulCastTexture:SetSize(iconSize, iconSize)
    successfulCastTexture:SetPoint("LEFT", SuccessfulCastFrame, "LEFT", 0, 0)
    successfulCastLabel:ClearAllPoints()
    successfulCastLabel:SetPoint("CENTER", successfulCastTexture, "CENTER", 0, 0)
    successfulCastLabel:SetSize(iconSize, iconSize)
    successfulCastTexture.blockLabel:ClearAllPoints()
    successfulCastTexture.blockLabel:SetPoint("BOTTOM", successfulCastTexture, "BOTTOM", 0, 2)
    successfulCastTexture.blockLabel:SetWidth(iconSize)
    successfulCastTexture.stepLabel:ClearAllPoints()
    successfulCastTexture.stepLabel:SetPoint("TOP", successfulCastTexture, "TOP", 0, -2)
    successfulCastTexture.stepLabel:SetWidth(iconSize)

    if not IsSuccessfulCastFrameEnabled() then
        successfulCastTexture:Hide()
        successfulCastLabel:Hide()
        successfulCastFlash:Hide()
        successfulCastTexture.blockLabel:Hide()
        successfulCastTexture.stepLabel:Hide()
        SuccessfulCastFrame:Hide()
        if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
        return
    end

    successfulCastTexture:SetTexture(successfulCastIconID or Statics.QuestionMarkIconID)
    successfulCastTexture:SetAlpha(successfulCastIconID and (pendingSuccessfulCast and 0.55 or 1) or 0.35)
    successfulCastTexture:Show()
    successfulCastLabel:Show()
    successfulCastTexture.blockLabel:SetText("")
    successfulCastTexture.blockLabel:Hide()
    successfulCastTexture.stepLabel:SetText("")
    successfulCastTexture.stepLabel:Hide()
    SuccessfulCastFrame:Show()
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    RefreshSuccessfulCastMoveMode()
end

UpdateAssistedSuccessFrame = function()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local iconSize = currentOptions.IconSize
    local now = GetTime and GetTime() or 0
    local isActive = heldAssistedSuccessIconID and now < heldAssistedSuccessExpiresAt

    AssistedSuccessFrame:SetSize(iconSize, iconSize)
    assistedSuccessTexture:ClearAllPoints()
    assistedSuccessTexture:SetSize(iconSize, iconSize)
    assistedSuccessTexture:SetPoint("CENTER", AssistedSuccessFrame, "CENTER", 0, 0)
    assistedSuccessGlow:ClearAllPoints()
    assistedSuccessGlow:SetSize(iconSize + 10, iconSize + 10)
    assistedSuccessGlow:SetPoint("CENTER", assistedSuccessTexture, "CENTER", 0, 0)
    assistedSuccessLabel:ClearAllPoints()
    assistedSuccessLabel:SetPoint("CENTER", assistedSuccessTexture, "CENTER", 0, 0)

    if not IsAssistedSuccessFrameEnabled() then
        assistedSuccessTexture:Hide()
        assistedSuccessGlow:Hide()
        assistedSuccessFlash:Hide()
        assistedSuccessLabel:Hide()
        AssistedSuccessFrame:Hide()
        if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
        RefreshAssistedSuccessMoveMode()
        return
    end

    if not isActive then
        heldAssistedSuccessIconID = nil
        heldAssistedSuccessName = nil
        heldAssistedSuccessExpiresAt = 0

        if IsPlayerInCombat() then
            assistedSuccessTexture:Hide()
            assistedSuccessGlow:Hide()
            assistedSuccessFlash:Hide()
            assistedSuccessLabel:Hide()
            AssistedSuccessFrame:Hide()
            if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
            RefreshAssistedSuccessMoveMode()
            return
        end

        assistedSuccessTexture:SetTexture(Statics.QuestionMarkIconID)
        assistedSuccessTexture:SetAlpha(0.25)
        assistedSuccessTexture:Show()
        assistedSuccessGlow:Hide()
        assistedSuccessFlash:Hide()
        assistedSuccessLabel:SetAlpha(0.45)
        assistedSuccessLabel:Show()
        AssistedSuccessFrame:Show()
        if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
        RefreshAssistedSuccessMoveMode()
        return
    end

    assistedSuccessTexture:SetTexture(heldAssistedSuccessIconID)
    assistedSuccessTexture:SetAlpha(1)
    assistedSuccessTexture:Show()
    assistedSuccessGlow:Show()
    assistedSuccessLabel:SetAlpha(1)
    assistedSuccessLabel:Show()
    AssistedSuccessFrame:Show()
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    RefreshAssistedSuccessMoveMode()
end

AssistedSuccessFrame:SetScript("OnUpdate", function()
    if heldAssistedSuccessIconID and (GetTime and GetTime() or 0) >= heldAssistedSuccessExpiresAt then
        UpdateAssistedSuccessFrame()
    end
end)

local function GetAssistedCombatSpellID()
    if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return nil end

    if C_AssistedCombat.IsAvailable then
        local ok, available = pcall(C_AssistedCombat.IsAvailable)
        if ok and not available then return nil end
    end

    local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if not ok or not spellID then
        ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell)
        if not ok then spellID = nil end
    end

    return tonumber(spellID) or spellID
end

local function GetAssistedCombatIconInfo()
    local nextCastSpell = GetAssistedCombatSpellID()
    if not nextCastSpell then return nil end

    local spellInfo = GSE.GetSpellInfo and GSE.GetSpellInfo(nextCastSpell)
    local name = spellInfo and spellInfo.name
    local iconID = spellInfo and spellInfo.iconID

    if not iconID and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, nextCastSpell)
        if ok then iconID = texture end
    end

    if (not iconID or not name) and GetSpellInfo then
        local spellName, _, spellIcon = GetSpellInfo(nextCastSpell)
        name = name or spellName
        iconID = iconID or spellIcon
    end

    if not iconID and GetSpellTexture then
        iconID = GetSpellTexture(nextCastSpell)
    end

    return iconID, name, nextCastSpell
end

local function SetAssistedHighlightIcon(sequence, iconID, trackHit, hitSerial, displayName, isFallback)
    if not iconID then return end

    assistedHighlightSequence = sequence
    assistedHighlightIconID = iconID
    assistedHighlightIsFallback = isFallback == true
    UpdateCastMirrorIcons()
end

local function MarkChannelAsSuccessfulIfAssisted(sequence, spellID, iconID, spellName)
    if not spellID or not iconID or not UnitChannelInfo then return end

    local _, _, _, startTimeMS, _, _, _, channelSpellID = UnitChannelInfo("player")
    channelSpellID = tonumber(channelSpellID)
    if not channelSpellID or channelSpellID ~= tonumber(spellID) then return end

    startTimeMS = tonumber(startTimeMS) or 0
    if lastAssistedChannelSpellID == channelSpellID and lastAssistedChannelStartMS == startTimeMS then return end

    lastAssistedChannelSpellID = channelSpellID
    lastAssistedChannelStartMS = startTimeMS
    successfulCastCount = successfulCastCount + 1
    successfulCastSequence = sequence or activeSequence
    successfulCastIconID = iconID
    successfulCastName = spellName or tostring(channelSpellID)
    SuccessfulCastFrame.blockPath = SequenceIconFrame.lastBlockPath
    SuccessfulCastFrame.step = SequenceIconFrame.lastStep
    lastSuccessfulCastHitTime = GetTime and GetTime() or 0
    lastSuccessfulCastHitIconID = iconID
    successfulCastHitSerial = successfulCastHitSerial + 1
    pendingSuccessfulCast = false
    UpdateCastMirrorIcons()
end

local function ClearAssistedHighlightIcon()
    assistedHighlightSequence = nil
    assistedHighlightIconID = nil
    assistedHighlightIsFallback = false
    UpdateCastMirrorIcons()
end

local function RefreshAssistedHighlightIcon(sequence)
    local iconID, spellName, spellID = GetAssistedCombatIconInfo()
    if iconID then
        SetAssistedHighlightIcon(sequence, iconID, false, nil, spellName, false)
        MarkChannelAsSuccessfulIfAssisted(sequence, spellID, iconID, spellName)
        TryTriggerAssistedSuccessPing()
        return iconID
    end

    ClearAssistedHighlightIcon()
    return nil
end

local function GetSequenceIconAlpha(index, entryCount, iconCount)
    -- Opacity ramp that scales with how many icons are visible. The oldest icon
    -- ("last") fades based on entryCount, and every newer icon adds +0.20 on top,
    -- capped at 1.00. iconCount is unused now -- the ramp applies whenever the
    -- scroll has 2+ entries, even before reaching the configured cap.
    --   1 icon   -> [100]
    --   2 icons  -> [100, 80]
    --   3 icons  -> [100, 80, 60]
    --   4 icons  -> [100, 80, 60, 40]
    --   5+ icons -> [..., 100, 100, 80, 60, 40]   (last 3 always 80/60/40)
    local lastAlpha
    if entryCount <= 1 then
        lastAlpha = 1.00
    elseif entryCount == 2 then
        lastAlpha = 0.80
    elseif entryCount == 3 then
        lastAlpha = 0.60
    else
        lastAlpha = 0.40
    end
    local distanceFromLast = entryCount - index
    local alpha = lastAlpha + (distanceFromLast * 0.20)
    if alpha > 1.0 then alpha = 1.0 end
    if alpha < 0.0 then alpha = 0.0 end
    return alpha
end

local function LayoutSequenceIcons()
    local currentOptions = EnsureSequenceIconFrameOptions()
    local iconSize = currentOptions.IconSize
    local visibleCount = math.max(1, #SequenceIconEntries)

    if currentOptions.Orientation == "HORIZONTAL" then
        SequenceIconFrameWidth = math.max(iconSize, iconSize * visibleCount)
        SequenceIconFrameHeight = iconSize
    else
        SequenceIconFrameWidth = iconSize
        SequenceIconFrameHeight = math.max(iconSize, iconSize * visibleCount)
    end

    SequenceIconFrame:SetSize(SequenceIconFrameWidth, SequenceIconFrameHeight)

    for index = 1, math.max(#SequenceIconTextures, currentOptions.IconCount) do
        local texture = EnsureIconTexture(index)
        texture:ClearAllPoints()
        texture:SetSize(iconSize, iconSize)

        if SequenceIconEntries[index] then
            local entry = SequenceIconEntries[index]
            local iconAlpha = GetSequenceIconAlpha(index, #SequenceIconEntries, currentOptions.IconCount)
            texture:SetTexture(entry.iconID)
            texture:SetAlpha(iconAlpha)
            texture:Show()

            if currentOptions.Orientation == "HORIZONTAL" then
                texture:SetPoint("TOPLEFT", SequenceIconFrame, "TOPLEFT", (index - 1) * iconSize, 0)
            else
                texture:SetPoint("TOPLEFT", SequenceIconFrame, "TOPLEFT", 0, -((index - 1) * iconSize))
            end

        else
            texture:Hide()
            if SequenceIconFlashes[index] then
                SequenceIconFlashes[index]:Hide()
            end
        end
    end

    placeholderIcon:ClearAllPoints()
    placeholderIcon:SetSize(iconSize, iconSize)
    placeholderIcon:SetPoint("TOPLEFT", SequenceIconFrame, "TOPLEFT", 0, 0)

    UpdateCastMirrorIcons()
    UpdateSequenceTextPosition()
end

local function ShowPlaceholder()
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled or #SequenceIconEntries > 0 then
        placeholderIcon:Hide()
        return
    end

    LayoutSequenceIcons()
    placeholderIcon:SetTexture(Statics.Icons.GSE_Logo_Dark or Statics.QuestionMarkIconID)
    placeholderIcon:Show()
    UpdateSequenceText(nil, nil, "Waiting for GSE sequence")
    SequenceIconFrame:Show()
end

local function RenderSequenceIcons()
    LayoutSequenceIcons()

    if #SequenceIconEntries > 0 then
        placeholderIcon:Hide()
        SequenceIconFrame:Show()
        UpdateSequenceText(SequenceIconEntries[1].sequence)
    else
        ShowPlaceholder()
    end
end

local function ResolveActionIcon(action)
    if not action then return nil end

    local iconInfo
    if action.type == "macro" and action.macrotext then
        if GSE.GetMacroTextIconInfo then
            iconInfo = GSE.GetMacroTextIconInfo(action.macrotext, true)
        end
        if not iconInfo and GSE.GetSpellsFromString then
            iconInfo = GSE.GetSpellsFromString(action.macrotext, true)
        end
        if iconInfo and #iconInfo > 0 then
            iconInfo = iconInfo[1]
        end
    elseif action.type == "macro" and action.macro then
        local _, macroIcon = GetMacroInfo(action.macro)
        if macroIcon then iconInfo = {iconID = macroIcon} end
    elseif action.type == "item" and action.item then
        local item = GSE.UnEscapeString and GSE.UnEscapeString(action.item) or action.item
        local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(item)
        if itemName and itemIcon then iconInfo = {name = itemName, iconID = itemIcon} end
    elseif action.type == "spell" and action.spell then
        local spell = GSE.UnEscapeString and GSE.UnEscapeString(action.spell) or action.spell
        local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(spell) or spell
        iconInfo = GSE.GetSpellInfo(currentSpell)
    end

    if action.Icon and (not IsFallbackIcon(action.Icon) or not (iconInfo and iconInfo.iconID)) then
        return action.Icon
    end

    return iconInfo and iconInfo.iconID
end

local function GetCurrentSequenceStep(sequence)
    local button = sequence and _G[sequence]
    if not (button and button.GetAttribute) then return 1 end

    local step = tonumber(button:GetAttribute("step")) or 1
    local iteration = tonumber(button:GetAttribute("iteration")) or 1
    if iteration > 1 then
        return step + ((iteration - 1) * 253)
    end
    return step
end

local function GetCurrentSequenceAction(sequence)
    local executionseq = sequence and GSE.SequencesExec and GSE.SequencesExec[sequence]
    if not executionseq then return nil end

    local step = GetCurrentSequenceStep(sequence)
    local candidates = {step, 1}

    local button = _G[sequence]
    if button and button.GetAttribute then
        local rawStep = tonumber(button:GetAttribute("step")) or 1
        local iteration = tonumber(button:GetAttribute("iteration")) or 1
        if iteration > 1 then
            table.insert(candidates, rawStep + (iteration * 254))
            table.insert(candidates, rawStep)
        end
    end

    for _, candidate in ipairs(candidates) do
        if executionseq[candidate] then return executionseq[candidate] end
    end
end

local function ResolveSequenceIcon(sequence)
    local button = sequence and _G[sequence]
    if button and GSE.GetCurrentButtonIconInfo then
        local iconInfo = GSE.GetCurrentButtonIconInfo(button, false)
        if iconInfo and iconInfo.iconID and not IsFallbackIcon(iconInfo.iconID) then
            return iconInfo.iconID
        end
    end

    local actionIcon = ResolveActionIcon(GetCurrentSequenceAction(sequence))
    if actionIcon then return actionIcon end

    local executionseq = sequence and GSE.SequencesExec and GSE.SequencesExec[sequence]
    if executionseq then
        for _, action in ipairs(executionseq) do
            actionIcon = ResolveActionIcon(action)
            if actionIcon then return actionIcon end
        end
    end

    if GetMacroIndexByName and sequence then
        local macroIndex = GetMacroIndexByName(sequence)
        if macroIndex and macroIndex > 0 then
            local _, macroIcon = GetMacroInfo(macroIndex)
            if macroIcon and not IsFallbackIcon(macroIcon) then return macroIcon end
        end
    end
end

local function GetSucceededSpellID(...)
    local count = select("#", ...)
    for index = count, 1, -1 do
        local value = select(index, ...)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
end

local function GetSpellCastIconInfo(spellID)
    if not spellID then return nil end

    local spellInfo = GSE.GetSpellInfo and GSE.GetSpellInfo(spellID)
    local name = spellInfo and spellInfo.name
    local iconID = spellInfo and spellInfo.iconID

    if not iconID and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok then iconID = texture end
    end

    if (not iconID or not name) and GetSpellInfo then
        local spellName, _, spellIcon = GetSpellInfo(spellID)
        name = name or spellName
        iconID = iconID or spellIcon
    end

    if not iconID and GetSpellTexture then
        iconID = GetSpellTexture(spellID)
    end

    return iconID, name or tostring(spellID)
end

local function GetScrollTextureForSuccessfulCast(iconID)
    for index = 1, #SequenceIconEntries do
        if SequenceIconEntries[index].iconID == iconID and SequenceIconTextures[index] then
            return SequenceIconTextures[index], index, true
        end
    end

    local index = #SequenceIconEntries > 0 and 1 or 0
    if index > 0 then
        return SequenceIconTextures[index], index, false
    end
end

local function TriggerSuccessfulCastProc(iconID)
    FlashTexture(successfulCastTexture, successfulCastFlash)

    local rowTexture, rowIndex = GetScrollTextureForSuccessfulCast(iconID)
    if rowTexture and rowIndex then
        FlashTexture(rowTexture, EnsureIconFlash(rowIndex))
    end
    TryTriggerAssistedSuccessPing()
end

local function HandleUnitSpellcastSucceeded(unitTarget, ...)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled or unitTarget ~= "player" then return end

    local now = GetTime and GetTime() or 0
    -- Only treat this cast as a GSE "successful cast" when it is the cast that
    -- directly follows a GSE button press. pendingSuccessfulCast is armed in
    -- MarkGSEActivity (a GSE macro fired) and consumed below by the first cast
    -- that lands; a stray cast from a key that has nothing to do with GSE finds
    -- it already false and is ignored. Without this, ANY cast inside the
    -- SuccessCastWindow flashed the tracker -- the "glows on unrelated keys"
    -- bug. The window check below stays as a staleness guard (a GSE press whose
    -- cast never lands must not arm a later unrelated cast).
    if not pendingSuccessfulCast then return end
    if not lastGSEActivitySequence or (now - lastGSEActivityTime) > Statics.TrackerConfig.SuccessCastWindow then return end

    local spellID = GetSucceededSpellID(...)
    local iconID, spellName = GetSpellCastIconInfo(spellID)
    if not iconID then return end

    successfulCastIconID = iconID
    successfulCastName = spellName
    successfulCastSequence = lastGSEActivitySequence
    SuccessfulCastFrame.blockPath = SequenceIconFrame.lastBlockPath
    SuccessfulCastFrame.step = SequenceIconFrame.lastStep
    lastSuccessfulCastHitTime = now
    lastSuccessfulCastHitIconID = iconID
    successfulCastHitSerial = successfulCastHitSerial + 1
    successfulCastCount = successfulCastCount + 1
    pendingSuccessfulCast = false

    UpdateCastMirrorIcons()
    TriggerSuccessfulCastProc(iconID)
    SequenceIconFrame:Show()
    UpdateSequenceText(successfulCastSequence)

    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == SequenceIconFrame then
        ShowMoveTooltip()
    end
end

local function TrimIconEntries()
    local maxIcons = EnsureSequenceIconFrameOptions().IconCount
    while #SequenceIconEntries > maxIcons do
        table.remove(SequenceIconEntries)
    end
end

local function PushSequenceIcon(sequence, iconID, directInput, buttonName, blockPath, step)
    if not sequence or not iconID then return false end
    if not GSE.SequenceIconShouldAcceptSequence(sequence, directInput, buttonName) then return false end

    MarkGSEActivity(sequence)

    local now = GetTime and GetTime() or 0
    if lastPushSequence == sequence and lastPushIcon == iconID and (now - lastPushTime) < 0.05 then
        SequenceIconFrame.lastBlockPath = blockPath or SequenceIconFrame.lastBlockPath
        SequenceIconFrame.lastStep = step or SequenceIconFrame.lastStep
        local entry = SequenceIconEntries[1]
        if entry then
            entry.blockPath = blockPath or entry.blockPath
            entry.step = step or entry.step
            RenderSequenceIcons()
        end
        return true
    end

    activeSequence = sequence
    lastPushSequence = sequence
    lastPushIcon = iconID
    lastPushTime = now
    scrollHitSerial = scrollHitSerial + 1
    RefreshAssistedHighlightIcon(sequence)
    SequenceIconFrame.lastBlockPath = blockPath
    SequenceIconFrame.lastStep = step

    table.insert(SequenceIconEntries, 1, {sequence = sequence, iconID = iconID, blockPath = blockPath, step = step})
    TrimIconEntries()
    RenderSequenceIcons()
    return true
end

local function GetSequencePreviewIcons(sequence)
    local icons = {}
    local executionseq = sequence and GSE.SequencesExec and GSE.SequencesExec[sequence]
    local maxIcons = EnsureSequenceIconFrameOptions().IconCount

    if executionseq and #executionseq > 0 then
        local startStep = GetCurrentSequenceStep(sequence)
        if startStep < 1 or startStep > #executionseq then startStep = 1 end

        for offset = 0, #executionseq - 1 do
            local index = ((startStep + offset - 1) % #executionseq) + 1
            local iconID = ResolveActionIcon(executionseq[index])
            if iconID then
                table.insert(icons, {iconID = iconID, blockPath = executionseq[index].blockPath, step = index})
                if #icons >= maxIcons then return icons end
            end
        end
    end

    local sequenceIcon = ResolveSequenceIcon(sequence)
    if sequenceIcon then
        table.insert(icons, {iconID = sequenceIcon})
    end

    return icons
end

local function SetSequencePreview(sequence, directInput, buttonName)
    if not IsValidSequence(sequence) then return false end
    if not GSE.SequenceIconShouldAcceptSequence(sequence, directInput, buttonName) then return false end

    if activeSequence ~= sequence then
        lastSequenceButtonName = nil
        lastSequenceMods = nil
    end
    activeSequence = sequence
    for index = #SequenceIconEntries, 1, -1 do
        SequenceIconEntries[index] = nil
    end

    local icons = GetSequencePreviewIcons(sequence)
    for _, entry in ipairs(icons) do
        table.insert(SequenceIconEntries, {sequence = sequence, iconID = entry.iconID, blockPath = entry.blockPath, step = entry.step})
    end
    RefreshAssistedHighlightIcon(sequence)

    TrimIconEntries()
    RenderSequenceIcons()
    return #SequenceIconEntries > 0
end

local function FindAvailableSequence()
    if IsValidSequence(activeSequence) and GSE.SequenceIconShouldAcceptSequence(activeSequence, false) then return activeSequence end
    if #SequenceIconEntries > 0 and IsValidSequence(SequenceIconEntries[1].sequence)
        and GSE.SequenceIconShouldAcceptSequence(SequenceIconEntries[1].sequence, false) then
        return SequenceIconEntries[1].sequence
    end

    if GSE.UsedSequences then
        for buttonName, entry in pairs(GSE.UsedSequences) do
            local sequence = ResolveUsedSequence(buttonName)
            if IsValidSequence(sequence) and GSE.SequenceIconShouldAcceptSequence(sequence, false, buttonName) then return sequence end
            if type(entry) == "string" and IsValidSequence(entry) and GSE.SequenceIconShouldAcceptSequence(entry, false, buttonName) then return entry end
        end
    end

    if GSE.ButtonOverrides then
        for buttonName, sequence in pairs(GSE.ButtonOverrides) do
            if IsValidSequence(sequence) and GSE.SequenceIconShouldAcceptSequence(sequence, false, buttonName) then return sequence end
        end
    end

    if GSE.SequencesExec then
        for sequence in pairs(GSE.SequencesExec) do
            if IsValidSequence(sequence) and GSE.SequenceIconShouldAcceptSequence(sequence, false) then return sequence end
        end
    end
end

local function NoteSequenceButtonPressed(button)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled then return end

    local sequence = ResolveSequenceKey(button)
    if not sequence then return end

    local buttonName = button.GetName and button:GetName()
    if not GSE.SequenceIconShouldAcceptSequence(sequence, true, buttonName) then return end

    local mods = GSE.SequenceIconParseModifierString(button.GetAttribute and button:GetAttribute("localmods"))
    if mods then
        local clickSerial = button.GetAttribute and tonumber(button:GetAttribute("gseclickserial") or 0) or 0
        GSE.SequenceIconCaptureMods(sequence, mods, buttonName, nil, nil, clickSerial)
    else
        MarkGSEActivity(sequence, buttonName)
    end
    activeSequence = sequence
    local iconID = ResolveSequenceIcon(sequence)
    if iconID then
        local step = button.GetAttribute and tonumber(button:GetAttribute("step") or 1) or nil
        local iteration = button.GetAttribute and tonumber(button:GetAttribute("iteration") or 1) or 1
        if step and iteration and iteration > 1 then step = step + (iteration * 254) end
        -- blockPath arg: 'action' is undefined in this button-press path, so this has
        -- always passed nil (there is no editor block context on a live button press).
        PushSequenceIcon(sequence, iconID, true, buttonName, nil, step)
    elseif #SequenceIconEntries == 0 then
        SetSequencePreview(sequence, true, buttonName)
    else
        UpdateSequenceText(sequence, mods)
        SequenceIconFrame:Show()
    end
end

local function HookButton(buttonName)
    if type(buttonName) ~= "string" or buttonName == "" or hookedButtons[buttonName] then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local button = _G[buttonName]
    if not (button and button.HookScript) then return end

    local ok = pcall(button.HookScript, button, "PostClick", NoteSequenceButtonPressed)
    if ok then
        hookedButtons[buttonName] = true
    end
end

local function HookKnownButtons()
    if InCombatLockdown and InCombatLockdown() then return end

    if GSE.SequencesExec then
        for sequence in pairs(GSE.SequencesExec) do
            HookButton(sequence)
        end
    end

    if GSE.ButtonOverrides then
        for buttonName in pairs(GSE.ButtonOverrides) do
            HookButton(buttonName)
        end
    end

    if GSE.UsedSequences then
        for buttonName in pairs(GSE.UsedSequences) do
            HookButton(buttonName)
        end
    end
end

local bindingHooksInstalled = false
local function InstallBindingHooks()
    if bindingHooksInstalled or not hooksecurefunc then return end
    bindingHooksInstalled = true

    pcall(hooksecurefunc, "SetOverrideBindingClick", function(_, _, _, buttonName)
        HookButton(buttonName)
    end)

    pcall(hooksecurefunc, "SetBindingClick", function(_, buttonName)
        HookButton(buttonName)
    end)
end

local function RefreshAllSequenceIcons()
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled then return end

    InstallBindingHooks()
    HookKnownButtons()

    if #SequenceIconEntries == 0 then
        local sequence = FindAvailableSequence()
        if sequence and not SetSequencePreview(sequence) then
            ShowPlaceholder()
        elseif not sequence then
            ShowPlaceholder()
        end
    else
        RenderSequenceIcons()
    end
end

local function ScheduleSequenceIconRefresh()
    RefreshAllSequenceIcons()
    C_Timer.After(0, RefreshAllSequenceIcons)
    C_Timer.After(0.25, RefreshAllSequenceIcons)
    C_Timer.After(1, RefreshAllSequenceIcons)
end

local function ResetSequenceIconFramePosition()
    if GSE.SequenceIconResetTrackerWidgetPosition then GSE.SequenceIconResetTrackerWidgetPosition() end
    GSE.SequenceIconTrackerWidget:SetClampedToScreen(true)
    if GSE.SequenceIconStickTrackerFrames then GSE.SequenceIconStickTrackerFrames() end
    if not EnsureSequenceIconFrameOptions().TextMoved then
        UpdateSequenceTextPosition()
    end
    ScheduleSequenceIconRefresh()

    if EnsureSequenceIconFrameOptions().Enabled then
        SequenceIconFrame:Show()
    end
end

local function ResetSequenceTextFramePosition()
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.TextMoved = false
    currentOptions.TextX = nil
    currentOptions.TextY = nil
    currentOptions.TextWidth = GSE.SequenceIconTextResize.DefaultWidth
    currentOptions.TextHeight = GSE.SequenceIconTextResize.DefaultHeight
    UpdateSequenceTextPosition()

    if currentOptions.Enabled and currentOptions.ShowTrackerText ~= false then
        SequenceIconTextFrame:Show()
    end
end

local function ResetSuccessfulCastFramePosition()
    if GSE.SequenceIconStickTrackerFrames then
        GSE.SequenceIconStickTrackerFrames()
    end
    UpdateCastMirrorIcons()

    if IsSuccessfulCastFrameEnabled() then
        SuccessfulCastFrame:Show()
    end
end

local function ResetAssistedSuccessFramePosition()
    if GSE.SequenceIconStickTrackerFrames then
        GSE.SequenceIconStickTrackerFrames()
    end
    UpdateAssistedSuccessFrame()
end

local function UpdateSequenceIconFromButton(button, spellinfo, foundSpell, action)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled or not button then return end

    local sequence = ResolveSequenceKey(button)
    if not sequence then return end

    local buttonName = button.GetName and button:GetName()
    if not GSE.SequenceIconShouldAcceptSequence(sequence, true, buttonName) then return end

    local mods = GSE.SequenceIconParseModifierString(button.GetAttribute and button:GetAttribute("localmods"))
    if mods then
        local clickSerial = button.GetAttribute and tonumber(button:GetAttribute("gseclickserial") or 0) or 0
        GSE.SequenceIconCaptureMods(sequence, mods, buttonName, nil, nil, clickSerial)
    else
        MarkGSEActivity(sequence, buttonName)
    end
    local iconID = spellinfo and spellinfo.iconID
    if (not iconID or IsFallbackIcon(iconID)) and action then
        iconID = ResolveActionIcon(action)
    end
    if not iconID or IsFallbackIcon(iconID) then
        iconID = ResolveSequenceIcon(sequence)
    end

    if iconID then
        PushSequenceIcon(sequence, iconID, true, buttonName)
    elseif #SequenceIconEntries == 0 then
        SetSequencePreview(sequence, true, buttonName)
    end

    SequenceIconFrame:Show()
    UpdateSequenceText(sequence, mods)
end

local function SetSequenceIconFrameEnabled(enabled)
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.Enabled = enabled == true
    if currentOptions.Enabled and currentOptions.PrintModifiersRestored ~= true then
        GSEOptions.DebugPrintModConditionsOnKeyPress = true
        currentOptions.PrintModifiersRestored = true
    end

    if currentOptions.Enabled then
        SequenceIconFrame:Show()
        if currentOptions.ShowTrackerText ~= false then
            SequenceIconTextFrame:Show()
        else
            SequenceIconTextFrame:Hide()
        end
        ScheduleSequenceIconRefresh()
        UpdateCastMirrorIcons()
        UpdateAssistedSuccessFrame()
        -- Re-run layout (anchors frames missing a saved position to the
        -- widget defaults; frames WITH saved positions keep them).
        -- Do NOT call StickTrackerFrames here -- it wipes saved positions.
        if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    else
        ClearSequenceTextLines()
        placeholderIcon:Hide()
        SequenceIconFrame:Hide()
        SequenceIconTextFrame:Hide()
        SuccessfulCastFrame:Hide()
        AssistedSuccessFrame:Hide()
    end
    RefreshMoveModes()
end

SetSequenceIconFrameEnabled(initialOpts.Enabled)

local function SetSuccessfulCastFrameEnabled(enabled)
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.ShowSuccessfulCasts = enabled == true
    UpdateCastMirrorIcons()
    UpdateAssistedSuccessFrame()
    -- Re-run layout (preserves saved positions). Was StickTrackerFrames which wipes them.
    if GSE.SequenceIconLayoutTrackerWidget then GSE.SequenceIconLayoutTrackerWidget() end
    RefreshSuccessfulCastMoveMode()
    RefreshAssistedSuccessMoveMode()
end

-- Show/hide the dark Tracker text panel (Status / Sequence Name / Casts / Step / Blk / Hardware Events).
-- Independent of SequenceIconFrame.Enabled: respects ShowTrackerText, but only un-hides while Enabled is true.
local function SetSequenceIconTextFrameEnabled(enabled)
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.ShowTrackerText = enabled == true
    if currentOptions.ShowTrackerText and currentOptions.Enabled then
        SequenceIconTextFrame:Show()
    else
        SequenceIconTextFrame:Hide()
    end
    RefreshSequenceTextMoveMode()
end

function GSE.SequenceIconNormalizePayload(payload, second)
    local info = {}

    if type(payload) == "table" then
        info.sequence = payload.SequenceName or payload.sequenceName or payload.Sequence or payload.sequence or payload.Name or payload.name or payload[1]
        info.buttonName = payload.ButtonName or payload.buttonName or payload.Button or payload.button or info.sequence
        info.spamKey = payload.SpamKey or payload.spamKey or payload.Key or payload.key or payload.Binding or payload.binding
        info.hardwareEvent = payload.HardwareEvent or payload.hardwareEvent or payload.Hardware or payload.hardware or payload.MouseButton or payload.mouseButton
        info.clickSerial = payload.ClickSerial or payload.clickSerial or payload.Serial or payload.serial
        info.blockPath = payload.BlockPath or payload.blockPath or payload.Block or payload.block
        info.step = payload.Step or payload.step
        info.mods = payload.Mods or payload.mods or payload.ModList or payload.modList or payload.modlist
        info.spellinfo = payload.SpellInfo or payload.spellInfo or payload.spellinfo

        if type(payload[2]) == "table" then
            if payload[2].iconID or payload[2].name then
                info.spellinfo = info.spellinfo or payload[2]
            else
                info.mods = info.mods or payload[2]
            end
        elseif type(payload[2]) == "string" then
            info.spamKey = info.spamKey or payload[2]
        end

        if type(payload[3]) == "string" then
            info.hardwareEvent = info.hardwareEvent or payload[3]
        end
        if type(payload[4]) == "table" then
            info.mods = info.mods or payload[4]
        end
    else
        info.sequence = payload
        info.buttonName = payload
        if type(second) == "table" then
            if second.iconID or second.name then
                info.spellinfo = second
            else
                info.mods = second
            end
        else
            info.spamKey = second
        end
    end

    if not info.sequence and info.buttonName then
        info.sequence = ResolveUsedSequence(info.buttonName) or (IsValidSequence(info.buttonName) and info.buttonName)
    end
    if not info.buttonName then info.buttonName = info.sequence end

    return info
end

local function showSequenceIcon(event, payload, spellinfoArg)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled then return end

    local info = GSE.SequenceIconNormalizePayload(payload, spellinfoArg)
    local buttonName = info.buttonName
    local spellinfo = info.spellinfo
    local sequence = ResolveUsedSequence(info.sequence) or (IsValidSequence(info.sequence) and info.sequence)
    if not sequence or not spellinfo or not spellinfo.iconID then return end

    if PushSequenceIcon(sequence, spellinfo.iconID, false, buttonName, info.blockPath, info.step) then
        UpdateSequenceText(sequence)
    end
end

local function showModKeys(event, payload, modsArg)
    local currentOptions = EnsureSequenceIconFrameOptions()
    if not currentOptions.Enabled then return end

    local info = GSE.SequenceIconNormalizePayload(payload, modsArg)
    local buttonName = info.buttonName
    local mods = info.mods
    local sequence = ResolveUsedSequence(info.sequence) or (IsValidSequence(info.sequence) and info.sequence)
    if not sequence or not mods then return end
    if not GSE.SequenceIconShouldAcceptSequence(sequence, true, buttonName) then return end
    if not IsFreshClickSerial(lastModsMessageClickSerials, sequence, buttonName, info.clickSerial) then return end

    mods = GSE.SequenceIconReadGameMods(mods, info.hardwareEvent)
    MarkGSEActivity(sequence, buttonName, mods)
    local keyText = FormatActualKeyPress(sequence, mods, info.spamKey)
    SetActiveSpamKey(sequence, keyText)
    PushKeyHistory(info.hardwareEvent, sequence)
    activeSequence = sequence
    if #SequenceIconEntries == 0 then
        SetSequencePreview(sequence, true, buttonName)
    else
        RenderSequenceIcons()
    end
    SequenceIconFrame:Show()

    UpdateSequenceText(sequence, mods)
end

function GSE.IconFrameResize(newSize)
    local currentOptions = EnsureSequenceIconFrameOptions()
    currentOptions.IconSize = 100
    RenderSequenceIcons()
end

function GSE.SetSequenceIconFrameIconCount(newCount)
    local currentOptions = EnsureSequenceIconFrameOptions()
    local upper = currentOptions.SingleIcon and 1 or 10
    currentOptions.IconCount = ClampNumber(newCount, 1, upper, Statics.TrackerConfig.DefaultIconCount)
    TrimIconEntries()
    RenderSequenceIcons()
end

GSE.SetSequenceIconFrameEnabled = SetSequenceIconFrameEnabled
GSE.SetSuccessfulCastFrameEnabled = SetSuccessfulCastFrameEnabled
GSE.SetSequenceIconTextFrameEnabled = SetSequenceIconTextFrameEnabled
GSE.RefreshSequenceIconFrame = ScheduleSequenceIconRefresh
GSE.RefreshSuccessfulCastFrame = UpdateCastMirrorIcons
GSE.RefreshAssistedSuccessFrame = UpdateAssistedSuccessFrame
GSE.ResetSequenceIconFramePosition = ResetSequenceIconFramePosition
GSE.ResetSequenceTextFramePosition = ResetSequenceTextFramePosition
GSE.ResetSuccessfulCastFramePosition = ResetSuccessfulCastFramePosition
GSE.ResetAssistedSuccessFramePosition = ResetAssistedSuccessFramePosition
GSE.SequenceIconFrameUpdateFromButton = UpdateSequenceIconFromButton

GSE:RegisterMessage(Statics.Messages.GSE_SEQUENCE_ICON_UPDATE, showSequenceIcon)
GSE:RegisterMessage(Statics.Messages.GSE_MODS_VISIBLE, showModKeys)
GSE:RegisterMessage(Statics.Messages.SEQUENCE_UPDATED, function(event, sequence)
    if EnsureSequenceIconFrameOptions().Enabled and IsValidSequence(sequence) then
        SetSequencePreview(sequence)
    end
end)

local function RefreshAssistedHighlightFromActiveSequence()
    if not EnsureSequenceIconFrameOptions().Enabled then return end

    local sequence = activeSequence or (#SequenceIconEntries > 0 and SequenceIconEntries[1].sequence)
    RefreshAssistedHighlightIcon(sequence)
    UpdateCastMirrorIcons()
    if sequence then
        UpdateSequenceText(sequence)
    end
end

function GSE.SequenceIconResetCombatCounters()
    successfulCastCount = 0
    assistedSuccessHitCount = 0
    UpdateCastMirrorIcons()
end

function GSE.SequenceIconGetAssistedSuccessStats()
    local casts = tonumber(successfulCastCount) or 0
    local matches = tonumber(assistedSuccessHitCount) or 0
    local percent = casts > 0 and (matches / casts) * 100 or 0

    return {
        casts = casts,
        matches = matches,
        percent = percent,
        percentText = string.format("%.2f%%", percent)
    }
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
    local assistedCombatEvents = {
        "ASSISTED_COMBAT_ACTION_SPELL_CAST",
        "CURRENT_SPELL_CAST_CHANGED",
        "PLAYER_TARGET_CHANGED",
        "UNIT_TARGET",
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "SPELL_UPDATE_USABLE",
        "ACTIONBAR_UPDATE_STATE",
        "ACTIONBAR_UPDATE_USABLE",
        "ACTIONBAR_SLOT_CHANGED",
        "PLAYER_SPECIALIZATION_CHANGED",
        "UNIT_AURA"
    }
    for _, event in ipairs(assistedCombatEvents) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
end
if eventFrame.RegisterUnitEvent then
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",  "player")
    -- Empowered spells (Evoker, etc.) fire EMPOWER_START in place of SUCCEEDED at
    -- the moment the empower begins. Same payload shape (unit, castGUID, spellID)
    -- so HandleUnitSpellcastSucceeded handles it without further branching.
    -- STOP events clear GSE.SequenceIconActiveChannel so UNIT_SPELLCAST_SUCCEEDED can
    -- resume updating the icon for new hardcasts after the channel/empower ends.
    -- Retail-only: the EMPOWER event family was introduced in Dragonflight 10.0
    -- for Evoker spells. Classic/TBC/MoP-Classic clients don't recognise the
    -- event name and RegisterUnitEvent throws "Attempt to register unknown
    -- event", so gate on GSE.GameMode >= 11 (the existing Retail check used
    -- elsewhere in this file).
    if GSE.GameMode and GSE.GameMode >= 11 then
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP",  "player")
    end
else
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    if GSE.GameMode and GSE.GameMode >= 11 then
        eventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    end
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- Channel / empower START: mark active, then update the Successful Cast icon to
    -- match the channeled/empowered spell. Filter on unit == "player" so the fallback
    -- RegisterEvent code path does not toggle on others' channels.
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        local unit = ...
        if unit == "player" then GSE.SequenceIconActiveChannel = true end
        HandleUnitSpellcastSucceeded(...)
        return
    end
    -- Channel / empower STOP: clear the flag so subsequent UNIT_SPELLCAST_SUCCEEDED
    -- events can update the icon again. STOP fires on natural end AND on interrupts.
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local unit = ...
        if unit == "player" then GSE.SequenceIconActiveChannel = false end
        return
    end
    -- Normal cast SUCCEEDED: process unless a channel/empower is currently active.
    -- This makes the channel/empower icon "sticky" -- sub-casts the GSE macro fires
    -- during the channel cannot replace it.
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if GSE.SequenceIconActiveChannel then return end
        HandleUnitSpellcastSucceeded(...)
        return
    end

    local unit = ...
    if (event == "UNIT_AURA" or event == "UNIT_TARGET") and unit and unit ~= "player" and unit ~= "target" then
        return
    end

    if event == "ASSISTED_COMBAT_ACTION_SPELL_CAST"
        or event == "CURRENT_SPELL_CAST_CHANGED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "UNIT_TARGET"
        or event == "NAME_PLATE_UNIT_ADDED"
        or event == "NAME_PLATE_UNIT_REMOVED"
        or event == "SPELL_UPDATE_USABLE"
        or event == "ACTIONBAR_UPDATE_STATE"
        or event == "ACTIONBAR_UPDATE_USABLE"
        or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "UNIT_AURA" then
        RefreshAssistedHighlightFromActiveSequence()
        if event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_USABLE" or event == "UNIT_AURA" then return end
    end

    RefreshMoveModes()
    if event == "PLAYER_REGEN_DISABLED" then
        GSE.SequenceIconResetCombatCounters()
    end
    if (event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED") and EnsureSequenceIconFrameOptions().Enabled then
        UpdateAssistedSuccessFrame()
        local sequence = activeSequence or (#SequenceIconEntries > 0 and SequenceIconEntries[1].sequence)
        if sequence then
            UpdateSequenceText(sequence)
        end
    end
    if event == "MODIFIER_STATE_CHANGED" then return end

    if EnsureSequenceIconFrameOptions().Enabled then
        ScheduleSequenceIconRefresh()
    end
end)

RefreshMoveModes()
end
table.insert(ns.deferred, setup)
