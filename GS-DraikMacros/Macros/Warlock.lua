local Sequences = GSMasterSequences
------------------
----- Warlock
------------------
-- Affliction Legion
-- talents 2111212
Sequences['AFF'] = {
specID = 265,
author = "Jimmy",
helpTxt = "Talents - 3,1,3,1,2,1,2",
PreMacro = [[
/targetenemy [noharm][dead],
/startattack
]],
'/cast [nochanneling] Agony',
'/cast [nochanneling] Corruption',
'/cast [nochanneling] Unstable Affliction',
'/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
'/cast [nochanneling] Reap Souls',
PostMacro = [[
/startattack
/petattack
/use [combat]13
/use [combat]14
]],
}


Sequences['AFF2'] = {
specID = 265,
author = "Jimmy",
helpTxt = "Talents - 3,1,3,1,2,1,2",
PreMacro = [[
/targetenemy [noharm][dead],
/startattack
]],
'/cast [nochanneling] Agony',
'/cast [nochanneling] Corruption',
'/cast [nochanneling] Unstable Affliction',
'/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
'/cast [nochanneling] Phantom Singularity',
'/cast [nochanneling] Reap Souls',
PostMacro = [[
/startattack
/petattack
/use [combat]13
/use [combat]14
]],
}


Sequences['Demon'] = {
specID = 266,
author = "Jimmy",
helpTxt = "Talents - 3,2,1,2,2,1,3",
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
"/castsequence [nochanneling] Doom,Demonic Empowerment,Demonwrath",
"/cast [nochanneling] Shadow Bolt",
"/cast [nochanneling] Shadow Bolt",
"/cast [nochanneling] Life Tap",
PostMacro = [[
/startattack
/petattack
/use [combat]13
/use [combat]14
]],
}

Sequences['Destro'] = {
specID = 267,
author = "Jimmy",
helpTxt = "Talents - 1,1,1,2,2,1,3",
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
"/cast [nochanneling] Conflagrate",
"/castsequence [nochanneling] Incinerate,Immolate,Incinerate,Immolate,Drain Life",
PostMacro = [[
/startattack
/petattack
/use [combat]13
/use [combat]14
]],
}
