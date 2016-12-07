local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

--- List addons that GSE knows about that have been disabled
function GSE.ListUnloadedAddons()
  local returnVal = "";
  for k,v in pairs(GSE.UnloadedAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end

-- --- List addons that GSE knows about that have been enabled
-- function GSE.ListAddons()
--   local returnVal = "";
--   for k,v in pairs(GSE.AddInPacks) do
--     aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
--     returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
--   end
--   return returnVal
-- end

function GSE.RegisterAddon(name, version, sequencenames)
  local updateflag = false
  if GSE.isEmpty(GSE.AddInPacks[name]) then
    GSE.AddInPacks[name] = {}
    GSE.AddInPacks[name].Name = name
  end
  if  GSE.AddinPacks[name].Version ~= version then
    updateflag = true
    GSE.AddinPacks[name].Version = version
  end
  GSE.AddinPacks[name].SequenceNames = sequencenames
  return updateflag
end

function GSE.FormatSequenceNames(names)
  local returnstring = ""
  for k,_ in pairs(names) do
    returnstring = returnstring .. K .. ","
  end
  returnstring = returnstring:sub(1, -2)
  return returnstring
end
