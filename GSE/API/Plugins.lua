local _, GSE = ...
local L = GSE.L
local Statics = GSE.Static

-- --- List addons that GSE knows about that have been disabled
-- function GSE.ListUnloadedAddons()
--     local returnVal = "";
--     for k,_ in pairs(GSE.UnloadedAddInPacks) do
--         local _,atitle,anotes,_,_,_ = GetAddOnInfo(k)
--         returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r ' .. anotes .. '\n\n'
--     end
--     return returnVal
-- end

--- List addons that GSE knows about that have been enabled
-- function GSE.ListAddons()
--  local returnVal = "";
--  for k,v in pairs(GSE.AddInPacks) do
--    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
--    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
--  end
--  return returnVal
-- end

function GSE.RegisterAddon(name, version, sequencenames, sequencetable)
    local updateflag = false
    if GSE.isEmpty(GSE.AddInPacks) then
        GSE.AddInPacks = {}
    end
    if GSE.isEmpty(GSE.AddInPacks[name]) then
        GSE.AddInPacks[name] = {}
        GSE.AddInPacks[name].Name = name
    end
    if GSE.isEmpty(GSEOptions.AddInPacks) then
        GSEOptions.AddInPacks = {}
    end
    if GSE.isEmpty(GSEOptions.AddInPacks[name]) then
        GSEOptions.AddInPacks[name] = {}
        GSEOptions.AddInPacks[name].Name = name
    end

    if GSE.isEmpty(GSEOptions.AddInPacks[name].Version) then
        updateflag = true
        GSEOptions.AddInPacks[name].Version = version
    elseif GSEOptions.AddInPacks[name].Version ~= version then
        updateflag = true
        GSEOptions.AddInPacks[name].Version = version
    end
    GSE.AddInPacks[name].SequenceNames = sequencenames
    if sequencetable then
        GSE.AddInPacks[name].Sequences = sequencetable
        -- On first load or version change GSE handles the import directly so the
        -- plugin does not need its own ReloadMessage handler.
        if updateflag then
            GSE.LoadPluginSequences(sequencetable)
        end
    end
    return updateflag
end

--- Import every sequence in a plugin's sequences table and trigger a reload.
-- Called automatically on first/version-change load and from the "Reload All"
-- button when the plugin has supplied its Sequences table.
function GSE.LoadPluginSequences(sequencetable)
    for _, seq in pairs(sequencetable) do
        GSE.ImportSerialisedSequence(seq, false)
    end
    GSE.PerformReloadSequences()
end

--- Decode a single plugin sequence and return its compatibility status.
-- Returns a table:
--   compatible  (bool)   - GSEVersion is in the valid range for this client
--   GSEVersion  (number) - the sequence's GSEVersion, or nil if unreadable
--   checksum    (string) - "valid", "invalid", or "no_checksum"
function GSE.GetPluginSequenceStatus(encodedSeq)
    local result = {compatible = false, GSEVersion = nil, checksum = "no_checksum"}
    if not encodedSeq then return result end
    local ok, decoded
    if type(encodedSeq) == "table" then
        ok, decoded = true, encodedSeq
    else
        ok, decoded = GSE.DecodeMessage(encodedSeq)
    end
    if not ok or not decoded then return result end
    local meta = decoded.MetaData
    if not meta then return result end
    result.GSEVersion = meta.GSEVersion
    result.compatible = meta.GSEVersion ~= nil
        and meta.GSEVersion > 3200
        and meta.GSEVersion <= GSE.VersionNumber
    if result.compatible and GSE.VerifySequenceChecksum then
        local cs = GSE.VerifySequenceChecksum(decoded)
        if cs == true then
            result.checksum = "valid"
        elseif cs == false then
            result.checksum = "invalid"
        else
            result.checksum = "no_checksum"
        end
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Legacy plugin compatibility shim
--
-- Other addons (out of our control) still do `local GSE = GSE` at parse-time
-- and call `GSE.RegisterAddon(...)` / `GSE.GetSequenceNamesFromLibrary(...)`
-- to register their bundled sequence packs. Since we removed the global GSE,
-- those plugins would silently no-op (their nil-guard would print the
-- "requires GSE3" warning and `return`).
--
-- Expose a minimal public proxy at `_G.GSE` carrying ONLY the two functions
-- those plugins need for registration. Everything else on the private GSE
-- namespace (L, Static, Library, isEmpty, internal helpers, event mixins …)
-- is deliberately absent — the proxy isn't a leak; it's a contract surface.
--
-- Writes are silently dropped so a stray `GSE.foo = bar` in a third-party
-- addon can't clobber our exposed methods or accidentally graft state onto
-- the proxy. setmetatable is locked so the proxy can't be re-tabled either.
-- ---------------------------------------------------------------------------
local publicProxy = {
    RegisterAddon = GSE.RegisterAddon,
    GetSequenceNamesFromLibrary = GSE.GetSequenceNamesFromLibrary,
    -- isEmpty is the nil-guard helper plugins use to defend their own
    -- Sequences table before handing it to RegisterAddon. Without it the
    -- registration handshake errors before it reaches the two methods above.
    isEmpty = GSE.isEmpty,
    Statics = {}
}
setmetatable(publicProxy, {
    __newindex = function() end,
    __metatable = false,
})
rawset(_G, "GSE", publicProxy)

GSE.DebugProfile("Plugins")
