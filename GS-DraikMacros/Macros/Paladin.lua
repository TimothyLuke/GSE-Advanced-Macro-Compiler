------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local Sequences = GSMasterSequences

------------------
----- Paladin
------------------

-------------------
-- Protection - 66
-------------------
Sequences['DB_Prot'] = {
specID = 66,
author = "Maurice Greer",
helpTxt = "Protection single target tanking macro.",
StepFunction = GSStaticPriority,
PreMacro = [[
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
]],
}


Sequences['DB_Palla_Prot_ST'] = {
author="LNPV",
specID=66,
helpTxt = 'Talents: 1332223  This build is based in mastery, hast and crit (food is variable for boss). ',
icon=236264,
PreMacro=[[
/targetenemy [noharm][dead]
]],
"/cast Avenger's Shield",
"/cast Judgment",
"/cast Hammer of the Righteous",
"/cast Shield of the Righteous",
"/cast Consecration",
"/cast Light of the Protector",
"/cast Judgment",
"/cast Hammer of the Righteous",
"/cast Shield of the Righteous",
PostMacro=[[
/cast Avenging Wrath
/cast Divine Steed
/startattack
]],
}

Sequences['DB_Palla_Prot_AOE'] = {
author="LNPV",
specID=66,
helpTxt='Talents: 2332233  This build is based in mastery, hast and crit (food is variable for boss).',
icon=236264,
PreMacro=[[
/targetenemy [noharm][dead]
]],
"/cast Avenger's Shield",
"/cast Judgment",
"/cast Blessed Hammer",
"/cast Shield of the Righteous",
"/cast Consecration",
"/cast Light of the Protector",
"/cast Judgment",
"/cast Blessed Hammer",
"/cast Shield of the Righteous",
PostMacro=[[
/cast Avenging Wrath
/cast Divine Steed
/startattack
]],
}

Sequences['DB_Palla_Sera'] = {
author="LNPV",
specID=66,
helpTxt = 'Talents: 2232222  This build is based in mastery, hast and crit (food is variable for boss).',
icon=236264,
PreMacro=[[
/targetenemy [noharm][dead]
]],
"/cast Avenger's Shield",
"/cast Judgment",
"/cast Blessed Hammer",
"/cast Consecration",
"/cast Light of the Protector",
"/cast Shield of the Righteous",
"/cast Judgment",
"/cast Blessed Hammer",
PostMacro=[[
/cast Avenging Wrath
/cast Bastion of Light
/cast Seraphim
/cast Divine Steed
/startattack
]],
}

-------------------
-- Retribution - 70
-------------------

Sequences['DB_Ret'] = {
author="TimothyLuke",
specID=70,
helpTxt = "Talents: 1112111",
StepFunction = GSStaticPriority,
icon='INV_Sword_2H_AshbringerCorrupt',
lang="enUS",
PreMacro=[[
/targetenemy [noharm][dead]
/cast Avenging Wrath
/cast Shield of Vengeance
]],
"/cast [talent:5/1] Justicar's Vengeance",
"/cast Templar's Verdict",
"/cast Blade of Justice",
"/cast Judgment",
"/cast Crusader Strike",
"/cast Wake of Ashes",
PostMacro=[[
/startattack
]],
}

Sequences['DB_RetAoE'] = {
specID = 70,
author = "TimothyLuke",
helpTxt = "Retribution AoE macro - 1112111.",
StepFunction = GSStaticPriority,
icon = "Ability_Paladin_DivineStorm",
PreMacro=[[
/targetenemy [noharm][dead]
/cast Avenging Wrath
/cast Shield of Vengeance
]],
"/cast [talent:5/1] Justicar's Vengeance",
"/cast Divine Storm",
"/cast Blade of Justice",
"/cast Judgment",
"/cast Crusader Strike",
"/cast Wake of Ashes",
PostMacro=[[
/startattack
]],
}


-------------------
-- Holy - 65
-------------------

Sequences['DB_HolyDeeps'] = {
specID = 65,
author = "TimothyLuke",
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
}
