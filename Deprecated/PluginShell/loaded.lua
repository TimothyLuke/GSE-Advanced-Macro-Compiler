local ModName, Sequences = ... -- Sequences will bring in macros sotred in other other files
local GSE = GSE
---- PRINT MISSING GSE
if GSE == nil then
  print(
    "Addon requires GSE3. You can get it from Curseforge @https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros"
  )
  return
end

local L = GSE.L
local Statics = GSE.Static
local GSEPlugin = LibStub("AceAddon-3.0"):NewAddon(ModName, "AceEvent-3.0")

-- check in case Sequences is empty
if GSE.isEmpty(Sequences) then
  local Sequences = {}
end

-- This is an example only
-- Sequences["newMacro"] = [[asdaksjdhfskjdfhgsdfsdf]]

--- We make this a function as then we can register for the reload event within GSE
local function loadSequences(event, arg)
  -- by changing the event from "load" you can do other login here if you wish.

  if arg == ModName then -- check this is my mod not someone elses
    for k, v in pairs(Sequences) do
      GSE.ImportSerialisedSequence(v, false) -- change this to true to popup the merge dialog instad
    end

    ---- Tell GSE to reload the new stuff
    GSE.PerformReloadSequences()

    ---- Print Success Message
    GSE.Print(
      "Hello, " .. UnitName("player") .. " " .. UnitLevel("player") .. "  - Holy's Mage Macros has been loaded.",
      ModName
    )
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
