local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "enUS", true)

L["Update"] = true
L["Enable Actionbar Override Popup"] = true
L["GSE Sequence"] = true
L["Show Actionbar Override Watermark"] = true
L["Show the GSE logo as a small watermark on actionbar override buttons."] = true
L["Show Actionbar Override Label"] = true
L["Show the sequence name as a text label on actionbar override buttons."] = true
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
L["Versions starts at index 0 (Lua ipairs starts at 1 → editor and runtime see no versions). %d entr%s at index 0."] = true
L["Sequence '%s' is incompatible with the current version of GSE. Upload it to https://gse.tools to update it to the current format, then re-import."] = true
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
L["'%s' cannot be shared — it is protected content."] = true
L["Cannot share protected content"] = true
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

L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."] = true
L["Enter a Name for the New Sequence"] = true
L["Sequence Renamed"] = true
L["-gse.tools ID will remain the same-"] = true
L["Delete Sequence"] = true
L["Are you sure you want to Delete"] = true
L["This will Delete the Sequence and all Versions."] = true
L["This Action Cannot be Undone!"] = true
L["Copy this Link and Paste into a Chat Window."] = true
L["Text selected. Press Ctrl+C to Copy"] = true
L["Version Number"] = true
L["Developer Debug"] = true
L["Corrupt Sequence"] = true
L["Enter NEW Name for the Duplicated Sequence:"] = true
L["-sequence will receive a new gse.tools id-"] = true
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
L["Duplicate"] = true

L["Load Sequence"] = true
L["Disable Sequence"] = true
L["Sequence Editor"] = true
L["Sequence Name"] = true
L["Step Function"] = true
L["Sequential (1 2 3 4)"] = true
L["Priority List (1 12 123 1234)"] = true
L["Macro Icon"] = true
L["Delete Version"] = true
-- Options Debug

-- Options Stuff
L["You need to reload the User Interface to complete this task.  Would you like to do this now?"] = true
L["Yes"] = true
L["No"] = true
L["General"] = true


L["Debug Mode Options"] = true

L["Display debug messages in Chat Window"] = true
L["This will display debug messages in the Chat window."] = true
L["Store Debug Messages"] = true

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
L["Sequence '%s' was created with an older version of GSE (%s) - importing anyway as part of collection."] = true
L["Compatible with this version of GSE"] = true
L["Not compatible with this version of GSE (sequence version: %s)"] = true
L["unknown"] = true
L["Checksum valid"] = true
L["Checksum invalid - sequence may have been modified"] = true
L["No checksum"] = true

L["Import"] = true
L["Close"] = true
L["Debug Output Options"] = true
L["Enable Debug for the following Modules"] = true
L["Debug"] = true
L["Filter Sequence Selection"] = true
L["Editor Scroll Speed"] = true
L["Pixels scrolled per mouse-wheel notch in the Sequence Editor. Higher = faster scrolling. Default 280."] = true
L["All Sequences"] = true
L["Show All Sequences in Editor"] = true
L["Show Class Sequences in Editor"] = true

-- New Strings 1.4
L["Sequence Debugger"] = true
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
L[" sent"] = true
L["Reset Sequences when out of combat"] = true

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
L["Author"] = true
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
L[
        "GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."
    ] = true

L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."] =
    true
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

-- GSE 2.1.01
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
L["The version of this macro to use in PVP."] = true
L["The version of this macro to use in normal dungeons."] = true
L["The version of this macro to use when in time walking dungeons."] = true
L["The version of this macro to use in Mythic+ Dungeons."] = true
L[
        "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
    ] = true
L["The author of this macro."] = true
L[
        "Delete this version of the macro.  This can be undone by closing this window and not saving the change.  \nThis is different to the Delete button below which will delete this entire macro."
    ] = true
L["Decompress"] = true

-- GSE 2.4.11
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
L["The milliseconds being used in key click delay."] = true

-- 2.5.3

-- 2.5.4
L["GSE: Import a Macro String."] = true

-- 2.5.5
L["Version"] = true

-- 2.5.9
L["The version of this macro to use in Delves and Scenarios."] = true
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

--2.6.08
L["WARNING ONLY"] = true

-- 2.6.11

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
L["Move Down"] = true
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
L["Default Debugger Height"] = true
L["Default Debugger Width"] = true
L["How many pixels wide should the Debugger start at.  Defaults to 700"] = true

--#994
L["Reverse Priority (1 21 321 4321)"] = true

-- #880
L["Milliseconds"] = true
L["How many milliseconds to pause for?"] = true
L["Local Function: "] = true

-- #659

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

-- #1087

-- #1114
L["The GUI is missing.  Please ensure that your GSE install is complete."] = true
L["The GUI is corrupt.  Please ensure that your GSE install is complete."] = true
L["The GUI needs updating.  Please ensure that your GSE install is complete."] = true

-- #981
-- #1146
L["was unable to be interpreted."] = true
L["Unrecognised Import"] = true

-- #1161

-- #1202
L["Troubleshooting"] = true
L["Common Solutions to game quirks that seem to affect some people."] = true
L["CVar Settings"] = true
L["ActionButtonUseKeyDown"] = true

-- #1209

-- #1215

-- #1210
L[
        "The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."
    ] = true
L["OOC Queue Delay"] = true
L["Default Import Action"] = true
L[
        "Pre-selected action when an imported sequence collides with one you already have. Merge appends new versions to the existing sequence; Replace overwrites it; Ignore skips the import; Rename brings the new sequence in under a different name."
    ] = true
L[
        "Auto-repaired %d sequence(s) with structurally invalid Versions (index-0 keys remapped to 1-based)."
    ] = true

--1239
L["/gse|r again."] = true

--1248
L["Clear Spell Cache"] = true
L["Clear"] = true
L["This function will clear the spell cache and any mappings between individual spellIDs and spellnames."] = true
L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."] = true
L["Edit Spell Cache"] = true
L["The GSE_GUI Module needs to be enabled to edit the spell cache."] = true
L["Edit"] = true
L["Reload"] = true
L["Spell Cache Editor"] = true
L["Spell ID"] = true
L["Spell Name"] = true

--1315

-- 1377

-------------------------
L["Unit Name"] = true
L["Disable Sequence"] = true
L["Do not compile this Sequence at startup."] = true
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
L["Repeat"] = true
L["How many times does this action repeat"] = true
L["When exporting from GSE create a descriptive export for Discord/Discource forums."] = true
L["Create Human Readable Exports"] = true
L["The author of this Variable."] = true
L["The author of this Macro."] = true
L["Saved"] = true
L["Save pending for "] = true
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

L["Button Settings"] = true

-- #1806
L["Skyriding / Vehicle Keybinds"] = true
L["Skyriding Button"] = true
L["Press a key..."] = true

-- #1835
L["Keybinding Tools"] = true
-- #1846
L["Options Not Enabled"] = true
L["Import String Not Recognised."] = true
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
L["Toolbar"] = true
L["Toolbar Options"] = true
L["Growth Direction"] = true
L["Up"] = true
L["Down"] = true
L["Left"] = true
L["Right"] = true
L["Lock Position"] = true
L["Lock Toolbar Position"] = true
L["Strata"] = true
L["Static Toolbar"] = true
L["Slide Out Toolbar"] = true
L["When checked, the toolbar icons stay always visible (Static Toolbar). When unchecked, icons stay hidden until you mouseover the logo, then slide out."] = true
L["Background"] = true
L["Low"] = true
L["High"] = true
L["Dialog"] = true
L["Right-Click for Options"] = true
L["Shift + Right-Click to copy version"] = true
L["Position Locked"] = true
L["Change"] = true
L["Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."] = true

L["When enabled, all of your WoW macros are imported into GSE.Tools and kept in sync via the GSE Companion App. Changes made via the /macro dialog are reflected in GSE's Managed Macro Section, and incoming changes from GSE.Tools are written back to your WoW macros."] = true
L["Sync WoW Macros to GSE.Tools"] = true
L["Pause Sequences While Shift Is Held"] = true
L["When enabled, holding Shift makes GSE send an empty macro and stops the sequence from advancing until Shift is released."] = true
L["Pause Sequences While Alt Is Held"] = true
L["When enabled, holding Alt makes GSE send an empty macro and stops the sequence from advancing until Alt is released."] = true
L["Pause Sequences While Ctrl Is Held"] = true
L["When enabled, holding Ctrl makes GSE send an empty macro and stops the sequence from advancing until Ctrl is released."] = true

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

-- =========================================================================
-- Keys auto-added by locale audit: previously fell through to AceLocale's
-- key-as-value default. Adding them here makes enUS the complete source of
-- truth so future translators have a full reference. No runtime change.
-- =========================================================================

-- Used in GSE_GUI/Editor.lua
L["You cannot open a new Sequence Editor window while you are in combat.  Please exit combat and then try again."] = true

-- Used in GSE_GUI/Editor_Macro.lua
L["Used by Sequences"] = true

-- Used in GSE_GUI/Editor_Metadata.lua
L["Class"] = true
L["Config"] = true
L["Date Last Updated"] = true
L["Delves/Scenarios"] = true
L["Notes"] = true
L["PvE"] = true
L["PvP"] = true
L["Solo"] = true
L["Specialization/Class ID"] = true
L["The version of this macro to use while solo in PvE."] = true
L["Type"] = true

-- Used in GSE_GUI/Editor_Tree.lua
L["Delete this sequence.  This is not able to be undone."] = true
L["Export this sequence."] = true
L["One or more MacroBlocks are over 255 characters. Shorten them before saving."] = true
L["Open or close the sequence debugger."] = true
L["Reload the user interface."] = true
L["This sequence is unable to be exported."] = true

-- Used in GSE_GUI/Export.lua
L["Enter Export Package Name"] = true

-- Used in GSE_GUI/Menu.lua
L["Cannot Open Options during Combat"] = true

-- Used in GSE_GUI/NativeUI.lua
L["GSE Developer Debug settings are active.\n\nActive: %s\n\nThese settings can create heavy logging during gameplay or loading."] = true

-- Used in GSE_Options/Options.lua
L["Breathe"] = true
L["Dimming intensity of the focused-block highlight pulse, stacked on top of the Focus Highlight Proc type. Step left/right with the arrow buttons — Low is subtler (smaller alpha swing), Medium uses the type's baseline, High is more dramatic (bigger alpha swing). Has no effect when Focus Highlight Proc is set to Off."] = true
L["Flash"] = true
L["Focus Highlight Brightness"] = true
L["Focus Highlight Proc"] = true
L["Focus Highlight Tint"] = true
L["How many pixels wide should the Editor start at.  Defaults to 1050"] = true
L["Medium"] = true
L["Off"] = true
L["Proc-style animation type for the focused-block highlight border in the Sequence Editor. Step left/right with the arrow buttons to cycle through styles — Pulse is the default smooth fade; Flash is sharp fast on/off; Throb is a slow heavy fade; Breathe is a slow gentle ripple; Strobe is very fast alternation; Off keeps the border solid. Border color stays the per-action-type default."] = true
L["Pulse"] = true
L["Strobe"] = true
L["Throb"] = true
L["Use GSE's Modern interface skin. This does not require ElvUI."] = true
L["When enabled, holding the matching modifier sends an empty macro instead of advancing the sequence step."] = true
L["When enabled, the focused block's empty areas (outside the macro text box) get a soft fill in the rail color so you can spot it at a glance. Disable to keep only the proc-pulsed border around the focused block — useful if the tint feels distracting while reading or editing."] = true

-- Used in GSE_QoL/QoL.lua
L["Not Bound"] = true

-- Used in GSE_Utils/Utils.lua
L["/gse showspec|r will show your current Specialisation and the SPECID needed to tag any existing macros."] = true
L["Your sequence name was longer than 27 characters.  It has been shortened from %s to %s so that your macro will work."] = true
L["|r.  As a result this macro was not created.  Please delete some macros and reenter "] = true
L["|r. As a result this macro was not created.  Please delete some macros and reenter "] = true

-- Release sync: keys present in code but previously missing from enUS.
-- Added so enUS is complete (used == defined) and translators see them.
L["Delay spell translations to reduce lag for users with older machines. When on, the macro editor waits until you click out of a box to translate and colour spell IDs and names instead of doing it as you type. Off by default (live as you type while editing). This only affects the editor; nothing is translated during normal gameplay."] = true
L["Delayed Spell Translations"] = true
L["GSE registers additional subcommands of /gse: /gse resettracker (restore the tracker to its default layout), /gse savelayoutx and /gse savelayouty (save the current tracker layout to slot X or Y), /gse applylayoutx and /gse applylayouty (apply a saved layout), /gse iconscan and /gse spelliconreset and /gse saveallsequences (action-icon maintenance)."] = true
L["How the macro editor turns spell IDs into spell names as you edit."] = true

-- =========================================================================
-- DebugWindow.lua button-label strings — passed to GSE.SetDebuggerButtonText
-- which routes through DebuggerLabel → L[key]. These don't appear as
-- L["..."] in source so the static audit missed them; AceLocale errored
-- at runtime on first lookup until these were registered.
-- =========================================================================
L["Tracker: On"] = true
L["Tracker: Off"] = true
L["Stats: On"] = true
L["Stats: Off"] = true
L["Hardware: On"] = true
L["Hardware: Off"] = true
L["|cFFFFFFFFGS|r|cFF00FFFFE|r|cFFFFFFFF:|r |cFFFFD100Resources|r"] = true

-- =========================================================================
-- Restored direct L["X"] uses missed by earlier audit (caught at runtime
-- when Editor_Metadata.lua's contextVersionConfigs table loaded — these
-- keys are referenced as `L["X"]` at chunk-level in that file).
-- =========================================================================
L["Mythic"] = true
L["The version of this macro to use in Mythic Dungeons."] = true
L["PVP"] = true
L["Heroic"] = true
L["The version of this macro to use in heroic dungeons."] = true
L["Party"] = true
L["The version of this macro to use when in a party in the world."] = true
L["Delves and Scenarios"] = true
L["Specialisation / Class ID"] = true

-- Help text / dialog copy backfilled from locale audit 2026-06-02. These all
-- appear at runtime (Options tooltips, About panel, supporter list, OOC update
-- prompt, auto-repair chat print); they previously fell through AceLocale's
-- key-as-value fallback.
L["Auto-repaired %d sequence(s) with structurally invalid Versions (index-0 keys remapped to 1-based)."] = true
L["By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."] = true
L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."] = true
L["GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."] = true
L["GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."] = true
L["GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community."] = true
L["Pre-selected action when an imported sequence collides with one you already have. Merge appends new versions to the existing sequence; Replace overwrites it; Ignore skips the import; Rename brings the new sequence in under a different name."] = true
L["The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."] = true
L["The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."] = true
L["These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] = true
L["This is a common WoW setting used by all addons; it controls when your action buttons respond.  On: they react when you press the key (key-down).  Off: they react when you release it (key-up).  GSE now works either way -- Actionbar Overrides and keybinds fire a single step in both states.  With this on, GSE keybinds also fire on key-down for a faster response.  Changes apply immediately out of combat (or on your next rebind if toggled mid-combat)."] = true
