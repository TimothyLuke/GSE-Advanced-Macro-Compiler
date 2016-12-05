local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "enUS", true)

-- Options translation
--@localization(locale="enUS", format="lua_additive_table", namespace="GSE", handle-subnamespaces="none")@


--@do-not-package@


--Debug Strings from Core
L["createButton KeyPress: "] = true
L["createButton KeyRelease: "] = true
L["Reloading Sequences"] = true
L["Entering GSSplitMeIntolines with :"] = true
L["Line : "] = true
L["Testing String: "] = true
L[" Deleted Orphaned Macro "] = true
L["I am loaded"] = true
L[" Sequence named "] = true
L[" is unknown."] = true
L["Moving on - "] = true
L["Moving on - macro for "] = true
L[" already exists."] = true
L["Sequence Name: "] = true
L["No Specialisation information for sequence "] = true
L[". Overriding with information for current spec "] = true
L["Checking if specID "] = true
L[" equals "] = true
L[" equals currentclassid "] = true
L["GSUpdateSequence KeyPress updated to: "] = true
L["GSUpdateSequence KeyRelease updated to: "] = true
L["Adding missing Language :"] =  true
L["Removing "] = true
L[" From library"] = true
L["has been disabled.  The Macro stub for this sequence will be deleted and will not be recreated until you re-enable this sequence.  It will also not appear in the /gs list until it is recreated."] = true
L["This Sequence is currently Disabled Locally."] = true
L["is currently disabled from use."] = true
L["has been enabled.  The Macro stub is now available in your Macro interface."] = true
L["Testing "]  = true
L["Source "] = true
L["Cycle Version "] = true
L["Active Version "] = true
L["To get started "] = true
L["Your current Specialisation is "] = true
L["We have a perfect match"] = true
L["Matching specID"] = true
L["Different specID"] = true
L["Matching StepFunction"] = true
L["Different StepFunction"] = true
L["Matching KeyPress"] = true
L["Different KeyPress"] = true
L["Same Sequence Steps"] = true
L["Different Sequence Steps"] = true
L["Matching KeyRelease"] = true
L["Different KeyRelease"] = true
L["GCD Delay:"] = true

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
L["Two sequences with unknown sources found."] = true
L["FYou cannot delete this version of a sequence.  This version will be reloaded as it is contained in "] = true

-- Setup and Help Output from Core
L["GnomeSequencer was originally written by semlar of wowinterface.com."] = true
L["This is a small addon that allows you create a sequence of macros to be executed at the push of a button."] = true
L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."] = true
L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."] = true
L[":|r To get started "] = true
L["/gs|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."] = true
L["/gs listall|r will produce a list of all available macros with some help information."] = true
L["To use a macro, open the macros interface and create a macro with the exact same name as one from the list.  A new macro with two lines will be created and place this on your action bar."] = true
L["The command "] = true
L["/gs showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."] = true
L["/gs cleanorphans|r will loop through your macros and delete any left over GS-E macros that no longer have a sequence to match them."] = true
L[":|r Your current Specialisation is "] = true
L["  The Alternative ClassID is "] = true
L["GnomeSequencer-Enhanced loaded.|r  Type "] = true
L["/gs help|r to get started."] = true
L["Version="] = true
L[":|r You cannot delete the only copy of a sequence."] = true
L[" has been added as a new version and set to active.  Please review if this is as expected."] = true
L["A sequence collision has occured. "] = true
L[" tried to overwrite the version already loaded from "] = true
L[". This version was not loaded."] = true
L["Sequence specID set to current spec of "] = true
L["Sequence Author set to Unknown"] = true
L["No Help Information Available"] = true
L[" was imported with the following errors."] = true

-- 1.4 changes
L["No Active Version"] = true
L["Matching helpTxt"] = true
L["Different helpTxt"] = true
L["You cannot delete this version of a sequence.  This version will be reloaded as it is contained in "] = true

-- Editor DEBUG
L["Selecting tab: "] = true
L["GSTranslateSequenceFromTo(GSMasterOptions.SequenceLibrary["] = true
L["], (GSE.isEmpty(GSMasterOptions.SequenceLibrary["] = true
L["].lang) and GSMasterOptions.SequenceLibrary["] = true
L["].lang or GetLocale()), key)"] = true
L["GSSE:loadSequence "] = true
L["Moving on - LiveTest.KeyPress already exists."] = true
L["Moving on - LiveTest.PosMacro already exists."] = true
L["String Icon "] = true
L["Spec = "] = true
L["Class = "] = true
L["sequenceIndex: "] = true
L["No value"] = true
L["Icon: "] = true
L["none"] = true
L["Macro Found "] = true
L[" with iconid "] = true
L["of no value"] = true
L["with no body"] = true
L["No Macro Found. Possibly different spec for Sequence "] = true
L["SequenceSpecID: "] = true
L["No Sequence Icon setting to "] = true
L["No value"] = true
L["Setting Editor clean "] = true
L[" not added to list."] = true

--sequence editor stuff
L["Sequence"] = true
L["Edit"] = true
L["New"] = true
L["Choose Language"] = true
L["Translated Sequence"] = true
L["Sequence Viewer"] = true
L["Gnome Sequencer: Sequence Viewer"] = true
L["Load Sequence"] = true
L["Disable Sequence"] = true
L["Enable Sequence"] = true
L["Translate to"] = true
L["Sequence Editor"] = true
L["Gnome Sequencer: Sequence Editor."] = true
L["Sequence Name"] = true
L["Step Function"] = true
L["Sequential (1 2 3 4)"] = true
L["Priority List (1 12 123 1234)"] = true
L["Specialization Specific Macro"] = true
L["Classwide Macro"] = true
L["Macro Icon"] = true
L["KeyPress"] = true
L["KeyRelease"] = true
L["Completely New GS Macro."] = true
L["Please wait till you have left combat before using the Sequence Editor."] = true
L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] = true
L["/gsse |r to get started."] = true
L["Gnome Sequencer: Sequence Version Manager"] = true
L["Manage Versions"] = true
L["Active Version: "] = true
L["Select Other Version"] = true
L["Make Active"] = true
L["Delete Version"] = true
L["No Sequences present so none displayed in the list."] = true
L["Specialisation / Class ID"] = true
L["You need to reload the User Interface for the change in StepFunction to take effect.  Would you like to do this now?"] = true
-- options Debug


-- options stuff
L["You need to reload the User Interface to complete this task.  Would you like to do this now?"] = true
L["Yes"] = true
L["No"] = true
L["|cffff0000GS-E:|r Gnome Sequencer - Enhanced Options"] = true
L["General"] = true
L["General Options"] = true
L["Only Save Local Macros"] = true
L["GS-E can save all macros or only those versions that you have created locally.  Turning this off will cache all macros in your WTF\\GS-Core.lua variables file but will increase load times and potentially cause colissions."] = true
L["Use Macro Translator"] = true
L["The Macro Translator will translate an English sequence to your local language for execution.  It can also be used to translate a sequence into a different language.  It is also used for syntax based colour markup of Sequences in the editor."] = true
L["Delete Orphaned Macros on Logout"] = true
L["As GS-E is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gs cleanorphans"] = true
L["Use Global Account Macros"] = true
L["When creating a macro, if there is not a personal character macro space, create an account wide macro."] = true
L["Set Default Icon QuestionMark"] = true
L["By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."] = true
L["Seed Initial Macro"] = true
L["If you load Gnome Sequencer - Enhanced and the Sequence Editor and want to create new macros from scratch, this will enable a first cut sequenced template that you can load into the editor as a starting point.  This enables a Hello World macro called Draik01.  You will need to do a /console reloadui after this for this to take effect."] = true
L["Gameplay Options"] = true
L["Require Target to use"] = true
L["This option prevents macros firing unless you have a target. Helps reduce mistaken targeting of other mobs/groups when your target dies."] = true
L["Prevent Sound Errors"] = true
L["This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableErrorSpeech lines within a Sequence.  Turning this on will trigger a Scam warning about running custom scripts."] = true
L["Prevent UI Errors"] = true
L["This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."] = true
L["Clear Errors"] = true
L["This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."] = true
L["Use First Ring in KeyRelease"] = true
L["Incorporate the first ring slot into the KeyRelease. This is the equivalent of /use [combat] 11 in a KeyRelease."] = true
L["Use Second Ring in KeyRelease"] = true
L["Incorporate the second ring slot into the KeyRelease. This is the equivalent of /use [combat] 12 in a KeyRelease."] = true
L["Use First Trinket in KeyRelease"] = true
L["Incorporate the first trinket slot into the KeyRelease. This is the equivalent of /use [combat] 13 in a KeyRelease."] = true
L["Use Second Trinket in KeyRelease"] = true
L["Incorporate the second trinket slot into the KeyRelease. This is the equivalent of /use [combat] 14 in a KeyRelease."] = true
L["Use Neck Item in KeyRelease"] = true
L["Incorporate the neck slot into the KeyRelease. This is the equivalent of /use [combat] 2 in a KeyRelease."] = true
L["Use Belt Item in KeyRelease"] = true
L["Incorporate the belt slot into the KeyRelease. This is the equivalent of /use [combat] 5 in a KeyRelease."] = true
L["Debug Mode Options"] = true
L["Enable Mod Debug Mode"] = true
L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"] = true
L["Display debug messages in Chat Window"] = true
L["This will display debug messages in the Chat window."] = true
L["Store Debug Messages"] = true
L["Store output of debug messages in a Global Variable that can be referrenced by other mods."] = true
L["Debug Sequence Execution"] = true
L["Output the action for each button press to verify StepFunction and spell availability."] = true
L["Colour"] = true
L["Colour and Accessibility Options"] = true
L["Title Colour"] = true
L["Picks a Custom Colour for the Mod Names."] = true
L["Author Colour"] = true
L["Picks a Custom Colour for the Author."] = true
L["Command Colour"] = true
L["Picks a Custom Colour for the Commands."] = true
L["Emphasis Colour"] = true
L["Picks a Custom Colour for emphasis."] = true
L["Normal Colour"] = true
L["Picks a Custom Colour to be used normally."] = true
L["Editor Colours"] = true
L["Spell Colour"] = true
L["Picks a Custom Colour to be used for Spells and Abilities."] = true
L["Unknown Colour"] = true
L["Picks a Custom Colour to be used for unknown terms."] = true
L["Icon Colour"] = true
L["Picks a Custom Colour to be used for Icons."] = true
L["SpecID/ClassID Colour"] = true
L["Picks a Custom Colour to be used for numbers."] = true
L["String Colour"] = true
L["Picks a Custom Colour to be used for strings."] = true
L["Conditionals Colour"] = true
L["Picks a Custom Colour to be used for macro conditionals eg [mod:shift]"] = true
L["Help Colour"] = true
L["Picks a Custom Colour to be used for braces and indents."] = true
L["Step Functions"] = true
L["Picks a Custom Colour to be used for StepFunctions."] = true
L["Language Colour"] = true
L["Picks a Custom Colour to be used for language descriptors"] = true
L["Blizzard Functions Colour"] = true
L["Picks a Custom Colour to be used for Macro Keywords like /cast and /target"] = true
L["Plugins"] = true
L["GS-E Plugins"] = true
L["Registered Addons"] = true
L["Available Addons"] = true
L[":|r The Sequence Translator allows you to use GS-E on other languages than enUS.  It will translate sequences to match your language.  If you also have the Sequence Editor you can translate sequences between languages.  The GS-E Sequence Translator is available on curse.com"] = true
L["Use Realtime Parsing"] = true
L["The Sequence Editor can attempt to parse the Sequences, KeyPress and KeyRelease in realtime.  This is still experimental so can be turned off."] = true
L["Import"] = true
L["Close"] = true
L["Import Macro from Forums"] = true
L["Debug Output Options"] = true
L["Enable Debug for the following Modules"] = true
L["This will display debug messages for the GS-E Sequence Editor"] = true
L["This will display debug messages for the Core of GS-E"] = true
L["This will display debug messages for the GS-E Translator"] = true
L["Debug"] = true
L["Filter Macro Selection"] = true
L["Show All Macros in Editor"] = true
L["By setting this value the Sequence Editor will show every macro for every class."] = true
L["Show Class Macros in Editor"] = true
L["By setting this value the Sequence Editor will show every macro for your class."] = true
L["Source Language "] = true
L[" is not available.  Unable to translate sequence "] = true
L["Target language "] = true
L["Auto Create Class Macro Stubs"] = true
L["When loading or creating a sequence, if it is a macro of the same class automatically create the Macro Stub"] = true
L["Auto Create Global Macro Stubs"] = true
L["When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"] = true
L["Updating due to new version."] = true
L["Creating New Sequence."] = true

-- Transmission stuff
L["This will display debug messages for the GS-E Ingame Transmission and transfer"] = true

-- New Strings 1.4
L["Use Head Item in KeyRelease"] = true
L["Incorporate the Head slot into the KeyRelease. This is the equivalent of /use [combat] 1 in a KeyRelease."] = true
L["GS-E: Left Click to open the Sequence Editor"] = true
L["GS-E: Middle Click to open the Transmission Interface"] = true
L["GS-E: Right Click to open the Sequence Debugger"] = true
L["Sequence Debugger"] = true
L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] = true
L["Output"] = true
L["Pause"] = true
L["Resume"] = true
L["Clear"] = true
L["Options"] = true
L["Disable"] = true
L["Enable"] = true
L["GnomeSequencer-Enhanced"] = true
L["Help Information"] = true
L["Save"] = true
L["Sequence Saved as version "] = true
L["Imported new sequence "] = true
L["Send To"] = true
L["Send"] = true
L["Received Sequence "] = true
L[" from "] = true
L[" saved as version "] = true
L["Ready to Send"] = true
L[" sent"] = true
L["Reset Macro when out of combat"] = true
L["Resets macros back to the initial state when out of combat."] = true
L["A sequence collision has occured.  Your local version of "] = true

-- 1.4.4
L["Inner Loop Start"] = true
L["Inner Loop End"] = true
L["Inner Loop Limit"] = true
L["Record Macro"] = true
L["Gnome Sequencer: Record your rotation to a macro."] = true
L["Actions"] = true
L["Record"] = true
L["Pause"] = true
L["Create Macro"] = true
L["Stop"] = true

-- 2.0
L["The Custom StepFunction Specified is not recognised and has been ignored."] = true
L["Load"] = true
L["There are No Macros Loaded for this class.  Would you like to load the Sample Macro?"]= true
L["A sequence collision has occured.  Extra versions of this macro have been loaded.  Manage the sequence to determine how to use them "] = true
L["GSE is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."] = true
L["Macro unable to be imported."] = true
L["Macro Import Successful."]= true
L["Gnome Sequencer: Import a Macro String."] = true
L["GSE Macro"] = true
L["Legacy GS/GSE1 Macro"] = true
L["Macro Collection to Import."] = true
L["Configuration"] = true
L["Talents"] = true
L["Help Information"] = true
L["Help Link"] = true
L["Default Version"] = true
L["Raid"] = true
L["Mythic"] = true
L["PVP"] = true
L["Language"] = true
L["PreMacro"] = true
L["PostMacro"] = true
L["Author"] = true
L["Head"] = true
L["Neck"] = true
L["Belt"] = true
L["Ring 1"] = true
L["Ring 2"] = true
L["Trinket 1"] = true
L["Trinket 2"] = true
L["Use"] = true
L["Target"] = true
L["Combat"] = true
L["Resets"] = true
L["Sequence %s saved."] = true
L["This is the only version of this macro.  Delete the entire macro to delete this version."] = true
L["You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."] = true
L["Macro Version %n deleted."] = true
L["This change will not come into effect until you save this macro."] = true
L["PVP setting changed to Default."] = true

--@end-do-not-package@
