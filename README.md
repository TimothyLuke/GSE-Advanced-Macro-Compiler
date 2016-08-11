What is GnomeSequencer 
===================================

[![Build Status](https://travis-ci.org/TimothyLuke/GnomeSequenced-Enhanced.svg?branch=master)](https://travis-ci.org/TimothyLuke/GnomeSequenced-Enhanced) 

This is a small addon that allows you create a sequence of macros to be executed at the push of a button.

Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike
castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is
pushed instead of stopping when it can't cast something.

This means if a spell is on cooldown and you push the button it will continue to the next item in the list with
each press until it reaches the end and starts over.

This was originally written by semlar and released at http://www.wowinterface.com/downloads/info23234-GnomeSequencer.html


When you first install the addon you will need to create a "Sequences.lua" file and open the file in a text editor to add 
your own sequences.  Alternatively to this you can load a Macro Pack from another author.




