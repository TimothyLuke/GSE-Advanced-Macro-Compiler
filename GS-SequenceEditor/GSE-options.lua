
local OptionsTable = {
  type = "group",
  name = "|cffff0000GS-E:|r Gnome Sequencer - Enhanced Options",
  args = {
    cleanTempMacro = {
      name = "Clean Temporary Macros",
      desc = "The Sequence Editor creates a temporary Macro called \"LiveTest\".  The content of this temporary macro is deleted on logout but the game leaves a macro stub behind.  This switch deletes the Macro Stub from your macros on logout.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.cleanTempMacro = val end,
      get = function(info) return GSMasterOptions.cleanTempMacro end
    },
    hideSoundErrors={
      name = "Prevent Sound Errors",
      desc = "This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableSFX lines within a Sequence",
      type = "toggle",
      set = function(info,val) GSMasterOptions.hideSoundErrors = val end,
      get = function(info) return GSMasterOptions.hideSoundErrors end
    },
    hideUIErrors={
      name = "Prevent UI Errors",
      desc = "This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a PostMacro",
      type = "toggle",
      set = function(info,val) GSMasterOptions.hideUIErrors = val end,
      get = function(info) return GSMasterOptions.hideUIErrors end
    },
    clearUIErrors={
      name = "Clear Errors",
      desc = "This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a PostMacro",
      type = "toggle",
      set = function(info,val) GSMasterOptions.clearUIErrors = val end,
      get = function(info) return GSMasterOptions.clearUIErrors end
    },
    seedInitialMacro={
      name = "Seed Initial Macro",
      desc = "If you load Gnome Sequencer - Enhanced and the Sequence Editor and want to create new macros from scratch, this will enable a first cut sequenced template that you can load into the editor as a starting point.  This enables a Hello World macro called Draik01.  You will need to do a /console reloadui after this for this to take effect.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.seedInitialMacro = val end,
      get = function(info) return GSMasterOptions.seedInitialMacro end
    },
--    addins={
--      name = "Registered Sequence Addin Packs",
--      desc = "You can create and loadin Sequence Packs.",
--      type = "multiselect",
--      values = GSMasterOptions.AddInPacks,
--      --set = function(info,val) --[[ do stuff ]]  end,
--      --get = function(info) --[[ do stuff ]]  end,
--      arg = GSMasterOptions.AddInPacks
--    },
  }
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("GSSE", OptionsTable, {"gse"})
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSSE", "|cffff0000GS-E:|r Gnome Sequencer - Enhanced")
