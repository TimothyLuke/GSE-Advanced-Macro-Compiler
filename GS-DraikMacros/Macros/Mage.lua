local Sequences = GSMasterSequences

------------------
----- Mage
------------------
-- Fire 63
-- Frost 64


------------------------
Sequences['ArcaneLegion'] = {
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

Sequences['PTRfire'] = {
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
