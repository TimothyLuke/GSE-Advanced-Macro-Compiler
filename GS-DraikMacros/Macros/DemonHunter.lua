------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local Sequences = GSMasterSequences

------------------
----- Demon Hunter
------------------


Sequences['DB_DHHavoc'] = {
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
]],
}



--havoc
Sequences['DB_havocsingle'] = {
specID = 577,
author = "lloskka",
helpTxt = "Talents 2,3,1,2,2,3,1",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
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
/cast [combat,nochanneling] Chaos Nova
/cast [combat,nochanneling] Chaos Blades
/cast [combat,nochanneling] Blur
]],
}


Sequences['DB_Vengeance'] = {
specID = 581,
author = "Tocktris",
helpTxt = "Talents unknown",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/cast Demon Spikes",
"/cast Immolation Aura",
"/cast Soul Cleave",
"/cast Shear",
PostMacro = [[
]],
}
