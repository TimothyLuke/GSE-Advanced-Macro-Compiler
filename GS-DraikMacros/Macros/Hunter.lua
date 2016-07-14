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

Sequences['Mmtest'] = {
specID = 254,
author = "emanuel",
helpTxt = "Single Target - Talent: 3312123",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/cast Trueshot
]],
'/cast !A Murder of Crows',
'/cast !Arcane Shot',
'/cast !Marked Shot',
'/cast !Aimed Shot',
'/cast !Bursting Shot',
'/cast !Black Arrow',
PostMacro = [[
/startattack
/petattack
/script UIErrorsFrame:Clear()
]],
}

Sequences['BMTest'] = {
specID = 253,
author = "Nano",
helpTxt = "Single Target Talent 3311313",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/petautocastoff [group] Growl
/petautocaston [nogroup] growl
]],
"/castsequence Cobra Shot,Kill Command",
"/cast !Chimaera Shot",
"/cast !Dire Beast",
"/cast Cobra Shot",
"/cast Bestial Wrath",
"/cast Titan's Thunder",
"/cast A Murder of Crows",
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['BMAOETest'] = {
specID = 253,
author = "Nano",
helpTxt = "BMAOE Talent 3311313",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/petautocastoff [group] Growl
/petautocaston [nogroup] growl
]],
"/castsequence Multi-Shot,Kill Command",
"/cast !Chimaera Shot",
"/cast !Dire Beast",
"/cast Cobra Shot",
"/cast Bestial Wrath",
"/cast Titan's Thunder",
"/cast A Murder of Crows",
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}
