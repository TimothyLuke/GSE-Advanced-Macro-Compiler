local Sequences = GSMasterSequences

------------------
----- Shaman
------------------
-- Elemental 262


Sequences['PTREnhST'] = {
specID = 263,
author = "Suiseiseki - stan",
helpTxt = "Single Target",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence [combat] Crash Lightning, Lava Lash, Lava Lash",
"/cast Stormstrike",
"/castsequence Flametongue, Rockbiter, Rockbiter, Rockbiter, Rockbiter, Rockbiter",
'/cast Windsong',
PostMacro = [[
/cast Feral Lunge
/use [combat] 13
/use [combat] 14
/script UIErrorsFrame:Hide();
]],
}


Sequences['enhsingle'] = {
specID = 263,
author = "lloskka",
helpTxt = "Talents  3112112 - Artifact Order: Doom Winds —> Hammer of Storms —> Gathering Storms —> Wind Strikes —> Wind Surge —> Weapons of the elements —> Elemental Healing —> and all the way to Unleash Doom",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/run sfx=GetCVar("Sound_EnableSFX");
/console Sound_EnableSFX 0
]],
[[/castsequence Boulderfist, Crash Lightning, !Stormstrike;]],
[[/castsequence Boulderfist, Stormstrike, Crash Lightning;]],
[[/castsequence [nochanneling] Boulderfist, Boulderfist, !Crash Lightning;]],
[[/castsequence Boulderfist, Boulderfist;]],
[[/cast Lightning Bolt;]],	
PostMacro = [[
/startattack
/use [combat] 11
/use [combat] 12
/cast [combat] Doom Winds
/cast [combat] 
/run UIErrorsFrame:Clear()
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}



Sequences['RestoDeeps'] = {
specID = 264,
author = "Draik",
helpTxt = "Talents - 3211233",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Chain Lightning',
'/cast Flame Shock',
'/cast Eathern Shield Totem',
'/cast Lava Burst',
'/cast Lightning Bold',
'/cast Lightning Surge Totem',
PostMacro = [[
/use [combat] 13
/use [combat] 14
/script UIErrorsFrame:Hide();
]],
}
