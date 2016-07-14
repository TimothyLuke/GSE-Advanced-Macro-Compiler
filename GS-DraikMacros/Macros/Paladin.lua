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
]],
}

-------------------
-- Retribution - 70
-------------------

Sequences['Ret'] = {
specID = 70,
author = "Draik",
helpTxt = "Retribution Single Target macro - 3311112.",
icon = "INV_Sword_2H_AshbringerCorrupt",
PreMacro = [[
/targetenemy [noharm][dead]    
]],  
'/cast Judgment',  
'/cast Crusader Strike',  
'/cast Blade of Justice',  
'/cast [combat]!Consecration',  
'/cast [combat]!Crusade',  
'/cast !Wake of Ashes',  
"/cast Templar's Verdict",   
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}

Sequences['RetAoE'] = {
specID = 70,
author = "Draik",
helpTxt = "Retribution AoE macro - 3311112.",
icon = "Ability_Paladin_DivineStorm",
PreMacro = [[
/targetenemy [noharm][dead]    
]],  
'/cast Judgment',  
'/cast Crusader Strike',  
'/cast Blade of Justice',  
'/cast [combat]!Consecration',  
'/cast [combat]!Crusade',  
'/cast !Wake of Ashes',  
"/cast Divine Storm",   
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}


-------------------
-- Holy - 65
-------------------

Sequences['HolyDeeps'] = {
specID = 65,
author = "Draik",
helpTxt = "Holy DPS levelling macro - 3131123.",
icon = "Ability_Paladin_InfusionofLight",
PreMacro = [[
/targetenemy [noharm][dead]    
]],  
'/cast Judgment',  
'/cast Crusader Strike',  
'/cast Consecration',  
'/cast [combat]!Avenging Wrath',  
'/cast !Blinding Light',  
'/cast Holy Shock',
'/cast Divine Protection',
PostMacro = [[
/use [combat]13
/use [combat]14
]],
}