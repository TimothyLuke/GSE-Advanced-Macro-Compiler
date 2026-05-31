# GSE Spell Library

Per-version, per-class, per-spec spell name lists exposed on the GSE
namespace (`GSE.SpellLibrary` / `GSE.LookupSpellList`). They provide a
static fallback set of spell names for a class/spec, used when a live
spellbook query can't reach a class (e.g. browsing spells for a class you
are not currently logged in as).

## Layout

```
Spells/
  Vanilla/        ← interface 11508 (9 classes)
    Warrior/
      Arms.lua
      Fury.lua
      Protection.lua
    ...
  Retail/         ← interface 120005 (13 classes)
    ...
```

Only **Vanilla** and **Retail** lists ship. TBC (20505) and MoP
(50503/50504) data is **not** included: rather than ship empty stub
registrations, those versions are simply absent and `GSE.LookupSpellList`
returns an empty list for them (its documented behaviour for any
unregistered version/class/spec). If TBC/MoP data is gathered later, add
`Spells/TBC/<Class>/<Spec>.lua` and `Spells/MoP/<Class>/<Spec>.lua` files
and list them in `GSE_QoL.toc`.

## File format

Each `<Class>/<Spec>.lua` registers its list by calling
`GSE.RegisterSpellList(version, classFile, specKey, names)`:

```lua
-- Vanilla Warrior — Arms
GSE.RegisterSpellList("Vanilla", "WARRIOR", "Arms", {
    "Mortal Strike",
    "Overpower",
    "Heroic Strike",
})
```

- `version`   — "Vanilla" | "TBC" | "MoP" | "Retail"
- `classFile` — uppercase class token as returned by `UnitClass` ("WARRIOR", "DEATHKNIGHT", ...)
- `specKey`   — English spec/tree display name ("Arms", "Beast Mastery", ...)
- `names`     — flat ordered array of English (en-US) spell names

Names are stored in **English**. At runtime they are resolved to the
client locale through the addon's translator pipeline
(`C_Spell.GetSpellInfo`, or the legacy `GetSpellInfo`, plus the per-locale
`GSESpellCache`). Populated files carry a header comment with the source
URL the data was taken from so it can be re-verified later.
