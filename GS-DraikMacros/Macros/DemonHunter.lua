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

Sequences['havocsingle'] = {
specID = 577,
author = "lloskka",
helpTxt = "Talents  2,3,1,2,2,3,1",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/run sfx=GetCVar("Sound_EnableSFX");
/console Sound_EnableSFX 0
]],
	[[/castsequence [nochanneling] Demon's Bite, Chaos Strike, !Felblade;]],
	[[/castsequence [nochanneling] Demon's Bite, Chaos Strike, Blade Dance;]],
	[[/castsequence [nochanneling] Demon's Bite, Demon's Bite, !Eye Beam;]],
	[[/castsequence [nochanneling] Demon's Bite, Demon's Bite;]],
	[[/cast [nochanneling] Fel Eruption;]],	
	PostMacro = [[
/startattack
/use [combat] 13
/cast [combat] Chaos Blades
/cast [combat] Fury of the Illidari
/run UIErrorsFrame:Clear()
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}