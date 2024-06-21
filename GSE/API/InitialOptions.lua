local GSE = GSE
local Statics = GSE.Static
GSE.DebugProfile("End Patrons")
-- These are overridden when the saved variables are loaded in
GSEOptions = {}

function GSE.resetMacroResetModifiers()
    GSEOptions.MacroResetModifiers = {}
    GSEOptions.MacroResetModifiers["LeftButton"] = false
    GSEOptions.MacroResetModifiers["RightButton"] = false
    GSEOptions.MacroResetModifiers["MiddleButton"] = false
    GSEOptions.MacroResetModifiers["Button4"] = false
    GSEOptions.MacroResetModifiers["Button5"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["Alt"] = false
    GSEOptions.MacroResetModifiers["LeftControl"] = false
    GSEOptions.MacroResetModifiers["RightControl"] = false
    GSEOptions.MacroResetModifiers["Control"] = false
    GSEOptions.MacroResetModifiers["LeftShift"] = false
    GSEOptions.MacroResetModifiers["RightShift"] = false
    GSEOptions.MacroResetModifiers["Shift"] = false
    GSEOptions.MacroResetModifiers["LeftAlt"] = false
    GSEOptions.MacroResetModifiers["RightAlt"] = false
    GSEOptions.MacroResetModifiers["AnyMod"] = false
end

function GSE.SetDefaultOptions()
    GSEOptions.saveAllMacrosLocal = true
    GSEOptions.initialised = true
    GSEOptions.deleteOrphansOnLogout = false
    GSEOptions.debug = false
    GSEOptions.sendDebugOutputToChat = nil
    GSEOptions.sendDebugOutputToChatWindow = false
    GSEOptions.sendDebugOutputToDebugOutput = false
    GSEOptions.setDefaultIconQuestionMark = true
    GSEOptions.TitleColour = "|cFFFF0000"
    GSEOptions.AuthorColour = "|cFF00D1FF"
    GSEOptions.CommandColour = "|cFF00FF00"
    GSEOptions.NormalColour = "|cFFFFFFFF"
    GSEOptions.EmphasisColour = "|cFFFFFF00"
    GSEOptions.KEYWORD = "|cff88bbdd"
    GSEOptions.UNKNOWN = "|cffff6666"
    GSEOptions.CONCAT = "|cffcc7777"
    GSEOptions.NUMBER = "|cffffaa00"
    GSEOptions.STRING = "|cff888888"
    GSEOptions.COMMENT = "|cff55cc55"
    GSEOptions.INDENT = "|cffccaa88"
    GSEOptions.EQUALS = "|cffccddee"
    GSEOptions.STANDARDFUNCS = "|cff55ddcc"
    GSEOptions.WOWSHORTCUTS = "|cffddaaff"
    GSEOptions.overflowPersonalMacros = false
    GSEOptions.RealtimeParse = false
    GSEOptions.ActiveSequenceVersions = {}
    GSEOptions.DisabledSequences = {}
    GSEOptions.DebugModules = {}

    GSEOptions.DebugModules[Statics.DebugModules["Translator"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Editor"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Viewer"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Storage"]] = false
    GSEOptions.DebugModules[Statics.DebugModules[Statics.SourceTransmission]] = false
    GSEOptions.DebugModules[Statics.DebugModules["API"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["GUI"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Versions"]] = false
    GSEOptions.DebugModules[Statics.DebugModules["Startup"]] = false

    GSEOptions.filterList = {}
    GSEOptions.filterList[Statics.Spec] = true
    GSEOptions.filterList[Statics.Class] = true
    GSEOptions.filterList[Statics.All] = false
    GSEOptions.filterList[Statics.Global] = true
    GSEOptions.autoCreateMacroStubsClass = true
    GSEOptions.autoCreateMacroStubsGlobal = false
    GSEOptions.resetOOC = true
    GSEOptions.DefaultDisabledMacroIcon = "Interface\\Icons\\INV_MISC_BOOK_08"
    GSEOptions.CreateGlobalButtons = false
    GSEOptions.HideLoginMessage = false
    GSEOptions.DebugPrintModConditionsOnKeyPress = false
    GSEOptions.showGSEUsers = false
    GSEOptions.showGSEoocqueue = true
    GSEOptions.UseVerboseExportFormat = false
    GSEOptions.DefaultImportAction = "MERGE"
    GSEOptions.UseWLMExportFormat = true
    GSEOptions.PromptSample = true
    GSEOptions.msClickRate = 250
    GSEOptions.showMiniMap = {
        hide = true
    }
    GSEOptions.editorHeight = 700
    GSEOptions.editorWidth = 700
    GSEOptions.showCurrentSpells = true
    GSEOptions.OOCQueueDelay = 7
    GSE.resetMacroResetModifiers()
    GSEOptions.frameLocations = {}
end

GSE.SetDefaultOptions()

GSE.OOCQueue = {}
GSE.UnsavedOptions = {}
GSE.UnsavedOptions["DebugSequenceExecution"] = false
GSE.TranslatorLanguageTables = {}
GSE.AdditionalLanguagesAvailable = false

local Translator = GSE.TranslatorLanguageTables

Translator[Statics.TranslationKey] = {}
Translator[Statics.TranslationHash] = {}
Translator[Statics.TranslationShadow] = {}

GSE.PrintAvailable = false
GSE.StandardAddInPacks = {}
GSE.UsedSequences = {}
GSE.SequencesExec = {}
GSE.UnsavedOptions["PartyUsers"] = {}
GSE.UnsavedOptions["GUI"] = false

local colorTable = {}

local tokens = IndentationLib.tokens

colorTable[tokens.TOKEN_SPECIAL] = GSEOptions.WOWSHORTCUTS
colorTable[tokens.TOKEN_KEYWORD] = GSEOptions.KEYWORD
colorTable[tokens.TOKEN_UNKNOWN] = GSEOptions.UNKNOWN
colorTable[tokens.TOKEN_COMMENT_SHORT] = GSEOptions.COMMENT
colorTable[tokens.TOKEN_COMMENT_LONG] = GSEOptions.COMMENT

local stringColor = GSEOptions.NormalColour
colorTable[tokens.TOKEN_STRING] = stringColor
colorTable[".."] = stringColor

local tableColor = GSEOptions.CONCAT
colorTable["..."] = tableColor
colorTable["{"] = tableColor
colorTable["}"] = tableColor
colorTable["["] = GSEOptions.STRING
colorTable["]"] = GSEOptions.STRING

local arithmeticColor = GSEOptions.NUMBER
colorTable[tokens.TOKEN_NUMBER] = arithmeticColor
colorTable["+"] = arithmeticColor
colorTable["-"] = arithmeticColor
colorTable["/"] = arithmeticColor
colorTable["*"] = arithmeticColor

local logicColor1 = GSEOptions.EQUALS
colorTable["=="] = logicColor1
colorTable["<"] = logicColor1
colorTable["<="] = logicColor1
colorTable[">"] = logicColor1
colorTable[">="] = logicColor1
colorTable["~="] = logicColor1

local logicColor2 = GSEOptions.EQUALS
colorTable["and"] = logicColor2
colorTable["or"] = logicColor2
colorTable["not"] = logicColor2

local castColor = GSEOptions.UNKNOWN
colorTable["/cast"] = castColor

colorTable[0] = "|r"

Statics.IndentationColorTable = colorTable

GSE.DebugProfile("InitialOptions")
