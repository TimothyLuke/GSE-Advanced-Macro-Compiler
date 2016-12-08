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
  if GSE.isEmpty(GSE.AddInPacks[name].Version) or GSE.AddInPacks[name].Version ~= version then
    updateflag = true
    GSE.AddInPacks[name].Version = version
  end
  GSE.AddInPacks[name].SequenceNames = sequencenames
  return updateflag
end

function GSE.FormatSequenceNames(names)
  local returnstring = ""
  for k,v in ipairs(names) do
    returnstring = returnstring .. " - ".. v .. ",\n"
  end
  returnstring = returnstring:sub(1, -3)
  return returnstring
end
