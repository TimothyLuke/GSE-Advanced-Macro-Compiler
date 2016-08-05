local Sequences = GSMasterSequences

------------------
----- Hunter
------------------
Sequences['HP_RBMAoE'] = {
specID = 253,
author = "John",
helpTxt = "Raiding AoE - Talent: 3212233",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
]],
"/cast [nochanneling] Bestial Wrath",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Dire Frenzy",
"/cast [nochanneling] Multi-Shot",
"/cast [nochanneling] Titan's Thunder",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Bestial Wrath",
PostMacro = [[
/cast Aspect of the Wild
]],
}

Sequences['HP_RBMmain'] = {
specID = 253,
author = "John",
helpTxt = "Raiding main - Talent: 3212233",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
]],
"/cast [nochanneling] Bestial Wrath",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Dire Frenzy",
"/cast [nochanneling] Concussive Shot",
"/cast [nochanneling] Cobra Shot",
"/cast [nochanneling] Titan's Thunder",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Bestial Wrath",
PostMacro = [[
/cast Aspect of the Wild
]],
}

Sequences['HP_lookdead'] = {
specID = 253,
author = "John",
helpTxt = "Look Dead - Talent: 3222321",
icon = "Ability_Mage_TormentOfTheWeak",
StepFunction = GSStaticPriority,
"/cast [nochanneling] Feign Death",
"/cast [nochanneling] Play Dead",
}

Sequences['HP_OShit'] = {
specID = 253,
author = "John",
helpTxt = "Oh Shit - Talent: 3222321",
icon = "Ability_Hunter_MendPet",
StepFunction = GSStaticPriority,
"/cast Aspect of the Turtle",
"/cast [target=player, help] Spirit Mend",
"/cast [nochanneling] Exhilaration",
"/cast [nochanneling] !mend pet",
"/use Healing Tonic",
}

Sequences['HP_BMburst'] = {
specID = 253,
author = "John",
helpTxt = "BMAoE - Talent: 3222321",
icon = "Ability_Hunter_KillCommand",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
]],
"/cast [nochanneling] Bestial Wrath",
"/cast [nochanneling] Stampede",
"/cast [nochanneling] Intimidation",
"/cast Barrage",
"/cast [nochanneling] Multi-Shot",
"/cast [nochanneling] Titan's Thunder",
PostMacro = [[
/cast Aspect of the Wild
]],
}

Sequences['HP_Healpet'] = {
specID = 253,
author = "John",
helpTxt = "Pet Heal - Talent: 3222321",
StepFunction = GSStaticPriority,
"/cast [nochanneling] !mend pet",
"/cast [nochanneling] Exhilaration",
}

Sequences['HP_BM2'] = {
specID = 253,
author = "John",
helpTxt = "Without Barrage - Talent: 3222321",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
]],
"/cast [nochanneling] Bestial Wrath",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Dire Frenzy",
"/cast [nochanneling] Intimidation",
"/cast [nochanneling] Cobra Shot",
"/cast [nochanneling] Concussive Shot",
"/cast [nochanneling] Titan's Thunder",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Bestial Wrath",
PostMacro = [[
/cast Aspect of the Wild
]],
}

Sequences['HP_BM1'] = {
specID = 253,
author = "John",
helpTxt = "With Barrage - Talent: 3222321",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
/petattack [@target,harm]
/petautocastoff [group] Growl
/petautocaston [nogroup] Growl
/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection
]],
"/cast [nochanneling] Bestial Wrath",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Intimidation",
"/cast [nochanneling] Dire Frenzy",
"/cast Barrage",
"/cast [nochanneling] Titan's Thunder",
"/cast [nochanneling] !Kill Command",
"/cast [nochanneling] Bestial Wrath",
PostMacro = [[
/cast Aspect of the Wild
]],
}
