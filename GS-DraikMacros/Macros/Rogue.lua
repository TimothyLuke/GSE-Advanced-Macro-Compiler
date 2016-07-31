local Sequences = GSMasterSequences

------------------
----- Rogue
------------------
-- Outlaw 260
-- Assination 259



Sequences['DB_Outlaw'] = {
specID = 260,
author = "Suiseiseki - www.wowlazymacros.com",
helpTxt = "Outlaw - 1223122",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [combat] Marked for Death
]],
'/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Saber Slash',
'/castsequence Saber Slash, Run Through, Saber Slash, Pistol Shot',
'/castsequence [talent:7/1] Slice and Dice; [talent:7/2][talent:7/3] Roll the Bones, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot, Run Through, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot',
'/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot',
'/cast [@focus] Tricks of the Trade',
PostMacro = [[
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_Assassin'] = {
author='TimothyLuke',
specID=259,
helpTxt = 'Talents: 3113231',
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
]],
icon='Ability_Rogue_DeadlyBrew',
"/cast [@focus] Tricks of the Trade",
"/cast Rupture",
"/cast Vendetta",
"/cast Vanish",
"/cast Hemorrhage",
"/cast Garrote",
"/cast Exsanguinate",
"/cast Envenom",
"/cast Mutilate",
PostMacro=[[
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_Subtle'] = {
author='TimothyLuke',
specID=261,
helpTxt = 'Talents: 1233212',
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [combat] Marked for Death
]],
icon='Ability_Stealth',
"/cast [@focus] Tricks of the Trade",
"/cast Symbols of Death",
"/cast Shadowstrike",
"/cast Shadow Blades",
"/cast Vanish",
"/cast Nightblade",
"/cast Shadow Dance",
"/cast Shuriken Storm",
"/cast Eviscerate",
"/cast Backstab",
PostMacro=[[
/use [combat] 13
/use [combat] 14
]],
}

Sequences['DB_DRoutlaw'] = {
StepFunction = GSStaticPriority,
author="Druccy",
specID=260,
helpTxt="Talents - 1232232",
PreMacro = [[
/startattack
/cast [stealth] ambush,cheap shot
/cast [nostealth,nocombat] Stealth
/cast Marked for Death
/cast Adrenaline Rush
]],
'/castsequence reset=target Ghostly Strike, Saber Slash, Saber Slash, Pistol Shot, Roll the Bones,feint',
'/cast [nochanneling] Run Through',
'/cast [nochanneling] Between the Eyes',
'/cast [nochanneling] Killing Spree',
'/cast [nochanneling] Crimson Vial',
PostMacro = [[
/cast [combat] Riposte
/cast [combat]13
/use [combat] 14
]],
}

Sequences['DB_TLAssassin'] = {
author="Todd Livengood - wowlazymacros.com",
specID=259,
helpTxt = 'Talents: 3233332',
StepFunction = GSStaticPriority,
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [stealth] Cheap Shot
]],
"/cast Mutilate",
"/cast Garrote",
"/cast Exsanguinate",
"/cast Mutilate",
"/castsequence reset=5 Rupture,Envenom",
"/cast Hemorrhage",
PostMacro=[[
/stopattack [stealth]
]],
}


Sequences['DB_CalliynOutlaw'] = {
author="Ambergreen",
specID=260,
helpTxt = 'Talents: 1333131',
PreMacro=[[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [combat] Marked for Death
]],
icon='INV_Sword_30',
"/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Saber Slash",
"/castsequence [mod:alt] Blade Flurry",
"/castsequence Saber Slash, Run Through, Saber Slash, Pistol Shot",
"/castsequence [talent:7/1] Slice and Dice; [talent:7/2][talent:7/3] Roll the Bones, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot, Run Through, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot",
"/castsequence [mod:alt] Blade Flurry",
"/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot",
"/castsequence [mod:alt] Blade Flurry",
"/cast [@focus] Tricks of the Trade",
"/cast Crimson Vial",
PostMacro=[[
/use [combat] 13
/use [combat] 14
]],
}
