local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "enUS", true)


L["Update"] = true
L["<SEQUENCEDEBUG> |r "] = true
L["<DEBUG> |r "] = true

-- Output Strings from Core
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

-- Sequence Editor Stuff
L["Sequence"] = true
L["Edit"] = true
L["New"] = true
L["Choose Language"] = true
L["Translated Sequence"] = true
L["Sequence Viewer"] = true

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
L["/gs |r to get started."] = true
L["Gnome Sequencer: Sequence Version Manager"] = true
L["Manage Versions"] = true
L["Active Version: "] = true
L["Select Other Version"] = true
L["Make Active"] = true
L["Delete Version"] = true
L["No Sequences present so none displayed in the list."] = true
L["Specialisation / Class ID"] = true
L["You need to reload the User Interface for the change in StepFunction to take effect.  Would you like to do this now?"] = true

-- Options Debug


-- Options Stuff
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
L["Debug"] = true
L["Filter Macro Selection"] = true
L["Show All Macros in Editor"] = true
L["By setting this value the Sequence Editor will show every macro for every class."] = true
L["Show Class Macros in Editor"] = true
L["Source Language "] = true
L[" is not available.  Unable to translate sequence "] = true
L["Target language "] = true
L["Auto Create Class Macro Stubs"] = true
L["When loading or creating a sequence, if it is a macro of the same class automatically create the Macro Stub"] = true
L["Auto Create Global Macro Stubs"] = true
L["When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"] = true
L["Updating due to new version."] = true
L["Creating New Sequence."] = true

-- Transmission Stuff
L["This will display debug messages for the GS-E Ingame Transmission and transfer"] = true

-- New Strings 1.4
L["Use Head Item in KeyRelease"] = true
L["Incorporate the Head slot into the KeyRelease. This is the equivalent of /use [combat] 1 in a KeyRelease."] = true
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
L["GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."] = true
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
L["Macro Version %d deleted."] = true
L["This change will not come into effect until you save this macro."] = true
L["PVP setting changed to Default."] = true
L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."] = true
L["Delete"] = true
L["Cancel"] = true
L["Delete Icon"] = true
L["Create Icon"] = true
L["Addin Version %s contained versions for the following macros:"] = true
L["GSE allows plugins to load Macro Collections as plugins.  You can reload a collection by pressing the button below."] = true
L["The Sample Macros have been reloaded."] = true
L["GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."] = true
L["GSE"] = true
L["/gs |r to get started."] = true
L["Gnome Sequencer: Export a Sequence String."] = true
L["Export a Sequence"] = true
L["Export"] = true
L["Help URL"] = true
L["Copy this link and open it in a Browser."] = true
L["This will display debug messages for the "] = true
L[" Deleted Orphaned Macro "] = true

--- GSE2.0.1-2.0.4
L["Create buttons for Global Macros"] = true
L["Global Macros are those that are valid for all classes.  GSE2 also imports unknown macros as Global.  This option will create a button for these macros so they can be called for any class.  Having all macros in this space is a performance loss hence having them saved with a the right specialisation is important."] = true
L["Show Global Macros in Editor"] = true
L["This shows the Global Macros available as well as those for your class."] = true
L["Moved %s to class %s."] = true
L["Options have been reset to defaults."] = true
L["Hide Login Message"] = true
L["Hides the message that GSE is loaded."] = true
L["Your current Specialisation is "] = true
-- GSE 2.0.14
L["This Sequence was exported from GSE %s."] = true

-- GSE 2.1.0
L["Dungeon"] = true
L["Heroic"] = true
L["GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."] = true
L["Print KeyPress Modifiers on Click"] = true
L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."] = true
L["Automatically Create Macro Icon"] = true
L["Mouse Buttons."] = true
L["Macro Reset"] = true
L["These options combine to allow you to reset a macro while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] = true
L["Left Mouse Button"] = true
L["Right Mouse Button"] = true
L["Middle Mouse Button"] = true
L["Mouse Button 4"] = true
L["Mouse Button 5"] = true
L["Left Shift Key"] = true
L["Right Shift Key"] = true
L["Any Shift Key"] = true
L["Left Alt Key"] = true
L["Right Alt Key"] = true
L["Any Alt Key"] = true
L["Left Control Key"] = true
L["Right Control Key"] = true
L["Any Control Key"] = true
L["Alt Keys."] = true
L["Control Keys."] = true
L["Shift Keys."] = true
L["To get started "] = true
L["Update Macro Stubs."] = true
L["Update Macro Stubs"] = true
L["This function will update macro stubs to support listening to the options below.  This is required to be completed 1 time per character."] = true

-- GSE 2.1.01
L["There is an issue with sequence %s.  It has not been loaded to prevent the mod from failing."] = true
L["Error found in version %i of %s."] = true
L["To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"] = true
L["/gs checkmacrosforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."] = true
L["By setting this value the Sequence Editor will show every macro for your class.  Turning this off will only show the class macros for your current specialisation."] = true

-- GSE 2.1.04
L["Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."] = true

-- GSE 2.1.05
L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."] = true
L["Show GSE Users in LDB"] = true
L["Show OOC Queue in LDB"] = true
L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."] = true
L["GSE Users"] = true
L["There are no events in out of combat queue"] = true
L["There are %i events in out of combat queue"] = true
L["GSE Version: %s"] = true
L["GSE: Left Click to open the Sequence Editor"] = true
L["GSE: Middle Click to open the Transmission Interface"] = true
L["GSE: Right Click to open the Sequence Debugger"] = true
L["Finished scanning for errors.  If no other messages then no errors were found."] = true
L["UpdateSequence"] = "Update Sequence"
L["Replace"] = true
L["openviewer"] = "Open Viewer"
L["CheckMacroCreated"] = "Check Macro Created"
L["Paused"] = true
L["Running"] = true
L["Paused - In Combat"]  = true
L["The GSE Out of Combat queue is %s"] = true

-- GSE 2.2.00
L["Unable to interpret sequence."] = true
L["Use Verbose Export Sequence Format"] = true
L["When exporting a sequence use a human readable verbose form."] = true
L["Gnome Sequencer: Compress a Sequence String."] = true
L["Compress Sequence from Forums"] = true
L["Sequence to Compress."] = true
L["Compress"] = true
L["Party"] = true
L["Heroic setting changed to Default."] = true
L["Dungeon setting changed to Default."] = true
L["Party setting changed to Default."] = true
L["Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."] = true

-- GSE 2.2.07
L["Random - It will select .... a spell, any spell"] = true

-- GSE 2.2.08
L["Don't Translate Sequences"] = true
L["Enable this option to stop automatically translating sequences from enUS to local language."] = true

-- GSE 2.3.00
L["The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."] = true
L["Target protection is currently %s"] = true
L["Arena setting changed to Default."] = true
L["Arena"] = true
L["Local Macro"] = true
L["Updated Macro"] = true
L["Sequence Compare"] = true
L["Default Import Action"] = true
L["When GSE imports a macro and it already exists locally and has local edits, what do you want the default action to be.  Merge - Add the new MacroVersions to the existing Macro.  Replace - Replace the existing macro with the new version. Ignore - ignore updates.  This default action will set the default on the Compare screen however if the GUI is not available this will be the action taken."] = true
L["Merge"] = true
L["Ignore"] = true
L["Choose import action:"] = true
L["Continue"] = true
L["Extra Macro Versions of %s has been added."] = true
L["No changes were made to "] = true
L[" was updated to new version."] = true
L["All macros are now stored as upper case names.  You may need to re-add your old macros to your action bars."] = true
L["MergeSequence"] = true
L["Sequence Name %s is in Use. Please choose a different name."] = true
L["Timewalking"] = true
L["Mythic+"] = true
L["Format export for WLM Forums"] = true

-- GSE 2.3.02
L["Rename New Macro"] = true
L[" was imported as a new macro."] = true
L["New Sequence Name"] = true

-- GSE 2.3.04
L["Use WLM Export Sequence Format"] = true
L["When exporting a sequence create a stub entry to import for WLM's Website."] = true


-- GSE 2.3.09
L["Mythic+ setting changed to Default."] = true
L["Timewalking setting changed to Default."] = true

-- GSE 2.4.01
L["Enforce GSE minimum version for this macro"] = true
L["This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."] = true
L["Export Macro Read Only"] = true
L["This sequence is Read Only and unable to be edited."] = true
L["Disable Editor"] = true

-- GSE 2.4.06
L["Your ClassID is "] = true

-- GSE 2.4.08
L["The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."] = true
L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."] = true
L["Opens the GSE Options window"] = true
L["Send this macro to another GSE player who is on the same server as you are."] = true
L["Save the changes made to this macro"] = true
L["What class or spec is this macro for?  If it is for all classes choose Global."] = true
L["What are the preferred talents for this macro?\n'1,2,3,1,2,3,1' means First row choose the first talent, Second row choose the second talent etc"] = true
L["Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."] = true
L["Website or forum URL where a player can get more information or ask questions about this macro."] = true
L["The version of this macro that will be used where no other version has been configured."] = true
L["The version of this macro that will be used when you enter raids."] = true
L["The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."] = true
L["The version of this macro to use in Mythic Dungeons."] = true
L["The version of this macro to use in PVP."] = true
L["The version of this macro to use in normal dungeons."] = true
L["The version of this macro to use in heroic dungeons."] = true
L["The version of this macro to use when in a party in the world."] = true
L["The version of this macro to use when in time walking dungeons."] = true
L["The version of this macro to use in Mythic+ Dungeons."] = true
L["The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."] = true
L["Inner Loop Limit controls how many times the Sequence part of your macro executes \nuntil it goes onto to the PostMacro and then resets to the PreMacro."] = true
L["The author of this macro."] = true
L["Delete this verion of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."] = true
L["These lines are executed every time you click this macro.  They are evaluated by WOW before the line in the Sequence Box."] = true
L["These lines are executed before the lines in the Sequence Box.  If an Inner Loop Limit is not set, these are executed only once.  \nIf an Inner Loop Limit has been set these are executed after the Sequence has been looped through the number of times.  \nThe Sequence will then go on to the Post Macro if it exists then back to the PreMacro."] = true
L["The main lines of the macro."] = true
L["These lines are executed every time you click this macro.  They are evaluated by WOW after the line in the Sequence Box."] = true
L["These lines are executed after the lines in the Sequence Box have been repeated Inner Loop Limit number of times.  If an Inner Loop Limit is not set, these are never executed as the sequence will never stop repeating.\nThe Sequence will then go on to the PreMacro if it exists then back to the Sequence."] = true
L["Reset this macro when you exit combat."] = true
L["These tick boxes have three settings for each slot.  Gold = Definately use this item. Blank = Do not use this item automatically.  Silver = Either use or not based on my default settings store in GSE's Options."] = true
L["Delete this macro.  This is not able to be undone."] = true
L["Create a new macro."] = true
L["Edit this macro.  To delete a macro, choose this edit option and then from inside hit the delete button."] = true
L["Export this Macro."] = true
L["Create or remove a Macro stub in /macro that can be dragged to your action bar so that you can use this macro.\nGSE can store an unlimited number of macros however WOW's /macro interface can only store a limited number of macros."] = true
L["Record the spells and items you use into a new macro."] = true
L["Decompress"] = true

-- GSE 2.4.10
L["Prompt Samples"] = true
L["When you log into a class without any macros, prompt to load the sample macros."] = true

-- GSE 2.4.11
L["About"] = true
L["About GSE"] = true
L["History"] = true
L["GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write macros with it.  Check out https://wowlazymacros.com for the things that make this mod work.  Special thanks to Lutechi for creating this community."] = true
L["Supporters"] = true
L["The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."] = true
L["Hide Minimap Icon"] = true
L["Hide Minimap Icon for LibDataBroker (LDB) data text."] = true

-- GSE 2.4.15 - Missing translations
L["Raid setting changed to Default."] = true
L["Mythic setting changed to Default."] = true

-- GSE 2.4.18
L["No Sample Macros are available yet for this class."] = true

-- GSE 2.4.22
L["Rank"] = true

-- GSE 2.4.23
L["Clear Keybindings"] = true
L["This function will remove the SHIFT+N, ALT+N and CTRL+N keybindings for this character.  Useful if [mod:shift] etc conditions don't work in game."] = true
L["Clear Common Keybindings"] = true