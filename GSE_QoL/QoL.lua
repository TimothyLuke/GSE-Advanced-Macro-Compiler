local GSE = GSE

local Statics = GSE.Static

local L = GSE.L
-- Icon for the "Skyriding / Vehicle Keybinds" editor tree node, using the
-- skyriding.png art now shipped under GSE_GUI/Assets (a 128x128 Skyriding icon).
local SKYRIDING_KEYBIND_ICON = "Interface\\AddOns\\GSE_GUI\\Assets\\skyriding.png"
local SKYRIDING_KEYBIND_COL_WIDTH  = 200   -- each of the 3 even columns
local SKYRIDING_KEYBIND_ICON_COL   = 30    -- icon size (image = frame size)
local SKYRIDING_KEYBIND_LABEL_WIDTH  = SKYRIDING_KEYBIND_COL_WIDTH
local SKYRIDING_KEYBIND_BUTTON_WIDTH = 130
local SKYRIDING_KEYBIND_ROW_GAP = 16
local SKYRIDING_KEYBIND_ROW_WIDTH = SKYRIDING_KEYBIND_LABEL_WIDTH + SKYRIDING_KEYBIND_ROW_GAP +
    SKYRIDING_KEYBIND_BUTTON_WIDTH + SKYRIDING_KEYBIND_ROW_GAP + SKYRIDING_KEYBIND_ICON_COL
local SKYRIDING_KEYBIND_ROW_COUNT = 12
local SKYRIDING_KEYBIND_ROW_HEIGHT = 34
local SKYRIDING_KEYBIND_DIVIDER_HEIGHT = 1
local SKYRIDING_KEYBIND_LIST_GAP = 2
local SKYRIDING_KEYBIND_ROWS_HEIGHT = (SKYRIDING_KEYBIND_ROW_COUNT * SKYRIDING_KEYBIND_ROW_HEIGHT) +
    ((SKYRIDING_KEYBIND_ROW_COUNT - 1) * SKYRIDING_KEYBIND_LIST_GAP)

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
    local function GetSkyridingBindText(slotIndex)
        return (GSEOptions.SkyRidingBinds and GSEOptions.SkyRidingBinds[tostring(slotIndex)]) or L["Not Bound"]
    end

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
        if self.obj and self.obj.SetText then
            self.obj:SetText(binding)
        else
            self:SetText(binding)
        end
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
    end

    local function CancelSkyridingKeyCapture(button)
        if not button then return end
        local frame = button.frame or button
        if frame.SetScript then frame:SetScript("OnKeyDown", nil) end
        if frame.EnableKeyboard then frame:EnableKeyboard(false) end
        if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
    end

    local function StartSkyridingKeyCapture(button, slotIndex)
        if not button then return end
        local frame = button.frame or button
        frame.gseSlot = slotIndex
        if button.SetText then
            button:SetText(L["Press a key..."])
        elseif frame.SetText then
            frame:SetText(L["Press a key..."])
        end
        if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(false) end
        if frame.EnableKeyboard then frame:EnableKeyboard(true) end
        if frame.SetScript then frame:SetScript("OnKeyDown", onKeyDown) end
    end

    function GSE.BuildSkyridingKeybindTreeNode()
        return {
            value = "SKYRIDING",
            text = L["Skyriding / Vehicle Keybinds"],
            icon = SKYRIDING_KEYBIND_ICON
        }
    end

    function GSE.DrawSkyridingKeybindEditor(container)
        local activeUI = GSE.UI
        if not (container and activeUI) then return end
        container:ReleaseChildren()
        container:SetFullHeight(true)
        container:SetLayout("List")
        local skyPad = (GSE.GUI and GSE.GUI.CONTENT_PADDING) or 20
        container:SetListPadding(skyPad, skyPad, skyPad, skyPad)
        container:SetListGap(SKYRIDING_KEYBIND_LIST_GAP)

        local function centerFlowContent(widget, contentWidth)
            local function apply(width)
                width = tonumber(width) or (widget.frame and widget.frame:GetWidth()) or contentWidth
                local padding = math.max(0, math.floor((width - contentWidth) / 2))
                widget.flowPadLeft = padding
                widget.flowPadRight = padding
            end

            widget.OnWidthSet = function(self, width)
                apply(width)
                if self.DoLayout then self:DoLayout() end
            end

            -- Frame-level OnSizeChanged catches size changes from the parent
            -- container's layout pass, which AceGUI does NOT always route through
            -- the widget's SetWidth path. Without this hook, SetFullWidth(true)
            -- children get the correct frame width but never recompute padding,
            -- leaving the flow content stuck at left-aligned (padding = 0).
            if widget.frame and widget.frame.HookScript then
                widget.frame:HookScript("OnSizeChanged", function(_, width)
                    apply(width)
                    if widget.DoLayout then widget:DoLayout() end
                end)
            end

            apply(widget.width)
        end

        local function centerRowsVertically(widget, spacer)
            local function apply(height)
                height = tonumber(height) or (widget.frame and widget.frame:GetHeight()) or 0
                local skyPad2 = (GSE.GUI and GSE.GUI.CONTENT_PADDING) or 20
                -- 36 px headingRow + 1 px divider + 3 list gaps = fixed visual height above rows.
                local fixedHeight = skyPad2 +
                    36 +
                    SKYRIDING_KEYBIND_DIVIDER_HEIGHT +
                    SKYRIDING_KEYBIND_ROWS_HEIGHT +
                    skyPad2 +
                    (SKYRIDING_KEYBIND_LIST_GAP * 3)
                local spacerHeight = math.max(0, math.floor((height - fixedHeight) / 2))

                spacer.height = spacerHeight
                spacer.explicitHeight = true
                if spacer.frame then spacer.frame:SetHeight(math.max(1, spacerHeight)) end
            end

            widget.OnHeightSet = function(_, height)
                apply(height)
            end

            if widget.frame and widget.frame.HookScript then
                widget.frame:HookScript("OnSizeChanged", function(_, _, height)
                    apply(height)
                    if widget.DoLayout then widget:DoLayout() end
                end)
            end

            apply(widget.height)
        end

        local function addDivider()
            local divider = activeUI:Create("SimpleGroup")
            divider:SetFullWidth(true)
            divider:SetHeight(1)
            local line = divider.frame and divider.frame:CreateTexture(nil, "ARTWORK")
            if line then
                line:SetPoint("LEFT", divider.frame, "LEFT", 0, 0)
                line:SetPoint("RIGHT", divider.frame, "RIGHT", 0, 0)
                line:SetHeight(1)
                line:SetColorTexture(1, 1, 1, 0.22)
            end
            container:AddChild(divider)
        end

        -- Page header. The canvas subcategory does not get a native Blizzard
        -- header (only VerticalLayoutSubcategory does), so render one in-canvas
        -- styled to match Tools & Diagnostics: white text, GameFontHighlightLarge-ish
        -- font, left-aligned, followed by a 1px divider line.
        local headingRow = activeUI:Create("SimpleGroup")
        headingRow:SetFullWidth(true)
        headingRow:SetHeight(36)
        headingRow:SetLayout("Flow")
        if headingRow.SetFlowPadding then headingRow:SetFlowPadding(10, 6, 0, 0) end

        local heading = activeUI:Create("Heading")
        heading:SetText(L["Skyriding / Vehicle Keybinds"])
        heading:SetWidth(520)
        heading:SetHeight(28)
        heading:SetJustifyH("LEFT")
        heading:SetJustifyV("MIDDLE")
        heading:SetColor(1, 1, 1, 1)
        if heading.frame then
            local fs = heading.frame.GetFontString and heading.frame:GetFontString()
            if not fs then fs = heading.label or heading.text end
            if fs and fs.SetFont and GameFontHighlightLarge then
                local face, size, flags = GameFontHighlightLarge:GetFont()
                if face then fs:SetFont(face, size or 14, flags) end
            end
        end
        headingRow:AddChild(heading)
        container:AddChild(headingRow)
        addDivider()

        local verticalSpacer = activeUI:Create("SimpleGroup")
        verticalSpacer:SetFullWidth(true)
        verticalSpacer:SetHeight(1)
        container:AddChild(verticalSpacer)
        centerRowsVertically(container, verticalSpacer)

        for i = 1, SKYRIDING_KEYBIND_ROW_COUNT do
            local slotIndex = i
            local row = activeUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetHeight(SKYRIDING_KEYBIND_ROW_HEIGHT)
            row:SetLayout("Flow")
            row:SetFlowGap(SKYRIDING_KEYBIND_ROW_GAP)
            row:SetFlowVAlign("CENTER")
            centerFlowContent(row, SKYRIDING_KEYBIND_ROW_WIDTH)

            local button = activeUI:Create("Button")
            button:SetText(GetSkyridingBindText(i))
            button:SetWidth(SKYRIDING_KEYBIND_BUTTON_WIDTH)
            button:SetHeight(20)
            button:SetCallback("OnClick", function(widget, mouseButton)
                if mouseButton == "RightButton" then
                    if GSE.isEmpty(GSEOptions.SkyRidingBinds) then GSEOptions.SkyRidingBinds = {} end
                    GSEOptions.SkyRidingBinds[tostring(slotIndex)] = nil
                    if GSE.UpdateVehicleBar then GSE.UpdateVehicleBar() end
                    -- Cancel capture and update text deferred so WoW flushes
                    -- the input event before we redraw the button label.
                    local function doCancel()
                        CancelSkyridingKeyCapture(widget)
                        local notBound = L["Not Bound"]
                        widget:SetText(notBound)
                        local frame = widget.frame or widget
                        if frame.SetText then frame:SetText(notBound) end
                    end
                    C_Timer.After(0, doCancel)
                else
                    StartSkyridingKeyCapture(widget, slotIndex)
                end
            end)
            row:AddChild(button)

            -- Icon column (centre): shows vehicle bar slot icon if mounted, placeholder otherwise
            local slotIcon = activeUI:Create("Icon")
            local function refreshSlotIcon()
                local tex = nil
                if HasVehicleActionBar and HasVehicleActionBar() then
                    local page = GetVehicleBarIndex and GetVehicleBarIndex() or 0
                    if page > 0 then
                        tex = GetActionTexture and GetActionTexture((page - 1) * 12 + slotIndex)
                    end
                end
                slotIcon:SetImage(tex or "")
            end
            refreshSlotIcon()
            slotIcon:SetImageSize(SKYRIDING_KEYBIND_ICON_COL, SKYRIDING_KEYBIND_ICON_COL)
            if slotIcon.SetHoverImageSize then slotIcon:SetHoverImageSize(SKYRIDING_KEYBIND_ICON_COL, SKYRIDING_KEYBIND_ICON_COL) end
            if slotIcon.SetHoverLocked then slotIcon:SetHoverLocked(true) end
            slotIcon.flowXOffset = 0
            slotIcon.flowYOffset = math.floor((SKYRIDING_KEYBIND_ROW_HEIGHT - SKYRIDING_KEYBIND_ICON_COL) / 2)
            row:AddChild(slotIcon)

            local label = activeUI:Create("Label")
            label:SetText(L["Skyriding Button"] .. " " .. i)
            label:SetWidth(SKYRIDING_KEYBIND_LABEL_WIDTH)
            label:SetHeight(28)
            label:SetJustifyH("LEFT")
            label:SetJustifyV("MIDDLE")
            label:SetColor(1, 0.82, 0, 1)
            row:AddChild(label)

            container:AddChild(row)
        end
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
        "onattributechanged",
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
