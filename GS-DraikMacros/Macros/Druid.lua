local Sequences = GSMasterSequences

------------------
----- Druid
------------------
Sequences['GuardianST'] = {
	specID = 104,
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
/targetenemy [noharm][dead]
/castsequence [@player,nostance:1] Bear Form(Shapeshift)
/cast Wild Charge
]],  '/cast !Mangle',
'/castsequence [combat] reset=target Thrash,Lacerate,Lacerate,Lacerate,Pulverize',
'/castsequence [combat] Savage Defense,Savage Defense,Frenzied Regeneration',
'/cast !Mangle',
'/cast [combat] survival Instincts',
'/cast [combat] Barkskin',
'/cast [combat] Berserk',
'/cast !Mangle',
'/cast [combat] Mighty Bash',
'/cast [combat] Cenarion Ward',	
[[/console autounshift 0
/cast [@player,combat] Healing Touch
/console autounshift 1]],
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['GuardianAoE'] = {
	specID = 104,
	author = "Draik",
	helpTxt = "AoE",
	StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],   PreMacro = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:1] Bear Form(Shapeshift)
/cast Wild Charge
]],  '/cast !Mangle',
'/castsequence [combat] reset=target Thrash,Thrash,Lacerate',
'/castsequence [combat] Savage Defense,Savage Defense,Frenzied Regeneration',
'/cast [combat] survival Instincts',
'/cast [combat] Barkskin',
'/cast !Mangle',
'/cast [combat] Mighty Bash',
'/cast [combat] Cenarion Ward',
[[/console autounshift 0
/cast [@player,combat] Healing Touch
/console autounshift 1]],
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['FeralST'] = {
	specID = 103,
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
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Mark of the Wild,Cat Form(Shapeshift)
/cast [nostealth,nocombat] Prowl
/castsequence [nocombat] reset=target !rake,null
/stopattack [stealth]
]],  '/castsequence [combat,nostealth] reset=target Shred,Shred,Shred,Rip,Rake,Shred,Shred,Shred,Ferocious Bite,Rake,Shred,Savage Roar',
'/cast [combat] Cenarion Ward',
'/cast [combat] Berserk',
[[/cast Tiger's Fury]],
[[/console autounshift 0
/cast [@player,combat] Healing Touch
/console autounshift 1]],
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['FeralCD'] = {
	specID = 103,
	author = "Draik",
	helpTxt = "Feral Cooldowns",
	PreMacro = [[
/targetenemy [noharm][dead]
]],  [[/cast [combat] Incarnation: King of the Jungle]],  '/cast [combat] Berserk',  PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['FeralAoE'] = {
specID = 103,
author = "Draik",
helpTxt = "AoE",
StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],   PreMacro = [[
/targetenemy [noharm][dead]
/castsequence [@player,nostance:2] Mark of the Wild,Cat Form(Shapeshift)
/cast [nostealth,nocombat] Prowl
/castsequence [nocombat] reset=target !rake,null
/stopattack [stealth]
]],  '/castsequence [combat,nostealth] Thrash, Swipe, Swipe, Swipe, Rip, Swipe, Thrash, Swipe, Ferocious Bite',
[[/cast [combat] Tiger's Fury]],
'/cast [combat] Cenarion Ward',	
[[/console autounshift 0
/cast [@player,combat] Healing Touch
/console autounshift 1]],
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['BoomyST'] = { 
	specID = 102,
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
/targetenemy [noharm][dead]
/use [noform]!Moonkin Form
]],
"/castsequence reset=25/target Moonfire",
"/castsequence reset=25/target Sunfire",
"/castsequence reset=10 Force of Nature",
"/cast [nochanneling] Starsurge",
"/cast Starfire",
"/cast [nochanneling] Starsurge",
"/cast [nochanneling] Wrath",
"/cast Celestial Alignment",
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}