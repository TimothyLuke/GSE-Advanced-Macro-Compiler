local Sequences = GSMasterSequences

------------------
----- Mage
------------------


Sequences['Arcaneaoe'] = { 
  specID = 62,
  author = "Draik",
  helpTxt = "AoE",
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
/targetenemy [noharm][dead]

]],
  '/castsequence reset=combat Arcane Explosion, Arcane Explosion, Arcane Explosion, Arcane Explosion, Arcane Barrage',
  '/cast Supernova',
  '/cast Arcane Power',
  '/cast Presense of Mind',
  PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['Arcanest'] = { 
  specID = 62,
  author = "Draik",
  helpTxt = "Single Target",
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
/targetenemy [noharm][dead]

]],
  '/castsequence reset=combat Arcane Blast',
  '/cast [nochanneling] Arcane Missiles',
  '/cast Supernova',
  '/cast Arcane Power',
  '/cast Presense of Mind',
  PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
]],
}

Sequences['Frosty'] = {
  specID = 64,
  author = "Draik",
  helpTxt = "Frost Single Target - Talents 3,3,2,2,3,1,3",
PreMacro = [[
/targetenemy [noharm][dead]
]],
[[/castsequence reset=25, Ice Barrier]],
[[/castsequence reset=20, Ice Ward]],
[[/castsequence reset=30, Comet Storm]],
[[/castsequence reset=25, Ice Nova,Frostbolt,Frostbolt,Frostbolt,Ice Lance,Ice Lance,Frostfire Bolt,Frostbolt,Frostbolt,Frostbolt,Ice Lance,Ice Lance,Frostfire Bolt]],
[[/cast Frozen Orb]],
[[/cast Ice Nova]],
[[/castsequence reset=20 Deep Freeze,Ice Lance,Ice Lance]],

PostMacro = [[
/startattack
/use [combat]13
/use [combat]14
/use [combat]Ice Floes
/use [combat]Icy Veins
/use [combat]Mirror Image
/use [combat]Frozen Orb

]],
}


