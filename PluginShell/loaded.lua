local ModName, Library = ... -- Library will hold some stuff if there are other files, if not it won't.
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local GSEPlugin = LibStub("AceAddon-3.0"):NewAddon(ModName, "AceEvent-3.0")

local Sequences = Library -- In case you have some stuff via the format Sequences[Name] =


-- This next Line will put this entry into the Druid part of the table
Sequences['EG_Bear'] = {
  SpecID = 104,
  Author = "John Mets www.wowlazymacros.com",
  Talents = "2,3,3,1,1,1,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [@player,nostance:1] Bear Form",
      },
      StepFunction = "Priority",
      "/castsequence reset=combat Thrash, Moonfire, Maul, Swipe",
      "/castsequence reset=combat Savage Defense, Swipe, Swipe, Savage Defense ,Frenzied Regeneration, Ironfur",
      "/cast Survival Instincts",
      "/cast Thrash",
      "/castsequence reset=combat Swipe, Moonfire, Maul, Mangle, Ironfur",
      "/cast Pulverize",
      "/cast Incapacitating Roar",
      "/cast [combat] Barkskin",
      "/cast [combat] Mighty Bash",
      "/cast [combat] Berserk",
      "/castsequence Cenarion ward",
      KeyRelease={
        "/startattack",
      },
    },
  }
}

-- This will also add a macro to the same place
Library['EG_Feral-ST'] = {
  SpecID = 103,
  Author = "Jimmy www.wowlazymacros.com",
  Talents = "2,2,3,1,1,2,3",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [@player,nostance:2] Cat Form",
        "/cast [nostealth,nocombat] Prowl",
        "/stopattack [stealth]"
      },
      '/castsequence [combat,nostealth] Rake,Shred,Shred,Rake,Shred,Rip',
      '/castsequence [combat,nostealth] Shred,Rake,Shred,Shred,Rake,Ferocious Bite',
      KeyRelease={
        "/startattack",
        "/cast Tiger's Fury"
      },
    }
  },
}

--- We make this a function as then we can register for the reload event within GSE
local function loadSequences(event, arg)
  if arg == ModName then
    GSE.ImportMacroCollection(Library)
  end
end

GSEPlugin:RegisterMessage(Statics.ReloadMessage, "loadSequences")

-- If not loaded or an updated version, then these sequences.
-- GSE.RegisterAddon will keep track of the current version and then if the version is different to the last one it
-- returns true to indicate that it wants you to send through update versions.  The super simple way is below.
-- You could do specific things via the GSE API like adding an updated version and then setting it to be the default
-- or pvp version.
if GSE.RegisterAddon(ModName, GetAddOnMetadata(ModName, "Version"), GSE.GetSequenceNamesFromLibrary(library) then
  loadSequences("Load", ModName)
end
