local Sequences = GSMasterSequences

------------------
----- Hunter
------------------
-- Beast Mastery 253
-- Survival 255
-- Marksmanship - 254

Sequences['DB_BMsingle'] = {
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

Sequences['DB_BMaoe'] = {
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

Sequences['DB_SurvivelH'] = {
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

Sequences['DB_Mm'] = {
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
]],
}

Sequences['DB_BM'] = {
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

Sequences['DB_BMAOE'] = {
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

Sequences['DB_MMAOE'] = {
author='Nano',
specID=254,
helpTxt = 'Talents: 3113122',
PreMacro=[[
/targetenemy [noharm][dead]
/cast Trueshot
]],
icon='Ability_Hunter_FocusedAim',
'/cast [nochanneling] !Multi-shot',
'/cast [nochanneling] !Marked Shot',
'/cast [nochanneling] Windburst',
'/cast [nochanneling] !Aimed Shot',
'/cast [nochanneling] Piercing Shot',
'/cast [nochanneling] !Multi-shot',
'/cast [nochanneling] !Marked Shot',
PostMacro=[[
/startattack
/petattack
]],
}

Sequences['DB_MMS'] = {
author=Nano,
specID='254',
helpTxt = 'Talents: 3113122',
PreMacro=[[
/targetenemy [noharm][dead]
/cast Trueshot
]],
icon='Ability_Hunter_FocusedAim',
'/cast [nochanneling] !Arcane Shot',
'/cast [nochanneling] !Marked Shot',
'/cast [nochanneling] Windburst',
'/cast [nochanneling] !Aimed Shot',
'/cast [nochanneling] Piercing Shot',
'/cast [nochanneling] !Arcane Shot',
'/cast [nochanneling] !Marked Shot',
PostMacro=[[
/startattack
/petattack
]],
}
