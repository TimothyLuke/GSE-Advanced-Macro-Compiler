-- =========================================================================
-- GSE_Utils/SlashCommands.lua
--
-- Centralised registry for GSE's native-Blizzard-style slash commands
-- (the `SLASH_NAME1 = "/cmd"` + `SlashCmdList.NAME = function() ... end`
-- pattern, as opposed to the AceConsole `/gse` command that lives in
-- Utils.lua). Previously each of these eight commands sat near the
-- bottom of GSE_GUI/Editor.lua because some of them were paired with
-- icon-fix routines defined there; that meant the layout / tracker
-- commands lived in a file that has nothing to do with the Tracker
-- and was 7,000+ lines long, making them effectively impossible to
-- find. Pulling them out into this dedicated module:
--
--   * gives someone reading the codebase a single, obvious place to
--     find every chat slash command GSE registers (besides /gse and
--     /rl which use AceConsole and live in Utils.lua / Native.lua);
--   * lets the handlers reference whatever GSE.* function they need
--     without dragging a load-order dependency -- by the time the
--     user types the command, every GSE addon has finished loading;
--   * removes ~75 lines from Editor.lua, where they were noise.
--
-- This file is registered last in GSE_Utils.toc so all the target
-- functions (icon scan, save / apply layout, reset tracker) are
-- already on the GSE namespace before this file evaluates. Each
-- handler is guarded with `if GSE.Foo then` for defensive play in
-- case a layered build ever omits the underlying module.
--
-- Commands registered (grouped by what they touch):
--
--   Icon resolver (GSE_GUI/Editor.lua-owned routines):
--     /gsespelliconreset    -> GSE.ResetAllSequenceActionIcons
--     /gseiconscan          -> GSE.ScanSequenceActionIcons
--     /gsesaveallsequences  -> GSE.SaveAllSequenceActionIcons
--
--   Tracker layout slots (GSE_Utils/Tracker.lua-owned routines):
--     /gsesavelayoutx       -> GSE.SequenceIconSaveLayout("X")
--     /gsesavelayouty       -> GSE.SequenceIconSaveLayout("Y")
--     /gseapplylayoutx      -> GSE.SequenceIconApplyLayout("X")
--     /gseapplylayouty      -> GSE.SequenceIconApplyLayout("Y")
--
--   Tracker defaults (GSE_Options/Options.lua-owned routine, exposed
--   on the GSE namespace for cross-addon reuse):
--     /gseresettracker      -> GSE.ResetTrackerToDefaultLayout
-- =========================================================================

local GSE = GSE

-- -------------------------------------------------------------------------
-- Icon resolver commands
-- -------------------------------------------------------------------------

SLASH_GSESPELLICONRESET1 = "/gsespelliconreset"
SlashCmdList.GSESPELLICONRESET = function()
    if GSE.ResetAllSequenceActionIcons then GSE.ResetAllSequenceActionIcons() end
end

SLASH_GSEICONSCAN1 = "/gseiconscan"
SlashCmdList.GSEICONSCAN = function()
    if GSE.ScanSequenceActionIcons then GSE.ScanSequenceActionIcons() end
end

SLASH_GSESAVEALL1 = "/gsesaveallsequences"
SlashCmdList.GSESAVEALL = function()
    if GSE.SaveAllSequenceActionIcons then GSE.SaveAllSequenceActionIcons() end
end

-- -------------------------------------------------------------------------
-- Tracker layout-slot save / apply
--
-- /gsesavelayoutx and /gsesavelayouty capture the current Tracker frame
-- positions and configuration into named layout slot X or Y. The Apply
-- UI buttons in the Options panel restore from these slots. There is no
-- UI Save button (intentional, to keep the panel uncluttered), so these
-- slash commands are the chat-side equivalent.
--
-- /gseapplylayoutx and /gseapplylayouty are the chat-side counterpart.
-- Restores Tracker frame positions and configuration from the named
-- layout slot (X or Y). If the slot hasn't been saved yet,
-- GSE.SequenceIconApplyLayout returns false; we print a hint pointing
-- back at the save command so the user can rescue without leaving chat.
-- -------------------------------------------------------------------------

SLASH_GSESAVELAYOUTX1 = "/gsesavelayoutx"
SlashCmdList.GSESAVELAYOUTX = function()
    if GSE.SequenceIconSaveLayout and GSE.SequenceIconSaveLayout("X") then
        GSE.Print("Tracker Layout X saved with the current positions and configuration.")
    end
end

SLASH_GSESAVELAYOUTY1 = "/gsesavelayouty"
SlashCmdList.GSESAVELAYOUTY = function()
    if GSE.SequenceIconSaveLayout and GSE.SequenceIconSaveLayout("Y") then
        GSE.Print("Tracker Layout Y saved with the current positions and configuration.")
    end
end

SLASH_GSEAPPLYLAYOUTX1 = "/gseapplylayoutx"
SlashCmdList.GSEAPPLYLAYOUTX = function()
    if GSE.SequenceIconApplyLayout and GSE.SequenceIconApplyLayout("X") then
        GSE.Print("Tracker Layout X applied.")
    else
        GSE.Print("Tracker Layout X is not saved. Save it first with /gsesavelayoutx.")
    end
end

SLASH_GSEAPPLYLAYOUTY1 = "/gseapplylayouty"
SlashCmdList.GSEAPPLYLAYOUTY = function()
    if GSE.SequenceIconApplyLayout and GSE.SequenceIconApplyLayout("Y") then
        GSE.Print("Tracker Layout Y applied.")
    else
        GSE.Print("Tracker Layout Y is not saved. Save it first with /gsesavelayouty.")
    end
end

-- -------------------------------------------------------------------------
-- Tracker defaults
--
-- /gseresettracker is a chat shortcut for "restore Tracker defaults".
-- Calls the same routine that the Options panel's "Restore Defaults"
-- button invokes via AttachTrackerDefaultsHandler. Defaults include
-- enabled state, icon size / count, scale, horizontal orientation,
-- widget position, text-frame size, and the standard
-- ShowSuccessfulCasts / ShowSequenceName flags. Safe to call at any
-- time -- does not touch saved layouts X or Y.
-- -------------------------------------------------------------------------

SLASH_GSERESETTRACKER1 = "/gseresettracker"
SlashCmdList.GSERESETTRACKER = function()
    if GSE.ResetTrackerToDefaultLayout then
        GSE.ResetTrackerToDefaultLayout()
        GSE.Print("Tracker reset to the default layout.")
    end
end
