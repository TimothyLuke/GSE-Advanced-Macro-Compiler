local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local L = GSE.L
local Statics = GSE.Static

-- ── The GSE Action Bar ──────────────────────────────────────────────────────
--
-- Two bars of twelve buttons, GSEButton1-24, each a binding WoW knows about
-- (Bindings.xml), so its key is set, kept and conflict-checked in WoW's own
-- Key Bindings like any action bar's. A button holds a spell, item, macro and
-- so on like any bar's (Actions.lua), or runs the sequence its Button Binding
-- names -- set in the editor's Button Bindings, by right-clicking the button,
-- or by dropping a sequence on it -- through the same override every other
-- bar's buttons get (Events.lua), so it follows the spec and talent loadout
-- the same way.
--
-- Every setting is out of combat: the buttons are secure, so WoW will not let
-- them be shown, hidden, moved or resized in combat. Alpha is the exception,
-- which is how a hidden bar hides -- shown at no alpha with the mouse off, so
-- its keys still work -- and how Mouseover shows one.

-- The button template's own size (45 on Retail, 36 on the classics), read
-- off the first button: its art is laid out for that size, and a button made
-- smaller leaves the icon short of the frame. A bar's Scale sizes it.
local buttonSize = 36
local BAR_COUNT = ns.BUTTON_COUNT / ns.BAR_SIZE
local DEFAULT_POINTS = {
    [1] = { "BOTTOM", "UIParent", "BOTTOM", 0, 230 },
    [2] = { "BOTTOM", "UIParent", "BOTTOM", 0, 276 },
}

local bars, buttons = {}, {}
local dragging = false -- a sequence is being dragged: every bar shows for the drop
local editing = false -- WoW's Edit Mode is open: every bar shows to be placed
local keybinding = false -- WoW's Quick Keybind mode is on: every button shows to be bound
local inCombat = InCombatLockdown() -- for the In Combat / Out of Combat bars
local pendingLayout = false -- a change waited for combat to end

local Masque = LibStub and LibStub("Masque", true)

local function barOf(index)
    return math.floor((index - 1) / ns.BAR_SIZE) + 1
end

-- What WoW's Key Bindings call each button (Bindings.xml). The sections,
-- one per bar as the stock bars have, are named in Statics.lua.
for index = 1, ns.BUTTON_COUNT do
    _G["BINDING_NAME_" .. ns.BindingCommand(index)] = string.format(L["GSE Action Bar %d Button %d"],
        barOf(index), (index - 1) % ns.BAR_SIZE + 1)
end

--- The buttons' names, for the editor's Button Bindings -- none while the
--- bar is turned off.
function GSE.ActionBarButtonNames()
    local names = {}
    if not GSE.ActionBarActive() then return names end
    for index = 1, ns.BUTTON_COUNT do names[index] = ns.ButtonName(index) end
    return names
end

-- The key WoW binds to a button, as the button shows it.
local function keyText(index)
    local key = GetBindingKey(ns.BindingCommand(index))
    if not key then return "" end
    local text = GetBindingText and GetBindingText(key, true) or key
    return text or key
end

local function updateKeys()
    local show = ns.Options().ShowKeys
    for index, button in ipairs(buttons) do
        if button.HotKey then
            button.HotKey:SetText(show and keyText(index) or "")
            button.HotKey:SetShown(show)
        end
    end
end


-- Size, rows and place of one bar, and which of its buttons show. Icons is
-- how many of its twelve buttons it has; PerRow how many sit side by side
-- before the next line starts -- a row, or a column when it is vertical.
local function layoutBar(b)
    local bar, settings, options = bars[b], ns.Options().Bars[b], ns.Options()
    local count = math.max(1, math.min(ns.BAR_SIZE, tonumber(settings.Icons) or ns.BAR_SIZE))
    local perRow = math.max(1, math.min(count, tonumber(settings.PerRow) or ns.BAR_SIZE))
    local vertical = settings.Orientation == "VERTICAL"
    local spacing = tonumber(options.Spacing) or 4
    local rows = math.ceil(count / perRow)
    local across, down = perRow, rows
    if vertical then across, down = rows, perRow end
    bar:SetScale(math.max(0.5, math.min(2, tonumber(settings.Scale) or 1)))
    bar:SetSize(across * buttonSize + (across - 1) * spacing, down * buttonSize + (down - 1) * spacing)
    bar:ClearAllPoints()
    -- In Edit Mode's layout, where it has one (EditMode.lua); else where it
    -- was dragged to, or where it starts.
    local point = ns.EditModePoint and ns.EditModePoint(b)
        or type(settings.Point) == "table" and settings.Point or DEFAULT_POINTS[b]
    bar:SetPoint(point[1], UIParent, point[3], point[4], point[5])
    for slot = 1, ns.BAR_SIZE do
        local button = buttons[(b - 1) * ns.BAR_SIZE + slot]
        local column, row = (slot - 1) % perRow, math.floor((slot - 1) / perRow)
        if vertical then column, row = row, column end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", column * (buttonSize + spacing), -row * (buttonSize + spacing))
        button:SetShown(slot <= count
            and (dragging or editing or keybinding or options.ShowEmpty or ns.HasContent(button)))
    end
end

-- How much of a bar shows, and whether it takes the mouse. Alpha only, so
-- this much works in combat too.
local function barAlpha(b)
    local visibility = ns.Options().Bars[b].Visibility
    if dragging or editing or keybinding or visibility == "SHOW" then return 1 end
    if visibility == "INCOMBAT" then return inCombat and 1 or 0 end
    if visibility == "OUTOFCOMBAT" then return inCombat and 0 or 1 end
    if visibility == "MOUSEOVER" and bars[b]:IsMouseOver() then return 1 end
    return 0
end

local function applyVisibility(b)
    local bar = bars[b]
    bar:SetAlpha(barAlpha(b))
    if InCombatLockdown() then return end
    local mouse = dragging or keybinding or ns.Options().Bars[b].Visibility ~= "HIDE"
    for slot = 1, ns.BAR_SIZE do
        buttons[(b - 1) * ns.BAR_SIZE + slot]:EnableMouse(mouse)
    end
end

--- Lay every bar out again from its settings. In combat it waits. Turned
--- off, the bars hide; their buttons were disarmed with the overrides
--- (GSE.ReloadOverrides skips them), so their keys do nothing.
function ns.Refresh()
    if InCombatLockdown() then
        pendingLayout = true
        return
    end
    pendingLayout = false
    if not GSE.ActionBarActive() then
        for b = 1, BAR_COUNT do bars[b]:Hide() end
        return
    end
    for b = 1, BAR_COUNT do
        bars[b]:Show()
        layoutBar(b)
        applyVisibility(b)
        -- Where the client has Edit Mode, it places the bars instead (EditMode.lua).
        bars[b].mover:SetShown(not ns.Options().Locked and not ns.editMode)
    end
    updateKeys()
    ns.ApplyActions()
end

-- Unlocked, each bar has a handle over it to drag it by. Its place is kept
-- per bar, against the bottom of the screen it was dropped nearest.
local function makeMover(bar, b)
    local mover = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    mover:SetAllPoints()
    mover:SetFrameLevel(bar:GetFrameLevel() + 20)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    if mover.SetBackdrop then
        mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        mover:SetBackdropColor(0, 0.6, 1, 0.35)
    end
    mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mover.label:SetPoint("CENTER")
    mover.label:SetText(string.format(L["GSE Action Bar %d"], b))
    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        bar:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        -- Kept against UIParent, at the bar's own scale.
        local point, _, relativePoint, x, y = bar:GetPoint(1)
        ns.Options().Bars[b].Point = { point, "UIParent", relativePoint, x, y }
    end)
    mover:Hide()
    return mover
end

-- An empty button says what it is for.
local function emptyTooltip(button)
    if ns.HasContent(button) or InCombatLockdown() then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(string.format(L["GSE Button %d"], button.gseIndex))
    GameTooltip:AddLine(L["Drag a spell, item, macro or sequence here, or right-click to choose a sequence. Set its key in WoW's Key Bindings, under GSE."], 1, 1, 1, true)
    GameTooltip:Show()
end

for b = 1, BAR_COUNT do
    local bar = CreateFrame("Frame", "GSEActionBar" .. b, UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.mover = makeMover(bar, b)
    -- Mouseover bars fade in under the mouse; alpha is allowed in combat.
    local elapsed = 0
    bar:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        if ns.Options().Bars[b].Visibility == "MOUSEOVER" and not dragging then
            self:SetAlpha(barAlpha(b))
        end
    end)
    bars[b] = bar
    bar.masque = Masque and Masque:Group(L["GSE Action Bar"], string.format(L["Bar %d"], b))
end

for index = 1, ns.BUTTON_COUNT do
    -- The secure template last, as WoW's own bars have it: ActionButtonTemplate
    -- brings the flyout's OnClick, and whichever template comes later sets the
    -- script. Listed first, the secure click was replaced and nothing ran.
    local button = CreateFrame("CheckButton", ns.ButtonName(index), bars[barOf(index)],
        "ActionButtonTemplate, SecureActionButtonTemplate")
    -- No SetID: an ID is an action slot to GSE's overrides, which would then
    -- yield the button to whatever sits in that slot of WoW's own bar.
    button.gseIndex = index
    if index == 1 and (button:GetWidth() or 0) > 0 then buttonSize = button:GetWidth() end
    -- The cooldown's number sits centred on the button, whatever its frame
    -- is anchored to.
    local countdown = button.cooldown and button.cooldown.GetCountdownFontString
        and button.cooldown:GetCountdownFontString()
    if countdown then
        countdown:ClearAllPoints()
        countdown:SetPoint("CENTER", button, "CENTER", 0, 0)
        if countdown.SetJustifyH then countdown:SetJustifyH("CENTER") end
        if countdown.SetJustifyV then countdown:SetJustifyV("MIDDLE") end
    end
    -- Marks it for the drag and the right-click menu, which otherwise want a
    -- button with an action slot, and for the overrides, which never look for
    -- one behind it.
    button.gseActionBarButton = true
    -- Both edges: the button acts on the one ActionButtonUseKeyDown names (no
    -- useOnKeyDown of its own) and hands a single click on to the sequence.
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- A right click is the menu (GSE.ActionButtonMenuHandler), never a cast.
    button:SetAttribute("type2", "")
    -- Before any hook on OnClick: it wraps OnClick, and wrapping sets the
    -- script, which drops the hooks already on it -- the menu's among them.
    ns.SetupActionButton(button)
    if GSE.ActionButtonMenuHandler then button:HookScript("OnClick", GSE.ActionButtonMenuHandler) end
    button:HookScript("OnEnter", emptyTooltip)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    if bars[barOf(index)].masque then bars[barOf(index)].masque:AddButton(button, nil, "Action") end
    -- WoW's Quick Keybind mode binds the hovered button to the next key, as
    -- on its own bars. Its mixin, not its template: the template brings an
    -- OnClick, which would replace the secure click.
    if _G.QuickKeybindButtonTemplateMixin and _G.KeybindFrames_InQuickKeybindMode then
        Mixin(button, _G.QuickKeybindButtonTemplateMixin)
        button.commandName = ns.BindingCommand(index)
        local highlight = button:CreateTexture(nil, "OVERLAY")
        highlight:SetAllPoints()
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.4)
        highlight:Hide()
        button.QuickKeybindHighlightTexture = highlight
        button:HookScript("OnEnter", button.QuickKeybindButtonOnEnter)
        button:HookScript("OnLeave", button.QuickKeybindButtonOnLeave)
    end
    buttons[index] = button
end
ns.buttons = buttons
ns.bars, ns.DEFAULT_POINTS = bars, DEFAULT_POINTS

--- WoW's Edit Mode opened or closed (EditMode.lua): open, every bar and
--- button shows, to see what is being placed.
function ns.SetEditing(open)
    editing = open
    ns.Refresh()
end

-- Quick Keybind mode on or off: every button shows, lit, while it is on.
-- Followed on the window itself: WoW announces only that the mode ended.
if _G.QuickKeybindFrame and _G.QuickKeybindButtonTemplateMixin then
    local function setKeybinding(on)
        keybinding = on
        for _, button in ipairs(buttons) do
            if button.DoModeChange then button:DoModeChange(on) end
        end
        ns.Refresh()
    end
    _G.QuickKeybindFrame:HookScript("OnShow", function() setKeybinding(true) end)
    _G.QuickKeybindFrame:HookScript("OnHide", function() setKeybinding(false) end)
end

-- Every event that changes what the bars show.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("UPDATE_BINDINGS")
-- WoW's own signal that the cursor picked up something an action bar takes.
events:RegisterEvent("ACTIONBAR_SHOWGRID")
events:RegisterEvent("ACTIONBAR_HIDEGRID")

-- The keybinds move onto the bar once per character; early in a login WoW
-- cannot yet say which spec is which, so it tries again for a while.
local migrationTries = 0
local function migrate()
    if not GSE.ActionBarActive() then return end
    if ns.MigrateKeybinds() then
        if not InCombatLockdown() and GSE.ReloadOverrides then GSE.ReloadOverrides() end
        return
    end
    migrationTries = migrationTries + 1
    if migrationTries < 30 and not InCombatLockdown() then C_Timer.After(1, migrate) end
end

events:SetScript("OnEvent", function(_, event)
    -- In Combat / Out of Combat bars change by alpha, which combat allows.
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        for b = 1, BAR_COUNT do bars[b]:SetAlpha(barAlpha(b)) end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then inCombat = false end
    if event == "UPDATE_BINDINGS" then
        updateKeys()
        return
    end
    -- A spell, item or macro on the cursor: every bar shows to drop it on, as
    -- for a sequence.
    if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
        local showing = event == "ACTIONBAR_SHOWGRID"
        if showing and not GSE.ActionBarActive() then return end
        if dragging == showing then return end
        dragging = showing
        ns.Refresh()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then migrate() end
    if event == "PLAYER_REGEN_ENABLED" then
        if type(GSE_C) == "table" and not (GSE_C.Updates and GSE_C.Updates.actionBarKeys) then migrate() end
        if not pendingLayout then
            for b = 1, BAR_COUNT do applyVisibility(b) end
            return
        end
    end
    ns.Refresh()
end)

-- A Button Binding was set or cleared, or the spec or loadout changed: which
-- buttons are empty changed with it.
local messages = LibStub("AceEvent-3.0"):Embed({})
messages:RegisterMessage(Statics.Messages.ACTIONBAR_OVERRIDES_UPDATED, function() ns.Refresh() end)
-- A sequence is being dragged: every button shows to drop it on, whatever
-- the bar is set to, and goes back when the drag ends. Drags happen only out
-- of combat (GSE.BeginSequenceDrag).
messages:RegisterMessage(Statics.Messages.SEQUENCE_DRAG_STARTED, function()
    if not GSE.ActionBarActive() then return end
    dragging = true
    ns.Refresh()
end)
messages:RegisterMessage(Statics.Messages.SEQUENCE_DRAG_ENDED, function()
    if not dragging then return end
    dragging = false
    ns.Refresh()
end)

-- GSE's options change a setting: lay the bars out again.
GSE.ActionBarRefresh = ns.Refresh

--- Turned on or off (GSE.StartActionBar), and once at load: on, move this
--- character's keybinds onto the bar and show it; off, hide it.
function GSE.ActionBarApply()
    migrate()
    ns.Refresh()
end

GSE.ActionBarApply()
end
table.insert(ns.deferred, setup)
