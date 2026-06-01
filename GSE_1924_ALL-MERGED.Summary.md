# GSE_1924 — Merged Summaries (all 9 fix bundles)

*Generated 2026-06-01 22:45. Per-bundle summaries, concatenated in chronological order.*

## Contents

1. [Scrollbar — 12:29 PM](#1-scrollbar)
2. [ArrowKeys — 12:47 PM](#2-arrowkeys)
3. [ReloadCmd — 12:55 PM](#3-reloadcmd)
4. [RemoveCtrlZ — 1:04 PM](#4-removectrlz)
5. [MultiEditor — 1:20 PM](#5-multieditor)
6. [toolbar-toggle — 7:06 PM](#6-toolbar-toggle)
7. [error-muting — 7:25 PM](#7-error-muting)
8. [aceconsole-removal — 8:30 PM](#8-aceconsole-removal)
9. [all-fixes — 8:54 PM](#9-all-fixes)

---

<a id="1-scrollbar"></a>

## 1. Scrollbar — 12:29 PM

> **Source:** `GSE_1924_Scrollbar-0612026-1229/Changes GSE_1924_Scrollbar-0612026-1229/Summary.MD`

# GSE_1924_Scrollbar-0612026-1229 — Summary

Fix package for the GSE macro **editor main scroll bar** not appearing.

- **Addon bundle:** GSE `3.3.19-18-g657a37a-PatronBuild`
- **WoW interface:** `120005` (patch 12.0.5)
- **Files changed:** 1 (`GSE_GUI/NativeUI.lua`)
- **Everything else in the bundle is unchanged.**

---

## Problem

The macro editor showed no main scroll bar, so long macro lists couldn't be
scrolled with the bar.

## Root cause

The editor's scroll frame (`UIPanelScrollFrameTemplate`) creates its scrollbar as
a child of the **inner** scroll frame. The constructor enables
`scrollFrame:SetClipsChildren(true)` to keep the macro content bounded, and
because a clip mask clips by parent, it clipped the scrollbar away too. The
`applyModernSlimScrollBar` helper only repositions the bar under the **ElvUI**
skin (it early-returns otherwise), so on the default skin nothing rescued it.

## Fix

In `createScrollFrame()`, re-parent the scrollbar onto the **outer** (unclipped)
frame and anchor it explicitly in the reserved right-hand gutter
(`TOPRIGHT`/`BOTTOMRIGHT` to the outer frame, width `STYLE.scrollBarWidth`, frame
level above the scroll frame). The existing `applyModernSlimScrollBar` call is
kept after the block — a no-op on the default skin, still styling under ElvUI.
The bar object and all of its scroll wiring are otherwise untouched, so scroll
behaviour (wheel, drag, smooth-scroll) is unchanged.

Per-file detail is in `MD/NativeUI.lua.md`; the unified diff is in `DIFF/`.

---

## How it was verified

- Loaded the real patched `NativeUI.lua` under a WoW stub, built a `ScrollFrame`
  widget through the actual `GSE.UI:Create` dispatcher, and confirmed
  `scrollbar:GetParent()` is the outer frame (not the clipped inner scroll frame).
- Negative control: the same harness against the unpatched file fails (bar still
  parented to the clipped inner frame) — confirming the test catches the real bug.
- `luac5.1 -p` passes; the patch in `DIFF/` reproduces the fixed file
  byte-for-byte; CRLF preserved; diff confirms only `NativeUI.lua` changed.

---

## Install

Replace this one file, then `/reload`:

```
World of Warcraft\_retail_\Interface\AddOns\GSE_GUI\NativeUI.lua
```

The full addon folders are also included at the root of this package
(`GSE/`, `GSE_GUI/`, `GSE_LDB/`, `GSE_Options/`, `GSE_QoL/`, `GSE_Utils/`) if you
prefer to drop in the whole bundle. Alternatively, from the AddOns folder:

```
patch -p1 --binary < "Changes GSE_1924_Scrollbar-0612026-1229/DIFF/GSE_1924_Scrollbar-0612026-1229.combined.diff"
```

---

## Notes

- This is a GUI-only change. If this install is separate from the earlier
  loading fix (AceConsole‑3.0 bundled into `GSE/Lib` + `embeds.xml`, plus the
  `Init.lua`/`Events.lua` patches), keep those too — otherwise GSE won't load far
  enough to open the editor where this scrollbar lives.
- Naming follows the requested `GSE_1924_Scrollbar-0612026-1229` convention; the actual
  fix is the editor scroll-bar visibility issue described above.

---

<a id="2-arrowkeys"></a>

## 2. ArrowKeys — 12:47 PM

> **Source:** `GSE_1924_ArrowKeys-0612026-1247/Changes GSE_1924_ArrowKeys-0612026-1247/Summary.MD`

# GSE_1924_ArrowKeys-0612026-1247 — Summary

Fix package for the GSE macro editor capturing the **arrow keys** (which are
bound to character movement by default).

- **Addon bundle:** GSE `3.3.19-18-g657a37a-PatronBuild`
- **WoW interface:** `120005` (patch 12.0.5)
- **This fix changes 1 file:** `GSE_GUI/Editor.lua`
- **Bundle is cumulative** — the folders also include the prior scrollbar fix
  (`GSE_GUI/NativeUI.lua`). See "Install" below.

---

## Problem

In the editor, **Up/Down** moved the block-selection cursor and **Shift+Up/Down**
reordered the focused block. Because the handler called
`SetPropagateKeyboardInput(false)` on arrows, it consumed them and the player
couldn't move while the editor was open.

## Fix

Remove the editor's arrow-key subsystem from `Editor.lua` (the `OnKeyDown`
handler `HandleMacroBlockMoveKey`, its four helpers, and the keyboard
registration block — 95 lines). The editor no longer installs an arrow handler.
`Editor_Undo`'s `SetupUndo()` still owns the editor frame's keyboard with
**propagation kept ON**, so arrows now pass through to the game and Ctrl+Z undo
still works. Block reordering stays on the **Move Up / Move Down** buttons
(retained `MoveSelectedMacroBlock`); the cursor is moved by clicking a block.

Per-file detail is in `MD/Editor.lua.md`; the unified diff is in `DIFF/`.

---

## How it was verified

- `luac5.1 -p` passes on `Editor.lua`.
- Grep confirms the arrow subsystem (handler + 4 helpers + the
  `OnKeyDown`/`SetPropagateKeyboardInput(false)`/`EnableKeyboard(true)` calls) is
  gone, while `MoveSelectedMacroBlock` (def + Move buttons) and `SetupUndo`
  remain.
- 12-check behavioural harness on the real `Editor_Undo.lua`: arrows (Up, Down,
  Shift+Up) and a normal key keep propagating to the game; Ctrl+Z still consumes
  and undoes. A control with an old-style arrow handler confirms it used to
  consume the arrow.
- The `DIFF/` reproduces the fixed `Editor.lua` byte-for-byte; CRLF preserved.

---

## Install

This package's change is one file:

```
World of Warcraft\_retail_\Interface\AddOns\GSE_GUI\Editor.lua
```

The full addon folders at the root of this package are **cumulative**: they
contain both this arrow-key fix (`Editor.lua`) and the earlier scrollbar fix
(`NativeUI.lua`). So you can drop the whole bundle into `Interface\AddOns\`
(overwrite) and get both fixes at once, then `/reload`. If you instead apply only
this package's `DIFF/`, it patches `Editor.lua` alone — keep your scrollbar-fixed
`NativeUI.lua` in place.

```
patch -p1 --binary < "Changes GSE_1924_ArrowKeys-0612026-1247/DIFF/GSE_1924_ArrowKeys-0612026-1247.combined.diff"
```

---

## Notes

- This and the scrollbar fix are GUI-only. If this install is separate from the
  loading fix (AceConsole‑3.0 in `GSE/Lib` + `embeds.xml`, plus the
  `Init.lua`/`Events.lua` patches), keep those too or GSE won't load.
- Naming follows the `GSE_1924_<fix>-<date>-<time>` convention; the time portion
  (`1247`) is a placeholder — tell me the exact value if you want it changed.

---

<a id="3-reloadcmd"></a>

## 3. ReloadCmd — 12:55 PM

> **Source:** `GSE_1924_ReloadCmd-0612026-1255/Changes GSE_1924_ReloadCmd-0612026-1255/Summary.MD`

# GSE_1924_ReloadCmd-0612026-1255 — Summary

Adds a `/rl` chat command that reloads the UI.

- **Addon bundle:** GSE `3.3.19-18-g657a37a-PatronBuild`
- **WoW interface:** `120005` (patch 12.0.5)
- **This change touches 1 file:** `GSE_Utils/Utils.lua`
- **Bundle is cumulative** — the folders also include the earlier scrollbar fix
  (`GSE_GUI/NativeUI.lua`) and the arrow-key removal (`GSE_GUI/Editor.lua`).

---

## Change

Registered a `/rl` slash command (alias for `/reload` / `/reloadui`) right after
GSE's existing `/gse` registration, using the same `SLASH_*` / `SlashCmdList`
pattern and the same guarded `if ReloadUI then ReloadUI() end` call used
elsewhere in GSE. Purely additive — nothing else changes.

```lua
-- /rl is a quick alias for reloading the UI (same as /reload or /reloadui).
SLASH_GSERELOADUI1 = "/rl"
SlashCmdList.GSERELOADUI = function()
    if ReloadUI then ReloadUI() end
end
```

Per-file detail is in `MD/Utils.lua.md`; the unified diff is in `DIFF/`.

---

## How it was verified

- `luac5.1 -p` passes on `Utils.lua`.
- Functional test loaded the exact inserted lines against a stubbed
  `ReloadUI` / `SlashCmdList`: `SLASH_GSERELOADUI1 == "/rl"`, the handler is a
  function, and invoking it calls `ReloadUI()`.
- The `DIFF/` reproduces the fixed `Utils.lua` byte-for-byte; CRLF preserved.

---

## Install

This change is one file:

```
World of Warcraft\_retail_\Interface\AddOns\GSE_Utils\Utils.lua
```

`/reload` once to load it; afterwards `/rl` reloads the UI.

The full addon folders at the root of this package are **cumulative** — they
contain this `/rl` change (`Utils.lua`), the scrollbar fix (`NativeUI.lua`), and
the arrow-key removal (`Editor.lua`). Drop the whole bundle into
`Interface\AddOns\` (overwrite) to get all three at once, then `/reload`. If you
instead apply only this package's `DIFF/`, it patches `Utils.lua` alone.

```
patch -p1 --binary < "Changes GSE_1924_ReloadCmd-0612026-1255/DIFF/GSE_1924_ReloadCmd-0612026-1255.combined.diff"
```

---

## Notes

- `/rl` is a common alias; if another enabled addon registers it too, the
  last-loaded one wins. Can be made conditional if needed.
- These three changes are GUI/utility only. If this install is separate from the
  loading fix (AceConsole‑3.0 in `GSE/Lib` + `embeds.xml`, plus the
  `Init.lua`/`Events.lua` patches), keep those too or GSE won't load.
- Naming follows `GSE_1924_<fix>-<date>-<time>`; the time (`1255`) is a
  placeholder — tell me the exact value if you want it changed.

---

<a id="4-removectrlz"></a>

## 4. RemoveCtrlZ — 1:04 PM

> **Source:** `GSE_1924_RemoveCtrlZ-0612026-1304/Changes GSE_1924_RemoveCtrlZ-0612026-1304/Summary.MD`

# GSE_1924_RemoveCtrlZ-0612026-1304 — Summary

Removes the editor's **Ctrl+Z undo** subsystem.

- **Addon bundle:** GSE `3.3.19-18-g657a37a-PatronBuild`
- **WoW interface:** `120005` (patch 12.0.5)
- **This change:** edits `GSE_GUI/Editor.lua` and `GSE_GUI/GSE_GUI.toc`, and
  deletes `GSE_GUI/Editor_Undo.lua`.
- **Bundle is cumulative** — the folders also include the earlier scrollbar fix
  (`NativeUI.lua`), arrow-key removal (`Editor.lua`), and the `/rl` command
  (`Utils.lua`).

---

## What changed

The Ctrl+Z undo system is gone:
- `Editor_Undo.lua` deleted and removed from the `.toc` load list.
- The three calls that wired it into the editor were removed from `Editor.lua`
  (`SetupUndo` on the editor frame; `BindUndoWidget` on the spell and macro edit
  boxes).
- The arrow-fix comment in `Editor.lua` was updated to reflect that nothing
  captures the editor frame's keyboard anymore.

No remaining references to the undo API exist anywhere in the addon.

Detail is in `MD/RemoveCtrlZ.md`; unified diffs (including the file deletion) are
in `DIFF/`.

## Why it's safe

The arrow-key fix had relied on the undo system keeping the editor frame's
keyboard captured with propagation ON. With undo removed, **nothing** captures
that frame's keyboard, so arrows (and all keys) propagate to the game by default
— movement still works, the arrow fix's outcome is preserved. Typing in the
edit boxes is native and unaffected; only the Ctrl+Z undo is gone.

## How it was verified

- `luac5.1 -p` passes on `Editor.lua`.
- `Editor_Undo.lua` removed from folder and `.toc`; grep confirms zero remaining
  references to the undo API or its shared helpers anywhere.
- Grep confirms no `EnableKeyboard`/`OnKeyDown`/`SetPropagateKeyboardInput` on
  the editor frame remain in `Editor.lua`.
- Patch round-trip: the combined `DIFF/` reproduces `Editor.lua` + `GSE_GUI.toc`
  byte-for-byte and deletes `Editor_Undo.lua`; CRLF preserved.

---

## Install

This change touches `GSE_GUI`: replace `Editor.lua` and `GSE_GUI.toc`, and delete
`Editor_Undo.lua`:

```
World of Warcraft\_retail_\Interface\AddOns\GSE_GUI\Editor.lua        (replace)
World of Warcraft\_retail_\Interface\AddOns\GSE_GUI\GSE_GUI.toc       (replace)
World of Warcraft\_retail_\Interface\AddOns\GSE_GUI\Editor_Undo.lua   (delete)
```

Easiest is to drop the whole **cumulative** bundle from this package's root into
`Interface\AddOns\` (overwrite) — it already has `Editor_Undo.lua` removed and
all four changes applied — then `/reload`. Or apply the combined `DIFF/`, which
also deletes the file:

```
patch -p1 --binary < "Changes GSE_1924_RemoveCtrlZ-0612026-1304/DIFF/GSE_1924_RemoveCtrlZ-0612026-1304.combined.diff"
```

---

## Notes

- These four changes are GUI/utility only. If this install is separate from the
  loading fix (AceConsole‑3.0 in `GSE/Lib` + `embeds.xml`, plus the
  `Init.lua`/`Events.lua` patches), keep those too or GSE won't load.
- Naming follows `GSE_1924_<fix>-<date>-<time>`; the time (`1304`) is a
  placeholder — tell me the value you want and I'll match it.

---

<a id="5-multieditor"></a>

## 5. MultiEditor — 1:20 PM

> **Source:** `GSE_1924_MultiEditor-0612026-1320/Changes GSE_1924_MultiEditor-0612026-1320/Summary.MD`

# GSE_1924_MultiEditor-0612026-1320 — Summary

With the GSE Toolbar OFF, a repeated `/gse` now opens **additional** editor
windows.

- **Addon bundle:** GSE `3.3.19-18-g657a37a-PatronBuild`
- **WoW interface:** `120005` (patch 12.0.5)
- **This change touches 1 file:** `GSE_Utils/Utils.lua`
- **Bundle is cumulative** — the folders also include the scrollbar fix
  (`NativeUI.lua`), arrow-key removal + Ctrl+Z removal (`Editor.lua`, with
  `Editor_Undo.lua` deleted and dropped from the `.toc`), and the `/rl` command
  (`Utils.lua`).

---

## Change

When the Toolbar is OFF, `/gse` opens the Sequence Editor. Previously a repeat
`/gse` just re-showed the existing window. Now, on builds that support multiple
editors (Patron — `GSE.GUI.Feature.MULTI_WINDOW`), each repeat `/gse` opens an
**additional** editor window via the canonical `GSE.ShowSequences()` path; on
single-window builds it still brings the existing editor forward. The first
`/gse` (and its login "restore" handling) is unchanged.

Detail is in `MD/Utils.lua.md`; the unified diff is in `DIFF/`.

## How it was verified

- `luac5.1 -p` passes on `Utils.lua`.
- A harness drove the new decision against the **real** `MULTI_WINDOW` flag from
  `Editor_Utils.lua`: Patron + editor open → a new window is opened; non-Patron →
  existing brought forward; no editors → unchanged first-open path; missing flag
  → safe fallback. Confirmed `MULTI_WINDOW()` tracks `GSE.Patron`.
- Patch round-trip reproduces `Utils.lua` byte-for-byte; CRLF preserved.

---

## Install

This change is one file:

```
World of Warcraft\_retail_\Interface\AddOns\GSE_Utils\Utils.lua
```

`/reload` once. Then, with the Toolbar OFF (Options → Windows & Layout → "GSE
Toolbar OFF"), `/gse` opens an editor and each repeat `/gse` opens another.

The full folders at the root of this package are **cumulative** (all five changes
applied, `Editor_Undo.lua` already removed). Drop the whole bundle into
`Interface\AddOns\` (overwrite) for everything at once, then `/reload`. Or apply
just this package's `DIFF/`:

```
patch -p1 --binary < "Changes GSE_1924_MultiEditor-0612026-1320/DIFF/GSE_1924_MultiEditor-0612026-1320.combined.diff"
```

---

## Notes

- Multiple editor windows is a Patron-build capability (`MULTI_WINDOW`). On this
  PatronBuild it's enabled. On a non-Patron build, `/gse` keeps a single editor.
- `ShowSequences()` keeps its combat guard: it won't open a new editor window
  while you are in combat (prints the usual message) — same as the first open.
- These five changes are GUI/utility only. If this install is separate from the
  loading fix (AceConsole‑3.0 in `GSE/Lib` + `embeds.xml`, plus the
  `Init.lua`/`Events.lua` patches), keep those too or GSE won't load.
- Naming follows `GSE_1924_<fix>-<date>-<time>`; the time (`1320`) is a
  placeholder — tell me the value you want and I'll match it.

---

<a id="6-toolbar-toggle"></a>

## 6. toolbar-toggle — 7:06 PM

> **Source:** `GSE_1924_toolbar-toggle-6-12026-706pm/GSE_1924_toolbar-toggle-6-12026-706pm/Changes GSE_1924_toolbar-toggle-6-12026-706pm/Summary.md`

# Summary — GSE #1924: Toolbar toggle won't turn back ON

**What was wrong:** The *GSE Toolbar ON / OFF* checkbox (Options → Windows & Layout)
turned the Toolbar off but couldn't turn it back on. The checkbox showed "ON" but no
Toolbar appeared, and it stayed gone after a reload.

**Why:** `GSE_GUI` is LoadOnDemand and is the addon that defines `GSE.ShowMenu` /
`GSE.MenuFrame`. After the Toolbar was toggled off and that state survived a reload,
the login auto-show (gated on `menu.open`) never ran, so `GSE_GUI` wasn't loaded. The
checkbox's ON path called `GSE.ShowMenu()` behind an `if GSE.ShowMenu then` guard but
never loaded `GSE_GUI` first — so the guard silently skipped and nothing happened. The
`/gse toolbar` slash command avoided this because it calls `GSE.CheckGUI()` first.

**The fix:** Add `if GSE.CheckGUI then GSE.CheckGUI() end` to the ON branch of the
checkbox's `SetValue`, immediately before `GSE.ShowMenu()` — making the checkbox load
`GSE_GUI` the same way the slash command does.

**Scope:** One file, one branch. `GSE_Options/Options.lua`, +7 lines (6 comment, 1
code), nothing removed.

**Verified:** `luac` parse OK; a Lua harness reproduced the bug on the old code and
confirmed the fix shows the Toolbar (`menu.open = true`); the included `.diff` applies
cleanly with `patch -p1` / `git apply` and reproduces the fixed file exactly.

**To turn the Toolbar back on in an unpatched client:** type `/gse toolbar on`.

---

<a id="7-error-muting"></a>

## 7. error-muting — 7:25 PM

> **Source:** `GSE_1924_error-muting-20260601-1925/GSE_1924_error-muting-20260601-1925/Changes GSE_1924_error-muting-20260601-1925/Summary.md`

# Summary — GSE #1924: Added Error Muting Options

**What was added:** A new **Error Messages** section under **Options → General** with
three checkboxes (all default On):

- **UIErrorFrame** — suppresses most red UI error text (e.g. "Not enough rage") while
  still showing important errors (full bags, full quest log, dead, dead pet, pickpocket
  fails, LFG boot/teleport). Leatrix-style `UIErrorsFrame` filter.
- **Voice Errors** — mutes spoken UI error voice lines (`Sound_EnableErrorSpeech` = 0;
  off = 1).
- **Lower Energy** — mutes the vigor/lower-energy sound (file ID `1489541`).

**Files changed (this task):** `GSE/API/Events.lua` (core logic +
`GSE.ApplyErrorMessageOptions`, called from `PLAYER_ENTERING_WORLD`),
`GSE/API/InitialOptions.lua` (defaults + migration guards), `GSE_Options/Options.lua`
(the UI section + its call).

**Integration note:** The feature came from a build on an **older baseline**. Files were
**not** copied wholesale — doing so would have removed the `/gse toolbar` command and
re-added the previously-removed Ctrl+Z Undo subsystem. Only the three error-muting files'
changes were applied, on CRLF endings to match this tree.

**Also included:** the earlier **Toolbar-toggle fix** (`GSE.CheckGUI()` in the toolbar
ON/OFF checkbox) is still present in `Options.lua`. Both fixes ship together.

**Verified:**
- `luac` parse OK on all three files.
- `Events.lua` / `InitialOptions.lua` are CR-normalised-identical to the source build
  (exact feature); `Options.lua` differs from it only by the 7-line toolbar fix.
- Integrated tree differs from baseline in exactly 3 files; `/gse toolbar` retained, Undo
  not re-introduced.
- Behavioural test on the real extracted code: junk suppressed, important errors shown,
  voice + vigor muted; each toggle reverses correctly; no handler leak across toggle
  cycles.
- The `.diff` applies cleanly with `patch -p1` / `git apply` and reproduces the tree.

---

<a id="8-aceconsole-removal"></a>

## 8. aceconsole-removal — 8:30 PM

> **Source:** `GSE_1924_aceconsole-removal-20260601-2030/GSE_1924_aceconsole-removal-20260601-2030/Changes GSE_1924_aceconsole-removal-20260601-2030/Summary.md`

# Summary — GSE #1924: Remove unused AceConsole-3.0

**What:** AceConsole-3.0 was embedded but never used. Removed it — no longer loaded or
mixed into `GSE`, stale comment corrected, bundled library folder deleted.

**Why safe:** AceConsole was referenced in only three plumbing/comment spots
(`embeds.xml` include, `Init.lua` `NewAddon` mixin, a `Native.lua` comment). Its
functionality is handled by GSE's own code instead: slash commands via native
`SLASH_GSE1`/`SlashCmdList.GSE` in `GSE_Utils/Utils.lua`, and chat output via GSE's own
`GSE.Print` (`Init.lua:114`). There are zero calls to `RegisterChatCommand` / `:Print` /
`:Printf` / `:GetArgs` anywhere outside the libraries.

**Changed (this task):**
- `GSE/embeds.xml` — removed the AceConsole `<Include>` line.
- `GSE/API/Init.lua` — removed `"AceConsole-3.0",` from `NewAddon(...)`.
- `GSE/API/Native.lua` — corrected the header comment.
- Deleted `GSE/Lib/AceConsole-3.0/`.

**Verified (static):** `Init.lua` + `Native.lua` compile; `embeds.xml` is well-formed and
every remaining include resolves to an existing file; `embeds.xml` loads before
`Init.lua`; none of the 23 remaining library files require AceConsole; no GSE code calls
an AceConsole method; zero AceConsole references remain in the package. No live client
here, but there is no code path left that could fail from this removal — an in-game check
that `/gse` and chat output still work fully confirms it.

**Note:** the `GSE/` folders here are cumulative and also include the earlier fixes
(toolbar toggle, error muting, action-bar override flicker). The DIFF in this folder
covers only the AceConsole removal.

---

<a id="9-all-fixes"></a>

## 9. all-fixes — 8:54 PM

> **Source:** `GSE_1924_all-fixes-20260601-2054/GSE_1924_all-fixes-20260601-2054/Changes GSE_1924_all-fixes-20260601-2054/Summary.md`

# Summary — GSE #1924 consolidated fixes

One tree containing all four pieces of work, made from the pristine
3.3.19-18-g657a37a-PatronBuild baseline.

**1. Toolbar ON/OFF toggle** — `GSE_Options/Options.lua`. The ON branch now force-loads
the (load-on-demand) GUI via `GSE.CheckGUI()` before `GSE.ShowMenu()`, so the toolbar
turns back on after being switched off + reloaded.

**2. Error Muting Options** — `GSE → General → Error Messages`, three toggles default ON.
Leatrix-style and **taint-safe**: swaps `UIErrorsFrame`'s `OnEvent` handler (no
`:Hide()`), drops only non-allow-listed red errors and forwards everything else
(including info/yellow) to Blizzard's handler, which only displays text — so the tainted
path never reaches protected code. Voice via `Sound_EnableErrorSpeech`; Lower-Energy via
`MuteSoundFile(1489541)`. This only ensures the feature isn't a taint *source*; it doesn't
address taint from elsewhere (e.g. the secure override buttons).

**3. ActionBar Override flicker** — `Events.lua` + `Storage.lua`. Adds the missing
slot-content trigger (`ACTIONBAR_SLOT_CHANGED`) plus an icon yield and a fix to the three
`OnEnter` handlers, so dropping a real spell into an ABO slot makes the button behave/look
like a normal action (no flicker, no watermark, not disabled) and restores the override
when removed. Verified statically + unit-tested; **not yet confirmed live**.

**4. AceConsole-3.0 removal** — `embeds.xml`, `Init.lua`, `Native.lua` + deleted the lib
folder. It was embedded but unused.

**Files changed:** 7 modified (`GSE/API/Events.lua`, `Storage.lua`, `InitialOptions.lua`,
`Init.lua`, `Native.lua`, `GSE/embeds.xml`, `GSE_Options/Options.lua`) + deleted
`GSE/Lib/AceConsole-3.0/`.

**Verified:** all `.lua` parse; `embeds.xml` well-formed and loads before `Init.lua`; the
single DIFF round-trips to this tree byte-for-byte; the upload's divergent files
(`Utils.lua` missing `/gse toolbar`, `Editor.lua`/`.toc` re-adding the removed Undo) were
deliberately not merged.

**Remaining risk:** the flicker fix (#3) is the only item not yet confirmed in a live
client.

---
