local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- Keybinds and overrides hold the id of the sequence they run (GSE_C is
-- brought up to date at login -- GSE.UpdateCharacterSequenceRefs). A value
-- that is not an id is looked up as a name, for anything that slipped past.
local function sequenceIdOf(ref)
    if ref == nil then return nil end
    if GSE.SequenceEnvelope(ref) then return GSE.ResolveSequenceId(ref) end
    return GSE.FindSequenceId(ref) or GSE.FindSequenceId(ref, nil, true)
end

local function sequenceExists(ref)
    return sequenceIdOf(ref) ~= nil
end

local function sequenceIsDisabled(ref)
    local id = sequenceIdOf(ref)
    local seq = id and GSE.GetSequence(id)
    if seq then
        return seq.MetaData and seq.MetaData.Disabled == true
    end
    return false
end

-- What the player reads for a sequence reference: its label.
local function sequenceLabel(ref)
    local id = sequenceIdOf(ref)
    return (id and GSE.SequenceName(id)) or tostring(ref)
end

-- Append a disabled warning to a tree node label when the sequence is disabled.
local function keybindNodeText(bindLabel, seqName)
    local base = bindLabel .. " " .. GSEOptions.KEYWORD .. "(" .. sequenceLabel(seqName) .. ")" .. Statics.StringReset
    if sequenceIsDisabled(seqName) then
        base = base .. " |cFFFF6600" .. L["Sequence Disabled"] .. "|r"
    end
    return base
end

-- Every saved talent loadout for a spec of the player's class, newest API
-- first.  Empty on clients without talent loadouts, which is what the callers
-- want -- no loadout nodes and a loadout dropdown holding only "All".
-- The saved talent loadout the player is in, for the spec at specIndex: nil
-- unless that is the player's current spec. The same call the keybind and
-- override rebuilds use (GetLastSelectedSavedConfigID), so the loadout with the
-- gold ring is the one whose binds are live.
local function activeLoadoutForSpec(specIndex)
    if not (GSE.HasTalentLoadouts() and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and GetSpecializationInfo) then
        return nil
    end
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    if not (getSpec and getSpec() == specIndex) then return nil end
    local specid = GetSpecializationInfo(specIndex)
    local ok, configid = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specid)
    return ok and configid or nil
end

local function loadoutsForSpec(specIndex)
    if not (GSE.HasTalentLoadouts() and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and GetSpecializationInfoForClassID) then
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
--
-- A spec's own binds are the shared profile's for the class, unless this
-- character has opted out of it for that spec (Profiles.lua); a talent
-- loadout's are always this character's.
local function keybindScope(specialization, loadout, create)
    if not loadout then return GSE.SpecKeyBinds(specialization, create) end
    local loadouts = GSE.SpecLoadoutKeyBinds(specialization, create)
    if not loadouts then return nil end
    if not loadouts[loadout] then
        if not create then return nil end
        loadouts[loadout] = {}
    end
    return loadouts[loadout]
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
    -- The spec's: the shared profile's, or this character's own (Profiles.lua).
    if not loadout then return GSE.SpecOverrides(specialization, create) end
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

-- A page's spec as the tree names it (GSE.BindingSpecs): Retail's
-- specialisation, Primary / Secondary, or nothing when the page is just the
-- class (no second name to show).
local function specLabelFor(specialization, classname)
    for _, spec in ipairs(GSE.BindingSpecs()) do
        if spec.key == tostring(specialization) then
            if spec.label == classname then return nil end
            return spec.label, spec.icon
        end
    end
end

-- The Bindings tree goes area > class > spec > talent loadout, as the other
-- areas go area > class.  Binds are this character's class's, so there is one
-- class node; it is there so the tree reads the same as the rest.
local function bindingsClassNode()
    local classid = GSE.GetCurrentClassID()
    local classname, classfile = GetClassInfo(classid)
    local color = classfile and C_ClassColor and C_ClassColor.GetClassColor(classfile)
    local text = classname or tostring(classid)
    if color and classname then text = WrapTextInColorCode(classname, color:GenerateHexColor()) end
    return {value = tostring(classid), text = text, icon = GSE.GetClassIcon(classid), children = {}}
end

-- The tree path to a spec's page (and a talent loadout's, with `loadout`).
-- area: "AO" or "KB".  Without spec, the class node.
function GSE.GUI.BindingsPath(area, spec, loadout)
    local path = "KEYBINDINGS\001" .. area .. "\001" .. tostring(GSE.GetCurrentClassID())
    if spec then path = path .. "\001" .. tostring(spec) end
    if spec and loadout then path = path .. "\001" .. tostring(loadout) end
    return path
end

-- Unfold the tree down to a Bindings path, wherever the current grouping
-- puts it (gseTreePath maps the by-type path; By Class has Bindings inside
-- the class's group).
function GSE.GUI.ExpandBindingsPath(editframe, path)
    local tree = editframe and editframe.treeContainer
    local status = tree and (tree.status or tree.localstatus)
    if not (status and status.groups) then return end
    if tree.gseTreePath then path = tree.gseTreePath(path) end
    local parts = {("\001"):split(path)}
    for n = 1, #parts do status.groups[table.concat(parts, "\001", 1, n)] = true end
end

-- The player's current spec index, for the panel's default scope.
-- The binder's own key (Profiles.lua): this used to switch at GameMode 10 where
-- the binder switches at 7, so Legion to Shadowlands clients opened on spec 1.
local function defaultSpecIndex()
    return tonumber(GSE.CurrentSpecKey()) or 1
end

-- Redraw whatever panel the tree has selected, after its data changed.
local function reselect(editframe)
    local tc = editframe.treeContainer
    local st = tc and (tc.status or tc.localstatus)
    local selected = st and st.selected
    if editframe.ManageTree then editframe.ManageTree() end
    if selected and tc and tc.SelectByValue then
        editframe.forceTreeSelection = true
        tc:SelectByValue(selected)
    end
end

-- The Button Bindings page reads its rows once, when it is built, so an
-- override put on a button or cleared somewhere else -- the bar's right-click
-- menu, a drag onto a button -- did not show until the page was reopened.
-- Every open editor on that page redraws when the overrides change.  Not for
-- the page's own Save or Shared switch, which redraw themselves
-- (ownOverrideReload).  A frame later, once the reload that said so is done.
local ownOverrideReload = false
local overrideRedrawPending = false
LibStub("AceEvent-3.0"):Embed({}):RegisterMessage(Statics.Messages.ACTIONBAR_OVERRIDES_UPDATED, function()
    if ownOverrideReload or overrideRedrawPending then return end
    overrideRedrawPending = true
    C_Timer.After(0, function()
        overrideRedrawPending = false
        for _, editframe in ipairs(GSE.GUI.editors or {}) do
            local tc = editframe.treeContainer
            local st = tc and (tc.status or tc.localstatus)
            local selected = st and st.selected
            if type(selected) == "string" and string.find("\001" .. selected .. "\001", "\001AO\001", 1, true) then
                reselect(editframe)
            end
        end
    end)
end)

-- "Shared with every <class> character": whether this spec's binds and
-- overrides are the class's shared profile (Profiles.lua) or this character's
-- own. Unticking gives the character its own copy of the profile's; ticking
-- drops its own for the profile's, after asking, since they are gone then.
local function sharedProfileRow(editframe, specialization, classname)
    local row = UI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    if row.SetFlowHAlign then row:SetFlowHAlign("CENTER") end
    local box = UI:Create("CheckBox")
    box:SetLabel(string.format(L["Shared with every %s Character"], classname or ""))
    -- The widget's frame is only the check square; its label hangs off the
    -- right.  Sized to square + label, so the row's CENTER centres what is
    -- drawn -- over Save's hint line, where the row is pinned.
    local labelWidth = box.text and box.text.GetStringWidth and box.text:GetStringWidth() or 0
    box:SetWidth(labelWidth > 0 and math.ceil((box.checkbg and box.checkbg:GetWidth() or 24) + labelWidth) or 360)
    box:SetValue(GSE.UsesSharedProfile(specialization))
    box:SetCallback("OnEnter", function()
        GSE.CreateToolTip(L["Shared Profile"],
            L["Ticked, this spec's keybinds and action bar overrides are shared by every character of this class, on any realm or faction. Unticked, this character keeps its own. Talent loadout binds are always this character's own."],
            editframe)
    end)
    box:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    box:SetCallback("OnValueChanged", function(_, _, value)
        local function apply()
            GSE.SetSharedProfile(specialization, value)
            if not InCombatLockdown() then
                GSE.ReloadKeyBindings()
                ownOverrideReload = true
                GSE.ReloadOverrides()
                ownOverrideReload = false
            end
            reselect(editframe)
        end
        if not value then return apply() end
        GSE.UI.ShowConfirmDialog({
            owner       = editframe,
            title       = L["Shared Profile"],
            message     = L["Use the shared binds and overrides for this spec? This character's own binds and overrides for it are removed."],
            width       = 360,
            height      = 200,
            confirmText = L["Use Shared"],
            cancelText  = L["Cancel"],
            onConfirm   = apply,
            onCancel    = function() box:SetValue(false) end,
        })
    end)
    row:AddChild(box)
    return row
end

-- The Shared row sits just over Save's hint line, pinned with Save rather than
-- added to the scrolling list: it belongs with the action that commits the
-- binds.  Parented to the ScrollFrame's own frame like Save; released with the
-- pane.  Returns the height the bottom gutter must add for it.
local SHARED_ROW_WIDTH = 360
local function pinSharedRow(rightContainer, saveHint, row)
    row:SetWidth(SHARED_ROW_WIDTH)
    row.frame:SetParent(rightContainer.frame)
    row.frame:SetFrameLevel(rightContainer.frame:GetFrameLevel() + 10)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("BOTTOM", saveHint, "TOP", 0, 4)
    row.frame:Show()
    if row.DoLayout then row:DoLayout() end
    local height = row.frame:GetHeight()
    return (height and height > 0 and height or 24) + 4
end

-- Defined further down beside the widget helpers; the tree builder only runs
-- at ManageTree time, long after this file has finished loading.
local KB_HERO_RING, KB_HERO_RING_ACTIVE

-- ---------------------------------------------------------------------------
-- buildKeybindMenu()  →  full KEYBINDINGS tree node
-- ---------------------------------------------------------------------------
local function buildKeybindMenu()
    local tree = {
        {
            value = "AO",
            text = L["Button Bindings"],
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
    tree[1].children[1] = bindingsClassNode()
    tree[2].children[1] = bindingsClassNode()

    -- Button Bindings nodes.  Same shape as the keybind nodes below: the
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
        -- And the shared profiles' for this class's specs.
        for _, spec in ipairs(GSE.BindingSpecs()) do
            local buttons = GSE.SpecOverrides(spec.key, false)
            for key, override in pairs(buttons or {}) do
                if type(override) ~= "table" or not sequenceExists(override.Sequence) then buttons[key] = nil end
            end
        end

        -- One node per spec the binds are kept by (Profiles.lua): Retail's
        -- specialisations with their talent loadouts, or a dual-spec client's
        -- Primary and Secondary, or the class.
        do
            for _, spec in ipairs(GSE.BindingSpecs()) do
                local specIndex = tonumber(spec.key)
                local node = {value = spec.key, text = spec.label, icon = spec.icon, selectHighlight = true, children = {}}
                local activeLoadout = activeLoadoutForSpec(specIndex)
                for _, configid in ipairs(loadoutsForSpec(specIndex)) do
                    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configid)
                    if info then
                        local icon, iconCoords = heroTalentIcon(configid, specIndex)
                        table.insert(node["children"], {
                            value = tostring(configid),
                            text = "|cffffcc00" .. info.name .. Statics.StringReset,
                            icon = icon or Statics.Icons.Talents,
                            iconCoords = iconCoords,
                            iconRing = (configid == activeLoadout and KB_HERO_RING_ACTIVE)
                                or (icon and KB_HERO_RING or nil),
                            selectHighlight = true
                        })
                    end
                end
                table.insert(tree[1]["children"][1]["children"], node)
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
        -- This character's tables, and the shared profiles' for its class.
        local tables = {}
        for _, v in pairs(GSE_C["KeyBindings"] or {}) do tables[#tables + 1] = v end
        for _, spec in ipairs(GSE.BindingSpecs()) do
            local shared = GSE.UsesSharedProfile(spec.key) and GSE.SpecKeyBinds(spec.key, false)
            if shared then tables[#tables + 1] = shared end
        end
        for _, v in ipairs(tables) do
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

        do
            for _, spec in ipairs(GSE.BindingSpecs()) do
                local specIndex = tonumber(spec.key)
                local node = {
                    value = spec.key,
                    text = spec.label,
                    icon = spec.icon,
                    selectHighlight = true,
                    children = {}
                }
                -- Every loadout for the spec, not only those that already have
                -- binds -- the panel is where binds get added, so you have to
                -- be able to navigate to an empty loadout. Talent loadouts are
                -- Retail's; elsewhere there are none to list.
                local activeLoadout = activeLoadoutForSpec(specIndex)
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
                                iconRing = (configid == activeLoadout and KB_HERO_RING_ACTIVE)
                                    or (icon and KB_HERO_RING or nil),
                                selectHighlight = true
                            }
                        )
                    end
                end
                table.insert(tree[2]["children"][1]["children"], node)
            end
        end
    end

    -- Keybinding switched off (WoW Forever and Retail 12.1.7, or the GSE
    -- Action Bar carries the keys): Button Bindings only.
    if not GSE.KeybindingsEnabled() then table.remove(tree, 2) end

    -- Covers BOTH of its children: an override binds a sequence to a button,
    -- a keybind binds it to a key. Naming the parent "Keybindings" put a
    -- child of the same name inside it and read as though the Actionbar
    -- Overrides beside it were something else again.
    return {
        value = "KEYBINDINGS",
        text = L["Bindings"],
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
-- The same ring in Blizzard's gold: marks the loadout the player is in, on
-- its tree icon and on the medallion at the top of its panel.
KB_HERO_RING_ACTIVE = "talents-node-choiceflyout-circle-yellow"

-- A hero medallion with the ring over it, as a fixed-size group the panel
-- can flow beside a heading.  Inline text cannot do this: two |A| escapes sit
-- side by side, they do not stack.  Textures are cached per frame in a weak
-- table because SimpleGroup is pooled and the pool sweeps caller fields.
local heroBadgeArt = setmetatable({}, {__mode = "k"})
-- active: the loadout is the one the player is in -- its ring is drawn gold,
-- as the tree draws it on that loadout's icon.
local function heroBadge(element, size, active)
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
    art.ring:SetAtlas(active and KB_HERO_RING_ACTIVE or KB_HERO_RING)
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

-- A measured fix-up -- wrap heights, slid columns -- is only right for the
-- size the pane had when it ran, and a pane built into a still-hidden editor
-- (the reopen after a /reload) has no real size yet. Run the pass again on
-- the next frame each time the pane is shown or resized, coalesced, as a
-- drag-resize fires many. Returns the queue so a caller can run it at once.
-- The pane is a ScrollFrame, which is not pooled: the hooks go away with it,
-- and once it is released (parent cleared) the queue does nothing.
local function refitWithPane(rightContainer, pass)
    local queued = false
    local function queue()
        if queued or not rightContainer.parent or not (C_Timer and C_Timer.After) then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            if rightContainer.parent then pass() end
        end)
    end
    local frame = rightContainer.frame
    if frame and frame.HookScript then
        frame:HookScript("OnSizeChanged", queue)
        frame:HookScript("OnShow", queue)
    end
    return queue
end

-- ---------------------------------------------------------------------------
-- The two layers on one page.  A spec's binds hold for every talent loadout;
-- a loadout's own sit on top and win where both set the same key or button.
-- A spec page marks what a loadout replaces; a loadout page lists what it
-- takes from the spec unchanged, under its own rows.
-- ---------------------------------------------------------------------------
local KB_COL_MARK = KB_ICON_SIZE + 4
local KB_INHERITED_COLOUR = "|cff9d9d9d"

local function loadoutNameOf(loadout)
    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(tonumber(loadout))
    return (info and info.name) or tostring(loadout)
end

-- { [key] = {loadout name, ...} } for a spec's loadout layers, where `layers`
-- is { [loadout] = { [key] = ... } }.
local function loadoutReplacements(layers)
    local out = {}
    for loadout, t in pairs(layers or {}) do
        if type(t) == "table" then
            for k in pairs(t) do
                out[k] = out[k] or {}
                table.insert(out[k], loadoutNameOf(loadout))
            end
        end
    end
    for _, names in pairs(out) do table.sort(names) end
    return out
end

-- A spec-page row's last cell: the talent icon where loadouts replace the
-- row, naming them; blank otherwise, so the columns stay in line.
local function loadoutMark(editframe, names)
    local mark
    if names then
        mark = UI:Create("Icon")
        mark:SetImage(Statics.Icons.Talents)
        mark:SetImageSize(KB_ICON_SIZE, KB_ICON_SIZE)
        mark:SetCallback("OnEnter", function()
            GSE.CreateToolTip(L["Replaced by a talent loadout"],
                string.format(L["While %s is the active talent loadout, its own binding is used instead of this one."],
                    table.concat(names, ", ")),
                editframe)
        end)
        mark:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
    else
        mark = UI:Create("Spacer")
    end
    mark:SetWidth(KB_COL_MARK)
    mark:SetHeight(KB_ROW_HEIGHT)
    return mark
end

-- Shrink text to `width` by taking characters out of the middle: a long
-- button name differs at both ends (the bar and the slot number).  Cut by
-- character, not byte, so a sequence name with accents is never split
-- inside one.
local function fitText(fontString, text, width)
    fontString:SetText(text)
    if not (fontString.GetStringWidth and width and width > 0) or fontString:GetStringWidth() <= width then
        return text
    end
    local chars = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    for keep = #chars - 1, 4, -1 do
        local head = math.ceil(keep / 2)
        local fitted = table.concat(chars, "", 1, head) .. "…" .. table.concat(chars, "", #chars - (keep - head) + 1)
        fontString:SetText(fitted)
        if fontString:GetStringWidth() <= width then return fitted end
    end
    return table.concat(chars, "", 1, math.min(3, #chars)) .. "…"
end

-- What a button is called on the panel: its bar and slot.  Frame names
-- spend most of their length on "Action" and "Button", which every one of
-- them shares, and cutting a long one short hid the bar -- two buttons on
-- different bars read the same.  GamepadMainActionButton7 -> GamepadMain 7,
-- MultiBarBottomLeftButton7 -> MultiBarBottomLeft 7.  The frame name is in
-- the tooltip.
local function buttonLabel(name)
    if GSE.isEmpty(name) then return name end
    -- Forever's gamepad bars: the name is mostly frame nesting
    -- (GamepadMainActionBarFramePageUnitBottomCenteredAnchorBottomBarActionButton7).
    if string.find(name, "PageUnit", 1, true) then
        local bar, slot = string.match(name, "(%u%l+Bar)ActionButton(%d+)$")
        if bar then return "Gamepad " .. bar .. " " .. slot end
    end
    local prefix, num = string.match(name, "^(.-)(%d+)$")
    if not prefix then return name end
    -- GSE's own bars: "GSE Action Bar 2 - 1" for GSEButton13.
    if prefix == "GSEButton" then
        local slot = tonumber(num)
        return string.format(L["GSE Action Bar %d"], math.ceil(slot / 12)) .. " - " .. ((slot - 1) % 12 + 1)
    end
    local bar = prefix:gsub("Action", ""):gsub("Button", ""):gsub("[_%s]+$", "")
    if bar == "" then bar = prefix end
    return bar .. " " .. num
end

-- Shrink text to `width` from the front, keeping its end: a button label ends
-- in what tells it from its neighbours -- the bar and the slot -- and begins
-- with what they share (buttonLabel).
local function fitTail(fontString, text, width)
    fontString:SetText(text)
    if not (fontString.GetStringWidth and width and width > 0) or fontString:GetStringWidth() <= width then
        return text
    end
    local chars = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    for keep = #chars - 1, 3, -1 do
        local fitted = "…" .. table.concat(chars, "", #chars - keep + 1)
        fontString:SetText(fitted)
        if fontString:GetStringWidth() <= width then return fitted end
    end
    return "…" .. table.concat(chars, "", math.max(1, #chars - 2))
end

-- On a talent loadout's page, the spec's binds it does not replace, which
-- are live in this loadout too.  Read-only here: Override copies one into the
-- loadout's own rows, to change for this loadout only.
-- entries: { {first = text, firstWidth = px, seq = id, onOverride = fn} }
-- opts (all optional), for a page laying the rows out its own way:
--   seqJustify: the sequence text's justify, "CENTER" unless given. Set
--     before the text: the game keeps a text's layout from when it was set
--     (measured on the Button Bindings page: justify read LEFT, text still
--     drawn centred).
--   seqWidth: the sequence text's width (KB_COL_SEQ), so it is no longer
--     than the dropdown above.
--   seqInset: the text's inset from its box's left edge, in pixels (0).
--   topGap: space above the section's caption, in pixels (none).
local function inheritedSection(editframe, container, entries, opts)
    opts = opts or {}
    local seqJustify, seqWidth, seqInset = opts.seqJustify, opts.seqWidth or KB_COL_SEQ, opts.seqInset
    container:ReleaseChildren()
    local built = {} -- {row = widget, cells = {name, button, sequence frames}}, for a caller lining them up
    if #entries == 0 then return built end
    if opts.topGap then
        local gap = UI:Create("Spacer")
        gap:SetFullWidth(true)
        gap:SetHeight(opts.topGap)
        container:AddChild(gap)
    end
    local caption = UI:Create("Label")
    caption:SetFullWidth(true)
    caption:SetJustifyH("CENTER")
    caption:SetText(KB_INHERITED_COLOUR .. "« " .. L["All Talent Loadouts"] .. " »  -  "
        .. L["also live in this loadout"] .. Statics.StringReset)
    container:AddChild(caption)
    for _, entry in ipairs(entries) do
        local row = UI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        if row.SetFlowGap then row:SetFlowGap(6) end
        if row.SetFlowPadding then row:SetFlowPadding(0, 0, 0, 0) end
        if row.SetFlowVAlign then row:SetFlowVAlign("CENTER") end
        if row.SetFlowHAlign then row:SetFlowHAlign("CENTER") end
        local first = UI:Create("Label")
        first:SetWidth(entry.firstWidth)
        first:SetJustifyH("CENTER")
        first:SetJustifyV("MIDDLE")
        first:SetText(KB_INHERITED_COLOUR .. fitTail(first.text, entry.first, entry.firstWidth - 8) .. Statics.StringReset)
        local seq = UI:Create("Label")
        seq:SetWidth(seqWidth)
        seq:SetJustifyH(seqJustify or "CENTER")
        seq:SetJustifyV("MIDDLE")
        if seqInset and seqInset ~= 0 and seq.text then
            -- The box stays put; only its text moves in. Pooled: the label's
            -- text goes back to filling the box when the label is released.
            seq.text:ClearAllPoints()
            seq.text:SetPoint("TOPLEFT", seqInset, 0)
            seq.text:SetPoint("BOTTOMRIGHT")
            seq:SetCallback("OnRelease", function(widget)
                widget.text:ClearAllPoints()
                widget.text:SetPoint("TOPLEFT")
                widget.text:SetPoint("BOTTOMRIGHT")
            end)
        end
        seq:SetText(KB_INHERITED_COLOUR .. fitText(seq.text, sequenceLabel(entry.seq), seqWidth - 8 - (seqInset or 0))
            .. Statics.StringReset)
        local override = UI:Create("Button")
        override:SetText(L["Copy to Loadout"])
        -- As wide as its label needs, never under the old 100.
        local labelWidth = override.text and override.text.GetStringWidth and override.text:GetStringWidth() or 0
        override:SetWidth(math.max(100, math.ceil(labelWidth) + 24))
        override:SetCallback("OnClick", entry.onOverride)
        override:SetCallback("OnEnter", function()
            GSE.CreateToolTip(L["Copy to Loadout"], L["Copy this into the loadout's own rows, to change it for this loadout only."],
                editframe)
        end)
        override:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        row:AddChild(first)
        row:AddChild(override)
        row:AddChild(seq)
        container:AddChild(row)
        built[#built + 1] = {row = row, cells = {first.frame, override.frame, seq.frame}, seq = seq}
    end
    return built
end

-- A loadout page's row list takes an inherited one: the lone blank row the
-- panel always opens on is filled rather than left above it.
local function addInheritedRow(rows, row)
    local only = rows[1]
    if #rows == 1 and not next(only) then
        rows[1] = row
    else
        table.insert(rows, row)
    end
end

local showKeybindPanel
showKeybindPanel = function(editframe, specialization, loadout, rightContainer)
    specialization = tostring(specialization or defaultSpecIndex())

    local rows = {}
    local saveButton, rowContainer, inheritedContainer, redraw
    -- A spec page: which keys a talent loadout replaces.  nil on a loadout
    -- page, and when no loadout replaces anything (no mark column then).
    local marks = not loadout and loadoutReplacements(GSE.SpecLoadoutKeyBinds(specialization, false)) or nil
    if marks and not next(marks) then marks = nil end
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
                        -- The loadout mark rides beside the X.
                        for _, frame in ipairs({icon, edge.mark}) do
                            local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
                            if point then
                                frame:SetPoint(point, relativeTo, relativePoint, (x or 0) - slack, y or 0)
                            end
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
        -- Keyed by id, shown by label: what is saved is the id.
        for _, classid in ipairs({GSE.GetCurrentClassID(), 0}) do
            for id, env in pairs(GSE.SequenceEnvelopes(classid)) do
                if env.Name and not names[id] then
                    names[id] = sequenceIsDisabled(id) and env.Name .. " (" .. L["Sequence Disabled"] .. ")" or env.Name
                    table.insert(order, id)
                end
            end
        end
        table.sort(order, function(a, b) return names[a]:lower() < names[b]:lower() end)
        return names, order
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
            local loadouts = GSE.SpecLoadoutKeyBinds(specialization, false)
            if loadouts then loadouts[loadout] = nil end
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
                GSE.isEmpty(r.key) and sequenceLabel(r.seq) or r.key,
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

        local mark = marks and loadoutMark(editframe, not GSE.isEmpty(model.key) and marks[model.key] or nil)

        local fieldEdge, fieldPad = dropdownFieldEdge(sequence)
        rowEdges[#rowEdges + 1] = {field = fieldEdge, pad = fieldPad, icon = remove.frame, mark = mark and mark.frame}

        row:AddChild(addSlot)
        row:AddChild(keybind)
        row:AddChild(sequence)
        row:AddChild(remove)
        if mark then row:AddChild(mark) end
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

        -- A loadout page: the spec's binds on keys it has no row for.
        if loadout then
            local own, entries = {}, {}
            for _, r in ipairs(rows) do
                if not GSE.isEmpty(r.key) then own[r.key] = true end
            end
            local spec = keybindScope(specialization, nil, false) or {}
            local keys = {}
            for k in pairs(spec) do
                if k ~= "LoadOuts" and not own[k] then table.insert(keys, k) end
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                entries[#entries + 1] = {first = k, firstWidth = KB_COL_KEY, seq = spec[k], onOverride = function()
                    addInheritedRow(rows, {key = k, seq = spec[k]})
                    markDirty()
                    redraw()
                end}
            end
            inheritedSection(editframe, inheritedContainer, entries)
            inheritedContainer:DoLayout()
        end

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
    local specname, specicon = specLabelFor(specialization, classname)

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
        loadoutRow:AddChild(heroBadge(loadoutArt, 28,
            tonumber(loadout) == activeLoadoutForSpec(tonumber(specialization))))
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
    inheritedContainer = UI:Create("SimpleGroup")
    inheritedContainer:SetFullWidth(true)
    inheritedContainer:SetLayout("List")
    if inheritedContainer.SetListGap then inheritedContainer:SetListGap(2) end

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
    if marks then
        local markHeading = UI:Create("Label")
        markHeading:SetWidth(KB_COL_MARK)
        markHeading:SetText("")
        headings:AddChild(markHeading)
    end

    if rightContainer.SetListGap then rightContainer:SetListGap(4) end
    rightContainer:AddChild(centeredRow(headerLabel))
    -- No loadout line where there are no talent loadouts: the spec is all
    -- there is, and "All Talent Loadouts" would name something that is not.
    if loadout or GSE.HasTalentLoadouts() then rightContainer:AddChild(loadoutRow or centeredRow(loadoutLabel)) end
    local sharedRow = not loadout and sharedProfileRow(editframe, specialization, classname) or nil
    rightContainer:AddChild(headings)
    rightContainer:AddChild(rowContainer)
    rightContainer:AddChild(inheritedContainer)

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
    refitWithPane(rightContainer, tightenRemoveIcons)
    local sharedRowHeight = sharedRow and pinSharedRow(rightContainer, saveHint, sharedRow) or 0
    rightContainer:SetCallback("OnRelease", function()
        saveButton:Release()
        if sharedRow then sharedRow:Release() end
    end)

    -- Without a gutter the last row scrolls underneath the pinned button.
    local bottomGutter = UI:Create("Spacer")
    bottomGutter:SetFullWidth(true)
    bottomGutter:SetHeight(saveButton.frame:GetHeight() + KB_SAVE_INSET * 2 + 18 + sharedRowHeight)
    rightContainer:AddChild(bottomGutter)

    redraw()
end


-- ---------------------------------------------------------------------------
-- Button Bindings: the same panel shape as keybinds.
-- ---------------------------------------------------------------------------
local AO_COL_BUTTON, AO_COL_KEY, AO_COL_KEYS, AO_COL_STATE, AO_COL_SEQ = 175, 110, 110, 110, 180
local AO_ROW_WIDTH = KB_COL_ADD + AO_COL_BUTTON + AO_COL_KEY + AO_COL_KEYS + AO_COL_STATE + AO_COL_SEQ + KB_COL_REMOVE + 30

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
    -- The GSE Action Bar's buttons, while it is on.
    for _, name in ipairs(GSE.ActionBarButtonNames and GSE.ActionBarButtonNames() or {}) do
        if _G[name] then buttonlist[name] = name end
    end
    -- Anything a saved override names that exists but was not auto-detected.
    local binds = GSE_C["ActionBarBinds"] or {}
    local specTables = {}
    for _, buttons in pairs(binds["Specialisations"] or {}) do specTables[#specTables + 1] = buttons end
    for _, spec in ipairs(GSE.BindingSpecs()) do
        local shared = GSE.SpecOverrides(spec.key, false)
        if shared then specTables[#specTables + 1] = shared end
    end
    for _, buttons in ipairs(specTables) do
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
    -- GSE's own bar first in the picker.
    for i, group in ipairs(groups) do
        if group.prefix == "GSEButton" then
            table.insert(groups, 1, table.remove(groups, i))
            break
        end
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
-- The classes whose bars change with a stance or form, which is what a
-- button state is for: Warrior, Rogue, Druid.
local STATE_CLASSES = {[1] = true, [4] = true, [11] = true}

-- Whether the panel has a State column: a stance or form class with a
-- LibActionButton bar (state_types) on this client -- or a saved row that
-- already has a state, which must stay visible to be changed or removed.
local function stateColumnWanted(rows, buttonNames)
    for _, r in ipairs(rows) do
        if r.state then return true end
    end
    if not STATE_CLASSES[GSE.GetCurrentClassID()] then return false end
    for name in pairs(buttonNames) do
        local frame = _G[name]
        if type(frame) == "table" and frame.state_types then return true end
    end
    return false
end

-- The key WoW's Key Bindings put on a button.  It is the button's, not
-- GSE's -- the panel shows it and never sets it.  Blizzard's bars bind by
-- command; bar addons bind a click on the frame; anything else, read the
-- hotkey the bar itself draws.
local BAR_COMMANDS = {
    ActionButton = "ACTIONBUTTON",
    MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON", MultiBarBottomRightButton = "MULTIACTIONBAR2BUTTON",
    MultiBarRightButton = "MULTIACTIONBAR3BUTTON", MultiBarLeftButton = "MULTIACTIONBAR4BUTTON",
    MultiBar5Button = "MULTIACTIONBAR5BUTTON", MultiBar6Button = "MULTIACTIONBAR6BUTTON",
    MultiBar7Button = "MULTIACTIONBAR7BUTTON",
}
-- Every key bound to a binding action.  Some actions live in a binding
-- context of their own -- Forever's crossbar modifiers are in
-- GamepadModeInGameCore -- and GetBindingKey finds those only when given it,
-- the way Blizzard's Key Bindings screen asks (Blizzard_Keybindings.lua).
local function bindingKeys(action)
    local context = C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and C_KeyBindings.GetBindingContextForAction(action)
    if context then return GetBindingKey(action, nil, context) end
    return GetBindingKey(action)
end
-- The WoW binding command a bar button is keyed by, for the buttons whose key
-- can be set here: Blizzard's bars (BAR_COMMANDS), and a bar that names its
-- command on the button (button.commandName, or Dominos's "commandName"
-- attribute).  Nil for the rest -- a bar addon that binds a click on its own
-- frame, Forever's gamepad bars -- whose keys are shown and set elsewhere.
local function bindingCommandFor(bind)
    if GSE.isEmpty(bind) then return nil end
    local prefix, num = string.match(bind, "^(.-)(%d+)$")
    if prefix and BAR_COMMANDS[prefix] then return BAR_COMMANDS[prefix] .. num end
    local b = _G[bind]
    if type(b) ~= "table" then return nil end
    local cmd = b.commandName or (b.GetAttribute and b:GetAttribute("commandName"))
    if type(cmd) == "string" and cmd ~= "" then return cmd end
    return nil
end
-- What WoW has bound to such a button right now: its key, its backup key.
local function boundKeysFor(bind)
    local cmd = bindingCommandFor(bind)
    if cmd and GetBindingKey then return bindingKeys(cmd) end
end

-- Forever's gamepad bars (Blizzard_GamepadActionBars) have no key binding
-- per button.  There are four -- TopBar / LeftBar / RightBar / BottomBar, each
-- inside its own anchor frame, so the name runs PageUnit<Side>CenteredAnchor
-- <Side>BarActionButton<n>.  Blizzard draws what reaches one from fixed
-- input keys, not from bindings: each button's glyph is its
-- ButtonIcon.mappedButtonKey, and a bar's modifiers are the triggers held
-- for it (ActionBarTemplates.xml: LeftIcon GAMEPAD_TRIGGER_LEFT, RightIcon
-- GAMEPAD_TRIGGER_RIGHT, the bottom bar both).  The same keys through the
-- same lookup the bar uses give the glyphs it shows, for whichever
-- controller style is active.
local function gamepadBarModifiers(bar)
    if bar == "LeftBar" then return {GAMEPAD_TRIGGER_LEFT} end
    if bar == "RightBar" then return {GAMEPAD_TRIGGER_RIGHT} end
    if bar == "BottomBar" then return {GAMEPAD_TRIGGER_LEFT, GAMEPAD_TRIGGER_RIGHT} end
    if bar == "TopBar" then return {} end
end
-- The glyphs for a gamepad bar button, as inline atlases; nil for any other
-- button, or where the client cannot say.
local function gamepadBarKeys(buttonName)
    if not string.find(buttonName, "PageUnit", 1, true) then return nil end
    local bar = string.match(buttonName, "(%u%l+Bar)ActionButton%d$")
    local modifiers = bar and gamepadBarModifiers(bar)
    local frame = _G[buttonName]
    local key = type(frame) == "table" and frame.ButtonIcon and frame.ButtonIcon.mappedButtonKey
    local util = InputIconTextureSetUtility
    if not (modifiers and key and util and util.GetNormalActiveInputIconButtonTexture) then return nil end
    local glyphs = {}
    for _, input in ipairs(modifiers) do glyphs[#glyphs + 1] = input end
    glyphs[#glyphs + 1] = key
    for i, input in ipairs(glyphs) do
        local ok, atlas = pcall(util.GetNormalActiveInputIconButtonTexture, input)
        if not (ok and atlas) then return nil end
        glyphs[i] = "|A:" .. atlas .. ":24:24|a"
    end
    return table.concat(glyphs, " + ")
end

-- A controller button's name is a glyph, not text: Blizzard sets KEY_PAD1
-- and the rest to "|A:Gamepad_..._64:24:24|a" (SetGamepadBindingStrings), and
-- GetBindingText hands that back.  Drawn at `size` so it sits in a row.
-- Blizzard's newer controller art -- what the gamepad bars show -- sits on a
-- 76x75 canvas with a border and shadow round the glyph, so at the same size
-- it drew far smaller than the others.  Blizzard draws those 5px past a 20px
-- slot on every side (InputIconTextureMixin:ApplyTextureLayout), half as big
-- again; so does this.
local function sizeGlyphs(text, size)
    return (text:gsub("|A:([^:|]+):%d+:%d+|a", function(atlas)
        local drawn = size
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if info and info.width == 76 and info.height == 75 then drawn = math.floor(size * 1.5 + 0.5) end
        return "|A:" .. atlas .. ":" .. drawn .. ":" .. drawn .. "|a"
    end))
end

-- Every key on the binding, as Key Bindings lists them (Move Forward: W and
-- Up Arrow), joined by `separator` -- ", " in the column, a line each in the
-- tooltip, where the column is too narrow to show more than one.
local function buttonKeysText(buttonName, separator)
    if GSE.isEmpty(buttonName) then return nil end
    local keys = {}
    if GetBindingKey then
        local prefix, num = string.match(buttonName, "^(.-)(%d+)$")
        local command = prefix and BAR_COMMANDS[prefix]
        if command then keys = {bindingKeys(command .. num)} end
        if #keys == 0 then keys = {bindingKeys("CLICK " .. buttonName .. ":LeftButton")} end
        if #keys == 0 then keys = {bindingKeys("CLICK " .. buttonName .. ":Keybind")} end
    end
    if #keys == 0 then
        local gamepad = gamepadBarKeys(buttonName)
        if gamepad then return gamepad end
    end
    -- ConsolePort's buttons are the pad buttons themselves.
    if #keys == 0 and string.sub(buttonName, 1, 4) == "CPB_" then keys = {string.sub(buttonName, 5)} end
    local shown = {}
    for _, key in ipairs(keys) do shown[#shown + 1] = GetBindingText and GetBindingText(key) or key end
    if #shown > 0 then return table.concat(shown, separator or ", ") end
    local frame = _G[buttonName]
    local hotKey = type(frame) == "table" and ((frame.TextOverlayContainer and frame.TextOverlayContainer.HotKey)
        or frame.HotKey)
    local text = hotKey and hotKey.GetText and hotKey:GetText()
    if text and text ~= "" and text ~= RANGE_INDICATOR then return text end
    return nil
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
-- A row's keys into WoW, on Save: the bar button's bindings become the
-- row's key and backup key, in that order (a key used by another action
-- moves here, as on WoW's own screen).  True when written.  Out of combat
-- only: WoW blocks SetBinding in combat.
local function writeBackupKey(row)
    local cmd = row.keysChanged and bindingCommandFor(row.bind)
    if not cmd or InCombatLockdown() then return false end
    local old1, old2 = bindingKeys(cmd)
    if old1 then SetBinding(old1) end
    if old2 then SetBinding(old2) end
    if row.key1 then SetBinding(row.key1, cmd) end
    if row.key2 then SetBinding(row.key2, cmd) end
    row.keysChanged = nil
    return true
end
-- The binding set WoW is using (account or character); 2, the character's,
-- where the client cannot say.
local function saveWoWBindings()
    if not SaveBindings then return end
    local getSet = _G.GetCurrentBindingSet
    SaveBindings(getSet and getSet() or 2)
end
-- The open Button Bindings panel's rows re-read their keys when WoW's
-- bindings change, so a key set in WoW's own Key Bindings shows at once.
local activeKeyRefreshers
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UPDATE_BINDINGS")
    watcher:SetScript("OnEvent", function()
        for _, refresh in ipairs(activeKeyRefreshers or {}) do pcall(refresh) end
    end)
end
showOverridePanel = function(editframe, specialization, loadout, rightContainer)
    specialization = tostring(specialization or defaultSpecIndex())

    local rows = {}
    local saveButton, rowContainer, inheritedContainer, redraw
    local showState
    -- A row removed here came off the bar at once and has not been saved: left
    -- that way, the pane puts the bar back as saved when it closes.
    local releasedUnsaved = false
    -- One per shown row (activeKeyRefreshers).
    local keyRefreshers = {}
    activeKeyRefreshers = keyRefreshers
    -- A spec page: which buttons a talent loadout replaces (by row key).
    local marks
    if not loadout then
        local layers = GSE_C["ActionBarBinds"] and GSE_C["ActionBarBinds"]["LoadOuts"]
        marks = loadoutReplacements(layers and layers[specialization])
        if not next(marks) then marks = nil end
    end
    -- One chain per row: the row's frames left to right, and for each frame
    -- that is a dropdown, the frame + pad whose RIGHT edge is its visible
    -- edge (dropdownFieldEdge).  The heading cells are a chain too, shifted
    -- by whatever the first row measured so they stay over their columns.
    local rowChains, headingFrames = {}, {}
    local inheritedRows = {} -- a loadout page's greyed rows (inheritedSection)
    -- Per-column heading offset from the measured centre, negative = left.
    -- Part of the target, not an extra slide, so the measured pass still
    -- converges instead of re-applying it on every run.
    local headingNudge = {[2] = -10}
    -- The columns, left to right, for the rows and the headings alike.
    -- Button stays second, which headingNudge counts on.
    local function columnLayout()
        local order = {"add", "button", "key", "keys", "sequence"}
        if showState then order[#order + 1] = "state" end
        order[#order + 1] = "remove"
        if marks then order[#order + 1] = "mark" end
        return order
    end
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
    -- One row; true once it is placed. Runs right after each layout of the
    -- row (row.afterLayout), in the same frame, so a resize never draws the
    -- loose row first; and from tightenRows. A second run finds nothing.
    local function tightenChain(chain)
        -- Skip until the layout has actually placed the row (under
        -- UI:SuspendLayout the frames have no points yet).
        if not (chain.frames[1].GetLeft and chain.frames[1]:GetLeft()) then return false end
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
        if chain.mark and chain.removeFrame then
            chain.mark:ClearAllPoints()
            chain.mark:SetPoint("LEFT", chain.removeFrame, "RIGHT", KB_ICON_GAP, 0)
            -- The layout centred the row without the marker; centre
            -- it with the marker, so the marker takes room from the
            -- left margin instead of running off the right edge. A
            -- row wider than its frame starts at the frame's left.
            local left = chain.frames[1]:GetLeft()
            local right = chain.removeFrame:GetRight()
            local rowLeft, rowRight = chain.row:GetLeft(), chain.row:GetRight()
            if left and right and rowLeft and rowRight then
                right = right + KB_ICON_GAP + chain.mark:GetWidth()
                local by = (left + right) / 2 - (rowLeft + rowRight) / 2
                if right - left > rowRight - rowLeft then by = left - rowLeft end
                for _, frame in ipairs(chain.frames) do slideLeft(frame, by) end
            end
        end
        return true
    end
    -- Headings: centre each over the VISIBLE box of its column's control
    -- on the first row -- frame left to the arrow's right edge -- not
    -- over the frame, which the native dropdown never fills.
    local function slideHeadings(first)
        if not first then return end
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
    -- A greyed row lined up with the first row's columns: its button name
    -- under the button, Copy to Loadout under the Main Key and Backup Key
    -- cells together, its sequence left-aligned at the sequence dropdown's
    -- left edge.
    local function alignInherited(entry)
        local f = rowChains[1] and rowChains[1].frames
        if not f then return end
        local function centreOf(a, z)
            local l, r = a and a.GetLeft and a:GetLeft(), z and z.GetRight and z:GetRight()
            return l and r and (l + r) / 2
        end
        local targets = {centreOf(f[2], f[2]), centreOf(f[3], f[4])}
        for i = 1, 2 do
            local frame = entry.cells[i]
            local have, want = frame.GetCenter and frame:GetCenter(), targets[i]
            if have and want then slideLeft(frame, have - want) end
        end
        local seqFrame, seqLeft = entry.cells[3], f[5] and f[5].GetLeft and f[5]:GetLeft()
        local have = seqFrame and seqFrame.GetLeft and seqFrame:GetLeft()
        if have and seqLeft then slideLeft(seqFrame, have - seqLeft) end
    end
    local function tightenRows()
        local first
        for _, chain in ipairs(rowChains) do
            if tightenChain(chain) then first = first or chain end
        end
        slideHeadings(first)
        for _, entry in ipairs(inheritedRows) do alignInherited(entry) end
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
        -- Keyed by id, shown by label: what is saved is the id.
        for _, classid in ipairs({GSE.GetCurrentClassID(), 0}) do
            for id, env in pairs(GSE.SequenceEnvelopes(classid)) do
                if env.Name and not names[id] then
                    names[id] = sequenceIsDisabled(id) and env.Name .. " (" .. L["Sequence Disabled"] .. ")" or env.Name
                    table.insert(order, id)
                end
            end
        end
        table.sort(order, function(a, b) return names[a]:lower() < names[b]:lower() end)
        return names, order
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
            GSE.Print(L["Button Bindings"] .. ": " .. (ERR_NOT_IN_COMBAT or "not in combat"))
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
        -- A row with a button and no sequence, or a sequence and no button,
        -- is still being filled in: kept on screen and said, below.
        local incomplete = {}
        for _, r in ipairs(rows) do
            local key = rowKey(r)
            if key and not GSE.isEmpty(r.seq) then
                local state = r.state
                if state == "Default" or state == stateDefaultFor(r.bind) then state = nil end
                scope[key] = {Bind = r.bind, State = state, Sequence = r.seq}
            elseif key or not GSE.isEmpty(r.seq) then
                incomplete[#incomplete + 1] = r
            end
        end
        if loadout and not next(scope) then
            GSE_C["ActionBarBinds"]["LoadOuts"][specialization][loadout] = nil
        end

        -- Backup keys changed on rows go to WoW on Save, and WoW's own Key
        -- Bindings screen shows them then.
        local keysChanged = false
        for _, r in ipairs(rows) do
            if writeBackupKey(r) then keysChanged = true end
        end
        if keysChanged then saveWoWBindings() end

        -- LoadOverrides reverts every live override before re-arming from the
        -- data, so rows removed here go dead on this call.
        ownOverrideReload = true
        GSE.ReloadOverrides()
        ownOverrideReload = false
        releasedUnsaved = false
        for _, r in ipairs(rows) do
            local rowButton = not GSE.isEmpty(r.seq) and GSE.StoredSequenceId(r.seq)
            if rowButton and _G[rowButton] and GSE.UpdateIcon then GSE.UpdateIcon(_G[rowButton]) end
        end
        if saveButton then saveButton:SetDisabled(true) end
        loadRows()
        -- Put the half-set rows back, so Save never makes a row disappear, and
        -- say what each one is still missing.
        for _, r in ipairs(incomplete) do
            table.insert(rows, r)
            GSE.Print(string.format(L["%s was not saved: it still needs a %s."],
                GSE.isEmpty(r.bind) and sequenceLabel(r.seq) or buttonLabel(r.bind),
                GSE.isEmpty(r.bind) and L["Actionbar Button"] or L["Sequence"]), L["Button Bindings"])
        end
        if #incomplete > 0 and saveButton then saveButton:SetDisabled(false) end
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
            -- The bar loses the override now, as it gains one the moment it is
            -- assigned there; Save makes it permanent.  Not while another row
            -- still names the button (a state of its own).
            local bind, stillUsed = model.bind, false
            for _, r in ipairs(rows) do
                if r.bind == bind then stillUsed = true end
            end
            if not GSE.isEmpty(bind) and not stillUsed and GSE.ReleaseActionBarOverride
                and GSE.ReleaseActionBarOverride(bind) then
                releasedUnsaved = true
            end
            markDirty()
            redraw()
        end)

        local state = showState and UI:Create("Dropdown")
        if state then state:SetWidth(AO_COL_STATE) end
        local function refreshStates()
            if not state then return end
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
        if state then
            state:SetCallback("OnValueChanged", function(_, _, key)
                model.state = key ~= "Default" and key or nil
                markDirty()
            end)
        end

        -- The button's key and its backup key: its first and second binding
        -- in WoW's Key Bindings, as that panel lists them.  Click, press a
        -- key; written to WoW on Save.  A button whose keys cannot be set
        -- here (bindingCommandFor) only shows them.
        local function keyCell(width)
            local cell = UI:Create("ControllerKeybinding")
            cell:SetWidth(width)
            cell:SetHeight(KB_ROW_HEIGHT)
            if cell.button and cell.frame then
                -- The widget keeps 20px clear on its right; not in a row.
                cell.button:SetPoint("BOTTOMRIGHT", cell.frame, "BOTTOMRIGHT", 0, 0)
                -- The tooltip lists the keys of a button that cannot be set too.
                if cell.button.SetMotionScriptsWhileDisabled then cell.button:SetMotionScriptsWhileDisabled(true) end
            end
            return cell
        end
        local key, keys = keyCell(AO_COL_KEY), keyCell(AO_COL_KEYS)
        local refreshButtonText
        -- The button's keys as WoW shows them: its own key, then its backup
        -- (every further key, for a button not set here).  Read from the row
        -- for a button set here, so a backup key not saved yet shows; from
        -- WoW for the rest.
        local function keyTexts()
            if bindingCommandFor(model.bind) then
                if not model.keysRead then
                    model.key1, model.key2 = boundKeysFor(model.bind)
                    model.keysRead = true
                end
                local shown = GetBindingText or function(key) return key end
                return model.key1 and shown(model.key1) or nil, model.key2 and shown(model.key2) or nil
            end
            local all = buttonKeysText(model.bind, "\001")
            if not all then return nil end
            local first, rest = string.match(all, "^(.-)\001(.*)$")
            if not first then return all end
            return first, (string.gsub(rest, "\001", ", "))
        end
        local function fillKeyCell(cell, width, text, settable)
            cell:SetKey(text or "")
            -- A controller's keys are pictures of its buttons: the red button
            -- under them goes, and the cell still takes the click.  This
            -- widget is not pooled, so the art comes back with the next row.
            if cell.button then
                local shown = (text and text:find("|A:", 1, true)) and 0 or 1
                for _, part in ipairs({"Left", "Middle", "Right"}) do
                    local art = cell.button[part]
                    if art and art.SetAlpha then art:SetAlpha(shown) end
                end
            end
            local caption = text and cell.button and cell.button:GetFontString()
            if caption then
                if text:find("|A:", 1, true) then
                    -- Controller glyphs: sized to the row (their atlases carry
                    -- padding, so smaller reads as specks), and never cut -- a
                    -- cut through the |A..|a markup prints it as text.  Two
                    -- keys with modifiers run past the cell at that size, so
                    -- they step down until the cell holds them.
                    local fitted
                    for _, size in ipairs({22, 18, 16, 14}) do
                        fitted = sizeGlyphs(text, size)
                        caption:SetText(fitted)
                        if not caption.GetStringWidth or caption:GetStringWidth() <= width - 12 then break end
                    end
                    text = fitted
                else
                    text = fitText(caption, text, width - 12)
                end
                cell.button:SetText(text)
            end
            -- Nothing to show and nothing to set: a dash, not "Not Bound".
            if not text and not settable and cell.button then cell.button:SetText("-") end
            cell:SetDisabled(not settable)
        end
        local function refreshKeys()
            local first, second = keyTexts()
            local settable = bindingCommandFor(model.bind) ~= nil
            fillKeyCell(key, AO_COL_KEY, first, settable)
            fillKeyCell(keys, AO_COL_KEYS, second, settable)
            if refreshButtonText then refreshButtonText() end
        end
        -- A key WoW uses for something else moves on Save, as on WoW's own
        -- screen; say what it is bound to now.
        local function noteTakenKey(k)
            local action = k and GetBindingAction and GetBindingAction(k)
            if action and action ~= "" and action ~= bindingCommandFor(model.bind) then
                GSE.Print(string.format(L["%s is bound to %s now; Save moves it to %s."],
                    k, _G.GetBindingName and _G.GetBindingName(action) or action, buttonLabel(model.bind)),
                    L["Button Bindings"])
            end
        end
        key:SetCallback("OnKeyChanged", function(_, _, k)
            model.key1 = k ~= "" and k or nil
            -- The button's key is not also its backup.
            if model.key1 and model.key2 == model.key1 then model.key2 = nil end
            model.keysChanged = true
            noteTakenKey(model.key1)
            refreshKeys()
            markDirty()
        end)
        keys:SetCallback("OnKeyChanged", function(_, _, k)
            -- The key the button already has is not also its backup.
            model.key2 = (k ~= "" and k ~= model.key1 and k) or nil
            model.keysChanged = true
            noteTakenKey(model.key2)
            refreshKeys()
            markDirty()
        end)
        for _, cell in ipairs({key, keys}) do
            cell:SetCallback("OnEnter", function()
                local hint = bindingCommandFor(model.bind)
                    and L["Click > Set Keys or ESC to Clear > Save!"]
                    or L["Set for this button in WoW's Key Bindings.  Change this in WoW's Options -> Keybindings."]
                GSE.CreateToolTip(nil, hint, editframe)
            end)
            cell:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        end
        -- A backup key typed here and not yet saved is kept.
        keyRefreshers[#keyRefreshers + 1] = function()
            if model.keysChanged or not (keys.frame and keys.frame:IsVisible()) then return end
            model.keysRead = nil
            refreshKeys()
        end

        -- ~100 action buttons is too many for one flat list.  The picker is
        -- a button showing the current name that opens a NESTED menu -- one
        -- submenu per bar -- through MenuUtil, as the tree's right-click
        -- menus do.  Falls back to a flat menu where MenuUtil is missing.
        local button = UI:Create("Button")
        button:SetWidth(AO_COL_BUTTON)
        button:SetHeight(KB_ROW_HEIGHT)
        -- Bar and slot (buttonLabel), fitted to the button.  Its keys are
        -- the two cells beside it.  The frame name is in the tooltip.
        refreshButtonText = function()
            if GSE.isEmpty(model.bind) then
                button:SetText(L["Pick a button"])
                return
            end
            button:SetText(fitTail(button.text, buttonLabel(model.bind), AO_COL_BUTTON - 20))
        end
        button:SetCallback("OnEnter", function()
            if GSE.isEmpty(model.bind) then return end
            -- Bar and slot, as the picker names it ("Gamepad TopBar 1", not 70
            -- letters of frame nesting).  The keys are on the row already.
            GSE.CreateToolTip(buttonLabel(model.bind), "", editframe)
        end)
        button:SetCallback("OnLeave", function() GSE.ClearTooltip(editframe) end)
        local function choose(name)
            model.bind = name
            model.state = nil
            model.keysRead, model.keysChanged = nil, nil
            refreshButtonText()
            refreshStates()
            refreshKeys()
            markDirty()
        end
        button:SetCallback("OnClick", function()
            if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
            GSE.OpenContextMenu(button.frame, function(_, root)
                root:CreateTitle(L["Actionbar Buttons"])
                -- A saved button not on this client right now still shows.
                if not GSE.isEmpty(model.bind) and not buttonNames[model.bind] then
                    root:CreateButton(model.bind, function() choose(model.bind) end)
                end
                for _, group in ipairs(actionButtonGroups(buttonOrder)) do
                    -- Forever's gamepad bars are not picked here: a sequence
                    -- goes on one from the bar itself (right-click, or drag).
                    -- A saved override on one keeps its row.
                    local listed = string.find(group.prefix, "PageUnit", 1, true) and 0 or #group.items
                    if listed == 1 then
                        local name = group.items[1].name
                        root:CreateButton(name, function() choose(name) end)
                    elseif group.prefix == "GSEButton" then
                        -- GSE's own two bars of twelve, one submenu each.
                        local subs = {}
                        for _, item in ipairs(group.items) do
                            local bar = math.ceil(item.num / 12)
                            if not subs[bar] then
                                subs[bar] = root:CreateButton(string.format(L["GSE Action Bar %d"], bar))
                            end
                            subs[bar]:CreateRadio("GSEButton " .. (item.num - (bar - 1) * 12),
                                function() return model.bind == item.name end,
                                function() choose(item.name) end)
                        end
                    elseif listed > 1 then
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
                                        L["%s is not an actionbar button on this client."], name), L["Button Bindings"])
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

        if state then compactDropdown(state) end
        compactDropdown(sequence)
        refreshStates()
        refreshKeys()

        local mark = marks and loadoutMark(editframe, rowKey(model) and marks[rowKey(model)] or nil)
        local cells = {add = addSlot, button = button, key = key, keys = keys, sequence = sequence, state = state,
            remove = remove, mark = mark}
        local chain = {frames = {}, edges = {}}
        for i, name in ipairs(columnLayout()) do
            local cell = cells[name]
            if name == "mark" then
                -- The loadout marker sits just right of the X, on the row's
                -- own line. As a flowed cell it made the row wider than the
                -- pane, so the layout wrapped it under the row; pinned to the
                -- right it never wraps, and tightenRows anchors it to the X.
                cell.flowRightAlign = true
                chain.mark, chain.removeFrame, chain.row = cell.frame, remove.frame, row.frame
            else
                chain.frames[i] = cell.frame
                if name == "sequence" or name == "state" then
                    local edgeFrame, pad = dropdownFieldEdge(cell)
                    chain.edges[i] = {frame = edgeFrame, pad = pad}
                end
            end
            row:AddChild(cell)
        end
        rowChains[#rowChains + 1] = chain
        row:SetHeight(KB_ROW_HEIGHT)
        -- A resize lays the row out again, undoing the tightening: redo it
        -- in the same layout pass (the first row carries the headings).
        row.afterLayout = function()
            if tightenChain(chain) and rowChains[1] == chain then slideHeadings(chain) end
        end
        return row
    end

    redraw = function()
        if #rows == 0 then table.insert(rows, {}) end
        wipe(rowChains)
        wipe(keyRefreshers)
        rowContainer:ReleaseChildren()
        for i = 1, #rows do
            rowContainer:AddChild(buildRow(i))
        end
        rowContainer:DoLayout()
        -- A loadout page: the spec's overrides on buttons it has no row for.
        if loadout then
            local own, entries = {}, {}
            for _, r in ipairs(rows) do
                local key = rowKey(r)
                if key then own[key] = true end
            end
            local spec = overrideScope(specialization, nil, false) or {}
            local keys = {}
            for k, v in pairs(spec) do
                if type(v) == "table" and not own[k] then table.insert(keys, k) end
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = spec[k]
                local label = buttonLabel(v.Bind or k)
                if v.State then label = label .. " (" .. v.State .. ")" end
                entries[#entries + 1] = {first = label, firstWidth = AO_COL_BUTTON, seq = v.Sequence, onOverride = function()
                    addInheritedRow(rows, {bind = v.Bind or k, state = v.State, seq = v.Sequence})
                    markDirty()
                    redraw()
                end}
            end
            inheritedRows = inheritedSection(editframe, inheritedContainer, entries,
                {seqJustify = "LEFT", seqWidth = AO_COL_SEQ, seqInset = 10, topGap = KB_ROW_HEIGHT})
            -- Laid out after the rows on a resize: line up in the same pass.
            for _, entry in ipairs(inheritedRows) do
                entry.row.afterLayout = function() alignInherited(entry) end
            end
            inheritedContainer:DoLayout()
        end
        -- Once now, once after the editor's suspended layout has really run.
        tightenRows()
        if C_Timer and C_Timer.After then C_Timer.After(0, tightenRows) end
    end

    loadRows()
    showState = stateColumnWanted(rows, buttonNames)

    local classid = GSE.GetCurrentClassID()
    local classname, classfile = "", nil
    if GetClassInfo then classname, classfile = GetClassInfo(classid) end
    local specname, specicon = specLabelFor(specialization, classname)
    local classColour = GSEOptions.KEYWORD
    if classfile and C_ClassColor and C_ClassColor.GetClassColor then
        local colour = C_ClassColor.GetClassColor(classfile)
        if colour and colour.GenerateHexColor then classColour = "|c" .. colour:GenerateHexColor() end
    end
    local headerText = iconText(GSE.GetClassIcon(classid), classColour .. (classname or "") .. Statics.StringReset, 22)
    if specname then
        headerText = headerText .. "  -  " .. iconText(specicon, classColour .. specname .. Statics.StringReset, 22)
    end
    -- Sized to its text, so the centred row centres it: a label as wide as
    -- every column together is wider than the pane, and the layout then
    -- starts it at the left edge, off centre (the loadout line below is
    -- sized the same way).
    local function fitToText(label, text)
        label:SetWidth(AO_ROW_WIDTH)
        label:SetText(text)
        local fs = label.text or label.label
        local textWidth = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
        if textWidth > 0 then label:SetWidth(math.ceil(textWidth) + 6) end
    end
    local headerLabel = UI:Create("Heading")
    headerLabel:SetJustifyH("CENTER")
    headerLabel:SetJustifyV("MIDDLE")
    fitToText(headerLabel, headerText)

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
        loadoutRow:AddChild(heroBadge(loadoutArt, 28,
            tonumber(loadout) == activeLoadoutForSpec(tonumber(specialization))))
        loadoutRow:AddChild(loadoutLabel)
    else
        -- No icon on the all-loadouts header: the guillemets already say it is
        -- a scope, and the generic talent icon read as a loadout of its own.
        fitToText(loadoutLabel, heroIconText(loadoutArt, nil, loadoutText, 20))
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
    inheritedContainer = UI:Create("SimpleGroup")
    inheritedContainer:SetFullWidth(true)
    inheritedContainer:SetLayout("List")
    if inheritedContainer.SetListGap then inheritedContainer:SetListGap(2) end

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
        -- "Actionbar Buttons" with its icon is wider than the button column
        -- and was cut to "Actionbar Butto...".  A heading takes the width its
        -- text needs; the tighten pass centres it over its column all the
        -- same, and the columns either side leave it the room.
        local fs = h.text or h.label
        local textWidth = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
        if textWidth + 6 > width then h:SetWidth(math.ceil(textWidth) + 6) end
        return h
    end
    local function blank(width)
        local b = UI:Create("Label")
        b:SetWidth(width)
        b:SetText("")
        return b
    end
    local headingCells = {
        add = function() return blank(KB_COL_ADD) end,
        button = function() return heading(AO_COL_BUTTON, Statics.Icons.Button, L["Action Bar Type"]) end,
        key = function() return heading(AO_COL_KEY, nil, L["Main Key"]) end,
        keys = function() return heading(AO_COL_KEYS, nil, L["Backup Key"]) end,
        sequence = function() return heading(AO_COL_SEQ, Statics.Icons.Sequences, L["Sequence"]) end,
        state = function() return heading(AO_COL_STATE, nil, L["State"]) end,
        remove = function() return blank(KB_COL_REMOVE) end,
        mark = function() return blank(KB_COL_MARK) end,
    }
    -- Same order as the row.  Recorded so the tighten pass can slide each
    -- heading by what its column moved.
    wipe(headingFrames)
    for _, name in ipairs(columnLayout()) do
        local cell = headingCells[name]()
        headings:AddChild(cell)
        headingFrames[#headingFrames + 1] = cell.frame
    end

    if rightContainer.SetListGap then rightContainer:SetListGap(4) end
    rightContainer:AddChild(centeredRow(headerLabel))
    -- As on the keybind panel: no loadout line without talent loadouts.
    if loadout or GSE.HasTalentLoadouts() then rightContainer:AddChild(loadoutRow) end
    local sharedRow = not loadout and sharedProfileRow(editframe, specialization, classname) or nil
    rightContainer:AddChild(headings)
    rightContainer:AddChild(rowContainer)
    rightContainer:AddChild(inheritedContainer)

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
    refitWithPane(rightContainer, tightenRows)
    local sharedRowHeight = sharedRow and pinSharedRow(rightContainer, saveHint, sharedRow) or 0
    rightContainer:SetCallback("OnRelease", function()
        saveButton:Release()
        if sharedRow then sharedRow:Release() end
        -- Rows removed and never saved: the bar goes back to what is saved.
        if releasedUnsaved and not InCombatLockdown() then
            releasedUnsaved = false
            ownOverrideReload = true
            GSE.ReloadOverrides()
            ownOverrideReload = false
        end
    end)

    local bottomGutter = UI:Create("Spacer")
    bottomGutter:SetFullWidth(true)
    bottomGutter:SetHeight(saveButton.frame:GetHeight() + KB_SAVE_INSET * 2 + 18 + sharedRowHeight)
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
-- a blank pane.  Two tiles -- Button Bindings and Keybindings -- each an
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

-- Two half-width cells on one row, each centring whatever it holds, so the
-- two tiles line up across the pane regardless of how far each one's bullets
-- wrapped.
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
local function columnHotspot(container, index, topCell, bottomCell, onClick, onEnter, onLeave)
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
        button:SetScript("OnEnter", function(self)
            glow:Show()
            if self.gseOnEnter then self.gseOnEnter() end
        end)
        button:SetScript("OnLeave", function(self)
            glow:Hide()
            if self.gseOnLeave then self.gseOnLeave() end
        end)
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
    button.gseOnEnter, button.gseOnLeave = onEnter, onLeave
    button:Show()
    return button
end

-- Mirror the right column's outer edge off the left column's: the right
-- hotspot's right edge sits as far in from the pane's right as the left
-- hotspot's left edge sits in from the pane's left.  Measured after layout,
-- so the row's own width arithmetic never has to be right for this to be.
-- Gap between the section divider and the top of a column highlight, so it
-- clears the line by the same margin the highlight leaves at the bottom of
-- the pane.
local KB_HOTSPOT_TOP_GAP = 4

local function mirrorHotspots(container)
    local parent = container.content or container.frame
    local pane = container.frame or parent
    local pair = hotspots[parent]
    local left, right = pair and pair[1], pair and pair[2]
    if not (left and right and pane.GetLeft and left.GetLeft) then return end
    local paneLeft, paneRight = pane:GetLeft(), pane:GetRight()
    local leftEdge, leftRightEdge = left:GetLeft(), left:GetRight()
    if not (paneLeft and paneRight and leftEdge and leftRightEdge) then return end
    local inset = leftEdge - paneLeft
    local width = leftRightEdge - leftEdge
    -- Outer edges line up with the ends of the divider line above, which is
    -- what the eye measures them against. Mirroring the left inset put the
    -- right edge past the line's end: the pane keeps space on the right for
    -- its scrollbar, so the line stops short of the pane edge on that side.
    local rightInset = inset
    local edgeRef = container.gseChooserTopAnchor
    if edgeRef and edgeRef.GetLeft and edgeRef.GetRight then
        local lineLeft, lineRight = edgeRef:GetLeft(), edgeRef:GetRight()
        if lineLeft and lineRight then
            inset = lineLeft - paneLeft
            rightInset = paneRight - lineRight
        end
    end
    -- Start under the section divider rather than over the "Bindings" header.
    -- Measured, so it follows whatever height that header ends up with.
    local topOffset = 0
    local topAnchor = container.gseChooserTopAnchor
    if topAnchor and topAnchor.GetBottom then
        local anchorBottom, paneTop = topAnchor:GetBottom(), pane:GetTop()
        if anchorBottom and paneTop then
            topOffset = math.min(0, anchorBottom - paneTop) - KB_HOTSPOT_TOP_GAP
        end
    end
    -- Both columns run the pane's full height. The top used to come from the
    -- column's own top cell, which is fine while the tiles start at the top of
    -- the pane; centred, that left the highlight starting halfway down.
    --
    -- Anchored to the scrolled content, not the pane, so they move with the
    -- page when it scrolls; the pane is the fixed viewport, and highlights
    -- pinned to it stayed put while the tiles scrolled away under them. The
    -- offsets measured against the pane above are carried over to the content
    -- by the difference between the two frames' edges, taken at the same
    -- moment. The bottom is the content's own bottom when it is taller than
    -- the pane (the page scrolls), else the pane's, as before.
    local anchor, dx, dy = pane, 0, 0
    local contentTop, contentBottom = parent.GetTop and parent:GetTop(), parent.GetBottom and parent:GetBottom()
    local paneTop, paneBottom = pane:GetTop(), pane:GetBottom()
    local contentLeft, contentRight = parent.GetLeft and parent:GetLeft(), parent.GetRight and parent:GetRight()
    if parent ~= pane and contentTop and contentBottom and paneTop and paneBottom and contentLeft and contentRight then
        anchor = parent
        dx = paneLeft - contentLeft
        dy = paneTop - contentTop
    end
    local bottomAnchor, bottomDy = pane, 0
    if anchor ~= pane and (contentTop - contentBottom) > (paneTop - paneBottom) + 1 then
        bottomAnchor = parent
    elseif anchor ~= pane then
        -- Content fits: keep the bottom on the pane's, expressed against the
        -- content so both ends move together.
        bottomAnchor = parent
        bottomDy = paneBottom - contentBottom
    end
    left:ClearAllPoints()
    left:SetWidth(width)
    left:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset + dx, topOffset + dy)
    left:SetPoint("BOTTOMLEFT", bottomAnchor, "BOTTOMLEFT", inset + (bottomAnchor == pane and 0 or dx), bottomDy)
    right:ClearAllPoints()
    right:SetWidth(width)
    local rdx = (anchor ~= pane) and (paneRight - contentRight) or 0
    right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -rightInset + rdx, topOffset + dy)
    right:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMRIGHT", -rightInset + (bottomAnchor == pane and 0 or rdx), bottomDy)
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

-- The two cells are 0.49 of the row each and pack from the left, so the 2%
-- left over sits to the right of the second column and its content reads as
-- shifted left. Push the right cell over by exactly that, measured after
-- layout, so each column sits the same distance inside its own edge.
local function alignRightColumn(row, leftCell, rightCell)
    if not (row and leftCell and rightCell) then return end
    if not (row.frame and leftCell.frame and rightCell.frame) then return end
    local rowWidth = row.frame:GetWidth()
    local leftWidth = leftCell.frame:GetWidth()
    local rightWidth = rightCell.frame:GetWidth()
    if not (rowWidth and leftWidth and rightWidth) then return end
    local slack = rowWidth - leftWidth - rightWidth
    if slack > 0 and rightCell.SetFlowOffset then rightCell:SetFlowOffset(slack, 0) end
end

local function showKeybindChooser(editframe, rightContainer)
    wipe(pendingParagraphs)

    -- Opening Bindings unfolds this character's spec under both areas, so its
    -- talent loadouts -- and the gold ring on the one in use -- show without a click.
    local tree = editframe.treeContainer
    local status = tree and (tree.status or tree.localstatus)
    if status and status.groups and tree.RefreshTree then
        for _, area in ipairs({"KB", "AO"}) do
            GSE.GUI.ExpandBindingsPath(editframe, GSE.GUI.BindingsPath(area, defaultSpecIndex()))
        end
        tree:RefreshTree()
    end

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

    -- Where each tile lands: this character's spec (every client has a node
    -- per spec, GSE.BindingSpecs), which opens on All Talent Loadouts.
    local keybindPath = GSE.GUI.BindingsPath("KB", defaultSpecIndex())
    -- The loadout the player is in, when there is one: each tile goes straight
    -- to it rather than to the spec, and lights its row in the tree on hover.
    local activeLoadout = activeLoadoutForSpec(defaultSpecIndex())
    local overridePath = GSE.GUI.BindingsPath("AO", defaultSpecIndex())
    if activeLoadout then
        keybindPath = keybindPath .. "\001" .. tostring(activeLoadout)
        overridePath = overridePath .. "\001" .. tostring(activeLoadout)
    end

    -- The tree row a tile leads to, lit with the tree's own selection band
    -- while the tile is hovered, and put back as the tree left it after.
    local function treeRow(path)
        local tree = editframe.treeContainer
        for _, row in ipairs(tree and tree.buttons or {}) do
            if row:IsShown() and row.uniquevalue == path then return row end
        end
    end
    local function lightRow(path)
        local row = treeRow(path)
        if row and row.selectBand then row.selectBand:Show() end
    end
    local function restoreRow(path)
        local row = treeRow(path)
        if row and row.selectBand then row.selectBand:SetShown(row.selected and true or false) end
    end

    -- Content from the GSE wiki, KeyBinding and Button Bindings.
    local overrideTop, overrideNote, overrideBullets = chooserTile(
        Statics.Icons.Button,
        L["Button Bindings"],
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
            L["Works with any action bar addon, and with key-up or key-down."],
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
            L["When flying, the Sky Riding bar's own binds override these on keys 1-7.  The alternative is to use [flying] in the sequence, eg /click [flying] ActionButton2."],
        },
        function() goTo(keybindPath) end
    )

    -- The section divider is the last thing already in the pane; the column
    -- highlights below start under its line rather than over the header.
    local existing = rightContainer.children
    local divider = existing and existing[#existing]
    rightContainer.gseChooserTopAnchor = divider and divider.frame or nil

    -- The tiles sit centred on the pane rather than at the top. The spacer is
    -- sized once the layout has landed, below; the two columns keep their
    -- alignment to each other -- the whole block simply moves down together.
    local centreSpacer = UI:Create("Spacer")
    if centreSpacer.SetFullWidth then centreSpacer:SetFullWidth(true) end
    centreSpacer:SetHeight(1)
    rightContainer:AddChild(centreSpacer)

    local topRow, overrideTopCell, keybindTopCell = halfRow(overrideTop, keybindTop)
    rightContainer:AddChild(topRow)
    local noteRow, overrideNoteCell, keybindNoteCell = halfRow(overrideNote, keybindNote, 6, true)
    rightContainer:AddChild(noteRow)
    -- The bullets are the bottom of each column now: the two pictures below
    -- them illustrated the key-up / key-down split, and that split is gone.
    local bulletRow, overrideBulletCell, keybindBulletCell =
        halfRow(overrideBullets, keybindBullets, 6)
    rightContainer:AddChild(bulletRow)

    -- Hover + click over each whole column, both running to the bottom of
    -- the pane.
    columnHotspot(rightContainer, 1, overrideTopCell, overrideBulletCell, function() goTo(overridePath) end,
        function() lightRow(overridePath) end, function() restoreRow(overridePath) end)
    columnHotspot(rightContainer, 2, keybindTopCell, keybindBulletCell, function() goTo(keybindPath) end,
        function() lightRow(keybindPath) end, function() restoreRow(keybindPath) end)

    -- Heights are only right once the widths are: once now for the case
    -- where layout is live, then through refitWithPane after every show and
    -- resize of the pane.
    fitParagraphs(rightContainer)
    mirrorHotspots(rightContainer)

    local spacerHeight = 1
    local function showingChooser()
        return centreSpacer.parent == rightContainer
    end
    -- Measure the block and size the spacer so its middle sits on the pane's
    -- middle. A block taller than the pane stays at the top.
    local function centreBlock()
        if not showingChooser() or not rightContainer.scrollframe then return end
        local viewTop = rightContainer.scrollframe:GetTop()
        local viewBottom = rightContainer.scrollframe:GetBottom()
        local blockTop = topRow.frame:GetTop()
        local blockBottom = bulletRow.frame:GetBottom()
        if not (viewTop and viewBottom and blockTop and blockBottom) then return end
        local wantTop = (viewTop + viewBottom) / 2 + (blockTop - blockBottom) / 2
        spacerHeight = math.max(1, math.floor(spacerHeight + blockTop - wantTop))
        centreSpacer:SetHeight(spacerHeight)
        if rightContainer.DoLayout then rightContainer:DoLayout() end
        mirrorHotspots(rightContainer)
    end
    local function relayout()
        if not showingChooser() then return end
        fitParagraphs(rightContainer)
        alignRightColumn(topRow, overrideTopCell, keybindTopCell)
        alignRightColumn(noteRow, overrideNoteCell, keybindNoteCell)
        alignRightColumn(bulletRow, overrideBulletCell, keybindBulletCell)
        mirrorHotspots(rightContainer)
        -- A frame later again, once those heights have landed.
        if C_Timer and C_Timer.After then C_Timer.After(0, centreBlock) end
    end
    refitWithPane(rightContainer, relayout)()
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
