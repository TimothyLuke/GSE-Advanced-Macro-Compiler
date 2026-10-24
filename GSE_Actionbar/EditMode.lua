local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L

-- ── The bars in WoW's Edit Mode ─────────────────────────────────────────────
--
-- On Retail and Forever (GSE.ActionBarUsesEditMode) each bar is placed and
-- set up in Edit Mode, beside WoW's own bars, through LibEditMode -- which the
-- TOC loads on those clients only. GSE's options then have no Lock for them.
--
-- A bar's place is kept per Edit Mode layout, as WoW's own bars' are:
-- Bars[b].Layouts[layout name] = { point, x, y } against UIParent. A layout
-- with no place for it yet has the one it had before (Bars[b].Point). What a
-- bar shows and its size are one setting for every layout, the same ones
-- GSE's options show.
local LEM = LibStub("LibEditMode", true)
if not LEM or not GSE.ActionBarUsesEditMode() then return end
ns.editMode = true

local BAR_COUNT = ns.BUTTON_COUNT / ns.BAR_SIZE

local function barOptions(b)
    return ns.Options().Bars[b]
end

local function layouts(b)
    local bar = barOptions(b)
    if type(bar.Layouts) ~= "table" then bar.Layouts = {} end
    return bar.Layouts
end

--- Where the active Edit Mode layout puts bar b, or nil where it has no place
--- for it yet. Read by the bar's layout (ActionBar.lua).
function ns.EditModePoint(b)
    local name = LEM:GetActiveLayoutName()
    local saved = name and layouts(b)[name]
    if type(saved) ~= "table" then return nil end
    return { saved[1], "UIParent", saved[1], saved[2], saved[3] }
end

-- Blizzard's own names for an action bar's settings, so the box reads like
-- theirs in every language.
local VISIBILITY = {
    { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_ALWAYS, value = "SHOW" },
    { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_IN_COMBAT, value = "INCOMBAT" },
    { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_OUT_OF_COMBAT, value = "OUTOFCOMBAT" },
    { text = L["On mouseover"], value = "MOUSEOVER" },
    { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_HIDDEN, value = "HIDE" },
}

-- How many buttons the bar has, and how many lines (rows, or columns when
-- vertical) they sit in. The bar keeps PerRow -- buttons per line -- as GSE's
-- options set it; Edit Mode speaks in lines, as Blizzard's does.
local function iconCount(b)
    return math.max(1, math.min(ns.BAR_SIZE, tonumber(barOptions(b).Icons) or ns.BAR_SIZE))
end
local function lineCount(b)
    local perLine = math.max(1, tonumber(barOptions(b).PerRow) or ns.BAR_SIZE)
    return math.ceil(iconCount(b) / perLine)
end
local function setLines(b, lines)
    barOptions(b).PerRow = math.ceil(iconCount(b) / math.max(1, lines))
end

local function settingsFor(b)
    local function set(key)
        return function(_, value)
            barOptions(b)[key] = value
            ns.Refresh()
        end
    end
    local function linesName()
        return barOptions(b).Orientation == "VERTICAL" and _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS
            or _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS
    end
    local lines = {
        kind = LEM.SettingType.Slider,
        name = linesName(),
        default = 1,
        minValue = 1, maxValue = 4, valueStep = 1,
        get = function() return math.min(4, lineCount(b)) end,
        set = function(_, value)
            setLines(b, value)
            ns.Refresh()
        end,
    }
    return {
        {
            kind = LEM.SettingType.Dropdown,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION,
            default = "HORIZONTAL",
            values = {
                { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_HORIZONTAL, value = "HORIZONTAL" },
                { text = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_VERTICAL, value = "VERTICAL" },
            },
            get = function() return barOptions(b).Orientation or "HORIZONTAL" end,
            set = function(_, value)
                barOptions(b).Orientation = value
                -- Rows become columns.
                lines.name = linesName()
                ns.Refresh()
                LEM:RefreshFrameSettings(ns.bars[b])
            end,
        },
        lines,
        {
            kind = LEM.SettingType.Slider,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ICONS,
            default = ns.BAR_SIZE,
            minValue = 6, maxValue = ns.BAR_SIZE, valueStep = 1,
            get = function() return iconCount(b) end,
            set = function(_, value)
                -- The lines stay as they were, as on Blizzard's bars.
                local keep = lineCount(b)
                barOptions(b).Icons = value
                setLines(b, keep)
                ns.Refresh()
            end,
        },
        {
            kind = LEM.SettingType.Slider,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_SIZE,
            default = 100,
            minValue = 50, maxValue = 200, valueStep = 10,
            formatter = function(value) return string.format("%d%%", value) end,
            get = function() return math.floor((tonumber(barOptions(b).Scale) or 1) * 100 + 0.5) end,
            set = function(_, value)
                barOptions(b).Scale = value / 100
                ns.Refresh()
            end,
        },
        {
            -- For every bar, as in GSE's options.
            kind = LEM.SettingType.Slider,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_PADDING,
            desc = L["The gap between buttons."],
            default = 4,
            minValue = 0, maxValue = 20, valueStep = 1,
            get = function() return tonumber(ns.Options().Spacing) or 4 end,
            set = function(_, value)
                ns.Options().Spacing = value
                ns.Refresh()
            end,
        },
        {
            kind = LEM.SettingType.Dropdown,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING,
            desc = L["A bar that is not shown still works: its buttons' keys run their sequences. It shows while a sequence is being dragged, to drop it on."],
            default = "SHOW",
            values = VISIBILITY,
            get = function() return barOptions(b).Visibility or "SHOW" end,
            set = set("Visibility"),
        },
        {
            -- For every bar, as in GSE's options.
            kind = LEM.SettingType.Checkbox,
            name = _G.HUD_EDIT_MODE_SETTING_ACTION_BAR_ALWAYS_SHOW_BUTTONS,
            desc = L["Show buttons with no sequence on them. They always show while a sequence is being dragged."],
            default = true,
            get = function() return ns.Options().ShowEmpty == true end,
            set = function(_, value)
                ns.Options().ShowEmpty = value and true or false
                ns.Refresh()
            end,
        },
        {
            -- For every bar. GSE's own: WoW has no such setting.
            kind = LEM.SettingType.Checkbox,
            name = L["Show keys"],
            desc = L["Show on each button the key WoW's Key Bindings give it."],
            default = true,
            get = function() return ns.Options().ShowKeys == true end,
            set = function(_, value)
                ns.Options().ShowKeys = value and true or false
                ns.Refresh()
            end,
        },
    }
end

-- What the bars were set to when Edit Mode opened, for Revert Changes.
local snapshot
local function takeSnapshot()
    local options = ns.Options()
    snapshot = { Spacing = options.Spacing, ShowEmpty = options.ShowEmpty, ShowKeys = options.ShowKeys,
        Bars = _G.CopyTable(options.Bars) }
end
local function revertChanges()
    if not snapshot then return end
    local options = ns.Options()
    options.Spacing, options.ShowEmpty, options.ShowKeys = snapshot.Spacing, snapshot.ShowEmpty, snapshot.ShowKeys
    for b = 1, BAR_COUNT do
        if type(snapshot.Bars[b]) == "table" then options.Bars[b] = _G.CopyTable(snapshot.Bars[b]) end
    end
    ns.Refresh()
    for b = 1, BAR_COUNT do LEM:RefreshFrameSettings(ns.bars[b]) end
end

-- Leave Edit Mode the way Blizzard's own action bar buttons do (kept open
-- underneath, back when what was opened closes), then open what was asked.
-- No Quick Keybind Mode or Action Bar Settings button: those close Edit Mode
-- the way Blizzard's own buttons do, which from addon code runs tainted and
-- breaks it on Retail. Blizzard's bars' boxes have the Quick Keybind button,
-- and GSE's buttons take part in that mode.
local buttonsForBar = {
    { text = _G.HUD_EDIT_MODE_REVERT_CHANGES, click = revertChanges },
}

-- The box's label is the bar's name, one line; on a bar too narrow for it,
-- one word group per line -- GSE / Action Bar / 2 -- centred.
local function labelFor(b, selection)
    local name = string.format(L["GSE Action Bar %d"], b)
    local label = selection.Label
    if not (label and label.GetUnboundedStringWidth) then return name end
    label:SetText(name)
    -- The label ignores the bar's scale and the box does not: compare on screen.
    local textWidth = label:GetUnboundedStringWidth() * label:GetEffectiveScale()
    if textWidth <= selection:GetWidth() * selection:GetEffectiveScale() then return name end
    return string.format(L["GSE\nAction Bar\n%d"], b)
end

for b = 1, BAR_COUNT do
    local bar = ns.bars[b]
    local start = ns.DEFAULT_POINTS[b]
    LEM:AddFrame(bar, function(_, layoutName, point, x, y)
        if layoutName then layouts(b)[layoutName] = { point, x, y } end
    end, { point = start[1], x = start[4], y = start[5] }, string.format(L["GSE Action Bar %d"], b))
    LEM:AddFrameSettings(bar, settingsFor(b))
    LEM:AddFrameSettingsButtons(bar, buttonsForBar)
    local selection = LEM.frameSelections and LEM.frameSelections[bar]
    if selection and selection.GetLabelText then
        local own = selection.GetLabelText
        function selection:GetLabelText()
            if self:IsSelected() then return labelFor(b, self) end
            return own(self)
        end
        if selection.Label and selection.Label.SetJustifyH then selection.Label:SetJustifyH("CENTER") end
    end
end

-- Open, every bar shows to be placed, a hidden one too.
-- A setting that resizes a bar re-fits its label at once.
hooksecurefunc(ns, "Refresh", function()
    for b = 1, BAR_COUNT do
        local selection = LEM.frameSelections and LEM.frameSelections[ns.bars[b]]
        if selection and selection:IsShown() and selection.UpdateLabelVisibility then selection:UpdateLabelVisibility() end
    end
end)
LEM:RegisterCallback("enter", function()
    takeSnapshot()
    ns.SetEditing(true)
end)
LEM:RegisterCallback("exit", function() ns.SetEditing(false) end)
-- Another layout: the bars go where it has them. Also once at login, when
-- WoW says which layout is active.
LEM:RegisterCallback("layout", function() ns.Refresh() end)
-- A layout copied from another starts with the bars where that one has them;
-- a renamed one keeps them; a deleted one's places go with it.
LEM:RegisterCallback("create", function(name, _, source)
    if not source then return end
    for b = 1, BAR_COUNT do
        local from = layouts(b)[source]
        if type(from) == "table" then layouts(b)[name] = { from[1], from[2], from[3] } end
    end
end)
LEM:RegisterCallback("rename", function(old, new)
    for b = 1, BAR_COUNT do
        local places = layouts(b)
        places[new], places[old] = places[old], nil
    end
end)
LEM:RegisterCallback("delete", function(name)
    for b = 1, BAR_COUNT do layouts(b)[name] = nil end
end)

ns.Refresh()
end
table.insert(ns.deferred, setup)
