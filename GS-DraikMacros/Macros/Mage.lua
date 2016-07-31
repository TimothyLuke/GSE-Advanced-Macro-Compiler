------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local Sequences = GSMasterSequences

------------------
----- Mage
------------------
-- Fire 63
-- Frost 64


------------------------
Sequences['DB_Arcane'] = {
specID = 62,
author = "Flashgreer - wowlazymacros.com",
helpTxt = "2122132",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence [nochanneling]Arcane Blast,Arcane Blast,Arcane Blast,Arcane Blast,Arcane Barrage',
'/cast [nochanneling]Arcane Missiles',
'/castsequence [nochanneling]charged up, Arcane Barrage',
'/cast [nochanneling]Rune of power',
PostMacro = [[
/startattack
/cast [combat]Arcane Power
/cast [combat]Presence of Mind
]],
}

Sequences['DB_Fire'] = {
specID = 63,
author = "John Mets - wowlazymacros.com",
helpTxt = "Talents - 2233111",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence reset=combat Fireball, Fireball, Fireball, Fireball, Fire Blast, Pyroblast",
"/cast Combustion",
"/cast Living Bomb",
"/cast Ice flows",
PostMacro = [[
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_Frosty'] = {
author='Sceptre',
specID=64,
helpTxt = 'Talents: 1322112',
icon='Spell_Frost_FrostBolt02',
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nopet,nomod] Summon Water Elemental
]],
"/cast [nochanneling] Rune of Power",
"/cast [nochanneling] Ray of Frost",
"/cast [nochanneling] Frost Bomb",
"/cast [nochanneling] Frozen Orb",
"/cast [nochanneling] Frozen Touch",
"/cast [nochanneling] Ice Lance",
"/cast [nochanneling] Flurry",
"/cast [nochanneling] Ice Lance",
"/cast [nochanneling] Glacial Spike",
"/cast [nochanneling] Frostbolt",
PostMacro=[[
/startattack
/use [combat]13
/use [combat]14
/cast [nochanneling] Ice Barrier
/cast [nochanneling] Ice Floes
/cast [nochanneling] Icy Veins
/cast [nochanneling] Frozen Orb
]],
}

Sequences['DB_AaslaanFire'] = {
author="Ambergreen",
specID=63,
helpTxt = 'Talents: 2131111',
PreMacro=[[
/targetenemy [noexists][noharm][dead]
]],
icon='Spell_Fire_FireBolt02',
"/cast [nochanneling]Rune of power",
"/castsequence [nochanneling] reset=combat/target Fireball,Fireball,Fireball",
"/castsequence [nochanneling,@target] reset=12/target Living Bomb",
"/castsequence [nochanneling,@target] reset=4/target Blast Wave",
"/castsequence [nochanneling] reset=combat/target Fire Blast",
"/castsequence [nochanneling,mod:alt] Combustion",
"/cast [nochanneling]Ice Barrier",
PostMacro=[[
/use [combat] 13
/use [combat] 14
]],
}
