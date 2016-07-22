local Sequences = GSMasterSequences

------------------
----- Priest
------------------


Sequences['DB_ShadowPriest'] = {
specID = 258,
author = "Jimmy",
helpTxt = "unknown Talents",
PreMacro = [[
/targetenemy [noharm][dead]
]],
"/castsequence [nochanneling] reset=12 Shadow Word: Pain,Vampiric Touch",
"/castsequence [nochanneling] Mind Spike,Mind Blast,Mind Spike",
"/cast [nochanneling] Mind Sear",
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_DiscDeeps'] = {
specID = 256,
author = "Draik",
helpTxt = "Talents 3113131",
icon = "Ability_Mage_FireStarter",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Smite',
'/cast [nochanneling] Penance',
'/cast Halo',
'/cast Holy Nova',
'/cast Purge the Wicked',
'/cast Mindbender',
'/cast Schism',
'/cast Shining Force',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_KTN_DiscDeeps'] = {
specID = 256,
author = "KTN",
helpTxt = "Talents 3213131 - Set yourself as Focus.  ALso use the DB_KTN_Mouseover macro for some out of combat/dont pull things healing",
icon = "Ability_Mage_FireStarter",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast [@focus] Power Word: Shield',
'/cast Smite',
'/cast [nochanneling] Penance',
'/cast Halo',
'/cast Holy Nova',
'/cast Purge the Wicked',
'/cast Mindbender',
'/cast Schism',
'/cast Shining Force',
PostMacro = [[
/startattack
/castsequence [target=mouseover,help,nodead][] Plea, Shadow Mend
/use [combat]13
/use [combat]14
]],
}

Sequences['DB_KTN_MouseOver'] = {
specID = 256,
author = "KTN",
helpTxt = "Talents 3213131",
'/castsequence [target=mouseover,help,nodead][] Power Word: Shield, Plea, Shadow Mend, Shadow Mend',
}


Sequences['DB_HolyPriesty'] = {
specID = 257,
author = "Draik",
helpTxt = "Talents 3121133",
icon = "Ability_Priest_Archangel",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast Smite',
'/cast Holy Fire',
'/cast Halo',
'/cast Holy Nova',
'/cast Holy Word:Chastise',
PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}
