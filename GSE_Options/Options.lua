local GNOME, _ = ...
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

local function FormatSequenceNames(names)
    local returnstring = ""
    for _, v in ipairs(names) do
        returnstring = returnstring .. " - " .. v .. ",\n"
    end
    returnstring = returnstring:sub(1, -3)
    return returnstring
end

function GSE.GetOptionsTable()
    local OptionsTable = {
        type = "group",
        name = "|cffff0000GSE:|r " .. L["Options"],
        args = {
            troubleshooting = {
                name = L["Troubleshooting"],
                desc = L["Common Solutions to game quirks that seem to affect some people."],
                type = "group",
                order = 5,
                args = {
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
                            "This setting is a common setting used by all WoW mods.  If affects how your action buttons respond.  With this on the react when you hit the button.  With them off they react when you let them go.  In GSE's case this setting has to be off for Actionbar Overrides to work."
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
                            C_CVar.SetCVar("ActionButtonUseKeyDown", setting)
                        end,
                        get = function(info)
                            local setting
                            setting = C_CVar.GetCVar("ActionButtonUseKeyDown")

                            if tonumber(setting) == 1 then
                                return true
                            else
                                return false
                            end
                        end,
                        order = 541
                    },
                    buttonsettingstitle = {
                        type = "header",
                        name = L["Button Settings"],
                        order = 550
                    },
                    disableLAB = {
                        name = L["Use MultiClick Buttons"],
                        desc = L[
                            "GSE Sequences are converted to a button that responds to 'Clicks' or Keyboard keypresses (WoW calls these Hardware Events).  \n\nWhen you use a KeyBind with a sequence, WoW sends two hardware events each time. With this setting on, GSE then interprets these two clicks as one and advances your sequence one step.  With this off it would advance two steps.  \n\nIn comparison Actionbar Overrides and '/click SEQUENCE' macros only sends one hardware Event.  If you primarily use Keybinds over Actionbar Overrides over Keybinds you want this set to false."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.Multiclick = val
                            StaticPopup_Show("GSE_ConfirmReloadUIDialog")
                        end,
                        get = function(info)
                            return GSEOptions.Multiclick
                        end,
                        order = 551
                    },
                    disableExeperimental = {
                        type = "header",
                        name = L["Keybinding Tools"],
                        order = 560
                    },
                    printKeyPressModifiers = {
                        name = L["Print Active Modifiers on Click"],
                        desc = L[
                            "Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."
                        ],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.DebugPrintModConditionsOnKeyPress = val
                            StaticPopup_Show("GSE_ConfirmReloadUIDialog")
                        end,
                        get = function(info)
                            return GSEOptions.DebugPrintModConditionsOnKeyPress
                        end,
                        order = 561
                    },
                    showSequenceIcons = {
                        name = L["Show Sequence Icons"],
                        desc = L["Show the Sequence Icon Preview Frame"],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.SequenceIconFrame.Enabled = val
                            if not val then
                                GSE.SequenceIconFrame:Hide()
                            else
                                GSE.SequenceIconFrame:Show()
                            end
                        end,
                        get = function(info)
                            return GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Enabled or false
                        end,
                        order = 562
                    },
                    showSequenceModifiers = {
                        name = L["Show Sequence Modifiers"],
                        desc = L["Show the Modifiers (eg Shift, Alt, Ctrl) and Buttons (eg Left Mousebutton) that were seen by the GSE sequence at the click/press it was triggered from."],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.SequenceIconFrame.ShowIconModifiers = val
                        end,
                        get = function(info)
                            return GSEOptions.SequenceIconFrame.ShowIconModifiers
                        end,
                        order = 563
                    },
                    showSequenceName = {
                        name = L["Show Sequence Name"],
                        desc = L["Show the Name of the Sequence"],
                        type = "toggle",
                        set = function(info, val)
                            GSEOptions.SequenceIconFrame.ShowSequenceName = val
                        end,
                        get = function(info)
                            return GSEOptions.SequenceIconFrame.ShowSequenceName
                        end,
                        order = 563
                    },
                    IconSize = {
                        name = L["Preview Icon Size"],
                        desc = L["Default is 64 pixels."],
                        type = "input",
                        set = function(info, val)
                            val = tonumber(val)
                            GSEOptions.SequenceIconFrame.IconSize = val
                            GSE.IconFrameResize(val)
                        end,
                        get = function(info)
                            return GSEOptions.SequenceIconFrame.IconSize or "64"
                        end,
                        order = 565
                    },
                    defaultImportAction = {
                        name = L["Icon Preview Orientation"],
                        desc = L["Horizontal or Vertical Layout"],
                        type = "select",
                        style = "radio",
                        values = {
                            ["HORIZONTAL"] = L["Horizontal"],
                            ["VERTICAL"] = L["Vertical"]
                        },
                        set = function(info, val)
                            GSEOptions.SequenceIconFrame.Orientation = val
                        end,
                        get = function(info)
                            return GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Orientation or "HORIZONTAL"
                        end,
                        order = 564
                    }
                    -- disableExeperimental = {
                    --     type = "header",
                    --     name = L["Experimental Features"],
                    --     order = 550
                    -- }
                }
            },
            colour = {
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
            plugins = {
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
                            "GSE allows plugins to load Collections as plugins.  You can reload a collection by pressing the button below."
                        ]
                    }
                }
            },
            windowSize = {
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
                            return tostring(GSEOptions.editorWidth) and tostring(GSEOptions.editorWidth) or "700"
                        end,
                        order = 12
                    },
                    menutitle = {
                        type = "header",
                        name = L["Variables"],
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
                    macrotitle = {
                        type = "header",
                        name = L["Macros"],
                        order = 16
                    },
                    macroHeight = {
                        name = L["Default Menu Height"],
                        desc = L["How many pixels high should the Menu start at.  Defaults to 500"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 500 then
                                GSEOptions.macroHeight = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.macroHeight and tostring(GSEOptions.menuHeight) or "500")
                        end,
                        order = 17
                    },
                    macroWidth = {
                        name = L["Default Menu Width"],
                        desc = L["How many pixels wide should the Menu start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 700 then
                                GSEOptions.macroWidth = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.macroWidth and tostring(GSEOptions.menuWidth) or "700")
                        end,
                        order = 18
                    },
                    keybindtitle = {
                        type = "header",
                        name = L["Keybindings"],
                        order = 19
                    },
                    keybindHeight = {
                        name = L["Default Keybinding Height"],
                        desc = L["How many pixels high should Keybindings start at.  Defaults to 500"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 500 then
                                GSEOptions.keybindingHeight = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.keybindingHeight and tostring(GSEOptions.keybindingHeight) or "500")
                        end,
                        order = 20
                    },
                    keybindWidth = {
                        name = L["Default Keybinding Width"],
                        desc = L["How many pixels wide should Keybinding start at.  Defaults to 700"],
                        type = "input",
                        set = function(info, val)
                            if tonumber(val) >= 700 then
                                GSEOptions.keybindingWidth = tonumber(val)
                            end
                        end,
                        get = function(info)
                            return (GSEOptions.keybindingWidth and tostring(GSEOptions.keybindingWidth) or "500")
                        end,
                        order = 21
                    },
                    debugtitle = {
                        type = "header",
                        name = L["Sequence Debugger"],
                        order = 22
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
                        order = 23
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
                        order = 24
                    }
                }
            },
            about = {
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
                            "GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community."
                        ],
                        order = 20,
                        image = Statics.Icons.Logo,
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
                    support = {
                        type = "execute",
                        name = L["GSE Discord"],
                        order = 24,
                        image = Statics.Icons.Discord,
                        imageWidth = 120,
                        imageHeight = 120,
                        func = function()
                            StaticPopupDialogs["GSE_SEQUENCEHELP"].url = "https://discord.gg/yUS9R4ZXZA"
                            StaticPopup_Show("GSE_SEQUENCEHELP")
                        end
                    },
                    issues = {
                        type = "execute",
                        name = L["Report an Issue"],
                        order = 25,
                        image = Statics.Icons.GitHub,
                        imageWidth = 120,
                        imageHeight = 120,
                        func = function()
                            StaticPopupDialogs["GSE_SEQUENCEHELP"].url =
                                "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/issues"
                            StaticPopup_Show("GSE_SEQUENCEHELP")
                        end
                    },
                    patreonlink = {
                        type = "execute",
                        name = L["Support GSE"],
                        order = 26,
                        image = Statics.Icons.Patreon,
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
            }
        }
    }
    if GSE.Developer then
        OptionsTable.args.debug = {
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
                title6 = {
                    type = "header",
                    name = L["Enable Debug for the following Modules"],
                    order = 30
                }
            }
        }
        local ord = 30
        for k, _ in pairs(Statics.DebugModules) do
            ord = ord + 1
            OptionsTable.args.debug.args[k] = {
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
    end
    local ord = 900
    -- Add Dynamic Content Container
    if not GSE.isEmpty(GSE.AddInPacks) then
        for _, v in pairs(GSE.AddInPacks) do
            ord = ord + 1
            OptionsTable.args.plugins.args[v.Name] = {
                name = C_AddOns.GetAddOnMetadata(v.Name, "Title") and C_AddOns.GetAddOnMetadata(v.Name, "Title") or
                    v.Name,
                desc = C_AddOns.GetAddOnMetadata(v.Name, "Notes") and
                    C_AddOns.GetAddOnMetadata(v.Name, "Notes") ..
                        "\n\n" ..
                            C_AddOns.GetAddOnMetadata(v.Name, "Author") ..
                                "\n" .. C_AddOns.GetAddOnMetadata(v.Name, "Version") or
                    string.format(L["Addin Version %s contained versions for the following sequences:"], v.Name) ..
                        string.format("\n%s", FormatSequenceNames(v.SequenceNames)),
                type = "execute",
                func = function(info, val)
                    GSE:SendMessage(Statics.ReloadMessage, v.Name)
                end,
                order = ord
            }
        end
    end

    return OptionsTable
end

local addonName = "|cFFFFFFFFGS|r|cFF00FFFFE|r"
local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")
local modoptions = GSE.GetOptionsTable()

local registered = false

local function createBlizzOptions()

    -- Troubleshooting
    config:RegisterOptionsTable(addonName .. "-Troubleshooting", modoptions.args.troubleshooting)
    dialog:AddToBlizOptions(addonName .. "-Troubleshooting", modoptions.args.troubleshooting.name, GSE.MenuCategoryID)

    -- colour
    config:RegisterOptionsTable(addonName .. "-Colour", modoptions.args.colour)
    dialog:AddToBlizOptions(addonName .. "-Colour", modoptions.args.colour.name, GSE.MenuCategoryID)

    -- Plugins
    config:RegisterOptionsTable(addonName .. "-Plugins", modoptions.args.plugins)
    dialog:AddToBlizOptions(addonName .. "-Plugins", modoptions.args.plugins.name, GSE.MenuCategoryID)

    config:RegisterOptionsTable(addonName .. "-WindowSizes", modoptions.args.windowSize)
    dialog:AddToBlizOptions(addonName .. "-WindowSizes", modoptions.args.windowSize.name, GSE.MenuCategoryID)

    if GSE.Developer then
        -- about
        config:RegisterOptionsTable(addonName .. "-Debug", modoptions.args.debug)
        dialog:AddToBlizOptions(addonName .. "-Debug", modoptions.args.debug.name, GSE.MenuCategoryID)
    end
end

function GSE:CreateConfigPanels()
    if not registered then
        modoptions.args.about.args.patrons = {
            type = "description",
            name = table.concat(Statics.Patrons, ", "),
            order = 32
        }
        config:RegisterOptionsTable(addonName, modoptions.args.about)
        local _, catid = dialog:AddToBlizOptions(addonName, addonName)

        registered = true
        GSE.MenuCategoryID = catid
        local category = Settings.GetCategory(catid)

        local generalOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["General"])

        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["General Options"] , ["tooltip"]= L["General"] }))
        end
        -- Hide Minimap icon
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "minimapIcon", "hide", GSEOptions.showMiniMap, Settings.VarType.Boolean, L["Hide Minimap Icon"], true)
            setting:SetValueChangedCallback(function ()
                if GSE.LDB then
                    GSE.MiniMapControl(GSEOptions.showMiniMap.hide)
                end
            end)
            Settings.CreateCheckbox(generalOptions, setting, L["Hide Minimap Icon for LibDataBroker (LDB) data text."])
        end
        -- Show Other Users
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showothergseusersintooltip", "showGSEUsers", GSEOptions, Settings.VarType.Boolean, L["Show GSE Users in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."])
        end
        -- Show OOC Queue
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showoocqueueintooltip", "showGSEoocqueue", GSEOptions, Settings.VarType.Boolean, L["Show OOC Queue in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."])
        end
        -- Reset OOC Queue
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "resetOOC", "resetOOC", GSEOptions, Settings.VarType.Boolean, L["Reset Sequences when out of combat"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Resets sequences back to the initial state when out of combat."])
        end
        -- Hide Login Message
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "hideLogin", "HideLoginMessage", GSEOptions, Settings.VarType.Boolean, L["Hide Login Message"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Hides the message that GSE is loaded."])
        end
        -- Actionbar Override Popup (Patron only, requires GSE_QoL)
        if (GSE.Patron or GSE.Developer) and C_AddOns.IsAddOnLoaded("GSE_QoL") then
            local setting = Settings.RegisterAddOnSetting(generalOptions, "actionbaroverpopup", "actionBarOverridePopup", GSEOptions, Settings.VarType.Boolean, L["Enable Actionbar Override Popup"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."])
        end
        -- Hide Login Message
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "UseVerboseExportFormat", "DefaultHumanReadableExportFormat", GSEOptions, Settings.VarType.Boolean, L["Create Human Readable Exports"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["When exporting from GSE create a descriptive export for Discord/Discource forums."])
        end
        ---- OOC Queue Delay
        do
            local function GetValue()
                return GSEOptions.OOCQueueDelay or 7
            end

            local function SetValue(value)
                GSEOptions.OOCQueueDelay = value
            end

            local setting = Settings.RegisterProxySetting(generalOptions, "defaultOOCTimerDelay", Settings.VarType.Number, L["OOC Queue Delay"], 7, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(1, 60, 1)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(generalOptions, setting, options, L["The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."])
        end

        ---- externalMillisecondClickRate
        do
            if GSE.Patron or GSE.Developer then
                local function GetValue()
                    return GSEOptions.msClickRate or 250
                end

                local function SetValue(value)
                    GSEOptions.msClickRate = value
                end

                local setting = Settings.RegisterProxySetting(generalOptions, "msClickRate", Settings.VarType.Number, L["MS Click Rate"], 250, GetValue, SetValue)
                local options = Settings.CreateSliderOptions(100, 1000, 1)
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                Settings.CreateSlider(generalOptions, setting, options, L["The milliseconds being used in key click delay."])
            end
        end
        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Filter Sequence Selection"], ["tooltip"]= L["Filter Sequence Selection"]}))
        end
        -- Show All Sequences
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showAllMacros", Statics.All, GSEOptions.filterList, Settings.VarType.Boolean, L["Show All Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Resets sequences back to the initial state when out of combat."])
        end
        -- showClassMacros
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showClassMacros", Statics.Class, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Class Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."])
        end
        -- HshowGlobalMacros
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showGlobalMacros", Statics.Global, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Global Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["This shows the Global Sequences available as well as those for your class."])
        end
        -- showCurrentSpells
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showCurrentSpells", "showCurrentSpells", GSEOptions, Settings.VarType.Boolean, L["Show Current Spells"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."])
        end

        -- Character Specific Settings

        do
            local CharOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Character"])


            -- Reset OOC Queue
            do
                local setting = Settings.RegisterAddOnSetting(CharOptions, "charresetOOC", "resetOOC", GSE_C, Settings.VarType.Boolean, L["Reset Sequences when out of combat"], true)
                Settings.CreateCheckbox(CharOptions, setting, L["Resets sequences back to the initial state when out of combat."])
            end

            ---- externalMillisecondClickRate
            do
                if GSE.Patron or GSE.Developer then
                    local function GetValue()
                        return GSE_C.msClickRate or 250
                    end

                    local function SetValue(value)
                        GSE_C.msClickRate = value
                    end

                    local setting = Settings.RegisterProxySetting(CharOptions, "charmsClickRate", Settings.VarType.Number, L["MS Click Rate"], 250, GetValue, SetValue)
                    local options = Settings.CreateSliderOptions(100, 1000, 1)
                    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                    Settings.CreateSlider(CharOptions, setting, options, L["The milliseconds being used in key click delay."])
                end
            end
        end

        do
            local ResetOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Sequence Reset"])

            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Mouse Buttons."] , ["tooltip"]= L["These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] }))
            end
            -- Reset OOC Queue
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftButton", "LeftButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightButton", "RightButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetMiddleButton", "MiddleButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Middle Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetButton4", "Button4", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Mouse Button 4"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetButton5", "Button5", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Mouse Button 5"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Alt Keys."], ["tooltip"]= L["Alt Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyAltKey", "Alt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftAltKey", "LeftAlt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightAltKey", "RightAlt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Control Keys."], ["tooltip"]= L["Control Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyControlKey", "Control", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftControlKey", "LeftControl", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightControlKey", "RightControl", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Shift Keys."], ["tooltip"]= L["Shift Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyShiftKey", "Shift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftShiftKey", "LeftShift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightShiftKey", "RightShift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
        end

        createBlizzOptions()

    end

end
GSE:CreateConfigPanels()

