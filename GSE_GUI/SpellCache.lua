local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local UI = GSE.UI
local L = GSE.L

local cacheFrame = UI:Create("Frame")
UI.MakePopup(cacheFrame.frame, {center = true})
cacheFrame:Hide()
GSE.GUICacheFrame = cacheFrame
function GSE.GUICreateCacheTabs()
    local tabl = {}

    for key, _ in pairs(GSESpellCache or {}) do
        table.insert(
            tabl,
            {
                text = key,
                value = key
            }
        )
    end
    return tabl
end

-- True while the table is being torn down and rebuilt. Every row callback
-- below checks it before touching GSESpellCache. The flag has always been set
-- here but was never READ anywhere, and that is what let a redraw destroy the
-- cache it was drawing.
function GSE.CacheEditorReloading()
    return cacheFrame.reloading and true or false
end

function GSE.GUISelectCacheTab(container, event, group)
    if GSE.isEmpty(container) then
        return
    end
    -- Not re-entrant. OnSizeChanged fires GUISelectCacheTab, and the redraw
    -- below changes sizes -- so a redraw could start while the previous one was
    -- still adding rows. It released widgets the outer pass was still holding,
    -- and with the widget pool those go straight back out to a LATER row: one
    -- widget, two rows, and a row closure whose currentKey no longer matches
    -- the text in its own box. The rename below then wrote
    -- cache[text] = cache[staleKey] (nil), which deletes. Coalesce instead:
    -- remember that another draw is wanted and run it once this one finishes.
    if cacheFrame.reloading then
        cacheFrame.pendingRedraw = group
        return
    end
    cacheFrame.reloading = true
    cacheFrame.pendingRedraw = nil
    cacheFrame.SelectedTab = group
    local ok, err = pcall(
        function()
            container:ReleaseChildren()
            GSE:GUIDrawSpellCacheEditor(container, group)
        end
    )
    -- Always clear the flag: a draw that errored out must not leave the editor
    -- permanently convinced it is mid-reload, which would silently disable
    -- every edit in the table.
    cacheFrame.reloading = false
    if not ok then
        GSE.Print(tostring(err), L["Spell Cache Editor"])
        return
    end
    local pending = cacheFrame.pendingRedraw
    if pending then
        cacheFrame.pendingRedraw = nil
        C_Timer.After(
            0,
            function()
                GSE.GUISelectCacheTab(container, "PendingRedraw", pending)
            end
        )
    end
end

-- One column model, used by the header row AND every data row. Before this the
-- two disagreed: headings were sized 0.48/0.47/0.10 of the row (105% of it,
-- before the two spacer widgets and before the Flow layout's own 10px gap
-- between every child) while the cells below were sized from rowWidth - 70, so
-- no column ever sat under its heading. Sizing both from one function is what
-- keeps them lined up.
local COLUMN_GAP = 8
local DELETE_ICON_SIZE = 20
-- Flow wraps a child when x + width > contentWidth, so a row that adds up to
-- EXACTLY its container is decided by the last bit of a float: these widths
-- come from the frame's measured width, and re-adding them left to right lands
-- a ULP either side of it. That coin flip is what pushed the delete icon onto a
-- second flow row -- visible on the auto-height header, and hidden behind the
-- next row's edit boxes on the fixed-height data rows. Never size a row to fit
-- exactly; keep a few pixels back.
local ROW_SLACK = 6
local ROW_HEIGHT = 24

local function cacheColumnWidths(rowWidth)
    local usable = rowWidth - DELETE_ICON_SIZE - (COLUMN_GAP * 2) - ROW_SLACK
    if usable < 120 then
        usable = 120
    end
    local half = math.floor(usable * 0.5)
    return half, half
end

-- Flow's defaults (10px between children, 6px each side) are tuned for forms,
-- not for a table: they add invisible width that no column model can predict.
-- Zero the padding and own the gap so a row is exactly its own columns.
local function newCacheRow(rowWidth)
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetWidth(rowWidth)
    if row.SetFlowGap then
        row:SetFlowGap(COLUMN_GAP)
    end
    if row.SetFlowPadding then
        row:SetFlowPadding(0, 0, 0, 0)
    end
    -- Centre the 20px icon against the 24px boxes beside it.
    if row.SetFlowVAlign then
        row:SetFlowVAlign("CENTER")
    end
    return row
end

local function addKeyPairRow(container, rowWidth, key, value, language)
    local blank = false

    if GSE.isEmpty(key) then
        blank = true
    end
    if GSE.isEmpty(value) then
        blank = true
    end
    if GSE.isEmpty(language) then
        blank = true
    end
    if blank == true then
        return
    end

    local nameWidth, idWidth = cacheColumnWidths(rowWidth)

    local linegroup1 = newCacheRow(rowWidth)
    linegroup1:SetHeight(ROW_HEIGHT)

    local keyEditBox = UI:Create("EditBox")
    -- Compact (no label slot): a labelled EditBox reserves 14px above the box
    -- whether or not the label has any text, which is what made each row twice
    -- as tall as the delete icon beside it.
    keyEditBox:SetCompactNoLabel(true)
    keyEditBox:DisableButton(true)
    keyEditBox:SetWidth(nameWidth)
    keyEditBox:SetHeight(ROW_HEIGHT)
    keyEditBox:SetText(key)
    local currentKey = key

    -- The live cache table, or nil when there is nothing safe to write to.
    local function cacheTable()
        if GSE.CacheEditorReloading() then
            return nil
        end
        local cache = GSESpellCache and GSESpellCache[language]
        if type(cache) ~= "table" then
            return nil
        end
        return cache
    end

    -- Renaming used to run on OnTextChanged -- on every keystroke, and on every
    -- programmatic SetText, including the ones the widget pool issues when it
    -- resets a reused box. It read:
    --     cache[text] = cache[currentKey]
    --     cache[currentKey] = nil
    -- so whenever text happened to EQUAL currentKey it wrote the value back to
    -- the same key and then deleted that key. One spurious fire per row and the
    -- whole cache was gone, with no leftover entry to show for it.
    --
    -- Commit on OnEnterPressed/OnEditFocusLost instead: those only fire when a
    -- person has actually finished typing, never as a side effect of drawing.
    local function commitKeyRename(text)
        local cache = cacheTable()
        if not cache then
            return
        end
        text = tostring(text or "")
        if text == "" or text == currentKey then
            -- Nothing to do. Put the box back to the name it still holds rather
            -- than leaving the user looking at an edit that was not applied.
            keyEditBox:SetText(currentKey)
            return
        end
        if cache[text] ~= nil then
            -- That name is already cached. Refuse rather than silently
            -- overwrite someone else's entry with this row's ID.
            keyEditBox:SetText(currentKey)
            return
        end
        cache[text] = cache[currentKey]
        cache[currentKey] = nil
        currentKey = text
    end

    keyEditBox:SetCallback(
        "OnEnterPressed",
        function(_, _, text)
            commitKeyRename(text)
        end
    )
    keyEditBox:SetCallback(
        "OnEditFocusLost",
        function(_, _, text)
            commitKeyRename(text)
        end
    )
    linegroup1:AddChild(keyEditBox)

    local valueEditBox = UI:Create("EditBox")
    valueEditBox:SetCompactNoLabel(true)
    valueEditBox:SetWidth(idWidth)
    valueEditBox:SetHeight(ROW_HEIGHT)
    valueEditBox:DisableButton(true)
    valueEditBox:SetText(value)

    -- Same move as the name box, plus a type fix: the old OnTextChanged handler
    -- stored the raw edit box STRING, while everything that reads the cache
    -- (GSE.TranslateSpell, GSE.GetSpellId) expects the number the translator
    -- put there. A half-typed ID was also written on every keystroke.
    local function commitSpellID(text)
        local cache = cacheTable()
        if not cache then
            return
        end
        local spellID = tonumber(text)
        if not spellID then
            valueEditBox:SetText(cache[currentKey])
            return
        end
        cache[currentKey] = spellID
    end

    valueEditBox:SetCallback(
        "OnEnterPressed",
        function(_, _, text)
            commitSpellID(text)
        end
    )
    valueEditBox:SetCallback(
        "OnEditFocusLost",
        function(_, _, text)
            commitSpellID(text)
        end
    )

    linegroup1:AddChild(valueEditBox)

    local deleteRowButton = UI:Create("Icon")
    deleteRowButton:SetImageSize(DELETE_ICON_SIZE, DELETE_ICON_SIZE)
    deleteRowButton:SetWidth(DELETE_ICON_SIZE)
    deleteRowButton:SetHeight(DELETE_ICON_SIZE)
    deleteRowButton:SetImage("Interface\\Icons\\spell_chargenegative")
    -- Pinned to the row's right edge. layoutFlow exempts right-aligned children
    -- from the wrap test altogether, so however the column arithmetic rounds,
    -- the delete button cannot be pushed onto a second line.
    if deleteRowButton.SetFlowRightAlign then
        deleteRowButton:SetFlowRightAlign(true)
    end

    deleteRowButton:SetCallback(
        "OnClick",
        function()
            local cache = cacheTable()
            if not cache then
                return
            end
            cache[currentKey] = nil
            -- Redraw the tab rather than emptying this row in place: the old
            -- ReleaseChildren() left a row-height hole in the middle of the
            -- table. Deferred a frame because the redraw releases the very
            -- widget whose click handler is running.
            local tab = cacheFrame.SelectedTab
            C_Timer.After(
                0,
                function()
                    GSE.GUISelectCacheTab(cacheFrame.ContentContainer, "Delete", tab)
                end
            )
        end
    )

    linegroup1:AddChild(deleteRowButton)

    container:AddChild(linegroup1)
    return keyEditBox
end

function GSE:GUIDrawSpellCacheEditor(container, language)
    local languageCache = GSESpellCache and GSESpellCache[language]
    if type(languageCache) ~= "table" then languageCache = {} end

    local maxWidth = container.frame:GetWidth()
    local scrollcontainer = UI:Create("SimpleGroup") -- "InlineGroup" is also good
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetHeight(cacheFrame.Height - 110)
    scrollcontainer:SetLayout("Fill") -- Important!

    local contentcontainer = UI:Create("ScrollFrame") -- "InlineGroup" is also good
    contentcontainer:SetWidth(maxWidth)
    contentcontainer:SetAutoAdjustHeight(true)
    scrollcontainer:AddChild(contentcontainer)
    local columnWidth = maxWidth - 55
    local nameWidth, idWidth = cacheColumnWidths(columnWidth)

    -- Two headings, not three: the delete button is self-explanatory and an
    -- "Actions" column title over a single icon earns nothing.
    local headerRow = newCacheRow(columnWidth)

    local nameLabel = UI:Create("Heading")
    nameLabel:SetText(L["Spell Name"])
    nameLabel:SetWidth(nameWidth)
    headerRow:AddChild(nameLabel)

    local valueLabel = UI:Create("Heading")
    valueLabel:SetText(L["Spell ID"])
    valueLabel:SetWidth(idWidth)
    headerRow:AddChild(valueLabel)
    contentcontainer:AddChild(headerRow)

    -- Sorted, not pairs(): the old iteration order was hash order, so every
    -- redraw -- and this frame redraws on every resize step -- reshuffled the
    -- whole table under the user. It was also being mutated mid-iteration,
    -- since a row's OnTextChanged renames its key in this very table; walking
    -- a snapshot of the names makes that safe as well as stable.
    local spellNames = {}
    for spellName in pairs(languageCache) do
        spellNames[#spellNames + 1] = spellName
    end
    -- Compare as strings: a cache built by an older client can hold a numeric
    -- key, and table.sort's default comparator errors outright on a mixed list.
    table.sort(
        spellNames,
        function(a, b)
            return tostring(a) < tostring(b)
        end
    )
    for _, spellName in ipairs(spellNames) do
        addKeyPairRow(contentcontainer, columnWidth, spellName, languageCache[spellName], language)
    end
    container:AddChild(scrollcontainer)
end

cacheFrame.Height = GSEOptions.cacheHeight and GSEOptions.cacheHeight or 700
cacheFrame.Width = GSEOptions.cacheWidth and GSEOptions.cacheWidth or 700
if cacheFrame.Height < 500 then
    cacheFrame.Height = 500
    GSEOptions.cacheHeight = cacheFrame.Height
end
if cacheFrame.Width < 700 then
    cacheFrame.Width = 700
    GSEOptions.cacheWidth = cacheFrame.Width
end
cacheFrame.frame:SetClampRectInsets(10, 0, 0, 0)
cacheFrame.frame:SetHeight(cacheFrame.Height)
cacheFrame.frame:SetWidth(cacheFrame.Width)
cacheFrame:SetTitle(L["Spell Cache Editor"])
cacheFrame:SetCallback(
    "OnClose",
    function(self)
        cacheFrame:Hide()
    end
)
cacheFrame:SetLayout("List")
cacheFrame.frame:SetScript(
    "OnSizeChanged",
    function(self, width, height)
        cacheFrame.Height = height
        cacheFrame.Width = width
        if cacheFrame.Height > GetScreenHeight() then
            cacheFrame.Height = GetScreenHeight() - 10
            cacheFrame:SetHeight(cacheFrame.Height)
        end
        if cacheFrame.Height < 500 then
            cacheFrame.Height = 500
            cacheFrame:SetHeight(cacheFrame.Height)
        end
        if cacheFrame.Width < 700 then
            cacheFrame.Width = 700
            cacheFrame:SetWidth(cacheFrame.Width)
        end
        GSEOptions.cacheHeight = cacheFrame.Height
        GSEOptions.cacheWidth = cacheFrame.Width
        GSE.GUISelectCacheTab(cacheFrame.ContentContainer, "Resize", cacheFrame.SelectedTab)
        cacheFrame:DoLayout()
    end
)

local tabgrp = UI:Create("TabGroup")
tabgrp:SetLayout("Flow")
local cacheTabs = GSE.GUICreateCacheTabs()
tabgrp:SetTabs(cacheTabs)
cacheFrame.ContentContainer = tabgrp
tabgrp:SetCallback(
    "OnGroupSelected",
    function(container, event, group)
        GSE.GUISelectCacheTab(container, event, group)
    end
)

tabgrp:SetFullWidth(true)
tabgrp:SetFullHeight(true)

-- Draw the tab's contents when the window is first SHOWN, not while the addon
-- loads. SelectTab fires GUISelectCacheTab -> GUIDrawSpellCacheEditor, which
-- builds two EditBoxes plus labels for EVERY cached spell. This frame starts
-- hidden and most authors never open it, so doing that during the on-demand
-- LoadAddOn (which is what opening the GSE menu triggers) stalled the client
-- for seconds on a cache built up over years.
local pendingInitialTab = cacheTabs[1] and cacheTabs[1].value
cacheFrame.frame:HookScript(
    "OnShow",
    function()
        if not pendingInitialTab then return end
        local tab = pendingInitialTab
        pendingInitialTab = nil
        tabgrp:SelectTab(tab)
    end
)
cacheFrame:AddChild(tabgrp)

if cacheFrame and cacheFrame.frame and GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(cacheFrame.frame)
end
end
table.insert(ns.deferred, setup)
