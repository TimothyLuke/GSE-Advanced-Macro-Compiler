local GNOME, Sequences = ...
local modversion = GetAddOnMetadata(GNOME, "Version")
local AceEvent = LibStub("AceEvent-3.0")

GSDBOptions = {}
GSDBOptions.warnupdate = false
GSDBOptions.currentversion = modversion
GSDBOptions.loadedcount = 1
GSDBOptions.disableActionComplete = false

local KnownSequences = {}
for k,_ in pairs(Sequences) do
  KnownSequences[k] = true
  Sequences[k].source = GNOME
  Sequences[k].authorversion = modversion
end

GSImportLegacyMacroCollections(Sequences)

local function processAddonLoaded()
  if not GSDBOptions.disableActionComplete then
    for k,_ in pairs(KnownSequences) do
      if GSMasterOptions.SequenceLibrary[k][GSGetActiveSequenceVersion(k)].source == GNOME then
        GSDisableSequence(k)
      end
      GSPrint("The DB_ Macros that you have not edited have been disabled.  This is a one time action.", GNOME)
      GSDBOptions = true
    end
  end
  if GSDBOptions.loadedcount < 4 then
    GSPrint("Draik Bundled Macros loaded.  This set is an example set to demonstrate the capabilities of GS-E.  The macros are designed for use levelling to 110.  They should not be considered the best or perfect but are examples.", GNOME)
    GSPrint("There are other plugins like this available for GS-E that contain macro sets better suited for raiding and competative PVP.  ", GNOME)
    GSPrint("Macros are constantly evolving.  The latest macros are available at http://www.wowlazymacros.com  ", GNOME)
    GSPrint("The DB_ Macros are disabled.  To use them in the /gsse window choose a macro and Enable Sequence.")
    GSDBOptions.loadedcount = GSDBOptions.loadedcount + 1
  end

end

AceEvent:RegisterMessage(GSStaticCoreLoadedMessage,  processAddonLoaded)
