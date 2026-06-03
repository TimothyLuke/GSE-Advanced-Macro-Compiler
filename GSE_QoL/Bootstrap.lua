local _, ns = ...
ns.deferred = ns.deferred or {}

function GSE_QoL_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
