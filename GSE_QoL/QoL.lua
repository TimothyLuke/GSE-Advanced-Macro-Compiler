local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local L = GSE.L

-- ============================================================================
-- Macro Insertion Toolbar moved to the GSE_MacroToolbar addon.
-- This file now contains the native icon picker, OnBuildIconMenu, Patron
-- sequence checksum stamper, and the Skyriding Bind Bar (Retail only).
-- See GSE_MacroToolbar/MacroToolbar.lua for the toolbar code.
-- ============================================================================


-- Native WoW icon picker, owned by GSE.
--
-- Pattern lifted from Jaliborc/BagBrother config/panels/ruleEdit.lua Ã¢â‚¬â€
-- the only public addon I found that successfully creates a STANDALONE
-- popup from IconSelectorPopupFrameTemplate (rather than borrowing
-- Blizzard's MacroPopupFrame, which is hard-coupled to MacroFrame and
-- silently does nothing when shown without it). Critical bits the
-- earlier "obvious" implementation missed:
--   * Explicit SetSize Ã¢â‚¬â€ the template's XML <Size> doesn't reliably
--     apply to a CreateFrame'd virtual template instance.
--   * Explicit SetPoint on `IconSelector` inside `BorderBox`. Without
--     this the icon grid has no anchor, so even though the popup is
--     "showing" you see nothing render.
--   * iconDataProvider + SetSelectionsDataProvider + SelectedCallback
--     wired ONCE at frame creation, not per-show. The template mixin
--     already provides GetIconByIndex/GetNumIcons/GetIndexOfIcon as
--     dataProvider proxies, so we don't redefine them.
--   * No OnShow / OnHide override needed Ã¢â‚¬â€ the template's own OnShow
--     handles event registration; we just position once.
local iconPickerCallback = nil
local iconPickerFrame = nil

local function buildIconPickerFrame()
    if iconPickerFrame then return iconPickerFrame end
    if not IconSelectorPopupFrameTemplateMixin then return nil end

    local f = CreateFrame("Frame", "GSE_IconSelectorPopupFrame", UIParent, "IconSelectorPopupFrameTemplate")
    f:Hide()
    -- The template's instantiation adds its own anchor (TOPLEFT to UIParent),
    -- so a plain SetPoint("CENTER") gets queued AFTER it -- GetPoint(1)
    -- returns TOPLEFT and the popup paints in the screen's top-left corner
    -- (behind addon trays, easy to miss). MakePopup's center=true clears
    -- all points first, then anchors centre -- same pattern Jaliborc/
    -- BagBrother uses.
    GSE.UI.MakePopup(f, {center = true, movable = true})

    -- Strip the macro-name workflow Blizzard's template assumes Ã¢â‚¬â€ the
    -- name editbox, its header label, the "Currently Selected" preview
    -- on the right, and the Okay button itself are all geared toward
    -- creating/editing a named macro. We just want "click an icon Ã¢â€ â€™
    -- return it." Hide them all and skip the Okay-button confirm step.
    if f.BorderBox then
        if f.BorderBox.IconSelectorEditBox    then f.BorderBox.IconSelectorEditBox:Hide() end
        if f.BorderBox.EditBoxHeaderText      then f.BorderBox.EditBoxHeaderText:Hide() end
        if f.BorderBox.SelectedIconArea       then f.BorderBox.SelectedIconArea:Hide() end
        if f.BorderBox.OkayButton             then f.BorderBox.OkayButton:Hide() end
    end

    -- Initialise the icon data provider ONCE. Methods GetIconByIndex /
    -- GetNumIcons / GetIndexOfIcon are inherited from
    -- IconSelectorPopupFrameTemplateMixin and auto-proxy through this.
    f.iconDataProvider = CreateAndInitFromMixin(
        IconDataProviderMixin, IconDataProviderExtraType.None)

    -- The icon grid needs an explicit anchor inside the BorderBox.
    -- Anchored higher than BagBrother's offset because we hid the
    -- name-entry section above it.
    f.IconSelector:ClearAllPoints()
    f.IconSelector:SetPoint("TOPLEFT", f.BorderBox, "TOPLEFT", 21, -56)
    f.IconSelector:SetSelectionsDataProvider(
        GenerateClosure(f.GetIconByIndex, f),
        GenerateClosure(f.GetNumIcons,    f))

    -- Single-click commit: as soon as the user picks an icon, fire the
    -- callback and hide. Cancel button still works normally Ã¢â‚¬â€ the user
    -- can dismiss without a selection. No Okay-button round-trip.
    f.IconSelector:SetSelectedCallback(function(_, icon)
        if iconPickerCallback and icon then
            local cb = iconPickerCallback
            iconPickerCallback = nil
            cb(icon)
        end
        f:Hide()
    end)

    -- Trim the popup height since we removed the top section.
    f:SetSize(525, 460)

    -- Cancel still works Ã¢â‚¬â€ clear pending callback so a later Show
    -- doesn't accidentally fire it.
    function f:CancelButton_OnClick()
        IconSelectorPopupFrameTemplateMixin.CancelButton_OnClick(self)
        iconPickerCallback = nil
    end

    iconPickerFrame = f
    return f
end

local function ShowNativeIconPicker(callback)
    local f = buildIconPickerFrame()
    if not f then
        GSE.Print("|cffff6666GSE QoL:|r icon picker template unavailable.", "Error")
        return
    end
    iconPickerCallback = callback
    -- Scroll the grid to its top on each open so it renders cleanly.
    -- Wrapped in pcall because the icon data provider can lazy-init
    -- and throw on the first show after a /reload Ã¢â‚¬â€ when invoked from
    -- inside a context-menu callback the menu system swallows errors
    -- silently and the user just sees nothing happen.
    local ok, err = pcall(function()
        if f.IconSelector and f.iconDataProvider and f.iconDataProvider:GetNumIcons() > 0 then
            f.IconSelector:SetSelectedIndex(1)
            f.IconSelector:ScrollToSelectedIndex()
        end
    end)
    if not ok then
        GSE.Print("|cffff6666GSE QoL:|r icon picker init failed: " .. tostring(err), "Error")
    end
    f:Show()
end
if GSE.WagoAnalytics then
    GSE.WagoAnalytics:Switch("Patron", true)
end

-- Editor capability: allow more than one editor window open at once.
GSE.CanMultiWindow = function() return true end

-- Editor capability: show the Raw Edit button.
GSE.CanRawEdit = function() return true end

-- Appended to the icon context menu in the editor for QoL users.
GSE.OnBuildIconMenu = function(rootDescription, lbl, sequence, version, keyPath)
    rootDescription:CreateDivider()
    rootDescription:CreateButton(L["Choose any icon..."], function()
        ShowNativeIconPicker(function(iconID)
            lbl:SetText("|T" .. iconID .. ":0|t")
            sequence.Versions[version].Actions[keyPath].Icon = iconID
            sequence.Versions[version].Actions[keyPath].IconUserSelected = true
        end)
    end)
end

-- Stamp the checksum onto the locally saved sequence on every save.
local function onSequenceSaved(_, sequenceName)
    if not GSE.ComputeSequenceChecksum then return end
    for classid = 0, 13 do
        local seq = GSE.Library[classid] and GSE.Library[classid][sequenceName]
        if seq and seq.MetaData then
            seq.MetaData.Checksum = GSE.ComputeSequenceChecksum(seq)
            GSESequences[classid][sequenceName] = GSE.EncodeMessage({sequenceName, seq})
            break
        end
    end
end
GSE:RegisterMessage(Statics.Messages.SEQUENCE_UPDATED, onSequenceSaved)

-- MS Click Timing options, added to GSE's General options page (Options.lua calls
-- this hook when present). Used for PAUSE block calculations.
local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback or minimum
    if value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return math.floor(value + 0.5)
end
GSE.OnBuildClickTimingOptions = function(optionsCategory)
    do
        local layout = SettingsPanel:GetLayout(optionsCategory)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = "MS Click Timing", ["tooltip"] = "Used for PAUSE Block Calculations"}))
    end

    if GSE.isEmpty(GSE_C) then GSE_C = {} end
    do
        local function GetValue()
            GSE_C.msClickRate = ClampNumber(GSE_C.msClickRate, 100, 1000, 250)
            return GSE_C.msClickRate
        end
        local function SetValue(value)
            GSE_C.msClickRate = ClampNumber(value, 100, 1000, 250)
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "charmsClickRate", Settings.VarType.Number, "This Character - MS Click Rate", 250, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(100, 1000, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["The milliseconds being used in key click delay."])
    end

    do
        local function GetValue()
            GSEOptions.msClickRate = ClampNumber(GSEOptions.msClickRate, 100, 1000, 250)
            return GSEOptions.msClickRate
        end
        local function SetValue(value)
            GSEOptions.msClickRate = ClampNumber(value, 100, 1000, 250)
        end
        local setting = Settings.RegisterProxySetting(optionsCategory, "msClickRate", Settings.VarType.Number, "Global Default - MS Click Rate", 250, GetValue, SetValue)
        local options = Settings.CreateSliderOptions(100, 1000, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(optionsCategory, setting, options, L["The milliseconds being used in key click delay."])
    end
end

-- Editor tree context-menu extras (right-click a sequence in the editor tree).
GSE.OnTreeContextMenuExtras = function(rootDescription, ctx)
    rootDescription:CreateButton(
        string.format(L["Open %s in New Window"], ctx.sequencename),
        function()
            local targetGroup = ctx.group
            if ctx.unique[1] == "Sequences" and #ctx.unique == 3 then
                targetGroup = ctx.group .. "\001config"
            elseif ctx.unique[#ctx.unique] == "newversion" then
                targetGroup = table.concat({ctx.unique[1], ctx.unique[2], ctx.unique[3], "config"}, "\001")
            end
            local editor = GSE.CreateEditor()
            editor.ManageTree()
            editor:Show()
            C_Timer.After(0, function()
                if GSE.GUI.SelectEditorTreePath then
                    GSE.GUI.SelectEditorTreePath(editor, targetGroup)
                end
            end)
        end
    )
end

-- Player spellbook enumeration for the Tab spell list. The pre-#1914 QoL
-- kept an event-refreshed playerSpells cache; enumerating on demand at
-- menu-open time is fast enough (one pass over the spellbook) and cannot
-- go stale, so the cache and its AceEvent plumbing were not restored.
--
-- Two spellbook APIs, and the choice is made per FUNCTION rather than per
-- table. Checking `C_SpellBook` alone is not enough: TBC Classic Anniversary
-- and MoP Classic expose C_SpellBook while missing parts of it — the same
-- trap that produced ~179 errors per save in #1925, see the comment on
-- spellIDIsInSpellBook in GSE/API/translator.lua. A client with a partial
-- C_SpellBook needs the legacy path, so require every function the modern
-- loop actually calls before choosing it.
local function getPlayerSpells()
    local spells, seen = {}, {}
    local function add(name)
        -- Dedupe by name. Classic lists one entry per RANK, and a macro wants
        -- the name only — /cast <name> already picks the highest rank known.
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            spells[#spells + 1] = name
        end
    end

    local numSkillLines = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
    local skillLineInfo = C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo
    local modernItemInfo = C_SpellBook and C_SpellBook.GetSpellBookItemInfo

    if numSkillLines and skillLineInfo and modernItemInfo then
        -- Retail and any Classic client with the full modern API. Skill line 1
        -- is General; the pre-#1914 list started at 2 and that is kept.
        for tab = 2, numSkillLines() do
            local lineinfo = skillLineInfo(tab)
            if not lineinfo then break end
            local offset = lineinfo.itemIndexOffset or 0
            for i = 1, lineinfo.numSpellBookItems or 0 do
                local spellinfo = modernItemInfo(i + offset, 0)
                if spellinfo and spellinfo.name and not spellinfo.isPassive and not spellinfo.isOffSpec then
                    add(spellinfo.name)
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        -- Classic: tabs instead of skill lines, every lookup takes a book type,
        -- and passive/offspec live behind separate calls rather than fields on
        -- an info table. Before this, Classic fell through the C_SpellBook
        -- guard and the menu offered an empty Insert Spell list.
        local bookType = BOOKTYPE_SPELL or "spell"
        for tab = 2, GetNumSpellTabs() do
            local _, _, offset, numSlots, _, offSpecID = GetSpellTabInfo(tab)
            -- offSpecID is Cata+ only; nil on older clients, 0 for the active
            -- spec. Anything else is another spec's book and is skipped, which
            -- is what isOffSpec does on the modern path.
            if offset and numSlots and (offSpecID == nil or offSpecID == 0) then
                for i = offset + 1, offset + numSlots do
                    -- "FUTURESPELL" is a not-yet-learned row shown greyed out;
                    -- only "SPELL" is castable. A client without the info call
                    -- still lists names rather than nothing.
                    local itemType = GetSpellBookItemInfo and GetSpellBookItemInfo(i, bookType)
                    local passive = IsPassiveSpell and IsPassiveSpell(i, bookType)
                    if (itemType == nil or itemType == "SPELL") and not passive then
                        add((GetSpellBookItemName(i, bookType)))
                    end
                end
            end
        end
    end

    table.sort(spells)
    return spells
end

-- Tab spell list for the Action block (restores the pre-#1914 Patron
-- feature lost when the Macro Insertion Toolbar moved to GSE_MacroToolbar).
-- Spell field: pick a spell (stores via the field's own handlers) or a
-- variable. Macro commands box: insert the spell name / variable at the
-- cursor; the box's OnTextChanged owns storage, nothing else is written.
GSE.OnEditorSpellTab = function(widget, menuOwner, apply)
    local editBox = widget and (widget.editBox or widget.editbox)
    if not editBox then return end
    editBox:SetScript("OnTabPressed", function()
        MenuUtil.CreateContextMenu(editBox, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Insert Spell"])
            for _, v in ipairs(getPlayerSpells()) do
                rootDescription:CreateButton(v, function() apply(v) end)
            end
            rootDescription:CreateTitle(L["Insert GSE Variable"])
            for k, _ in pairs(GSEVariables) do
                rootDescription:CreateButton(k, function() apply([[=GSE.V["]] .. k .. [["]()]]) end)
            end
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Tab autofill menu for the macro-commands box (Patron). Five top-level
-- categories with flyouts: Commands / Conditionals / Spells / Macros /
-- GSE Variables. Static lists are authored by Larry; Spells, Macros and
-- Variables are live. Insertion is caret-aware (see insertSmart).
-- ---------------------------------------------------------------------------
local TAB_COMMANDS = {
    "/cast", "/castsequence", "/use", "/stopmacro", "/stopcasting", "/cancelaura",
    "/cancelform", "/targetenemy", "/targetlasttarget", "/cleartarget", "/focus",
    "/startattack", "/stopattack", "/petattack", "/petfollow", "/petpassive", "/ping",
}
local TAB_RESET_VALUES = { "combat", "target", "5", "10", "15", "20", "30", "45", "60" }
-- Whole lines people write over and over in sequences: inserted exactly as
-- written, as their own row.
local TAB_BOILERPLATES = {
    "/targetenemy [noharm][dead]",
    "/startattack",
    "/stopmacro",
    "/stopmacro [channeling]",
    "/stopmacro [@playertarget,noexists][channeling]",
    "/cqs",
    "/cast [@player]",
    "/cast [@cursor]",
    "/cast [nomounted]",
    "/cast [nostealth] Stealth",
    "/cast [@mouseover,combat][@targettarget,combat][combat]",
    "/cast [help,@mouseover,exists]",
    "/cast [harm,@mouseover,exists]",
    "/cast [help,@focus,nodead,exists]",
    "/cast [help,@focus,exists,combat][combat]",
    "/castsequence [help,@mouseover,exists]",
    "/castsequence [harm,@mouseover,exists]",
    "/use [combat]",
    "/use [@pet,dead]",
    "/use [nopet,nodead] Call Pet",
    "/petattack [harm,combat]",
    "/ping [harm,@target,exists,group:scenario] attack",
    "/cast [harm] Single-Button Assistant",
}
local TAB_CONDITIONALS = {
    { "Modifiers", {
        "mod", "nomod", "mod:shift", "mod:shiftctrl", "mod:shiftalt",
        "mod:ctrl", "mod:ctrlalt", "mod:alt",
    }},
    { "Combat", {
        "combat", "nocombat", "stealth", "nostealth", "pvpcombat",
        "channeling", "nochanneling", "mounted", "nomounted", "flying", "noflying",
        "swimming", "indoors", "outdoors",
    }},
    { "Target", {
        "@target", "@targettarget", "@focus", "@focustarget", "@mouseover", "@mouseovertarget",
        "@pet", "@pettarget", "@player", "@cursor",
        "exists", "noexists", "help", "nohelp", "harm", "noharm", "dead", "nodead",
        "party", "noparty", "raid", "noraid",
        "@none", "@arena1", "@arena2", "@arena3", "@boss1", "@boss2",
        "@party1", "@party2", "@party3", "@party4",
    }},
    { "Character", {
        "spec:1", "spec:2", "spec:3", "spec:4",
        "form:0", "form:1", "form:2", "form:3", "form:4", "form:5", "form:6",
        "stance:0", "stance:1", "stance:2", "stance:3",
        "known:ID", "pet", "nopet", "group:party", "group:raid", "group:scenario", "nogroup",
        "flyable", "advflyable", "canexitvehicle",
    }},
}

-- Names of GSE-managed in-game macros (the editor's Macros section).
local function getManagedMacroNames()
    local names, seen = {}, {}
    local function isMacroNode(v)
        return type(v) == "table" and (v.text ~= nil or v.icon ~= nil or v.value ~= nil
            or v.Managed ~= nil or v.managedMacro ~= nil or v.manageMacro ~= nil)
    end
    if type(GSEMacros) == "table" then
        for k, v in pairs(GSEMacros) do
            if isMacroNode(v) then
                if not seen[k] then seen[k] = true; names[#names + 1] = k end
            elseif type(v) == "table" then -- per-character bucket
                for k2, v2 in pairs(v) do
                    if isMacroNode(v2) and not seen[k2] then seen[k2] = true; names[#names + 1] = k2 end
                end
            end
        end
    end
    table.sort(names)
    return names
end

GSE.OnEditorMacroBlockTab = function(widget, menuOwner)
    local editBox = widget and (widget.editBox or widget.editbox)
    if not editBox then return end
    editBox:SetScript("OnTabPressed", function()
        -- Line-builder session. The bracket group is NEVER left open in the text:
        -- every conditional pick rewrites the whole group in place ([a] -> [a,b]),
        -- so the text is always valid and no menu-close event is needed (Blizzard
        -- menus release/re-acquire unpredictably during navigation and refresh --
        -- probe-proven -- so nothing here depends on their lifecycle).
        local buildMenu -- forward declaration: pickCommand reopens the menu with it
        -- Every gate-changing pick reopens the menu, and MenuUtil.CreateContextMenu
        -- anchors at the MOUSE -- so each reopen re-anchored under the row just
        -- clicked and the menu walked across the screen. Blizzard's manager takes
        -- an explicit anchor (MenuManagerMixin:OpenMenu, public via the proxy), so
        -- pin the menu under the macro box for the whole build session. Falls back
        -- to the cursor-anchored path if any piece is missing on older flavours.
        local function openMenu()
            local mgr = Menu and Menu.GetManager and Menu.GetManager()
            if mgr and mgr.OpenMenu and AnchorUtil and AnchorUtil.CreateAnchor
                and MenuUtil.CreateRootMenuDescription and Menu.PopulateDescription then
                local mixin = editBox.menuMixin
                    or (MenuVariants and MenuVariants.GetDefaultContextMenuMixin
                        and MenuVariants.GetDefaultContextMenuMixin())
                local desc = MenuUtil.CreateRootMenuDescription(mixin)
                Menu.PopulateDescription(buildMenu, editBox, desc)
                mgr:OpenMenu(editBox, desc, AnchorUtil.CreateAnchor("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2))
                return
            end
            MenuUtil.CreateContextMenu(editBox, buildMenu)
        end
        -- Start every session on DECODED text: colour codes injected by repaints
        -- between sessions make raw offsets lie (splices landed inside escape
        -- sequences and shredded them). Strip the codes, remap the caret to its
        -- visible position, and run all session math on plain text; colouring
        -- returns after the session via the normal repaint paths.
        local function stripCodes(t)
            t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            t = t:gsub("|c%x*$", ""):gsub("|$", "")
            return t
        end
        local rawText = editBox:GetText() or ""
        local caretPos = (editBox.GetCursorPosition and editBox:GetCursorPosition()) or #rawText
        local decoded = (GSE.DecodeMacroEditorText and GSE.DecodeMacroEditorText(rawText)) or stripCodes(rawText)
        if decoded ~= rawText then
            local mapped = #stripCodes(rawText:sub(1, caretPos))
            editBox:SetText(decoded)
            if editBox.SetCursorPosition then editBox:SetCursorPosition(mapped) end
            caretPos = mapped
            widget.gseRecolourToken = (widget.gseRecolourToken or 0) + 1
        end
        local cursor = caretPos
        -- the builder always appends to the caret's LINE END (rule of thumb:
        -- Commands > Conditionals > Reset > Spells; a parked mid-line caret
        -- must not scatter picks into the middle of the line)
        local groupTokens = {}
        local groupStart, groupLen = nil, 0
        local resetStart, resetLen, resetValues = nil, 0, {}
        local condBase -- canonical slot for a new group: right after the command

        -- Editor.lua's focus-loss commit repaint would inject colour codes and
        -- shift these raw offsets; suppress it with a rolling deadline that
        -- self-expires shortly after the last pick.
        local function touchSession()
            editBox.gseTabSessionUntil = GetTime() + 2
        end
        touchSession()

        -- A repaint can sneak colour codes back into the box mid-session
        -- (probe-proven: 47 plain chars -> 95 coloured between two picks), so
        -- EVERY session read runs on decoded text and every splice writes
        -- decoded text back -- the session is colour-proof by construction.
        local function plainFull()
            local f = editBox:GetText() or ""
            return (f:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
        local function rowBeforeCaret()
            local full = plainFull()
            return full:sub(1, math.min(cursor, #full)):match("([^\n]*)$") or ""
        end
        -- "Need Stuff Here" is the new-block placeholder, not content.
        local rawBox = decoded
        local boxIsPlaceholder = tostring(rawBox):match("^%s*Need Stuff Here%s*$") ~= nil

        -- One undo step per pick: the text IS the state (adoptClause re-derives
        -- everything from it), so snapshotting text + caret is enough to walk
        -- back a misclick.
        local history = {}
        local function pushHistory()
            history[#history + 1] = {
                -- decoded: cursor offsets are plain-text offsets, so a snapshot
                -- that still held colour codes would restore a shifted caret
                text = plainFull(),
                cursor = cursor,
                placeholder = boxIsPlaceholder,
            }
        end
        -- Splice `text` in at [at, at+replacing) via SetText: Insert() depends on
        -- the live caret and the box is unfocused while the menu is up.
        local function splice(at, replacing, text)
            touchSession()
            pushHistory()
            if boxIsPlaceholder then
                editBox:SetText(text)
                boxIsPlaceholder = false
                cursor = #text
            else
                local full = plainFull()
                at = math.max(0, math.min(at, #full))
                editBox:SetText(full:sub(1, at) .. text .. full:sub(at + replacing + 1))
                cursor = at + #text
            end
            if editBox.SetCursorPosition then editBox:SetCursorPosition(cursor) end
            -- cancel the debounced live repaint the SetText just scheduled
            widget.gseRecolourToken = (widget.gseRecolourToken or 0) + 1
        end
        local function resetGroup() groupTokens = {}; groupStart, groupLen = nil, 0 end
        local function undoLast()
            local prev = table.remove(history)
            if not prev then return MenuResponse.Refresh end
            touchSession()
            editBox:SetText(prev.text)
            cursor = prev.cursor
            boxIsPlaceholder = prev.placeholder
            if editBox.SetCursorPosition then editBox:SetCursorPosition(cursor) end
            widget.gseRecolourToken = (widget.gseRecolourToken or 0) + 1
            -- every gate can change on an undo, so rebuild the menu
            C_Timer.After(0, openMenu)
            return MenuResponse.Close
        end
        -- True end of the current row (next newline after the build cursor, or
        -- end of text): ,nil and ; must land at the END of the line regardless
        -- of where the build cursor sits.
        local function lineEndPos()
            local full = plainFull()
            local at = math.min(cursor, #full)
            local nl = full:find("\n", at + 1, true)
            return (nl and nl - 1) or #full
        end
        local function currentLineText()
            local full = plainFull()
            local endPos = lineEndPos()
            local startPos = 1
            for i = math.min(cursor, #full), 1, -1 do
                if full:sub(i, i) == string.char(10) then startPos = i + 1 break end
            end
            return full:sub(startPos, endPos)
        end
        cursor = lineEndPos()
        -- Stored macro text often ends with a newline; a caret parked on that
        -- blank trailing line would make the session build on an empty row and
        -- grey every clause-gated entry. Snap to the end of the last line that
        -- has content (a Command pick still starts its own new row from there).
        if currentLineText():match("^%s*$") then
            local fullText = plainFull()
            local lastContent = fullText:find("%S%s*$")
            if lastContent then
                cursor = lastContent
                cursor = lineEndPos()
            end
        end
        -- Re-derive the clause state from the LIVE text -- the text is the single
        -- source of truth. Tracked offsets go stale the moment a pick ends a
        -- clause (a spell or ';' clears the group) or the author types between
        -- picks, which is how a second conditional ended up in its own bracket
        -- instead of merging into the one already on the line. Run at session
        -- start AND before every conditional/reset pick so the canonical order
        -- (Command > Conditionals > Reset > Spells) always holds: an existing
        -- [group] is merged into, an existing reset= extended, and a new group
        -- opens right after the command (or the "; ") -- never after the spells.
        local function adoptClause()
            groupTokens, groupStart, groupLen = {}, nil, 0
            resetStart, resetLen, resetValues = nil, 0, {}
            condBase = nil
            local endPos = lineEndPos()
            local line = currentLineText()
            local lineStart0 = endPos - #line
            local ci, cj = line:find("^%s*/%S+%s?")
            if cj then condBase = lineStart0 + cj end
            -- a ';' starts a new clause with its own group + reset=: adopt only
            -- the tail after the LAST ';' so a re-Tab keeps building the clause
            -- in progress instead of merging into an earlier one.
            local base = line:find(";[^;]*$") or 0
            if base > 0 then
                condBase = lineStart0 + base + #(line:sub(base + 1):match("^%s*") or "")
            end
            local tail = line:sub(base + 1)
            local gi, gj = tail:find("%[.-%]")
            if gi then
                local seg = tail:sub(gi + 1, gj - 1)
                if tail:sub(gj + 1, gj + 1) == " " then gj = gj + 1 end
                groupStart = lineStart0 + base + gi - 1
                groupLen = gj - gi + 1
                for tok in seg:gmatch("[^,]+") do
                    groupTokens[#groupTokens + 1] = tok:match("^%s*(.-)%s*$")
                end
            end
            local ri, rj = tail:find("reset=%S+")
            if ri then
                local vals = tail:sub(ri + 6, rj)
                if tail:sub(rj + 1, rj + 1) == " " then rj = rj + 1 end
                resetStart = lineStart0 + base + ri - 1
                resetLen = rj - ri + 1
                for v in vals:gmatch("[^/]+") do resetValues[#resetValues + 1] = v end
            end
        end
        adoptClause()

        -- Command: inline on an empty row, otherwise a new row. Starts a fresh line build.
        local function pickCommand(cmd)
            resetGroup()
            resetStart, resetLen, resetValues = nil, 0, {}
            local row = rowBeforeCaret()
            if row:match("^%s*$") then splice(cursor, 0, cmd .. " ")
            else splice(cursor, 0, "\n" .. cmd .. " ") end
            -- Refresh does not reliably re-run the root generator (probe-proven),
            -- so gates like Reset would stay stale: close and reopen for a full
            -- regeneration instead.
            condBase = cursor
            C_Timer.After(0, openMenu)
            return MenuResponse.Close
        end
        -- Boiler plate: a whole ready-made line, inserted verbatim. Same
        -- placement rule as a command pick (inline on an empty row, otherwise a
        -- new row); the menu reopens so the line can be built on further.
        local function pickBoilerplate(text)
            resetGroup()
            resetStart, resetLen, resetValues = nil, 0, {}
            local row = rowBeforeCaret()
            if row:match("^%s*$") then splice(cursor, 0, text)
            else splice(cursor, 0, "\n" .. text) end
            C_Timer.After(0, openMenu)
            return MenuResponse.Close
        end
        -- Conditional: rewrite the group in place, always closed: [a] -> [a,b] -> [a,b,c]
        local function pickConditional(token)
            adoptClause()
            -- Conditionals belong BEFORE reset=: if a reset segment already
            -- exists, open the group at its start and push it right.
            if not groupStart then groupStart = condBase or resetStart or cursor end
            -- Same-family colon tokens collapse into WoW's multi-value form:
            -- picking spec:1 then spec:2 yields spec:1/2 (an OR), never
            -- spec:1,spec:2 (an AND that could not be true). Applies to any
            -- prefix:value family (spec/form/stance/mod/group/known...).
            local prefix, value = token:match("^([^:]+):(.+)$")
            local collapsed = false
            if prefix then
                for i, existing in ipairs(groupTokens) do
                    if existing == prefix or existing:match("^([^:]+):") == prefix then
                        -- dedupe: picking the same value twice adds it once
                        local values = existing:match("^[^:]+:(.+)$") or ""
                        local dupe = false
                        for v in (values .. "/"):gmatch("([^/]+)/") do
                            if v == value then dupe = true break end
                        end
                        if not dupe then
                            groupTokens[i] = existing:find(":") and (existing .. "/" .. value)
                                or (existing .. ":" .. value)
                        end
                        collapsed = true
                        break
                    end
                end
            end
            if not collapsed then groupTokens[#groupTokens + 1] = token end
            local segment = "[" .. table.concat(groupTokens, ",") .. "] "
            splice(groupStart, groupLen, segment)
            local delta = #segment - groupLen
            groupLen = #segment
            if resetStart and resetStart >= groupStart then
                resetStart = resetStart + delta
            end
            -- keep the build caret at the END of the line (after any reset=)
            cursor = resetStart and (resetStart + resetLen) or (groupStart + groupLen)
            if editBox.SetCursorPosition then editBox:SetCursorPosition(cursor) end
            return MenuResponse.Refresh
        end
        -- reset= (castsequence only): its own tracked segment, values collapse
        -- into one reset= token with "/" and dedupe, e.g. reset=combat/target/5.
        local function pickReset(value)
            adoptClause()
            for _, v in ipairs(resetValues) do if v == value then return MenuResponse.Refresh end end
            local firstReset = not resetStart
            -- canonical slot: reset= sits AFTER the [group] (or the command /
            -- the "; " that opened this clause) and BEFORE the spells -- never
            -- at the caret, which may sit past spells already on the clause.
            if not resetStart then
                resetStart = (groupStart and (groupStart + groupLen)) or condBase or cursor
            end
            -- only ONE number is valid in a reset=; a second numeric pick
            -- REPLACES the existing number instead of adding another
            local replaced = false
            if tonumber(value) then
                for i, v in ipairs(resetValues) do
                    if tonumber(v) then resetValues[i] = value; replaced = true; break end
                end
            end
            if not replaced then resetValues[#resetValues + 1] = value end
            local segment = "reset=" .. table.concat(resetValues, "/") .. " "
            splice(resetStart, resetLen, segment)
            resetLen = #segment
            if firstReset then
                -- the ,nil gate depends on reset= being present; a plain Refresh
                -- does not re-run the root generator, so reopen for a fresh build
                C_Timer.After(0, openMenu)
                return MenuResponse.Close
            end
            return MenuResponse.Refresh
        end
        -- True when the text after the LAST ';' ends with a spell name --
        -- the shared test for "does a ', ' separator / a ';' belong here".
        -- ';' starts a fresh clause, so only the tail after it counts.
        local function clauseEndsWithSpell(line)
            local clause = line:gsub("%s+$", "")
            if clause == "" or not clause:find("/", 1, true) then return false end
            local tail = (clause:match("[^;]*$") or ""):gsub("^%s+", ""):gsub("%s+$", "")
            return tail ~= ""
                and tail:match("/%S+$") == nil          -- not just the command
                and tail:match("%]$") == nil            -- not ending on a bracket group
                and tail:match("reset=%S*$") == nil     -- not ending on reset=
                and tail:match(",%s*nil$") == nil       -- not after a ,nil ender
        end
        -- An empty [] group closes the line's conditions: it lands at the END of
        -- the bracket run ("[stuff,stuff][]"), or opens one on a bare command
        -- ("/cast []"). A run already ending in [] is left alone.
        local function pickEmptyGroup()
            adoptClause()
            if not groupStart then
                splice(condBase or resetStart or cursor, 0, "[] ")
                return MenuResponse.Refresh
            end
            local full = plainFull()
            local pos, last = groupStart + 1, nil
            while true do
                local i, j = full:find("^%s*%[[^%]]*%]", pos)
                if not i then break end
                last = j
                pos = j + 1
            end
            if not last then return MenuResponse.Refresh end
            if full:sub(last - 1, last) == "[]" then return MenuResponse.Refresh end
            splice(last, 0, "[]")
            return MenuResponse.Refresh
        end
        -- Spell: lands at the line end -- but BEFORE a trailing ", nil" line
        -- ender -- and takes a ", " separator when the clause already ends
        -- with a spell (castsequence style). Ends the session.
        local function pickSpell(name)
            local endPos = lineEndPos()
            local line = currentLineText()
            local insertAt = endPos
            local clause = line
            local nilS = line:find(",%s*nil%s*$")
            if nilS then
                insertAt = endPos - (#line - nilS + 1)
                clause = line:sub(1, nilS - 1)
            end
            local text = (clauseEndsWithSpell(clause) and ", " or "") .. name
            splice(insertAt, 0, text)
            cursor = lineEndPos()
            if editBox.SetCursorPosition then editBox:SetCursorPosition(cursor) end
            resetGroup()
            -- the ';' and ', nil' gates change once a spell lands; a plain
            -- Refresh does not re-run the root generator, so reopen fresh
            C_Timer.After(0, openMenu)
            return MenuResponse.Close
        end

        -- Block-content rules: a block is EITHER macro text OR a lone macro
        -- name / lone variable call.
        local boxText = tostring(rawBox)
        local boxHasText = not boxText:match("^%s*$") and not boxIsPlaceholder
        local firstChar = boxText:match("^%s*(.)")
        local boxIsNameOrVar = boxHasText and firstChar ~= "/"

        local function greyed(parent, label, why)
            local b = parent:CreateButton("|cFF808080" .. label .. "|r", function() end)
            if b.SetEnabled then b:SetEnabled(false) end
            if b.SetTooltip then
                b:SetTooltip(function(tooltip)
                    GameTooltip_SetTitle(tooltip, label)
                    GameTooltip_AddNormalLine(tooltip, why)
                end)
            end
            return b
        end
        local NAME_ONLY = L["Must be alone in the block - clear the block first."]
        local TEXT_ONLY = L["The block holds a macro name or variable - it must stay alone."]

        local function pickSemicolon()
            -- no space before the ; -- swallow any trailing spaces first
            local endPos = lineEndPos()
            local full = editBox:GetText() or ""
            local wsStart = endPos
            while wsStart > 0 and full:sub(wsStart, wsStart) == " " do wsStart = wsStart - 1 end
            splice(wsStart, endPos - wsStart, "; ")
            -- a ; starts a new clause on the same command: fresh group + reset,
            -- and new conditionals/reset= belong right after the "; "
            resetGroup()
            resetStart, resetLen, resetValues = nil, 0, {}
            condBase = cursor
            -- the ';'/', nil' gates change (new clause is empty); Refresh does
            -- not re-run the root generator, so reopen for a fresh build
            C_Timer.After(0, openMenu)
            return MenuResponse.Close
        end
        local function pickNil()
            splice(lineEndPos(), 0, ", nil")
            editBox.gseTabSessionUntil = 0
            return MenuResponse.Close
        end

        buildMenu = function(ownerRegion, rootDescription)
            -- Block-state rules are evaluated FRESH on every build: the menu is
            -- reopened mid-session (command picks) and a session that started on
            -- an empty block must not leave Macros/Variables open after the
            -- author has built a line into it.
            local live = (editBox:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local liveIsPlaceholder = live:match("^%s*Need Stuff Here%s*$") ~= nil
            local liveHasText = not live:match("^%s*$") and not liveIsPlaceholder
            local liveFirst = live:match("^%s*(.)")
            local liveIsNameOrVar = liveHasText and liveFirst ~= "/"
            -- A fresh line must start with a command before conditionals/spells
            -- can land on it (macros/variables are the whole-block case).
            local NEEDS_CMD = L["Start the line with a command first."]
            local rowHasCmd = currentLineText():match("^%s*/%S") ~= nil

            -- Undo sits at the top: a misclick is fixed without leaving the menu.
            if #history > 0 then
                rootDescription:CreateButton(L["Undo Last"], undoLast)
            else
                greyed(rootDescription, L["Undo Last"], L["Nothing to undo yet."])
            end
            rootDescription:CreateDivider()

            -- Boiler plates: whole lines, so no command is needed on the row first.
            if liveIsNameOrVar then
                greyed(rootDescription, L["Boiler Plates"], TEXT_ONLY)
            else
                local plates = rootDescription:CreateButton(L["Boiler Plates"])
                for _, text in ipairs(TAB_BOILERPLATES) do
                    plates:CreateButton(text, function() return pickBoilerplate(text) end)
                end
            end

            -- Macros / GSE Variables: must be ALONE in the block.
            if liveHasText then
                greyed(rootDescription, L["Macros"], NAME_ONLY)
                greyed(rootDescription, L["GSE Variables"], NAME_ONLY)
            else
                local function setWhole(content)
                    touchSession()
                    editBox:SetText(content)
                    if editBox.SetCursorPosition then editBox:SetCursorPosition(#content) end
                    widget.gseRecolourToken = (widget.gseRecolourToken or 0) + 1
                    editBox.gseTabSessionUntil = 0
                    return MenuResponse.Close
                end
                local macros = rootDescription:CreateButton(L["Macros"])
                for _, name in ipairs(getManagedMacroNames()) do
                    macros:CreateButton(name, function() return setWhole(name) end)
                end
                local vars = rootDescription:CreateButton(L["GSE Variables"])
                for k, _ in pairs(GSEVariables or {}) do
                    vars:CreateButton(k, function() return setWhole([[=GSE.V["]] .. k .. [["]()]]) end)
                end
            end

            if liveIsNameOrVar then
                -- the block holds a macro name / variable: nothing else may join it
                greyed(rootDescription, L["Commands"], TEXT_ONLY)
                greyed(rootDescription, L["Conditionals"], TEXT_ONLY)
                greyed(rootDescription, L["Reset"], TEXT_ONLY)
                greyed(rootDescription, L["Spells"], TEXT_ONLY)
                greyed(rootDescription, ";", TEXT_ONLY)
                greyed(rootDescription, ", nil", TEXT_ONLY)
                return
            end

            local cmds = rootDescription:CreateButton(L["Commands"])
            for _, c in ipairs(TAB_COMMANDS) do
                cmds:CreateButton(c, function() return pickCommand(c) end)
            end

            if rowHasCmd then
                local conds = rootDescription:CreateButton(L["Conditionals"])
                for _, group in ipairs(TAB_CONDITIONALS) do
                    local sub = conds:CreateButton(group[1])
                    for _, token in ipairs(group[2]) do
                        sub:CreateButton(token, function() return pickConditional(token) end)
                    end
                end
                conds:CreateButton("[]", function() return pickEmptyGroup() end)
            else
                greyed(rootDescription, L["Conditionals"], NEEDS_CMD)
            end

            -- Reset: only meaningful on a /castsequence line.
            if rowBeforeCaret():find("/castsequence", 1, true) then
                local resets = rootDescription:CreateButton(L["Reset"])
                for _, v in ipairs(TAB_RESET_VALUES) do
                    resets:CreateButton("reset=" .. v, function() return pickReset(v) end)
                end
            else
                greyed(rootDescription, L["Reset"], L["Only valid after a /castsequence command."])
            end

            if rowHasCmd then
                local spells = rootDescription:CreateButton(L["Spells"])
                for _, v in ipairs(getPlayerSpells()) do
                    spells:CreateButton(v, function() return pickSpell(v) end)
                end
            else
                greyed(rootDescription, L["Spells"], NEEDS_CMD)
            end

            -- ; ends the current clause and starts a new one on the same
            -- command (its own conditionals/reset), at the end of the line.
            local clause = currentLineText():gsub("%s+$", "")
            if clauseEndsWithSpell(clause) then
                rootDescription:CreateButton(";", function() return pickSemicolon() end)
            else
                greyed(rootDescription, ";", L["Only valid after a spell."])
            end

            -- ,nil line-ender: the sequence sticks on nil until the reset fires,
            -- so the spell(s) cast once per reset. Valid only at the end of a
            -- /castsequence clause that has its OWN reset= (';' starts a fresh
            -- clause) and already ends with a spell.
            local row = currentLineText()
            local tailHasReset = (row:match("[^;]*$") or ""):find("reset=", 1, true) ~= nil
            local isCastseq = row:match("^%s*/castsequence") ~= nil
            if isCastseq and tailHasReset and clauseEndsWithSpell(row) then
                rootDescription:CreateButton(", nil", function() return pickNil() end)
            elseif not (isCastseq and tailHasReset) then
                greyed(rootDescription, ", nil", L["Requires a reset= on the line."])
            else
                greyed(rootDescription, ", nil", L["Only valid after a spell."])
            end
        end
        openMenu()
    end)
end

-- Editor Tab-completion menus: press Tab in an editor field to insert a GSE
-- variable / test case (boolean field) or a variable / sequence (managed macro).
GSE.OnEditorBooleanTab = function(editBox, menuOwner, apply)
    editBox:SetScript("OnTabPressed", function()
        MenuUtil.CreateContextMenu(editBox, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Insert GSE Variable"])
            for k, _ in pairs(GSEVariables) do
                rootDescription:CreateButton(k, function() apply([[=GSE.V["]] .. k .. [["]()]]) end)
            end
            rootDescription:CreateTitle(L["Insert Test Case"])
            rootDescription:CreateButton("True", function() apply([[= true]]) end)
            rootDescription:CreateButton("False", function() apply([[= false]]) end)
        end)
    end)
end
GSE.OnEditorMacroTab = function(editBox, menuOwner)
    editBox:SetScript("OnTabPressed", function()
        MenuUtil.CreateContextMenu(editBox, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Insert GSE Variable"])
            for k, _ in pairs(GSEVariables) do
                rootDescription:CreateButton(k, function()
                    editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                end)
            end
            local function insertSeq(k)
                if GSE.GetMacroStringFormat() == "DOWN" then
                    editBox:Insert("\n/click " .. k .. [[LeftButton t]])
                else
                    editBox:Insert("\n/click " .. k)
                end
            end
            rootDescription:CreateTitle(L["Insert GSE Sequence"])
            for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()]) do
                rootDescription:CreateButton(k, function() insertSeq(k) end)
            end
            for k, _ in pairs(GSESequences[0]) do
                rootDescription:CreateButton(k, function() insertSeq(k) end)
            end
        end)
    end)
end

-- Skyriding Bind Bar for Retail
if GSE.GameMode >= 11 then
    -- Native Blizzard Settings subcategory. Lifted from the master-branch
    -- pattern that was overwritten by the AceGUI removal pass — register a
    -- vertical layout subcategory and add native button initializers, one
    -- per vehicle slot. CreateSettingsButtonInitializer + SettingsPanel are
    -- standard Blizzard APIs (11.0+); the panel rebuilds each open from
    -- the initializer data so the displayed text always reflects what
    -- was saved.
    -- Prefer the subcategory pre-registered by GSE_Options/Options.lua
    -- (createBlizzOptions) so this page sits ABOVE Tools & Diagnostics. Fall
    -- back to registering our own (lands last) if it isn't there for any reason.
    local skyOptions = GSE.SkyridingOptionsCategory or Settings.RegisterVerticalLayoutSubcategory(
        Settings.GetCategory(GSE.MenuCategoryID),
        L["Skyriding / Vehicle Keybinds"]
    )

    do
        local layout = SettingsPanel:GetLayout(skyOptions)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
            name = L["Skyriding / Vehicle Keybinds"],
            tooltip = "Override bindings for Skyriding, Vehicle, Possess and Override Bars",
        }))
    end

    local slotInits = {}

    local function onKeyDown(self, key)
        if key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or
           key == "LSHIFT" or key == "RSHIFT" or key == "LMETA" or key == "RMETA" then
            return
        end
        local slotIndex = self.gseSlot
        local binding
        if key == "ESCAPE" then
            if GSE.isEmpty(GSEOptions.SkyRidingBinds) then GSEOptions.SkyRidingBinds = {} end
            GSEOptions.SkyRidingBinds[tostring(slotIndex)] = nil
            binding = L["Not Bound"]
        else
            local mods = ""
            if IsControlKeyDown() then mods = "CTRL-" .. mods end
            if IsAltKeyDown()     then mods = "ALT-"  .. mods end
            if IsShiftKeyDown()   then mods = "SHIFT-".. mods end
            binding = mods .. key
            if GSE.isEmpty(GSEOptions.SkyRidingBinds) then GSEOptions.SkyRidingBinds = {} end
            GSEOptions.SkyRidingBinds[tostring(slotIndex)] = binding
        end
        if GSE.UpdateVehicleBar then GSE.UpdateVehicleBar() end
        self:SetText(binding)
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        -- Keep initializer data in sync so the panel shows the current
        -- binding when re-opened. Without this the row text reverts to the
        -- initial value supplied at register time (typically "Not Bound").
        local init = slotInits[slotIndex]
        if init and init.GetData then
            local data = init:GetData()
            if data then data.buttonText = binding end
        end
    end

    for i = 1, 12 do
        local slotIndex = i
        local layout = SettingsPanel:GetLayout(skyOptions)
        local init = CreateSettingsButtonInitializer(
            L["Skyriding Button"] .. " " .. i,
            (GSEOptions.SkyRidingBinds and GSEOptions.SkyRidingBinds[tostring(i)]) or L["Not Bound"],
            function(btnArg)
                if not btnArg then return end
                local btn = btnArg
                btn.gseSlot = slotIndex
                btn:SetText(L["Press a key..."])
                if btn.SetPropagateKeyboardInput then btn:SetPropagateKeyboardInput(false) end
                btn:EnableKeyboard(true)
                btn:SetScript("OnKeyDown", onKeyDown)
            end,
            "",
            false
        )
        slotInits[i] = init
        layout:AddInitializer(init)
    end


    -- Vehicle/Skyriding/PetBattle binding handler. When the player enters a
    -- vehicle, possess bar, override bar, Skyriding (bonusbar:5), or a pet
    -- battle, redirect each configured key to ACTIONBUTTON<n> as a priority
    -- override -- which beats GSE's base sequence binding and falls back to
    -- it automatically when ClearBindings() runs on dismount/exit.
    -- ACTIONBUTTON<n> already does the right thing for whatever bar is
    -- currently active, so no actionpage / intermediate-button indirection
    -- is needed.
    local VehicleBar = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
    VehicleBar:Hide()

    local function resolveMainBarButton(i)
        if _G["BT4Button" .. i] then return "BT4Button" .. i end
        if _G["DominosActionButton" .. i] then return "DominosActionButton" .. i end
        if _G["ElvUI_Bar1Button" .. i] then return "ElvUI_Bar1Button" .. i end
        return "ActionButton" .. i
    end

    -- Compile the user's SkyRidingBinds map into VehicleKeybind inside the
    -- restricted environment. Called once at init and again whenever the
    -- user changes a bind in Options.
    function GSE.UpdateVehicleBar()
        local tableval = {}
        if GSE.isEmpty(GSEOptions.SkyRidingBinds) then
            GSEOptions.SkyRidingBinds = {}
        end
        local tablevals = false
        for k, v in pairs(GSEOptions.SkyRidingBinds) do
            table.insert(tableval, k .. "\001" .. v)
            tablevals = true
        end
        -- Resolve frame names for all 12 slots. Always populated, even
        -- when the user has no binds yet, so the secure environment has
        -- a consistent VehicleButtonName table to read from.
        local nameTable = {}
        for i = 1, 12 do
            table.insert(nameTable, tostring(i) .. "\001" .. resolveMainBarButton(i))
        end
        local executionString
        if tablevals then
            executionString =
                "VehicleKeybindTable = newtable([=======[" ..
                string.join("]=======],[=======[", unpack(tableval)) ..
                    "]=======])" ..
                        [[
                VehicleKeybind = newtable()
                for _,v in ipairs(VehicleKeybindTable) do
                    local x, y = strsplit("\001",v)
                    VehicleKeybind[tonumber(x)] = y
                end

                ]]
        else
            executionString = "VehicleKeybind = newtable()\n"
        end
        executionString = executionString ..
            "VehicleButtonNameTable = newtable([=======[" ..
            string.join("]=======],[=======[", unpack(nameTable)) ..
                "]=======])" ..
                    [[
            VehicleButtonName = newtable()
            for _,v in ipairs(VehicleButtonNameTable) do
                local x, y = strsplit("\001",v)
                VehicleButtonName[tonumber(x)] = y
            end
            ]]
        VehicleBar:Execute(executionString)
    end

    GSE.UpdateVehicleBar()

    if not IsLoggedIn() then
        local plf = CreateFrame("Frame")
        plf:RegisterEvent("PLAYER_LOGIN")
        plf:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            if GSE.UpdateVehicleBar then GSE.UpdateVehicleBar() end
        end)
    end

    VehicleBar:SetAttribute(
        -- Leading underscore matters. The secure infrastructure only fires
        -- the underscore-prefixed snippet; the plain name is a silent no-op
        -- (regression at a32c1c64 "Second Cut removing AceGUI Dependency",
        -- restored 2026-06-01). Do not drop the underscore again.
        "_onattributechanged",
        [[
  if name == "vehicletype" then
    if value == "vehicle" then        -- Vehicles / Possess / Override / Skyriding
      for i = 1, 12 do
        if VehicleKeybind[i] and VehicleButtonName[i] then
          self:SetBinding(true, VehicleKeybind[i], "CLICK "..VehicleButtonName[i]..":LeftButton")
        end
      end
    elseif value == "petbattle" then  -- Pet battle
      for i = 1, 6 do
        if VehicleKeybind[i] and VehicleButtonName[i] then
          self:SetBinding(true, VehicleKeybind[i], "CLICK "..VehicleButtonName[i]..":LeftButton")
        end
      end
    elseif value == "none" then       -- Back to normal, drop our overrides
      self:ClearBindings()
    end
  end
]]
    )

    RegisterAttributeDriver(
        VehicleBar,
        "vehicletype",
        "[vehicleui][possessbar][overridebar][bonusbar:5] vehicle; [petbattle] petbattle; none"
    )
end
end
table.insert(ns.deferred, setup)
