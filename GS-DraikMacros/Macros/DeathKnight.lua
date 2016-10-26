------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local GNOME, Sequences = ...

------------------
----- Death Knight
------------------

Sequences['DB_Blood'] = {
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

Sequences['DB_DF'] = {
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

Sequences['DB_BloodDK'] = {
StepFunction = GSStaticPriority,
specID = 250,
author = "Owns",
helpTxt = "Talents 2112333",
PreMacro = [[
]],
"/cast Marrowrend",
"/castsequence reset=combat Death's Caress, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike, Death Strike",
'/castsequence reset=combat Blood Boil, Blood Boil, Marrowrend',
'/castsequence reset=combat Heart Strike, Heart Strike, Heart Strike, Heart Strike, Marrowrend',
PostMacro = [[
/targetenemy [noharm][dead]
]],
}

Sequences["DB_SquishyDK"] = {
StepFunction = GSStaticPriority,
specID = 250,
author = "Suiseiseki",
helpTxt = "Talents 2112333",
PreMacro = [[
/cast [combat] Vampiric Blood
/Cast [combat] Dancing Rune Weapon
/cancelaura Wraith Walk
]],
'/castsequence Marrowrend, Marrowrend, Marrowrend, Marrowrend, Death Strike',
"/castsequence reset=combat Death's Caress, Blood Boil, Blood Boil, Marrowrend",
"/cast Death Strike",
"/castsequence reset=combat Death's Caress, Blood Boil, Blood Boil, Heart Strike",
"/cast Heart Strike",
"/cast Death Strike",
'/cast Marrowrend',
PostMacro = [[
/TargetEnemy [noharm][dead]
]],
}
