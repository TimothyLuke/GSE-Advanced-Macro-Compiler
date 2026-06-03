local _, ns = ...
ns.deferred = ns.deferred or {}

-- Entry point called by the main GSE addon once it has loaded.
-- See GSE/API/Init.lua: pushGSEInto / ADDON_LOADED dispatcher.
--
-- Each Lua file in this submodule wraps its body in `local function setup()`
-- and registers it via `table.insert(ns.deferred, setup)`. We invoke them in
-- TOC parse order with the private GSE table bound first.
--
-- Silent reinit guard: if anything calls _Initialize a second time, we drop
-- it on the floor rather than re-running setups or overwriting the bound
-- GSE reference.
function GSE_Utils_Initialize(gse)
    if ns.GSE then return end
    ns.GSE = gse
    local queue = ns.deferred
    ns.deferred = nil
    for _, fn in ipairs(queue) do
        fn()
    end
end
