
function GSListAddons()
  local returnVal = "";
  for k,v in pairs(GSMasterOptions.AddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end

function updateOptions(option, val)
  option = val
  GSReloadSequences()
end


local OptionsTable = {
  type = "group",
  name = "|cffff0000GS-E:|r Gnome Sequencer - Enhanced Options",
  args = {
    title1 = {
      type = "header",
      name = "General Options",
      order = 100
    },
    cleanTempMacro = {
      name = "Clean Temporary Macros",
      desc = "The Sequence Editor creates a temporary Macro called \"LiveTest\".  The content of this temporary macro is deleted on logout but the game leaves a macro stub behind.  This switch deletes the Macro Stub from your macros on logout.",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.cleanTempMacro, val) end,
      get = function(info) return GSMasterOptions.cleanTempMacro end,
      order = 200
    },
    deleteOrphanLogout = {
      name = "Delete Orphaned Macros on Logout",
      desc = "As GS-E is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gs cleanorphans",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.deleteOrphansOnLogout, val) end,
      get = function(info) return GSMasterOptions.deleteOrphansOnLogout end,
      order = 300
    },
    seedInitialMacro={
      name = "Seed Initial Macro",
      desc = "If you load Gnome Sequencer - Enhanced and the Sequence Editor and want to create new macros from scratch, this will enable a first cut sequenced template that you can load into the editor as a starting point.  This enables a Hello World macro called Draik01.  You will need to do a /console reloadui after this for this to take effect.",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.seedInitialMacro, val) end,
      get = function(info) return GSMasterOptions.seedInitialMacro end,
      order = 400
    },
    title2 = {
      type = "header",
      name = "Execution Options",
      order = 500
    },
    hideSoundErrors={
      name = "Prevent Sound Errors",
      desc = "This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableSFX lines within a Sequence.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.hideSoundErrors, val) end,
      get = function(info) return GSMasterOptions.hideSoundErrors end,
      order = 600
    },
    hideUIErrors={
      name = "Prevent UI Errors",
      desc = "This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.hideUIErrors, val) end,
      get = function(info) return GSMasterOptions.hideUIErrors end,
      order = 700
    },
    clearUIErrors={
      name = "Clear Errors",
      desc = "This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) updateOptions(GSMasterOptions.clearUIErrors, val) end,
      get = function(info) return GSMasterOptions.clearUIErrors end,
      order = 800
    },
    title3 = {
      type = "header",
      name = "Registered Addons",
      order = 900
    },
    addins={
      --name = "Registered Sequence Addin Packs",
      --desc = "You can create and loadin Sequence Packs.",
      type = "description",
      name = GSListAddons(),
      order = 1000
    },
  }
}


LibStub("AceConfig-3.0"):RegisterOptionsTable("GSSE", OptionsTable, {"gse"})
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSSE", "|cffff0000GS-E:|r Gnome Sequencer - Enhanced")
