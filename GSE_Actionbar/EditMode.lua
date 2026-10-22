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

local function settingsFor(b)
    local function set(key)
        return function(_, value)
            barOptions(b)[key] = value
            ns.Refresh()
        end
    end
    return {
        {
            kind = LEM.SettingType.Dropdown,
            name = L["Show the bar"],
            desc = L["A bar that is not shown still works: its buttons' keys run their sequences. It shows while a sequence is being dragged, to drop it on."],
            default = "SHOW",
            values = {
                { text = L["Always"], value = "SHOW" },
                { text = L["On mouseover"], value = "MOUSEOVER" },
                { text = L["Never"], value = "HIDE" },
            },
            get = function() return barOptions(b).Visibility or "SHOW" end,
            set = set("Visibility"),
        },
        {
            kind = LEM.SettingType.Slider,
            name = L["Buttons per row"],
            desc = L["How many buttons each row of the bar holds."],
            default = ns.BAR_SIZE,
            minValue = 1, maxValue = ns.BAR_SIZE, valueStep = 1,
            get = function() return tonumber(barOptions(b).PerRow) or ns.BAR_SIZE end,
            set = set("PerRow"),
        },
        {
            kind = LEM.SettingType.Slider,
            name = L["Scale"],
            desc = L["The size of the bar."],
            default = 1,
            minValue = 0.5, maxValue = 2, valueStep = 0.05,
            formatter = function(value) return string.format("%.2f", value) end,
            get = function() return tonumber(barOptions(b).Scale) or 1 end,
            set = set("Scale"),
        },
        {
            -- For every bar, as in GSE's options.
            kind = LEM.SettingType.Slider,
            name = L["Button spacing"],
            desc = L["The gap between buttons."],
            default = 4,
            minValue = 0, maxValue = 20, valueStep = 1,
            get = function() return tonumber(ns.Options().Spacing) or 4 end,
            set = function(_, value)
                ns.Options().Spacing = value
                ns.Refresh()
            end,
        },
    }
end

for b = 1, BAR_COUNT do
    local bar = ns.bars[b]
    local start = ns.DEFAULT_POINTS[b]
    LEM:AddFrame(bar, function(_, layoutName, point, x, y)
        if layoutName then layouts(b)[layoutName] = { point, x, y } end
    end, { point = start[1], x = start[4], y = start[5] }, string.format(L["GSE Action Bar %d"], b))
    LEM:AddFrameSettings(bar, settingsFor(b))
end

-- Open, every bar shows to be placed, a hidden one too.
LEM:RegisterCallback("enter", function() ns.SetEditing(true) end)
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
