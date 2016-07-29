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

Sequences['DB_Mm_ST'] = {
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

Sequences['DB_BM_ST'] = {
specID = 253,
author = "Nano",
helpTxt = "Single Target Talent 3311313",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/petautocastoff [group] Growl
/petautocaston [nogroup] growl
]],
"/castsequence Cobra Shot,Kill Coand",
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
"/castsequence Multi-Shot,Kill Coand",
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

Sequences['DB_Marks_AOE'] = {
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

Sequences['DB_Single_Marls'] = {
author="Nano",
specID=254,
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

Sequences['DB_SURVST'] = {
specID = 255,
author = "yiffking fleabag",
helpTxt = "Single Target - Unknown Talents ",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=8 !Raptor Strike, Lacerate',
'/castsequence Throwing Axes, Aspect of the Eagle, Mongoose Bite, Mongoose Bite, Mongoose Bite',
'/castsequence reset=22 !Snake Hunter, Mongoose Bite, Mongoose Bite, Mongoose Bite',
'/cast Raptor Strike',
'/cast Lacerate',
'/cast !Mongoose Bite',
'/cast Throwing Axes',
'/cast Spitting Cobra',
'/cast Flanking Strike',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_SURVAOE'] = {
specID = 255,
author = "yiffking fleabag",
helpTxt = "AoE - Unknown Talents ",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=8 !Raptor Strike, Carve',
'/castsequence Serpent Sting, Throwing Axes, Aspect of the Eagle, Mongoose Bite, Mongoose Bite, Mongoose Bite',
'/castsequence reset=22 !Snake Hunter, Mongoose Bite, Mongoose Bite, Mongoose Bite',
'/cast Raptor Strike',
'/cast Carve',
'/cast !Mongoose Bite',
'/cast Butchery',
'/cast Spitting Cobra',
'/cast Throwing Axes',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_BMH'] = {
specID = 253,
author = "Moonfale",
helpTxt = "Single Target - Talent: 3322313",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/cast [@pet,dead]Heart of the Phoenix
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
/cast Blood Fury
/cast Intimidation
/cast Bestial Wrath
/cast Aspect of the Wild
]],
'/cast [nochanneling] !kill command',
'/cast [nochanneling] !Dire Beast',
'/cast [nochanneling] Chimaera Shot',
'/cast [nochanneling] A Murder of Crows',
'/cast [nochanneling] Cobra Shot',
PostMacro = [[
/startattack
/petattack
/use [combat]11
/use [combat]13
/use [combat]14
]],
}