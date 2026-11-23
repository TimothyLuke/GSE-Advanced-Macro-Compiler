local _, ns = ...
ns.deferred = ns.deferred or {}

-- GSE's in-game help, in an AddOn of its own: it is loaded the first time help
-- is asked for (LoadOnDemand; GSE.CheckHelp, GSE's Events.lua), so it costs a
-- loading screen nothing, and it can be turned off in the AddOn list. Each
-- file registers its body in ns.deferred; main GSE hands its table over on
-- ADDON_LOADED and they run in TOC order.
function GSE_Help_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
