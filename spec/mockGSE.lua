GSE = {}
GSE.L = {}
GSE.Static = {}
GSE.VersionString = 2000;

GNOME = "UnitTest"

GSELibrary = {}

-- Mock Character FUncitons
function GetTalentTierInfo(tier, ...)
  return 1
end

function GetSpecialization()
  return 11
end

function GetClassInfo(i)
  if i == 11 then
    return "Druid", "DRUID", 11
  else
    return "Paladin", "PALADIN", 2
  end
end

function GetSpecializationInfoByID(id)
  return id, "SPecName", "SPecDescription", 1234567, "file.blp", 1, "DRUID"
end

function UnitClass(str)
  return "Druid", "DRUID", 11
end

-- Mock standard functions
function GSE.Print(message, title)
  print (title .. ": " .. message)
end

function GSE.PrintDebugMessage(message, title)
  GSE.Print(message, title)
end



GSE.PVPFlag = false
GSE.inRaid = false
GSE.inMythic = false

function strmatch(string, pattern, initpos)
  return string.match(string, pattern, initpos)
end

function newLocale(application, locale, isDefault, silent)
  local writedefaultproxy = setmetatable({}, {
    __newindex = function(self, key, value)
      if not rawget(registering, key) then
        rawset(registering, key, value == true and key or value)
      end
    end,
    __index = assertfalse
  })
  if isDefault then
    return writedefaultproxy
  end
end

function GetLocale()
  return "enUS"
end
