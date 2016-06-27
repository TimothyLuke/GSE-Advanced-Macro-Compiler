local Sequences = GSMasterSequences

------------------
----- Warrior
------------------
-- PROT - 73
-- ARMS - 71



---Legion Fury Warrior - 2,3,3,2,2,2,3

Sequences["Fury1"] = {
	specID = 72,
	author = "Firone - wowlazymacros.com",
	helpTxt = "Single Target -- 2,3,3,2,2,2,3",
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

Sequences["Fury2"] = { 
specID = 72,
author = "Firone - wowlazymacros.com",
helpTxt = "AOE -- 2,3,3,2,2,2,3",
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