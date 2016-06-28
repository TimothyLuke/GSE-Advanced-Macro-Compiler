local Sequences = GSMasterSequences

------------------
----- Paladin
------------------




-------------------
-- Protection - 66
-------------------
Sequences['Prot'] = {
specID = 66,
author = "Maurice Greer",
helpTxt = "Protection single target tanking macro.",
StepFunction = GSStaticPriority,
PreMacro = [[
/console Sound_EnableSFX 0
/targetenemy [noharm][dead]
]],

     "/cast Avenger's Shield",	
     '/cast Judgment',
	'/cast Hammer of the Righteous',	
	'/cast Holy Wrath',
	"/cast Avenger's Shield",
	'/cast Hammer of Wrath',
	'/cast Consecration',
PostMacro = [[
/cast Shield of the Righteous
/startattack
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}

-------------------
-- Retribution - 77
-------------------

Sequences['Ret'] = {
	specID = 70,
	author = "Draik",
	helpTxt = "Retribution Single Target macro - 3132233.",
	PreMacro = [[
/targetenemy [noharm][dead]    
]],  
'/cast Judgment',  
'/cast Crusader Strike',  
'/cast Blade of Justice',  
'/cast [combat]!Sanctified Wrath',  
'/cast !Wake of Ashes',  
"/cast Templar's Verdict",   
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}
