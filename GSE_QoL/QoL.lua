local GSE = GSE

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

-- Patron feature: stamp the checksum onto the locally saved sequence on every save.
-- Non-patrons only receive a checksum via the export path.
local function onSequenceSaved(_, sequenceName)
    if not GSE.Patron then return end
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

-- Skyriding Bind Bar for Retail
if GSE.GameMode >= 11 then
    -- Native Blizzard Settings subcategory. Lifted from the master-branch
    -- pattern that was overwritten by the AceGUI removal pass — register a
    -- vertical layout subcategory and add native button initializers, one
    -- per vehicle slot. CreateSettingsButtonInitializer + SettingsPanel are
    -- standard Blizzard APIs (11.0+); the panel rebuilds each open from
    -- the initializer data so the displayed text always reflects what
    -- was saved.
    local skyOptions = Settings.RegisterVerticalLayoutSubcategory(
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


    -- Hidden macro buttons that execute pet battle abilities, to click on them when the player -- enters a pet battle, with the binds assigned by the user in the vehicle binds panel
    ----------------------------------------------------------------------------------------------------------

    -- Pet battle buttons
    local PetBattleButton = {}
    for i = 1, 6 do
        PetBattleButton[i] = CreateFrame("Button", "GSE_PetBattleButton" .. i, nil, "SecureActionButtonTemplate")
        PetBattleButton[i]:RegisterForClicks("AnyDown")
        PetBattleButton[i]:SetAttribute("type", "macro")
        if i <= 3 then
            PetBattleButton[i]:SetAttribute(
                "macrotext",
                "/run PetBattleFrame.BottomFrame.abilityButtons[" .. i .. "]:Click()"
            )
        end
    end

    PetBattleButton[4]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.SwitchPetButton:Click()")
    PetBattleButton[5]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.CatchButton:Click()")
    PetBattleButton[6]:SetAttribute("macrotext", "/run PetBattleFrame.BottomFrame.ForfeitButton:Click()") -- Hidden action bar to click on its buttons when the player enters a vehicle or -- skyriding mount, with the binds assigned by the user in the vehicle binds panel
    -------------------------------------------------------------------------------------------------------

    -- Vehicle/Skyriding bar
    local VehicleBar = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
    VehicleBar:SetAttribute("actionpage", 1)
    VehicleBar:Hide()

    -- Creating buttons
    local VehicleButton = {}
    for i = 1, 12 do
        VehicleButton[i] = CreateFrame("Button", "GSE_VehicleButton" .. i, VehicleBar, "SecureActionButtonTemplate")
        local B = VehicleButton[i]
        B:Hide()
        B:SetID(i)
        B:SetAttribute("type", "action")
        B:SetAttribute("action", i)
        B:SetAttribute("useparent-actionpage", true)
        B:RegisterForClicks("AnyDown")
    end

    -- Table that will store the keybinds for vehicles desired by the user

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
        local executionString =
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
        if not tablevals then
            executionString = "VehicleKeybind = newtable()"
        end
        VehicleBar:Execute(executionString) -- Key: Button index / Value: Keybind
    end

    GSE.UpdateVehicleBar()
    -- Triggers
    VehicleBar:SetAttribute(
        -- Leading underscore matters. Dropping it (the change at a32c1c64
        -- "Second Cut removing AceGUI Dependency") broke skyriding /
        -- vehicle / petbattle key bindings — BoKamil reported it 2026-06-01;
        -- downgrade to pre-a32c1c64 on the same client restored function,
        -- proving it's our code, not a Blizzard-side change. The snippet
        -- below uses secure restricted-environment methods (SetBindingClick)
        -- so the attribute name has to be the one the secure infrastructure
        -- listens to; the unprefixed name isn't it. Do not drop the
        -- underscore again.
        "_onattributechanged",
        [[
  -- Actionpage update
  if name == "page" then
    if HasVehicleActionBar() then self:SetAttribute("actionpage", GetVehicleBarIndex())
    elseif HasOverrideActionBar() then self:SetAttribute("actionpage", GetOverrideBarIndex())
    elseif HasBonusActionBar() then self:SetAttribute("actionpage", GetBonusBarIndex())
    else self:SetAttribute("actionpage", GetActionBarPage()) end

  -- Settings binds of higher priority than the normal ones when the player enters a vehicle, to be able to use it
  elseif name == "vehicletype" then
    if value == "vehicle" then -- Vehicles/Skyriding
      for i = 1, 12 do
        if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_VehicleButton"..i) end
      end

    elseif value == "petbattle" then -- Pet battle
      for i = 1, 6 do
        if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_PetBattleButton"..i) end
      end

    elseif value == "none" then -- No vehicle, deleting vehicle binds
      self:ClearBindings()
    end
  end
]]
    )

    -- Actionpage trigger
    RegisterAttributeDriver(VehicleBar, "page", "[vehicleui] A; [possessbar] B; [overridebar] C; [bonusbar:5] D; E")

    -- Vehicle trigger
    RegisterAttributeDriver(
        VehicleBar,
        "vehicletype",
        "[vehicleui][possessbar][overridebar][bonusbar:5] vehicle;" .. "[petbattle] petbattle;" .. "none"
    ) -- Event PET_BATTLE_OPENING_START -- Triggers when a pet battle starts. Used only in MoP because it doesn't have the [petbattle] -- macro condition to detect pet battles from the Restricted Environment like post-MoP expansions.
    ----------------------------------------------------------------------------------------------------------------------

    --[[ Events ]]
    function GSE:PET_BATTLE_OPENING_START()
        VehicleBar:Execute(
            [[
    for i = 1, 6 do
      if VehicleKeybind[i] then self:SetBindingClick(true, VehicleKeybind[i], "GSE_PetBattleButton"..i) end
    end
  ]]
        )
    end

    -- Event PET_BATTLE_CLOSE
    -- Triggers when a pet battle starts. Used only in MoP because it doesn't have the [petbattle]
    -- macro condition to detect pet battles from the Restricted Environment like post-MoP expansions.
    function GSE:PET_BATTLE_CLOSE()
        VehicleBar:Execute([[ self:ClearBindings() ]])
    end
    GSE:RegisterEvent("PET_BATTLE_OPENING_START")
    GSE:RegisterEvent("PET_BATTLE_CLOSE")
end
