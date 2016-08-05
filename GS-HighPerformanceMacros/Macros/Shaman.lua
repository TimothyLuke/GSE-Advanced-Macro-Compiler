local Sequences = GSMasterSequences

------------------
----- Shaman
------------------
Sequences['HP_enhST'] = {
author = "Rocktris",
helpTxt = "Talents are 3212112",
specID = 263,
lang="enUS",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence Boulderfist',
'/cast Stormstrike',
'/cast Crash Lightning',
'/castsequence Flametongue',
'/cast Feral Spirit',
PostMacro = [[
/startattack
/cast [combat] Doom Winds
/cast [combat] Astral Shift
]],
}
