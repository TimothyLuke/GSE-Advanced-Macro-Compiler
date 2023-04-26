local GSE = GSE
local Statics = GSE.Static
local L = GSE.L
GSE.Library = {}

Statics.CastCmds = {
    use = true,
    cast = true,
    spell = true,
    cancelaura = true,
    cancelform = true,
    stopmacro = true,
    petautocastoff = true,
    petautocaston = true
}

Statics.MacroCommands = {"petattack", "dismount", "shoot", "startattack", "stopattack", "targetenemy"}

Statics.CleanStrings = {
    [1] = "/console Sound_EnableSFX 0%;",
    [2] = "/console Sound_EnableSFX 1%;",
    [3] = "/script UIErrorsFrame:Hide%(%)%;",
    [4] = "/run UIErrorsFrame:Clear%(%)%;",
    [5] = "/script UIErrorsFrame:Clear%(%)%;",
    [6] = "/run UIErrorsFrame:Hide%(%)%;",
    [7] = "/console Sound_EnableErrorSpeech 1",
    [8] = "/console Sound_EnableErrorSpeech 0",
    [11] = "/console Sound_EnableSFX 0",
    [12] = "/console Sound_EnableSFX 1",
    [13] = "/script UIErrorsFrame:Hide%(%)",
    [14] = "/run UIErrorsFrame:Clear%(%)",
    [15] = "/script UIErrorsFrame:Clear%(%)",
    [16] = "/run UIErrorsFrame:Hide%(%)",
    [17] = "/console Sound_EnableErrorSpeech 1%;",
    [18] = "/console Sound_EnableErrorSpeech 0%;",
    [19] = [[""]],
    [20] = "/stopmacro [@playertarget, noexists]",
    -- [30] = "/use 2",
    -- [31] = "/use [combat] 11",
    -- [32] = "/use [combat] 12",
    -- [33] = "/use [combat] 13",
    -- [34] = "/use [combat] 14",
    -- [35] = "/use 11",
    -- [36] = "/use 12",
    -- [37] = "/use 13",
    -- [38] = "/use 14",
    -- [39] = "/Use [combat] 11",
    -- [40] = "/Use [combat] 12",
    -- [41] = "/Use [combat] 13",
    -- [42] = "/Use [combat] 14",
    -- [43] = "/use [combat]11",
    -- [44] = "/use [combat]12",
    -- [45] = "/use [combat]13",
    -- [46] = "/use [combat]14",
    -- [47] = "/use [combat]2",
    -- [48] = "/use [combat] 2",
    -- [49] = "/use [combat]5",
    -- [50] = "/use [combat] 5",
    -- [51] = "/use [combat]1",
    -- [52] = "/use [combat] 1",
    -- [53] = "/use 1",
    -- [54] = "/use 5",
    [101] = "\n\n"
}

Statics.StringReset = "|r"
Statics.CoreLoadedMessage = "GS-CoreLoaded"

Statics.SystemVariables = {
    ["GCD"] = function()
        return GSE.GetGCD()
    end
}

Statics.SystemVariableDescriptions = {
    ["GCD"] = L["Returns your current Global Cooldown value accounting for your haste if that stat is present."],
    ["LID"] = L["Returns the current Loop Index.  If this is the third action in a loop it will return 3."]
}

if GSE.GameMode ~= 1 then
    Statics.SystemVariables["HE"] = function()
        local itemLink = GetInventoryItemLink("player", 2)
        if not GSE.isEmpty(itemLink) then
            if GetItemInfo(itemLink) == "Heart of Azeroth" then
                return "/cast [combat,nochanneling] Heart Essence"
            else
                return "-- /cast Heart Essence"
            end
        else
            return "-- /cast Heart Essence"
        end
    end
    Statics.SystemVariableDescriptions["HE"] =
        L[
        "Checks to see if you have a Heart of Azeroth equipped and if so will insert '/cast Heart Essence' into the macro.  If not your macro will skip this line."
    ]
end
Statics.SpecIDClassList = {
    [0] = 0,
    [1] = 1,
    [2] = 2,
    [3] = 3,
    [4] = 4,
    [5] = 5,
    [6] = 6,
    [7] = 7,
    [8] = 8,
    [9] = 9,
    [10] = 10,
    [11] = 11,
    [12] = 12,
    [13] = 13,
    [62] = 8,
    [63] = 8,
    [64] = 8,
    [65] = 2,
    [66] = 2,
    [70] = 2,
    [71] = 1,
    [72] = 1,
    [73] = 1,
    [102] = 11,
    [103] = 11,
    [104] = 11,
    [105] = 11,
    [250] = 6,
    [251] = 6,
    [252] = 6,
    [253] = 3,
    [254] = 3,
    [255] = 3,
    [256] = 5,
    [257] = 5,
    [258] = 5,
    [259] = 4,
    [260] = 4,
    [261] = 4,
    [262] = 7,
    [263] = 7,
    [264] = 7,
    [265] = 9,
    [266] = 9,
    [267] = 9,
    [268] = 10,
    [269] = 10,
    [270] = 10,
    [577] = 12,
    [581] = 12,
    [1467] = 13,
    [1468] = 13
}

local function determineSpecializationName(specID)
    if GSE.GameMode < 4 then
        return Statics.SpecIDClassList[specID]
    else
        local _, specname = GetSpecializationInfoByID(specID)
        return specname
    end
end

local function determineClassName(specID)
    local specname
    -- if GSE.GameMode == 1 then
    --     local ClassTable = C_CreatureInfo.GetClassInfo(specID)
    --     return ClassTable["className"]
    -- else
    specname = GetClassInfo(specID)
    -- end
    return specname
end

function GSE.GetClassName(classID)
    return determineClassName(classID)
end

Statics.SpecIDList = {}

if GSE.GameMode < 4 then
    Statics.SpecIDClassList = {
        [0] = 0,
        [1] = 1,
        [2] = 2,
        [3] = 3,
        [4] = 4,
        [5] = 5,
        [6] = 6,
        [7] = 7,
        [8] = 8,
        [9] = 9,
        --[10] = 10,
        [11] = 11
    }
    Statics.SpecIDList = {
        [0] = L["Global"],
        [1] = determineClassName(1),
        [2] = determineClassName(2),
        [3] = determineClassName(3),
        [4] = determineClassName(4),
        [5] = determineClassName(5),
        [6] = determineClassName(6),
        [7] = determineClassName(7),
        [8] = determineClassName(8),
        [9] = determineClassName(9),
        [11] = determineClassName(11)
    }
    if GSE.GameMode >= 3 then
        Statics.SpecIDList[6] = determineClassName(6)
    end
else
    Statics.SpecIDList = {
        [0] = L["Global"],
        [1] = determineClassName(1),
        [2] = determineClassName(2),
        [3] = determineClassName(3),
        [4] = determineClassName(4),
        [5] = determineClassName(5),
        [6] = determineClassName(6),
        [7] = determineClassName(7),
        [8] = determineClassName(8),
        [9] = determineClassName(9),
        [10] = determineClassName(10),
        [11] = determineClassName(11),
        [12] = determineClassName(12),
        [13] = determineClassName(13),
        [62] = determineSpecializationName(62),
        [63] = determineSpecializationName(63),
        [64] = determineSpecializationName(64) .. " - " .. determineClassName(8),
        [65] = determineSpecializationName(65) .. " - " .. determineClassName(2),
        [66] = determineSpecializationName(66) .. " - " .. determineClassName(2),
        [70] = determineSpecializationName(70),
        [71] = determineSpecializationName(71),
        [72] = determineSpecializationName(72),
        [73] = determineSpecializationName(73),
        [102] = determineSpecializationName(102),
        [103] = determineSpecializationName(103),
        [104] = determineSpecializationName(104),
        [105] = determineSpecializationName(105) .. " - " .. determineClassName(11),
        [250] = determineSpecializationName(250),
        [251] = determineSpecializationName(251) .. " - " .. determineClassName(6),
        [252] = determineSpecializationName(252),
        [253] = determineSpecializationName(253),
        [254] = determineSpecializationName(254),
        [255] = determineSpecializationName(255),
        [256] = determineSpecializationName(256),
        [257] = determineSpecializationName(257) .. " - " .. determineClassName(5),
        [258] = determineSpecializationName(258),
        [259] = determineSpecializationName(259),
        [260] = determineSpecializationName(260),
        [261] = determineSpecializationName(261),
        [262] = determineSpecializationName(262),
        [263] = determineSpecializationName(263),
        [264] = determineSpecializationName(264) .. " - " .. determineClassName(7),
        [265] = determineSpecializationName(265),
        [266] = determineSpecializationName(266),
        [267] = determineSpecializationName(267),
        [268] = determineSpecializationName(268),
        [269] = determineSpecializationName(269),
        [270] = determineSpecializationName(270),
        [577] = determineSpecializationName(577),
        [581] = determineSpecializationName(581),
        [1467] = determineSpecializationName(1467),
        [1468] = determineSpecializationName(1468)
    }
end

Statics.SpecIDHashList = {}
for k, v in pairs(Statics.SpecIDList) do
    Statics.SpecIDHashList[v] = k
end

Statics.SequenceDebug = "SEQUENCEDEBUG"

Statics.Priority = "Priority"
Statics.Sequential = "Sequential"
Statics.ReversePriority = "ReversePriority"
Statics.Random = "Random"

Statics.PrintKeyModifiers =
    [[
print("Right alt key " .. tostring(IsRightAltKeyDown()))
print("Left alt key " .. tostring(IsLeftAltKeyDown()))
print("Any alt key " .. tostring(IsAltKeyDown()))
print("Right ctrl key " .. tostring(IsRightControlKeyDown()))
print("Left ctrl key " .. tostring(IsLeftControlKeyDown()))
print("Any ctrl key " .. tostring(IsControlKeyDown()))
print("Right shft key " .. tostring(IsRightShiftKeyDown()))
print("Left shft key " .. tostring(IsLeftShiftKeyDown()))
print("Any shft key " .. tostring(IsShiftKeyDown()))
print("Any mod key " .. tostring(IsModifierKeyDown()))
print("GetMouseButtonClicked() " .. GetMouseButtonClicked() )
]]

Statics.StringFormatEscapes = {
    ["|c%x%x%x%x%x%x%x%x"] = "", -- Color start
    ["|r"] = "", -- Color end
    ["|H.-|h(.-)|h"] = "%1", -- Links
    ["|T.-|t"] = "", -- Textures
    ["{.-}"] = "" -- Raid target icons
}

Statics.MacroResetSkeleton = [[
if %s then
	self:SetAttribute('step', 1)
	self:SetAttribute('loopiter', 1)
end
]]

Statics.SourceLocal = "Local"
Statics.SourceTransmission = "Transmission"
Statics.DebugModules = {}
Statics.DebugModules["Translator"] = "Translator"
Statics.DebugModules["Storage"] = "Storage"
Statics.DebugModules["Editor"] = "Editor"
Statics.DebugModules["Viewer"] = "Viewer"
Statics.DebugModules["Versions"] = "Versions"
Statics.DebugModules[Statics.SourceTransmission] = Statics.SourceTransmission
Statics.DebugModules["API"] = "API"
Statics.DebugModules["GUI"] = "GUI"
Statics.DebugModules["Startup"] = "Startup"

Statics.TranslationKey = "KEY"
Statics.TranslationHash = "HASH"
Statics.TranslationShadow = "SHADOW"

Statics.Spec = "Spec"
Statics.Class = "Class"
Statics.All = "All"
Statics.Global = "Global"

Statics.SampleMacros = {}
Statics.QuestionMark = "INV_MISC_QUESTIONMARK"

Statics.ReloadMessage = "Reload"
Statics.CommPrefix = "GSE"

Statics.BaseSpellTable = {}

-- Azerite essences
Statics.BaseSpellTable[296325] = 296208 -- Vision of Perfection 1
Statics.BaseSpellTable[299368] = 296208 -- Vision of Perfection 2
Statics.BaseSpellTable[299370] = 296208 -- Vision of Perfection 3

Statics.BaseSpellTable[303823] = 296208 -- Conflict 1
Statics.BaseSpellTable[304088] = 296208 -- Conflict 2
Statics.BaseSpellTable[304121] = 296208 -- Conflict 3

Statics.BaseSpellTable[297108] = 296208 -- Blood of the Enemy 1
Statics.BaseSpellTable[297108] = 296208 -- Blood of the Enemy 2
Statics.BaseSpellTable[297108] = 296208 -- Blood of the Enemy 3

Statics.BaseSpellTable[295258] = 296208 -- Focused Azerite Beam
Statics.BaseSpellTable[299336] = 296208 -- Focused Azerite Beam
Statics.BaseSpellTable[299338] = 296208 -- Focused Azerite Beam

Statics.BaseSpellTable[295840] = 296208 -- Guardian of Azeroth 1
Statics.BaseSpellTable[299355] = 296208 -- Guardian of Azeroth 2
Statics.BaseSpellTable[299358] = 296208 -- Guardian of Azeroth 3

Statics.BaseSpellTable[295337] = 296208 -- Purification Protocol 1
Statics.BaseSpellTable[299345] = 296208 -- Purification Protocol 2
Statics.BaseSpellTable[299347] = 296208 -- Purification Protocol 3

Statics.BaseSpellTable[295186] = 296208 -- World Vein Resonance 1
Statics.BaseSpellTable[298628] = 296208 -- World Vein Resonance 2
Statics.BaseSpellTable[299334] = 296208 -- World Vein Resonance 3

Statics.BaseSpellTable[298357] = 296208 -- Memory of Lucid Dreams 1
Statics.BaseSpellTable[299372] = 296208 -- Memory of Lucid Dreams 2
Statics.BaseSpellTable[299374] = 296208 -- Memory of Lucid Dreams 3

Statics.BaseSpellTable[296072] = 296208 -- Overcharge Mana 1
Statics.BaseSpellTable[299876] = 296208 -- Overcharge Mana 2
Statics.BaseSpellTable[299374] = 296208 -- Overcharge Mana 3

Statics.BaseSpellTable[295746] = 296208 -- Empowered Null Barrier 1
Statics.BaseSpellTable[300015] = 296208 -- Empowered Null Barrier 2
Statics.BaseSpellTable[300016] = 296208 -- Empowered Null Barrier 3

Statics.BaseSpellTable[293032] = 296208 -- Life-Binders Invocation 1
Statics.BaseSpellTable[299943] = 296208 -- Life-Binders Invocation 2
Statics.BaseSpellTable[299944] = 296208 -- Life-Binders Invocation 3

Statics.BaseSpellTable[295373] = 296208 -- Concentrated Flame 1
Statics.BaseSpellTable[299349] = 296208 -- Concentrated Flame 2
Statics.BaseSpellTable[299353] = 296208 -- Concentrated Flame 3

Statics.BaseSpellTable[294926] = 296208 -- Anima of Death 1
Statics.BaseSpellTable[300002] = 296208 -- Anima of Death 2
Statics.BaseSpellTable[300003] = 296208 -- Anima of Death 3

Statics.BaseSpellTable[296197] = 296208 -- Refreshment 1
Statics.BaseSpellTable[299932] = 296208 -- Refreshment 2
Statics.BaseSpellTable[299933] = 296208 -- Refreshment 3

Statics.BaseSpellTable[298168] = 296208 -- Aegis of the Deep 1
Statics.BaseSpellTable[299273] = 296208 -- Aegis of the Deep 2
Statics.BaseSpellTable[299275] = 296208 -- Aegis of the Deep 3

Statics.BaseSpellTable[293019] = 296208 -- Azeroth's Undying Gift 1
Statics.BaseSpellTable[298080] = 296208 -- Azeroth's Undying Gift 2
Statics.BaseSpellTable[298081] = 296208 -- Azeroth's Undying Gift 3

Statics.BaseSpellTable[298452] = 296208 -- The Unbound Force 1
Statics.BaseSpellTable[299376] = 296208 -- The Unbound Force 2
Statics.BaseSpellTable[299378] = 296208 -- The Unbound Force 3

Statics.BaseSpellTable[296230] = 296208 -- Vitality Conduit 1
Statics.BaseSpellTable[299958] = 296208 -- Vitality Conduit 2
Statics.BaseSpellTable[299959] = 296208 -- Vitality Conduit 3

Statics.BaseSpellTable[293031] = 296208 -- Suppressing Pulse 1
Statics.BaseSpellTable[300009] = 296208 -- Suppressing Pulse 2
Statics.BaseSpellTable[300010] = 296208 -- Suppressing Pulse 3

Statics.BaseSpellTable[296094] = 296208 -- Standstill 1
Statics.BaseSpellTable[299882] = 296208 -- Standstill 2
Statics.BaseSpellTable[299883] = 296208 -- Standstill 3

Statics.BaseSpellTable[302731] = 296208 -- Ripple in Space 1
Statics.BaseSpellTable[302982] = 296208 -- Ripple in Space 2
Statics.BaseSpellTable[302983] = 296208 -- Ripple in Space 3

Statics.BaseSpellTable[201427] = 344862 -- Annihilation -> Chaos Strike

Statics.Actions = {}
Statics.Actions.Loop = "Loop"
Statics.Actions.If = "If"
Statics.Actions.Repeat = "Repeat"
Statics.Actions.Action = "Action"
Statics.Actions.Pause = "Pause"

Statics.ActionsIcons = {}
Statics.ActionsIcons.Loop = "Interface\\Addons\\GSE_GUI\\Assets\\loop.tga"
Statics.ActionsIcons.If = "Interface\\Addons\\GSE_GUI\\Assets\\if.tga"
Statics.ActionsIcons.Repeat = "Interface\\Addons\\GSE_GUI\\Assets\\repeat.tga"
Statics.ActionsIcons.Action = "Interface\\Addons\\GSE_GUI\\Assets\\action.tga"
Statics.ActionsIcons.Pause = "Interface\\Addons\\GSE_GUI\\Assets\\pause.tga"
Statics.ActionsIcons.Up = "Interface\\Addons\\GSE_GUI\\Assets\\up.tga"
Statics.ActionsIcons.Down = "Interface\\Addons\\GSE_GUI\\Assets\\down.tga"
Statics.ActionsIcons.Delete = "Interface\\Addons\\GSE_GUI\\Assets\\delete.tga"

Statics.GSE3OnClick =
    [=[
local step = self:GetAttribute('step')
step = tonumber(step)
self:SetAttribute('macrotext', macros[step] )
step = step % #macros + 1
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
	print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
	step = 1
end
self:SetAttribute('step', step)
self:CallMethod('UpdateIcon')
]=]

Statics.TranslatorMode = {}
Statics.TranslatorMode.Current = "CURRENT"
Statics.TranslatorMode.String = "STRING"
Statics.TranslatorMode.ID = "ID"

Statics.TableMetadataFunction = {
    __index = function(t, k)
        for _, v in ipairs(k) do
            if not t then
                error("attempt to index nil")
            end
            t = rawget(t, v)
        end
        return t
    end,
    __newindex = function(t, key, v)
        local last_k
        for _, k in ipairs(key) do
            k, last_k = last_k, k
            if k ~= nil then
                local parent_t = t
                t = rawget(parent_t, k)
                if t == nil then
                    t = {}
                    rawset(parent_t, k, t)
                end
                if type(t) ~= "table" then
                    error("Unexpected subtable", 2)
                end
            end
        end
        rawset(t, last_k, v)
    end
}

GSE.DebugProfile("Statics")
