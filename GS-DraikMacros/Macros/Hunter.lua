local Sequences = GSMasterSequences

------------------
----- Hunter
------------------
-- Beast Mastery 253
-- Survival 255
-- Marksmanship - 254

Sequences['BMsingle'] = {
	specID = 253,
	author = "Jimmy Boy Albrecht",
 	helpTxt = "Single Target - Talent: 3111323",
	StepFunction = GSStaticPriority,
   PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
/cast [nochanneling] Intimidation
]], 
 
'/cast [nochanneling] Cobra Shot',
'/cast [nochanneling] !Kill Command',
'/cast [nochanneling] Bestial Wrath',
'/cast [nochanneling] !Dire Beast',
'/cast [nochanneling] Barrage',

PostMacro = [[
/startattack
/petattack
/cast Aspect of the Wild
/use [combat]13
/use [combat]14
]],
}

Sequences['BMaoe'] = {
	specID = 253,
	author = "Jimmy Boy Albrecht",
	helpTxt = "AoE - Talent: 3111323",
	StepFunction = GSStaticPriority,
   PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
/cast [nochanneling] Intimidation
]], 
 
'/cast [nochanneling] Multi-Shot',
'/cast [nochanneling] !Kill Command',
'/cast [nochanneling] Bestial Wrath',
'/cast [nochanneling] !Dire Beast',
'/cast [nochanneling] Barrage',

PostMacro = [[
/startattack
/petattack
/cast Aspect of the Wild
/use [combat]13
/use [combat]14
]],
}

Sequences['SurvivelH'] = {
	specID = 255,
	author = "Jimmy Boy Albrecht",
 	helpTxt = "Single Target - Talent: 3111323",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Mongoose Bite',
'/cast Lacerate',
'/cast Flanking Strike',
'/cast A Murder of Crows',
'/cast Raptor Strike',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}