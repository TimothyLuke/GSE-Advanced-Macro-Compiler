About this Repository
===================================
Tis repository is a work in progress.  Code here may be broken at any point in time.  This contains the source code for GnomeSequencer-Enahnced in its raw form.  Libraries are referred to but are not present in this repository.  While releases are tagged as releases, alpha builds are released via http://wow.curseforge.com/addons/gnomesequencer-enhanced/  

To use this locally straight from this source you must install https://mods.curse.com/addons/wow/ace3 as a standalone mod.

Current Build Status
===================================
[![Build Status](https://travis-ci.org/TimothyLuke/GnomeSequenced-Enhanced.svg?branch=master)](https://travis-ci.org/TimothyLuke/GnomeSequenced-Enhanced) 

At the moment this means that there are no lua errors.  It doesnt mean it works ... yet

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




