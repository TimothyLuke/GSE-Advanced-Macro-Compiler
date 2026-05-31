# GSE PatronBuild — Change Summary
### "Remove Ace3 GUI dependency" — target: `TimothyLuke/GSE-Advanced-Macro-Compiler`

This describes the changeset captured in **`GSE_remove-ace3_changes.diff`**.

## Comparison basis
- **Baseline (`a/`)** — the attached build, which still bundles the Ace3 stack and uses the AceGUI-based interface.
- **Proposed (`b/`)** — Ace3 removed, replaced by a native (no-Ace) UI, plus the release-prep fixes from this session.
- Both carry the same TOC version: `3.3.19-10-g7e2a200-PatronBuild`.

## At a glance
| | count |
|---|---|
| Files modified | 72 |
| Files removed | 63 (39 vendored Ace3 lib files + 4 custom AceGUI extensions + 20 unused assets) |
| Files added | 93 (native UI + spell-data library + assets + lint config) |

---

## Removed
**Vendored Ace3 libraries — 39 files across 8 suites:** `AceAddon-3.0`, `AceComm-3.0`, `AceConsole-3.0`, `AceEvent-3.0`, `AceGUI-3.0`, `AceGUI-3.0-Completing-EditBox`, `AceLocale-3.0`, `AceTimer-3.0`. *(Listed here rather than dumped into the diff — they are third-party.)*

**Custom AceGUI extensions — 4 files** (under `GSE_GUI/Ace3_Extensions/`): `AceGUI-3.0-Controller_KeyBind`, `AceGUI-3.0-GSETreeGroup`, `AceGUI-3.0-Spacer`, `AceGUIContainer-KeyGroup`.

**Unused assets — 20 files:** old muted-icon variants and superseded logos (`*_muted.png`, `GSE_Menu_Logo.png`, `NewPlus.png`, `redbutton.png`, `hide.png`/`show.png`, etc.) no longer referenced by the native UI.

## Added
**Native UI core:** `GSE_GUI/NativeUI.lua` (6,646 lines — the AceGUI replacement), `GSE/API/Native.lua`, `GSE_GUI/Editor_Undo.lua`, `GSE_Utils/SlashCommands.lua`, `GSE_QoL/SpellLibrary.lua`.

**Spell-data library — 66 files (+README):** `GSE_QoL/Spells/Retail/` (39) and `GSE_QoL/Spells/Vanilla/` (27), organised per class/spec.

**Lint config:** `.luacheckrc` — reproducible `luacheck` config for the fork.

**Assets — 20 files:** native-UI icons/logos plus this session's additions (`classbar.png`, `TimGnome.png`, `Oak.png`, `skyriding.png`).

## Modified — 72 files by sub-addon
`GSE` 29 · `GSE_GUI` 29 · `GSE_Utils` 8 · `GSE_LDB` 2 · `GSE_Options` 2 · `GSE_QoL` 2.
Most are adaptations from AceGUI calls to the native UI; per-line detail is in the diff.

---

## This session's release-prep changes
The specific edits made in this packaging session, *on top of* the broader native-UI rework:

1. **`.luacheckrc` (new)** — declares GSE's intentional globals and the necessary WoW-API ignore (W113), so `luacheck` runs clean and reproducibly (15 benign warnings / 0 errors).
2. **`GSE_Utils/Tracker.lua`** — renamed the file-scope `opts` snapshot to `initialOpts` to clear upvalue-shadow warnings, **then fixed a regression** where four load-time references (lines ~506 / 532 / 551 / 3367) still said `opts` and crashed with `attempt to index global 'opts' (a nil value)`. All four now use `initialOpts`, restoring the original behavior.
3. **`GSE_Options/Options.lua`** — corrected a stale source comment; moved the `classbar.png` texture path to `GSE_GUI/Assets`.
4. **`GSE_GUI/Editor.lua`** — removed a dangling reference to a non-existent `CURSOR_FIX_NOTES.md`.
5. **`GSE/Localization/ModL_enUS.lua`** — back-filled 4 used-but-undefined English strings.
6. **`GSE_GUI/Statics.lua` + `GSE_GUI/Editor_Tree.lua`** — added an "Oak – YouTube" resource link (icon + panel entry).
7. **`GSE_GUI/Export.lua`** — the export window now pre-selects the object it was opened for.
8. **`GSE_QoL/QoL.lua`** — the Skyriding / Vehicle Keybinds tree node now ships and uses its own `skyriding.png` icon (was a missing-art placeholder).
9. **`GSE_GUI/DebugWindow.lua`** — nudged the "Output Selection" label down 1px for alignment.
10. **Asset moves** — `classbar.png` + `TimGnome.png` relocated from `GSE_Options/Assets` to `GSE_GUI/Assets`; the now-empty `GSE_Options/Assets/` folder was removed.
11. **`GSE/CHANGELOG.md`** — documented the above.

See **`OUTSTANDING_ITEMS.md`** for what still needs checking before/after merge.
