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
author='Draik',
specID='64',
helpTxt = 'Talents: 1222112',
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nopet,nomod] Summon Water Elemental]],
icon='Spell_Frost_FrostBolt02',
"/cast [combat]Rune of Power",
"/cast [nochanneling]Ray of Frost",
"/cast [combat]Rune of Power",
"/cast Frost Bomb",
"/cast Frozen Orb",
"/cast Frozen Touch",
"/cast Ice Lance",
"/cast Flurry",
"/cast Water Jet",
"/cast Frostbolt",
"/cast Frostbolt",
"/cast Ice Lance",
"/cast Glacial Spike",
"/cast Frostbolt",
PostMacro=[[
/startattack
/use [combat]13
/use [combat]14
/use [combat]Ice Floes
/use [combat]Icy Veins
/use [combat]Mirror Image
/use [combat]Frozen Orb
]],
}
