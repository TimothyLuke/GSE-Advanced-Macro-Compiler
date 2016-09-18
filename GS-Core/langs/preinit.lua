local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

GSStaticSourceLocal = "Local"
GSStaticSourceTransmission = "Transmission"

GSMasterOptions = {}
GSMasterOptions.saveAllMacrosLocal = true
GSMasterOptions.hideSoundErrors = false
GSMasterOptions.hideUIErrors = false
GSMasterOptions.clearUIErrors = false
GSMasterOptions.seedInitialMacro = false
GSMasterOptions.initialised = true
GSMasterOptions.deleteOrphansOnLogout = false
GSMasterOptions.debug = false
GSMasterOptions.debugSequenceEx = false
GSMasterOptions.sendDebugOutputToChat = true
GSMasterOptions.sendDebugOutputGSDebugOutput = false
GSMasterOptions.useTranslator = false
GSMasterOptions.requireTarget = false
GSMasterOptions.use2 = false
GSMasterOptions.use6 = false
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
GSMasterOptions.RealtimeParse = false
GSMasterOptions.SequenceLibrary = {}
GSMasterOptions.ActiveSequenceVersions = {}
GSMasterOptions.DisabledSequences = {}
GSMasterOptions.DebugModules = {}
GSMasterOptions.DebugModules["GS-Core"] = true
GSMasterOptions.DebugModules["GS-SequenceTranslator"] = false
GSMasterOptions.DebugModules["GS-SequenceEditor"] = false
GSMasterOptions.DebugModules[GSStaticSourceTransmission] = false
GSMasterOptions.filterList = {}
GSMasterOptions.filterList["Spec"] = true
GSMasterOptions.filterList["Class"] = true
GSMasterOptions.filterList["All"] = false
GSMasterOptions.autoCreateMacroStubsClass = true
GSMasterOptions.autoCreateMacroStubsGlobal = false

--- Checks for nil or empty.
function GSisEmpty(s)
  return s == nil or s == ''
end



--- When the Addon loads, printing is paused until after every other mod has loaded.
--    This method prints the print queue.
function GSPerformPrint()
  for k,v in ipairs(GSOutput) do
    print(v)
    GSOutput[k] = nil
  end
end


--- Prints <code>filepath</code>to the chat handler.  This accepts an optional
--    <code>title</code> to be prepended to that message.
function GSPrint(message, title)
  -- stroe this for later on.
  if not GSisEmpty(title) then
    message = GSMasterOptions.TitleColour .. title .. GSStaticStringRESET .." " .. message
  end
  table.insert(GSOutput, message)
  if GSPrintAvailable then
    GSPerformPrint()
  end
end

--- Send the message string to an output source.
--    If <code>GSMasterOptions.sendDebugOutputGSDebugOutput</code> then the output will
--    be appended to variable <code>GSDebugOutput</code>
--    If <code>GSMasterOptions.sendDebugOutputToChat</code> then the output will
--    be sent to variable <code>GSPrint</code>
local function determinationOutputDestination(message)
  if GSMasterOptions.sendDebugOutputGSDebugOutput then
    GSDebugOutput = GSDebugOutput .. message .. "\n"
	end
	if GSMasterOptions.sendDebugOutputToChat then
    GSPrint(message)
	end
end

--- Prints <code>message</code>to the chat handler.  This accepts an optional
--    <code>module</code> that is used to identify whether debugging for that module
--    is currently enabled.
function GSPrintDebugMessage(message, module)
    if GSisEmpty(module) then
      module = "GS-Core"
    end
    if GSMasterOptions.debugSequenceEx == true and module == GSStaticSequenceDebug then
      determinationOutputDestination(GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<SEQUENCEDEBUG> |r "] .. message )
		elseif GSMasterOptions.debug and module ~= GSStaticSequenceDebug and GSMasterOptions.DebugModules[module] == true then
      determinationOutputDestination(GSMasterOptions.TitleColour .. (GSisEmpty(module) and GNOME or module) .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<DEBUG> |r "] .. message )
    end
end



GSTRStaticKey = "KEY"
GSTRStaticHash = "HASH"
GSTRStaticShadow = "SHADOW"

GSAvailableLanguages = {}
GSAvailableLanguages[GSTRStaticKey] = {}
GSAvailableLanguages[GSTRStaticHash] = {}
GSAvailableLanguages[GSTRStaticShadow] = {}
