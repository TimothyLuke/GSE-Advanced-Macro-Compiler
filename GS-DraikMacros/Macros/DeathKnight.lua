local Sequences = GSMasterSequences

------------------
----- Death Knight
------------------

Sequences['DB_PTRBlood'] = {
specID = 250,
author = "John Mets",
helpTxt = "As for talents (2212213) but does run real smooth if you have Heartbreaker, Soulgorge and Ossuary.",
StepFunction = GSStaticPriority,
PreMacro = [[
/Cast [combat] Vampiric Blood
/Cast [combat] Dancing Rune Weapon
]],
'/cast Marrowrend',
"/castsequence reset=combat Death's Caress, Blood Boil, Death Strike, blood Boil, Marrowrend",
"/castsequence reset=combat Death's Caress, Blood Boil, Blood Boil, death strike, soulgorge",
"/cast Heart Strike",
"/cast Death Strike",
PostMacro = [[
/cast [mod:alt] Anti-Magic Shell
/TargetEnemy [noharm][dead]
/Use [combat] 13
/Use [combat] 14
]],
}

Sequences['DB_DBFrost'] = {
specID = 251,
author = "Suiseiseki",
helpTxt = "Talents: 2132113",
StepFunction = GSStaticPriority,
PreMacro = [[
/use [combat] Obliteration
/use [combat] Pillar Of Frost
]],
'/cast [combat] Glacial Advance',
'/cast Frost Strike',
"/cast [combat] Remorseless Winter",
'/castsequence Howling Blast, Frostscythe, Howling Blast, Obliterate',
'/castsequence Howling Blast, Howling Blast, Frostscythe, Howling Blast, Obliterate',
PostMacro = [[
]],
}

Sequences['DB_FDK2'] = {
specID = 251,
author = "Tazkilla",
helpTxt = "Talents:1111131",
StepFunction = GSStaticPriority,
PreMacro = [[
/cast [combat] Pillar of Frost
/cast [combat] Anti-Magic Shell
]],
'/castsequence reset=combat Frost Strike',
'/cast Obliterate',
'/cast Obliteration',
'/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Obliterate',
'/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Howling Blast',
PostMacro = [[
/targetenemy [noharm][dead]
]],
}

Sequences['DB_DFPTR'] = {
specID = 251,
author = "John Mets",
helpTxt = "Talents 2133121",
StepFunction = GSStaticPriority,
PreMacro = [[
/cast [combat] Pillar of Frost
]],
"/castsequence reset=combat Obliterate, Frost Strike",
'/castsequence reset=combat Obliterate, Frost Strike, Frost Strike, Obliterate, howling blast',
"/castsequence reset=combat Obliteration",
"/cast [combat] remorseless winter",
"/cast [combat] empower rune weapon",
PostMacro = [[
/targetenemy [noharm][dead]
/cast [combat] Anti-Magic Shell
/use [combat] 12
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_DKunholy'] = {
PreMacro = [[
/targetenemy [noharm][dead]
]],
specID = 252,
author = "throwryuken",
helpTxt = "Talents 2221213",
'/cast [nochanneling] Raise Dead',
'/cast [nochanneling] Outbreak',
'/cast [nochanneling] Dark Transformation',
'/cast [nochanneling] Festering Strike',
'/cast [nochanneling] Scourge Strike',
'/cast [nochanneling] Soul Reaper',
'/cast [nochanneling] Death Strike',
'/cast [nochanneling] Summon Gargoyle',
'/cast [nochanneling] Death Coil',
PostMacro = [[
/startattack
]],
}
