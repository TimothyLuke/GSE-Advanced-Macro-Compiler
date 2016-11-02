-- GLOBALS: GSE
GSE = LibStub("AceAddon-3.0"):NewAddon("GSE", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0")
GSE.L = {}
GSE.Static = {}

GSE.versionString = GetAddOnMetadata("GSE", "Version");

GSE.MediaPath = "Interface\\Addons\\GSE\\Media"



-- Initialisation Functions


--- When the Addon loads, printing is paused until after every other mod has loaded.
--    This method prints the print queue.
function GSE.PerformPrint()
  for k,v in ipairs(GSOutput) do
    print(v)
    GSOutput[k] = nil
  end
end


--- Prints <code>filepath</code>to the chat handler.  This accepts an optional
--    <code>title</code> to be prepended to that message.
function GSE.Print(message, title)
  -- stroe this for later on.
  if not GSE.isEmpty(title) then
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
--    The Title is stripped for intermod debug output via GSDebugOutput
local function determinationOutputDestination(message, title)
  if GSDebugSequenceEx then
    GSDebugOutput = GSDebugOutput .. message .. "\n"
	elseif GSMasterOptions.sendDebugOutputGSDebugOutput  then
    GSDebugOutput = GSDebugOutput .. message .. "\n"
  end
	if GSMasterOptions.sendDebugOutputToChatWindow  then
    GSPrint(message, title)
	end
end

--- Prints <code>message</code>to the chat handler.  This accepts an optional
--    <code>module</code> that is used to identify whether debugging for that module
--    is currently enabled.
function GSE.PrintDebugMessage(message, module)
    if GSE.isEmpty(module) then
      module = "GS-Core"
    end
    if module == GSStaticSequenceDebug then
      determinationOutputDestination(message, GSMasterOptions.TitleColour .. GNOME .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<SEQUENCEDEBUG> |r "] )
		elseif GSMasterOptions.debug and module ~= GSStaticSequenceDebug and GSMasterOptions.DebugModules[module] == true then
      determinationOutputDestination(GSMasterOptions.TitleColour .. (GSisEmpty(module) and GNOME or module) .. ':|r ' .. GSMasterOptions.AuthorColour .. L["<DEBUG> |r "] .. message )
    end
end
