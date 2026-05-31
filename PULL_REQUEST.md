# Pull Request (paste-ready)

**Title**

```
#1914 Remove Ace3 GUI dependency
```

**Target repository:** https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler

---

## Description (paste into the PR body)

### Summary
Removes the embedded **Ace3** dependency and replaces the AceGUI-based interface with a native (no-Ace) implementation, plus a release-prep pass: a reproducible lint config, localization back-fills, a load-time crash fix, and several small UI fixes.

### What changed

**Removed**
- Vendored Ace3 libraries (8 suites): `AceAddon-3.0`, `AceComm-3.0`, `AceConsole-3.0`, `AceEvent-3.0`, `AceGUI-3.0`, `AceGUI-3.0-Completing-EditBox`, `AceLocale-3.0`, `AceTimer-3.0`.
- 4 custom AceGUI extensions (`GSE_GUI/Ace3_Extensions/`).
- 20 assets no longer used by the native UI.

**Added**
- Native UI: `GSE_GUI/NativeUI.lua`, `GSE/API/Native.lua`, `GSE_GUI/Editor_Undo.lua`, `GSE_Utils/SlashCommands.lua`, `GSE_QoL/SpellLibrary.lua`.
- A per-class/spec spell-data library under `GSE_QoL/Spells/` (Retail + Vanilla, 66 files).
- `.luacheckrc` for reproducible linting.
- New assets (`classbar`, `Oak`, `skyriding`, `TimGnome`, plus native-UI icons).

**Modified**
- 72 first-party files adapted from AceGUI to the native UI, plus the release-prep fixes below.

### Release-prep fixes in this branch
- Fixed a load-time crash in `GSE_Utils/Tracker.lua` (`attempt to index global 'opts' (a nil value)`) — four file-scope references now use the renamed `initialOpts` snapshot.
- Added `.luacheckrc`; the tree lints clean (15 benign warnings / 0 errors across 127 files).
- Back-filled 4 missing `enUS` localization strings; removed a dangling doc reference; corrected a stale source comment.
- UI: Skyriding tree-node icon now ships and renders; export window pre-selects its object; added an "Oak – YouTube" resource link; "Output Selection" label alignment; relocated `classbar.png` / `TimGnome.png` into `GSE_GUI/Assets`.

### Testing
- **Static:** all 127 first-party Lua files compile (`luac5.1 -p`); `luacheck` reports 15 warnings / 0 errors.
- **Pending in-game:** fresh-install load, upgrade-over-existing-SavedVariables load, and a native-UI smoke test (editor / tree / export / import / keybind / Skyriding).

### Notes
- `C_EncodingUtil` in `GSE/API/Serialisation.lua` is intentionally unguarded (core serialization primitive; matches upstream).

---
*If `#1914` is the tracking issue for this work, you can add `Closes #1914` to the body so the issue auto-closes on merge.*
