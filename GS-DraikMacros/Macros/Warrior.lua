local Sequences = GSMasterSequences

------------------
----- Warrior
------------------
-- PROT

Sequences['Prot-Glad'] = {
	specID = 73,
	author = "Draik",
	helpTxt = "Single Target Talents: Double Time, Enraged Regeneration, Unyielding Strikes, Storm Bolt (SingleTarget) or Dragon Road (AoE), Vigilance, Bloodbath (SingleTarget) or Bladestorm (AoE), Gladiator's Resolve with Glyph of Unending Rage and Glyph of Cleave",
	PreMacro = [[
/targetenemy [noharm][dead]
/cast Charge
]],  '/cast Shield Slam',  '/cast Revenge',  --'/cast [combat] Blood Fury',  '/cast [combat] Bloodbath',  '/use [combat] 13',  '/use [combat] 14',  '/cast [mod:shift] Shield Block',  '/cast [mod:alt] Heroic Strike',  '/cast Shield Slam',  '/cast Revenge',  '/cast Victory Rush',  '/cast Storm Bolt',  '/cast [combat] Dragon Roar',  '/cast Devastate',  '/cast Shield Slam',  '/cast Revenge',
}


--Fury


Sequences['Fury'] = {
	specID = 72,
	author = "Draik",
	helpTxt = "Single Target -- Talents: Double Time, Enraged Regeneration, Sudden Death, Storm Bolt (SingleTarget or Dragon Road (AoE), Vigilance, Bloodbath, Anger Management with Glyph of Unending Rage ",
	PreMacro = [[
/targetenemy [noharm][dead]
/cast Charge
]],  --'/cast [combat] Recklessness',  '/cast [combat] Blood Fury',  '/cast [combat] Bloodbath',  '/use [combat] 13',  '/use [combat] 14',  '/cast [mod:shift] Wild Strike',  '/cast [mod:alt] Whirlwind',  '/cast Bloodthirst',  '/cast Victory Rush',  '/cast Execute',  '/cast Storm Bolt',  '/cast [combat] Dragon Roar',  '/cast Raging Blow',
}

--Arms
--Talents 2,2,2,1,3,2,2
Sequences['ArmsST'] = {
	specID = 71,
	author = "Draik",
	helpTxt = "Single Target.  Talents 2,2,2,1,3,2,2",
	PreMacro = [[
/targetenemy [noharm][dead]
/cast Charge
]],  '/castsequence reset=target/5 Rend, Mortal Strike, Whirlwind, Mortal Strike, Whirlwind',  '/cast [combat] Bloodbath',  '/cast Victory Rush',  '/cast Rocket Barrage',  '/cast Storm Bolt',  '/cast Execute',  '/cast Colossus Smash',  PostMacro = [[
/script UIErrorsFrame:Hide();
/startattack
/use [combat]13
/use [combat]14
]],
}
Sequences['ArmsAoE'] = {
specID = 71,
author = "Draik",
helpTxt = "AoE",
PreMacro = [[
/targetenemy [noharm][dead]
/cast Charge
/startattack
]],  '/cast Mortal Strike',  '/cast Thunder Clap',  '/cast Sweeping Strikes',  '/cast Whirlwind',  '/cast Rend',  '/cast !Execute',  PostMacro = [[
/cast [combat] !Colossus Smash
/cast [combat] Berserker Rage
/cast [combat] bloodbath
/cast [combat] Recklessness
/cast !victory rush
]],
}