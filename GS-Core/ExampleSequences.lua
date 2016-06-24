local GNOME, Sequences = ... -- Don't touch this


----
-- Rename this file to Sequences.lua before you get started, it uses a different file name so as not to overwrite your existing file with a future update.
-- Every entry in the Sequences table defines a single sequence of macros which behave similarly to /castsequence.
-- Sequence names must be unique and contain no more than 16 characters.
-- To use a macro sequence, create a blank macro in-game with the same name you picked for the sequence here and it will overwrite it.
----

----
-- Here's a large demonstration sequence documenting the format:
Sequences["GnomeExample1"] = {
	-- StepFunction optionally defines how the step is incremented when pressing the button.
	-- This example increments the step in the following order: 1 12 123 1234 etc. until it reaches the end and starts over
	-- DO NOT DEFINE A STEP FUNCTION UNLESS YOU THINK YOU KNOW WHAT YOU'RE DOING
	StepFunction = [[
		limit = limit or 1
		if step == limit then
			limit = limit % #macros + 1
			step = 1
		else
			step = step % #macros + 1
		end
	]],
	
	-- PreMacro is optional macro text that you want executed before every single button press.
	-- This is if you want to add something like /startattack or /stopcasting before all of the macros in the sequence.
	PreMacro = [[
/run print("-- PreMacro Script --")
/startattack	
	]],
	
	-- PostMacro is optional macro text that you want executed after every single button press.
	-- I don't know what you would need this for, but it's here anyway.
	PostMacro = [[
/run print("-- PostMacro Script --")
	]],
	
	-- Macro 1
	[[
/run print("Executing macro 1!")
/cast SpellName1
	]],
	
	-- Macro 2
	[[
/run print("Executing macro 2!")
/cast SpellName2
	]],
	
	-- Macro 3
	[[
/run print("Executing macro 3!")
/cast SpellName3
	]],
}

----
-- Here is a short example which is what most sequences will look like
Sequences["GnomeExample2"] = {	
	-- Macro 1
	[[
/run print("Executing macro 1!")
/cast SpellName1
	]],
	
	-- Macro 2
	[[
/run print("Executing macro 2!")
/cast SpellName2
	]],
	
	-- Macro 3
	[[
/run print("Executing macro 3!")
/cast SpellName3
	]],
}