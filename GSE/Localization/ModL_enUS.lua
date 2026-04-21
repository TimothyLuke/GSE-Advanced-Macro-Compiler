local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "enUS", true)

L["Update"] = true
L["Enable Actionbar Override Popup"] = true
L["GSE Sequence"] = true
L["Show Actionbar Override Watermark"] = true
L["Show the GSE logo as a small watermark on actionbar override buttons."] = true
L["GSE Companion"] = true
L["Auto Accept Companion Updates"] = true
L["Automatically import sequences pushed from the GSE Companion app without showing the import dialog. Deletes will still require confirmation."] = true

-- Sequence version / compatibility strings
L["GSE_SEQUENCE_OLDER_VERSION_TEXT"] = "WARNING: The sequence '%s' was created with an older version of GSE (%s).\n\nIt may need adjustments before it works correctly.\n\nDo you want to proceed with the import anyway?"

-- Sequence integrity / checksum strings
L["Sequence has been altered from its exported state"] = true
L["Proceed"] = true
L["GSE_SEQUENCE_INTEGRITY_WARNING_TEXT"] = "WARNING: The sequence '%s' does not have a valid integrity checksum.\n\nThis means the sequence was either not created with GSE, or has been modified since it was last exported.\n\nPlease verify its contents before using it.\n\nDo you want to proceed with the import anyway?"

-- Corrupt-sequence dialog strings
L["Skip"] = true
L["GSE_CORRUPT_SEQUENCE_TEXT"] = "The sequence '%s' (class %d) could not be read and may be corrupt.\n\nDelete it to remove the broken data, or Skip to leave it for now.\nYou can reimport the sequence from its original source to recover it."
L["Corrupt sequence '%s' (class %d) deleted."] = true
L["%d corrupt sequence(s) found \226\128\148 showing resolution options."] = true

-- checksequencesforerrors / FixSequenceStructure strings
L["Scanning GSE.Library for structural and content issues..."] = true
L["Sequence is not a table"] = true
L["Missing MetaData table"] = true
L["Missing or invalid Macros table"] = true
L["MetaData.SpecID is missing"] = true
L["Macros array is empty (no versions defined)"] = true
L["Macros array has gaps: %d version(s) reachable of %d total (max index %d)"] = true
L["MetaData.%s = %d references a non-existent Macros version (max valid index: %d)"] = true
L["Macros[%d] is not a table"] = true
L["Macros[%d].Actions is missing or not a table"] = true
L["Macros[%d].Actions has gaps: %d reachable of %d total (max index %d)"] = true
L["Macros[%d].Actions[%d] is missing Type field"] = true
L["Macros[%d].Actions[%d] has unrecognized Type: '%s'"] = true
L["Macros[%d].Actions[%d] (If) is missing the Variable field"] = true
L["Macros[%d].Actions[%d] (Embed) is missing the Sequence field"] = true
L["Macros[%d].Actions[%d] (Pause) has neither Clicks nor MS"] = true
L["Macros[%d].Actions[%d] macro text exceeds 255 characters (%d chars)"] = true
L["Macros[%d].Actions[%d] macro text has unbalanced brackets (%d '[' vs %d ']')"] = true
L["Macros[%d].Actions[%d] uses unrecognized slash command: /%s"] = true
L["Macros[%d].Actions[%d] uses // comments instead of --; GSE will not strip these on compile"] = true
L["Issues found in '%s' (class library %d):"] = true
L["Sequence '%s' (class %d) version %d block %d has no icon set (showing ?).  Open the block in the editor and assign an icon."] = true
L["To attempt automatic repair run: %s/run GSE.FixSequenceStructure(%d, \"%s\")%s"] = true
L["Compile error in Macros[%d] of '%s': %s"] = true
L["Empty step at index %d in Macros[%d] of '%s': spell ID lookup may have failed"] = true
L["%d issue(s) found.  See above for details and fix commands."] = true
-- Dependency UI labels
L["Dependencies"] = true
L["Requires Variables:"] = true
L["Embeds Sequences:"] = true
L["Requires Macros:"] = true
L["Embedded by:"] = true
L["Used by Variables:"] = true
L["Used by Sequences:"] = true
-- Dependency tracking
L["Sequence '%s' (class %d) depends on variable '%s' which does not exist."] = true
L["Sequence '%s' (class %d) embeds sequence '%s' which does not exist."] = true
L["Sequence '%s' (class %d) depends on macro '%s' which does not exist."] = true
L["Variable '%s' depends on variable '%s' which does not exist."] = true
-- Macro restore
L["Restored macro '%s' required by sequence '%s'."] = true
-- Export dependency auto-include
L["Auto-included %d variable(s) required by %s: %s"] = true
L["WARNING: %s depends on variable(s) that do not exist and cannot be exported: %s"] = true
L["%s embeds sequence '%s' — add it to the export if needed."] = true
L["WARNING: %s embeds sequence(s) that do not exist: %s"] = true
L["Invalid class library ID: %s"] = true
L["Sequence '%s' not found in class library %d."] = true
L["Cleared %d pending queue entries for '%s'."] = true
L["MetaData.%s remapped from non-existent version %d to %d."] = true
L["'%s' has been repaired and queued for recompile.  Leave combat or /reload to apply."] = true
L["'%s' repaired. Sequence is for class %d; button will update when that class is played."] = true
L["Assign GSE Sequence"] = true
L["Change Sequence"] = true
L["Clear Override"] = true
L["Sequence Disabled"] = true
L["Actionbar Overrides: The following CVars were automatically set to false as they interfere with Actionbar Overrides: "] = true
L["A UI reload is required for the MultiClickButtons change to take effect.  Type /reload when convenient."] = true

L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."] = true
L["Enter a name for the new sequence:"] = true
L["Enter a name for the new variable:"] = true
L["Create"] = true
L["<SEQUENCEDEBUG> |r "] = true
L["<DEBUG> |r "] = true

-- Output Strings from Core
L["Close to Maximum Personal Macros.|r  You can have a maximum of "] = true
L[" macros per character.  You currently have "] = true
L["Close to Maximum Macros.|r  You can have a maximum of "] = true
L["|r.  You can also have a  maximum of "] = true
L[" macros per Account.  You currently have "] = true
L["No Help Information "] = true

-- Setup and Help Output from Core
L["GnomeSequencer was originally written by semlar of wowinterface.com."] = true
L[
        "Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."
    ] = true
L[
        "This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."
    ] = true
L["The command "] = true
L["  The Alternative ClassID is "] = true
-- Sequence Editor Stuff
L["Sequence"] = true
L["New"] = true

L["Load Sequence"] = true
L["Disable Sequence"] = true
L["Sequence Editor"] = true
L["Sequence Name"] = true
L["Step Function"] = true
L["Sequential (1 2 3 4)"] = true
L["Priority List (1 12 123 1234)"] = true
L["Macro Icon"] = true
L["Delete Version"] = true
L["Specialisation / Class ID"] = true
-- Options Debug

-- Options Stuff
L["You need to reload the User Interface to complete this task.  Would you like to do this now?"] = true
L["Yes"] = true
L["No"] = true
L["General"] = true
L["General Options"] = true

L[
        "By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."
    ] = true

L["Debug Mode Options"] = true

L["Display debug messages in Chat Window"] = true
L["This will display debug messages in the Chat window."] = true
L["Store Debug Messages"] = true

L["Colour"] = true
L["Colour and Accessibility Options"] = true
L["Open Colour Settings"] = true
L["Click to open the colour picker for GSE text and editor colours."] = true
L["Title Colour"] = true
L["Picks a Custom Colour for the Mod Names."] = true
L["Info Colour"] = true
L["Picks a Custom Colour for informational and debug output."] = true
L["Command Colour"] = true
L["Picks a Custom Colour for the Commands."] = true
L["Emphasis Colour"] = true
L["Picks a Custom Colour for emphasis."] = true
L["Normal Colour"] = true
L["Picks a Custom Colour to be used normally."] = true
L["Editor Colours"] = true
L["Spells & Action Labels"] = true
L["Picks a Custom Colour for spell names and action block type labels."] = true
L["Unknown Colour"] = true
L["Picks a Custom Colour to be used for unknown terms."] = true
L["Table Operators"] = true
L["Picks a Custom Colour for table operators such as { } and ..."] = true
L["Numbers & Operators"] = true
L["Picks a Custom Colour for numbers and arithmetic operators."] = true
L["Bracket Operators"] = true
L["Picks a Custom Colour for array bracket operators [ ]."] = true
L["Conditionals & Comments"] = true
L["Picks a Custom Colour for macro conditionals eg [mod:shift] and comments."] = true
L["Logic & Comparison"] = true
L["Picks a Custom Colour for logic and comparison operators such as == and or."] = true
L["Modifiers & Functions"] = true
L["Picks a Custom Colour for conditional modifiers and standard functions."] = true
L["Slash Commands"] = true
L["Picks a Custom Colour for WoW macro slash commands like /cast and /use."] = true
L["Plugins"] = true

L["Registered Addons"] = true
L["No plugins are currently registered."] = true
L["Reload All"] = true
L["Restore"] = true
L["Individual Sequences - %s"] = true
L["Restore a single sequence from this plugin"] = true
L["Sequence '%s' was created with an older version of GSE (%s) - importing anyway as part of collection."] = true
L["Compatible with this version of GSE"] = true
L["Not compatible with this version of GSE (sequence version: %s)"] = true
L["unknown"] = true
L["Checksum valid"] = true
L["Checksum invalid - sequence may have been modified"] = true
L["No checksum"] = true
L["Default Tree Panel Width"] = true
L["How many pixels wide should the sequence list panel on the left of the Editor be.  Defaults to 150"] = true

L["Import"] = true
L["Close"] = true
L["Debug Output Options"] = true
L["Enable Debug for the following Modules"] = true
L["Debug"] = true
L["Filter Sequence Selection"] = true
L["Show All Sequences in Editor"] = true
L["Show Class Sequences in Editor"] = true
L[
        "When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"
    ] = true

-- New Strings 1.4
L["Sequence Debugger"] = true
L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] = true
L["Output"] = true
L["Pause"] = true
L["Resume"] = true
L["Clear"] = true
L["Options"] = true
L["Disable"] = true
L["Enable"] = true

L["Save"] = true
L["Send To"] = true
L["Send"] = true
L["Received Sequence "] = true
L[" from "] = true
L["Ready to Send"] = true
L[" sent"] = true
L["Reset Sequences when out of combat"] = true
L["Resets sequences back to the initial state when out of combat."] = true

-- 1.4.4
L["Record Macro"] = true
L["Actions"] = true
L["Record"] = true
L["Pause"] = true
L["Create Macro"] = true
L["Stop"] = true

-- 2.0
L[
        "GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."
    ] = true

L["Configuration"] = true
L["Help Information"] = true
L["Help Link"] = true
L["Default Version"] = true
L["Raid"] = true
L["Mythic"] = true
L["PVP"] = true
L["Author"] = true
L["Combat"] = true
L["Resets"] = true
L["This is the only version of this macro.  Delete the entire macro to delete this version."] = true
L[
        "You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."
    ] = true
L["Macro Version %d deleted."] = true
L["This change will not come into effect until you save this macro."] = true
L["PVP setting changed to Default."] = true
L["Delete"] = true
L["Cancel"] = true
L["Addin Version %s contained versions for the following sequences:"] = true

L["GSE"] = true
L["Export a Sequence"] = true
L["Export"] = true
L["Copy this link and open it in a Browser."] = true
L["This will display debug messages for the "] = true
L[" Deleted Orphaned Macro "] = true
--- GSE2.0.1-2.0.4
L["Show Global Sequences in Editor"] = true
L["This shows the Global Sequences available as well as those for your class."] = true
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
L[
        "GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."
    ] = true

L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."] =
    true
L["Mouse Buttons."] = true
L["Sequence Reset"] = true
L[
        "These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."
    ] = true
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
L[
        "This function will update macro stubs to support listening to the options below.  This is required to be completed 1 time per character."
    ] = true

-- GSE 2.1.01
L[
        "To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"
    ] = true
L[
        "By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."
    ] = true

-- GSE 2.1.04
L[
        "Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."
    ] = true

-- GSE 2.1.05
L[
        "GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."
    ] = true
L["Show GSE Users in LDB"] = true
L["Show OOC Queue in LDB"] = true

L["GSE Users"] = true
L["There are no events in out of combat queue"] = true
L["There are %i events in out of combat queue"] = true
L["GSE Version: %s"] = true
L["GSE: Left Click to open the Sequence Editor"] = true
L["GSE: Right Click to open the Sequence Debugger"] = true
L["Finished scanning for errors.  If no other messages then no errors were found."] = true
L["Replace"] = true
L["Paused"] = true
L["Running"] = true
L["Paused - In Combat"] = true
L["The GSE Out of Combat queue is %s"] = true

-- GSE 2.2.00
L["Unable to interpret sequence."] = true
L["Gnome Sequencer: Compress a Sequence String."] = true
L["Compress Sequence from Forums"] = true
L["Sequence to Compress."] = true
L["Compress"] = true
L["Heroic setting changed to Default."] = true
L["Dungeon setting changed to Default."] = true
L["Party setting changed to Default."] = true
L[
        "Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."
    ] = true

-- GSE 2.2.07
L["Random - It will select .... a spell, any spell"] = true

-- GSE 2.3.00
L["The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."] = true
L["Arena setting changed to Default."] = true
L["Arena"] = true
L["Local Macro"] = true
L["Updated Macro"] = true
L["Sequence Compare"] = true
L[
        "When GSE imports a sequence and it already exists locally and has local edits, what do you want the default action to be.  Merge - Add the new MacroVersions to the existing Sequence.  Replace - Replace the existing sequence with the new version. Ignore - ignore updates.  This default action will set the default on the Compare screen however if the GUI is not available this will be the action taken."
    ] = true
L["Merge"] = true
L["Ignore"] = true
L["Choose import action:"] = true
L["Continue"] = true
L["Extra Macro Versions of %s has been added."] = true
L["No changes were made to "] = true
L[" was updated to new version."] = true
L["Sequence Name %s is in Use. Please choose a different name."] = true
L["Timewalking"] = true
L["Mythic+"] = true
L["Create Human Readable Export"] = true

-- GSE 2.3.02
L["Rename New Macro"] = true
L[" was imported as a new macro."] = true
L["New Sequence Name"] = true

-- GSE 2.3.09
L["Mythic+ setting changed to Default."] = true
L["Timewalking setting changed to Default."] = true

-- GSE 2.4.01
L[
        "This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."
    ] = true

-- GSE 2.4.06
L["Your ClassID is "] = true

-- GSE 2.4.08
L[
        "The name of your macro.  This name has to be unique and can only be used for one object.\nYou can copy this entire macro by changing the name and choosing Save."
    ] = true
L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."] = true
L["Opens the GSE Options window"] = true
L["Send this macro to another GSE player who is on the same server as you are."] = true
L["Save the changes made to this macro"] = true
L["What class or spec is this macro for?  If it is for all classes choose Global."] = true
L[
        "Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."
    ] = true
L["Website or forum URL where a player can get more information or ask questions about this macro."] = true
L["The version of this macro that will be used where no other version has been configured."] = true
L["The version of this macro that will be used when you enter raids."] = true
L[
        "The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."
    ] = true
L["The version of this macro to use in Mythic Dungeons."] = true
L["The version of this macro to use in PVP."] = true
L["The version of this macro to use in normal dungeons."] = true
L["The version of this macro to use in heroic dungeons."] = true
L["The version of this macro to use when in a party in the world."] = true
L["The version of this macro to use when in time walking dungeons."] = true
L["The version of this macro to use in Mythic+ Dungeons."] = true
L[
        "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
    ] = true
L["The author of this macro."] = true
L[
        "Delete this version of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
    ] = true
L["Reset this macro when you exit combat."] = true
L["Delete this macro.  This is not able to be undone."] = true
L["Decompress"] = true

-- GSE 2.4.11
L["About"] = true
L["About GSE"] = true
L["History"] = true
L[
        "GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community."
    ] = true
L["Supporters"] = true
L[
        "The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."
    ] = true
L["Hide Minimap Icon"] = true
L["Hide Minimap Icon for LibDataBroker (LDB) data text."] = true

-- GSE 2.4.15 - Missing translations
L["Raid setting changed to Default."] = true
L["Mythic setting changed to Default."] = true

-- GSE 2.5.0
L["MS Click Rate"] = true
L["The milliseconds being used in key click delay."] = true

-- 2.5.3
L["Scenario"] = true
L["Delves and Scenarios"] = true

-- 2.5.4
L["GSE: Import a Macro String."] = true

-- 2.5.5
L["Version"] = true

-- 2.5.9
L["The version of this macro to use in Scenarios."] = true
L["The version of this macro to use in Delves and Scenarios."] = true
L["Scenario setting changed to Default."] = true
L["Delves and Scenarios setting changed to Default."] = true

-- 2.6.01
L["Variables"] = true
L["Name"] = true
L["Delete Variable"] = true
L["Delete this variable from the sequence."] = true
L["Comma-separated list of WoW events or GSE messages that trigger this variable. You can type names directly or pick from the list on the right."] = true
L["Default Editor Height"] = true
L["How many pixels high should the Editor start at.  Defaults to 700"] = true
L["Default Editor Width"] = true
L["How many pixels wide should the Editor start at.  Defaults to 700"] = true

--2.6.08
L["WARNING ONLY"] = true

-- 2.6.11
L[
        "Checks to see if you have a Heart of Azeroth equipped and if so will insert '/cast Heart Essence' into the macro.  If not your macro will skip this line."
    ] = true

-- 2.6.19
L["Current GCD"] = true

-- 2.6.21
L["WeakAuras was not found."] = true

--2.6.33
L["Show Current Spells"] = true
L[
        "GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."
    ] = true

--2.6.38
L["GSE - %s's Macros"] = true
L["Request Macro"] = true
L["Request that the user sends you a copy of this macro."] = true
L["Select a Sequence"] = true
--3.0.0
L["Block Type: %s"] = true
L["How many macro Clicks to pause for?"] = true
L["Clicks"] = true
L["Measure"] = true
L[
        "A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.\nIf using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box."
    ] = true
L["Raw Edit"] = true
L[
        "Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."
    ] = true
L["Compile"] = true
L["Unable to process content.  Fix table and try again."] = true
L["Raw Editor"] = true
L["Global"] = true
L["Move Up"] = true
L["Move this block up one block."] = true
L["Move Down"] = true
L["Move this block down one block."] = true
L["Delete Block"] = true
L[
        "Delete this Block from the sequence.  \nWARNING: If this is a loop this will delete all the blocks inside the loop as well."
    ] = true
L["Add Action"] = true
L["Add an Action Block."] = true
L["Add Loop"] = true
L["Add a Loop Block."] = true
L["Add Pause"] = true
L["Add a Pause Block."] = true
L["Pause for the GCD."] = true
L["Error processing Custom Pause Value.  You will need to recheck your macros."] = true
L["Support GSE"] = true

-- 3.0.2
L["Compiled Template"] = true
L["Show the compiled version of this macro."] = true

--3.0.10
L["was unable to be programmed.  This macro will not fire until errors in the macro are corrected."] = true
L[
        "%s macro may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this macro."
    ] = true

--3.0.13
L["Compiled"] = true

--3.0.16
L["Disable Block"] = true
L[
        "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
    ] = true

--3.0.17
L["If Blocks require a variable that returns either true or false.  Create the variable first."] = true
L["Add If"] = true
L[
        "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
    ] = true

--3.0.20
L["Macro Compile Error"] = true
L["If Blocks Require a variable."] = true

--3.0.35
L["Window Sizes"] = true
L["Frame Locations"] = true
L["Default Debugger Height"] = true
L["How many pixels high should the Debuger start at.  Defaults to 500"] = true
L["Default Debugger Width"] = true
L["How many pixels wide should the Debugger start at.  Defaults to 700"] = true

--#994
L["Reverse Priority (1 21 321 4321)"] = true

-- #880
L["Milliseconds"] = true
L["How many milliseconds to pause for?"] = true
L["Local Function: "] = true

-- #659
L["Copy this link and paste it into a chat window."] = true

-- #996
L[
        "/gse|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."
    ] = true
L[
        "/gse cleanorphans|r will loop through your macros and delete any left over GSE macros that no longer have a sequence to match them."
    ] = true
L["/gse help|r to get started."] = true
L["Advanced Macro Compiler loaded.|r  Type "] = true
L["GSE Plugins"] = true
L[
        "As GSE is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gse cleanorphans"
    ] = true

-- #1087
L["Character"] = true

-- #1114
L["The GUI is missing.  Please ensure that your GSE install is complete."] = true
L["The GUI is corrupt.  Please ensure that your GSE install is complete."] = true
L["The GUI needs updating.  Please ensure that your GSE install is complete."] = true

-- #981
L["Block Path"] = true
L[
        "The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.\nEG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block."
    ] = true
L["Error: Destination path not found."] = true
L["Error: Source path not found."] = true
L["Error: You cannot move a container to be a child within itself."] = true
-- #1146
L["was unable to be interpreted."] = true
L["Unrecognised Import"] = true

-- #1161

-- #1202
L["Troubleshooting"] = true
L["Common Solutions to game quirks that seem to affect some people."] = true
L["CVar Settings"] = true
L["ActionButtonUseKeyDown"] = true
L[
        "This CVAR makes WoW use your abilities when you press the key not when you release it.  To use GSE in its native configuration this needs to be checked."
    ] = true

-- #1209
L[
        "This setting forces the ActionButtonUseKeyDown setting one way or another.  It also reconfigures GSE's Macro Stubs to operate in the specified mode."
    ] = true

-- #1215
L[
        "Dragonflight has changed how the /click command operates.  As a result all your macro stubs (found in /macro) have been updated to match the value of the CVar ActionButtonUseKeyDown.  This is a one off configuration change that needs to be done for each character.  You can change this configuration in GSE's Options."
    ] = true
L[
        "GSE Macro Stubs have been reset to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)"
    ] = true

-- #1210
L[
        "The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."
    ] = true
L["OOC Queue Delay"] = true

--1239
L["/gse|r again."] = true

--1248
L["Clear Spell Cache"] = true
L["Clear"] = true
L["This function will clear the spell cache and any mappings between individual spellIDs and spellnames."] = true
L[
        "This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames.."
    ] = true
L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."] = true
L["Edit Spell Cache"] = true
L["The GSE_GUI Module needs to be enabled to edit the spell cache."] = true
L["Edit"] = true
L["Reload"] = true
L["Spell Cache Editor"] = true
L["Spell ID"] = true
L["Spell Name"] = true

--1315
L[
        "GSE2 Retro interface loaded.  Type `%s/gse2 import%s` to import an old GSE2 string or `%s/gse2 edit%s` to mock up a new template using the GSE2 editor."
    ] = true

-- 1377

-------------------------
L["Unit Name"] = true
L["Disable Sequence"] = true
L["Do not compile this Sequence at startup."] = true
L["Action Type"] = true
L["There was an error processing "] = true
L["Export Variable"] = true
L["Save the changes made to this variable."] = true
L["Variable"] = true
L["Sequences"] = true
L["Macros"] = true
L["Implementation Link"] = true
L["Current Value"] = true
L["Not Yet Active"] = true
L["Chat Link"] = true
L["Account Macros"] = true
L["Character Macros"] = true
L["Macro Name"] = true
L["Manage Macro with GSE"] = true
L["%s/255 Characters Used"] = true
L["Macro"] = true
L["Macro Template"] = true
L["Compiled Macro"] = true
L["Manage Variables"] = true
L["Insert GSE Sequence"] = true
L["Insert GSE Variable"] = true
L[
        "The UI has been set to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)  You will need to check your macros and adjust your click commands."
    ] = true
L[
        "The UI has been set to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME` You will need to check your macros and adjust your click commands."
    ] = true
L["Import Macro from Forums"] = true
L["Gnome Sequencer Enhanced"] = true
L["GSE: Record your rotation to a macro."] = true
L["GSE: Export"] = true
L["Print Active Modifiers on Click"] = true
L["Store output of debug messages in a Global Variable that can be referrenced by other mods."] = true
L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"] = true
L["Enable Mod Debug Mode"] = true
L["Command Colour"] = true
L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."] =
    true
L["Party"] = true
L["Repeat"] = true
L["How many times does this action repeat"] = true
L[
        "Create a new macro in the /macro interface and assign it an Icon. Then reopen this menu.  You cannot create a new macro here but after it has been created you can manage it."
    ] = true
L["When exporting from GSE create a descriptive export for Discord/Discource forums."] = true
L["Create Human Readable Exports"] = true
L["The author of this Variable."] = true
L["Last Updated"] = true
L["The author of this Macro."] = true
L["Saved"] = true
L["Save pending for "] = true
L["Insert Spell"] = true
L["Advanced Export"] = true
L["Set Key to Bind"] = true
L["Keybind"] = true
L["Keybindings"] = true
L["Spell"] = true
L["Item"] = true
L["Pet"] = true
L["Toy"] = true
L["Macro Name or Macro Commands"] = true
L["Pet Ability"] = true
L["This macro is not compatible with this version of the game and cannot be imported."] = true
L["Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."] = true
L["with no body"] = true
L["GSE Discord"] = true
L["Report an Issue"] = true
L["GSE: Whats New in "] = "GSE: What's new in "
L["Show next time you login."] = true
L["Changes Left Side, Changes Right Side, Many Changes!!!! Handle It!"] = true

-- #1524
L["Enter the implementation link for this variable. Use '= true' or '= false' to test."] = true
L["Insert Test Case"] = true

-- #1525
L["Left Mouse Button"] = true
L["Right Mouse Button"] = true
L["Talent Loadout"] = true
L["All Talent Loadouts"] = true

L["Processing Collection of %s Elements."] = true
L["Already Known"] = true
L[" was imported."] = true

-- #1617
L["Actionbar Overrides"] = true
L["Actionbar Buttons"] = true
L["New KeyBind"] = true
L["New Actionbar Override"] = true

L["Missing Variable "] = true

-- #1648
L["GSE: Middle Click to open the Keybinding Interface"] = true

-- #1621
L["Select Icon"] = true
L["Choose any icon..."] = true

-- #1683
L["There is an error in the sequence that needs to be corrected before it can be saved."] = true

-- #1713
L["Button State"] = true

-- #1738
L["Open %s in New Window"] = true
L["modified in other window.  This view is now behind the current sequence."] = true

-- #1762
L["New Sequence"] = true
L["Default"] = true
L["New Variable"] = true

-- #1773
L[
        "This setting is a common setting used by all WoW mods.  If affects how your action buttons respond.  With this on the react when you hit the button.  With them off they react when you let them go.  In GSE's case this setting has to be off for Actionbar Overrides to work."
    ] = true
L["Use MultiClick Buttons"] = true
L[
        "GSE Sequences are converted to a button that responds to 'Clicks' or Keyboard keypresses (WoW calls these Hardware Events).  \n\nWhen you use a KeyBind with a sequence, WoW sends two hardware events each time. With this setting on, GSE then interprets these two clicks as one and advances your sequence one step.  With this off it would advance two steps.  \n\nIn comparison Actionbar Overrides and '/click SEQUENCE' macros only sends one hardware Event.  If you primarily use Keybinds over Actionbar Overrides over Keybinds you want this set true.  If however you want to use Actionbar Overrides this must be false."
    ] = true
L["Button Settings"] = true

-- #1806
L["Skyriding / Vehicle Keybinds"] = true
L["Override bindings for Skyriding, Vehicle, Possess and Override Bars"] = true
L["Skyriding Button"] = true
L["Unassigned"] = true
L["Press a key..."] = true

-- #1835
L["Keybinding Tools"] = true
L["Show Sequence Icons"] = true
L["Show the Sequence Icon Preview Frame"] = true
L["Preview Icon Size"] = true
L["Default is 64 pixels."] = true
L["Horizontal Layout"] = true
L["Icon Preview Orientation: Horizontal"] = true
L["Vertical Layout"] = true
L["Icon Preview Orientation: Vertical"] = true
L["Show Sequence Modifiers"] = true
L["Show the Modifiers (eg Shift, Alt, Ctrl) and Buttons (eg Left Mousebutton) that were seen by the GSE sequence at the click/press it was triggered from."] = true
L["Show Sequence Name"] = true
L["Show the Name of the Sequence"] = true
-- #1846
L["Options Not Enabled"] = true
L["Options will open after combat ends."] = true
L["Import String Not Recognised."] = true
L["GSE Import Successful."] = true
L["GSE Collection to Import."] = true

-- #1860
L["Removed unreadable sequence "] = true
L[
        "/gse checksequencesforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."
    ] = true
L[
        "/gse clearincoming|r will abort any pending GSE Companion updates without importing them, and tell the Companion to prune them."
    ] = true

-- #1854
L["Add Embed"] = true

-- #1850 Variable Event Callback
L["Execute on Event"] = true
L["Trigger Events"] = true
L["When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."] = true
L["Add from List"] = true
L["Select a known WoW event or GSE message to append it to the Trigger Events box."] = true
-- Menu orientation & lock
L["Menu"] = true
L["Menu Options"] = true
L["Growth Direction"] = true
L["Direction the menu grows from the logo button."] = true
L["Up"] = true
L["Down"] = true
L["Left"] = true
L["Right"] = true
L["Lock Position"] = true
L["Lock Menu Position"] = true
L["Prevent the menu from being dragged to a new position."] = true
L["Right-Click for Options"] = true
L["Shift + Right-Click to copy version"] = true
L["Position Locked"] = true
L["Change"] = true
L["Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."] = true
L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."] = true

L["When enabled, all of your WoW macros are imported into GSE.Tools and kept in sync via the GSE Companion App. Changes made via the /macro dialog are reflected in GSE's Managed Macro Section, and incoming changes from GSE.Tools are written back to your WoW macros."] = true
L["Sync WoW Macros to GSE.Tools"] = true

L["WhatsNew"] =
[[|cFFFFFFFFGS|r|cFF00FFFFE|r 3.3.10

|cFFFFD100GSE.tools — The GSE Platform|r
GSE now has a home on the web at |cFF00BFFFgse.tools|r. Browse, share, and discover sequences, variables, and macros created by the community. Sequences you mark as |cFF00FFFFpublic|r on the platform are visible to everyone — no account required to view them.

|cFFFFD100GSE Companion App|r
The |cFF00BFFFGSE Companion|r is a desktop app that connects your in-game GSE to the platform. It:
 - |cFFFFD100Syncs|r your sequences, variables, and macros to your gse.tools account automatically.
 - |cFFFFD100Installs|r content from the platform directly into your WoW client — browse on gse.tools, click Install, and |cFF00BFFF/reload|r.
 - |cFFFFD100Receives updates|r when authors publish new versions of sequences you have installed.
 - Works with Retail, Classic, and PTR clients.

Download the Companion at |cFF00BFFFgse.tools|r. Once installed, a small bridge addon (|cFFFFFFFFGSE Companion Bridge|r) appears in your addon list — keep it enabled.

|cFFFFD100Platform Import Queue|r
When the Companion delivers content, the |cFF00BFFFImport|r dialog opens automatically on login showing what is available. If you close the dialog without importing, a reminder appears in chat with instructions to reopen it via |cFF00BFFF/gse import|r.

Authors who enable |cFF00BFFFAuto-Accept|r in GSE Options will have incoming updates imported silently on login.

]]
