local Sequences = GSMasterSequences

------------------
----- Warrior
------------------
-- ARMS - 71



---Legion Fury Warrior - 2,3,3,2,2,2,3

Sequences['DB_Fury1'] = {
specID = 72,
author = "Firone - wowlazymacros.com",
helpTxt = "Single Target -- 2,3,3,2,2,2,3",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/cast [combat] Berserker Rage
/cast [combat] Bloodbath
/cast [combat] Avatar
]],
[[/cast Execute]],
[[/castsequence reset=60 Rampage,Battle Cry]],
[[/cast Rampage]],
[[/cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar]],
[[/cast Bloodthirst]],
[[/cast Raging Blow]],
[[/cast Furious Slash]],
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_Fury2'] = {
specID = 72,
author = "Firone - wowlazymacros.com",
helpTxt = "AOE -- 2,3,3,2,2,2,3",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/cast [combat] Berserker Rage
]],
[[/cast [talent:7/1] Bladestorm;[talent:7/3] Dragon Roar]],
[[/cast !Whirlwind]],
[[/cast !Raging blow]],
[[/cast !Bloodthirst]],
PostMacro = [[
/cast [combat]Berserker Rage
/use [combat]13
/use [combat]14
]],
}




Sequences['DB_Fury3'] = {
specID = 72,
author = "Firone modified by obst- wowlazymacros.com",
helpTxt = "AOE -- 2,3,3,2,2,2,3 Bladestorm, Dragon Roar, and Battle Cry have also been removed to create better control ass to your bars and use manually",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/cast [modifier:alt]Charge
/cast [combat] Bloodbath
/cast [combat] Avatar
]],
'/cast Execute',
'/castsequence reset=60 Rampage',
'/cast Rampage',
'/cast Bloodthirst',
'/cast Furious Slash',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_Fury4'] = {
specID = 72,
author = "Firone mod by Obst- wowlazymacros.com ",
helpTxt = "AOE -- 2,3,3,2,2,2,3 Bladestorm, Dragon Roar, and Battle Cry have also been removed to create better control ass to your bars and use manually",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/cast [modifier:alt]Charge
]],
'/cast !Whirlwind',
'/cast !Raging blow',
'/cast !Bloodthirst',
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}


Sequences['ProtWar'] = {
specID = 73,
author = "Suiseiseki - wowlazymacros.com",
helpTxt = "Talents: 1223212",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence Devastate",
"/castsequence Shield Slam",
"/castsequence Revenge",
"/castsequence Ignore Pain",
"/castsequence Focused Rage",
"/castsequence [combat] Thunder Clap, Shield Block",
"/castsequence [combat] Shockwave",
"/castsequence Shield Slam",
'/cast Victory Rush',
PostMacro = [[
/cast [combat] Demoralizing Shout
/cast [combat] Battle Cry
/use [combat] 13
/use [combat] 14
]],
}
