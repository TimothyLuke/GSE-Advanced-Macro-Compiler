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