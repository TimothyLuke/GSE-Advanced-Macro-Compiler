local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

-- Form-field label colour. The GSE modern theme paints labels in the
-- KEYWORD accent (gold/yellow by default). When EllesmereUI is driving
-- the look we want neutral white so the labels match the rest of EUI's
-- panel typography. Centralised so every label site stays consistent.
local function keywordColor()
    -- GSE.GUIGetColour returns r, g, b as separate values (not a table).
    -- :SetColor unpacks those into :SetTextColor(r, g, b[, a]), so we must
    -- return multiple values too — a table here would arrive as r=<table>
    -- at SetTextColor and crash.
    if GSE.IsEllesmereUILoaded and GSE.IsEllesmereUILoaded() then
        return 1, 1, 1, 1
    end
    return GSE.GUIGetColour(GSEOptions.KEYWORD)
end

local FRAME_DISPLACEMENT = 30
local DEFAULT_HEIGHT = 800
local DEFAULT_WIDTH = 800
local MIN_EDITOR_WIDTH  = 800   -- minimum resize width
local MIN_EDITOR_HEIGHT = 500   -- minimum resize height
local MAX_EDITOR_HEIGHT = 2000
local MAX_EDITOR_WIDTH = 3000
local EDITOR_SCREEN_MARGIN = 20
local TOOLBAR_OFFSET = 70
local SCROLLCONTAINER_OFFSET = 70
local MACRO_STATIC_HEADER_HEIGHT = 52
local RAW_EDITOR_BUTTON_ROW_HEIGHT = 26
local RAW_EDITOR_TEXT_HEIGHT_OFFSET = 82
local RAW_EDITOR_LEFT_PADDING = 8
local RAW_EDITOR_TOP_PADDING = 0
local ACTION_SPELL_UNIT_FIELD_WIDTH = 220
local EDITOR_DEFAULT_STRATA = "MEDIUM"
local MACRO_BLOCK_FOCUS_MARGIN = 18
local MACRO_BLOCK_FOCUS_BOTTOM_PADDING = 72

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local EnsureSequenceEditorRestoreOptions

-- Track every CreateMacroBlockSelectionOverlay return value so the live
-- Settings callback can refresh pulse parameters without rebuilding overlays.
-- Weak-keyed so destroyed frames don't leak references.
local FocusHighProcOverlays = setmetatable({}, {__mode = "k"})

-- Proc-style animation presets. Each entry bakes the alpha range, half-cycle
-- duration (each leg of the looping fadeOut→fadeIn pair) and smoothing curve
-- so a single dropdown picks a distinct *type* of proc effect rather than an
-- intensity slider. To add a new type, add a new entry here and a matching
-- container:Add() row in Options.lua — no Editor.lua wiring change needed.
-- Notes:
--   * low/high are alpha bounds (high=1.0 means fully visible at the bright
--     end of the cycle; low<1.0 dips the border by that amount each cycle).
--   * duration is each leg (so total cycle = 2*duration).
--   * smoothing "IN_OUT" gives the smooth pulse feel; "NONE" yields sharp
--     linear transitions that look more like a strobe/flash.
local FOCUS_HIGH_PROC_TYPES = {
    OFF     = { low = 1.00, high = 1.00, duration = 0.70, smoothing = "IN_OUT" },  -- solid, no animation
    PULSE   = { low = 0.45, high = 1.00, duration = 0.70, smoothing = "IN_OUT" },  -- original baseline
    FLASH   = { low = 0.30, high = 1.00, duration = 0.15, smoothing = "NONE"   },  -- sharp fast on/off
    THROB   = { low = 0.20, high = 1.00, duration = 1.00, smoothing = "IN_OUT" },  -- slow heavy fade
    BREATHE = { low = 0.65, high = 1.00, duration = 1.50, smoothing = "IN_OUT" },  -- slow gentle
    STROBE  = { low = 0.10, high = 1.00, duration = 0.08, smoothing = "NONE"   },  -- very fast alternation
}

-- Backward-compat: the previous version of this option used intensity values
-- (OFF/LOW/MEDIUM/HIGH). If a saved-variables entry still holds one of those
-- we silently map it to the nearest named type instead of falling back to the
-- default — so users who already adjusted the slider keep their preference.
local FOCUS_HIGH_PROC_LEGACY = {
    LOW    = "BREATHE",  -- previous "Low" was a gentle pulse → BREATHE
    MEDIUM = "PULSE",    -- previous "Medium" was the original baseline → PULSE
    HIGH   = "THROB",    -- previous "High" was a heavy pulse → THROB
}

-- Brightness modifier applied on top of the chosen proc TYPE. Each entry is
-- an additive shift on the type's low-alpha bound (the dim end of the cycle).
-- LOW raises the low bound (smaller swing, subtler effect); HIGH lowers it
-- (bigger swing, more dramatic). MEDIUM is the type's baseline as defined in
-- FOCUS_HIGH_PROC_TYPES. The final low alpha is clamped to [0.05, 0.95] so
-- no combination can render the border fully invisible or pin it solid.
local FOCUS_HIGH_PROC_BRIGHTNESS = {
    LOW    =  0.25,
    MEDIUM =  0.00,
    HIGH   = -0.20,
}

-- Resolve the user's saved choice to a config row. Unknown values fall back
-- to PULSE (the documented default) defensively. The base low-alpha from the
-- type table is then nudged by the Brightness modifier and clamped — the
-- resulting row is a fresh table so the FOCUS_HIGH_PROC_TYPES preset values
-- are never mutated.
local function GetFocusHighProcConfig()
    local raw = type(GSEOptions) == "table" and tostring(GSEOptions.FocusHighProc or "PULSE"):upper() or "PULSE"
    if FOCUS_HIGH_PROC_LEGACY[raw] then raw = FOCUS_HIGH_PROC_LEGACY[raw] end
    local base = FOCUS_HIGH_PROC_TYPES[raw] or FOCUS_HIGH_PROC_TYPES.PULSE

    -- OFF leaves low == high == 1.0; brightness doesn't apply (no animation
    -- to modulate). Return the base row as-is to avoid producing a swing
    -- where there was none.
    if base.low >= 1.00 then return base end

    local bRaw = type(GSEOptions) == "table" and tostring(GSEOptions.FocusHighProcBrightness or "MEDIUM"):upper() or "MEDIUM"
    local shift = FOCUS_HIGH_PROC_BRIGHTNESS[bRaw]
    if shift == nil then shift = 0.00 end

    local adjustedLow = base.low + shift
    if adjustedLow < 0.05 then adjustedLow = 0.05
    elseif adjustedLow > 0.95 then adjustedLow = 0.95 end

    return {
        low       = adjustedLow,
        high      = base.high,
        duration  = base.duration,
        smoothing = base.smoothing,
    }
end

-- Apply the current FocusHighProc type to a single overlay's pulse anim.
-- Called when the overlay is first shown and again from the live refresh
-- helper after the user changes the dropdown.
local function ApplyFocusHighProcToOverlay(overlay)
    if not (overlay and overlay.gseFadeOut and overlay.gseFadeIn and overlay.gsePulse) then return end
    local cfg = GetFocusHighProcConfig()
    overlay.gseFadeOut:SetFromAlpha(cfg.high)
    overlay.gseFadeOut:SetToAlpha(cfg.low)
    overlay.gseFadeOut:SetDuration(cfg.duration)
    if overlay.gseFadeOut.SetSmoothing then overlay.gseFadeOut:SetSmoothing(cfg.smoothing) end
    overlay.gseFadeIn:SetFromAlpha(cfg.low)
    overlay.gseFadeIn:SetToAlpha(cfg.high)
    overlay.gseFadeIn:SetDuration(cfg.duration)
    if overlay.gseFadeIn.SetSmoothing then overlay.gseFadeIn:SetSmoothing(cfg.smoothing) end
    -- OFF: stop the anim and pin the border solid. Otherwise (re)start it so
    -- the new type takes effect mid-cycle if the overlay is already visible
    -- — sharp types like STROBE switching from a smooth PULSE need a restart
    -- to clear the in-flight smoothing curve.
    if cfg.low >= 1.00 then
        overlay.gsePulse:Stop()
        overlay:SetAlpha(1.0)
    elseif overlay:IsShown() then
        overlay.gsePulse:Stop()
        overlay:SetAlpha(1.0)
        overlay.gsePulse:Play()
    end
end

-- Public refresh hook for the Settings dropdown's value-changed callback.
-- Sweeps every overlay registered during CreateMacroBlockSelectionOverlay
-- and re-applies the current FocusHighProc type — and the focus-tint
-- visibility (master toggle + disabled state) since the same Settings
-- panel hosts both controls and the tint toggle uses this hook too.
GSE.GUI.RefreshFocusHighProc = function()
    for overlay in pairs(FocusHighProcOverlays) do
        ApplyFocusHighProcToOverlay(overlay)
        if overlay.gseRefreshTint then overlay.gseRefreshTint() end
    end
end

local function EditorIsVisible(editor)
    return editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown()
end

local function RefreshEditorActivation()
    local editors = GSE.GUI and GSE.GUI.editors
    if GSE.isEmpty(editors) then
        if GSE.GUI then GSE.GUI.activeEditor = nil end
        return
    end

    local visibleCount = 0
    for _, editor in ipairs(editors) do
        if EditorIsVisible(editor) then visibleCount = visibleCount + 1 end
    end

    if visibleCount == 0 then
        GSE.GUI.activeEditor = nil
        return
    end

    if not EditorIsVisible(GSE.GUI.activeEditor) then
        for _, editor in ipairs(editors) do
            if EditorIsVisible(editor) then
                GSE.GUI.activeEditor = editor
                break
            end
        end
    end

    for _, editor in ipairs(editors) do
        local inactive = visibleCount > 1 and EditorIsVisible(editor) and editor ~= GSE.GUI.activeEditor
        if editor.inactiveOverlay then
            if inactive then
                if editor.inactiveOverlay.SetFrameLevel and editor.frame and editor.frame.GetFrameLevel then
                    editor.inactiveOverlay:SetFrameLevel(editor.frame:GetFrameLevel() + 80)
                end
                editor.inactiveOverlay:Show()
            else
                editor.inactiveOverlay:Hide()
            end
        end
    end

    if GSE.GUI.SyncTrees then GSE.GUI.SyncTrees() end
end

-- Enforce the single Left Tree rule across all open editors: only the active
-- editor shows a tree (its own), so it controls the active editor whether docked
-- or floating; every other editor's tree stays hidden. Each tree's
-- RefreshNavWindow contains the show/hide + dock/float gate; this re-runs it for
-- every editor after the active editor or detach state changes.
GSE.GUI.SyncTrees = function()
    local gui = GSE.GUI
    if not gui then return end
    -- Make sure the single tree homes onto the most-current editor. If the active
    -- editor is missing or hidden (e.g. mid-close, before RefreshEditorActivation
    -- runs), fall back to the most recently shown visible editor so the tree
    -- attaches to it rather than briefly vanishing.
    local function isVisible(e) return e and e.frame and e.frame.IsShown and e.frame:IsShown() end
    if not isVisible(gui.activeEditor) then
        for i = #(gui.editors or {}), 1, -1 do
            local e = gui.editors[i]
            if isVisible(e) then gui.activeEditor = e; break end
        end
    end
    -- Floating tree tracks the MOST ACTIVE editor: while detached it always works
    -- with whatever editor is currently active, swapping to it (at the shared float
    -- geometry) instead of staying pinned to the editor it was detached from. If the
    -- active editor isn't available yet (mid-close/hide), fall back to the most
    -- recently shown visible editor so the floating tree survives the close.
    if gui.navDetached then
        if isVisible(gui.activeEditor) then
            gui.floatOwner = gui.activeEditor
        elseif not isVisible(gui.floatOwner) then
            gui.floatOwner = nil
            for i = #(gui.editors or {}), 1, -1 do
                local e = gui.editors[i]
                if isVisible(e) then gui.floatOwner = e; break end
            end
        end
    end
    -- Floating right window follows the SAME rules as the left tree: while detached
    -- it tracks the most active editor (swapping to it at the shared float geometry)
    -- instead of staying pinned to the editor it was detached from. Falls back to the
    -- most recently shown visible editor if the active one isn't available yet
    -- (mid-close/hide) so the floating window survives the close.
    if gui.rightDetached then
        if isVisible(gui.activeEditor) then
            gui.rightFloatOwner = gui.activeEditor
        elseif not isVisible(gui.rightFloatOwner) then
            gui.rightFloatOwner = nil
            for i = #(gui.editors or {}), 1, -1 do
                local e = gui.editors[i]
                if isVisible(e) then gui.rightFloatOwner = e; break end
            end
        end
    end
    for _, editor in ipairs(gui.editors or {}) do
        local tc = editor and editor.treeContainer
        if tc and tc.RefreshNavWindow then tc.RefreshNavWindow() end
    end
    -- Enforce the single active right slideout: only the active editor's slideout
    -- may be out at a time. Inactive editors hide theirs (keeping locked/detached
    -- state) and the active editor's pops back as it was.
    for _, editor in ipairs(gui.editors or {}) do
        local p = editor and editor.leftPanel
        if p and p.RefreshSidePanel then p.RefreshSidePanel() end
    end
    -- When the tree moves to a different editor (gains a tree), open it to the
    -- sequence/version/page that editor is currently on. Only on change, so a
    -- user who scrolled the tree away isn't yanked back on every refresh.
    local shower = (gui.navDetached and gui.floatOwner) or gui.activeEditor
    if shower ~= gui.lastTreeShower then
        gui.lastTreeShower = shower
        local tc = shower and shower.treeContainer
        if tc and tc.skipNextReveal then
            -- This tree just adopted the detached tree's working location on open
            -- (attached opening rules); its menu already matches, so don't reveal /
            -- refresh and scroll it. One-shot.
            tc.skipNextReveal = nil
        elseif tc and tc.RevealSelection then
            if GSE.After then
                C_Timer.After(0, function() if tc and tc.RevealSelection then tc:RevealSelection() end end)
            else
                tc:RevealSelection()
            end
        end
    end
end

local function SetActiveEditor(editframe)
    if not editframe then return end
    GSE.GUI.activeEditor = editframe
    if editframe.frame and editframe.frame.Raise then editframe.frame:Raise() end
    -- Raise navWindow and leftPanel alongside the editor
    local function syncSidePanel(p)
        if not (p and p:IsShown()) then return end
        if p.Raise then p:Raise() end
        if editframe.frame.GetFrameStrata and p.SetFrameStrata then
            p:SetFrameStrata(editframe.frame:GetFrameStrata())
        end
        if editframe.frame.GetFrameLevel and p.SetFrameLevel then
            p:SetFrameLevel((editframe.frame:GetFrameLevel() or 0) + 1)
        end
    end
    syncSidePanel(editframe.treeContainer and editframe.treeContainer.navWindowFrame)
    syncSidePanel(editframe.leftPanel)
    RefreshEditorActivation()
end

local function ShouldUseModernEditorSkin()
    if GSE.ShouldUseModernSkin then
        return GSE.ShouldUseModernSkin()
    end
    return GSE.ShouldUseElvUISkin and GSE.ShouldUseElvUISkin()
end

local MODERN_MINI_CLASS_COLORS = {
    DEATHKNIGHT = {0.77, 0.12, 0.23, 1},
    DEMONHUNTER = {0.64, 0.19, 0.79, 1},
    DRUID = {1.00, 0.49, 0.04, 1},
    EVOKER = {0.20, 0.58, 0.50, 1},
    HUNTER = {0.67, 0.83, 0.45, 1},
    MAGE = {0.25, 0.78, 0.92, 1},
    MONK = {0.00, 1.00, 0.59, 1},
    PALADIN = {0.96, 0.55, 0.73, 1},
    PRIEST = {1.00, 1.00, 1.00, 1},
    ROGUE = {1.00, 0.96, 0.41, 1},
    SHAMAN = {0.00, 0.44, 0.87, 1},
    WARLOCK = {0.53, 0.53, 0.93, 1},
    WARRIOR = {0.78, 0.61, 0.43, 1}
}

local function GetModernMiniClassColor(alpha)
    if GSE.ShouldUseModernCustomColor and GSE.ShouldUseModernCustomColor() and GSE.GetModernCustomColor then
        return GSE.GetModernCustomColor(alpha)
    end
    if not (GSE.ShouldUseModernClassColors and GSE.ShouldUseModernClassColors()) then return nil end
    if not UnitClass then return nil end
    local localizedClass, classFile = UnitClass("player")
    classFile = classFile or localizedClass
    if type(classFile) == "string" then
        classFile = classFile:upper():gsub("%s+", "")
    end
    local color = classFile and MODERN_MINI_CLASS_COLORS[classFile]
    if not color then return nil end
    return {color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, alpha or color.a or color[4] or 1}
end

local function ApplyModernMiniBackdrop(frame, bg, border)
    if not (frame and frame.SetBackdrop) then return end
    local borderColor = border or GetModernMiniClassColor(1) or {0.22, 0.24, 0.25, 0.95}
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    frame:SetBackdropColor(unpack(bg or {0.02, 0.025, 0.028, 0.94}))
    frame:SetBackdropBorderColor(unpack(borderColor))
end

local function SetModernMiniCloseTexture(texture, active)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(not active) end
    if texture.SetVertexColor then
        if active then
            texture:SetVertexColor(1, 1, 1, 1)
        else
            texture:SetVertexColor(0.36, 0.36, 0.36, 0.78)
        end
    end
end

local MAX_MACRO_BODY = 255
local MACRO_LIMIT_BG = {0.35, 0, 0, 0.35}
local MACRO_LIMIT_BORDER = {1, 0.05, 0.05, 1}
local MACRO_NORMAL_BG = {0, 0, 0, 1}
local MACRO_NORMAL_BORDER = {0.4, 0.4, 0.4, 1}
local BLOCK_FRAME_RIGHT_STACK_OFFSET = 4
local BLOCK_FRAME_RAIL_COLORS_BY_TYPE = {
    Action = {0.00, 0.784, 0.784, 1}, -- #00c8c8
    Repeat = {0.00, 0.784, 0.784, 1}, -- #00c8c8
    Loop = {0.533, 0.533, 1.00, 1}, -- #8888ff
    If = {0.867, 0.627, 0.267, 1}, -- #dda044
    Pause = {0.867, 0.533, 0.533, 1}, -- #dd8888
    Embed = {0.533, 0.800, 0.533, 1}, -- #88cc88
}

local function BumpCheckBoxTextUp(widget)
    if widget and widget.text and widget.frame then
        widget.text:ClearAllPoints()
        widget.text:SetPoint("LEFT", widget.frame, "RIGHT", 0, 1)
        widget.text:SetJustifyV("MIDDLE")
    end
end

local function StyleEditorFrame(widget, depth, stackRight, actionType)
    if not widget then return end
    depth = math.max(0, tonumber(depth) or 0)
    local color = BLOCK_FRAME_RAIL_COLORS_BY_TYPE[actionType] or BLOCK_FRAME_RAIL_COLORS_BY_TYPE.Action
    if widget.SetLeftBorderColor then
        -- Pass `depth` as a per-pixel bottom-bump so nested action blocks'
        -- rails terminate progressively higher above their parent's bottom
        -- inset. Without this, the L-shaped bottom-left corners of stacked
        -- rails pile up at the same y-coordinate and read as one chunky
        -- multi-colored corner; with the bump each depth level steps up by
        -- one pixel, giving a clean staircase that visually separates the
        -- nest levels. depth==0 (top-level blocks) is unchanged.
        widget:SetLeftBorderColor(color[1], color[2], color[3], color[4], 3, depth)
    end
    if widget.SetListRightInset then
        widget:SetListRightInset(0)
    end
    if widget.content and widget.frame then
        widget.content:ClearAllPoints()
		widget.content:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 6, -6)
        widget.content:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 0, 0)
    end
    if widget.SetAutoHeightExtra then
        widget:SetAutoHeightExtra(0)
    else
        widget.autoHeightExtra = 0
    end
    if widget.SetListPadding then
        widget:SetListPadding(0, 0, 0, 0)
    end
    if widget.SetListGap then
        widget:SetListGap(0)
    end
    if stackRight and widget.SetFlowOffset then
        widget:SetFlowOffset(BLOCK_FRAME_RIGHT_STACK_OFFSET, widget.flowYOffset or 0)
    end
end

local function GetActionTypeColor(actionType)
    local color = BLOCK_FRAME_RAIL_COLORS_BY_TYPE[actionType] or BLOCK_FRAME_RAIL_COLORS_BY_TYPE.Action
    return color[1], color[2], color[3], color[4]
end

local function MacroBlockFrameDepth(keyPath)
    return math.max(0, #(keyPath or {}) - 1)
end

-- Visible compiled length, matching what the runtime emits and what WoW would
-- count once color escapes are stripped. UnEscapeString already removes both
-- single and doubled |c..|r forms, so this is the right thing to count.
local function GetCompiledMacroBodyLength(macroText)
    if type(macroText) ~= "string" or macroText == "" then return 0 end
    local compiled = macroText
    if GSE.CompileMacroText then
        local ok, result = pcall(GSE.CompileMacroText, macroText, Statics.TranslatorMode.String)
        if ok and result then compiled = result end
    end
    if GSE.UnEscapeString then
        local ok, result = pcall(GSE.UnEscapeString, compiled)
        if ok and result then compiled = result end
    end
    if GSE.DecodeMacroEditorText then
        compiled = GSE.DecodeMacroEditorText(compiled)
    end
    if GSE.GetMacroEditorTextLength then
        return GSE.GetMacroEditorTextLength(compiled)
    end
    return string.len(compiled or "")
end

local function CountSequenceMacroBlocksOverLimit(sequence, version)
    local overCount = 0
    local maxLength = 0

    local function scanActionList(actions)
        if type(actions) ~= "table" then return end

        for _, action in ipairs(actions) do
            if type(action) == "table" then
                if type(action.macro) == "string" and action.macro ~= "" then
                    local lenMacro = GetCompiledMacroBodyLength(action.macro)
                    maxLength = math.max(maxLength, lenMacro)
                    if lenMacro > MAX_MACRO_BODY then
                        overCount = overCount + 1
                    end
                end

                if action.Type == Statics.Actions.Loop then
                    scanActionList(action)
                elseif action.Type == Statics.Actions.If then
                    scanActionList(action[1])
                    scanActionList(action[2])
                end
            end
        end
    end

    local activeVersion = tonumber(version) or version
    if type(sequence) == "table" and type(sequence.Versions) == "table" and activeVersion then
        local sequenceVersion = sequence.Versions[activeVersion]
        if type(sequenceVersion) == "table" then
            scanActionList(sequenceVersion.Actions)
        end
    end

    return overCount, maxLength
end

local function RefreshMacroLimitSaveState(editframe, version)
    if not editframe then return true, 0, 0 end

    local requestedVersion = version or editframe.currentMacroLimitVersion
    local activeVersion = tonumber(requestedVersion) or requestedVersion
    if activeVersion then
        editframe.currentMacroLimitVersion = activeVersion
    end

    local overCount, maxLength = CountSequenceMacroBlocksOverLimit(editframe.Sequence, activeVersion)
    local disabled = overCount > 0

    editframe.macroLimitVersion = activeVersion
    editframe.macroLimitOverCount = overCount
    editframe.macroLimitMaxLength = maxLength
    editframe.macroLimitSaveDisabled = disabled

    if editframe.SaveButton and editframe.SaveButton.SetDisabled then
        editframe.SaveButton:SetDisabled(disabled)
    end

    return not disabled, overCount, maxLength
end
-- Toggle the macro edit box between normal and over-limit visuals on its
-- native scrollBG backdrop. Silent fallback if scrollBG is missing.
local function UpdateMacroLimitState(macroEditBox, macroText, editframe, version)
    local overLimit = GetCompiledMacroBodyLength(macroText) > MAX_MACRO_BODY
    local backdrop = macroEditBox and macroEditBox.scrollBG
    if backdrop and backdrop.SetBackdropColor and backdrop.SetBackdropBorderColor then
        if overLimit then
            backdrop:SetBackdropColor(unpack(MACRO_LIMIT_BG))
            backdrop:SetBackdropBorderColor(unpack(MACRO_LIMIT_BORDER))
        else
            backdrop:SetBackdropColor(unpack(MACRO_NORMAL_BG))
            backdrop:SetBackdropBorderColor(unpack(MACRO_NORMAL_BORDER))
        end
    end

    if editframe then RefreshMacroLimitSaveState(editframe, version) end
end
local MACRO_EDITOR_SCROLL_PIXELS = 96

local function GetEditorScrollContainer(frame)
    local editor = frame and (frame.obj or frame)
    return editor and editor.scrollContainer
end

-- When the macro edit box has focus, wheel scrolls inside it; otherwise
-- forward to the editor's outer scroll container.
local function ScrollFocusedMacroEditor(macroEditBox, delta)
    local editBox = macroEditBox and macroEditBox.editBox
    if not (editBox and editBox.HasFocus and editBox:HasFocus()) then return false end

    local scrollFrame = macroEditBox.scrollFrame
    if not (scrollFrame and scrollFrame.GetVerticalScroll and scrollFrame.SetVerticalScroll) then return true end

    local range = (scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange()) or 0
    if range <= 0 then return true end

    local current = scrollFrame:GetVerticalScroll() or 0
    local wheelDelta = delta or 0
    if wheelDelta > 0 then
        wheelDelta = 1
    elseif wheelDelta < 0 then
        wheelDelta = -1
    end
    local step = math.max(1, math.min(MACRO_EDITOR_SCROLL_PIXELS, range / 10))
    local target = current - (wheelDelta * step)
    if target < 0 then
        target = 0
    elseif target > range then
        target = range
    end
    scrollFrame:SetVerticalScroll(target)
    return true
end

local function MacroEditor_OnMouseWheel(mouseFrame, delta)
    local macroEditBox = mouseFrame and mouseFrame.gseWheelForwardWidget
    if ScrollFocusedMacroEditor(macroEditBox, delta) then return end

    local scrollContainer = GetEditorScrollContainer(macroEditBox and macroEditBox.gseWheelForwardFrame)
    if scrollContainer and scrollContainer.MoveScroll then
        scrollContainer:MoveScroll(delta)
    elseif mouseFrame and mouseFrame.gsePreviousOnMouseWheel then
        mouseFrame.gsePreviousOnMouseWheel(mouseFrame, delta)
    end
end

local function ForwardMacroEditorMouseWheel(macroEditBox, frame)
    if not macroEditBox then return end
    macroEditBox.gseWheelForwardFrame = frame

    for _, mouseFrame in ipairs({ macroEditBox.editBox, macroEditBox.scrollFrame }) do
        if mouseFrame and mouseFrame.SetScript then
            mouseFrame.gseWheelForwardWidget = macroEditBox
            if not mouseFrame.gseMacroWheelForwarded then
                mouseFrame.gsePreviousOnMouseWheel = mouseFrame.GetScript and mouseFrame:GetScript("OnMouseWheel")
                mouseFrame:SetScript("OnMouseWheel", MacroEditor_OnMouseWheel)
                mouseFrame.gseMacroWheelForwarded = true
            end
            if mouseFrame.EnableMouseWheel then mouseFrame:EnableMouseWheel(true) end
        end
    end
end

-- Inline "X/255" indicator anchored to the top-right of the macro edit box,
-- replacing the old side-panel that listed compiled output. Created on first
-- call; subsequent calls just retext + recolour.
local function SetMacroCountText(macroEditBox, lenMacro)
    if not (macroEditBox and macroEditBox.frame) then return end

    local fs = macroEditBox.gseMacroCountText
    if not fs then
        fs = macroEditBox.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("RIGHT")
        fs:SetJustifyV("MIDDLE")
        fs:ClearAllPoints()
        local anchor = macroEditBox.label or macroEditBox.frame
        local rightOffset = (macroEditBox.scrollBarReserve or 24) + (macroEditBox.rightOffset or 4)
        fs:SetPoint("RIGHT", anchor, "RIGHT", -rightOffset, 0)
        macroEditBox.gseMacroCountText = fs
    end

    lenMacro = lenMacro or 0
    local text = string.format("%d/%d", lenMacro, MAX_MACRO_BODY)
    if lenMacro > MAX_MACRO_BODY then
        local prefix = (GSEOptions and GSEOptions.UNKNOWN) or "|cffff5555"
        local suffix = (Statics and Statics.StringReset) or "|r"
        fs:SetText(prefix .. text .. suffix)
    else
        fs:SetText(text)
    end
end

-- Exposed so GSE_QoL's CreateSpellEditBox override can wire the same hooks.
GSE.GUI.UpdateMacroLimitState = UpdateMacroLimitState
GSE.GUI.RefreshMacroLimitSaveState = RefreshMacroLimitSaveState
GSE.GUI.ForwardMacroEditorMouseWheel = ForwardMacroEditorMouseWheel
GSE.GUI.SetMacroCountText = SetMacroCountText
-- The "X/255" indicator must report the SAME length the over-limit trigger
-- (UpdateMacroLimitState) and WoW itself enforce: the compiled body, after
-- spell-name translation. Showing the raw typed length instead made the
-- counter read e.g. 252/255 while the trigger fired on the 256-char compiled
-- body. Expose the compiled-length helper so every counter call site uses it.
GSE.GUI.GetCompiledMacroBodyLength = GetCompiledMacroBodyLength

local DecodeEditorText = GSE.DecodeEditorText
local DecodeMacroEditorText = GSE.DecodeMacroEditorText

local function DisableRawEditorColoring(rawEditBox)
    if rawEditBox and rawEditBox.editBox and IndentationLib and IndentationLib.disable then
        IndentationLib.disable(rawEditBox.editBox)
    end
end

local function DisableMultilineEditorColoring(editBox)
    if editBox and editBox.editBox and IndentationLib and IndentationLib.disable then
        IndentationLib.disable(editBox.editBox)
    end
end

local StoreMacroEditorText = GSE.StoreMacroEditorText
local INGAME_MACRO_BLOCK_ICON = "Interface\\AddOns\\GSE_GUI\\Assets\\macro.png"
local VARIABLE_BLOCK_ICON = "Interface\\AddOns\\GSE_GUI\\Assets\\variables.png"

-- ============================================================================
-- Macro editor cursor mapping (8-year cursor-snap-back fix, 2026-05-29)
-- ----------------------------------------------------------------------------
-- Problem (long-standing): when the user typed or pasted a spell name that
-- the GSE translator rewrites to its base form ("Azure Sweep" → "Azure
-- Strike"), the macro edit box re-coloured + retranslated the text on
-- OnTextChanged, and the cursor landed 1 visible char short of the end of
-- the translated word. Four prior fix attempts in this session all failed:
--     1. Skip trailing |r tokens after the visible target            (no)
--     2. Use string.len + 1 in the exhausted-loop fallback           (no)
--     3. Snap-to-end heuristic with + 1                              (no)
--     4. Snap-to-end heuristic with + 2                              (no)
-- ...because every one of them used a WHOLE-TEXT atEnd check:
--     visibleCursor >= currentTotalVisible
-- That check only fires when the cursor sits at the end of the ENTIRE
-- buffer. On any line of a multi-line macro that has more lines below it
-- (the common case), visibleCursor < currentTotalVisible, the atEnd branch
-- never runs, and the visible-offset-preservation branch lands cursor mid-
-- translated-word because the translated word has more visible chars than
-- the typed source. End-of-LINE ≠ end-of-TEXT was the missing distinction.
--
-- Verified diagnostic from the working fix (Larry's own play session):
--     APPLY line=1 visInLine=17 atEOL=true newCur=118 dispLen=116
--     AFTER postCur=116
-- line=1 (second line) with atEOL=true was the exact case the old code
-- missed; cursor snapped to 116 (= dispLen, clamped by WoW from the +2
-- overshoot) = visual end of line. ✓
--
-- Fix architecture: two helpers replacing the old whole-text pair.
--     analyzeMacroEditorCursor(text, pos)
--         → (lineIndex, visibleOffsetInLine, isAtEndOfLine)
--         walks per-line, treats "next byte is \n" the same as "at end of
--         text" for atEOL purposes.
--     macroEditorCursorPositionForLineOffset(text, lineIndex, visInLine, atEOL)
--         → byte cursor position
--         when atEOL, snaps to end of the corresponding line in `text`
--         (byte just before its \n, or len+2 for last line so WoW clamps
--         to end). Otherwise preserves visible offset within the line.
--
-- DO NOT reintroduce a single whole-text "atEnd" check here. If the cursor
-- starts snapping back again in some new scenario, the right move is to
-- adjust analyzeMacroEditorCursor / macroEditorCursorPositionForLineOffset
-- to handle that scenario per-line, not to add a global heuristic on top.
-- ============================================================================

local function getMacroEditorColoredDisplayText(text)
    if type(text) ~= "string" or string.sub(text, 1, 1) ~= "/" or not GSE.CompileMacroText then return nil end

    local ok, displayText = pcall(GSE.CompileMacroText, text, Statics.TranslatorMode.Current)
    if not ok or type(displayText) ~= "string" or displayText == "" then return nil end
    return displayText
end

-- Map a raw cursor byte position in coloured macro text to (lineIndex,
-- visibleOffsetInLine, isAtEndOfLine). "Line" is a stretch between '\n'
-- separators; visible offset within a line counts visible glyphs only
-- (skipping |c...|r markup), so the result maps cleanly to a different
-- coloured/translated version of the same line.
local function analyzeMacroEditorCursor(text, cursorPosition)
    if type(text) ~= "string" or not cursorPosition or cursorPosition <= 0 then
        return 0, 0, (cursorPosition or 0) >= ((type(text) == "string") and string.len(text) or 0)
    end

    local textLen = string.len(text)
    local index = 1
    local lineIndex = 0
    local visibleInLine = 0
    local limit = math.min(cursorPosition, textLen)

    while index <= limit do
        local character     = string.sub(text, index, index)
        local nextCharacter = string.sub(text, index + 1, index + 1)

        if character == "|" and (nextCharacter == "c" or nextCharacter == "C")
                and string.match(string.sub(text, index + 2, index + 9), "^%x%x%x%x%x%x%x%x$") then
            index = index + 10
        elseif character == "|" and nextCharacter == "r" then
            index = index + 2
        elseif character == "|" and nextCharacter == "|" then
            visibleInLine = visibleInLine + 1
            index = index + 2
        elseif character == "\n" then
            lineIndex = lineIndex + 1
            visibleInLine = 0
            index = index + 1
        else
            visibleInLine = visibleInLine + 1
            index = index + 1
        end
    end

    -- "End of line" means there is no further visible content on this line
    -- in the source text: either we're at end of total text, or the next byte
    -- is '\n'. Both cases need snap-to-line-end (translation may change the
    -- byte length of any word on this line, so visible-offset preservation
    -- would land the cursor mid-translated-word).
    local atEndOfLine = (cursorPosition >= textLen)
    if not atEndOfLine then
        if string.sub(text, cursorPosition + 1, cursorPosition + 1) == "\n" then
            atEndOfLine = true
        end
    end

    return lineIndex, visibleInLine, atEndOfLine
end

-- Inverse of analyzeMacroEditorCursor: given a target (lineIndex,
-- visibleOffsetInLine, isAtEndOfLine), return the byte cursor position in
-- `text` that lands at the equivalent visual spot. If isAtEndOfLine, snap to
-- the actual end of that line in `text` regardless of the visible offset.
local function macroEditorCursorPositionForLineOffset(text, targetLine, visibleOffsetInLine, isAtEndOfLine)
    if type(text) ~= "string" then return 0 end

    local textLen = string.len(text)
    local index = 1
    local lineCount = 0
    local visibleInLine = 0

    while index <= textLen do
        local character     = string.sub(text, index, index)
        local nextCharacter = string.sub(text, index + 1, index + 1)

        if character == "|" and (nextCharacter == "c" or nextCharacter == "C")
                and string.match(string.sub(text, index + 2, index + 9), "^%x%x%x%x%x%x%x%x$") then
            index = index + 10
        elseif character == "|" and nextCharacter == "r" then
            index = index + 2
        elseif character == "\n" then
            if lineCount == targetLine then
                -- End of the target line, with more lines below. Cursor goes
                -- "after the byte just before \n" = position (index - 1) in
                -- WoW's 0-indexed-from-before cursor system.
                return index - 1
            end
            lineCount = lineCount + 1
            visibleInLine = 0
            index = index + 1
        elseif character == "|" and nextCharacter == "|" then
            if lineCount == targetLine then
                visibleInLine = visibleInLine + 1
                index = index + 2
                if not isAtEndOfLine and visibleInLine >= visibleOffsetInLine then
                    return index - 1
                end
            else
                index = index + 2
            end
        else
            if lineCount == targetLine then
                visibleInLine = visibleInLine + 1
                index = index + 1
                if not isAtEndOfLine and visibleInLine >= visibleOffsetInLine then
                    return index - 1
                end
            else
                index = index + 1
            end
        end
    end

    -- Reached end of text. Target line was the last line (or text has fewer
    -- lines than expected). WoW treats SetCursorPosition(len) as "before last
    -- byte" when text ends with |r, so overshoot by 2 and let WoW clamp —
    -- same pattern used historically for end-of-text.
    return textLen + 2
end

local function RefreshMacroEditorColoredText(widget, plainText)
    if not (widget and widget.SetText) then return end

    local displayText = getMacroEditorColoredDisplayText(plainText)
    if not displayText then return end

    local editBox = widget.editBox or widget.editbox
    local currentText = widget.GetText and widget:GetText() or (editBox and editBox.GetText and editBox:GetText()) or ""
    -- Mid-word with trailing whitespace = user is still typing; wait for them
    -- to commit a non-space char before re-coloring (avoids tripping the
    -- translator on partial words).
    if type(currentText) == "string" and currentText:match("%s$") then return end
    if displayText == currentText then return end  -- normal no-op (editor first load)

    local cursorPosition = editBox and editBox.GetCursorPosition and editBox:GetCursorPosition() or nil

    -- Per-line cursor mapping. See the long comment block above the cursor
    -- helpers for why this is per-line and not whole-text. DO NOT replace
    -- with a single global atEnd check.
    local lineIndex, visibleInLine, atEndOfLine =
        analyzeMacroEditorCursor(currentText, cursorPosition)
    local newCursor =
        macroEditorCursorPositionForLineOffset(displayText, lineIndex, visibleInLine, atEndOfLine)

    widget.GSEMacroEditorColoring = true
    if editBox then editBox.GSEMacroEditorColoring = true end
    widget:SetText(displayText)
    -- Defer cursor restore to the next frame so WoW's internal post-SetText
    -- caret handling (scroll/layout recalculation done in C after Lua returns)
    -- runs first and our SetCursorPosition wins. Same pattern as
    -- Export.lua:351 and DebugWindow.lua:2799.
    if editBox and editBox.SetCursorPosition and editBox.HasFocus and editBox:HasFocus() then
        local capturedBox    = editBox
        local capturedCursor = newCursor
        C_Timer.After(0, function()
            if capturedBox and capturedBox.SetCursorPosition then
                capturedBox:SetCursorPosition(capturedCursor)
            end
        end)
    end
    if editBox then editBox.GSEMacroEditorColoring = nil end
    widget.GSEMacroEditorColoring = nil
end

GSE.GUI.RefreshMacroEditorColoredText = RefreshMacroEditorColoredText

local function trimIconCandidate(value)
    local trimmed = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed
end

local function isVariableMacroBody(macro)
    return string.find(trimIconCandidate(macro), "^=GSE%.V%.") ~= nil
end

local function isVariableAction(action)
    return type(action) == "table" and action.macro and isVariableMacroBody(GSE.UnEscapeString(action.macro))
end

local function isInGameMacroBody(macro)
    macro = trimIconCandidate(macro)
    if macro == "" then return false end

    local firstCharacter = string.sub(macro, 1, 1)
    return firstCharacter ~= "/" and firstCharacter ~= "="
end

local function isInGameMacroAction(action)
    return type(action) == "table" and action.macro and isInGameMacroBody(GSE.UnEscapeString(action.macro))
end

local FORM_SPELL_IDS = {
    [71] = true, -- Defensive Stance
    [768] = true, -- Cat Form
    [783] = true, -- Travel Form
    [1066] = true, -- Aquatic Form
    [2457] = true, -- Battle Stance
    [2458] = true, -- Berserker Stance
    [2645] = true, -- Ghost Wolf
    [5487] = true, -- Bear Form
    [24858] = true, -- Moonkin Form
    [33891] = true, -- Tree of Life
    [33943] = true, -- Flight Form
    [40120] = true, -- Swift Flight Form
    [114282] = true, -- Treant Form
    [165961] = true, -- Stag Form
    -- Pet summoning slots: treated the same as forms/stances. A line like
    -- /cast Call Pet 1 should not steal the action icon unless it is the
    -- only valid candidate in the macro block.
    [883]    = true, -- Call Pet 1
    [83242]  = true, -- Call Pet 2
    [83243]  = true, -- Call Pet 3
    [83244]  = true, -- Call Pet 4
    [83245]  = true, -- Call Pet 5
}

local SPELL_NAME_ICON_FALLBACK_IDS = {
    ["demon blades"] = { 203555 },
    ["dream breath"] = { 355936, 355941, 382614 },
    ["lifetreading"] = { 1217941 },
    ["rapid fire"]   = { 257044 }, -- Marksmanship Hunter channel
}

local function isFormSpellCandidate(value)
    local candidate = trimIconCandidate(value)
    if candidate == "" then return false end

    local spellID = tonumber(candidate)
    if spellID and FORM_SPELL_IDS[spellID] then return true end

    local lowerCandidate = strlower(candidate)
    return lowerCandidate == "ghost wolf" or lowerCandidate == "tree of life" or
        lowerCandidate:match("%f[%a]form%f[%A]") ~= nil or
        lowerCandidate:match("%f[%a]stance%f[%A]") ~= nil or
        -- "Call Pet", "Call Pet 1" ... "Call Pet 5"
        lowerCandidate:match("^call pet%f[%A]") ~= nil
end

local function isFormIconInfo(spellinfo)
    if type(spellinfo) ~= "table" then return false end
    return isFormSpellCandidate(spellinfo.spellID) or isFormSpellCandidate(spellinfo.name)
end

local function getFirstIconInfo(spellinfo, skipForms)
    if not spellinfo then return nil end
    if spellinfo.iconID and not (skipForms and isFormIconInfo(spellinfo)) then return spellinfo end
    for _, candidate in ipairs(spellinfo) do
        if candidate and candidate.iconID and not (skipForms and isFormIconInfo(candidate)) then return candidate end
    end
end

local function isQuestionMarkIcon(icon)
    if GSE.isEmpty(icon) then return false end
    if tonumber(icon) == Statics.QuestionMarkIconID then return true end
    if type(icon) ~= "string" then return false end

    local iconText = strlower(icon)
    local questionMark = Statics.QuestionMark and strlower(Statics.QuestionMark) or "inv_misc_questionmark"
    return iconText == questionMark or string.find(iconText, "questionmark", 1, true) ~= nil
end

local function isAutomaticCategorisedActionIcon(action)
    if type(action) ~= "table" or action.IconUserSelected or type(action.Icon) ~= "string" then return false end

    local icon = strlower(action.Icon)
    return icon == strlower(INGAME_MACRO_BLOCK_ICON) or icon == strlower(VARIABLE_BLOCK_ICON)
end

local function shouldAutoFillActionIcon(action)
    return type(action) == "table" and
        (GSE.isEmpty(action.Icon) or isQuestionMarkIcon(action.Icon) or isAutomaticCategorisedActionIcon(action))
end

local function isIconBearingAction(action)
    if type(action) ~= "table" then return false end
    if action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then return true end

    return not GSE.isEmpty(action.macro) or not GSE.isEmpty(action.spell) or
        not GSE.isEmpty(action.item) or not GSE.isEmpty(action.toy)
end

local function getManualActionIcon(action)
    if type(action) == "table" and action.Icon and not isQuestionMarkIcon(action.Icon) and not isAutomaticCategorisedActionIcon(action) then
        return action.Icon
    end
end

local function stripLeadingIconConditionals(value)
    value = trimIconCandidate(value)
    while string.sub(value, 1, 1) == "[" do
        local closing = string.find(value, "]", 1, true)
        if not closing then break end
        value = trimIconCandidate(string.sub(value, closing + 1))
    end
    return value
end

local function normaliseIconCandidate(value)
    value = stripLeadingIconConditionals(value)
    value = trimIconCandidate(value:gsub("^reset=%S+%s*", ""))
    while string.sub(value, 1, 1) == "!" do
        value = trimIconCandidate(string.sub(value, 2))
    end
    return value
end

local function getItemIconInfo(candidate)
    local icon = select(10, C_Item.GetItemInfo(candidate))
    if icon then
        return {
            name = candidate,
            iconID = icon,
        }
    end
end

local function getEquipmentSlotIconInfo(candidate)
    local slot = tonumber(trimIconCandidate(candidate))
    if not slot or slot < 1 or slot > 19 then return nil end

    if GetInventoryItemTexture then
        local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
        if ok and texture then
            return {
                name = "equipment slot " .. slot,
                iconID = texture,
            }
        end
    end

    if GetInventoryItemID and C_Item and C_Item.GetItemIconByID then
        local ok, itemID = pcall(GetInventoryItemID, "player", slot)
        if ok and itemID then
            local okIcon, icon = pcall(C_Item.GetItemIconByID, itemID)
            if okIcon and icon then
                return {
                    name = "equipment slot " .. slot,
                    iconID = icon,
                }
            end
        end
    end
end

local function getSpellNameFallbackIconInfo(candidate, skipForms)
    local spellIDs = SPELL_NAME_ICON_FALLBACK_IDS[strlower(trimIconCandidate(candidate))]
    if not spellIDs then return nil end

    for _, spellID in ipairs(spellIDs) do
        if not (skipForms and isFormSpellCandidate(spellID)) then
            local spellInfo = GSE.GetSpellInfo(spellID)
            if spellInfo and spellInfo.iconID and not (skipForms and isFormIconInfo(spellInfo)) then
                return spellInfo
            end
        end
    end
end

local function getSpellOrItemIconInfo(candidate, preferItem, skipForms)
    candidate = normaliseIconCandidate(candidate)
    if candidate == "" then return nil end
    if preferItem and tonumber(candidate) and tonumber(candidate) <= 19 then
        return getEquipmentSlotIconInfo(candidate)
    end
    if skipForms and isFormSpellCandidate(candidate) then return nil end

    if preferItem then
        local itemInfo = getItemIconInfo(candidate)
        if itemInfo then return itemInfo end
    end

    local spellInfo = GSE.GetSpellInfo(candidate)
    if spellInfo and spellInfo.iconID and not (skipForms and isFormIconInfo(spellInfo)) then return spellInfo end
    if tonumber(candidate) then
        spellInfo = GSE.GetSpellInfo(tonumber(candidate))
        if spellInfo and spellInfo.iconID and not (skipForms and isFormIconInfo(spellInfo)) then return spellInfo end
    end
    if GSE.GetSpellId then
        local spellID = GSE.GetSpellId(candidate, Statics.TranslatorMode.ID, true)
        if spellID and spellID ~= candidate and not (skipForms and isFormSpellCandidate(spellID)) then
            spellInfo = GSE.GetSpellInfo(spellID)
            if spellInfo and spellInfo.iconID and not (skipForms and isFormIconInfo(spellInfo)) then return spellInfo end
        end
    end

    spellInfo = getSpellNameFallbackIconInfo(candidate, skipForms)
    if spellInfo then return spellInfo end

    return getItemIconInfo(candidate)
end

local function getKnownConditionalIconInfo(candidate, skipForms)
    for spellID in tostring(candidate or ""):gmatch("%f[%w]known:(%d+)") do
        local iconInfo = getSpellOrItemIconInfo(spellID, nil, skipForms)
        if iconInfo then return iconInfo end
    end
end

local function getFallbackCandidateIconInfo(candidate, preferItem, skipForms)
    local knownIconInfo
    for _, semicolonCandidate in ipairs(GSE.split(candidate or "", ";")) do
        knownIconInfo = knownIconInfo or getKnownConditionalIconInfo(semicolonCandidate, skipForms)
        semicolonCandidate = normaliseIconCandidate(semicolonCandidate)
        for _, commaCandidate in ipairs(GSE.split(semicolonCandidate, ",")) do
            local iconInfo = getSpellOrItemIconInfo(commaCandidate, preferItem, skipForms)
            if iconInfo then return iconInfo end
        end
    end
    return knownIconInfo
end

local function getCastSequenceIconInfo(candidate, skipForms)
    local knownIconInfo
    for _, semicolonCandidate in ipairs(GSE.split(candidate or "", ";")) do
        knownIconInfo = knownIconInfo or getKnownConditionalIconInfo(semicolonCandidate, skipForms)
        for _, sequenceCandidate in ipairs(GSE.SplitCastSequence(semicolonCandidate)) do
            local _, _, etc = GSE.GetConditionalsFromString(sequenceCandidate)
            local iconInfo = getFallbackCandidateIconInfo(etc, nil, skipForms)
            if iconInfo then return iconInfo end
        end
    end
    return knownIconInfo
end

local function getMacroLineResolvedIconInfo(line, skipForms)
    local cmd, etc = string.match(line or "", "^%s*/(%w+)%s+([^\n]+)")
    if not cmd or not etc then return nil end

    cmd = strlower(cmd)
    if not Statics.CastCmds[cmd] then return nil end
    if cmd == "stopmacro" or cmd == "cancelaura" or cmd == "cancelform" or cmd == "petautocastoff" or cmd == "petautocaston" then return nil end

    local resolved = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(etc, true)
    resolved = trimIconCandidate(resolved)
    if resolved == "" then return nil end

    if cmd == "castsequence" then
        return getCastSequenceIconInfo(resolved, skipForms)
    end

    local preferItem = cmd == "use" or cmd == "usetoy" or cmd == "toy"
    return getFallbackCandidateIconInfo(resolved, preferItem, skipForms)
end

local function getMacroLineFallbackIconInfo(line, skipForms)
    local cmd, etc = string.match(line or "", "^%s*/(%w+)%s+([^\n]+)")
    if not cmd or not etc then return nil end

    cmd = strlower(cmd)
    if cmd == "castsequence" then
        return getCastSequenceIconInfo(etc, skipForms)
    end

    if not Statics.CastCmds[cmd] then return nil end
    if cmd == "stopmacro" or cmd == "cancelaura" or cmd == "cancelform" or cmd == "petautocastoff" or cmd == "petautocaston" then return nil end

    local preferItem = cmd == "use" or cmd == "usetoy" or cmd == "toy"
    local iconInfo = getFallbackCandidateIconInfo(etc, preferItem, skipForms)
    if iconInfo then return iconInfo end

    local _, _, parsedEtc = GSE.GetConditionalsFromString("/" .. cmd .. " " .. etc)
    if type(parsedEtc) ~= "string" or parsedEtc == "" or string.sub(parsedEtc, 1, 1) == "/" then
        parsedEtc = etc
    end

    local resolved = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(parsedEtc, true)
    local candidate = resolved and trimIconCandidate(resolved) or stripLeadingIconConditionals(parsedEtc)

    return getFallbackCandidateIconInfo(candidate, preferItem, skipForms)
end

local function getMacroLineResolvedIconCandidate(line)
    local cmd, etc = string.match(line or "", "^%s*/(%w+)%s+([^\n]+)")
    if not cmd or not etc then return nil end

    cmd = strlower(cmd)
    if not Statics.CastCmds[cmd] then return nil end
    if cmd == "stopmacro" or cmd == "cancelaura" or cmd == "cancelform" or cmd == "petautocastoff" or cmd == "petautocaston" then return nil end

    local _, _, parsedEtc = GSE.GetConditionalsFromString("/" .. cmd .. " " .. etc)
    if type(parsedEtc) ~= "string" or parsedEtc == "" or string.sub(parsedEtc, 1, 1) == "/" then
        parsedEtc = etc
    end

    local resolved = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(parsedEtc, true)
    return resolved and trimIconCandidate(resolved) or stripLeadingIconConditionals(parsedEtc)
end

local function isMacroLineFormOrStance(line)
    return isFormSpellCandidate(getMacroLineResolvedIconCandidate(line))
end

local function getFirstMacroLineIconInfo(macro, skipForms)
    for _, line in ipairs(GSE.SplitMeIntoLines(macro or "")) do
        if not (skipForms and isMacroLineFormOrStance(line)) then
            local spellinfo = GSE.GetSpellsFromString(line, true)
            local iconInfo = getMacroLineResolvedIconInfo(line, skipForms) or getFirstIconInfo(spellinfo, skipForms) or getMacroLineFallbackIconInfo(line, skipForms)
            if iconInfo then return iconInfo end
        end
    end
end

local function getFirstMacroFormIconInfo(macro)
    for _, line in ipairs(GSE.SplitMeIntoLines(macro or "")) do
        local spellinfo = GSE.GetSpellsFromString(line, true)
        local iconInfo = getFirstIconInfo(spellinfo) or getMacroLineFallbackIconInfo(line)
        if iconInfo then
            return (isFormIconInfo(iconInfo) or isMacroLineFormOrStance(line)) and iconInfo or nil
        end
    end
end

local function getOnlyMacroFormIconInfo(macro)
    local formIconInfo

    for _, line in ipairs(GSE.SplitMeIntoLines(macro or "")) do
        local spellinfo = GSE.GetSpellsFromString(line, true)
        local iconInfo = getFirstIconInfo(spellinfo) or getMacroLineFallbackIconInfo(line)
        if iconInfo then
            if not (isFormIconInfo(iconInfo) or isMacroLineFormOrStance(line)) then
                return nil
            end
            formIconInfo = formIconInfo or iconInfo
        end
    end

    return formIconInfo
end

local function iconValuesMatch(left, right)
    if left == right then return true end
    if tonumber(left) and tonumber(right) then return tonumber(left) == tonumber(right) end
    if type(left) == "string" and type(right) == "string" then return strlower(left) == strlower(right) end
    return false
end

local function getResolvedMacroBody(action)
    local macro = action and action.macro and GSE.UnEscapeString(action.macro) or ""
    if string.sub(macro, 1, 1) == "=" then
        local compiled = GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
        if compiled and string.sub(compiled, 1, 1) == "/" then macro = compiled end
    end
    return macro
end

local function shouldReplaceFormActionIcon(action)
    if type(action) ~= "table" or GSE.isEmpty(action.Icon) or isQuestionMarkIcon(action.Icon) then return false end
    if action.IconUserSelected then return false end
    if GSE.isEmpty(action.macro) then return false end

    local macro = getResolvedMacroBody(action)
    if string.sub(macro, 1, 1) ~= "/" then return false end

    local formIconInfo = getFirstMacroFormIconInfo(macro)
    if not formIconInfo then return false end

    local replacementIconInfo = getFirstMacroLineIconInfo(macro, true)
    return replacementIconInfo and replacementIconInfo.iconID and
        not iconValuesMatch(replacementIconInfo.iconID, formIconInfo.iconID)
end

local function shouldUseCategorisedActionIcon(action)
    return type(action) == "table" and not action.IconUserSelected and
        (isVariableAction(action) or isInGameMacroAction(action))
end

local function getActionIconType(action)
    if type(action) ~= "table" then return nil end

    local actionType = type(action.type) == "string" and strlower(action.type) or action.type
    if actionType ~= "macro" and actionType ~= "spell" and actionType ~= "item" and actionType ~= "toy" then
        actionType = nil
    end

    if GSE.isEmpty(actionType) then
        if not GSE.isEmpty(action.macro) then
            actionType = "macro"
        elseif not GSE.isEmpty(action.spell) then
            actionType = "spell"
        elseif not GSE.isEmpty(action.item) then
            actionType = "item"
        elseif not GSE.isEmpty(action.toy) then
            actionType = "toy"
        end
    end

    return actionType
end

-- Treat WoW's default question-mark texture as "not resolved" so callers
-- can re-try later (e.g. after the GSESpellCache picks up an entry) instead
-- of baking 134400 into action.Icon and considering the icon "done".
local function notQuestionMark(iconID)
    if iconID and isQuestionMarkIcon(iconID) then return nil end
    return iconID
end

local function getActionAutoIcon(action)
    if type(action) ~= "table" then return nil end

    local actionType = getActionIconType(action)

    if actionType == "spell" then
        local si = action.spell and GSE.GetSpellInfo(action.spell)
        -- Cross-class fallback: spell names that fail C_Spell.GetSpellInfo
        -- (because the current character does not know that spell) can
        -- still resolve via the saved-variable name->ID cache.
        if (not si or not si.iconID) and type(action.spell) == "string" and not tonumber(action.spell) and type(GSESpellCache) == "table" then
            local locale = GetLocale and GetLocale() or "enUS"
            local cachedID = GSESpellCache[locale] and GSESpellCache[locale][action.spell]
            if cachedID then si = GSE.GetSpellInfo(cachedID) end
        end
        return notQuestionMark(si and si.iconID)
    elseif actionType == "item" or actionType == "toy" then
        local itemKey = action.item or action.toy
        if itemKey then
            return notQuestionMark(select(10, C_Item.GetItemInfo(itemKey)))
        end
    elseif actionType == "macro" then
        if isVariableAction(action) then return VARIABLE_BLOCK_ICON end
        if isInGameMacroAction(action) then
            -- Prefer the icon the user assigned to the in-game macro itself.
            -- Only fall back to macro.png (INGAME_MACRO_BLOCK_ICON) when the
            -- macro can't be resolved or its icon is the default '?'.
            local body = trimIconCandidate(GSE.UnEscapeString(action.macro or ""))
            local macindex = GetMacroIndexByName and GetMacroIndexByName(body) or 0
            if macindex and macindex > 0 and GetMacroInfo then
                local _, micon = GetMacroInfo(macindex)
                local resolved = notQuestionMark(micon)
                if resolved then return resolved end
            end
            return INGAME_MACRO_BLOCK_ICON
        end

        local macro = getResolvedMacroBody(action)
        if string.sub(macro, 1, 1) == "/" then
            local spellstuff = getFirstMacroLineIconInfo(macro, true) or getOnlyMacroFormIconInfo(macro)
            return notQuestionMark(spellstuff and spellstuff.iconID)
        else
            local macindex = GetMacroIndexByName(macro)
            local _, micon = GetMacroInfo(macindex)
            return notQuestionMark(micon)
        end
    end
end

local function addIconMenuCandidates(list, spellinfo)
    if not spellinfo then return end
    if spellinfo.iconID then
        for _, candidate in ipairs(list) do
            if candidate.iconID == spellinfo.iconID and candidate.name == spellinfo.name then return end
        end
        table.insert(list, spellinfo)
        return
    end
    for _, candidate in ipairs(spellinfo) do
        if candidate and candidate.iconID then
            addIconMenuCandidates(list, candidate)
        end
    end
end

local actionIconControls = setmetatable({}, {__mode = "v"})
local actionIconDirtySequences = setmetatable({}, {__mode = "k"})

local function countPendingActionIconSaves()
    local pendingSequences = 0
    local pendingIcons = 0

    for sequence, iconCount in pairs(actionIconDirtySequences) do
        if type(sequence) == "table" and (iconCount or 0) > 0 then
            pendingSequences = pendingSequences + 1
            pendingIcons = pendingIcons + iconCount
        end
    end

    return pendingSequences, pendingIcons
end

local function registerActionIconControl(control)
    table.insert(actionIconControls, control)
end

local function refreshActionIconControls()
    local refreshed = 0
    for _, control in pairs(actionIconControls) do
        if control and control.RefreshIcon then
            control:RefreshIcon()
            refreshed = refreshed + 1
        end
    end
    return refreshed
end

local function refreshActionIconControlFor(sequence, version, keyPath)
    for _, control in pairs(actionIconControls) do
        if control and control.RefreshIcon and control.GSESequence == sequence and
            control.GSEVersion == version and control.GSEKeyPath == keyPath then
            control:RefreshIcon()
            return true
        end
    end
    return false
end

GSE.GUI.RefreshActionIconFor = refreshActionIconControlFor

local function getMacroIconDebugCandidate(macro)
    for _, line in ipairs(GSE.SplitMeIntoLines(macro or "")) do
        local cmd, etc = string.match(line or "", "^%s*/(%w+)%s+([^\n]+)")
        if cmd and etc then
            cmd = strlower(cmd)
            if cmd == "castsequence" then
                for _, semicolonCandidate in ipairs(GSE.split(etc, ";")) do
                    for _, sequenceCandidate in ipairs(GSE.SplitCastSequence(semicolonCandidate)) do
                        local _, _, sequenceEtc = GSE.GetConditionalsFromString(sequenceCandidate)
                        local candidate = normaliseIconCandidate(sequenceEtc)
                        if candidate ~= "" then return cmd .. "=" .. candidate end
                    end
                end
            elseif Statics.CastCmds[cmd] and cmd ~= "stopmacro" and cmd ~= "cancelaura" and cmd ~= "cancelform" then
                local candidate = normaliseIconCandidate(etc)
                if candidate ~= "" then return cmd .. "=" .. candidate end
            end
        end
    end
end

local function addIconScanMiss(scanStats, action)
    if not scanStats then return end
    scanStats.missingIcons = (scanStats.missingIcons or 0) + 1
    scanStats.misses = scanStats.misses or {}
    if #scanStats.misses >= 3 then return end

    local macro = action and action.macro and GSE.UnEscapeString(action.macro) or ""
    local candidate = getMacroIconDebugCandidate(macro)
    macro = trimIconCandidate(macro:gsub("\n", " | "))
    if string.len(macro) > 90 then macro = string.sub(macro, 1, 87) .. "..." end
    table.insert(
        scanStats.misses,
        string.format(
            "type=%s candidate=%s macro=%s",
            tostring(action and action.type),
            candidate or "<none>",
            macro ~= "" and macro or "<none>"
        )
    )
end

local function hydrateActionIcons(actions, scanStats)
    if type(actions) ~= "table" then return false, 0, 0 end

    local changed = false
    local changedIcons = 0
    local scannedActions = 0

    local function mergeScanResult(childChanged, childChangedIcons, childScannedActions)
        if childChanged then changed = true end
        changedIcons = changedIcons + (childChangedIcons or 0)
        scannedActions = scannedActions + (childScannedActions or 0)
    end

    for _, action in ipairs(actions) do
        if type(action) == "table" then
            if isIconBearingAction(action) and (shouldAutoFillActionIcon(action) or shouldReplaceFormActionIcon(action) or shouldUseCategorisedActionIcon(action)) then
                scannedActions = scannedActions + 1
                local icon = getActionAutoIcon(action)
                if icon and action.Icon ~= icon then
                    action.Icon = icon
                    action.IconUserSelected = nil
                    changed = true
                    changedIcons = changedIcons + 1
                elseif not icon then
                    addIconScanMiss(scanStats, action)
                end
            end

            if action.Type == Statics.Actions.Loop then
                mergeScanResult(hydrateActionIcons(action, scanStats))
            elseif action.Type == Statics.Actions.If then
                mergeScanResult(hydrateActionIcons(action[1], scanStats))
                mergeScanResult(hydrateActionIcons(action[2], scanStats))
            elseif not isIconBearingAction(action) then
                for _, childActions in ipairs(action) do
                    mergeScanResult(hydrateActionIcons(childActions, scanStats))
                end
            end
        end
    end
    return changed, changedIcons, scannedActions
end

local function resetActionIcons(actions, scanStats)
    if type(actions) ~= "table" then return false, 0, 0, 0 end

    local changed = false
    local refreshedIcons = 0
    local scannedActions = 0
    local clearedUserSelections = 0

    local function mergeResetResult(childChanged, childRefreshedIcons, childScannedActions, childClearedUserSelections)
        if childChanged then changed = true end
        refreshedIcons = refreshedIcons + (childRefreshedIcons or 0)
        scannedActions = scannedActions + (childScannedActions or 0)
        clearedUserSelections = clearedUserSelections + (childClearedUserSelections or 0)
    end

    for _, action in ipairs(actions) do
        if type(action) == "table" then
            if isIconBearingAction(action) then
                scannedActions = scannedActions + 1

                local oldIcon = action.Icon
                local hadUserSelection = action.IconUserSelected and true or false
                action.IconUserSelected = nil

                local icon = getActionAutoIcon(action)
                if icon then
                    action.Icon = icon
                    refreshedIcons = refreshedIcons + 1
                    if oldIcon ~= icon or hadUserSelection then changed = true end
                else
                    action.Icon = nil
                    if not GSE.isEmpty(oldIcon) or hadUserSelection then changed = true end
                    addIconScanMiss(scanStats, action)
                end

                if hadUserSelection then
                    clearedUserSelections = clearedUserSelections + 1
                end
            end

            if action.Type == Statics.Actions.Loop then
                mergeResetResult(resetActionIcons(action, scanStats))
            elseif action.Type == Statics.Actions.If then
                mergeResetResult(resetActionIcons(action[1], scanStats))
                mergeResetResult(resetActionIcons(action[2], scanStats))
            elseif not isIconBearingAction(action) then
                for _, childActions in ipairs(action) do
                    mergeResetResult(resetActionIcons(childActions, scanStats))
                end
            end
        end
    end

    return changed, refreshedIcons, scannedActions, clearedUserSelections
end
--- Hydrate icons for every sequence in a single class library and mark any
-- newly-resolved icons as dirty so the next /gsesaveallsequences persists them.
-- Used by Storage.lua when a class is decompressed on demand so icons appear
-- correctly the first time a user browses to another class.
function GSE.HydrateClassActionIcons(classid)
    if not classid then return end
    if type(GSE.Library) ~= "table" or type(GSE.Library[classid]) ~= "table" then return end
    for _, sequence in pairs(GSE.Library[classid]) do
        local sequenceChangedIcons = 0
        if type(sequence) == "table" and type(sequence.Versions) == "table" then
            for _, versionData in ipairs(sequence.Versions) do
                if type(versionData) == "table" then
                    local _, versionChangedIcons = hydrateActionIcons(versionData.Actions, nil)
                    sequenceChangedIcons = sequenceChangedIcons + (versionChangedIcons or 0)
                end
            end
        end
        if sequenceChangedIcons > 0 then
            actionIconDirtySequences[sequence] = (actionIconDirtySequences[sequence] or 0) + sequenceChangedIcons
        end
    end
end

function GSE.HydrateLoadedSequenceActionIcons(scanStats, saveChanges)
    if type(GSE.Library) ~= "table" then return 0, 0, 0 end

    -- Force-load every class that exists in the saved-variable store so the
    -- scan covers all sequences, not just classes the user has browsed this
    -- session. EnsureClassLoaded is a no-op for classes already decompressed.
    if type(GSESequences) == "table" and GSE.EnsureClassLoaded then
        for classid, _ in pairs(GSESequences) do
            GSE.EnsureClassLoaded(classid)
        end
    end

    local changedSequences = 0
    local changedIcons = 0
    local scannedActions = 0
    local savedSequences = 0
    local savedIcons = 0
    for classid, classLibrary in pairs(GSE.Library) do
        if type(classLibrary) == "table" then
            for sequenceName, sequence in pairs(classLibrary) do
                local changed = false
                local sequenceChangedIcons = 0
                if type(sequence) == "table" and type(sequence.Versions) == "table" then
                    for _, versionData in ipairs(sequence.Versions) do
                        if type(versionData) == "table" then
                            local versionChanged, versionChangedIcons, versionScannedActions = hydrateActionIcons(versionData.Actions, scanStats)
                            if versionChanged then changed = true end
                            changedIcons = changedIcons + (versionChangedIcons or 0)
                            sequenceChangedIcons = sequenceChangedIcons + (versionChangedIcons or 0)
                            scannedActions = scannedActions + (versionScannedActions or 0)
                        end
                    end
                end
                if changed then
                    changedSequences = changedSequences + 1
                end

                local pendingIconSaves = actionIconDirtySequences[sequence] or 0
                if saveChanges then
                    if (changed or pendingIconSaves > 0) and GSESequences and GSESequences[classid] then
                        GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
                        savedSequences = savedSequences + 1
                        savedIcons = savedIcons + sequenceChangedIcons + pendingIconSaves
                        actionIconDirtySequences[sequence] = nil
                    end
                elseif changed then
                    actionIconDirtySequences[sequence] = pendingIconSaves + sequenceChangedIcons
                end
            end
        end
    end
    return changedSequences, changedIcons, scannedActions, savedSequences, savedIcons
end

function GSE.ResetLoadedSequenceActionIcons(scanStats, saveChanges)
    if type(GSE.Library) ~= "table" then return 0, 0, 0, 0, 0, 0 end

    -- Force-load every class that exists in the saved-variable store so the
    -- reset covers all sequences, not just classes the user has browsed this
    -- session. EnsureClassLoaded is a no-op for classes already decompressed.
    if type(GSESequences) == "table" and GSE.EnsureClassLoaded then
        for classid, _ in pairs(GSESequences) do
            GSE.EnsureClassLoaded(classid)
        end
    end

    local changedSequences = 0
    local refreshedIcons = 0
    local scannedActions = 0
    local savedSequences = 0
    local savedIcons = 0
    local clearedUserSelections = 0

    for classid, classLibrary in pairs(GSE.Library) do
        if type(classLibrary) == "table" then
            for sequenceName, sequence in pairs(classLibrary) do
                local changed = false
                local sequenceRefreshedIcons = 0
                local sequenceClearedUserSelections = 0

                if type(sequence) == "table" and type(sequence.Versions) == "table" then
                    for _, versionData in ipairs(sequence.Versions) do
                        if type(versionData) == "table" then
                            local versionChanged, versionRefreshedIcons, versionScannedActions, versionClearedUserSelections =
                                resetActionIcons(versionData.Actions, scanStats)
                            if versionChanged then changed = true end
                            refreshedIcons = refreshedIcons + (versionRefreshedIcons or 0)
                            sequenceRefreshedIcons = sequenceRefreshedIcons + (versionRefreshedIcons or 0)
                            scannedActions = scannedActions + (versionScannedActions or 0)
                            clearedUserSelections = clearedUserSelections + (versionClearedUserSelections or 0)
                            sequenceClearedUserSelections = sequenceClearedUserSelections + (versionClearedUserSelections or 0)
                        end
                    end
                end

                if changed then
                    changedSequences = changedSequences + 1
                end

                if saveChanges and changed and GSESequences and GSESequences[classid] then
                    GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, sequence})
                    savedSequences = savedSequences + 1
                    savedIcons = savedIcons + sequenceRefreshedIcons + sequenceClearedUserSelections
                    actionIconDirtySequences[sequence] = nil
                elseif changed then
                    actionIconDirtySequences[sequence] =
                        (actionIconDirtySequences[sequence] or 0) + sequenceRefreshedIcons + sequenceClearedUserSelections
                end
            end
        end
    end

    return changedSequences, refreshedIcons, scannedActions, savedSequences, savedIcons, clearedUserSelections
end
function GSE.ScanSequenceActionIcons(saveChanges)
    local scanStats = {}
    local changedSequences, changedIcons, scannedActions, savedSequences, savedIcons =
        GSE.HydrateLoadedSequenceActionIcons(scanStats, saveChanges)
    local refreshed = refreshActionIconControls()
    if GSE.Print then
        if saveChanges then
            if (savedIcons or 0) > 0 then
                GSE.Print(
                    string.format(
                        "GSE saveall: saved %d action icon fix(es) across %d sequence(s); checked %d auto-icon candidate action(s); unresolved %d; refreshed %d open editor icon(s).",
                        savedIcons or 0,
                        savedSequences or 0,
                        scannedActions or 0,
                        scanStats.missingIcons or 0,
                        refreshed or 0
                    )
                )
            else
                GSE.Print(
                    string.format(
                        "GSE saveall: no pending action icon fixes to save; checked %d auto-icon candidate action(s); unresolved %d; refreshed %d open editor icon(s).",
                        scannedActions or 0,
                        scanStats.missingIcons or 0,
                        refreshed or 0
                    )
                )
            end
        else
            local pendingSequences, pendingIcons = countPendingActionIconSaves()
            local saveHint = (pendingIcons or 0) > 0 and " Run /gsesaveallsequences to save these icon fixes." or " No icon fixes need saving."
            GSE.Print(
                string.format(
                    "GSE icon scan: filled %d action icon(s) across %d sequence(s); pending %d unsaved icon fix(es) across %d sequence(s); checked %d auto-icon candidate action(s); unresolved %d; refreshed %d open editor icon(s).%s",
                    changedIcons or 0,
                    changedSequences or 0,
                    pendingIcons or 0,
                    pendingSequences or 0,
                    scannedActions or 0,
                    scanStats.missingIcons or 0,
                    refreshed or 0,
                    saveHint
                )
            )
        end
        for _, miss in ipairs(scanStats.misses or {}) do
            GSE.Print("GSE icon scan unresolved sample: " .. miss)
        end
    end
    return changedSequences, changedIcons, scannedActions, refreshed, savedSequences, savedIcons
end

function GSE.SaveAllSequenceActionIcons()
    if GSE.ScanSequenceActionIcons then return GSE.ScanSequenceActionIcons(true) end
end

function GSE.ResetAllSequenceActionIcons()
    if not GSE.ResetLoadedSequenceActionIcons then return end

    local scanStats = {}
    local changedSequences, refreshedIcons, scannedActions, savedSequences, savedIcons, clearedUserSelections =
        GSE.ResetLoadedSequenceActionIcons(scanStats, true)
    local refreshedEditorIcons = refreshActionIconControls()

    if GSE.Print then
        GSE.Print(
            string.format(
                "GSE spell icon reset: refreshed %d action icon(s), cleared %d selected icon override(s), saved %d update(s) across %d sequence(s); checked %d icon-bearing action(s); unresolved %d; refreshed %d open editor icon(s).",
                refreshedIcons or 0,
                clearedUserSelections or 0,
                savedIcons or 0,
                savedSequences or 0,
                scannedActions or 0,
                scanStats.missingIcons or 0,
                refreshedEditorIcons or 0
            )
        )
        for _, miss in ipairs(scanStats.misses or {}) do
            GSE.Print("GSE spell icon reset unresolved sample: " .. miss)
        end
    end

    return changedSequences, refreshedIcons, scannedActions, savedSequences, savedIcons, clearedUserSelections
end

-- Slash commands previously defined here (/gsespelliconreset,
-- /gseiconscan, /gsesaveallsequences, /gsesavelayoutx/y,
-- /gseapplylayoutx/y, /gseresettracker) were moved to
-- GSE_Utils/SlashCommands.lua so all GSE native slash commands live
-- together. The handlers still reach back into Editor.lua-owned
-- functions (GSE.ResetAllSequenceActionIcons, GSE.ScanSequenceActionIcons,
-- GSE.SaveAllSequenceActionIcons) through the GSE.* namespace.


function GSE.CreateIconControl(action, version, keyPath, sequence, frame)
    local iconSize = 28
    local lbl = UI:Create("Icon")
    lbl:SetImageSize(iconSize, iconSize)
    lbl:SetWidth(iconSize)
    lbl:SetHeight(iconSize)
    if lbl.SetSquareIcon then lbl:SetSquareIcon(true) end
    if lbl.SetElvUIKeepIconFullColor then lbl:SetElvUIKeepIconFullColor(true) end
    if lbl.SetElvUISubduedIcon then lbl:SetElvUISubduedIcon(false) end

    local function setIcon(iconID)
        lbl:SetImage(iconID or Statics.QuestionMarkIconID)
    end

    -- Backwards compatibility for QoL icon picker extensions that used the old
    -- InteractiveLabel texture string API.
    function lbl:SetText(value)
        local texture = tostring(value or ""):match("|T([^:|]+)")
        setIcon(tonumber(texture) or texture or Statics.QuestionMarkIconID)
    end

    -- Derives the display icon for the block.  Called once on creation and
    -- again whenever the spell/item/toy field changes (via RefreshIcon).
    -- Honours a manually-assigned action.Icon; otherwise infers from the
    -- spell, item, toy, or macro content.
    local function refreshIcon()
        local iconID = Statics.QuestionMarkIconID
        local manualIcon = getManualActionIcon(action)
        if manualIcon and not shouldReplaceFormActionIcon(action) and not shouldUseCategorisedActionIcon(action) then
            iconID = manualIcon
        else
            iconID = getActionAutoIcon(action) or iconID
        end
        setIcon(iconID)
    end

    -- Expose so callers can refresh the icon after the spell field changes.
    lbl.RefreshIcon = refreshIcon
    lbl.GSESequence = sequence
    lbl.GSEVersion = version
    lbl.GSEKeyPath = keyPath
    registerActionIconControl(lbl)
    refreshIcon()

    local spellinfolist = {}
    if action.type == "macro" then
        if isVariableAction(action) then
            table.insert(spellinfolist, {
                name = "GSE Variable",
                iconID = VARIABLE_BLOCK_ICON,
            })
        elseif isInGameMacroAction(action) then
            table.insert(spellinfolist, {
                name = "In-Game Macro",
                iconID = INGAME_MACRO_BLOCK_ICON,
            })
        end

        local macro = GSE.UnEscapeString(action.macro)
        if macro and string.sub(macro, 1, 1) == "/" then
            local lines = GSE.SplitMeIntoLines(macro)
            for _, v in ipairs(lines) do
                addIconMenuCandidates(spellinfolist, GSE.GetSpellsFromString(v, true))
                addIconMenuCandidates(spellinfolist, getMacroLineFallbackIconInfo(v))
            end
        else
            local spellinfo = {}
            spellinfo.name = action.macro
            local macindex = GetMacroIndexByName(spellinfo.name)
            local _, iconid, _ = GetMacroInfo(macindex)
            if macindex and iconid then
                spellinfo.iconID = iconid
                table.insert(spellinfolist, spellinfo)
            end
        end
    elseif action.type == "spell" then
        local spellinfo = GSE.GetSpellInfo(action.spell)
        if spellinfo and spellinfo.iconID then
            table.insert(spellinfolist, spellinfo)
        end
    end

    lbl:SetCallback("OnClick", function(widget, button)
        MenuUtil.CreateContextMenu(frame, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Select Icon"])
            for _, v in pairs(spellinfolist) do
                rootDescription:CreateButton(
                    "|T" .. v.iconID .. ":0|t " .. v.name,
                    function()
                        setIcon(v.iconID)
                        sequence.Versions[version].Actions[keyPath].Icon = v.iconID
                        sequence.Versions[version].Actions[keyPath].IconUserSelected = true
                    end
                )
            end
            -- Extension point: QoL and other modules append extra items here.
            if GSE.OnBuildIconMenu then
                GSE.OnBuildIconMenu(rootDescription, lbl, sequence, version, keyPath)
            end
        end)
    end)
    return lbl
end
local function BuildVersionLabel(version, label, excludekey)
    version = tostring(version)
    if not label then
        if version == "1" then
            label = L["Default"]
        else
            label = L["Version"]
        end
    end
    if excludekey then
        return label
    else
        return version .. " - " .. label
    end
end

function EnsureSequenceEditorRestoreOptions()
    if GSE.isEmpty(GSEOptions.frameLocations) then
        GSEOptions.frameLocations = {}
    end
    if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
        GSEOptions.frameLocations.sequenceeditor = {}
    end
    return GSEOptions.frameLocations.sequenceeditor
end

local function SetSequenceEditorOpenPreference(isOpen, mode)
    local seOpts = EnsureSequenceEditorRestoreOptions()
    seOpts.open = isOpen and true or false
    if mode then seOpts.openMode = mode end
end

function GSE.CreateEditor()
    if GSE.isEmpty(GSE.GUI.editors) then
        GSE.GUI.editors = {}
    end
    if GSE.GUI.editors[1] and not GSE.Patron then
        return GSE.GUI.editors[1]
    end
    local editframe = UI:Create("Frame")
    table.insert(GSE.GUI.editors, editframe)
    editframe:Hide()
    editframe.editorStrata = EDITOR_DEFAULT_STRATA
    -- Blank attachable right side window — mirrors the left nav window
    -- (dock/detach/snap/resize, edge chevron toggle). Fill panel.content with
    -- buttons; visibility/placement is handled by the window itself + SyncTrees.
    C_Timer.After(0, function()
        if not GSE.Patron then return end   -- patron-only window
        local panel = UI.CreateEditorSidePanel(editframe.frame, editframe.treeContainer and editframe.treeContainer.frame)
        if panel then
            editframe.leftPanel = panel

            -- ── Placeholder content ────────────────────────────────────────────
            -- Replace with real buttons later; the window handles its own
            -- show/hide, docking and detaching like the left tree.
            local c = panel.content

            local title = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
            title:SetPoint("TOP", c, "TOP", 0, -2)
            title:SetText("|cFFFFB300Patreon|r")
            -- ───────────────────────────────────────────────────────────────────

            -- Establish initial docked/active state.
            if panel.RefreshSidePanel then panel.RefreshSidePanel() end
        end
    end)
    EnsureSequenceEditorRestoreOptions().strata = nil
    editframe.frame:SetFrameStrata(EDITOR_DEFAULT_STRATA)
    editframe.frame:SetClampedToScreen(true)
    editframe.Sequence = {}
    editframe.Sequence.Versions = {}
    function editframe:RefreshMacroLimitSaveState(version)
        return RefreshMacroLimitSaveState(self, version)
    end
    editframe.SequenceName = ""
    editframe.Raid = 1
    editframe.PVP = 1
    editframe.Mythic = 1
    editframe.Dungeon = 1
    editframe.Heroic = 1
    editframe.Party = 1
    editframe.Arena = 1
    editframe.Timewalking = 1
    editframe.MythicPlus = 1
    editframe.Scenario = 1
    editframe.ClassID = GSE.GetCurrentClassID()
    editframe.save = false
	editframe.statusText = "GSE: " .. GSE.VersionString
	editframe.booleanFunctions = {}
	editframe.frame:SetClampRectInsets(10, 0, 0, 0)
    if editframe.statustext then
        editframe.statustext:ClearAllPoints()
        editframe.statustext:SetPoint("BOTTOMLEFT", editframe.frame, "BOTTOMLEFT", 14, 11)
        editframe.statustext:SetPoint("BOTTOMRIGHT", editframe.frame, "BOTTOMRIGHT", -14, 11)
        editframe.statustext:SetJustifyH("CENTER")
        editframe.statustext:SetJustifyV("MIDDLE")
        if editframe.statustext.SetDrawLayer then editframe.statustext:SetDrawLayer("OVERLAY", 7) end

        function editframe:SetVersionTextHover(hovered)
            if not self.statustext then return end
            if self.statustext.GetFont and self.statustext.SetFont then
                if not self.versionTextBaseFont then
                    local fontFile, fontSize, fontFlags = self.statustext:GetFont()
                    if fontFile and fontSize then self.versionTextBaseFont = {fontFile, fontSize, fontFlags} end
                end
                if self.versionTextBaseFont then
                    self.statustext:SetFont(
                        self.versionTextBaseFont[1],
                        hovered and math.floor((self.versionTextBaseFont[2] * 1.14) + 0.5) or self.versionTextBaseFont[2],
                        self.versionTextBaseFont[3]
                    )
                    return
                end
            end
            if self.statustext.SetScale then self.statustext:SetScale(hovered and 1.08 or 1) end
        end

        function editframe:UpdateVersionHitBox()
            if not (self.versionHitBox and self.statustext) then return end
            local textWidth = self.statustext.GetStringWidth and self.statustext:GetStringWidth() or 0
            local textHeight = self.statustext.GetStringHeight and self.statustext:GetStringHeight() or 0
            self.versionHitBox:ClearAllPoints()
            self.versionHitBox:SetSize(math.max(1, math.ceil(textWidth)), math.max(12, math.ceil(textHeight) + 6))
            self.versionHitBox:SetPoint("CENTER", self.statustext, "CENTER", 0, 0)
        end

        editframe.versionHitBox = CreateFrame("Button", nil, editframe.frame)
        editframe.versionHitBox:RegisterForClicks("LeftButtonUp")
        editframe.versionHitBox:EnableMouse(true)
        if editframe.versionHitBox.SetFrameLevel and editframe.frame.GetFrameLevel then
            editframe.versionHitBox:SetFrameLevel((editframe.frame:GetFrameLevel() or 0) + 80)
        end
        editframe.versionHitBox:SetScript(
            "OnMouseDown",
            function()
                local now = GetTime and GetTime() or 0
                if now - (editframe.lastVersionClick or 0) <= 0.35 then
                    editframe.lastVersionClick = 0
                    if GSE.GUIShowVersionCopyWindow then GSE.GUIShowVersionCopyWindow() end
                    return
                end
                editframe.lastVersionClick = now
            end
        )
        editframe.versionHitBox:SetScript(
            "OnEnter",
            function(self)
                editframe:SetVersionTextHover(true)
                editframe:UpdateVersionHitBox()
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetText("GSE Version")
                GameTooltip:AddLine("Double-click: Copy version", 1, 1, 1)
                GameTooltip:Show()
            end
        )
        editframe.versionHitBox:SetScript(
            "OnLeave",
            function()
                editframe:SetVersionTextHover(false)
                editframe:UpdateVersionHitBox()
                if GameTooltip then GameTooltip:Hide() end
            end
        )
        editframe:UpdateVersionHitBox()
    end

    local NativeSetStatusText = editframe.SetStatusText
    function editframe:SetStatusText(text)
        local statusText = tostring(text or "")
        NativeSetStatusText(self, statusText)
        if not self.statustext then return end

        local pendingPrefix = L["Save pending for "]
        if string.find(statusText, pendingPrefix, 1, true) == 1 then
            self.pendingSaveName = string.sub(statusText, string.len(pendingPrefix) + 1)
        elseif statusText == "" or statusText == (self.statusText or "") or string.find(statusText, L["Saved"], 1, true) then
            self.pendingSaveName = nil
        end

        if statusText == "" or statusText == (self.statusText or "") then
            self.statustext:SetTextColor(0.55, 0.55, 0.55, 1)
        elseif string.find(statusText, pendingPrefix, 1, true) then
            self.statustext:SetTextColor(1, 0.82, 0, 1)
        elseif string.find(statusText, L["Saved"], 1, true) then
            self.statustext:SetTextColor(0.25, 1, 0.25, 1)
        elseif string.find(statusText, "in Use", 1, true) or string.find(statusText, "Error", 1, true) then
            self.statustext:SetTextColor(1, 0.25, 0.25, 1)
        else
            self.statustext:SetTextColor(1, 1, 1, 1)
        end
        if self.UpdateVersionHitBox then self:UpdateVersionHitBox() end
    end

    -- Apply the version text immediately so it shows on a freshly-opened editor
    -- even before any sequence is loaded. On Classic / BoA / MoP the editor
    -- can open empty for a new character; without this call the footer stayed
    -- blank and the version-copy hitbox had no text to hover over.
    if editframe.statusText then
        editframe:SetStatusText(editframe.statusText)
    end

	local function EnsureSequenceEditorLocation()
		if GSE.isEmpty(GSEOptions.frameLocations) then
			GSEOptions.frameLocations = {}
		end
		if GSE.isEmpty(GSEOptions.frameLocations.sequenceeditor) then
			GSEOptions.frameLocations.sequenceeditor = {}
		end
		local se = GSEOptions.frameLocations.sequenceeditor
		-- Apply the saved Editor Scroll Speed (from the Options slider) to
		-- NativeUI's live runtime variable. Without this, the slider value
		-- only applies when the Options panel itself triggers EnsureSequenceEditorOptions
		-- — opening the editor directly wouldn't restore the saved scroll speed.
		if GSE.GUI and GSE.GUI.SetScrollStep and se.scrollSpeed then
			GSE.GUI.SetScrollStep(se.scrollSpeed)
		end
		return se
	end

	local function RoundNumber(value)
		return math.floor((tonumber(value) or 0) + 0.5)
	end

	local function GetMaxEditorWidth()
		local screenWidth = GetScreenWidth and GetScreenWidth()
		if screenWidth and screenWidth > 0 then
			return math.max(DEFAULT_WIDTH, math.min(MAX_EDITOR_WIDTH, screenWidth - EDITOR_SCREEN_MARGIN))
		end
		return MAX_EDITOR_WIDTH
	end

	local function SaveSequenceEditorLocation()
		if not editframe.frame or not editframe.frame.GetRect then return end
		local left, bottom, width, height = editframe.frame:GetRect()
		if not (left and bottom and width and height) then return end

		-- Use GetWidth/GetHeight for logical (unscaled) dimensions
		local logicalW = editframe.frame.GetWidth  and editframe.frame:GetWidth()  or width
		local logicalH = editframe.frame.GetHeight and editframe.frame:GetHeight() or height

		local seOpts = EnsureSequenceEditorLocation()
		seOpts.left   = RoundNumber(left)
		seOpts.top    = RoundNumber(bottom + height)
		seOpts.width  = math.min(GetMaxEditorWidth(), math.max(MIN_EDITOR_WIDTH,  RoundNumber(logicalW)))
		seOpts.height = math.min(MAX_EDITOR_HEIGHT,   math.max(MIN_EDITOR_HEIGHT, RoundNumber(logicalH)))
        seOpts.strata = nil
		if editframe.treeContainer then
			seOpts.treeWidth = RoundNumber(editframe.treeContainer:GetTreeWidth())
		end
	end
	-- Expose so PLAYER_LOGOUT can save size even if editor wasn't closed first
	editframe.SaveLocation = SaveSequenceEditorLocation

	local function GetVersionList()
        if not #editframe.Sequence.Versions then
            return {}
        end
        local tabl = {}
        for k, v in ipairs(editframe.Sequence.Versions) do
            tabl[tostring(k)] = v.Label and tostring(k) .. " - " .. v.Label or tostring(k)
        end
        return tabl
    end
    editframe.GetVersionList = GetVersionList

    local function GUIConfirmDeleteSequence(classid, sequenceName)
        GSE.DeleteSequence(classid, sequenceName)
        for _, v in ipairs(GSE.GUI.editors) do
            v.ManageTree()
        end
    end

    --- This function pops up a confirmation dialog.
    local function GUIDeleteSequence(classid, sequenceName)
        GSE.UI.ShowConfirmDialog({
            owner       = editframe,
            title       = L["Delete Sequence"],
            message     = L["Are you sure you want to Delete"]
                .. "\n\n|cFFFFFFFF" .. tostring(sequenceName) .. "|r\n\n"
                .. L["This will Delete the Sequence and all Versions."]
                .. "\n\n|cFFFF3030" .. L["This Action Cannot be Undone!"] .. "|r"
                .. "\n\n|cFFAAAAAA" .. "-you will lose the gse.tools sequence id-" .. "|r",
            width       = 360,
            height      = 240,
            confirmText = L["Delete"],
            cancelText  = L["Cancel"],
            onConfirm   = function()
                GUIConfirmDeleteSequence(classid, sequenceName)
            end,
        })
    end
    editframe.GUIDeleteSequence = GUIDeleteSequence

    --- This function then deletes the macro.

	local seOpts = EnsureSequenceEditorLocation()
	if seOpts.left and seOpts.top then
		local editorleft = seOpts.left
		local editortop = seOpts.top

		if #GSE.GUI.editors > 1 then
			editorleft = editorleft + FRAME_DISPLACEMENT
			editortop = editortop - FRAME_DISPLACEMENT
			seOpts.left = editorleft
			seOpts.top = editortop
		end
		editframe.frame:ClearAllPoints()
		editframe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", editorleft, editortop)
	else
		editframe.frame:ClearAllPoints()
		editframe:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	editframe.Height = math.max(MIN_EDITOR_HEIGHT, seOpts.height or MIN_EDITOR_HEIGHT)
	editframe.Width  = math.max(MIN_EDITOR_WIDTH,  seOpts.width  or MIN_EDITOR_WIDTH)

	if editframe.Height < 1 then
		editframe.Height = 1
		seOpts.height = editframe.Height
	end
	local maxEditorWidth = GetMaxEditorWidth()
	if editframe.Width < 1 then
		editframe.Width = 1
		seOpts.width = editframe.Width
	elseif editframe.Width > maxEditorWidth then
		editframe.Width = maxEditorWidth
		seOpts.width = editframe.Width
	end
    editframe.frame:SetHeight(editframe.Height)
	editframe.frame:SetWidth(editframe.Width)
	if editframe.SetResizeBounds then
		local maxHeight = GetScreenHeight and math.min(MAX_EDITOR_HEIGHT, GetScreenHeight()) or MAX_EDITOR_HEIGHT
		editframe:SetResizeBounds(MIN_EDITOR_WIDTH, MIN_EDITOR_HEIGHT, maxEditorWidth, maxHeight)
	end
	if editframe.SetResizable then editframe:SetResizable(true) end
	if editframe.frame.HookScript then
		editframe.frame:HookScript("OnDragStop", SaveSequenceEditorLocation)
	end
	editframe:SetTitle(L["Sequence Editor"])
    if editframe.closebutton and editframe.closebutton.HookScript then
        editframe.closebutton:HookScript("OnClick", function() SetSequenceEditorOpenPreference(false) end)
    end
	editframe:SetCallback(
		"OnClose",
		function(self)
            -- When minimizing we hide the frame which triggers OnHideÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢OnClose.
            -- Skip all cleanup so the frame stays usable for restore.
            if self.isMinimizing then return end

            self.buildGeneration = (self.buildGeneration or 0) + 1
            if self.HideBuildSpinner then self.HideBuildSpinner() end

			self.OrigSequenceName = nil
			GSE.ClearTooltip(editframe)
			SaveSequenceEditorLocation()
			self:Hide()
            -- Hide the Navigator when the editor closes
            if self.treeContainer and self.treeContainer.navWindowFrame then
                self.treeContainer.navWindowFrame:Hide()
            end
            if GSE.GUI.ClearUndo then GSE.GUI.ClearUndo(self) end
            if GSE.After and GSE.GUI.ClearUndoIfNoVisibleEditors then
                C_Timer.After(0, GSE.GUI.ClearUndoIfNoVisibleEditors)
            end
            self.Sequence = nil
            self.SequenceName = nil
            self.Raid = nil
            self.PVP = nil
            self.Mythic = nil
            self.Dungeon = nil
            self.Heroic = nil
            self.Party = nil
            self.Arena = nil
            self.Timewalking = nil
            self.MythicPlus = nil
            self.Scenario = nil
            self.ClassID = nil
            self.save = nil
            self.statusText = nil
            self.booleanFunctions = nil
            if self.minimizedWidget then
                self.minimizedWidget.editframe = nil
                self.minimizedWidget:Hide()
                self.minimizedWidget = nil
            end
            if self.PreviewFrame then
                self.PreviewFrame:Hide()
                self.PreviewFrame = nil
            end
            self:ReleaseChildren()
            for k, v in ipairs(GSE.GUI.editors) do
                if editframe == v then
                    table.remove(GSE.GUI.editors, k)
                end
            end
            -- need to clear the onSizeChanged else the old OnSizeChanged method will reapplu when we recreate the frame.
            self.frame:SetScript(
                "OnSizeChanged",
                function(self, width, height)
                end
            )

            UI:Release(self)
        end
    )

    -- Small draggable widget shown when the editor is minimized
    local minimizedWidget = CreateFrame("Button", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    local minWidgetUsesModern = ShouldUseModernEditorSkin()
    minimizedWidget:SetSize(220, minWidgetUsesModern and 30 or 34)
    minimizedWidget:SetFrameStrata(EDITOR_DEFAULT_STRATA)
    minimizedWidget:SetMovable(true)
    minimizedWidget:EnableMouse(true)
    minimizedWidget:RegisterForDrag("LeftButton")
    minimizedWidget:SetClampedToScreen(false)
    if GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(minimizedWidget) end
    minimizedWidget:HookScript("OnShow", function(self)
        if GSE.ApplyScaleToFrame then GSE.ApplyScaleToFrame(self) end
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
    end)
    local minWidgetBackdropYOffset = minWidgetUsesModern and 0 or 3
    local minWidgetSkinTopCrop = minWidgetUsesModern and 0 or 2
    local minWidgetSkinHeight = minWidgetUsesModern and 24 or 25
    local minWidgetSkinClip = CreateFrame("Frame", nil, minimizedWidget)
    minWidgetSkinClip:SetPoint("TOPLEFT", minimizedWidget, "TOPLEFT", minWidgetUsesModern and 0 or 15, minWidgetBackdropYOffset - 1 - minWidgetSkinTopCrop)
    minWidgetSkinClip:SetPoint("TOPRIGHT", minimizedWidget, "TOPRIGHT", 0, minWidgetBackdropYOffset - 1 - minWidgetSkinTopCrop)
    minWidgetSkinClip:SetHeight(minWidgetSkinHeight)
    minWidgetSkinClip:SetFrameLevel(minimizedWidget:GetFrameLevel())
    if minWidgetSkinClip.SetClipsChildren then minWidgetSkinClip:SetClipsChildren(true) end

    local minWidgetBackdrop = CreateFrame("Frame", nil, minWidgetSkinClip, BackdropTemplateMixin and "BackdropTemplate" or nil)
    minWidgetBackdrop:SetAllPoints(minWidgetSkinClip)
    minWidgetBackdrop:SetFrameLevel(minWidgetSkinClip:GetFrameLevel())
    minWidgetBackdrop:EnableMouse(false)
    if minWidgetUsesModern then
        ApplyModernMiniBackdrop(minWidgetBackdrop, nil, {0.22, 0.24, 0.25, 0.95})
    else
        minWidgetBackdrop:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4},
        })
        minWidgetBackdrop:SetBackdropColor(0, 0, 0, 0.85)
        minWidgetBackdrop:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    minimizedWidget:Hide()

    local minWidgetTitleYOffset = minWidgetUsesModern and 2 or 5
    local minWidgetTitlePrefix = "|cFFFFFFFFGS|r|cFF00FFFFE|r"
    local minWidgetContent = CreateFrame("Frame", nil, minimizedWidget)
    minWidgetContent:SetAllPoints(minimizedWidget)
    minWidgetContent:SetFrameLevel(minWidgetBackdrop:GetFrameLevel() + 1)

    local minWidgetTitle = minWidgetContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minWidgetTitle:SetPoint("LEFT", minimizedWidget, "LEFT", minWidgetUsesModern and 8 or 22, minWidgetTitleYOffset)
    minWidgetTitle:SetPoint("RIGHT", minimizedWidget, "RIGHT", minWidgetUsesModern and -58 or -64, minWidgetTitleYOffset)
    minWidgetTitle:SetJustifyH("LEFT")
    minWidgetTitle:SetWordWrap(false)
    local function formatMinWidgetTitle(title)
        local sequenceTitle = tostring(title or "")
        if sequenceTitle == "" then return minWidgetTitlePrefix end
        return minWidgetTitlePrefix .. ": " .. sequenceTitle
    end

    local minWidgetClose = CreateFrame("Button", nil, minimizedWidget)
    minWidgetClose:SetSize(32, 30)
    minWidgetClose:SetFrameLevel(minWidgetBackdrop:GetFrameLevel() + 2)
    minWidgetClose:SetPoint("TOPRIGHT", minimizedWidget, "TOPRIGHT", 2, 3)
    local minWidgetCloseTexture = "Interface\\AddOns\\GSE_GUI\\Assets\\close.png"
    minWidgetClose:SetNormalTexture(minWidgetCloseTexture)
    minWidgetClose:SetPushedTexture(minWidgetCloseTexture)
    minWidgetClose:SetHighlightTexture(minWidgetCloseTexture, minWidgetUsesModern and "BLEND" or "ADD")
    if minWidgetUsesModern then
        SetModernMiniCloseTexture(minWidgetClose:GetNormalTexture(), false)
        SetModernMiniCloseTexture(minWidgetClose:GetPushedTexture(), true)
        SetModernMiniCloseTexture(minWidgetClose:GetHighlightTexture(), true)
    end
    if minWidgetClose:GetHighlightTexture() then
        minWidgetClose:GetHighlightTexture():SetAlpha(minWidgetUsesModern and 1 or 0.35)
    end
    local minWidgetExpand = CreateFrame("Button", nil, minimizedWidget)
    minWidgetExpand:SetSize(24, 24)
    minWidgetExpand:EnableMouse(true)
    minWidgetExpand:RegisterForClicks("LeftButtonUp")
    minWidgetExpand:SetFrameLevel((minWidgetClose:GetFrameLevel() or minWidgetBackdrop:GetFrameLevel()) + 1)
    minWidgetExpand:SetPoint("RIGHT", minWidgetClose, "LEFT", 2, 0)
    local minWidgetExpandTexture = "Interface\\AddOns\\GSE_GUI\\Assets\\minimizearrowup.png"
    minWidgetExpand:SetNormalTexture(minWidgetExpandTexture)
    minWidgetExpand:SetPushedTexture(minWidgetExpandTexture)
    minWidgetExpand:SetHighlightTexture(minWidgetExpandTexture, minWidgetUsesModern and "BLEND" or "ADD")
    if minWidgetUsesModern then
        SetModernMiniCloseTexture(minWidgetExpand:GetNormalTexture(), false)
        SetModernMiniCloseTexture(minWidgetExpand:GetPushedTexture(), true)
        SetModernMiniCloseTexture(minWidgetExpand:GetHighlightTexture(), true)
    end
    if minWidgetExpand:GetHighlightTexture() then
        minWidgetExpand:GetHighlightTexture():SetAlpha(minWidgetUsesModern and 1 or 0.35)
    end
    minWidgetExpand:Show()
    minWidgetClose:SetScript("OnClick", function(self)
        local widget = self:GetParent()
        if widget and widget.editframe then
            widget.editframe.isMinimizing = nil
            widget.editframe:Fire("OnClose")
        elseif widget then
            widget:Hide()
        end
    end)

    minimizedWidget.editframe = editframe
    minimizedWidget:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    minimizedWidget:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if GSE.ClampFrameToScreen then GSE.ClampFrameToScreen(self) end
    end)
    local function expandEditorFromWidget(self)
        local widgetRight = self.GetRight and self:GetRight()
        local widgetTop = self.GetTop and self:GetTop()
        self:Hide()
        if self.editframe then
            if widgetRight and widgetTop and self.editframe.frame then
                if GSE.SetFrameScreenPoint then
                    GSE.SetFrameScreenPoint(self.editframe.frame, "TOPRIGHT", widgetRight, widgetTop)
                else
                    self.editframe.frame:ClearAllPoints()
                    self.editframe:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", widgetRight, widgetTop)
                end
            end
            self.editframe:Show()
            if self.previewWasVisible and self.editframe.PreviewFrame then
                self.editframe.PreviewFrame:Show()
            end
            -- Reposition and show the Navigator if it was visible
            if self.editframe.treeContainer and self.editframe.treeContainer.RefreshNavWindow then
                self.editframe.treeContainer.RefreshNavWindow()
            end
            -- Restore the right side window if it was visible before collapsing.
            -- Refresh now AND after the editor finishes its layout pass: a single
            -- next-frame refresh can fire before the editor reaches full height, so
            -- the window would lock onto a transitional (short) height. RefreshSidePanel
            -- is idempotent — it re-applies the full-height dock (or floating geom).
            if self.editframe.leftPanel and self.leftPanelWasVisible then
                local p = self.editframe.leftPanel
                local function restorePanel()
                    if not p then return end
                    if p.RefreshSidePanel then p.RefreshSidePanel()
                    elseif p.Show then p:Show() end
                end
                restorePanel()
                if GSE.After then
                    C_Timer.After(0,    restorePanel)
                    C_Timer.After(0.15, restorePanel)
                end
            end
        end
        self.previewWasVisible = nil
        self.leftPanelWasVisible = nil
    end
    minWidgetExpand:SetScript("OnClick", function(self)
        local widget = self:GetParent()
        if widget then expandEditorFromWidget(widget) end
    end)

    local lastMinimizedClick = 0
    minimizedWidget:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local now = GetTime()
        if now - lastMinimizedClick <= 0.35 then
            lastMinimizedClick = 0
            expandEditorFromWidget(self)
        else
            lastMinimizedClick = now
        end
    end)
    editframe.minimizedWidget = minimizedWidget
    editframe.editorStrata = EDITOR_DEFAULT_STRATA
    if editframe.minimizedWidget and editframe.minimizedWidget.SetFrameStrata then
        editframe.minimizedWidget:SetFrameStrata(EDITOR_DEFAULT_STRATA)
    end
    if editframe.PreviewFrame and editframe.PreviewFrame.SetFrameStrata then
        editframe.PreviewFrame:SetFrameStrata(EDITOR_DEFAULT_STRATA)
    end

    local inactiveOverlay = CreateFrame("Button", nil, editframe.frame)
    inactiveOverlay:SetPoint("TOPLEFT", editframe.frame, "TOPLEFT", 8, -28)
    inactiveOverlay:SetPoint("BOTTOMRIGHT", editframe.frame, "BOTTOMRIGHT", -8, 28)
    inactiveOverlay:SetFrameLevel(editframe.frame:GetFrameLevel() + 80)
    inactiveOverlay:EnableMouse(true)
    inactiveOverlay:RegisterForClicks("AnyDown")
    inactiveOverlay:SetScript("OnMouseDown", function()
        SetActiveEditor(editframe)
    end)
    inactiveOverlay:Hide()
    editframe.inactiveOverlay = inactiveOverlay

    -- Clicking the sidebar activates the editor
    C_Timer.After(0, function()
        local treeFrame = editframe.treeContainer and editframe.treeContainer.treeframe
        if not treeFrame then return end
        if treeFrame.HookScript then
            treeFrame:HookScript("OnMouseDown", function()
                SetActiveEditor(editframe)
            end)
        end
    end)

    -- Minimize button at the top-right corner of the editor frame
    local minimizeBtn = CreateFrame("Button", nil, editframe.frame)
    local minimizeBtnUsesModern = ShouldUseModernEditorSkin()
    minimizeBtn:SetSize(24, 24)
    minimizeBtn:EnableMouse(true)
    minimizeBtn:RegisterForClicks("LeftButtonUp")
    if editframe.closebutton then
        minimizeBtn:SetPoint("RIGHT", editframe.closebutton, "LEFT", 2, 0)
    else
        minimizeBtn:SetPoint("TOPRIGHT", editframe.frame, "TOPRIGHT", -34, -5)
    end
    minimizeBtn:SetFrameLevel(((editframe.closebutton and editframe.closebutton.GetFrameLevel and editframe.closebutton:GetFrameLevel()) or editframe.frame:GetFrameLevel() or 0) + 2)
    local minimizeBtnTexture = "Interface\\AddOns\\GSE_GUI\\Assets\\minimizearrowdown.png"
    minimizeBtn:SetNormalTexture(minimizeBtnTexture)
    minimizeBtn:SetPushedTexture(minimizeBtnTexture)
    minimizeBtn:SetHighlightTexture(minimizeBtnTexture, minimizeBtnUsesModern and "BLEND" or "ADD")
    if minimizeBtnUsesModern then
        SetModernMiniCloseTexture(minimizeBtn:GetNormalTexture(), false)
        SetModernMiniCloseTexture(minimizeBtn:GetPushedTexture(), true)
        SetModernMiniCloseTexture(minimizeBtn:GetHighlightTexture(), true)
    end
    if minimizeBtn:GetNormalTexture() then minimizeBtn:GetNormalTexture():SetAlpha(1) end
    if minimizeBtn:GetPushedTexture() then minimizeBtn:GetPushedTexture():SetAlpha(1) end
    if minimizeBtn:GetHighlightTexture() then minimizeBtn:GetHighlightTexture():SetAlpha(minimizeBtnUsesModern and 1 or 0.8) end
    minimizeBtn:Show()
    editframe.minimizeButton = minimizeBtn
    local function collapseEditor()
        if editframe.frame and editframe.frame.StopMovingOrSizing then
            editframe.frame:StopMovingOrSizing()
        end
        minWidgetTitle:SetText(formatMinWidgetTitle(editframe.SequenceName))
        minimizedWidget.previewWasVisible = editframe.PreviewFrame and editframe.PreviewFrame:IsVisible()
        if editframe.PreviewFrame then
            editframe.PreviewFrame:Hide()
        end
        minimizedWidget:ClearAllPoints()
        local x = editframe.frame:GetRight()
        local y = editframe.frame:GetTop()
        if x and y then
            if GSE.ApplyScaleToFrame then GSE.ApplyScaleToFrame(minimizedWidget) end
            if GSE.SetFrameScreenPoint then
                GSE.SetFrameScreenPoint(minimizedWidget, "TOPRIGHT", x, y)
            else
                minimizedWidget:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x, y)
            end
        else
            minimizedWidget:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        -- Set flag so OnClose (fired by the frame's OnHide handler) skips cleanup
        editframe.isMinimizing = true
        editframe:Hide()
        editframe.isMinimizing = nil
        -- Hide the Navigator when editor collapses
        if editframe.treeContainer and editframe.treeContainer.navWindowFrame then
            editframe.treeContainer.navWindowFrame:Hide()
        end
        -- Hide the patron side panel alongside the editor, even when locked.
        -- Remember whether it was visible so expand can restore it.
        if editframe.leftPanel then
            minimizedWidget.leftPanelWasVisible = editframe.leftPanel:IsShown()
            editframe.leftPanel:Hide()
        end
        minimizedWidget:Show()
        if GSE.ClampFrameToScreen then
            GSE.ClampFrameToScreen(minimizedWidget)
            if GSE.After then
                C_Timer.After(0, function()
                    if minimizedWidget:IsShown() then GSE.ClampFrameToScreen(minimizedWidget) end
                end)
            end
        end
    end
    minimizeBtn:SetScript("OnClick", collapseEditor)

    local lastTitleClick = 0
    local function isCursorOverTitleBar()
        local titleBar = editframe.titlebar or editframe.frame.TitleContainer
        local left = titleBar and titleBar.GetLeft and titleBar:GetLeft()
        local right = titleBar and titleBar.GetRight and titleBar:GetRight()
        local top = titleBar and titleBar.GetTop and titleBar:GetTop()
        local bottom = titleBar and titleBar.GetBottom and titleBar:GetBottom()

        if not (left and right and top and bottom) then
            left = editframe.frame:GetLeft()
            right = editframe.frame:GetRight()
            top = editframe.frame:GetTop()
            bottom = top and (top - 28)
        end
        if not (left and right and top and bottom) then return false end

        local x, y = GetCursorPosition()
        local scale = (titleBar and titleBar.GetEffectiveScale and titleBar:GetEffectiveScale()) or
            (editframe.frame.GetEffectiveScale and editframe.frame:GetEffectiveScale()) or
            (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or
            1
        x, y = x / scale, y / scale
        return x >= left and x <= right and y <= top and y >= bottom
    end

    editframe.frame:HookScript("OnMouseDown", function(_, button)
        if not isCursorOverTitleBar() then
            return
        end

        if button ~= "LeftButton" then return end

        local now = GetTime()
        if now - lastTitleClick <= 0.35 then
            lastTitleClick = 0
            collapseEditor()
        else
            lastTitleClick = now
        end
    end)
    editframe.frame:HookScript("OnUpdate", function()
        if not GameTooltip then return end
        if isCursorOverTitleBar() then
            if not editframe.titleTooltipShown then
                GameTooltip:SetOwner(editframe.frame, "ANCHOR_CURSOR")
                GameTooltip:SetText(L["Sequence Editor"] or "Sequence Editor")
                GameTooltip:AddLine("Double-click: Minimize editor", 1, 1, 1)
                GameTooltip:Show()
                editframe.titleTooltipShown = true
            end
        elseif editframe.titleTooltipShown then
            if GameTooltip.GetOwner and GameTooltip:GetOwner() == editframe.frame then
                GameTooltip:Hide()
            end
            editframe.titleTooltipShown = nil
        end
    end)
    editframe.frame:HookScript("OnLeave", function()
        if not editframe.titleTooltipShown then return end
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == editframe.frame then
            GameTooltip:Hide()
        end
        editframe.titleTooltipShown = nil
    end)

    -- If the editor is re-shown via any path (e.g. minimap button re-click) always
    -- dismiss the minimized widget so they never appear simultaneously.
    editframe.frame:HookScript("OnShow", function()
        minimizedWidget:Hide()
        SetActiveEditor(editframe)
    end)
    editframe.frame:HookScript("OnMouseDown", function()
        SetActiveEditor(editframe)
    end)
    editframe.frame:HookScript("OnHide", function()
        if GSE.GUI.activeEditor == editframe then GSE.GUI.activeEditor = nil end
        C_Timer.After(0, RefreshEditorActivation)
    end)

    editframe:SetLayout("Flow")
    editframe.panels = {}

    local function GUIUpdateSequenceDefinition(classid, SequenceName, sequence)
        sequence.LastUpdated = GSE.GetTimestamp()

        if not GSE.isEmpty(SequenceName) then
            if GSE.isEmpty(classid) then
                classid = GSE.GetCurrentClassID()
            end
            sequence.MetaData.Name = SequenceName
            if not GSE.isEmpty(SequenceName) then
                if editframe.newname and GSE.UnEscapeString(SequenceName) == editframe.OrigSequenceName then
                    editframe.newname = nil
                end
                local vals = {}
                vals.action = "Replace"
                vals.sequencename = SequenceName
                vals.sequence = sequence
                vals.classid = classid

                -- "Name in use" check: query Library directly rather than G
                -- so a just-deleted sequence's macro button (which lingers in
                -- G until reload) does not falsely block reuse of that name.
                local plainName = GSE.UnEscapeString(SequenceName)
                local nameInUse = not GSE.isEmpty(
                    GSE.Library[classid] and GSE.Library[classid][plainName]
                )
                if nameInUse and editframe.newname then
                    editframe:SetStatusText(
                        string.format(L["Sequence Name %s is in Use. Please choose a different name."], SequenceName)
                    )
                    editframe.nameeditbox:SetText(
                        GSEOptions.UNKNOWN .. editframe.nameeditbox:GetText() .. Statics.StringReset
                    )
                    editframe.nameeditbox:SetFocus()
                    return false
                end
                if editframe.newname then
                    -- True in-place rename: keep PlatformID so the GSE.Tools
                    -- record stays bound to this sequence under its new name.
                    -- Move the GSEPlatformIDs sidecar entry to the new key so
                    -- the Companion still resolves the right server record.
                    local author = sequence.MetaData and sequence.MetaData.Author or ""
                    if GSEPlatformIDs and editframe.OrigSequenceName then
                        local oldKey = editframe.OrigSequenceName .. "|" .. author
                        local newKey = plainName .. "|" .. author
                        if GSEPlatformIDs[oldKey] then
                            GSEPlatformIDs[newKey] = GSEPlatformIDs[oldKey]
                            GSEPlatformIDs[oldKey] = nil
                        end
                    end
                    local renameVals = {}
                    renameVals.action       = "renamesequence"
                    renameVals.oldname      = editframe.OrigSequenceName
                    renameVals.sequencename = SequenceName
                    renameVals.sequence     = sequence
                    renameVals.classid      = classid
                    GSE.EnqueueOOC(renameVals)
                    -- Confirm to the owner that renaming is gse.tools-id safe.
                    -- Fires for any sequence the user owns (i.e. not protected /
                    -- foreign content); protected content stays silent.
                    if not (sequence.MetaData and sequence.MetaData.noExport) then
                        GSE.UI.ShowMessageDialog({
                            owner      = editframe,
                            title      = L["Sequence Renamed"],
                            note       = L["-gse.tools ID will remain the same-"],
                            buttonText = CLOSE,
                        })
                    end
                    -- Update editor state so subsequent saves use the new name.
                    editframe.OrigSequenceName = plainName
                    editframe.newname          = nil
                    editframe:SetStatusText(L["Save pending for "] .. SequenceName)
                    return true
                end
                GSE.EnqueueOOC(vals)
                editframe:SetStatusText(L["Save pending for "] .. SequenceName)
                return true
            end
        end
        return false
    end
    editframe.GUIUpdateSequenceDefinition = GUIUpdateSequenceDefinition

    local basecontainer = UI:Create("SimpleGroup")
    basecontainer:SetLayout("Fill")
    basecontainer:SetFullHeight(true)
    basecontainer:SetFullWidth(true)
    editframe:AddChild(basecontainer)

    local treeContainer = UI:Create("GSE-TreeGroup")
    treeContainer:SetFullHeight(true)
    treeContainer:SetFullWidth(true)
    local seTreeWidth = GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor and GSEOptions.frameLocations.sequenceeditor.treeWidth
    if seTreeWidth then
        treeContainer:SetTreeWidth(seTreeWidth, true)
    end

    editframe.treeContainer = treeContainer
    treeContainer:SetCallback("OnTreeResize", function()
        SaveSequenceEditorLocation()
    end)

    basecontainer:AddChild(treeContainer)
    local function ChooseVersion(container, version, scrollpos, path)
        version = tonumber(version) or version
        editframe.currentMacroLimitVersion = version
        container:ReleaseChildren()
        editframe.pendingScrollRestore = (scrollpos and scrollpos > 0) and scrollpos or nil
        editframe.DrawSequenceEditor(container, version, path)
        if not GSE.isEmpty(editframe.scrollContainer) and scrollpos > 0 then
            editframe.scrollContainer:SetScroll(scrollpos)
        end
        editframe.scrollContainer:DoLayout()
        if editframe.RefreshMacroLimitSaveState then
            editframe:RefreshMacroLimitSaveState(version)
        end
    end
    -- Re-renders just the action panels of the currently-open version.
    -- Captured by DrawSequenceEditor on every render (covers both the
    -- ChooseVersion path and the direct call from GUIDrawMacroEditor),
    -- so external callers like MacroPreview Show/Close can replay it
    -- without knowing how the original render was triggered.
    editframe.RefreshCurrentVersion = function()
        local last = editframe.lastDrawSequence
        if not (last and last.container and editframe.DrawSequenceEditor) then return end
        editframe.currentMacroLimitVersion = last.version
        last.container:ReleaseChildren()
        editframe.DrawSequenceEditor(last.container, last.version, last.path)
        if editframe.scrollContainer and editframe.scrollContainer.DoLayout then
            editframe.scrollContainer:DoLayout()
        end
        if editframe.RefreshMacroLimitSaveState then
            editframe:RefreshMacroLimitSaveState(last.version)
        end
    end

    local function CreateCombatResetRow(version)
        local resetToolbarRow = UI:Create("SimpleGroup")
        resetToolbarRow:SetLayout("Flow")
        resetToolbarRow:SetFullWidth(true)
        resetToolbarRow:SetHeight(28)
        if resetToolbarRow.SetFlowGap then resetToolbarRow:SetFlowGap(4) end
        if resetToolbarRow.SetFlowVAlign then resetToolbarRow:SetFlowVAlign("CENTER") end
        if resetToolbarRow.SetFlowOffset then resetToolbarRow:SetFlowOffset(0, 4) end

        if GSE.isEmpty(editframe.Sequence.Versions[version].InbuiltVariables) then
            editframe.Sequence.Versions[version].InbuiltVariables = {}
        end

        local resetHeaderIndent = UI:Create("Label")
        resetHeaderIndent:SetWidth(7)

        local resetLabel = UI:Create("Label")
        resetLabel:SetText("Resets Combat")
        resetLabel:SetWidth(110)
        resetLabel:SetHeight(24)
        if resetLabel.SetJustifyV then resetLabel:SetJustifyV("MIDDLE") end
        resetLabel:SetColor(keywordColor())

        local combatResetDropdown = UI:Create("Dropdown")
        combatResetDropdown:SetLabel("")
        combatResetDropdown:SetWidth(235)
        combatResetDropdown:SetHeight(24)
        if combatResetDropdown.SetDropdownStyle then combatResetDropdown:SetDropdownStyle(true) end

        local resetDefault = "default"
        local resetOn = "on"
        local resetOff = "off"
        combatResetDropdown:SetList(
            {
                [resetDefault] = "Default (Use GSE Global)",
                [resetOn] = "On (Reset on Combat Exit)",
                [resetOff] = "Off (Never Reset on Combat Exit)"
            },
            {resetDefault, resetOn, resetOff}
        )

        local function combatResetKey(value)
            if value == true then return resetOn end
            if value == false then return resetOff end
            return resetDefault
        end

        local function combatResetValue(key)
            if key == resetOn then return true end
            if key == resetOff then return false end
            return nil
        end

        resetToolbarRow:AddChild(resetHeaderIndent)
        resetToolbarRow:AddChild(resetLabel)
        resetToolbarRow:AddChild(combatResetDropdown)
        combatResetDropdown:SetValue(combatResetKey(editframe.Sequence.Versions[version].InbuiltVariables.Combat))
        combatResetDropdown:SetCallback(
            "OnValueChanged",
            function(sel, object, value)
                editframe.Sequence.Versions[version].InbuiltVariables.Combat = combatResetValue(value)
            end
        )
        combatResetDropdown:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip("Combat Reset", "Choose whether this sequence resets when you exit combat.", editframe)
            end
        )
        combatResetDropdown:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        return resetToolbarRow
    end

    local function GetRawEditorTextHeight()
        local rawEditorViewportHeight =
            (editframe.scroller and editframe.scroller.height) or
            math.max(80, (editframe.Height or DEFAULT_HEIGHT) - SCROLLCONTAINER_OFFSET - (editframe.staticHeaderHeight or 0))
        return math.max(180, rawEditorViewportHeight - RAW_EDITOR_TEXT_HEIGHT_OFFSET)
    end

    local function SetOuterEditorScrollBarEnabled(enabled)
        if not editframe.scrollContainer then return end

        if editframe.scrollContainer.SetScrollBarEnabled then
            editframe.scrollContainer:SetScrollBarEnabled(enabled)
        elseif editframe.scrollContainer.scrollbar then
            if enabled == false then
                editframe.scrollContainer.scrollbar:Hide()
            else
                editframe.scrollContainer:UpdateScroll()
            end
        end
        if editframe.scrollContainer.DoLayout then editframe.scrollContainer:DoLayout() end
    end

    local function UpdateRawEditorLayout()
        local rawEditor = editframe.rawEditor
        if not (rawEditor and rawEditor.editbox) then return end

        rawEditor.editbox:SetHeight(GetRawEditorTextHeight())
        if rawEditor.buttons then rawEditor.buttons:SetHeight(RAW_EDITOR_BUTTON_ROW_HEIGHT) end
        if rawEditor.container and rawEditor.container.DoLayout then rawEditor.container:DoLayout() end
        if editframe.scrollContainer and editframe.scrollContainer.DoLayout then editframe.scrollContainer:DoLayout() end
        SetOuterEditorScrollBarEnabled(false)
        if editframe.scrollContainer and editframe.scrollContainer.SetScroll then editframe.scrollContainer:SetScroll(0) end
    end

    local function drawRawEditor(container, version, tablestring, path, outerResetToolbarRow)
        container:ReleaseChildren()
        if container.SetAutoHeightExtra then
            container:SetAutoHeightExtra(0)
        else
            container.autoHeightExtra = 0
        end
        if container.SetListPadding then container:SetListPadding(RAW_EDITOR_LEFT_PADDING, RAW_EDITOR_TOP_PADDING, 0, 10) end
        if container.SetListGap then container:SetListGap(2) end
        if outerResetToolbarRow then
            outerResetToolbarRow:SetHeight(0)
            if outerResetToolbarRow.frame then outerResetToolbarRow.frame:Hide() end
            if outerResetToolbarRow.parent and outerResetToolbarRow.parent.SetListGap then
                outerResetToolbarRow.parent:SetListGap(0)
            end
            if outerResetToolbarRow.parent and outerResetToolbarRow.parent.SetListPadding then
                outerResetToolbarRow.parent:SetListPadding(0, 0, 0, 10)
            end
            if outerResetToolbarRow.parent and outerResetToolbarRow.parent.DoLayout then
                outerResetToolbarRow.parent:DoLayout()
            end
        end

        local seqTableEditbox = UI:Create("MultiLineEditBox")
        seqTableEditbox:SetLabel(L["Sequence"])
        seqTableEditbox:DisableButton(true)
        seqTableEditbox:SetHeight(GetRawEditorTextHeight())
        seqTableEditbox:SetFullWidth(true)
        seqTableEditbox:SetText(tablestring)

        IndentationLib.enable(seqTableEditbox.editBox, Statics.IndentationColorTable, 4)
        seqTableEditbox:SetCallback("OnRelease", function(widget)
            DisableRawEditorColoring(widget)
        end)

        local compileButton = UI:Create("Button")
        compileButton:SetText(L["Compile"])
        compileButton:SetWidth(130)
        compileButton:SetCallback(
            "OnClick",
            function()
                local tab
                local load = "return " .. DecodeEditorText(seqTableEditbox:GetText())
                local func, err = loadstring(load)
                if err or not func then
                    GSE.Print(L["Unable to process content.  Fix table and try again."], L["Raw Editor"])
                    if err then
                        GSE.Print(err, L["Raw Editor"])
                    end
                else
                    tab = func()
                    if not GSE.isEmpty(tab) then
                        DisableRawEditorColoring(seqTableEditbox)
                        editframe.Sequence.Versions[version] = tab
                        treeContainer:SelectByValue(path .. "\001" .. version)
                    else
                        GSE.Print(L["Unable to process content.  Fix table and try again."], L["Raw Editor"])
                    end
                end
            end
        )
        compileButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local cancelButton = UI:Create("Button")
        cancelButton:SetText(L["Cancel"])
        cancelButton:SetWidth(130)
        cancelButton:SetCallback(
            "OnClick",
            function()
                DisableRawEditorColoring(seqTableEditbox)
                treeContainer:SelectByValue(path .. "\001" .. version)
            end
        )
        cancelButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )
        container:AddChild(seqTableEditbox)

        local toolcontainer = UI:Create("SimpleGroup")
        toolcontainer:SetLayout("Flow")
        if toolcontainer.SetFlowGap then toolcontainer:SetFlowGap(4) end
        if toolcontainer.SetFlowPadding then toolcontainer:SetFlowPadding(0, 0, 0, 0) end
        if toolcontainer.SetFlowVAlign then toolcontainer:SetFlowVAlign("CENTER") end

        toolcontainer:SetFullWidth(true)
        toolcontainer:SetHeight(RAW_EDITOR_BUTTON_ROW_HEIGHT)
        toolcontainer:AddChild(compileButton)
        toolcontainer:AddChild(cancelButton)
        container:AddChild(toolcontainer)

        editframe.rawEditor = {
            container = container,
            editbox = seqTableEditbox,
            buttons = toolcontainer
        }
        SetOuterEditorScrollBarEnabled(false)

        if editframe.scrollContainer and editframe.scrollContainer.SetScroll then
            editframe.scrollContainer:SetScroll(0)
        end
    end
    local function GetBuildSpinner()
        local anchor = (editframe.scrollContainer and editframe.scrollContainer.frame) or editframe.frame
        if not anchor then return nil end
        local overlay = editframe.buildSpinner
        if overlay and overlay.gseAnchor ~= anchor then
            overlay:Hide()
            overlay = nil
            editframe.buildSpinner = nil
        end
        if not overlay then
            overlay = CreateFrame("Frame", nil, anchor)
            overlay.gseAnchor = anchor
            overlay:SetAllPoints(anchor)
            overlay:SetFrameStrata(anchor:GetFrameStrata() or "DIALOG")
            overlay:SetFrameLevel((anchor:GetFrameLevel() or 0) + 60)
            overlay:EnableMouse(true)   -- swallow clicks on the half-built list
            overlay:SetScript("OnMouseWheel", function() end)
            local bg = overlay:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(overlay)
            bg:SetColorTexture(0, 0, 0, 0.45)
            local cog = overlay:CreateTexture(nil, "ARTWORK")
            cog:SetSize(44, 44)
            cog:SetPoint("CENTER", overlay, "CENTER", 0, 12)
            cog:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\cog.png")
            local ag = cog:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local rot = ag:CreateAnimation("Rotation")
            rot:SetDegrees(-360)
            rot:SetDuration(1.1)
            overlay.spinAnim = ag
            local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOP", cog, "BOTTOM", 0, -12)
            label:SetText("Building editor")
            overlay:Hide()
            editframe.buildSpinner = overlay
        end
        return overlay
    end

    function editframe.ShowBuildSpinner()
        local overlay = GetBuildSpinner()
        if not overlay then return end
        overlay:ClearAllPoints()
        overlay:SetAllPoints(overlay.gseAnchor)
        overlay:Show()
        if overlay.spinAnim then overlay.spinAnim:Play() end
    end

    function editframe.HideBuildSpinner()
        local overlay = editframe.buildSpinner
        if not overlay then return end
        if overlay.spinAnim then overlay.spinAnim:Stop() end
        overlay:Hide()
    end

    local function DrawSequenceEditor(tcontainer, version, path)
        editframe.drawingSequenceEditor = true
        editframe.buildGeneration = (editframe.buildGeneration or 0) + 1
        local myGen = editframe.buildGeneration
        local scrollRestore = editframe.pendingScrollRestore
        editframe.pendingScrollRestore = nil
        local batchLayout = not _G.GSE_NoLayoutBatch
        if batchLayout and UI and UI.SuspendLayout then UI:SuspendLayout() end
        editframe.rawEditor = nil
        SetOuterEditorScrollBarEnabled(true)
        if tcontainer.SetListPadding then
            tcontainer:SetListPadding(0, 0, 0, MACRO_BLOCK_FOCUS_BOTTOM_PADDING)
        end
        -- Captured for editframe.RefreshCurrentVersion so an external open/close
        -- of the Compiled Template window can re-render action panels.
        editframe.currentMacroLimitVersion = version
        editframe.lastDrawSequence = {
            container = tcontainer,
            version = version,
            path = path,
        }
        editframe.macroDragTargets = {}
        editframe.selectedMacroBlockHighlight = nil
        editframe.macroBlockSelectionOverlays = {}
        -- Visual (top-to-bottom) order of selectable blocks, rebuilt each draw as
        -- RegisterMacroBlockSelection runs. Used for arrow-key focus navigation.
        editframe.macroBlockNavOrder = {}

        local function ClonePath(sourcePath)
            local cloned = {}
            for _, value in ipairs(sourcePath or {}) do
                table.insert(cloned, tonumber(value) or value)
            end
            return cloned
        end

        local function ParentPath(sourcePath)
            local parent = ClonePath(sourcePath)
            table.remove(parent, #parent)
            return parent
        end

        local function PathsEqual(leftPath, rightPath)
            if #(leftPath or {}) ~= #(rightPath or {}) then return false end
            for index, value in ipairs(leftPath or {}) do
                if value ~= rightPath[index] then return false end
            end
            return true
        end

        local function SetMacroBlockSelectionOverlayShown(overlay, selected)
            if not overlay then return end
            if selected then
                overlay:Show()
                editframe.selectedMacroBlockHighlight = overlay
            else
                overlay:Hide()
            end
        end

        local function CreateMacroBlockSelectionOverlay(frame, actionType)
            local overlay = CreateFrame("Frame", nil, frame)
            overlay:EnableMouse(false)
            overlay:SetAllPoints(frame)
            if overlay.SetFrameLevel and frame.GetFrameLevel then
                overlay:SetFrameLevel((frame:GetFrameLevel() or 1) + 50)
            end

            local c = BLOCK_FRAME_RAIL_COLORS_BY_TYPE[actionType] or BLOCK_FRAME_RAIL_COLORS_BY_TYPE.Action
            local r, g, b, a = c[1], c[2], c[3], c[4]

            -- Focus tint: a 10%-opacity fill of the rail color drawn DIRECTLY
            -- on the block frame at the lowest BACKGROUND sublevel. WoW
            -- renders a frame's textures BEFORE its child frames, so any
            -- child widget with an opaque backdrop draws over this tint and
            -- hides it. In practice that means the macro edit box (which has
            -- a dark opaque backdrop) reads clean and stays easy to type in,
            -- while the block's "frame" areas around it get the soft tint.
            -- Sublevel -8 puts the texture below any other BACKGROUND
            -- textures that the block's backdrop might add later.
            --
            -- The tint lives on the BLOCK frame, not on the overlay frame
            -- (which carries the proc-pulse alpha animation), so it stays
            -- constant at 10% regardless of which proc style is active.
            -- gseRefreshTint() also honours the FocusHighlightTint master
            -- toggle and the per-action Disabled state — when either is
            -- off-true the tint is hidden so the red-disable highlight or
            -- the plain editor view dominates.
            -- ARTWORK (not BACKGROUND): under EllesmereUI every block frame gets
            -- an opaque flat inset backdrop (Skin.lua paintFlatBackdrop, drawn at
            -- BACKGROUND) which would otherwise hide this tint. ARTWORK sits above
            -- that fill but below the block's content child-frame, so the tint
            -- reads as the block surround on both the EUI and default skins.
            local focusTint = frame:CreateTexture(nil, "ARTWORK", nil, -8)
            focusTint:SetColorTexture(c[1], c[2], c[3], 0.25)
            focusTint:SetAllPoints(frame)
            focusTint:Hide()
            overlay.gseFocusTint = focusTint

            overlay.gseRefreshTint = function()
                local tint = overlay.gseFocusTint
                if not tint then return end
                if not overlay:IsShown() then tint:Hide(); return end
                -- Master toggle: explicit false disables tinting globally.
                -- nil / true (the default) leaves it enabled, so existing
                -- saved-variable files without this key behave like before.
                if GSEOptions and GSEOptions.FocusHighlightTint == false then
                    tint:Hide()
                    return
                end
                local action = overlay.gseGetAction and overlay.gseGetAction()
                if action and action.Disabled then
                    tint:Hide()
                else
                    tint:Show()
                end
            end

            overlay.top = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            overlay.bottom = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            overlay.left = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            overlay.right = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            local thickness = 2
            for _, line in ipairs({overlay.top, overlay.bottom, overlay.left, overlay.right}) do
                line:SetColorTexture(r, g, b, a)
            end
            overlay.top:SetPoint("TOPLEFT", overlay, "TOPLEFT", 1, -1)
            overlay.top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)
            overlay.top:SetHeight(thickness)
            overlay.bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 1, 3)
            overlay.bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 3)
            overlay.bottom:SetHeight(thickness)
            overlay.left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 1, -1)
            overlay.left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 1, 3)
            overlay.left:SetWidth(thickness)
            overlay.right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)
            overlay.right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 3)
            overlay.right:SetWidth(thickness)

            -- Proc-style pulse animation on the focused border. The four border
            -- textures' alpha drops to a low value and back to 100% over a 1.4s
            -- loop, giving the selected block a subtle "throbbing" feel like a
            -- spell proc. Uses WoW's native AnimationGroup (driven by the render
            -- thread) rather than OnUpdate so it's efficient and pauses
            -- automatically when hidden. The low-alpha bound is driven by the
            -- GSEOptions.FocusHighProc dropdown (Off/Low/Medium/High); alpha
            -- values are read each Play so the dropdown takes effect live.
            local pulse = overlay:CreateAnimationGroup()
            pulse:SetLooping("REPEAT")
            local fadeOut = pulse:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(1.0)
            fadeOut:SetToAlpha(0.45)
            fadeOut:SetDuration(0.7)
            fadeOut:SetOrder(1)
            fadeOut:SetSmoothing("IN_OUT")
            local fadeIn = pulse:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0.45)
            fadeIn:SetToAlpha(1.0)
            fadeIn:SetDuration(0.7)
            fadeIn:SetOrder(2)
            fadeIn:SetSmoothing("IN_OUT")
            -- Stash refs so the FocusHighProc Settings-callback can update
            -- alpha values without recreating overlays.
            overlay.gsePulse = pulse
            overlay.gseFadeOut = fadeOut
            overlay.gseFadeIn = fadeIn
            FocusHighProcOverlays[overlay] = true
            -- Apply the configured level now so the initial values match the
            -- saved setting instead of the hardcoded 0.45 baseline.
            ApplyFocusHighProcToOverlay(overlay)
            overlay:HookScript("OnShow", function(self)
                -- Re-read on every Show so a setting change since last view
                -- takes effect on the next focus.
                ApplyFocusHighProcToOverlay(self)
                local cfg = GetFocusHighProcConfig()
                if cfg.low < 1.00 then pulse:Play() end
                if self.gseRefreshTint then self.gseRefreshTint() end
            end)
            overlay:HookScript("OnHide", function(self)
                pulse:Stop()
                self:SetAlpha(1)  -- restore baseline alpha so next Show starts solid
                if self.gseFocusTint then self.gseFocusTint:Hide() end
            end)

            overlay:Hide()
            return overlay
        end

        local function MacroBlockSelectionKey(keyPath)
            return GSE.SafeConcat(keyPath or {}, ".")
        end

        local function MacroBlockPathIsEmpty(keyPath)
            return type(keyPath) ~= "table" or #keyPath == 0
        end

        local function MacroBlockAutoSelectionAllowed(keyPath)
            if MacroBlockPathIsEmpty(editframe.macroBlockAutoSelectOnlyPath) then return true end

            local now = GetTime and GetTime() or 0
            if editframe.macroBlockAutoSelectOnlyUntil and now > editframe.macroBlockAutoSelectOnlyUntil then
                editframe.macroBlockAutoSelectOnlyPath = nil
                editframe.macroBlockAutoSelectOnlyUntil = nil
                return true
            end

            return PathsEqual(editframe.macroBlockAutoSelectOnlyPath, keyPath)
        end

        local function RestrictMacroBlockAutoSelectionToPath(keyPath, duration)
            if MacroBlockPathIsEmpty(keyPath) then return end
            editframe.macroBlockAutoSelectOnlyPath = ClonePath(keyPath)
            editframe.macroBlockAutoSelectOnlyUntil = (GetTime and GetTime() or 0) + (duration or 0.4)
        end

        local function ClearMacroBlockAutoSelectionRestriction(keyPath)
            if
                MacroBlockPathIsEmpty(editframe.macroBlockAutoSelectOnlyPath) or
                MacroBlockPathIsEmpty(keyPath) or
                PathsEqual(editframe.macroBlockAutoSelectOnlyPath, keyPath)
            then
                editframe.macroBlockAutoSelectOnlyPath = nil
                editframe.macroBlockAutoSelectOnlyUntil = nil
            end
        end

        local function SelectMacroBlockPath(keyPath, overlay, force)
            if MacroBlockPathIsEmpty(keyPath) then return end
            if editframe.drawingSequenceEditor and not force then return end
            if not force and editframe.suppressMacroAutoSelectUntil and
                (GetTime and GetTime() or 0) < editframe.suppressMacroAutoSelectUntil then
                return
            end
            overlay = overlay or (editframe.macroBlockSelectionOverlays and
                editframe.macroBlockSelectionOverlays[MacroBlockSelectionKey(keyPath)])

            if editframe.selectedMacroBlockHighlight and editframe.selectedMacroBlockHighlight ~= overlay then
                editframe.selectedMacroBlockHighlight:Hide()
            end

            editframe.selectedMacroBlockPath = ClonePath(keyPath)
            editframe.selectedMacroBlockVersion = version
            SetMacroBlockSelectionOverlayShown(overlay, true)
            if editframe.UpdateMacroBlockToolbarState then
                editframe.UpdateMacroBlockToolbarState()
            end
            -- Center the selected block in the scroll view
            if editframe.gseFocusSelectedMacroBlock then
                C_Timer.After(0.05, editframe.gseFocusSelectedMacroBlock)
            end
        end

        -- Expose to GUIDrawMacroEditor scope (InsertTopToolbarAction cannot see these
        -- locals directly because it lives in a sibling function, not inside DrawSequenceEditor).
        editframe.gseSelectMacroBlockPath = SelectMacroBlockPath
        editframe.gseRestrictMacroBlockAutoSelect = RestrictMacroBlockAutoSelectionToPath
        editframe.gseClearMacroBlockAutoSelect = ClearMacroBlockAutoSelectionRestriction

        local function HookMacroBlockSelectionFrame(frame, keyPath)
            if not (frame and frame.HookScript) then return end
            local function selectBlock()
                if not MacroBlockAutoSelectionAllowed(keyPath) then return end
                SelectMacroBlockPath(keyPath)
            end

            for _, scriptName in ipairs({"OnMouseDown", "OnClick", "OnEditFocusGained"}) do
                local shouldHook = true
                if frame.HasScript then
                    local ok, hasScript = pcall(frame.HasScript, frame, scriptName)
                    shouldHook = ok and hasScript
                end
                if shouldHook then
                    pcall(frame.HookScript, frame, scriptName, selectBlock)
                end
            end
        end

        local function HookMacroBlockSelectionWidget(widget, keyPath)
            if not widget then return end
            local seenFrames = {}
            for _, frame in ipairs({widget.frame, widget.editbox, widget.editBox, widget.scrollFrame, widget.checkbg}) do
                if frame and not seenFrames[frame] then
                    seenFrames[frame] = true
                    HookMacroBlockSelectionFrame(frame, keyPath)
                end
            end
        end

        local function RegisterMacroBlockSelection(widget, keyPath, actionType)
            if not (widget and widget.frame) then return end
            local frame = widget.frame
            local overlay = CreateMacroBlockSelectionOverlay(frame, actionType)
            editframe.macroBlockSelectionOverlays[MacroBlockSelectionKey(keyPath)] = overlay
            if editframe.macroBlockNavOrder then
                editframe.macroBlockNavOrder[#editframe.macroBlockNavOrder + 1] = ClonePath(keyPath)
            end
            -- Closure so the overlay can resolve its action struct at show
            -- time and check action.Disabled to decide whether to render the
            -- focus tint. Cloned keyPath captured by value so subsequent
            -- mutations to the caller's table can't break the lookup.
            local boundKeyPath = ClonePath(keyPath)
            overlay.gseGetAction = function()
                if not (editframe and editframe.Sequence and editframe.Sequence.Versions) then return nil end
                local v = editframe.Sequence.Versions[version]
                if not (v and v.Actions) then return nil end
                local node = v.Actions
                for _, step in ipairs(boundKeyPath) do
                    if type(node) ~= "table" then return nil end
                    node = node[step]
                end
                return node
            end
            local pendingSelected = editframe.pendingMacroBlockSelectVersion == version and
                PathsEqual(editframe.pendingMacroBlockSelectPath, keyPath)
            if pendingSelected then
                editframe.selectedMacroBlockPath = ClonePath(keyPath)
                editframe.selectedMacroBlockVersion = version
            end
            local selected = pendingSelected or editframe.selectedMacroBlockVersion == version and
                PathsEqual(editframe.selectedMacroBlockPath, keyPath)
            SetMacroBlockSelectionOverlayShown(overlay, selected)
            frame:EnableMouse(true)
            frame:HookScript(
                "OnMouseDown",
                function(_, button)
                    if button ~= "LeftButton" or editframe.macroBlockDrag then return end
                    local alreadySelected = editframe.selectedMacroBlockVersion == version and
                        PathsEqual(editframe.selectedMacroBlockPath, keyPath)

                    if editframe.selectedMacroBlockHighlight and editframe.selectedMacroBlockHighlight ~= overlay then
                        editframe.selectedMacroBlockHighlight:Hide()
                    end

                    if alreadySelected then
                        editframe.selectedMacroBlockPath = nil
                        editframe.selectedMacroBlockVersion = nil
                        SetMacroBlockSelectionOverlayShown(overlay, false)
                    else
                        SelectMacroBlockPath(keyPath, overlay)
                    end
                end
            )
        end

        local function PathStartsWith(sourcePath, prefixPath)
            if #(prefixPath or {}) > #(sourcePath or {}) then return false end
            for index, value in ipairs(prefixPath or {}) do
                if sourcePath[index] ~= value then return false end
            end
            return true
        end

        local function FrameContainsCursor(frame)
            if not frame or not frame:IsShown() then return false end
            local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
            if not left or not right or not top or not bottom then return false end
            local scale = frame:GetEffectiveScale() or 1
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
        end

        local MACRO_BLOCK_DROP_HEADER_PADDING = 2
        local MACRO_BLOCK_DROP_FOOTER_PADDING = 4
        local MACRO_BLOCK_AUTO_SCROLL_EDGE = 34
        local MACRO_BLOCK_AUTO_SCROLL_OUTSIDE = 140
        local MACRO_BLOCK_AUTO_SCROLL_SPEED = 460

        local function GetMacroBlockDropAreaFrame(targetEditor)
            targetEditor = targetEditor or editframe
            local scrollContainer = targetEditor and targetEditor.scrollContainer
            if scrollContainer then
                return scrollContainer.scrollframe or scrollContainer.frame
            end
            return targetEditor and targetEditor.frame
        end

        local function GetMacroBlockDropAreaBounds(targetEditor)
            targetEditor = targetEditor or editframe
            local areaFrame = GetMacroBlockDropAreaFrame(targetEditor)
            if not areaFrame or not areaFrame:IsShown() then return nil end

            local left, right, top, bottom = areaFrame:GetLeft(), areaFrame:GetRight(), areaFrame:GetTop(), areaFrame:GetBottom()
            if not left or not right or not top or not bottom then return nil end

            local headerFrame = targetEditor.staticHeaderContainer and targetEditor.staticHeaderContainer.frame
            local headerBottom = headerFrame and headerFrame:IsShown() and headerFrame:GetBottom()
            if headerBottom then
                top = math.min(top, headerBottom - MACRO_BLOCK_DROP_HEADER_PADDING)
            end

            local footerFrame = targetEditor.editButtonGroup and targetEditor.editButtonGroup.frame
            local footerTop = footerFrame and footerFrame:IsShown() and footerFrame:GetTop()
            if footerTop then
                bottom = math.max(bottom, footerTop + MACRO_BLOCK_DROP_FOOTER_PADDING)
            end

            if bottom > top then return nil end
            return left, right, top, bottom, areaFrame
        end

        local function CursorInsideMacroBlockDropArea(targetEditor)
            local left, right, top, bottom, areaFrame = GetMacroBlockDropAreaBounds(targetEditor)
            if not left then return false end

            local scale = areaFrame:GetEffectiveScale() or 1
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
        end

        local function AutoScrollMacroBlockDropArea(targetEditor, elapsed)
            targetEditor = targetEditor or editframe
            local scrollContainer = targetEditor and targetEditor.scrollContainer
            if not (scrollContainer and scrollContainer.SetScroll) then return false end

            local left, right, top, bottom, areaFrame = GetMacroBlockDropAreaBounds(targetEditor)
            if not left then return false end

            local scale = areaFrame:GetEffectiveScale() or 1
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            if cursorX < left or cursorX > right then return false end

            local direction, distance
            if cursorY > top then
                direction = -1
                distance = cursorY - top
            elseif cursorY < bottom then
                direction = 1
                distance = bottom - cursorY
            elseif cursorY >= top - MACRO_BLOCK_AUTO_SCROLL_EDGE then
                direction = -1
                distance = top - cursorY
            elseif cursorY <= bottom + MACRO_BLOCK_AUTO_SCROLL_EDGE then
                direction = 1
                distance = cursorY - bottom
            else
                return false
            end

            if distance > MACRO_BLOCK_AUTO_SCROLL_OUTSIDE then return false end

            local status = scrollContainer.status or scrollContainer.localstatus or targetEditor.scrollStatus or {}
            local scrollFrame = scrollContainer.scrollframe
            local current = status.scrollvalue or (scrollFrame and scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll()) or 0
            local factor = math.max(0.25, math.min(1, distance / MACRO_BLOCK_AUTO_SCROLL_EDGE))
            scrollContainer:SetScroll(current + (direction * MACRO_BLOCK_AUTO_SCROLL_SPEED * (elapsed or 0.016) * factor))
            return true
        end

        local function MacroBlockDropMarkerInsideArea(targetEditor, targetFrame, dropAfter)
            local _, _, top, bottom = GetMacroBlockDropAreaBounds(targetEditor)
            if not top then return false end

            local markerY = dropAfter and targetFrame:GetBottom() or targetFrame:GetTop()
            return markerY and markerY >= bottom and markerY <= top
        end

        local function GetActionList(listPath, targetEditor, targetVersion)
            targetEditor = targetEditor or editframe
            targetVersion = tonumber(targetVersion or version)
            local actions = targetEditor.Sequence and targetEditor.Sequence.Versions and
                targetEditor.Sequence.Versions[targetVersion] and targetEditor.Sequence.Versions[targetVersion].Actions
            if type(actions) ~= "table" then return nil end
            if GSE.isEmpty(listPath) or #listPath == 0 then return actions end
            local actionList = actions[listPath]
            if type(actionList) ~= "table" then return nil end
            return actionList
        end

        local function GetActionAtPath(actionPath)
            local actionList = GetActionList(ParentPath(actionPath))
            local actionIndex = actionPath and tonumber(actionPath[#actionPath])
            if type(actionList) ~= "table" or not actionIndex then return nil end
            return rawget(actionList, actionIndex)
        end

        local function GetContainingIfBlockPathForMove(actionPath)
            local containingIfPath
            local candidatePath = {}
            for index = 1, math.max(0, #(actionPath or {}) - 2) do
                table.insert(candidatePath, actionPath[index])
                local branchIndex = tonumber(actionPath[index + 1])
                local candidateAction = GetActionAtPath(candidatePath)
                if
                    candidateAction and
                    candidateAction.Type == Statics.Actions.If and
                    (branchIndex == 1 or branchIndex == 2)
                then
                    containingIfPath = ClonePath(candidatePath)
                end
            end
            return containingIfPath
        end

        local function GetContainingIfBranchPathForMove(actionPath, containingIfPath)
            if not containingIfPath or not PathStartsWith(actionPath, containingIfPath) then return nil end
            local branchIndex = tonumber(actionPath[#containingIfPath + 1])
            if branchIndex ~= 1 and branchIndex ~= 2 then return nil end

            local branchPath = ClonePath(containingIfPath)
            table.insert(branchPath, branchIndex)
            return branchPath
        end

        local function MoveCrossesIfBranchBoundaryForMove(sourcePath, destinationPath)
            local sourceContainingIfPath = GetContainingIfBlockPathForMove(sourcePath)
            local sourceBranchPath = sourceContainingIfPath and
                GetContainingIfBranchPathForMove(sourcePath, sourceContainingIfPath) or
                nil
            local destinationContainingIfPath = GetContainingIfBlockPathForMove(destinationPath)
            local destinationBranchPath = destinationContainingIfPath and
                GetContainingIfBranchPathForMove(destinationPath, destinationContainingIfPath) or
                nil

            if sourceBranchPath then
                return not (destinationBranchPath and PathsEqual(sourceBranchPath, destinationBranchPath))
            end
            return destinationBranchPath ~= nil
        end

        local function FirstLine(value)
            value = tostring(value or "")
            value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            return value:match("([^\r\n]+)") or ""
        end

        local function GetMacroBlockDragText(action, sourcePath)
            local actionType = action and action.Type
            local title = (actionType == Statics.Actions.Repeat and Statics.Actions.Action) or Statics.Actions[actionType] or actionType or "Block"
            local detail = GSE.SafeConcat(sourcePath, ".")

            if actionType == Statics.Actions.Action or actionType == Statics.Actions.Repeat then
                detail = FirstLine(action.macro or action.spell or action.item or action.toy or action.action)
                if GSE.isEmpty(detail) then detail = action.type or GSE.SafeConcat(sourcePath, ".") end
            elseif actionType == Statics.Actions.Loop then
                detail = "Repeat " .. tostring(action.Repeat or 1)
            elseif actionType == Statics.Actions.Pause then
                detail = tostring(action.Variable or action.MS or action.Clicks or "Pause")
            elseif actionType == Statics.Actions.If then
                detail = FirstLine(action.Variable)
            elseif actionType == Statics.Actions.Embed then
                detail = tostring(action.Sequence or "Embed")
            end

            return title, detail, Statics.ActionsIcons[actionType] or Statics.ActionsIcons.Action
        end

        local function RegisterMacroBlockDragTarget(frame, keyPath)
            if not frame then return end
            table.insert(
                editframe.macroDragTargets,
                {
                    frame = frame,
                    keyPath = ClonePath(keyPath),
                    editor = editframe,
                    version = version
                }
            )
        end

        local function GetMacroBlockDropPath(sourcePath)
            if not CursorInsideMacroBlockDropArea(editframe) then return nil end

            local target
            for _, candidate in ipairs(editframe.macroDragTargets or {}) do
                if
                    candidate.frame and
                    candidate.frame:IsShown() and
                    FrameContainsCursor(candidate.frame) and
                    not PathsEqual(candidate.keyPath, sourcePath) and
                    not PathStartsWith(candidate.keyPath, sourcePath)
                    then
                    if not target or #candidate.keyPath > #target.keyPath then
                        target = candidate
                    end
                end
            end
            if not target then return nil end

            local destinationPath = ClonePath(target.keyPath)
            local frame = target.frame
            local top, bottom = frame:GetTop(), frame:GetBottom()
            local dropAfter = false
            if top and bottom then
                local _, cursorY = GetCursorPosition()
                cursorY = cursorY / (frame:GetEffectiveScale() or 1)
                if cursorY < ((top + bottom) / 2) then
                    dropAfter = true
                    destinationPath[#destinationPath] = destinationPath[#destinationPath] + 1
                end
            end
            if not MacroBlockDropMarkerInsideArea(editframe, frame, dropAfter) then return nil end
            if MoveCrossesIfBranchBoundaryForMove(sourcePath, destinationPath) then return nil end
            return destinationPath, frame, dropAfter
        end

        local function GetCrossEditorMacroBlockDropPath()
            local target
            for _, editor in ipairs(GSE.GUI.editors or {}) do
                if editor ~= editframe and EditorIsVisible(editor) and CursorInsideMacroBlockDropArea(editor) then
                    for _, candidate in ipairs(editor.macroDragTargets or {}) do
                        if candidate.frame and candidate.frame:IsShown() and FrameContainsCursor(candidate.frame) then
                            if not target or #candidate.keyPath > #target.keyPath then
                                target = candidate
                            end
                        end
                    end
                end
            end
            if not target then return nil end

            local destinationPath = ClonePath(target.keyPath)
            local frame = target.frame
            local top, bottom = frame:GetTop(), frame:GetBottom()
            local dropAfter = false
            if top and bottom then
                local _, cursorY = GetCursorPosition()
                cursorY = cursorY / (frame:GetEffectiveScale() or 1)
                if cursorY < ((top + bottom) / 2) then
                    dropAfter = true
                    destinationPath[#destinationPath] = destinationPath[#destinationPath] + 1
                end
            end
            if not MacroBlockDropMarkerInsideArea(target.editor, frame, dropAfter) then return nil end
            return destinationPath, frame, dropAfter, target.editor, target.version
        end

        local function MoveMacroBlockToPath(sourcePath, destinationPath, destinationEditor, destinationVersion)
            if GSE.isEmpty(sourcePath) or GSE.isEmpty(destinationPath) then return false end

            destinationEditor = destinationEditor or editframe
            destinationVersion = tonumber(destinationVersion or version)
            local sourceParent = ParentPath(sourcePath)
            local destinationParent = ParentPath(destinationPath)
            local sameEditorVersion = destinationEditor == editframe and destinationVersion == tonumber(version)
            if sameEditorVersion and PathsEqual(sourcePath, destinationPath) then return false end
            if sameEditorVersion and PathStartsWith(destinationParent, sourcePath) then return false end
            if sameEditorVersion and MoveCrossesIfBranchBoundaryForMove(sourcePath, destinationPath) then return false end

            local sourceList = GetActionList(sourceParent)
            local destinationList = GetActionList(destinationParent, destinationEditor, destinationVersion)
            if type(sourceList) ~= "table" or type(destinationList) ~= "table" then return false end

            local sourceIndex = tonumber(sourcePath[#sourcePath])
            local destinationIndex = tonumber(destinationPath[#destinationPath])
            if not sourceIndex or not destinationIndex or not sourceList[sourceIndex] then return false end

            local movingAction = GSE.CloneSequence(sourceList[sourceIndex])

            if sameEditorVersion then table.remove(sourceList, sourceIndex) end

            if sameEditorVersion and sourceList == destinationList and destinationIndex > sourceIndex then
                destinationIndex = destinationIndex - 1
            end
            if destinationIndex < 1 then destinationIndex = 1 end
            if destinationIndex > #destinationList + 1 then destinationIndex = #destinationList + 1 end

            table.insert(destinationList, destinationIndex, movingAction)

            local newPath = ClonePath(destinationParent)
            table.insert(newPath, destinationIndex)
            return true, newPath
        end

        local FinishMacroBlockDrag
        local UpdateMacroBlockDrag
        local DROP_MARKER_CURSOR_Y_OFFSET = -2
        local function EnsureMacroBlockDragGhost()
            if editframe.macroBlockDragGhost then return editframe.macroBlockDragGhost end

            local ghost = CreateFrame("Frame", nil, UIParent)
            ghost:SetFrameStrata("TOOLTIP")
            ghost:SetSize(170, 44)
            ghost:EnableMouse(false)
            ghost.bg = ghost:CreateTexture(nil, "BACKGROUND")
            ghost.bg:SetAllPoints()
            ghost.bg:SetColorTexture(0, 0, 0, 0.82)
            ghost.rail = ghost:CreateTexture(nil, "ARTWORK")
            ghost.rail:SetPoint("TOPLEFT")
            ghost.rail:SetPoint("BOTTOMLEFT")
            ghost.rail:SetWidth(4)
            ghost.rail:SetColorTexture(0.25, 1.00, 0.35, 1)
            ghost.texture = ghost:CreateTexture(nil, "ARTWORK")
            ghost.texture:SetSize(30, 30)
            ghost.texture:SetPoint("LEFT", 10, 0)
            ghost.texture:SetTexture(Statics.ActionsIcons.Mouse)
            ghost.texture:SetAlpha(0.85)
            ghost.title = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            ghost.title:SetPoint("LEFT", ghost.texture, "RIGHT", 8, 0)
            ghost.title:SetPoint("RIGHT", -8, 0)
            ghost.title:SetJustifyH("LEFT")
            if ghost.title.SetWordWrap then ghost.title:SetWordWrap(false) end
            ghost:Hide()
            editframe.macroBlockDragGhost = ghost
            return ghost
        end

        local function UpdateMacroBlockDragGhost(ghost, action, sourcePath)
            local title, _, icon = GetMacroBlockDragText(action, sourcePath)
            ghost.texture:SetTexture(icon)
            ghost.title:SetText(title)
        end

        local function EnsureMacroBlockDropMarker()
            if editframe.macroBlockDropMarker then return editframe.macroBlockDropMarker end

            local marker = CreateFrame("Frame", nil, UIParent)
            marker:SetFrameStrata("TOOLTIP")
            marker:SetSize(160, 8)
            marker:EnableMouse(false)
            marker.line = marker:CreateTexture(nil, "ARTWORK")
            marker.line:SetPoint("LEFT")
            marker.line:SetPoint("RIGHT")
            marker.line:SetHeight(4)
            marker.line:SetColorTexture(0.25, 1.00, 0.35, 1)
            marker.left = marker:CreateTexture(nil, "ARTWORK")
            marker.left:SetSize(8, 8)
            marker.left:SetPoint("LEFT")
            marker.left:SetColorTexture(0.25, 1.00, 0.35, 1)
            marker.right = marker:CreateTexture(nil, "ARTWORK")
            marker.right:SetSize(8, 8)
            marker.right:SetPoint("RIGHT")
            marker.right:SetColorTexture(0.25, 1.00, 0.35, 1)
            marker:Hide()
            editframe.macroBlockDropMarker = marker
            return marker
        end

        local function HideMacroBlockDropMarker()
            if editframe.macroBlockDropMarker then
                editframe.macroBlockDropMarker:Hide()
            end
        end

        local function ShowMacroBlockDropMarker(targetFrame, dropAfter)
            if not targetFrame then
                HideMacroBlockDropMarker()
                return
            end

            local marker = EnsureMacroBlockDropMarker()
            local width = targetFrame:GetWidth()
            if width and width > 40 then marker:SetWidth(width) end
            marker:ClearAllPoints()
            if dropAfter then
                marker:SetPoint("CENTER", targetFrame, "BOTTOM", 0, -2 + DROP_MARKER_CURSOR_Y_OFFSET)
            else
                marker:SetPoint("CENTER", targetFrame, "TOP", 0, 2 + DROP_MARKER_CURSOR_Y_OFFSET)
            end
            marker:Show()
        end

        local function PositionMacroBlockDragGhost(ghost)
            local scale = UIParent:GetEffectiveScale() or 1
            local cursorX, cursorY = GetCursorPosition()
            ghost:ClearAllPoints()
            ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cursorX / scale) + 12, (cursorY / scale) - 12)
        end

        local function BeginMacroBlockDrag(sourcePath, treepath, dragHandle)
            if GSE.isEmpty(sourcePath) then return false end
            local startX, startY = GetCursorPosition()
            local sourceAction = GetActionAtPath(sourcePath)
            editframe.macroBlockDrag = {
                sourcePath = ClonePath(sourcePath),
                treepath = treepath,
                dragHandle = dragHandle,
                startX = startX,
                startY = startY,
                originalActions = GSE.CloneSequence(editframe.Sequence.Versions[version].Actions)
            }
            if dragHandle and dragHandle.SetHoverLocked then dragHandle:SetHoverLocked(true) end

            local ghost = EnsureMacroBlockDragGhost()
            UpdateMacroBlockDragGhost(ghost, sourceAction, sourcePath)
            PositionMacroBlockDragGhost(ghost)
            ghost:Show()
            ghost:SetScript(
                "OnUpdate",
                function(self, elapsed)
                    if not editframe.macroBlockDrag then
                        self:SetScript("OnUpdate", nil)
                        self:Hide()
                        return
                    end
                    PositionMacroBlockDragGhost(self)
                    UpdateMacroBlockDrag(AutoScrollMacroBlockDropArea(editframe, elapsed))
                    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                        FinishMacroBlockDrag()
                    end
                end
            )
            return true
        end

        UpdateMacroBlockDrag = function(force)
            local drag = editframe.macroBlockDrag
            if not drag then return false end

            local cursorX, cursorY = GetCursorPosition()
            local dx = cursorX - (drag.startX or cursorX)
            local dy = cursorY - (drag.startY or cursorY)
            if not force and (dx * dx + dy * dy) < 64 then return false end

            local destinationPath, targetFrame, dropAfter, destinationEditor, destinationVersion
            if CursorInsideMacroBlockDropArea(editframe) then
                destinationPath, targetFrame, dropAfter = GetMacroBlockDropPath(drag.sourcePath)
                destinationEditor = editframe
                destinationVersion = version
            else
                destinationPath, targetFrame, dropAfter, destinationEditor, destinationVersion = GetCrossEditorMacroBlockDropPath()
            end
            drag.dropPath = destinationPath
            drag.dropEditor = destinationEditor
            drag.dropVersion = destinationVersion
            if destinationPath then
                ShowMacroBlockDropMarker(targetFrame, dropAfter)
            else
                HideMacroBlockDropMarker()
            end
            return destinationPath ~= nil
        end

        FinishMacroBlockDrag = function()
            local drag = editframe.macroBlockDrag
            if not drag then return end
            local releasedInside = CursorInsideMacroBlockDropArea(editframe)
            UpdateMacroBlockDrag(true)

            editframe.macroBlockDrag = nil
            if drag.dragHandle and drag.dragHandle.SetHoverLocked then drag.dragHandle:SetHoverLocked(false) end
            HideMacroBlockDropMarker()

            local ghost = editframe.macroBlockDragGhost
            if ghost then
                ghost:SetScript("OnUpdate", nil)
                ghost:Hide()
            end

            if releasedInside and drag.dropPath then
                local moved = MoveMacroBlockToPath(drag.sourcePath, drag.dropPath)
                if moved then
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, drag.treepath)
                end
            elseif drag.dropPath and drag.dropEditor and drag.dropEditor ~= editframe then
                local copied = MoveMacroBlockToPath(drag.sourcePath, drag.dropPath, drag.dropEditor, drag.dropVersion)
                if copied then
                    SetActiveEditor(drag.dropEditor)
                    if drag.dropEditor.RefreshCurrentVersion then drag.dropEditor.RefreshCurrentVersion() end
                end
            elseif not releasedInside and drag.originalActions then
                editframe.Sequence.Versions[version].Actions = drag.originalActions
                setmetatable(editframe.Sequence.Versions[version].Actions, Statics.TableMetadataFunction)
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, drag.treepath)
            end
        end
    local function GetBlockToolbar(
            version,
            path,
            treepath,
            includeAdd,
            headingLabel,
            container,
            disableMove,
            disableDelete,
            dontDeleteLastParent)
            local layoutcontainer = UI:Create("SimpleGroup")

            local actions = editframe.Sequence.Versions[version].Actions
            local lastPath = path[#path]

            local parentPath = GSE.CloneSequence(path)
            local toolbarTargetPath = {}

            local function EnsureActionList(listPath)
                if GSE.isEmpty(listPath) or #listPath == 0 then
                    return actions
                end

                local actionList = actions[listPath]
                if type(actionList) ~= "table" then
                    actions[listPath] = {}
                    actionList = actions[listPath]
                end
                return actionList
            end

            if #parentPath == 1 then
            else
                if GSE.isEmpty(dontDeleteLastParent) then
                    parentPath[#parentPath] = nil
                end
                toolbarTargetPath = GSE.CloneSequence(parentPath)
            end

            local function InsertToolbarAction(newAction)
                local targetList = EnsureActionList(toolbarTargetPath)
                local insertAt

                if GSE.isEmpty(dontDeleteLastParent) then
                    insertAt = lastPath + 1
                    if insertAt > #targetList + 1 then
                        insertAt = #targetList + 1
                    end
                else
                    insertAt = #targetList + 1
                end

                table.insert(targetList, insertAt, newAction)
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end

            local function InsertChildAction(newAction)
                local targetList = EnsureActionList(path)
                table.insert(targetList, #targetList + 1, newAction)
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
            layoutcontainer:SetLayout("Flow")
            if layoutcontainer.SetFlowGap then layoutcontainer:SetFlowGap(4) end
            if layoutcontainer.SetFlowVAlign then layoutcontainer:SetFlowVAlign("CENTER") end
            if layoutcontainer.SetFlowPadding then layoutcontainer:SetFlowPadding(4, 0, 4, 0) end
            layoutcontainer:SetFullWidth(true)
            layoutcontainer:SetHeight(32)
            local dragHandle

            if GSE.isEmpty(disableMove) then
                dragHandle = UI:Create("Icon")
                if dragHandle.SetElvUIIconBackgroundShown then dragHandle:SetElvUIIconBackgroundShown(false) end
                dragHandle:SetImageSize(30, 30)
                dragHandle:SetHoverImageSize(35, 35)
                dragHandle:SetWidth(30)
                dragHandle:SetHeight(30)
                dragHandle:SetImage(Statics.ActionsIcons.Mouse)
                dragHandle.frame:SetScript(
                    "OnMouseDown",
                    function(_, mouseButton)
                        if mouseButton == "LeftButton" then
                            BeginMacroBlockDrag(path, treepath, dragHandle)
                        end
                    end
                )
                dragHandle.frame:SetScript(
                    "OnMouseUp",
                    function(_, mouseButton)
                        if mouseButton == "LeftButton" then
                            FinishMacroBlockDrag()
                        end
                    end
                )
                dragHandle:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            "Drag Block",
                            "Hold left mouse on this icon, drag to another block, then release to move this block.",
                            editframe
                        )
                    end
                )
                dragHandle:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            local deleteBlockButton
            if not disableDelete then
                deleteBlockButton = UI:Create("Icon")
                deleteBlockButton:SetImageSize(30, 30)
                deleteBlockButton:SetWidth(30)
                deleteBlockButton:SetHeight(30)
                deleteBlockButton:SetImage([[Interface\AddOns\GSE_GUI\Assets\close.png]])
                if deleteBlockButton.SetElvUISubduedIcon then deleteBlockButton:SetElvUISubduedIcon(true) end

                deleteBlockButton:SetCallback(
                    "OnClick",
                    function()
                        container:ReleaseChildren()
                        local delPath = {}
                        local delObj
                        for k, v in ipairs(path) do
                            if k == #path then
                                delObj = v
                            else
                                table.insert(delPath, v)
                            end
                        end
                        local targetList = EnsureActionList(delPath)
                        local removed = false
                        if targetList and delObj and delObj >= 1 and delObj <= #targetList then
                            table.remove(targetList, delObj)
                            removed = true
                        end

                        -- Deleting a block used to leave the rebuilt editor scrolled to the
                        -- top, forcing the user to scroll all the way back down. Instead, keep
                        -- them where they were: select + scroll to the block immediately above
                        -- the one just removed (falling back to the new first block, or the
                        -- parent container block when a nested list is emptied). This mirrors
                        -- the Add/Move pending-select-then-focus pattern used elsewhere.
                        local focusPath
                        if removed then
                            if targetList and #targetList > 0 then
                                local focusIdx = delObj - 1
                                if focusIdx < 1 then focusIdx = 1 end
                                if focusIdx > #targetList then focusIdx = #targetList end
                                focusPath = {}
                                for _, step in ipairs(delPath) do
                                    focusPath[#focusPath + 1] = step
                                end
                                focusPath[#focusPath + 1] = focusIdx
                            elseif #delPath > 0 then
                                focusPath = {}
                                for _, step in ipairs(delPath) do
                                    focusPath[#focusPath + 1] = step
                                end
                            end
                        end

                        if focusPath then
                            if editframe.gseRestrictMacroBlockAutoSelect then
                                editframe.gseRestrictMacroBlockAutoSelect(focusPath, 0.45)
                            end
                            editframe.pendingMacroBlockSelectPath = focusPath
                            editframe.pendingMacroBlockSelectVersion = version
                        end

                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)

                        if focusPath then
                            if editframe.gseSelectMacroBlockPath then
                                editframe.gseSelectMacroBlockPath(focusPath, nil, true)
                            end
                            editframe.pendingMacroBlockSelectPath = nil
                            editframe.pendingMacroBlockSelectVersion = nil

                            local function refocusDeletedNeighbour()
                                if editframe.gseSelectMacroBlockPath then
                                    editframe.gseSelectMacroBlockPath(focusPath, nil, true)
                                end
                                if editframe.gseFocusSelectedMacroBlock then
                                    editframe.gseFocusSelectedMacroBlock()
                                end
                            end

                            -- Layout settles asynchronously after the rebuild, so
                            -- re-assert selection + scroll across a few frames.
                            C_Timer.After(0.01, refocusDeletedNeighbour)
                            C_Timer.After(0.06, refocusDeletedNeighbour)
                            C_Timer.After(0.18, refocusDeletedNeighbour)
                            C_Timer.After(0.45, function()
                                if editframe.gseClearMacroBlockAutoSelect then
                                    editframe.gseClearMacroBlockAutoSelect(focusPath)
                                end
                            end)
                        end
                    end
                )
                deleteBlockButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Delete Block"],
                            L[
                                "Delete this Block from the sequence.  \nWARNING: If this is a loop this will delete all the blocks inside the loop as well."
                            ],
                            editframe
                        )
                    end
                )
                deleteBlockButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            local addLoopButton, addActionButton, addPauseButton, addIfButton, addEmbedButton
            if includeAdd then
                addLoopButton = UI:Create("Icon")
                addActionButton = UI:Create("Icon")
                addPauseButton = UI:Create("Icon")
                addIfButton = UI:Create("Icon")
                addEmbedButton = UI:Create("Icon")
                addActionButton:SetImageSize(30, 30)
                addActionButton:SetWidth(30)
                addActionButton:SetHeight(30)
                addActionButton:SetImage(Statics.ActionsIcons.Action)
                if addActionButton.SetElvUISubduedIcon then addActionButton:SetElvUISubduedIcon(true) end

                addActionButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["macro"] = "Need Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                        InsertToolbarAction(newAction)
                    end
                )
                addActionButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
                    end
                )
                addActionButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addLoopButton:SetImageSize(30, 30)
                addLoopButton:SetWidth(30)
                addLoopButton:SetHeight(30)
                addLoopButton:SetImage(Statics.ActionsIcons.Loop)
                if addLoopButton.SetElvUISubduedIcon then addLoopButton:SetElvUISubduedIcon(true) end

                addLoopButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            [1] = {
                                ["macro"] = "Need Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            },
                            ["StepFunction"] = Statics.Sequential,
                            ["Type"] = Statics.Actions.Loop,
                            ["Repeat"] = 2
                        }

                        -- setmetatable(newAction, Statics.TableMetadataFunction)
                        InsertToolbarAction(newAction)
                    end
                )
                addLoopButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
                    end
                )
                addLoopButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addPauseButton:SetImageSize(30, 30)
                addPauseButton:SetWidth(30)
                addPauseButton:SetHeight(30)
                addPauseButton:SetImage(Statics.ActionsIcons.Pause)
                if addPauseButton.SetElvUISubduedIcon then addPauseButton:SetElvUISubduedIcon(true) end

                addPauseButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["Variable"] = "GCD",
                            ["Type"] = Statics.Actions.Pause
                        }
                        InsertToolbarAction(newAction)
                    end
                )
                addPauseButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
                    end
                )
                addPauseButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addIfButton:SetImageSize(30, 30)
                addIfButton:SetWidth(30)
                addIfButton:SetHeight(30)
                addIfButton:SetImage(Statics.ActionsIcons.If)
                if addIfButton.SetElvUISubduedIcon then addIfButton:SetElvUISubduedIcon(true) end

                addIfButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            [1] = {
                                {
                                    ["macro"] = "Need True Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                }
                            },
                            [2] = {
                                {
                                    ["macro"] = "Need False Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                }
                            },
                            ["Type"] = Statics.Actions.If
                        }
                        InsertToolbarAction(newAction)
                    end
                )
                addIfButton:SetCallback(
                    "OnEnter",
                    function()
                        if GSE.TableLength(editframe.booleanFunctions) > 0 then
                            GSE.CreateToolTip(
                                L["Add If"],
                                L[
                                    "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                                ],
                                editframe
                            )
                        else
                            GSE.CreateToolTip(
                                L["Add If"],
                                L[
                                    "If Blocks require a variable that returns either true or false.  Create the variable first."
                                ],
                                editframe
                            )
                        end
                    end
                )
                addIfButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                addEmbedButton:SetImageSize(30, 30)
                addEmbedButton:SetWidth(30)
                addEmbedButton:SetHeight(30)
                addEmbedButton:SetImage(Statics.ActionsIcons.Embed)
                if addEmbedButton.SetElvUISubduedIcon then addEmbedButton:SetElvUISubduedIcon(true) end

                addEmbedButton:SetCallback(
                    "OnClick",
                    function()
                        local newAction = {
                            ["Type"] = Statics.Actions.Embed
                        }
                        InsertToolbarAction(newAction)
                    end
                )
                addEmbedButton:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Add Embed"],
                            L[
                                "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                            ],
                            editframe
                        )
                    end
                )
                addEmbedButton:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            local function CreateAddButton(icon, onClick, onEnter)
                local button = UI:Create("Icon")
                button:SetImageSize(30, 30)
                button:SetWidth(30)
                button:SetHeight(30)
                button:SetImage(icon)
                button:SetCallback("OnClick", onClick)
                button:SetCallback("OnEnter", onEnter)
                button:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                return button
            end

            local function CreateAddButtonRow(leftPadding, topPadding, bottomPadding, buttonSet, insertAction)
                topPadding = topPadding or 0
                bottomPadding = bottomPadding or 4
                insertAction = insertAction or InsertToolbarAction
                local addButtonRow = UI:Create("SimpleGroup")
                addButtonRow:SetLayout("Flow")
                addButtonRow:SetFullWidth(true)
                addButtonRow:SetHeight(30 + topPadding + bottomPadding)
                if addButtonRow.SetFlowGap then addButtonRow:SetFlowGap(4) end
                if addButtonRow.SetFlowVAlign then addButtonRow:SetFlowVAlign("CENTER") end
                if addButtonRow.SetFlowPadding then
                    addButtonRow:SetFlowPadding(leftPadding or 4, topPadding, 4, bottomPadding)
                end

                local function showButton(name)
                    return GSE.isEmpty(buttonSet) or buttonSet[name]
                end

                if showButton("Action") then
                    addButtonRow:AddChild(
                    CreateAddButton(
                        Statics.ActionsIcons.Action,
                        function()
                            local newAction = {
                                ["macro"] = "Need Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            }
                            insertAction(newAction)
                        end,
                        function()
                            GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
                        end
                    )
                    )
                end

                if showButton("Loop") then
                    addButtonRow:AddChild(
                    CreateAddButton(
                        Statics.ActionsIcons.Loop,
                        function()
                            local newAction = {
                                [1] = {
                                    ["macro"] = "Need Stuff Here",
                                    ["type"] = "macro",
                                    ["Type"] = Statics.Actions.Action
                                },
                                ["StepFunction"] = Statics.Sequential,
                                ["Type"] = Statics.Actions.Loop,
                                ["Repeat"] = 2
                            }
                            insertAction(newAction)
                        end,
                        function()
                            GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
                        end
                    )
                    )
                end

                if showButton("Pause") then
                    addButtonRow:AddChild(
                    CreateAddButton(
                        Statics.ActionsIcons.Pause,
                        function()
                            local newAction = {
                                ["Variable"] = "GCD",
                                ["Type"] = Statics.Actions.Pause
                            }
                            insertAction(newAction)
                        end,
                        function()
                            GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
                        end
                    )
                    )
                end

                if showButton("If") then
                    addButtonRow:AddChild(
                    CreateAddButton(
                        Statics.ActionsIcons.If,
                        function()
                            local newAction = {
                                [1] = {
                                    {
                                        ["macro"] = "Need True Stuff Here",
                                        ["type"] = "macro",
                                        ["Type"] = Statics.Actions.Action
                                    }
                                },
                                [2] = {
                                    {
                                        ["macro"] = "Need False Stuff Here",
                                        ["type"] = "macro",
                                        ["Type"] = Statics.Actions.Action
                                    }
                                },
                                ["Type"] = Statics.Actions.If
                            }
                            insertAction(newAction)
                        end,
                        function()
                            if GSE.TableLength(editframe.booleanFunctions) > 0 then
                                GSE.CreateToolTip(
                                    L["Add If"],
                                    L[
                                        "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                                    ],
                                    editframe
                                )
                            else
                                GSE.CreateToolTip(
                                    L["Add If"],
                                    L[
                                        "If Blocks require a variable that returns either true or false.  Create the variable first."
                                    ],
                                    editframe
                                )
                            end
                        end
                    )
                    )
                end

                if showButton("Embed") then
                    addButtonRow:AddChild(
                    CreateAddButton(
                        Statics.ActionsIcons.Embed,
                        function()
                            local newAction = {
                                ["Type"] = Statics.Actions.Embed
                            }
                            insertAction(newAction)
                        end,
                        function()
                            GSE.CreateToolTip(
                                L["Add Embed"],
                                L[
                                    "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                                ],
                                editframe
                            )
                        end
                    )
                    )
                end

                return addButtonRow
            end

            local function CreateChildAddButtonRow(leftPadding, topPadding, bottomPadding, buttonSet)
                return CreateAddButtonRow(leftPadding, topPadding, bottomPadding, buttonSet, InsertChildAction)
            end

            -- Show the current block number as read-only text. Reordering now
            -- happens through drag/drop, and the redraw updates this value.
            local textpath = GSE.SafeConcat(path, ".")
            local blockNumber
            if GSE.isEmpty(disableMove) then
                blockNumber = UI:Create("Label")
                blockNumber:SetWidth(40)
                blockNumber:SetText(textpath)
                blockNumber:SetHeight(30)
				blockNumber:SetFontObject(GameFontHighlight)
                blockNumber:SetJustifyH("LEFT")
                blockNumber:SetJustifyV("MIDDLE")
            end

            -- Build disableBlock widget up front so it can be inserted near the end
            local disableBlock, highlightTexture
            if GSE.isEmpty(disableMove) then
                disableBlock = UI:Create("CheckBox")
                disableBlock:SetType("checkbox")
                disableBlock:SetWidth(80)
                disableBlock:SetTriState(false)
                disableBlock:SetLabel("Disable")
                BumpCheckBoxTextUp(disableBlock)
                disableBlock:SetValue(editframe.Sequence.Versions[version].Actions[path].Disabled)
                -- ARTWORK (not BACKGROUND) so the disabled-block red shows above
                -- EllesmereUI's opaque flat inset backdrop (drawn at BACKGROUND),
                -- while still sitting below the block's content child-frame.
                highlightTexture = container.frame:CreateTexture(nil, "ARTWORK")
                highlightTexture:SetAllPoints(true)

                disableBlock:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        SelectMacroBlockPath(path)
                        editframe.Sequence.Versions[version].Actions[path].Disabled = value
                        if value == true then
                            highlightTexture:SetColorTexture(0.95, 0.00, 0.00, 0.68)
                        else
                            highlightTexture:SetColorTexture(1, 0, 0, 0)
                        end
                        -- Refresh focus tint for this block's overlay so a
                        -- disable-toggle on the currently-focused block hides
                        -- the type-colored tint immediately (letting the red
                        -- highlight read clean) — and unhides it again on
                        -- re-enable without waiting for a re-focus.
                        local overlays = editframe.macroBlockSelectionOverlays
                        local overlay = overlays and overlays[GSE.SafeConcat(path, ".")]
                        if overlay and overlay.gseRefreshTint then overlay.gseRefreshTint() end
                    end
                )
                if editframe.Sequence.Versions[version].Actions[path].Disabled == true then
                    highlightTexture:SetColorTexture(0.95, 0.00, 0.00, 0.68)
                else
                    highlightTexture:SetColorTexture(1, 0, 0, 0)
                end

                container:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        highlightTexture:SetColorTexture(0, 0, 0, 0)
                    end
                )
                disableBlock:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            "Disable",
                            L[
                                "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
                            ],
                            editframe
                        )
                    end
                )
                disableBlock:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
            end

            -- 1. Drag handle
            if GSE.isEmpty(disableMove) then
                layoutcontainer:AddChild(dragHandle)
            end

            -- 2. Block number
            if GSE.isEmpty(disableMove) then
                layoutcontainer:AddChild(blockNumber)
                local spacerlabelPath = UI:Create("Label")
                spacerlabelPath:SetWidth(2)
                layoutcontainer:AddChild(spacerlabelPath)
            end

            -- 3. Icon + heading
            layoutcontainer:AddChild(headingLabel)

            -- 4. Toolbar add buttons
            if includeAdd then
                layoutcontainer:AddChild(addActionButton)
                layoutcontainer:AddChild(addLoopButton)
                layoutcontainer:AddChild(addPauseButton)
                layoutcontainer:AddChild(addIfButton)
                layoutcontainer:AddChild(addEmbedButton)
            end

            -- Returns a finalize function: callers must call it after injecting any
            -- block-specific widgets. Disable/Delete are right anchored on
            -- the same header row as the block title.
            local function finalizeToolbar()
                local rightControlsWidth = 0
                local rightControls = UI:Create("SimpleGroup")
                rightControls:SetLayout("Flow")
                rightControls:SetHeight(32)
                if rightControls.SetFlowGap then rightControls:SetFlowGap(5) end
                if rightControls.SetFlowVAlign then rightControls:SetFlowVAlign("CENTER") end
                if rightControls.SetFlowRightAlign then rightControls:SetFlowRightAlign(true) end
                if rightControls.SetFlowPadding then rightControls:SetFlowPadding(0, 0, 0, 0) end

                if GSE.isEmpty(disableMove) and disableBlock then
                    rightControls:AddChild(disableBlock)
                    rightControlsWidth = rightControlsWidth + 80
                end

                if not disableDelete and deleteBlockButton then
                    if rightControlsWidth > 0 then rightControlsWidth = rightControlsWidth + 5 end
                    rightControls:AddChild(deleteBlockButton)
                    rightControlsWidth = rightControlsWidth + 30
                end

                if rightControlsWidth > 0 then
                    rightControls:SetWidth(rightControlsWidth + 12)
                    if rightControls.SetFlowOffset then rightControls:SetFlowOffset(#path > 1 and -24 or 10, 0) end
                    layoutcontainer:AddChild(rightControls)
                end
            end

            return layoutcontainer, finalizeToolbar, CreateAddButtonRow, CreateChildAddButtonRow
        end
        local function drawAction(pcontainer, action, version, keyPath, treepath)
            local function drawChild(childContainer, childAction, childKeyPath, childTreepath)
                local q = editframe.incBuildQueue
                if q then
                    q[#q + 1] = function()
                        drawAction(childContainer, childAction, version, childKeyPath, childTreepath)
                    end
                else
                    drawAction(childContainer, childAction, version, childKeyPath, childTreepath)
                end
            end
            local function DrawNestedChildActions(parentContainer, parentAction, parentKeyPath)
                if type(parentAction) ~= "table" or #parentAction == 0 then return end

                local childGroup = UI:Create("SimpleGroup")
                childGroup:SetFullWidth(true)
                childGroup:SetLayout("List")
                parentContainer:AddChild(childGroup)
                for key, childAction in ipairs(parentAction) do
                    if type(childAction) == "table" and childAction.Type then
                        local newKeyPath = GSE.CloneSequence(parentKeyPath)
                        table.insert(newKeyPath, key)
                        drawChild(childGroup, childAction, newKeyPath, treepath)
                    end
                end
            end

            local hlabelIcon = UI:Create("Icon")
            hlabelIcon:SetImage(Statics.ActionsIcons[action.Type] or Statics.ActionsIcons.Action)
            hlabelIcon:SetImageSize(15, 15)
            hlabelIcon:SetWidth(15)
            hlabelIcon:SetHeight(20)
            hlabelIcon.image:SetTexCoord(0.16, 0.84, 0.16, 0.84)
            hlabelIcon.image:SetDesaturated(true)
            hlabelIcon.image:ClearAllPoints()
            hlabelIcon.image:SetPoint("CENTER", hlabelIcon.frame, "CENTER", 0, 0)
            hlabelIcon.frame:EnableMouse(false)
            hlabelIcon:SetCallback("OnRelease", function(self)
                self.image:SetDesaturated(false)
                self.image:ClearAllPoints()
                self.image:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
            end)

            local hlabelText = UI:Create("Label")
            hlabelText:SetText(action.Type == Statics.Actions.Repeat and Statics.Actions.Action or Statics.Actions[action.Type])
            hlabelText:SetFontObject(GameFontNormalLarge)
            hlabelText:SetColor(GetActionTypeColor(action.Type))
            hlabelText:SetWidth(60)
            hlabelText:SetHeight(20)
            hlabelText:SetJustifyV("MIDDLE")

            local repeatIndicator
            if action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then
                repeatIndicator = UI:Create("Label")
                repeatIndicator:SetWidth(28)
                repeatIndicator:SetHeight(30)
                repeatIndicator:SetFontObject(GameFontNormalSmall)
                repeatIndicator:SetColor(GetActionTypeColor(action.Type))
                repeatIndicator:SetJustifyH("LEFT")
                repeatIndicator:SetJustifyV("MIDDLE")
            end

            local hlabel = UI:Create("SimpleGroup")
            hlabel:SetLayout("Flow")
            if hlabel.SetFlowGap then hlabel:SetFlowGap(2) end
            if hlabel.SetFlowVAlign then hlabel:SetFlowVAlign("CENTER") end
            hlabel:SetWidth(repeatIndicator and 120 or 90)
            hlabel:SetHeight(30)
            hlabel:AddChild(hlabelIcon)
            hlabel:AddChild(hlabelText)
            if repeatIndicator then hlabel:AddChild(repeatIndicator) end
            local includeAdd = false

            local function UpdateRepeatIndicator()
                if not repeatIndicator then return end
                if action.Type == Statics.Actions.Repeat then
                    repeatIndicator:SetText("x" .. tostring(action.Interval or 3))
                else
                    repeatIndicator:SetText("")
                end
                if hlabel.DoLayout then hlabel:DoLayout() end
            end
            UpdateRepeatIndicator()

            if action.Type == Statics.Actions.Pause then
                local block = UI:Create("InlineGroup")
                StyleEditorFrame(block, MacroBlockFrameDepth(keyPath), true, action.Type)
                RegisterMacroBlockDragTarget(block.frame, keyPath)
                RegisterMacroBlockSelection(block, keyPath, action.Type)

                block:SetLayout("List")
                block:SetFullWidth(true)
                block:SetAutoAdjustHeight(true)
                if block.SetListPadding then block:SetListPadding(0, 0, 0, 6) end
                local linegroup1 = UI:Create("SimpleGroup")

                linegroup1:SetLayout("Flow")
                linegroup1:SetFullWidth(true)

                local pauseFields = UI:Create("SimpleGroup")
                pauseFields:SetLayout("Flow")
                pauseFields:SetFullWidth(true)
                pauseFields:SetHeight(48)
                if pauseFields.SetFlowGap then pauseFields:SetFlowGap(8) end
                if pauseFields.SetFlowPadding then pauseFields:SetFlowPadding(92, 0, 0, 0) end

                local clicksdropdown = UI:Create("Dropdown")
                clicksdropdown:SetLabel(L["Measure"])
                clicksdropdown:SetWidth(270)
                local clickdroplist = {
                    [L["Clicks"]] = L["How many macro Clicks to pause for?"],
                    [L["Milliseconds"]] = L["How many milliseconds to pause for?"],
                    ["GCD"] = L["Pause for the GCD."]
                }
                for k, _ in pairs(editframe.numericFunctions) do
                    clickdroplist[k] = L["Local Function: "] .. k
                end
                clicksdropdown:SetList(clickdroplist)
                clicksdropdown:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Pause"],
                            L[
                                "A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.\nIf using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box."
                            ],
                            editframe
                        )
                    end
                )
                if not GSE.isEmpty(action.Variable) then
                    if action.Variable == "GCD" then
                        clicksdropdown:SetValue(action.Variable)
                    elseif not GSE.isEmpty(editframe.numericFunctions[action.Variable]) then
                        clicksdropdown:SetValue(action.Variable)
                    else
                        action.Variable = nil
                    end
                elseif GSE.isEmpty(action.MS) then
                    clicksdropdown:SetValue(L["Clicks"])
                else
                    clicksdropdown:SetValue(L["Milliseconds"])
                    if action.MS == "~~GCD~~" or action.MS == "GCD" then
                        clicksdropdown:SetValue("GCD")
                        action.Variable = "GCD"
                        action.MS = nil
                    end
                end
                clicksdropdown:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                pauseFields:AddChild(clicksdropdown)

                local msvalueeditbox = UI:Create("EditBox")
                msvalueeditbox:SetLabel()

                msvalueeditbox:SetWidth(60)
                msvalueeditbox:SetHeight(26)
                msvalueeditbox.editbox:SetNumeric(true)
                msvalueeditbox:DisableButton(true)
                local value = GSE.isEmpty(action.MS) and action.Clicks or action.MS
                if not GSE.isEmpty(action.Clicks) or GSE.isEmpty(action.MS) then
                    msvalueeditbox:SetDisabled(false)
                else
                    msvalueeditbox:SetDisabled(true)
                end
                msvalueeditbox:SetText(value)
                msvalueeditbox:SetCallback(
                    "OnTextChanged",
                    function(self, event, text)
                        local pauseAction = editframe.Sequence.Versions[version].Actions[keyPath]
                        if clicksdropdown:GetValue() == L["Milliseconds"] then
                            pauseAction.MS = tonumber(text) or 0
                            pauseAction.Clicks = nil
                            pauseAction.Variable = nil
                        elseif clicksdropdown:GetValue() == L["Clicks"] then
                            pauseAction.Clicks = tonumber(text) or 0
                            pauseAction.MS = nil
                            pauseAction.Variable = nil
                        end
                        -- GCD / numeric-function measures ignore the (disabled) value box.
                        editframe:SetStatusText(editframe.statusText)
                    end
                )

                msvalueeditbox:SetCallback(
                    "OnRelease",
                    function(self, event, text)
                        msvalueeditbox.editbox:SetNumeric(false)
                    end
                )
                clicksdropdown:SetCallback(
                    "OnValueChanged",
                    function(self, event, text)
                        local pauseAction = editframe.Sequence.Versions[version].Actions[keyPath]
                        if text == L["Clicks"] then
                            pauseAction.Clicks = tonumber(msvalueeditbox:GetText()) or 0
                            pauseAction.MS = nil
                            pauseAction.Variable = nil
                            msvalueeditbox:SetDisabled(false)
                        elseif text == L["Milliseconds"] then
                            pauseAction.MS = tonumber(msvalueeditbox:GetText()) or 0
                            pauseAction.Clicks = nil
                            pauseAction.Variable = nil
                            msvalueeditbox:SetDisabled(false)
                        else
                            pauseAction.Variable = text
                            pauseAction.Clicks = nil
                            pauseAction.MS = nil
                            msvalueeditbox:SetDisabled(true)
                        end
                        editframe:SetStatusText(editframe.statusText)
                    end
                )
                if clicksdropdown:GetValue() == L["Milliseconds"] or clicksdropdown:GetValue() == L["Clicks"] then
                    msvalueeditbox:SetDisabled(false)
                else
                    msvalueeditbox:SetDisabled(true)
                end
                pauseFields:AddChild(msvalueeditbox)
                linegroup1:AddChild(pauseFields)

                local toolbarGroup, finalizeToolbar, createAddButtonRow, createChildAddButtonRow =
                    GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, linegroup1)
                finalizeToolbar()
                block:AddChild(toolbarGroup)
                block:AddChild(linegroup1)
                DrawNestedChildActions(block, action, keyPath)
                pcontainer:AddChild(block)
            elseif action.Type == Statics.Actions.Action or action.Type == Statics.Actions.Repeat then
                local macroPanel = UI:Create("InlineGroup")
                StyleEditorFrame(macroPanel, MacroBlockFrameDepth(keyPath), true, action.Type)
                RegisterMacroBlockDragTarget(macroPanel.frame, keyPath)
                RegisterMacroBlockSelection(macroPanel, keyPath, action.Type)
                if GSE.isEmpty(action.type) then
                    action.type = "macro"
                    action.macro = ""
                end
                macroPanel:SetLayout("List")
                macroPanel:SetFullWidth(true)
                macroPanel:SetAutoAdjustHeight(true)
                if macroPanel.SetListPadding then macroPanel:SetListPadding(0, 0, 0, 16) end
                if macroPanel.SetListGap then macroPanel:SetListGap(0) end

                local linegroup1, finalizeToolbar, createAddButtonRow, createChildAddButtonRow =
                    GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)
                finalizeToolbar()

                macroPanel:AddChild(linegroup1)

                local compiledMacro = UI:Create("Label")
                compiledMacro:SetFullHeight(true)

                local spellEditBox, macroeditbox =
                    GSE.CreateSpellEditBox(action, version, keyPath, editframe.Sequence, compiledMacro, editframe.frame)
                if spellEditBox.SetLabelBoxPadding then spellEditBox:SetLabelBoxPadding(2) end
                HookMacroBlockSelectionWidget(spellEditBox, keyPath)
                HookMacroBlockSelectionWidget(macroeditbox, keyPath)

                local unitEditBox = UI:Create("EditBox")
                unitEditBox:SetLabel(L["Unit Name"])
                if unitEditBox.SetLabelBoxPadding then unitEditBox:SetLabelBoxPadding(2) end
                HookMacroBlockSelectionWidget(unitEditBox, keyPath)

                unitEditBox:SetWidth(ACTION_SPELL_UNIT_FIELD_WIDTH)
                unitEditBox:DisableButton(true)
                unitEditBox:SetText(action.unit)
                --local compiledAction = GSE.CompileAction(action, editframe.Sequence.Versions[version])
                unitEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        SelectMacroBlockPath(keyPath)
                        editframe.Sequence.Versions[version].Actions[keyPath].unit = value
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Versions[version])
                    end
                )
                unitEditBox:SetCallback(
                    "OnEditFocusLost",
                    function()
                    end
                )
                local function MatchMacroLabelBoxGap(editbox)
                    if not (editbox and editbox.editbox and editbox.frame) then return end
                    editbox.editbox:ClearAllPoints()
                    editbox.editbox:SetPoint("TOPLEFT", editbox.frame, "TOPLEFT", 4, -16)
                    editbox.editbox:SetPoint("RIGHT", editbox.frame, "RIGHT", -4, 0)
                end
                if action.type ~= "macro" then
                    MatchMacroLabelBoxGap(spellEditBox)
                    MatchMacroLabelBoxGap(unitEditBox)
                end
                local typegroup = UI:Create("SimpleGroup")
                typegroup:SetFullWidth(true)
                typegroup:SetLayout("Flow")
    if typegroup.SetFlowVAlign then typegroup:SetFlowVAlign("CENTER") end
                typegroup:SetHeight(28)
                if typegroup.SetFlowOffset then typegroup:SetFlowOffset(0, 4) end
                if typegroup.SetFlowPadding then typegroup:SetFlowPadding(4, 0, 4, 0) end
		local actionicon = GSE.CreateIconControl(action, version, keyPath, editframe.Sequence, macroPanel.frame)
                -- Refresh the icon when the user finishes editing the spell/item/toy field.
                spellEditBox:SetCallback("OnEditFocusLost", function()
                    actionicon:RefreshIcon()
                end)
                local spellradio = UI:Create("CheckBox")
                spellradio:SetType("radio")
                spellradio:SetLabel(L["Spell"])
                BumpCheckBoxTextUp(spellradio)
                spellradio:SetValue((action.type and action.type == "spell" or false))
                spellradio:SetWidth(70)
                local itemradio = UI:Create("CheckBox")
                itemradio:SetType("radio")
                itemradio:SetLabel(L["Item"])
                BumpCheckBoxTextUp(itemradio)
                itemradio:SetValue((action.type and action.type == "item" or false))
                itemradio:SetWidth(70)
                local macroradio = UI:Create("CheckBox")
                macroradio:SetType("radio")
                macroradio:SetLabel(L["Macro"])
                BumpCheckBoxTextUp(macroradio)
                macroradio:SetValue((action.type and action.type == "macro" or false))
                macroradio:SetWidth(70)
                local petradio = UI:Create("CheckBox")
                petradio:SetType("radio")
                petradio:SetLabel(L["Pet"])
                BumpCheckBoxTextUp(petradio)
                petradio:SetValue((action.type and action.type == "pet" or false))
                petradio:SetWidth(70)
                local toyradio = UI:Create("CheckBox")
                toyradio:SetType("radio")
                toyradio:SetLabel(L["Toy"])
                BumpCheckBoxTextUp(toyradio)
                toyradio:SetValue((action.type and action.type == "toy" or false))
                toyradio:SetWidth(70)
                typegroup:AddChild(macroradio)
                typegroup:AddChild(spellradio)
                typegroup:AddChild(itemradio)
                typegroup:AddChild(petradio)
                typegroup:AddChild(toyradio)

                local spellcontainer = UI:Create("SimpleGroup")
                spellcontainer:SetLayout("List")
                spellcontainer:SetFullWidth(true)
                if spellcontainer.SetListPadding then spellcontainer:SetListPadding(0, 0, 0, 0) end
		if spellcontainer.SetListGap then spellcontainer:SetListGap(6) end

                -- Callback factory for action-type radio buttons.
                -- Each entry: which radio widget, which action.type string, which action
                -- field receives the text value, and which edit box to read it from.
                -- macroradio also clears action.unit (original behaviour preserved).
                local radioConfigs = {
                    { radio = spellradio, type = "spell", actionField = "spell",  sourceBox = spellEditBox  },
                    { radio = itemradio,  type = "item",  actionField = "item",   sourceBox = spellEditBox  },
                    { radio = petradio,   type = "pet",   actionField = "action", sourceBox = spellEditBox  },
                    { radio = toyradio,   type = "toy",   actionField = "toy",    sourceBox = spellEditBox  },
                    { radio = macroradio, type = "macro", actionField = "macro",  sourceBox = macroeditbox, clearUnit = true },
                }
                local actionTypeFields = {"spell", "macro", "item", "toy", "action"}

                local function makeRadioCallback(cfg)
                    return function(sel, object, value)
                        SelectMacroBlockPath(keyPath)
                        if value ~= true then return end
                        for _, other in ipairs(radioConfigs) do
                            if other.radio ~= cfg.radio then
                                other.radio:SetValue(false)
                            end
                        end
                        for _, field in ipairs(actionTypeFields) do
                            action[field] = nil
                        end
                        if cfg.clearUnit then action.unit = nil end
                        local currentType = action.type or editframe.Sequence.Versions[version].Actions[keyPath].type
                        local activeSourceBox = currentType == "macro" and macroeditbox or spellEditBox
                        local sourceText = activeSourceBox and activeSourceBox.GetText and activeSourceBox:GetText() or ""
                        if currentType == "macro" then
                            sourceText = DecodeMacroEditorText(sourceText)
                        else
                            sourceText = DecodeEditorText(sourceText)
                        end
                        if cfg.type == "macro" then
                            sourceText = StoreMacroEditorText(sourceText)
                        else
                            sourceText = DecodeEditorText(sourceText)
                        end
                        action[cfg.actionField] = sourceText
                        action.type = cfg.type
                        if not action.IconUserSelected then action.Icon = nil end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                end

                for _, cfg in ipairs(radioConfigs) do
                    HookMacroBlockSelectionWidget(cfg.radio, keyPath)
                    cfg.radio:SetCallback("OnValueChanged", makeRadioCallback(cfg))
                end

		-- Macro insertion toolbar is not ready for release/merge yet: it's kept in
		-- the code (and still exercised via the MenuTester) but not shown in the
		-- editor. Flip this to true to re-enable the row above the macro edit box.
		local SHOW_MACRO_INSERT_TOOLBAR = false
		-- 244 reserves room for the toolbar (76px row + a 6px list gap); 162 without.
		local macroBodyHeight = SHOW_MACRO_INSERT_TOOLBAR and 244 or 162
		local macroRailWidth = 86
		if action.type == "macro" then
			local macroBody = UI:Create("SimpleGroup")
			macroBody:SetLayout("Flow")
			macroBody:SetFullWidth(true)
			macroBody:SetHeight(macroBodyHeight)
			if macroBody.SetFlowGap then macroBody:SetFlowGap(0) end
			if macroBody.SetFlowPadding then macroBody:SetFlowPadding(4, 0, 4, 0) end

			local macroRail = UI:Create("SimpleGroup")
			macroRail:SetLayout("List")
			macroRail:SetWidth(macroRailWidth)
			macroRail:SetHeight(macroBodyHeight)
			if macroRail.SetListPadding then macroRail:SetListPadding(0, 0, 0, 0) end
			if macroRail.SetListGap then macroRail:SetListGap(6) end

			local typeLabel = UI:Create("Label")
			typeLabel:SetText("Type")
			typeLabel:SetWidth(macroRailWidth)
			typeLabel:SetHeight(28)
			typeLabel:SetColor(keywordColor())
			if typeLabel.SetJustifyH then typeLabel:SetJustifyH("LEFT") end
			if typeLabel.SetJustifyV then typeLabel:SetJustifyV("MIDDLE") end
			if typeLabel.SetFlowOffset then typeLabel:SetFlowOffset(0, 4) end

			local macroTextLabel = UI:Create("Label")
			macroTextLabel:SetText("")
			macroTextLabel:SetWidth(macroRailWidth)
			macroTextLabel:SetHeight(18)
			macroTextLabel:SetColor(keywordColor())
			if macroTextLabel.SetJustifyH then macroTextLabel:SetJustifyH("LEFT") end
			if macroTextLabel.SetJustifyV then macroTextLabel:SetJustifyV("MIDDLE") end

			local macroIconSize = 36
			actionicon:SetImageSize(macroIconSize, macroIconSize)
			actionicon:SetWidth(macroIconSize)
			actionicon:SetHeight(macroIconSize)

			local iconSlotHeight = 48
			local iconSize = macroIconSize
			local iconSlot = UI:Create("SimpleGroup")
			iconSlot:SetLayout("Flow")
			iconSlot:SetWidth(macroRailWidth)
			iconSlot:SetHeight(iconSlotHeight)
			if iconSlot.SetFlowPadding then
				iconSlot:SetFlowPadding(
					math.floor((macroRailWidth - iconSize) / 2),
					math.floor((iconSlotHeight - iconSize) / 2),
					0,
					0
				)
			end

			macroRail:AddChild(typeLabel)
			macroRail:AddChild(macroTextLabel)
			iconSlot:AddChild(actionicon)
			macroRail:AddChild(iconSlot)

			local macroFields = UI:Create("SimpleGroup")
			macroFields:SetLayout("List")
			if macroFields.SetFlowFillRemaining then macroFields:SetFlowFillRemaining(true) end
			macroFields:SetHeight(macroBodyHeight)
			if macroFields.SetListPadding then macroFields:SetListPadding(0, 0, 0, 0) end
			if macroFields.SetListGap then macroFields:SetListGap(6) end

			local macrolayout = UI:Create("SimpleGroup")
			macrolayout:SetLayout("Flow")
			macrolayout:SetFullWidth(true)
			macrolayout:SetHeight(108)
			if macrolayout.SetFlowOffset then macrolayout:SetFlowOffset(0, 4) end
			if macrolayout.SetFlowPadding then macrolayout:SetFlowPadding(4, 0, 4, 0) end
			macroeditbox:SetLabel(L["Macro Name or Macro Commands"])

			-- Populate compiled-side-panel text regardless of
			-- visibility ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â it's a no-op SetText when the Label
                    -- isn't in the layout, but means we don't have to
                    -- re-derive it on Compiled Template open/close.
                    local compiledmacrotext =
                        GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                    local compiledLen = GetCompiledMacroBodyLength(action.macro)
                    local charcount
                    if compiledLen > 255 then
                        charcount = string.format(
                            GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                            compiledLen
                        )
                    else
                        charcount = string.format(L["%s/255 Characters Used"], compiledLen)
                    end
                    compiledMacro.label:SetNonSpaceWrap(true)
                    compiledMacro:SetText(compiledmacrotext .. "\n\n" .. charcount)

                    local previewOpen = editframe.PreviewFrame and editframe.PreviewFrame:IsShown()
                    if previewOpen then
                        local previewYOffset = (macroeditbox.labelHeight or 12) + (macroeditbox.verticalOffset or 4) - 2
                        local previewHeight =
                            math.max(
                                40,
                                (macroeditbox.height or 108) - (macroeditbox.labelHeight or 12) - (macroeditbox.verticalOffset or 4)
                            )
                        local compiledPreview = UI:Create("ScrollFrame")
                        compiledPreview:SetRelativeWidth(0.45)
                        compiledPreview:SetHeight(previewHeight)
                        if compiledPreview.SetFlowOffset then compiledPreview:SetFlowOffset(0, -previewYOffset) end
                        if compiledPreview.SetListPadding then compiledPreview:SetListPadding(0, 0, 0, 0) end
                        if compiledPreview.SetListGap then compiledPreview:SetListGap(0) end
                        compiledMacro:SetFullHeight(false)
                        compiledMacro:SetFullWidth(true)

                        macroeditbox:SetRelativeWidth(0.5)
                        if macrolayout.SetFlowGap then macrolayout:SetFlowGap(6) end
                        compiledPreview:AddChild(compiledMacro)
                        macrolayout:AddChild(macroeditbox)
                        macrolayout:AddChild(compiledPreview)
			else
				macroeditbox:SetFullWidth(true)
				macrolayout:AddChild(macroeditbox)
			end

			macroFields:AddChild(typegroup)
			-- Insertion toolbar: Spells / Commands / Conditionals / Common
			-- Hosted by GSE_QoL so its data tables stay in one place.  If
			-- QoL isn't loaded (lite installs) the call returns nil and the
			-- row is silently skipped so the editor still renders.
			-- Gated off (SHOW_MACRO_INSERT_TOOLBAR) until the feature is ready.
			local macroInsertRow = SHOW_MACRO_INSERT_TOOLBAR and GSE.CreateMacroInsertionButtonRow and
				GSE.CreateMacroInsertionButtonRow(macroeditbox, editframe.Sequence, version, keyPath)
			if macroInsertRow then macroFields:AddChild(macroInsertRow) end
			macroFields:AddChild(macrolayout)
			macroBody:AddChild(macroRail)
			macroBody:AddChild(macroFields)
			spellcontainer:AddChild(macroBody)
			-- Report the COMPILED macro body length (after spell-name translation)
			-- so the "X/255" indicator matches the over-limit trigger and what WoW
			-- actually enforces on the macro slot. Showing the raw typed length
			-- made the counter read e.g. 252/255 while the trigger fired at 256.
			SetMacroCountText(macroeditbox, GetCompiledMacroBodyLength(macroeditbox:GetText() or ""))
		else
			local actionBodyHeight = 92
			local actionBody = UI:Create("SimpleGroup")
			actionBody:SetLayout("Flow")
			actionBody:SetFullWidth(true)
			actionBody:SetHeight(actionBodyHeight)
			if actionBody.SetFlowGap then actionBody:SetFlowGap(0) end
			if actionBody.SetFlowPadding then actionBody:SetFlowPadding(4, 0, 4, 0) end

			local actionRail = UI:Create("SimpleGroup")
			actionRail:SetLayout("List")
			actionRail:SetWidth(macroRailWidth)
			actionRail:SetHeight(actionBodyHeight)
			if actionRail.SetListPadding then actionRail:SetListPadding(0, 0, 0, 0) end
			if actionRail.SetListGap then actionRail:SetListGap(0) end

			local typeLabel = UI:Create("Label")
			typeLabel:SetText("Type")
			typeLabel:SetWidth(macroRailWidth)
			typeLabel:SetHeight(28)
			typeLabel:SetColor(keywordColor())
			if typeLabel.SetJustifyH then typeLabel:SetJustifyH("LEFT") end
			if typeLabel.SetJustifyV then typeLabel:SetJustifyV("MIDDLE") end
			if typeLabel.SetFlowOffset then typeLabel:SetFlowOffset(0, 4) end

			local actionTextLabel = UI:Create("Label")
			actionTextLabel:SetText("")
			actionTextLabel:SetWidth(macroRailWidth)
			actionTextLabel:SetHeight(4)
			actionTextLabel:SetColor(keywordColor())
			if actionTextLabel.SetJustifyH then actionTextLabel:SetJustifyH("LEFT") end
			if actionTextLabel.SetJustifyV then actionTextLabel:SetJustifyV("MIDDLE") end

			local actionIconSize = 36
			actionicon:SetImageSize(actionIconSize, actionIconSize)
			actionicon:SetWidth(actionIconSize)
			actionicon:SetHeight(actionIconSize)

			local iconSlotHeight = 44
			local iconSlot = UI:Create("SimpleGroup")
			iconSlot:SetLayout("Flow")
			iconSlot:SetWidth(macroRailWidth)
			iconSlot:SetHeight(iconSlotHeight)
			if iconSlot.SetFlowPadding then
				iconSlot:SetFlowPadding(
					math.floor((macroRailWidth - actionIconSize) / 2),
					math.floor((iconSlotHeight - actionIconSize) / 2),
					0,
					0
				)
			end

			actionRail:AddChild(typeLabel)
			actionRail:AddChild(actionTextLabel)
			iconSlot:AddChild(actionicon)
			actionRail:AddChild(iconSlot)

			local actionFields = UI:Create("SimpleGroup")
			actionFields:SetLayout("List")
			if actionFields.SetFlowFillRemaining then actionFields:SetFlowFillRemaining(true) end
			actionFields:SetHeight(actionBodyHeight)
			if actionFields.SetListPadding then actionFields:SetListPadding(0, 0, 0, 0) end
			if actionFields.SetListGap then actionFields:SetListGap(6) end

			local editcontainer = UI:Create("SimpleGroup")
			editcontainer:SetLayout("Flow")
			editcontainer:SetFullWidth(true)
			if editcontainer.SetFlowOffset then editcontainer:SetFlowOffset(0, 4) end
			if editcontainer.SetFlowPadding then editcontainer:SetFlowPadding(4, 0, 4, 0) end
			editcontainer:AddChild(spellEditBox)
			editcontainer:AddChild(unitEditBox)

			actionFields:AddChild(typegroup)
			actionFields:AddChild(editcontainer)
			actionBody:AddChild(actionRail)
			actionBody:AddChild(actionFields)
			spellcontainer:AddChild(actionBody)
                end

                macroPanel:AddChild(spellcontainer)
                local typerow = UI:Create("SimpleGroup")
                typerow:SetLayout("Flow")
                if typerow.SetFlowVAlign then typerow:SetFlowVAlign("CENTER") end
                typerow:SetFullWidth(true)
                if typerow.SetFlowOffset then typerow:SetFlowOffset(0, 16) end
		local repeatRowLeftPadding = macroRailWidth + 6
		local repeatRowBottomPadding = #keyPath == 1 and 0 or 10
		if typerow.SetFlowPadding then typerow:SetFlowPadding(repeatRowLeftPadding, 0, 4, repeatRowBottomPadding) end
		local repeatControlYOffset = 0
		local actiontype = UI:Create("CheckBox")
		actiontype:SetType("checkbox")
		actiontype:SetLabel("Repeat Interval")
		BumpCheckBoxTextUp(actiontype)
		actiontype:SetValue(action.Type == Statics.Actions.Repeat and true or false)
		actiontype:SetWidth(120)
		if actiontype.SetFlowOffset then actiontype:SetFlowOffset(0, repeatControlYOffset) end

		local interval = UI:Create("EditBox")
		interval:SetWidth(30)
		interval:SetHeight(26)
		if interval.SetFlowOffset then interval:SetFlowOffset(0, repeatControlYOffset) end
                if interval.SetCompactNoLabel then interval:SetCompactNoLabel(true) end
                local function RepeatIntervalDisplayValue(value)
                    value = tostring(value or "")
                    if value == "" then return 3 end
                    return value
                end
                local function CenterRepeatIntervalText()
                    if interval.editbox and interval.editbox.SetJustifyH then interval.editbox:SetJustifyH("CENTER") end
                end
                local function RestoreUnusedRepeatIntervalDefault()
                    if action.Type ~= Statics.Actions.Repeat and interval:GetText() == "" then
                        interval:SetText(3)
                    end
                    CenterRepeatIntervalText()
                end
                interval:SetText(RepeatIntervalDisplayValue(action.Interval))
                interval:SetDisabled(action.Type == Statics.Actions.Action and true or false)
                interval:DisableButton(true)
                if interval.SetNumeric then interval:SetNumeric(true) else interval.editbox:SetNumeric(true) end
                CenterRepeatIntervalText()
                interval:SetCallback(
                    "OnRelease",
                    function(self, event, text)
                        interval.editbox:SetNumeric(false)
                    end
                )
                interval:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        SelectMacroBlockPath(keyPath)
                        if action.Type ~= Statics.Actions.Repeat and tostring(value or "") == "" then
                            value = 3
                        end
                        editframe.Sequence.Versions[version].Actions[keyPath].Interval = value
                        action.Interval = value
                        UpdateRepeatIndicator()
                        CenterRepeatIntervalText()
                        --compiledAction = GSE.CompileAction(returnAction, editframe.Sequence.Versions[version])
                    end
                )
                interval:SetCallback("OnEditFocusLost", RestoreUnusedRepeatIntervalDefault)
                actiontype:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        SelectMacroBlockPath(keyPath)
                        if value == true then
                            editframe.Sequence.Versions[version].Actions[keyPath].Type = Statics.Actions.Repeat
                            action.Type = Statics.Actions.Repeat
                            if interval:GetText() == "" then interval:SetText(3) end
                            interval:SetDisabled(false)
                        else
                            editframe.Sequence.Versions[version].Actions[keyPath].Type = Statics.Actions.Action
                            action.Type = Statics.Actions.Action
                            RestoreUnusedRepeatIntervalDefault()
                            interval:SetDisabled(true)
                        end
                        CenterRepeatIntervalText()
                        UpdateRepeatIndicator()
                        hlabelText:SetColor(GetActionTypeColor(action.Type))
                        if repeatIndicator then repeatIndicator:SetColor(GetActionTypeColor(action.Type)) end
                    end
                )
                typerow:AddChild(actiontype)
                typerow:AddChild(interval)
                macroPanel:AddChild(typerow)
                DrawNestedChildActions(macroPanel, action, keyPath)
                pcontainer:AddChild(macroPanel)
            elseif action.Type == Statics.Actions.Loop then
                local layout3 = UI:Create("InlineGroup")
                StyleEditorFrame(layout3, MacroBlockFrameDepth(keyPath), true, action.Type)
                RegisterMacroBlockDragTarget(layout3.frame, keyPath)
                RegisterMacroBlockSelection(layout3, keyPath, action.Type)
                layout3:SetFullWidth(true)
                layout3:SetLayout("List")
                layout3:SetAutoAdjustHeight(true)
                local linegroup1, finalizeToolbar, createAddButtonRow, createChildAddButtonRow =
                    GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, layout3)
                if linegroup1.SetFlowOffset then linegroup1:SetFlowOffset(7, 0) end

                local stepdropdown = UI:Create("Dropdown")
                stepdropdown:SetLabel("")
                stepdropdown:SetWidth(150)
                stepdropdown:SetHeight(24)
                if stepdropdown.SetDropdownStyle then stepdropdown:SetDropdownStyle(true) end
                stepdropdown:SetList(
                    {
                        [Statics.Sequential] = L["Sequential (1 2 3 4)"],
                        [Statics.Priority] = L["Priority List (1 12 123 1234)"],
                        [Statics.ReversePriority] = L["Reverse Priority (1 21 321 4321)"],
                        [Statics.Random] = L["Random - It will select .... a spell, any spell"]
                    }
                )
                if stepdropdown.SetButtonTextMap then
                    stepdropdown:SetButtonTextMap(
                        {
                            [Statics.Sequential] = "Sequential",
                            [Statics.Priority] = "Priority",
                            [Statics.ReversePriority] = "Reverse",
                            [Statics.Random] = "Random"
                        }
                    )
                end
                stepdropdown:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Step Function"],
                            L[
                                "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
                            ],
                            editframe
                        )
                    end
                )
                stepdropdown:SetValue(action.StepFunction)
                stepdropdown:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                stepdropdown:SetCallback(
                    "OnValueChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].StepFunction = value
                    end
                )

                local looplimit = UI:Create("EditBox")
                looplimit:SetLabel("")
                looplimit:DisableButton(true)
                looplimit:SetMaxLetters(4)
                looplimit:SetWidth(30)
                looplimit:SetHeight(26)
                if looplimit.SetFlowOffset then looplimit:SetFlowOffset(4, 0) end
                if looplimit.SetCompactNoLabel then looplimit:SetCompactNoLabel(true) end

                if type(action.Repeat) ~= "number" or action.Repeat < 1 then
                    action.Repeat = 1
                end
                looplimit:SetText(action.Repeat)
                looplimit:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(L["Repeat"], L["How many times does this action repeat"], editframe)
                    end
                )
                looplimit:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )
                looplimit:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        value = tonumber(value)
                        if type(value) == "number" and value > 0 then
                            editframe.Sequence.Versions[version].Actions[keyPath].Repeat = value
                        end
                    end
                )

                finalizeToolbar()

                layout3:AddChild(linegroup1)

                local loopControlLabelWidth = 82
                local stepRow = UI:Create("SimpleGroup")
                stepRow:SetLayout("Flow")
                stepRow:SetFullWidth(true)
                stepRow:SetHeight(24)
                if stepRow.SetFlowGap then stepRow:SetFlowGap(6) end
                if stepRow.SetFlowVAlign then stepRow:SetFlowVAlign("CENTER") end
                if stepRow.SetFlowOffset then stepRow:SetFlowOffset(7, 0) end
                local stepRowLabel = UI:Create("Label")
                stepRowLabel:SetText("Step FN")
                stepRowLabel:SetWidth(loopControlLabelWidth)
                stepRowLabel:SetHeight(24)
                stepRowLabel:SetColor(keywordColor())
                if stepRowLabel.SetJustifyV then stepRowLabel:SetJustifyV("MIDDLE") end
                stepRow:AddChild(stepRowLabel)
                stepRow:AddChild(stepdropdown)
                layout3:AddChild(stepRow)

                local repeatRow = UI:Create("SimpleGroup")
                repeatRow:SetLayout("Flow")
                repeatRow:SetFullWidth(true)
                repeatRow:SetHeight(26)
                if repeatRow.SetFlowGap then repeatRow:SetFlowGap(6) end
                if repeatRow.SetFlowVAlign then repeatRow:SetFlowVAlign("CENTER") end
                if repeatRow.SetFlowOffset then repeatRow:SetFlowOffset(7, 0) end
                local repeatRowLabel = UI:Create("Label")
                repeatRowLabel:SetText(L["Repeat"])
                repeatRowLabel:SetWidth(loopControlLabelWidth)
                repeatRowLabel:SetHeight(24)
                repeatRowLabel:SetColor(keywordColor())
                if repeatRowLabel.SetJustifyV then repeatRowLabel:SetJustifyV("MIDDLE") end
                repeatRow:AddChild(repeatRowLabel)
                repeatRow:AddChild(looplimit)
                layout3:AddChild(repeatRow)

                local macroGroup = UI:Create("SimpleGroup")
                macroGroup:SetFullWidth(true)
                macroGroup:SetLayout("List")
                for key, act in ipairs(action) do
                    local newKeyPath = {}
                    for _, v in ipairs(keyPath) do
                        table.insert(newKeyPath, v)
                    end
                    table.insert(newKeyPath, key)
                    drawChild(macroGroup, act, newKeyPath)
                end

                layout3:AddChild(macroGroup)
                pcontainer:AddChild(layout3)
            elseif action.Type == Statics.Actions.If then
                local macroPanel = UI:Create("InlineGroup")
                StyleEditorFrame(macroPanel, MacroBlockFrameDepth(keyPath), true, action.Type)
                RegisterMacroBlockDragTarget(macroPanel.frame, keyPath)
                RegisterMacroBlockSelection(macroPanel, keyPath, action.Type)
                macroPanel:SetFullWidth(true)
                macroPanel:SetLayout("List")
                macroPanel:SetAutoAdjustHeight(true)
                macroPanel:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        macroPanel.frame:SetBackdrop(nil)
                    end
                )
                local linegroup1, finalizeToolbar, createAddButtonRow =
                    GetBlockToolbar(version, keyPath, treepath, false, hlabel, macroPanel)
                if linegroup1.SetFlowOffset then linegroup1:SetFlowOffset(0, -2) end

                local variableLabel = UI:Create("Label")
                variableLabel:SetText(L["Variable"])
                variableLabel:SetWidth(62)
                variableLabel:SetHeight(26)
                variableLabel:SetFontObject(GameFontNormalSmall)
                variableLabel:SetColor(1, 0.82, 0, 1)
                if variableLabel.SetJustifyH then variableLabel:SetJustifyH("LEFT") end
                if variableLabel.SetJustifyV then variableLabel:SetJustifyV("MIDDLE") end

                local booleanEditBox = UI:Create("EditBox")
                booleanEditBox:SetWidth(250)
                booleanEditBox:SetHeight(26)
                if booleanEditBox.SetCompactNoLabel then booleanEditBox:SetCompactNoLabel(true) end
                booleanEditBox:DisableButton(true)
                booleanEditBox:SetCallback(
                    "OnEnter",
                    function()
                        GSE.CreateToolTip(
                            L["Variable"],
                            L["Enter the implementation link for this variable. Use '= true' or '= false' to test."],
                            editframe
                        )
                    end
                )
                if not GSE.isEmpty(action.Variable) then
                    booleanEditBox:SetText(action.Variable)
                else
                    booleanEditBox:SetText("= true")
                    action.Variable = "= true"
                end
                booleanEditBox:SetCallback(
                    "OnLeave",
                    function()
                        GSE.ClearTooltip(editframe)
                    end
                )

                booleanEditBox:SetCallback(
                    "OnTextChanged",
                    function(sel, object, value)
                        editframe.Sequence.Versions[version].Actions[keyPath].Variable = value
                        action.Variable = value
                    end
                )
                if GSE.Patron then
                    booleanEditBox.editbox:SetScript(
                        "OnTabPressed",
                        function(widget, button, down)
                            MenuUtil.CreateContextMenu(
                                editframe.frame,
                                function(ownerRegion, rootDescription)
                                    rootDescription:CreateTitle(L["Insert GSE Variable"])
                                    for k, _ in pairs(GSEVariables) do
                                        rootDescription:CreateButton(
                                            k,
                                            function()
                                                booleanEditBox:SetText([[=GSE.V["]] .. k .. [["]()]])
                                                editframe.Sequence.Versions[version].Actions[keyPath].Variable =
                                                    [[=GSE.V["]] .. k .. [["]()]]
                                                action.Variable = [[=GSE.V["]] .. k .. [["]()]]
                                            end
                                        )
                                    end
                                    rootDescription:CreateTitle(L["Insert Test Case"])
                                    rootDescription:CreateButton(
                                        "True",
                                        function()
                                            booleanEditBox:SetText([[= true]])
                                            editframe.Sequence.Versions[version].Actions[keyPath].Variable = [[= true]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                    rootDescription:CreateButton(
                                        "False",
                                        function()
                                            booleanEditBox:SetText([[= false]])
                                            editframe.Sequence.Versions[version].Actions[keyPath].Variable = [[= false]]
                                            action.Variable = [[= true]]
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
                linegroup1:AddChild(variableLabel)
                linegroup1:AddChild(booleanEditBox)
                finalizeToolbar()

                local trueKeyPath = GSE.CloneSequence(keyPath)
                table.insert(trueKeyPath, 1)
                local trueGroup = UI:Create("InlineGroup")
                StyleEditorFrame(trueGroup, MacroBlockFrameDepth(trueKeyPath), true, action.Type)
                trueGroup:SetFullWidth(true)
                trueGroup:SetLayout("List")
                trueGroup:SetAutoAdjustHeight(true)
                if trueGroup.SetListPadding then trueGroup:SetListPadding(0, 0, 0, 6) end

                local tlabel = UI:Create("Label")
                tlabel:SetText("True")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                tlabel:SetFontObject(GameFontNormalLarge)
                tlabel:SetColor(keywordColor())

                local trueContainer = UI:Create("SimpleGroup")
                trueContainer:SetLayout("Flow")
                trueContainer:SetFullWidth(true)
                if trueContainer.SetFlowPadding then trueContainer:SetFlowPadding(0, 4, 0, 4) end

                local toolbar, finalizeToolbar1, createTrueAddButtonRow =
                    GetBlockToolbar(version, trueKeyPath, treepath, false, tlabel, trueContainer, true, true, true)
                toolbar:SetHeight(22)
                finalizeToolbar1()
                trueGroup:AddChild(toolbar)

                for key, act in ipairs(action[1]) do
                    local newKeyPath = GSE.CloneSequence(trueKeyPath)
                    table.insert(newKeyPath, key)
                    drawChild(trueGroup, act, newKeyPath)
                end

                macroPanel:AddChild(linegroup1)

                trueContainer:AddChild(trueGroup)
                macroPanel:AddChild(trueContainer)

                -- macroPanel:AddChild(falseGroup)
                local falseKeyPath = GSE.CloneSequence(keyPath)
                table.insert(falseKeyPath, 2)
                local falsegroup = UI:Create("InlineGroup")
                StyleEditorFrame(falsegroup, MacroBlockFrameDepth(falseKeyPath), true, action.Type)
                falsegroup:SetFullWidth(true)
                falsegroup:SetLayout("List")
                falsegroup:SetAutoAdjustHeight(true)
                if falsegroup.SetListPadding then falsegroup:SetListPadding(0, 0, 0, 6) end

                local flabel = UI:Create("Label")
                flabel:SetText("False")
                --tlabel:SetFont(fontName, fontHeight + 4 , fontFlags)
                flabel:SetFontObject(GameFontNormalLarge)
                flabel:SetColor(keywordColor())
                local falsecontainer = UI:Create("SimpleGroup")
                falsecontainer:SetFullWidth(true)
                falsecontainer:SetLayout("Flow")
                if falsecontainer.SetFlowPadding then falsecontainer:SetFlowPadding(0, 4, 0, 4) end

                local toolbar2, finalizeToolbar2, createFalseAddButtonRow =
                    GetBlockToolbar(version, falseKeyPath, treepath, false, flabel, falsecontainer, true, true, true)
                toolbar2:SetHeight(22)
                finalizeToolbar2()
                falsegroup:AddChild(toolbar2)

                for key, act in ipairs(action[2]) do
                    local newKeyPath = GSE.CloneSequence(falseKeyPath)
                    table.insert(newKeyPath, key)
                    drawChild(falsegroup, act, newKeyPath)
                end

                falsecontainer:AddChild(falsegroup)
                macroPanel:AddChild(falsecontainer)
                pcontainer:AddChild(macroPanel)
            elseif action.Type == Statics.Actions.Embed then
                local macroPanel = UI:Create("InlineGroup")
                StyleEditorFrame(macroPanel, MacroBlockFrameDepth(keyPath), true, action.Type)
                RegisterMacroBlockDragTarget(macroPanel.frame, keyPath)
                RegisterMacroBlockSelection(macroPanel, keyPath, action.Type)
                macroPanel:SetFullWidth(true)
                macroPanel:SetLayout("List")
                macroPanel:SetAutoAdjustHeight(true)
                if macroPanel.SetListPadding then macroPanel:SetListPadding(0, 0, 0, 6) end
                macroPanel:SetCallback(
                    "OnRelease",
                    function(self, obj, value)
                        macroPanel.frame:SetBackdrop(nil)
                    end
                )
                local linegroup1, finalizeToolbar, createAddButtonRow, createChildAddButtonRow =
                    GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)
                finalizeToolbar()
                macroPanel:AddChild(linegroup1)
                local SequenceDropDown = UI:Create("Dropdown")
                if SequenceDropDown.SetFlowFillRemaining then SequenceDropDown:SetFlowFillRemaining(true) end

                local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
                for k, v in GSE.pairsByKeys(GSE.GetSequenceNames() or {}, GSE.AlphabeticalTableSortAlgorithm) do
                    if v ~= editframe.Sequence.MetaData.Name then
                        local elements = GSE.split(tostring(k), ",") or {}
                        local classid, specid = tonumber(elements[1]), tonumber(elements[2])

                        if classid and cid ~= classid then
                            local classinfo, classfile = GetClassInfo(classid)
                            local classColor = classfile and C_ClassColor and C_ClassColor.GetClassColor(classfile)
                            local val = classColor and WrapTextInColorCode(classinfo or L["Global"], classColor:GenerateHexColor()) or (classinfo or L["Global"])
                            local key = classid .. val

                            SequenceDropDown:AddItem(key, val)
                            SequenceDropDown:SetItemDisabled(key, true)
                            cid = classid
                        end
                        if specid then
                            if sid ~= specid and (sid or 0) > 13 and specid > 13 then
                                local val = select(2, GetSpecializationInfoByID(specid))
                                local key = val and (specid .. val)

                                if key then
                                    SequenceDropDown:AddItem(key, val)
                                    SequenceDropDown:SetItemDisabled(key, true)
                                end
                                sid = specid
                            end
                        end
                        SequenceDropDown:AddItem(v, v)
                    end
                end
                for k, _ in pairs((GSESequences and GSESequences[0]) or {}) do
                    SequenceDropDown:AddItem(k, k)
                end
                SequenceDropDown:SetMultiselect(false)
                SequenceDropDown:SetLabel(L["Sequence"])
                if action.Sequence then
                    SequenceDropDown:SetValue(action.Sequence)
                end
                SequenceDropDown:SetCallback(
                    "OnValueChanged",
                    function(obj, event, key, checked)
                        local embedAction = editframe.Sequence.Versions[version].Actions[keyPath]
                        embedAction.Type = Statics.Actions.Embed
                        embedAction.Sequence = key
                    end
                )


                local sequenceFields = UI:Create("SimpleGroup")
                sequenceFields:SetLayout("Flow")
                sequenceFields:SetFullWidth(true)
                sequenceFields:SetHeight(56)
                if sequenceFields.SetFlowPadding then sequenceFields:SetFlowPadding(92, 0, 28, 8) end
                sequenceFields:AddChild(SequenceDropDown)
                macroPanel:AddChild(sequenceFields)
                DrawNestedChildActions(macroPanel, action, keyPath)
                pcontainer:AddChild(macroPanel)
            end
        end
        if GSE.isEmpty(editframe.Sequence.Versions[version].Actions) then
            editframe.Sequence.Versions[version].Actions = {
                [1] = {
                    ["macro"] = "Need Stuff Here",
                    ["type"] = "macro",
                    ["Type"] = Statics.Actions.Action
                }
            }
        end

        local macro = editframe.Sequence.Versions[version].Actions

        local font = CreateFont("seqPanelFont")
        font:SetFontObject(GameFontNormal)
        font:SetJustifyV("BOTTOM")

        local function finishDraw()
            if tcontainer.DoLayout then tcontainer:DoLayout() end
            if editframe.scrollContainer and editframe.scrollContainer.DoLayout then
                editframe.scrollContainer:DoLayout()
                if editframe.scrollContainer.SetScroll then
                    editframe.scrollContainer:SetScroll(scrollRestore or 0)
                end
            end
            if editframe.HideBuildSpinner then editframe.HideBuildSpinner() end
            editframe.suppressMacroAutoSelectUntil = (GetTime and GetTime() or 0) + 0.4
            editframe.drawingSequenceEditor = nil
        end

        -- Count the WHOLE block tree (nested If/Loop children included), not just
        -- the top level: a sequence can have a handful of top-level blocks whose
        -- subtrees hold hundreds, and that depth is the freeze.
        local function CountActionBlocks(list)
            if type(list) ~= "table" then return 0 end
            local n = 0
            for _, a in ipairs(list) do
                if type(a) == "table" and a.Type then
                    n = n + 1
                    if a.Type == Statics.Actions.If then
                        -- If branches live in separate child lists a[1]/a[2].
                        n = n + CountActionBlocks(a[1]) + CountActionBlocks(a[2])
                    else
                        -- Loop bodies (and any inline children) live in a's array part.
                        n = n + CountActionBlocks(a)
                    end
                end
            end
            return n
        end
        local totalBlocks = CountActionBlocks(macro)

        local INCREMENTAL_MIN_BLOCKS = 12
        if not (C_Timer and C_Timer.After) or totalBlocks <= INCREMENTAL_MIN_BLOCKS then
            editframe.incBuildQueue = nil
            for key, action in ipairs(macro) do
                drawAction(tcontainer, action, version, { key }, path)
            end
            if batchLayout and UI and UI.ResumeLayout then UI:ResumeLayout() end
            finishDraw()
        else
            if batchLayout and UI and UI.ResumeLayout then UI:ResumeLayout() end
            local queue = {}
            editframe.incBuildQueue = queue   -- DrawNestedChildActions appends here
            for key, action in ipairs(macro) do
                local k, a = key, action
                queue[#queue + 1] = function()
                    drawAction(tcontainer, a, version, { k }, path)
                end
            end
            if editframe.ShowBuildSpinner then editframe.ShowBuildSpinner() end
            local ITEMS = 4         -- blocks built per frame
            local head = 1
            local function buildChunk()
                -- Abort if a newer draw started or the editor closed (both bump
                -- buildGeneration) so we never write into a torn-down container.
                -- Do NOT clear incBuildQueue here — a newer draw may already own
                -- it; the next draw's dispatch always resets it.
                if editframe.buildGeneration ~= myGen then return end
                if not (editframe.Sequence and editframe.Sequence.Versions and editframe.Sequence.Versions[version]) then
                    return
                end
                if batchLayout and UI and UI.SuspendLayout then UI:SuspendLayout() end
                local built = 0
                -- The queue grows as blocks enqueue their children; drain FIFO via
                -- head index. Drained slots set false (not nil) so #queue stays a
                -- valid length as the tail grows.
                while built < ITEMS and head <= #queue do
                    local job = queue[head]
                    queue[head] = false
                    head = head + 1
                    built = built + 1
                    if job then job() end
                end
                if batchLayout and UI and UI.ResumeLayout then UI:ResumeLayout() end
                -- Lay out only the content container per chunk (cheap, keeps
                -- block heights current). Do NOT lay out the scroll frame here —
                -- its per-chunk UpdateScroll nudges the scroll position down as
                -- the content grows, so the editor landed ~1 block per chunk
                -- down instead of at the top (block 4 at 2 chunks, block 8 at 8).
                -- finishDraw lays out the scroll frame + sets scroll once, after
                -- every block exists. The spinner covers the build anyway.
                if tcontainer.DoLayout then tcontainer:DoLayout() end
                if head <= #queue then
                    C_Timer.After(0, buildChunk)
                else
                    editframe.incBuildQueue = nil
                    finishDraw()
                end
            end
            buildChunk()
        end
    end
    editframe.DrawSequenceEditor = function(...)
        DrawSequenceEditor(...)
    end
    local function GUIDrawMacroEditor(container, version, path)
        version = tonumber(version)
        if GSE.isEmpty(editframe.Sequence) then
            editframe.Sequence = {
                ["MetaData"] = {
                    ["Author"] = GSE.GetCharacterName(),
                    ["Default"] = 1,
                    ["SpecID"] = GSE.GetCurrentSpecID(),
                    ["GSEVersion"] = GSE.VersionString
                },
                ["Versions"] = {
                    [1] = {
                        ["Actions"] = {
                            [1] = {
                                ["macro"] = "Need Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        ["InbuiltVariables"] = {}
                    }
                }
            }
        end
        local macrocontainer = UI:Create("SimpleGroup")
        macrocontainer:SetFullWidth(true)
        macrocontainer:SetLayout("List")
        macrocontainer:SetAutoAdjustHeight(true)
        if macrocontainer.SetListPadding then macrocontainer:SetListPadding(4, 0, 0, 0) end
        setmetatable(editframe.Sequence.Versions[version].Actions, Statics.TableMetadataFunction)
        editframe.booleanFunctions = {}
        editframe.numericFunctions = {}

        local layoutcontainer = UI:Create("SimpleGroup")

        layoutcontainer:SetFullWidth(true)
        layoutcontainer:SetLayout("List")
        if layoutcontainer.SetFlowOffset then layoutcontainer:SetFlowOffset(0, 4) end

        local linegroup1 = UI:Create("SimpleGroup")
        linegroup1:SetLayout("Flow")
        if linegroup1.SetFlowGap then linegroup1:SetFlowGap(4) end
        if linegroup1.SetFlowOffset then linegroup1:SetFlowOffset(-4, 0) end

        linegroup1:SetFullWidth(true)
        linegroup1:SetHeight(40)

        local spacerlabel1 = UI:Create("Label")
        spacerlabel1:SetWidth(5)

        local basespellspacer = UI:Create("Label")
        basespellspacer:SetWidth(5)

        local spacerlabel7 = UI:Create("Label")
        spacerlabel7:SetWidth(10)

        local delversionbutton = UI:Create("Icon")
        delversionbutton:SetImage("Interface\\AddOns\\GSE_GUI\\Assets\\delete.png")
        if delversionbutton.SetElvUISubduedIcon then delversionbutton:SetElvUISubduedIcon(true) end
        delversionbutton:SetImageSize(30, 30)
        delversionbutton:SetWidth(30)
        delversionbutton:SetHeight(30)
        delversionbutton:SetCallback(
            "OnClick",
            function()
                version = tonumber(version)
                local sequence = editframe.Sequence
                if #sequence.Versions <= 1 then
                    GSE.Print(
                        L["This is the only version of this macro.  Delete the entire macro to delete this version."]
                    )
                    return
                end
                if sequence.MetaData.Default == version then
                    GSE.Print(
                        L[
                            "You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."
                        ]
                    )
                    return
                end
                GSE.UI.ShowConfirmDialog({
                    owner       = editframe,
                    title       = L["Delete Version"],
                    message     = L["Are you sure you want to Delete"]
                        .. "\n\n|cFFFFFFFF" .. tostring(sequence.MetaData.Name or editframe.SequenceName or "this macro")
                        .. " \226\128\148 Version " .. tostring(version) .. "|r\n\n"
                        .. "This will Delete the Version."
                        .. "\n\n|cFFFF3030" .. L["This Action Cannot be Undone!"] .. "|r",
                    width       = 360,
                    height      = 210,
                    confirmText = L["Delete"],
                    cancelText  = L["Cancel"],
                    onConfirm   = function()
                    local printtext = L["Macro Version %d deleted."]
                    if sequence.MetaData.PVP == version then
                        sequence.MetaData.PVP = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["PVP setting changed to Default."]
                    end
                    if sequence.MetaData.Arena == version then
                        sequence.MetaData.Arena = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Arena setting changed to Default."]
                    end
                    if sequence.MetaData.Raid == version then
                        sequence.MetaData.Raid = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Raid setting changed to Default."]
                    end
                    if sequence.MetaData.Mythic == version then
                        sequence.MetaData.Mythic = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Mythic setting changed to Default."]
                    end
                    if sequence.MetaData.Heroic == version then
                        sequence.MetaData.Heroic = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Heroic setting changed to Default."]
                    end
                    if sequence.MetaData.Dungeon == version then
                        sequence.MetaData.Dungeon = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Dungeon setting changed to Default."]
                    end
                    if sequence.MetaData.Party == version then
                        sequence.MetaData.Party = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Party setting changed to Default."]
                    end
                    if sequence.MetaData.MythicPlus == version then
                        sequence.MetaData.MythicPlus = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Mythic+ setting changed to Default."]
                    end
                    if sequence.MetaData.Timewalking == version then
                        sequence.MetaData.Timewalking = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Timewalking setting changed to Default."]
                    end
                    if sequence.MetaData.Scenario == version then
                        sequence.MetaData.Scenario = sequence.MetaData.Default
                        printtext = printtext .. " " .. L["Delves and Scenarios setting changed to Default."]
                    end

                    if sequence.MetaData.Default > 1 then
                        sequence.MetaData.Default = tonumber(sequence.MetaData.Default) - 1
                    else
                        sequence.MetaData.Default = 1
                    end

                    if
                        not GSE.isEmpty(sequence.MetaData.PVP) and sequence.MetaData.PVP > 1 and
                            sequence.MetaData.PVP >= version
                     then
                        sequence.MetaData.PVP = tonumber(sequence.MetaData.PVP) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Arena) and sequence.MetaData.Arena > 1 and
                            sequence.MetaData.Arena >= version
                     then
                        sequence.MetaData.Arena = tonumber(sequence.MetaData.Arena) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Raid) and sequence.MetaData.Raid > 1 and
                            sequence.MetaData.Raid >= version
                     then
                        sequence.MetaData.Raid = tonumber(sequence.MetaData.Raid) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Mythic) and sequence.MetaData.Mythic > 1 and
                            sequence.MetaData.Mythic >= version
                     then
                        sequence.MetaData.Mythic = tonumber(sequence.MetaData.Mythic) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.MythicPlus) and sequence.MetaData.MythicPlus > 1 and
                            sequence.MetaData.MythicPlus >= version
                     then
                        sequence.MetaData.MythicPlus = tonumber(sequence.MetaData.MythicPlus) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Timewalking) and sequence.MetaData.Timewalking > 1 and
                            sequence.MetaData.Timewalking >= version
                     then
                        sequence.MetaData.Timewalking = tonumber(sequence.MetaData.Timewalking) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Heroic) and sequence.MetaData.Heroic > 1 and
                            sequence.MetaData.Heroic >= version
                     then
                        sequence.MetaData.Heroic = tonumber(sequence.MetaData.Heroic) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Dungeon) and sequence.MetaData.Dungeon > 1 and
                            sequence.MetaData.Dungeon >= version
                     then
                        sequence.MetaData.Dungeon = tonumber(sequence.MetaData.Dungeon) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Party) and sequence.MetaData.Party > 1 and
                            sequence.MetaData.Party >= version
                     then
                        sequence.MetaData.Party = tonumber(sequence.MetaData.Party) - 1
                    end
                    if
                        not GSE.isEmpty(sequence.MetaData.Scenario) and sequence.MetaData.Scenario > 1 and
                            sequence.MetaData.Scenario >= version
                     then
                        sequence.MetaData.Scenario = tonumber(sequence.MetaData.Scenario) - 1
                    end
                    table.remove(sequence.Versions, version)

                    -- Mirror the deletion into the Library display cache so the
                    -- tree drops the version node immediately, before any Save
                    -- (GSESequences is only written on explicit Save). The tree is
                    -- built from GSE.Library, not editframe.Sequence, so without
                    -- this the deleted version lingered until save. Same approach
                    -- as the New Version handler and the drag-reorder handler.
                    local delClassID = tonumber(editframe.ClassID)
                    if delClassID then
                        GSE.EnsureSequenceLoaded(delClassID, editframe.SequenceName)
                        local libSeq = GSE.Library[delClassID] and GSE.Library[delClassID][editframe.SequenceName]
                        if libSeq and libSeq.Versions and libSeq.Versions[version] then
                            table.remove(libSeq.Versions, version)
                            if libSeq.MetaData then
                                libSeq.MetaData.Default = sequence.MetaData.Default
                                local contextKeys = {
                                    "Raid", "Arena", "Mythic", "MythicPlus", "PVP",
                                    "Heroic", "Dungeon", "Timewalking", "Party", "Scenario",
                                }
                                for _, ck in ipairs(contextKeys) do
                                    libSeq.MetaData[ck] = sequence.MetaData[ck]
                                end
                            end
                        end
                    end

                    printtext = printtext .. " " .. L["This change will not come into effect until you save this macro."]
                    editframe.ManageTree()
                    treeContainer:SelectByValue(path)
                    editframe:SetStatusText(string.format(printtext, version))
                    C_Timer.After(
                        5,
                        function()
                            editframe:SetStatusText(editframe.statusText)
                        end
                    )
                end,
                })
            end
        )
        delversionbutton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Delete Version"],
                    L[
                        "Delete this version of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
                    ],
                    editframe
                )
            end
        )
        delversionbutton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local delspacerlabel = UI:Create("Label")
        delspacerlabel:SetWidth(5)

        local resetToolbarRow
        local raweditbutton = UI:Create("Button")
        raweditbutton:SetText(L["Raw Edit"])
        raweditbutton:SetWidth(100)
        if raweditbutton.SetElvUIBackgroundShown then raweditbutton:SetElvUIBackgroundShown(true) end
        if raweditbutton.SetFlowOffset then raweditbutton:SetFlowOffset(0, -2) end
        raweditbutton:SetCallback(
            "OnClick",
            function()
                if GSE.SanitizeSequenceEditorMarkup then
                    GSE.SanitizeSequenceEditorMarkup(editframe.Sequence.Versions[version])
                end
                drawRawEditor(
                    macrocontainer,
                    version,
                    GSE.Dump(GSE.UnEscapeTableRecursive(editframe.Sequence.Versions[version])),
                    path,
                    resetToolbarRow
                )

                GSE.WagoAnalytics:Switch("Raw Edit", true)
            end
        )
        raweditbutton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Raw Edit"],
                    L[
                        "Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."
                    ],
                    editframe
                )
            end
        )
        raweditbutton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local previewMacro = UI:Create("Button")
        previewMacro:SetText(L["Compiled Template"])
        previewMacro:SetWidth(150)
        if previewMacro.SetElvUIBackgroundShown then previewMacro:SetElvUIBackgroundShown(true) end
        if previewMacro.SetFlowOffset then previewMacro:SetFlowOffset(0, -2) end
        previewMacro:SetCallback(
            "OnClick",
            function()
                local GSE3Macro = GSE.CompileTemplate(editframe.Sequence.Versions[version])
                GSE.GUIShowCompiledMacroGui(GSE3Macro, editframe.SequenceName .. " : " .. version, editframe)
                GSE.WagoAnalytics:Switch("Compile Template", true)
            end
        )
        previewMacro:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Compiled Template"], L["Show the compiled version of this macro."], editframe)
            end
        )
        previewMacro:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local spacerlabel2 = UI:Create("Label")
        spacerlabel2:SetWidth(6)

        local function CloneMacroBlockPath(sourcePath)
            local cloned = {}
            for _, value in ipairs(sourcePath or {}) do
                table.insert(cloned, tonumber(value) or value)
            end
            return cloned
        end

        local function ParentMacroBlockPath(sourcePath)
            local parent = CloneMacroBlockPath(sourcePath)
            table.remove(parent, #parent)
            return parent
        end

        local function GetTopButtonActionList(listPath)
            local actions = editframe.Sequence and editframe.Sequence.Versions and
                editframe.Sequence.Versions[version] and editframe.Sequence.Versions[version].Actions
            if type(actions) ~= "table" then return nil end
            if GSE.isEmpty(listPath) or #listPath == 0 then return actions end

            local actionList = actions[listPath]
            if type(actionList) ~= "table" then return nil end
            return actionList
        end

        local function GetTopButtonActionAtPath(actionPath)
            local actionList = GetTopButtonActionList(ParentMacroBlockPath(actionPath))
            local actionIndex = actionPath and tonumber(actionPath[#actionPath])
            if type(actionList) ~= "table" or not actionIndex then return nil end
            -- rawget bypasses TableMetadataFunction __index which only handles table keys
            return rawget(actionList, actionIndex)
        end

        local function SetSelectedMacroBlockPathForTopButtons(newPath)
            editframe.selectedMacroBlockPath = CloneMacroBlockPath(newPath)
            editframe.selectedMacroBlockVersion = version
            editframe.selectedMacroBlockHighlight = nil
        end

        local function MacroBlockPathsEqual(leftPath, rightPath)
            if #(leftPath or {}) ~= #(rightPath or {}) then return false end
            for index, value in ipairs(leftPath or {}) do
                if value ~= rightPath[index] then return false end
            end
            return true
        end

        local function MacroBlockPathStartsWith(sourcePath, prefixPath)
            if #(prefixPath or {}) > #(sourcePath or {}) then return false end
            for index, value in ipairs(prefixPath or {}) do
                if sourcePath[index] ~= value then return false end
            end
            return true
        end

        local function GetActionChildListPath(actionPath, action)
            if type(action) ~= "table" then return nil end

            if action.Type == Statics.Actions.Loop then
                return CloneMacroBlockPath(actionPath)
            elseif action.Type == Statics.Actions.If then
                local truePath = CloneMacroBlockPath(actionPath)
                table.insert(truePath, 1)
                return truePath
            elseif #action > 0 then
                return CloneMacroBlockPath(actionPath)
            end
            return nil
        end

        local function AddVisibleMacroBlockPaths(actionList, parentPath, visiblePaths)
            if type(actionList) ~= "table" then return end

            for index, action in ipairs(actionList) do
                if type(action) == "table" then
                    local actionPath = CloneMacroBlockPath(parentPath)
                    table.insert(actionPath, index)
                    table.insert(visiblePaths, actionPath)

                    if action.Type == Statics.Actions.Loop then
                        AddVisibleMacroBlockPaths(action, actionPath, visiblePaths)
                    elseif action.Type == Statics.Actions.If then
                        local truePath = CloneMacroBlockPath(actionPath)
                        table.insert(truePath, 1)
                        AddVisibleMacroBlockPaths(action[1], truePath, visiblePaths)

                        local falsePath = CloneMacroBlockPath(actionPath)
                        table.insert(falsePath, 2)
                        AddVisibleMacroBlockPaths(action[2], falsePath, visiblePaths)
                    elseif #action > 0 then
                        AddVisibleMacroBlockPaths(action, actionPath, visiblePaths)
                    end
                end
            end
        end

        local function GetVisibleMacroBlockPaths()
            local visiblePaths = {}
            AddVisibleMacroBlockPaths(GetTopButtonActionList({}), {}, visiblePaths)
            return visiblePaths
        end

        local function AddMovementMacroBlockPaths(actionList, parentPath, movementPaths)
            if type(actionList) ~= "table" then return end

            for index, action in ipairs(actionList) do
                if type(action) == "table" then
                    local actionPath = CloneMacroBlockPath(parentPath)
                    table.insert(actionPath, index)
                    table.insert(movementPaths, actionPath)

                    if action.Type == Statics.Actions.Loop then
                        AddMovementMacroBlockPaths(action, actionPath, movementPaths)
                    elseif action.Type ~= Statics.Actions.If and action.Type ~= Statics.Actions.Embed and #action > 0 then
                        AddMovementMacroBlockPaths(action, actionPath, movementPaths)
                    end
                end
            end
        end

        local function GetMovementMacroBlockPaths(rootPath)
            local movementPaths = {}
            AddMovementMacroBlockPaths(GetTopButtonActionList(rootPath or {}), rootPath or {}, movementPaths)
            return movementPaths
        end

        local function GetMoveDestinationAfterVisiblePath(targetPath)
            local targetAction = GetTopButtonActionAtPath(targetPath)
            local childListPath = GetActionChildListPath(targetPath, targetAction)
            if childListPath and type(GetTopButtonActionList(childListPath)) == "table" then
                local destinationPath = CloneMacroBlockPath(childListPath)
                table.insert(destinationPath, 1)
                return destinationPath
            end

            local destinationPath = CloneMacroBlockPath(targetPath)
            destinationPath[#destinationPath] = (tonumber(destinationPath[#destinationPath]) or 0) + 1
            return destinationPath
        end

        local function GetMoveDestinationAfterMovementPath(targetPath)
            local targetAction = GetTopButtonActionAtPath(targetPath)
            if targetAction and targetAction.Type ~= Statics.Actions.If and targetAction.Type ~= Statics.Actions.Embed then
                local childListPath = GetActionChildListPath(targetPath, targetAction)
                if childListPath and type(GetTopButtonActionList(childListPath)) == "table" then
                    local destinationPath = CloneMacroBlockPath(childListPath)
                    table.insert(destinationPath, 1)
                    return destinationPath
                end
            end

            local destinationPath = CloneMacroBlockPath(targetPath)
            destinationPath[#destinationPath] = (tonumber(destinationPath[#destinationPath]) or 0) + 1
            return destinationPath
        end

        local function GetPathAfterMacroBlock(targetPath)
            local destinationPath = CloneMacroBlockPath(targetPath)
            destinationPath[#destinationPath] = (tonumber(destinationPath[#destinationPath]) or 0) + 1
            return destinationPath
        end

        local function GetSkippedMoveBlockPath(actionPath, selectedPath)
            local candidatePath = {}
            for _, pathIndex in ipairs(actionPath or {}) do
                table.insert(candidatePath, pathIndex)
                local candidateAction = GetTopButtonActionAtPath(candidatePath)
                if
                    candidateAction and
                    (candidateAction.Type == Statics.Actions.If or candidateAction.Type == Statics.Actions.Embed)
                then
                    if selectedPath and MacroBlockPathStartsWith(selectedPath, candidatePath) then
                        return nil
                    end
                    return CloneMacroBlockPath(candidatePath)
                end
            end
            return nil
        end

        local function GetContainingIfBlockPath(actionPath)
            local containingIfPath
            local candidatePath = {}
            for index = 1, math.max(0, #(actionPath or {}) - 2) do
                table.insert(candidatePath, actionPath[index])
                local branchIndex = tonumber(actionPath[index + 1])
                local candidateAction = GetTopButtonActionAtPath(candidatePath)
                if
                    candidateAction and
                    candidateAction.Type == Statics.Actions.If and
                    (branchIndex == 1 or branchIndex == 2)
                then
                    containingIfPath = CloneMacroBlockPath(candidatePath)
                end
            end
            return containingIfPath
        end

        local function GetContainingIfBranchPath(actionPath, containingIfPath)
            if not containingIfPath or not MacroBlockPathStartsWith(actionPath, containingIfPath) then return nil end
            local branchIndex = tonumber(actionPath[#containingIfPath + 1])
            if branchIndex ~= 1 and branchIndex ~= 2 then return nil end

            local branchPath = CloneMacroBlockPath(containingIfPath)
            table.insert(branchPath, branchIndex)
            return branchPath
        end

        local function DestinationStaysInsideIfBranch(destinationPath, selectedBranchPath)
            return selectedBranchPath and MacroBlockPathStartsWith(destinationPath, selectedBranchPath)
        end

        local function MoveCrossesIfBranchBoundary(sourcePath, destinationPath)
            local sourceContainingIfPath = GetContainingIfBlockPath(sourcePath)
            local sourceBranchPath = sourceContainingIfPath and
                GetContainingIfBranchPath(sourcePath, sourceContainingIfPath) or
                nil
            local destinationContainingIfPath = GetContainingIfBlockPath(destinationPath)
            local destinationBranchPath = destinationContainingIfPath and
                GetContainingIfBranchPath(destinationPath, destinationContainingIfPath) or
                nil

            if sourceBranchPath then
                return not (destinationBranchPath and MacroBlockPathsEqual(sourceBranchPath, destinationBranchPath))
            end
            return destinationBranchPath ~= nil
        end

        local function FindMacroBlockPathByReference(actionList, targetAction, parentPath)
            if type(actionList) ~= "table" or type(targetAction) ~= "table" then return nil end

            for index, action in ipairs(actionList) do
                if type(action) == "table" then
                    local actionPath = CloneMacroBlockPath(parentPath)
                    table.insert(actionPath, index)
                    if action == targetAction then return actionPath end

                    local foundPath
                    if action.Type == Statics.Actions.Loop then
                        foundPath = FindMacroBlockPathByReference(action, targetAction, actionPath)
                    elseif action.Type == Statics.Actions.If then
                        local truePath = CloneMacroBlockPath(actionPath)
                        table.insert(truePath, 1)
                        foundPath = FindMacroBlockPathByReference(action[1], targetAction, truePath)
                        if not foundPath then
                            local falsePath = CloneMacroBlockPath(actionPath)
                            table.insert(falsePath, 2)
                            foundPath = FindMacroBlockPathByReference(action[2], targetAction, falsePath)
                        end
                    elseif #action > 0 then
                        foundPath = FindMacroBlockPathByReference(action, targetAction, actionPath)
                    end
                    if foundPath then return foundPath end
                end
            end
            return nil
        end

        local function MoveTopButtonMacroBlockToPath(sourcePath, destinationPath)
            if not sourcePath or not destinationPath or #sourcePath == 0 or #destinationPath == 0 then return false end

            local sourceParent = ParentMacroBlockPath(sourcePath)
            local destinationParent = ParentMacroBlockPath(destinationPath)
            if MacroBlockPathsEqual(sourcePath, destinationPath) then return false end
            if MacroBlockPathStartsWith(destinationParent, sourcePath) then return false end
            if MoveCrossesIfBranchBoundary(sourcePath, destinationPath) then return false end

            local sourceList = GetTopButtonActionList(sourceParent)
            local destinationList = GetTopButtonActionList(destinationParent)
            if type(sourceList) ~= "table" or type(destinationList) ~= "table" then return false end

            local sourceIndex = tonumber(sourcePath[#sourcePath])
            local destinationIndex = tonumber(destinationPath[#destinationPath])
            if not sourceIndex or not destinationIndex or not rawget(sourceList, sourceIndex) then return false end

            local movingAction = GSE.CloneSequence(rawget(sourceList, sourceIndex))
            table.remove(sourceList, sourceIndex)

            local adjustedDestinationParent = CloneMacroBlockPath(destinationParent)
            if MacroBlockPathStartsWith(adjustedDestinationParent, sourceParent) and #adjustedDestinationParent > #sourceParent then
                local shiftedIndexPosition = #sourceParent + 1
                local shiftedIndex = tonumber(adjustedDestinationParent[shiftedIndexPosition])
                if shiftedIndex and shiftedIndex > sourceIndex then
                    adjustedDestinationParent[shiftedIndexPosition] = shiftedIndex - 1
                end
            end

            if sourceList == destinationList and destinationIndex > sourceIndex then
                destinationIndex = destinationIndex - 1
            end
            if destinationIndex < 1 then destinationIndex = 1 end
            if destinationIndex > #destinationList + 1 then destinationIndex = #destinationList + 1 end

            table.insert(destinationList, destinationIndex, movingAction)

            local movedPath = FindMacroBlockPathByReference(GetTopButtonActionList({}), movingAction, {})
            if movedPath then return true, movedPath end

            movedPath = CloneMacroBlockPath(adjustedDestinationParent)
            table.insert(movedPath, destinationIndex)
            return true, movedPath
        end

        local FocusSelectedMacroBlock

        local function GetSelectedMacroBlockForTopButtons()
            local selectedPath =
                editframe.selectedMacroBlockVersion == version and CloneMacroBlockPath(editframe.selectedMacroBlockPath)
                    or nil
            local selectedAction = selectedPath and #selectedPath > 0 and GetTopButtonActionAtPath(selectedPath) or nil
            return selectedPath, selectedAction
        end

        local function SelectedMacroBlockIsInIfContext()
            local selectedPath, selectedAction = GetSelectedMacroBlockForTopButtons()
            if selectedAction and selectedAction.Type == Statics.Actions.If then return true end
            return GetContainingIfBlockPath(selectedPath) ~= nil
        end

        local function TopToolbarActionAllowedInSelectedBlock(newAction)
            -- All block types are allowed from the top toolbar regardless of context.
            -- The visual disable for Pause/Embed inside IF was removed; the logic
            -- gate is removed here to match.
            return true
        end

        -- Forward-declared: InsertTopToolbarAction (below) calls this, but the
        -- definition appears later in this scope; without the forward local the
        -- call would bind to a nil global.
        local BlinkSelectedMacroBlock
        local function InsertTopToolbarAction(newAction)
            if not TopToolbarActionAllowedInSelectedBlock(newAction) then
                BlinkSelectedMacroBlock()
                return
            end
            local selectedPath, selectedAction = GetSelectedMacroBlockForTopButtons()
            local insertedPath

            if selectedPath and #selectedPath > 0 then
                if type(selectedAction) == "table" then
                    -- Always insert the new block as a sibling immediately AFTER
                    -- the focused block, in the same container. Focusing a Loop or
                    -- If block therefore adds a new block BELOW it (a sibling), not
                    -- inside it; to add inside a loop or an If branch, focus one of
                    -- its child blocks and the new block lands right after that.
                    local parentPath = ParentMacroBlockPath(selectedPath)
                    local targetList = GetTopButtonActionList(parentPath)
                    local selectedIndex = tonumber(selectedPath[#selectedPath])
                    local insertAt = selectedIndex and selectedIndex + 1
                    if type(targetList) == "table" and insertAt then
                        if insertAt > #targetList + 1 then
                            insertAt = #targetList + 1
                        end
                        table.insert(targetList, insertAt, newAction)
                        insertedPath = CloneMacroBlockPath(parentPath)
                        table.insert(insertedPath, insertAt)
                    end
                end
            end

            if insertedPath then
                SetSelectedMacroBlockPathForTopButtons(insertedPath)
            else
                local rootActions = GetTopButtonActionList({})
                if type(rootActions) ~= "table" then return end
                table.insert(rootActions, 1, newAction)
                editframe.selectedMacroBlockHighlight = nil
                editframe.scrollStatus = editframe.scrollStatus or {}
                editframe.scrollStatus.scrollvalue = 1
                insertedPath = {1}
                SetSelectedMacroBlockPathForTopButtons(insertedPath)
            end

            editframe.scrollStatus = editframe.scrollStatus or {}
            local finalInsertedPath = CloneMacroBlockPath(insertedPath)
            if editframe.gseRestrictMacroBlockAutoSelect then
                editframe.gseRestrictMacroBlockAutoSelect(finalInsertedPath, 0.45)
            end
            editframe.pendingMacroBlockSelectPath = CloneMacroBlockPath(finalInsertedPath)
            editframe.pendingMacroBlockSelectVersion = version
            ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            if editframe.gseSelectMacroBlockPath then
                editframe.gseSelectMacroBlockPath(finalInsertedPath, nil, true)
            end
            editframe.pendingMacroBlockSelectPath = nil
            editframe.pendingMacroBlockSelectVersion = nil
            if insertedPath and FocusSelectedMacroBlock then
                C_Timer.After(0.01, function()
                    if editframe.gseSelectMacroBlockPath then
                        editframe.gseSelectMacroBlockPath(finalInsertedPath, nil, true)
                    end
                    FocusSelectedMacroBlock()
                end)
                C_Timer.After(0.06, function()
                    if editframe.gseSelectMacroBlockPath then
                        editframe.gseSelectMacroBlockPath(finalInsertedPath, nil, true)
                    end
                    FocusSelectedMacroBlock()
                end)
                C_Timer.After(0.18, function()
                    if editframe.gseSelectMacroBlockPath then
                        editframe.gseSelectMacroBlockPath(finalInsertedPath, nil, true)
                    end
                    FocusSelectedMacroBlock()
                end)
                C_Timer.After(0.45, function()
                    if editframe.gseClearMacroBlockAutoSelect then
                        editframe.gseClearMacroBlockAutoSelect(finalInsertedPath)
                    end
                end)
            end
        end

        FocusSelectedMacroBlock = function()
            local scrollContainer = editframe.scrollContainer
            local selectedOverlay = editframe.selectedMacroBlockHighlight
            local selectedFrame = selectedOverlay and selectedOverlay:GetParent()
            local scrollFrame = scrollContainer and scrollContainer.scrollframe
            if not (scrollContainer and scrollContainer.SetScroll and selectedFrame and scrollFrame) then return end
            if not (selectedFrame:IsShown() and scrollFrame:IsShown()) then return end

            local blockTop, blockBottom = selectedFrame:GetTop(), selectedFrame:GetBottom()
            local viewTop, viewBottom = scrollFrame:GetTop(), scrollFrame:GetBottom()
            if not (blockTop and blockBottom and viewTop and viewBottom) then return end

            local footerFrame = editframe.footer or (editframe.editButtonGroup and editframe.editButtonGroup.frame)
            local footerTop = footerFrame and footerFrame:IsShown() and footerFrame:GetTop()
            if footerTop then
                viewBottom = math.max(viewBottom, footerTop + MACRO_BLOCK_FOCUS_MARGIN)
            end

            local status = scrollContainer.status or scrollContainer.localstatus or editframe.scrollStatus or {}
            local current = status.scrollvalue or (scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll()) or 0

            -- Only scroll when the block is not already fully inside the viewable
            -- area. If it is visible, leave the scroll position alone (no
            -- recentring - that pop-to-centre was the annoyance). If it is off an
            -- edge, bring just that edge into view rather than centring it.
            local target
            if blockTop > viewTop + 1 then
                target = current - (blockTop - viewTop)        -- off the top edge
            elseif blockBottom < viewBottom - 1 then
                target = current - (blockBottom - viewBottom)  -- off the bottom edge
            else
                return                                         -- fully visible: leave it
            end

            if math.abs(target - current) > 0.5 then
                scrollContainer:SetScroll(target)
            end
        end

        local function RefocusSelectedMacroBlock()
            if not FocusSelectedMacroBlock then return end
            FocusSelectedMacroBlock()
            C_Timer.After(0.01, FocusSelectedMacroBlock)
            C_Timer.After(0.05, FocusSelectedMacroBlock)
        end

        -- Expose to DrawSequenceEditor scope so SelectMacroBlockPath
        -- can center the block when selected by clicking.
        editframe.gseFocusSelectedMacroBlock = FocusSelectedMacroBlock

        function BlinkSelectedMacroBlock()
            RefocusSelectedMacroBlock()

            local selectedOverlay = editframe.selectedMacroBlockHighlight
            if not selectedOverlay then return end

            editframe.selectedMacroBlockBlinkToken = (editframe.selectedMacroBlockBlinkToken or 0) + 1
            local blinkToken = editframe.selectedMacroBlockBlinkToken
            local function setBlinkAlpha(alpha)
                if editframe.selectedMacroBlockBlinkToken ~= blinkToken then return end
                if selectedOverlay.SetAlpha then selectedOverlay:SetAlpha(alpha) end
                if selectedOverlay.Show then selectedOverlay:Show() end
            end

            setBlinkAlpha(0.18)
            C_Timer.After(0.08, function() setBlinkAlpha(1) end)
            C_Timer.After(0.16, function() setBlinkAlpha(0.18) end)
            C_Timer.After(0.24, function() setBlinkAlpha(1) end)
        end

        local function MoveSelectedMacroBlock(direction)
            local selectedPath =
                editframe.selectedMacroBlockVersion == version and CloneMacroBlockPath(editframe.selectedMacroBlockPath)
                    or nil
            if not selectedPath or #selectedPath == 0 then return false end
            local selectedAction = GetTopButtonActionAtPath(selectedPath)
            local selectedIsIfBlock = selectedAction and selectedAction.Type == Statics.Actions.If
            local selectedContainingIfPath = GetContainingIfBlockPath(selectedPath)
            local selectedIfBranchPath = selectedContainingIfPath and
                GetContainingIfBranchPath(selectedPath, selectedContainingIfPath) or
                nil

            local movementRootPath = selectedIfBranchPath or {}
            local visiblePaths = GetMovementMacroBlockPaths(movementRootPath)
            local selectedVisibleIndex
            for index, visiblePath in ipairs(visiblePaths) do
                if MacroBlockPathsEqual(visiblePath, selectedPath) then
                    selectedVisibleIndex = index
                    break
                end
            end
            if not selectedVisibleIndex then return false end

            local destinationPath
            if direction < 0 then
                local previousPath = visiblePaths[selectedVisibleIndex - 1]
                if not previousPath then
                    BlinkSelectedMacroBlock()
                    return false
                end
                destinationPath = CloneMacroBlockPath(previousPath)
            else
                for index = selectedVisibleIndex + 1, #visiblePaths do
                    local nextPath = visiblePaths[index]
                    if not MacroBlockPathStartsWith(nextPath, selectedPath) then
                        destinationPath = GetMoveDestinationAfterMovementPath(nextPath)
                        break
                    end
                end
            end
            if not destinationPath then
                BlinkSelectedMacroBlock()
                return false
            end
            if
                selectedIfBranchPath and
                not DestinationStaysInsideIfBranch(destinationPath, selectedIfBranchPath)
            then
                BlinkSelectedMacroBlock()
                return false
            end

            local moved, movedPath = MoveTopButtonMacroBlockToPath(selectedPath, destinationPath)
            if not moved then
                BlinkSelectedMacroBlock()
                return false
            end

            SetSelectedMacroBlockPathForTopButtons(movedPath)

            editframe.scrollStatus = editframe.scrollStatus or {}
            local finalMovedPath = CloneMacroBlockPath(movedPath)
            editframe.pendingMacroBlockSelectPath = CloneMacroBlockPath(finalMovedPath)
            editframe.pendingMacroBlockSelectVersion = version
            ChooseVersion(macrocontainer, version, editframe.scrollStatus.scrollvalue, path)
            if editframe.gseSelectMacroBlockPath then
                editframe.gseSelectMacroBlockPath(finalMovedPath, nil, true)
            end
            editframe.pendingMacroBlockSelectPath = nil
            editframe.pendingMacroBlockSelectVersion = nil
            C_Timer.After(0.01, function()
                if editframe.gseSelectMacroBlockPath then
                    editframe.gseSelectMacroBlockPath(finalMovedPath, nil, true)
                end
                RefocusSelectedMacroBlock()
            end)
            RefocusSelectedMacroBlock()
            return true
        end


        local moveUpButton = UI:Create("Icon")
        local moveDownButton = UI:Create("Icon")
        local addLoopButton = UI:Create("Icon")
        local addActionButton = UI:Create("Icon")
        local addPauseButton = UI:Create("Icon")
        local addIfButton = UI:Create("Icon")
        local addEmbedButton = UI:Create("Icon")

        moveUpButton:SetImageSize(30, 30)
        moveUpButton:SetWidth(30)
        moveUpButton:SetHeight(30)
        moveUpButton:SetImage(Statics.ActionsIcons.Up)
        if moveUpButton.SetElvUISubduedIcon then moveUpButton:SetElvUISubduedIcon(true) end
        moveUpButton:SetCallback(
            "OnClick",
            function()
                MoveSelectedMacroBlock(-1)
            end
        )
        moveUpButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Move Up"], "Move the selected block up one block.", editframe)
            end
        )
        moveUpButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        moveDownButton:SetImageSize(30, 30)
        moveDownButton:SetWidth(30)
        moveDownButton:SetHeight(30)
        moveDownButton:SetImage(Statics.ActionsIcons.Down)
        if moveDownButton.SetElvUISubduedIcon then moveDownButton:SetElvUISubduedIcon(true) end
        moveDownButton:SetCallback(
            "OnClick",
            function()
                MoveSelectedMacroBlock(1)
            end
        )
        moveDownButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Move Down"], "Move the selected block down one block.", editframe)
            end
        )
        moveDownButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addActionButton:SetImageSize(30, 30)
        addActionButton:SetWidth(30)
        addActionButton:SetHeight(30)
        addActionButton:SetImage(Statics.ActionsIcons.Action)
        if addActionButton.SetElvUISubduedIcon then addActionButton:SetElvUISubduedIcon(true) end

        addActionButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["macro"] = "Need Stuff Here",
                    ["type"] = "macro",
                    ["Type"] = Statics.Actions.Action
                }
                InsertTopToolbarAction(newAction)
            end
        )
        addActionButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
            end
        )
        addActionButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addLoopButton:SetImageSize(30, 30)
        addLoopButton:SetWidth(30)
        addLoopButton:SetHeight(30)
        addLoopButton:SetImage(Statics.ActionsIcons.Loop)
        if addLoopButton.SetElvUISubduedIcon then addLoopButton:SetElvUISubduedIcon(true) end

        addLoopButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = {
                        ["macro"] = "Need Stuff Here",
                        ["type"] = "macro",
                        ["Type"] = Statics.Actions.Action
                    },
                    ["StepFunction"] = Statics.Sequential,
                    ["Type"] = Statics.Actions.Loop,
                    ["Repeat"] = 2
                }
                -- setmetatable(newAction, Statics.TableMetadataFunction)
                InsertTopToolbarAction(newAction)
            end
        )
        addLoopButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
            end
        )
        addLoopButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addPauseButton:SetImageSize(30, 30)
        addPauseButton:SetWidth(30)
        addPauseButton:SetHeight(30)
        addPauseButton:SetImage(Statics.ActionsIcons.Pause)
        if addPauseButton.SetElvUISubduedIcon then addPauseButton:SetElvUISubduedIcon(true) end

        addPauseButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["Variable"] = "GCD",
                    ["Type"] = Statics.Actions.Pause
                }
                InsertTopToolbarAction(newAction)
            end
        )
        addPauseButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
            end
        )
        addPauseButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addIfButton:SetImageSize(30, 30)
        addIfButton:SetWidth(30)
        addIfButton:SetHeight(30)
        addIfButton:SetImage(Statics.ActionsIcons.If)
        if addIfButton.SetElvUISubduedIcon then addIfButton:SetElvUISubduedIcon(true) end

        addIfButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    [1] = {
                        [1] = {
                            ["macro"] = "Need True Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    [2] = {
                        [1] = {
                            ["macro"] = "Need False Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        }
                    },
                    ["Type"] = Statics.Actions.If
                }
                InsertTopToolbarAction(newAction)
            end
        )
        addIfButton:SetCallback(
            "OnEnter",
            function()
                if #editframe.booleanFunctions > 0 then
                    GSE.CreateToolTip(
                        L["Add If"],
                        L[
                            "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                        ],
                        editframe
                    )
                else
                    GSE.CreateToolTip(
                        L["Add If"],
                        L["If Blocks require a variable that returns either true or false.  Create the variable first."],
                        editframe
                    )
                end
            end
        )
        addIfButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        addEmbedButton:SetImageSize(30, 30)
        addEmbedButton:SetWidth(30)
        addEmbedButton:SetHeight(30)
        addEmbedButton:SetImage(Statics.ActionsIcons.Embed)
        if addEmbedButton.SetElvUISubduedIcon then addEmbedButton:SetElvUISubduedIcon(true) end

        addEmbedButton:SetCallback(
            "OnClick",
            function()
                local newAction = {
                    ["Type"] = Statics.Actions.Embed
                }
                InsertTopToolbarAction(newAction)
            end
        )
        addEmbedButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Add Embed"],
                    L[
                        "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                    ],
                    editframe
                )
            end
        )
        addEmbedButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local function SetTopToolbarIconDisabled(iconWidget, disabled)
            disabled = disabled and true or false
            if iconWidget.SetDisabled then iconWidget:SetDisabled(disabled) end
            if iconWidget.frame and iconWidget.frame.SetAlpha then iconWidget.frame:SetAlpha(disabled and 0.35 or 1) end
            if iconWidget.image then
                if iconWidget.image.SetDesaturated then iconWidget.image:SetDesaturated(disabled) end
                if iconWidget.image.SetVertexColor then
                    if disabled then
                        iconWidget.image:SetVertexColor(0.45, 0.45, 0.45, 0.65)
                    else
                        iconWidget.image:SetVertexColor(1, 1, 1, 1)
                    end
                end
            end
            -- If this icon was opted into the modern/ElvUI subdued treatment, re-apply
            -- it so the SetVertexColor(1,1,1,1) above doesn't leave Pause and Embed
            -- bright-orange while the other toolbar buttons are subdued. The subdued
            -- styling already handles its own desaturated/dim color and respects the
            -- disabled alpha set on the parent frame above.
            if not disabled and iconWidget.SetElvUISubduedIcon
                and iconWidget.frame and iconWidget.frame.GSEElvUISubduedIcon then
                iconWidget:SetElvUISubduedIcon(true)
            end
        end

        local function UpdateTopToolbarAddButtonStates()
            SetTopToolbarIconDisabled(addPauseButton, false)
            SetTopToolbarIconDisabled(addEmbedButton, false)
        end
        editframe.UpdateMacroBlockToolbarState = UpdateTopToolbarAddButtonStates
        UpdateTopToolbarAddButtonStates()

        local linegroup3 = UI:Create("SimpleGroup")
        linegroup3:SetLayout("Flow")
        linegroup3:SetFullWidth(true)

        local versionLabel = UI:Create("EditBox")
        versionLabel:SetWidth(150)
        versionLabel:SetHeight(40)
        if versionLabel.SetFlowOffset then versionLabel:SetFlowOffset(0, 10) end
        versionLabel:SetLabel(L["Version"] .. " " .. L["Name"])
        versionLabel:SetText(BuildVersionLabel(version, editframe.Sequence.Versions[version].Label, true))
        versionLabel:SetCallback(
            "OnTextChanged",
            function(self, event, text)
                editframe.Sequence.Versions[version].Label = text
            end
        )
        versionLabel:DisableButton(true)

        local spacerlabel3 = UI:Create("Label")
        spacerlabel3:SetWidth(6)

        local versionSpacerBefore = UI:Create("Label")
        versionSpacerBefore:SetWidth(6)

        local staticHeaderIndent = UI:Create("Label")
        staticHeaderIndent:SetWidth(7)

        linegroup1:AddChild(staticHeaderIndent)
        linegroup1:AddChild(addActionButton)
        linegroup1:AddChild(addLoopButton)
        linegroup1:AddChild(addPauseButton)
        linegroup1:AddChild(addIfButton)
        linegroup1:AddChild(addEmbedButton)
        linegroup1:AddChild(moveUpButton)
        linegroup1:AddChild(moveDownButton)
        linegroup1:AddChild(versionSpacerBefore)
        linegroup1:AddChild(versionLabel)
        linegroup1:AddChild(delversionbutton)
        linegroup1:AddChild(previewMacro)
        if GSE.Patron or GSE.Developer then
            linegroup1:AddChild(raweditbutton)
        end
        resetToolbarRow = CreateCombatResetRow(version)

        local topToolbarSpacer = UI:Create("Spacer")
        topToolbarSpacer:SetHeight(8)
        if editframe.staticHeaderContainer then
            editframe.staticHeaderContainer:ReleaseChildren()
            if editframe.SetStaticHeaderHeight then
                editframe:SetStaticHeaderHeight(MACRO_STATIC_HEADER_HEIGHT)
            else
                editframe.staticHeaderContainer:SetHeight(MACRO_STATIC_HEADER_HEIGHT)
            end
            editframe.staticHeaderContainer:AddChild(topToolbarSpacer)
            editframe.staticHeaderContainer:AddChild(linegroup1)
            if editframe.staticHeaderContainer.DoLayout then editframe.staticHeaderContainer:DoLayout() end
        else
            layoutcontainer:AddChild(topToolbarSpacer)
            layoutcontainer:AddChild(linegroup1)
        end

        layoutcontainer:AddChild(resetToolbarRow)
        DrawSequenceEditor(macrocontainer, version, path)
        if not editframe.Sequence.MetaData.DisableEditor then
            layoutcontainer:AddChild(macrocontainer)
        end
        container:AddChild(layoutcontainer)
    end

    local function FinishResizeLayout()
        editframe.resizeLayoutPending = nil
        editframe.resizeLayoutDirty = nil
        if editframe.scroller and editframe.scroller.DoLayout then editframe.scroller:DoLayout() end
        UpdateRawEditorLayout()
        if editframe.DoLayout then editframe:DoLayout() end
    end

    local function ScheduleResizeLayout()
        if editframe.resizeLayoutPending then return end
        editframe.resizeLayoutPending = true
        C_Timer.After(0.02, function()
            if editframe.resizing then
                editframe.resizeLayoutPending = nil
                editframe.resizeLayoutDirty = true
                return
            end
            FinishResizeLayout()
        end)
    end

    editframe:SetCallback("OnResizeStart", function()
        if editframe.treeContainer then
            editframe.treeContainer.skipTreeRefresh = true
        end
    end)

    editframe:SetCallback("OnResizeStop", function()
        if editframe.treeContainer then
            editframe.treeContainer.skipTreeRefresh = nil
        end
        if editframe.resizeLayoutPending or editframe.resizeLayoutDirty then
            FinishResizeLayout()
        end
        SaveSequenceEditorLocation()
    end)

    editframe.frame:SetScript(
        "OnSizeChanged",
        function(self, width, height)
            editframe.Height = height
            editframe.Width = width
            if editframe.Height > GetScreenHeight() then
                editframe.Height = GetScreenHeight() - 10
                editframe:SetHeight(editframe.Height)
            end
            if editframe.Height < 1 then
                editframe.Height = 1
                editframe:SetHeight(editframe.Height)
            end
            local maxWidth = GetMaxEditorWidth()
            if editframe.Width < 1 then
                editframe.Width = 1
                editframe:SetWidth(editframe.Width)
            elseif editframe.Width > maxWidth then
                editframe.Width = maxWidth
                editframe:SetWidth(editframe.Width)
            end
			local seOpts = EnsureSequenceEditorLocation()
			seOpts.height = math.min(MAX_EDITOR_HEIGHT, math.max(1, RoundNumber(editframe.Height)))
			seOpts.width = math.min(maxWidth, math.max(1, RoundNumber(editframe.Width)))
            if editframe.scroller then
                local function getBaseHeight()
                    if editframe.GetScrollAreaHeight then
                        local h = editframe.GetScrollAreaHeight()
                        if h and h > 80 then return h end
                    end
                    return math.max(80, editframe.Height - SCROLLCONTAINER_OFFSET)
                end
                local baseHeight = getBaseHeight()
                local scrollerHeight = math.max(80, baseHeight - (editframe.staticHeaderHeight or 0))
                -- Update the scroller widget height so DoLayout reads fresh values.
                editframe.scroller.height = scrollerHeight
                editframe.scroller.explicitHeight = true
                if editframe.scroller.frame and editframe.scroller.frame.SetHeight then
                    editframe.scroller.frame:SetHeight(scrollerHeight)
                end
                -- Also update baseContainer (scroller's parent) so layoutList
                -- propagates the correct height during the live-resize DoLayout chain.
                local baseContainer = editframe.baseContainer or (editframe.scroller.parent)
                if baseContainer then
                    baseContainer.height = baseHeight
                    if baseContainer.frame and baseContainer.frame.SetHeight then
                        baseContainer.frame:SetHeight(baseHeight)
                    end
                end
                if editframe.resizing then
                    editframe.resizeLayoutDirty = true
                else
                    ScheduleResizeLayout()
                end
            end
            if editframe.DoFooterLayout then editframe:DoFooterLayout() end
        end
    )

    if GSE.isEmpty(GSE.CreateSpellEditBox) then
        GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro, frame)
            local spellEditBox = UI:Create("EditBox")

            spellEditBox:SetWidth(ACTION_SPELL_UNIT_FIELD_WIDTH)
            spellEditBox:DisableButton(true)

            local storedAction = sequence.Versions[version].Actions[keyPath]
            local function inferActionType(targetAction)
                if not GSE.isEmpty(targetAction.type) then
                    if targetAction.type == "spell" and GSE.isEmpty(targetAction.spell) then
                        return "macro"
                    end
                    return targetAction.type
                end
                if not GSE.isEmpty(targetAction.macro) then return "macro" end
                if not GSE.isEmpty(targetAction.item) then return "item" end
                if not GSE.isEmpty(targetAction.action) then return "pet" end
                if not GSE.isEmpty(targetAction.toy) then return "toy" end
                if not GSE.isEmpty(targetAction.spell) then return "spell" end
                return "macro"
            end
            local inferredType = inferActionType(storedAction)
            storedAction.type = inferredType
            action.type = inferredType
            if inferredType == "macro" and action.macro == nil then
                action.macro = ""
                storedAction.macro = ""
            end

            local spelltext

            if action.toy then
                spelltext = action.toy
                spellEditBox:SetLabel(L["Toy"])
            elseif action.item then
                spelltext = action.item
                spellEditBox:SetLabel(L["Item"])
            elseif action.macro then
                local repairedMacro = StoreMacroEditorText(action.macro)
                if repairedMacro ~= action.macro then
                    action.macro = repairedMacro
                end
                if string.sub(GSE.UnEscapeString(action.macro), 1, 1) == "/" then
                    spelltext = GSE.CompileMacroText(action.macro, Statics.TranslatorMode.Current)
                else
                    spelltext = GSE.UnEscapeString(action.macro)
                end
            elseif action.action then
                spellEditBox:SetLabel(L["Pet Ability"])
                spelltext = action.action
            else
                spellEditBox:SetLabel(L["Spell"])
                local translatedSpell = GSE.GetSpellId(action.spell, Statics.TranslatorMode.Current)
                if translatedSpell then
                    spelltext = translatedSpell
                else
                    spelltext = action.spell
                end
            end
            if not action.macro then
                spelltext = DecodeEditorText(spelltext)
            end

            spellEditBox:SetText(spelltext)

            spellEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    value = DecodeEditorText(value)
                    if sequence.Versions[version].Actions[keyPath].type == "pet" then
                        sequence.Versions[version].Actions[keyPath].action = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "macro" then
                        sequence.Versions[version].Actions[keyPath].macro = StoreMacroEditorText(value)
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                        sequence.Versions[version].Actions[keyPath].unit = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "item" then
                        sequence.Versions[version].Actions[keyPath].item = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    elseif sequence.Versions[version].Actions[keyPath].type == "toy" then
                        sequence.Versions[version].Actions[keyPath].toy = value
                        sequence.Versions[version].Actions[keyPath].spell = nil
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                    else
                        local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                        if storedValue then
                            sequence.Versions[version].Actions[keyPath].spell = storedValue
                        else
                            sequence.Versions[version].Actions[keyPath].spell = value
                        end
                        sequence.Versions[version].Actions[keyPath].action = nil
                        sequence.Versions[version].Actions[keyPath].macro = nil
                        sequence.Versions[version].Actions[keyPath].item = nil
                        sequence.Versions[version].Actions[keyPath].toy = nil
                    end

                    local editedAction = sequence.Versions[version].Actions[keyPath]
                    action.type = editedAction.type
                    action.spell = editedAction.spell
                    action.macro = editedAction.macro
                    action.item = editedAction.item
                    action.toy = editedAction.toy
                    action.action = editedAction.action
                    action.unit = editedAction.unit
                    if not editedAction.IconUserSelected then
                        editedAction.Icon = nil
                        action.Icon = nil
                    end
                    if GSE.GUI.RefreshActionIconFor then GSE.GUI.RefreshActionIconFor(sequence, version, keyPath) end
                end
            )
            spellEditBox:SetCallback(
                "OnEditFocusLost",
                function()
                end
            )
            local macroEditBox = UI:Create("MultiLineEditBox")
            DisableMultilineEditorColoring(macroEditBox)
            macroEditBox:SetLabel(L["Macro Name or Macro Commands"])
            macroEditBox:DisableButton(true)
            macroEditBox:SetNumLines(5)
            macroEditBox:SetRelativeWidth(0.5)
            macroEditBox:SetText(spelltext)
            ForwardMacroEditorMouseWheel(macroEditBox, frame)
            UpdateMacroLimitState(macroEditBox, action.macro, editframe, version)
            macroEditBox:SetCallback(
                "OnRelease",
                function(sel)
                    DisableMultilineEditorColoring(sel)
                    UpdateMacroLimitState(sel, nil, editframe, version)
                end
            )
            macroEditBox:SetCallback(
                "OnTextChanged",
                function(sel, object, value)
                    if sel and (sel.GSEMacroEditorColoring or (sel.editBox and sel.editBox.GSEMacroEditorColoring) or (sel.editbox and sel.editbox.GSEMacroEditorColoring)) then return end

                    value = DecodeMacroEditorText(value)
                    local storedMacro = StoreMacroEditorText(value)
                    sequence.Versions[version].Actions[keyPath].macro = storedMacro
                    sequence.Versions[version].Actions[keyPath].spell = nil
                    sequence.Versions[version].Actions[keyPath].action = nil
                    sequence.Versions[version].Actions[keyPath].item = nil
                    sequence.Versions[version].Actions[keyPath].toy = nil
                    action.macro = storedMacro
                    action.spell = nil
                    action.action = nil
                    action.item = nil
                    action.toy = nil
                    if not sequence.Versions[version].Actions[keyPath].IconUserSelected then
                        sequence.Versions[version].Actions[keyPath].Icon = nil
                        action.Icon = nil
                    end
                    if GSE.GUI.RefreshActionIconFor then GSE.GUI.RefreshActionIconFor(sequence, version, keyPath) end
                    -- Colour/translate as you type per GSE.ShouldTranslateLive()
                    -- (Options > Tools & Diagnostics > Spell Translation): always, only
                    -- out of combat ("editing"), or never ("delayed"). When it skips,
                    -- the OnEditFocusLost handler below applies translation + colouring
                    -- once on commit. The macro text is already stored above
                    -- (StoreMacroEditorText), so nothing is lost either way.
                    if GSE.ShouldTranslateLive() then
                        RefreshMacroEditorColoredText(sel, storedMacro)
                    end
                    -- Keep the side panel text in sync even if it's not in
                    -- the layout right now ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â saves a re-derive when the
                    -- Compiled Template window is reopened.
                    if compiledMacro and compiledMacro.SetText then
                        local body =
                            DecodeMacroEditorText(
                            GSE.UnEscapeString(
                                GSE.CompileMacroText(
                                    sequence.Versions[version].Actions[keyPath].macro,
                                    Statics.TranslatorMode.String
                                )
                            )
                        )
                        compiledMacro:SetText(body)
                        if compiledMacro.parent and compiledMacro.parent.DoLayout then compiledMacro.parent:DoLayout() end
                    end
                    SetMacroCountText(macroEditBox, GSE.GetMacroEditorTextLength(value or ""))
                    UpdateMacroLimitState(macroEditBox, sequence.Versions[version].Actions[keyPath].macro, editframe, version)
                end
            )
            macroEditBox:SetCallback(
                "OnEditFocusLost",
                function(sel)
                    -- Apply translation + coloring on focus-loss, not every
                    -- keystroke. See matching comment in MacroToolbar.lua.
                    local storedMacro = sequence.Versions[version].Actions[keyPath].macro
                    if storedMacro and GSE.GUI and GSE.GUI.RefreshMacroEditorColoredText then
                        GSE.GUI.RefreshMacroEditorColoredText(sel, storedMacro)
                    end
                end
            )
            return spellEditBox, macroEditBox
        end
    end

    -- Expose helpers needed by the refactored tree module
    editframe.BuildVersionLabel = BuildVersionLabel
    editframe.GUIDrawMacroEditor = GUIDrawMacroEditor

    -- Install refactored modules ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â each overrides the matching editframe method
    -- with a cleanly separated implementation. The original closure versions above
    -- remain as a safety fallback and are superseded by these calls.
    GSE.GUI.SetupMetadata(editframe)
    GSE.GUI.SetupVariable(editframe)
    GSE.GUI.SetupKeybind(editframe)
    GSE.GUI.SetupMacro(editframe)
    GSE.GUI.SetupTree(editframe)

    function editframe:remoteSequenceUpdated(seqName)
        if seqName == editframe.SequenceName then
            if editframe.save then
                editframe.pendingSaveName = nil
                editframe:SetStatusText(seqName .. " " .. L["Saved"])
                editframe.save = nil
                if GSE.GUI.ResetUndo then GSE.GUI.ResetUndo(editframe) end
                C_Timer.After(
                    5,
                    function()
                        editframe:SetStatusText(editframe.statusText or ("GSE: " .. GSE.VersionString))
                    end
                )
            else
                editframe:SetStatusText(
                    seqName .. " " .. L["modified in other window.  This view is now behind the current sequence."]
                )
            end
        elseif seqName == editframe.pendingSaveName then
            editframe.pendingSaveName = nil
            editframe:SetStatusText(seqName .. " " .. L["Saved"])
            if GSE.GUI.ResetUndo then GSE.GUI.ResetUndo(editframe) end
            C_Timer.After(
                5,
                function()
                    editframe:SetStatusText(editframe.statusText or ("GSE: " .. GSE.VersionString))
                end
            )
        end
        editframe.ManageTree()
    end

    return editframe
end

function GSE.ShowSequences()
    if not InCombatLockdown() or (GSE.PlayerSpellsLoaded and GSE.PlayerSpellsLoaded()) then
        local editframe = GSE.CreateEditor()
        editframe.ManageTree()
        if GSE.HydrateLoadedSequenceActionIcons then GSE.HydrateLoadedSequenceActionIcons() end
        local lastSequencePath = GSE.GUI.GetLastSequenceEditorPath and GSE.GUI.GetLastSequenceEditorPath()
        local classID = tostring(GSE.GetCurrentClassID and GSE.GetCurrentClassID() or "")

        -- Restore the last-opened sequence. In "show all classes" mode the tree
        -- shows every class, so restore it regardless of the class/spec the player
        -- is currently on. In current-class mode the tree only shows the current
        -- class, so only restore the path when it belongs to the current class
        -- (otherwise it would not be visible); fall back to the current class.
        -- Paths look like "Sequences\001<classID>\001..." so check segment 2.
        local showingAllClasses = GSEOptions and GSEOptions.filterList and GSEOptions.filterList[Statics.All]
        if lastSequencePath and not showingAllClasses then
            local parts = {("\001"):split(lastSequencePath)}
            local pathClass = parts[2] and tostring(parts[2]) or ""
            if pathClass ~= classID then
                lastSequencePath = nil   -- wrong class, fall back to current class
            end
        end

        local selectPath = lastSequencePath or "Sequences\001NewSequence"
        local treeStatus = editframe.treeContainer.status or editframe.treeContainer.localstatus

        -- Attached opening rules: when the tree is DETACHED, a newly opened editor
        -- opens to wherever the detached tree is already working (e.g. DK Sequence 1)
        -- instead of refreshing the tree to the normal current-class/last sequence.
        -- It mirrors the detached tree's expansion + scroll and selects that node
        -- silently, so opening the window does not refresh or jump the floating menu.
        local adopted = false
        if GSE.GUI.navDetached and GSE.GUI.floatOwner and GSE.GUI.floatOwner ~= editframe then
            local srcTree   = GSE.GUI.floatOwner.treeContainer
            local srcStatus = srcTree and (srcTree.status or srcTree.localstatus)
            if srcStatus and srcStatus.selected then
                -- Mirror expansion + scroll (copy the table, don't share the reference)
                treeStatus.groups = treeStatus.groups or {}
                for k in pairs(treeStatus.groups) do treeStatus.groups[k] = nil end
                for k, v in pairs(srcStatus.groups or {}) do treeStatus.groups[k] = v end
                treeStatus.scrollvalue = srcStatus.scrollvalue or 0
                -- Open to the detached tree's current node, silently: SetSelected loads
                -- the editor content via OnGroupSelected without expanding/RefreshTree.
                editframe.forceTreeSelection = true
                if editframe.treeContainer.SetSelected then
                    editframe.treeContainer:SetSelected(srcStatus.selected)
                end
                -- One-shot: stop SyncTrees from RevealSelection-refreshing this tree
                -- when the float follows to it (its menu already matches the source).
                editframe.treeContainer.skipNextReveal = true
                adopted = true
            end
        end

        if not adopted then
            treeStatus.groups["Sequences"] = true
            if classID ~= "" then
                treeStatus.groups["Sequences\001" .. classID] = true
            end
            -- Also expand the class that owns the sequence we are selecting, so a
            -- last sequence on a different class (All-classes mode) is revealed.
            if lastSequencePath then
                local lp = {("\001"):split(lastSequencePath)}
                if lp[2] and lp[2] ~= "" then
                    treeStatus.groups["Sequences\001" .. tostring(lp[2])] = true
                end
            end
            if GSE.GUI.SelectEditorTreePath then
                GSE.GUI.SelectEditorTreePath(editframe, selectPath)
            else
                editframe.treeContainer:SelectByValue(selectPath)
            end
        end

        -- Restore last non-sequence area (Variables, Macros, Keybindings) if that was last open
        local seOpts = GSEOptions and GSEOptions.frameLocations and GSEOptions.frameLocations.sequenceeditor
        local lastArea = seOpts and seOpts.lastArea
        if lastArea and lastArea ~= "Sequences" and editframe.RestoreLastNode then
            C_Timer.After(0.1, function() editframe.RestoreLastNode() end)
        end

        SetSequenceEditorOpenPreference(true, "sequences")
        editframe:Show()
    else
        GSE.Print(
            L[
                "You cannot open a new Sequence Editor window while you are in combat.  Please exit combat and then try again."
            ],
            Statics.DebugModules["Editor"]
        )
    end
end

local function remoteSeqences(message, seqName)
    if message == Statics.Messages.SEQUENCE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function remoteVariables(message, seqName)
    if message == Statics.Messages.VARIABLE_UPDATED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v:remoteSequenceUpdated(seqName)
            end
        end
    end
end

local function collectionImported(message)
    if message == Statics.Messages.COLLECTION_IMPORTED then
        if GSE.GUI.editors and #GSE.GUI.editors > 0 then
            for _, v in ipairs(GSE.GUI.editors) do
                v.ManageTree()
            end
        end
    end
end

GSE:RegisterMessage(Statics.Messages.SEQUENCE_UPDATED, remoteSeqences)
GSE:RegisterMessage(Statics.Messages.VARIABLE_UPDATED, remoteVariables)
GSE:RegisterMessage(Statics.Messages.COLLECTION_IMPORTED, collectionImported)

--- Create a brand-new sequence with the given name and navigate to it.
-- Called by the GSE_NEW_SEQUENCE_NAME StaticPopup OnAccept / Enter handler.
function GSE.GUICreateNewSequence(editor, name, recordedstring)
    local classid = GSE.GetCurrentClassID()
    local sequence = {
        ["MetaData"] = {
            ["Author"]     = GSE.GetCharacterName(),
            ["Default"]    = 1,
            ["SpecID"]     = GSE.GetCurrentSpecID(),
            ["GSEVersion"] = GSE.VersionString,
            ["Name"]       = name,
        },
        ["Versions"] = {
            [1] = {
                ["Actions"] = {
                    [1] = { ["macro"] = "Need Stuff Here", ["type"] = "macro", ["Type"] = Statics.Actions.Action }
                }
            }
        }
    }
    if not GSE.isEmpty(recordedstring) then
        sequence.Versions[1]["Actions"] = nil
        local recordedMacro = {}
        for _, v in ipairs(GSE.SplitMeIntoLines(recordedstring)) do
            local spellid = GSE.TranslateString(v, Statics.TranslatorMode.ID)
            if spellid then
                table.insert(recordedMacro, { ["Type"] = Statics.Actions.Action, ["type"] = "macro", ["macro"] = spellid })
            end
        end
        sequence.Versions[1]["Actions"] = recordedMacro
    end
    if GSE.isEmpty(sequence.WeakAuras) then sequence.WeakAuras = {} end
    GSESequences[classid][name] = GSE.EncodeMessage({name, sequence})
    GSE.Library[classid][name]  = sequence
    editor:SetStatusText("GSE: " .. GSE.VersionString)
    editor.SequenceName     = name
    editor.OrigSequenceName = name
    editor.newname          = nil
    editor.Sequence         = sequence
    editor.ClassID          = classid
    if GSE.GUI.ResetUndo then GSE.GUI.ResetUndo(editor) end
    editor.ManageTree()
    editor.treeContainer:SelectByValue(
        table.concat({"Sequences", classid, classid .. "," .. GSE.GetCurrentSpecID() .. "," .. name .. ",0", "config"}, "\001")
    )
end

--- Duplicate an existing sequence under a user-supplied name and navigate to it.
-- Called by the GSE_DUPLICATE_SEQUENCE_NAME StaticPopup OnAccept / Enter handler.
function GSE.GUIDuplicateSequence(editor, classid, sourceName, newName)
    classid = tonumber(classid) or GSE.GetCurrentClassID()
    local normalised = (newName or ""):gsub(" ", "_"):gsub(",", "_")
    if GSE.isEmpty(normalised) then return end
    if not GSE.isEmpty(GSE.Library[classid] and GSE.Library[classid][normalised]) then
        GSE.Print(
            string.format(L["Sequence Name %s is in Use. Please choose a different name."], normalised),
            "ERROR"
        )
        return
    end
    local created = GSE.DuplicateSequence(classid, sourceName, normalised)
    if GSE.isEmpty(created) then return end
    for _, v in ipairs(GSE.GUI.editors) do
        if v.ManageTree then v.ManageTree() end
    end
    if editor and editor.treeContainer and editor.treeContainer.SelectByValue then
        local meta = GSE.Library[classid][created] and GSE.Library[classid][created].MetaData
        local specid = (meta and meta.SpecID) or GSE.GetCurrentSpecID()
        editor.treeContainer:SelectByValue(
            table.concat({"Sequences", classid, classid .. "," .. specid .. "," .. created .. ",0", "config"}, "\001")
        )
    end
end

--- Create a brand-new variable with the given name and navigate to it.
-- Called by the GSE_NEW_VARIABLE_NAME StaticPopup OnAccept / Enter handler.
function GSE.GUICreateNewVariable(editor, name)
    local defaultVariable = {
        ["funct"]    = "function()\n    return true\nend",
        ["comments"] = "",
        ["Author"]   = GSE.GetCharacterName(),
    }
    GSE.UpdateVariable(defaultVariable, name)
    editor.ManageTree()
    editor.treeContainer:SelectByValue("VARIABLES\001" .. name)
end

function GSE.GUILoadEditor(editor, key, recordedstring)
    if GSE.isEmpty(key) then
        GSE.UI.ShowInputDialog({
            owner    = editor,
            title    = L["New"] .. " " .. L["GSE Sequence"],
            prompt   = L["Enter a Name for the New Sequence"],
            note     = L["-sequence will receive a new gse.tools id-"],
            acceptText = L["Create"],
            maxLetters = 60,
            onAccept = function(name)
                GSE.GUICreateNewSequence(editor, name, recordedstring)
            end,
        })
        return
    end

    local elements = GSE.split(key, ",")
    local classid = tonumber(elements[1])
    local sequenceName = elements[3]

    local _, seq = GSE.DecodeMessage(GSESequences[classid][sequenceName])
    local sequence
    if seq then
        sequence = seq[2]
    end

    if GSE.isEmpty(sequence.WeakAuras) then
        sequence.WeakAuras = {}
    end
    editor:SetStatusText("GSE: " .. GSE.VersionString)
    editor.SequenceName = sequenceName
    editor.OrigSequenceName = sequenceName
    editor.newname = nil
    editor.Sequence = sequence
    editor.ClassID = classid
    if GSE.GUI.ResetUndo then GSE.GUI.ResetUndo(editor) end
end

function GSE.ShowKeyBindings()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    local treeStatus = editor.treeContainer.status or editor.treeContainer.localstatus
    if treeStatus and treeStatus.groups then
        treeStatus.groups["KEYBINDINGS"] = true
        treeStatus.groups["KEYBINDINGS\001AO"] = true
        treeStatus.groups["KEYBINDINGS\001KB"] = true
    end
    editor.treeContainer:SelectByValue("KEYBINDINGS")
    SetSequenceEditorOpenPreference(true, "keybindings")
    editor:Show()
end

function GSE.ShowVariables()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("VARIABLES")
    SetSequenceEditorOpenPreference(true, "variables")
    editor:Show()
end

function GSE.ShowMacros()
    local editor = GSE.CreateEditor()
    editor.ManageTree()
    editor.treeContainer:SelectByValue("Macro")
    SetSequenceEditorOpenPreference(true, "macros")
    editor:Show()
end

local function RestoreSequenceEditorIfNeeded()
    local seOpts = EnsureSequenceEditorRestoreOptions()
    if not seOpts.open then
        GSE.SequenceEditorRestoreFired = true
        return
    end

    -- Re-entry guard: if an editor already exists at this point, the slash
    -- handler raced ahead of this deferred restore (it can land first when
    -- `seOpts.open` was false at slash time but `ShowSequences` flipped it
    -- true via SetSequenceEditorOpenPreference as a side effect). Bring the
    -- existing editor forward rather than creating a second one.
    if GSE.GUI and GSE.GUI.editors and #GSE.GUI.editors > 0 then
        local existing = GSE.GUI.editors[#GSE.GUI.editors]
        if existing and existing.Show then existing:Show() end
        GSE.SequenceEditorRestoreFired = true
        return
    end

    if seOpts.openMode == "keybindings" then
        GSE.ShowKeyBindings()
    elseif seOpts.openMode == "variables" then
        GSE.ShowVariables()
    elseif seOpts.openMode == "macros" then
        GSE.ShowMacros()
    else
        GSE.ShowSequences()
    end
    GSE.SequenceEditorRestoreFired = true
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, RestoreSequenceEditorIfNeeded)
else
    RestoreSequenceEditorIfNeeded()
end
end
table.insert(ns.deferred, setup)
