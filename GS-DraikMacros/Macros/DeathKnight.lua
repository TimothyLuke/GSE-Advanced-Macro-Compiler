local Sequences = GnomeSequencer_Sequences

------------------
----- Death Knight
------------------

Sequences['PTRBlood'] = {
specID = 250,
author = "John Mets",
helpTxt = "As for talents its not an issue but it does run real smooth if you have Heartbreaker, Soulgorge and Ossuary.",
StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],
    PreMacro = [[
/Cast [combat] Vampiric Blood
/Cast [combat] Dancing Rune Weapon
    ]],
    '/cast Marrowrend',
      "/castsequence reset=combat Death's Caress, Blood Boil, Death Strike, blood Boil, Marrowrend",
      "/castsequence reset=combat Death's Caress, Blood Boil, Blood Boil, death strike, soulgorge",
      "/cast Heart Strike",
      "/cast Death Strike",

    PostMacro = [[
/cast [mod:alt] Anti-Magic Shell
/TargetEnemy [noharm][dead]
/Use [combat] 13
/Use [combat] 14
/script UIErrorsFrame:Hide();
]],
}

