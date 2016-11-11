------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local GNOME, Sequences = ...

------------------
----- Druid
------------------
--Guardian 104
--Feral 103
--Balance 102

Sequences['SAM_bear1'] = {
specID = 104,
author = "John Mets www.wowlazymacros.com",
helpTxt = " Talents: 2331111",
StepFunction = "Priority",
KeyPress = [[
/targetenemy [noharm][dead]
]],
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
KeyRelease = [[
/startattack
]],
}

Sequences['SAM_bear2'] = {
specID = 104,
author = "John Mets www.wowlazymacros.com",
helpTxt = " Talents: 2331111",
KeyPress = [[
/targetenemy [noharm][dead]
]],
"/castsequence Thrash, Thrash, Thrash, Pulverize",
"/castsequence reset=5 Savage Defense, Swipe, Swipe, Frenzied Regeneration",
"/castsequence [combat] reset=target Moonfire, Mass Entanglement",
"/cast !Mangle",
"/castsequence reset=12 Maul",
"/cast Survival Instincts",
"/cast Thrash",
"/castsequence Swipe, Moonfire, Maul, Mangle",
"/cast Thrash",
"/castsequence Swipe, Moonfire, Maul, Mangle",
"/cast Thrash",
"/cast Pulverize",
"/cast Incapacitating Roar",
"/castsequence [combat] reset=60 Barkskin",
"/castsequence [combat] reset=180 Berserk",
"/castsequence reset=30 cenarion ward",
KeyRelease = [[
/startattack
]],
}

Sequences['SAM_Feral-ST'] = {
specID = 103,
author = "Jimmy www.wowlazymacros.com",
helpTxt = "2231123",
StepFunction = "Priority",
KeyPress = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Cat Form
/cast [nostealth,nocombat] Prowl
/stopattack [stealth]
]],
'/castsequence [combat,nostealth] Rake,Shred,Shred,Rake,Shred,Rip',
'/castsequence [combat,nostealth] Shred,Rake,Shred,Shred,Rake,Ferocious Bite',
KeyRelease = [[
/startattack
/cast Tiger's Fury
]],
}

Sequences['SAM_Feral-AoE'] = {
specID = 103,
author = "Jimmy www.wowlazymacros.com",
helpTxt = "2231123",
StepFunction = "Priority",
 KeyPress = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Cat Form
/cast [nostealth,nocombat] Prowl
/stopattack [stealth]
]],
'/castsequence [combat,nostealth] Thrash,Swipe,Swipe,Thrash,Swipe,Rip',
'/castsequence [combat,nostealth] Swipe,Thrash,Swipe,Swipe,Thrash,Ferocious Bite',
KeyRelease = [[
/startattack
/cast Tiger's Fury
]],
}

Sequences['SAM_feralaoe'] = {
specID = 103,
author = "lloskka www.wowlazymacros.com",
helpTxt = "Talents 2331223",
KeyPress = [[
/targetenemy [noharm][dead]
/use [noform:2]Cat Form
/cast [nostealth,nocombat] Prowl
]],
[[/cast [combat] !Incarnation: King of the Jungle]],
[[/cast [combat] !Mighty Bash]],
[[/castsequence reset=combat Rake,Thrash,Swipe,Swipe,Swipe,Ferocious Bite]],
KeyRelease = [[
/cast [combat] !survival Instincts
/cast [combat] !Tiger's Fury
/startattack
]],
}

Sequences['SAM_feralsingle'] = {
specID = 103,
author = "lloskka www.wowlazymacros.com",
helpTxt = "Talents 2331223",
KeyPress = [[
/cast Wild Charge
/targetenemy [noharm][dead]
]],
'/castsequence reset=combat Rake,shred,shred,shred,!Rip,Rake,shred,shred,shred,ferocious bite,Rake,shred,shred,shred,ferocious bite',
'/use [combat] Berserk',
'/use [combat] survival instincts',
'/cast Incarnation: King of the Jungle',
KeyRelease = [[
/startattack
/cast Tiger's Fury
]],
}

Sequences['SAM_Boomer'] = {
specID = 102,
author = "Draik",
helpTxt = "2323112",
 KeyPress = [[
/targetenemy [noharm][dead]
/use [noform]!Moonkin Form
]],
'/cast Moonfire',
'/cast Sunfire',
'/castsequence [combat] Solar Wrath,Lunar Strike,Solar Wrath,Lunar Strike,Solar Wrath,Solar Wrath',
'/cast Starsurge',
KeyRelease = [[
/startattack
]],
}


Sequences['SAM_RestoBoomer'] = {
specID = 105,
author = "Draik",
helpTxt = "2312232",
 KeyPress = [[
/targetenemy [noharm][dead]
/use [noform]!Moonkin Form
]],
'/cast Moonfire',
'/cast Sunfire',
'/castsequence [combat] Solar Wrath,Lunar Strike,Solar Wrath,Lunar Strike,Solar Wrath,Solar Wrath',
'/cast Starsurge',
KeyRelease = [[
/startattack
]],
}

Sequences["SAM_druid_bala_st"] = {
specID = 102,
author="someone",
helpTxt = "3333132 CTRL Blessing of the Ancients, Shift Celestial Alignment, Alt Solar Beam",
StepFunction = "Priority",
KeyPress = [[
/targetenemy [noharm][dead]
/cast [noform]!Moonkin Form
/cast [mod:ctrl] Blessing of the Ancients
/cast [mod:shift] Celestial Alignment
/cast [mod:alt] Solar Beam
]],
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
KeyRelease = [[
/startattack
]],
}

Sequences['SAM_KTNDRUHEALS'] = {
specID = 105,
author = "KTN",
helpTxt = "2113112",
KeyPress = [[
/cast [@focus,dead] Rebirth
]],
'/castsequence [@focus] reset=15/combat Lifebloom, Regrowth, Rejuvenation',
'/cast [@focus] Cenarion Ward',
'/castsequence reset=target [@mouseover,exists,help,nodead] Regrowth, Rejuvenation, Healing Touch, Swiftmend',
KeyRelease = [[
/cast [@focus]Ironbark
/cast [@player]Barkskin
]],
}

Sequences['SAM_KTNDRUAOEHEALS'] = {
specID = 105,
author = "KTN",
helpTxt = "2113112",
'/castsequence [@focus] Wild Growth',
}

Sequences['SAM_KTNRestoBoom'] = {
specID = 105,
author = "KTN",
helpTxt = "Talents-2113112",
KeyPress = [[
/cast [@focus,dead] Rebirth
/assist [@focus,exists,nodead]
/targetenemy [noharm]
/use [noform]!Moonkin Form
]],
'/castsequence [combat] Moonfire, Sunfire, Solar Wrath, Lunar Strike, Solar Wrath, Lunar Strike, Solar Wrath, Lunar Strike',
'/cast Starsurge',
KeyRelease = [[
/startattack
]],
}
