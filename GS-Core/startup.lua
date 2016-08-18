local GNOME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

GSMasterSequences = ns
GSStaticCastCmds = {}
GSTRUnfoundSpells = {}

GSStaticCastCmds = { use = true, cast = true, spell = true, cancelaura = true }

GSStaticCleanStrings = {}
GSStaticCleanStrings = {
  [1] = "/console Sound_EnableSFX 0%;\n",
  [2] = "/console Sound_EnableSFX 1%;\n",
  [3] = "/script UIErrorsFrame:Hide%(%)%;\n",
  [4] = "/run UIErrorsFrame:Clear%(%)%;\n",
  [5] = "/script UIErrorsFrame:Clear%(%)%;\n",
  [6] = "/run UIErrorsFrame:Hide%(%)%;\n",
  [7] = "/console Sound_EnableErrorSpeech 1\n",
  [8] = "/console Sound_EnableErrorSpeech 0\n",

  [11] = "/console Sound_EnableSFX 0\n",
  [12] = "/console Sound_EnableSFX 1\n",
  [13] = "/script UIErrorsFrame:Hide%(%)\n",
  [14] = "/run UIErrorsFrame:Clear%(%)\n",
  [15] = "/script UIErrorsFrame:Clear%(%)\n",
  [16] = "/run UIErrorsFrame:Hide%(%)\n",
  [17] = "/console Sound_EnableErrorSpeech 1%;\n",
  [18] = "/console Sound_EnableErrorSpeech 0%;\n",

  [20] = "/stopmacro [@playertarget, noexists]\n",

  [30] = "/use 2\n",
  [31] = "/use [combat] 11\n",
  [32] = "/use [combat] 12\n",
  [33] = "/use [combat] 13\n",
  [34] = "/use [combat] 14\n",
  [35] = "/use 11\n",
  [36] = "/use 12\n",
  [37] = "/use 13\n",
  [38] = "/use 14\n",
  [39] = "/Use [combat] 11\n",
  [40] = "/Use [combat] 12\n",
  [41] = "/Use [combat] 13\n",
  [42] = "/Use [combat] 14\n",
  [43] = "/use [combat]11\n",
  [44] = "/use [combat]12\n",
  [45] = "/use [combat]13\n",
  [46] = "/use [combat]14\n",
  [47] = "/use [combat]2\n",
  [48] = "/use [combat] 2\n",

  [101] = "\n\n",
}

GSStaticStringRESET = "|r"

-- Sety defaults.  THese will be overriden once the addon is marked as loaded.
GSMasterOptions = {}
GSMasterOptions.AddInPacks = {}
GSMasterOptions.cleanTempMacro = true
GSMasterOptions.hideSoundErrors = false
GSMasterOptions.hideUIErrors = false
GSMasterOptions.clearUIErrors = false
GSMasterOptions.seedInitialMacro = false
GSMasterOptions.initialised = true
GSMasterOptions.AddInPacks = {}
GSMasterOptions.deleteOrphansOnLogout = false
GSMasterOptions.debug = false
GSMasterOptions.debugSequence = true
GSMasterOptions.sendDebugOutputToChat = true
GSMasterOptions.sendDebugOutputGSDebugOutput = false
GSMasterOptions.useTranslator = false
GSMasterOptions.requireTarget = false
GSMasterOptions.use2 = false
GSMasterOptions.use11 = false
GSMasterOptions.use12 = false
GSMasterOptions.use13 = true
GSMasterOptions.use14 = true
GSMasterOptions.setDefaultIconQuestionMark = true
GSMasterOptions.TitleColour = "|cFFFF0000"
GSMasterOptions.AuthorColour = "|cFF00D1FF"
GSMasterOptions.CommandColour = "|cFF00FF00"
GSMasterOptions.NormalColour = "|cFFFFFFFF"
GSMasterOptions.EmphasisColour = "|cFFFFFF00"
GSMasterOptions.overflowPersonalMacros = false
GSMasterOptions.KEYWORD = "|cff88bbdd"
GSMasterOptions.UNKNOWN = "|cffff6666"
GSMasterOptions.CONCAT = "|cffcc7777"
GSMasterOptions.NUMBER = "|cffffaa00"
GSMasterOptions.STRING = "|cff888888"
GSMasterOptions.COMMENT = "|cff55cc55"
GSMasterOptions.INDENT = "|cffccaa88"
GSMasterOptions.EQUALS = "|cffccddee"
GSMasterOptions.STANDARDFUNCS = "|cff55ddcc"
GSMasterOptions.WOWSHORTCUTS = "|cffddaaff"
GSMasterOptions.RealtimeParse = true
GSMasterOptions.SequenceLibrary = {}
GSMasterOptions.ActiveSequenceVersions = {}

local function determinationOutputDestination(message)
  if GSMasterOptions.sendDebugOutputGSDebugOutput then
    GSDebugOutput = GSDebugOutput .. message .. "\n"
	end
	if GSMasterOptions.sendDebugOutputToChat then
    print(message)
	end
end

function GSPrintDebugMessage(message, module)
    if GSMasterOptions.debugSequence == true and module == GSStaticSequenceDebug then
      determinationOutputDestination(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<SEQUENCEDEBUG> |r "] .. message )
		elseif GSMasterOptions.debug and module ~= GSStaticSequenceDebug then
      determinationOutputDestination(GSMasterOptions.TitleColour .. (GSisEmpty(module) and GNOME or module) .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<DEBUG> |r "] .. message )
    end

end




GSDebugOutput = ""

GSStaticSequenceDebug = "SEQUENCEDEBUG"



-- -- Seed a first instance just to be sure an instance is loaded if we need to.
-- if GSMasterOptions.seedInitialMacro then
-- 	GSMasterSequences["Draik01"] = {
-- 	specID = 0,
-- 	author = "Draik",
-- 	helpTxt = "Sample GS Hellow World Macro.",
-- 	'/run print("Hellow World!")',
-- 	}
-- end

-------------------------------------------------------------------------------------
-- GSStaticPriority is a static step function that goes 1121231234123451234561234567
-- use this like StepFunction = GSStaticPriority, in a macro
-- This overides the sequential behaviour that is standard in GS
-------------------------------------------------------------------------------------
GSStaticPriority = [[
	limit = limit or 1
	if step == limit then
		limit = limit % #macros + 1
		step = 1
	else
		step = step % #macros + 1
	end
]]


function GSisEmpty(s)
  return s == nil or s == ''
end

function GSLoadWeakauras(str)
  local WeakAuras = WeakAuras

  if WeakAuras then
    WeakAuras.ImportString(str)
  end
end

function GSGetActiveSequenceVersion(SequenceName)
  return GSMasterOptions.ActiveSequenceVersions[SequenceName]
end

function GSGetNextSequenceVersion(SequenceName)
  local nextv = 0
  for k,_ in pairs(SequenceLibrary[SequenceName]) do
    if k>nextv then
      nextv = k
    end
    k = k + 1
  end
  return k
end


function GSGetKnownSequenceVersions(SequenceName)
  local t = {}
  for k,_ in pairs(GSMasterOptions.SequenceLibrary[sequenceName]) do
    t[k] = k
  end
  return t, GSMasterOptions.ActiveSequenceVersions[SequenceName]
end


function GSDeleteSequenceVersion(sequenceName, version)
  if version == 1 then
    print(GSMasterOptions.TitleColour ..  GNOME .. L[":|r You cannot delete the only copy of a sequence."])
  elseif not GSIsEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
    GSMasterOptions.SequenceLibrary[sequenceName][version] = nil
  end
end

-- This will need more logic for the moment iuf they are not equal set somethng.
function GSChooseActiveSequenceVersion(sequenceName, version)
  GSMasterOptions.ActiveSequenceVersions[sequenceName] = version
end

function GSAddSequenceToCollection(sequenceName, sequence, version)


  if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
    -- Sequence is new
    GSMasterOptions.SequenceLibrary[sequenceName] = {}
  end
  if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
    -- This version is new
    GSMasterOptions.SequenceLibrary[sequenceName][version] = {}
  end
  -- evaluate version
  if version ~= GSMasterOptions.ActiveSequenceVersions[sequenceName] then
    GSChooseActiveSequenceVersion(sequenceName, version)
  end

  GSMasterOptions.SequenceLibrary[sequenceName][version] = sequence


end

function GSImportLegacyMacroCollections()
  for k,v in pairs(GSMasterSequences) do
    if GSisEmpty(v.version) then
      v.version = 1
    end
    GSAddSequenceToCollection(k, v, v.version)
    GSMasterSequences[k] = nil
  end
end

-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        local name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" then
          --print (name)
					LoadAddOn(i);
          GSImportLegacyMacroCollections()
        end
				GSMasterOptions.AddInPacks[name] = true
    end

end


local escapes = {
    ["|c%x%x%x%x%x%x%x%x"] = "", -- color start
    ["|r"] = "", -- color end
    ["|H.-|h(.-)|h"] = "%1", -- links
    ["|T.-|t"] = "", -- textures
    ["{.-}"] = "", -- raid target icons
}

function GSTRUnEscapeSequence(sequence)
  local i = 1
  for _,v in ipairs(sequence) do
    --print (i .. " " .. v)
    sequence[i] = GSTRUnEscapeString(v)
    i = i + 1
  end
  return sequence
end

function GSTRUnEscapeString(str)
    for k, v in pairs(escapes) do
        str = gsub(str, k, v)
    end
    return str
end

if GetLocale() ~= "enUS" then
  -- We need to load in temporarily the current locale translation tables.
  -- we should also look at cacheing this
  if GSisEmpty(GSAvailableLanguages[GSTRStaticKey][GetLocale()]) then
    GSAvailableLanguages[GSTRStaticKey][GetLocale()] = {}
    GSAvailableLanguages[GSTRStaticHash][GetLocale()] = {}
    GSAvailableLanguages[GSTRStaticShadow][GetLocale()] = {}
    GSPrintDebugMessage(L["Adding missing Language :"] .. GetLocale() )
    local i = 0
    for k,v in pairs(GSAvailableLanguages[GSTRStaticKey]["enUS"]) do
      GSPrintDebugMessage(i.. " " .. k .. " " ..v)
      local spellname = GetSpellInfo(k)
      if spellname then
        GSAvailableLanguages[GSTRStaticKey][GetLocale()][k] = spellname
        GSAvailableLanguages[GSTRStaticHash][GetLocale()][spellname] = k
        GSAvailableLanguages[GSTRStaticShadow][GetLocale()][spellname] = string.lower(k)
      end
      i = i + 1
    end
  end
end
