-- GLOBALS: GSE
GSE =
    LibStub("AceAddon-3.0"):NewAddon(
    "GSE",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceSerializer-3.0",
    "AceTimer-3.0"
)
GSE.L = LibStub("AceLocale-3.0"):GetLocale("GSE")
GSE.Static = {}

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
GSE.VersionString = GetAddOnMetadata("GSE", "Version")

--@debug@
if GSE.VersionString:find("version") then
    GSE.VersionString = "3.1.01-development"
    GSE.Developer = true
end
--@end-debug@

if GSE.VersionString:find("Patron") then
    GSE.Patron = true
end
GSE.MediaPath = "Interface\\Addons\\GSE\\Media"
GSE.Pause = {}
GSE.OutputQueue = {}
GSE.DebugOutput = ""
GSE.SequenceDebugOutput = ""
GSE.GUI = {}
local L = GSE.L
local Statics = GSE.Static
local GNOME = "GSE"

-- Initialisation Functions
--- Checks for nil or empty variables.
function GSE.isEmpty(s)
    return s == nil or s == ""
end

--- Split a string into an array based on the delimiter specified.
function GSE.split(source, delimiters)
    local elements = {}
    local pattern = "([^" .. delimiters .. "]+)"
    local _ =
        string.gsub(
        source,
        pattern,
        function(value)
            elements[#elements + 1] = value
        end
    )
    return elements
end

local gameversion, build, date, tocversion = GetBuildInfo()
local majorVersion = GSE.split(gameversion, ".")

GSE.GameMode = tonumber(majorVersion[1])

--- This function takes a version String and returns a version number.
function GSE.ParseVersion(version)
    -- If it contains alpha or beta replace with the current version.  This will prevent notifying about test builds.
    if string.match(version, "alpha") or string.match(version, "beta") then
        version = GSE.VersionString
    end
    local parts = GSE.split(version, "-")
    local numbers = GSE.split(parts[1], ".")
    local returnVal
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

GSE.VersionNumber = GSE.ParseVersion(GSE.VersionString)

--- When the Addon loads, printing is paused until after every other mod has loaded.
--    This method prints the print queue.
function GSE.PerformPrint()
    for k, v in ipairs(GSE.OutputQueue) do
        print(v)
        GSE.OutputQueue[k] = nil
    end
end

--- Prints <code>filepath</code>to the chat handler.  This accepts an optional
--    <code>title</code> to be prepended to that message.
function GSE.Print(message, title)
    -- Store this for later on.
    if not GSE.isEmpty(title) then
        message = GSEOptions.CommandColour .. title .. Statics.StringReset .. " " .. message
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
    if GSE.UnsavedOptions.DebugSequenceExecution then
        GSE.DebugOutput = GSE.DebugOutput .. message .. "\n"
    elseif GSEOptions.sendDebugOutputToDebugOutput then
        GSE.DebugOutput = GSE.DebugOutput .. message .. "\n"
    end
    if GSEOptions.sendDebugOutputToChatWindow then
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
    local DebugModules, Debug, CommandColour, AuthorColour = {}, true, "|cFF00FF00", "|cFF00D1FF"
    if GSE.isEmpty(GSEOptions) then
        DebugModules[module] = false
    else
        DebugModules[module] = GSEOptions.DebugModules[module]
        if GSEOptions.debug then
            Debug = GSEOptions.debug
        end
        if GSEOptions.AuthorColour then
            AuthorColour = GSEOptions.AuthorColour
            CommandColour = GSEOptions.CommandColour
        end
    end
    if module == Statics.SequenceDebug then
        determinationOutputDestination(
            message,
            CommandColour .. GNOME .. ":|r " .. AuthorColour .. L["<SEQUENCEDEBUG> |r "]
        )
    elseif Debug and module ~= Statics.SequenceDebug and DebugModules[module] == true then
        determinationOutputDestination(
            CommandColour ..
                (GSE.isEmpty(module) and GNOME or module) .. ":|r " .. AuthorColour .. L["<DEBUG> |r "] .. message
        )
    end
end

function GSE.DebugProfile(event)
    local currentTimeStop = debugprofilestop()
    if GSE.ProfileStop and GSE.Developer then
        print(event, currentTimeStop - GSE.ProfileStop)
    end
    GSE.ProfileStop = currentTimeStop
end

GSE.CurrentGCD = 1.5
GSE.RecorderActive = false

-- Macro Mode Status
GSE.PVPFlag = false
GSE.inRaid = false
GSE.inMythic = false
GSE.inDungeon = false
GSE.inHeroic = false
GSE.inParty = false

-- initialise debugprofilestart
GSE.DebugProfile("init")
