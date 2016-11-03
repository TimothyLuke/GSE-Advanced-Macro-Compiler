local GNOME, Sequences = ...
local modversion = GetAddOnMetadata(GNOME, "Version")
local GSDB = LibStub("AceAddon-3.0"):NewAddon("GSDB", "AceEvent-3.0")
local localizedClass, englishClass, classIndex = UnitClass("unit");
GSDBOptions = {}


GSDBOptions.currentversion = modversion
GSDBOptions.loadedcount = 1

for k,_ in pairs(Sequences) do
  Sequences[k].source = GNOME
  Sequences[k].authorversion = modversion
end

GSImportMacroCollection(Sequences)

local f = CreateFrame('Frame')

local function processAddonLoaded()
  if GSE.isEmpty(GSDBOptions.ClassesProcessed) then
    GSDBOptions.ClassesProcessed = {}
    GSDBOptions["ClassesProcessed"][englishClass] = false
  end
  if GSE.isEmpty(GSDBOptions["ClassesProcessed"][englishClass] == true) then
    for k,_ in pairs(Sequences) do
      if GSMasterOptions.SequenceLibrary[k][GSGetActiveSequenceVersion(k)].source == GNOME then
        GSDisableSequence(k)
      else
        GSE.PrintDebugMessage("No entry for "  .. k, GNOME)
      end
    end
    GSDBOptions["ClassesProcessed"][englishClass] = true
  end
  if GSDBOptions.loadedcount < 4 then
    GSE.Print("Draik Bundled Macros loaded.  This set is an example set to demonstrate the capabilities of GS-E.  The macros are designed for use levelling to 110.  They should not be considered the best or perfect but are examples.", GNOME)
    GSE.Print("There are other plugins like this available for GS-E that contain macro sets better suited for raiding and competative PVP.  ", GNOME)
    GSE.Print("Macros are constantly evolving.  The latest macros are available at http://www.wowlazymacros.com  ", GNOME)
    GSE.Print("The DB_ Macros are disabled.  To use them in the /gsse window choose a macro and Enable Sequence.", GNOME)
    GSDBOptions.loadedcount = GSDBOptions.loadedcount + 1
  end
end

GSDB:RegisterMessage(Statics.CoreLoadedMessage,  processAddonLoaded)
