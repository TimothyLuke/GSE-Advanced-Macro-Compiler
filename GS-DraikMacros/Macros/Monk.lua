local Sequences = GSMasterSequences

------------------
----- Monk
------------------
Sequences['WWMonk-ST-Level'] = {
specID = 269,
author = "Draik",
helpTxt = "Single Target",
StepFunction = GSStaticPriority,
   PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Spinning Crane Kick',
'/cast !Fists of Fury',
'/cast [nochanneling] chi wave',
'/cast [nochanneling] !rising sun kick',
'/cast [nochanneling] !jab',
'/cast [nochanneling] jab',
'/cast [nochanneling] tiger palm',
'/cast [nochanneling] jab',
'/cast [nochanneling] Blackout Kick',
'/cast [nochanneling] jab',
'/cast [nochanneling] jab',
'/cast [nochanneling] Expel Harm',
'/cast [nochanneling] jab',
'/cast [nochanneling] tiger palm',
'/cast [nochanneling] [combat]Energizing Brew',
'/cast [nochanneling] [combat]Expel Harm',
'/cast [nochanneling] !jab',
PostMacro = [[
/cast !touch of death
/run UIErrorsFrame:Clear()
]],
}

Sequences['WWMonk-ST'] = {
	specID = 269,
	author = "Draik",
	helpTxt = "Single Target -- All in one - Serenity and Xuen",
StepFunction = GSStaticPriority,
   PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Spinning Crane Kick',
'/cast !Fists of Fury',
'/cast [nochanneling] chi wave',
'/cast [nochanneling] !rising sun kick',
'/cast [nochanneling] !jab',
'/cast [nochanneling] jab',
'/cast [nochanneling] tiger palm',
'/cast [nochanneling] jab',
'/cast [nochanneling] Blackout Kick',
'/cast [nochanneling] jab',
'/cast [nochanneling] jab',
'/cast [nochanneling] Expel Harm',
'/cast [nochanneling] jab',
'/cast [nochanneling] tiger palm',
'/cast [nochanneling] [combat]Energizing Brew',
'/cast [nochanneling] [combat]Expel Harm',
'/cast [nochanneling] !jab',
'/cast !touch of death',
'/cast ![combat]Tigereye Brew',
'/cast [combat]Invoke Xuen, the White Tiger',
'/cast [combat,nochanneling] Serenity',
PostMacro = [[
/run UIErrorsFrame:Clear()
]],
}

Sequences['WW-next'] = {
	specID = 269,
	author = "Leonardo Oliveira",
	helpTxt = "Single Target -- All in one - Talents 2123123",
	PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
'/castsequence reset=0 [combat,nochanneling] Chi Wave,Expel Harm',
'/cast [combat,nochanneling] !Expel Harm',
'/cast [combat,nochanneling] Fists of Fury',
'/cast [combat,nochanneling] Fists of Fury',
'/cast [combat,nochanneling] Rising Sun Kick',
'/cast [combat,nochanneling] Blackout Kick',
'/cast [combat,nochanneling] !Tiger Palm',
'/cast [combat,nochanneling] !Jab',
'/cast [combat,nochanneling] Fists of Fury',
'/cast [combat,nochanneling] Rising Sun Kick',
'/cast [combat,nochanneling] Blackout Kick',
'/cast [combat,nochanneling] Tiger Palm',
'/cast [combat,nochanneling] !Jab',
'/cast [combat,nochanneling] Fists of Fury',
'/cast [combat,nochanneling] Rising Sun Kick',
'/cast [combat,nochanneling] !Jab',
'/cast [combat,nochanneling] Fists of Fury',
'/cast [combat,nochanneling] !Jab',
'/cast [combat,nochanneling] Energizing Brew',
'/cast [combat,nochanneling] Serenity',
'/cast [combat,nochanneling] Expel Harm',
PostMacro = [[
/use [combat,nochanneling] 13,
/use [combat,nochanneling] 14,
/cast !touch of death,
/run UIErrorsFrame:Clear()
]],
}


Sequences['BREW-MONK'] = { 
specID = 268,
author = "Draik",
helpTxt = "Single Target",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=8 !keg smash,expel harm,jab,jab',
'/castsequence Blackout Kick, purifying brew, blackout kick,Breath of Fire,blackout kick',
'/castsequence reset=22 !keg smash,Elusive Brew',
'/cast tiger palm',
'/cast !keg smash',
'/cast Guard',
'/cast Chi Wave',	
'/cast Fortifying Brew',
'/cast Leg Sweep',
'/cast Touch of Death',
'/cast Invoke Xuen, the White Tiger',
'/cast Hurricane Strike',
PostMacro = [[
/use [combat,nochanneling] 13
/use [combat,nochanneling] 14
/run UIErrorsFrame:Clear()
/startattack
]],
}

Sequences['BREW-MONK-AOE'] = { 
specID = 268,
author = "Draik",
helpTxt = "AoE Tanking",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=22 !keg smash,Elusive Brew',
'/cast !keg smash',
'/cast !Breath of Fire',
'/cast [nochanneling] spinning crane kick',
'/cast Guard',
'/cast Chi Wave',	
'/cast Fortifying Brew',
'/cast Leg Sweep',
'/cast Touch of Death',
'/cast Invoke Xuen, the White Tiger',
'/cast Hurricane Strike',
PostMacro = [[
/use [combat,nochanneling] 13
/use [combat,nochanneling] 14
/run UIErrorsFrame:Clear()
/startattack
]],
}
