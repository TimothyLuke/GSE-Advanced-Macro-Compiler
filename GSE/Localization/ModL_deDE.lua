if GetLocale() ~= "deDE" then
    return
end

local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "deDE", false)

-- Options translation
--[[Translation missing --]]
L["  The Alternative ClassID is "] = "  The Alternative ClassID is "
--[[Translation missing --]]
L[" Deleted Orphaned Macro "] = " Deleted Orphaned Macro "
--[[Translation missing --]]
L[" from "] = " from "
--[[Translation missing --]]
L[" macros per Account.  You currently have "] = " macros per Account.  You currently have "
--[[Translation missing --]]
L[" macros per character.  You currently have "] = " macros per character.  You currently have "
--[[Translation missing --]]
L[" sent"] = " sent"
--[[Translation missing --]]
L[" was imported as a new macro."] = " was imported as a new macro."
L[" was imported."] = " wurde importiert."
--[[Translation missing --]]
L[" was updated to new version."] = " was updated to new version."
--[[Translation missing --]]
L["%d corrupt sequence(s) found â showing resolution options."] = "%d corrupt sequence(s) found â showing resolution options."
--[[Translation missing --]]
L["%d issue(s) found.  See above for details and fix commands."] = "%d issue(s) found.  See above for details and fix commands."
--[[Translation missing --]]
L["%s embeds sequence '%s' — add it to the export if needed."] = "%s embeds sequence '%s' — add it to the export if needed."
--[[Translation missing --]]
L["'%s' has been repaired and queued for recompile.  Leave combat or /reload to apply."] = "'%s' has been repaired and queued for recompile.  Leave combat or /reload to apply."
--[[Translation missing --]]
L["%s macro may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this macro."] = "%s macro may cause a 'RestrictedExecution.lua:431' error as it has %s actions when compiled.  This get interesting when you go past 255 actions.  You may need to simplify this macro."
--[[Translation missing --]]
L["'%s' repaired. Sequence is for class %d; button will update when that class is played."] = "'%s' repaired. Sequence is for class %d; button will update when that class is played."
L["%s/255 Characters Used"] = "%s/255 Zeichen verwendet"
--[[Translation missing --]]
L["/gse checksequencesforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."] = "/gse checksequencesforerrors|r will loop through your macros and check for corrupt macro versions.  This will then show how to correct these issues."
--[[Translation missing --]]
L["/gse cleanorphans|r will loop through your macros and delete any left over GSE macros that no longer have a sequence to match them."] = "/gse cleanorphans|r will loop through your macros and delete any left over GSE macros that no longer have a sequence to match them."
--[[Translation missing --]]
L["/gse help|r to get started."] = "/gse help|r to get started."
--[[Translation missing --]]
L["/gse|r again."] = "/gse|r again."
--[[Translation missing --]]
L["/gse|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."] = "/gse|r will list any macros available to your spec.  This will also add any macros available for your current spec to the macro interface."
--[[Translation missing --]]
L["|r.  You can also have a  maximum of "] = "|r.  You can also have a  maximum of "
--[[Translation missing --]]
L["<DEBUG> |r "] = "<DEBUG> |r "
--[[Translation missing --]]
L["<SEQUENCEDEBUG> |r "] = "<SEQUENCEDEBUG> |r "
--[[Translation missing --]]
L[ [=[A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.
If using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box.]=] ] = [=[A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.
If using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box.]=]
--[[Translation missing --]]
L["A UI reload is required for the MultiClickButtons change to take effect.  Type /reload when convenient."] = "A UI reload is required for the MultiClickButtons change to take effect.  Type /reload when convenient."
--[[Translation missing --]]
L["About"] = "About"
--[[Translation missing --]]
L["About GSE"] = "About GSE"
L["Account Macros"] = "Account Makros"
L["Action Type"] = "Aktionstyp"
--[[Translation missing --]]
L["Actionbar Buttons"] = "Actionbar Buttons"
--[[Translation missing --]]
L["Actionbar Overrides"] = "Actionbar Overrides"
--[[Translation missing --]]
L["Actionbar Overrides: The following CVars were automatically set to false as they interfere with Actionbar Overrides: "] = "Actionbar Overrides: The following CVars were automatically set to false as they interfere with Actionbar Overrides: "
--[[Translation missing --]]
L["ActionButtonUseKeyDown"] = "ActionButtonUseKeyDown"
--[[Translation missing --]]
L["Actions"] = "Actions"
--[[Translation missing --]]
L["Add a Loop Block."] = "Add a Loop Block."
--[[Translation missing --]]
L["Add a Pause Block."] = "Add a Pause Block."
--[[Translation missing --]]
L["Add Action"] = "Add Action"
--[[Translation missing --]]
L["Add an Action Block."] = "Add an Action Block."
--[[Translation missing --]]
L["Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."] = "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
--[[Translation missing --]]
L["Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."] = "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
--[[Translation missing --]]
L["Add Embed"] = "Add Embed"
--[[Translation missing --]]
L["Add from List"] = "Add from List"
--[[Translation missing --]]
L["Add If"] = "Add If"
--[[Translation missing --]]
L["Add Loop"] = "Add Loop"
--[[Translation missing --]]
L["Add Pause"] = "Add Pause"
--[[Translation missing --]]
L["Addin Version %s contained versions for the following sequences:"] = "Addin Version %s contained versions for the following sequences:"
L["Advanced Export"] = "Erweiterter Export"
--[[Translation missing --]]
L["Advanced Macro Compiler loaded.|r  Type "] = "Advanced Macro Compiler loaded.|r  Type "
L["All Talent Loadouts"] = "Alle Talent Ausrüstungen"
L["Already Known"] = "Bereits bekannt"
--[[Translation missing --]]
L["Alt Keys."] = "Alt Keys."
--[[Translation missing --]]
L["Any Alt Key"] = "Any Alt Key"
--[[Translation missing --]]
L["Any Control Key"] = "Any Control Key"
--[[Translation missing --]]
L["Any Shift Key"] = "Any Shift Key"
--[[Translation missing --]]
L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."] = "Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."
--[[Translation missing --]]
L["Arena"] = "Arena"
--[[Translation missing --]]
L["Arena setting changed to Default."] = "Arena setting changed to Default."
--[[Translation missing --]]
L["As GSE is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gse cleanorphans"] = "As GSE is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gse cleanorphans"
--[[Translation missing --]]
L["Assign GSE Sequence"] = "Assign GSE Sequence"
--[[Translation missing --]]
L["Author"] = "Author"
--[[Translation missing --]]
L["Auto-included %d variable(s) required by %s: %s"] = "Auto-included %d variable(s) required by %s: %s"
--[[Translation missing --]]
L["Block Path"] = "Block Path"
--[[Translation missing --]]
L["Block Type: %s"] = "Block Type: %s"
--[[Translation missing --]]
L["Bracket Operators"] = "Bracket Operators"
--[[Translation missing --]]
L["Button Settings"] = "Button Settings"
--[[Translation missing --]]
L["Button State"] = "Button State"
--[[Translation missing --]]
L["By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."] = "By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."
--[[Translation missing --]]
L["By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."] = "By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."
--[[Translation missing --]]
L["Cancel"] = "Cancel"
--[[Translation missing --]]
L["Change"] = "Change"
--[[Translation missing --]]
L["Change Sequence"] = "Change Sequence"
L["Changes Left Side, Changes Right Side, Many Changes!!!! Handle It!"] = "Änderungen auf der linken Seite, Änderungen auf der rechten Seite, viele Änderungen!!!! Komm damit klar!"
--[[Translation missing --]]
L["Character"] = "Character"
L["Character Macros"] = "Charakter Makros"
L["Chat Link"] = "Chat Link"
--[[Translation missing --]]
L["Checks to see if you have a Heart of Azeroth equipped and if so will insert '/cast Heart Essence' into the macro.  If not your macro will skip this line."] = "Checks to see if you have a Heart of Azeroth equipped and if so will insert '/cast Heart Essence' into the macro.  If not your macro will skip this line."
--[[Translation missing --]]
L["Checksum invalid - sequence may have been modified"] = "Checksum invalid - sequence may have been modified"
--[[Translation missing --]]
L["Checksum valid"] = "Checksum valid"
--[[Translation missing --]]
L["Choose import action:"] = "Choose import action:"
--[[Translation missing --]]
L["Clear"] = "Clear"
--[[Translation missing --]]
L["Clear Override"] = "Clear Override"
--[[Translation missing --]]
L["Clear Spell Cache"] = "Clear Spell Cache"
--[[Translation missing --]]
L["Cleared %d pending queue entries for '%s'."] = "Cleared %d pending queue entries for '%s'."
--[[Translation missing --]]
L["Click to open the colour picker for GSE text and editor colours."] = "Click to open the colour picker for GSE text and editor colours."
--[[Translation missing --]]
L["Clicks"] = "Clicks"
--[[Translation missing --]]
L["Close"] = "Close"
--[[Translation missing --]]
L["Close to Maximum Macros.|r  You can have a maximum of "] = "Close to Maximum Macros.|r  You can have a maximum of "
--[[Translation missing --]]
L["Close to Maximum Personal Macros.|r  You can have a maximum of "] = "Close to Maximum Personal Macros.|r  You can have a maximum of "
--[[Translation missing --]]
L["Colour"] = "Colour"
--[[Translation missing --]]
L["Colour and Accessibility Options"] = "Colour and Accessibility Options"
--[[Translation missing --]]
L["Combat"] = "Combat"
L["Command Colour"] = "Befehlsfarbe"
--[[Translation missing --]]
L["Common Solutions to game quirks that seem to affect some people."] = "Common Solutions to game quirks that seem to affect some people."
--[[Translation missing --]]
L["Compatible with this version of GSE"] = "Compatible with this version of GSE"
--[[Translation missing --]]
L["Compile"] = "Compile"
--[[Translation missing --]]
L["Compile error in Macros[%d] of '%s': %s"] = "Compile error in Macros[%d] of '%s': %s"
--[[Translation missing --]]
L["Compiled"] = "Compiled"
L["Compiled Macro"] = "Kompiliertes Makro"
--[[Translation missing --]]
L["Compiled Template"] = "Compiled Template"
--[[Translation missing --]]
L["Compress"] = "Compress"
--[[Translation missing --]]
L["Compress Sequence from Forums"] = "Compress Sequence from Forums"
--[[Translation missing --]]
L["Conditionals & Comments"] = "Conditionals & Comments"
--[[Translation missing --]]
L["Configuration"] = "Configuration"
--[[Translation missing --]]
L["Continue"] = "Continue"
--[[Translation missing --]]
L["Control Keys."] = "Control Keys."
--[[Translation missing --]]
L["Copy this link and open it in a Browser."] = "Copy this link and open it in a Browser."
--[[Translation missing --]]
L["Copy this link and paste it into a chat window."] = "Copy this link and paste it into a chat window."
--[[Translation missing --]]
L["Corrupt sequence '%s' (class %d) deleted."] = "Corrupt sequence '%s' (class %d) deleted."
--[[Translation missing --]]
L["Create"] = "Create"
L["Create a new macro in the /macro interface and assign it an Icon. Then reopen this menu.  You cannot create a new macro here but after it has been created you can manage it."] = "Erstelle ein neues Makro in der /macro-Oberfläche und weisen Sie ihm ein Symbol zu. Öffne anschließend dieses Menü erneut. Du kannst hier kein neues Makro erstellen, aber nachdem es erstellt wurde, können Sie es verwalten."
--[[Translation missing --]]
L["Create Human Readable Export"] = "Create Human Readable Export"
L["Create Human Readable Exports"] = "Erstelle menschenlesbare Exporte"
--[[Translation missing --]]
L["Create Macro"] = "Create Macro"
--[[Translation missing --]]
L["Current GCD"] = "Current GCD"
L["Current Value"] = "Aktueller Wert"
--[[Translation missing --]]
L["CVar Settings"] = "CVar Settings"
--[[Translation missing --]]
L["Debug"] = "Debug"
--[[Translation missing --]]
L["Debug Mode Options"] = "Debug Mode Options"
--[[Translation missing --]]
L["Debug Output Options"] = "Debug Output Options"
--[[Translation missing --]]
L["Decompress"] = "Decompress"
--[[Translation missing --]]
L["Default"] = "Default"
--[[Translation missing --]]
L["Default Debugger Height"] = "Default Debugger Height"
--[[Translation missing --]]
L["Default Debugger Width"] = "Default Debugger Width"
--[[Translation missing --]]
L["Default Editor Height"] = "Default Editor Height"
--[[Translation missing --]]
L["Default Editor Width"] = "Default Editor Width"
--[[Translation missing --]]
L["Default is 64 pixels."] = "Default is 64 pixels."
--[[Translation missing --]]
L["Default Tree Panel Width"] = "Default Tree Panel Width"
--[[Translation missing --]]
L["Default Version"] = "Default Version"
--[[Translation missing --]]
L["Delete"] = "Delete"
--[[Translation missing --]]
L["Delete Block"] = "Delete Block"
--[[Translation missing --]]
L[ [=[Delete this Block from the sequence.  
WARNING: If this is a loop this will delete all the blocks inside the loop as well.]=] ] = [=[Delete this Block from the sequence.  
WARNING: If this is a loop this will delete all the blocks inside the loop as well.]=]
--[[Translation missing --]]
L["Delete this macro.  This is not able to be undone."] = "Delete this macro.  This is not able to be undone."
--[[Translation missing --]]
L["Delete this variable from the sequence."] = "Delete this variable from the sequence."
--[[Translation missing --]]
L[ [=[Delete this version of the macro.  This can be undone by closing this window and not saving the change.  
This is different to the Delete button below which will delete this entire macro.]=] ] = [=[Delete this version of the macro.  This can be undone by closing this window and not saving the change.  
This is different to the Delete button below which will delete this entire macro.]=]
--[[Translation missing --]]
L["Delete Variable"] = "Delete Variable"
--[[Translation missing --]]
L["Delete Version"] = "Delete Version"
--[[Translation missing --]]
L["Dependencies"] = "Dependencies"
--[[Translation missing --]]
L["Direction the menu grows from the logo button."] = "Direction the menu grows from the logo button."
--[[Translation missing --]]
L["Disable"] = "Disable"
--[[Translation missing --]]
L["Disable Block"] = "Disable Block"
L["Disable Sequence"] = "Sequenz ausschalten"
--[[Translation missing --]]
L["Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."] = "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
--[[Translation missing --]]
L["Display debug messages in Chat Window"] = "Display debug messages in Chat Window"
L["Do not compile this Sequence at startup."] = "Kompilieren Sie diese Sequenz nicht beim Start."
--[[Translation missing --]]
L["Down"] = "Down"
--[[Translation missing --]]
L["Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."] = "Drag this icon to your action bar to use this macro. You can change this icon in the /macro window."
--[[Translation missing --]]
L["Dragonflight has changed how the /click command operates.  As a result all your macro stubs (found in /macro) have been updated to match the value of the CVar ActionButtonUseKeyDown.  This is a one off configuration change that needs to be done for each character.  You can change this configuration in GSE's Options."] = "Dragonflight has changed how the /click command operates.  As a result all your macro stubs (found in /macro) have been updated to match the value of the CVar ActionButtonUseKeyDown.  This is a one off configuration change that needs to be done for each character.  You can change this configuration in GSE's Options."
--[[Translation missing --]]
L["Dungeon"] = "Dungeon"
--[[Translation missing --]]
L["Dungeon setting changed to Default."] = "Dungeon setting changed to Default."
--[[Translation missing --]]
L["Edit"] = "Edit"
--[[Translation missing --]]
L["Edit Spell Cache"] = "Edit Spell Cache"
--[[Translation missing --]]
L["Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."] = "Edit this macro directly in Lua. WARNING: This may render the macro unable to operate and can crash your Game Session."
--[[Translation missing --]]
L["Editor Colours"] = "Editor Colours"
--[[Translation missing --]]
L["Embedded by:"] = "Embedded by:"
--[[Translation missing --]]
L["Embeds Sequences:"] = "Embeds Sequences:"
--[[Translation missing --]]
L["Emphasis Colour"] = "Emphasis Colour"
--[[Translation missing --]]
L["Enable"] = "Enable"
--[[Translation missing --]]
L["Enable Actionbar Override Popup"] = "Enable Actionbar Override Popup"
--[[Translation missing --]]
L["Enable Debug for the following Modules"] = "Enable Debug for the following Modules"
L["Enable Mod Debug Mode"] = "Mod-Debug-Modus einschalten"
--[[Translation missing --]]
L["Enter a name for the new sequence:"] = "Enter a name for the new sequence:"
--[[Translation missing --]]
L["Enter a name for the new variable:"] = "Enter a name for the new variable:"
L["Enter the implementation link for this variable. Use '= true' or '= false' to test."] = "Gebe den Implementierungslink für diese Variable ein. Verwende zum Testen „= true“ oder „= false“."
--[[Translation missing --]]
L["Error processing Custom Pause Value.  You will need to recheck your macros."] = "Error processing Custom Pause Value.  You will need to recheck your macros."
--[[Translation missing --]]
L["Error: Destination path not found."] = "Error: Destination path not found."
--[[Translation missing --]]
L["Error: Source path not found."] = "Error: Source path not found."
--[[Translation missing --]]
L["Error: You cannot move a container to be a child within itself."] = "Error: You cannot move a container to be a child within itself."
--[[Translation missing --]]
L["Execute on Event"] = "Execute on Event"
--[[Translation missing --]]
L["Export"] = "Export"
--[[Translation missing --]]
L["Export a Sequence"] = "Export a Sequence"
L["Export Variable"] = "Variable exportieren"
--[[Translation missing --]]
L["Extra Macro Versions of %s has been added."] = "Extra Macro Versions of %s has been added."
--[[Translation missing --]]
L["Filter Sequence Selection"] = "Filter Sequence Selection"
--[[Translation missing --]]
L["Finished scanning for errors.  If no other messages then no errors were found."] = "Finished scanning for errors.  If no other messages then no errors were found."
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["General Options"] = "General Options"
--[[Translation missing --]]
L["Global"] = "Global"
L["Gnome Sequencer Enhanced"] = "Gnome Sequencer Enhanced"
--[[Translation missing --]]
L["Gnome Sequencer: Compress a Sequence String."] = "Gnome Sequencer: Compress a Sequence String."
--[[Translation missing --]]
L["Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"] = "Gnome Sequencer: Sequence Debugger. Monitor the Execution of your Macro"
--[[Translation missing --]]
L["GnomeSequencer was originally written by semlar of wowinterface.com."] = "GnomeSequencer was originally written by semlar of wowinterface.com."
--[[Translation missing --]]
L["Growth Direction"] = "Growth Direction"
--[[Translation missing --]]
L["GSE"] = "GSE"
--[[Translation missing --]]
L["GSE - %s's Macros"] = "GSE - %s's Macros"
--[[Translation missing --]]
L["GSE Collection to Import."] = "GSE Collection to Import."
L["GSE Discord"] = "GSE Discord"
--[[Translation missing --]]
L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."] = "GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."
L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."] = "GSE hat einen LibDataBroker (LDB) Datenfeed. Setze diese Option, um in der Warteschlange befindliche \"Out of Combat\"-Ereignisse im Tooltip anzuzeigen."
--[[Translation missing --]]
L["GSE Import Successful."] = "GSE Import Successful."
--[[Translation missing --]]
L["GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."] = "GSE is a complete rewrite of that addon that allows you create a sequence of macros to be executed at the push of a button."
--[[Translation missing --]]
L["GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."] = "GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."
--[[Translation missing --]]
L["GSE Macro Stubs have been reset to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)"] = "GSE Macro Stubs have been reset to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)"
--[[Translation missing --]]
L["GSE Plugins"] = "GSE Plugins"
--[[Translation missing --]]
L["GSE Sequence"] = "GSE Sequence"
--[[Translation missing --]]
L[ [=[GSE Sequences are converted to a button that responds to 'Clicks' or Keyboard keypresses (WoW calls these Hardware Events).  

When you use a KeyBind with a sequence, WoW sends two hardware events each time. With this setting on, GSE then interprets these two clicks as one and advances your sequence one step.  With this off it would advance two steps.  

In comparison Actionbar Overrides and '/click SEQUENCE' macros only sends one hardware Event.  If you primarily use Keybinds over Actionbar Overrides over Keybinds you want this set to false.]=] ] = [=[GSE Sequences are converted to a button that responds to 'Clicks' or Keyboard keypresses (WoW calls these Hardware Events).  

When you use a KeyBind with a sequence, WoW sends two hardware events each time. With this setting on, GSE then interprets these two clicks as one and advances your sequence one step.  With this off it would advance two steps.  

In comparison Actionbar Overrides and '/click SEQUENCE' macros only sends one hardware Event.  If you primarily use Keybinds over Actionbar Overrides over Keybinds you want this set to false.]=]
--[[Translation missing --]]
L["GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."] = "GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."
--[[Translation missing --]]
L["GSE Users"] = "GSE Users"
--[[Translation missing --]]
L["GSE Version: %s"] = "GSE Version: %s"
--[[Translation missing --]]
L[ [=[GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.

GSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community.]=] ] = [=[GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.

GSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community.]=]
L["GSE: Export"] = "GSE: Exportieren"
--[[Translation missing --]]
L["GSE: Import a Macro String."] = "GSE: Import a Macro String."
--[[Translation missing --]]
L["GSE: Left Click to open the Sequence Editor"] = "GSE: Left Click to open the Sequence Editor"
--[[Translation missing --]]
L["GSE: Middle Click to open the Keybinding Interface"] = "GSE: Middle Click to open the Keybinding Interface"
L["GSE: Record your rotation to a macro."] = "GSE: Zeichne Deine Rotation in einem Makro auf."
--[[Translation missing --]]
L["GSE: Right Click to open the Sequence Debugger"] = "GSE: Right Click to open the Sequence Debugger"
L["GSE: Whats New in "] = "GSE: Was ist neu in"
--[[Translation missing --]]
L["GSE_CORRUPT_SEQUENCE_TEXT"] = [=[The sequence '%s' (class %d) could not be read and may be corrupt.

Delete it to remove the broken data, or Skip to leave it for now.
You can reimport the sequence from its original source to recover it.]=]
--[[Translation missing --]]
L["GSE_SEQUENCE_INTEGRITY_WARNING_TEXT"] = [=[WARNING: The sequence '%s' does not have a valid integrity checksum.

This means the sequence was either not created with GSE, or has been modified since it was last exported.

Please verify its contents before using it.

Do you want to proceed with the import anyway?]=]
--[[Translation missing --]]
L["GSE_SEQUENCE_OLDER_VERSION_TEXT"] = [=[WARNING: The sequence '%s' was created with an older version of GSE (%s).

It may need adjustments before it works correctly.

Do you want to proceed with the import anyway?]=]
--[[Translation missing --]]
L["GSE2 Retro interface loaded.  Type `%s/gse2 import%s` to import an old GSE2 string or `%s/gse2 edit%s` to mock up a new template using the GSE2 editor."] = "GSE2 Retro interface loaded.  Type `%s/gse2 import%s` to import an old GSE2 string or `%s/gse2 edit%s` to mock up a new template using the GSE2 editor."
--[[Translation missing --]]
L["Help Information"] = "Help Information"
--[[Translation missing --]]
L["Help Link"] = "Help Link"
--[[Translation missing --]]
L["Heroic"] = "Heroic"
--[[Translation missing --]]
L["Heroic setting changed to Default."] = "Heroic setting changed to Default."
--[[Translation missing --]]
L["Hide Login Message"] = "Hide Login Message"
--[[Translation missing --]]
L["Hide Minimap Icon"] = "Hide Minimap Icon"
--[[Translation missing --]]
L["Hide Minimap Icon for LibDataBroker (LDB) data text."] = "Hide Minimap Icon for LibDataBroker (LDB) data text."
--[[Translation missing --]]
L["Hides the message that GSE is loaded."] = "Hides the message that GSE is loaded."
--[[Translation missing --]]
L["History"] = "History"
--[[Translation missing --]]
L["Horizontal Layout"] = "Horizontal Layout"
--[[Translation missing --]]
L["How many macro Clicks to pause for?"] = "How many macro Clicks to pause for?"
--[[Translation missing --]]
L["How many milliseconds to pause for?"] = "How many milliseconds to pause for?"
--[[Translation missing --]]
L["How many pixels high should the Debuger start at.  Defaults to 500"] = "How many pixels high should the Debuger start at.  Defaults to 500"
--[[Translation missing --]]
L["How many pixels high should the Editor start at.  Defaults to 700"] = "How many pixels high should the Editor start at.  Defaults to 700"
--[[Translation missing --]]
L["How many pixels wide should the Debugger start at.  Defaults to 700"] = "How many pixels wide should the Debugger start at.  Defaults to 700"
--[[Translation missing --]]
L["How many pixels wide should the Editor start at.  Defaults to 700"] = "How many pixels wide should the Editor start at.  Defaults to 700"
--[[Translation missing --]]
L["How many pixels wide should the sequence list panel on the left of the Editor be.  Defaults to 150"] = "How many pixels wide should the sequence list panel on the left of the Editor be.  Defaults to 150"
L["How many times does this action repeat"] = "Wie oft wird diese Aktion wiederholt?"
--[[Translation missing --]]
L["Icon Preview Orientation: Horizontal"] = "Icon Preview Orientation: Horizontal"
--[[Translation missing --]]
L["Icon Preview Orientation: Vertical"] = "Icon Preview Orientation: Vertical"
--[[Translation missing --]]
L["If Blocks require a variable that returns either true or false.  Create the variable first."] = "If Blocks require a variable that returns either true or false.  Create the variable first."
--[[Translation missing --]]
L["If Blocks Require a variable."] = "If Blocks Require a variable."
--[[Translation missing --]]
L["Ignore"] = "Ignore"
L["Implementation Link"] = "Implementierungslink"
--[[Translation missing --]]
L["Import"] = "Import"
L["Import Macro from Forums"] = "Makros aus dem Forum importieren"
--[[Translation missing --]]
L["Import String Not Recognised."] = "Import String Not Recognised."
--[[Translation missing --]]
L["Individual Sequences - %s"] = "Individual Sequences - %s"
--[[Translation missing --]]
L["Info Colour"] = "Info Colour"
L["Insert GSE Sequence"] = "GSE-Sequenz einfügen"
L["Insert GSE Variable"] = "GSE-Variable einfügen"
L["Insert Spell"] = "Zauber einfügen"
L["Insert Test Case"] = "Testfall einfügen"
--[[Translation missing --]]
L["Invalid class library ID: %s"] = "Invalid class library ID: %s"
--[[Translation missing --]]
L["Issues found in '%s' (class library %d):"] = "Issues found in '%s' (class library %d):"
L["Item"] = "Gegenstand"
L["Keybind"] = "Tastenbelegung"
--[[Translation missing --]]
L["Keybinding Tools"] = "Keybinding Tools"
L["Keybindings"] = "Tastenbelegungen"
L["Last Updated"] = "Zuletzt aktualisiert"
--[[Translation missing --]]
L["Left"] = "Left"
--[[Translation missing --]]
L["Left Alt Key"] = "Left Alt Key"
--[[Translation missing --]]
L["Left Control Key"] = "Left Control Key"
L["Left Mouse Button"] = "Linke Maustaste"
--[[Translation missing --]]
L["Left Shift Key"] = "Left Shift Key"
--[[Translation missing --]]
L["Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."] = "Like a /castsequence macro, it cycles through a series of commands when the button is pushed. However, unlike castsequence, it uses macro text for the commands instead of spells, and it advances every time the button is pushed instead of stopping when it can't cast something."
--[[Translation missing --]]
L["Load Sequence"] = "Load Sequence"
--[[Translation missing --]]
L["Local Function: "] = "Local Function: "
--[[Translation missing --]]
L["Local Macro"] = "Local Macro"
--[[Translation missing --]]
L["Lock Menu Position"] = "Lock Menu Position"
--[[Translation missing --]]
L["Lock Position"] = "Lock Position"
--[[Translation missing --]]
L["Logic & Comparison"] = "Logic & Comparison"
L["Macro"] = "Makro"
--[[Translation missing --]]
L["Macro Compile Error"] = "Macro Compile Error"
--[[Translation missing --]]
L["Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."] = "Macro found by the name %sPVP%s. Rename this macro to a different name to be able to use it.  WOW has a global object called PVP that is referenced instead of this macro."
--[[Translation missing --]]
L["Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."] = "Macro found by the name %sWW%s. Rename this macro to a different name to be able to use it.  WOW has a hidden button called WW that is executed instead of this macro."
--[[Translation missing --]]
L["Macro Icon"] = "Macro Icon"
L["Macro Name"] = "Makroname"
L["Macro Name or Macro Commands"] = "Makroname oder Makrobefehle"
L["Macro Template"] = "Makro Vorlage"
--[[Translation missing --]]
L["Macro Version %d deleted."] = "Macro Version %d deleted."
L["Macros"] = "Makros"
--[[Translation missing --]]
L["Macros array has gaps: %d version(s) reachable of %d total (max index %d)"] = "Macros array has gaps: %d version(s) reachable of %d total (max index %d)"
--[[Translation missing --]]
L["Macros array is empty (no versions defined)"] = "Macros array is empty (no versions defined)"
--[[Translation missing --]]
L["Macros[%d] is not a table"] = "Macros[%d] is not a table"
--[[Translation missing --]]
L["Macros[%d].Actions has gaps: %d reachable of %d total (max index %d)"] = "Macros[%d].Actions has gaps: %d reachable of %d total (max index %d)"
--[[Translation missing --]]
L["Macros[%d].Actions is missing or not a table"] = "Macros[%d].Actions is missing or not a table"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] (Embed) is missing the Sequence field"] = "Macros[%d].Actions[%d] (Embed) is missing the Sequence field"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] (If) is missing the Variable field"] = "Macros[%d].Actions[%d] (If) is missing the Variable field"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] (Pause) has neither Clicks nor MS"] = "Macros[%d].Actions[%d] (Pause) has neither Clicks nor MS"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] has unrecognized Type: '%s'"] = "Macros[%d].Actions[%d] has unrecognized Type: '%s'"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] is missing Type field"] = "Macros[%d].Actions[%d] is missing Type field"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] macro text exceeds 255 characters (%d chars)"] = "Macros[%d].Actions[%d] macro text exceeds 255 characters (%d chars)"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] macro text has unbalanced brackets (%d '[' vs %d ']')"] = "Macros[%d].Actions[%d] macro text has unbalanced brackets (%d '[' vs %d ']')"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] uses // comments instead of --; GSE will not strip these on compile"] = "Macros[%d].Actions[%d] uses // comments instead of --; GSE will not strip these on compile"
--[[Translation missing --]]
L["Macros[%d].Actions[%d] uses unrecognized slash command: /%s"] = "Macros[%d].Actions[%d] uses unrecognized slash command: /%s"
L["Manage Macro with GSE"] = "Makros mit GSE verwalten"
L["Manage Variables"] = "Variablen verwalten"
--[[Translation missing --]]
L["Measure"] = "Measure"
--[[Translation missing --]]
L["Menu"] = "Menu"
--[[Translation missing --]]
L["Menu Options"] = "Menu Options"
--[[Translation missing --]]
L["Merge"] = "Merge"
--[[Translation missing --]]
L["MetaData.%s = %d references a non-existent Macros version (max valid index: %d)"] = "MetaData.%s = %d references a non-existent Macros version (max valid index: %d)"
--[[Translation missing --]]
L["MetaData.%s remapped from non-existent version %d to %d."] = "MetaData.%s remapped from non-existent version %d to %d."
--[[Translation missing --]]
L["MetaData.SpecID is missing"] = "MetaData.SpecID is missing"
--[[Translation missing --]]
L["Middle Mouse Button"] = "Middle Mouse Button"
--[[Translation missing --]]
L["Milliseconds"] = "Milliseconds"
--[[Translation missing --]]
L["Missing MetaData table"] = "Missing MetaData table"
--[[Translation missing --]]
L["Missing or invalid Macros table"] = "Missing or invalid Macros table"
--[[Translation missing --]]
L["Missing Variable "] = "Missing Variable "
--[[Translation missing --]]
L["modified in other window.  This view is now behind the current sequence."] = "modified in other window.  This view is now behind the current sequence."
--[[Translation missing --]]
L["Modifiers & Functions"] = "Modifiers & Functions"
--[[Translation missing --]]
L["Mouse Button 4"] = "Mouse Button 4"
--[[Translation missing --]]
L["Mouse Button 5"] = "Mouse Button 5"
--[[Translation missing --]]
L["Mouse Buttons."] = "Mouse Buttons."
--[[Translation missing --]]
L["Move Down"] = "Move Down"
--[[Translation missing --]]
L["Move this block down one block."] = "Move this block down one block."
--[[Translation missing --]]
L["Move this block up one block."] = "Move this block up one block."
--[[Translation missing --]]
L["Move Up"] = "Move Up"
--[[Translation missing --]]
L["Moved %s to class %s."] = "Moved %s to class %s."
--[[Translation missing --]]
L["MS Click Rate"] = "MS Click Rate"
--[[Translation missing --]]
L["Mythic"] = "Mythic"
--[[Translation missing --]]
L["Mythic setting changed to Default."] = "Mythic setting changed to Default."
--[[Translation missing --]]
L["Mythic+"] = "Mythic+"
--[[Translation missing --]]
L["Mythic+ setting changed to Default."] = "Mythic+ setting changed to Default."
--[[Translation missing --]]
L["Name"] = "Name"
--[[Translation missing --]]
L["New"] = "New"
--[[Translation missing --]]
L["New Actionbar Override"] = "New Actionbar Override"
--[[Translation missing --]]
L["New KeyBind"] = "New KeyBind"
--[[Translation missing --]]
L["New Sequence"] = "New Sequence"
--[[Translation missing --]]
L["New Sequence Name"] = "New Sequence Name"
--[[Translation missing --]]
L["New Variable"] = "New Variable"
--[[Translation missing --]]
L["No"] = "No"
--[[Translation missing --]]
L["No changes were made to "] = "No changes were made to "
--[[Translation missing --]]
L["No checksum"] = "No checksum"
--[[Translation missing --]]
L["No Help Information "] = "No Help Information "
--[[Translation missing --]]
L["No plugins are currently registered."] = "No plugins are currently registered."
--[[Translation missing --]]
L["Normal Colour"] = "Normal Colour"
--[[Translation missing --]]
L["Not compatible with this version of GSE (sequence version: %s)"] = "Not compatible with this version of GSE (sequence version: %s)"
L["Not Yet Active"] = "Noch nicht aktiv"
--[[Translation missing --]]
L["Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."] = "Notes and help on how this macro works.  What things to remember.  This information is shown in the sequence browser."
--[[Translation missing --]]
L["Numbers & Operators"] = "Numbers & Operators"
--[[Translation missing --]]
L["OOC Queue Delay"] = "OOC Queue Delay"
--[[Translation missing --]]
L["Open %s in New Window"] = "Open %s in New Window"
--[[Translation missing --]]
L["Open Colour Settings"] = "Open Colour Settings"
--[[Translation missing --]]
L["Opens the GSE Options window"] = "Opens the GSE Options window"
--[[Translation missing --]]
L["Options"] = "Options"
--[[Translation missing --]]
L["Options have been reset to defaults."] = "Options have been reset to defaults."
--[[Translation missing --]]
L["Options Not Enabled"] = "Options Not Enabled"
--[[Translation missing --]]
L["Output"] = "Output"
--[[Translation missing --]]
L["Override bindings for Skyriding, Vehicle, Possess and Override Bars"] = "Override bindings for Skyriding, Vehicle, Possess and Override Bars"
L["Party"] = "Party"
--[[Translation missing --]]
L["Party setting changed to Default."] = "Party setting changed to Default."
--[[Translation missing --]]
L["Pause"] = "Pause"
--[[Translation missing --]]
L["Pause for the GCD."] = "Pause for the GCD."
--[[Translation missing --]]
L["Paused"] = "Paused"
--[[Translation missing --]]
L["Paused - In Combat"] = "Paused - In Combat"
L["Pet"] = "Begleiter"
L["Pet Ability"] = "Begleiter Fähigkeit"
--[[Translation missing --]]
L["Picks a Custom Colour for array bracket operators [ ]."] = "Picks a Custom Colour for array bracket operators [ ]."
--[[Translation missing --]]
L["Picks a Custom Colour for conditional modifiers and standard functions."] = "Picks a Custom Colour for conditional modifiers and standard functions."
--[[Translation missing --]]
L["Picks a Custom Colour for emphasis."] = "Picks a Custom Colour for emphasis."
--[[Translation missing --]]
L["Picks a Custom Colour for informational and debug output."] = "Picks a Custom Colour for informational and debug output."
--[[Translation missing --]]
L["Picks a Custom Colour for logic and comparison operators such as == and or."] = "Picks a Custom Colour for logic and comparison operators such as == and or."
--[[Translation missing --]]
L["Picks a Custom Colour for macro conditionals eg [mod:shift] and comments."] = "Picks a Custom Colour for macro conditionals eg [mod:shift] and comments."
--[[Translation missing --]]
L["Picks a Custom Colour for numbers and arithmetic operators."] = "Picks a Custom Colour for numbers and arithmetic operators."
--[[Translation missing --]]
L["Picks a Custom Colour for spell names and action block type labels."] = "Picks a Custom Colour for spell names and action block type labels."
--[[Translation missing --]]
L["Picks a Custom Colour for table operators such as { } and ..."] = "Picks a Custom Colour for table operators such as { } and ..."
--[[Translation missing --]]
L["Picks a Custom Colour for the Commands."] = "Picks a Custom Colour for the Commands."
--[[Translation missing --]]
L["Picks a Custom Colour for the Mod Names."] = "Picks a Custom Colour for the Mod Names."
--[[Translation missing --]]
L["Picks a Custom Colour for WoW macro slash commands like /cast and /use."] = "Picks a Custom Colour for WoW macro slash commands like /cast and /use."
--[[Translation missing --]]
L["Picks a Custom Colour to be used for unknown terms."] = "Picks a Custom Colour to be used for unknown terms."
--[[Translation missing --]]
L["Picks a Custom Colour to be used normally."] = "Picks a Custom Colour to be used normally."
--[[Translation missing --]]
L["Plugins"] = "Plugins"
--[[Translation missing --]]
L["Position Locked"] = "Position Locked"
--[[Translation missing --]]
L["Press a key..."] = "Press a key..."
--[[Translation missing --]]
L["Prevent the menu from being dragged to a new position."] = "Prevent the menu from being dragged to a new position."
--[[Translation missing --]]
L["Preview Icon Size"] = "Preview Icon Size"
L["Print Active Modifiers on Click"] = "Aktive Modifikatoren per Klick drucken"
--[[Translation missing --]]
L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."] = "Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."
--[[Translation missing --]]
L["Priority List (1 12 123 1234)"] = "Priority List (1 12 123 1234)"
--[[Translation missing --]]
L["Proceed"] = "Proceed"
L["Processing Collection of %s Elements."] = "Sammlung von %s Elementen wird verarbeitet."
--[[Translation missing --]]
L["PVP"] = "PVP"
--[[Translation missing --]]
L["PVP setting changed to Default."] = "PVP setting changed to Default."
--[[Translation missing --]]
L["Raid"] = "Raid"
--[[Translation missing --]]
L["Raid setting changed to Default."] = "Raid setting changed to Default."
--[[Translation missing --]]
L["Random - It will select .... a spell, any spell"] = "Random - It will select .... a spell, any spell"
--[[Translation missing --]]
L["Raw Edit"] = "Raw Edit"
--[[Translation missing --]]
L["Raw Editor"] = "Raw Editor"
--[[Translation missing --]]
L["Ready to Send"] = "Ready to Send"
--[[Translation missing --]]
L["Received Sequence "] = "Received Sequence "
--[[Translation missing --]]
L["Record"] = "Record"
--[[Translation missing --]]
L["Record Macro"] = "Record Macro"
--[[Translation missing --]]
L["Registered Addons"] = "Registered Addons"
--[[Translation missing --]]
L["Reload"] = "Reload"
--[[Translation missing --]]
L["Reload All"] = "Reload All"
--[[Translation missing --]]
L["Removed unreadable sequence "] = "Removed unreadable sequence "
--[[Translation missing --]]
L["Rename New Macro"] = "Rename New Macro"
L["Repeat"] = "Wiederholung"
--[[Translation missing --]]
L["Replace"] = "Replace"
L["Report an Issue"] = "Ein Problem melden"
--[[Translation missing --]]
L["Request Macro"] = "Request Macro"
--[[Translation missing --]]
L["Request that the user sends you a copy of this macro."] = "Request that the user sends you a copy of this macro."
--[[Translation missing --]]
L["Requires Macros:"] = "Requires Macros:"
--[[Translation missing --]]
L["Requires Variables:"] = "Requires Variables:"
--[[Translation missing --]]
L["Reset Sequences when out of combat"] = "Reset Sequences when out of combat"
--[[Translation missing --]]
L["Reset this macro when you exit combat."] = "Reset this macro when you exit combat."
--[[Translation missing --]]
L["Resets"] = "Resets"
--[[Translation missing --]]
L["Resets sequences back to the initial state when out of combat."] = "Resets sequences back to the initial state when out of combat."
--[[Translation missing --]]
L["Restore"] = "Restore"
--[[Translation missing --]]
L["Restore a single sequence from this plugin"] = "Restore a single sequence from this plugin"
--[[Translation missing --]]
L["Restored macro '%s' required by sequence '%s'."] = "Restored macro '%s' required by sequence '%s'."
--[[Translation missing --]]
L["Resume"] = "Resume"
--[[Translation missing --]]
L["Reverse Priority (1 21 321 4321)"] = "Reverse Priority (1 21 321 4321)"
--[[Translation missing --]]
L["Right"] = "Right"
--[[Translation missing --]]
L["Right Alt Key"] = "Right Alt Key"
--[[Translation missing --]]
L["Right Control Key"] = "Right Control Key"
L["Right Mouse Button"] = "Rechte Maustaste"
--[[Translation missing --]]
L["Right Shift Key"] = "Right Shift Key"
--[[Translation missing --]]
L["Right-Click for Options"] = "Right-Click for Options"
--[[Translation missing --]]
L["Running"] = "Running"
--[[Translation missing --]]
L["Save"] = "Save"
L["Save pending for "] = "Speichern ausstehend für"
--[[Translation missing --]]
L["Save the changes made to this macro"] = "Save the changes made to this macro"
L["Save the changes made to this variable."] = "Speicher die an dieser Variable vorgenommenen Änderungen."
L["Saved"] = "Gespeichert"
--[[Translation missing --]]
L["Scanning GSE.Library for structural and content issues..."] = "Scanning GSE.Library for structural and content issues..."
--[[Translation missing --]]
L["Scenario"] = "Scenario"
--[[Translation missing --]]
L["Scenario setting changed to Default."] = "Scenario setting changed to Default."
--[[Translation missing --]]
L["Select a known WoW event or GSE message to append it to the Trigger Events box."] = "Select a known WoW event or GSE message to append it to the Trigger Events box."
--[[Translation missing --]]
L["Select a Sequence"] = "Select a Sequence"
--[[Translation missing --]]
L["Select Icon"] = "Select Icon"
--[[Translation missing --]]
L["Send"] = "Send"
--[[Translation missing --]]
L["Send this macro to another GSE player who is on the same server as you are."] = "Send this macro to another GSE player who is on the same server as you are."
--[[Translation missing --]]
L["Send To"] = "Send To"
--[[Translation missing --]]
L["Sequence"] = "Sequence"
--[[Translation missing --]]
L["Sequence '%s' (class %d) depends on macro '%s' which does not exist."] = "Sequence '%s' (class %d) depends on macro '%s' which does not exist."
--[[Translation missing --]]
L["Sequence '%s' (class %d) depends on variable '%s' which does not exist."] = "Sequence '%s' (class %d) depends on variable '%s' which does not exist."
--[[Translation missing --]]
L["Sequence '%s' (class %d) embeds sequence '%s' which does not exist."] = "Sequence '%s' (class %d) embeds sequence '%s' which does not exist."
--[[Translation missing --]]
L["Sequence '%s' (class %d) version %d block %d has no icon set (showing ?).  Open the block in the editor and assign an icon."] = "Sequence '%s' (class %d) version %d block %d has no icon set (showing ?).  Open the block in the editor and assign an icon."
--[[Translation missing --]]
L["Sequence '%s' not found in class library %d."] = "Sequence '%s' not found in class library %d."
--[[Translation missing --]]
L["Sequence Compare"] = "Sequence Compare"
--[[Translation missing --]]
L["Sequence Debugger"] = "Sequence Debugger"
--[[Translation missing --]]
L["Sequence Disabled"] = "Sequence Disabled"
--[[Translation missing --]]
L["Sequence Editor"] = "Sequence Editor"
--[[Translation missing --]]
L["Sequence has been altered from its exported state"] = "Sequence has been altered from its exported state"
--[[Translation missing --]]
L["Sequence is not a table"] = "Sequence is not a table"
--[[Translation missing --]]
L["Sequence Name"] = "Sequence Name"
--[[Translation missing --]]
L["Sequence Name %s is in Use. Please choose a different name."] = "Sequence Name %s is in Use. Please choose a different name."
--[[Translation missing --]]
L["Sequence Reset"] = "Sequence Reset"
--[[Translation missing --]]
L["Sequence to Compress."] = "Sequence to Compress."
L["Sequences"] = "Sequenzen"
--[[Translation missing --]]
L["Sequential (1 2 3 4)"] = "Sequential (1 2 3 4)"
L["Set Key to Bind"] = "Zum Binden die Taste festlegen"
--[[Translation missing --]]
L["Shift + Right-Click to copy version"] = "Shift + Right-Click to copy version"
--[[Translation missing --]]
L["Shift Keys."] = "Shift Keys."
--[[Translation missing --]]
L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."] = "Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."
--[[Translation missing --]]
L["Show Actionbar Override Watermark"] = "Show Actionbar Override Watermark"
--[[Translation missing --]]
L["Show All Sequences in Editor"] = "Show All Sequences in Editor"
--[[Translation missing --]]
L["Show Class Sequences in Editor"] = "Show Class Sequences in Editor"
--[[Translation missing --]]
L["Show Current Spells"] = "Show Current Spells"
--[[Translation missing --]]
L["Show Global Sequences in Editor"] = "Show Global Sequences in Editor"
--[[Translation missing --]]
L["Show GSE Users in LDB"] = "Show GSE Users in LDB"
L["Show next time you login."] = "Bei der nächsten Anmeldung anzeigen."
--[[Translation missing --]]
L["Show OOC Queue in LDB"] = "Show OOC Queue in LDB"
--[[Translation missing --]]
L["Show Sequence Icons"] = "Show Sequence Icons"
--[[Translation missing --]]
L["Show Sequence Modifiers"] = "Show Sequence Modifiers"
--[[Translation missing --]]
L["Show Sequence Name"] = "Show Sequence Name"
--[[Translation missing --]]
L["Show the compiled version of this macro."] = "Show the compiled version of this macro."
--[[Translation missing --]]
L["Show the GSE logo as a small watermark on actionbar override buttons."] = "Show the GSE logo as a small watermark on actionbar override buttons."
--[[Translation missing --]]
L["Show the Modifiers (eg Shift, Alt, Ctrl) and Buttons (eg Left Mousebutton) that were seen by the GSE sequence at the click/press it was triggered from."] = "Show the Modifiers (eg Shift, Alt, Ctrl) and Buttons (eg Left Mousebutton) that were seen by the GSE sequence at the click/press it was triggered from."
--[[Translation missing --]]
L["Show the Name of the Sequence"] = "Show the Name of the Sequence"
--[[Translation missing --]]
L["Show the Sequence Icon Preview Frame"] = "Show the Sequence Icon Preview Frame"
--[[Translation missing --]]
L["Skip"] = "Skip"
--[[Translation missing --]]
L["Skyriding / Vehicle Keybinds"] = "Skyriding / Vehicle Keybinds"
--[[Translation missing --]]
L["Skyriding Button"] = "Skyriding Button"
--[[Translation missing --]]
L["Slash Commands"] = "Slash Commands"
--[[Translation missing --]]
L["Specialisation / Class ID"] = "Specialisation / Class ID"
L["Spell"] = "Zauber"
--[[Translation missing --]]
L["Spell Cache Editor"] = "Spell Cache Editor"
--[[Translation missing --]]
L["Spell ID"] = "Spell ID"
--[[Translation missing --]]
L["Spell Name"] = "Spell Name"
--[[Translation missing --]]
L["Spells & Action Labels"] = "Spells & Action Labels"
--[[Translation missing --]]
L["Step Function"] = "Step Function"
--[[Translation missing --]]
L["Stop"] = "Stop"
--[[Translation missing --]]
L["Store Debug Messages"] = "Store Debug Messages"
L["Store output of debug messages in a Global Variable that can be referrenced by other mods."] = "Speichert die Ausgabe von Debug-Meldungen in einer globalen Variable, die von anderen Mods referenziert werden kann."
--[[Translation missing --]]
L["Support GSE"] = "Support GSE"
--[[Translation missing --]]
L["Supporters"] = "Supporters"
--[[Translation missing --]]
L["Table Operators"] = "Table Operators"
L["Talent Loadout"] = "Talent Ausrüstung"
L["The author of this Macro."] = "Der Autor dieses Makros."
--[[Translation missing --]]
L["The author of this macro."] = "The author of this macro."
L["The author of this Variable."] = "Der Autor dieser Variable."
--[[Translation missing --]]
L[ [=[The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.
EG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block.]=] ] = [=[The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.
EG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block.]=]
--[[Translation missing --]]
L["The command "] = "The command "
--[[Translation missing --]]
L["The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."] = "The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."
--[[Translation missing --]]
L["The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."] = "The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."
--[[Translation missing --]]
L["The GSE Out of Combat queue is %s"] = "The GSE Out of Combat queue is %s"
--[[Translation missing --]]
L["The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."] = "The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."
--[[Translation missing --]]
L["The GUI is corrupt.  Please ensure that your GSE install is complete."] = "The GUI is corrupt.  Please ensure that your GSE install is complete."
--[[Translation missing --]]
L["The GUI is missing.  Please ensure that your GSE install is complete."] = "The GUI is missing.  Please ensure that your GSE install is complete."
--[[Translation missing --]]
L["The GUI needs updating.  Please ensure that your GSE install is complete."] = "The GUI needs updating.  Please ensure that your GSE install is complete."
--[[Translation missing --]]
L["The milliseconds being used in key click delay."] = "The milliseconds being used in key click delay."
--[[Translation missing --]]
L[ [=[The name of your macro.  This name has to be unique and can only be used for one object.
You can copy this entire macro by changing the name and choosing Save.]=] ] = [=[The name of your macro.  This name has to be unique and can only be used for one object.
You can copy this entire macro by changing the name and choosing Save.]=]
--[[Translation missing --]]
L[ [=[The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  
The next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  
If Priority it will try some spells more often than others.]=] ] = [=[The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  
The next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  
If Priority it will try some spells more often than others.]=]
L["The UI has been set to KeyDown configuration.  The /click command needs to be `/click TEMPLATENAME LeftButton t` (Note the 't' here is required along with the LeftButton.)  You will need to check your macros and adjust your click commands."] = "Die Benutzeroberfläche wurde auf KeyDown-Konfiguration eingestellt. Der /click-Befehl benötigt `/click TEMPLATENAME LeftButton t` (Beachte 't' hier zusammen mit dem LeftButton erforderlich ist.) Du musst Ihre Makros überprüfen und Ihre Klickbefehle anpassen."
L["The UI has been set to KeyUp configuration.  The /click command needs to be `/click TEMPLATENAME` You will need to check your macros and adjust your click commands."] = "Die Benutzeroberfläche wurde auf KeyUp-Konfiguration eingestellt. Der /click-Befehl muss `/click TEMPLATENAME` lauten. Du musst Deine Makros überprüfen und Deine Klickbefehle anpassen."
--[[Translation missing --]]
L["The version of this macro that will be used when you enter raids."] = "The version of this macro that will be used when you enter raids."
--[[Translation missing --]]
L["The version of this macro that will be used where no other version has been configured."] = "The version of this macro that will be used where no other version has been configured."
--[[Translation missing --]]
L["The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."] = "The version of this macro to use in Arenas.  If this is not specified, GSE will look for a PVP version before the default."
--[[Translation missing --]]
L["The version of this macro to use in heroic dungeons."] = "The version of this macro to use in heroic dungeons."
--[[Translation missing --]]
L["The version of this macro to use in Mythic Dungeons."] = "The version of this macro to use in Mythic Dungeons."
--[[Translation missing --]]
L["The version of this macro to use in Mythic+ Dungeons."] = "The version of this macro to use in Mythic+ Dungeons."
--[[Translation missing --]]
L["The version of this macro to use in normal dungeons."] = "The version of this macro to use in normal dungeons."
--[[Translation missing --]]
L["The version of this macro to use in PVP."] = "The version of this macro to use in PVP."
--[[Translation missing --]]
L["The version of this macro to use in Scenarios."] = "The version of this macro to use in Scenarios."
--[[Translation missing --]]
L["The version of this macro to use when in a party in the world."] = "The version of this macro to use when in a party in the world."
--[[Translation missing --]]
L["The version of this macro to use when in time walking dungeons."] = "The version of this macro to use when in time walking dungeons."
--[[Translation missing --]]
L["There are %i events in out of combat queue"] = "There are %i events in out of combat queue"
--[[Translation missing --]]
L["There are no events in out of combat queue"] = "There are no events in out of combat queue"
--[[Translation missing --]]
L["There is an error in the sequence that needs to be corrected before it can be saved."] = "There is an error in the sequence that needs to be corrected before it can be saved."
L["There was an error processing "] = "Bei der Verarbeitung ist ein Fehler aufgetreten"
--[[Translation missing --]]
L["These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] = "These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."
--[[Translation missing --]]
L["This change will not come into effect until you save this macro."] = "This change will not come into effect until you save this macro."
--[[Translation missing --]]
L["This CVAR makes WoW use your abilities when you press the key not when you release it.  To use GSE in its native configuration this needs to be checked."] = "This CVAR makes WoW use your abilities when you press the key not when you release it.  To use GSE in its native configuration this needs to be checked."
--[[Translation missing --]]
L["This function will clear the spell cache and any mappings between individual spellIDs and spellnames."] = "This function will clear the spell cache and any mappings between individual spellIDs and spellnames."
--[[Translation missing --]]
L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."] = "This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."
--[[Translation missing --]]
L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames.."] = "This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames.."
--[[Translation missing --]]
L["This function will update macro stubs to support listening to the options below.  This is required to be completed 1 time per character."] = "This function will update macro stubs to support listening to the options below.  This is required to be completed 1 time per character."
--[[Translation missing --]]
L["This is the only version of this macro.  Delete the entire macro to delete this version."] = "This is the only version of this macro.  Delete the entire macro to delete this version."
L["This macro is not compatible with this version of the game and cannot be imported."] = "Dieses Makro ist nicht mit dieser Spielversion kompatibel und kann nicht importiert werden."
--[[Translation missing --]]
L["This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."] = "This macro uses features that are not available in this version. You need to update GSE to %s in order to use this macro."
L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"] = "Diese Option gibt zusätzliche Trace-Informationen im Chat-Fenster aus, um Probleme mit dem Mod zu beheben"
--[[Translation missing --]]
L["This Sequence was exported from GSE %s."] = "This Sequence was exported from GSE %s."
--[[Translation missing --]]
L["This setting forces the ActionButtonUseKeyDown setting one way or another.  It also reconfigures GSE's Macro Stubs to operate in the specified mode."] = "This setting forces the ActionButtonUseKeyDown setting one way or another.  It also reconfigures GSE's Macro Stubs to operate in the specified mode."
--[[Translation missing --]]
L["This setting is a common setting used by all WoW mods.  If affects how your action buttons respond.  With this on the react when you hit the button.  With them off they react when you let them go.  In GSE's case this setting has to be off for Actionbar Overrides to work."] = "This setting is a common setting used by all WoW mods.  If affects how your action buttons respond.  With this on the react when you hit the button.  With them off they react when you let them go.  In GSE's case this setting has to be off for Actionbar Overrides to work."
--[[Translation missing --]]
L["This shows the Global Sequences available as well as those for your class."] = "This shows the Global Sequences available as well as those for your class."
--[[Translation missing --]]
L["This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."] = "This version has been modified by TimothyLuke to make the power of GnomeSequencer avaialble to people who are not comfortable with lua programming."
--[[Translation missing --]]
L["This will display debug messages for the "] = "This will display debug messages for the "
--[[Translation missing --]]
L["This will display debug messages in the Chat window."] = "This will display debug messages in the Chat window."
--[[Translation missing --]]
L["Timewalking"] = "Timewalking"
--[[Translation missing --]]
L["Timewalking setting changed to Default."] = "Timewalking setting changed to Default."
--[[Translation missing --]]
L["Title Colour"] = "Title Colour"
--[[Translation missing --]]
L["To attempt automatic repair run: %s/run GSE.FixSequenceStructure(%d, \"%s\")%s"] = "To attempt automatic repair run: %s/run GSE.FixSequenceStructure(%d, \"%s\")%s"
--[[Translation missing --]]
L["To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"] = "To correct this either delete the version via the GSE Editor or enter the following command to delete this macro totally.  %s/run GSE.DeleteSequence (%i, %s)%s"
--[[Translation missing --]]
L["To get started "] = "To get started "
L["Toy"] = "Spielzeug"
--[[Translation missing --]]
L["Trigger Events"] = "Trigger Events"
--[[Translation missing --]]
L["Troubleshooting"] = "Troubleshooting"
--[[Translation missing --]]
L["Unable to interpret sequence."] = "Unable to interpret sequence."
--[[Translation missing --]]
L["Unable to process content.  Fix table and try again."] = "Unable to process content.  Fix table and try again."
--[[Translation missing --]]
L["Unassigned"] = "Unassigned"
L["Unit Name"] = "Einheiten Name"
--[[Translation missing --]]
L["unknown"] = "unknown"
--[[Translation missing --]]
L["Unknown Colour"] = "Unknown Colour"
--[[Translation missing --]]
L["Unrecognised Import"] = "Unrecognised Import"
--[[Translation missing --]]
L["Up"] = "Up"
--[[Translation missing --]]
L["Update"] = "Update"
--[[Translation missing --]]
L["Updated Macro"] = "Updated Macro"
--[[Translation missing --]]
L["Use MultiClick Buttons"] = "Use MultiClick Buttons"
--[[Translation missing --]]
L["Used by Sequences:"] = "Used by Sequences:"
--[[Translation missing --]]
L["Used by Variables:"] = "Used by Variables:"
L["Variable"] = "Variable"
--[[Translation missing --]]
L["Variable '%s' depends on variable '%s' which does not exist."] = "Variable '%s' depends on variable '%s' which does not exist."
--[[Translation missing --]]
L["Variables"] = "Variables"
--[[Translation missing --]]
L["Version"] = "Version"
--[[Translation missing --]]
L["Vertical Layout"] = "Vertical Layout"
--[[Translation missing --]]
L["WARNING ONLY"] = "WARNING ONLY"
--[[Translation missing --]]
L["WARNING: %s depends on variable(s) that do not exist and cannot be exported: %s"] = "WARNING: %s depends on variable(s) that do not exist and cannot be exported: %s"
--[[Translation missing --]]
L["WARNING: %s embeds sequence(s) that do not exist: %s"] = "WARNING: %s embeds sequence(s) that do not exist: %s"
--[[Translation missing --]]
L["was unable to be interpreted."] = "was unable to be interpreted."
--[[Translation missing --]]
L["was unable to be programmed.  This macro will not fire until errors in the macro are corrected."] = "was unable to be programmed.  This macro will not fire until errors in the macro are corrected."
--[[Translation missing --]]
L["WeakAuras was not found."] = "WeakAuras was not found."
--[[Translation missing --]]
L["Website or forum URL where a player can get more information or ask questions about this macro."] = "Website or forum URL where a player can get more information or ask questions about this macro."
--[[Translation missing --]]
L["What class or spec is this macro for?  If it is for all classes choose Global."] = "What class or spec is this macro for?  If it is for all classes choose Global."
--[[Translation missing --]]
L["When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."] = "When enabled, this variable's function will be called automatically when the selected WoW events or GSE messages fire."
L["When exporting from GSE create a descriptive export for Discord/Discource forums."] = "Erstellen Sie beim Exportieren aus GSE einen beschreibenden Export für Discord/Discource-Foren."
--[[Translation missing --]]
L["When GSE imports a sequence and it already exists locally and has local edits, what do you want the default action to be.  Merge - Add the new MacroVersions to the existing Sequence.  Replace - Replace the existing sequence with the new version. Ignore - ignore updates.  This default action will set the default on the Compare screen however if the GUI is not available this will be the action taken."] = "When GSE imports a sequence and it already exists locally and has local edits, what do you want the default action to be.  Merge - Add the new MacroVersions to the existing Sequence.  Replace - Replace the existing sequence with the new version. Ignore - ignore updates.  This default action will set the default on the Compare screen however if the GUI is not available this will be the action taken."
--[[Translation missing --]]
L["When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"] = "When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"
--[[Translation missing --]]
L["Window Sizes"] = "Window Sizes"
--[[Translation missing --]]
L["Yes"] = "Yes"
--[[Translation missing --]]
L["You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."] = "You cannot delete the Default version of this macro.  Please choose another version to be the Default on the Configuration tab."
--[[Translation missing --]]
L["You need to reload the User Interface to complete this task.  Would you like to do this now?"] = "You need to reload the User Interface to complete this task.  Would you like to do this now?"
--[[Translation missing --]]
L["Your ClassID is "] = "Your ClassID is "
--[[Translation missing --]]
L["Your current Specialisation is "] = "Your current Specialisation is "


