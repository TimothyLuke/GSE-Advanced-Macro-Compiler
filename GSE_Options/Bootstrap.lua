local _, ns = ...
ns.deferred = ns.deferred or {}

-- See GSE/API/Init.lua's ADDON_LOADED dispatcher and
-- GSE_Utils/Bootstrap.lua for the shape of this pattern.
function GSE_Options_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
