local L = LibStub("AceLocale-3.0"):NewLocale("GSE", "enUS", true)

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
[[|cFFFFFFFFGS|r|cFF00FFFFE|r 3.3.04

|cFFFFD100Actionbar Override Popup|r
Right-clicking an empty actionbar button while out of combat now opens a |cFF00BFFFAssign GSE Sequence|r popup, letting you bind a sequence to that button without opening the editor. Your current spec icon is shown in the menu so you always know which spec you are assigning for.

If you use |cFFFF8C00keybinds exclusively|r and have no actionbar overrides configured, this popup is |cFFFF8C00disabled by default|r to avoid getting in your way. You can toggle it in |cFF00BFFFOptions → Actionbar Overrides → Enable Actionbar Override Popup|r.

|cFFFFD100Dominos Support|r
GSE's actionbar override system now works with the |cFF00BFFFDominos|r actionbar addon as well as the default Blizzard bars.

|cFFFFD100Editor: Minimize Button|r
The Sequence Editor now has a |cFF00BFFFminimize button|r in the top-right corner of the frame. Clicking it collapses the editor (and the Compile Template preview if open) into a small draggable |cFFFFFFFFGS|r|cFF00FFFFE|r icon showing the current sequence name. Click the icon to restore the editor. The icon position is never saved.

|cFFFFD100Editor: Compile Template Window|r
The |cFF00BFFFCompile Template|r preview window now closes automatically when its parent editor is closed, and is reused on repeat clicks rather than creating a new floating window each time.

|cFFFFD100Editor: Tree Panel Width Remembered|r
The width of the sequence tree panel on the left side of the editor is now saved and restored alongside the editor's height and width.

|cFFFFD100Enhanced Sequence Checker|r
|cFF00BFFF/gse checksequencesforerrors|r now performs a deep structural inspection of every sequence, reporting on:
 - Missing or malformed metadata
 - Empty, gapped, or out-of-range action arrays
 - Macro text exceeding 255 characters
 - Unbalanced brackets or unrecognised slash commands
 - Missing variable or embed references
Where issues are found, a ready-to-paste |cFF00BFFF/run|r command is shown to attempt automatic repair.

|cFFFFD100Performance|r
Internal improvements to OOC queue processing, login sequencing, and event handling reduce overhead during load, zone changes, and group changes.

|cFFFFD100Bug Fixes|r
 - Keybinds configured in GSE are no longer overridden by the actionbar override system.
 - Actionbar override icons now display correctly for bars other than bar 1.
 - Hovering over an actionbar override button no longer clears its icon.
 - GSE Options are now correctly initialised on first install.
 - Fixed several secure frame errors related to actionbar overrides.
]]
