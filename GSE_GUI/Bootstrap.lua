local _, ns = ...
ns.deferred = ns.deferred or {}

-- Entry point called by the main GSE addon once GSE_GUI loads. See
-- GSE/API/Init.lua's ADDON_LOADED dispatcher. Each Lua file in this
-- submodule wraps its body in `local function setup()` and registers it
-- via `table.insert(ns.deferred, setup)`. Setup runs in TOC parse order
-- with the private GSE table bound first. The reinit guard silently drops
-- repeated _Initialize calls.
function GSE_GUI_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
