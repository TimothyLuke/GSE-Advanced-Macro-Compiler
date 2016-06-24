local Sequences = GSMasterSequences

------------------
----- Shaman
------------------

Sequences['Elemental'] = { 
specID = 262,
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
	]],  PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence reset=target/30 Searing Totem,null',
'/cast Flame Shock',
'/cast Unleash Flame',
'/cast [nochanneling] Lava Burst',
'/cast [nochanneling] Elemental Blast',
'/cast Earth Shock',
'/castsequence [nochanneling] Lightning Bolt,Lightning Bolt,Lightning Bolt',
PostMacro = [[
/startattack
]],
}

Sequences['ELE-SHAMAN-AOE'] = {
	specID = 262,
	author = "Draik",
	helpTxt = "AoE",
	PreMacro = [[
/targetenemy [noharm][dead]
]],
'/castsequence Unleash Flame, Flame Shock, Chain Lightning, Chain Lightning, Chain Lightning,Earth Shock, Chain Lightning',
'/castsequence reset=55 Searing Totem(Fire Totem),Fire Elemental Totem,Earth Elemental Totem',
'/castsequence reset=25 Grounding Totem(Air Totem)',
'/castsequence reset=30 Healing Stream Totem(Water Totem)',
'/cast Thunderstorm',
'/cast Elemental Blast',
'/cast Lava Burst',
'/cast Ancestral Swiftness',
'/cast Ancestral Guidance',
'/cast Shamanistic Rage',
PostMacro = [[
/startattack
]],
}

