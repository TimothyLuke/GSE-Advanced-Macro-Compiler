===================================
What is GnomeSequencer
===================================

This is a small addon that allows you create a sequence of macros to be executed at the push of a button.

Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike
castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is
pushed instead of stopping when it can't cast something.

This means if a spell is on cooldown and you push the button it will continue to the next item in the list with
each press until it reaches the end and starts over.

This was originally written by semlar and released at http://www.wowinterface.com/downloads/info23234-GnomeSequencer.html


When you first install the addon you will need to create a "Sequences.lua" file and open the file in a text editor to add 
your own sequences.  Alternatively to this you can load a Macro Pack from another author.


===================================
Writing Sequences
===================================

The Sequences file contains a couple examples to get you started with writing your own sequences, I'll post its entirety here.
Lua Code:

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




===================================
What is different on this fork?
===================================
Intro Video - https://youtu.be/CpR3yCGY8zg

I have extended the original interface to include some help information (/gnome help) as well as extending the
macro spec to store the following extra information.

specID = 259,
author = "Draik",
helpTxt = "Rogue Assassination Talents: 331232",

Author and HelpTxt are self explanatory but specID is what spec the macro is written for. The list is as below.

The theory is that other authors could add in their macros.

===================================
Making Addon Packs.
===================================
Gnome Sequencer now supports addon packs. GS-Core will work as it always has but you can create optional addon packs as long as they start with GS- in the name and are set to Load on Demand.

Create a folder called GS-NewMacros
Inside that folder make two files with a text editor:
- GS-NewMacros.toc
- NewSequences.lua

Inside GS-NewMacros.toc:

  ## Interface: 70000
  ## Title: GS New Macros
  ## Notes: A sample random collection of new macros
  ## Author: Draik
  ## Version: r1
  ## RequiredDeps: GS-Core
  ## LoadOnDemand: 1
  NewSequences.lua

Start the first line of the NewSequences.lua with the following line then continue as before:

  local Sequences = GSMasterSequences

===================================
Macro SpecID
===================================

Each Macro has a Class and Spec ID. The table of SpecID's are as follows:
0 - All Classes:All Specs
62 - Mage: Arcane
63 - Mage: Fire
64 - Mage: Frost
65 - Paladin: Holy
66 - Paladin: Protection
70 - Paladin: Retribution
71 - Warrior: Arms
72 - Warrior: Fury
73 - Warrior: Protection
102 - Druid: Balance
103 - Druid: Feral
104 - Druid: Guardian
105 - Druid: Restoration
250 - Death Knight: Blood
251 - Death Knight: Frost
252 - Death Knight: Unholy
253 - Hunter: Beast Mastery
254 - Hunter: Marksmanship
255 - Hunter: Survival
256 - Priest: Discipline
257 - Priest: Holy
258 - Priest: Shadow
259 - Rogue: Assassination
260 - Rogue: Combat
261 - Rogue: Subtlety
262 - Shaman: Elemental
263 - Shaman: Enhancement
264 - Shaman: Restoration
265 - Warlock: Affliction
266 - Warlock: Demonology
267 - Warlock: Destruction
268 - Monk: Brewmaster
269 - Monk: Windwalker
270 - Monk: Mistweaver
577 - Demon Hunter: Havoc
581 - Demon Hunter: Vengence
http://wowprogramming.com/docs/api_types#specID


===================================
GSStaticPriority
===================================
'GSStaticPriority' is a static step function that goes 1121231234123451234561234567
use this like StepFunction = GSStaticPriority, in a macro
This overides the sequential behaviour that is standard in GS

