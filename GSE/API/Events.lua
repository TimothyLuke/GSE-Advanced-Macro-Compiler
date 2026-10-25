local _, GSE = ...

local L = GSE.L
local Statics = GSE.Static

function GSE:UNIT_FACTION()
    -- local pvpType, ffa, _ = GetZonePVPInfo()
    if UnitIsPVP("player") then
        GSE.PVPFlag = true
    else
        GSE.PVPFlag = false
    end
    --@debug@
    GSE.PrintDebugMessage("PVP Flag toggled to " .. tostring(GSE.PVPFlag), Statics.DebugModules["API"])
    --@end-debug@
    GSE.ReloadSequences()
end

function GSE.UpdateZoneFlags()
    local _, type, difficulty, _, _, _, _, _, _ = GetInstanceInfo()
    GSE.PVPFlag      = (type == "pvp")
    GSE.inMythic     = (difficulty == 23)
    GSE.inDungeon    = (difficulty == 1)
    GSE.inHeroic     = (difficulty == 2)
    GSE.inMythicPlus = (difficulty == 8)
    GSE.inTimeWalking = (difficulty == 24 or difficulty == 33)
    GSE.inRaid       = (type == "raid")
    GSE.inParty      = IsInGroup() and true or false
    GSE.inArena      = (type == "arena")
    GSE.inScenario   = (type == "scenario" or difficulty == 167 or difficulty == 152 or difficulty == 208)
    --@debug@
    GSE.PrintDebugMessage(
        table.concat(
            {
                "PVP: ",        tostring(GSE.PVPFlag),
                " inMythic: ",  tostring(GSE.inMythic),
                " inRaid: ",    tostring(GSE.inRaid),
                " inDungeon ",  tostring(GSE.inDungeon),
                " inHeroic ",   tostring(GSE.inHeroic),
                " inArena ",    tostring(GSE.inArena),
                " inTimeWalking ", tostring(GSE.inTimeWalking),
                " inMythicPlus ",  tostring(GSE.inMythicPlus),
                " inScenario ",    tostring(GSE.inScenario)
            }
        ),
        Statics.DebugModules["API"]
    )
    --@end-debug@
end

function GSE:ZONE_CHANGED_NEW_AREA()
    GSE.UpdateZoneFlags()
    GSE.UnsavedOptions.ReloadQueued = nil
    GSE.ReloadSequences()
end

-- The current spec's key in the binds (Profiles.lua).
local function GetSpec()
    return GSE.CurrentSpecKey()
end

local function playerSpec()
    if GSE.GameMode < 3 then
        return 1
    else
        return GSE.GetCurrentSpecID()
    end
end

local SHBT = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate,SecureFrameTemplate")

-- Secure OnAttributeChanged handler shared by all native/Dominos/third-party button paths.
-- When WoW swaps the action bar (vehicle, skyriding, possession, override bar) it changes
-- the 'action' or 'pressandholdaction' attribute on the button.  We catch that here,
-- recalculate the effective action slot (accounting for the current bar page), and ask
-- GetActionInfo whether the slot still holds a macro.  If it doesn't (vehicle spell, etc.)
-- we revert type to 'action' so the bar-swap controls work normally.
local BAR_SWAP_OAC = [[
    if name ~= "action" and name ~= "pressandholdaction" then return end
    -- Gate on the SECURE flag, never the insecure "gse-button" string. Reading an
    -- insecurely-written attribute here would taint this snippet's execution, and
    -- because this runs interleaved with Blizzard's own OnAttributeChanged on the
    -- same action-change event (incl. Bartender4 State-Config actionpage paging),
    -- that taint rides into Blizzard's UpdatePressAndHoldAction and blocks its
    -- protected SetAttribute in combat (issue #1931). gse-secure is set only from
    -- inside the secure environment (secureArmGSEButton), so it is never tainted.
    if not self:GetAttribute("gse-secure") then return end
    local slot = self:GetID()
    local page = slot > 0 and self:GetEffectiveAttribute("actionpage") or nil
    -- Dominos and some third-party bars store the action directly (no page hierarchy).
    -- Fall back to GetEffectiveAttribute("action") when actionpage is absent.
    local effectiveAction = (slot == 0 or not page) and self:GetEffectiveAttribute("action")
                            or (page and (slot + page * 12 - 12)) or nil
    local swapped = 0
    if effectiveAction then
        local at = GetActionInfo(effectiveAction)
        -- at == nil means the slot is empty; treat empty slots same as macros so
        -- the GSE click-button binding is preserved rather than reset to type="action".
        if at == nil or at == "macro" then
            self:SetAttribute("type", "click")
        else
            self:SetAttribute("type", "action")
            swapped = effectiveAction
        end
    end
    -- Signal the non-secure icon hook only when the swapped state actually changes.
    if self:GetAttribute("gse-eff-action") ~= swapped then
        self:SetAttribute("gse-eff-action", swapped)
    end
]]

-- OnClick pre-handler: same bar-swap check applied at mouse-click time.
-- Without this, the pre-click handler would unconditionally re-assert type='click'
-- (overriding BAR_SWAP_OAC) so mouse clicks during vehicle/skyriding/possession
-- would still redirect to the GSE sequence instead of the override-bar action.
local BAR_SWAP_ONCLICK = [[
    -- Gate on the secure flag, not the insecure "gse-button" string (see BAR_SWAP_OAC).
    local gseButton = self:GetAttribute('gse-secure')
    if gseButton then
        local slot = self:GetID()
        local page = slot > 0 and self:GetEffectiveAttribute("actionpage") or nil
        local effectiveAction = (slot == 0 or not page) and self:GetEffectiveAttribute("action")
                                or (page and (slot + page * 12 - 12)) or nil
        local swapped = 0
        if effectiveAction then
            local at = GetActionInfo(effectiveAction)
            -- at == nil means the slot is empty; preserve type='click' so the GSE
            -- sequence still fires instead of resetting to a bare action button.
            if at == nil or at == "macro" then
                self:SetAttribute('type', 'click')
            else
                self:SetAttribute('type', 'action')
                swapped = effectiveAction
            end
        end
        if self:GetAttribute("gse-eff-action") ~= swapped then
            self:SetAttribute("gse-eff-action", swapped)
        end
    else
        self:SetAttribute('type', 'action')
    end
]]

-- Track which buttons already have the icon-update hook to avoid duplicate hooks.
local iconHookedButtons = {}

-- Track which LAB buttons already have the secure WrapScript installed.
-- Only needs to be set up once per button across repeated LoadOverrides() calls.
local labVehicleDriverButtons = {}

-- Secure OnAttributeChanged snippet for LAB-managed buttons (BT4, ElvUI, NDui, CPB_).
--
-- Problem: SetState registers a custom state handler whose func sets type="click",
-- but the func is guarded with InCombatLockdown() so in combat it cannot call
-- SetAttribute.  When the bar returns from a vehicle/skyriding state in combat,
-- LAB activates the custom state and sets type="custom", but the func is skipped,
-- leaving the button stuck at type="custom" (does nothing when clicked).
--
-- Fix: intercept type="custom" transitions here, inside the secure execution
-- environment where InCombatLockdown() does NOT restrict SetAttribute calls.
-- Immediately complete the state setup that the func would have done OOC.
local VEHICLE_OAC_LAB = [[
    if name ~= "type" then return end
    if value ~= "custom" then return end
    if not self:GetAttribute("gse-button") then return end
    -- Only restore type="click" for custom states GSE ITSELF registered --
    -- marked securely as gse-lab-state-<state> when the override is applied.
    -- The bar addon's own custom states (e.g. ElvUI's leave-vehicle button on
    -- the vehicle page) must keep their native behaviour.
    local st = self:GetAttribute("state")
    if st ~= nil and not self:GetAttribute("gse-lab-state-" .. st) then return end
    -- LAB activated the custom state (type="custom") but the state func is guarded
    -- with InCombatLockdown() so in combat it cannot call SetAttribute.
    -- Complete the type restoration here in the secure execution environment
    -- where InCombatLockdown() does NOT restrict SetAttribute calls.
    -- clickbutton is intentionally NOT touched: LAB never clears it during state
    -- transitions, so the reference set at overrideActionButton time remains valid.
    self:SetAttribute("type", "click")
]]

-- ---------------------------------------------------------------------------
-- Secure arming of native / Dominos / third-party action buttons (issue #1931).
--
-- Writing a button's secure attributes (type, clickbutton, and the gate flag)
-- from insecure Lua marks those values TAINTED. The GSE secure snippets above
-- then read the flag, become tainted, and -- because they run interleaved with
-- Blizzard's own ActionButton update on the same event (and with Bartender4's
-- "State Configuration" actionpage paging) -- that taint rides into Blizzard's
-- UpdatePressAndHoldAction, whose protected SetAttribute is then blocked in
-- combat. Performing the writes INSIDE the SecureHandler (SHBT:Execute) keeps the
-- values secure, so GSE seeds no taint.
--
-- gse-secure (boolean) is the snippet gate and is ONLY ever written here.
-- The "gse-button" string (sequence id) is still set insecurely elsewhere for
-- the non-secure icon / yield hooks; no secure code reads it, so its taint is
-- inert. Callers must be out of combat (SetFrameRef writes a protected attr).
-- ---------------------------------------------------------------------------
local function secureArmGSEButton(button, sequenceName)
    if not button then return end
    -- clickbutton holds the GSE executor frame. It MUST be set from insecure Lua
    -- with the real frame object, NOT from inside the secure snippet via a frame
    -- ref. A clickbutton stored from a snippet GetFrameRef resolved to a handle
    -- that Blizzard's (insecure) SecureActionButton_OnClick could not call ->
    -- "attempt to call a nil value" on every click of a stock/retail bar. The
    -- LAB paths (BT4/ElvUI, line ~732) always set clickbutton insecurely, which
    -- is why only the stock-bar (secureArmGSEButton) path regressed.
    --
    -- This does NOT reintroduce the #1931 taint: no secure snippet READS
    -- clickbutton, so its taint is inert (same as the gse-button string). Only
    -- the gate flag (gse-secure, read by the snippets) and type (read by
    -- Blizzard's secure click) need to be set inside the SecureHandler.
    local executor = sequenceName and _G[sequenceName]
    if executor and executor ~= button and not InCombatLockdown() then
        button:SetAttribute("clickbutton", executor)
    end
    SHBT:SetFrameRef("gseArmButton", button)
    SHBT:Execute([[
        local b = self:GetFrameRef("gseArmButton")
        if not b then return end
        b:SetAttribute("gse-secure", true)
        b:SetAttribute("type", "click")
    ]])
end

-- Secure type="action": the override yields to a real action dropped on its slot.
-- gse-secure stays set so the BAR_SWAP snippets keep re-evaluating the slot.
local function secureYieldGSEButton(button)
    if not button then return end
    SHBT:SetFrameRef("gseArmButton", button)
    SHBT:Execute([[
        local b = self:GetFrameRef("gseArmButton")
        if b then b:SetAttribute("type", "action") end
    ]])
end

-- Secure disarm: clear the gate flag and reset type as the override is removed.
local function secureDisarmGSEButton(button)
    if not button then return end
    SHBT:SetFrameRef("gseArmButton", button)
    SHBT:Execute([[
        local b = self:GetFrameRef("gseArmButton")
        if b then
            b:SetAttribute("gse-secure", nil)
            b:SetAttribute("type", "action")
        end
    ]])
end

-- Compute the effective action slot for a button from non-secure code.
-- WoW's RegisterAttributeDriver writes the final computed slot into the "action"
-- attribute on every button (Blizzard, Dominos, etc.), so prefer that first.
-- Fall back to GetID()+actionpage for bars that don't use the driver.
-- The secure button behind a GSE sequence macro sitting on an action slot, or
-- nil when the macro is the player's own. A sequence's WoW macro carries the
-- sequence's label; its button is named by the sequence's id.
local function gseMacroButton(macroName)
    if not macroName then return nil end
    return (GSE.FindSequenceId(macroName))
end

local function getButtonEffectiveSlot(btn)
    -- The GSE Action Bar's buttons have no action slot behind them.
    if btn.gseActionBarButton then return nil end
    local action = tonumber(btn:GetAttribute("action"))
    if action and action > 0 then return action end
    -- Blizzard native action buttons resolve their paged/bonus-bar slot in C and
    -- expose it as the .action Lua field, NOT as a secure "action" attribute. When
    -- a bonus bar is active (Druid Cat/Bear form, Prowl, etc. -- GetBonusBarOffset()
    -- > 0) ActionButton1 maps to slot 73, not base slot 1. The GetID()+actionpage
    -- fallback below cannot see that offset and would wrongly inspect base slot 1,
    -- yielding the override to whatever sits on the base bar (e.g. the Single-Button
    -- Assistant) while the slot the button actually fires is empty. Prefer the
    -- resolved field so we always evaluate the slot the button truly uses.
    local resolved = tonumber(btn.action)
    if resolved and resolved > 0 then return resolved end
    local slot = btn:GetID()
    if not slot or slot == 0 then return nil end
    local page = tonumber(btn:GetAttribute("actionpage")) or 1
    return slot + (page - 1) * 12
end

-- True when the player has dropped a real (non-empty, non-macro) action into the
-- action-bar slot a GSE override sits on. Mirrors the BAR_SWAP secure handlers,
-- which treat empty and macro slots as still owned by the override and any other
-- action as something to yield to. Used to stop GSE repainting its sequence icon
-- over the real action's icon, which otherwise fights WoW's own repaint and makes
-- the button flicker when a normal key/spell is placed in the same slot.
function GSE.ActionBarSlotHasForeignAction(button)
    if not button or not button.GetAttribute then return false end
    if not button:GetAttribute("gse-button") then return false end
    local slot = getButtonEffectiveSlot(button)
    if not slot or not GetActionInfo then return false end
    local actionType, macroIndex = GetActionInfo(slot)
    -- Empty slot: the override owns it.
    if actionType == nil then return false end
    -- A macro slot is "foreign" only when it is NOT one of GSE's own sequence
    -- macros. Keep the override only for a macro we can positively confirm is a
    -- GSE sequence; any other macro (or one whose name won't resolve) is the
    -- player's, so yield to it (the Blizzard action wins and is shown).
    if actionType == "macro" then
        if macroIndex and GetMacroInfo then
            local macroName = GetMacroInfo(macroIndex)
            if gseMacroButton(macroName) then
                return false
            end
        end
        return true
    end
    return true
end

-- Return the display icon for a GSE-overridden button.
-- Resolve directly from the compiled GSE action first so MacroBlock conditionals
-- such as [mod:alt] repaint like a normal in-game macro.
local function isGSEFallbackTexture(texture)
    -- Routes through GSE.IsFallbackIcon (defined in Statics.lua) for a single
    -- source of truth across all four sites that decide "is this a placeholder?".
    -- Doing so also closes a gap unique to this site: the original inline body
    -- here only checked Statics.QuestionMarkIconID (numeric form), missing the
    -- Statics.QuestionMark string form ("INV_MISC_QUESTIONMARK") that the
    -- other three predicates included. Some API paths return the string form;
    -- those were silently slipping past this check.
    return GSE.IsFallbackIcon(texture)
end

local function getCurrentGSEAction(seq)
    local seqFrame = seq and _G[seq]
    local executionseq = seq and GSE.SequencesExec and GSE.SequencesExec[seq]
    if not seqFrame or not executionseq then return nil end

    local step = seqFrame:GetAttribute("step") or 1
    local iteration = seqFrame:GetAttribute("iteration") or 1
    if iteration > 1 then
        step = step + iteration * 254
    end

    return executionseq[step]
end

local function getGSESequenceIcon(seq)
    -- A base icon the player picked shows while the sequence is at rest (its
    -- first step, first time through); running, the step icons show as before.
    local base = GSE.GetSequenceBaseIcon(seq)
    if base then
        local frame = _G[seq]
        local step = frame and frame:GetAttribute("step") or 1
        local iteration = frame and frame:GetAttribute("iteration") or 1
        if step <= 1 and iteration <= 1 then return base end
    end
    if seq and _G[seq] then
        local action = getCurrentGSEAction(seq)
        if action and action.type == "macro" and action.macrotext and GSE.GetMacroTextIconInfo then
            local iconInfo = GSE.GetMacroTextIconInfo(action.macrotext)
            if iconInfo and iconInfo.iconID and not isGSEFallbackTexture(iconInfo.iconID) then return iconInfo.iconID end
        end

        if GSE.GetCurrentButtonIconInfo then
            local iconInfo = GSE.GetCurrentButtonIconInfo(_G[seq], false)
            if iconInfo and iconInfo.iconID and not isGSEFallbackTexture(iconInfo.iconID) then return iconInfo.iconID end
        end
    end

    if not GetMacroIndexByName then return nil end
    if not seq then return nil end
    local idx = GetMacroIndexByName(seq)
    if not idx or idx == 0 then return nil end
    local _, texture = GetMacroInfo(idx)
    if isGSEFallbackTexture(texture) then return nil end
    return texture
end

local function getGSEButtonIcon(self)
    -- A real action in the slot wins: don't paint the sequence icon over it.
    if GSE.ActionBarSlotHasForeignAction(self) then return nil end
    local seq = self:GetAttribute("gse-button")
    local seqTexture = getGSESequenceIcon(seq)
    if seqTexture then return seqTexture end

    local effectiveSlot = getButtonEffectiveSlot(self)
    if effectiveSlot and GetActionTexture then
        local texture = GetActionTexture(effectiveSlot)
        if texture and not isGSEFallbackTexture(texture) then return texture end
    end
end

-- Bars that hide empty action buttons (notably Dominos) will hide a GSE override
-- slot, because the slot holds no real action -- HasAction() is false, so the
-- bar's "show empty buttons" gate keeps it hidden and the assigned override
-- vanishes. Dominos gates visibility on a `showgrid` bitmask of "reasons" and
-- exposes the insecure helper button:SetShowGridInsecure(show, reason, force).
-- We OR in a private GSE reason bit (clear of Dominos' own 1/2/4/16/32) so the
-- slot stays shown without disturbing Dominos' grid state; clearing the bit on
-- removal lets the slot hide again. Feature-detected, so it is a no-op on
-- Blizzard/other bars that don't provide the method. Combat-guarded by Dominos.
local GSE_FORCE_SHOWGRID_REASON = 262144 -- 0x40000, a single high bit

-- Blizzard's own bars (Retail and Forever) do the same with the "showgrid"
-- attribute: with "Always Show Buttons" off, ActionBarMixin:UpdateShownButtons
-- shows a button only when it has an action or showgrid is non-zero. The same
-- private bit goes into showgrid inside the SecureHandler -- written from
-- insecure Lua the attribute would be tainted, and Blizzard's secure bar code
-- reads it (the #1931 lesson) -- and the button is shown at once.
local SHOWGRID_ON = [[
    local b = self:GetFrameRef("gseGridButton")
    if not b then return end
    local grid = b:GetAttribute("showgrid") or 0
    if math.floor(grid / 262144) % 2 == 0 then b:SetAttribute("showgrid", grid + 262144) end
    b:Show()
]]
local SHOWGRID_OFF = [[
    local b = self:GetFrameRef("gseGridButton")
    if not b then return end
    local grid = b:GetAttribute("showgrid") or 0
    if math.floor(grid / 262144) % 2 == 1 then b:SetAttribute("showgrid", grid - 262144) end
]]
local function setOverrideButtonForcedShown(buttonOrName, shown)
    local btn = type(buttonOrName) == "string" and _G[buttonOrName] or buttonOrName
    if not btn or InCombatLockdown() then return end
    if btn.SetShowGridInsecure then
        btn:SetShowGridInsecure(shown and true or false, GSE_FORCE_SHOWGRID_REASON, true)
    elseif btn.GetShowGrid and btn.bar and btn.bar.UpdateShownButtons then
        -- Only when the bit has to change: repaints call this often.
        local hasBit = math.floor((btn:GetAttribute("showgrid") or 0) / GSE_FORCE_SHOWGRID_REASON) % 2 == 1
        if hasBit == (shown and true or false) and (not shown or btn:IsShown()) then return end
        SHBT:SetFrameRef("gseGridButton", btn)
        SHBT:Execute(shown and SHOWGRID_ON or SHOWGRID_OFF)
    end
end

-- An override slot holds no action, so the bar draws no cooldown on it. The
-- swipe is for the spell whose icon the button shows. That icon can be a
-- block's own icon or the player's base icon rather than the spell the step
-- resolves to, so the spell is found by its icon among every spell the
-- sequence names (all branches). No spell there has that icon (an item, a
-- picked picture): no swipe.
local overrideSpell = setmetatable({}, {__mode = "k"})
local isSecretValue = _G.issecretvalue or function() return false end
local function addClauseSpells(map, clauses)
    for _, clause in ipairs(clauses) do
        local target = GSE.GetMacroClauseTarget(clause)
        if target ~= "" then
            local current = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(target) or target
            local info = GSE.GetSpellInfo(current) or GSE.GetSpellInfo(tonumber(target) or target)
            if info and info.spellID and info.iconID and not map[info.iconID] then map[info.iconID] = info.spellID end
        end
    end
end
local function buildIconSpells(executionseq)
    local map, seen = {}, {}
    for _, action in pairs(executionseq) do
        local text = type(action) == "table" and action.macrotext
        -- A block of one plain spell compiles to a spell action, no macro text.
        local spell = type(action) == "table" and action.type == "spell" and action.spell
        if type(spell) == "string" and not seen[spell] then
            seen[spell] = true
            addClauseSpells(map, {GSE.UnEscapeString(spell)})
        end
        if type(text) == "string" and not seen[text] then
            seen[text] = true
            -- Line by line: a bare command ("/startattack") must not swallow
            -- the line after it.
            for line in string.gmatch(text, "[^\r\n]+") do
                local cmd, rest = string.match(line, "^%s*/(%a+)[ \t]+(.+)")
                cmd = cmd and string.lower(cmd)
                for _, branch in ipairs(cmd and GSE.split(rest, ";") or {}) do
                    if cmd == "castsequence" then
                        addClauseSpells(map, GSE.SplitCastSequence(branch))
                    elseif cmd == "cast" or cmd == "use" or cmd == "spell" then
                        addClauseSpells(map, {branch})
                    end
                end
            end
        end
    end
    return map
end
local sequenceIconSpells = {} -- [seq] = {exec = compiled steps, built = time, map = {[texture] = spellID}}
local function spellForIcon(seq, texture)
    local executionseq = seq and GSE.SequencesExec and GSE.SequencesExec[seq]
    if not (executionseq and texture) or isSecretValue(texture) then return nil end
    local entry = sequenceIconSpells[seq]
    -- Rebuilt when the sequence is recompiled, and on a miss at most every 5s
    -- (a spell not known yet at login, a talent swap).
    if not entry or entry.exec ~= executionseq or (not entry.map[texture] and GetTime() - entry.built > 5) then
        local ok, map = pcall(buildIconSpells, executionseq)
        entry = {exec = executionseq, built = GetTime(), map = ok and map or {}}
        sequenceIconSpells[seq] = entry
    end
    return entry.map[texture]
end
local function spellInRange(spellID, unit)
    if C_Spell and C_Spell.IsSpellInRange then return C_Spell.IsSpellInRange(spellID, unit) end
    local info = IsSpellInRange and GSE.GetSpellInfo(spellID)
    local answer = info and info.name and IsSpellInRange(info.name, unit)
    if answer ~= nil then return answer == 1 end
end
-- The LibActionButton library that owns a button (Bartender, ElvUI, NDui and
-- ConsolePort each ship their own copy), or nil for a Blizzard-style button.
local labLibFor = setmetatable({}, {__mode = "k"})
local function labLib(button)
    local lib = labLibFor[button]
    if lib == nil then
        lib = false
        for name, candidate in pairs(LibStub and LibStub.libs or {}) do
            if type(name) == "string" and string.find(name, "^LibActionButton") and type(candidate) == "table"
                and type(candidate.buttonRegistry) == "table" and candidate.buttonRegistry[button] then
                lib = candidate
                break
            end
        end
        labLibFor[button] = lib
    end
    return lib or nil
end
-- Whether the override, not a real action, is what the button shows now.
local function overrideShowing(button)
    if not button:GetAttribute("gse-button") then return false end
    if labLib(button) then
        return button._state_type == "custom"
            and button:GetAttribute("gse-lab-state-" .. tostring(button:GetAttribute("state"))) and true or false
    end
    return not GSE.ActionBarSlotHasForeignAction(button)
end
-- A LibActionButton bar draws cooldown, range colour and proc glow itself, in
-- the player's own settings, from what each button answers for its spell. An
-- override is a "custom" state, which answers nothing, so while one shows the
-- button answers for the spell whose icon shows; any other state gets the
-- library's own answer.
local GLOW_PROBE_ID = -1 -- no real spell: lets the library be told to glow one button
local glowProbe = {}
local LAB_ANSWERS = {
    GetSpellId = function(spellID) return spellID end,
    GetCooldownInfo = function(spellID) return GSE.GetSpellCooldown(spellID) end,
    GetCooldownDuration = function(spellID)
        return C_Spell and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(spellID) or nil
    end,
    IsUnitInRange = function(spellID, unit) return spellInRange(spellID, unit or "target") end,
    IsUsable = function(spellID)
        if C_Spell and C_Spell.IsSpellUsable then return C_Spell.IsSpellUsable(spellID) end
        if IsUsableSpell then return IsUsableSpell(spellID) end
    end,
    GetDisplayCount = function(spellID)
        if C_Spell and C_Spell.GetSpellDisplayCount then return C_Spell.GetSpellDisplayCount(spellID) end
        return nil
    end,
    GetCount = function(spellID)
        local get = C_Spell and C_Spell.GetSpellCastCount or _G.GetSpellCastCount or _G.GetSpellCount
        return get and get(spellID) or 0
    end,
    IsConsumableOrStackable = function(spellID)
        local is = C_Spell and C_Spell.IsConsumableSpell or IsConsumableSpell
        return is and is(spellID) or nil
    end,
    GetChargeInfo = function(spellID)
        return C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID) or nil
    end,
}
local labAnswering = setmetatable({}, {__mode = "k"})
local function hookLABAnswers(button)
    if not button or labAnswering[button] or not labLib(button) then return end
    labAnswering[button] = true
    for method, answer in pairs(LAB_ANSWERS) do
        button[method] = function(self, ...)
            if method == "GetSpellId" and glowProbe[self] then return GLOW_PROBE_ID end
            local spellID = overrideShowing(self) and overrideSpell[self]
            if spellID then return answer(spellID, ...) end
            local kind = getmetatable(self)
            local own = kind and type(kind.__index) == "table" and kind.__index[method]
            if own then return own(self, ...) end
        end
    end
end
-- The library's own show/hide for one button: its glow event with a spell id
-- only that button answers to.
local function labGlow(button, lib, lit)
    local handler = lib.eventFrame and lib.eventFrame.GetScript and lib.eventFrame:GetScript("OnEvent")
    if not handler then return end
    glowProbe[button] = true
    pcall(handler, lib.eventFrame,
        lit and "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", GLOW_PROBE_ID)
    glowProbe[button] = nil
end
-- That spell's cooldown (the global cooldown included, as on a spell button)
-- on the button's own cooldown frame. Where WoW has duration objects (Retail;
-- its cooldown values can be secret in combat, which SetCooldown refuses from
-- an addon) the object goes to the frame; elsewhere the plain start and
-- duration.
-- shortcut: no charge or loss-of-control swipe, add if a sequence needs them.
local function setSpellCooldown(cooldown, spellID)
    if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            cooldown:SetCooldownFromDurationObject(duration)
        else
            cooldown:Clear()
        end
    else
        local info = GSE.GetSpellCooldown(spellID)
        if info and info.startTime and info.duration then
            cooldown:SetCooldown(info.startTime, info.duration, info.modRate)
        else
            cooldown:Clear()
        end
    end
end
local applyingCooldown -- our own SetCooldown/Clear, not the bar's
local function applyOverrideCooldown(button)
    local cooldown = button and button.cooldown
    if not (cooldown and cooldown.SetCooldown and cooldown.Clear) then return end
    -- A real action on the slot wins: its cooldown is the bar's to draw.
    if not overrideShowing(button) then return end
    local spellID = overrideSpell[button]
    applyingCooldown = true
    if spellID then
        pcall(setSpellCooldown, cooldown, spellID)
    else
        cooldown:Clear()
    end
    applyingCooldown = nil
end
-- The count on the icon for the spell it shows -- its charges, or the stacks
-- it costs -- as WoW's own buttons draw it: C_Spell.GetSpellDisplayCount,
-- the flyout buttons' call (an action slot's count reads the slot, which an
-- override has none of); older clients, the cast count else the charges. A
-- LibActionButton bar draws its own from the answers above. In combat the
-- client can keep the count secret; the text takes a secret string as it is.
local function spellCountText(spellID)
    if C_Spell and C_Spell.GetSpellDisplayCount then return C_Spell.GetSpellDisplayCount(spellID) end
    local get = _G.GetSpellCastCount or _G.GetSpellCount
    local count = get and get(spellID) or 0
    if count > 0 then return count end
    local current, max
    if C_Spell and C_Spell.GetSpellCharges then
        local charges = C_Spell.GetSpellCharges(spellID)
        if charges then current, max = charges.currentCharges, charges.maxCharges end
    elseif GetSpellCharges then
        current, max = GetSpellCharges(spellID)
    end
    if max and max > 1 then return current end
    return ""
end
local applyingCount -- our own SetText, not the bar's
local function applyOverrideCount(button)
    if not (button and button.GetAttribute) or labLib(button) then return end
    local name = button.GetName and button:GetName()
    local count = button.Count or (name and _G[name .. "Count"])
    if not (count and count.SetText) or not overrideShowing(button) then return end
    local spellID = overrideSpell[button]
    applyingCount = true
    if spellID then
        local ok, text = pcall(spellCountText, spellID)
        count:SetText(ok and text or "")
    else
        count:SetText("")
    end
    applyingCount = nil
end
-- The bar writes an empty slot's count ("") on its own updates; put ours
-- back in the same call.
local countHooked = setmetatable({}, {__mode = "k"})
local function hookCountKeep(button)
    local name = button and button.GetName and button:GetName()
    local count = button and (button.Count or (name and _G[name .. "Count"]))
    if not (count and count.SetText and not countHooked[count]) then return end
    countHooked[count] = true
    hooksecurefunc(count, "SetText", function()
        if not applyingCount then applyOverrideCount(button) end
    end)
end
-- The proc glow while the spell whose icon shows is lit up by a proc
-- (C_SpellActivationOverlay). On a LibActionButton bar the library shows its
-- own (labGlow). Elsewhere the bar's own alert manager, so it looks and is
-- skinned like every other button's: an override slot holds no action, so the
-- bar takes the alert down on its own updates and it is put back with no
-- birth animation. (The bar reads the manager's state only at the end of its
-- Update, after its protected writes.)
local overrideGlowing = setmetatable({}, {__mode = "k"})
local applyingGlow -- our own ShowAlert/HideAlert, not the bar's
local applyOverrideUsable -- below: the icon's tint follows its spell
-- The proc glow's art, as Blizzard picks it for its own buttons (its
-- CheckAndSetArtStyle, which skips a button with no bar): with the assisted
-- highlight on -- or its reduce-highlights option, while an assisted-combat
-- button exists -- a rotation spell's proc is the thin ring, so the blue
-- ring beside it stays readable. Its rule reads the button's action slot;
-- an override has none, so the spell its icon shows stands in.
local function styleOverrideAlert(button)
    local alert = button and button.SpellActivationAlert
    local manager = _G.AssistedCombatManager
    if not (alert and alert.ProcAltGlow and alert.ProcStartFlipbook and alert.ProcLoopFlipbook
        and manager and manager.IsRotationSpell and manager.IsAssistedHighlightActive) then return end
    local spellID, thin = overrideSpell[button], false
    if spellID then
        local reduce = manager:IsAssistedHighlightActive()
        if not reduce and _G.CVarCallbackRegistry and C_ActionBar and C_ActionBar.HasAssistedCombatActionButtons then
            reduce = _G.CVarCallbackRegistry:GetCVarValueBool("assistedCombatReduceHighlights")
                and C_ActionBar.HasAssistedCombatActionButtons()
        end
        if reduce then thin = manager:IsRotationSpell(spellID) and true or false end
    end
    alert.ProcStartFlipbook:SetShown(not thin)
    alert.ProcLoopFlipbook:SetShown(not thin)
    alert.ProcAltGlow:SetShown(thin)
end
local function applyOverrideGlow(button, reassert)
    local overlay = _G.C_SpellActivationOverlay
    if not (button and button.GetAttribute and overlay and overlay.IsSpellOverlayed) then return end
    local lib, alerts = labLib(button), _G.ActionButtonSpellAlertManager
    if not lib and not (alerts and alerts.ShowAlert and alerts.HideAlert) then return end
    local showing = overrideShowing(button)
    local spellID, lit = overrideSpell[button], false
    if spellID and showing then
        lit = overlay.IsSpellOverlayed(spellID)
        if isSecretValue(lit) then return end
        lit = lit and true or false
    end
    if lit == (overrideGlowing[button] or false) and not (lit and reassert) then return end
    overrideGlowing[button] = lit or nil
    applyingGlow = true
    if lib then
        if lit or showing then labGlow(button, lib, lit) end
    elseif lit then
        pcall(alerts.ShowAlert, alerts, button, reassert)
        styleOverrideAlert(button)
    elseif showing or not button:GetAttribute("gse-button") then -- a real action's glow is the bar's to show
        pcall(alerts.HideAlert, alerts, button)
    end
    applyingGlow = nil
end
if _G.ActionButtonSpellAlertManager and _G.ActionButtonSpellAlertManager.HideAlert then
    hooksecurefunc(_G.ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        if not applyingGlow and overrideGlowing[button] then applyOverrideGlow(button, true) end
    end)
end
-- Blizzard's assisted highlight: the blue glow on the spell its rotation
-- helper would cast next, for players who turned that option on. Its list of
-- buttons only holds slots with an action, so an override whose icon shows
-- that spell is given the same frame through Blizzard's own call. A
-- LibActionButton bar does its own (GetSpellId, above).
-- shortcut: not put back if the bar hides it on an action change, add a hook if seen.
local overrideAssisted = setmetatable({}, {__mode = "k"})
local function applyOverrideAssist(button)
    local manager = _G.AssistedCombatManager
    if not (button and button.GetAttribute and manager and manager.SetAssistedHighlightFrameShown
        and manager.IsAssistedHighlightActive) or labLib(button) then return end
    local spellID, nextSpell, shown = overrideSpell[button], manager.lastNextCastSpellID, false
    if spellID and nextSpell and not isSecretValue(nextSpell) and manager:IsAssistedHighlightActive()
        and overrideShowing(button) then
        shown = spellID == nextSpell
    end
    if not shown and not overrideAssisted[button] then return end -- never hide a real action's
    overrideAssisted[button] = shown or nil
    pcall(manager.SetAssistedHighlightFrameShown, manager, button, shown)
    -- Blizzard shrinks the glow (66 on its 45 buttons) to 48 for any button
    -- with no action slot, meant for the small stance buttons; a slotless
    -- override button (the GSE Action Bar's) gets the template's size back,
    -- in proportion to the button.
    local glow = shown and button.action == nil and button.AssistedCombatHighlightFrame
    if glow and glow.Flipbook and button.GetWidth then
        local size = (button:GetWidth() or 45) * 66 / 45
        glow.Flipbook:SetSize(size, size)
    end
end
if _G.AssistedCombatManager and _G.EventRegistry and _G.EventRegistry.RegisterCallback then
    local owner = CreateFrame("Frame")
    -- Next frame: after Blizzard's own pass, and after it has noted combat
    -- (the glow animates in combat only).
    local function refreshAssist()
        C_Timer.After(0, function()
            for buttonName in pairs(GSE.ButtonOverrides or {}) do
                applyOverrideAssist(_G[buttonName])
                -- Blizzard restyles its own buttons' proc glows on these too.
                if overrideGlowing[_G[buttonName]] then styleOverrideAlert(_G[buttonName]) end
            end
        end)
    end
    _G.EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", refreshAssist, owner)
    _G.EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", refreshAssist, owner)
    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:SetScript("OnEvent", refreshAssist)
end
-- Several painters set an override's icon (this file, Storage's UpdateIcon,
-- the bar): the spell is re-read wherever the texture is set.
-- The spell the sequence casts next, by the icon of its current step, for
-- a button whose own icon is nobody's spell: at rest a base icon the player
-- picked shows (getGSESequenceIcon), so the assisted highlight -- and the
-- cooldown, count, range and glow beside it -- had nothing to match until
-- combat put a step icon up.
local function stepSpell(seq)
    local action = getCurrentGSEAction(seq)
    if type(action) ~= "table" then return nil end
    local iconID
    if action.type == "spell" and action.spell then
        local info = GSE.GetSpellInfo(GSE.UnEscapeString(tostring(action.spell)))
        iconID = info and info.iconID
    elseif action.macrotext and GSE.GetMacroTextIconInfo then
        local info = GSE.GetMacroTextIconInfo(action.macrotext, true)
        iconID = info and info.iconID
    end
    return iconID and spellForIcon(seq, iconID) or nil
end
local iconSpellHooked = setmetatable({}, {__mode = "k"})
local function hookIconSpell(button)
    local name = button and button.GetName and button:GetName()
    local icon = button and (button.icon or (name and _G[name .. "Icon"]))
    if not (icon and icon.SetTexture and icon.GetTexture) or iconSpellHooked[icon] then return end
    iconSpellHooked[icon] = true
    local function follow()
        local seq = button:GetAttribute("gse-button")
        if not seq then return end
        local spellID = spellForIcon(seq, icon:GetTexture()) or stepSpell(seq)
        if spellID ~= overrideSpell[button] then
            overrideSpell[button] = spellID
            applyOverrideCooldown(button)
            applyOverrideCount(button)
            applyOverrideGlow(button)
            applyOverrideAssist(button)
            applyOverrideUsable(button)
        end
    end
    hooksecurefunc(icon, "SetTexture", follow)
    follow()
end
-- The bar clears an empty slot's cooldown on its own updates; put ours back
-- in the same call, so no frame is drawn without it.
local cooldownHooked = setmetatable({}, {__mode = "k"})
local function hookCooldownKeep(button)
    local cooldown = button and button.cooldown
    if not (cooldown and cooldown.Clear and not cooldownHooked[cooldown]) then return end
    cooldownHooked[cooldown] = true
    local function reassert()
        if not applyingCooldown then applyOverrideCooldown(button) end
    end
    hooksecurefunc(cooldown, "Clear", reassert)
    hooksecurefunc(cooldown, "SetCooldown", reassert)
end
-- Blizzard's own range indicator for that spell against the target: the key
-- text goes red out of range. The client only reports range for a slot that
-- holds an action, so an override is checked here, on the stock 0.2s beat.
-- A LibActionButton bar colours range itself (IsUnitInRange, above).
-- shortcut: a secret answer leaves the key as it is, revisit if Retail hides range in combat.
local overrideOutOfRange = setmetatable({}, {__mode = "k"}) -- read by the icon tint
local function applyOverrideRange(button)
    if not (button and button.HotKey and button.GetAttribute) or labLib(button) then return end
    if not overrideShowing(button) then return end
    local spellID, inRange = overrideSpell[button], nil
    if spellID then inRange = spellInRange(spellID, "target") end
    if isSecretValue(inRange) then return end
    pcall(_G.ActionButton_UpdateRangeIndicator, button, inRange ~= nil, inRange)
    local outOfRange = inRange == false or nil
    if overrideOutOfRange[button] ~= outOfRange then
        overrideOutOfRange[button] = outOfRange
        if applyOverrideUsable then applyOverrideUsable(button) end
    end
end
-- HUI ActionBars (Larry runs it) colours a Blizzard button's icon from its
-- own settings -- cooldown, out of range, out of power, not usable, each
-- with its colour and desaturate switch -- reading the button's action
-- slot, which an override has none of. With it loaded the override takes
-- its colours and order, from the bar's config where it has one, else
-- HUI's global settings; the user's choices on their bars apply to GSE's.
local function huiTint(button, onCooldown, outOfRange, usable, noMana)
    local hui = _G.HUI
    if not (hui and hui.GetValue and hui.GetRGBA and hui.GetConfig) then return nil end
    local ok, _, configName = pcall(hui.GetConfig, hui, button)
    if not ok then return nil end
    local function on(key) return hui:GetValue(key, nil, configName) end
    local function colour(key, desaturateKey)
        local r, g, b = hui:GetRGBA(key, nil, configName)
        return r, g, b, on(desaturateKey) and true or false
    end
    if onCooldown and on("UseCDColor") then return colour("CDColor", "CDColorDesaturate") end
    if outOfRange and on("UseOORColor") then return colour("OORColor", "OORDesaturate") end
    if usable then return 1, 1, 1, false end
    if noMana and on("UseOOMColor") then return colour("OOMColor", "OOMDesaturate") end
    if on("UseNoUseColor") then return colour("NoUseColor", "NoUseDesaturate") end
    -- A colour HUI has off it leaves to WoW's own paint: blue short of
    -- power, grey not usable.
    if noMana then return 0.5, 0.5, 1, false end
    return 0.4, 0.4, 0.4, false
end
-- On a cooldown of its own, past the global one, for HUI's cooldown colour.
local function onOwnCooldown(spellID)
    local info = GSE.GetSpellCooldown(spellID)
    if not info or isSecretValue(info.isActive) or isSecretValue(info.isOnGCD) then return false end
    if info.isActive ~= nil then return info.isActive and not info.isOnGCD end
    return (info.duration or 0) > 1.5 and (info.startTime or 0) > 0
end
-- The icon's tint for the spell it shows, as WoW's bars paint theirs: white
-- usable, blue short of power, grey not usable. Nothing with no spell (an
-- item's icon), on a LibActionButton bar (its own, from IsUsable above), or
-- when WoW keeps the answer secret. True when painted.
local applyingTint -- our own SetVertexColor, not a skin's
applyOverrideUsable = function(button)
    if not (button and button.GetAttribute) or labLib(button) then return false end
    local name = button.GetName and button:GetName()
    local icon = button.icon or (name and _G[name .. "Icon"])
    if not (icon and icon.SetVertexColor) or not overrideShowing(button) then return false end
    local spellID = overrideSpell[button]
    if not spellID then return false end
    local usable, noMana
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        usable, noMana = IsUsableSpell(spellID)
    else
        return false
    end
    if isSecretValue(usable) or isSecretValue(noMana) then return false end
    local r, g, b, desaturate = huiTint(button, onOwnCooldown(spellID), overrideOutOfRange[button], usable, noMana)
    if not r then
        -- WoW's own bars: white, blue short of power, grey not usable; no
        -- range tint on the icon (the key text goes red).
        desaturate = false
        if usable then r, g, b = 1, 1, 1 elseif noMana then r, g, b = 0.5, 0.5, 1 else r, g, b = 0.4, 0.4, 0.4 end
    end
    applyingTint = true
    icon:SetVertexColor(r, g, b)
    if icon.SetDesaturated then icon:SetDesaturated(desaturate) end
    applyingTint = nil
    return true
end
GSE.ApplyOverrideUsable = applyOverrideUsable -- the icon colour guard, below

do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    -- What changes a spell's usability, as WoW's bars listen for it.
    for _, event in ipairs({ "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE", "PLAYER_TARGET_CHANGED" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    pcall(watcher.RegisterUnitEvent, watcher, "UNIT_POWER_FREQUENT", "player")
    -- What changes a count: charges, the stacks it costs, reagents.
    pcall(watcher.RegisterEvent, watcher, "SPELL_UPDATE_CHARGES")
    pcall(watcher.RegisterUnitEvent, watcher, "UNIT_AURA", "player")
    pcall(watcher.RegisterEvent, watcher, "BAG_UPDATE_DELAYED")
    pcall(watcher.RegisterEvent, watcher, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    pcall(watcher.RegisterEvent, watcher, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    local USABLE = { SPELL_UPDATE_USABLE = true, ACTIONBAR_UPDATE_USABLE = true, PLAYER_TARGET_CHANGED = true,
        UNIT_POWER_FREQUENT = true }
    local COUNT = { SPELL_UPDATE_CHARGES = true, UNIT_AURA = true, BAG_UPDATE_DELAYED = true,
        SPELL_UPDATE_USABLE = true }
    watcher:SetScript("OnEvent", function(_, event)
        local apply = event == "SPELL_UPDATE_COOLDOWN" and applyOverrideCooldown
            or USABLE[event] and applyOverrideUsable or COUNT[event] and applyOverrideCount or applyOverrideGlow
        for buttonName in pairs(GSE.ButtonOverrides or {}) do
            apply(_G[buttonName])
            if event == "SPELL_UPDATE_COOLDOWN" then applyOverrideUsable(_G[buttonName]) end
            if COUNT[event] and apply ~= applyOverrideCount then applyOverrideCount(_G[buttonName]) end
        end
    end)
    if _G.ActionButton_UpdateRangeIndicator then
        local sinceRange = 0
        watcher:SetScript("OnUpdate", function(_, elapsed)
            sinceRange = sinceRange + elapsed
            if sinceRange < 0.2 then return end
            sinceRange = 0
            for buttonName in pairs(GSE.ButtonOverrides or {}) do applyOverrideRange(_G[buttonName]) end
        end)
    end
end
-- A held key on an override button arrives as repeated presses whose down and
-- up land in the same frame, so the button is PUSHED and NORMAL again before
-- anything is drawn and the press-down never shows (a normal spell button
-- stays pushed while held). Keep the pushed art up briefly after such a press.
-- Visual only, so it works in combat.
local PRESS_FLASH_SECONDS = 0.1
local pressFlashHooked = setmetatable({}, {__mode = "k"})
local function hookPressFlash(button)
    if not (button and button.GetPushedTexture and button.SetButtonState and not pressFlashHooked[button]) then return end
    pressFlashHooked[button] = true
    local pushedAt
    hooksecurefunc(button, "SetButtonState", function(self, state)
        if not self:GetAttribute("gse-button") then return end
        if state == "PUSHED" then
            pushedAt = GetTime()
        elseif state == "NORMAL" and pushedAt and GetTime() - pushedAt < 0.02 then
            local pushed = self:GetPushedTexture()
            if pushed then
                pushed:Show()
                C_Timer.After(PRESS_FLASH_SECONDS, function()
                    if self:GetButtonState() == "NORMAL" then pushed:Hide() end
                end)
            end
        end
    end)
end

local function repaintGSEOverrideButton(button, defer)
    if not button or not button.GetAttribute then return end

    local function repaint()
        if not button:GetAttribute("gse-button") then return end
        -- Keep bars that hide empty buttons (Dominos) from hiding this override
        -- slot; re-asserted here because Dominos may re-evaluate grid state after
        -- our initial apply (hence the staggered repaint schedule).
        setOverrideButtonForcedShown(button, true)
        local btnName = button:GetName()
        local icon = button.icon or (btnName and _G[btnName .. "Icon"])
        if not icon then return end

        local texture = getGSEButtonIcon(button)
        if texture then
            icon:SetTexture(texture)
            icon:Show()
        end
    end

    if defer then
        C_Timer.After(0, repaint)
    else
        repaint()
    end
end

local function repaintAllGSEOverrideIcons(defer, sequenceName)
    if not GSE.ButtonOverrides then return end
    for buttonName, seq in pairs(GSE.ButtonOverrides) do
        if not sequenceName or seq == sequenceName then
            repaintGSEOverrideButton(_G[buttonName], defer)
        end
    end
end

function GSE.RefreshActionBarOverrideIcons(sequenceName, defer)
    repaintAllGSEOverrideIcons(defer, sequenceName)
end

-- A sequence's base icon: picked on its Config page (right-click the drag
-- icon) so sequences that open with the same spell do not all look alike on
-- the bars. Kept on this PC only (GSEOptions), never in the sequence itself.
function GSE.GetSequenceBaseIcon(sequenceId)
    local icons = GSEOptions and GSEOptions.SequenceBaseIcons
    return sequenceId and icons and icons[sequenceId] or nil
end

function GSE.SetSequenceBaseIcon(sequenceId, icon)
    if not sequenceId then return end
    GSEOptions.SequenceBaseIcons = GSEOptions.SequenceBaseIcons or {}
    GSEOptions.SequenceBaseIcons[sequenceId] = icon
    GSE.RefreshActionBarOverrideIcons(sequenceId)
end

local function scheduleGSEOverrideIconRepaint()
    repaintAllGSEOverrideIcons(true)
    C_Timer.After(0, function() repaintAllGSEOverrideIcons(false) end)
    C_Timer.After(0.1, function() repaintAllGSEOverrideIcons(false) end)
    C_Timer.After(0.25, function() repaintAllGSEOverrideIcons(false) end)
    C_Timer.After(0.5, function() repaintAllGSEOverrideIcons(false) end)
    C_Timer.After(1, function() repaintAllGSEOverrideIcons(false) end)
    C_Timer.After(2, function() repaintAllGSEOverrideIcons(false) end)
end
-- Small GSE logo overlaid in the bottom-right corner of overridden buttons.
local watermarkedButtons = {}
-- Watermarks on frames that stand in for an override button (the editor's
-- Config icon), so the option shows and hides them too.
local otherWatermarks = setmetatable({}, {__mode = "k"})
local WATERMARK_SIZE, WATERMARK_INSET = 14, 2

-- Size and place a watermark for a button drawn at scale times a bar button.
function GSE.PlaceGSEWatermark(wm, frame, scale)
    scale = scale or 1
    wm:SetSize(WATERMARK_SIZE * scale, WATERMARK_SIZE * scale)
    wm:ClearAllPoints()
    wm:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -WATERMARK_INSET * scale, WATERMARK_INSET * scale)
end

local function createGSEWatermark(frame)
    local wm = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    wm:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.png")
    wm:SetAlpha(0.85)
    GSE.PlaceGSEWatermark(wm, frame)
    if GSEOptions.showActionBarWatermark == false then wm:Hide() end
    return wm
end

-- The override button's watermark on a frame that is not one, as it would
-- show on the bar.
function GSE.CreateGSEWatermark(frame)
    local wm = createGSEWatermark(frame)
    otherWatermarks[wm] = true
    return wm
end

local function addGSEWatermark(Button)
    if watermarkedButtons[Button] then return end
    local btn = _G[Button]
    if not btn then return end
    watermarkedButtons[Button] = createGSEWatermark(btn)
end

local function removeGSEWatermark(Button)
    local wm = watermarkedButtons[Button]
    if not wm then return end
    wm:Hide()
    watermarkedButtons[Button] = nil
end

local function setWatermarkVisible(Button, visible)
    if GSEOptions.showActionBarWatermark == false then return end
    local wm = watermarkedButtons[Button]
    if not wm then return end
    if visible then wm:Show() else wm:Hide() end
end

function GSE.SetActionBarWatermarkEnabled(enabled)
    for _, wm in pairs(watermarkedButtons) do
        if enabled then wm:Show() else wm:Hide() end
    end
    for wm in pairs(otherWatermarks) do
        if enabled then wm:Show() else wm:Hide() end
    end
end


-- Restore the GSE macro icon on a button, deferring one frame so WoW's own
-- ActionButton_Update pass (triggered by type/attribute changes) runs first.
-- If GetActionTexture is not yet populated (e.g. at startup), falls back to
-- GSE.UpdateIcon which reads the icon directly from the compiled SequencesExec.
local function scheduleIconRestore(self, icon)
    C_Timer.After(0, function()
        if not self:GetAttribute("gse-button") then return end
        local texture = getGSEButtonIcon(self)
        if texture then
            icon:SetTexture(texture)
            icon:Show()
            return
        end
        -- Action bar slot not yet populated ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ delegate to UpdateIcon which
        -- resolves the spell icon from the compiled sequence execution table.
        local seq = self:GetAttribute("gse-button")
        if seq and _G[seq] and GSE.UpdateIcon then
            GSE.UpdateIcon(_G[seq], false)
        end
    end)
end

-- Resolve and display the tooltip for a GSE-overridden action button.
-- Reads the current step's spell from GSE.SequencesExec (the action bar slot is
-- empty for GSE overrides, so GetActionInfo is not useful here).
-- Safe to call in combat ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â all APIs used are non-secure reads.
local function showGSEButtonTooltip(btn)
    if not btn or not btn.GetAttribute then return end
    if not btn:GetAttribute("gse-button") then return end
    local seqName = btn:GetAttribute("gse-button")
    local seqFrame = seqName and _G[seqName]
    if not seqFrame or not GSE.SequencesExec then return end
    local step = seqFrame:GetAttribute("step") or 1
    local executionseq = GSE.SequencesExec[seqName]
    if not executionseq or not executionseq[step] then return end
    local entry = executionseq[step]
    local spellID
    if entry.type == "spell" and entry.spell then
        local spell = GSE.UnEscapeString(entry.spell)
        local currentSpell = GSE.GetCurrentSpellID and GSE.GetCurrentSpellID(spell) or spell
        local info = GSE.GetSpellInfo(currentSpell)
        spellID = info and info.spellID
    elseif entry.type == "macro" and entry.macrotext then
        local info = GSE.GetSpellsFromString(entry.macrotext)
        if info then
            if info.spellID then
                spellID = info.spellID
            elseif info[1] and info[1].spellID then
                -- castsequence returns an array; use the first spell
                spellID = info[1].spellID
            end
        end
        -- Fallback: scan each line with SecureCmdOptionParse so that
        -- conditionals like [known:X] are evaluated for the current state.
        if not spellID then
            for line in string.gmatch(entry.macrotext .. "\n", "([^\n]+)\n") do
                local rest = line:match("^/%a+%s+(.*)")
                if rest then
                    local spell = GSE.SafeSecureCmdOptionParse and GSE.SafeSecureCmdOptionParse(rest, true)
                    if spell and spell ~= "" then
                        local si = GSE.GetSpellInfo(spell)
                        if si and si.spellID then
                            spellID = si.spellID
                            break
                        end
                    end
                end
            end
        end
    elseif entry.type == "macro" and entry.macro and GetMacroIndexByName then
        local idx = GetMacroIndexByName(entry.macro)
        if idx and idx > 0 then spellID = GetMacroSpell(idx) end
    end
    GameTooltip_SetDefaultAnchor(GameTooltip, btn)
    if spellID then
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spellID)
        else
            GameTooltip:SetHyperlink("spell:" .. spellID)
        end
        -- The rank, top right, as Blizzard's own action buttons show it. They
        -- read it from the action slot; SetSpellByID has only the ID and
        -- leaves the line empty on WoW Forever.
        local rankText = GSE.GetSpellRankText and GSE.GetSpellRankText(spellID)
        local rightLine = _G.GameTooltipTextRight1
        if rankText and rightLine and GSE.isEmpty(rightLine:GetText()) then
            rightLine:SetText(rankText)
            rightLine:SetTextColor(0.5, 0.5, 0.5)
            rightLine:Show()
        end
    else
        GameTooltip:SetText(seqName, 1, 1, 1)
        GameTooltip:AddLine(L["GSE Sequence"], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- Keep override icons in full colour (#2123, approach from PR #2124). Off by
-- default: GSEOptions.actionBarKeepIconColour.
--
-- Bar skins grey or desaturate an icon whose slot is "not usable", and an
-- override's slot is empty, so it always reads as unusable to them (e.g.
-- HUI_ActionBars' "Custom color for Not Usable spells"). They recolour from
-- their own hooks and timers, so rather than race each one, watch the icon and
-- put it back whenever anything recolours it while GSE owns the slot. A real
-- action in the slot keeps its colour (the override yields to it).
--
-- The icon is put back to the tint of the spell it shows -- white usable,
-- blue short of power, grey not usable, as WoW's bars paint theirs
-- (GSE.ApplyOverrideUsable). With no spell to go on (an item's icon), white
-- only when the option says so, else whatever the bar drew.
local colourGuardedButtons = {}
local function guardOverrideIconColour(Button)
    if colourGuardedButtons[Button] then return end
    local button = _G[Button]
    local icon = button and (button.icon or _G[Button .. "Icon"])
    if not icon or not icon.SetVertexColor then return end
    colourGuardedButtons[Button] = true
    local restoring = false
    local function restore()
        if restoring or applyingTint then return end
        if not button:GetAttribute("gse-button") then return end
        if GSE.ActionBarSlotHasForeignAction(button) then return end
        restoring = true
        if not GSE.ApplyOverrideUsable(button) and GSEOptions.actionBarKeepIconColour == true then
            icon:SetVertexColor(1, 1, 1)
            if icon.SetDesaturated then icon:SetDesaturated(false) end
        end
        restoring = false
    end
    hooksecurefunc(icon, "SetVertexColor", restore)
    if icon.SetDesaturated then hooksecurefunc(icon, "SetDesaturated", restore) end
    restore()
end

function GSE.SetActionBarKeepIconColour(enabled)
    if not enabled then return end
    for Button in pairs(GSE.ButtonOverrides or {}) do guardOverrideIconColour(Button) end
end

-- Non-secure hook that watches attributes written by BAR_SWAP_OAC / BAR_SWAP_ONCLICK.
-- gse-eff-action > 0  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ bar has swapped (vehicle/skyriding), show the override icon.
-- gse-eff-action == 0 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ back to normal GSE state, restore the macro icon.
-- type == "click"     ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ WoW just reset the type (OnEnter / post-combat), restore icon.
local function hookButtonIconUpdates(Button)
    -- Before the once-only check: it has its own, and must still go on for a
    -- button first hooked while the option was off.
    guardOverrideIconColour(Button)
    if iconHookedButtons[Button] then return end
    iconHookedButtons[Button] = true
    hookCooldownKeep(_G[Button])
    hookCountKeep(_G[Button])
    hookLABAnswers(_G[Button])
    hookIconSpell(_G[Button])
    hookPressFlash(_G[Button])

    -- WoW hides the icon and shows the empty-slot look on hover for type="click" buttons.
    -- Restore the icon immediately after WoW's own OnEnter/OnLeave processing.
    local function restoreIconNow(self)
        if not self:GetAttribute("gse-button") then return end
        local btnName = self:GetName()
        local icon = self.icon or (btnName and _G[btnName .. "Icon"])
        if not icon then return end
        local texture = getGSEButtonIcon(self)
        if texture then
            icon:SetTexture(texture)
            icon:Show()
        end
    end
    _G[Button]:HookScript("OnEnter", function(self)
        restoreIconNow(self)
        showGSEButtonTooltip(self)
    end)
    _G[Button]:HookScript("OnLeave", restoreIconNow)

    _G[Button]:HookScript("OnAttributeChanged", function(self, name, value)
        if not self:GetAttribute("gse-button") then return end
        local btnName = self:GetName()
        local icon = self.icon or (btnName and _G[btnName .. "Icon"])
        if not icon then return end
        if name == "gse-eff-action" then
            if value and value > 0 then
                -- Bar swapped (vehicle/skyriding) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ show override icon, hide watermark.
                local texture = GetActionTexture(value)
                if texture then icon:SetTexture(texture) end
                setWatermarkVisible(btnName, false)
            else
                -- Returned to normal GSE state ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ restore spell icon, show watermark.
                scheduleIconRestore(self, icon)
                setWatermarkVisible(btnName, true)
            end
        elseif name == "type" and value == "click" then
            -- type was set back to "click" ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ WoW's own update will run this frame
            -- and clear the icon; restore it on the next frame.
            scheduleIconRestore(self, icon)
        end
    end)
end

-- Intercept every ActionButton_Update call for GSE-overridden buttons.
-- WoW fires this on ACTIONBAR_SLOT_CHANGED, page turns, bar events, etc.
-- For type="click" buttons WoW has no icon to show, so we supply it ourselves.
-- Deferred to PLAYER_ENTERING_WORLD so ActionButton_Update is guaranteed to
-- exist, and guarded in case it is absent in a given game version.
local actionButtonUpdateHooked = false
local function hookActionButtonUpdate()
    if actionButtonUpdateHooked then return end
    if not ActionButton_Update then return end
    actionButtonUpdateHooked = true
    -- ActionButton_OnEnter registers a per-frame UpdateTooltip which calls
    -- ActionButton_SetTooltip repeatedly.  For type="click" buttons this clears
    -- the tooltip each frame.  Intercept and restore the GSE spell tooltip.
    if ActionButton_SetTooltip then
        hooksecurefunc("ActionButton_SetTooltip", function(self)
            if not self or not self.GetAttribute then return end
            if not self:GetAttribute("gse-button") then return end
            showGSEButtonTooltip(self)
        end)
    end

    hooksecurefunc("ActionButton_Update", function(self)
        if not self or not self.GetAttribute then return end

        local btnName = self:GetName()
        local icon = self.icon or (btnName and _G[btnName .. "Icon"])
        if not icon then return end

        local texture
        local seq = self:GetAttribute("gse-button")
        if seq and self:GetAttribute("type") == "click" then
            texture = getGSEButtonIcon(self)
        else
            local effectiveSlot = getButtonEffectiveSlot(self)
            if effectiveSlot and GetActionInfo and GetMacroInfo then
                local actionType, macroIndex = GetActionInfo(effectiveSlot)
                if actionType == "macro" and macroIndex then
                    local stubButton = gseMacroButton(GetMacroInfo(macroIndex))
                    if stubButton then
                        texture = getGSESequenceIcon(stubButton)
                    end
                end
            end
        end

        if texture then
            icon:SetTexture(texture)
            icon:Show()
        end
    end)
end

-- EllesmereUI routes action-bar keybinds to native engine commands instead of
-- clicking the visible EABButton frame, so route those keys back through the
-- button frame when GSE owns the override.
local GSE_EABBindOwner = CreateFrame("Frame", "GSE_EABBindOwner", UIParent)

local function overrideActionButton(savedBind, force)
    if GSE.isEmpty(GSE.ButtonOverrides) then
        GSE.ButtonOverrides = {}
    end
    local Button = savedBind.Bind
    if not _G[Button] then
        return
    end
    -- The GSE Action Bar turned off this session: its buttons stay loaded
    -- (WoW cannot unload them) but run nothing.
    if _G[Button].gseActionBarButton and not GSE.ActionBarActive() then
        return
    end
    -- A spell, item or macro on a GSE Action Bar button wins, as an action in
    -- its slot does on any other bar; the sequence is back once it is taken off.
    if _G[Button].gseActionBarButton and GSE.ActionBarButtonHasAction and GSE.ActionBarButtonHasAction(_G[Button]) then
        return
    end
    -- The bind holds the sequence's id, which names its secure button. Nothing
    -- to run means nothing to override.
    local Sequence = GSE.StoredSequenceId(savedBind.Sequence)
    if not Sequence then return end
    local SequenceLabel = GSE.SequenceName(savedBind.Sequence) or Sequence
    local state =
        savedBind.State and savedBind.State or string.sub(Button, 1, 3) == "BT4" and "0" or
        string.sub(Button, 1, 4) == "CPB_" and "" or
        string.sub(Button, 1, 4) == "NDui_" and "2" or
        "1"
    _G[Button]:SetAttribute("gse-button", Sequence)
    if string.sub(Button, 1, 9) == "EABButton" and not InCombatLockdown() then
        local cmd = _G[Button].commandName
        if cmd then
            local k1, k2 = GetBindingKey(cmd)
            if k1 then SetOverrideBindingClick(GSE_EABBindOwner, true, k1, Button) end
            if k2 then SetOverrideBindingClick(GSE_EABBindOwner, true, k2, Button) end
        else
            --@debug@
            GSE.PrintDebugMessage(
                "EllesmereUI button " .. Button .. " has no commandName; keybind override not applied",
                "EVENTS"
            )
            --@end-debug@
        end
    end
    -- A Dominos action button may be named DominosActionButtonN OR, for action
    -- slots 25-72 / 133-168 on retail, MultiBar*ActionButtonN (note the "Action"
    -- infix -- these are Dominos-created frames, not the Blizzard MultiBar*ButtonN
    -- frames Dominos hides). Detect by the Dominos-only SetShowGridInsecure method
    -- rather than a name prefix, so every Dominos button takes this path instead
    -- of falling through to the third-party slot/page logic, which is invalid for
    -- Dominos buttons (the action slot is a flat secure attribute, not paged).
    local isDominosButton = _G[Button].SetShowGridInsecure ~= nil
    if _G[Button].gseActionBarButton then
        -- The GSE Action Bar: no action slot, so no bar swap to watch for --
        -- the button only ever clicks its sequence.
        if not InCombatLockdown() then
            secureArmGSEButton(_G[Button], Sequence)
        end
        hookButtonIconUpdates(Button)
        addGSEWatermark(Button)
        scheduleIconRestore(_G[Button], _G[Button].icon or _G[Button .. "Icon"])
        GSE.ButtonOverrides[Button] = Sequence
        repaintGSEOverrideButton(_G[Button])
        repaintGSEOverrideButton(_G[Button], true)
    elseif isDominosButton or string.sub(Button, 1, 7) == "Dominos" or string.sub(Button, 1, 11) == "ButtonForge" then
        -- Dominos and ButtonForge use ActionBarButtonTemplate / SecureActionButtonTemplate;
        -- action slot is a secure attribute only, not a page/slot hierarchy.
        -- Use simplified WrapScript (no GetActionInfo lookup).
        if not InCombatLockdown() then
            if (not GSE.ButtonOverrides[Button] or force) then
                SHBT:WrapScript(_G[Button], "OnClick", BAR_SWAP_ONCLICK)
                _G[Button]:HookScript(
                    "OnEnter",
                    function(self)
                        if not InCombatLockdown() and self:GetAttribute("gse-button")
                            and not GSE.ActionBarSlotHasForeignAction(self) then
                            self:SetAttribute("type", "click")
                        end
                    end
                )
                SHBT:WrapScript(_G[Button], "OnAttributeChanged", BAR_SWAP_OAC)
            end
            -- Dominos routes a slot's keybind to a hidden hotkey proxy
            -- ($parentHotkey) that casts the parent's *action* directly via
            -- useparent-action -- it ignores the parent's type/clickbutton, so the
            -- GSE override (which lives on the visible button) is bypassed and the
            -- key fires the empty slot. Mouse clicks hit the visible button and
            -- work; the key does not. Re-point the bound key(s) at the visible
            -- button with a PRIORITY override binding, which supersedes Dominos'
            -- non-priority proxy binding regardless of apply order. Cleared and
            -- re-applied on every LoadOverrides via GSE_EABBindOwner. ButtonForge
            -- is excluded -- it is not affected and has no such proxy.
            if isDominosButton then
                local cmd = _G[Button]:GetAttribute("commandName")
                if cmd then
                    local k1, k2 = GetBindingKey(cmd)
                    if k1 then SetOverrideBindingClick(GSE_EABBindOwner, true, k1, Button) end
                    if k2 then SetOverrideBindingClick(GSE_EABBindOwner, true, k2, Button) end
                end
            end
            -- Arm type/clickbutton + the secure gate from inside the secure
            -- environment so GSE seeds no taint (issue #1931).
            secureArmGSEButton(_G[Button], Sequence)
        end
        hookButtonIconUpdates(Button)
        addGSEWatermark(Button)
        scheduleIconRestore(_G[Button], _G[Button].icon or _G[Button .. "Icon"])
        GSE.ButtonOverrides[Button] = Sequence
        repaintGSEOverrideButton(_G[Button])
        repaintGSEOverrideButton(_G[Button], true)
    elseif _G[Button].SetState then
        if _G[Button] and _G[Button].SetState then
            -- A fresh custom-state config (LAB stores it per state).
            local function customState()
                return {
                    func = function(self)
                        if not InCombatLockdown() then
                            self:SetAttribute("type", "click")
                            self:SetAttribute("clickbutton", _G[self:GetAttribute("gse-button")])
                        end
                    end,
                    tooltip = "GSE: " .. SequenceLabel,
                    texture = getGSESequenceIcon(Sequence) or Statics.Icons.GSE_Logo_Dark,
                    type = "click",
                    clickbutton = _G[Sequence]
                }
            end
            -- LAB bars page the button per stance/form (e.g. Druid Cat = state 7,
            -- Prowl = state 8, Bear = another) and re-apply that state's action on
            -- every shift, wiping a single-state override -- which is why the ABO
            -- died in Prowl on Bartender. Register the GSE override on EVERY state
            -- the button has so it stays active across all of the bar's paging. A
            -- user-pinned State still targets just that one state.
            --
            -- EXCEPT temporary bar-swap pages (skyriding, vehicle/possess, temp
            -- shapeshift, override). WoW parks the swapped bar's real actions in
            -- those pages' slots and the bar addon registers LAB states for them
            -- (ElvUI: "[overridebar] 14; [vehicleui][possessbar] 12; ..."), so
            -- overriding those states hijacked the swapped bar -- e.g. the MoP
            -- Sunsong Ranch farm tools, where HasVehicleActionBar() is true and
            -- ElvUI pages bar 1 to the vehicle page, but the GSE click override
            -- registered on that state kept firing the sequence instead. Detect
            -- swap states by the action SLOT they page to (portable across LAB
            -- addons' state numbering), plus custom states keyed by a swap page
            -- number (ElvUI's leave-vehicle button on button 12).
            local swapPages = {
                [11] = true, -- [bonusbar:5] skyriding page; no API accessor
                [(C_ActionBar and C_ActionBar.GetVehicleBarIndex or GetVehicleBarIndex or function() return 12 end)()] = true,
                [(C_ActionBar and C_ActionBar.GetTempShapeshiftBarIndex or GetTempShapeshiftBarIndex or function() return 13 end)()] = true,
                [(C_ActionBar and C_ActionBar.GetOverrideBarIndex or GetOverrideBarIndex or function() return 14 end)()] = true
            }
            local stateTypes = _G[Button].state_types
            local stateActions = _G[Button].state_actions
            local function isSwapState(st)
                local kind = type(stateTypes) == "table" and stateTypes[st]
                if kind == "action" then
                    local slot = type(stateActions) == "table" and stateActions[st]
                    if type(slot) == "number" and slot > 0 then
                        return swapPages[math.floor((slot - 1) / 12) + 1] == true
                    end
                elseif kind == "custom" then
                    -- A custom state keyed by a swap page number is the bar
                    -- addon's own (e.g. ElvUI's leave-vehicle button on the
                    -- vehicle page) -- never take it over. GSE's own custom
                    -- states live on non-swap keys and are re-applied normally.
                    return swapPages[tonumber(st)] == true
                end
                return false
            end
            -- Register a GSE custom state and mark it from INSIDE the secure
            -- environment (mark first, so it is visible when SetState triggers
            -- the type change). VEHICLE_OAC_LAB gates its type="click" restore
            -- on this mark so it never captures the bar addon's own custom
            -- states, and gse-lab-state-* stays untainted (see issue #1931).
            -- Remember what each state held before GSE took it over, so clearing
            -- the override puts every one back (LoadOverrides). Only the first
            -- take-over is recorded: a state already carrying GSE's mark holds
            -- GSE's own custom state, not the bar's.
            local function rememberState(st)
                local btn = _G[Button]
                local key = tostring(st)
                btn.gseLabOriginal = btn.gseLabOriginal or {}
                if btn.gseLabOriginal[key] ~= nil then return end
                if btn:GetAttribute("gse-lab-state-" .. key) then return end
                local kind = type(stateTypes) == "table" and stateTypes[key] or nil
                local action = type(stateActions) == "table" and stateActions[key] or nil
                btn.gseLabOriginal[key] = kind and { kind = kind, action = action } or false
            end
            local function applyGSEState(st)
                rememberState(st)
                SHBT:SetFrameRef("gseArmButton", _G[Button])
                SHBT:Execute(
                    "local b = self:GetFrameRef('gseArmButton') " ..
                        "if b then b:SetAttribute('gse-lab-state-" .. tostring(st) .. "', true) end"
                )
                _G[Button]:SetState(st, "custom", customState())
            end
            if savedBind.State then
                applyGSEState(state)
            elseif type(stateTypes) == "table" and next(stateTypes) then
                for st in pairs(stateTypes) do
                    if not isSwapState(st) then
                        applyGSEState(st)
                    end
                end
            else
                applyGSEState(state)
            end
            -- Kick the live type only when the button is not currently sitting
            -- on a swap state (LoadOverrides can fire while on the farm / in a
            -- vehicle); LAB re-asserts type from labtype-<state> on the next
            -- state change either way. clickbutton is not state-managed by LAB
            -- and is ignored while type="action", so it is always safe to set.
            local currentState = _G[Button]:GetAttribute("state")
            if currentState == nil or not isSwapState(tostring(currentState)) then
                _G[Button]:SetAttribute("type", "click")
            end
            _G[Button]:SetAttribute("clickbutton", _G[Sequence])
            -- Install a secure OnAttributeChanged WrapScript (once per button) that
            -- intercepts LAB's type="custom" transition and immediately restores
            -- type="click".  This fires inside the secure execution environment so
            -- it works even during combat lockdown, allowing the GSE button to
            -- function immediately after dismounting/leaving a vehicle in combat.
            if not labVehicleDriverButtons[Button] then
                labVehicleDriverButtons[Button] = true
                SHBT:WrapScript(_G[Button], "OnAttributeChanged", VEHICLE_OAC_LAB)
            end
        end
        hookButtonIconUpdates(Button)
        addGSEWatermark(Button)
        scheduleIconRestore(_G[Button], _G[Button].icon or _G[Button .. "Icon"])
        GSE.ButtonOverrides[Button] = Sequence
        repaintGSEOverrideButton(_G[Button])
        repaintGSEOverrideButton(_G[Button], true)
    else
        if not InCombatLockdown() then
            if (not GSE.ButtonOverrides[Button] or force) then
                -- Detect Blizzard native action buttons - WrapScript is restricted on these
                -- in recent patches. Use SetAttribute directly for OnClick type control,
                -- and HookScript (non-secure) for OnEnter tooltip/type correction.
                local isBlizzardButton =
                    string.sub(Button, 1, 12) == "ActionButton" or
                    string.sub(Button, 1, 24) == "MultiBarBottomLeftButton" or
                    string.sub(Button, 1, 25) == "MultiBarBottomRightButton" or
                    string.sub(Button, 1, 15) == "MultiBar5Button" or
                    string.sub(Button, 1, 15) == "MultiBar6Button" or
                    string.sub(Button, 1, 15) == "MultiBar7Button" or
                    string.sub(Button, 1, 19) == "MultiBarRightButton" or
                    string.sub(Button, 1, 18) == "MultiBarLeftButton" or
                    -- WoW Forever's Gamepad action bars are Blizzard frames too.
                    string.sub(Button, 1, 7) == "Gamepad"

                if isBlizzardButton then
                    -- For Blizzard bars: WrapScript on OnClick is still allowed,
                    -- but OnEnter WrapScript is blocked. Use HookScript for OnEnter.
                    SHBT:WrapScript(_G[Button], "OnClick", BAR_SWAP_ONCLICK)
                    _G[Button]:HookScript(
                        "OnEnter",
                        function(self)
                            if not InCombatLockdown() and self:GetAttribute("gse-button")
                                and not GSE.ActionBarSlotHasForeignAction(self) then
                                self:SetAttribute("type", "click")
                            end
                        end
                    )
                    SHBT:WrapScript(_G[Button], "OnAttributeChanged", BAR_SWAP_OAC)
                else
                    -- For other (third-party) buttons: full WrapScript on both
                    SHBT:WrapScript(_G[Button], "OnClick", BAR_SWAP_ONCLICK)
                    SHBT:WrapScript(
                        _G[Button],
                        "OnEnter",
                        "",
                        [[
    if self:GetAttribute('gse-secure') then
        local slot = self:GetID()
        local page = slot > 0 and self:GetEffectiveAttribute("actionpage") or nil
        local effectiveAction = (slot == 0 or not page) and self:GetEffectiveAttribute("action")
                                or (page and (slot + page * 12 - 12)) or nil
        local at = effectiveAction and GetActionInfo(effectiveAction)
        -- Only re-assert the override on hover when the slot is empty or a macro;
        -- if a real action sits here, leave type="action" so it stays usable.
        if at == nil or at == "macro" then
            self:SetAttribute('type', 'click')
        end
    end
]]
                    )
                    SHBT:WrapScript(_G[Button], "OnAttributeChanged", BAR_SWAP_OAC)
                end
            end
            -- Arm type/clickbutton + the secure gate from inside the secure
            -- environment so GSE seeds no taint on the Blizzard button -- this is
            -- the taint that Bartender4 State Config surfaced in issue #1931.
            secureArmGSEButton(_G[Button], Sequence)
        end
        hookButtonIconUpdates(Button)
        addGSEWatermark(Button)
        scheduleIconRestore(_G[Button], _G[Button].icon or _G[Button .. "Icon"])
        GSE.ButtonOverrides[Button] = Sequence
        repaintGSEOverrideButton(_G[Button])
        repaintGSEOverrideButton(_G[Button], true)
    end
    -- Force the slot to stay visible on bars that hide empty buttons (Dominos);
    -- a GSE override leaves the action slot empty, so it would otherwise vanish.
    setOverrideButtonForcedShown(_G[Button], true)
    -- Post-load repaint after GSE action-bar override mapping is populated.
    if GSE.UpdateIcon and _G[Sequence] then
        C_Timer.After(0, function()
            if _G[Sequence] then
                GSE.UpdateIcon(_G[Sequence], false)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Yield an override to a real action the player drops into its slot.
--
-- The secure BAR_SWAP_ONCLICK / BAR_SWAP_OAC snippets already switch a button
-- between the GSE override (type="click") and the underlying action
-- (type="action"), but they only run on a click or a bar-page/state swap. When
-- the player simply drops a spell into the slot neither fires, so the button is
-- left behind the stale override -- GSE icon + watermark bleeding through, and
-- the action looking disabled -- until the next click. ACTIONBAR_SLOT_CHANGED
-- (registered below) runs the same evaluation immediately. type is a protected
-- attribute, so this only acts out of combat; the in-combat case is covered by
-- LoadOverrides() on PLAYER_REGEN_ENABLED. Attributes are written only when they
-- actually change, so a no-op slot event does not re-trigger a repaint.
-- ---------------------------------------------------------------------------
local function reevaluateOverrideButtonState(buttonName, sequence)
    local btn = _G[buttonName]
    if not btn or not btn.GetAttribute or not btn:GetAttribute("gse-button") then return end
    local foreign = GSE.ActionBarSlotHasForeignAction(btn)
    local desiredEff = foreign and (getButtonEffectiveSlot(btn) or 0) or 0
    local isLAB = btn.SetState ~= nil
    if not isLAB then
        local desiredType = foreign and "action" or "click"
        if btn:GetAttribute("type") ~= desiredType then
            -- Route through the secure handler so this slot-yield re-arm does not
            -- re-taint the button (issue #1931). Caller is out of combat.
            if foreign then
                secureYieldGSEButton(btn)
            else
                secureArmGSEButton(btn, sequence)
            end
        end
    end
    -- gse-eff-action drives the existing OnAttributeChanged icon hook: > 0 shows the
    -- real action icon and hides the GSE watermark; 0 restores the sequence icon.
    if btn:GetAttribute("gse-eff-action") ~= desiredEff then
        btn:SetAttribute("gse-eff-action", desiredEff)
    end
end

local function reevaluateAllOverrideButtons()
    if GSE.isEmpty(GSE.ButtonOverrides) then return end
    if InCombatLockdown() then return end
    for buttonName, sequence in pairs(GSE.ButtonOverrides) do
        reevaluateOverrideButtonState(buttonName, sequence)
    end
end

function GSE:ACTIONBAR_SLOT_CHANGED()
    reevaluateAllOverrideButtons()
end

-- After a GSE override is removed from a button, force WoW to repaint the
-- button's REAL action-slot icon. Without this, removing an override cleared the
-- watermark (removeGSEWatermark) but the GSE-painted icon lingered until the next
-- ActionButton update -- e.g. the user moused over the button (OnEnter triggers
-- Blizzard's update). Deferred a frame so any type/attribute resets settle first;
-- bails if the button was re-armed in the same LoadOverrides pass.
local function refreshClearedOverrideIcon(button)
    if not button or not button.GetAttribute then return end
    -- What the override drew for its spell comes off with it: the swipe, the
    -- glows, the red key. Before the bar's own repaint, for every bar.
    overrideSpell[button] = nil
    applyOverrideGlow(button)
    applyOverrideAssist(button)
    if button.cooldown and button.cooldown.Clear then button.cooldown:Clear() end
    if button.Count and button.Count.SetText then button.Count:SetText("") end
    if button.HotKey and _G.ActionButton_UpdateRangeIndicator then pcall(_G.ActionButton_UpdateRangeIndicator, button, false, false) end
    -- A GSE Action Bar button has no slot to repaint from: it goes back to
    -- the action it holds, or to empty.
    if button.gseActionBarButton then
        if GSE.ActionBarButtonCleared then GSE.ActionBarButtonCleared(button) end
        return
    end
    C_Timer.After(0, function()
        if not button or not button.GetAttribute then return end
        if button:GetAttribute("gse-button") then return end -- re-armed: keep its GSE icon
        -- Let WoW repaint from the real slot. button:Update() (retail ActionButton
        -- mixin / LAB) or the global ActionButton_Update (Classic/MoP). Our
        -- ActionButton_Update hook is a no-op here because gse-button is nil.
        if type(button.Update) == "function" and pcall(button.Update, button) then return end
        if ActionButton_Update and pcall(ActionButton_Update, button) then return end
        -- Fallback: paint straight from the slot, or clear the icon if it's empty.
        local btnName = button.GetName and button:GetName()
        local icon = button.icon or (btnName and _G[btnName .. "Icon"])
        if not icon then return end
        local slot = getButtonEffectiveSlot(button)
        local tex = slot and HasAction and HasAction(slot) and GetActionTexture and GetActionTexture(slot)
        if tex then
            icon:SetTexture(tex)
            icon:Show()
        else
            icon:SetTexture(nil)
        end
    end)
end

-- Take GSE's override off one button: its secure arming, wrapped scripts and
-- watermark.  Out of combat only (the callers check).
local function revertOverrideButton(k)
    -- Drop the forced-shown bit so a no-longer-overridden Dominos slot can
    -- hide again; it is re-applied below for slots that remain overridden.
    setOverrideButtonForcedShown(k, false)
    -- revert all buttons
    if _G[k] and _G[k].SetState then
        local btn = _G[k]
        local original = btn.gseLabOriginal
        btn.gseLabOriginal = nil
        -- Every state GSE took over gets back what the bar had there --
        -- an action on its page, the bar's own custom button
        -- (Bartender4's vehicle exit), or nothing. Restoring only one
        -- state left the override live on every other page, form and
        -- stance.
        local restore = {}
        if original and next(original) then
            for st, was in pairs(original) do restore[#restore + 1] = { st, was } end
        else
            local state = "1"
            if string.sub(k, 1, 3) == "BT4" then
                state = "0"
            elseif string.sub(k, 1, 4) == "CPB_" then
                state = ""
            end
            restore[1] = { state, { kind = "action", action = tonumber(string.match(k, "%d+$")) } }
        end
        -- Un-GSE the button FIRST. VEHICLE_OAC_LAB turns any custom
        -- type on a marked GSE button into a click on the sequence, so
        -- restoring a custom state (the vehicle exit) while still
        -- marked would hand it straight back to GSE. The marks are
        -- cleared where they were set: in the secure environment (#1931).
        btn:SetAttribute("gse-button", nil)
        SHBT:SetFrameRef("gseArmButton", btn)
        local unmark = { "local b = self:GetFrameRef('gseArmButton') if not b then return end" }
        for _, r in ipairs(restore) do
            unmark[#unmark + 1] = "b:SetAttribute('gse-lab-state-" .. tostring(r[1]) .. "', nil)"
        end
        SHBT:Execute(table.concat(unmark, " "))
        for _, r in ipairs(restore) do
            if r[2] then
                btn:SetState(r[1], r[2].kind, r[2].action)
            else
                btn:SetState(r[1], "empty")
            end
        end
        removeGSEWatermark(k)
    else
        _G[k]:SetAttribute("gse-button", nil)
        -- Clear the secure gate + reset type from inside the secure
        -- environment (issue #1931); gse-button is a non-secure string so
        -- clearing it insecurely is harmless.
        secureDisarmGSEButton(_G[k])
        -- The GSE Action Bar's buttons were never wrapped; the wrap
        -- they do have is the bar's own (Actions.lua).
        if not _G[k].gseActionBarButton then
            SecureHandlerUnwrapScript(_G[k], "OnClick")
            SecureHandlerUnwrapScript(_G[k], "OnEnter")
            SecureHandlerUnwrapScript(_G[k], "OnAttributeChanged")
        end
        removeGSEWatermark(k)
    end
end

local function LoadOverrides(force)
    if GSE.isEmpty(GSE.ButtonOverrides) then
        GSE.ButtonOverrides = {}
    end
    -- This character's spec-level overrides into the shared profiles, once.
    GSE.MigrateToProfiles()
    if GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        GSE_C["ActionBarBinds"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"]) then
        GSE_C["ActionBarBinds"]["LoadOuts"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()]) then
        GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()] = {}
    end
    if not InCombatLockdown() then
        ClearOverrideBindings(GSE_EABBindOwner)
        -- Remember which buttons are currently overridden so we can repaint the
        -- real icon on any that end up cleared (not re-armed) by this pass.
        local clearedCandidates = {}
        for k in pairs(GSE.ButtonOverrides) do
            clearedCandidates[k] = true
        end
        -- revert all buttons
        for k, _ in pairs(GSE.ButtonOverrides) do
            revertOverrideButton(k)
        end
        GSE.ButtonOverrides = {}

        -- The spec's overrides: the shared profile's, or this character's own.
        for _, v in pairs(GSE.SpecOverrides(GetSpec(), false) or {}) do
            overrideActionButton(v, force)
        end
        do
            local selected = GSE.GetBindingLoadoutKey and GSE.GetBindingLoadoutKey()

            if
                selected and GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()] and
                    GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()][selected]
             then
                --@debug@
                GSE.PrintDebugMessage("changing from " .. tostring(GSE.GetSelectedLoadoutConfigID()), "EVENTS")
                --@end-debug@
                for _, v in pairs(GSE_C["ActionBarBinds"]["LoadOuts"][GetSpec()][selected]) do
                    overrideActionButton(v, force)
                end
            end
        end

        -- Repaint the real action icon on any button whose override was just
        -- removed and NOT re-armed above. removeGSEWatermark() already cleared the
        -- watermark; without this the GSE-painted icon stuck around until the next
        -- ActionButton update (the "have to mouse over it to clear" bug).
        for clearedName in pairs(clearedCandidates) do
            local b = _G[clearedName]
            if b and b.GetAttribute and not b:GetAttribute("gse-button") then
                refreshClearedOverrideIcon(b)
            end
        end
        -- A button just given a sequence starts from the keys it has now.
        if GSE.CheckOverrideKeys then GSE.CheckOverrideKeys() end
    end
end

-- Every key LoadKeyBindings bound on its last run. The rebuild is otherwise
-- add-only: it re-binds what is in GSE_C now and never releases what it bound
-- before, so a key that was deleted, rebound, or belonged to the loadout you
-- just switched away from keeps firing its old sequence for the rest of the
-- session. Session scope only -- GSE keybinds are rebuilt from GSE_C on every
-- login, so nothing needs to survive one.
local boundKeys = {}

-- Which spec + saved talent loadout the last rebuild bound for, and whether a
-- re-check is already scheduled. Blizzard updates BOTH GetSpecialization and
-- GetLastSelectedSavedConfigID only AFTER the events GSE rebuilds on, so a
-- rebuild triggered by a spec change or a loadout swap still reads the one
-- being left and re-binds its keys over the one moved to -- which is why those
-- keys kept firing until a reload. The rebuild releases before it adds, so
-- running it again once the API has caught up is all that is needed.
local lastBindingContext, bindingRecheckPending
local LoadKeyBindings, scheduleBindingRecheck
local BINDING_RECHECK_INTERVAL, BINDING_RECHECK_ATTEMPTS = 0.5, 20

local function currentBindingContext()
    -- GetSpec() alone cannot separate the two builds on a dual-spec client: it
    -- is always "1" where there is one specialisation per class, so a Primary
    -- <-> Secondary switch produced an identical context and the rebuild
    -- re-bound what was already bound. GetBindingLoadoutKey carries the spec
    -- group there and the saved loadout id on retail.
    return GetSpec() .. "\001" .. (GSE.GetBindingLoadoutKey and GSE.GetBindingLoadoutKey() or "")
end

local keybindingframe
if GSE.GameMode == 5 then
    keybindingframe = CreateFrame("Frame", "GSEKeyBinds", UIParent)
    keybindingframe:Hide()
end

-- Older builds stored mouse buttons 4/5 (and the middle button) using the
-- frame-script names ("Button4"/"Button5"/"MiddleButton") rather than valid WoW
-- binding names ("BUTTON4"/"BUTTON5"/"BUTTON3"), so SetBindingClick silently
-- failed and the bind did nothing in game. Normalise any stored key to the
-- binding name so legacy saves keep working without needing to be re-bound.
local function normalizeBindKey(key)
    if type(key) ~= "string" then
        return key
    end
    return (key:gsub("MiddleButton", "BUTTON3"):gsub("Button4", "BUTTON4"):gsub("Button5", "BUTTON5"))
end
-- The GSE Action Bar binds the same stored keys to its buttons.
GSE.NormalizeBindKey = normalizeBindKey

function LoadKeyBindings(payload)
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE.isEmpty(GSE_C["KeyBindings"]) then
        GSE_C["KeyBindings"] = {}
    end
    -- This character's spec-level binds into the shared profiles, once.
    GSE.MigrateToProfiles()

    -- What this rebuild is about to bind for. See scheduleBindingRecheck.
    lastBindingContext = currentBindingContext()

    -- Release everything the previous rebuild bound, then let the loops below
    -- re-bind exactly what still exists. Without this the rebuild only ever
    -- adds: deleting a keybind, rebinding it to another key, or switching to a
    -- talent loadout that does not define it all leave the old key bound and
    -- still firing the old sequence. On MoP the same keys also sit in the
    -- override layer, which has no per-key remove call, so drop the whole
    -- layer for our owner frame as well.
    if not InCombatLockdown() then
        for k in pairs(boundKeys) do
            SetBinding(k)
        end
        wipe(boundKeys)
        if GSE.GameMode == 5 and keybindingframe then
            ClearOverrideBindings(keybindingframe)
        end
    end
    -- Keybinding switched off (WoW Forever and Retail 12.1.7, or the GSE Action
    -- Bar carries the keys): released above, bind nothing.
    if not GSE.KeybindingsEnabled() then return end

    -- A keybind holds the sequence's id; it clicks that sequence's button. The
    -- spec's binds are the shared profile's, or this character's own.
    for k, v in pairs(GSE.SpecKeyBinds(GetSpec(), false) or {}) do
        local button = k ~= "LoadOuts" and GSE.StoredSequenceId(v)
        if button and not InCombatLockdown() then
            local target = GSE.GetKeybindClickTarget(button)
            k = normalizeBindKey(k)
            SetBindingClick(k, target, "LeftButton")
            boundKeys[k] = true
            if GSE.GameMode == 5 then
                SetOverrideBindingClick(keybindingframe, false, k, target)
            end
        -- print("Bound", k, v)
        end
    end

    if payload and not InCombatLockdown() then
        do
            local selected = GSE.GetBindingLoadoutKey and GSE.GetBindingLoadoutKey()
            local loadouts = GSE.SpecLoadoutKeyBinds(GetSpec(), false)
            if selected and loadouts and loadouts[selected] then
                --@debug@
                GSE.PrintDebugMessage(
                    "changing from " .. tostring(payload) .. " " .. tostring(GSE.GetSelectedLoadoutConfigID()),
                    "EVENTS"
                )
                --@end-debug@
                for k, v in pairs(loadouts[selected]) do
                    k = normalizeBindKey(k)
                    SetBinding(k)
                    local target = GSE.GetKeybindClickTarget(GSE.StoredSequenceId(v) or v)
                    SetBindingClick(k, target, "LeftButton")
                    boundKeys[k] = true
                    if GSE.GameMode == 5 then
                        SetOverrideBindingClick(keybindingframe, false, k, target)
                    end
                end
            end
        end
        -- The spec and loadout read above may still name the ones being left,
        -- and can stay stale for seconds. See scheduleBindingRecheck.
        scheduleBindingRecheck(BINDING_RECHECK_ATTEMPTS)

        -- The keybind tree lists the spec's talent loadouts, so one created or
        -- deleted while an editor is open would otherwise not show until the
        -- editor was reopened. Only costs anything when an editor is actually
        -- open, which is the rare case.
        if GSE.GUI and GSE.GUI.editors then
            for _, editor in ipairs(GSE.GUI.editors) do
                if editor.ManageTree then editor.ManageTree() end
            end
        end

        -- A freshly (re)loaded override whose slot already holds a real action
        -- must start yielded, not behind the override. Defer one frame so the
        -- action-bar slots are populated before we read them.
        C_Timer.After(0, reevaluateAllOverrideButtons)
    end
end

function GSE.ReloadOverrides(force)
    LoadOverrides(force)
    GSE:SendMessage(Statics.Messages.ACTIONBAR_OVERRIDES_UPDATED)
end

--- Put sequence id on action-bar button buttonName. layer "loadout" keeps it
--- to the active talent loadout, "spec" makes it the spec's for every loadout
--- (GSE.SetOverrideData); nil changes the button where its override already
--- comes from, so the change is the one that shows. Returns the layer written.
function GSE.CreateActionBarOverride(buttonName, sequenceId, layer)
    if InCombatLockdown() then return end
    layer = layer or (GSE.OverrideLayerFor(buttonName) == "loadout" and "loadout" or "spec")
    local written = GSE.SetOverrideData(buttonName, sequenceId, layer)
    GSE.ReloadOverrides()
    return written
end

--- Clear the override the button shows now -- the active talent loadout's or
--- the spec's -- and leave every other layer as it was.
function GSE.RemoveActionBarOverride(buttonName)
    if InCombatLockdown() then return end
    GSE.ClearOverrideData(buttonName)
    GSE.ReloadOverrides()
end

--- Move the sequence fromName shows onto toName, as dragging it there does.
--- A sequence toName showed comes back to fromName, so the two swap; else
--- fromName is left empty. Each button's change goes where its override
--- lives (the active loadout's, or the spec's). Returns "loadout" when either
--- did.
function GSE.MoveActionBarOverride(fromName, toName)
    if InCombatLockdown() or fromName == toName then return end
    local from, to = _G[fromName], _G[toName]
    local fromSeq = from and from:GetAttribute("gse-button")
    if not fromSeq then return end
    local toSeq = to and to:GetAttribute("gse-button")
    local function layerFor(name) return GSE.OverrideLayerFor(name) == "loadout" and "loadout" or "spec" end
    local written = GSE.SetOverrideData(toName, fromSeq, layerFor(toName))
    if toSeq then
        if GSE.SetOverrideData(fromName, toSeq, layerFor(fromName)) == "loadout" then written = "loadout" end
    else
        GSE.ClearOverrideData(fromName)
    end
    GSE.ReloadOverrides()
    return written
end

--- Take the override off a button now and leave what is saved alone: the
--- Button Bindings page when a row is removed, before Save writes it.  The
--- next GSE.ReloadOverrides puts back whatever is still saved.  True when a
--- live override came off.
function GSE.ReleaseActionBarOverride(buttonName)
    if InCombatLockdown() or not (GSE.ButtonOverrides and GSE.ButtonOverrides[buttonName] and _G[buttonName]) then
        return false
    end
    revertOverrideButton(buttonName)
    GSE.ButtonOverrides[buttonName] = nil
    refreshClearedOverrideIcon(_G[buttonName])
    return true
end

--- The name of the active talent loadout, for saying where a change went.
function GSE.ActiveBindingLoadoutName()
    local loadout = GSE.ActiveBindingLoadout()
    if not loadout then return nil end
    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(tonumber(loadout))
    return (info and info.name) or loadout
end

-- ---------------------------------------------------------------------------
-- Drag a sequence onto an action button.
--
-- Long ago a sequence came with a macro holding /click <button>, and dragging
-- that macro to a bar was how a sequence got onto a button. WoW no longer lets
-- that macro work. This gives the same gesture back without one: the editor
-- shows the sequence's icon, and dragging it draws GSE's own copy of the icon
-- under the mouse. Nothing is put on WoW's cursor and nothing goes into a
-- slot. On release, the action button under the mouse gets an action-bar
-- override, exactly as the right-click picker would set.
--
-- The button is found by testing which one the mouse is over, not by name and
-- not by mouse focus (the drag keeps the mouse captured by the editor icon), so
-- any bar works -- Blizzard, Bartender, ElvUI, Dominos, ConsolePort, Forever's
-- gamepad bars -- as long as its buttons are named, which overrides need.

-- The icon of the sequence's first compiled step, as the override button would
-- show it, or nil.
function GSE.GetSequenceStartIcon(sequenceId)
    if not sequenceId or not (GSE.SequencesExec and GSE.SequencesExec[sequenceId]) then return nil end
    local firstStep = {
        GetAttribute = function() return 1 end,
        GetName = function() return sequenceId end,
    }
    local info = GSE.GetCurrentButtonIconInfo and GSE.GetCurrentButtonIconInfo(firstStep, false)
    local icon = info and info.iconID
    if icon and not isGSEFallbackTexture(icon) then return icon end
    return getGSESequenceIcon(sequenceId)
end

local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

-- A frame an override can go on: a named button that holds an action slot.
local function isOverrideTargetUnsafe(frame)
    if not frame or not frame.IsObjectType or not frame:IsObjectType("Button") then return false end
    -- Some UI code reuses method names for other things: Blizzard's damage
    -- meter rows define GetName() to return their name FontString. Only a
    -- real string name counts.
    local name = frame.GetName and frame:GetName()
    if type(name) ~= "string" or name == "" then return false end
    if GSE.SequencesExec and GSE.SequencesExec[name] then return false end -- a GSE sequence button
    if string.sub(name, 1, 4) == "CPB_" then return true end -- ConsolePort: controller-mapped, no slot
    if frame.gseActionBarButton then return true end -- the GSE Action Bar: no slot either
    if frame.action ~= nil or frame._state_action ~= nil or frame.UpdateAction then return true end
    return frame.GetAttribute and frame:GetAttribute("action") ~= nil or false
end

-- Every frame in the UI passes through this when a drag starts, including ones
-- built in ways nobody planned for; one that errors is simply not a target.
local function isOverrideTarget(frame)
    local ok, result = pcall(isOverrideTargetUnsafe, frame)
    return ok and result == true
end

-- Every shown action button under frame. Hidden branches are skipped (a
-- hidden button is no drop target): walking every frame in the game with
-- EnumerateFrames froze a Retail UI with many addons for seconds.
-- Each frame is visited under its own pcall: one frame that errors (a
-- secret value in Midnight, an addon's odd frame) is skipped with whatever it
-- holds. Under a single pcall around the whole walk it ended the walk, and
-- every frame after it -- Bartender4's bars, created late -- was never a
-- drop target, so a drop on them did nothing.
local function collectOverrideTargets(frame, out)
    if isOverrideTarget(frame) then out[#out + 1] = frame end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for i = 1, #children do
        local child = children[i]
        pcall(function()
            if not (child.IsForbidden and child:IsForbidden()) and child:IsShown() then
                collectOverrideTargets(child, out)
            end
        end)
    end
end

local drag -- the drag in progress: { sequenceId, candidates, target, fromButton }

local function overrideTargetUnderMouse()
    local best, bestRank, bestLevel
    for _, frame in ipairs(drag.candidates) do
        if frame:IsVisible() and frame:IsMouseOver() then
            local rank = STRATA_RANK[frame:GetFrameStrata()] or 0
            local level = frame:GetFrameLevel() or 0
            if not best or rank > bestRank or (rank == bestRank and level > bestLevel) then
                best, bestRank, bestLevel = frame, rank, level
            end
        end
    end
    return best
end

local dragIcon, dragHighlight
local function ensureDragFrames()
    if dragIcon then return end
    dragIcon = CreateFrame("Frame", nil, UIParent)
    dragIcon:SetSize(36, 36)
    dragIcon:SetFrameStrata("TOOLTIP")
    dragIcon:EnableMouse(false)
    dragIcon.texture = dragIcon:CreateTexture(nil, "ARTWORK")
    dragIcon.texture:SetAllPoints()
    dragIcon:Hide()

    dragHighlight = CreateFrame("Frame", nil, UIParent)
    dragHighlight:SetFrameStrata("TOOLTIP")
    dragHighlight:EnableMouse(false)
    dragHighlight.texture = dragHighlight:CreateTexture(nil, "OVERLAY")
    dragHighlight.texture:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    dragHighlight.texture:SetBlendMode("ADD")
    dragHighlight.texture:SetAllPoints()
    dragHighlight:Hide()

    dragIcon:SetScript("OnUpdate", function(self)
        if not drag then return end
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        local target = overrideTargetUnderMouse()
        drag.target = target
        if target then
            dragHighlight:ClearAllPoints()
            dragHighlight:SetAllPoints(target)
            dragHighlight:Show()
        else
            dragHighlight:Hide()
        end
    end)
    -- The editor icon normally ends the drag (OnDragStop). If the editor closes
    -- mid-drag that never comes, so any mouse release, or entering combat, ends
    -- it too.
    dragIcon:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            GSE.CancelSequenceDrag()
        else
            GSE.FinishSequenceDrag()
        end
    end)
end

local function endDrag()
    local ended = drag ~= nil
    drag = nil
    if ended then GSE:SendMessage(Statics.Messages.SEQUENCE_DRAG_ENDED) end
    if dragIcon then
        dragIcon:UnregisterAllEvents()
        dragIcon:Hide()
        dragHighlight:Hide()
    end
end

function GSE.CancelSequenceDrag()
    endDrag()
end

-- Start dragging a sequence. Returns false (and says why) when it cannot.
-- fromButton: the GSE Action Bar button it is being dragged off, if any --
-- the drop then moves it, and a drop on nothing takes it off the bar.
function GSE.BeginSequenceDrag(sequenceId, fromButton)
    if drag then endDrag() end
    if InCombatLockdown() then
        GSE.Print(L["Sequences cannot be put on action buttons in combat."])
        return false
    end
    if not (sequenceId and _G[sequenceId] and GSE.SequencesExec and GSE.SequencesExec[sequenceId]) then
        GSE.Print(L["Only a saved sequence for this character's class can be put on an action button."])
        return false
    end
    ensureDragFrames()
    local thisDrag = { sequenceId = sequenceId, candidates = {}, fromButton = fromButton }
    drag = thisDrag
    -- The icon first, at the cursor, so it shows the moment the drag starts:
    -- the player's base icon, else the start icon.
    dragIcon.texture:SetTexture(GSE.GetSequenceBaseIcon(sequenceId) or GSE.GetSequenceStartIcon(sequenceId)
        or Statics.Icons.GSE_Logo_Dark)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    dragIcon:ClearAllPoints()
    dragIcon:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    pcall(dragIcon.RegisterEvent, dragIcon, "GLOBAL_MOUSE_UP")
    dragIcon:RegisterEvent("PLAYER_REGEN_DISABLED")
    dragIcon:Show()
    -- Before the buttons are gathered below, so a bar that hides itself (the
    -- GSE Action Bar) can show for the drop.
    GSE:SendMessage(Statics.Messages.SEQUENCE_DRAG_STARTED, sequenceId)
    -- Every action button shown now; the drag tests these for the mouse. It
    -- runs on the next frame so the icon shows first.
    C_Timer.After(0, function()
        if drag ~= thisDrag then return end
        local candidates = {}
        pcall(collectOverrideTargets, UIParent, candidates)
        thisDrag.candidates = candidates
    end)
    return true
end

-- Release: bind the sequence to the button under the mouse, if there is one
-- it can go on.
function GSE.FinishSequenceDrag()
    if not drag then return end
    local sequenceId, fromButton = drag.sequenceId, drag.fromButton
    local target = overrideTargetUnderMouse() or drag.target
    endDrag()
    if target == fromButton then return end
    if InCombatLockdown() then
        if target or fromButton then GSE.Print(L["Sequences cannot be put on action buttons in combat."]) end
        return
    end
    -- Off a GSE Action Bar button and dropped on nothing: it comes off the
    -- bar, as an action dragged off a bar does.
    if not target then
        if fromButton then GSE.RemoveActionBarOverride(fromButton:GetName()) end
        return
    end
    -- A real spell or item in the slot would win over the override and hide it,
    -- so only an empty slot, or one GSE already overrides, takes a sequence.
    -- Between two GSE Action Bar buttons the two swap: the action comes to
    -- the button the sequence left.
    if not target:GetAttribute("gse-button") then
        local slot = getButtonEffectiveSlot(target)
        local holdsAction = target.gseActionBarButton and GSE.ActionBarButtonHasAction
            and GSE.ActionBarButtonHasAction(target)
        if holdsAction and fromButton and fromButton.gseActionBarButton and GSE.ActionBarSwapActions then
            GSE.ActionBarSwapActions(target, fromButton)
        elseif holdsAction or (slot and HasAction(slot)) then
            GSE.Print(L["That action button already holds something. Clear it first, then drop the sequence on it."])
            return
        end
    end
    -- A drop replaces what the button shows. Where that is the active talent
    -- loadout's override, the drop changes that loadout's -- say so, since the
    -- spec's own override for the button is left as it was.
    local written
    if fromButton then
        written = GSE.MoveActionBarOverride(fromButton:GetName(), target:GetName())
    else
        written = GSE.CreateActionBarOverride(target:GetName(), sequenceId)
    end
    if written == "loadout" then
        GSE.Print(string.format(L["Changed for talent loadout %s only."], GSE.ActiveBindingLoadoutName() or ""),
            L["Button Bindings"])
    end
end

--- Watch the spec + loadout the game reports until it catches up with what the
--- player actually swapped to, and rebuild when it does. Blizzard updates both
--- only after the events GSE rebuilds on, so those rebuilds bind the previous
--- spec's or loadout's keys; how long that lags is not fixed, hence a bounded
--- watch rather than one delayed look. A rebuild records the new context, so
--- the next check matches and the watch stops.
function scheduleBindingRecheck(attempts)
    if bindingRecheckPending or attempts < 1 or not C_Timer then
        return
    end
    bindingRecheckPending = true
    C_Timer.After(
        BINDING_RECHECK_INTERVAL,
        function()
            bindingRecheckPending = false
            if InCombatLockdown() then
                return
            end
            if currentBindingContext() ~= lastBindingContext then
                -- LoadKeyBindings arms the next watch itself.
                LoadKeyBindings(true)
            else
                scheduleBindingRecheck(attempts - 1)
            end
        end
    )
end

function GSE.ReloadKeyBindings()
    LoadKeyBindings(true)
end

--- Release a physical key GSE had bound to a sequence. ONE path for every
--- delete/rebind in the editor (tree right-click, panel Delete, panel Save):
---  * normalises legacy mouse-button names, so the key that is actually bound
---    is the one cleared (#1954 normalised on load only);
---  * rebuilds the keybind tables afterwards, which releases every key the last
---    rebuild bound before re-adding the ones that survive;
---  * in combat, where SetBinding is protected, defers itself to the OOC queue
---    instead of silently doing nothing (which is exactly how a "deleted" key
---    kept firing its old sequence). Callers remove the GSE_C entry FIRST so
---    the rebuild cannot re-add it.
--- Deliberately does NOT call SaveBindings: GSE_C is the source of truth and
--- the rebuild on login is the persistence. Writing the live binding table to
--- bindings-cache.wtf would bake whatever GSE has bound right now into the
--- character's (or, on an account-wide set, every character's) saved bindings.
function GSE.ClearKeyBinding(key)
    if GSE.isEmpty(key) then return false end
    key = normalizeBindKey(key)
    if InCombatLockdown() then
        GSE.EnqueueOOC({ action = "clearkeybind", key = key })
        GSE.Print(string.format(L["Keybind %s will be cleared when combat ends."], key))
        return false
    end
    SetBinding(key)
    LoadKeyBindings(true)
    return true
end

-- Where WoW no longer honours GSE's own keybinds (Retail 12.1.7 on; Forever
-- never had any to move), a character with some gets the GSE Action Bar
-- turned on, once per account,
-- with both bars hidden: its keybinds move onto the bar's buttons
-- (GSE_Actionbar/Migration.lua) and keep working, and nothing new shows until
-- the player chooses to show it. There is no reload: GSE loads the bar itself (loadActionBar). Turned off again
-- afterwards, it stays off. Everywhere else
-- the keybinds still work, and moving them is the player's choice: the switch
-- in GSE's options.
local function enableActionBarForKeybinds()
    if not GSE.DirectKeybindsRetired or GSE.IsForever then return end
    if GSE.ActionBarActive() or type(GSE_C) ~= "table" or GSEOptions.ActionBarAutoEnabled then return end
    if not GSE.ActionBarInstalled() then return end
    local hasKeys = false
    for _, spec in ipairs(GSE.BindingSpecs()) do
        for key in pairs(GSE.SpecKeyBinds(spec.key, false) or {}) do
            if key ~= "LoadOuts" then hasKeys = true end
        end
        for _, binds in pairs(GSE.SpecLoadoutKeyBinds(spec.key, false) or {}) do
            if type(binds) == "table" and next(binds) then hasKeys = true end
        end
    end
    if not hasKeys then return end
    GSEOptions.ActionBarAutoEnabled = true
    -- The bar's starting state: hidden, its keys working. Only where the
    -- player has never turned the bar on or off, so nothing they chose is
    -- undone.
    if GSEOptions.ActionBarEnabled == nil then GSEOptions.ActionBarStartHidden = true end
    -- What's New explains it (GSE.ShowUpdateNotes, below).
    GSEOptions.ActionBarEnabled = true
end

-- Load the GSE Action Bar while it is turned on. It is LoadOnDemand, so it
-- loads now, and its setup runs before this returns (ADDON_LOADED), so its
-- buttons exist when the Button Bindings go on. Their keys are WoW's own
-- (Bindings.xml); GSE binds nothing for them. Its buttons are secure, so in
-- combat it waits for combat to end (PLAYER_REGEN_ENABLED).
local actionBarWaiting = false
local function loadActionBar()
    if InCombatLockdown() then
        actionBarWaiting = true
        return
    end
    actionBarWaiting = false
    if GSE.ActionBarEnabled() and not C_AddOns.IsAddOnLoaded(Statics.ActionBarAddOn) then
        local loaded, reason = C_AddOns.LoadAddOn(Statics.ActionBarAddOn)
        if not loaded then
            GSE.Print(string.format(L["The GSE Action Bar could not be loaded: %s"], tostring(reason)))
            return
        end
    end
    -- Loaded before (on now, or turned off this session): it shows or hides
    -- itself to match.
    if GSE.ActionBarApply then GSE.ActionBarApply() end
end

--- The GSE Action Bar was turned on or off (GSE.SetActionBarEnabled): load or
--- show it, or hide it, and put the Button Bindings on again, which arms or
--- disarms its buttons. No key binding changes: the buttons' keys are WoW's
--- own, set in its Key Bindings.
function GSE.StartActionBar()
    loadActionBar()
    if InCombatLockdown() then return end
    GSE.ReloadOverrides()
end

function GSE:PLAYER_ENTERING_WORLD()
    GSE.PrintAvailable = true
    GSE.PerformPrint()
    GSE.InstallDeveloperDebugGameMenuWarning()
    GSE.currentZone = GetRealZoneText()
    GSE.PlayerEntered = true
    GSE.UpdateZoneFlags()
    -- One-off: stamp LastUpdated on any pre-existing record that's missing it
    -- (older mod versions didn't track it for macros at all, and never-edited
    -- sequences/variables can also be missing the field). Idempotent ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a
    -- SavedVariables flag prevents re-runs after the first successful pass.
    if GSE.BackfillLastUpdated then
        GSE.BackfillLastUpdated()
    end
    enableActionBarForKeybinds()
    LoadKeyBindings(true)
    GSE.PerformReloadSequences(true)
    hookActionButtonUpdate()
    -- The GSE Action Bar's buttons have to exist before Button Bindings go on.
    loadActionBar()
    LoadOverrides()
    GSE.ManageMacros()
    scheduleGSEOverrideIconRepaint()
    -- Migrate any remaining classes in the background so login is not blocked.
    if GSE.MigrateAllRemainingClasses then
        GSE.EnqueueOOC({action = "migrateremainingclasses"})
    end
    if ConsolePort then
        C_Timer.After(10, LoadOverrides)
    end
    hookActionButtonUpdate()
    GSE:RegisterEvent("UPDATE_MACROS")
    if GSEOptions.shownew and not GSE.UnsavedOptions.UpdateNotesShown then
        GSE.UnsavedOptions.UpdateNotesShown = true
        GSE:ShowUpdateNotes()
    end
    local menuOpts = not GSE.isEmpty(GSEOptions.frameLocations) and GSEOptions.frameLocations.menu
    if menuOpts and menuOpts.open and GSEOptions.ToolbarEnabled ~= false then
        C_Timer.After(0, function()
            if GSE.CheckGUI() and GSE.ShowMenu then
                GSE.ShowMenu()
            end
        end)
    end
end

local function startup()
    local charKey = GSE.CharacterMacroBucketKey()
    -- Before anything reads a setting a profile carries (Profiles.lua).
    GSE.InstallProfileSettings()
    GSE.PerformOneOffEvents()

    if GSE.isEmpty(GSESpellCache) then
        GSESpellCache = {
            ["enUS"] = {}
        }
    end

    if GSE.isEmpty(GSESpellCache[GetLocale()]) then
        GSESpellCache[GetLocale()] = {}
    end
    if GSE.SanitizeSpellCache then
        GSE.SanitizeSpellCache()
    end

    GSE.LoadStorage(GSE.Library)
    -- Before anything is bound: this character's keybinds and overrides hold
    -- sequence ids, not names.
    GSE.UpdateCharacterSequenceRefs()

    if GSE.LoadDeltaForks then GSE.LoadDeltaForks() end

    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()]) then
        GSE.Library[GSE.GetCurrentClassID()] = {}
    end
    if GSE.isEmpty(GSE.Library[0]) then
        GSE.Library[0] = {}
    end
    if GSE.isEmpty(GSE.Store("macro")[charKey]) then
        GSE.Store("macro")[charKey] = {}
    end
    --@debug@
    GSE.PrintDebugMessage("I am loaded")
    --@end-debug@
    if GSE.GameMode >= 12 then
        -- only do this for retail not classics
        for iter = 0, 13 do
            if GSE.Library[iter] then
                for k,v in ipairs(GSE.Library[iter]) do
                    if not v.MetaData then
                        v.MetaData = {}
                    end
                    if not v.MetaData.GSEVersion or v.MetaData.GSEVersion < math.floor(GSE.VersionNumber/ 100) * 100 then
                        v.MetaData.Disabled = true
                        local vals = {}
                        vals.action = "Replace"
                        vals.id = k
                        vals.sequence = v
                        vals.classid = iter
                        GSE.EnqueueOOC(vals)
                    end
                end
            end
        end
    end
    GSE:SendMessage(Statics.CoreLoadedMessage)

    -- The GSE_Companion bridge addon handles showing the import dialog
    -- for incoming platform content. The import landing page also shows
    -- a banner when GSE.IncomingQueue has pending entries.

    -- Register the Sample Macros
    if not GSEOptions.HideLoginMessage then
        GSE.Print(
            L["Advanced Macro Compiler loaded.|r  Type "] ..
                GSEOptions.CommandColour .. L["/gse help|r to get started."]
        )
    end

    GSE.WagoAnalytics:Switch("minimapIcon", GSEOptions.showMiniMap.hide)
end

startup()

local spellIconRefreshQueued = false
local function refreshCurrentSpellIconsNow()
    if GSE.SequencesExec then
        for name, _ in pairs(GSE.SequencesExec) do
            local button = _G[name]
            if button and GSE.UpdateIcon then
                GSE.UpdateIcon(button, false)
            end
        end
    end

    repaintAllGSEOverrideIcons(false)
    C_Timer.After(0, function()
        repaintAllGSEOverrideIcons(false)
    end)
end

local function queueCurrentSpellIconRefresh(immediate)
    if immediate then
        spellIconRefreshQueued = false
        refreshCurrentSpellIconsNow()
        return
    end

    if spellIconRefreshQueued then return end
    spellIconRefreshQueued = true
    C_Timer.After(0.05, function()
        spellIconRefreshQueued = false
        refreshCurrentSpellIconsNow()
    end)
end

function GSE:SPELL_UPDATE_USABLE()
    queueCurrentSpellIconRefresh()
end

function GSE:SPELL_ACTIVATION_OVERLAY_SHOW()
    queueCurrentSpellIconRefresh()
end

function GSE:SPELL_ACTIVATION_OVERLAY_HIDE()
    queueCurrentSpellIconRefresh()
end


function GSE:MODIFIER_STATE_CHANGED()
    queueCurrentSpellIconRefresh(true)
end

function GSE.GetDeveloperDebugWarningReasons()
    local reasons = {}
    if GSEOptions then
        if GSEOptions.debug then
            reasons[#reasons + 1] = "Enable Mod Debug Mode"
        end
        if GSEOptions.sendDebugOutputToChatWindow then
            reasons[#reasons + 1] = "Display debug messages in Chat Window"
        end
        if GSEOptions.sendDebugOutputToDebugOutput then
            reasons[#reasons + 1] = "Store Debug Messages"
        end
        if type(GSEOptions.DebugModules) == "table" then
            for moduleName, enabled in pairs(GSEOptions.DebugModules) do
                if enabled == true then
                    reasons[#reasons + 1] = "Module: " .. tostring(moduleName)
                end
            end
        end
    end
    return reasons
end

function GSE.HasDeveloperDebugWarning()
    return #GSE.GetDeveloperDebugWarningReasons() > 0
end

function GSE.ShowDeveloperDebugActiveWarning()
    if not GSE.HasDeveloperDebugWarning() then return end
    GSE.GUICall("GUIShowDeveloperDebugWarning", table.concat(GSE.GetDeveloperDebugWarningReasons(), ", "))
end

function GSE.InstallDeveloperDebugGameMenuWarning()
    if GSE.DeveloperDebugGameMenuWarningInstalled then return end
    if GameMenuFrame and GameMenuFrame.HookScript then
        GameMenuFrame:HookScript("OnShow", function()
            if GSE.ShowDeveloperDebugActiveWarning then
                GSE.ShowDeveloperDebugActiveWarning()
            end
        end)
        GSE.DeveloperDebugGameMenuWarningInstalled = true
    end
end

function GSE:PLAYER_REGEN_ENABLED(unit, event, addon)
    GSE:UnregisterEvent("PLAYER_REGEN_ENABLED")
    GSE.ResetButtons()
    -- The GSE Action Bar waited for combat to end to load (loadActionBar).
    if actionBarWaiting then GSE.StartActionBar() end
    LoadOverrides()
    GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function GSE:PLAYER_LEAVING_WORLD()
    if GSE.GUI and GSE.GUI.editors then
        for _, editor in ipairs(GSE.GUI.editors) do
            if editor.SaveLocation then editor.SaveLocation() end
        end
    end
end

function GSE:PLAYER_LOGOUT()
    -- "Forget Last Opened Sequence on Logout": the editor writes its
    -- where-was-I state to GSEOptions as you click around, so honouring the
    -- option means clearing that state on the way out rather than declining to
    -- save it. Deliberately outside the UnsavedOptions["GUI"] block below --
    -- that gate is about writing frame positions, and this has to run whether
    -- or not it does.
    if GSEOptions and GSEOptions.forgetLastSequenceOnLogout
        and GSE.GUI and GSE.GUI.ForgetLastSequenceEditorNode then
        GSE.GUI.ForgetLastSequenceEditorNode()
    end
    if not GSE.UnsavedOptions["GUI"] then
        if GSE["MenuFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations) then
                GSEOptions.frameLocations = {}
            end

            if GSE.isEmpty(GSEOptions.frameLocations.menu) then
                GSEOptions.frameLocations.menu = {}
            end
            GSEOptions.frameLocations.menu.top  = GSE.MenuFrame:GetTop()
            GSEOptions.frameLocations.menu.left = GSE.MenuFrame:GetLeft()
        end
        if GSE["GUIVariableFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.variablesframe) then
                GSEOptions.frameLocations.variablesframe = {}
            end

            GSEOptions.frameLocations.variablesframe.top = GSE.GUIVariableFrame.frame:GetTop()
            GSEOptions.frameLocations.variablesframe.left = GSE.GUIVariableFrame.frame:GetLeft()
        end
        if GSE["GUIMacroFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.macroframe) then
                GSEOptions.frameLocations.macroframe = {}
            end
            GSEOptions.frameLocations.macroframe.top = GSE.GUIMacroFrame.frame:GetTop()
            GSEOptions.frameLocations.macroframe.left = GSE.GUIMacroFrame.frame:GetLeft()
        end
        if GSE["GUIDebugFrame"] then
            if GSE.isEmpty(GSEOptions.frameLocations.debug) then
                GSEOptions.frameLocations.debug = {}
            end
            GSEOptions.frameLocations.debug.top = GSE.GUIDebugFrame.frame:GetTop()
            GSEOptions.frameLocations.debug.left = GSE.GUIDebugFrame.frame:GetLeft()
        end
        if GSE["GUIkeybindingframe"] then
            if GSE.isEmpty(GSEOptions.frameLocations.keybindingframe) then
                GSEOptions.frameLocations.keybindingframe = {}
            end
            GSEOptions.frameLocations.keybindingframe.top = GSE.GUIkeybindingframe.frame:GetTop()
            GSEOptions.frameLocations.keybindingframe.left = GSE.GUIkeybindingframe.frame:GetLeft()
        end
    end
    -- Last, so nothing above can still be writing content: fold this session's
    -- working views back into GSEStore before WoW writes SavedVariables. This
    -- event fires on /reload as well as on exit, and nothing else in GSE writes
    -- content during logout.
    if GSE.ReconcileStore then GSE.ReconcileStore() end
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
    if not InCombatLockdown() then
        LoadKeyBindings(GSE.PlayerEntered)
        GSE.ReloadSequences()
        LoadOverrides()
    end
end

function GSE:PLAYER_LEVEL_UP()
    GSE.ReloadSequences()
end

function GSE:CHARACTER_POINTS_CHANGED()
    GSE.ReloadSequences()
end

function GSE:SPELLS_CHANGED()
    GSE.ReloadSequences()
end

-- A newly trained spell rank. A ranked cast steps up to it (see "Spell ranks"
-- in translator.lua), and SPELLS_CHANGED is only registered on Classic, so WoW
-- Forever -- which reports GameMode 12 -- would otherwise keep the old rank
-- until the next level-up or reload.
function GSE:LEARNED_SPELL_IN_SKILL_LINE()
    GSE.ReloadSequences()
end

function GSE:SPELL_DATA_LOAD_RESULT(_, spellID, success)
    if success and GSE.SpellRankDataLoaded and GSE.SpellRankDataLoaded(spellID) then
        GSE.ReloadSequences()
    end
end

function GSE:ACTIVE_TALENT_GROUP_CHANGED()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_PVP_TALENT_UPDATE()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:SPEC_INVOLUNTARILY_CHANGED()
    GSE.ReloadSequences(GSE.PlayerEntered)
    LoadOverrides()
end

function GSE:TRAIT_NODE_CHANGED()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_TARGET_CHANGED()
    GSE:UnregisterEvent("PLAYER_TARGET_CHANGED")
    if GSE.isEmpty(GSE.UnsavedOptions.ReloadQueued) and not InCombatLockdown() then
        GSE.ReloadSequences()
    end
    GSE:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function GSE:TRAIT_CONFIG_UPDATED(_, payload)
    GSE:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")
end

function GSE:ACTIVE_COMBAT_CONFIG_CHANGED()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences()
end

function GSE:PLAYER_TALENT_UPDATE()
    LoadKeyBindings(GSE.PlayerEntered)
    LoadOverrides()
    GSE.ReloadSequences(GSE.PlayerEntered)
end

function GSE:GROUP_ROSTER_UPDATE(...)
    -- Serialisation stuff
    GSE.sendVersionCheck()
    for k, _ in pairs(GSE.UnsavedOptions["PartyUsers"]) do
        if not (UnitInParty(k) or UnitInRaid(k)) then
            -- Take them out of the list
            GSE.UnsavedOptions["PartyUsers"][k] = nil
        end
    end
    local channel
    if IsInRaid() then
        channel =
            (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
            "RAID"
    else
        channel =
            (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
            "PARTY"
    end
    if #GSE.UnsavedOptions["PartyUsers"] > 1 then
        GSE.SendSpellCache(channel)
    end
    -- Group Team stuff
    local _, _, difficulty, _, _, _, _, _, _ = GetInstanceInfo()
    -- dont trigger the normal things if in a delve
    if difficulty ~= 208 then
        GSE:ZONE_CHANGED_NEW_AREA()
    end
end

function GSE:GUILD_ROSTER_UPDATE(...)
    -- Serialisation stuff
    GSE.sendVersionCheck("GUILD")
end

function GSE:UPDATE_MACROS()
    GSE.ManageMacros()
    scheduleGSEOverrideIconRepaint()
end

function GSE:CINEMATIC_STOP()
    LoadOverrides()
end

GSE:RegisterEvent("GROUP_ROSTER_UPDATE")
GSE:RegisterEvent("PLAYER_LOGOUT")
GSE:RegisterEvent("PLAYER_LEAVING_WORLD")
GSE:RegisterEvent("PLAYER_ENTERING_WORLD")
GSE:RegisterEvent("PLAYER_REGEN_ENABLED")
GSE:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
GSE:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GSE:RegisterEvent("UNIT_FACTION")
GSE:RegisterEvent("PLAYER_LEVEL_UP")
GSE:RegisterEvent("GUILD_ROSTER_UPDATE")
GSE:RegisterEvent("PLAYER_TARGET_CHANGED")
GSE:RegisterEvent("CINEMATIC_STOP")
GSE:RegisterEvent("MODIFIER_STATE_CHANGED")

if GSE.GameMode > 8 then
    GSE:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    GSE:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    GSE:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
end

if GSE.GameMode > 10 then
    GSE:RegisterEvent("PLAYER_TALENT_UPDATE")
    GSE:RegisterEvent("SPEC_INVOLUNTARILY_CHANGED")
    GSE:RegisterEvent("TRAIT_CONFIG_UPDATED")
    GSE:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    GSE:RegisterEvent("SPELL_UPDATE_USABLE")
    GSE:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
    GSE:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
end

if GSE.GameMode <= 3 then
    GSE:RegisterEvent("CHARACTER_POINTS_CHANGED")
    GSE:RegisterEvent("SPELLS_CHANGED")
end

-- Spell ranks. Keyed on the event existing, not the game version: registering
-- an event a client does not have is an error.
for _, eventName in ipairs({"LEARNED_SPELL_IN_SKILL_LINE", "SPELL_DATA_LOAD_RESULT"}) do
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(eventName) then
        GSE:RegisterEvent(eventName)
    end
end

function GSE:OnEnable()
    if GSE.OOCQueue and #GSE.OOCQueue > 0 then
        GSE.StartOOCTimer()
    end
end

--- Start the OOC Queue Timer
function GSE.StartOOCTimer()
    if GSE.OOCQueuePaused then return end
    if GSE.OOCTimer then return end
    local delay = GSEOptions.OOCQueueDelay and GSEOptions.OOCQueueDelay or 7
    GSE.OOCTimer = C_Timer.NewTicker(delay, function() GSE.ProcessOOCQueue() end)
end

--- Stop the OOC Queue Timer
function GSE.StopOOCTimer()
    if GSE.OOCTimer then GSE.OOCTimer:Cancel() end
    GSE.OOCTimer = nil
end

--- True while a boss encounter is in progress. Prefers the 12.0 (Midnight)
--- C_InstanceEncounter namespace; falls back to the long-standing global.
function GSE.IsEncounterInProgress()
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress then
        return C_InstanceEncounter.IsEncounterInProgress()
    end
    if IsEncounterInProgress then
        return IsEncounterInProgress()
    end
    return false
end

function GSE:ProcessOOCQueue()
    -- check ZONE_CHANGED_NEW_AREA issues
    if GSE.currentZone ~= GetRealZoneText() then
        GSE:ZONE_CHANGED_NEW_AREA()
        GSE.currentZone = GetRealZoneText()
    end
    -- Swap the queue atomically: items enqueued during processing land in the
    -- new table, and combat-blocked items are re-inserted cleanly with no holes.
    local queue = GSE.OOCQueue
    GSE.OOCQueue = {}
    local encounterInProgress = GSE.IsEncounterInProgress()
    for _, v in ipairs(queue) do
        if not InCombatLockdown() then
            if v.action == "UpdateSequence" then
                if encounterInProgress then
                    table.insert(GSE.OOCQueue, v)
                else
                    GSE.OOCUpdateSequence(v.id, v.macroversion)
                end
            elseif v.action == "Save" then
                GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid, v.id)
            elseif v.action == "Replace" then
                if v.id == nil or not GSE.SequenceEnvelope(v.id) then
                    local name = v.sequencename
                        or (type(v.sequence) == "table" and type(v.sequence.MetaData) == "table" and v.sequence.MetaData.Name)
                    GSE.AddSequenceToCollection(name, v.sequence, v.classid, v.id)
                else
                    GSE.ReplaceSequence(v.classid, v.id, v.sequence)
                    local macroVersion = v.sequence.Versions[GSE.GetActiveSequenceVersion(v.id)]
                    if encounterInProgress then
                        GSE.UpdateSequence(v.id, macroVersion)
                    else
                        GSE.OOCUpdateSequence(v.id, macroVersion)
                    end
                end
            elseif v.action == "updatevariable" then
                GSE.UpdateVariable(v.variable, v.name)
            elseif v.action == "updatemacro" then
                GSE.UpdateMacro(v.node)
            elseif v.action == "importmacro" then
                GSE.ImportMacro(v.node)
            elseif v.action == "managemacros" then
                GSE.ManageMacros()
                scheduleGSEOverrideIconRepaint()
            elseif v.action == "MergeSequence" then
                GSE.OOCPerformMergeAction(v.mergeaction, v.classid, v.id, v.newSequence, v.newname)
            elseif v.action == "FinishReload" then
                GSE.UnsavedOptions.ReloadQueued = nil
            elseif v.action == "migrateremainingclasses" then
                GSE.MigrateAllRemainingClasses()
                if GSE.ProcessCorruptSequences and not GSE.isEmpty(GSE.CorruptSequences) then
                    GSE.ProcessCorruptSequences()
                end
            elseif v.action == "openoptions" then
                if GSE.OpenOptionsPanel then
                    GSE.OpenOptionsPanel()
                end
            elseif v.action == "clearkeybind" then
                GSE.ClearKeyBinding(v.key)
            elseif v.action == "deletesequence" then
                -- Generic OOC sequence delete. Used by the Companion bridge
                -- after the user confirms a delete (the website record has
                -- already been soft-deleted by the time we get here) and
                -- could be used by future Mod UI paths that need to delete
                -- out-of-combat. classid resolved at enqueue time. The bridge
                -- names what it deletes; the name is looked up in that class
                -- only, global (0) included -- that class used to be refused,
                -- so a confirmed delete of a global sequence never happened.
                local cid = tonumber(v.classid)
                local id = v.id or (cid and GSE.FindSequenceId(v.sequencename, cid))
                if id and cid then
                    GSE.DeleteSequence(cid, id)
                end
            elseif v.action == "renamesequence" then
                -- True in-place rename: the label changes, the id -- and so the
                -- GSE.Tools record and everything that refers to it -- stays.
                if v.id and v.newname and v.classid and v.sequence then
                    local ok = GSE.RenameSequence(v.classid, v.id, v.newname, v.sequence)
                    if ok then
                        local macroVersion = v.sequence.Versions and
                            v.sequence.Versions[GSE.GetActiveSequenceVersion(v.id)]
                        if macroVersion then
                            if encounterInProgress then
                                GSE.UpdateSequence(v.id, macroVersion)
                            else
                                GSE.OOCUpdateSequence(v.id, macroVersion)
                            end
                        end
                    end
                end
            elseif v.action == "deletevariable" then
                if v.variablename then
                    GSE.DeleteVariable(v.variablename)
                end
            elseif v.action == "deletemacro" then
                if v.macroname then
                    GSE.DeleteMacro(v.macroname)
                end
            end
        else
            -- Still in combat; put the item back so it's processed next tick.
            table.insert(GSE.OOCQueue, v)
        end
    end
    if not GSE.isEmpty(GSE.GCDLDB) then
        GSE.GCDLDB.value = GSE.GetGCD()
        GSE.GCDLDB.text = string.format("GCD: %ss", GSE.GetGCD())
    end
    if not GSE.OOCQueue or #GSE.OOCQueue == 0 then
        GSE.StopOOCTimer()
    end
end

function GSE.ToggleOOCQueue()
    -- Explicit user pause/resume. This is the ONLY thing that "pauses" the
    -- queue; the ticker itself is stopped automatically whenever the queue
    -- drains empty (see ProcessOOCQueue), which is idle, not paused.
    if GSE.OOCQueuePaused then
        GSE.OOCQueuePaused = false
        if GSE.OOCQueue and #GSE.OOCQueue > 0 then
            GSE.StartOOCTimer()
        end
    else
        GSE.OOCQueuePaused = true
        GSE.StopOOCTimer()
    end
end

function GSE.CheckGUI()
    local loaded, reason = C_AddOns.LoadAddOn("GSE_GUI")
    if not loaded then
        if reason == "DISABLED" then
            --@debug@
            GSE.PrintDebugMessage("GSE GUI Disabled", "GSE_GUI")
            --@end-debug@
            GSE.Print(
                L["The GUI has not been loaded.  Please activate this plugin amongst WoW's addons to use the GSE GUI."]
            )
        elseif reason == "MISSING" then
            GSE.Print(L["The GUI is missing.  Please ensure that your GSE install is complete."])
        elseif reason == "CORRUPT" then
            GSE.Print(L["The GUI is corrupt.  Please ensure that your GSE install is complete."])
        elseif reason == "INTERFACE_VERSION" then
            GSE.Print(L["The GUI needs updating.  Please ensure that your GSE install is complete."])
        end
    end
    return loaded
end

-- Force-load the LoadOnDemand GUI (which hosts the native dialogs) and then
-- call the named GSE.* GUI function. Used by always-loaded core/util/options
-- code that may need to raise a popup before the GUI has been opened.
function GSE.GUICall(fnName, ...)
    if GSE.CheckGUI and not GSE.CheckGUI() then return end
    local fn = GSE[fnName]
    if type(fn) == "function" then
        return fn(...)
    end
end

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Events") end

