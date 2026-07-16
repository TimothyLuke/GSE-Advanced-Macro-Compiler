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

-- Editor Tab-completion menus: press Tab in an editor field to insert a GSE
-- variable / test case (boolean field) or a variable / sequence (managed macro).
GSE.OnEditorBooleanTab = function(editBox, menuOwner, apply)
    editBox:SetScript("OnTabPressed", function()
        MenuUtil.CreateContextMenu(menuOwner, function(ownerRegion, rootDescription)
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
        MenuUtil.CreateContextMenu(menuOwner, function(ownerRegion, rootDescription)
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
