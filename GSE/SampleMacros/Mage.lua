local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[8] = {}

local Sequences = Statics.SampleMacros[8]
------------------
----- Mage
------------------
-- Fire 63
-- Frost 64


------------------------
Sequences['SAM_Arcane'] = {
  SpecID = 62,
  Author = "Flashgreer - wowlazymacros.com",
  Talents = "2,1,2,2,1,3,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/castsequence [nochanneling]Arcane Blast,Arcane Blast,Arcane Blast,Arcane Blast,Arcane Barrage',
      '/cast [nochanneling]Arcane Missiles',
      '/castsequence [nochanneling]charged up, Arcane Barrage',
      '/cast [nochanneling]Rune of power',
      KeyRelease = {
        "/startattack",
        "/cast [combat]Arcane Power",
        "/cast [combat]Presence of Mind",
      },
    }
  }
}


Sequences['SAM_Fire'] = {
  SpecID = 63,
  Author = "John Mets - wowlazymacros.com",
  Talents = "2,2,3,3,1,1,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      "/castsequence reset=combat Fireball, Fireball, Fireball, Fireball, Fire Blast, Pyroblast",
      "/cast Combustion",
      "/cast Living Bomb",
      "/cast Ice floes",
    }
  }
}

Sequences['SAM_Ichthys_Frosty'] = {
  Author="Mageichthys@Kilrogg",
  SpecID=64,
  Talents = "Talents: 1322112 -  Works best with a 0.75 to 1.0 second  button spam",
  Icon='INV_MISC_QUESTIONMARK',
  Lang="enUS",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [nopet,nomod] Summon Water Elemental",
      },
      "/cast [nochanneling] Rune of Power",
      "/cast [nochanneling] Ray of Frost",
      "/cast [nochanneling] Frost Bomb",
      "/cast [nochanneling] Frozen Orb",
      "/cast [nochanneling] Frozen Touch",
      "/cast [nochanneling] Ebonbolt",
      "/cast [nochanneling] Frostbolt",
      "/cast [nochanneling] Ice Lance",
      "/cast [nochanneling] Flurry",
      "/cast [nochanneling] Ice Lance",
      "/cast [nochanneling] Glacial Spike",
      "/cast [nochanneling] Frostbolt",
      KeyRelease={
        "/cast [nochanneling] Ice Barrier",
        "/cast [nochanneling] Ice Floes",
        "/cast [nochanneling] Icy Veins",
        "/cast [nochanneling] Frozen Orb",
      },
    }
  }
}
