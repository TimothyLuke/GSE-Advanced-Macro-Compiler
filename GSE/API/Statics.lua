local GSE = GSE
local Statics = GSE.Static


Statics.CastCmds = { use = true, cast = true, spell = true, cancelaura = true, startattack = true, cancelform = true }

Statics.CleanStrings = {
  [1] = "/console Sound_EnableSFX 0%;\n",
  [2] = "/console Sound_EnableSFX 1%;\n",
  [3] = "/script UIErrorsFrame:Hide%(%)%;\n",
  [4] = "/run UIErrorsFrame:Clear%(%)%;\n",
  [5] = "/script UIErrorsFrame:Clear%(%)%;\n",
  [6] = "/run UIErrorsFrame:Hide%(%)%;\n",
  [7] = "/console Sound_EnableErrorSpeech 1\n",
  [8] = "/console Sound_EnableErrorSpeech 0\n",

  [11] = "/console Sound_EnableSFX 0\n",
  [12] = "/console Sound_EnableSFX 1\n",
  [13] = "/script UIErrorsFrame:Hide%(%)\n",
  [14] = "/run UIErrorsFrame:Clear%(%)\n",
  [15] = "/script UIErrorsFrame:Clear%(%)\n",
  [16] = "/run UIErrorsFrame:Hide%(%)\n",
  [17] = "/console Sound_EnableErrorSpeech 1%;\n",
  [18] = "/console Sound_EnableErrorSpeech 0%;\n",

  [20] = "/stopmacro [@playertarget, noexists]\n",

  [30] = "/use 2\n",
  [31] = "/use [combat] 11\n",
  [32] = "/use [combat] 12\n",
  [33] = "/use [combat] 13\n",
  [34] = "/use [combat] 14\n",
  [35] = "/use 11\n",
  [36] = "/use 12\n",
  [37] = "/use 13\n",
  [38] = "/use 14\n",
  [39] = "/Use [combat] 11\n",
  [40] = "/Use [combat] 12\n",
  [41] = "/Use [combat] 13\n",
  [42] = "/Use [combat] 14\n",
  [43] = "/use [combat]11\n",
  [44] = "/use [combat]12\n",
  [45] = "/use [combat]13\n",
  [46] = "/use [combat]14\n",
  [47] = "/use [combat]2\n",
  [48] = "/use [combat] 2\n",
  [49] = "/use [combat]5\n",
  [50] = "/use [combat] 5\n",
  [51] = "/use [combat]1\n",
  [52] = "/use [combat] 1\n",
  [53] = "/use 1\n",
  [54] = "/use 5\n",
  [101] = "\n\n",
}

Statics.StringReset =  "|r"
Statics.CoreLoadedMessage = "GS-CoreLoaded"

Statics.SpecIDList = {
  [0] = "All",
  [1] = "Warrior",
  [2] = "Paladin",
  [3] = "Hunter",
  [4] = "Rogue",
  [5] = "Priest",
  [6] = "Death Knight",
  [7] = "Shaman",
  [8] = "Mage",
  [9] = "Warlock",
  [10] = "Monk",
  [11] = "Druid",
  [12] = "Demon Hunter",
  [62] = "Arcane",
  [63] = "Fire",
  [64] = "Frost - Mage",
  [65] = "Holy - Paladin",
  [66] = "Protection - Paladin",
  [70] = "Retribution",
  [71] = "Arms",
  [72] = "Fury",
  [73] = "Protection - Warrior",
  [102] = "Balance",
  [103] = "Feral",
  [104] = "Guardian",
  [105] = "Restoration - Druid",
  [250] = "Blood",
  [251] = "Frost - DK",
  [252] = "Unholy",
  [253] = "Beast Mastery",
  [254] = "Marksmanship",
  [255] = "Survival",
  [256] = "Discipline",
  [257] = "Holy - Priest",
  [258] = "Shadow",
  [259] = "Assassination",
  [260] = "Outlaw",
  [261] = "Subtlety",
  [262] = "Elemental",
  [263] = "Enhancement",
  [264] = "Restoration - Shaman",
  [265] = "Affliction",
  [266] = "Demonology",
  [267] = "Destruction",
  [268] = "Brewmaster",
  [269] = "Windwalker",
  [270] = "Mistweaver",
  [577] = "Havoc",
  [581] = "Vengeance",
}

Statics.SpecIDHashList = {}
for k,v in pairs(Statics.SpecIDList) do
  Statics.SpecIDHashList[v] = k
end

Statics.SequenceDebug = "SEQUENCEDEBUG"


--- <code>GSStaticPriority</code> is a static step function that goes 1121231234123451234561234567
--    use this like StepFunction = GSStaticPriority, in a macro
--    This overides the sequential behaviour that is standard in GS
Statics.Priority = [[
  limit = limit or 1
  if step == limit then
    limit = limit % #macros + 1
    step = 1
  else
    step = step % #macros + 1
  end
]]

--- <code>GSStaticLoopPriority</code> is a static step function that goes 1121231234123451234561234567
--    but it does this within an internal loop.  So more like 123343456
--    If the macro has loopstart or loopstop defined then it will use this instead of GSStaticPriority
Statics.LoopPriority = [[
  if step < loopstart then
    step = step + 1
  elseif looplimit <= 1 then
    -- when we get to the end reset to loopstart
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if looplimit == loopiter then
        loopiter = 1
        self:SetAttribute('loopiter', loopiter)
      end
    else
      step = step + 1
    end
  elseif step > looplimit then
    step = step + 1
  elseif loopiter == looplimit then
    step = loopstop + 1
  elseif step == #macros then
    step = 1
    self:SetAttribute('loopiter', 1)
  else
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if limit == loopiter then
        loopiter = loopiter + 1
        self:SetAttribute('loopiter', loopiter)
      end
    else
      step = step + 1
    end
  end
]]

--- <code>GSStaticLoopPriority</code> is a static step function that
--    operates in a sequential mode but with an internal loop.
--    eg 12342345
Statics.LoopSequential = [[
  if step < loopstart then
    -- I am before the loop increment to next step.
    step = step + 1
  elseif looplimit <= 1 then
    -- when we get to the end reset to loopstart
    if step == loopstop then
      step = loopstart
      loopiter = loopiter + 1
      self:SetAttribute('loopiter', loopiter)
    else
      step = step + 1
    end
  elseif step > loopstop then
    step = step + 1
  elseif loopiter == looplimit then
    if step == #macros then
      step = 1
      loopiter = 1
      self:SetAttribute('loopiter', 1)
    else
      step = step + 1
    end
  elseif step == loopstop then
    step = loopstart
    loopiter = loopiter + 1
    self:SetAttribute('loopiter', loopiter)
  elseif step == #macros  then
    step = 1
    self:SetAttribute('loopiter', 1)
  else
    step = step + 1
  end
]]



Statics.StringFormatEscapes = {
    ["|c%x%x%x%x%x%x%x%x"] = "", -- color start
    ["|r"] = "", -- color end
    ["|H.-|h(.-)|h"] = "%1", -- links
    ["|T.-|t"] = "", -- textures
    ["{.-}"] = "", -- raid target icons
}

Statics.SourceLocal = "Local"
Statics.SourceTransmission = "Transmission"

Statics.DebugModules["Translator"] = "Translator"
Statics.DebugModules["Storage"] = "Storage"
Statics.DebugModules["Editor"] ="Editor"
Statics.DebugModules["Viewer"] = "Viewer"
Statics.DebugModules["Versions"] = "Versions"
Statics.DebugModules[Statics.SourceTransmission] = Statics.SourceTransmission
Statics.DebugModules["API"] = "API"


Statics.TranslationKey = "KEY"
Statics.TranslationHash = "HASH"
Statics.TranslationShadow = "SHADOW"

Statics.Spec = "Spec"
Statics.Class = "Class"
Statics.All = "All"

GSE.TranslatorLanguageTables = {}

local Translator = GSE.TranslatorLanguageTables

Translator[Statics.TranslationKey] = {}
Translator[Statics.TranslationHash] = {}
Translator[Statics.TranslationShadow] = {}
