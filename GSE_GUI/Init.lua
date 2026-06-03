local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
GSE.UnsavedOptions["GUI"] = true
end
table.insert(ns.deferred, setup)
