local Sequences = GSMasterSequences

------------------
----- Shaman
------------------
-- Elemental 262


Sequences['PTREnhST'] = {
specID = 263,
author = "Suiseiseki",
helpTxt = "Single Target",
    PreMacro = [[
/targetenemy [noharm][dead]
    ]],
	"/castsequence [combat] Crash Lightning, Lava Lash, Lava Lash",
	"/cast Stormstrike",
	"/castsequence Flametongue, Rockbiter, Rockbiter, Rockbiter, Rockbiter, Rockbiter",
	'/cast Windsong',
    PostMacro = [[
/cast Feral Lunge
/use [combat] 13
/use [combat] 14
/script UIErrorsFrame:Hide();
    ]],
}