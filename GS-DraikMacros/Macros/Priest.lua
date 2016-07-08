local Sequences = GSMasterSequences

------------------
----- Priest
------------------


Sequences['ShadowPriest'] = {
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

Sequences['DiscDeeps'] = {
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




Sequences['HolyPriesty'] = {
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

