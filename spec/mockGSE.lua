---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field
GSE = {}
GSE.L = {}
GSE.Static = {}
GSE.VersionString = "2.0.00-18-g95ecb41"

GNOME = "UnitTest"

GSELibrary = {}
GSEStorage = {}
GSEStorage[0] = {}
GSEStorage[1] = {}
GSEStorage[2] = {}
GSEStorage[3] = {}
GSEStorage[4] = {}
GSEStorage[5] = {}
GSEStorage[6] = {}
GSEStorage[7] = {}
GSEStorage[8] = {}
GSEStorage[9] = {}
GSEStorage[10] = {}
GSEStorage[11] = {}
GSEStorage[12] = {}
GSEStorage[13] = {}

GSE.Library = {}
StaticPopupDialogs = {}
-- Mock Character Functions
function GetTalentTierInfo(tier, ...)
  return 1
end

C_SpellBook = {}
C_SpecializationInfo = {}

function C_SpecializationInfo.GetSpecialization()
  return 11
end

function GetSpecialization()
  return C_SpecializationInfo.GetSpecialization()
end

function GetClassInfo(i)
  if i == 11 then
    return "Druid", "DRUID", 11
  else
    return "Paladin", "PALADIN", 2
  end
end

function UnitSpellHaste(unit)
  -- return a haste of 25%
  return 25
end

function GetSpecializationInfoByID(id)
  return id, "SPecName", "SPecDescription", 1234567, "file.blp", 1, "DRUID"
end

function UnitClass(str)
  return "Druid", "DRUID", 11
end

function GetUnitName(str, bool)
  local retval = "Unknown"
  if str == "player" then
    retval = "Draik"
  end
  return retval
end

function date(dateval)
  return os.date()
end

function GetSpellInfo(spellstring)
  print("GetSpellInfo -- " .. spellstring)
  local name, rank, icon, castTime, minRange, maxRange, spellId
  if type(spellstring) == "string" then
    name = spellstring
    spellId = 1010101
  else
    name = "Eye of Tyr"
    spellId = spellstring
  end
  print("GetSpellInfo " .. name .. spellId)
  return name, rank, icon, castTime, minRange, maxRange, spellId
end

function GSE.PrintDebugMessage(message, title)
  GSE.Print(message, title)
end

function GSE.isEmpty(s)
  return s == nil or s == ""
end

-- Mock Standard Functions
function GSE.Print(message, title)
  if GSE.isEmpty(title) then
    title = "GSETEST"
  end
  print(title .. ": " .. message)
end

--- Split a string into an array based on the delimiter specified.
function GSE.split(source, delimiters)
  local elements = {}
  local pattern = "([^" .. delimiters .. "]+)"
  string.gsub(
    source,
    pattern,
    function(value)
      elements[#elements + 1] = value
    end
  )
  return elements
end

--- This function takes a version String and returns a version number.
function GSE.ParseVersion(version)
  local parts = GSE.split(version, "-")
  local numbers = GSE.split(parts[1], ".")
  local returnVal = 0
  if GSE.isEmpty(numbers) and type(version) == "number" then
    returnVal = version
  else
    if table.getn(numbers) > 1 then
      returnVal = (tonumber(numbers[1]) * 1000) + (tonumber(numbers[2]) * 100) + (tonumber(numbers[3]))
    else
      returnVal = tonumber(version)
    end
  end
  return tonumber(returnVal)
end

GSE.PVPFlag = false
GSE.inRaid = false
GSE.inMythic = false
GSE.inDungeon = false
GSE.inHeroic = false

function strmatch(string, pattern, initpos)
  return string.match(string, pattern, initpos)
end

function newLocale(application, locale, isDefault, silent)
  local writedefaultproxy =
    setmetatable(
    {},
    {
      __newindex = function(self, key, value)
        if not rawget(registering, key) then
          rawset(registering, key, value == true and key or value)
        end
      end,
      __index = assertfalse
    }
  )
  if isDefault then
    return writedefaultproxy
  end
end

function GetLocale()
  return "enUS"
end

INVSLOT_AMMO = 0
INVSLOT_HEAD = 1
INVSLOT_NECK = 2
INVSLOT_SHOULDER = 3
INVSLOT_BODY = 4 --(shirt)
INVSLOT_CHEST = 5
INVSLOT_WAIST = 6
INVSLOT_LEGS = 7
INVSLOT_FEET = 8
INVSLOT_WRIST = 9
INVSLOT_HAND = 10
INVSLOT_FINGER1 = 11
INVSLOT_FINGER2 = 12
INVSLOT_TRINKET1 = 13
INVSLOT_TRINKET2 = 14
INVSLOT_BACK = 15
INVSLOT_MAINHAND = 16
INVSLOT_OFFHAND = 17
INVSLOT_RANGED = 18
INVSLOT_TABARD = 19

local classic = "1.13.2 12345 Aug 10 2019 11302"
local retail = "8.2.0 31429 Aug 7 2019 80200"
currentver = retail
GSE.GameMode = 8

function GetBuildInfo()
  return currentver
end

function setClassic()
  GSE.GameMode = 1
  currentver = classic
end

function setRetail()
  GSE.GameMode = 8
  currentver = retail
end

GSE.EncodeMessage = function(tab)
  return tab
end

GSE.DecodeMessage = function (tab)
  return tab
end

function C_SpellBook.FindBaseSpellByID(stuff)
  return stuff
end

function debugprofilestop()
  return os.clock()
end

function GSE.DebugProfile(event)
  local currentTimeStop = debugprofilestop()
  if GSE.ProfileStop and GSE.Developer then
    print(event, currentTimeStop - GSE.ProfileStop)
  end
  GSE.ProfileStop = currentTimeStop
end

C_CreatureInfo = {}
function C_CreatureInfo.GetClassInfo()
  return {
    className = "Druid",
    classFile = "DRUID",
    classID = 11
  }
end
