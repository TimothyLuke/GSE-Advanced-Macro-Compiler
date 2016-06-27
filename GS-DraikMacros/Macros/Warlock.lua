local Sequences = GSMasterSequences
------------------
----- Warlock
------------------
-- Affliction Legion
-- talents 2111212
Sequences['aff'] = {
specID = 265,
author = "Ojoverde",
helpTxt = "Single Target talents 2111212",
PreMacro = [[
'/targetenemy [noharm][dead]',
'/petattack [@target,harm]'
]],
'/castsequence [nochanneling] reset=target/38 Agony,Corruption,Unstable Affliction,siphon life, drain life, life tap',
'/cast [combat] phantom singularity',
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}

Sequences['AFF2'] = {
	specID = 265,
	author = "TBA - Fiddle Pacific?",
	helpTxt = "Single Target - Talents",
StepFunction = [[
limit = limit or 1
if step == limit then
limit = limit % #macros + 1
step = 1
else
step = step % #macros + 1
end
]],
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/console Sound_EnableSFX 0
]],
"/castsequence [nochanneling] reset=target Agony,Corruption,Siphon Life,Unstable Affliction,Drain Soul,Drain Soul,Unstable Affliction,Corruption,Siphon Life,Drain Soul,Drain Soul",
'/castsequence [nochanneling] reset=target Unending Resolve, Phantom Singularity',
'/cast [nochanneling, combat] Reap Souls',
PostMacro = [[
/startattack
/petattack
/use [combat]13
/use [combat]14
/script UIErrorsFrame:Clear()
/console Sound_EnableSFX 1
]],
}