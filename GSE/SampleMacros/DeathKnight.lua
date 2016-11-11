local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[6] = {}

local Sequences = Statics.SampleMacros[6]
------------------
----- Death Knight
------------------

Sequences['SAM_Blood'] = {
specID = 250,
author = "John Mets",
helpTxt = "As for talents (2212213) but does run real smooth if you have Heartbreaker, Soulgorge and Ossuary.",
StepFunction = "Priority",
KeyPress = [[
/Cast [combat] Vampiric Blood
/Cast [combat] Dancing Rune Weapon
]],
'/cast Marrowrend',
"/castsequence reset=combat Death's Caress, Blood Boil, Death Strike, blood Boil, Marrowrend",
"/castsequence reset=combat Death's Caress, Blood Boil, Blood Boil, death strike, soulgorge",
"/cast Heart Strike",
"/cast Death Strike",
KeyRelease = [[
/cast [mod:alt] Anti-Magic Shell
/TargetEnemy [noharm][dead]
]],
}

Sequences['SAM_DBFrost'] = {
specID = 251,
author = "Suiseiseki",
helpTxt = "Talents: 2132113",
StepFunction = "Priority",
KeyPress = [[
/use [combat] Obliteration
/use [combat] Pillar Of Frost
]],
'/cast [combat] Glacial Advance',
'/cast Frost Strike',
"/cast [combat] Remorseless Winter",
'/castsequence Howling Blast, Frostscythe, Howling Blast, Obliterate',
'/castsequence Howling Blast, Howling Blast, Frostscythe, Howling Blast, Obliterate',
KeyRelease = [[
]],
}

Sequences['SAM_FDK2'] = {
specID = 251,
author = "Tazkilla",
helpTxt = "Talents:1111131",
StepFunction = "Priority",
KeyPress = [[
/cast [combat] Pillar of Frost
/cast [combat] Anti-Magic Shell
]],
'/castsequence reset=combat Frost Strike',
'/cast Obliterate',
'/cast Obliteration',
'/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Obliterate',
'/castsequence reset=combat Howling Blast, Howling Blast, Howling Blast, Howling Blast',
KeyRelease = [[
/targetenemy [noharm][dead]
]],
}

Sequences['SAM_DF'] = {
specID = 251,
author = "John Mets",
helpTxt = "Talents 2133121",
StepFunction = "Priority",
KeyPress = [[
/cast [combat] Pillar of Frost
]],
"/castsequence reset=combat Obliterate, Frost Strike",
'/castsequence reset=combat Obliterate, Frost Strike, Frost Strike, Obliterate, howling blast',
"/castsequence reset=combat Obliteration",
"/cast [combat] remorseless winter",
"/cast [combat] empower rune weapon",
KeyRelease = [[
/targetenemy [noharm][dead]
/cast [combat] Anti-Magic Shell
]],
}

Sequences['SAM_DKunholy'] = {
KeyPress = [[
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
KeyRelease = [[
/startattack
]],
}

Sequences['SAM_BloodDK'] = {
StepFunction = "Priority",
specID = 250,
author = "Owns",
helpTxt = "Talents 2112333",
KeyPress = [[
]],
"/cast Marrowrend",
"/castsequence reset=combat Death's Caress, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike",
'/castsequence reset=combat Blood Boil, Blood Boil, Marrowrend',
'/castsequence reset=combat Heart Strike, Heart Strike, Heart Strike, Heart Strike, Marrowrend',
KeyRelease = [[
/targetenemy [noharm][dead]
]],
}
