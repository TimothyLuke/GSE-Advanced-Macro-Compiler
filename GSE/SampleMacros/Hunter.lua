local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[3] = {}

local Sequences = Statics.SampleMacros[3]

------------------
----- Hunter
------------------
-- Beast Mastery 253
-- Survival 255
-- Marksmanship - 254

Sequences['SAM_BMsingle'] = {
  SpecID = 253,
  Author = "Jimmy Boy Albrecht",
  Talents = "3,1,1,1,3,2,3",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/petattack [@target,harm]",
        "/petautocastoff [group] Growl",
        "/petautocaston [nogroup] Growl",
        "/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection",
      },
      '/cast [nochanneling] Cobra Shot',
      '/cast [nochanneling] !Kill Command',
      '/cast [nochanneling] Bestial Wrath',
      '/cast [nochanneling] !Dire Beast',
      '/cast [nochanneling] Barrage',
      KeyRelease = {
        "/startattack",
        "/petattack",
        "/cast Aspect of the Wild",
      },
    }
  }
}

Sequences['SAM_BMaoe'] = {
  SpecID = 253,
  Author = "Jimmy Boy Albrecht",
  Talents = "3,1,1,1,3,2,3",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/petattack [@target,harm]",
        "/petautocastoff [group] Growl",
        "/petautocaston [nogroup] Growl",
        "/cast [target=focus, exists, nodead],[target=pet, exists, nodead] Misdirection",
      },
      '/cast [nochanneling] Multi-Shot',
      '/cast [nochanneling] !Kill Command',
      '/cast [nochanneling] Bestial Wrath',
      '/cast [nochanneling] !Dire Beast',
      '/cast [nochanneling] Barrage',
      KeyRelease = {
        "/startattack",
        "/petattack",
        "/cast Aspect of the Wild",
      },
    }
  }
}

Sequences['SAM_Mm_ST'] = {
  SpecID = 254,
  Author = "emanuel",
  Talents = "3,3,1,2,1,2,3",
  StepFunction = "Priority",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
  /cast Trueshot
  ]],
  '/cast !A Murder of Crows',
  '/cast !Arcane Shot',
  '/cast !Marked Shot',
  '/cast !Aimed Shot',
  '/cast !Bursting Shot',
  '/cast !Black Arrow',
  KeyRelease = [[
  /startattack
  /petattack
  ]],
}

Sequences['SAM_Marks_AOE'] = {
  Author='Nano',
  SpecID=254,
  Talents = '3,1,1,3,1,2,2',
  Default=1,
  Icon='Ability_Hunter_FocusedAim',
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast Trueshot",
      },
      '/cast [nochanneling] !Multi-shot',
      '/cast [nochanneling] !Marked Shot',
      '/cast [nochanneling] Windburst',
      '/cast [nochanneling] !Aimed Shot',
      '/cast [nochanneling] Piercing Shot',
      '/cast [nochanneling] !Multi-shot',
      '/cast [nochanneling] !Marked Shot',
      KeyRelease={
        "/startattack",
        "/petattack"
      }
    }
  }
}

Sequences['SAM_SURVST'] = {
  SpecID = 255,
  Author = "yiffking fleabag",
  Talents = "1,1,1,1,1,1,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/castsequence reset=8 !Raptor Strike, Lacerate',
      '/castsequence Throwing Axes, Aspect of the Eagle, Mongoose Bite, Mongoose Bite, Mongoose Bite',
      '/castsequence reset=22 !Snake Hunter, Mongoose Bite, Mongoose Bite, Mongoose Bite',
      '/cast Raptor Strike',
      '/cast Lacerate',
      '/cast !Mongoose Bite',
      '/cast Throwing Axes',
      '/cast Spitting Cobra',
      '/cast Flanking Strike',
      KeyRelease = {
        "/startattack",
      },
    }
  }
}

Sequences['SAM_SURVAOE'] = {
  SpecID = 255,
  Author = "yiffking fleabag",
  Talents = "1,1,1,1,1,1,1",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]",
      },
      '/castsequence reset=8 !Raptor Strike, Carve',
      '/castsequence Serpent Sting, Throwing Axes, Aspect of the Eagle, Mongoose Bite, Mongoose Bite, Mongoose Bite',
      '/castsequence reset=22 !Snake Hunter, Mongoose Bite, Mongoose Bite, Mongoose Bite',
      '/cast Raptor Strike',
      '/cast Carve',
      '/cast !Mongoose Bite',
      '/cast Butchery',
      '/cast Spitting Cobra',
      '/cast Throwing Axes',
      KeyRelease = {
        "/startattack",
      },
    }
  }
}
