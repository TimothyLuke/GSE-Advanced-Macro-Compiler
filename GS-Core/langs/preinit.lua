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
    if GSMasterOptions.debugSequence == true and module == GSStaticSequenceDebug then
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
