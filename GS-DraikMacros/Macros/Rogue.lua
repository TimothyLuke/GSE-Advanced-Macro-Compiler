local Sequences = GSMasterSequences

------------------
----- Rogue
------------------
-- Outlaw 260
-- Assination 259



Sequences['DB_Outlaw'] = {
specID = 260,
author = "Suiseiseki - www.wowlazymacros.com",
helpTxt = "Outlaw - 1223122",
StepFunction = GSStaticPriority,
PreMacro = [[
/targetenemy [noharm][dead]
/cast [nostealth,nocombat]Stealth
/cast [combat] Marked for Death
]],
'/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Saber Slash',
'/castsequence Saber Slash, Run Through, Saber Slash, Pistol Shot',
'/castsequence [talent:7/1] Slice and Dice; [talent:7/2][talent:7/3] Roll the Bones, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot, Run Through, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot',
'/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot',
'/cast [@focus] Tricks of the Trade',
PostMacro = [[
/use [combat] 13
/use [combat] 14
]],
}
