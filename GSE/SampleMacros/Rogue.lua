local GSE = GSE
local Statics = GSE.Static

Statics.SampleMacros[4] = {}

local Sequences = Statics.SampleMacros[4]

------------------
----- Rogue
------------------
-- Outlaw 260
-- Assination 259

Sequences['SAM_Assassin'] = {
  Author='TimothyLuke',
  SpecID=259,
  Talents = '3,1,1,3,2,3,1',
  Default=1,
  Icon='Ability_Rogue_DeadlyBrew',
  MacroVersions = {
    [1] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast [nostealth,nocombat]Stealth",
      },
      "/cast [@focus] Tricks of the Trade",
      "/cast Rupture",
      "/cast Vendetta",
      "/cast Vanish",
      "/cast Hemorrhage",
      "/cast Garrote",
      "/cast Exsanguinate",
      "/cast Envenom",
      "/cast Mutilate",
      }
    }
  }
}

Sequences['SAM_Subtle'] = {
  Author='TimothyLuke',
  SpecID=261,
  Talents = '1,2,3,3,2,1,2',
  Default=1,
  Icon='Ability_Stealth',
  MacroVersions = {
    [1] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast [nostealth,nocombat]Stealth",
        "/cast [combat] Marked for Death",
      },
      "/cast [@focus] Tricks of the Trade",
      "/cast Symbols of Death",
      "/cast Shadowstrike",
      "/cast Shadow Blades",
      "/cast Vanish",
      "/cast Nightblade",
      "/cast Shadow Dance",
      "/cast Shuriken Storm",
      "/cast Eviscerate",
      "/cast Backstab",
      }
    }
  }
}


Sequences['SAM_CalliynOutlaw'] = {
  Author="Ambergreen",
  SpecID=260,
  Talents = '1,3,3,3,1,3,1',
  Default=1,
  Icon="INV_Sword_30"
  MacroVersions = {
    [1] = {
      KeyPress={
        "/targetenemy [noharm][dead]",
        "/cast [nostealth,nocombat]Stealth",
        "/cast [combat] Marked for Death"
      },
      "/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Saber Slash",
      "/castsequence [mod:alt] Blade Flurry",
      "/castsequence Saber Slash, Run Through, Saber Slash, Pistol Shot",
      "/castsequence [talent:7/1] Slice and Dice; [talent:7/2][talent:7/3] Roll the Bones, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot, Run Through, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot",
      "/castsequence [mod:alt] Blade Flurry",
      "/castsequence Ghostly Strike, Saber Slash, Saber Slash, Saber Slash, Saber Slash, Pistol Shot",
      "/castsequence [mod:alt] Blade Flurry",
      "/cast [@focus] Tricks of the Trade",
      "/cast Crimson Vial",
      }
    }
  }
}
