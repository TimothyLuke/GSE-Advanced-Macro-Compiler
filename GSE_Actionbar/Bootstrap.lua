local _, ns = ...
ns.deferred = ns.deferred or {}

-- Buttons 1-12 are the first bar, 13-24 the second. Bindings.xml declares a
-- binding for each, by these names.
ns.BUTTON_COUNT, ns.BAR_SIZE = 24, 12

function ns.ButtonName(index)
    return "GSEButton" .. index
end

function ns.BindingCommand(index)
    return "CLICK GSEButton" .. index .. ":LeftButton"
end

-- The button a binding command clicks, or nil when it is not one of ours.
function ns.ButtonForCommand(command)
    return tonumber(string.match(command or "", "^CLICK GSEButton(%d+):LeftButton$"))
end

-- What the bars are set to, account-wide: GSEOptions.ActionBar, with anything
-- missing filled in. Per bar: Visibility is SHOW, INCOMBAT, OUTOFCOMBAT,
-- MOUSEOVER or HIDE; Orientation HORIZONTAL or VERTICAL; Icons how many of its
-- twelve buttons it has; Spacing, ShowEmpty and ShowKeys its icon padding,
-- whether it shows empty buttons and keys. A hidden bar's keys still work.
-- ReportOverrides: say in chat when an override takes a button's key
-- (Overrides.lua).
local DEFAULTS = {
    Locked = true,
    ReportOverrides = true,
    -- key -> the button GSE moved it onto (Migration.lua), so every
    -- character of the account puts a key on the same button.
    KeyButtons = {},
    Bars = {
        [1] = { Visibility = "SHOW", Scale = 1, PerRow = 12, Icons = 12, Orientation = "HORIZONTAL",
            Spacing = 4, ShowEmpty = true, ShowKeys = true },
        [2] = { Visibility = "HIDE", Scale = 1, PerRow = 12, Icons = 12, Orientation = "HORIZONTAL",
            Spacing = 4, ShowEmpty = true, ShowKeys = true },
    },
}

local function fillDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            fillDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns.Options()
    if type(GSEOptions.ActionBar) ~= "table" then GSEOptions.ActionBar = {} end
    local options = GSEOptions.ActionBar
    -- Icon padding, empty buttons and keys were once one setting for every
    -- bar: each bar starts from it.
    for _, key in ipairs({ "Spacing", "ShowEmpty", "ShowKeys" }) do
        if options[key] ~= nil then
            if type(options.Bars) ~= "table" then options.Bars = {} end
            for b = 1, #DEFAULTS.Bars do
                if type(options.Bars[b]) ~= "table" then options.Bars[b] = {} end
                if options.Bars[b][key] == nil then options.Bars[b][key] = options[key] end
            end
            options[key] = nil
        end
    end
    fillDefaults(options, DEFAULTS)
    -- GSE turned the bar on by itself, for keybinds it had (GSE's Events.lua):
    -- the bars start hidden, their keys working.
    if GSEOptions.ActionBarStartHidden then
        for _, bar in ipairs(options.Bars) do bar.Visibility = "HIDE" end
        GSEOptions.ActionBarStartHidden = nil
    end
    return options
end

-- A bar's buttons sit in lines: rows, or columns when it is vertical. The bar
-- keeps PerRow, buttons per line; Edit Mode (EditMode.lua) and GSE's options
-- both set it as a number of lines, as Blizzard's bars do.

--- How many of its twelve buttons bar b has.
function ns.IconCount(b)
    return math.max(1, math.min(ns.BAR_SIZE, tonumber(ns.Options().Bars[b].Icons) or ns.BAR_SIZE))
end

--- How many lines bar b's buttons sit in.
function ns.Lines(b)
    local perLine = math.max(1, tonumber(ns.Options().Bars[b].PerRow) or ns.BAR_SIZE)
    return math.ceil(ns.IconCount(b) / perLine)
end

--- Put bar b's buttons in `lines` lines.
function ns.SetLines(b, lines)
    ns.Options().Bars[b].PerRow = math.ceil(ns.IconCount(b) / math.max(1, lines))
end

function GSE_Actionbar_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    -- For GSE's options, which set these once the bar is loaded.
    gse.ActionBarOptions, gse.ActionBarLines, gse.SetActionBarLines = ns.Options, ns.Lines, ns.SetLines
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
