-- Vanilla Warrior — Arms
-- Source: https://www.icy-veins.com/wow-classic/warrior-dps-pve-spell-summary
--         https://www.wowhead.com/classic/spells/abilities/warrior
-- Active abilities a warrior might macro.  Passives (Tactical Mastery,
-- Improved Overpower, Flurry, Block, Parry, Dodge) are omitted — they
-- can't be cast.

GSE.RegisterSpellList("Vanilla", "WARRIOR", "Arms", {
    -- Stances
    "Battle Stance",
    "Defensive Stance",
    "Berserker Stance",
    -- Core rotation (Arms-specific marked)
    "Mortal Strike",     -- Arms 31-pt talent
    "Overpower",
    "Slam",
    "Hamstring",
    "Rend",
    "Execute",
    "Heroic Strike",
    "Cleave",
    "Whirlwind",
    "Thunder Clap",
    "Sunder Armor",
    -- Movement
    "Charge",
    "Intercept",
    -- Cooldowns
    "Sweeping Strikes",  -- Arms talent
    "Retaliation",
    "Recklessness",
    "Bloodrage",
    "Berserker Rage",
    -- Defensive
    "Shield Wall",
    "Shield Block",
    -- Interrupts / disarms / CC
    "Pummel",
    "Shield Bash",
    "Disarm",
    "Intimidating Shout",
    "Mocking Blow",
    -- Threat
    "Taunt",
    "Challenging Shout",
    -- Shouts / buffs
    "Battle Shout",
    "Demoralizing Shout",
})
