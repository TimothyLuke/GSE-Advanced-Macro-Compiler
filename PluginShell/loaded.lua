local ModName, Sequences = ... -- Sequences will bring in macros sotred in other other files
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local GSEPlugin = LibStub("AceAddon-3.0"):NewAddon(ModName, "AceEvent-3.0")

-- This is an example only
-- Sequences["newMacro"] = [[asdaksjdhfskjdfhgsdfsdf]]


--- We make this a function as then we can register for the reload event within GSE
local function loadSequences(event, arg)
  if arg == ModName then
    GSE.ImportCompressedMacroCollection (Sequences)
  end
end

GSEPlugin:RegisterMessage(Statics.ReloadMessage, loadSequences)

-- If not loaded or an updated version, then these sequences.
-- GSE.RegisterAddon will keep track of the current version and then if the version is different to the last one it
-- returns true to indicate that it wants you to send through update versions.  The super simple way is below.
-- You could do specific things via the GSE API like adding an updated version and then setting it to be the default
-- or pvp version.

-- Note: You could change the loadSequences function to load specific updated sequence
if GSE.RegisterAddon(ModName, GetAddOnMetadata(ModName, "Version"), GSE.GetSequenceNamesFromLibrary(Sequences)) then
  loadSequences("Load", ModName)
end
