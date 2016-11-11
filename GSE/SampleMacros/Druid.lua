local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[11] = {}

local Sequences = Statics.SampleMacros[11]

------------------
----- Druid
------------------
--Guardian 104
--Feral 103
--Balance 102

Sequences['SAM_Bear'] = {
  SpecID = 104,
  Author = "John Mets www.wowlazymacros.com",
  Talents = "2,3,3,1,1,1,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
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

Sequences['SAM_Feral-ST'] = {
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


Sequences['SAM_Feral-AoE'] = {
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
      '/castsequence [combat,nostealth] Thrash,Swipe,Swipe,Thrash,Swipe,Rip',
      '/castsequence [combat,nostealth] Swipe,Thrash,Swipe,Swipe,Thrash,Ferocious Bite',
      KeyRelease={
        "/startattack",
        "/cast Tiger's Fury"
      },
    }
  },
}

Sequences['SAM_Boomer'] = {
  SpecID = 102,
  Author = "TimothyLuke",
  Talents = "2,3,2,3,1,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/use [noform]!Moonkin Form"
      },
      '/cast Moonfire',
      '/cast Sunfire',
      '/castsequence [combat] Solar Wrath,Lunar Strike,Solar Wrath,Lunar Strike,Solar Wrath,Solar Wrath',
      '/cast Starsurge',
      KeyRelease={
        "/startattack",
      },
    },
  }
}

Sequences["SAM_druid_bala_st"] = {
  SpecID = 102,
  Author="someone",
  Talents = "3,3,3,3,1,3,2",
  Help = "CTRL Blessing of the Ancients, Shift Celestial Alignment, Alt Solar Beam",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [noform]!Moonkin Form",
        "/cast [mod:ctrl] Blessing of the Ancients",
        "/cast [mod:shift] Celestial Alignment",
        "/cast [mod:alt] Solar Beam",
      },
      "/castsequence reset=target Sunfire,null",
      "/castsequence reset=target Moonfire,null",
      "/castsequence [combat]Starsurge,Solar Wrath,Lunar Strike,Solar Wrath",
      "/castsequence Lunar Strike,Solar Wrath,Starsurge,Solar Wrath,Lunar Strike,Starsurge",
      "/castsequence [combat]Solar Wrath,Lunar Strike,Solar Wrath,Moonfire",
      "/castsequence [combat]Solar Wrath,Starsurge,Lunar Strike,Solar Wrath",
      "/castsequence [combat]Starsurge,Solar Wrath,Solar Wrath,Sunfire",
      "/castsequence [combat]Solar Wrath,Lunar Strike,Starsurge,Moonfire",
      "/castsequence [combat]Lunar Strike,Solar Wrath,Lunar Strike",
      "/cast Starsurge",
      KeyRelease={
        "/startattack",
      },
    },
  }
}

Sequences['SAM_KTNDRUHEALS'] = {
  SpecID = 105,
  Author = "KTN",
  Talents = "2,1,1,3,1,1,2",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/cast [@focus,dead] Rebirth",
      },
      '/castsequence [@focus] reset=15/combat Lifebloom, Regrowth, Rejuvenation',
      '/cast [@focus] Cenarion Ward',
      '/castsequence reset=target [@mouseover,exists,help,nodead] Regrowth, Rejuvenation, Healing Touch, Swiftmend',
      KeyRelease = {
        "/cast [@focus]Ironbark",
        "/cast [@player]Barkskin",
      },
    },
  }
}
