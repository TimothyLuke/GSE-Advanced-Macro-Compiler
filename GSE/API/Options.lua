local GNOME, _ = ...
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

function GSE.GetOptionsTable()
    local OptionsTable = {
        type = "group",
        name = "|cffff0000GSE:|r " .. L["Options"],
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
                    minimapIcon = {
                        name = L["Hide Minimap Icon"],
                        desc = L["Hide Minimap Icon for LibDataBroker (LDB) data text."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.showMiniMap.hide = val
                            if GSE.LDB then
                                GSE.MiniMapControl(GSEOptions.showMiniMap.hide)
                            end
                        end,
                        get = function(info)
                            return GSEOptions.showMiniMap.hide
                        end,
                        order = 199
                    },
                    showothergseusersintooltip = {
                        name = L["Show GSE Users in LDB"],
                        desc = L[
                            "GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.showGSEUsers = val
                        end,
                        get = function(info)
                            return GSEOptions.showGSEUsers
                        end,
                        order = 200
                    },
                    showoocqueueintooltip = {
                        name = L["Show OOC Queue in LDB"],
                        desc = L[
                            "GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.showGSEoocqueue = val
                        end,
                        get = function(info)
                            return GSEOptions.showGSEoocqueue
                        end,
                        order = 201
                    },
                    hideLogin = {
                        name = L["Hide Login Message"],
                        desc = L["Hides the message that GSE is loaded."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.HideLoginMessage = val
                        end,
                        get = function(info)
                            return GSEOptions.HideLoginMessage
                        end,
                        order = 202
                    },
                    promptSamples = {
                        name = L["Prompt Samples"],
                        desc = L["When you log into a class without any macros, prompt to load the sample macros."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.PromptSample = val
                        end,
                        get = function(info)
                            return GSEOptions.PromptSample
                        end,
                        order = 208
                    },
                    resetOOC = {
                        name = L["Reset Macro when out of combat"],
                        desc = L["Resets macros back to the initial state when out of combat."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.resetOOC = val
                        end,
                        get = function(info)
                            return GSEOptions.resetOOC
                        end,
                        order = 300
                    },
                    deleteOrphanLogout = {
                        name = L["Delete Orphaned Macros on Logout"],
                        desc = L[
                            "As GSE is updated, there may be left over macros that no longer relate to sequences.  This will check for these automatically on logout.  Alternatively this check can be run via /gse cleanorphans"
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.deleteOrphansOnLogout = val
                        end,
                        get = function(info)
                            return GSEOptions.deleteOrphansOnLogout
                        end,
                        order = 301
                    },
                    overflowPersonalMacros = {
                        name = L["Use Global Account Macros"],
                        desc = L[
                            "When creating a macro, if there is not a personal character macro space, create an account wide macro."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.overflowPersonalMacros = val
                        end,
                        get = function(info)
                            return GSEOptions.overflowPersonalMacros
                        end,
                        order = 302
                    },
                    autocreateclassstub = {
                        name = L["Auto Create Class Macro Stubs"],
                        desc = L[
                            "When loading or creating a sequence, if it is a macro of the same class automatically create the Macro Stub"
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.autoCreateMacroStubsClass = val
                        end,
                        get = function(info)
                            return GSEOptions.autoCreateMacroStubsClass
                        end,
                        order = 303
                    },
                    autocreateglobalstub = {
                        name = L["Auto Create Global Macro Stubs"],
                        desc = L[
                            "When loading or creating a sequence, if it is a global or the macro has an unknown specID automatically create the Macro Stub in Account Macros"
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.autoCreateMacroStubsGlobal = val
                        end,
                        get = function(info)
                            return GSEOptions.autoCreateMacroStubsGlobal
                        end,
                        order = 304
                    },
                    useQuestionMark = {
                        name = L["Set Default Icon QuestionMark"],
                        desc = L[
                            "By setting the default Icon for all macros to be the QuestionMark, the macro button on your toolbar will change every key hit."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.setDefaultIconQuestionMark = val
                        end,
                        get = function(info)
                            return GSEOptions.setDefaultIconQuestionMark
                        end,
                        order = 310
                    },
                    defaultImportAction = {
                        name = L["Default Import Action"],
                        desc = L[
                            "When GSE imports a macro and it already exists locally and has local edits, what do you want the default action to be.  Merge - Add the new MacroVersions to the existing Macro.  Replace - Replace the existing macro with the new version. Ignore - ignore updates.  This default action will set the default on the Compare screen however if the GUI is not available this will be the action taken."
                        ],
                        type = "select",
                        style = "radio",
                        values = {
                            ["MERGE"] = L["Merge"],
                            ["REPLACE"] = L["Replace"],
                            ["IGNORE"] = L["Ignore"]
                        },
                        set = function(info, val)
                            GSEOptions.DefaultImportAction = val
                        end,
                        get = function(info)
                            return GSEOptions.DefaultImportAction
                        end,
                        order = 320
                    },
                    fullBlockDebug = {
                        name = L["Show Full Block Execution"],
                        desc = L[
                            "When debugging the output of a sequence, show the full executed block in the Debugger Output."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.showFullBlockDebug = val
                        end,
                        get = function(info)
                            return GSEOptions.showFullBlockDebug and GSEOptions.showFullBlockDebug or false
                        end,
                        order = 330
                    },
                    UseVerboseExportFormat = {
                        name = L["Use WLM Export Sequence Format"],
                        desc = L["When exporting a sequence create a stub entry to import for WLM's Website."],
                        --            guiHidden = true,
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.UseWLMExportFormat = val
                        end,
                        get = function(info)
                            return GSEOptions.UseWLMExportFormat
                        end,
                        order = 300
                    },
                    MSFiltertitle1 = {
                        type = "header",
                        name = L["Millisecond click settings"],
                        order = 380
                    },
                    externalMillisecondClickRate = {
                        name = L["MS Click Rate"],
                        desc = L["The milliseconds being used in key click delay."],
                        type = "input",
                        set = function(info, val)
                            GSEOptions.msClickRate = tonumber(val)
                        end,
                        get = function(info)
                            return GSEOptions.msClickRate and tostring(GSEOptions.msClickRate) or "250"
                        end,
                        order = 385
                    },
                    defaultOOCTimerDelay = {
                        name = L["OOC Queue Delay"],
                        desc = L[
                            "The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates macros.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."
                        ],
                        type = "input",
                        set = function(info, val)
                            val = tonumber(val)
                            if val < 1 then
                                val = 7
                            end
                            GSEOptions.OOCQueueDelay = val
                        end,
                        get = function(info)
                            return GSEOptions.OOCQueueDelay and tostring(GSEOptions.OOCQueueDelay) or "7"
                        end,
                        order = 386
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
                        set = function(info, val)
                            GSEOptions.filterList["All"] = val
                        end,
                        get = function(info)
                            return GSEOptions.filterList["All"]
                        end,
                        order = 410
                    },
                    showClassMacros = {
                        name = L["Show Class Macros in Editor"],
                        desc = L[
                            "By setting this value the Sequence Editor will show every macro for your class.  Turning this off will only show the class macros for your current specialisation."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.filterList["Class"] = val
                        end,
                        get = function(info)
                            return GSEOptions.filterList["Class"]
                        end,
                        order = 420
                    },
                    showGlobalMacros = {
                        name = L["Show Global Macros in Editor"],
                        desc = L["This shows the Global Macros available as well as those for your class."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.filterList["Global"] = val
                        end,
                        get = function(info)
                            return GSEOptions.filterList["Global"]
                        end,
                        order = 430
                    },
                    createGlobalMacroButtons = {
                        name = L["Create buttons for Global Macros"],
                        desc = L[
                            "Global Macros are those that are valid for all classes.  GSE2 also imports unknown macros as Global.  This option will create a button for these macros so they can be called for any class.  Having all macros in this space is a performance loss hence having them saved with a the right specialisation is important."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.CreateGlobalButtons = val
                        end,
                        get = function(info)
                            return GSEOptions.CreateGlobalButtons
                        end,
                        order = 440
                    },
                    showCurrentSpells = {
                        name = L["Show Current Spells"],
                        desc = L[
                            "GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.showCurrentSpells = val
                        end,
                        get = function(info)
                            return GSEOptions.showCurrentSpells
                        end,
                        order = 441
                    },
                    title2 = {
                        type = "header",
                        name = L["Gameplay Options"],
                        order = 500
                    },
                    requireTarget = {
                        name = L["Require Target to use"],
                        desc = L[
                            "This option prevents macros firing unless you have a target. Helps reduce mistaken targeting of other mobs/groups when your target dies."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.requireTarget = val
                            GSE.PerformReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.requireTarget
                        end,
                        order = 510
                    },
                    hideUIErrors = {
                        name = L["Prevent UI Errors"],
                        desc = L[
                            "This option hides text error popups and dialogs and stack traces ingame.  This is the equivalent of /script UIErrorsFrame:Hide() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.hideUIErrors = val
                            GSE.PerformReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.hideUIErrors
                        end,
                        order = 530
                    },
                    clearUIErrors = {
                        name = L["Clear Errors"],
                        desc = L[
                            "This option clears errors and stack traces ingame.  This is the equivalent of /run UIErrorsFrame:Clear() in a KeyRelease.  Turning this on will trigger a Scam warning about running custom scripts."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.clearUIErrors = val
                            GSE.PerformReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.clearUIErrors
                        end,
                        order = 540
                    },
                    use11 = {
                        name = L["Use First Ring in KeyRelease"],
                        desc = L[
                            "Incorporate the first ring slot into the KeyRelease. This is the equivalent of /use [combat] 11 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use11 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use11
                        end,
                        order = 550
                    },
                    use12 = {
                        name = L["Use Second Ring in KeyRelease"],
                        desc = L[
                            "Incorporate the second ring slot into the KeyRelease. This is the equivalent of /use [combat] 12 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use12 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use12
                        end,
                        order = 560
                    },
                    use13 = {
                        name = L["Use First Trinket in KeyRelease"],
                        desc = L[
                            "Incorporate the first trinket slot into the KeyRelease. This is the equivalent of /use [combat] 13 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use13 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use13
                        end,
                        order = 570
                    },
                    use14 = {
                        name = L["Use Second Trinket in KeyRelease"],
                        desc = L[
                            "Incorporate the second trinket slot into the KeyRelease. This is the equivalent of /use [combat] 14 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use14 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use14
                        end,
                        order = 580
                    },
                    use2 = {
                        name = L["Use Neck Item in KeyRelease"],
                        desc = L[
                            "Incorporate the neck slot into the KeyRelease. This is the equivalent of /use [combat] 2 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use2 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use2
                        end,
                        order = 591
                    },
                    use6 = {
                        name = L["Use Belt Item in KeyRelease"],
                        desc = L[
                            "Incorporate the belt slot into the KeyRelease. This is the equivalent of /use [combat] 5 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use6 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use6
                        end,
                        order = 592
                    },
                    use1 = {
                        name = L["Use Head Item in KeyRelease"],
                        desc = L[
                            "Incorporate the Head slot into the KeyRelease. This is the equivalent of /use [combat] 1 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.use1 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            return GSEOptions.use1
                        end,
                        order = 593
                    }
                }
            },
            characterOptionsTab = {
                name = L["Character"],
                desc = L["Character Specific Options which override the normal account settings."],
                type = "group",
                order = 2,
                args = {
                    title1 = {
                        type = "header",
                        name = L["General Options"],
                        order = 100
                    },
                    resetOOC = {
                        name = L["Reset Macro when out of combat"],
                        desc = L["Resets macros back to the initial state when out of combat."],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.resetOOC = val
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.resetOOC and GSE_C.resetOOC or GSEOptions.resetOOC
                        end,
                        order = 110
                    },
                    requireTarget = {
                        name = L["Require Target to use"],
                        desc = L[
                            "This option prevents macros firing unless you have a target. Helps reduce mistaken targeting of other mobs/groups when your target dies."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.requireTarget = val
                            GSE.PerformReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.requireTarget and GSE_C.requireTarget or GSEOptions.requireTarget
                        end,
                        order = 120
                    },
                    use11 = {
                        name = L["Use First Ring in KeyRelease"],
                        desc = L[
                            "Incorporate the first ring slot into the KeyRelease. This is the equivalent of /use [combat] 11 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use11 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use11 and GSE_C.use11 or GSEOptions.use11
                        end,
                        order = 130
                    },
                    use12 = {
                        name = L["Use Second Ring in KeyRelease"],
                        desc = L[
                            "Incorporate the second ring slot into the KeyRelease. This is the equivalent of /use [combat] 12 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use12 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use12 and GSE_C.use12 or GSEOptions.use12
                        end,
                        order = 140
                    },
                    use13 = {
                        name = L["Use First Trinket in KeyRelease"],
                        desc = L[
                            "Incorporate the first trinket slot into the KeyRelease. This is the equivalent of /use [combat] 13 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use13 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end

                            return GSE_C.use13 and GSE_C.use13 or GSEOptions.use13
                        end,
                        order = 150
                    },
                    use14 = {
                        name = L["Use Second Trinket in KeyRelease"],
                        desc = L[
                            "Incorporate the second trinket slot into the KeyRelease. This is the equivalent of /use [combat] 14 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use14 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use14 and GSE_C.use14 or GSEOptions.use14
                        end,
                        order = 160
                    },
                    use2 = {
                        name = L["Use Neck Item in KeyRelease"],
                        desc = L[
                            "Incorporate the neck slot into the KeyRelease. This is the equivalent of /use [combat] 2 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use2 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use2 and GSE_C.use2 or GSEOptions.use2
                        end,
                        order = 170
                    },
                    use6 = {
                        name = L["Use Belt Item in KeyRelease"],
                        desc = L[
                            "Incorporate the belt slot into the KeyRelease. This is the equivalent of /use [combat] 5 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use6 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use6 and GSE_C.use6 or GSEOptions.use6
                        end,
                        order = 180
                    },
                    use1 = {
                        name = L["Use Head Item in KeyRelease"],
                        desc = L[
                            "Incorporate the Head slot into the KeyRelease. This is the equivalent of /use [combat] 1 in a KeyRelease."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSE_C.use1 = val
                            GSE.ReloadSequences()
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.use1 and GSE_C.use1 or GSEOptions.use1
                        end,
                        order = 190
                    },
                    MSFiltertitle1 = {
                        type = "header",
                        name = L["Millisecond click settings"],
                        order = 380
                    },
                    externalMillisecondClickRate = {
                        name = L["MS Click Rate"],
                        desc = L["The milliseconds being used in key click delay."],
                        type = "input",
                        set = function(info, val)
                            GSE_C.msClickRate = val
                        end,
                        get = function(info)
                            if GSE.isEmpty(GSE_C) then
                                GSE_C = {}
                            end
                            return GSE_C.msClickRate and GSE_C.msClickRate or ""
                        end,
                        order = 385
                    }
                }
            },
            macroResetTab = {
                name = L["Macro Reset"],
                desc = L[
                    "These options combine to allow you to reset a macro while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."
                ],
                order = 3,
                type = "group",
                args = {
                    resetbuttontitle = {
                        type = "header",
                        name = L["Mouse Buttons."],
                        order = 550
                    },
                    resetLeftButton = {
                        name = L["Left Mouse Button"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["LeftButton"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["LeftButton"] = value
                        end,
                        order = 551
                    },
                    resetRightButton = {
                        name = L["Right Mouse Button"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["RightButton"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["RightButton"] = value
                        end,
                        order = 552
                    },
                    resetMiddleButton = {
                        name = L["Middle Mouse Button"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["MiddleButton"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["MiddleButton"] = value
                        end,
                        order = 553
                    },
                    resetButton4 = {
                        name = L["Mouse Button 4"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["Button4"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["Button4"] = value
                        end,
                        order = 554
                    },
                    resetButton5 = {
                        name = L["Mouse Button 5"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["Button5"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["Button5"] = value
                        end,
                        order = 555
                    },
                    resetalttitle = {
                        type = "header",
                        name = L["Alt Keys."],
                        order = 560
                    },
                    resetAnyAltKey = {
                        name = L["Any Alt Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["Alt"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["Alt"] = value
                        end,
                        order = 561
                    },
                    resetLeftAltKey = {
                        name = L["Left Alt Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["LeftAlt"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["LeftAlt"] = value
                        end,
                        order = 562
                    },
                    resetRightAltKey = {
                        name = L["Right Alt Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["RightAlt"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["RightAlt"] = value
                        end,
                        order = 563
                    },
                    resetcontroltitle = {
                        type = "header",
                        name = L["Control Keys."],
                        order = 570
                    },
                    resetAnyControlKey = {
                        name = L["Any Control Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["Control"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["Control"] = value
                        end,
                        order = 571
                    },
                    resetLeftControlKey = {
                        name = L["Left Control Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["LeftControl"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["LeftControl"] = value
                        end,
                        order = 572
                    },
                    resetRightControlKey = {
                        name = L["Right Control Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["RightControl"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["RightControl"] = value
                        end,
                        order = 573
                    },
                    resetshifttitle = {
                        type = "header",
                        name = L["Shift Keys."],
                        order = 580
                    },
                    resetAnyShiftKey = {
                        name = L["Any Shift Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["Shift"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["Shift"] = value
                        end,
                        order = 581
                    },
                    resetLeftShiftKey = {
                        name = L["Left Shift Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["LeftShift"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["LeftShift"] = value
                        end,
                        order = 582
                    },
                    resetRightShiftKey = {
                        name = L["Right Shift Key"],
                        type = "toggle",
                        get = function()
                            return GSEOptions.MacroResetModifiers["RightShift"]
                        end,
                        set = function(key, value)
                            GSEOptions.MacroResetModifiers["RightShift"] = value
                        end,
                        order = 583
                    }
                }
            },
            troubleshootingTab = {
                name = L["Troubleshooting"],
                desc = L["Common Solutions to game quirks that seem to affect some people."],
                type = "group",
                order = 5,
                args = {
                    clearCommonKeyBindsTitle = {
                        type = "header",
                        name = L["Clear Common Keybindings"],
                        order = 500
                    },
                    clearCommonKeyBinds = {
                        name = L["Clear Keybindings"],
                        desc = L[
                            "This function will remove the SHIFT+N, ALT+N and CTRL+N keybindings for this character.  Useful if [mod:shift] etc conditions don't work in game."
                        ],
                        type = "execute",
                        func = function(info, val)
                            GSE.ClearCommonKeyBinds()
                        end,
                        order = 501
                    },
                    enablemacrostubupdatetitle = {
                        type = "header",
                        name = L["Update Macro Stubs."],
                        order = 520
                    },
                    virtualButtonSupport = {
                        name = L["Virtual Button Support"],
                        desc = L["This is needed for ConsolePort and BindPad."],
                        type = "toggle",
                        get = function()
                            return GSEOptions.virtualButtonSupport
                        end,
                        set = function(key, value)
                            GSEOptions.virtualButtonSupport = value
                        end,
                        order = 521
                    },
                    updatemacrobuttonstubs = {
                        name = L["Update Macro Stubs"],
                        desc = L[
                            "This function will update macro stubs to support listening to the options below.  This is required to be completed 1 time per character."
                        ],
                        type = "execute",
                        func = function(info, val)
                            GSE.UpdateMacroString()
                        end,
                        order = 522
                    },
                    spellCachetitle = {
                        type = "header",
                        name = L["Spell Cache Editor"],
                        order = 530
                    },
                    clearSpellCache = {
                        name = L["Clear Spell Cache"],
                        desc = L[
                            "This function will clear the spell cache and any mappings between individual spellIDs and spellnames.."
                        ],
                        type = "execute",
                        func = function(info, val)
                            GSESpellCache = {}
                            GSESpellCache["enUS"] = {}
                            if GSE.isEmpty(GSESpellCache[GetLocale()]) then
                                GSESpellCache[GetLocale()] = {}
                            end
                        end,
                        order = 531
                    },
                    editSpellCache = {
                        name = L["Edit Spell Cache"],
                        desc = L[
                            "This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames.."
                        ],
                        type = "execute",
                        func = function(info, val)
                            GSE.CheckGUI()
                            if GSE.UnsavedOptions["GUI"] then
                                GSE.GUIShowSpellCacheWindow()
                            else
                                GSE.Print(
                                    L["The GSE_GUI Module needs to be enabled to edit the spell cache."],
                                    L["Options"]
                                )
                            end
                        end,
                        order = 532
                    },
                    cvarsettingstitle = {
                        type = "header",
                        name = L["CVar Settings"],
                        order = 540
                    },
                    ActionButtonUseKeyDownCvar = {
                        name = L["ActionButtonUseKeyDown"],
                        desc = L[
                            "This CVAR makes WoW use your abilities when you press the key not when you release it.  To use GSE in its native configuration this needs to be checked."
                        ],
                        type = "toggle",
                        tristate = false,
                        set = function(_, val)
                            local setting
                            if val == true then
                                setting = 1
                            end
                            if val == false then
                                setting = 0
                            end
                            if GSE.GameMode > 7 then
                                C_CVar.SetCVar("ActionButtonUseKeyDown", setting)
                            else
                                SetCVar("ActionButtonUseKeyDown", setting)
                            end
                        end,
                        get = function(info)
                            local setting
                            if GSE.GameMode > 7 then
                                setting = C_CVar.GetCVar("ActionButtonUseKeyDown")
                            else
                                setting = GetCVar("ActionButtonUseKeyDown")
                            end

                            if tonumber(setting) == 1 then
                                return true
                            else
                                return false
                            end
                        end,
                        order = 541
                    },
                    forcecvarsettingstitle = {
                        type = "header",
                        name = L["Force ActionButtonUseKeyDown State"],
                        order = 550
                    },
                    CvarActionButtonState = {
                        type = "select",
                        name = L["Force CVar State"],
                        desc = L[
                            "Up forces GSE into ActionButtonUseKeyDown=0 while Down forces GSE into ActionButtonUseKeyDown=1"
                        ],
                        values = {
                            ["DONTFORCE"] = L["Don't Force"],
                            ["UP"] = L["KeyUp"],
                            ["DOWN"] = L["KeyDown"]
                        },
                        set = function(_, val)
                            local setting
                            GSEOptions.CvarActionButtonState = val
                            GSE.setActionButtonUseKeyDown()
                        end,
                        get = function(info)
                            return GSEOptions.CvarActionButtonState and GSEOptions.CvarActionButtonState or "DOWN"
                        end,
                        order = 552
                    }
                }
            },
            colourTab = {
                name = L["Colour"],
                desc = L["Colour and Accessibility Options"],
                type = "group",
                order = 5,
                args = {
                    ctitle1 = {
                        type = "header",
                        name = L["General Options"],
                        order = 100
                    },
                    titleColour = {
                        type = "color",
                        name = L["Title Colour"],
                        desc = L["Picks a Custom Colour for the Mod Names."],
                        order = 101,
                        hasAlpha = false,
                        get = function(info)
                            return GSE.GUIGetColour(GSEOptions.TitleColour)
                        end,
                        set = function(info, r, g, b, a)
                            GSEOptions.TitleColour =
                                string.format("|c%02x%02x%02x%02x", a * 255, r * 255, g * 255, b * 255)
                        end
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
                            GSEOptions.AuthorColour =
                                string.format("|c%02x%02x%02x%02x", 255, r * 255, g * 255, b * 255)
                        end
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
                            GSEOptions.CommandColour =
                                string.format("|c%02x%02x%02x%02x", 255, r * 255, g * 255, b * 255)
                        end
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
                            GSEOptions.EmphasisColour =
                                string.format("|c%02x%02x%02x%02x", 255, r * 255, g * 255, b * 255)
                        end
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
                            GSEOptions.NormalColour =
                                string.format("|c%02x%02x%02x%02x", 255, r * 255, g * 255, b * 255)
                        end
                    },
                    ctitle2 = {
                        type = "header",
                        name = L["Editor Colours"],
                        order = 200
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
                        end
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
                        end
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
                        end
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
                        end
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
                        end
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
                        end
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
                        end
                    },
                    stepColour = {
                        type = "color",
                        name = L["Step Functions"],
                        desc = L["Picks a Custom Colour to be used for StepFunctions."],
                        order = 280,
                        hasAlpha = false,
                        get = function(info)
                            return GSE.GUIGetColour(GSEOptions.EQUALS)
                        end,
                        set = function(info, r, g, b)
                            GSE.GUISetColour(GSEOptions.EQUALS, r, g, b)
                        end
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
                        end
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
                        end
                    }
                }
            },
            pluginsTab = {
                name = L["Plugins"],
                desc = L["GSE Plugins"],
                type = "group",
                order = 6,
                args = {
                    title3 = {
                        type = "header",
                        name = L["Registered Addons"],
                        order = 900
                    },
                    plugindesc = {
                        type = "description",
                        name = L[
                            "GSE allows plugins to load Macro Collections as plugins.  You can reload a collection by pressing the button below."
                        ]
                    }
                }
            },
            windowsizeTab = {
                name = L["Window Sizes"],
                desc = L["The default sizes of each window."],
                type = "group",
                order = 7,
                args = {
                    editortitle = {
                        type = "header",
                        name = L["Sequence Editor"],
                        order = 10
                    },
                    editorHeight = {
                        name = L["Default Editor Height"],
                        desc = L["How many pixels high should the Editor start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 500 then
                                GSEOptions.editorHeight = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return tostring(GSEOptions.editorHeight)
                        end,
                        order = 11
                    },
                    editorWidth = {
                        name = L["Default Editor Width"],
                        desc = L["How many pixels wide should the Editor start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 700 then
                                GSEOptions.editorWidth = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return tostring(GSEOptions.editorWidth)
                        end,
                        order = 12
                    },
                    menutitle = {
                        type = "header",
                        name = L["Sequence Menu"],
                        order = 13
                    },
                    menuHeight = {
                        name = L["Default Menu Height"],
                        desc = L["How many pixels high should the Menu start at.  Defaults to 500"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 500 then
                                GSEOptions.menuHeight = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.menuHeight and tostring(GSEOptions.menuHeight) or "500")
                        end,
                        order = 14
                    },
                    menuWidth = {
                        name = L["Default Menu Width"],
                        desc = L["How many pixels wide should the Menu start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 700 then
                                GSEOptions.menuWidth = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.menuWidth and tostring(GSEOptions.menuWidth) or "700")
                        end,
                        order = 15
                    },
                    debugtitle = {
                        type = "header",
                        name = L["Sequence Debugger"],
                        order = 16
                    },
                    debugHeight = {
                        name = L["Default Debugger Height"],
                        desc = L["How many pixels high should the Debuger start at.  Defaults to 500"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 500 then
                                GSEOptions.debugHeight = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.debugHeight and tostring(GSEOptions.debugHeight) or "500")
                        end,
                        order = 17
                    },
                    debugWidth = {
                        name = L["Default Debugger Width"],
                        desc = L["How many pixels wide should the Debugger start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 700 then
                                GSEOptions.debugWidth = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.debugWidth and tostring(GSEOptions.debugWidth) or "500")
                        end,
                        order = 18
                    }
                }
            },
            aboutTab = {
                name = L["About"],
                desc = L["About GSE"],
                type = "group",
                order = 8,
                args = {
                    -- aboutIcon = {
                    --   type = "description",
                    --   name = "",
                    --   image = "Interface\\Addons\\GSE_GUI\\GSE2_Logo_Dark_512.tga",
                    --   imageWidth = 100;
                    --   imageHeight = 100;
                    --   order = 5
                    -- },
                    title4 = {
                        type = "header",
                        name = L["History"],
                        order = 10
                    },
                    aboutDescription = {
                        type = "description",
                        name = L[
                            "GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write macros with it.  Check out https://wowlazymacros.com for the things that make this mod work.  Special thanks to Lutechi for creating this community."
                        ],
                        order = 20,
                        image = "Interface\\Addons\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.tga",
                        imageWidth = 120,
                        imageHeight = 120
                    },
                    versionHeader = {
                        type = "header",
                        name = L["Version"],
                        order = 21
                    },
                    versionDescription = {
                        type = "description",
                        name = "GSE: " .. GSE.VersionString,
                        order = 22
                    },
                    documentation = {
                        type = "execute",
                        name = L["Get Help"],
                        order = 25,
                        image = "Interface\\Addons\\GSE_GUI\\Assets\\github.tga",
                        imageWidth = 120,
                        imageHeight = 120,
                        func = function()
                            StaticPopupDialogs["GSE_SEQUENCEHELP"].url =
                                "https://github.com/TimothyLuke/GnomeSequencer-Enhanced/issues"
                            StaticPopup_Show("GSE_SEQUENCEHELP")
                        end
                    },
                    patreonlink = {
                        type = "execute",
                        name = L["Support GSE"],
                        order = 25,
                        image = "Interface\\Addons\\GSE_GUI\\Assets\\patreon.tga",
                        imageWidth = 120,
                        imageHeight = 120,
                        func = function()
                            StaticPopupDialogs["GSE_SEQUENCEHELP"].url = "https://www.patreon.com/TimothyLuke"
                            StaticPopup_Show("GSE_SEQUENCEHELP")
                        end
                    },
                    title5 = {
                        type = "header",
                        name = L["Supporters"],
                        order = 30
                    },
                    supportersDescription = {
                        type = "description",
                        name = L[
                            "The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."
                        ],
                        order = 31
                    }
                }
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
                    debug = {
                        name = L["Enable Mod Debug Mode"],
                        desc = L[
                            "This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.debug = val
                            GSE.PrintDebugMessage("Debug Mode Enabled", GNOME)
                        end,
                        get = function(info)
                            return GSEOptions.debug
                        end,
                        order = 10
                    },
                    title5 = {
                        type = "header",
                        name = L["Debug Output Options"],
                        order = 20
                    },
                    debugchat = {
                        name = L["Display debug messages in Chat Window"],
                        desc = L["This will display debug messages in the Chat window."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.sendDebugOutputToChatWindow = val
                        end,
                        get = function(info)
                            return GSEOptions.sendDebugOutputToChatWindow
                        end,
                        order = 21
                    },
                    sendDebugOutputToDebugOutput = {
                        name = L["Store Debug Messages"],
                        desc = L[
                            "Store output of debug messages in a Global Variable that can be referrenced by other mods."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.sendDebugOutputToDebugOutput = val
                        end,
                        get = function(info)
                            return GSEOptions.sendDebugOutputToDebugOutput
                        end,
                        order = 25
                    },
                    printKeyPressModifiers = {
                        name = L["Print KeyPress Modifiers on Click"],
                        desc = L[
                            "Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.DebugPrintModConditionsOnKeyPress = val
                        end,
                        get = function(info)
                            return GSEOptions.DebugPrintModConditionsOnKeyPress
                        end,
                        order = 26
                    },
                    title6 = {
                        type = "header",
                        name = L["Enable Debug for the following Modules"],
                        order = 30
                    }
                }
            }
        }
    }
    -- Add Dynamic Content Container

    local ord = 900
    for _, v in pairs(GSE.AddInPacks) do
        ord = ord + 1
        OptionsTable.args.pluginsTab.args[v.Name] = {
            name = v.Name,
            desc = string.format(L["Addin Version %s contained versions for the following macros:"], v.Name) ..
                string.format("\n%s", GSE.FormatSequenceNames(v.SequenceNames)),
            type = "execute",
            func = function(info, val)
                GSE:SendMessage(Statics.ReloadMessage, v.Name)
            end,
            order = ord
        }
    end

    ord = 30
    for k, _ in pairs(Statics.DebugModules) do
        ord = ord + 1
        OptionsTable.args.debugTab.args[k] = {
            name = k,
            desc = L["This will display debug messages for the "] .. k,
            type = "toggle",
            set = function(info, val)
                GSEOptions.DebugModules[k] = val
            end,
            get = function(info)
                return GSEOptions.DebugModules[k]
            end,
            order = ord
        }
    end

    ord = 31
    for k, v in ipairs(Statics.Patrons) do
        local pos = ord + k
        OptionsTable.args.aboutTab.args[v .. k] = {
            name = v,
            desc = v,
            type = "description",
            order = pos
        }
    end
    return OptionsTable
end

function GSE.ReportTargetProtection()
    local disabledstr = "disabled"
    if GSEOptions.requireTarget then
        disabledstr = "enabled"
    end
    return string.format(L["Target protection is currently %s"], disabledstr)
end

GSE.DebugProfile("Options")
