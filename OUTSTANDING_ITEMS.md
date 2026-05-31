# Outstanding Items
### For the "Remove Ace3 GUI dependency" branch

Static checks all pass: **all 127 first-party Lua files compile** (`luac5.1 -p`) and **`luacheck` reports 15 warnings / 0 errors**. The items below are what a static environment *cannot* confirm, plus known notes.

## Needs in-game verification (a live WoW client)
1. **Fresh install load** — install into a clean WoW with no prior GSE SavedVariables; confirm no Lua errors on login and the UI opens.
2. **Upgrade-over-old-SavedVariables load** — load over an existing (pre-native-UI) install; confirm the options/migration path runs cleanly with no errors.
3. **Native UI smoke test** — open the editor, tree, export, import, keybind, and Skyriding panels; confirm each renders and functions. This is the core thing to exercise, since the native UI fully replaces the AceGUI interface.
4. **Tracker frames** — confirm the icon / text / successful-cast / assisted-success frames build and size correctly at load. This is exactly where the `opts` → `initialOpts` fix lives.
5. **This session's visual tweaks** — verify on screen: the "Oak – YouTube" link in the resources panel, the Skyriding node icon, the export window pre-selecting its object, the "Output Selection" label position, and the relocated `classbar` banner.

## Known non-regression note
- **`GSE/API/Serialisation.lua` calls `C_EncodingUtil` unguarded.** This is intentional and matches upstream — it is the core serialization primitive, and there is no legacy fallback that preserves the on-disk format. Flagged only so it isn't mistaken for an oversight.

## Optional / deferred (not done — awaiting your call)
- **`TimGnome.png`** (author portrait) is bundled but not wired to draw anywhere. It can be added to the About panel or dropped from the package.
- **Lint blind spot:** `.luacheckrc` necessarily ignores **W113 (undefined-global *reads*)** because WoW injects hundreds of API globals that luacheck can't know about. Be aware this is the one bug class static checks can't catch here — a renamed/typo'd local that decays into a global *read* (exactly the Tracker.lua regression above). It still catches W111 (undefined-global *writes*, the classic missing-`local`).
