# GSE

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Resources popup — Copy button can no longer wrap)

### Fixed
- **Resources popup Copy button no longer wraps onto the next row's icon.** Each row's Copy button is now pinned to the right edge of its row (a right-aligned Flow child, which skips the wrap test), so it is structurally unable to spill onto a second line at any UI scale or font size. The URL box beside it now fills the space between the icon and the Copy button instead of using a fixed width, so it adapts to the popup's real content width. This replaces the earlier pixel-width tweaks, which depended on guessing the live content width and did not reliably hold. To make a filled body and a right-pinned control share one Flow row without overlapping, `flowFillRemaining` now reserves the width of any right-aligned siblings (`GSE_GUI/NativeUI.lua`); this is additive and changes no existing layout, since no other container combines the two.

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Resources popup — tighten row gap)

### Changed
- **Resources popup rows are tighter.** The Flow gap at the end of each row dropped from 5 to 2 (`RESOURCE_ROW_FLOW_GAP`), pulling the Copy button in toward its URL box (and reclaiming a little row width so it sits on the row rather than wrapping).

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Resources popup sizing — fix Copy-button wrap)

### Fixed
- **Resources popup no longer wraps the Copy button onto a second line.** The popup is 40px wider and 40px taller, and the URL text boxes are 20px shorter, giving the row's Flow layout enough clearance for the icon + URL box + Copy button (width 510->550, height 382->422, `RESOURCE_BODY_WIDTH` 298->278).

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Internal: Debugger local-variable headroom)

### Internal
- **Sequence Debugger no longer sits on Lua 5.1's per-chunk local limit.** `GSE_GUI/DebugWindow.lua` was exactly at the 200-local ceiling (zero room to add another file-scope local on Vanilla/Classic). Its ~36 layout/dimension constants were collapsed into a single `DEBUG_UI` table, freeing about 35 local slots. No behaviour change — purely register-pressure relief so the debugger can take future additions.

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Toolbar auto-swap removed; debugger & popup tweaks)

### Removed
- **GSE Toolbar Slide-Out auto-swap removed.** The Slide-Out toolbar no longer tries to auto-flip its pop-out direction near a screen edge; it always slides the icons out in the direction you choose from the right-click menu. The auto-flip was too buggy, and the related scale tweak to the on-screen clamp was reverted too, so the toolbar clamp behaves exactly as it did before.

### Changed
- **Debugger bottom button row order is now Hardware, Tracker, Reload, Stats.**
- **Debugger "Output Selection" label nudged up 2px.**
- **Resources popup now sits 15px right of screen centre** (previously dead-centre).

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Debugger Tracker toggle; Resources popup centring)

### Added
- **Tracker On/Off toggle on the Sequence Debugger.** A new "Tracker: On/Off" button sits in the debugger's lower button row (order: Hardware, Tracker, Reload, Stats). It toggles the same master Tracker switch as the Options panel's "Tracker On / Off" checkbox (`GSEOptions.SequenceIconFrame.Enabled` via `GSE.SetSequenceIconFrameEnabled`), so the two controls mirror each other and the debugger button label refreshes to match the current state.

### Changed
- **Resources popup now centres on the screen.** It previously opened offset beside whichever window launched it; it now appears centred on the screen (later nudged 15px to the right).

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Editor: block focus & arrow navigation)

### Changed
- **Focusing an action block no longer recentres the view.** If the block you focus is already visible, the scroll position is left alone; it only scrolls when the block is off an edge, and then just enough to bring that edge into view rather than snapping it to the centre.
- **Arrow keys now navigate block focus; Shift + arrows move the block.** With an action block focused, Up/Down moves the focus to the previous/next block (in on-screen order, including inside If branches and loops) without reordering. Hold Shift with Up/Down to move (reorder) the focused block, as the arrows did before. The focused block is kept in the viewable area in both cases.

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Editor: open to last sequence)

### Changed
- **The editor now opens to the last sequence you had open, honouring the tree filter.** Previously it discarded the remembered sequence whenever it did not belong to your current class and fell back to the current class. Now:
  - **Show all classes on:** reopen to the last sequence you were working on, regardless of the class/spec you are currently on.
  - **Show all classes off (current class only):** reopen to the last sequence if it belongs to your current class; otherwise expand to your current class/spec as before.

  Driven by `GSEOptions.filterList["All"]`. The remembered path is still persisted in the saved sequence-editor options, and the restored sequence's class node is expanded so it is revealed even when it differs from your current class.

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-30 (Editor: delayed spell translations)

### Added
- **"Delayed Spell Translations" option** (Options > Tools & Diagnostics) — honours a long-standing request to let users turn off real-time parsing of the macro editor for older machines. A single checkbox, off by default, stored in `GSEOptions.DelayedSpellTranslations` and read live by the editor (no reload):
  - **Off (default):** the editor translates and colours spell IDs/names live as you type while editing.
  - **On:** the editor defers translation/colouring until you click out of a box, reducing editor lag on older machines.

  The authored macro text is always stored as you type either way, and focus-loss always reconciles the compiled macro, so nothing is ever lost — only the derived translation/colouring is deferred. This affects the editor only; GSE does not translate anything during normal gameplay (compiled macros are fired directly).

## [3.3.19-10-g7e2a200-PatronBuild] — 2026-05-29 (Release prep)

Native-UI ("no Ace") fork. Replaces the AceGUI layer with a native Blizzard-style UI implemented in `GSE_GUI/NativeUI.lua`. Supports Vanilla (11508), TBC (20505), MoP Classic (50503/50504), and Retail (120005).

### Headline fixes
- **Macro-editor cursor no longer snaps back after spell-name translation.** Per-line cursor mapping preserves caret position when the editor's translator pipeline rewrites a line.
- **Editor resize is live and smooth.** Native resize is driven by a self-cancelling OnUpdate pump throttled to ~50 fps (interval 0.02 s); it stops on mouse-up and on frame hide and allocates no per-frame tables.

### Tracker
- Single source of truth for the "show sequence name" default: the constant `Statics.TrackerConfig.DefaultShowSequenceName` is now referenced by both default layout presets (X and Y), by `Tracker.lua`'s `EnsureSequenceIconFrameOptions`, and by `Options.lua`'s mirror init and `ResetTrackerToDefaultLayout` — five sites that previously each hard-coded `true`.

### Spell library
- TBC and MoP empty spell-list stubs (27 + 34 = 61 files) removed from the package and from `GSE_QoL.toc`. `GSE.LookupSpellList` already returns an empty list for unregistered version/class/spec triples, so the behaviour for TBC and MoP is unchanged. Vanilla (27) and Retail (39) spell lists are unaffected.

### Slash commands
- `/gse help` now documents the standalone commands: `/gseresettracker`, `/gsesavelayoutx`/`Y`, `/gseapplylayoutx`/`Y`, `/gseiconscan`, `/gsespelliconreset`, `/gsesaveallsequences`, and `/rl`.

### Quality of life
- Skyriding / Vehicle Keybinds editor tree node now ships and uses its own `skyriding.png` icon (the art was previously missing from the package, which had left the node's icon broken on all clients).
- Three superseded chevron textures (`chevron-down`, `chevron-up`, `dropdown-chevron`) removed; no code references them.
- `GSE_QoL/Spells/README.md` rewritten to match the actual `GSE.RegisterSpellList(version, classFile, specKey, names)` API and the shipped Vanilla/Retail-only layout.

### Internals / hygiene
- Raw error prints (`print(err)`, `print(error)` in Storage.lua and the leftover `print("Processed test link foo")` in Serialisation.lua) removed or routed through `GSE.PrintDebugMessage("...", "Storage")` so nothing prints to chat on a normal load.
- Duplicate `Statics.PrintKeyModifiers` definition removed (the second of two identical assignments was kept — the macro-debug snippet behaviour is unchanged).
- Two `luacheck` same-scope shadowing warnings fixed: `Editor_Variable.lua` lost a dead outer `fmt`, and an inner action-bar slot variable in `Storage.lua` was renamed to `actionSlot` so it no longer shadows the outer sequence-action local.
- Dead duplicate `GSE/Init.lua` (unreferenced by the TOC; `API/Init.lua` is the loaded one) removed.
- `.luacheckrc` added for reproducible lint runs.

### Verified
- All 127 first-party `.lua` files pass `luac5.1 -p`.
- Every TOC-referenced file exists on disk; every texture path referenced in code resolves to a file under `Assets/`.
- Localization fallback verified: `__index` on `GSE.L` returns the key on a miss, so missing translations render as English and never error. `enUS` is now complete — every `L[...]` key used in first-party code is defined there (4 recently-added plain-English keys for the Delayed Spell Translations option and the `/gse help` standalone-command list were back-filled this pass), and no token-style keys are missing. All 11 locale files pass `luac5.1 -p`, and each translated file is gated by an `if GetLocale() ~= "xx" then return end` guard.
- `COMBAT_LOG_EVENT_UNFILTERED` is not registered with a handler in first-party code (no per-event work on combat-log spam).

### Compatibility
- TOC `## Interface` line unchanged: `11508, 20505, 50503, 50504, 120005`.
- Cross-client API calls are routed through `GSE/API/Native.lua`'s shim layer (existence check then legacy global fallback). Spot-checked sites in `Tracker.lua`, `translator.lua`, `Storage.lua`, and `Editor_Keybind.lua` all use the guarded pattern.
- Patreon, Wago, Curse and WoW Interface resource links retained.

### Release verification (final pass)
- **Stale developer notes corrected.** The `/gseresettracker` comment in `Options.lua` now points at the real registration site (`GSE_Utils/SlashCommands.lua`, not the old `Editor.lua`), and a dangling reference to a non-shipped `CURSOR_FIX_NOTES.md` was removed from `Editor.lua` (the per-line cursor-mapping design is already documented inline).
- **`.luacheckrc` hardened for a meaningful lint signal.** It now declares GSE's intentional writable globals (the legacy `GSELibrary`/`GSE3Storage` migration targets, the `GSE_Ed25519Verify`/`GSE_SHA512` crypto exports, the conditional `SaveBindings` polyfill, Blizzard's `ColorPickerFrame`, and GSE's `Settings*ControlMixin` tables) and the WoW `string.split/join/trim` extensions, and scopes its ignore list (underscore-unused, fixed-signature callback args, cosmetic whitespace) so a genuinely *accidental* global would still surface. The file-scope `opts` snapshot in `Tracker.lua` was renamed to `initialOpts`, clearing 8 upvalue-shadow warnings without touching the eight functions that correctly re-fetch fresh options each call. Result: **0 errors**; the ~15 residual warnings are all verified-benign (intentional fresh-fetch upvalue re-binds plus two defensive `0,0` initializers).
- **Additional items audited and confirmed clean (no change required):** SavedVariables initialisation for both fresh installs and upgrades (file-scope `GSEOptions` defaults, `nil`-only backfills that preserve user settings, version-gated `OneOffEvents` migrations); combat/taint safety (secure `SetAttribute` work gated by `InCombatLockdown`, a secure-handler snippet completing state transitions where the engine allows it, and `PLAYER_REGEN_ENABLED` re-applying deferred work); frame hygiene (singleton-guarded or pooled frames, no per-event `CreateFrame`, transient drag indicators on `TOOLTIP` strata, no self-anchors); import/export error UX (`DecodeMessage` is `pcall`-protected and bad input surfaces the friendly "Import String Not Recognised." dialog rather than a raw error); embedded-library integrity (all 21 vendored lib files parse; `LibStub`/`CallbackHandler` multiple-loads are idempotent by design); and the resize / smooth-scroll / tracker-drag `OnUpdate` pumps (throttled, self-cancelling, no per-frame allocation).
- **Cross-client caveat (documented, not a regression):** `C_EncodingUtil` — GSE's core serialisation primitive, used by every `EncodeMessage`/`DecodeMessage` call and therefore by every sequence stored in `GSESequences` — is intentionally called unguarded. This matches upstream exactly, relies on the API being present on every modern-engine flavour GSE ships to, and cannot take a "legacy fallback" without breaking compatibility with the `C_EncodingUtil`-format data already in users' SavedVariables.
- **Requires an in-game client to finish (verified at the code level here):** a clean-`WTF` fresh-install load with zero errors at `PLAYER_LOGIN`; an upgrade load over pre-fork SavedVariables; and the on-screen visual confirmation of the live editor-resize and macro-editor cursor-stability fixes on Retail plus one Classic flavour.


## [3.3.18](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/tree/3.3.18) (2026-05-18)
[Full Changelog](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/compare/3.3.17...3.3.18) [Previous Releases](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/releases)

- #1890 Update import script  
- #1890 Change metadata test to match current expansion  
