local GSE = GSE
local Statics = GSE.Static
local L = GSE.L
GSELibrary = {}

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

Statics.MacroCommands = {
  "petattack",
  "dismount",
  "shoot",
  "startattack",
  "stopattack",
  "targetenemy"
}

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
}

Statics.SpecIDHashList = {}
for k,v in pairs(Statics.SpecIDList) do
  Statics.SpecIDHashList[v] = k
end

Statics.SequenceDebug = "SEQUENCEDEBUG"

Statics.Priority = "Priority"
Statics.Sequential = "Sequential"
Statics.Random = "Random"

Statics.RandomImplementation = [[
  step = math.random(#macros)
]]

Statics.LoopRandomImplementation = [[
  step = math.random(#macros)
]]


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

  elseif step > loopstop and loopstop == #macros then
    if step >= #macros then
      loopiter = 1
      step = loopstart
      if looplimit > 0 then
        step = 1
        limit = loopstart
      end
    else
      step = step + 1
    end
  elseif step == loopstop then
    if looplimit > 0 then
      if loopiter >= looplimit then
        if loopstop >= #macros then
          step = 1
          limit = loopstart
        else
          step = step + 1
          loopiter = 1
        end
      else
        step = loopstart
        loopiter = loopiter + 1
      end
    else
      step = loopstart
    end
  elseif step >= #macros then
    loopiter = 1
    step = loopstart
    if looplimit > 0 then
      step = 1
      limit = loopstart
    end
  else
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if limit == loopiter then
        loopiter = loopiter + 1
      end
    else
      step = step + 1
    end
  end
]]

Statics.PrintKeyModifiers = [[
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

Statics.OnClick = [=[
local step = self:GetAttribute('step')
local loopstart = self:GetAttribute('loopstart') or 1
local loopstop = self:GetAttribute('loopstop') or #macros
local loopiter = self:GetAttribute('loopiter') or 1
local looplimit = self:GetAttribute('looplimit') or 0
loopstart = tonumber(loopstart)
loopstop = tonumber(loopstop)
loopiter = tonumber(loopiter)
looplimit = tonumber(looplimit)
step = tonumber(step)
self:SetAttribute('macrotext', self:GetAttribute('KeyPress') .. "\n" .. macros[step] .. "\n" .. self:GetAttribute('KeyRelease'))
%s
if not step or not macros[step] then -- User attempted to write a step method that doesn't work, reset to 1
  print('|cffff0000Invalid step assigned by custom step sequence', self:GetName(), step or 'nil', '|r')
  step = 1
end
self:SetAttribute('step', step)
self:SetAttribute('loopiter', loopiter)
self:CallMethod('UpdateIcon')
]=]

--- <code>GSStaticLoopPriority</code> is a static step function that
--    operates in a sequential mode but with an internal loop.
--    eg 12342345
Statics.LoopSequentialImplementation = [[
if step < loopstart then
  -- I am before the loop increment to next step.
  step = step + 1
elseif step > loopstop then
  if step >= #macros then
    loopiter = 1
    step = loopstart
    if looplimit > 0 then
      step = 1
    end
  else
    step = step + 1
  end
elseif step == loopstop then
  if looplimit > 0 then
    if loopiter >= looplimit then
      if loopstop >= #macros then
        step = 1
      else
        step = step + 1
      end
      loopiter = 1
    else
      step = loopstart
      loopiter = loopiter + 1
    end
  else
    step = loopstart
  end
elseif step >= #macros then
  loopiter = 1
  step = loopstart
  if looplimit > 0 then
    step = 1
  end
else
  step = step + 1
end
]]

Statics.StringFormatEscapes = {
    ["|c%x%x%x%x%x%x%x%x"] = "", -- Color start
    ["|r"] = "", -- Color end
    ["|H.-|h(.-)|h"] = "%1", -- Links
    ["|T.-|t"] = "", -- Textures
    ["{.-}"] = "", -- Raid target icons
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
Statics.CommPrefix = "GSE"

Statics.BaseSpellTable = {}

-- Paladin
Statics.BaseSpellTable[231895] = 31884 -- Crusade -> Avenging Wrath
Statics.BaseSpellTable[216331] = 31884 -- Avenging Crusader -> Avenging Wrath
Statics.BaseSpellTable[200025] = 53563 -- Beacon of Virtue -> Beacon of Light
Statics.BaseSpellTable[204019] = 53595 -- Blessed Hammer -> Hammer of the Righteous
Statics.BaseSpellTable[204018] = 1022 -- Blessing of Spellwarding -> Blessing of Protection
Statics.BaseSpellTable[213652] = 184092 -- Hand of the Protector -> Light of the Protector

-- Warrior
Statics.BaseSpellTable[202168] = 34428 -- Impending Victory -> Victory Rush
Statics.BaseSpellTable[262161] = 167105 -- Warbreaker -> Colossus Smash
Statics.BaseSpellTable[152277] = 227847 -- Ravager -> Bladestorm
Statics.BaseSpellTable[236279] = 20243 -- Devastator -> Devastate

-- Rogue
Statics.BaseSpellTable[200758] = 53 -- Gloomblade -> Backstab
Statics.BaseSpellTable[5171] = 193316 -- Slice and Dice -> Roll the Bones

-- Priest
Statics.BaseSpellTable[123040] = 34433 -- Mindbender -> Shadow Fiend
Statics.BaseSpellTable[200174] = 34433 -- Mindbender -> Shadow Fiend
Statics.BaseSpellTable[205369] = 8122 -- Mind Bomb -> Physic Scream
Statics.BaseSpellTable[205351] = 8092 -- Shadow Word: Void -> Mind Blast
Statics.BaseSpellTable[204197] = 589 -- Purge the Wicked -> Shadow Word: Pain
Statics.BaseSpellTable[271466] = 62618 -- Luminous Barrier -> Power Word: Barrier
Statics.BaseSpellTable[228266] = 228260 -- Void Bolt -> Void Eruption
Statics.BaseSpellTable[205448] = 228260 -- Void Bolt -> Void Eruption

-- Hunter
Statics.BaseSpellTable[259387] = 186270 -- Mongoose Bite -> Raptor Strike
Statics.BaseSpellTable[136] = 982 -- Mend Pet -> Revive Pet
Statics.BaseSpellTable[270335] = 259495 -- Shrapnel Bomb -> Wildfire Bomb
Statics.BaseSpellTable[270323] = 259495 -- Pheromone Bomb -> Wildfire Bomb
Statics.BaseSpellTable[271045] = 259495 -- Volatile Bomb -> Wildfire Bomb

-- Warlock

-- Shaman
Statics.BaseSpellTable[192249] = 198067 -- Storm Elemental -> Fire Elemental
Statics.BaseSpellTable[157153] = 5394 -- Cloudburst Totem -> Healing Stream Totem

-- Mage
Statics.BaseSpellTable[205024] = 31687 -- Lonely Winter -> Summon Water Elemental
Statics.BaseSpellTable[212653] = 1953 -- Shimmer -> Blink

-- Monk
Statics.BaseSpellTable[115008] = 109132 -- Chi Torpedo -> Roll
Statics.BaseSpellTable[152173] = 137639 -- Serenity -> Storm, Earth and Fire

-- Druid
Statics.BaseSpellTable[252216] = 1850 -- Tiger Dash -> Dash
Statics.BaseSpellTable[102560] = 194223 -- Incarnation: Chosen of Elune -> Celestial Alignment
Statics.BaseSpellTable[102543] = 106951 -- Incarnation: King of the Jungle -> Beserk
Statics.BaseSpellTable[202028] = 213764 -- Brutal Slash -> Swipe
Statics.BaseSpellTable[236748] = 99 -- Intimidating Roar -> Incapacitating Roar

-- Demon Hunter
Statics.BaseSpellTable[203555] = 162243 -- Demon Blades -> Demon’s Bite
Statics.BaseSpellTable[263642] = 203782 -- Fracture -> Shear
Statics.BaseSpellTable[201427] = 162794 -- Annihilation -> Chaos Strike
Statics.BaseSpellTable[210152] = 188499 -- Death Sweep -> Blade Dance


-- Death Knight
Statics.BaseSpellTable[207311] = 55090 -- Clawing Shadows -> Scourge Strike
Statics.BaseSpellTable[152280] = 43265 -- Defile -> Death and Decay
Statics.BaseSpellTable[207127] = 47568 -- Hungering Rune Weapon -> Empower Rune Weapon

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

Statics.Patrons = {
  "bf2champ",
  "dblakesneed",
  "drobaserge",
  "faultless1986",
  "rezaadams",
  "roberto.zanini",
  "russbakr",
  "susietoo12",
  "siko760"
}
