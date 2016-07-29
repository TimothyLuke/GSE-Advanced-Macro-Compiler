local GNOME, _ = ...

function GSListAddons()
  local returnVal = "";
  for k,v in pairs(GSMasterOptions.AddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
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
      set = function(info,val) GSMasterOptions.cleanTempMacro = val end,
      get = function(info) return GSMasterOptions.cleanTempMacro end,
      order = 200
    },
    usetranslator = {
      name = "Use Macro Translator",
      desc = "The Macro Translator will translate an English sequence to your local language for execution.  It can also be used to translate a sequence into a different language.",
      type = "toggle",
      set = function(info,val) GSTtoggleTranslator(val) end,
      get = function(info) return GSMasterOptions.useTranslator end,
      order = 201
    },
    deleteOrphanLogout = {
      name = "Delete Orphaned Macros on Logout",
      desc = "As GS-E is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gs cleanorphans",
      type = "toggle",
      set = function(info,val) GSMasterOptions.deleteOrphansOnLogout = val end,
      get = function(info) return GSMasterOptions.deleteOrphansOnLogout end,
      order = 300
    },
    seedInitialMacro={
      name = "Seed Initial Macro",
      desc = "If you load Gnome Sequencer - Enhanced and the Sequence Editor and want to create new macros from scratch, this will enable a first cut sequenced template that you can load into the editor as a starting point.  This enables a Hello World macro called Draik01.  You will need to do a /console reloadui after this for this to take effect.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.seedInitialMacro = val end,
      get = function(info) return GSMasterOptions.seedInitialMacro end,
      order = 400
    },
    title2 = {
      type = "header",
      name = "Enabling these options will trigger the ingame Warning about Custom Scripts.",
      order = 500
    },
    requireTarget={
      name = "Require Target to use",
      desc = "This option prevents macros firing unless you have a target. Helps reduce mistaken targeting of other mobs/groups when your target dies.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.requireTarget = val GSReloadSequences() end,
      get = function(info) return GSMasterOptions.requireTarget end,
      order = 550
    },
    hideSoundErrors={
      name = "Prevent Sound Errors",
      desc = "This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableSFX lines within a Sequence.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.hideSoundErrors = val GSReloadSequences() end,
      get = function(info) return GSMasterOptions.hideSoundErrors end,
      order = 600
    },
    hideUIErrors={
      name = "Prevent UI Errors",
      desc = "This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.hideUIErrors = val GSReloadSequences() end,
      get = function(info) return GSMasterOptions.hideUIErrors end,
      order = 700
    },
    clearUIErrors={
      name = "Clear Errors",
      desc = "This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.clearUIErrors = val GSReloadSequences() end,
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
    title4 = {
      type = "header",
      name = "Debug Mode Options",
      order = -1
    },
    debug={
      name = "Enable Mod Debug Mode",
      desc = "This option dumps extra trace information to your chat window to help troubleshoot problems with the mod",
      type = "toggle",
      set = function(info,val) GSMasterOptions.debug = val GSPrintDebugMessage("Debug Mode Enabled", GNOME) end,
      get = function(info) return GSMasterOptions.debug end,
      order = -1
    },
    debugchat={
      name = "Display debug messages in Chat Window",
      desc = "This will display debug messages in the Chat window.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.sendDebugOutputToChat = val end,
      get = function(info) return GSMasterOptions.sendDebugOutputToChat end,
      order = -1
    },
    debugGSDebugOutput={
      name = "Store Debug Messages",
      desc = "Store output of debug messages in a Global Variable that can be referrenced by other mods.",
      type = "toggle",
      set = function(info,val) GSMasterOptions.sendDebugOutputGSDebugOutput = val end,
      get = function(info) return GSMasterOptions.sendDebugOutputGSDebugOutput end,
      order = -1
    },
  }
}

GSMasterOptions.sendDebugOutputToChat = true
GSMasterOptions.sendDebugOutputGSDebugOutput = false

function GSTtoggleTranslator (boole)
  if GSTranslatorAvailable then
    GSMasterOptions.useTranslator = boole
  elseif boole then
    print('|cffff0000' .. GNOME .. ':|r The Sequence Translator allows you to use GS-E on other languages than enUS.  It will translate sequences to match your language.  If you also have the Sequence Editor you can translate sequences between languages.  The GS-E Sequence Translator is available on curse.com')
  else
    GSMasterOptions.useTranslator = boole
  end
end

LibStub("AceConfig-3.0"):RegisterOptionsTable("GSSE", OptionsTable, {"gse"})
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSSE", "|cffff0000GS-E:|r Gnome Sequencer - Enhanced")
