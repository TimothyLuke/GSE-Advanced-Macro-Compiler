local Sequences = GSMasterSequences

------------------
----- Druid
------------------
--Guardian 104
--Feral 103
--Balance 102

Sequences["Legionbear1"] = {
specID = 104,
author = "Druccy www.wowlazymacros.com",
helpTxt = " —2331111—",
PreMacro = [[
/targetenemy [noharm][dead]reset=target,
/console Sound_EnableSFX 0
]],
[[/cast !Mangle]],
[[/castsequence Thrash,Moonfire,Maul,Swipe]],
[[/castsequence reset=target Savage Defense,Swipe,Swipe,Savage Defense,Frenzied Regeneration,Iron Fur]],
[[/castsequence [combat] reset=target Moonfire, Mass Entanglement,Iron Fur]],
[[/cast Survival Instincts]],
[[/cast Thrash]],
[[/castsequence Swipe,Moonfire,Maul,Mangle,Iron Fur]],
[[/cast Thrash]],
[[/castsequence Swipe,Moonfire,Maul,Mangle,Iron Fur]],
[[/cast Thrash]],
[[/cast Pulverize]],
[[/cast Incapacitating Roar]],
[[/castsequence reset=12 Maul]],
[[/castsequence [combat] reset=60 Barkskin]],
[[/castsequence [combat] reset=50 Mighty Bash]],
[[/castsequence [combat] reset=180 Berserk]],
[[/castsequence reset=30 cenarion ward]],
[[/cast !Mangle]],
PostMacro = [[
/startattack
/script UIErrorsFrame:Clear()
/console Sound_EnableSFX 1
]],
}

Sequences["legionbear2"] = {
specID = 104,
author = "Druccy www.wowlazymacros.com",
helpTxt = " —2331111—",
PreMacro = [[
/targetenemy [noharm][dead]reset=target
]],
[[/castsequence Thrash,Thrash,Thrash,Pulverize]],
[[/castsequence reset=5 Savage Defense,Swipe,Swipe,Frenzied Regeneration]],
[[/castsequence [combat] reset=target Moonfire, Mass Entanglement]],
[[/cast !Mangle]],
[[/castsequence reset=12 Maul]],
[[/cast Survival Instincts]],
[[/cast Thrash]],
[[/castsequence Swipe,Moonfire,Maul,Mangle]],
[[/cast Thrash]],
[[/castsequence Swipe,Moonfire,Maul,Mangle]],
[[/cast Thrash]],
[[/cast Pulverize]],
[[/cast Incapacitating Roar]],
[[/castsequence [combat] reset=60 Barkskin]],
[[/castsequence [combat] reset=180 Berserk]],
[[/castsequence reset=30 cenarion ward]],
PostMacro = [[
/startattack
/script UIErrorsFrame:Clear()
/console Sound_EnableSFX 1
]],
} 

Sequences['Feral-ST'] = {
specID = 103,
author = "Jimmy www.wowlazymacros.com",
helpTxt = "2231123",
StepFunction = GSStaticPriority,   
PreMacro = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Cat Form(Shapeshift)
/cast [nostealth,nocombat] Prowl
/stopattack [stealth]
]],
'/castsequence [combat,nostealth] Rake,Shred,Shred,Rake,Shred,Rip',
'/castsequence [combat,nostealth] Shred,Rake,Shred,Shred,Rake,Ferocious Bite',
PostMacro = [[
/startattack
/cast Tiger's Fury
/use [combat]13
/use [combat]14
]],
}

Sequences['Feral-AoE'] = {
specID = 103,
author = "Jimmy www.wowlazymacros.com",
helpTxt = "2231123",
StepFunction = GSStaticPriority, 
 PreMacro = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Cat Form(Shapeshift)
/cast [nostealth,nocombat] Prowl
/stopattack [stealth]
]],
'/castsequence [combat,nostealth] Thrash,Swipe,Swipe,Thrash,Swipe,Rip',
'/castsequence [combat,nostealth] Swipe,Thrash,Swipe,Swipe,Thrash,Ferocious Bite',
PostMacro = [[
/startattack
/cast Tiger's Fury
/use [combat]13
/use [combat]14
]],
}

Sequences['feralaoe'] = {
specID = 103,
author = "lloskka www.wowlazymacros.com",
helpTxt = "Talents 2331223",
PreMacro = [[
/targetenemy [noharm][dead]
/use [noform:2]Cat Form
/cast [nostealth,nocombat] Prowl
/console Sound_EnableSFX 0
	]],
	[[/cast [combat] !Incarnation: King of the Jungle]],
	[[/cast [combat] !Mighty Bash]],
	[[/castsequence reset=combat Rake,Thrash,Swipe,Swipe,Swipe,Ferocious Bite]],
	PostMacro = [[
/cast [combat] !survival Instincts
/cast [combat] !Tiger's Fury
/use [combat] 11
/use [combat] 12
/startattack
/run UIErrorsFrame:Clear()
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}

Sequences['feralsingle'] = {
specID = 103,
author = "lloskka www.wowlazymacros.com",
helpTxt = "Talents 2331223",
PreMacro = [[
/cast Wild Charge
/targetenemy [noharm][dead]
/run sfx=GetCVar("Sound_EnableSFX");	]],
'/castsequence reset=combat Rake,shred,shred,shred,!Rip,Rake,shred,shred,shred,ferocious bite,Rake,shred,shred,shred,ferocious bite',
'/use [combat] Berserk',
'/use [combat] survival instincts',
'/cast Incarnation: King of the Jungle',
PostMacro = [[
/startattack
/cast Tiger's Fury
/use [combat] 11
/use [combat] 12
/run UIErrorsFrame:Clear()
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}

Sequences['Boomer'] = {
specID = 102,
author = "Draik",
helpTxt = "2323112",
 PreMacro = [[
/targetenemy [noharm][dead]
/use [noform]!Moonkin Form
]],
'/cast Moonfire',
'/cast Sunfire',
'/castsequence [combat] Solar Wrath,Lunar Strike,Solar Wrath,Lunar Strike,Solar Wrath,Solar Wrath',
'/cast Starsurge',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}


Sequences['RestoBoomer'] = {
specID = 105,
author = "Draik",
helpTxt = "2312232",
 PreMacro = [[
/targetenemy [noharm][dead]
/use [noform]!Moonkin Form
]],
'/cast Moonfire',
'/cast Sunfire',
'/castsequence [combat] Solar Wrath,Lunar Strike,Solar Wrath,Lunar Strike,Solar Wrath,Solar Wrath',
'/cast Starsurge',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}