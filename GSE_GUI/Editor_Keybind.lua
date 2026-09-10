local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local function sequenceExists(seqName)
    for _, classLib in pairs(GSE.Library or {}) do
        if classLib[seqName] then return true end
    end
    return false
end

local function sequenceIsDisabled(seqName)
    for _, classLib in pairs(GSE.Library or {}) do
        local seq = classLib[seqName]
        if seq then
            return seq.MetaData and seq.MetaData.Disabled == true
        end
    end
    return false
end

-- Append a disabled warning to a tree node label when the sequence is disabled.
local function keybindNodeText(bindLabel, seqName)
    local base = bindLabel .. " " .. GSEOptions.KEYWORD .. "(" .. seqName .. ")" .. Statics.StringReset
    if sequenceIsDisabled(seqName) then
        base = base .. " |cFFFF6600" .. L["Sequence Disabled"] .. "|r"
    end
    return base
end

-- Every saved talent loadout for a spec of the player's class, newest API
-- first.  Empty on clients without talent loadouts, which is what the callers
-- want -- no loadout nodes and a loadout dropdown holding only "All".
local function loadoutsForSpec(specIndex)
    if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and GetSpecializationInfoForClassID) then
        return {}
    end
    local specid = GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specIndex)
    if not specid then return {} end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specid)
    return (ok and ids) or {}
end

-- ---------------------------------------------------------------------------
-- heroTalentIcon(configid, specIndex)  ->  icon, iconCoords
-- The hero talent artwork for ONE talent loadout, for the tree row that opens
-- it.  Blizzard hands this out as an ATLAS (traitsubtreeinfo.iconElementID)
-- and the tree draws its rows with SetTexture, which cannot take one -- so
-- resolve the atlas to its file plus texture coords and return both.  The tree
-- already passes an iconCoords through to SetTexCoord, so no widget change.
-- Returns nil where there are no hero talents (Classic) or the loadout's
-- subtree cannot be resolved; the caller keeps the generic talent icon.
-- ---------------------------------------------------------------------------
local function heroTalentSubTreeID(configid, specIndex)
    if not (C_ClassTalents and C_Traits and C_Traits.GetSubTreeInfo) then return nil end

    -- The equipped loadout answers directly, and this is the one call both
    -- GRIP-EMS and Gnomester use, so it is the path known to work.
    if C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveHeroTalentSpec then
        local ok, activeConfig = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and activeConfig == configid then
            local activeOK, subTreeID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
            if activeOK and tonumber(subTreeID) and subTreeID > 0 then return subTreeID end
        end
    end

    -- Any other loadout: walk the spec's subtrees and take the one this config
    -- has taken.  isActive is the only per-config marker Blizzard exposes.
    if not (C_ClassTalents.GetHeroTalentSpecsForClassSpec and GetSpecializationInfoForClassID) then
        return nil
    end
    local specid = GetSpecializationInfoForClassID(GSE.GetCurrentClassID(), specIndex)
    if not specid then return nil end
    local ok, subTreeIDs = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec, configid, specid)
    if not ok or type(subTreeIDs) ~= "table" then return nil end
    for _, subTreeID in ipairs(subTreeIDs) do
        local infoOK, info = pcall(C_Traits.GetSubTreeInfo, configid, subTreeID)
        if infoOK and type(info) == "table" and info.isActive then return subTreeID end
    end
    return nil
end

-- The raw artwork handle for a loadout's hero talent: an atlas NAME on
-- current clients, a fileID on some builds.  nil where there is none.
local function heroTalentElement(configid, specIndex)
    local subTreeID = heroTalentSubTreeID(configid, specIndex)
    if not subTreeID then return nil end
    local ok, info = pcall(C_Traits.GetSubTreeInfo, configid, subTreeID)
    if not (ok and type(info) == "table" and info.iconElementID) then return nil end
    return info.iconElementID
end

local function heroTalentIcon(configid, specIndex)
    local element = heroTalentElement(configid, specIndex)
    if not element then return nil end

    local atlas = C_Texture and C_Texture.GetAtlasInfo and type(element) == "string"
        and C_Texture.GetAtlasInfo(element) or nil
    if atlas and atlas.file then
        return atlas.file,
            {atlas.leftTexCoord, atlas.rightTexCoord, atlas.topTexCoord, atlas.bottomTexCoord}
    end
    -- A fileID rather than an atlas name needs no resolving.
    if type(element) == "number" then return element, nil end
    return nil
end

-- The table a keybind for this spec (and optionally this talent loadout) lives
-- in.  `create` builds the intermediate tables; without it a missing scope
-- returns nil rather than littering GSE_C on a read.
local function keybindScope(specialization, loadout, create)
    if not GSE_C["KeyBindings"] then
        if not create then return nil end
        GSE_C["KeyBindings"] = {}
    end
    local spec = GSE_C["KeyBindings"][tostring(specialization)]
    if not spec then
        if not create then return nil end
        spec = {}
        GSE_C["KeyBindings"][tostring(specialization)] = spec
    end
    if not loadout then return spec end
    if not spec["LoadOuts"] then
        if not create then return nil end
        spec["LoadOuts"] = {}
    end
    if not spec["LoadOuts"][loadout] then
        if not create then return nil end
        spec["LoadOuts"][loadout] = {}
    end
    return spec["LoadOuts"][loadout]
end

-- The table an actionbar override for this spec (and optionally this talent
-- loadout) lives in.  Same contract as keybindScope on the ActionBarBinds
-- shape: Specialisations[spec][key] / LoadOuts[spec][loadout][key], where key
-- is the button name, or name-state when a button state is set.
local function overrideScope(specialization, loadout, create)
    local binds = GSE_C["ActionBarBinds"]
    if not binds then
        if not create then return nil end
        binds = {}
        GSE_C["ActionBarBinds"] = binds
    end
    specialization = tostring(specialization)
    if not loadout then
        if not binds["Specialisations"] then
            if not create then return nil end
            binds["Specialisations"] = {}
        end
        if not binds["Specialisations"][specialization] then
            if not create then return nil end
            binds["Specialisations"][specialization] = {}
        end
        return binds["Specialisations"][specialization]
    end
    if not binds["LoadOuts"] then
        if not create then return nil end
        binds["LoadOuts"] = {}
    end
    if not binds["LoadOuts"][specialization] then
        if not create then return nil end
        binds["LoadOuts"][specialization] = {}
    end
    if not binds["LoadOuts"][specialization][loadout] then
        if not create then return nil end
        binds["LoadOuts"][specialization][loadout] = {}
    end
    return binds["LoadOuts"][specialization][loadout]
end

-- The player's current spec index, for the panel's default scope.
local function defaultSpecIndex()
    if GSE.GameMode < 10 then return 1 end
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    return getSpec and getSpec() or 1
end

-- Defined further down beside the widget helpers; the tree builder only runs
-- at ManageTree time, long after this file has finished loading.
local KB_HERO_RING

-- ---------------------------------------------------------------------------
-- buildKeybindMenu()  →  full KEYBINDINGS tree node
-- ---------------------------------------------------------------------------
local function buildKeybindMenu()
    local tree = {
        {
            value = "AO",
            text = L["Actionbar Overrides"],
            icon = Statics.Icons.Button,
            children = {}
        },
        {
            value = "KB",
            text = L["Keybindings"],
            icon = Statics.ActionsIcons.Key,
            children = {}
        }
    }

    -- Actionbar Overrides nodes.  Same shape as the keybind nodes below: the
    -- tree stops at spec and its talent loadouts; every override in a scope is
    -- a row on the panel.  Overrides whose sequence no longer exists are
    -- pruned here in one pass, as the leaf builder used to do.
    do
        local binds = GSE_C["ActionBarBinds"] or {}
        for _, buttons in pairs(binds["Specialisations"] or {}) do
            for key, override in pairs(buttons) do
                if type(override) ~= "table" or not sequenceExists(override.Sequence) then buttons[key] = nil end
            end
        end
        for _, loadouts in pairs(binds["LoadOuts"] or {}) do
            for loadoutid, buttons in pairs(loadouts) do
                for key, override in pairs(buttons) do
                    if type(override) ~= "table" or not sequenceExists(override.Sequence) then buttons[key] = nil end
                end
                if not next(buttons) then loadouts[loadoutid] = nil end
            end
        end

        if GetSpecializationInfo then
            for specIndex = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
                local _, speclabel, _, specIcon = GetSpecializationInfo(specIndex)
                local node = {value = tostring(specIndex), text = speclabel, icon = specIcon, children = {}}
                for _, configid in ipairs(loadoutsForSpec(specIndex)) do
                    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configid)
                    if info then
                        local icon, iconCoords = heroTalentIcon(configid, specIndex)
                        table.insert(node["children"], {
                            value = tostring(configid),
                            text = "|cffffcc00" .. info.name .. Statics.StringReset,
                            icon = icon or Statics.Icons.Talents,
                            iconCoords = iconCoords,
                            iconRing = icon and KB_HERO_RING or nil
                        })
                    end
                end
                table.insert(tree[1]["children"], node)
            end
        end
    end

    -- Keybinding nodes.  The tree stops at spec (and its talent loadouts):
    -- every bind in that scope is a row on the panel now, not a node here.
    -- Clicking a spec opens the panel for All Talent Loadouts; clicking one of
    -- its loadouts opens the same panel with that loadout already selected.
    do
        -- Binds whose sequence no longer exists used to be pruned while
        -- building their leaf nodes.  There are no leaf nodes any more, so
        -- prune in one pass over the saved data instead.
        for _, v in pairs(GSE_C["KeyBindings"]) do
            local orphans = {}
            for i, j in pairs(v) do
                if i ~= "LoadOuts" and not sequenceExists(j) then
                    table.insert(orphans, i)
                end
            end
            for _, i in ipairs(orphans) do
                if not InCombatLockdown() then SetBinding(i) end
                v[i] = nil
            end
            for loadoutid, binds in pairs(v["LoadOuts"] or {}) do
                local loOrphans = {}
                for i, j in pairs(binds) do
                    if not sequenceExists(j) then table.insert(loOrphans, i) end
                end
                for _, i in ipairs(loOrphans) do
                    if not InCombatLockdown() then SetBinding(i) end
                    binds[i] = nil
                end
                if not next(binds) then v["LoadOuts"][loadoutid] = nil end
            end
        end

        if GetSpecializationInfo then
            for specIndex = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
                local _, speclabel, _, specIcon = GetSpecializationInfo(specIndex)
                local node = {
                    value = tostring(specIndex),
                    text = speclabel,
                    icon = specIcon,
                    children = {}
                }
                -- Every loadout for the spec, not only those that already have
                -- binds -- the panel is where binds get added, so you have to
                -- be able to navigate to an empty loadout.
                for _, configid in ipairs(loadoutsForSpec(specIndex)) do
                    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configid)
                    if info then
                        local icon, iconCoords = heroTalentIcon(configid, specIndex)
                        table.insert(
                            node["children"],
                            {
                                value = tostring(configid),
                                text = "|cffffcc00" .. info.name .. Statics.StringReset,
                                icon = icon or Statics.Icons.Talents,
                                iconCoords = iconCoords,
                                iconRing = icon and KB_HERO_RING or nil
                            }
                        )
                    end
                end
                table.insert(tree[2]["children"], node)
            end
        end
    end

    return {
        value = "KEYBINDINGS",
        text = L["Keybindings"],
        icon = Statics.Icons.Keybindings,
        children = tree
    }
end

-- ---------------------------------------------------------------------------
-- showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- showKeybindPanel(editframe, specialization, loadout, rightContainer)
-- One panel per spec + talent loadout listing every keybind in that scope as a
-- row, in place of one tree node and one panel per bind.  Save is enabled only
-- once something changes and writes every row at once; rows are removed with
-- the X beside them and added with the + above them.
-- ---------------------------------------------------------------------------
-- Column widths, shared by the rows and the headings above them so the two
-- line up.  KB_ROW_WIDTH is what one row occupies including the flow gaps.
-- The two icon columns are sized to their artwork plus a hairline: the Icon
-- widget centres its texture in the frame, so every pixel of column wider than
-- KB_ICON_SIZE reads as a gap between the icon and the control beside it.
local KB_ICON_SIZE = 18
local KB_COL_ADD, KB_COL_KEY, KB_COL_SEQ, KB_COL_REMOVE = KB_ICON_SIZE + 4, 180, 260, KB_ICON_SIZE + 4
local KB_ROW_HEIGHT = 24
-- Rows a panel will add up to.  Saved data above the cap still loads; it just
-- cannot grow further from here.
local KB_MAX_ROWS = 16
-- Gap between a control and the icon beside it.
local KB_ICON_GAP = 6
-- Column headings are plain white: the class-coloured header above them is
-- what carries colour on this panel, and a second accent competed with it.
local KB_HEADING_COLOUR = "|cffffffff"

-- Inline |T..|t rather than Icon widgets: an Icon needs a fixed width, which
-- pushes its text away from it. This keeps icon and label as one string.
local function iconText(icon, text, size)
    size = size or 18
    if not icon then return text end
    return "|T" .. icon .. ":" .. size .. ":" .. size .. "|t " .. text
end
-- Same as iconText for a hero talent handle: an atlas name needs the |A..|a
-- escape, which takes no coords and so needs no GetAtlasInfo detour; a fileID
-- goes through iconText.  Falls back to `fallback` where there is no hero art.
local function heroIconText(element, fallback, text, size)
    size = size or 18
    if type(element) == "string" then
        return "|A:" .. element .. ":" .. size .. ":" .. size .. "|a " .. text
    end
    return iconText(element or fallback, text, size)
end
-- Blizzard's grey circular node ring, laid over the round hero medallions so
-- they stop reading as floating.  talents-node-choiceflyout-circle-gray, the
-- variant Larry picked from the four drawn live on 2026-09-07.
KB_HERO_RING = "talents-node-choiceflyout-circle-gray"

-- A hero medallion with the ring over it, as a fixed-size group the panel
-- can flow beside a heading.  Inline text cannot do this: two |A| escapes sit
-- side by side, they do not stack.  Textures are cached per frame in a weak
-- table because SimpleGroup is pooled and the pool sweeps caller fields.
local heroBadgeArt = setmetatable({}, {__mode = "k"})
local function heroBadge(element, size)
    local badge = UI:Create("SimpleGroup")
    badge:SetWidth(size)
    badge:SetHeight(size)
    local host = badge.frame
    local art = heroBadgeArt[host]
    if not art then
        art = {icon = host:CreateTexture(nil, "ARTWORK"), ring = host:CreateTexture(nil, "OVERLAY")}
        -- The medallion sits 2px inside the ring so the ring's inner edge
        -- covers its rim instead of the two edges fighting.  Pixel snapping
        -- off on both: these atlases are drawn for ~50px nodes, and snapped
        -- to the grid at a quarter of that they go muddy.
        art.icon:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -2)
        art.icon:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
        art.ring:SetAllPoints(host)
        for _, t in pairs(art) do
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        end
        heroBadgeArt[host] = art
    end
    art.icon:SetAtlas(element)
    art.ring:SetAtlas(KB_HERO_RING)
    art.icon:Show()
    art.ring:Show()
    return badge
end
local KB_ROW_WIDTH = KB_COL_ADD + KB_COL_KEY + KB_COL_SEQ + KB_COL_REMOVE + 18

-- The Dropdown draws ONE of two things: Blizzard's UIDropDownMenuTemplate
-- (widget.nativeDropdown -- the path Retail takes, NativeUI SetDropdownStyle)
-- or its own button.  Only the visible one is worth measuring or styling; the
-- other is hidden and flush with the frame, which is how three passes at the
-- X measured zero slack and the text never centred.  Returns the frame whose
-- RIGHT edge is the visible field's right edge, and the pad to add to it.
-- For the native template that is its arrow button: the template's Right
-- texture carries ~16px of transparent margin, so the frame edge is no use.
local function dropdownFieldEdge(dropdown)
    local native = dropdown.nativeDropdown
    if native and native.IsShown and native:IsShown() then
        local name = native.GetName and native:GetName()
        local arrow = native.Button or (name and _G[name .. "Button"])
        if arrow then return arrow, 2 end
        return native, -16
    end
    local button = dropdown.button
    if button and button.IsShown and button:IsShown() then return button, 0 end
    return nil, 0
end

local showKeybindPanel
showKeybindPanel = function(editframe, specialization, loadout, rightContainer)
    specialization = tostring(specialization or defaultSpecIndex())

    local rows = {}
    local saveButton, rowContainer, redraw
    -- Per-row {field, icon} pairs, so the post-layout pass can hang each X off
    -- the dropdown's real right edge.  Rebuilt by every redraw.
    local rowEdges = {}

    -- The Dropdown's visible field is its BUTTON, which compact mode anchors
    -- independently of the widget frame the Flow layout measures, so the 6px
    -- flow gap after the frame is not the gap you see.  Measure the slack and
    -- slide the x of the point the layout already gave the icon -- never
    -- re-anchor it, which throws away the layout's vertical centring.
    local function tightenRemoveIcons()
        for _, edge in ipairs(rowEdges) do
            local field, icon = edge.field, edge.icon
            if field and icon and field.GetRight and icon.GetLeft and icon.GetPoint then
                local fieldRight, iconLeft = field:GetRight(), icon:GetLeft()
                if fieldRight and iconLeft then
                    local slack = iconLeft - (fieldRight + (edge.pad or 0) + KB_ICON_GAP)
                    if slack > 0.5 then
                        local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
                        if point then
                            icon:SetPoint(point, relativeTo, relativePoint, (x or 0) - slack, y or 0)
                        end
                    end
                end
            end
        end
    end

    local function loadRows()
        wipe(rows)
        local scope = keybindScope(specialization, loadout, false)
        local keys = {}
        for k in pairs(scope or {}) do
            if k ~= "LoadOuts" then table.insert(keys, k) end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            table.insert(rows, {key = k, seq = scope[k]})
        end
    end

    local function markDirty()
        if saveButton then saveButton:SetDisabled(false) end
    end

    -- Every sequence this character can bind.  Disabled ones are flagged rather
    -- than hidden, so a row already pointing at one still shows what it is.
    local function sequenceList()
        local names, order = {}, {}
        for _, source in ipairs({GSESequences[GSE.GetCurrentClassID()] or {}, GSESequences[0] or {}}) do
            for k in pairs(source) do
                if not names[k] then
                    names[k] = sequenceIsDisabled(k) and k .. " (" .. L["Sequence Disabled"] .. ")" or k
                    table.insert(order, k)
                end
            end
        end
        return names, GSE.SortTableAlphabetical(order)
    end

    local function save()
        -- Two rows on one key would silently discard one of them.
        local seen = {}
        for _, r in ipairs(rows) do
            if not GSE.isEmpty(r.key) then
                if seen[r.key] then
                    GSE.Print(string.format(L["%s is bound more than once.  Change or remove one before saving."], r.key))
                    return
                end
                seen[r.key] = true
            end
        end

        -- A row binds only once it has BOTH halves.  One that does not is a
        -- row still being filled in: keep it on screen instead of writing it.
        -- Silently dropping it is what made new binds look like they vanished
        -- -- the write skipped them, and the reload below, which reads back
        -- only what was stored, then wiped them off the panel.
        local incomplete = {}
        for _, r in ipairs(rows) do
            local hasKey, hasSeq = not GSE.isEmpty(r.key), not GSE.isEmpty(r.seq)
            if hasKey ~= hasSeq then
                table.insert(incomplete, {key = r.key, seq = r.seq})
            end
        end

        local scope = keybindScope(specialization, loadout, true)
        for k in pairs(scope) do
            if k ~= "LoadOuts" then scope[k] = nil end
        end
        for _, r in ipairs(rows) do
            if not GSE.isEmpty(r.key) and not GSE.isEmpty(r.seq) then
                scope[r.key] = r.seq
            end
        end
        -- An emptied loadout would stay in the tree as a childless node -- but
        -- only drop it when nothing is still being filled in, or a half-set row
        -- would take the whole loadout with it.
        if loadout and not next(scope) and #incomplete == 0 then
            GSE_C["KeyBindings"][specialization]["LoadOuts"][loadout] = nil
        end

        -- The rebuild releases every key the previous one bound before adding
        -- back what survives, so rows removed here go dead immediately.
        GSE.ReloadKeyBindings()
        if saveButton then saveButton:SetDisabled(true) end
        loadRows()
        -- Put the half-set rows back, so Save never makes a row disappear, and
        -- say what each one is still missing rather than leaving it a mystery.
        for _, r in ipairs(incomplete) do
            table.insert(rows, r)
            GSE.Print(string.format(L["%s was not saved: it still needs a %s."],
                GSE.isEmpty(r.key) and r.seq or r.key,
                GSE.isEmpty(r.key) and L["Keybind"] or L["Sequence"]))
        end
        if #incomplete > 0 and saveButton then saveButton:SetDisabled(false) end
        redraw()
        editframe.ManageTree()
    end

    local function buildRow(index)
        local model = rows[index]
        local row = UI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        if row.SetFlowGap then row:SetFlowGap(6) end
        if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
        if row.SetFlowVAlign then row:SetFlowVAlign("CENTER") end
        if row.SetFlowHAlign then row:SetFlowHAlign("CENTER") end

        -- + rides the LAST row, on its left, so the row it adds appears
        -- directly below it.  Earlier rows carry a blank of the same width so
        -- the four columns still line up.  Adding a row is not itself a
        -- change, so it does not arm Save -- the keybind and sequence
        -- callbacks below do that once the row is actually filled in.
        local addSlot
        if index == #rows then
            addSlot = UI:Create("Icon")
            addSlot:SetImage(Statics.ActionsIcons.Add)
            addSlot:SetImageSize(KB_ICON_SIZE, KB_ICON_SIZE)
            local full = #rows >= KB_MAX_ROWS
            addSlot:SetCallback(
                "OnClick",
                function()
                    if #rows >= KB_MAX_ROWS then return end
                    table.insert(rows, {})
                    redraw()
                end
            )
            addSlot:SetCallback("OnEnter", function()
                GSE.CreateToolTip(L["Add"],
                    full and string.format(L["Limit of %d rows."], KB_MAX_ROWS) or L["Add a row below this one."],
                    editframe)
            end)
            -- At the cap the + stays in its slot, greyed, and says why.
            if full then addSlot:SetDisabled(true) end
            addSlot:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        else
            addSlot = UI:Create("Spacer")
        end
        addSlot:SetWidth(KB_COL_ADD)
        addSlot:SetHeight(KB_ROW_HEIGHT)

        local remove = UI:Create("Icon")
        remove:SetImage(Statics.ActionsIcons.DeleteX)
        remove:SetImageSize(KB_ICON_SIZE, KB_ICON_SIZE)
        remove:SetWidth(KB_COL_REMOVE)
        remove:SetHeight(KB_ROW_HEIGHT)
        -- The Flow layout honours flowYOffset: lifts the X the 2px it sat
        -- below the dropdown's centre line (Larry, 2026-09-08).
        remove.flowYOffset = 2
        remove:SetCallback("OnEnter", function()
            -- The only row is cleared, not removed; say which.
            local text = #rows <= 1 and L["Clear this row."] or L["Remove this row."]
            GSE.CreateToolTip(L["Remove"], text, editframe)
        end)
        remove:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        remove:SetCallback(
            "OnClick",
            function()
                -- The base row is never removed.  When it is the only row, X
                -- clears it back to blank instead, so the panel always has a
                -- row for the + to ride on.  Clearing a row that was already
                -- blank changes nothing, so it does not arm Save.
                if #rows <= 1 then
                    if GSE.isEmpty(model.key) and GSE.isEmpty(model.seq) then return end
                    rows[index] = {}
                else
                    table.remove(rows, index)
                end
                markDirty()
                redraw()
            end
        )

        -- No per-widget labels: the column headings above the list name these
        -- once instead of repeating on every row.
        local keybind = UI:Create("ControllerKeybinding")
        keybind:SetWidth(KB_COL_KEY)
        -- The widget reserves STYLE.keyBindButtonReserve (20px) of empty space
        -- to the right of its button, which on a row sat on top of the flow
        -- gap and read as a hole between the key and the sequence.  Closed on
        -- this instance only -- the constant is shared with every other
        -- ControllerKeybinding in the addon, and nothing is anchored in that
        -- strip.  Safe because ControllerKeybinding is not in POOLED_TYPES, so
        -- this frame is never handed to another consumer.
        if keybind.button and keybind.frame then
            keybind.button:SetPoint("BOTTOMRIGHT", keybind.frame, "BOTTOMRIGHT", 0, 0)
        end
        if not GSE.isEmpty(model.key) then keybind:SetKey(model.key) end
        keybind:SetCallback(
            "OnKeyChanged",
            function(_, _, key)
                model.key = key
                markDirty()
            end
        )

        local sequence = UI:Create("Dropdown")
        sequence:SetWidth(KB_COL_SEQ)
        local names, order = sequenceList()
        sequence:SetList(names, order)
        for k in pairs(names) do
            if sequenceIsDisabled(k) then sequence:SetItemDisabled(k, true) end
        end
        if not GSE.isEmpty(model.seq) then sequence:SetValue(model.seq) end
        sequence:SetCallback(
            "OnValueChanged",
            function(_, _, key)
                model.seq = key
                markDirty()
            end
        )

        -- The heading above names both columns once, so neither control
        -- carries its own label. SetDropdownStyle(true) is the widget's own
        -- compact mode -- it hides the label, pulls the control to the frame
        -- top and is reapplied by the dropdown's internal refresh, which an
        -- external height tweak is not.
        if sequence.SetDropdownStyle then sequence:SetDropdownStyle(true) end
        -- Pooled Dropdown: one last used as a disabled State dropdown on the
        -- overrides panel comes back with its native frame still greyed (the
        -- pool reset only re-enables the custom button).  Enable explicitly.
        sequence:SetDisabled(false)

        -- Centre the selected value in the field.  applyDropdownStyle pins its
        -- text hard left (LEFT + padLarge, RIGHT at the arrow); span it
        -- symmetrically about the field centre instead, with the left inset
        -- matched to the arrow's measured width so a long sequence name still
        -- stops short of the arrow rather than running under it.  Set after
        -- SetDropdownStyle, which is what creates the arrow.  refresh() only
        -- re-colours the text, so this survives a value change.
        local sequenceButton = sequence.button
        local sequenceArrow = sequenceButton and sequenceButton.dropdownArrow
        local sequenceText = sequenceButton and sequenceButton:GetFontString()
        if sequence.nativeDropdown and UIDropDownMenu_JustifyText then
            -- Native template: NativeUI justifies it LEFT once at creation and
            -- never again, so this holds across value changes.
            UIDropDownMenu_JustifyText(sequence.nativeDropdown, "CENTER")
        elseif sequenceText and sequenceArrow then
            local inset = (sequenceArrow:GetWidth() or 0) + 2
            sequenceText:ClearAllPoints()
            sequenceText:SetPoint("LEFT", sequenceButton, "LEFT", inset, 0)
            sequenceText:SetPoint("RIGHT", sequenceArrow, "LEFT", -2, 0)
            sequenceText:SetJustifyH("CENTER")
        end
        keybind:SetHeight(KB_ROW_HEIGHT)
        remove:SetHeight(KB_ROW_HEIGHT)

        local fieldEdge, fieldPad = dropdownFieldEdge(sequence)
        rowEdges[#rowEdges + 1] = {field = fieldEdge, pad = fieldPad, icon = remove.frame}


        row:AddChild(addSlot)
        row:AddChild(keybind)
        row:AddChild(sequence)
        row:AddChild(remove)
        row:SetHeight(KB_ROW_HEIGHT)
        return row
    end

    redraw = function()
        -- The panel is never empty: a scope with nothing saved opens on one
        -- blank row, and removing the last row leaves one behind, so the +
        -- always has a row to ride on.  A blank row saves to nothing.
        if #rows == 0 then table.insert(rows, {}) end
        wipe(rowEdges)
        rowContainer:ReleaseChildren()
        for i = 1, #rows do
            rowContainer:AddChild(buildRow(i))
        end
        rowContainer:DoLayout()

        tightenRemoveIcons()
        -- The editor builds inside UI:SuspendLayout(), which makes the DoLayout
        -- above a no-op -- the real layout lands a frame later, so the pass
        -- above measured frames that had not been positioned yet.  That is why
        -- the nudge did nothing.  Run it again once layout has actually run;
        -- the slack guard makes it idempotent.
        if C_Timer and C_Timer.After then C_Timer.After(0, tightenRemoveIcons) end
    end



    loadRows()

    -- Header: class and spec as one line.  Inline |T..|t textures keep the
    -- icons hard against their text -- separate Icon widgets each need a fixed
    -- width, which spread the four pieces apart.
    local classid = GSE.GetCurrentClassID()
    local classname, classfile = "", nil
    if GetClassInfo then classname, classfile = GetClassInfo(classid) end
    local specname, specicon
    if GetSpecializationInfo then
        local _, n, _, i = GetSpecializationInfo(tonumber(specialization) or 1)
        specname, specicon = n, i
    end

    -- Class colour, via the same C_ClassColor path the tree uses for its class
    -- nodes.  Falls back to the accent where C_ClassColor is missing.
    local classColour = GSEOptions.KEYWORD
    if classfile and C_ClassColor and C_ClassColor.GetClassColor then
        local colour = C_ClassColor.GetClassColor(classfile)
        if colour and colour.GenerateHexColor then
            classColour = "|c" .. colour:GenerateHexColor()
        end
    end

    local headerText = iconText(GSE.GetClassIcon(classid),
        classColour .. (classname or "") .. Statics.StringReset, 22)
    if specname then
        headerText = headerText .. "  -  " ..
            iconText(specicon, classColour .. specname .. Statics.StringReset, 22)
    end

    local headerLabel = UI:Create("Heading")
    headerLabel:SetWidth(KB_ROW_WIDTH)
    headerLabel:SetJustifyH("CENTER")
    headerLabel:SetJustifyV("MIDDLE")
    headerLabel:SetText(headerText)

    -- Which loadout this panel is editing, as a plain label -- the tree is
    -- where you switch between them, so a second selector here would be two
    -- controls doing one job.
    -- A loadout-specific panel carries that loadout's hero talent art, the
    -- same icon its tree row shows; All Talent Loadouts keeps the generic one.
    -- Guillemets mark the all-loadouts scope as a state rather than a name, so
    -- it does not read like a loadout called "All Talent Loadouts".  Not the
    -- ASCII tilde: that glyph is drawn at cap height, so it floated above the
    -- text no matter how the label was aligned.
    local loadoutName = "« " .. L["All Talent Loadouts"] .. " »"
    local loadoutArt
    if loadout then
        local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(tonumber(loadout))
        loadoutName = (info and info.name) or tostring(loadout)
        loadoutArt = heroTalentElement(tonumber(loadout), tonumber(specialization))
    end
    local loadoutText = "|cffffcc00" .. loadoutName .. Statics.StringReset
    local loadoutLabel = UI:Create("Heading")
    loadoutLabel:SetJustifyH("CENTER")
    loadoutLabel:SetJustifyV("MIDDLE")
    local loadoutRow
    if type(loadoutArt) == "string" then
        -- Ringed medallion beside the name; the ring cannot ride an inline |A|.
        loadoutLabel:SetText(loadoutText)
        -- Width from the string, not the row: a half-row label centred its
        -- text in the middle of its own box, a hand's width from the badge.
        local fs = loadoutLabel.text or loadoutLabel.label
        local textWidth = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
        loadoutLabel:SetWidth(math.max(40, math.ceil(textWidth) + 6))
        loadoutRow = UI:Create("SimpleGroup")
        loadoutRow:SetFullWidth(true)
        loadoutRow:SetLayout("Flow")
        if loadoutRow.SetFlowPadding then loadoutRow:SetFlowPadding(0, 0, 0, 0) end
        if loadoutRow.SetFlowGap then loadoutRow:SetFlowGap(6) end
        if loadoutRow.SetFlowHAlign then loadoutRow:SetFlowHAlign("CENTER") end
        if loadoutRow.SetFlowVAlign then loadoutRow:SetFlowVAlign("CENTER") end
        loadoutRow:AddChild(heroBadge(loadoutArt, 28))
        loadoutRow:AddChild(loadoutLabel)
    else
        loadoutLabel:SetWidth(KB_ROW_WIDTH)
        -- No icon on the all-loadouts header: the guillemets already say it is
        -- a scope, and the generic talent icon read as a loadout of its own.
        loadoutLabel:SetText(heroIconText(loadoutArt, nil, loadoutText, 20))
    end

    saveButton = UI:Create("Button")
    saveButton:SetText(L["Save"])
    saveButton:SetWidth(120)
    saveButton:SetDisabled(true)
    saveButton:SetCallback("OnClick", save)

    rowContainer = UI:Create("SimpleGroup")
    rowContainer:SetFullWidth(true)
    rowContainer:SetLayout("List")
    if rowContainer.SetListGap then rowContainer:SetListGap(2) end

    -- Flow groups default to STYLE.flowPadY above and below their contents.
    -- Stacked, those pads were most of the gap between the headings and the
    -- first row, so the wrappers here carry none.
    local function centeredRow(child)
        local group = UI:Create("SimpleGroup")
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        if group.SetFlowPadding then group:SetFlowPadding(0, 0, 0, 0) end
        if group.SetFlowHAlign then group:SetFlowHAlign("CENTER") end
        group:AddChild(child)
        return group
    end

    -- Column headings, once, sized to the row columns so they line up.
    local headings = UI:Create("SimpleGroup")
    headings:SetFullWidth(true)
    headings:SetLayout("Flow")
    if headings.SetFlowGap then headings:SetFlowGap(6) end
    if headings.SetFlowPadding then headings:SetFlowPadding(0, 0, 0, 0) end
    if headings.SetFlowHAlign then headings:SetFlowHAlign("CENTER") end
    -- Blank heading over the + column so the four columns line up.
    local addHeading = UI:Create("Label")
    addHeading:SetWidth(KB_COL_ADD)
    addHeading:SetText("")
    local keyHeading = UI:Create("Heading")
    keyHeading:SetWidth(KB_COL_KEY)
    keyHeading:SetJustifyH("CENTER")
    keyHeading:SetJustifyV("MIDDLE")
    keyHeading:SetText(iconText(Statics.Icons.Keybindings, KB_HEADING_COLOUR .. L["Keybind"] .. Statics.StringReset))
    local seqHeading = UI:Create("Heading")
    seqHeading:SetWidth(KB_COL_SEQ)
    seqHeading:SetJustifyH("CENTER")
    seqHeading:SetJustifyV("MIDDLE")
    seqHeading:SetText(iconText(Statics.Icons.Sequences, KB_HEADING_COLOUR .. L["Sequence"] .. Statics.StringReset))
    local removeHeading = UI:Create("Label")
    removeHeading:SetWidth(KB_COL_REMOVE)
    removeHeading:SetText("")
    headings:AddChild(addHeading)
    headings:AddChild(keyHeading)
    headings:AddChild(seqHeading)
    headings:AddChild(removeHeading)

    if rightContainer.SetListGap then rightContainer:SetListGap(4) end
    rightContainer:AddChild(centeredRow(headerLabel))
    rightContainer:AddChild(loadoutRow or centeredRow(loadoutLabel))
    rightContainer:AddChild(headings)
    rightContainer:AddChild(rowContainer)

    -- Save is pinned to the bottom of the scroll viewport rather than added as
    -- the last child: the List layout re-anchors every child on each DoLayout
    -- and would drag it back under the final row.  So it is parented to
    -- rightContainer.frame (the ScrollFrame widget's own frame, outside the
    -- scrolling content) and anchored by hand.  ScrollFrame is not a pooled
    -- type, so its OnRelease fires exactly once -- that is where the button
    -- goes back to the Button pool instead of leaking.
    local KB_SAVE_INSET = 8

    -- Horizontally it lines up with the footer's Resources button directly
    -- below it, so the two read as one column.  Centring on the pane instead
    -- left it half the scrollbar reserve off that line.  Measured live from
    -- the two frames rather than derived from the reserve constants, so it
    -- stays right if either changes; re-measured on resize.
    local function pinSave()
        local frame = rightContainer.frame
        if not (frame and saveButton and saveButton.frame) then return end
        local dx = 0
        local resources = (editframe.sectionFooterChildrenCache or {})[1]
        local target = resources and resources.frame
        if target and target.GetCenter and frame.GetCenter then
            local targetX = target:GetCenter()
            local frameX = frame:GetCenter()
            if targetX and frameX then dx = targetX - frameX end
        end
        saveButton.frame:ClearAllPoints()
        saveButton.frame:SetPoint("BOTTOM", frame, "BOTTOM", dx, KB_SAVE_INSET)
    end

    saveButton.frame:SetParent(rightContainer.frame)
    saveButton.frame:SetFrameLevel(rightContainer.frame:GetFrameLevel() + 10)
    saveButton.frame:Show()
    -- One line over Save, anchored to the button so it rides the pin.  Lives
    -- on the ScrollFrame's own frame, which is not pooled, so it goes away
    -- with the pane rather than leaking into another panel.
    local saveHint = rightContainer.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveHint:SetPoint("BOTTOM", saveButton.frame, "TOP", 0, 4)
    saveHint:SetText(L["Set All of your Binds and Click Save!"])
    pinSave()
    -- The footer lays out on the same frame this panel is built in, so its
    -- button may not have its final position yet on the first pass.
    if C_Timer and C_Timer.After then C_Timer.After(0, pinSave) end
    if rightContainer.frame.HookScript then rightContainer.frame:HookScript("OnSizeChanged", pinSave) end
    rightContainer:SetCallback("OnRelease", function() saveButton:Release() end)

    -- Without a gutter the last row scrolls underneath the pinned button.
    local bottomGutter = UI:Create("Spacer")
    bottomGutter:SetFullWidth(true)
    bottomGutter:SetHeight(saveButton.frame:GetHeight() + KB_SAVE_INSET * 2 + 18)
    rightContainer:AddChild(bottomGutter)

    redraw()
end


-- ---------------------------------------------------------------------------
-- Actionbar Overrides: the same panel shape as keybinds.
-- ---------------------------------------------------------------------------
local AO_COL_BUTTON, AO_COL_STATE, AO_COL_SEQ = 200, 110, 220
local AO_ROW_WIDTH = KB_COL_ADD + AO_COL_BUTTON + AO_COL_STATE + AO_COL_SEQ + KB_COL_REMOVE + 24

-- Every action button this client can override, name -> name.  One scan per
-- panel build, not per row: ButtonForge alone is a thousand _G lookups.
local function actionButtonNames()
    local buttonnames = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "MultiBarLeftButton", "MultiBarRightButton"
    }
    local buttonlist = {}
    if ElvUI then
        for i = 15, 1, -1 do table.insert(buttonnames, 1, "ElvUI_Bar" .. i .. "Button") end
    end
    if NDui then
        for i = 15, 1, -1 do table.insert(buttonnames, 1, "NDui_ActionBar" .. i .. "Button") end
    end
    for _, v in ipairs(buttonnames) do
        for i = 1, 12 do
            if _G[v .. i] then buttonlist[v .. i] = v .. i end
        end
    end
    if ConsolePort then
        for _, pad in ipairs({"PADDUP", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADLSHOULDER", "PADRSHOULDER",
            "PADRTRIGGER", "PADLTRIGGER", "PAD1", "PAD2", "PAD3", "PAD4"}) do
            buttonlist["CPB_" .. pad] = "CPB_" .. pad
        end
    end
    if Bartender4 then
        for i = 1, 180 do
            local name = "BT4Button" .. i
            if _G[name] and _G[name]:IsShown() then buttonlist[name] = name end
        end
    end
    if Dominos then
        -- Dominos frame names differ between retail and Classic; list every
        -- pattern either flavour uses (missing names just never match _G).
        for i = 1, 24 do
            if _G["DominosActionButton" .. i] then buttonlist["DominosActionButton" .. i] = "DominosActionButton" .. i end
        end
        for i = 73, 168 do
            if _G["DominosActionButton" .. i] then buttonlist["DominosActionButton" .. i] = "DominosActionButton" .. i end
        end
        for _, prefix in ipairs({"MultiBarRightActionButton", "MultiBarLeftActionButton",
            "MultiBarBottomRightActionButton", "MultiBarBottomLeftActionButton",
            "MultiBar5ActionButton", "MultiBar6ActionButton", "MultiBar7ActionButton"}) do
            for i = 1, 12 do
                if _G[prefix .. i] then buttonlist[prefix .. i] = prefix .. i end
            end
        end
    end
    if BFButton then
        -- ButtonForge numbers bars and buttons on separate counters under one
        -- prefix; only the CheckButtons are action buttons.
        for i = 1, 1000 do
            local f = _G["ButtonForge" .. i]
            if f and f:IsObjectType("CheckButton") then buttonlist["ButtonForge" .. i] = "ButtonForge" .. i end
        end
    end
    -- EllesmereUI's action bars are its own frames, not Blizzard's, so no
    -- prefix above finds them. Created as "EABButton" .. slot by
    -- EllesmereUIActionBars (GetOrCreateButton); 180 is the slot ceiling that
    -- addon scans to itself.
    --
    -- Tested for by frame, the way the rest of GSE tests for these: Utils.lua
    -- gates its OnClick hook on _G["EABButton1"] and Events.lua matches the
    -- name with string.sub(Button, 1, 9) == "EABButton". Neither reads a bare
    -- EllesmereUI global -- which is why none is declared in .luacheckrc, and
    -- why reading one here would be the only such access in the addon. It
    -- would also be the wrong question: the frames are made by
    -- EllesmereUIActionBars, a different addon from EllesmereUI. No outer gate
    -- at all, so a setup whose first built slot is not 1 still lists.
    -- Grouping is automatic -- actionButtonGroups splits the trailing number,
    -- so these land under one "EABButton" submenu.
    for i = 1, 180 do
        if _G["EABButton" .. i] then buttonlist["EABButton" .. i] = "EABButton" .. i end
    end
    -- Anything a saved override names that exists but was not auto-detected.
    local binds = GSE_C["ActionBarBinds"] or {}
    for _, buttons in pairs(binds["Specialisations"] or {}) do
        for _, override in pairs(buttons) do
            local name = type(override) == "table" and override.Bind
            if name and _G[name] then buttonlist[name] = name end
        end
    end
    for _, loadouts in pairs(binds["LoadOuts"] or {}) do
        for _, buttons in pairs(loadouts) do
            for _, override in pairs(buttons) do
                local name = type(override) == "table" and override.Bind
                if name and _G[name] then buttonlist[name] = name end
            end
        end
    end
    local order = {}
    for k in pairs(buttonlist) do table.insert(order, k) end
    return buttonlist, GSE.SortTableAlphabetical(order)
end

-- The button names grouped by bar for a nested menu: "MultiBar5Button7" ->
-- group "MultiBar5Button", item 7.  Groups keep the order the names were
-- sorted in; items sort by their number.  Names with no trailing number
-- (ConsolePort's CPB_PADDUP) are their own single entry.
local function actionButtonGroups(order)
    local groups, byName = {}, {}
    for _, name in ipairs(order) do
        local prefix, num = string.match(name, "^(.-)(%d+)$")
        if not prefix then prefix, num = name, nil end
        local group = byName[prefix]
        if not group then
            group = {prefix = prefix, items = {}}
            byName[prefix] = group
            groups[#groups + 1] = group
        end
        group.items[#group.items + 1] = {name = name, num = tonumber(num) or 0}
    end
    for _, group in ipairs(groups) do
        table.sort(group.items, function(a, b) return a.num < b.num end)
    end
    return groups
end

-- LibActionButton state handling, unchanged from the old panel: the state
-- that means "no override state" depends on which bar addon owns the button.
local function stateDefaultFor(buttonName)
    if string.sub(buttonName, 1, 3) == "BT4" then return "0" end
    if string.sub(buttonName, 1, 4) == "NDui_" then return "2" end
    if string.sub(buttonName, 1, 4) == "CPB_" then return "" end
    return "1"
end
local function stateListFor(buttonName)
    local frame = buttonName and _G[buttonName]
    if not (frame and frame.state_types) then return nil end
    local states, order = {["Default"] = "Default"}, {"Default"}
    local default = stateDefaultFor(buttonName)
    for k in pairs(frame.state_types) do
        if k ~= default and k ~= buttonName then
            states[k] = k
            table.insert(order, k)
        end
    end
    return states, order
end

-- ponytail: a second copy of the keybind panel's skeleton (header, headings,
-- rows, Save pinning) rather than a shared builder parameterised by row
-- shape.  Fold the two into one once this panel has been confirmed on the
-- same terms the keybind one was; refactoring a panel Larry has just signed
-- off on to save 120 lines is the wrong trade today.
local showOverridePanel
showOverridePanel = function(editframe, specialization, loadout, rightContainer)
    specialization = tostring(specialization or defaultSpecIndex())

    local rows = {}
    local saveButton, rowContainer, redraw
    -- One chain per row: the row's frames left to right, and for each frame
    -- that is a dropdown, the frame + pad whose RIGHT edge is its visible
    -- edge (dropdownFieldEdge).  The heading cells are a chain too, shifted
    -- by whatever the first row measured so they stay over their columns.
    local rowChains, headingFrames = {}, {}
    -- Per-column heading offset from the measured centre, negative = left.
    -- Part of the target, not an extra slide, so the measured pass still
    -- converges instead of re-applying it on every run.
    local headingNudge = {[2] = -10}
    local buttonNames, buttonOrder = actionButtonNames()

    -- Negative `by` slides right; both directions are used below.
    local function slideLeft(frame, by)
        if not (frame and frame.GetPoint) or math.abs(by) <= 0.5 then return end
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if point then frame:SetPoint(point, relativeTo, relativePoint, (x or 0) - by, y or 0) end
    end

    -- Same padding as the keybind rows, at every gap: the keybind panel has
    -- one dropdown and closes the gap after it; these rows have three, so the
    -- pass walks the whole row.  For each control whose visible edge is
    -- short of its frame, everything after it slides left by the measured
    -- slack.  Positions update as points are set, so the walk reads real
    -- values and a second run finds nothing to move.
    local function tightenRows()
        local first
        for _, chain in ipairs(rowChains) do
            -- Skip until the layout has actually placed the row (under
            -- UI:SuspendLayout the frames have no points yet).
            if chain.frames[1].GetLeft and chain.frames[1]:GetLeft() then
                local carried = 0
                for i = 1, #chain.frames - 1 do
                    local edge = chain.edges[i]
                    local nextFrame = chain.frames[i + 1]
                    if edge and edge.frame and edge.frame.GetRight and nextFrame.GetLeft then
                        local visibleRight, nextLeft = edge.frame:GetRight(), nextFrame:GetLeft()
                        if visibleRight and nextLeft then
                            local slack = nextLeft - (visibleRight + (edge.pad or 0) + KB_ICON_GAP)
                            if slack > 0.5 then
                                for j = i + 1, #chain.frames do slideLeft(chain.frames[j], slack) end
                                carried = carried + slack
                            end
                        end
                    end
                end
                -- The row shrank by `carried`; give half back so the tightened
                -- row is centred where the loose one was.
                if carried > 0.5 then
                    for _, frame in ipairs(chain.frames) do slideLeft(frame, -carried / 2) end
                end
                first = first or chain
            end
        end
        -- Headings: centre each over the VISIBLE box of its column's control
        -- on the first row -- frame left to the arrow's right edge -- not
        -- over the frame, which the native dropdown never fills.
        if first then
            for i, headingFrame in ipairs(headingFrames) do
                local control, edge = first.frames[i], first.edges[i]
                if control and headingFrame.GetCenter and control.GetLeft then
                    local left = control:GetLeft()
                    local right = edge and edge.frame and edge.frame.GetRight and edge.frame:GetRight()
                    right = right and (right + (edge.pad or 0)) or (control.GetRight and control:GetRight())
                    local have = headingFrame:GetCenter()
                    if left and right and have then
                        slideLeft(headingFrame, have - ((left + right) / 2 + (headingNudge[i] or 0)))
                    end
                end
            end
        end
    end

    local function loadRows()
        wipe(rows)
        local scope = overrideScope(specialization, loadout, false) or {}
        local keys = {}
        for k, v in pairs(scope) do
            if type(v) == "table" then table.insert(keys, k) end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = scope[k]
            table.insert(rows, {bind = v.Bind or k, state = v.State, seq = v.Sequence})
        end
    end

    local function markDirty()
        if saveButton then saveButton:SetDisabled(false) end
    end

    local function sequenceList()
        local names, order = {}, {}
        for _, source in ipairs({GSESequences[GSE.GetCurrentClassID()] or {}, GSESequences[0] or {}}) do
            for k in pairs(source) do
                if not names[k] then
                    names[k] = sequenceIsDisabled(k) and k .. " (" .. L["Sequence Disabled"] .. ")" or k
                    table.insert(order, k)
                end
            end
        end
        return names, GSE.SortTableAlphabetical(order)
    end

    local function rowKey(r)
        if GSE.isEmpty(r.bind) then return nil end
        if r.state and r.state ~= "Default" and r.state ~= stateDefaultFor(r.bind) then
            return r.bind .. "-" .. r.state
        end
        return r.bind
    end

    local function save()
        if InCombatLockdown() then
            GSE.Print(L["Actionbar Overrides"] .. ": " .. (ERR_NOT_IN_COMBAT or "not in combat"))
            return
        end
        local seen = {}
        for _, r in ipairs(rows) do
            local key = rowKey(r)
            if key then
                if seen[key] then
                    GSE.Print(string.format(L["%s is overridden more than once.  Change or remove one before saving."], key))
                    return
                end
                seen[key] = true
            end
        end

        local scope = overrideScope(specialization, loadout, true)
        for k, v in pairs(scope) do
            if type(v) == "table" then scope[k] = nil end
        end
        for _, r in ipairs(rows) do
            local key = rowKey(r)
            if key and not GSE.isEmpty(r.seq) then
                local state = r.state
                if state == "Default" or state == stateDefaultFor(r.bind) then state = nil end
                scope[key] = {Bind = r.bind, State = state, Sequence = r.seq}
            end
        end
        if loadout and not next(scope) then
            GSE_C["ActionBarBinds"]["LoadOuts"][specialization][loadout] = nil
        end

        -- LoadOverrides reverts every live override before re-arming from the
        -- data, so rows removed here go dead on this call.
        GSE.ReloadOverrides()
        for _, r in ipairs(rows) do
            if not GSE.isEmpty(r.seq) and _G[r.seq] and GSE.UpdateIcon then GSE.UpdateIcon(_G[r.seq]) end
        end
        if saveButton then saveButton:SetDisabled(true) end
        loadRows()
        redraw()
        editframe.ManageTree()
    end

    local function compactDropdown(dropdown)
        if dropdown.SetDropdownStyle then dropdown:SetDropdownStyle(true) end
        if dropdown.nativeDropdown and UIDropDownMenu_JustifyText then
            UIDropDownMenu_JustifyText(dropdown.nativeDropdown, "CENTER")
        end
        -- Dropdown is pooled.  SetDisabled(true) -- the State column when a
        -- button has no states -- greys the NATIVE frame via
        -- UIDropDownMenu_DisableDropDown, and the pool's reset re-enables
        -- only the custom button, so a recycled widget came back grey with
        -- no arrow.  Enable explicitly once the style (and native frame)
        -- exists; the State column re-disables itself right after if needed.
        dropdown:SetDisabled(false)
    end

    local function buildRow(index)
        local model = rows[index]
        local row = UI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        if row.SetFlowGap then row:SetFlowGap(6) end
        if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
        if row.SetFlowVAlign then row:SetFlowVAlign("CENTER") end
        if row.SetFlowHAlign then row:SetFlowHAlign("CENTER") end

        local addSlot
        if index == #rows then
            addSlot = UI:Create("Icon")
            addSlot:SetImage(Statics.ActionsIcons.Add)
            addSlot:SetImageSize(KB_ICON_SIZE, KB_ICON_SIZE)
            local full = #rows >= KB_MAX_ROWS
            addSlot:SetCallback("OnClick", function()
                if #rows >= KB_MAX_ROWS then return end
                table.insert(rows, {})
                redraw()
            end)
            addSlot:SetCallback("OnEnter", function()
                GSE.CreateToolTip(L["Add"],
                    full and string.format(L["Limit of %d rows."], KB_MAX_ROWS) or L["Add a row below this one."],
                    editframe)
            end)
            -- At the cap the + stays in its slot, greyed, and says why.
            if full then addSlot:SetDisabled(true) end
            addSlot:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        else
            addSlot = UI:Create("Spacer")
        end
        addSlot:SetWidth(KB_COL_ADD)
        addSlot:SetHeight(KB_ROW_HEIGHT)

        local remove = UI:Create("Icon")
        remove:SetImage(Statics.ActionsIcons.DeleteX)
        remove:SetImageSize(KB_ICON_SIZE, KB_ICON_SIZE)
        remove:SetWidth(KB_COL_REMOVE)
        remove:SetHeight(KB_ROW_HEIGHT)
        -- The Flow layout honours flowYOffset: lifts the X the 2px it sat
        -- below the dropdown's centre line (Larry, 2026-09-08).
        remove.flowYOffset = 2
        remove:SetCallback("OnEnter", function()
            -- The only row is cleared, not removed; say which.
            local text = #rows <= 1 and L["Clear this row."] or L["Remove this row."]
            GSE.CreateToolTip(L["Remove"], text, editframe)
        end)
        remove:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        remove:SetCallback("OnClick", function()
            if #rows <= 1 then
                if GSE.isEmpty(model.bind) and GSE.isEmpty(model.seq) then return end
                rows[index] = {}
            else
                table.remove(rows, index)
            end
            markDirty()
            redraw()
        end)

        local state = UI:Create("Dropdown")
        state:SetWidth(AO_COL_STATE)
        local function refreshStates()
            local states, order = stateListFor(model.bind)
            if states then
                state:SetList(states, order)
                state:SetValue(model.state or "Default")
                state:SetDisabled(false)
            else
                state:SetList({["Default"] = "Default"}, {"Default"})
                state:SetValue("Default")
                state:SetDisabled(true)
                model.state = nil
            end
        end
        state:SetCallback("OnValueChanged", function(_, _, key)
            model.state = key ~= "Default" and key or nil
            markDirty()
        end)

        -- ~100 action buttons is too many for one flat list.  The picker is
        -- a button showing the current name that opens a NESTED menu -- one
        -- submenu per bar -- through MenuUtil, as the tree's right-click
        -- menus do.  Falls back to a flat menu where MenuUtil is missing.
        local button = UI:Create("Button")
        button:SetWidth(AO_COL_BUTTON)
        button:SetHeight(KB_ROW_HEIGHT)
        local function refreshButtonText()
            button:SetText(GSE.isEmpty(model.bind) and L["Pick a button"] or model.bind)
        end
        local function choose(name)
            model.bind = name
            model.state = nil
            refreshButtonText()
            refreshStates()
            markDirty()
        end
        button:SetCallback("OnClick", function()
            if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
            MenuUtil.CreateContextMenu(button.frame, function(_, root)
                root:CreateTitle(L["Actionbar Buttons"])
                -- A saved button not on this client right now still shows.
                if not GSE.isEmpty(model.bind) and not buttonNames[model.bind] then
                    root:CreateButton(model.bind, function() choose(model.bind) end)
                end
                for _, group in ipairs(actionButtonGroups(buttonOrder)) do
                    if #group.items == 1 then
                        local name = group.items[1].name
                        root:CreateButton(name, function() choose(name) end)
                    else
                        local sub = root:CreateButton(group.prefix)
                        for _, item in ipairs(group.items) do
                            sub:CreateRadio(item.name,
                                function() return model.bind == item.name end,
                                function() choose(item.name) end)
                        end
                    end
                end
                -- Everything above is a prefix GSE knows. A bar addon released
                -- after this build is not on that list, and waiting for a GSE
                -- release to bind to it is a poor answer when the frame is
                -- sitting there in game -- so let it be named directly.
                --
                -- It has to EXIST and be a Button: the apply path calls
                -- _G[name]:SetAttribute("gse-button", ...) (Events.lua), which
                -- a typo or a bar that is not loaded would error on. Checking
                -- here turns that into a message. CheckButton passes -- it is a
                -- Button -- which is what every bar addon actually creates.
                if UI and UI.ShowInputDialog then
                    root:CreateDivider()
                    root:CreateButton(L["Type a button name..."], function()
                        UI.ShowInputDialog({
                            owner      = editframe,
                            title      = L["Name an Actionbar Button"],
                            prompt     = L["Enter the frame name of the button:"],
                            note       = L["For a bar addon GSE does not detect yet.  The button must exist right now -- /fstack over it in game to read its name."],
                            default    = model.bind,
                            acceptText = L["Use"],
                            maxLetters = 80,
                            onAccept   = function(name)
                                if GSE.isEmpty(name) then return end
                                local frame = _G[name]
                                if not (frame and type(frame) == "table" and frame.IsObjectType
                                    and frame:IsObjectType("Button")) then
                                    GSE.Print(string.format(
                                        L["%s is not an actionbar button on this client."], name), L["Actionbar Overrides"])
                                    return
                                end
                                choose(name)
                            end,
                        })
                    end)
                end
            end)
        end)
        refreshButtonText()

        local sequence = UI:Create("Dropdown")
        sequence:SetWidth(AO_COL_SEQ)
        local seqNames, seqOrder = sequenceList()
        sequence:SetList(seqNames, seqOrder)
        for k in pairs(seqNames) do
            if sequenceIsDisabled(k) then sequence:SetItemDisabled(k, true) end
        end
        if not GSE.isEmpty(model.seq) then sequence:SetValue(model.seq) end
        sequence:SetCallback("OnValueChanged", function(_, _, key)
            model.seq = key
            markDirty()
        end)

        compactDropdown(state)
        compactDropdown(sequence)
        refreshStates()

        -- Column order: button, sequence, state.
        local chain = {frames = {addSlot.frame, button.frame, sequence.frame, state.frame, remove.frame}, edges = {}}
        for i, dropdown in pairs({[3] = sequence, [4] = state}) do
            local edgeFrame, pad = dropdownFieldEdge(dropdown)
            chain.edges[i] = {frame = edgeFrame, pad = pad}
        end
        rowChains[#rowChains + 1] = chain

        row:AddChild(addSlot)
        row:AddChild(button)
        row:AddChild(sequence)
        row:AddChild(state)
        row:AddChild(remove)
        row:SetHeight(KB_ROW_HEIGHT)
        return row
    end

    redraw = function()
        if #rows == 0 then table.insert(rows, {}) end
        wipe(rowChains)
        rowContainer:ReleaseChildren()
        for i = 1, #rows do
            rowContainer:AddChild(buildRow(i))
        end
        rowContainer:DoLayout()
        -- Once now, once after the editor's suspended layout has really run.
        tightenRows()
        if C_Timer and C_Timer.After then C_Timer.After(0, tightenRows) end
    end

    loadRows()

    local classid = GSE.GetCurrentClassID()
    local classname, classfile = "", nil
    if GetClassInfo then classname, classfile = GetClassInfo(classid) end
    local specname, specicon
    if GetSpecializationInfo then
        local _, n, _, i = GetSpecializationInfo(tonumber(specialization) or 1)
        specname, specicon = n, i
    end
    local classColour = GSEOptions.KEYWORD
    if classfile and C_ClassColor and C_ClassColor.GetClassColor then
        local colour = C_ClassColor.GetClassColor(classfile)
        if colour and colour.GenerateHexColor then classColour = "|c" .. colour:GenerateHexColor() end
    end
    local headerText = iconText(GSE.GetClassIcon(classid), classColour .. (classname or "") .. Statics.StringReset, 22)
    if specname then
        headerText = headerText .. "  -  " .. iconText(specicon, classColour .. specname .. Statics.StringReset, 22)
    end
    local headerLabel = UI:Create("Heading")
    headerLabel:SetWidth(AO_ROW_WIDTH)
    headerLabel:SetJustifyH("CENTER")
    headerLabel:SetJustifyV("MIDDLE")
    headerLabel:SetText(headerText)

    local loadoutName, loadoutArt = "« " .. L["All Talent Loadouts"] .. " »", nil
    if loadout then
        local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(tonumber(loadout))
        loadoutName = (info and info.name) or tostring(loadout)
        loadoutArt = heroTalentElement(tonumber(loadout), tonumber(specialization))
    end
    local loadoutText = "|cffffcc00" .. loadoutName .. Statics.StringReset
    local loadoutLabel = UI:Create("Heading")
    loadoutLabel:SetJustifyH("CENTER")
    loadoutLabel:SetJustifyV("MIDDLE")

    local function centeredRow(child)
        local group = UI:Create("SimpleGroup")
        group:SetFullWidth(true)
        group:SetLayout("Flow")
        if group.SetFlowPadding then group:SetFlowPadding(0, 0, 0, 0) end
        if group.SetFlowGap then group:SetFlowGap(6) end
        if group.SetFlowHAlign then group:SetFlowHAlign("CENTER") end
        if group.SetFlowVAlign then group:SetFlowVAlign("CENTER") end
        if child then group:AddChild(child) end
        return group
    end

    local loadoutRow
    if type(loadoutArt) == "string" then
        loadoutLabel:SetText(loadoutText)
        local fs = loadoutLabel.text or loadoutLabel.label
        local textWidth = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
        loadoutLabel:SetWidth(math.max(40, math.ceil(textWidth) + 6))
        loadoutRow = centeredRow(nil)
        loadoutRow:AddChild(heroBadge(loadoutArt, 28))
        loadoutRow:AddChild(loadoutLabel)
    else
        loadoutLabel:SetWidth(AO_ROW_WIDTH)
        -- No icon on the all-loadouts header: the guillemets already say it is
        -- a scope, and the generic talent icon read as a loadout of its own.
        loadoutLabel:SetText(heroIconText(loadoutArt, nil, loadoutText, 20))
        loadoutRow = centeredRow(loadoutLabel)
    end

    saveButton = UI:Create("Button")
    saveButton:SetText(L["Save"])
    saveButton:SetWidth(120)
    saveButton:SetDisabled(true)
    saveButton:SetCallback("OnClick", save)

    rowContainer = UI:Create("SimpleGroup")
    rowContainer:SetFullWidth(true)
    rowContainer:SetLayout("List")
    if rowContainer.SetListGap then rowContainer:SetListGap(2) end

    local headings = UI:Create("SimpleGroup")
    headings:SetFullWidth(true)
    headings:SetLayout("Flow")
    if headings.SetFlowGap then headings:SetFlowGap(6) end
    if headings.SetFlowPadding then headings:SetFlowPadding(0, 0, 0, 0) end
    if headings.SetFlowHAlign then headings:SetFlowHAlign("CENTER") end
    local function heading(width, icon, text)
        local h = UI:Create("Heading")
        h:SetWidth(width)
        h:SetHeight(KB_ROW_HEIGHT)
        h:SetJustifyH("CENTER")
        h:SetJustifyV("MIDDLE")
        h:SetText(icon and iconText(icon, KB_HEADING_COLOUR .. text .. Statics.StringReset)
            or (KB_HEADING_COLOUR .. text .. Statics.StringReset))
        return h
    end
    local blankAdd = UI:Create("Label"); blankAdd:SetWidth(KB_COL_ADD); blankAdd:SetText("")
    local blankRemove = UI:Create("Label"); blankRemove:SetWidth(KB_COL_REMOVE); blankRemove:SetText("")
    -- Same order as the row: button, sequence, state.  Recorded so the
    -- tighten pass can slide each heading by what its column moved.
    wipe(headingFrames)
    for _, cell in ipairs({
        blankAdd,
        heading(AO_COL_BUTTON, Statics.Icons.Button, L["Actionbar Buttons"]),
        heading(AO_COL_SEQ, Statics.Icons.Sequences, L["Sequence"]),
        heading(AO_COL_STATE, nil, L["State"]),
        blankRemove,
    }) do
        headings:AddChild(cell)
        headingFrames[#headingFrames + 1] = cell.frame
    end

    if rightContainer.SetListGap then rightContainer:SetListGap(4) end
    rightContainer:AddChild(centeredRow(headerLabel))
    rightContainer:AddChild(loadoutRow)
    rightContainer:AddChild(headings)
    rightContainer:AddChild(rowContainer)

    -- Save pinned to the viewport bottom, centred on the footer's Resources
    -- button; identical mechanism to the keybind panel.
    local KB_SAVE_INSET = 8
    local function pinSave()
        local frame = rightContainer.frame
        if not (frame and saveButton and saveButton.frame) then return end
        local dx = 0
        local resources = (editframe.sectionFooterChildrenCache or {})[1]
        local target = resources and resources.frame
        if target and target.GetCenter and frame.GetCenter then
            local targetX, frameX = target:GetCenter(), frame:GetCenter()
            if targetX and frameX then dx = targetX - frameX end
        end
        saveButton.frame:ClearAllPoints()
        saveButton.frame:SetPoint("BOTTOM", frame, "BOTTOM", dx, KB_SAVE_INSET)
    end
    saveButton.frame:SetParent(rightContainer.frame)
    saveButton.frame:SetFrameLevel(rightContainer.frame:GetFrameLevel() + 10)
    saveButton.frame:Show()
    -- One line over Save, anchored to the button so it rides the pin.  Lives
    -- on the ScrollFrame's own frame, which is not pooled, so it goes away
    -- with the pane rather than leaking into another panel.
    local saveHint = rightContainer.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveHint:SetPoint("BOTTOM", saveButton.frame, "TOP", 0, 4)
    saveHint:SetText(L["Set All of your Binds and Click Save!"])
    pinSave()
    if C_Timer and C_Timer.After then C_Timer.After(0, pinSave) end
    if rightContainer.frame.HookScript then rightContainer.frame:HookScript("OnSizeChanged", pinSave) end
    rightContainer:SetCallback("OnRelease", function() saveButton:Release() end)

    local bottomGutter = UI:Create("Spacer")
    bottomGutter:SetFullWidth(true)
    bottomGutter:SetHeight(saveButton.frame:GetHeight() + KB_SAVE_INSET * 2 + 18)
    rightContainer:AddChild(bottomGutter)

    redraw()
end

local function showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
    if type == "KB" then
        showKeybindPanel(editframe, specialization, loadout, rightContainer)
    elseif type == "AO" then
        showOverridePanel(editframe, specialization, loadout, rightContainer)
    end
end

-- ---------------------------------------------------------------------------
-- showKeybindChooser(editframe, rightContainer)
-- The landing panel for the Keybindings tree node itself, which used to leave
-- a blank pane.  Two tiles -- Actionbar Overrides and Keybindings -- each an
-- icon over its own description.  Clicking one SELECTS that area's tree node
-- rather than drawing its window here, so the tree and the pane stay in step
-- and there is only ever one copy of each panel's build code.
-- ---------------------------------------------------------------------------
local KB_TILE_ICON_SIZE = 64
-- Two columns that always fit: each tile takes 49% of the pane's content
-- width with no flow gap between them, so the pair never wraps onto two rows
-- the way a fixed 340 + 40 + 340 did in an ~800px pane.
local KB_TILE_RELATIVE_WIDTH = 0.49

-- A wrapped paragraph.  Word wrap is forced on and the height is measured
-- from the FontString AFTER layout has given the label its real width -- at
-- SetText time the width is not final (relative widths resolve in layout,
-- and the editor builds under UI:SuspendLayout), so a height taken then is a
-- one-line height and the text renders as a single line ending in "...".
-- Every paragraph registers itself so one deferred pass can fit them all.
local pendingParagraphs = {}
local function paragraph(text, colour, justify)
    local label = UI:Create("Label")
    label:SetFullWidth(true)
    label:SetJustifyH(justify or "LEFT")
    local fs = label.text or label.label
    if fs then
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(0) end
    end
    label:SetHeight(400)
    label:SetText((colour or "") .. text .. (colour and Statics.StringReset or ""))
    pendingParagraphs[#pendingParagraphs + 1] = label
    return label
end

local function fitParagraphs(rightContainer)
    for _, label in ipairs(pendingParagraphs) do
        local fs = label.text or label.label
        if fs and fs.GetStringHeight and label.frame and label.frame:IsShown() then
            local h = fs:GetStringHeight()
            if h and h > 0 then label:SetHeight(math.ceil(h) + 4) end
        end
    end
    if rightContainer and rightContainer.DoLayout then rightContainer:DoLayout() end
end

-- A centred picture at its own aspect, as a fixed-size group.  Raw texture on
-- the group's frame, cached per frame in a weak table because SimpleGroup is
-- pooled and the pool sweeps caller fields (same as heroBadge).
local pictureArt = setmetatable({}, {__mode = "k"})
local function picture(path, width, height, xOffset)
    local host = UI:Create("SimpleGroup")
    host:SetWidth(width)
    host:SetHeight(height)
    -- Flow layout honours child.flowXOffset: a sideways nudge from where the
    -- cell would otherwise centre it.
    host.flowXOffset = xOffset
    local art = pictureArt[host.frame]
    if not art then
        art = host.frame:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints(host.frame)
        -- A UI capture goes to mud when scaled or snapped to the pixel grid;
        -- drawn 1:1 with snapping off it stays as sharp as the capture.
        if art.SetSnapToPixelGrid then art:SetSnapToPixelGrid(false) end
        if art.SetTexelSnappingBias then art:SetTexelSnappingBias(0) end
        pictureArt[host.frame] = art
    end
    art:SetTexture(path)
    art:SetTexCoord(0, 1, 0, 1)
    art:Show()
    return host
end

-- Caption under the bullets, arrows on the OUTSIDE of their words so the
-- line reads "[down] KEY-DOWN / KEY-UP [up]": part.after puts the arrow
-- after the word, otherwise it leads.  Inline so each pair stays together.
local KB_CAPTION_ICON_SIZE = 18
local function keyCaption(parts)
    local label = UI:Create("Label")
    label:SetFullWidth(true)
    label:SetJustifyH("CENTER")
    label:SetHeight(KB_CAPTION_ICON_SIZE + 10)
    label:SetJustifyV("MIDDLE")
    -- An inline |T| already centres on the text line; a vertical offset here
    -- only moves it OFF that line (a -3 "correction" put the arrows 3px low).
    local pieces = {}
    for _, part in ipairs(parts) do
        local arrow = "|T" .. part.icon .. ":" .. KB_CAPTION_ICON_SIZE .. ":" .. KB_CAPTION_ICON_SIZE .. "|t"
        local word = "|cffffd100" .. part.text .. Statics.StringReset
        pieces[#pieces + 1] = part.after and (word .. " " .. arrow) or (arrow .. " " .. word)
    end
    label:SetText(table.concat(pieces, "   /   "))
    return label
end

-- Two half-width cells on one row, each centring whatever it holds, so the
-- captions -- and the picture -- line up across the two tiles regardless of
-- how far each tile's bullets wrapped.
local function halfRow(leftChild, rightChild, topPad, vCenter)
    local row = UI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    if row.SetFlowPadding then row:SetFlowPadding(0, topPad or 0, 0, 0) end
    if row.SetFlowGap then row:SetFlowGap(0) end
    -- The row is as tall as its taller cell; with vCenter the shorter cell's
    -- content sits in the middle of that height instead of at its top.
    if vCenter and row.SetFlowVAlign then row:SetFlowVAlign("CENTER") end
    local cells = {}
    for _, child in ipairs({leftChild or false, rightChild or false}) do
        local cell = UI:Create("SimpleGroup")
        cell:SetRelativeWidth(KB_TILE_RELATIVE_WIDTH)
        cell:SetLayout("Flow")
        if cell.SetFlowPadding then cell:SetFlowPadding(0, 0, 0, 0) end
        if cell.SetFlowHAlign then cell:SetFlowHAlign("CENTER") end
        if child then cell:AddChild(child) end
        row:AddChild(cell)
        cells[#cells + 1] = cell
    end
    return row, cells[1], cells[2]
end

-- The whole column is one target: a button stretched from the column's top
-- cell to its bottom cell, above everything in between, that lights on hover
-- and clicks through to the tile's destination.  Anchored to the cells, so
-- it follows the layout.  Kept per container in a weak table because the
-- rows are pooled widgets and their frames are swept on reuse.
local hotspots = setmetatable({}, {__mode = "k"})
local function columnHotspot(container, index, topCell, bottomCell, onClick)
    local parent = container.content or container.frame
    hotspots[parent] = hotspots[parent] or {}
    local button = hotspots[parent][index]
    if not button then
        button = CreateFrame("Button", nil, parent)
        button:RegisterForClicks("AnyUp")
        -- Rounded highlight: a backdrop with a 9-slice edge whose corner
        -- slices are quarter circles, so the radius stays 16px whatever the
        -- column's size.  A plain HIGHLIGHT texture cannot round its corners.
        local glow = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate" or nil)
        glow:SetAllPoints(button)
        if glow.SetBackdrop then
            glow:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = Statics.Icons.RoundedEdge,
                edgeSize = 16,
                insets = {left = 16, right = 16, top = 16, bottom = 16},
            })
            glow:SetBackdropColor(1, 1, 1, 0.08)
            glow:SetBackdropBorderColor(1, 1, 1, 0.08)
        end
        glow:Hide()
        button:SetScript("OnEnter", function() glow:Show() end)
        button:SetScript("OnLeave", function() glow:Hide() end)
        hotspots[parent][index] = button
    end
    -- Top and sides from the column's top cell; bottom from the pane itself,
    -- so the target runs all the way down the sub-window, not just to the
    -- last row of content.
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", topCell.frame, "TOPLEFT", 0, 0)
    button:SetPoint("TOPRIGHT", topCell.frame, "TOPRIGHT", 0, 0)
    button:SetPoint("BOTTOM", container.frame, "BOTTOM", 0, 0)
    button:SetFrameLevel((bottomCell.frame:GetFrameLevel() or 1) + 20)
    button:SetScript("OnClick", onClick)
    button:Show()
    return button
end

-- Mirror the right column's outer edge off the left column's: the right
-- hotspot's right edge sits as far in from the pane's right as the left
-- hotspot's left edge sits in from the pane's left.  Measured after layout,
-- so the row's own width arithmetic never has to be right for this to be.
local function mirrorHotspots(container)
    local parent = container.content or container.frame
    local pair = hotspots[parent]
    local left, right = pair and pair[1], pair and pair[2]
    if not (left and right and parent.GetLeft and left.GetLeft) then return end
    local parentLeft, parentRight, leftEdge = parent:GetLeft(), parent:GetRight(), left:GetLeft()
    if not (parentLeft and parentRight and leftEdge) then return end
    local inset = leftEdge - parentLeft
    right:SetPoint("RIGHT", parent, "RIGHT", -inset, 0)
end

-- A tile is TWO stacked groups, not one: the top (icon, title, blurb, note)
-- and the bullets.  Laid out as two shared rows across both columns, each
-- row as tall as its taller cell, so the bullet blocks start level even
-- though one note is six lines and the other three.
local function listGroup()
    local group = UI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("List")
    if group.SetListGap then group:SetListGap(6) end
    return group
end

local function chooserTile(icon, title, blurb, note, points, onClick)
    local tile = listGroup()

    local art = UI:Create("Icon")
    art:SetImage(icon)
    art:SetImageSize(KB_TILE_ICON_SIZE, KB_TILE_ICON_SIZE)
    art:SetWidth(KB_TILE_ICON_SIZE)
    art:SetHeight(KB_TILE_ICON_SIZE)
    art:SetCallback("OnClick", onClick)

    -- Flow wrapper so the icon centres over the text below it.
    local artRow = UI:Create("SimpleGroup")
    artRow:SetFullWidth(true)
    artRow:SetLayout("Flow")
    if artRow.SetFlowPadding then artRow:SetFlowPadding(0, 0, 0, 0) end
    if artRow.SetFlowHAlign then artRow:SetFlowHAlign("CENTER") end
    artRow:AddChild(art)

    local heading = UI:Create("InteractiveLabel")
    heading:SetFullWidth(true)
    heading:SetJustifyH("CENTER")
    if heading.SetFontObject then heading:SetFontObject(GameFontHighlightLarge) end
    heading:SetText(KB_HEADING_COLOUR .. title .. Statics.StringReset)
    heading:SetCallback("OnClick", onClick)

    tile:AddChild(artRow)
    tile:AddChild(heading)
    tile:AddChild(paragraph(blurb))
    -- Short how-to under the blurb: ONE centred label with the lines joined,
    -- so they sit at the font's natural line height -- one Label per line
    -- costs each a 20px minimum plus the list gap and reads double-spaced.
    -- Its own group so it can be a shared row, centred in that row's height.
    local noteGroup = listGroup()
    if note and #note > 0 then
        noteGroup:AddChild(paragraph(table.concat(note, "\n"), "|cffffffff", "CENTER"))
    end
    -- The details, one bullet each, in the muted colour so the blurb leads.
    local bullets = listGroup()
    for _, point in ipairs(points) do
        bullets:AddChild(paragraph("|cffffd100-|r  " .. point, "|cffbbbbbb"))
    end
    return tile, noteGroup, bullets
end

local function showKeybindChooser(editframe, rightContainer)
    wipe(pendingParagraphs)

    -- The whole chooser sits 5px right of where the pane's padding puts it.
    if rightContainer.SetListPadding then
        rightContainer:SetListPadding(
            (rightContainer.listPadLeft or 0) + 5, rightContainer.listPadTop or 0,
            math.max(0, (rightContainer.listPadRight or 0) - 5), rightContainer.listPadBottom or 0)
    end

    local function goTo(path)
        if editframe.treeContainer and editframe.treeContainer.SelectByValue then
            editframe.treeContainer:SelectByValue(path)
        end
    end

    -- Where each tile lands: this character's spec, which opens on All Talent
    -- Loadouts; without GetSpecializationInfo no spec nodes exist and the
    -- area node itself is the panel.
    local keybindPath = GetSpecializationInfo
        and ("KEYBINDINGS\001KB\001" .. tostring(defaultSpecIndex()))
        or "KEYBINDINGS\001KB"
    local overridePath = GetSpecializationInfo
        and ("KEYBINDINGS\001AO\001" .. tostring(defaultSpecIndex()))
        or "KEYBINDINGS\001AO"

    -- Content from the GSE wiki, KeyBinding and Actionbar Overrides.
    local overrideTop, overrideNote, overrideBullets = chooserTile(
        Statics.Icons.Button,
        L["Actionbar Overrides"],
        L["Puts a sequence on an action bar button, so the button fires the sequence.  Right-click a button on your bar and pick the sequence; that is the quickest setup."],
        {
            L["Right Click an Empty Action Button"],
            L["Assign a Sequence / Same for Clearing"],
            L["-or-"],
            L["Set in the Left Menu"],
            L["Sets Store by:"],
            L["Class / Spec / State"],
        },
        {
            L["Works with the standard bars, ElvUI, NDui, Bartender4, Dominos and ConsolePort."],
            L["After dismounting in combat the button cannot swap back to the sequence until combat ends."],
            L["Needs the ActionButtonUseKeyDown CVar off (Key Up)."],
        },
        function() goTo(overridePath) end
    )
    local keybindTop, keybindNote, keybindBullets = chooserTile(
        Statics.Icons.Keybindings,
        L["Keybindings"],
        L["Binds a key straight to a sequence, bypassing the action bar.  This is what The War Within requires: a macro can no longer call another macro."],
        {
            L["Set in the Left Menu"],
            L["Sets Store by:"],
            L["Class / Spec"],
        },
        {
            L["Binds are per spec, and optionally per talent loadout; the spec binds are the fallback."],
            L["Controllers work: /console GamePadEnable 1.  PAD1-4 are A, B, X, Y."],
            L["Keys 1-7 stop driving the Sky Riding bar.  Use [flying] in the sequence, or /click ActionButton2."],
        },
        function() goTo(keybindPath) end
    )

    local topRow, overrideTopCell, keybindTopCell = halfRow(overrideTop, keybindTop)
    rightContainer:AddChild(topRow)
    rightContainer:AddChild(halfRow(overrideNote, keybindNote, 6, true))
    rightContainer:AddChild(halfRow(overrideBullets, keybindBullets, 6))

    -- Captions on one shared row so they sit level, then the picture in the
    -- Overrides column under its caption.
    local captionRow = halfRow(
        keyCaption({{text = L["KEY-UP"], icon = Statics.ActionsIcons.Up, after = true}}),
        keyCaption({{text = L["KEY-DOWN"], icon = Statics.ActionsIcons.Down}, {text = L["KEY-UP"], icon = Statics.ActionsIcons.Up, after = true}}),
        8)
    rightContainer:AddChild(captionRow)
    -- The right-click menu, captured at 148x181 and drawn 1:1 -- small enough
    -- that the chooser fits the pane without a scrollbar, and unresampled.
    -- Keybinds gets the hand-on-key icon at the capture's height, and the row
    -- centres its cells vertically, so the two sit level and the icon is in
    -- the middle of the space either way.
    local pictureRow_, overridePictureCell, keybindPictureCell = halfRow(
        picture(Statics.Icons.OverrideMenu, 148, 181),
        picture(Statics.Icons.HandClick, 200, 189, 20), 6, true)
    rightContainer:AddChild(pictureRow_)

    -- Hover + click over each whole column, both running to the bottom of
    -- the pane.
    columnHotspot(rightContainer, 1, overrideTopCell, overridePictureCell, function() goTo(overridePath) end)
    columnHotspot(rightContainer, 2, keybindTopCell, keybindPictureCell, function() goTo(keybindPath) end)

    -- Heights are only right once the widths are: once now for the case
    -- where layout is live, and once more after the editor's suspended
    -- layout actually runs.
    fitParagraphs(rightContainer)
    mirrorHotspots(rightContainer)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            fitParagraphs(rightContainer)
            mirrorHotspots(rightContainer)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Public installer
-- ---------------------------------------------------------------------------
function GSE.GUI.SetupKeybind(editframe)
    editframe.showKeybind = function(bind, button, specialization, loadout, type, rightContainer)
        showKeybind(editframe, bind, button, specialization, loadout, type, rightContainer)
    end
    editframe.showKeybindChooser = function(rightContainer)
        showKeybindChooser(editframe, rightContainer)
    end
    editframe.buildKeybindMenu = buildKeybindMenu
end
end
table.insert(ns.deferred, setup)
