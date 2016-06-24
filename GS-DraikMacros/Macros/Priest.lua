local Sequences = GSMasterSequences

------------------
----- Priest
------------------
Sequences['SPriestST'] = {
	specID = 258,
	author = "Draik",
	helpTxt = "Single Target",
	PreMacro = [[
/targetenemy [noharm][dead]
/cast [noform] !Shadowform
]],  '/castsequence [nochanneling] reset=target Shadow Word: Pain, Vampiric Touch, Mind Flay, Mind Flay, Mind Flay',  '/cast !Mind Blast',  '/cast [nochanneling] Shadowfiend',  '/cast !Shadow Word: Death',  '/cast !Devouring Plague',  '/cast !Cascade',  PostMacro = [[
/use [combat]13
/use [combat]14
]],
}

Sequences['SPriestSTLevelling'] = {
specID = 258,
author = "Draik",
helpTxt = "Levelling Single Target",
PreMacro = [[
/targetenemy [noharm][dead]
/cast [noform] !Shadowform
]],  '/cast !Mind Blast',  '/cast Mind Spike',  '/cast !Shadow Word: Death',  '/cast !Devouring Plague',  '/cast !Cascade',  PostMacro = [[
/use [combat]13
/use [combat]14
]],
}