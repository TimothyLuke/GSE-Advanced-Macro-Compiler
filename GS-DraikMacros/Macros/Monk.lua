local Sequences = GSMasterSequences

------------------
----- Monk
------------------
-- 268 tank 


Sequences['PTRWW'] = {
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
/cast [mod:alt] Serenity
/cast [mod:ctrl] invoke Xuen The white Tiger
/cast !Healing Elixir
/use [combat] 13
/use [combat] 14
/script UIErrorsFrame:Hide();
    ]],
}




