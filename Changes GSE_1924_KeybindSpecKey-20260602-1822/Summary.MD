# Summary — GSE_1924 (KeybindSpecKey) · branch `1914-Gui-Only`

**Date:** 2026-06-02 18:22 UTC · **Base:** `1914-Gui-Only` @ `2b4ea37` (= your `g2b4ea37` PatronBuild) · **File:** `GSE_GUI/Editor_Keybind.lua` · **Change:** 2 lines

## What was wrong
Keybindings set in the GSE editor were inconsistent for users on **Legion / BfA / Shadowlands** clients (the "Europe and Asia" private-server populations) — sometimes they applied, sometimes not, and often stopped working after a reload.

## Why
`GSE.GameMode` is the WoW major version. The keybind **editor** stored bindings under spec key `"1"` whenever `GameMode < 10`, but the **loader** (`GetSpec()`, threshold `< 7`) re-read them under the live spec index. On GameMode **7/8/9** these disagree, so any spec other than #1 saved to a bucket the loader never reads. Spec #1 matched — hence "hit and miss." Retail (10/11) and Midnight (12) were always correct.

## The fix
Change the editor threshold from `< 10` to `< 7` (lines 247 and 432, the `KB` and `AO` branches), matching the loader. `specialization` stays numeric (resolved by the branch's `getSpec` helper); nothing else changes.

```diff
-            if GSE.GameMode < 10 then
+            if GSE.GameMode < 7 then
                 specialization = 1
```

## Verified
- File still parses (luaparser) — no syntax regression.
- Save-key vs load-key parity across all 12 client versions: **3 mismatches (7/8/9) before → 0 after**.
- Confirmed branch HEAD `2b4ea37` == your PatronBuild commit `g2b4ea37`, so the bug is in your build and the line numbers match.

## Notes
- Old bindings saved under `"1"` on 7/8/9 for non-first specs were already non-functional; re-create them once. No data migrated automatically.
- Bundled `GSE*` folders are patched **branch source** (no Ace3 libs) — for review/diffing, not a drop-in. Prefer applying the `.diff`.
- This branch omits `GSE_Personal` (not present on `1914-Gui-Only`); folders included: `GSE`, `GSE_GUI`, `GSE_LDB`, `GSE_Options`, `GSE_QoL`, `GSE_Utils`.

## Files in this package
- `GSE_1924_KeybindSpecKey.diff` — the patch (against `1914-Gui-Only`)
- `GSE_1924_KeybindSpecKey.md` — full root-cause analysis, parity table, verification
- `Summary.MD` — this file
- `GSE`, `GSE_GUI`, `GSE_LDB`, `GSE_Options`, `GSE_QoL`, `GSE_Utils` — patched branch source
