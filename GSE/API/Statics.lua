local GSE = GSE
local Statics = GSE.Static
local L = GSE.L
GSELibrary = {}

Statics.CastCmds = { use = true, cast = true, spell = true, cancelaura = true, cancelform = true, stopmacro = true }

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

  [30] = "/use 2",
  [31] = "/use [combat] 11",
  [32] = "/use [combat] 12",
  [33] = "/use [combat] 13",
  [34] = "/use [combat] 14",
  [35] = "/use 11",
  [36] = "/use 12",
  [37] = "/use 13",
  [38] = "/use 14",
  [39] = "/Use [combat] 11",
  [40] = "/Use [combat] 12",
  [41] = "/Use [combat] 13",
  [42] = "/Use [combat] 14",
  [43] = "/use [combat]11",
  [44] = "/use [combat]12",
  [45] = "/use [combat]13",
  [46] = "/use [combat]14",
  [47] = "/use [combat]2",
  [48] = "/use [combat] 2",
  [49] = "/use [combat]5",
  [50] = "/use [combat] 5",
  [51] = "/use [combat]1",
  [52] = "/use [combat] 1",
  [53] = "/use 1",
  [54] = "/use 5",
  [101] = "\n\n",
}

Statics.StringReset =  "|r"
Statics.CoreLoadedMessage = "GS-CoreLoaded"

Statics.SpecIDList = {
  [0] = "Global",
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

Statics.Priority = "Priority"
Statics.Sequential = "Sequential"

--- <code>GSStaticPriority</code> is a static step function that goes 1121231234123451234561234567
--    use this like StepFunction = GSStaticPriority, in a macro
--    This overides the sequential behaviour that is standard in GS
Statics.PriorityImplementation = [[
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
Statics.LoopPriorityImplementation = [[
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

Statics.OnClick = [=[
local step = self:GetAttribute('step')
local loopstart = self:GetAttribute('loopstart') or 1
local loopstop = self:GetAttribute('loopstop') or #macros
local loopiter = self:GetAttribute('loopiter') or 1
local looplimit = self:GetAttribute('looplimit') or 1
loopstart = tonumber(loopstart)
loopstop = tonumber(loopstop)
loopiter = tonumber(loopiter)
looplimit = tonumber(looplimit)
step = tonumber(step)
%s
self:SetAttribute('macrotext', self:GetAttribute('KeyPress') .. "\n" .. macros[step] .. "\n" .. self:GetAttribute('KeyRelease'))
%s
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:CallMethod('UpdateIcon')
]=]

--- <code>GSStaticLoopPriority</code> is a static step function that
--    operates in a sequential mode but with an internal loop.
--    eg 12342345
Statics.LoopSequentialImplementation = [[
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

Statics.TargetResetImplementation = [[
local target = self:GetAttribute('target') or "none"
local _, commandtarget = SecureCmdOptionParse(macros[step])
if target ~= target then
  self:SetAttribute('step', 0)
  self:SetAttribute('target', commandtarget)
  self:SetAttribute('loopiter', 0)
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
Statics.DebugModules = {}
Statics.DebugModules["Translator"] = "Translator"
Statics.DebugModules["Storage"] = "Storage"
Statics.DebugModules["Editor"] ="Editor"
Statics.DebugModules["Viewer"] = "Viewer"
Statics.DebugModules["Versions"] = "Versions"
Statics.DebugModules[Statics.SourceTransmission] = Statics.SourceTransmission
Statics.DebugModules["API"] = "API"
Statics.DebugModules["GUI"] = "GUI"


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
