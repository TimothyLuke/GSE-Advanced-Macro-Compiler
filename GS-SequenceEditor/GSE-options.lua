local GNOME, _ = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")

StaticPopupDialogs["GSEConfirmReloadUI"] = {
  text = L["You need to reload the User Interface to complete this task.  Would you like to do this now?"],
  button1 = L["Yes"],
  button2 = L["No"],
  OnAccept = function()
      ReloadUI();
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
}

function GSListUnloadedAddons()
  local returnVal = "";
  for k,v in pairs(GSUnloadedAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end


function GSListAddons()
  local returnVal = "";
  for k,v in pairs(GSAddInPacks) do
    aname, atitle, anotes, _, _, _ = GetAddOnInfo(k)
    returnVal = returnVal .. '|cffff0000' .. atitle .. ':|r '.. anotes .. '\n\n'
  end
  return returnVal
end

function GSGetColour(option)
  hex = string.gsub(option, "#","")
  return tonumber("0x".. string.sub(option,5,6))/255, tonumber("0x"..string.sub(option,7,8))/255, tonumber("0x"..string.sub(option,9,10))/255
end

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
          set = function(info,val) GSMasterOptions.saveAllMacrosLocal = val end,
          get = function(info) return GSMasterOptions.saveAllMacrosLocal end,
          order = 200
        },
        usetranslator = {
          name = L["Use Macro Translator"],
          desc = L["The Macro Translator will translate an English sequence to your local language for execution.  It can also be used to translate a sequence into a different language.  It is also used for syntax based colour markup of Sequences in the editor."],
          type = "toggle",
          set = function(info,val) GSTtoggleTranslator(val) end,
          get = function(info) return GSMasterOptions.useTranslator end,
          order = 201
        },
        realtimeparse = {
          name = L["Use Realtime Parsing"],
          desc = L["The Sequence Editor can attempt to parse the Sequences, PreMacro and PostMacro in realtime.  This is still experimental so can be turned off."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.RealtimeParse = val end,
          get = function(info) return GSMasterOptions.RealtimeParse end,
          order = 201
        },
        deleteOrphanLogout = {
          name = L["Delete Orphaned Macros on Logout"],
          desc = L["As GS-E is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gs cleanorphans"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.deleteOrphansOnLogout = val end,
          get = function(info) return GSMasterOptions.deleteOrphansOnLogout end,
          order = 300
        },
        overflowPersonalMacros = {
          name = L["Use Global Account Macros"],
          desc = L["When creating a macro, if there is not a personal character macro space, create an account wide macro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.overflowPersonalMacros = val end,
          get = function(info) return GSMasterOptions.overflowPersonalMacros end,
          order = 301
        },
        autocreateclassstub = {
          name = L["Auto Create Class Macro Stubs"],
          desc = L["When loading or creating a sequence, if it is a macro of the same class automatically create the Macro Stub"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.autoCreateMacroStubsClass = val end,
          get = function(info) return GSMasterOptions.autoCreateMacroStubsClass end,
          order = 302
        },
        autocreateglobalstub = {
          name = L["Auto Create Global Macro Stubs"],
          desc = L["When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.autoCreateMacroStubsGlobal = val end,
          get = function(info) return GSMasterOptions.autoCreateMacroStubsGlobal end,
          order = 303
        },
        useQuestionMark = {
          name = L["Set Default Icon QuestionMark"],
          desc = L["By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.setDefaultIconQuestionMark = val end,
          get = function(info) return GSMasterOptions.setDefaultIconQuestionMark end,
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
          set = function(info,val) GSMasterOptions.filterList["All"] = val end,
          get = function(info) return GSMasterOptions.filterList["All"] end,
          order = 410
        },
        showClassMacros = {
          name = L["Show Class Macros in Editor"],
          desc = L["By setting this value the Sequence Editor will show every macro for your class."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.filterList["Class"] = val end,
          get = function(info) return GSMasterOptions.filterList["Class"] end,
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
          set = function(info,val) GSMasterOptions.requireTarget = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.requireTarget end,
         order = 510
        },
        hideSoundErrors={
          name = L["Prevent Sound Errors"],
          desc = L["This option hide error sounds like \"That is out of range\" from being played while you are hitting a GS Macro.  This is the equivalent of /console Sound_EnableErrorSpeech lines within a Sequence.  Turning this on will trigger a Scam warning about running custom scripts."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.hideSoundErrors = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.hideSoundErrors end,
          order = 520
        },
        hideUIErrors={
          name = L["Prevent UI Errors"],
          desc = L["This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.hideUIErrors = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.hideUIErrors end,
          order = 530
        },
        clearUIErrors={
          name = L["Clear Errors"],
          desc = L["This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a PostMacro.  Turning this on will trigger a Scam warning about running custom scripts."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.clearUIErrors = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.clearUIErrors end,
          order = 540
        },
        use11={
          name = L["Use First Ring in Postmacro"],
          desc = L["Incorporate the first ring slot into the PostMacro. This is the equivalent of /use [combat] 11 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use11 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use11 end,
          order = 550
        },
        use12={
          name = L["Use Second Ring in Postmacro"],
          desc = L["Incorporate the second ring slot into the PostMacro. This is the equivalent of /use [combat] 12 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use12 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use12 end,
          order = 560
        },
        use13={
          name = L["Use First Trinket in Postmacro"],
          desc = L["Incorporate the first trinket slot into the PostMacro. This is the equivalent of /use [combat] 13 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use13 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use13 end,
          order = 570
        },
        use14={
          name = L["Use Second Trinket in Postmacro"],
          desc = L["Incorporate the second trinket slot into the PostMacro. This is the equivalent of /use [combat] 14 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use14 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use14 end,
          order = 580
        },
        use2={
          name = L["Use Neck Item in Postmacro"],
          desc = L["Incorporate the neck slot into the PostMacro. This is the equivalent of /use [combat] 2 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use2 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use2 end,
          order = 591
        },
        use6={
          name = L["Use Belt Item in Postmacro"],
          desc = L["Incorporate the belt slot into the PostMacro. This is the equivalent of /use [combat] 5 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use6 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use6 end,
          order = 592
        },
        use1={
          name = L["Use Head Item in Postmacro"],
          desc = L["Incorporate the Head slot into the PostMacro. This is the equivalent of /use [combat] 1 in a PostMacro."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.use1 = val GSReloadSequences() end,
          get = function(info) return GSMasterOptions.use1 end,
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
    			get = function(info) return GSGetColour(GSMasterOptions.TitleColour) end,
    			set = function(info, r, g, b, a)
            GSMasterOptions.TitleColour = string.format("|c%02x%02x%02x%02x", a*255 , r*255, g * 255, b*255)
          end,
    		},
        authorColour = {
    			type = "color",
    			name = L["Author Colour"],
    			desc = L["Picks a Custom Colour for the Author."],
          order = 110,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.AuthorColour)
    			end,
    			set = function(info, r, g, b)
    				GSMasterOptions.AuthorColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
    			end,
    		},
        commandColour = {
    			type = "color",
    			name = L["Command Colour"],
    			desc = L["Picks a Custom Colour for the Commands."],
          order = 120,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.CommandColour)
    			end,
    			set = function(info, r, g, b)
    				GSMasterOptions.CommandColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
    			end,
    		},
        emphasisColour = {
    			type = "color",
    			name = L["Emphasis Colour"],
    			desc = L["Picks a Custom Colour for emphasis."],
          order = 130,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.EmphasisColour)
    			end,
    			set = function(info, r, g, b)
    				GSMasterOptions.EmphasisColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
    			end,
    		},
        normalColour = {
    			type = "color",
    			name = L["Normal Colour"],
    			desc = L["Picks a Custom Colour to be used normally."],
          order = 140,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.NormalColour)
    			end,
    			set = function(info, r, g, b)
    				GSMasterOptions.NormalColour = string.format("|c%02x%02x%02x%02x", 255 , r*255, g * 255, b*255)
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
            return GSGetColour(GSMasterOptions.KEYWORD)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.KEYWORD, r, g, b)
    			end,
    		},
        unknownColour = {
    			type = "color",
    			name = L["Unknown Colour"],
    			desc = L["Picks a Custom Colour to be used for unknown terms."],
          order = 220,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.UNKNOWN)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.UNKNOWN, r, g, b)
    			end,
    		},
        iconColour = {
    			type = "color",
          name = L["Icon Colour"],
    			desc = L["Picks a Custom Colour to be used for Icons."],
          order = 230,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.CONCAT)
    			end,
    			set = function(info, r, g, b) GSSetColour(GSMasterOptions.CONCAT, r, g, b) end,
    		},
        numberColour = {
    			type = "color",
    			name = L["SpecID/ClassID Colour"],
    			desc = L["Picks a Custom Colour to be used for numbers."],
          order = 240,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.NUMBER)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.NUMBER, r, g, b)
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
            return GSGetColour(GSMasterOptions.STRING)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.STRING, r, g, b)
    			end,
    		},
        conditionalColour = {
    			type = "color",
    			name = L["Conditionals Colour"],
    			desc = L["Picks a Custom Colour to be used for macro conditionals eg [mod:shift]"],
          order = 260,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.COMMENT)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.COMMENT, r, g, b)
    			end,
    		},
        helpColour = {
    			type = "color",
    			name = L["Help Colour"],
    			desc = L["Picks a Custom Colour to be used for braces and indents."],
          order = 270,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.INDENT)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.INDENT, r, g, b)
    			end,
    		},
        stepColour = {
    			type = "color",
    			name = L["Step Functions"],
    			desc = L["Picks a Custom Colour to be used for StepFunctions."],
          order =280,
          hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.EQUALS)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.EQUALS, r, g, b)
    			end,
    		},
        languageColour = {
    			type = "color",
    			name = L["Language Colour"],
    			desc = L["Picks a Custom Colour to be used for language descriptors"],
          order = 290,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.STANDARDFUNCS)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.STANDARDFUNCS, r, g, b)
    			end,
    		},
        shortcutsColour = {
    			type = "color",
    			name = L["Blizzard Functions Colour"],
    			desc = L["Picks a Custom Colour to be used for Macro Keywords like /cast and /target"],
          order = 300,
    			hasAlpha = false,
    			get = function(info)
            return GSGetColour(GSMasterOptions.WOWSHORTCUTS)
    			end,
    			set = function(info, r, g, b)
    				GSSetColour(GSMasterOptions.WOWSHORTCUTS, r, g, b)
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
        addins={
          --name = "Registered Sequence Addin Packs",
          --desc = "You can create and loadin Sequence Packs.",
          type = "description",
          name = GSListAddons(),
          order = 1000,
        },
        unloadedtitle3 = {
          type = "header",
          name = L["Available Addons"],
          order = 1100,
        },
        unloadedaddins={
          --name = "Registered Sequence Addin Packs",
          --desc = "You can create and loadin Sequence Packs.",
          type = "description",
          name = GSListUnloadedAddons(),
          order = 1200,
        },

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
          set = function(info,val) GSMasterOptions.debug = val GSPrintDebugMessage("Debug Mode Enabled", GNOME) end,
          get = function(info) return GSMasterOptions.debug end,
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
          set = function(info,val) GSMasterOptions.sendDebugOutputToChat = val end,
          get = function(info) return GSMasterOptions.sendDebugOutputToChat end,
          order = 21
        },
        debugGSDebugOutput={
          name = L["Store Debug Messages"],
          desc = L["Store output of debug messages in a Global Variable that can be referrenced by other mods."],
          type = "toggle",
          set = function(info,val) GSMasterOptions.sendDebugOutputGSDebugOutput = val end,
          get = function(info) return GSMasterOptions.sendDebugOutputGSDebugOutput end,
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
          set = function(info,val) GSMasterOptions.debugSequenceEx = val end,
          get = function(info) return GSMasterOptions.debugSequenceEx end,
          order = 31
        },
        debugmodcore={
          name = "GS-Core",
          desc = L["This will display debug messages for the Core of GS-E"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.DebugModules["GS-Core"] = val end,
          get = function(info) return GSMasterOptions.DebugModules["GS-Core"] end,
          order = 32
        },
        debugmodtranslator={
          name = "GS-SequenceTranslator",
          desc = L["This will display debug messages for the GS-E Translator"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.DebugModules["GS-SequenceTranslator"] = val end,
          get = function(info) return GSMasterOptions.DebugModules["GS-SequenceTranslator"] end,
          order = 33
        },
        debugmodeditor={
          name = "GS-SequenceEditor",
          desc = L["This will display debug messages for the GS-E Sequence Editor"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.DebugModules["GS-SequenceEditor"] = val end,
          get = function(info) return GSMasterOptions.DebugModules["GS-SequenceEditor"] end,
          order = 34
        },
        debugmodtransmission={
          name = "GS-SequenceTransmission",
          desc = L["This will display debug messages for the GS-E Ingame Transmission and transfer"],
          type = "toggle",
          set = function(info,val) GSMasterOptions.DebugModules[GSStaticSourceTransmission] = val end,
          get = function(info) return GSMasterOptions.DebugModules[GSStaticSourceTransmission] end,
          order = 35
        },
      }
    }
  }
}

GSMasterOptions.sendDebugOutputToChat = true
GSMasterOptions.sendDebugOutputGSDebugOutput = false

function GSTtoggleTranslator (boole)
  if GSTranslatorAvailable then
    GSMasterOptions.useTranslator = boole
  elseif boole then
    print('|cffff0000' .. GNOME .. L[":|r The Sequence Translator allows you to use GS-E on other languages than enUS.  It will translate sequences to match your language.  If you also have the Sequence Editor you can translate sequences between languages.  The GS-E Sequence Translator is available on curse.com"])
  else
    GSMasterOptions.useTranslator = boole
  end
  StaticPopup_Show ("GSEConfirmReloadUI")
end

LibStub("AceConfig-3.0"):RegisterOptionsTable("GSSE", OptionsTable, {"gse"})
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GSSE", "|cffff0000GS-E:|r Gnome Sequencer - Enhanced")
