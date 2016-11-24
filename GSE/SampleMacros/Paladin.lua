local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[2] = {}

local Sequences = Statics.SampleMacros[2]

------------------
----- Paladin
------------------

-------------------
-- Protection - 66
-------------------
Sequences['SAM_Prot_ST'] = {
  Author="LNPV",
  SpecID=66,
  Talents = '2,3,3,2,2,2,3',
  Icon=236264,
  Default=1,
  Raid=2,
  Mythic=2,
  MacroVersions = {
    [1] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      KeyRelease={
        "/cast Avenging Wrath",
        "/startattack",
      },
    },
    [2] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Consecration",
      "/cast Light of the Protector",
      KeyRelease={
        "/cast !Avenging Wrath",
        "/startattack"
      },
    }

  }
}

Sequences['SAM_Prot_AOE'] = {
  Author="LNPV",
  SpecID=66,
  Talents = 'Talents: 3332123',
  Icon=236264,
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      "/cast Avenger's Shield",
      "/cast Judgment",
      "/cast Blessed Hammer",
      "/cast Hammer of the Righteous",
      "/cast Consecration",
      "/cast Light of the Protector",
      "/cast Shield of the Righteous",
      "/cast Blinding Light",
      KeyRelease={
        "/cast Avenging Wrath",
        "/cast Eye of Tyr",
        "/startattack",
      },
    }
  }
}

Sequences['SAM_Palla_Sera'] = {
  Author="LNPV",
  SpecID=66,
  Talents = '2,2,3,2,2,2,2',
  Icon=236264,
  [1] = {
    KeyPress={
      "/targetenemy [noharm][dead]"
    },
    "/cast Avenger's Shield",
    "/cast Judgment",
    "/cast Blessed Hammer",
    "/cast Consecration",
    "/cast Light of the Protector",
    "/cast Shield of the Righteous",
    "/cast Blinding Light",
    KeyRelease={
      "/cast Avenging Wrath",
      "/cast Bastion of Light",
      "/cast Seraphim",
      "/cast Eye of Tyr",
      "/startattack",
    },
  }
}


-------------------
-- Retribution - 70
-------------------

Sequences['SAM_Ret'] = {
  Author="TimothyLuke",
  SpecID=70,
  Icon='INV_MISC_QUESTIONMARK',
  Lang="enUS",
  Talents="1112111",
  Helplink="https://wowlazymacros.com/forums/topic/tls-ret-macro/",
  Default=1,
  Raid=2,
  PVP=3,
  Mythic=4,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      SoundErrorPrevention=true,
      Trinket1=true,
      Trinket2=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast Avenging Wrath",
        "/cast Shield of Vengeance",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease={
      },
    },
    [2] = {
      StepFunction = "Priority",
      Reset="target,combat",
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Crusader Strike",
    },
    [3] = {
      StepFunction = "Priority",
      Reset="target",
      Head=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast Avenging Wrath",
        "/cast Shield of Vengeance",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease={
        "/cast Hand of Hindrance",
      },
    },
    [4] = {
      StepFunction = "Sequential",
      LoopLimit=5,
      Trinket1=true,
      Ring1=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      PreMacro={
        "/cast Avenging Wrath",
        "/cast [talent:5/2]Eye for an Eye",
      },
      "/cast [talent:5/1] Justicar's Vengeance",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      PostMacro={
        "/cast Shield of Vengeance",
      },
      KeyRelease={
      },
    },
  }
}

Sequences['SAM_RetAOE'] = {
  Author="TimothyLuke",
  SpecID=70,
  Icon='INV_MISC_QUESTIONMARK',
  Lang="enUS",
  Talents="1112111",
  Helplink="https://wowlazymacros.com/forums/topic/tls-ret-macro/",
  Default=1,
  Raid=2,
  PVP=3,
  Mythic=4,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      SoundErrorPrevention=true,
      Trinket1=true,
      Trinket2=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast Avenging Wrath",
        "/cast Shield of Vengeance",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Divine Storm",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease={
      },
    },
    [2] = {
      StepFunction = "Priority",
      Reset="target,combat",
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Divine Storm",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Crusader Strike",
    },
    [3] = {
      StepFunction = "Priority",
      Reset="target",
      Head=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast Avenging Wrath",
        "/cast Shield of Vengeance",
      },
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Divine Storm",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease={
        "/cast Hand of Hindrance",
      },
    },
    [4] = {
      StepFunction = "Sequential",
      LoopLimit=5,
      Trinket1=true,
      Ring1=true,
      KeyPress={
        "/targetenemy [noharm][dead]",
      },
      PreMacro={
        "/cast Avenging Wrath",
        "/cast [talent:5/2]Eye for an Eye",
      },
      "/cast [talent:5/1] Justicar's Vengeance",
      "/cast Divine Storm",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      PostMacro={
        "/cast Shield of Vengeance",
      },
      KeyRelease={
      },
    },
  }
}

-------------------
-- Holy - 65
-------------------

Sequences['SAM_HolyDeeps'] = {
  SpecID = 65,
  Author = "TimothyLuke",
  Help = "Holy DPS levelling macro",
  Talents = "3,1,3,1,1,2,3",
  Icon = "Ability_Paladin_InfusionofLight",
  Default=1,
  MacroVersions = {
    [1] = {
      KeyPress = {
        "/targetenemy [noharm][dead]"
      },
      '/cast Judgment',
      '/cast Crusader Strike',
      '/cast Consecration',
      '/cast [combat]!Avenging Wrath',
      '/cast Blinding Light',
      '/cast Holy Shock',
      '/cast Divine Protection',
    }
  }
}
