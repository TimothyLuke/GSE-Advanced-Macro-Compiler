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

--- Every sequence carried by one plugin entry, whatever shape it arrived in.
--
-- Three shapes reach here. A bare sequence has MetaData at the top. The
-- on-disk form is the {name, sequence} tuple, so its MetaData is at [2]. And a
-- plugin can ship a COLLECTION, which is {type = "COLLECTION", payload =
-- {Sequences = {[name] = sequence}}} -- a wrapper with no MetaData of its own,
-- because the version and the checksum belong to the sequences inside it.
--
-- Members are usually strings rather than tables, and a website export seals
-- them, so most are !GSE3!+. Decode them anyway: GSE.DecodeMessage dispatches
-- the packed envelope to DecodePackedMessage, and the addon HAS that key --
-- being unable to read one is a Companion problem, not ours. Skipping them
-- was what left a collection with nothing to judge and reported every
-- sequence in it as "unknown".
local function pluginSequenceMembers(decoded)
    if type(decoded) ~= "table" then return {} end

    if decoded.type == "COLLECTION" then
        local out = {}
        local payload = decoded.payload
        local sequences = type(payload) == "table" and payload.Sequences or nil
        if type(sequences) ~= "table" then return out end
        for _, member in pairs(sequences) do
            if type(member) == "table" then
                out[#out + 1] = member
            elseif type(member) == "string" then
                local memberOk, memberDecoded = GSE.DecodeMessage(member)
                -- A member can decode to the {name, sequence} tuple as well as
                -- to the sequence itself.
                if memberOk and type(memberDecoded) == "table" then
                    if type(memberDecoded[2]) == "table" and type(memberDecoded[2].MetaData) == "table" then
                        out[#out + 1] = memberDecoded[2]
                    else
                        out[#out + 1] = memberDecoded
                    end
                end
            end
        end
        return out
    end

    -- {name, sequence}: the array form, metadata one level down.
    if type(decoded[2]) == "table" and type(decoded[2].MetaData) == "table" then
        return {decoded[2]}
    end

    if type(decoded.MetaData) == "table" then return {decoded} end
    return {}
end

--- Decode a plugin entry and return its compatibility status.
-- Returns a table:
--   compatible  (bool)   - GSEVersion is in the valid range for this client
--   GSEVersion  (number) - the sequence's GSEVersion, or nil if unreadable
--   checksum    (string) - "valid", "invalid", or "no_checksum"
--
-- For a collection these describe every sequence in it together: compatible
-- only when they all are, and the checksum is "invalid" if ANY member fails --
-- one good sequence must not vouch for a bad one. GSEVersion reports the
-- LOWEST found, since that is the one that decides compatibility.
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

    local members = pluginSequenceMembers(decoded)
    if #members == 0 then return result end

    local allCompatible = true
    local anyInvalid, allValid = false, true
    for _, sequence in ipairs(members) do
        local meta = sequence.MetaData
        local version = type(meta) == "table" and meta.GSEVersion or nil
        if result.GSEVersion == nil or (version ~= nil and version < result.GSEVersion) then
            result.GSEVersion = version
        end
        -- Same rule the import path uses. OOCAddSequenceToCollection skips its
        -- version gate entirely on a development build, because a source
        -- checkout reports the hardcoded 3.3.00 from Init.lua and is by
        -- definition ahead of whatever it last tagged -- so content built by a
        -- newer GSE is not "incompatible" there, and must not read as such
        -- here either. The addon migrates what it needs to on import.
        local devBuild = type(GSE.VersionString) == "string"
            and string.match(GSE.VersionString, "development") ~= nil
        local compatible = version ~= nil
            and version > 3200
            and (devBuild or version <= GSE.VersionNumber)
        if not compatible then allCompatible = false end

        if compatible and GSE.VerifySequenceChecksum then
            local cs = GSE.VerifySequenceChecksum(sequence)
            if cs == false then
                anyInvalid = true
                allValid = false
            elseif cs ~= true then
                allValid = false
            end
        else
            allValid = false
        end
    end

    result.compatible = allCompatible
    if anyInvalid then
        result.checksum = "invalid"
    elseif allValid then
        result.checksum = "valid"
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
