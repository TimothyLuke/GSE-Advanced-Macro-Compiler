------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local Sequences = GSMasterSequences

------------------
----- Shaman
------------------
-- Elemental 262


Sequences['DB_EnhST'] = {
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
]],
}


Sequences['DB_enhsingle'] = {
specID = 263,
author = "lloskka",
helpTxt = "Talents  3112112 - Artifact Order: Doom Winds �> Hammer of Storms �> Gathering Storms �> Wind Strikes �> Wind Surge �> Weapons of the elements �> Elemental Healing �> and all the way to Unleash Doom",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence Boulderfist, Crash Lightning, !Stormstrike;",
"/castsequence Boulderfist, Stormstrike, Crash Lightning",
"/castsequence [nochanneling] Boulderfist, Boulderfist, !Crash Lightning;",
"/castsequence Boulderfist, Boulderfist;",
"/cast Lightning Bolt",
PostMacro = [[
/startattack
/use [combat] 11
/use [combat] 12
/cast [combat] Doom Winds
]],
}

Sequences['DB_ENLegi'] = {
specID = 263,
author = "Andy",
helpTxt = "Talents  1313211",
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
'/castsequence [nochanneling]!Rockbiter,!Lava Lash,!frostbrand,!Lava Lash,!frostbrand',
'/castsequence [nochanneling]reset=6/target !Crash Lightning',
'/castsequence [nochanneling]reset=8.2/target Lightning Bolt',
'/castsequence [nochanneling]reset=11/target !Flametongue',
'/castsequence [nochanneling]reset=15/target !Stormstrike',
'/castsequence [nochanneling]reset=45/target !windsong',
'/castsequence [nochanneling]reset=120/target !Feral Spirit',
'/castsequence [nochanneling]reset=300/target !ascendance',
'/cast !stormstrike',
PostMacro = [[
/cast [combat] Blood Fury
/use [combat] 13
/use [combat] 14
]],
}


Sequences['DB_RestoDeeps'] = {
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
]],
}

Sequences['DB_ElemAoE'] = {
specID = 262,
author = "Nano",
helpTxt = 'Talents: 1213132',
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=target/combat Flame Shock,Chain Lightning,Chain Lightning,Chain Lightning',
'/cast [nochanneling] !Lava Burst',
PostMacro = [[
/cast Blood Fury
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_ElemAoE'] = {
specID = 262,
author = "Nano",
helpTxt = 'Talents: 1213112',
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=target/combat Flame Shock,Chain Lightning,Chain Lightning,Chain Lightning',
'/cast [nochanneling] !Lava Burst',
PostMacro = [[
/cast Elemental Mastery
/cast Blood Fury
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_Elem'] = {
specID = 262,
author = "Nano",
helpTxt = 'Talents: 1213132',
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=target/combat Flame Shock,Lightning Bolt,Lightning Bolt,Lightning Bolt',
'/castsequence reset=10 !Earth Shock',
'/cast [nochanneling] !Lava Burst',
PostMacro = [[
/cast Blood Fury
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_Elem'] = {
specID = 262,
author = "Nano",
helpTxt = 'Talents: 1213112',
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=target/combat Flame Shock,Lightning Bolt,Lightning Bolt,Lightning Bolt',
'/castsequence reset=10 !Earth Shock',
'/cast [nochanneling] !Lava Burst',
PostMacro = [[
/cast Elemental Mastery
/cast Blood Fury
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_MC_ElemST'] = {
author='Maalkomx',
specID=262,
helpTxt = 'Talents: 2112211',
PreMacro=
[[
/targetenemy [noharm][dead]
/petattack [@target,harm]
]],
"/castsequence reset=combat [nopet:Earth Elemental] Fire Elemental",
"/castsequence [nochanneling] reset=combat Lava Burst, Flame Shock, Lava Burst",
"/castsequence [nochanneling] Lightning Bolt, Lightning Bolt, Lightning Bolt, Lightning Bolt",
"/cast Lava Burst",
PostMacro=[[
/use [combat] 14
/use [combat] 13
]],
}

Sequences['DB_MC_ElemAoE'] = {
author='Maalkomx',
specID=262,
helpTxt = 'Talents: 2112211',
PreMacro=[[
/targetenemy [noharm][dead]
/petattack [@target,harm]
]],
"/castsequence reset=combat [nopet:Earth Elemental] Fire Elemental",
"/castsequence [nochanneling] reset=combat Lava Burst, Flame Shock, Lava Burst",
"/castsequence [nochanneling] Chain Lightning, Chain Lightning, Chain Lightning",
"/cast Lava Burst",
PostMacro=[[
/use [combat] 14
/use [combat] 13
]],
}

Sequences['DB_MC_Surge'] = {
author='Maalkomx',
specID=264,
helpTxt = 'Talents: 3313313',
PreMacro=[[
]],
"/castsequence [nochanneling]reset=30 Healing Stream Totem",
"/castsequence [nopet,nodead][nochanneling,target=mouseover,help]reset=5 !Riptide",
"/castsequence [nochanneling,target=mouseover,help]Healing Surge, Healing Surge, Healing Surge, Healing Surge",
"/castsequence [nochanneling,target=mouseover,help]Healing Surge",
PostMacro=[[
/startattack
]],
}

Sequences['DB_MC_Wave'] = {
author='Maalkomx',
specID=264,
helpTxt = 'Talents: 3313313',
PreMacro=[[
]],
"/castsequence [nochanneling]reset=30 Healing Stream Totem",
"/castsequence [nopet,nodead][nochanneling,target=mouseover,help]reset=5 !Riptide",
"/castsequence [nochanneling,target=mouseover,help]Healing Wave, Healing Wave, Healing Wave, Healing Wave",
"/castsequence [nochanneling,target=mouseover,help]Healing Wave",
PostMacro=[[
/startattack
]],
}

Sequences['DB_MC_Chain'] = {
author='Maalkomx',
specID=264,
helpTxt = 'Talents: 3313313',
PreMacro=[[
]],
"/castsequence [nochanneling]reset=30 Healing Stream Totem",
"/castsequence [nopet,nodead][nochanneling,target=mouseover,help]reset=5 !Riptide",
"/castsequence [nochanneling,target=mouseover,help]Chain Heal, Chain Heal, Chain Heal, Chain Heal",
"/castsequence [nochanneling,target=mouseover,help]Healing Surge",
PostMacro=[[
/startattack
]],
}
