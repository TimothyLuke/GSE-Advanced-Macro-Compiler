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

local function GetSpec()
    if GSE.GameMode < 7 then
        return "1"
    else
        if GSE.GameMode < 12 then
            return tostring(GetSpecialization())
        else
            local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
            return tostring(getSpec and getSpec() or 1)
        end
    end
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
-- The "gse-button" string (sequence name) is still set insecurely elsewhere for
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
local function getButtonEffectiveSlot(btn)
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
            if macroName and ((GSE.SequencesExec and GSE.SequencesExec[macroName]) or _G[macroName]) then
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

local function setOverrideButtonForcedShown(buttonOrName, shown)
    local btn = type(buttonOrName) == "string" and _G[buttonOrName] or buttonOrName
    if not btn or not btn.SetShowGridInsecure then return end
    if InCombatLockdown() then return end
    btn:SetShowGridInsecure(shown and true or false, GSE_FORCE_SHOWGRID_REASON, true)
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

local function addGSEWatermark(Button)
    if watermarkedButtons[Button] then return end
    local btn = _G[Button]
    if not btn then return end
    local wm = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    wm:SetTexture("Interface\\AddOns\\GSE_GUI\\Assets\\GSE_Logo_Dark_512.png")
    wm:SetSize(14, 14)
    wm:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    wm:SetAlpha(0.85)
    if GSEOptions.showActionBarWatermark == false then wm:Hide() end
    watermarkedButtons[Button] = wm
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
    else
        GameTooltip:SetText(seqName, 1, 1, 1)
        GameTooltip:AddLine(L["GSE Sequence"], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- Non-secure hook that watches attributes written by BAR_SWAP_OAC / BAR_SWAP_ONCLICK.
-- gse-eff-action > 0  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ bar has swapped (vehicle/skyriding), show the override icon.
-- gse-eff-action == 0 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ back to normal GSE state, restore the macro icon.
-- type == "click"     ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ WoW just reset the type (OnEnter / post-combat), restore icon.
local function hookButtonIconUpdates(Button)
    if iconHookedButtons[Button] then return end
    iconHookedButtons[Button] = true

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
                    local macroName = GetMacroInfo(macroIndex)
                    if macroName and ((GSE.SequencesExec and GSE.SequencesExec[macroName]) or _G[macroName]) then
                        texture = getGSESequenceIcon(macroName)
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
    local Sequence = savedBind.Sequence
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
    if isDominosButton or string.sub(Button, 1, 7) == "Dominos" or string.sub(Button, 1, 11) == "ButtonForge" then
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
                    tooltip = "GSE: " .. Sequence,
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
            local stateTypes = _G[Button].state_types
            if savedBind.State then
                _G[Button]:SetState(state, "custom", customState())
            elseif type(stateTypes) == "table" and next(stateTypes) then
                for st in pairs(stateTypes) do
                    _G[Button]:SetState(st, "custom", customState())
                end
            else
                _G[Button]:SetState(state, "custom", customState())
            end
            _G[Button]:SetAttribute("type", "click")
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
                    string.sub(Button, 1, 22) == "MultiBarBottomLeftButton" or
                    string.sub(Button, 1, 23) == "MultiBarBottomRightButton" or
                    string.sub(Button, 1, 13) == "MultiBar5Button" or
                    string.sub(Button, 1, 13) == "MultiBar6Button" or
                    string.sub(Button, 1, 13) == "MultiBar7Button" or
                    string.sub(Button, 1, 18) == "MultiBarRightButton" or
                    string.sub(Button, 1, 17) == "MultiBarLeftButton"

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

local function LoadOverrides(force)
    if GSE.isEmpty(GSE.ButtonOverrides) then
        GSE.ButtonOverrides = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        GSE_C["ActionBarBinds"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
        GSE_C["ActionBarBinds"]["Specialisations"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()]) then
        GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()] = {}
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
        for k, _ in pairs(GSE.ButtonOverrides) do
            -- Drop the forced-shown bit so a no-longer-overridden Dominos slot can
            -- hide again; it is re-applied below for slots that remain overridden.
            setOverrideButtonForcedShown(k, false)
            -- revert all buttons
            if _G[k] and _G[k].SetState then
                local state = "1"
                --_G[Button]:GetAttribute("state"),
                if string.sub(k, 1, 3) == "BT4" then
                    state = "0"
                elseif string.sub(k, 1, 4) == "CPB_" then
                    state = ""
                end
                _G[k]:SetState(state, "action", tonumber(string.match(k, "%d+$")))
                removeGSEWatermark(k)
            else
                _G[k]:SetAttribute("gse-button", nil)
                -- Clear the secure gate + reset type from inside the secure
                -- environment (issue #1931); gse-button is a non-secure string so
                -- clearing it insecurely is harmless.
                secureDisarmGSEButton(_G[k])
                SecureHandlerUnwrapScript(_G[k], "OnClick")
                SecureHandlerUnwrapScript(_G[k], "OnEnter")
                SecureHandlerUnwrapScript(_G[k], "OnAttributeChanged")
                removeGSEWatermark(k)
            end
        end
        GSE.ButtonOverrides = {}

        for _, v in pairs(GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()]) do
            overrideActionButton(v, force)
        end
        if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
            local selected = playerSpec() and tostring(C_ClassTalents.GetLastSelectedSavedConfigID(playerSpec()))

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
    end
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

local function LoadKeyBindings(payload)
    if GSE.isEmpty(GSE_C) then
        GSE_C = {}
    end
    if GSE.isEmpty(GSE_C["KeyBindings"]) then
        GSE_C["KeyBindings"] = {}
    end

    if GSE.isEmpty(GSE_C["KeyBindings"][GetSpec()]) then
        GSE_C["KeyBindings"][GetSpec()] = {}
    end

    for k, v in pairs(GSE_C["KeyBindings"][GetSpec()]) do
        if k ~= "LoadOuts" and not InCombatLockdown() then
            local target = GSE.GetKeybindClickTarget(v)
            k = normalizeBindKey(k)
            SetBindingClick(k, target, "LeftButton")
            if GSE.GameMode == 5 then
                SetOverrideBindingClick(keybindingframe, false, k, target)
            end
        -- print("Bound", k, v)
        end
    end

    if payload and not InCombatLockdown() then
        if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
            local selected = playerSpec() and tostring(C_ClassTalents.GetLastSelectedSavedConfigID(playerSpec()))
            if
                selected and GSE_C["KeyBindings"][GetSpec()]["LoadOuts"] and
                    GSE_C["KeyBindings"][GetSpec()]["LoadOuts"][selected]
             then
                --@debug@
                GSE.PrintDebugMessage(
                    "changing from " .. tostring(payload) .. " " .. tostring(GSE.GetSelectedLoadoutConfigID()),
                    "EVENTS"
                )
                --@end-debug@
                for k, v in pairs(GSE_C["KeyBindings"][GetSpec()]["LoadOuts"][selected]) do
                    k = normalizeBindKey(k)
                    SetBinding(k)
                    local target = GSE.GetKeybindClickTarget(v)
                    SetBindingClick(k, target, "LeftButton")
                    if GSE.GameMode == 5 then
                        SetOverrideBindingClick(keybindingframe, false, k, target)
                    end
                end
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
end

function GSE.CreateActionBarOverride(buttonName, sequenceName)
    if InCombatLockdown() then return end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        GSE_C["ActionBarBinds"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"]) then
        GSE_C["ActionBarBinds"]["Specialisations"] = {}
    end
    if GSE.isEmpty(GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()]) then
        GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()] = {}
    end
    local bind = {
        Bind = buttonName,
        Sequence = sequenceName
    }
    GSE_C["ActionBarBinds"]["Specialisations"][GetSpec()][buttonName] = bind
    GSE.ReloadOverrides()
end

function GSE.RemoveActionBarOverride(buttonName)
    if InCombatLockdown() then return end
    local spec = GetSpec()
    if not GSE.isEmpty(GSE_C["ActionBarBinds"]) then
        local specs = GSE_C["ActionBarBinds"]["Specialisations"]
        if specs and specs[spec] then
            specs[spec][buttonName] = nil
        end
        local loadouts = GSE_C["ActionBarBinds"]["LoadOuts"]
        if loadouts and loadouts[spec] then
            for _, loadout in pairs(loadouts[spec]) do
                if type(loadout) == "table" then
                    loadout[buttonName] = nil
                end
            end
        end
    end
    GSE.ReloadOverrides()
end

function GSE.ReloadKeyBindings()
    LoadKeyBindings(true)
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
    LoadKeyBindings(true)
    GSE.PerformReloadSequences(true)
    hookActionButtonUpdate()
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
    local char = UnitFullName("player")
    local realm = GetRealmName()
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

    if GSE.isEmpty(GSESequences[GSE.GetCurrentClassID()]) then
        GSESequences[GSE.GetCurrentClassID()] = {}
    end
    if GSE.isEmpty(GSE.Library[GSE.GetCurrentClassID()]) then
        GSE.Library[GSE.GetCurrentClassID()] = {}
    end
    if GSE.isEmpty(GSE.Library[0]) then
        GSE.Library[0] = {}
    end
    if GSE.isEmpty(GSEVariables) then
        GSEVariables = {}
    end
    if GSE.isEmpty(GSEMacros) then
        GSEMacros = {}
    end
    if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
        GSEMacros[char .. "-" .. realm] = {}
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
                        vals.sequencename = k
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
end

function GSE:PLAYER_SPECIALIZATION_CHANGED()
    if GSE.isEmpty(GSE_C["KeyBindings"][GetSpec()]) then
        GSE_C["KeyBindings"][GetSpec()] = {}
    end
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
                    GSE.OOCUpdateSequence(v.name, v.macroversion)
                end
            elseif v.action == "Save" then
                GSE.OOCAddSequenceToCollection(v.sequencename, v.sequence, v.classid)
            elseif v.action == "Replace" then
                if GSE.isEmpty(GSE.Library[v.classid][v.sequencename]) then
                    GSE.AddSequenceToCollection(v.sequencename, v.sequence, v.classid)
                else
                    GSE.ReplaceSequence(v.classid, v.sequencename, v.sequence)
                    local macroVersion = v.sequence.Versions[GSE.GetActiveSequenceVersion(v.sequencename)]
                    if encounterInProgress then
                        GSE.UpdateSequence(v.sequencename, macroVersion)
                    else
                        GSE.OOCUpdateSequence(v.sequencename, macroVersion)
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
            elseif v.action == "CheckMacroCreated" then
                GSE.OOCCheckMacroCreated(v.sequencename, v.create)
            elseif v.action == "MergeSequence" then
                GSE.OOCPerformMergeAction(v.mergeaction, v.classid, v.sequencename, v.newSequence)
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
            elseif v.action == "deletesequence" then
                -- Generic OOC sequence delete. Used by the Companion bridge
                -- after the user confirms a delete (the website record has
                -- already been soft-deleted by the time we get here) and
                -- could be used by future Mod UI paths that need to delete
                -- out-of-combat. classid resolved at enqueue time.
                if v.sequencename and v.classid and tonumber(v.classid) and tonumber(v.classid) > 0 then
                    GSE.DeleteSequence(tonumber(v.classid), v.sequencename)
                end
            elseif v.action == "renamesequence" then
                -- True in-place rename: moves the Library/GSESequences entry
                -- from oldname → sequencename, preserving PlatformID so the
                -- GSE.Tools record stays associated with the renamed sequence.
                if v.oldname and v.sequencename and v.classid and v.sequence then
                    local ok = GSE.RenameSequence(v.classid, v.oldname, v.sequencename, v.sequence)
                    if ok then
                        local macroVersion = v.sequence.Versions and
                            v.sequence.Versions[GSE.GetActiveSequenceVersion(v.sequencename)]
                        if macroVersion then
                            if encounterInProgress then
                                GSE.UpdateSequence(v.sequencename, macroVersion)
                            else
                                GSE.OOCUpdateSequence(v.sequencename, macroVersion)
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

