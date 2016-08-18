local L = LibStub("AceLocale-3.0"):NewLocale("GS-E", "enUS", true)

--Debug Strings from Core
L["createButton PreMacro: "] = true
L["createButton PostMacro: "] = true
L["Reloading Sequences"] = true
L["Entering GSSplitMeIntolines with :"] = true
L["Line : "] = true
L["Testing String: "] = true
L[" Deleted Orphaned Macro "] = true
L["I am loaded"] = true
L[" Sequence named "] = true
L[" is unknown."] = true
L["Moving on - "] = true
L[" already exists."] = true
L["Sequence Name: "] = true
L["No Specialisation information for sequence "] = true
L[". Overriding with information for current spec "] = true
L["Checking if specID "] = true
L[" equals "] = true
L[" equals currentclassid "] = true
L["GSUpdateSequence PreMacro updated to: "] = true
L["GSUpdateSequence PostMacro updated to: "] = true
L["Adding missing Language :"] =  true

--Debug Strings from Errorhandler
L["Dump of GS Debug messages"] = true
L["Update"] = true
L["Close"] = true
L["[GNOME] syntax error on line %d of Sequences.lua:|r %s"] = true
L["<SEQUENCEDEBUG> |r "] = true
L["<DEBUG> |r "] = true

--Output Strings from Core
L["Close to Maximum Personal Macros.|r  You can have a maximum of "] = true
L[" macros per character.  You currently have "] = true
L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] = true
L["/gs|r again."] = true
L["Close to Maximum Macros.|r  You can have a maximum of "] = true
L["|r.  You can also have a  maximum of "] = true
L[" macros per Account.  You currently have "] = true
L["Contributed by: "] = true
L["No Help Information "] = true
L["Unknown Author|r "] = true
L["|r Incomplete Sequence Definition - This sequence has no further information "] = true

-- Setup and Help Output from Core
L[":|r GnomeSequencer was originally written by semlar of wowinterface.com."] = true
L[":|r This is a small addon that allows you create a sequence of macros to be executed at the push of a button."] = true
L[":|r Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."] = true
L[":|r This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."] = true
L[":|r To get started "] = true
L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."] = true
L["/gs listall|r will produce a list of all available macros with some help information."] = true
L[":|r To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar."] = true
L[":|r The command "] = true
L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."] = true
L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."] = true
L[":|r Your current Specialisation is "] = true
L["  The Alternative ClassID is "] = true
L["GnomeSequencer-Enhanced loaded.|r  Type "] = true
L["/gs help|r to get started."] = true
L["Version="] = true
L[":|r You cannot delete the only copy of a sequence."] = true
