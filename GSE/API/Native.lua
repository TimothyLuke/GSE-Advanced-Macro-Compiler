-- GSE helper functions that genuinely add behavior — NOT thin wrappers
-- around WoW APIs. WoW APIs are called directly at the call site.
-- Ace3 mixin (AceConsole / AceEvent / AceComm via Init.lua) provides
-- :RegisterChatCommand / :RegisterEvent / :SendMessage / :RegisterComm etc.
--
-- This file contains:
--   * GSE.SafeSecureCmdOptionParse: pcall + UI-error suppression around
--     SecureCmdOptionParse, with a non-secure preview fallback path.
--   * GSE.GetSpellInfo / GSE.GetSpellCooldown: cross-version shape
--     normalizers that unify Vanilla's multi-return signature with
--     Retail's table return so call sites can use one shape on all
--     supported game versions.

local function getPreviewMacroOptionCandidate(options)
    for segment in tostring(options or ""):gmatch("([^;]+)") do
        local candidate = segment:gsub("^%s+", ""):gsub("%s+$", "")
        while string.sub(candidate, 1, 1) == "[" do
            local closing = string.find(candidate, "]", 1, true)
            if not closing then
                candidate = ""
                break
            end
            candidate = string.sub(candidate, closing + 1):gsub("^%s+", ""):gsub("%s+$", "")
        end
        candidate = candidate:gsub("^reset=%S+%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
        while string.sub(candidate, 1, 1) == "!" do
            candidate = string.sub(candidate, 2):gsub("^%s+", ""):gsub("%s+$", "")
        end
        if candidate ~= "" then return candidate end
    end
end

--- Safely call SecureCmdOptionParse, optionally suppressing the UI error
--- message frame's "Unknown macro option:" output during the parse.
--- When suppressUIErrors is set we route through a non-secure preview
--- candidate extractor that doesn't talk to the real parser — preview
--- code shouldn't trigger UI errors regardless of macro contents.
function GSE.SafeSecureCmdOptionParse(options, suppressUIErrors)
    if not SecureCmdOptionParse or type(options) ~= "string" then return nil end
    if suppressUIErrors then
        return getPreviewMacroOptionCandidate(options)
    end
    if not suppressUIErrors then
        local ok, result, target = pcall(SecureCmdOptionParse, options)
        if ok then return result, target end
        return nil
    end

    local errorFrame = UIErrorsFrame
    local originalAddMessage
    local hadUIErrorMessageEvent
    if errorFrame and errorFrame.AddMessage then
        local unknownMacroOptionPrefix =
            type(ERR_UNKNOWN_MACRO_OPTION_S) == "string" and
            (ERR_UNKNOWN_MACRO_OPTION_S:match("^(.-)%%s") or ERR_UNKNOWN_MACRO_OPTION_S) or
            "Unknown macro option:"
        originalAddMessage = errorFrame.AddMessage
        local function filteredAddMessage(self, text, ...)
            if
                type(text) == "string" and unknownMacroOptionPrefix and unknownMacroOptionPrefix ~= "" and
                    text:find(unknownMacroOptionPrefix, 1, true)
             then
                return
            end
            return originalAddMessage(self, text, ...)
        end
        local replaced = pcall(function() errorFrame.AddMessage = filteredAddMessage end)
        if not replaced then originalAddMessage = nil end
    end
    if errorFrame and errorFrame.IsEventRegistered and errorFrame.UnregisterEvent then
        local ok, registered = pcall(errorFrame.IsEventRegistered, errorFrame, "UI_ERROR_MESSAGE")
        hadUIErrorMessageEvent = ok and registered
        if hadUIErrorMessageEvent then
            pcall(errorFrame.UnregisterEvent, errorFrame, "UI_ERROR_MESSAGE")
        end
    end

    local ok, result, target = pcall(SecureCmdOptionParse, options)

    if hadUIErrorMessageEvent and errorFrame and errorFrame.RegisterEvent then
        pcall(errorFrame.RegisterEvent, errorFrame, "UI_ERROR_MESSAGE")
    end
    if originalAddMessage and errorFrame then
        pcall(function() errorFrame.AddMessage = originalAddMessage end)
    end

    if ok then return result, target end
    return nil
end

--- Cross-version normalizer for spell info. Vanilla / TBC / Cata return
--- (name, rank, iconID, castTime, minRange, maxRange, spellID, originalIconID)
--- as multi-return from the global GetSpellInfo. Retail's C_Spell.GetSpellInfo
--- returns a table. This always returns the table shape so call sites stay
--- uniform across game versions.
function GSE.GetSpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spell)
        if ok and spellInfo then
            return spellInfo
        end
    end
    if GetSpellInfo then
        local name, rank, iconID, castTime, minRange, maxRange, spellID, originalIconID = GetSpellInfo(spell)
        if name then
            return {
                name = name,
                rank = rank,
                iconID = iconID,
                castTime = castTime,
                minRange = minRange,
                maxRange = maxRange,
                spellID = spellID,
                originalIconID = originalIconID or iconID
            }
        end
    end
    return nil
end

--- Cross-version normalizer for spell cooldown. Same rationale as
--- GSE.GetSpellInfo — converts Vanilla's multi-return shape to Retail's
--- table shape so call sites can read .startTime/.duration uniformly.
function GSE.GetSpellCooldown(spell)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spell)
        if ok and cooldownInfo then
            return cooldownInfo
        end
    end
    if GetSpellCooldown then
        local startTime, duration, isEnabled, modRate = GetSpellCooldown(spell)
        return {startTime = startTime, duration = duration, isEnabled = isEnabled, modRate = modRate}
    end
    return nil
end
