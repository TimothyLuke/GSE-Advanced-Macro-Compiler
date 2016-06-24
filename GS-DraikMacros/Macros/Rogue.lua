local Sequences = GSMasterSequences

------------------
----- Rogue
------------------
Sequences['ComSimple'] = {
specID = 260,
author = "Draik",
helpTxt = "Single Target",
StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],   PreMacro = [[
/cancelaura Blade Flurry
/targetenemy [noharm][dead]
/startattack
/cast [nostealth,nocombat]Stealth
    ]],
'/castsequence reset=target Revealing Strike,Slice and Dice,null',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Eviscerate',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/castsequence reset=35 Revealing Strike,Slice and DIce',
PostMacro = [[
/cast [combat] Adrenaline Rush
/use [combat]14
/startattack
    ]],

}

Sequences["ROGUE-ASS"] = {
	specID = 259,
	author = "Draik",
	helpTxt = "Rogue Assassination",
	PreMacro = [[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [stealth] Cheap Shot
]],
'/castsequence reset=19 Mutilate,Mutilate,Recuperate,null',
'/castsequence reset=6 Mutilate,Feint,Mutilate,Mutilate,Rupture,Mutilate,Mutilate,Envenom',
'/cast [combat]Cloak of Shadows',
'/cast [combat]Combat Readiness',
'/cast [combat]!Vendetta]]',
'/cast [combat]!Dispatch]]',
'/cast [combat]Evasion]]',
PostMacro = [[
/startattack
]],
}


Sequences['ComSimpleAOE'] = {
specID = 260,
author = "Draik",
helpTxt = "Single Target",
StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],   PreMacro = [[
/cast [nomod] !Blade Flurry
/targetenemy [noharm][dead]
/startattack
    ]],
'/castsequence reset=target Revealing Strike,Slice and Dice,null',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Crimson Tempest',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Sinister Strike',
'/cast Killing Spree', 
'/castsequence reset=35 Revealing Strike,Slice and DIce',
PostMacro = [[
/cast [combat] Adrenaline Rush
/startattack
/use [combat]14
    ]],

}

