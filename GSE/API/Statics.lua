local GSE = GSE
local Statics = GSE.Static
local L = GSE.L
GSELibrary = {}

Statics.CastCmds = { use = true, cast = true, spell = true, cancelaura = true, cancelform = true, stopmacro = true, petautocastoff = true, petautocaston = true, petattack = true }

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

Statics.CharacterDollSlot = {}

Statics.CharacterDollSlot[INVSLOT_HEAD] = "HeadSlot"
Statics.CharacterDollSlot[INVSLOT_NECK] = "NeckSlot"
Statics.CharacterDollSlot[INVSLOT_SHOULDER] = "ShoulderSlot"
Statics.CharacterDollSlot[INVSLOT_BACK] = "BackSlot"
Statics.CharacterDollSlot[INVSLOT_CHEST] = "ChestSlot"
Statics.CharacterDollSlot[INVSLOT_BODY] = "ShirtSlot"
Statics.CharacterDollSlot[INVSLOT_TABARD] = "TabardSlot"
Statics.CharacterDollSlot[INVSLOT_WRIST] = "WristSlot"
Statics.CharacterDollSlot[INVSLOT_HAND] = "HandsSlot"
Statics.CharacterDollSlot[INVSLOT_WAIST] = "WaistSlot"
Statics.CharacterDollSlot[INVSLOT_LEGS] = "LegsSlot"
Statics.CharacterDollSlot[INVSLOT_FEET] = "FeetSlot"
Statics.CharacterDollSlot[INVSLOT_FINGER1] = "Finger1Slot"
Statics.CharacterDollSlot[INVSLOT_FINGER2] = "Finger2Slot"
Statics.CharacterDollSlot[INVSLOT_TRINKET1] = "Trinket1Slot"
Statics.CharacterDollSlot[INVSLOT_TRINKET2] = "Trinket2Slot"
Statics.CharacterDollSlot[INVSLOT_MAINHAND] = "MainHandSlot"
Statics.CharacterDollSlot[INVSLOT_OFFHAND] = "OffHandSlot"
Statics.CharacterDollSlot[INVSLOT_AMMO] = "AmmoSlot"

Statics.CharacterDollSlotReverse = {}

Statics.CharacterDollSlotReverse["headslot"] = INVSLOT_HEAD
Statics.CharacterDollSlotReverse["neckslot"] = INVSLOT_NECK
Statics.CharacterDollSlotReverse["shoulderslot"] = INVSLOT_SHOULDER
Statics.CharacterDollSlotReverse["backslot"] = INVSLOT_BACK
Statics.CharacterDollSlotReverse["chestslot"] = INVSLOT_CHEST
Statics.CharacterDollSlotReverse["shirtslot"] = INVSLOT_BODY
Statics.CharacterDollSlotReverse["tabardslot"] = INVSLOT_TABARD
Statics.CharacterDollSlotReverse["wristslot"] = INVSLOT_WRIST
Statics.CharacterDollSlotReverse["handsslot"] = INVSLOT_HAND
Statics.CharacterDollSlotReverse["waistslot"] = INVSLOT_WAIST
Statics.CharacterDollSlotReverse["legsslot"] = INVSLOT_LEGS
Statics.CharacterDollSlotReverse["feetslot"] = INVSLOT_FEET
Statics.CharacterDollSlotReverse["finger1slot"] = INVSLOT_FINGER1
Statics.CharacterDollSlotReverse["finger2slot"] = INVSLOT_FINGER2
Statics.CharacterDollSlotReverse["trinket1slot"] = INVSLOT_TRINKET1
Statics.CharacterDollSlotReverse["trinket2slot"] = INVSLOT_TRINKET2
Statics.CharacterDollSlotReverse["mainhandslot"] = INVSLOT_MAINHAND
Statics.CharacterDollSlotReverse["offhandslot"] = INVSLOT_OFFHAND
Statics.CharacterDollSlotReverse["ammoslot"] = INVSLOT_AMMO


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
    ["|c%x%x%x%x%x%x%x%x"] = "", -- color start
    ["|r"] = "", -- color end
    ["|H.-|h(.-)|h"] = "%1", -- links
    ["|T.-|t"] = "", -- textures
    ["{.-}"] = "", -- raid target icons
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
Statics.BaseSpellTable[231895] = 31884 -- Crusade to Avenging Wrath
Statics.BaseSpellTable[216331] = 31884 -- Avenging Crusader to Avenging Wrath
Statics.BaseSpellTable[200025] = 53563 -- Beacon of Virtue to Beacon of Light
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

-- Hunter
Statics.BaseSpellTable[259387] = 186270 -- Mongoose Bite -> Raptor Strike

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

-- Death Knight
Statics.BaseSpellTable[207311] = 55090 -- Clawing Shadows -> Scourge Strike
Statics.BaseSpellTable[152280] = 43265 -- Defile -> Death and Decay
Statics.BaseSpellTable[207127] = 47568 -- Hungering Rune Weapon -> Empower Rune Weapon
