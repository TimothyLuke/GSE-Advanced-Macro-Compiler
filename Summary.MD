# GSE 1914/1924 snapshot review — Summary

Cross-snapshot diff + notes for the nine `GSE_*` zips, taken against the
`1914-Gui-Only` branch point they were all built from.

- **Common baseline (all 9 snapshots):** GSE `3.3.19-18-g657a37a-PatronBuild`
  → git commit **`657a37a`** ("#1914 More code cleanup") on branch
  **`1914-Gui-Only`**.
- **Branch has since moved 5 commits past that point** (not in any snapshot):
  `1b0ad1ca` EllesmereUI look-and-feel · `74ce89f1` menu graphic ·
  `e7abc049` keybind-clear fix · `628caa87` restore skyriding keybinds ·
  `228dbc7f` remove AceConsole reference (current HEAD).
  → **Any of this work needs rebasing onto current HEAD**, and HEAD already
  contains a fuller AceConsole removal than the snapshots' partial one.
- **WoW interface targeted:** `120005` (patch 12.0.5).
- **Real changed source files vs baseline: 15** (+ the generated patron list).
  Everything else that "differs" from the git tree is build noise (see below).

> **These are sibling working-copies, not a clean linear chain.** Each zip is the
> shared working base plus a *subset* of the in-progress features. The subsets do
> **not** strictly nest (e.g. the earliest `abo` snapshot carries more features
> than the later `macro-charcount`), so treat the timestamps as session labels,
> not a dependency order. The intended cumulative head is
> **`options-dropdown-strata` / `b1153`** — they are byte-identical in source.

---

## What is *not* a real change (filtered out of the diffs)

The git tree holds build tokens; the packaged "PatronBuild" zips have them filled
in. None of this is feature work and it is excluded from every diff here:

- **Token substitution** in `GSE.toc`, `GSE_GUI.toc`, `GSE_LDB.toc`,
  `GSE_Options.toc`, `GSE_QoL.toc`, `GSE_Utils.toc`, all `Localization/ModL_*.lua`,
  and `GSE/API/Init.lua` — `@project-version@` → the build string, etc.
- **`GSE_Utils/Patrons.lua`** — the supporter name list (~585 lines churned). Generated, not code.
- **`GSE/embeds.xml`, `GSE_Utils/embeds.xml`** — *line-ending only* (CRLF↔LF); no real change.
- **`Lib/…`** — embedded third-party libraries (Ace3, LibQTip-2.0, LibStub, LibDBIcon, LibSharedMedia, WagoAnalytics). Not GSE source.
- **`b1153` vs `options-dropdown-strata`:** the *only* difference is that the
  `options-dropdown-strata` zip carries an embedded `Changes …/` package folder;
  the addon source is identical.
- The `GSE_1924_macro-charcount` zip was a **double-zip** — it also bundled the
  `options-dropdown-strata` snapshot (verified byte-identical to its standalone zip).

---

## The shared working base (present in **all 9** snapshots)

This is the groundwork every snapshot inherited on top of `657a37a`. It already
contains the namesake features of the earliest sessions (macro char-counter,
abo-highlight). 6 real files + option defaults:

| File | ~lines | What it does |
|---|---|---|
| `GSE_GUI/Editor.lua` | 136 | Macro **"X/255" counter now measures the *compiled* body length** (new `GSE.GUI.GetCompiledMacroBodyLength`), so the indicator agrees with the over-limit trigger and what WoW enforces on the slot. |
| `GSE_GUI/Editor_Macro.lua` | 8 | Same change at the per-macro edit box — counter uses compiled length, not raw typed length. |
| `GSE/API/Events.lua` | 180 | Two engines: (1) **UI-error filtering + voice / lower-energy muting** (`FilterUIErrorsFrame`, `SetErrorSpeechMuted`, `SetLowerEnergyMuted`, `GSE.ApplyErrorMessageOptions`); (2) **action-bar highlight verification** — `GSE:ACTIONBAR_SLOT_CHANGED`, `GSE.ActionBarSlotHasForeignAction`, override-button re-evaluation. (The "abo-highlight-verified" namesake.) |
| `GSE/API/Storage.lua` | 6 | **Icon-flicker fix:** don't repaint a GSE button's icon when the player has dropped a *foreign* action into that slot (uses `ActionBarSlotHasForeignAction`). |
| `GSE_GUI/NativeUI.lua` | 18 | **Editor scrollbar fix:** re-parents the macro editor's scrollbar onto the outer (un-clipped) frame and anchors it in the right gutter — it was being clipped away by `SetClipsChildren`, so the editor looked like it had no scrollbar. |
| `GSE/API/Native.lua` | 4 | Comment-only: drops the `AceConsole` / `RegisterChatCommand` mention from the Ace3 mixin note. |
| `GSE/API/InitialOptions.lua` (subset) | — | **Option defaults in all 9:** `HideUIErrorFrame`, `MuteVoiceErrors`, `MuteLowerEnergy` (with nil-guards). *Note:* the larger center-scaling math in this file is a feature patch (below), present in 8 of 9. |

---

## Feature patches (only in some snapshots)

Each is an independent patch on the shared base. See the matrix for membership.

1. **center-scaling** — `GSE_GUI/Menu.lua` + `GSE/API/InitialOptions.lua`.
   Scales the toolbar **about its centre** by capturing the centre in absolute
   screen pixels across `SetScale` (was drifting by `newScale/oldScale`), and adds
   `frame.GSESkipScaleClamp` so a self-clamping frame opts out of GSE's post-scale
   clamp — which used to permanently re-anchor the frame and cause the "left jump"
   on scale-down.
2. **scroll-speed** — `GSE_GUI/Editor_Tree.lua`. Removes the hardcoded
   `SetScrollStep(96)` on the editor panes so they inherit the live,
   Options-driven `SCROLL_STEP` set by the "Editor Scroll Speed" slider.
3. **casting detection** — `GSE_Utils/Events.lua`. Adds `ResolvePlayerCast` and the
   debug **"Casting"** / **"Next Cast"** columns; gates "Next Cast" on the Retail
   `C_AssistedCombat` API; works around WoW **12.0 secret spell names in combat** by
   reading the spell ID and the never-secret cast-bar ID. Present in all 9 but in
   **4 maturity variants** — the integrated head uses the `help/debug/options`
   variant; `casting-events` carries a *different, more elaborate* variant that did
   **not** reach `b1153`.
4. **debug window** — `GSE_GUI/DebugWindow.lua`, three stacked levels:
   - **L1** Casting column shown (abo, casting-events)
   - **L2** + successful-cast fallback row marking, `MarkSuccessfulCastRow` (help-spells)
   - **L3** + reorderable / sortable columns with saved order:
     `CopyDebugColumnOrder`, `MoveDebugColumnBefore`, `activeDebugSort`,
     `GetVisibleDebugColumnOrder` (debug-column-sort-move, options, b1153)
5. **options-dropdown-strata** — `GSE_Options/Options.lua`. Raises the Settings-panel
   dropdown popouts to `TOOLTIP` strata so they render in front of the panel
   (`RaiseOptionsDropdown*`, structural `FrameHasButtonChildren` walk for the
   anonymous `SelectionPopout`), and adds an **"Error Messages"** settings section
   wiring up the mute options. (options, b1153)
6. **toolbar plumbing** — `GSE_Utils/Utils.lua`, 2 variants (`CommandColour`,
   `ToolbarEnabled`, `frameLocations.menu.open`). Variant A: macro/center/scroll;
   Variant B: abo/help/casting/debug/options/b1153.

---

## Feature × snapshot matrix

Chronological by filename timestamp. ✓ = shared base (in all). Cells show the
variant where one file has several.

| Snapshot (session time) | char-count ✓ | abo-highlight ✓ | mute-defaults ✓ | center-scaling | scroll-speed | toolbar Utils | casting (Events) | DebugWindow | options-strata |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `abo-highlight-verified` (Jun-01 ~21:35) | ✓ | ✓ | ✓ | ✓ | ✓ | B | abo | L1 | — |
| `macro-charcount` (Jun-01 23:00) | ✓ | ✓ | ✓ | — | — | A | v3 | — | — |
| `center-scaling` (Jun-01 23:30) | ✓ | ✓ | ✓ | ✓ | — | A | v3 | — | — |
| `help-spells-ooc-casting` (Jun-01 23:30) | ✓ | ✓ | ✓ | ✓ | ✓ | B | help | L2 | — |
| `scroll-speed` (Jun-01 23:45) | ✓ | ✓ | ✓ | ✓ | ✓ | A | v3 | — | — |
| `debug-column-sort-move` (Jun-02 00:15) | ✓ | ✓ | ✓ | ✓ | ✓ | B | help | L3 | — |
| `casting-events` (Jun-02 00:50) | ✓ | ✓ | ✓ | ✓ | ✓ | B | **casting** | L1 | — |
| `options-dropdown-strata` (Jun-02 01:30) | ✓ | ✓ | ✓ | ✓ | ✓ | B | help | L3 | ✓ |
| `b1153` (untimed; = options src) | ✓ | ✓ | ✓ | ✓ | ✓ | B | help | L3 | ✓ |

**Things this surfaces:**
- `b1153` and `options-dropdown-strata` are the integrated head (everything except the divergent `casting-events` Events variant).
- The `macro/center/scroll` trio is a *less-merged* sub-lineage (Utils **A**, Events **v3**, DebugWindow at baseline) — they're missing scroll-speed and/or center-scaling and the toolbar-B / casting work.
- `casting-events` is a fork: its `GSE_Utils/Events.lua` is more elaborate than the head's, but it dropped back to DebugWindow **L1** — so picking it up means reconciling its Events variant against the head's.

---

## How this was verified

- **Diffs are appliable and reproduce the snapshots exactly.** Every one of the 15
  source diffs passes `git apply --check` against `657a37a` (0 rejects) and applies
  with `patch -p1 --binary`. Each `DIFF/by-snapshot/<name>.combined.diff` was applied
  onto a fresh `657a37a` checkout — all 9 apply clean, and `b1153` reconstructs
  **byte-for-byte** (only the embedded `Lib/` dirs differ, which aren't source).
- **Factoring validated:** rebuilding 5 snapshots (`abo`, `macro-charcount`,
  `debug-column-sort-move`, `options-dropdown-strata`, `b1153`) from
  `baseline + 00-shared-base.diff + the feature patches` reproduces every source file.
- **CRLF preserved** in all diffs (matches the addon's line endings).

> **Honest caveat:** this is a structural / textual analysis of the packaged code.
> I could not run a Lua linter (no Lua runtime in this environment) or the live WoW
> client, so there is no runtime check here — the per-feature in-game reasoning lives
> in each session's own `Changes …/Summary.MD` (two of which were bundled inside the
> zips). Confidence in the *diff accuracy* is high (byte-exact reconstruction);
> in-game behaviour should still be tested per the original session notes.

---

## What's in this package

```
GSE_1924_snapshot-review-20260602/
├── Summary.MD                         ← this file
├── DIFF/
│   ├── 00-shared-base.diff            ← 657a37a → common groundwork (6 files, all 9 snapshots)
│   ├── 10-center-scaling__Menu.diff
│   ├── 11-scroll-speed__Editor_Tree.diff
│   ├── 12-mute-defaults__InitialOptions_shared-all.diff
│   ├── 13-toolbar__Utils_variantA.diff / 13-toolbar__Utils_variantB.diff
│   ├── 14-center-scaling__InitialOptions.diff
│   ├── 20/21/22-debug__DebugWindow_*.diff   ← L1 Casting col / L2 cast-fallback / L3 sort+move
│   ├── 30/31/32-casting__UtilsEvents_*.diff ← Events variants (abo / help / casting)
│   ├── 40-options__Options_pre-strata.diff
│   ├── 41-options-dropdown-strata__Options.diff
│   └── by-snapshot/<name>.combined.diff     ← one self-contained diff per snapshot
└── MD/<file>.lua.md                   ← per-file write-ups
```

**Apply a whole snapshot onto the branch point:**
```
git checkout 657a37a            # the common baseline
patch -p1 --binary < "DIFF/by-snapshot/b1153.combined.diff"
```
(then rebase onto current `1914-Gui-Only` HEAD — remember the 5 newer commits above.)
