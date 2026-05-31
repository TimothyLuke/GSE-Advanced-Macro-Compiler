-- ============================================================
-- GSE Spell Library — static per-version/class/spec spell name lists
-- ============================================================
-- Populated by the files under Spells/<Version>/<Class>/<Spec>.lua;
-- each file calls GSE.RegisterSpellList(version, classFile, specKey, names).
-- Consumed by spellsMenuFn in QoL.lua to show spells for classes the
-- player isn't currently logged in as.
--
-- Layout:
--   GSE.SpellLibrary[version][CLASSFILE][specKey] = { "Spell 1", "Spell 2", ... }
-- where:
--   version  ∈ "Vanilla" | "TBC" | "MoP" | "Retail"
--   CLASSFILE = "WARRIOR", "DEATHKNIGHT", etc (matches UnitClass return value)
--   specKey  = spec display name in English ("Beast Mastery", "Arms", etc).
--             For Vanilla/TBC the keys are tree names ("Arms", "Fury", "Protection").

GSE = GSE or {}
GSE.SpellLibrary = GSE.SpellLibrary or {}

-- ── Registration ────────────────────────────────────────────────────────
function GSE.RegisterSpellList(version, classFile, specKey, names)
    if type(version) ~= "string" or version == ""
       or type(classFile) ~= "string" or classFile == ""
       or type(specKey) ~= "string" or specKey == ""
       or type(names) ~= "table" then
        return
    end
    GSE.SpellLibrary[version] = GSE.SpellLibrary[version] or {}
    GSE.SpellLibrary[version][classFile] = GSE.SpellLibrary[version][classFile] or {}
    GSE.SpellLibrary[version][classFile][specKey] = names
end

-- ── Current WoW version detection ───────────────────────────────────────
-- Uses WOW_PROJECT_ID when available (Mainline / Classic flavors set it);
-- falls back to GetBuildInfo TOC version parsing otherwise.
function GSE.GetWoWVersionKey()
    -- Project ID is the most reliable signal — Blizzard explicitly sets it
    -- per-flavor.  Numbers from Blizzard's WoW UI globals.
    if WOW_PROJECT_ID then
        if WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return "Retail" end
        if WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return "Vanilla" end
        if WOW_PROJECT_BURNING_CRUSADE_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then return "TBC" end
        if WOW_PROJECT_WRATH_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then return "MoP" end -- fallback (MoP closest available)
        if WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then return "MoP" end -- fallback
        if WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then return "MoP" end
    end

    -- Fallback: parse the TOC interface number.
    if GetBuildInfo then
        local _, _, _, tocVersion = GetBuildInfo()
        tocVersion = tonumber(tocVersion) or 0
        if tocVersion >= 100000 then return "Retail" end
        if tocVersion >=  50000 then return "MoP" end
        if tocVersion >=  20000 then return "TBC" end
        return "Vanilla"
    end

    return "Retail"  -- last-resort default
end

-- ── Lookup ──────────────────────────────────────────────────────────────
-- Returns the static spell list for (version, classFile, specKey), or an
-- empty table if none registered.  When specKey is missing/nil, returns
-- the union of all specs registered for that class (useful for Vanilla/TBC
-- where there are no formal specs).
function GSE.LookupSpellList(version, classFile, specKey)
    local v = GSE.SpellLibrary[version]; if not v then return {} end
    local c = v[classFile];               if not c then return {} end
    if specKey and specKey ~= "" then
        return c[specKey] or {}
    end
    -- No spec key supplied — merge every spec into one deduped list.
    local seen, merged = {}, {}
    for _, specList in pairs(c) do
        for _, name in ipairs(specList) do
            if not seen[name] then
                seen[name] = true
                merged[#merged + 1] = name
            end
        end
    end
    return merged
end
