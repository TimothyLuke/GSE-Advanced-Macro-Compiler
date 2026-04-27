local GSE = GSE

local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local L = GSE.L

local playerSpells = {}

function GSE.PlayerSpellsLoaded()
    return #playerSpells > 0
end

if GSE.GameMode > 10 then
    local function loadPlayerSpells()
        table.wipe(playerSpells)

        for tab = 2, C_SpellBook.GetNumSpellBookSkillLines() do
            local lineinfo = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if not lineinfo then break end  -- <-- add this line

            local offset = lineinfo.itemIndexOffset

            -- Items in this skill line are at indices [offset+1 .. offset+N].
            -- The previous `for i = 0, N do` ran N+1 times and started at
            -- index `offset` — the last item of the prior skill line, or 0.
            for i = 1, lineinfo.numSpellBookItems do
                local spellinfo = C_SpellBook.GetSpellBookItemInfo(i + offset, 0)
                if spellinfo then  -- <-- also guard this
                    local spellName = spellinfo.name
                    local offspec = spellinfo.isOffSpec
                    local passive = spellinfo.isPassive
                    if not passive and not offspec and spellName then
                        table.insert(playerSpells, spellName)
                    end
                end
            end
        end
        table.sort(playerSpells)
    end

    AceEvent:RegisterEvent("SPELLS_CHANGED", loadPlayerSpells)
    AceEvent:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", loadPlayerSpells)
    AceEvent:RegisterEvent("TRAIT_CONFIG_UPDATED", loadPlayerSpells)
    AceEvent:RegisterEvent("PLAYER_TALENT_UPDATE", loadPlayerSpells)

    GSE.CreateSpellEditBox = function(action, version, keyPath, sequence, compiledMacro, frame)
        if GSE.isEmpty(action.type) then
            action.type = "spell"
        end

        local spellEditBox = AceGUI:Create("EditBox")

        spellEditBox:SetWidth(250)
        spellEditBox:DisableButton(true)
        if #playerSpells < 1 then
            loadPlayerSpells()
        end
        if GSE.isEmpty(sequence.Versions[version].Actions[keyPath].type) then
            sequence.Versions[version].Actions[keyPath].type = "spell"
        end
        if GSE.isEmpty(action.type) then
            action.type = "spell"
        end

        local spelltext

        if action.toy then
            spelltext = action.toy
            spellEditBox:SetLabel(L["Toy"])
        elseif action.item then
            spelltext = action.item
            spellEditBox:SetLabel(L["Item"])
        elseif action.macro then
            if string.sub(GSE.UnEscapeString(action.macro), 1, 1) == "/" then
                spelltext = GSE.CompileMacroText(action.macro, Statics.TranslatorMode.Current)
            else
                spelltext = GSE.UnEscapeString(action.macro)
            end
        elseif action.action then
            spellEditBox:SetLabel(L["Pet Ability"])
            spelltext = action.action
        else
            spellEditBox:SetLabel(L["Spell"])
            local translatedSpell = GSE.GetSpellId(action.spell, Statics.TranslatorMode.Current)
            if translatedSpell then
                spelltext = translatedSpell
            else
                spelltext = action.spell
            end
        end

        spellEditBox:SetText(spelltext)
        --local compiledAction = GSE.CompileAction(action, sequence.Versions[version])
        spellEditBox:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                if sequence.Versions[version].Actions[keyPath].type == "pet" then
                    sequence.Versions[version].Actions[keyPath].action = value
                    sequence.Versions[version].Actions[keyPath].spell = nil
                    sequence.Versions[version].Actions[keyPath].macro = nil
                    sequence.Versions[version].Actions[keyPath].item = nil
                    sequence.Versions[version].Actions[keyPath].toy = nil
                elseif sequence.Versions[version].Actions[keyPath].type == "item" then
                    sequence.Versions[version].Actions[keyPath].item = value
                    sequence.Versions[version].Actions[keyPath].spell = nil
                    sequence.Versions[version].Actions[keyPath].action = nil
                    sequence.Versions[version].Actions[keyPath].macro = nil
                    sequence.Versions[version].Actions[keyPath].toy = nil
                elseif sequence.Versions[version].Actions[keyPath].type == "toy" then
                    sequence.Versions[version].Actions[keyPath].toy = value
                    sequence.Versions[version].Actions[keyPath].spell = nil
                    sequence.Versions[version].Actions[keyPath].action = nil
                    sequence.Versions[version].Actions[keyPath].macro = nil
                    sequence.Versions[version].Actions[keyPath].item = nil
                else
                    local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                    if storedValue then
                        sequence.Versions[version].Actions[keyPath].spell = storedValue
                    else
                        sequence.Versions[version].Actions[keyPath].spell = value
                    end
                    sequence.Versions[version].Actions[keyPath].action = nil
                    sequence.Versions[version].Actions[keyPath].macro = nil
                    sequence.Versions[version].Actions[keyPath].item = nil
                    sequence.Versions[version].Actions[keyPath].toy = nil
                end

                --compiledAction = GSE.CompileAction(returnAction, sequence.Versions[version])
            end
        )
        spellEditBox:SetCallback(
            "OnEditFocusLost",
            function()
            end
        )

        local macroEditBox = AceGUI:Create("MultiLineEditBox")
        macroEditBox:SetLabel(L["Macro Name or Macro Commands"])
        macroEditBox:DisableButton(true)
        macroEditBox:SetNumLines(5)
        macroEditBox:SetRelativeWidth(0.5)
        macroEditBox:SetText(spelltext)
        macroEditBox:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                value = GSE.UnEscapeString(value)
                if string.sub(value, 1, 1) == "/" then
                    sequence.Versions[version].Actions[keyPath].macro =
                        GSE.CompileMacroText(value, Statics.TranslatorMode.ID)
                else
                    sequence.Versions[version].Actions[keyPath].macro = value
                end
                sequence.Versions[version].Actions[keyPath].spell = nil
                sequence.Versions[version].Actions[keyPath].action = nil
                sequence.Versions[version].Actions[keyPath].item = nil
                sequence.Versions[version].Actions[keyPath].toy = nil
                local compiledmacrotext =
                    GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
                local lenMacro = string.len(compiledmacrotext)
                compiledmacrotext = compiledmacrotext .. "\n\n" .. string.format(L["%s/255 Characters Used"], lenMacro)
                compiledMacro:SetText(compiledmacrotext)
            end
        )

        if GSE.Patron then
            spellEditBox.editbox:SetScript(
                "OnTabPressed",
                function(widget, button, down)
                    -- if button == "RightButton" then
                    MenuUtil.CreateContextMenu(
                        frame,
                        function(ownerRegion, rootDescription)
                            rootDescription:CreateTitle(L["Insert Spell"])
                            for _, v in pairs(playerSpells) do
                                rootDescription:CreateButton(
                                    v,
                                    function()
                                        spellEditBox:SetText(v)
                                        sequence.Versions[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        spellEditBox:SetText("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Versions[version].Actions[keyPath].spell =
                                            "\n" .. [[=GSE.V["]] .. k .. [["]()]]
                                    end
                                )
                            end
                        end
                    )
                end
            )

            macroEditBox.editBox:SetScript(
                "OnTabPressed",
                function(widget, button, down)
                    -- if button == "RightButton" then
                    MenuUtil.CreateContextMenu(
                        frame,
                        function(ownerRegion, rootDescription)
                            rootDescription:CreateTitle(L["Insert Spell"])
                            for _, v in pairs(playerSpells) do
                                rootDescription:CreateButton(
                                    v,
                                    function()
                                        macroEditBox.editBox:Insert(v)
                                        sequence.Versions[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        macroEditBox.editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Versions[version].Actions[keyPath].spell =
                                            "\n" .. [[=GSE.V["]] .. k .. [["]()]]
                                    end
                                )
                            end
                        end
                    )
                end
            )
        end

        return spellEditBox, macroEditBox
    end
end

-- Native WoW icon picker, owned by GSE.
--
-- Pattern lifted from Jaliborc/BagBrother config/panels/ruleEdit.lua —
-- the only public addon I found that successfully creates a STANDALONE
-- popup from IconSelectorPopupFrameTemplate (rather than borrowing
-- Blizzard's MacroPopupFrame, which is hard-coupled to MacroFrame and
-- silently does nothing when shown without it). Critical bits the
-- earlier "obvious" implementation missed:
--   * Explicit SetSize — the template's XML <Size> doesn't reliably
--     apply to a CreateFrame'd virtual template instance.
--   * Explicit SetPoint on `IconSelector` inside `BorderBox`. Without
--     this the icon grid has no anchor, so even though the popup is
--     "showing" you see nothing render.
--   * iconDataProvider + SetSelectionsDataProvider + SelectedCallback
--     wired ONCE at frame creation, not per-show. The template mixin
--     already provides GetIconByIndex/GetNumIcons/GetIndexOfIcon as
--     dataProvider proxies, so we don't redefine them.
--   * No OnShow / OnHide override needed — the template's own OnShow
--     handles event registration; we just position once.
local iconPickerCallback = nil
local iconPickerFrame = nil

local function buildIconPickerFrame()
    if iconPickerFrame then return iconPickerFrame end
    if not IconSelectorPopupFrameTemplateMixin then return nil end

    local f = CreateFrame("Frame", "GSE_IconSelectorPopupFrame", UIParent, "IconSelectorPopupFrameTemplate")
    f:Hide()
    f:SetFrameStrata("DIALOG")
    -- The template's instantiation adds its own anchor (TOPLEFT to UIParent),
    -- so a plain SetPoint("CENTER") gets queued AFTER it — GetPoint(1)
    -- returns TOPLEFT and the popup paints in the screen's top-left corner
    -- (behind addon trays, easy to miss). ClearAllPoints first, then anchor
    -- ourselves — same pattern Jaliborc/BagBrother uses.
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Strip the macro-name workflow Blizzard's template assumes — the
    -- name editbox, its header label, the "Currently Selected" preview
    -- on the right, and the Okay button itself are all geared toward
    -- creating/editing a named macro. We just want "click an icon →
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
    -- callback and hide. Cancel button still works normally — the user
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

    -- Cancel still works — clear pending callback so a later Show
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
    -- and throw on the first show after a /reload — when invoked from
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
    local skyOptions = Settings.RegisterVerticalLayoutSubcategory(
        Settings.GetCategory(GSE.MenuCategoryID),
        L["Skyriding / Vehicle Keybinds"]
    )

    do
        local layout = SettingsPanel:GetLayout(skyOptions)
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
            name = L["Skyriding / Vehicle Keybinds"],
            tooltip = L["Override bindings for Skyriding, Vehicle, Possess and Override Bars"],
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
            binding = L["Unassigned"]
        else
            local mods = ""
            if IsControlKeyDown() then mods = "CTRL-" .. mods end
            if IsAltKeyDown()     then mods = "ALT-"  .. mods end
            if IsShiftKeyDown()   then mods = "SHIFT-".. mods end
            binding = mods .. key
            if GSE.isEmpty(GSEOptions.SkyRidingBinds) then GSEOptions.SkyRidingBinds = {} end
            GSEOptions.SkyRidingBinds[tostring(slotIndex)] = binding
            GSE.UpdateVehicleBar()
        end
        self:SetText(binding)
        self:SetScript("OnKeyDown", nil)
        self:EnableKeyboard(false)
        self:SetPropagateKeyboardInput(true)
        -- keep initializer data in sync so button text is correct on panel re-open
        local init = slotInits[slotIndex]
        if init then
            local d = init:GetData()
            if d then d.buttonText = binding end
        end
    end

    for i = 1, 12 do
        local slotIndex = i
        do
            local layout = SettingsPanel:GetLayout(skyOptions)
            local init = CreateSettingsButtonInitializer(
                L["Skyriding Button"] .. " " .. i,
                (GSEOptions.SkyRidingBinds and GSEOptions.SkyRidingBinds[tostring(i)]) or L["Unassigned"],
                function(btnArg)
                    if not btnArg then return end
                    local btn = btnArg
                    btn.gseSlot = slotIndex
                    btn:SetText(L["Press a key..."])
                    btn:SetPropagateKeyboardInput(false)
                    btn:EnableKeyboard(true)
                    btn:SetScript("OnKeyDown", onKeyDown)
                end,
                "",
                false
            )
            slotInits[i] = init
            layout:AddInitializer(init)
        end
    end -- Hidden macro buttons that execute pet battle abilities, to click on them when the player -- enters a pet battle, with the binds assigned by the user in the vehicle binds panel
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
