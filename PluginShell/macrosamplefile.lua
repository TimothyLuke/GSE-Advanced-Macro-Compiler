local ModName, Sequences = ... -- Library will hold some stuff if there are other files.if not it wont.

Sequences['EG_Feral-AoE'] = {
  SpecID = 103,
  Author = "Jimmy www.wowlazymacros.com",
  Talents = "2,2,3,1,1,2,3",
  Default=1,
  MacroVersions = {
    [1] = {
      StepFunction = "Priority",
      KeyPress = {
        "/targetenemy [noharm][dead]",
        "/cast [@player,nostance:2] Cat Form",
        "/cast [nostealth,nocombat] Prowl",
        "/stopattack [stealth]"
      },
      '/castsequence [combat,nostealth] Thrash,Swipe,Swipe,Thrash,Swipe,Rip',
      '/castsequence [combat,nostealth] Swipe,Thrash,Swipe,Swipe,Thrash,Ferocious Bite',
      KeyRelease={
        "/startattack",
        "/cast Tiger's Fury"
      },
    }
  },
}
