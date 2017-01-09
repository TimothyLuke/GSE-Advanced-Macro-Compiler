-- GLOBALS: GSE
GSE = LibStub("AceAddon-3.0"):NewAddon("GSE", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0")
GSE.L = LibStub("AceLocale-3.0"):GetLocale("GSE")
GSE.Static = {}

GSE.VersionString = GetAddOnMetadata("GSE", "Version");

GSE.MediaPath = "Interface\\Addons\\GSE\\Media"

GSE.OutputQueue = {}
GSE.DebugOutput = ""
GSE.SequenceDebugOutput = ""
GSE.GUI = {}
L = GSE.L

local Statics = GSE.Static

-- Initialisation Functions


--- When the Addon loads, printing is paused until after every other mod has loaded.
--    This method prints the print queue.
function GSE.PerformPrint()
  for k,v in ipairs(GSE.OutputQueue) do
    print(v)
    GSE.OutputQueue[k] = nil
  end
end


--- Prints <code>filepath</code>to the chat handler.  This accepts an optional
--    <code>title</code> to be prepended to that message.
function GSE.Print(message, title)
  -- stroe this for later on.
  if not GSE.isEmpty(title) then
    message = GSEOptions.TitleColour .. title .. Statics.StringReset .." " .. message
  end
  table.insert(GSE.OutputQueue, message)
  if GSE.PrintAvailable then
    GSE.PerformPrint()
  end
end

--- Send the message string to an output source.
--    If <code>GSEOptions.sendDebugOutputGSE.DebugOutput</code> then the output will
--    be appended to variable <code>GSE.DebugOutput</code>
--    If <code>GSEOptions.sendDebugOutputToChat</code> then the output will
--    be sent to variable <code>GSE.Print</code>
--    The Title is stripped for intermod debug output via GSE.DebugOutput
local function determinationOutputDestination(message, title)
  if GSDebugSequenceEx then
    GSE.DebugOutput = GSE.DebugOutput .. message .. "\n"
	elseif GSEOptions.sendDebugOutputToDebugOutput   then
    GSE.DebugOutput = GSE.DebugOutput .. message .. "\n"
  end
	if GSEOptions.sendDebugOutputToChatWindow  then
    GSE.Print(message, title)
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
      determinationOutputDestination(message, GSEOptions.TitleColour .. GNOME .. ':|r ' .. GSEOptions.AuthorColour .. L["<SEQUENCEDEBUG> |r "] )
		elseif GSEOptions.debug and module ~= GSStaticSequenceDebug and GSEOptions.DebugModules[module] == true then
      determinationOutputDestination(GSEOptions.TitleColour .. (GSE.isEmpty(module) and GNOME or module) .. ':|r ' .. GSEOptions.AuthorColour .. L["<DEBUG> |r "] .. message )
    end
end

GSE.CurrentGCD = GetSpellCooldown(61304)
GSE.RecorderActive = false

-- Macro mode Status
GSE.PVPFlag = false
GSE.inRaid = false
GSE.inMythic = false
