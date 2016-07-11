local Sequences = GSMasterSequences

------------------
----- Demon Hunter
------------------


Sequences['DHTEST'] = {
specID = 577,
author = "Nano",
helpTxt = "Talents 2,3,2,2,2,3,1,",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
]],
        [[/cast [nochanneling] Felblade;]],
	[[/cast [nochanneling] Throw Glaive;]],
        [[/cast [nochanneling] Demon's Bite;]],
	[[/cast [nochanneling] Chaos Strike;]],
        [[/cast [nochanneling] Blade Dance;]],
        [[/cast [nochanneling] Fel Eruption;]],
        
	
PostMacro = [[
/startattack
/petattack [@target,harm]
/use [combat]13
/use [combat]14
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}



--havoc
Sequences['havocsingle'] = {
specID = 577,
author = "lloskka",
helpTxt = "Talents 2,3,1,2,2,3,1",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/run sfx=GetCVar("Sound_EnableSFX");
/console Sound_EnableSFX 0
]],	
"/cast [combat,nochanneling] !Throw Glaive",
"/cast [combat,nochanneling] !Fury of the Illidari",
"/castsequence [combat,nochanneling] Demon's Bite, Chaos Strike, !Felblade",
"/castsequence [combat,nochanneling] Demon's Bite, Chaos Strike, Blade Dance",
"/cast [combat,nochanneling] !Throw Glaive",
"/castsequence [combat,nochanneling] Demon's Bite, Demon's Bite, !Eye Beam",
"/castsequence [combat,nochanneling] Demon's Bite, Demon's Bite",
"/cast [combat,nochanneling] Fel Eruption",	
PostMacro = [[
/startattack
/use [combat,nochanneling] 13
/use [combat,nochanneling] 14
/cast [combat,nochanneling] Chaos Nova
/cast [combat,nochanneling] Chaos Blades
/cast [combat,nochanneling] Blur
/run UIErrorsFrame:Clear()
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}


Sequences['Vengeance'] = {
specID = 581,
author = "Tocktris",
helpTxt = "Talents unknown",
PreMacro = [[
/targetenemy [noharm][dead]
/console Sound_EnableSFX 0
]],
"/cast Demon Spikes",
"/cast Immolation Aura",
"/cast Soul Cleave",
"/cast Shear",
PostMacro = [[
/use 13
/use 14
/run UIErrorsFrame:Hide()
/console Sound_EnableSFX 1
]],
}