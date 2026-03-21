local GSE = GSE
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

GSE.DebugProfile("Plugins")
