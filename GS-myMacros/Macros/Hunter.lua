local Sequences = GSMasterSequences -- Dont remove this

------------------
-- Hunter
-- 3 - Classid
-- Spec ID’s
-- 253 - Beast Mastery
-- 254 - Marksmanship
-- 255 - Survival
-- Edit below this line  ---------------------

Sequences['MMRaeBarrage'] = {
author = "Raejyn",
specID= 254,
helpTxt = "Talent: 1313221",
PreMacro = [[
/targetenemy [noharm][dead]
]],
'/cast [mod:alt][nochanneling] True Shot',
'/cast [nochanneling] Windburst',
'/cast [nochanneling] Sidewinders',
'/cast [nochanneling] Marked Shot',
'/cast [nochanneling] Barrage',
'/cast [nochanneling] Aimed Shot',
PostMacro = [[
/startattack
]],
}
