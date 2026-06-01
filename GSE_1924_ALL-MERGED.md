# GSE_1924 — Merged Change Notes (all 9 fix bundles)

*Generated 2026-06-01 22:45. Per-feature technical change docs, concatenated in chronological order.*

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

> **Source:** `GSE_1924_Scrollbar-0612026-1229/Changes GSE_1924_Scrollbar-0612026-1229/MD/NativeUI.lua.md`

# NativeUI.lua — Changes

**File:** `GSE_GUI/NativeUI.lua`
**Edit:** 1 (editor main scrollbar visibility)
**Line endings:** CRLF preserved (6694 lines)
**Version:** GSE `3.3.19-18-g657a37a-PatronBuild`

---

## Change — Editor scroll bar was invisible (clipped away)

### Location
`createScrollFrame()`, immediately after `widget.scrollbar = getScrollBar(scrollFrame)` (around line 2945).

### Before
```lua
    widget.scrollbar = getScrollBar(scrollFrame)
    applyModernSlimScrollBar(widget.scrollbar, frame, -STYLE.padXL, 0, 0)
    widget.localstatus = {scrollvalue = 0}
```

### After
```lua
    widget.scrollbar = getScrollBar(scrollFrame)
    if widget.scrollbar then
        -- UIPanelScrollFrameTemplate parents its scrollbar to the inner scroll
        -- frame and anchors it just outside that frame's right edge. Because the
        -- scroll frame has SetClipsChildren(true) (set above, to keep the macro
        -- content bounded), that clip mask was cutting the scrollbar away -- which
        -- is why the editor looked like it had no main scrollbar. applyModernSlim-
        -- ScrollBar only re-anchors under the ElvUI skin, so on the default skin
        -- nothing repositioned it. Re-parent the bar onto the OUTER frame (not
        -- clipped) and anchor it in the reserved right-hand gutter so it renders.
        widget.scrollbar:SetParent(frame)
        widget.scrollbar:ClearAllPoints()
        widget.scrollbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.padXXS, -STYLE.scrollBarWidth)
        widget.scrollbar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.padXXS, STYLE.scrollBarWidth)
        widget.scrollbar:SetWidth(STYLE.scrollBarWidth)
        if widget.scrollbar.SetFrameLevel and scrollFrame.GetFrameLevel then
            widget.scrollbar:SetFrameLevel(scrollFrame:GetFrameLevel() + 5)
        end
    end
    applyModernSlimScrollBar(widget.scrollbar, frame, -STYLE.padXL, 0, 0)
    widget.localstatus = {scrollvalue = 0}
```

### Why
The macro editor's main scroll frame uses `UIPanelScrollFrameTemplate`, whose
built-in scrollbar is created as a **child of the inner scroll frame** and
anchored just past that frame's right edge. The constructor turns on
`scrollFrame:SetClipsChildren(true)` (a few lines above) so the scrolling macro
content stays cleanly bounded — but a clip mask clips by **parent**, so it also
clipped the scrollbar out of existence. Result: the editor appeared to have no
main scrollbar.

`applyModernSlimScrollBar` does not save it: that helper early-returns unless the
ElvUI skin is active (`if not (scrollbar and shouldUseElvUISkin()) then return end`),
so on the default skin nothing repositioned or re-parented the bar.

The fix re-parents the bar onto the **outer** frame (which is not clipped) and
anchors it in the right-hand gutter that the layout already reserves
(`scrollFrame`'s `BOTTOMRIGHT` is inset by `STYLE.scrollBarReserve`). Width is set
to `STYLE.scrollBarWidth` (16) and the frame level is lifted above the scroll
frame so the bar draws on top. The existing `applyModernSlimScrollBar` call is
left in place after the block: it remains a no-op on the default skin (the
explicit anchors stand) and still applies the slim styling/anchoring under ElvUI.

This mirrors how the tree widget parents its own slider to its frame rather than
to a clipped child, and is the same fix previously applied to the 5‑31 build,
ported to this `g657a37a` version.

### Behaviour
- Default skin: scrollbar now visible in the editor's right gutter; scrolling,
  wheel, and click-drag unchanged (the bar object and its `OnValueChanged`/
  `SetMinMaxValues` wiring are untouched — only its parent/anchor changed).
- ElvUI skin: unchanged (slim styling still applied by the retained call).

---

## Verification
- `luac5.1 -p GSE_GUI/NativeUI.lua` → OK.
- Loaded the real patched file under a WoW stub, built a `ScrollFrame` widget via
  the actual `GSE.UI:Create` dispatcher, and confirmed `scrollbar:GetParent()` is
  the **outer** frame, not the clipped inner scroll frame.
- Negative control: the same harness run against the unpatched file fails
  (scrollbar parented to the clipped inner frame), proving the test detects the
  real bug.
- Patch round-trip: applying `DIFF/` to a pristine copy reproduces this file
  byte-for-byte, CRLF preserved.

---

<a id="2-arrowkeys"></a>

## 2. ArrowKeys — 12:47 PM

> **Source:** `GSE_1924_ArrowKeys-0612026-1247/Changes GSE_1924_ArrowKeys-0612026-1247/MD/Editor.lua.md`

# Editor.lua — Changes

**File:** `GSE_GUI/Editor.lua`
**Edit:** 1 (remove editor arrow-key navigation / reorder) — a net removal
**Line endings:** CRLF preserved
**Version:** GSE `3.3.19-18-g657a37a-PatronBuild`

---

## Change — Remove arrow-key block navigation and Shift+arrow reorder

### Problem
In the macro-block editor, **Up/Down** moved the selection cursor through the
block list and **Shift+Up/Down** reordered the focused block. The arrow keys are
bound to character movement in WoW by default, and the editor's handler called
`SetPropagateKeyboardInput(false)` when it acted on an arrow — actively
**consuming** the key — so the player could not move while the editor was open.

### Root cause
The editor installed an `OnKeyDown` handler (`HandleMacroBlockMoveKey`) on the
editor frame that captured Up/Down for navigate/reorder and stopped propagation,
stealing movement. It was backed by four helpers
(`KeyboardFocusIsTextEntry`, `SetEditorKeyboardPropagation`,
`MacroMoveKeyIsBoundToWoW`, `NavigateSelectedMacroBlock`) and a registration
block that called `EnableKeyboard(true)` + `SetPropagateKeyboardInput(true)`.

### Fix
Remove the entire arrow-key subsystem — the four helpers, `HandleMacroBlockMoveKey`,
and the registration/enable block (95 lines around 6538–6632) — replaced with a
short comment explaining the removal. The editor no longer installs an arrow
handler or grabs the keyboard itself.

```lua
        -- Arrow-key block handling has been REMOVED.
        --   * plain Up/Down previously moved the selection cursor through the list
        --   * Shift+Up/Down previously reordered the focused block
        -- ... (see full comment in the file) ...
        -- We deliberately do NOT register an OnKeyDown handler or enable keyboard
        -- capture here. Editor_Undo's SetupUndo() owns the editor frame's keyboard:
        -- it enables capture with propagation kept TRUE ... and drives Ctrl+Z undo.
```

Crucially, **Ctrl+Z undo stays live**: `Editor_Undo`'s `SetupUndo()` already
owns the editor frame's keyboard, enabling capture with **propagation kept ON**
(`BindKeyboardFrame(editor, editor.frame, true)` → `SetPropagateKeyboardInput(true)`).
Its `OnKeyDown` consumes only Ctrl+Z (`SetPropagateSafe(self, false)` →
`RestoreUndo`) and lets every other key — including the arrows — fall through and
propagate to the game. With the arrow handler gone, nothing sets `OnKeyDown`
before `SetupUndo`, so `previousOnKeyDown` is nil and no chained handler
re-consumes arrows.

Block reordering remains on the **Move Up / Move Down** buttons (which still call
the retained `MoveSelectedMacroBlock`); the cursor is moved by clicking a block.

### Behaviour
- Arrow keys (Up/Down) and Shift+Up/Down now pass straight to WoW — character
  movement works while the editor is open.
- Move Up / Move Down buttons still reorder blocks.
- Ctrl+Z undo still works.

---

## Verification
- `luac5.1 -p GSE_GUI/Editor.lua` → OK.
- Grep confirms the four helpers + `HandleMacroBlockMoveKey` and the
  `OnKeyDown`/`SetPropagateKeyboardInput(false)`/`EnableKeyboard(true)` calls are
  gone from `Editor.lua` (only the explanatory comment mentions them), while
  `MoveSelectedMacroBlock` (def + both Move-button calls) and the `SetupUndo`
  call remain.
- 12-check behavioural harness loading the real `Editor_Undo.lua`: with no arrow
  handler installed, `SetupUndo` keeps propagation TRUE; plain Up, plain Down,
  Shift+Up, and a normal key all keep propagating (not consumed); Ctrl+Z still
  consumes the key and triggers undo. A control wiring an old-style arrow handler
  confirms it *did* consume the arrow — proving the test detects consumption.
- Patch round-trip: applying `DIFF/` to a pristine copy reproduces this file
  byte-for-byte, CRLF preserved.

---

<a id="3-reloadcmd"></a>

## 3. ReloadCmd — 12:55 PM

> **Source:** `GSE_1924_ReloadCmd-0612026-1255/Changes GSE_1924_ReloadCmd-0612026-1255/MD/Utils.lua.md`

# Utils.lua — Changes

**File:** `GSE_Utils/Utils.lua`
**Edit:** 1 (add `/rl` reload-UI slash command) — a small addition
**Line endings:** CRLF preserved
**Version:** GSE `3.3.19-18-g657a37a-PatronBuild`

---

## Change — Add `/rl` as a reload-UI command

### Location
Immediately after GSE's existing `/gse` slash-command registration (around line 1804).

### Added
```lua
-- /rl is a quick alias for reloading the UI (same as /reload or /reloadui).
SLASH_GSERELOADUI1 = "/rl"
SlashCmdList.GSERELOADUI = function()
    if ReloadUI then ReloadUI() end
end
```

### Why
Convenience: typing `/rl` in chat reloads the UI, the same as the built-in
`/reload` / `/reloadui`. It uses the standard WoW `SLASH_*` / `SlashCmdList`
registration pattern that GSE already uses for `/gse` two lines above, and the
same guarded `if ReloadUI then ReloadUI() end` call the addon uses elsewhere
(e.g. `DebugWindow.lua`, `Editor_Tree.lua`). The `GSERELOADUI` command name is
GSE-namespaced so it won't collide with GSE's own commands.

### Behaviour
- `/rl` in chat → `ReloadUI()`.
- No existing behaviour changed; this is purely additive.

### Note
`/rl` is a common alias. WoW maps a slash text to whichever addon registers it
last, so if another enabled addon also registers `/rl`, the last one loaded
wins. If that ever shadows this, the registration can be made conditional
(only claim `/rl` when unused) — say the word.

---

## Verification
- `luac5.1 -p GSE_Utils/Utils.lua` → OK.
- Functional test: loaded the exact inserted lines against a stubbed
  `ReloadUI` / `SlashCmdList`, confirmed `SLASH_GSERELOADUI1 == "/rl"`,
  `SlashCmdList.GSERELOADUI` is a function, and invoking it calls `ReloadUI()`.
- Patch round-trip: applying `DIFF/` to a pristine copy reproduces this file
  byte-for-byte, CRLF preserved.

---

<a id="4-removectrlz"></a>

## 4. RemoveCtrlZ — 1:04 PM

> **Source:** `GSE_1924_RemoveCtrlZ-0612026-1304/Changes GSE_1924_RemoveCtrlZ-0612026-1304/MD/RemoveCtrlZ.md`

# Remove Ctrl+Z undo — Changes

**Change:** remove the editor's Ctrl+Z undo subsystem entirely.
**Files:** `GSE_GUI/Editor.lua` (edited), `GSE_GUI/GSE_GUI.toc` (edited),
`GSE_GUI/Editor_Undo.lua` (deleted).
**Line endings:** CRLF preserved.
**Version:** GSE `3.3.19-18-g657a37a-PatronBuild`

---

## What was removed

The undo subsystem was implemented in `GSE_GUI/Editor_Undo.lua` (snapshots,
`CaptureUndoCheckpoint`, `RestoreUndo`, and a keyboard handler that consumed
Ctrl+Z to undo) and wired into the editor from three points in `Editor.lua`:

- `GSE.GUI.SetupUndo(editframe)` — installed the undo handler on the editor
  frame (and was what owned that frame's keyboard).
- `GSE.GUI.BindUndoWidget(editframe, spellEditBox)` — Ctrl+Z undo in the spell box.
- `GSE.GUI.BindUndoWidget(editframe, macroEditBox)` — Ctrl+Z undo in the macro box.

All three calls were removed, `Editor_Undo.lua` was removed from `GSE_GUI.toc`'s
load list, and the file itself was deleted. There are no remaining references to
the undo API anywhere in the addon.

## Why this is safe (arrows + typing still work)

The earlier arrow-key fix relied on `Editor_Undo`'s `SetupUndo` to keep the
editor frame's keyboard captured **with propagation ON** so arrows reached the
game. With the undo system gone, nothing enables keyboard capture on the editor
frame at all — so the arrow keys (and every other key) propagate to the game by
**default**. Character movement still works; the arrow fix's outcome is
preserved. Confirmed: `Editor.lua` no longer contains any `EnableKeyboard`,
`OnKeyDown`, or `SetPropagateKeyboardInput` call on the editor frame (only the
explanatory comment mentions them).

Typing is unaffected: the macro/spell edit boxes capture their own keyboard
natively (text entry, backspace, cursor, selection, copy/paste), independent of
the editor frame. Only the GSE-added Ctrl+Z **undo** is gone.

The arrow-fix comment in `Editor.lua` was updated so it no longer claims
`Editor_Undo` owns the frame's keyboard.

## Behaviour after the change

- Ctrl+Z in the editor does nothing (no undo).
- Arrow keys propagate to the game (movement works) — unchanged from the arrow fix.
- Move Up / Move Down buttons still reorder blocks; clicking a block moves the cursor.
- Typing in the editor works as before.

---

## Verification
- `luac5.1 -p GSE_GUI/Editor.lua` → OK.
- `Editor_Undo.lua` removed from the folder and not referenced in `GSE_GUI.toc`.
- Grep confirms **zero** remaining references to `SetupUndo`, `BindUndoWidget`,
  `RestoreUndo`, `CaptureUndoCheckpoint`, `RunWhenCombatSafe`,
  `SetPropagateKeyboardSafe`, or `Editor_Undo` anywhere in the addon (the shared
  helpers `Editor_Undo` exposed were already unused after the arrow-key fix).
- Grep confirms no `EnableKeyboard`/`OnKeyDown`/`SetPropagateKeyboardInput` calls
  remain on the editor frame in `Editor.lua`.
- Patch round-trip: applying the combined `DIFF/` to a pristine copy reproduces
  `Editor.lua` and `GSE_GUI.toc` byte-for-byte **and deletes** `Editor_Undo.lua`;
  CRLF preserved.

---

<a id="5-multieditor"></a>

## 5. MultiEditor — 1:20 PM

> **Source:** `GSE_1924_MultiEditor-0612026-1320/Changes GSE_1924_MultiEditor-0612026-1320/MD/Utils.lua.md`

# Utils.lua — Changes

**File:** `GSE_Utils/Utils.lua`
**Edit:** 1 (let a repeated `/gse` open additional editor windows when the
Toolbar is OFF)
**Line endings:** CRLF preserved
**Version:** GSE `3.3.19-18-g657a37a-PatronBuild`

---

## Change — repeated `/gse` opens additional editors (Toolbar OFF)

### Location
`GSE:GSSlash` default branch, the "Toolbar OFF" routing (around line 2044).

### Problem
With the GSE Toolbar OFF, `/gse` opens the Sequence Editor. But repeating `/gse`
did **not** open another editor — step 1 of that branch detected an existing
editor and simply re-showed the most recent one, then `return`ed ("never create
a duplicate"). So users could only ever have the one window.

### Why it can be fixed safely
- `GSE.CreateEditor()` (Editor.lua) is a singleton **only** for non-Patron
  builds (`if editors[1] and not GSE.Patron then return editors[1]`). On Patron
  builds it inserts and returns a **new** `editframe` every call.
- `GSE.ShowSequences()` (Editor.lua) is the canonical "open the editor" path used
  by the menu, LDB, etc.: it calls `CreateEditor()`, populates the tree, restores
  the last sequence, and ends with `editframe:Show()`. Calling it again on a
  Patron build therefore produces a new, visible editor window.
- Closing an editor removes it from `GSE.GUI.editors` (Editor.lua), and there is
  already a purpose-built feature flag `GSE.GUI.Feature.MULTI_WINDOW()`
  (= `GSE.Patron`) for exactly this — it just wasn't being consulted anywhere.

### Edit
Step 1 of the Toolbar-OFF branch now checks `MULTI_WINDOW`:

```lua
if GSE.GUI and GSE.GUI.editors and #GSE.GUI.editors > 0 then
    local multiWindow = GSE.GUI.Feature and GSE.GUI.Feature.MULTI_WINDOW
        and GSE.GUI.Feature.MULTI_WINDOW()
    if multiWindow and GSE.ShowSequences then
        -- Open an additional editor window.
        GSE.ShowSequences()
    else
        local existing = GSE.GUI.editors[#GSE.GUI.editors]
        if existing and existing.Show then existing:Show() end
    end
    return
end
```

- **Multi-window builds (Patron):** each repeat `/gse` opens an **additional**
  editor window.
- **Single-window builds (non-Patron):** unchanged — the existing editor is
  brought forward (CreateEditor can't make a second one there anyway).
- **Missing flag (degenerate):** falls back to bringing the existing editor
  forward.

Steps 2 and 3 (the first-open path, including the "restore pending" guard so a
saved-open editor isn't duplicated at login) are untouched, so the **first**
`/gse` behaves exactly as before.

### Behaviour after the change (Toolbar OFF, Patron build)
- `/gse` (first) → opens an editor (unchanged).
- `/gse` again → opens another editor window. Repeat for as many as you want.
- Each window is independent and closes individually.

---

## Verification
- `luac5.1 -p GSE_Utils/Utils.lua` → OK.
- Behavioral harness driving the new step-1 decision against the **real**
  `GSE.GUI.Feature.MULTI_WINDOW` table extracted from `Editor_Utils.lua`:
  - Patron + an editor open → `ShowSequences()` is called (new window); the
    existing one is **not** merely re-shown.
  - non-Patron + an editor open → the existing editor is brought forward; no new
    window.
  - no editors yet → falls through to the unchanged first-open path.
  - flag missing → safe fallback to bringing the existing editor forward.
  - confirmed `MULTI_WINDOW()` tracks `GSE.Patron`.
- Patch round-trip: applying `DIFF/` to a pristine copy reproduces this file
  byte-for-byte; CRLF preserved.

## Note
`ShowSequences()` keeps its existing combat guard — it will not open a new editor
window while you are in combat (it prints the usual "cannot open a new Sequence
Editor window … in combat" message), same as the first-open path. Out of combat,
repeat `/gse` opens additional windows as requested.

---

<a id="6-toolbar-toggle"></a>

## 6. toolbar-toggle — 7:06 PM

> **Source:** `GSE_1924_toolbar-toggle-6-12026-706pm/GSE_1924_toolbar-toggle-6-12026-706pm/Changes GSE_1924_toolbar-toggle-6-12026-706pm/GSE_1924_toolbar-toggle.md`

# GSE #1924 — GSE Toolbar toggle does not turn back ON after being toggled OFF

**Fix slug:** `toolbar-toggle`
**Date / time:** 2026-06-01, 7:06 PM
**Base build:** GSE 3.3.19-18-g657a37a-PatronBuild
**Files changed:** `GSE_Options/Options.lua` (one branch, +7 lines, 0 removed)

---

## Symptom

In **Options → Windows & Layout**, the **"GSE Toolbar ON / OFF"** checkbox turns the
Toolbar off correctly, but once it has been off it will not bring the Toolbar back.
The checkbox itself flips to checked and the label reads "GSE Toolbar ON", yet **no
Toolbar appears**, and it does not come back on the next login either.

## Root cause

`GSE_GUI` is a **LoadOnDemand** addon (`## LoadOnDemand: 1` in `GSE_GUI/GSE_GUI.toc`).
It is the addon that defines `GSE.ShowMenu` and `GSE.MenuFrame` — both are created at
the bottom of `GSE_GUI/Menu.lua`, so **they do not exist until `GSE_GUI` is loaded**.

`GSE_Options` is *not* LoadOnDemand (it only depends on `GSE_Utils`), so the Options
panel — and its checkbox — is registered at login, **before** `GSE_GUI` is loaded.

The Toolbar checkbox's `SetValue` had an asymmetry compared with the `/gse toolbar`
slash command:

* The **slash command** (`Utils.lua`, the `"toolbar"` branch) calls `GSE.CheckGUI()`
  *before* `GSE.ShowMenu()`. That is exactly why its own in-code comment calls it
  *"the reliable way to turn the Toolbar back ON."* `GSE.CheckGUI()` runs
  `C_AddOns.LoadAddOn("GSE_GUI")`, which synchronously loads the GUI and defines
  `GSE.ShowMenu` / `GSE.MenuFrame`.
* The **Options checkbox** called `GSE.ShowMenu()` with only an `if GSE.ShowMenu then`
  guard and **no `CheckGUI()`**. When `GSE_GUI` was not loaded, the guard silently
  skipped, the Toolbar never showed, and `menu.open` was never set to `true` — so it
  would not auto-show on the next login either.

### Why "once it's been toggled off" is the trigger

The login auto-show in `GSE/API/Events.lua` (line ~951) only loads + shows the Toolbar
when **`menu.open` AND `ToolbarEnabled ~= false`**:

1. Toolbar visible (default): at login the auto-show loads `GSE_GUI` and shows it.
2. You toggle the checkbox **OFF** → Toolbar hides, `menu.open = false`,
   `ToolbarEnabled = false`. (`GSE_GUI` is still loaded *this* session.)
3. You `/reload` or relog. Persisted state is now Toolbar OFF, so the login auto-show
   does **not** run, and **`GSE_GUI` is not loaded**.
4. You open Settings and toggle the checkbox **back ON**. `SetValue(true)` sets
   `ToolbarEnabled = true`, then hits `if GSE.ShowMenu then …` — but `GSE.ShowMenu`
   is `nil`. Nothing happens. The checkbox shows "ON"; no Toolbar appears.

## The fix

Make the checkbox's ON path load the GUI first, mirroring what `/gse toolbar` already
does. Only the ON branch needs it (the OFF branch already works without `GSE_GUI`
loaded — its `GSE.MenuFrame` Hide is nil-guarded and it sets `menu.open = false`
directly), so the change is kept to a single branch.

```diff
                 local function SetValue(val)
                     GSEOptions.ToolbarEnabled = val and true or false
                     if val then
+                        -- GSE_GUI is LoadOnDemand and owns GSE.ShowMenu / GSE.MenuFrame.
+                        -- On a session where the Toolbar started OFF, GSE_GUI is not
+                        -- loaded yet, so GSE.ShowMenu would be nil and the toggle would
+                        -- flip to ON without the Toolbar ever appearing (and without
+                        -- setting menu.open, so it would not return on next login
+                        -- either). Force-load it first, the same way /gse toolbar does.
+                        if GSE.CheckGUI then GSE.CheckGUI() end
                         -- Turned ON: bring up the toolbar immediately so the user
                         -- sees the result of toggling on. GSE.ShowMenu sets
                         -- menu.open = true so the toolbar also auto-shows on next
                         -- login.
                         if GSE.ShowMenu then GSE.ShowMenu() end
                     else
                         -- Turned OFF: hide the toolbar live if visible and clear
                         -- the persisted open flag so it won't auto-show on login.
                         if GSE.MenuFrame and GSE.MenuFrame:IsShown() then
                             GSE.MenuFrame:Hide()
                         end
                         if GSEOptions.frameLocations and GSEOptions.frameLocations.menu then
                             GSEOptions.frameLocations.menu.open = false
                         end
                     end
                     if setting and setting.SetName then setting:SetName(getLabel()) end
                 end
```

### Sequence after the fix (the failing case)

1. `ToolbarEnabled = true`.
2. `GSE.CheckGUI()` → `C_AddOns.LoadAddOn("GSE_GUI")` loads the GUI synchronously;
   `Menu.lua` runs and defines `GSE.ShowMenu` / `GSE.MenuFrame`. (`menu.open` is still
   `false` at this instant, so `Menu.lua`'s own `if loc.open then frame:Show()` does
   not fire — no flicker.)
3. `GSE.ShowMenu()` → sets `menu.open = true` and shows the frame. **Toolbar appears.**

## Why this is the right-sized change

* It addresses the actual root cause (LoadOnDemand timing), not a symptom.
* It reuses the existing, proven pattern (`GSE.CheckGUI()` then `GSE.ShowMenu()`) used
  by the slash command and the login path — no new mechanism is introduced.
* It is confined to the ON branch of one function; nothing else is rewritten and no
  existing behavior is removed.
* It degrades gracefully: if the user has explicitly **disabled** the GSE GUI addon,
  `GSE.CheckGUI()` returns `false` and prints the existing "please activate this
  plugin" message — better feedback than the previous silent no-op.

## Verification

* **Syntax:** `luac5.4 -p GSE_Options/Options.lua` → parses cleanly (before and after).
* **Logic reproduction:** a standalone Lua harness modelled the WoW Settings proxy API
  (checkbox state read from `setting:GetValue()`), `GSE_GUI` LoadOnDemand behaviour
  (`GSE.ShowMenu`/`MenuFrame` undefined until loaded), and the `Events.lua` login
  auto-show. Running the exact OFF → reload → ON sequence with the **current** code
  reproduced the bug (`toolbar shown = false`, `menu.open = false`) and with the
  **fixed** code resolved it (`toolbar shown = true`, `menu.open = true`).
* **Patch round-trip:** the included `.diff` applies cleanly with
  `patch -p1` / `git apply` to a pristine copy and reproduces the fixed file
  byte-for-byte; the patched file parses.

## Remaining notes / risks

* Calling `C_AddOns.LoadAddOn` from a Settings callback is consistent with the slash
  command and the login path, both of which already do it. Loading a LoadOnDemand
  addon is permitted in combat, so there is no new combat-lockdown risk.
* **Out of scope (not changed):** the other Toolbar controls in the same section
  (Strata, Growth Direction, Static/Slide Out, Lock Position) similarly rely on
  `GSE.*` functions from `GSE_GUI` and are nil-guarded. Adjusting those while the
  Toolbar/GUI is unloaded still won't take effect live. That is a separate, lower-impact
  concern than the reported toggle bug and was deliberately left untouched to keep this
  change minimal; it is flagged here in case the maintainer wants a follow-up.

---

<a id="7-error-muting"></a>

## 7. error-muting — 7:25 PM

> **Source:** `GSE_1924_error-muting-20260601-1925/GSE_1924_error-muting-20260601-1925/Changes GSE_1924_error-muting-20260601-1925/GSE_1924_error-muting.md`

# GSE #1924 — Add Error Muting Options (integrated on top of the Toolbar-toggle fix)

**Fix slug:** `error-muting`
**Date / time:** 2026-06-01, 7:25 PM
**Base build:** GSE 3.3.19-18-g657a37a-PatronBuild
**Source of feature:** `GSE_1924_error-messages-20260601-1308` (uploaded)
**Files changed by THIS task:** `GSE/API/Events.lua`, `GSE/API/InitialOptions.lua`, `GSE_Options/Options.lua`

> This package also carries the earlier **Toolbar-toggle fix** in `GSE_Options/Options.lua`
> (the `GSE.CheckGUI()` call in the toolbar ON/OFF checkbox). Both fixes are present.

---

## What was added

A new **"Error Messages"** section under **Options → General**, with three checkboxes
(all default **On**):

| Option | Default | Effect |
|---|---|---|
| **UIErrorFrame** | On | Installs a Leatrix-style `UIErrorsFrame` event filter that suppresses most `UI_ERROR_MESSAGE` red error text (e.g. "Not enough rage"), while still letting important errors through — full bags, full quest log, dead player, dead pet, pickpocket failures, raid-only, and the LFG boot/teleport errors. |
| **Voice Errors** | On | Mutes spoken UI error voice lines by setting the `Sound_EnableErrorSpeech` CVar to `0`. Turning the option off restores it to `1`. |
| **Lower Energy** | On | Mutes sound file ID `1489541` (the lower-energy / vigor recharge sound), matching the Leatrix Plus `MuteVigor` entry. Turning it off unmutes. |

## How it was integrated (and why not a wholesale copy)

The feature was supplied inside another fix package. That package, however, was built
from a **different, older baseline** (`GSE_6-12026-1255am`) than this addon
(`GSE_6-12026-156pm`). A full tree comparison showed the uploaded build also differed in
files that have **nothing to do with error muting**:

* `GSE_Utils/Utils.lua` — the uploaded build predates the `/gse toolbar` chat command
  (copying it would have **removed** that command).
* `GSE_GUI/Editor.lua`, `GSE_GUI/GSE_GUI.toc`, `GSE_GUI/Editor_Undo.lua` — the uploaded
  build still contains the Ctrl+Z **Undo subsystem** that this baseline deliberately
  removed (copying it would have **re-introduced** removed code).

So files were **not** copied wholesale. Instead, the error-muting changes were isolated
(the uploaded build's own `Changes.MD` lists exactly three files) and applied to this
tree:

* **`GSE/API/Events.lua`** — adds the core logic: `LOWER_ENERGY_SOUND_ID`, the
  `errorMessageState` table, `EnsureErrorMessageOptions()`, `IsAllowedUIError()`, the
  `FilterUIErrorsFrame()` event filter, `SetErrorSpeechMuted()`, `SetLowerEnergyMuted()`,
  and the public `GSE.ApplyErrorMessageOptions()`. The apply function is called once from
  `GSE:PLAYER_ENTERING_WORLD()` so the chosen settings take effect on login.
* **`GSE/API/InitialOptions.lua`** — adds the three keys (`HideUIErrorFrame`,
  `MuteVoiceErrors`, `MuteLowerEnergy`) to `GSE.SetDefaultOptions()` and adds matching
  `== nil` migration guards so existing profiles pick up the defaults.
* **`GSE_Options/Options.lua`** — adds `AddErrorMessageOptions(generalOptions)` (the
  section header + the three checkboxes, each wired through a `SetValueChangedCallback`
  to `GSE.ApplyErrorMessageOptions()` so toggling applies live) and calls it from
  `GSE:CreateConfigPanels()` after the Action Button CVar section.

Line endings were normalised to **CRLF** to match the rest of this tree (the uploaded
build had mixed CRLF/LF in `Events.lua` and `InitialOptions.lua`).

### Wiring sanity

`GSE.ApplyErrorMessageOptions` lives in the always-loaded core (`GSE`); `GSE_Options`
depends on `GSE_Utils` → `GSE`, so the callback's `if GSE.ApplyErrorMessageOptions then`
guard is satisfied whenever the option is toggled. The checkboxes use
`Settings.RegisterAddOnSetting(..., GSEOptions, ...)`, which reads/writes
`GSEOptions.<key>` directly, so the UI, the defaults, and the apply logic all share the
same storage.

## Verification

* **Parse:** `luac5.4 -p` passes for all three changed files.
* **Exact feature match:** after integration, `Events.lua` and `InitialOptions.lua` are
  **byte-identical (CR-normalised) to the uploaded build** — i.e. exactly the intended
  feature, nothing more. `Options.lua` differs from the uploaded build by **only** the
  7-line Toolbar-toggle fix, confirming the error-muting UI was added cleanly without
  disturbing the prior fix.
* **No collateral changes:** the integrated tree differs from the pristine baseline in
  exactly three files; the `/gse toolbar` command is still present and the Undo subsystem
  was **not** re-introduced.
* **Behavioural test:** the real error-muting block was extracted from the edited
  `Events.lua` and exercised against mocked WoW APIs. With defaults on, junk errors are
  suppressed while important errors pass through, `Sound_EnableErrorSpeech` is set to
  `0`, and sound `1489541` is muted; turning each option off reverses it; and an
  install → restore → re-install cycle never leaks the original `UIErrorsFrame` handler.
  The filter also tolerates `ERR_*` globals being `nil`.
* **Patch round-trip:** the included `.diff` applies cleanly with `patch -p1` / `git apply`
  to the prior (Toolbar-fixed) tree and reproduces this integrated tree byte-for-byte.

## Notes / remaining risks

* The error filter swaps `UIErrorsFrame`'s `OnEvent` script. If another addon swaps the
  same handler **after** GSE installs the filter and later restores its own captured
  handler, ordering can interact — this mirrors how Leatrix Plus itself behaves and is
  the standard approach. The implementation only re-captures the original when the
  current handler is not already GSE's own filter, so repeated `ApplyErrorMessageOptions`
  calls do not stack.
* `Sound_EnableErrorSpeech` is a normal (non-protected) CVar; setting it is wrapped in
  `pcall`, so a future client change that renames or restricts it fails safe rather than
  erroring.
* Defaults are **On** for all three (matching the source feature). If a more
  conservative default is preferred, change the three defaults in `InitialOptions.lua`
  and the `RegisterAddOnSetting` default flag in `Options.lua`.

---

<a id="8-aceconsole-removal"></a>

## 8. aceconsole-removal — 8:30 PM

> **Source:** `GSE_1924_aceconsole-removal-20260601-2030/GSE_1924_aceconsole-removal-20260601-2030/Changes GSE_1924_aceconsole-removal-20260601-2030/GSE_1924_aceconsole-removal.md`

# GSE #1924 — Remove unused AceConsole-3.0 dependency

**Fix slug:** `aceconsole-removal`
**Date / time:** 2026-06-01, 8:30 PM
**Base build:** GSE 3.3.19-18-g657a37a-PatronBuild
**Files changed by THIS task:** `GSE/embeds.xml`, `GSE/API/Init.lua`, `GSE/API/Native.lua`
**Files deleted:** `GSE/Lib/AceConsole-3.0/AceConsole-3.0.lua`, `GSE/Lib/AceConsole-3.0/AceConsole-3.0.xml`

---

## What this is

AceConsole-3.0 was embedded into the addon but **none of its API was ever used**. This
removes the dead dependency: the library is no longer loaded or mixed into the `GSE`
object, the stale comment that referenced it is corrected, and the bundled library folder
is deleted.

## Why it was safe to remove

A full scan of the addon (excluding the library itself) found AceConsole referenced in
only three places, all of which were plumbing or documentation — never a real call:

* `GSE/embeds.xml` — `<Include>` that loads the library.
* `GSE/API/Init.lua` — `"AceConsole-3.0"` in the `NewAddon(...)` mixin list.
* `GSE/API/Native.lua` — a comment claiming the mixin "provides `:RegisterChatCommand`…".

The functionality AceConsole would provide is supplied by GSE's own code instead:

* **Slash commands** are registered natively — `SLASH_GSE1 = "/gse"` /
  `SlashCmdList.GSE = …` (and `/rl`) in `GSE_Utils/Utils.lua` (lines 1810–1817) — not via
  AceConsole's `RegisterChatCommand`.
* **Chat output** goes through GSE's own `GSE.Print` (`GSE/API/Init.lua:114`, plus
  `GSE.PrintDebugMessage` at :157), which queues to `GSE.OutputQueue` / `GSE.PerformPrint`
  — not AceConsole's `:Print` / `:Printf`.
* There are **zero** colon-calls to `:Print(`, `:Printf(`, `:GetArgs`, or
  `RegisterChatCommand` anywhere outside the bundled libraries.

## The change

1. `GSE/embeds.xml` — removed the line
   `<Include file="Lib\AceConsole-3.0\AceConsole-3.0.xml"/>`.
2. `GSE/API/Init.lua` — removed `"AceConsole-3.0",` from the `NewAddon` mixin list, so it
   reads `NewAddon("GSE", "AceEvent-3.0", "AceComm-3.0")`.
3. `GSE/API/Native.lua` — updated the header comment to drop the AceConsole /
   `RegisterChatCommand` mentions (now: "Ace3 mixin (AceEvent / AceComm via Init.lua)
   provides :RegisterEvent / :SendMessage / :RegisterComm etc.").
4. Deleted the `GSE/Lib/AceConsole-3.0/` folder.

## Verification

* **Lua parse:** `luac5.4 -p` passes for `Init.lua` and `Native.lua`.
* **XML:** `embeds.xml` is well-formed, and **all 9 remaining includes resolve to files
  that exist** (LibStub, CallbackHandler, AceAddon, AceEvent, AceLocale, AceComm,
  LibDataBroker, WagoAnalytics, LibQTip).
* **Load order:** `embeds.xml` is loaded at `GSE.toc` line 33, before `API\Init.lua` at
  line 52 — so the remaining AceEvent/AceComm mixins are registered before `NewAddon`
  runs.
* **No dependency on AceConsole:** none of the 23 remaining library `.lua` files call
  `LibStub("AceConsole-3.0")`, so removing it cannot cause a missing-library error.
* **No usage:** no GSE code calls any AceConsole method, so there is no code path that
  could raise a nil-method error at runtime.
* **Zero dangling references** to AceConsole remain anywhere in the packaged addon, and
  the `GSE/Lib/AceConsole-3.0/` folder is absent from the package.

## Remaining risk

Verification is static (no live WoW client here). However, since there is no remaining
code path that touches AceConsole, a runtime failure caused by this removal has nowhere to
originate. A quick in-game smoke test — confirm `/gse` opens and chat/debug output still
prints — exercises the native slash handler and `GSE.Print`, both untouched.

## Note on scope

The `GSE/` folders in this package are the **cumulative** working copy and therefore also
contain the earlier fixes from this issue — the Toolbar ON/OFF toggle fix, the Error
Muting Options, and the ActionBar Override flicker work. This task's DIFF
(`GSE_1924_aceconsole-removal.diff`) shows **only** the AceConsole removal.

---

<a id="9-all-fixes"></a>

## 9. all-fixes — 8:54 PM

> **Source:** `GSE_1924_all-fixes-20260601-2054/GSE_1924_all-fixes-20260601-2054/Changes GSE_1924_all-fixes-20260601-2054/GSE_1924_all-fixes.md`

# GSE #1924 — Consolidated fixes

**Date / time:** 2026-06-01, 8:54 PM
**Base build:** GSE 3.3.19-18-g657a37a-PatronBuild
**This package contains all four pieces of work from this issue in one tree.**

Files changed vs the pristine baseline (7 modified + 1 folder deleted):

* `GSE/API/Events.lua` — error muting + action-bar override flicker
* `GSE/API/Storage.lua` — action-bar override flicker (LAB icon yield)
* `GSE/API/InitialOptions.lua` — error-muting defaults
* `GSE_Options/Options.lua` — toolbar toggle fix + error-muting options UI
* `GSE/embeds.xml`, `GSE/API/Init.lua`, `GSE/API/Native.lua` — AceConsole removal
* **Deleted:** `GSE/Lib/AceConsole-3.0/` (`AceConsole-3.0.lua`, `AceConsole-3.0.xml`)

The single DIFF in this folder (`GSE_1924_all-fixes.diff`) reproduces this exact tree
from the pristine baseline and applies with `git apply` / `patch -p1`. (It covers the 7
text files; deleting the `AceConsole-3.0` folder is the one step it can't express as text
and is called out in its header.)

---

## 1. Toolbar ON/OFF toggle won't turn back on

**Symptom:** turning the GSE toolbar off and reloading left it impossible to turn back on
from the options checkbox.

**Cause:** `GSE_GUI` is load-on-demand. After the toolbar is off and the UI reloads,
`GSE_GUI` isn't loaded, so `GSE.ShowMenu` is nil; the checkbox's ON branch called
`GSE.ShowMenu()` behind an `if GSE.ShowMenu then` guard that silently no-op'd, so the
toolbar never came back (and `menu.open` was never set, so it didn't return on next login
either).

**Fix (`GSE_Options/Options.lua`):** in the checkbox's ON branch, force-load the GUI first
the same way `/gse toolbar` does — `if GSE.CheckGUI then GSE.CheckGUI() end` — before
calling `GSE.ShowMenu()`. ON-branch only; +7 lines.

## 2. Error Muting Options (Leatrix-style, taint-safe)

**What:** a new `GSE → General → Error Messages` section with three toggles, all default
**ON**: hide UI error frame red errors, mute voice errors, mute the Lower-Energy sound.

**Implementation:**
* `GSE/API/InitialOptions.lua` — defaults `HideUIErrorFrame`, `MuteVoiceErrors`,
  `MuteLowerEnergy` (all `true`) plus nil-guards so existing profiles pick them up.
* `GSE_Options/Options.lua` — the three checkboxes under General.
* `GSE/API/Events.lua` — `GSE.ApplyErrorMessageOptions()`, called from
  `PLAYER_ENTERING_WORLD`.

**Taint-safety (confirmed):**
* **No frame hiding.** It swaps `UIErrorsFrame`'s `OnEvent` handler
  (`UIErrorsFrame:SetScript("OnEvent", FilterUIErrorsFrame)`) and restores the captured
  original when toggled off. There is no `UIErrorsFrame:Hide()`. `UIErrorsFrame` is a
  plain `MessageFrame`, not a protected frame, so this is a normal, taint-safe operation.
* **Selective suppression, forwards the rest.** `FilterUIErrorsFrame` drops only red
  `UI_ERROR_MESSAGE` events that are *not* on an allow-list (`IsAllowedUIError`: inventory
  full, quest log full, "you are dead", can't-pickpocket, LFG boot reasons, etc.). Those
  important reds, and every non-error event (yellow `UI_INFO_MESSAGE`, etc.), are passed
  back to Blizzard's original handler. That handler only does message display, so the
  tainted call path terminates in display code and never reaches a secure/protected
  action — which is exactly why this approach is taint-safe.
* **Voice / Lower-Energy handled outside protected code.** Voice errors via the
  `Sound_EnableErrorSpeech` CVar (pcall-guarded); Lower-Energy via
  `MuteSoundFile(1489541)` / `UnmuteSoundFile` (the Leatrix MuteVigor sound id).

**Important scope note:** this guarantees the *error-message feature* is not a source of
taint. It does not, and cannot, prevent taint originating elsewhere — in particular GSE's
own secure action-bar override buttons are a separate surface (see #3).

## 3. ActionBar Override flicker / "disabled" when a real action shares the slot

**Symptom:** with an ABO on a slot, dropping a normal spell into that slot left the button
flickering ("showing through") and looking disabled until clicked.

**Cause:** the secure `BAR_SWAP_ONCLICK` / `BAR_SWAP_OAC` snippets already switch the
button between the override (`type="click"`) and the real action (`type="action"`), but
they only run on a click or a bar page/state swap — never when the slot's *contents*
change. So a freshly dropped action sat behind the stale override. Three further pieces
made it worse: GSE kept painting its sequence icon over the real action, and all three
`OnEnter` handlers re-asserted `type="click"` on every mouseover with no check for a real
action.

**Fix (`GSE/API/Events.lua` + `GSE/API/Storage.lua`):**
* `GSE.ActionBarSlotHasForeignAction()` predicate (matches the secure rule: empty/macro =
  override-owned, anything else = yield). `getGSEButtonIcon` and the LAB branch of
  `GSE.UpdateIcon` (Storage.lua) yield when it's true, so GSE stops painting over the real
  icon.
* `GSE:ACTIONBAR_SLOT_CHANGED` (+ a deferred re-check at the end of `LoadOverrides`) runs
  the same evaluation immediately on a slot-content change: real action ⇒ `type="action"`
  + `gse-eff-action = slot` (the existing icon hook then shows the real icon and hides the
  watermark); empty ⇒ restore the override. Out of combat only (`type` is protected);
  combat is covered by the existing `LoadOverrides` on `PLAYER_REGEN_ENABLED`. Attributes
  are written only when they change, so no new flicker.
* All three `OnEnter` handlers (Blizzard, Dominos, secure third-party) now only re-assert
  `type="click"` when the slot is empty/macro, using the same check — so hovering no
  longer flips a real action back into override mode.

**Status:** verified by parse + extracted-logic unit tests (yield on drop-in, restore on
removal, idempotent no-op, combat-deferred, paged-bar slot, LAB handling). **Not yet
confirmed in a live client** — this is the one item still pending your in-game check / the
"different file" fix you mentioned.

## 4. Remove unused AceConsole-3.0

AceConsole-3.0 was embedded but never used (slash commands are native via
`SLASH_GSE1`/`SlashCmdList.GSE` in `GSE_Utils/Utils.lua`; printing is GSE's own
`GSE.Print`). Removed the `embeds.xml` include and the `NewAddon` mixin entry, corrected
the stale `Native.lua` comment, and deleted the library folder. No remaining library
depends on it and no GSE code calls its methods.

---

## Verification (whole package)

* **Parse:** `luac5.4 -p` passes for all touched `.lua` files.
* **XML / load:** `embeds.xml` well-formed; all 9 remaining includes resolve to files that
  exist; `embeds.xml` loads before `Init.lua`.
* **Patch round-trip:** `GSE_1924_all-fixes.diff` applies cleanly to the pristine baseline
  and reproduces this tree byte-for-byte (7 files).
* **No collateral changes:** the only differences from baseline are the four fixes; the
  upload's divergent files (`Utils.lua` missing the `/gse toolbar` command; `Editor.lua` /
  `GSE_GUI.toc` re-adding the removed Undo subsystem) were deliberately **not** merged, as
  they would regress this work.
* **Tests:** error-muting and flicker logic exercised with Lua harnesses on the real
  extracted code.

## Known risk

The action-bar flicker fix (#3) is verified statically but not in a live client; everything
else is low-risk. A quick in-game check — drop a spell onto an ABO slot and confirm it
behaves/looks like a normal action and the GSE watermark is gone, and that `/gse` + chat
output still work — confirms the remaining surface.

---
