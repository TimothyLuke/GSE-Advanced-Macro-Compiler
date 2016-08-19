------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local Sequences = GSMasterSequences

------------------
----- Monk
------------------
-- 268 tank


Sequences['DB_WW'] = {
specID = 269,
author = "John Mets",
helpTxt = "Talent are 2 3 2 3 1 2 3",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Rising Sun Kick",
"/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Fists of Fury",
"/cast Tiger Palm",
"/cast Touch of Death",
PostMacro = [[
/cast [combat] Invoke Xuen, the White Tiger
/cast [combat] Serenity
/cast [combat] Touch of Death
]],
}

Sequences['DB_winsingle'] = {
specID = 269,
author = "lloskka",
helpTxt = "Talents 2 3 2 3 2 2 3",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/cast [combat] Touch of Karma
]],
'/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm',
'/castsequence [nochanneling] Tiger Palm, Fists of Fury, Tiger Palm, Blackout Kick',
'/castsequence [nochanneling] Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick, Fists of Fury, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
'/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
PostMacro = [[
/startattack
/cast [combat] Invoke Xuen, the White Tiger
/cast [combat] Serenity
/cast [combat] Touch of Death
]],
}


Sequences['DB_BrewMaster_ST'] = {
specID = 268,
author = "TimothyLuke",
helpTxt = "Talent are 1122312",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/cast Keg Smash",
"/cast Breath of Fire",
"/cast Blackout Strike",
"/cast Rushing Jade Wind",
"/cast Tiger Palm",
"/cast Blackout Strike",
"/cast Blackout Combo",
PostMacro = [[
]],
}

Sequences['DB_BrewMaster_AoE'] = {
specID = 268,
author = "TimothyLuke",
helpTxt = "Talent are 1122312",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/cast Keg Smash",
"/cast Breath of Fire",
"/cast Blackout Strike",
"/cast Chi Burst",
"/cast Rushing Jade Wind",
"/cast Tiger Palm",
"/cast Blackout Strike",
PostMacro = [[
]],
}
