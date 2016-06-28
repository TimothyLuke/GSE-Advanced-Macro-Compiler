local Sequences = GSMasterSequences

------------------
----- Mage
------------------
-- Fire 63
-- Frost 64

Sequences['Arcaneaoe'] = { 




------------------------
Sequences['ArcaneLegion'] = { 
specID = 62,
author = "Flashgreer - wowlazymacros.com",
helpTxt = "2122132",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence [nochanneling]Arcane Blast,Arcane Blast,Arcane Blast,Arcane Blast,Arcane Barrage',
'/cast [nochanneling]Arcane Missiles',
'/castsequence [nochanneling]charged up, Arcane Barrage',
'/cast [nochanneling]Rune of power',
PostMacro = [[
/startattack
/cast [combat]Arcane Power
/cast [combat]Presence of Mind
/script UIErrorsFrame:Hide();
/console Sound_EnableSFX 1
]],
}

