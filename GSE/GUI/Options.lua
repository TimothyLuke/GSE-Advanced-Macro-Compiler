local GNOME, _ = ...
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

function GSE.GetOptionsTable()
  local OptionsTable = {
    type = "group",
    name = L["|cffff0000GS-E:|r Gnome Sequencer - Enhanced Options"],
    args = {
      generalTab = {
        name = L["General"],
        desc = L["General Options"],
        type = "group",
        order = 1,
        args = {
          title1 = {
            type = "header",
            name = L["General Options"],
            order = 100
          },
          saveAllMacrosLocal = {
            name = L["Only Save Local Macros"],
            desc = L["GS-E can save all macros or only those versions that you have created locally.  Turning this off will cache all macros in your WTF\\GS-Core.lua variables file but will increase load times and potentially cause colissions."],
            type = "toggle",
            set = function(info,val) GSEOptions.saveAllMacrosLocal = val end,
            get = function(info) return GSEOptions.saveAllMacrosLocal end,
            order = 200
          },
          usetranslator = {
            name = L["Use Macro Translator"],
            desc = L["The Macro Translator will translate an English sequence to your local language for execution.  It can also be used to translate a sequence into a different language.  It is also used for syntax based colour markup of Sequences in the editor."],
            type = "toggle",
            set = function(info,val) GSE.ToggleTranslator(val) end,
            get = function(info) return GSEOptions.useTranslator end,
            order = 201
          },
          realtimeparse = {
            name = L["Use Realtime Parsing"],
            desc = L["The Sequence Editor can attempt to parse the Sequences, KeyPress and KeyRelease in realtime.  This is still experimental so can be turned off."],
            type = "toggle",
            set = function(info,val) GSEOptions.RealtimeParse = val end,
            get = function(info) return GSEOptions.RealtimeParse end,
            order = 202
          },
          resetOOC = {
            name = L["Reset Macro when out of combat"],
            desc = L["Resets macros back to the initial state when out of combat."],
            type = "toggle",
            set = function(info,val) GSEOptions.resetOOC = val end,
            get = function(info) return GSEOptions.resetOOC end,
            order = 300
          },
          deleteOrphanLogout = {
            name = L["Delete Orphaned Macros on Logout"],
            desc = L["As GS-E is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gs cleanorphans"],
            type = "toggle",
            set = function(info,val) GSEOptions.deleteOrphansOnLogout = val end,
            get = function(info) return GSEOptions.deleteOrphansOnLogout end,
            order = 301
          },
          overflowPersonalMacros = {
            name = L["Use Global Account Macros"],
            desc = L["When creating a macro, if there is not a personal character macro space, create an account wide macro."],
            type = "toggle",
            set = function(info,val) GSEOptions.overflowPersonalMacros = val end,
            get = function(info) return GSEOptions.overflowPersonalMacros end,
            order = 302
          },
          autocreateclassstub = {
            name = L["Auto Create Class Macro Stubs"],
            desc = L["When loading or creating a sequence, if it is a macro of the same class automatically create the Macro Stub"],
            type = "toggle",
            set = function(info,val) GSEOptions.autoCreateMacroStubsClass = val end,
            get = function(info) return GSEOptions.autoCreateMacroStubsClass end,
            order = 303
          },
          autocreateglobalstub = {
            name = L["Auto Create Global Macro Stubs"],
            desc = L["When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"],
            type = "toggle",
            set = function(info,val) GSEOptions.autoCreateMacroStubsGlobal = val end,
            get = function(info) return GSEOptions.autoCreateMacroStubsGlobal end,
            order = 304
          },
          useQuestionMark = {
            name = L["Set Default Icon QuestionMark"],
            desc = L["By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."],
            type = "toggle",
            set = function(info,val) GSEOptions.setDefaultIconQuestionMark = val end,
            get = function(info) return GSEOptions.setDefaultIconQuestionMark end,
            order = 310
          },
          filtertitle1 = {
            type = "header",
            name = L["Filter Macro Selection"],
            order = 400
          },
          showAllMacros = {
            name = L["Show All Macros in Editor"],
            desc = L["By setting this value the Sequence Editor will show every macro for every class."],
            type = "toggle",
            set = function(info,val) GSEOptions.filterList["All"] = val end,
            get = function(info) return GSEOptions.filterList["All"] end,
            order = 410
          },
          showClassMacros = {
            name = L["Show Class Macros in Editor"],
            desc = L["By setting this value the Sequence Editor will show every macro for your class."],
            type = "toggle",
            set = function(info,val) GSEOptions.filterList["Class"] = val end,
            get = function(info) return GSEOptions.filterList["Class"] end,
            order = 420
          },
          title2 = {
            type = "header",
            name = L["Gameplay Options"],
            order = 500
          },
          requireTarget={
            name = L["Require Target to use"],
            desc = L["This option prevents macros firing unless you have a target. Helps reduce mistaken targeting of other mobs/groups when your target dies."],
            type = "toggle",
            set = function(info,val) GSEOptions.requireTarget = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.requireTarget end,
            order = 510
          },
          hideSoundErrors={
            name = L["Prevent Sound Errors"],
            desc = L["This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableErrorSpeech lines within a Sequence.  Turning this on will trigger a Scam warning about running custom scripts."],
            type = "toggle",
            set = function(info,val) GSEOptions.hideSoundErrors = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.hideSoundErrors end,
            order = 520
          },
          hideUIErrors={
            name = L["Prevent UI Errors"],
            desc = L["This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."],
            type = "toggle",
            set = function(info,val) GSEOptions.hideUIErrors = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.hideUIErrors end,
            order = 530
          },
          clearUIErrors={
            name = L["Clear Errors"],
            desc = L["This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."],
            type = "toggle",
            set = function(info,val) GSEOptions.clearUIErrors = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.clearUIErrors end,
            order = 540
          },
          use11={
            name = L["Use First Ring in KeyRelease"],
            desc = L["Incorporate the first ring slot into the KeyRelease. This is the equivalent of /use [combat] 11 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use11 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use11 end,
            order = 550
          },
          use12={
            name = L["Use Second Ring in KeyRelease"],
            desc = L["Incorporate the second ring slot into the KeyRelease. This is the equivalent of /use [combat] 12 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use12 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use12 end,
            order = 560
          },
          use13={
            name = L["Use First Trinket in KeyRelease"],
            desc = L["Incorporate the first trinket slot into the KeyRelease. This is the equivalent of /use [combat] 13 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use13 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use13 end,
            order = 570
          },
          use14={
            name = L["Use Second Trinket in KeyRelease"],
            desc = L["Incorporate the second trinket slot into the KeyRelease. This is the equivalent of /use [combat] 14 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use14 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use14 end,
            order = 580
          },
          use2={
            name = L["Use Neck Item in KeyRelease"],
            desc = L["Incorporate the neck slot into the KeyRelease. This is the equivalent of /use [combat] 2 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use2 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use2 end,
            order = 591
          },
          use6={
            name = L["Use Belt Item in KeyRelease"],
            desc = L["Incorporate the belt slot into the KeyRelease. This is the equivalent of /use [combat] 5 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use6 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use6 end,
            order = 592
          },
          use1={
            name = L["Use Head Item in KeyRelease"],
            desc = L["Incorporate the Head slot into the KeyRelease. This is the equivalent of /use [combat] 1 in a KeyRelease."],
            type = "toggle",
            set = function(info,val) GSEOptions.use1 = val GSE.ReloadSequences() end,
            get = function(info) return GSEOptions.use1 end,
            order = 593
          },
        },
      },
      colourTab = {
        name = L["Colour"],
        desc = L["Colour and Accessibility Options"],
        type = "group",
        order = 2,
        args = {
          ctitle1 = {
            type = "header",
            name = L["General Options"],
            order = 100,
          },
          titleColour = {
            type = "color",
            name = L["Title Colour"],
            desc = L["Picks a Custom Colour for the Mod Names."],
            order = 101,
            hasAlpha = false,
            get = function(info) return GSE.GUIGetColour(GSEOptions.TitleColour) end,
            set = function(info, r, g, b, a)
              GSEOptions.TitleColour = string.format("|c%02x%02x%02x%02x", a*255 , r*255, g * 255, b*255)
            end,
          },
          authorColour = {
            type = "color",
            name = L["Author Colour"],
            desc = L["Picks a Custom Colour for the Author."],
            order = 110,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.AuthorColour)
            end,
            set = function(info, r, g, b)
              GSEOptions.AuthorColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
            end,
          },
          commandColour = {
            type = "color",
            name = L["Command Colour"],
            desc = L["Picks a Custom Colour for the Commands."],
            order = 120,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.CommandColour)
            end,
            set = function(info, r, g, b)
              GSEOptions.CommandColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
            end,
          },
          emphasisColour = {
            type = "color",
            name = L["Emphasis Colour"],
            desc = L["Picks a Custom Colour for emphasis."],
            order = 130,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.EmphasisColour)
            end,
            set = function(info, r, g, b)
              GSEOptions.EmphasisColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
            end,
          },
          normalColour = {
            type = "color",
            name = L["Normal Colour"],
            desc = L["Picks a Custom Colour to be used normally."],
            order = 140,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.NormalColour)
            end,
            set = function(info, r, g, b)
              GSEOptions.NormalColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
            end,
          },
          ctitle2 = {
            type = "header",
            name = L["Editor Colours"],
            order = 200,
          },

          keywordColour = {
            type = "color",
            name = L["Spell Colour"],
            desc = L["Picks a Custom Colour to be used for Spells and Abilities."],
            order = 210,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.KEYWORD)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.KEYWORD, r, g, b)
            end,
          },
          unknownColour = {
            type = "color",
            name = L["Unknown Colour"],
            desc = L["Picks a Custom Colour to be used for unknown terms."],
            order = 220,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.UNKNOWN)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.UNKNOWN, r, g, b)
            end,
          },
          iconColour = {
            type = "color",
            name = L["Icon Colour"],
            desc = L["Picks a Custom Colour to be used for Icons."],
            order = 230,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.CONCAT)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.CONCAT, r, g, b)
            end,
          },
          numberColour = {
            type = "color",
            name = L["SpecID/ClassID Colour"],
            desc = L["Picks a Custom Colour to be used for numbers."],
            order = 240,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.NUMBER)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.NUMBER, r, g, b)
            end,
          },
          stringColour = {
            type = "color",
            name = L["String Colour"],
            desc = L["Picks a Custom Colour to be used for strings."],
            hidden = true,
            order = 250,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.STRING)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.STRING, r, g, b)
            end,
          },
          conditionalColour = {
            type = "color",
            name = L["Conditionals Colour"],
            desc = L["Picks a Custom Colour to be used for macro conditionals eg [mod:shift]"],
            order = 260,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.COMMENT)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.COMMENT, r, g, b)
            end,
          },
          helpColour = {
            type = "color",
            name = L["Help Colour"],
            desc = L["Picks a Custom Colour to be used for braces and indents."],
            order = 270,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.INDENT)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.INDENT, r, g, b)
            end,
          },
          stepColour = {
            type = "color",
            name = L["Step Functions"],
            desc = L["Picks a Custom Colour to be used for StepFunctions."],
            order =280,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.EQUALS)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.EQUALS, r, g, b)
            end,
          },
          languageColour = {
            type = "color",
            name = L["Language Colour"],
            desc = L["Picks a Custom Colour to be used for language descriptors"],
            order = 290,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.STANDARDFUNCS)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.STANDARDFUNCS, r, g, b)
            end,
          },
          shortcutsColour = {
            type = "color",
            name = L["Blizzard Functions Colour"],
            desc = L["Picks a Custom Colour to be used for Macro Keywords like /cast and /target"],
            order = 300,
            hasAlpha = false,
            get = function(info)
              return GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS)
            end,
            set = function(info, r, g, b)
              GSE.GUISetColour(GSEOptions.WOWSHORTCUTS, r, g, b)
            end,
          },
        },
      },
      pluginsTab = {
        name = L["Plugins"],
        desc = L["GS-E Plugins"],
        type = "group",
        order = 3,
        args = {
          title3 = {
            type = "header",
            name = L["Registered Addons"],
            order = 900,
          },
          plugindesc = {
            type = "description",
            name = L["GSE allows plugins to load Macro Collections as plugins.  You can reload a collection by pressing the button below."]
          }
        },
      },
      debugTab = {
        name = L["Debug"],
        desc = L["Debug Mode Options"],
        type = "group",
        order = -1,
        args = {
          title4 = {
            type = "header",
            name = L["Debug Mode Options"],
            order = 1
          },
          debug={
            name = L["Enable Mod Debug Mode"],
            desc = L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"],
            type = "toggle",
            set = function(info,val) GSEOptions.debug = val GSE.PrintDebugMessage("Debug Mode Enabled", GNOME) end,
            get = function(info) return GSEOptions.debug end,
            order = 10
          },
          title5= {
            type = "header",
            name = L["Debug Output Options"],
            order = 20
          },
          debugchat={
            name = L["Display debug messages in Chat Window"],
            desc = L["This will display debug messages in the Chat window."],
            type = "toggle",
            set = function(info,val) GSEOptions.sendDebugOutputToChatWindow  = val end,
            get = function(info) return GSEOptions.sendDebugOutputToChatWindow  end,
            order = 21
          },
          sendDebugOutputToDebugOutput={
            name = L["Store Debug Messages"],
            desc = L["Store output of debug messages in a Global Variable that can be referrenced by other mods."],
            type = "toggle",
            set = function(info,val) GSEOptions.sendDebugOutputToDebugOutput = val end,
            get = function(info) return GSEOptions.sendDebugOutputToDebugOutput end,
            order = 25
          },
          title6= {
            type = "header",
            name = L["Enable Debug for the following Modules"],
            order = 30
          },
          debugGSSequenceExecution={
            name = L["Debug Sequence Execution"],
            desc = L["Output the action for each button press to verify StepFunction and spell availability."],
            type = "toggle",
            set = function(info,val) GSDebugSequenceEx = val end,
            get = function(info) return GSDebugSequenceEx end,
            order = 31
          },
          debugmodcore={
            name = "GS-Core",
            desc = L["This will display debug messages for the Core of GS-E"],
            type = "toggle",
            set = function(info,val) GSEOptions.DebugModules["GS-Core"] = val end,
            get = function(info) return GSEOptions.DebugModules["GS-Core"] end,
            order = 32
          },
          debugmodtranslator={
            name = "GS-SequenceTranslator",
            desc = L["This will display debug messages for the GS-E Translator"],
            type = "toggle",
            set = function(info,val) GSEOptions.DebugModules["GS-SequenceTranslator"] = val end,
            get = function(info) return GSEOptions.DebugModules["GS-SequenceTranslator"] end,
            order = 33
          },
          debugmodeditor={
            name = "GS-SequenceEditor",
            desc = L["This will display debug messages for the GS-E Sequence Editor"],
            type = "toggle",
            set = function(info,val) GSEOptions.DebugModules["GS-SequenceEditor"] = val end,
            get = function(info) return GSEOptions.DebugModules["GS-SequenceEditor"] end,
            order = 34
          },
          debugmodtransmission={
            name = "GS-SequenceTransmission",
            desc = L["This will display debug messages for the GS-E Ingame Transmission and transfer"],
            type = "toggle",
            set = function(info,val) GSEOptions.DebugModules[GSStaticSourceTransmission] = val end,
            get = function(info) return GSEOptions.DebugModules[GSStaticSourceTransmission] end,
            order = 35
          },
        }
      }
    }
  }
  -- Add Dynamic contentcontainer

  local ord = 900
  for k,v in pairs(GSE.AddInPacks) do
    ord = ord + 1
    OptionsTable.args.pluginsTab.args[v.Name] = {
      name = v.Name,
      desc = string.format(L["Addin Version %s contained versions for the following macros: \n%s"], v.Name, GSE.FormatSequenceNames(v.SequenceNames)),
      type = "execute",
      func = function(info, val)
        GSE:SendMessage(Statics.ReloadMessage, v.Name)
      end,
      order = ord

    }
  end
  return OptionsTable
end
