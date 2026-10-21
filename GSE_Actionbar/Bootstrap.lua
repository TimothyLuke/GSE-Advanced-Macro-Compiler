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

-- The bars' settings, kept by GSE itself (GSE.ActionBarOptions), as GSE's
-- options show them while the bar is off too.
function ns.Options()
    return ns.GSE.ActionBarOptions()
end

function GSE_Actionbar_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
