# GSE_1924 — Keybindings save under the wrong spec key on Legion/BfA/Shadowlands clients

| | |
|---|---|
| **Work item** | GSE_1924 (keybind spec-key fix) |
| **Target branch** | `1914-Gui-Only` (#1914) |
| **Base commit** | `2b4ea37` — *"#1914 TOC Updates for 12.0.07"* |
| **Matches build** | `GSE-3.3.19-30-g2b4ea37-PatronBuild` (same `g2b4ea37` commit) |
| **Date / time** | 2026-06-02 18:22 UTC |
| **File changed** | `GSE_GUI/Editor_Keybind.lua` (2 lines: 247, 432) |
| **Change** | `GSE.GameMode < 10` → `GSE.GameMode < 7` |
| **Risk** | Low — single literal in a version comparison; loader untouched |

> **Now based on your exact build source.** The `1914-Gui-Only` branch HEAD is commit `2b4ea37`, which is the `g2b4ea37` in your PatronBuild's name — so this branch *is* the source your build was compiled from. The bundled `GSE*` folders here therefore match your build line-for-line (the only difference from an installed build is the Ace3 libraries, which the repository does not vendor). The branch targets **12.0.07 (Midnight, GameMode 12)**.

---

## Reported symptom

> "Keybinding are hit and miss for users in Europe and Asia — sometimes they can set them / sometimes not / sometimes when they do set them they get cleared on reload."

## Root cause

`GSE.GameMode` is the WoW **major version number** (`GSE/API/Init.lua`): `tonumber((GetBuildInfo()):split(".")[1])`. So 7 = Legion, 8 = BfA, 9 = Shadowlands, 10 = Dragonflight, 11 = The War Within, 12 = Midnight.

GSE stores keybindings per-spec under `GSE_C["KeyBindings"][<specKey>]`. The **loader** and the **editor** derive `<specKey>` with **different version thresholds**.

**Loader — `GetSpec()` (`GSE/API/Events.lua`), also used by `CreateActionBarOverride`, `LoadKeyBindings`, `LoadOverrides`:**

```lua
local function GetSpec()
    if GSE.GameMode < 7 then                 -- threshold 7
        return "1"
    else
        if GSE.GameMode < 12 then
            return tostring(GetSpecialization())
        else
            local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
            return tostring(getSpec and getSpec() or 1)
        end
    end
end
```

**Editor — `showKeybind()` (`GSE_GUI/Editor_Keybind.lua`), the `KB` (line 247) and `AO` (line 432) branches, stored as `tostring(specialization)`:**

```lua
if GSE.GameMode < 10 then                    -- threshold 10  ← MISMATCH
    specialization = 1
else
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    specialization = getSpec and getSpec() or 1
end
```

For `GameMode` **7, 8, 9** the editor writes the binding under spec key **`"1"`**, but the loader re-reads it under the **live specialization index** (`"2"`, `"3"`, …). The buckets never meet, so the binding saves but never re-applies.

### Why "hit and miss" and "Europe and Asia"

- A character whose active spec resolves to index **1** stores and loads under `"1"`, so it works. Any **other spec** stores under `"1"` while the loader looks under `"2"`/`"3"` — the bind never activates and "disappears" after a reload or spec change; switching back to spec 1 can make it reappear. Hence the intermittency.
- `GameMode` 7/8/9 = **Legion / BfA / Shadowlands cores**, the private/emulated servers whose populations concentrate in Europe and Asia. Retail (10/11) and Midnight (12) were always correct, so no retail user reported it. This is not truly geographic.

### Corroboration on this branch

- The **actionbar-override save path** (`CreateActionBarOverride`, line ~841) already uses `GetSpec()` (threshold 7) and is correct — confirming threshold 7 is the canonical pattern and the editor's `< 10` is the outlier.
- `GameMode < 10` appears **only** at `Editor_Keybind.lua:247` and `:432` across the entire branch.

---

## The fix

Change the editor threshold from `< 10` to `< 7` in both `showKeybind` branches. `specialization` stays numeric and is still resolved by the branch's `getSpec` helper, so `tostring(specialization)` now equals `GetSpec()` for every client.

```diff
@@ showKeybind() — KB branch (line 247)
-            if GSE.GameMode < 10 then
+            if GSE.GameMode < 7 then
                 specialization = 1
             else
                 local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization

@@ showKeybind() — AO branch (line 432)
-            if GSE.GameMode < 10 then
+            if GSE.GameMode < 7 then
                 specialization = 1
             else
                 local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
```

Full patch: `GSE_1924_KeybindSpecKey.diff` (in this folder).

---

## Save-key vs load-key parity (verification)

Modelled on this branch's actual functions (incl. the `getSpec` resolver; `C_SpecializationInfo.GetSpecialization` present on 10+ and equal to `GetSpecialization`). Spec index 2 shown as the representative non-first spec; spec 1 always matched.

| GameMode | Client | Loader key | Editor (before) | Editor (after) | Before | After |
|---:|---|:--:|:--:|:--:|:--:|:--:|
| 1–6 | Classic … WoD | "1" | "1" | "1" | ✅ | ✅ |
| **7** | **Legion** | **"2"** | **"1"** | **"2"** | **❌** | **✅** |
| **8** | **BfA** | **"2"** | **"1"** | **"2"** | **❌** | **✅** |
| **9** | **Shadowlands** | **"2"** | **"1"** | **"2"** | **❌** | **✅** |
| 10 | Dragonflight | "2" | "2" | "2" | ✅ | ✅ |
| 11 | The War Within | "2" | "2" | "2" | ✅ | ✅ |
| 12 | Midnight | "2" | "2" | "2" | ✅ | ✅ |

**Mismatches before fix: 3 (GameMode 7/8/9). After fix: 0.**

### How this was verified

1. **Static** — `GameMode < 10` occurs only at lines 247 and 432; after edit, 0 remain and both read `< 7`.
2. **Syntax** — parsed the edited `Editor_Keybind.lua` with `luaparser`: no syntax regression.
3. **Logic** — reproduced both spec-key derivations (with this branch's `getSpec` resolver) across all 12 GameModes: 3 mismatches before (7/8/9), full parity after.
4. **Provenance** — confirmed the branch HEAD `2b4ea37` equals the `g2b4ea37` PatronBuild commit, so the defect is in your build.

**Not verifiable here:** the in-game AceGUI editor cannot be rendered, so no live screenshot. The change only selects a SavedVariables key — no widget/layout/button behavior changes, and editing *existing* bindings is unaffected (that path passes `specialization` explicitly and skips the changed block).

---

## Scope decisions

- **Loader untouched** — `GetSpec()` (threshold 7) is the reference; only the editor was wrong.
- **No data migration** — bindings previously created on 7/8/9 for non-first specs sit under `"1"` and were non-functional (the bug); affected users may re-create them once. Auto-relocating user data was judged too risky.
- **MoP (GameMode 5) bucketing unchanged** — it lumps specs as `"1"` consistently on both save and load, so it does not cause this bug; a separate question.

## Remaining risks / follow-ups

- **Duplicated threshold logic** in `GetSpec`, `Statics.lua`, and the two editor blocks drifted once. A shared `GSE.GetSpecKey()` used everywhere would prevent recurrence. Deferred to keep this change surgical.

## Installation

1. **Recommended:** apply `GSE_1924_KeybindSpecKey.diff` to your `1914-Gui-Only` checkout / PatronBuild, or change both occurrences of `GSE.GameMode < 10` to `GSE.GameMode < 7` in `GSE_GUI/Editor_Keybind.lua` (lines 247 and 432 on this branch). Because this package is built from your exact commit, those line numbers match your build.
2. The bundled `GSE*` folders are the **patched branch source** (commit `2b4ea37`) and do **not** include the Ace3 libraries — for review/diffing, not a standalone drop-in.
3. `/reload` or relog after applying. Affected users on Legion/BfA/Shadowlands should re-create any previously broken keybinds on their non-first specs.
