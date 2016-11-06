Sequences['Ret'] = {
  author="TimothyLuke",
  specID=70,
  icon='INV_MISC_QUESTIONMARK',
  lang="enUS",
  talents="1112111",
  default=1,
  raid=2,
  pvp=3,
  mythic=4,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      SoundErrorPrevention=true,
      Trinket1=true;
      Trinket2=true;
      KeyPress=[[
      /targetenemy [noharm][dead]
      /cast Avenging Wrath
      /cast Shield of Vengeance
      ]],
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease=[[
      ]],
    },
    [2] = {
      StepFunction = "Priority",
      reset="target,combat",
      KeyPress=[[
      /targetenemy [noharm][dead]
      ]],
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Crusader Strike",
    },
    [3] = {
      StepFunction = "Priority",
      reset="target",
      Head=true;
      KeyPress=[[
      /targetenemy [noharm][dead]
      /cast Avenging Wrath
      /cast Shield of Vengeance
      ]],
      "/cast [talent:5/1] Justicar's Vengeance; [talent:5/2]Eye for an Eye",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      KeyRelease=[[
      /cast Hand of Hindrance
      ]],
    },
    [4] = {
      StepFunction = "Sequential",
      LoopLimit=5,
      Trinket1=true,
      Ring1=true,
      KeyPress=[[
      /targetenemy [noharm][dead]
      ]],
      PreMacro=[[
      /cast Avenging Wrath
      /cast [talent:5/2]Eye for an Eye
      ]],
      "/cast [talent:5/1] Justicar's Vengeance",
      "/cast Templar's Verdict",
      "/cast Judgment",
      "/cast Blade of Justice",
      "/cast Wake of Ashes",
      "/cast Crusader Strike",
      PostMacro=[[
      /cast Shield of Vengeance
      ]],
      KeyRelease=[[
      ]],
    },
  }
}
