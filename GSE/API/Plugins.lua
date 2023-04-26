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

function GSE.RegisterAddon(name, version, sequencenames)
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
    end
    GSE.AddInPacks[name].SequenceNames = sequencenames
    return updateflag
end

function GSE.FormatSequenceNames(names)
    local returnstring = ""
    for _, v in ipairs(names) do
        returnstring = returnstring .. " - " .. v .. ",\n"
    end
    returnstring = returnstring:sub(1, -3)
    return returnstring
end

GSE.DebugProfile("Plugins")
