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
            local offset = lineinfo.itemIndexOffset

            for i = 0, lineinfo.numSpellBookItems do
                local spellinfo = C_SpellBook.GetSpellBookItemInfo(i + offset, 0)

                local spellName = spellinfo.name
                --local spellID = spellinfo.spellID
                local offspec = spellinfo.isOffSpec
                local passive = spellinfo.isPassive
                if not passive and not offspec and spellName then
                    table.insert(playerSpells, spellName)
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
        if GSE.isEmpty(sequence.Macros[version].Actions[keyPath].type) then
            sequence.Macros[version].Actions[keyPath].type = "spell"
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
        --local compiledAction = GSE.CompileAction(action, sequence.Macros[version])
        spellEditBox:SetCallback(
            "OnTextChanged",
            function(sel, object, value)
                if sequence.Macros[version].Actions[keyPath].type == "pet" then
                    sequence.Macros[version].Actions[keyPath].action = value
                    sequence.Macros[version].Actions[keyPath].spell = nil
                    sequence.Macros[version].Actions[keyPath].macro = nil
                    sequence.Macros[version].Actions[keyPath].item = nil
                    sequence.Macros[version].Actions[keyPath].toy = nil
                elseif sequence.Macros[version].Actions[keyPath].type == "item" then
                    sequence.Macros[version].Actions[keyPath].item = value
                    sequence.Macros[version].Actions[keyPath].spell = nil
                    sequence.Macros[version].Actions[keyPath].action = nil
                    sequence.Macros[version].Actions[keyPath].macro = nil
                    sequence.Macros[version].Actions[keyPath].toy = nil
                elseif sequence.Macros[version].Actions[keyPath].type == "toy" then
                    sequence.Macros[version].Actions[keyPath].toy = value
                    sequence.Macros[version].Actions[keyPath].spell = nil
                    sequence.Macros[version].Actions[keyPath].action = nil
                    sequence.Macros[version].Actions[keyPath].macro = nil
                    sequence.Macros[version].Actions[keyPath].item = nil
                else
                    local storedValue = GSE.GetSpellId(value, Statics.TranslatorMode.ID)
                    if storedValue then
                        sequence.Macros[version].Actions[keyPath].spell = storedValue
                    else
                        sequence.Macros[version].Actions[keyPath].spell = value
                    end
                    sequence.Macros[version].Actions[keyPath].action = nil
                    sequence.Macros[version].Actions[keyPath].macro = nil
                    sequence.Macros[version].Actions[keyPath].item = nil
                    sequence.Macros[version].Actions[keyPath].toy = nil
                end

                --compiledAction = GSE.CompileAction(returnAction, sequence.Macros[version])
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
                    sequence.Macros[version].Actions[keyPath].macro =
                        GSE.CompileMacroText(value, Statics.TranslatorMode.ID)
                else
                    sequence.Macros[version].Actions[keyPath].macro = value
                end
                sequence.Macros[version].Actions[keyPath].spell = nil
                sequence.Macros[version].Actions[keyPath].action = nil
                sequence.Macros[version].Actions[keyPath].item = nil
                sequence.Macros[version].Actions[keyPath].toy = nil
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
                                        sequence.Macros[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        spellEditBox:SetText("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Macros[version].Actions[keyPath].spell =
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
                                        sequence.Macros[version].Actions[keyPath].spell = v
                                    end
                                )
                            end

                            rootDescription:CreateTitle(L["Insert GSE Variable"])
                            for k, _ in pairs(GSEVariables) do
                                rootDescription:CreateButton(
                                    k,
                                    function()
                                        macroEditBox.editBox:Insert("\n" .. [[=GSE.V["]] .. k .. [["]()]])
                                        sequence.Macros[version].Actions[keyPath].spell =
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

function GSE.CreateIconControl(action, version, keyPath, sequence, frame)
    local lbl = AceGUI:Create("InteractiveLabel")
    lbl:SetFontObject(GameFontNormalLarge)
    lbl:SetWidth(25)
    lbl:SetHeight(25)

    if action.Icon then
        lbl:SetText("|T" .. action.Icon .. ":0|t")
    else
        local spellinfo = {}
        spellinfo.iconID = Statics.QuestionMarkIconID
        if action.type == "macro" then
            local macro = GSE.UnEscapeString(action.macro)
            if string.sub(macro, 1, 1) == "/" then
                local spellstuff = GSE.GetSpellsFromString(macro)
                if spellstuff and #spellstuff > 1 then
                    spellstuff = spellstuff[1]
                end
                if spellstuff then
                    spellinfo = spellstuff
                end
            else
                spellinfo.name = action.macro
                local macindex = GetMacroIndexByName(spellinfo.name)
                local _, iconid, _ = GetMacroInfo(macindex)
                spellinfo.iconID = iconid
            end
        elseif action.type == "Spell" then
            spellinfo = C_Spell.GetSpellInfo(action.spell)
        end
        if spellinfo.iconID then
            lbl:SetText("|T" .. spellinfo.iconID .. ":0|t")
        end
    end
    local spellinfolist = {}

    if action.type == "macro" then
        local macro = GSE.UnEscapeString(action.macro)
        if string.sub(macro, 1, 1) == "/" then
            local lines = GSE.SplitMeIntoLines(macro)
            for _, v in ipairs(lines) do
                local spellinfo = GSE.GetSpellsFromString(v)
                if spellinfo and #spellinfo > 1 then
                    for _, j in ipairs(spellinfo) do
                        if j and j.iconID then
                            table.insert(spellinfolist, j)
                        end
                    end
                else
                    if spellinfo and spellinfo.iconID then
                        table.insert(spellinfolist, spellinfo)
                    end
                end
            end
        else
            local spellinfo = {}
            spellinfo.name = action.macro
            local macindex = GetMacroIndexByName(spellinfo.name)
            local _, iconid, _ = GetMacroInfo(macindex)
            if macindex and iconid then
                spellinfo.iconID = iconid
                table.insert(spellinfolist, spellinfo)
            end
        end
    elseif action.type == "Spell" then
        local spellinfo = C_Spell.GetSpellInfo(action.spell)
        if spellinfo and spellinfo.iconID then
            table.insert(spellinfolist, spellinfo)
        end
    end

    lbl:SetCallback(
        "OnClick",
        function(widget, button)
            MenuUtil.CreateContextMenu(
                frame,
                function(ownerRegion, rootDescription)
                    rootDescription:CreateTitle(L["Select Icon"])
                    for _, v in pairs(spellinfolist) do
                        rootDescription:CreateButton(
                            "|T" .. v.iconID .. ":0|t " .. v.name,
                            function()
                                lbl:SetText("|T" .. v.iconID .. ":0|t")
                                sequence.Macros[version].Actions[keyPath].Icon = v.iconID
                            end
                        )
                    end
                end
            )
        end
    )
    return lbl
end

-- Skyriding Bind Bar for Retail
if GSE.GameMode >= 11 then
    local config = LibStub("AceConfig-3.0")
    local dialog = LibStub("AceConfigDialog-3.0")
    local addonName = "|cFFFFFFFFGS|r|cFF00FFFFE|r"
    local OptionsTable = {
        type = "group",
        args = {
            title = {
                name = L["Skyriding / Vehicle Keybinds"],
                desc = L["Override bindings for Skyriding, Vehicle, Possess and Override Bars"],
                order = 1,
                type = "header"
            }
        }
    }

    for i = 1, 12 do
        OptionsTable.args["Skyriding" .. tostring(i)] = {
            name = L["Skyriding Button"] .. " " .. tostring(i),
            type = "keybinding",
            set = function(info, val)
                if GSE.isEmpty(GSEOptions.SkyRidingBinds) then
                    GSEOptions.SkyRidingBinds = {}
                end
                GSEOptions.SkyRidingBinds[tostring(i)] = val
                GSE.UpdateVehicleBar()
            end,
            get = function(info)
                return GSEOptions.SkyRidingBinds and GSEOptions.SkyRidingBinds[tostring(i)] and
                    GSEOptions.SkyRidingBinds[tostring(i)] or
                    ""
            end,
            order = i + 1
        }
    end
    config:RegisterOptionsTable(addonName .. "-Skyriding", OptionsTable)
    dialog:AddToBlizOptions(addonName .. "-Skyriding", OptionsTable.args.title.name, GSE.MenuCategoryID) -- Hidden macro buttons that execute pet battle abilities, to click on them when the player -- enters a pet battle, with the binds assigned by the user in the vehicle binds panel
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

if GSE.GameMode > 10 then
    -- Shared handler: right-click on an empty action button shows the GSE sequence picker.
    -- Fires for standard Blizzard bars immediately, and for third-party bars after they load.
    local function gseEmptyButtonHandler(self, mousebutton, down)
        if not GSEOptions.actionBarOverridePopup then return end
        if InCombatLockdown() then return end
        if not down then return end
        if mousebutton ~= "RightButton" then return end
        if self:GetAttribute("gse-button") then return end   -- already has a GSE override
        -- Dominos stores action as a secure attribute only; other addons use self.action
        local action = self.action or self:GetAttribute("action")
        if not action or action == 0 then return end
        if HasAction(action) then return end                 -- slot is not empty

        local names = {}
        if GSESequences then
            for k, _ in pairs(GSESequences[GSE.GetCurrentClassID()] or {}) do
                table.insert(names, k)
            end
            for k, _ in pairs(GSESequences[0] or {}) do
                table.insert(names, k)
            end
        end
        if #names == 0 then return end
        table.sort(names)

        local buttonName = self:GetName()
        MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
            rootDescription:CreateTitle(L["Assign GSE Sequence"])
            for _, k in ipairs(names) do
                rootDescription:CreateButton(k, function()
                    GSE.CreateActionBarOverride(buttonName, k)
                end)
            end
        end)
    end

    -- Standard Blizzard action bars hook via the global function
    hooksecurefunc("ActionButton_OnClick", gseEmptyButtonHandler)

    -- Third-party action bar addons use their own OnClick handlers, so we install
    -- HookScript directly on each button after PLAYER_ENTERING_WORLD, by which
    -- point all addon frames are guaranteed to exist.
    local gseBarHookFrame = CreateFrame("Frame")
    gseBarHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    gseBarHookFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        if Bartender4 then
            for i = 1, 180 do
                local btn = _G["BT4Button" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
        end

        if ElvUI then
            for bar = 1, 15 do
                for slot = 1, 12 do
                    local btn = _G["ElvUI_Bar" .. bar .. "Button" .. slot]
                    if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
                end
            end
        end

        if NDui then
            for bar = 1, 15 do
                for slot = 1, 12 do
                    local btn = _G["NDui_ActionBar" .. bar .. "Button" .. slot]
                    if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
                end
            end
        end

        if Dominos then
            -- IDs 1-24 and 73-132 are Dominos-owned frames; the rest reuse Blizzard names
            -- already covered by the hooksecurefunc above.
            for i = 1, 24 do
                local btn = _G["DominosActionButton" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
            for i = 73, 132 do
                local btn = _G["DominosActionButton" .. i]
                if btn then btn:HookScript("OnClick", gseEmptyButtonHandler) end
            end
        end
    end)
end
