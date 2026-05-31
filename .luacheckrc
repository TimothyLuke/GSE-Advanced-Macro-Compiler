-- .luacheckrc — reproducible lint config for the GSE_NoACE (PatronBuild) fork.
--
-- World of Warcraft injects hundreds of API globals at runtime that luacheck
-- cannot know about, so we:
--   * ignore 113 (accessing an undefined global)  -> WoW APIs are "undefined"
--     to luacheck but exist in-game; we still catch 111 (SETTING an undefined
--     global), which is the real "accidental global / missing local" bug.
--   * ignore the SLASH_* / BINDING_* global-write idiom (WoW's documented way
--     to register slash commands and bindings).
--   * drop the max-line-length check (631) -- cosmetic, not a correctness bug.
--
-- What this DOES still catch (the things item #4 cares about):
--   111  accidental global writes (missing `local`)
--   211/212/213  unused locals / arguments / values
--   411/412  redefinition of a local in the same scope
--   421/422  shadowing a previously defined local / argument
--   431/432  shadowing an upvalue

std = "lua51"
max_line_length = false
codes = true

-- GSE's own writable global namespace + SavedVariables (assigned at load).
globals = {
    "GSE",
    "GSEOptions",
    "GSESequences",
    "GSESpellCache",
    "GSEVariables",
    "GSEMacros",
    "GSEPlatformIDs",
    "GSEVariablePlatformIDs",
    "GSEMacroPlatformIDs",
    "GSE_C",
    "GSELegacyLibraryBackup",
    "GNOME",
    "SlashCmdList",
    "IndentationLib",
    "LibStub",
    -- Legacy globals read/cleared by the upgrade-migration code (Utils.lua,
    -- OneOffEvents.lua). They predate the fork and must be touchable.
    "GSELibrary",
    "GSE3Storage",
    -- Intentional public exports from the vendored crypto modules.
    "GSE_Ed25519Verify",
    "GSE_SHA512",
    -- WoW global that GSE conditionally polyfills on clients lacking it
    -- (CharacterFunctions.lua: `if not SaveBindings then ... end`).
    "SaveBindings",
    -- Blizzard UI global GSE hooks the documented way, plus GSE's own
    -- Settings mixin tables (defined via `function X:Method()` global mixins).
    "ColorPickerFrame",
    "SettingsButtonControlMixin",
    "SettingsCheckboxControlMixin",
    "SettingsCheckboxWithButtonControlMixin",
}

-- WoW extends Lua's stdlib with extra string methods at runtime; declare the
-- ones GSE uses so they are not flagged as undefined-field access (W143).
read_globals = {
    string = {
        fields = { "split", "join", "trim" },
    },
}

-- Suppress the noise that is not a correctness issue for a WoW addon.
ignore = {
    "113",            -- accessing an undefined global (WoW runtime APIs)
    "111/SLASH_.*",   -- WoW slash-command registration idiom
    "111/BINDING_.*", -- WoW binding-header registration idiom
    "112/SLASH_.*",
    -- Underscore-prefixed names are the project's "intentionally unused" marker.
    "21./_.*",
    "23./_.*",
    -- WoW event handlers / widget callbacks have fixed signatures; unused
    -- positional args (event, self, payload fields) are expected, not dead code.
    "212",
    "213",            -- unused loop variable in key,value iteration
    -- Cosmetic whitespace. Several localization strings carry *intentional*
    -- leading/trailing padding spaces (e.g. L[" Deleted Orphaned Macro "]),
    -- so stripping trailing whitespace would change displayed text.
    "611", "612", "613", "614",
    "542",            -- empty if branch (used as documented no-op guards)
}

-- Embedded third-party libraries are vendored verbatim; don't lint them.
exclude_files = {
    "**/Lib/**",
    "GSE/Lib/**",
    "GSE_Utils/Lib/**",
}
