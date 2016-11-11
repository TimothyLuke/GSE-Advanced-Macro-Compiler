local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[10] = {}

local Sequences = Statics.SampleMacros[10]
------------------
----- Monk
------------------
-- 268 tank


Sequences['SAM_WW'] = {
specID = 269,
author = "John Mets",
helpTxt = "Talent are 2 3 2 3 1 2 3",
KeyPress = [[
/targetenemy [noharm][dead]
]],
"/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Rising Sun Kick",
"/castsequence reset=combat Tiger Palm, Tiger Palm, Blackout Kick, Blackout Kick, Fists of Fury",
"/cast Tiger Palm",
"/cast Touch of Death",
KeyRelease = [[
/cast [combat] Invoke Xuen, the White Tiger
/cast [combat] Serenity
/cast [combat] Touch of Death
]],
}

Sequences['SAM_winsingle'] = {
specID = 269,
author = "lloskka",
helpTxt = "Talents 2 3 2 3 2 2 3",
StepFunction = "Priority",
KeyPress = [[
/targetenemy [noharm][dead]
/cast [combat] Touch of Karma
]],
'/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm',
'/castsequence [nochanneling] Tiger Palm, Fists of Fury, Tiger Palm, Blackout Kick',
'/castsequence [nochanneling] Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick, Fists of Fury, Tiger Palm, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
'/castsequence Tiger Palm, Rising Sun Kick, Tiger Palm, Tiger Palm, Tiger Palm, Blackout Kick',
KeyRelease = [[
/startattack
/cast [combat] Invoke Xuen, the White Tiger
/cast [combat] Serenity
/cast [combat] Touch of Death
]],
}


Sequences['SAM_BrewMaster_ST'] = {
specID = 268,
author = "TimothyLuke",
helpTxt = "Talent are 1122312",
KeyPress = [[
/targetenemy [noharm][dead]
]],
"/cast Keg Smash",
"/cast Breath of Fire",
"/cast Blackout Strike",
"/cast Rushing Jade Wind",
"/cast Tiger Palm",
"/cast Blackout Strike",
"/cast Blackout Combo",
KeyRelease = [[
]],
}

Sequences['SAM_BrewMaster_AoE'] = {
specID = 268,
author = "TimothyLuke",
helpTxt = "Talent are 1122312",
KeyPress = [[
/targetenemy [noharm][dead]
]],
"/cast Keg Smash",
"/cast Breath of Fire",
"/cast Blackout Strike",
"/cast Chi Burst",
"/cast Rushing Jade Wind",
"/cast Tiger Palm",
"/cast Blackout Strike",
KeyRelease = [[
]],
}
