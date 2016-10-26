------------------------------------------------------------------------------------------
-- Dont edit this file.  It is regularily update when GS-E is updated and any
-- changes you have made may be lost.  Instead either use the GS-myMacros
-- plugin from http://www.wowinterface.com/downloads/info24062-GS-EmyMacrosAddinPack.html
-- or see the wiki on creating Macro Plugins
-- https://github.com/TimothyLuke/GnomeSequenced-Enhanced/wiki/Creating-Addon-Packs
------------------------------------------------------------------------------------------

local GNOME, Sequences = ...
------------------
----- Warlock
------------------
-- Affliction Legion
-- talents 2111212
Sequences['DB_AFF'] = {
specID = 265,
author = "Jimmy",
helpTxt = "Talents - 3,1,3,1,2,1,2",
PreMacro = [[
/targetenemy [noharm][dead],
/startattack
]],
'/cast [nochanneling] Agony',
'/cast [nochanneling] Corruption',
'/cast [nochanneling] Unstable Affliction',
'/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
'/cast [nochanneling] Reap Souls',
PostMacro = [[
/startattack
/petattack
]],
}


Sequences['DB_AFF2'] = {
specID = 265,
author = "Jimmy",
helpTxt = "Talents - 3,1,3,1,2,1,2",
PreMacro = [[
/targetenemy [noharm][dead],
/startattack
]],
'/cast [nochanneling] Agony',
'/cast [nochanneling] Corruption',
'/cast [nochanneling] Unstable Affliction',
'/castsequence [nochanneling] Siphon Life,Drain Soul,Drain Soul',
'/cast [nochanneling] Phantom Singularity',
'/cast [nochanneling] Reap Souls',
PostMacro = [[
/startattack
/petattack
]],
}


Sequences['DB_Demon'] = {
specID = 266,
author = "Jimmy",
helpTxt = "Talents - 3,2,1,2,2,1,3",
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
"/castsequence [nochanneling] Doom,Demonic Empowerment,Demonwrath",
"/cast [nochanneling] Shadow Bolt",
"/cast [nochanneling] Shadow Bolt",
"/cast [nochanneling] Life Tap",
PostMacro = [[
/startattack
/petattack
]],
}

Sequences['DB_Destro'] = {
specID = 267,
author = "Jimmy",
helpTxt = "Talents - 1,1,1,2,2,1,3",
PreMacro = [[
/targetenemy [noharm][dead]
/startattack
]],
"/cast [nochanneling] Conflagrate",
"/castsequence [nochanneling] Incinerate,Immolate,Incinerate,Immolate,Drain Life",
PostMacro = [[
/startattack
/petattack
]],
}

Sequences['DB_DemoSingle'] = {
author='twitch.tv/Seydon',
specID=266,
helpTxt = 'Talents: 1111222',
icon='Spell_Warlock_Demonbolt',
PreMacro=[[
/cast [nopet,group] Summon Felguard
/cast [nopet,nogroup] Summon Felguard
/targetenemy [noharm][dead]
/petattack [@target,harm]
/targetenemy [noharm][dead]
]],
'/castsequence [combat] Call Dreadstalkers, Demonic Empowerment',
'/castsequence [combat] Summon Doomguard, Demonic Empowerment' ,
'/castsequence [combat] Grimoire: Felguard, Demonic Empowerment',
"/castsequence [nochanneling] Doom, Demonbolt, Demonbolt, Demonbolt, Hand of Gul'dan, Demonic Empowerment, Life Tap",
'/cast [combat] Command Demon',
PostMacro=[[
/startattack
/petattack
]],
}

Sequences['DB_DemoAoE'] = {
author='twitch.tv/Seydon',
specID=266,
helpTxt = 'Talents: 1111222',
icon="Spell_Warlock_HandofGul'dan",
PreMacro=[[
/cast [nopet,group] Summon Felguard
/cast [nopet,nogroup] Summon Felguard
/targetenemy [noharm][dead]
/petattack [@target,harm]
/targetenemy [noharm][dead]
]],
'/castsequence [combat] Call Dreadstalkers, Demonic Empowerment',
'/castsequence [combat] Summon Infernal, Demonic Empowerment' ,
'/castsequence [combat] Grimoire: Felguard, Demonic Empowerment',
"/castsequence [nochanneling] Hand of Gul'dan, Demonic Empowerment, Demonwrath, Demonwrath, Demonwrath, Life Tap",
'/cast [combat] Command Demon',
PostMacro=[[
/startattack
/petattack
]],
}
