local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

-- Forward declaration so drawAction can be called recursively from renderers.
local drawAction

-- ─── Per-action-type renderers ───────────────────────────────────────────────

local function renderPause(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    local block = AceGUI:Create("InlineGroup")

    block:SetLayout("List")
    block:SetFullWidth(true)
    local linegroup1 = AceGUI:Create("SimpleGroup")

    linegroup1:SetLayout("Flow")
    linegroup1:SetFullWidth(true)

    local clicksdropdown = AceGUI:Create("Dropdown")
    clicksdropdown:SetLabel(L["Measure"])
    clicksdropdown:SetRelativeWidth(0.24)
    local clickdroplist = {
        [L["Clicks"]] = L["How many macro Clicks to pause for?"],
        [L["Milliseconds"]] = L["How many milliseconds to pause for?"],
        ["GCD"] = L["Pause for the GCD."]
    }
    for k, _ in pairs(editframe.numericFunctions) do
        clickdroplist[k] = L["Local Function: "] .. k
    end
    clicksdropdown:SetList(clickdroplist)
    clicksdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Pause"],
                L[
                    "A pause can be measured in either clicks or seconds.  It will either wait 5 clicks or 1.5 seconds.\nIf using seconds, you can also wait for the GCD by entering ~~GCD~~ into the box."
                ],
                editframe
            )
        end
    )
    if not GSE.isEmpty(action.Variable) then
        if action.Variable == "GCD" then
            clicksdropdown:SetValue(action.Variable)
        elseif not GSE.isEmpty(editframe.numericFunctions[action.Variable]) then
            clicksdropdown:SetValue(action.Variable)
        else
            action.Variable = nil
        end
    elseif GSE.isEmpty(action.MS) then
        clicksdropdown:SetValue(L["Clicks"])
    else
        clicksdropdown:SetValue(L["Milliseconds"])
        if action.MS == "~~GCD~~" or action.MS == "GCD" then
            clicksdropdown:SetValue("GCD")
            action.Variable = "GCD"
            action.MS = nil
        end
    end
    clicksdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    linegroup1:AddChild(clicksdropdown)
    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(5)
    linegroup1:AddChild(spacerlabel1)

    local msvalueeditbox = AceGUI:Create("EditBox")
    msvalueeditbox:SetLabel()

    msvalueeditbox:SetWidth(100)
    msvalueeditbox.editbox:SetNumeric(true)
    msvalueeditbox:DisableButton(true)
    local value = GSE.isEmpty(action.MS) and action.Clicks or action.MS
    if not GSE.isEmpty(action.Clicks) or GSE.isEmpty(action.MS) then
        msvalueeditbox:SetDisabled(false)
    else
        msvalueeditbox:SetDisabled(true)
    end
    msvalueeditbox:SetText(value)
    msvalueeditbox:SetCallback(
        "OnTextChanged",
        function(self, event, text)
            local returnAction = {}
            returnAction["Type"] = action.Type
            if clicksdropdown:GetValue() == L["Clicks"] then
                returnAction["Clicks"] = tonumber(text)
            else
                returnAction["MS"] = tonumber(text)
            end
            editframe.Sequence.Macros[version].Actions[keyPath] = returnAction
            editframe:SetStatusText(editframe.statusText)
        end
    )

    msvalueeditbox:SetCallback(
        "OnRelease",
        function(self, event, text)
            msvalueeditbox.editbox:SetNumeric(false)
        end
    )
    clicksdropdown:SetCallback(
        "OnValueChanged",
        function(self, event, text)
            local returnAction = {}
            returnAction["Type"] = action.Type
            if text == L["Clicks"] then
                returnAction["Clicks"] = tonumber(msvalueeditbox:GetText())
                msvalueeditbox:SetDisabled(false)
            elseif text == L["Milliseconds"] then
                returnAction["MS"] = tonumber(msvalueeditbox:GetText())
                msvalueeditbox:SetDisabled(false)
            else
                returnAction["Variable"] = text
                msvalueeditbox:SetDisabled(true)
            end

            editframe.Sequence.Macros[version].Actions[keyPath] = returnAction
        end
    )
    if clicksdropdown:GetValue() == L["Milliseconds"] or clicksdropdown:GetValue() == L["Clicks"] then
        msvalueeditbox:SetDisabled(false)
    else
        msvalueeditbox:SetDisabled(true)
    end
    linegroup1:AddChild(msvalueeditbox)

    block:AddChild(GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, linegroup1))
    block:AddChild(linegroup1)
    pcontainer:AddChild(block)
end

local function renderAction(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    local macroPanel = AceGUI:Create("InlineGroup")
    if GSE.isEmpty(action.type) then
        action.type = "macro"
        action.macro = ""
    end
    macroPanel:SetLayout("List")
    macroPanel:SetFullWidth(true)
    macroPanel:SetAutoAdjustHeight(true)

    local linegroup1 = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)

    macroPanel:AddChild(linegroup1)

    local compiledMacro = AceGUI:Create("Label")
    compiledMacro:SetFullHeight(true)

    local spellEditBox, macroeditbox =
        GSE.CreateSpellEditBox(action, version, keyPath, editframe.Sequence, compiledMacro, editframe.frame)

    local unitEditBox = AceGUI:Create("EditBox")
    unitEditBox:SetLabel(L["Unit Name"])

    unitEditBox:SetWidth(250)
    unitEditBox:DisableButton(true)
    unitEditBox:SetText(action.unit)
    unitEditBox:SetCallback(
        "OnTextChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].Actions[keyPath].unit = value
        end
    )
    unitEditBox:SetCallback(
        "OnEditFocusLost",
        function()
        end
    )
    local typegroup = AceGUI:Create("SimpleGroup")
    typegroup:SetFullWidth(true)
    typegroup:SetLayout("Flow")
    local actionicon = GSE.CreateIconControl(action, version, keyPath, editframe.Sequence, macroPanel.frame)
    typegroup:AddChild(actionicon)
    local spellradio = AceGUI:Create("CheckBox")
    spellradio:SetType("radio")
    spellradio:SetLabel(L["Spell"])
    spellradio:SetValue((action.type and action.type == "spell" or false))
    spellradio:SetWidth(70)
    local itemradio = AceGUI:Create("CheckBox")
    itemradio:SetType("radio")
    itemradio:SetLabel(L["Item"])
    itemradio:SetValue((action.type and action.type == "item" or false))
    itemradio:SetWidth(70)
    local macroradio = AceGUI:Create("CheckBox")
    macroradio:SetType("radio")
    macroradio:SetLabel(L["Macro"])
    macroradio:SetValue((action.type and action.type == "macro" or false))
    macroradio:SetWidth(70)
    local petradio = AceGUI:Create("CheckBox")
    petradio:SetType("radio")
    petradio:SetLabel(L["Pet"])
    petradio:SetValue((action.type and action.type == "pet" or false))
    petradio:SetWidth(70)
    local toyradio = AceGUI:Create("CheckBox")
    toyradio:SetType("radio")
    toyradio:SetLabel(L["Toy"])
    toyradio:SetValue((action.type and action.type == "toy" or false))
    toyradio:SetWidth(70)
    typegroup:AddChild(macroradio)
    typegroup:AddChild(spellradio)
    typegroup:AddChild(itemradio)
    typegroup:AddChild(petradio)
    typegroup:AddChild(toyradio)

    local spellcontainer = AceGUI:Create("SimpleGroup")
    spellcontainer:SetLayout("List")
    spellcontainer:SetFullWidth(true)

    spellradio:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                itemradio:SetValue(false)
                macroradio:SetValue(false)
                toyradio:SetValue(false)
                petradio:SetValue(false)
                action.spell = spellEditBox:GetText()
                action.macro = nil
                action.item = nil
                action.toy = nil
                action.action = nil
                action.type = "spell"
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        end
    )
    itemradio:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                spellradio:SetValue(false)
                macroradio:SetValue(false)
                toyradio:SetValue(false)
                petradio:SetValue(false)
                action.spell = nil
                action.macro = nil
                action.item = spellEditBox:GetText()
                action.toy = nil
                action.action = nil
                action.type = "item"
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        end
    )
    petradio:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                spellradio:SetValue(false)
                macroradio:SetValue(false)
                toyradio:SetValue(false)
                itemradio:SetValue(false)
                action.spell = nil
                action.macro = nil
                action.item = nil
                action.action = spellEditBox:GetText()
                action.toy = nil
                action.type = "pet"
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        end
    )
    toyradio:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                spellradio:SetValue(false)
                macroradio:SetValue(false)
                itemradio:SetValue(false)
                petradio:SetValue(false)
                action.spell = nil
                action.macro = nil
                action.item = nil
                action.action = nil
                action.toy = spellEditBox:GetText()
                action.type = "toy"
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        end
    )
    macroradio:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                spellradio:SetValue(false)
                toyradio:SetValue(false)
                itemradio:SetValue(false)
                petradio:SetValue(false)
                action.spell = nil
                action.macro = macroeditbox:GetText()
                action.item = nil
                action.action = nil
                action.toy = nil
                action.unit = nil
                action.type = "macro"
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        end
    )

    spellcontainer:AddChild(typegroup)
    if action.type == "macro" then
        local macrolayout = AceGUI:Create("SimpleGroup")
        macrolayout:SetLayout("Flow")
        macrolayout:SetFullWidth(true)
        local compiledmacrotext =
            GSE.UnEscapeString(GSE.CompileMacroText(action.macro, Statics.TranslatorMode.String))
        local lenMacro = string.len(compiledmacrotext)
        local charcount
        if lenMacro > 255 then
            charcount =
                string.format(
                GSEOptions.UNKNOWN .. L["%s/255 Characters Used"] .. Statics.StringReset,
                lenMacro
            )
        else
            charcount = string.format(L["%s/255 Characters Used"], lenMacro)
        end
        compiledmacrotext = compiledmacrotext .. "\n\n" .. charcount

        compiledMacro:SetText(compiledmacrotext)
        compiledMacro.label:SetNonSpaceWrap(true)
        compiledMacro:SetRelativeWidth(0.45)

        local spacerm = AceGUI:Create("Label")
        spacerm:SetRelativeWidth(0.03)
        macrolayout:AddChild(macroeditbox)
        macrolayout:AddChild(spacerm)
        macrolayout:AddChild(compiledMacro)

        spellcontainer:AddChild(macrolayout)
    else
        local editcontainer = AceGUI:Create("SimpleGroup")
        editcontainer:SetLayout("Flow")
        editcontainer:SetFullWidth(true)
        editcontainer:AddChild(spellEditBox)
        editcontainer:AddChild(unitEditBox)
        spellcontainer:AddChild(editcontainer)
    end

    macroPanel:AddChild(spellcontainer)
    local typerow = AceGUI:Create("SimpleGroup")
    typerow:SetLayout("Flow")
    typerow:SetFullWidth(true)
    local actiontype = AceGUI:Create("CheckBox")
    actiontype:SetType("checkbox")
    actiontype:SetLabel(L["Repeat"])
    actiontype:SetValue(action.Type == Statics.Actions.Repeat and true or false)
    actiontype:SetWidth(70)

    local interval = AceGUI:Create("EditBox")
    interval:SetWidth(30)
    interval:SetText(action.Interval and action.Interval or 3)
    interval:SetDisabled(action.Type == Statics.Actions.Action and true or false)
    interval:DisableButton(true)
    interval.editbox:SetNumeric(true)
    interval:SetCallback(
        "OnRelease",
        function(self, event, text)
            interval.editbox:SetNumeric(false)
        end
    )
    interval:SetCallback(
        "OnTextChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].Actions[keyPath].Interval = value
        end
    )
    actiontype:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            if value == true then
                editframe.Sequence.Macros[version].Actions[keyPath].Type = Statics.Actions.Repeat
                interval:SetDisabled(false)
            else
                editframe.Sequence.Macros[version].Actions[keyPath].Type = Statics.Actions.Action
                interval:SetDisabled(true)
            end
        end
    )
    typerow:AddChild(actiontype)
    typerow:AddChild(interval)
    macroPanel:AddChild(typerow)
    pcontainer:AddChild(macroPanel)
end

local function renderLoop(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    local layout3 = AceGUI:Create("InlineGroup")
    layout3:SetFullWidth(true)
    layout3:SetLayout("List")
    local linegroup1 = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, layout3)

    local stepdropdown = AceGUI:Create("Dropdown")
    stepdropdown:SetLabel(L["Step Function"])
    stepdropdown:SetWidth(200)
    stepdropdown:SetList(
        {
            [Statics.Sequential] = L["Sequential (1 2 3 4)"],
            [Statics.Priority] = L["Priority List (1 12 123 1234)"],
            [Statics.ReversePriority] = L["Reverse Priority (1 21 321 4321)"],
            [Statics.Random] = L["Random - It will select .... a spell, any spell"]
        }
    )
    stepdropdown:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Step Function"],
                L[
                    "The step function determines how your macro executes.  Each time you click your macro GSE will go to the next line.  \nThe next line it chooses varies.  If Random then it will choose any line.  If Sequential it will go to the next line.  \nIf Priority it will try some spells more often than others."
                ],
                editframe
            )
        end
    )
    stepdropdown:SetValue(action.StepFunction)
    stepdropdown:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    stepdropdown:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].Actions[keyPath].StepFunction = value
        end
    )

    local looplimit = AceGUI:Create("EditBox")
    looplimit:SetLabel(L["Repeat"])
    looplimit:DisableButton(true)
    looplimit:SetMaxLetters(4)
    looplimit:SetWidth(100)

    if type(action.Repeat) ~= "number" or action.Repeat < 1 then
        action.Repeat = 1
    end
    looplimit:SetText(action.Repeat)
    looplimit:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(L["Repeat"], L["How many times does this action repeat"], editframe)
        end
    )
    looplimit:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )
    looplimit:SetCallback(
        "OnTextChanged",
        function(sel, object, value)
            value = tonumber(value)
            if type(value) == "number" and value > 0 then
                editframe.Sequence.Macros[version].Actions[keyPath].Repeat = value
            end
        end
    )

    local spacerlabel1 = AceGUI:Create("Label")
    spacerlabel1:SetWidth(15)
    linegroup1:AddChild(spacerlabel1)
    linegroup1:AddChild(stepdropdown)
    local spacerlabel2 = AceGUI:Create("Label")
    spacerlabel2:SetWidth(5)
    linegroup1:AddChild(spacerlabel2)
    linegroup1:AddChild(looplimit)

    layout3:AddChild(linegroup1)
    local macroGroup = AceGUI:Create("SimpleGroup")
    macroGroup:SetFullWidth(true)
    macroGroup:SetLayout("List")
    for key, act in ipairs(action) do
        local newKeyPath = {}
        for _, v in ipairs(keyPath) do
            table.insert(newKeyPath, v)
        end
        table.insert(newKeyPath, key)
        drawAction(editframe, macroGroup, act, version, newKeyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer)
    end

    layout3:AddChild(macroGroup)
    pcontainer:AddChild(layout3)
end

local function renderIf(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    local macroPanel = AceGUI:Create("InlineGroup")
    macroPanel:SetFullWidth(true)
    macroPanel:SetLayout("List")
    macroPanel:SetCallback(
        "OnRelease",
        function(self, obj, value)
            macroPanel.frame:SetBackdrop(nil)
        end
    )
    local linegroup1 = GetBlockToolbar(version, keyPath, treepath, false, hlabel, macroPanel)

    local booleanEditBox = AceGUI:Create("EditBox")
    booleanEditBox:SetLabel(L["Variable"])
    booleanEditBox:SetWidth(250)
    booleanEditBox:DisableButton(true)
    booleanEditBox:SetCallback(
        "OnEnter",
        function()
            GSE.CreateToolTip(
                L["Variable"],
                L["Enter the implementation link for this variable. Use '= true' or '= false' to test."],
                editframe
            )
        end
    )
    if not GSE.isEmpty(action.Variable) then
        booleanEditBox:SetText(action.Variable)
    else
        booleanEditBox:SetText("= true")
        action.Variable = "= true"
    end
    booleanEditBox:SetCallback(
        "OnLeave",
        function()
            GSE.ClearTooltip(editframe)
        end
    )

    booleanEditBox:SetCallback(
        "OnTextChanged",
        function(sel, object, value)
            editframe.Sequence.Macros[version].Actions[keyPath].Variable = value
            action.Variable = value
        end
    )
    if GSE.Patron then
        booleanEditBox.editbox:SetScript(
            "OnTabPressed",
            function(widget, button, down)
                MenuUtil.CreateContextMenu(
                    editframe.frame,
                    function(ownerRegion, rootDescription)
                        rootDescription:CreateTitle(L["Insert GSE Variable"])
                        for k, _ in pairs(GSEVariables) do
                            rootDescription:CreateButton(
                                k,
                                function()
                                    booleanEditBox:SetText([[=GSE.V["]] .. k .. [["]()]])
                                    editframe.Sequence.Macros[version].Actions[keyPath].Variable =
                                        [[=GSE.V["]] .. k .. [["]()]]
                                    action.Variable = [[=GSE.V["]] .. k .. [["]()]]
                                end
                            )
                        end
                        rootDescription:CreateTitle(L["Insert Test Case"])
                        rootDescription:CreateButton(
                            "True",
                            function()
                                booleanEditBox:SetText([[= true]])
                                editframe.Sequence.Macros[version].Actions[keyPath].Variable = [[= true]]
                                action.Variable = [[= true]]
                            end
                        )
                        rootDescription:CreateButton(
                            "False",
                            function()
                                booleanEditBox:SetText([[= false]])
                                editframe.Sequence.Macros[version].Actions[keyPath].Variable = [[= false]]
                                action.Variable = [[= true]]
                            end
                        )
                    end
                )
            end
        )
    end
    linegroup1:AddChild(booleanEditBox)

    local trueKeyPath = GSE.CloneSequence(keyPath)
    table.insert(trueKeyPath, 1)
    local trueGroup = AceGUI:Create("InlineGroup")
    trueGroup:SetFullWidth(true)
    trueGroup:SetLayout("List")

    local tlabel = AceGUI:Create("Label")
    tlabel:SetText("True")
    tlabel:SetFontObject(GameFontNormalLarge)
    tlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))

    local trueContainer = AceGUI:Create("SimpleGroup")
    trueContainer:SetLayout("Flow")
    trueContainer:SetFullWidth(true)

    local toolbar = GetBlockToolbar(version, trueKeyPath, treepath, true, tlabel, trueContainer, true, true, true)
    trueGroup:AddChild(toolbar)

    for key, act in ipairs(action[1]) do
        local newKeyPath = GSE.CloneSequence(trueKeyPath)
        table.insert(newKeyPath, key)
        drawAction(editframe, trueGroup, act, version, newKeyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer)
    end

    macroPanel:AddChild(linegroup1)

    trueContainer:AddChild(trueGroup)
    macroPanel:AddChild(trueContainer)

    local falseKeyPath = GSE.CloneSequence(keyPath)
    table.insert(falseKeyPath, 2)
    local falsegroup = AceGUI:Create("InlineGroup")
    falsegroup:SetFullWidth(true)
    falsegroup:SetLayout("List")

    local flabel = AceGUI:Create("Label")
    flabel:SetText("False")
    flabel:SetFontObject(GameFontNormalLarge)
    flabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
    local falsecontainer = AceGUI:Create("SimpleGroup")
    falsecontainer:SetFullWidth(true)
    falsecontainer:SetLayout("Flow")

    local toolbar2 = GetBlockToolbar(version, falseKeyPath, treepath, true, flabel, falsecontainer, true, true, true)
    falsegroup:AddChild(toolbar2)

    for key, act in ipairs(action[2]) do
        local newKeyPath = GSE.CloneSequence(falseKeyPath)
        table.insert(newKeyPath, key)
        drawAction(editframe, falsegroup, act, version, newKeyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer)
    end

    falsecontainer:AddChild(falsegroup)
    macroPanel:AddChild(falsecontainer)
    pcontainer:AddChild(macroPanel)
end

local function renderEmbed(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    local macroPanel = AceGUI:Create("InlineGroup")
    macroPanel:SetFullWidth(true)
    macroPanel:SetLayout("List")
    macroPanel:SetCallback(
        "OnRelease",
        function(self, obj, value)
            macroPanel.frame:SetBackdrop(nil)
        end
    )
    local linegroup1 = GetBlockToolbar(version, keyPath, treepath, includeAdd, hlabel, macroPanel)
    macroPanel:AddChild(linegroup1)
    local SequenceDropDown = AceGUI:Create("Dropdown")
    SequenceDropDown:SetFullWidth(true)

    local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
    for k, v in GSE.pairsByKeys(GSE.GetSequenceNames(), GSE.AlphabeticalTableSortAlgorithm) do
        if v ~= editframe.Sequence.MetaData.Name then
            local elements = GSE.split(k, ",")
            local classid, specid = tonumber(elements[1]), tonumber(elements[2])

            if cid ~= classid then
                local classinfo, classfile = GetClassInfo(cid)
                local val = C_ClassColor and WrapTextInColorCode(classinfo, C_ClassColor.GetClassColor(classfile):GenerateHexColor()) or L["Global"]
                local key = classid .. val

                SequenceDropDown:AddItem(key, val)
                SequenceDropDown:SetItemDisabled(key, true)
                cid = classid
            end
            if GetSpecializationInfoByID then
                if sid ~= specid and sid > 13 and specid > 13 then
                    local val = select(2, GetSpecializationInfoByID(specid))
                    local key = specid .. val

                    SequenceDropDown:AddItem(key, val)
                    SequenceDropDown:SetItemDisabled(key, true)
                    sid = specid
                end
            end
            SequenceDropDown:AddItem(v, v)
        end
    end
    for k, _ in pairs(GSESequences[0]) do
        SequenceDropDown:AddItem(k, k)
    end
    SequenceDropDown:SetMultiselect(false)
    SequenceDropDown:SetLabel(L["Sequence"])
    if action.Sequence then
        SequenceDropDown:SetValue(action.Sequence)
    end
    SequenceDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            editframe.Sequence.Macros[version].Actions[keyPath] = {
                ["Type"] = Statics.Actions.Embed,
                ["Sequence"] = key
            }
        end
    )


    macroPanel:AddChild(SequenceDropDown)
    pcontainer:AddChild(macroPanel)
end

-- ─── Dispatch table ──────────────────────────────────────────────────────────

local actionRenderers = {}
-- Populated after the renderer functions are defined above.
-- Note: Statics.Actions values are resolved at call time because Statics may
-- not yet be fully populated when this file is first parsed.

-- ─── drawAction (dispatcher) ─────────────────────────────────────────────────

-- The forward-declared local is assigned here.
drawAction = function(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer)
    -- Workaround for vanishing label ace3 bug
    local label = AceGUI:Create("Label")
    label:SetFontObject(GameFontNormalLarge)
    pcontainer:AddChild(label)

    local hlabel = AceGUI:Create("Label")
    hlabel:SetText(string.format(L["Block Type: %s"], Statics.Actions[action.Type]))
    hlabel:SetFontObject(GameFontNormalLarge)
    hlabel:SetColor(GSE.GUIGetColour(GSEOptions.KEYWORD))
    local includeAdd = true

    -- Build dispatch table lazily (first call) using the actual Statics values.
    if not actionRenderers[Statics.Actions.Pause] then
        actionRenderers[Statics.Actions.Pause]  = renderPause
        actionRenderers[Statics.Actions.Action] = renderAction
        actionRenderers[Statics.Actions.Repeat] = renderAction  -- same renderer handles both
        actionRenderers[Statics.Actions.Loop]   = renderLoop
        actionRenderers[Statics.Actions.If]     = renderIf
        actionRenderers[Statics.Actions.Embed]  = renderEmbed
    end

    local renderer = actionRenderers[action.Type]
    if renderer then
        renderer(editframe, pcontainer, action, version, keyPath, treepath, GetBlockToolbar, ChooseVersion, tcontainer, hlabel, includeAdd)
    end
end

-- ─── DrawSequenceEditor ──────────────────────────────────────────────────────

local function DrawSequenceEditor(editframe, tcontainer, version, path, ChooseVersion)
    local function GetBlockToolbar(
            version,
            path,
            treepath,
            includeAdd,
            headingLabel,
            container,
            disableMove,
            disableDelete,
            dontDeleteLastParent)
        local layoutcontainer = AceGUI:Create("SimpleGroup")

        local lastPath = path[#path]

        local parentPath = GSE.CloneSequence(path)
        local blocksThisLevel

        if #parentPath == 1 then
            blocksThisLevel = #editframe.Sequence.Macros[version].Actions
        else
            if GSE.isEmpty(dontDeleteLastParent) then
                parentPath[#parentPath] = nil
            end
            blocksThisLevel = #editframe.Sequence.Macros[version].Actions[parentPath]
        end
        layoutcontainer:SetLayout("Flow")
        layoutcontainer:SetFullWidth(true)
        layoutcontainer:SetHeight(30)
        local moveUpButton = AceGUI:Create("Icon")
        local moveDownButton = AceGUI:Create("Icon")

        if GSE.isEmpty(disableMove) then
            moveUpButton:SetImageSize(20, 20)
            moveUpButton:SetWidth(20)
            moveUpButton:SetHeight(20)
            moveUpButton:SetImage(Statics.ActionsIcons.Up)

            moveUpButton:SetCallback(
                "OnClick",
                function()
                    local original = GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                    local destinationPath = {}
                    for k, v in ipairs(path) do
                        if k == #path then
                            v = v - 1
                        end
                        table.insert(destinationPath, v)
                    end

                    editframe.Sequence.Macros[version].Actions[path] =
                        GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[destinationPath])
                    editframe.Sequence.Macros[version].Actions[destinationPath] = original
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            moveUpButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Move Up"], L["Move this block up one block."], editframe)
                end
            )
            moveUpButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            moveDownButton:SetImageSize(20, 20)
            moveDownButton:SetWidth(20)
            moveDownButton:SetHeight(20)
            moveDownButton:SetImage(Statics.ActionsIcons.Down)

            moveDownButton:SetCallback(
                "OnClick",
                function()
                    local original = GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                    local destinationPath = {}
                    for k, v in ipairs(path) do
                        if k == #path then
                            v = v + 1
                        end
                        table.insert(destinationPath, v)
                    end

                    editframe.Sequence.Macros[version].Actions[path] =
                        GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[destinationPath])
                    editframe.Sequence.Macros[version].Actions[destinationPath] = original
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            moveDownButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Move Down"], L["Move this block down one block."], editframe)
                end
            )
            moveDownButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )
        end

        local deleteBlockButton = AceGUI:Create("Icon")
        deleteBlockButton:SetImageSize(20, 20)
        deleteBlockButton:SetWidth(20)
        deleteBlockButton:SetHeight(20)
        deleteBlockButton:SetImage(Statics.ActionsIcons.Delete)

        deleteBlockButton:SetCallback(
            "OnClick",
            function()
                local delPath = {}
                local delObj
                for k, v in ipairs(path) do
                    if k == #path then
                        delObj = v
                    else
                        table.insert(delPath, v)
                    end
                end
                table.remove(editframe.Sequence.Macros[version].Actions[delPath], delObj)
                ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
            end
        )
        deleteBlockButton:SetCallback(
            "OnEnter",
            function()
                GSE.CreateToolTip(
                    L["Delete Block"],
                    L[
                        "Delete this Block from the sequence.  \nWARNING: If this is a loop this will delete all the blocks inside the loop as well."
                    ],
                    editframe
                )
            end
        )
        deleteBlockButton:SetCallback(
            "OnLeave",
            function()
                GSE.ClearTooltip(editframe)
            end
        )

        local addLoopButton = AceGUI:Create("Icon")
        local addActionButton = AceGUI:Create("Icon")
        local addPauseButton = AceGUI:Create("Icon")
        local addIfButton = AceGUI:Create("Icon")
        local addEmbedButton = AceGUI:Create("Icon")
        if includeAdd then
            addActionButton:SetImageSize(20, 20)
            addActionButton:SetWidth(20)
            addActionButton:SetHeight(20)
            addActionButton:SetImage(Statics.ActionsIcons.Action)

            addActionButton:SetCallback(
                "OnClick",
                function()
                    local newAction = {
                        ["macro"] = "Need Stuff Here",
                        ["type"] = "macro",
                        ["Type"] = Statics.Actions.Action
                    }
                    if #path > 1 then
                        table.insert(
                            editframe.Sequence.Macros[version].Actions[parentPath],
                            lastPath + 1,
                            newAction
                        )
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            addActionButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Add Action"], L["Add an Action Block."], editframe)
                end
            )
            addActionButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            addLoopButton:SetImageSize(20, 20)
            addLoopButton:SetWidth(20)
            addLoopButton:SetHeight(20)
            addLoopButton:SetImage(Statics.ActionsIcons.Loop)

            addLoopButton:SetCallback(
                "OnClick",
                function()
                    local newAction = {
                        [1] = {
                            ["macro"] = "Need Stuff Here",
                            ["type"] = "macro",
                            ["Type"] = Statics.Actions.Action
                        },
                        ["StepFunction"] = Statics.Sequential,
                        ["Type"] = Statics.Actions.Loop,
                        ["Repeat"] = 2
                    }

                    if #path > 1 then
                        table.insert(
                            editframe.Sequence.Macros[version].Actions[parentPath],
                            lastPath + 1,
                            newAction
                        )
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            addLoopButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Add Loop"], L["Add a Loop Block."], editframe)
                end
            )
            addLoopButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            addPauseButton:SetImageSize(20, 20)
            addPauseButton:SetWidth(20)
            addPauseButton:SetHeight(20)
            addPauseButton:SetImage(Statics.ActionsIcons.Pause)

            addPauseButton:SetCallback(
                "OnClick",
                function()
                    local newAction = {
                        ["Variable"] = "GCD",
                        ["Type"] = Statics.Actions.Pause
                    }
                    if #path > 1 then
                        table.insert(
                            editframe.Sequence.Macros[version].Actions[parentPath],
                            lastPath + 1,
                            newAction
                        )
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            addPauseButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(L["Add Pause"], L["Add a Pause Block."], editframe)
                end
            )
            addPauseButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            addIfButton:SetImageSize(20, 20)
            addIfButton:SetWidth(20)
            addIfButton:SetHeight(20)
            addIfButton:SetImage(Statics.ActionsIcons.If)

            addIfButton:SetCallback(
                "OnClick",
                function()
                    local newAction = {
                        [1] = {
                            {
                                ["macro"] = "Need True Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        [2] = {
                            {
                                ["macro"] = "Need False Stuff Here",
                                ["type"] = "macro",
                                ["Type"] = Statics.Actions.Action
                            }
                        },
                        ["Type"] = Statics.Actions.If
                    }
                    if #path > 1 then
                        table.insert(
                            editframe.Sequence.Macros[version].Actions[parentPath],
                            lastPath + 1,
                            newAction
                        )
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            addIfButton:SetCallback(
                "OnEnter",
                function()
                    if GSE.TableLength(editframe.booleanFunctions) > 0 then
                        GSE.CreateToolTip(
                            L["Add If"],
                            L[
                                "Add an If Block.  If Blocks allow you to shoose between blocks based on the result of a variable that returns a true or false value."
                            ],
                            editframe
                        )
                    else
                        GSE.CreateToolTip(
                            L["Add If"],
                            L[
                                "If Blocks require a variable that returns either true or false.  Create the variable first."
                            ],
                            editframe
                        )
                    end
                end
            )
            addIfButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            addEmbedButton:SetImageSize(20, 20)
            addEmbedButton:SetWidth(20)
            addEmbedButton:SetHeight(20)
            addEmbedButton:SetImage(Statics.ActionsIcons.Embed)

            addEmbedButton:SetCallback(
                "OnClick",
                function()
                    local newAction = {
                        ["Type"] = Statics.Actions.Embed
                    }
                    if #path > 1 then
                        table.insert(
                            editframe.Sequence.Macros[version].Actions[parentPath],
                            lastPath + 1,
                            newAction
                        )
                    else
                        table.insert(editframe.Sequence.Macros[version].Actions, lastPath + 1, newAction)
                    end
                    ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                end
            )
            addEmbedButton:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(
                        L["Add Embed"],
                        L[
                            "Add an Embed Block.  Embed Blocks allow you to incorporate another sequence into this sequence at the current block."
                        ],
                        editframe
                    )
                end
            )
            addEmbedButton:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )
        end

        if GSE.isEmpty(disableMove) then
            layoutcontainer:AddChild(moveUpButton)
            layoutcontainer:AddChild(moveDownButton)
            local spacerlabel1 = AceGUI:Create("Label")
            spacerlabel1:SetWidth(5)
            layoutcontainer:AddChild(spacerlabel1)
        end
        layoutcontainer:AddChild(headingLabel)
        if lastPath == 1 then
            moveUpButton:SetDisabled(true)
        elseif lastPath == blocksThisLevel then
            moveDownButton:SetDisabled(true)
        end
        if includeAdd then
            local spacerlabel2 = AceGUI:Create("Label")
            spacerlabel2:SetWidth(5)
            layoutcontainer:AddChild(spacerlabel2)
            layoutcontainer:AddChild(addActionButton)
            layoutcontainer:AddChild(addLoopButton)
            layoutcontainer:AddChild(addPauseButton)
            layoutcontainer:AddChild(addIfButton)
            layoutcontainer:AddChild(addEmbedButton)
        end
        local spacerlabel3 = AceGUI:Create("Label")
        spacerlabel3:SetWidth(30)
        layoutcontainer:AddChild(spacerlabel3)
        if GSE.isEmpty(disableMove) then
            local disableBlock = AceGUI:Create("CheckBox")
            disableBlock:SetType("checkbox")
            disableBlock:SetWidth(130)
            disableBlock:SetTriState(false)
            disableBlock:SetLabel(L["Disable Block"])
            layoutcontainer:AddChild(disableBlock)
            disableBlock:SetValue(editframe.Sequence.Macros[version].Actions[path].Disabled)
            local highlightTexture = container.frame:CreateTexture(nil, "BACKGROUND")
            highlightTexture:SetAllPoints(true)

            disableBlock:SetCallback(
                "OnValueChanged",
                function(sel, object, value)
                    editframe.Sequence.Macros[version].Actions[path].Disabled = value
                    if value == true then
                        highlightTexture:SetColorTexture(1, 0, 0, 0.15)
                    else
                        highlightTexture:SetColorTexture(1, 0, 0, 0)
                    end
                end
            )
            if editframe.Sequence.Macros[version].Actions[path].Disabled == true then
                highlightTexture:SetColorTexture(1, 0, 0, 0.15)
            else
                highlightTexture:SetColorTexture(1, 0, 0, 0)
            end

            container:SetCallback(
                "OnRelease",
                function(self, obj, value)
                    highlightTexture:SetColorTexture(0, 0, 0, 0)
                end
            )
            disableBlock:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(
                        L["Disable Block"],
                        L[
                            "Disable this block so that it is not executed. If this is a container block, like a loop, all the blocks within it will also be disabled."
                        ],
                        editframe
                    )
                end
            )
            disableBlock:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )
        end
        local spacerlabel4 = AceGUI:Create("Label")
        spacerlabel4:SetWidth(15)
        layoutcontainer:AddChild(spacerlabel4)
        if not disableDelete then
            layoutcontainer:AddChild(deleteBlockButton)
        end
        local spacerlabel5 = AceGUI:Create("Label")
        spacerlabel5:SetWidth(15)
        layoutcontainer:AddChild(spacerlabel5)

        local textpath = GSE.SafeConcat(path, ".")
        local patheditbox = AceGUI:Create("EditBox")
        if GSE.isEmpty(disableMove) then
            patheditbox:SetLabel(L["Block Path"])
            patheditbox:SetWidth(80)
            patheditbox:SetCallback(
                "OnEnterPressed",
                function(obj, event, key)
                    if not editframe.reloading then
                        local destinationPath = GSE.split(key, ".")
                        for k, v in ipairs(destinationPath) do
                            destinationPath[k] = tonumber(v)
                        end
                        local testpath = GSE.CloneSequence(destinationPath)
                        table.remove(testpath, #testpath)
                        local sourcepath = GSE.CloneSequence(path)
                        for k, v in ipairs(sourcepath) do
                            sourcepath[k] = tonumber(v)
                        end
                        table.remove(sourcepath, #sourcepath)
                        if #testpath > 0 then
                            -- check that the path exists
                            if
                                GSE.isEmpty(editframe.Sequence.Macros[version].Actions[testpath]) or
                                    type(editframe.Sequence.Macros[version].Actions[testpath]) ~= "table"
                                then
                                GSE.Print(L["Error: Destination path not found."])
                                return
                            end
                        end

                        if #sourcepath > 0 then
                            -- check that the path exists  If this has happened we have a big problem
                            if
                                GSE.isEmpty(editframe.Sequence.Macros[version].Actions[sourcepath]) or
                                    type(editframe.Sequence.Macros[version].Actions[sourcepath]) ~= "table"
                                then
                                GSE.Print(L["Error: Source path not found."])
                                return
                            end
                        end

                        if string.sub(key, 1, string.len(textpath)) == textpath then
                            GSE.Print(L["Error: You cannot move a container to be a child within itself."])
                            return
                        end

                        local insertActions =
                            GSE.CloneSequence(editframe.Sequence.Macros[version].Actions[path])
                        local endPoint = tonumber(destinationPath[#destinationPath])

                        local pathPoint = tonumber(path[#path])

                        if #sourcepath > 0 then
                            table.remove(editframe.Sequence.Macros[version].Actions[sourcepath], pathPoint)
                        else
                            table.remove(editframe.Sequence.Macros[version].Actions, pathPoint)
                        end
                        if #testpath > 0 then
                            if endPoint > #testpath + 1 then
                                endPoint = #testpath + 1
                            end
                            table.insert(
                                editframe.Sequence.Macros[version].Actions[testpath],
                                endPoint,
                                insertActions
                            )
                        else
                            if endPoint > #editframe.Sequence.Macros[version].Actions + 1 then
                                endPoint = #editframe.Sequence.Macros[version].Actions + 1
                            end
                            table.insert(editframe.Sequence.Macros[version].Actions, endPoint, insertActions)
                        end
                        ChooseVersion(tcontainer, version, editframe.scrollStatus.scrollvalue, treepath)
                    end
                end
            )
            patheditbox:SetCallback(
                "OnEnter",
                function()
                    GSE.CreateToolTip(
                        L["Block Path"],
                        L[
                            "The block path shows the direct location of a block.  This can be edited to move a block to a different position quickly.  Each block is prefixed by its container.\nEG 2.3 means that the block is the third block in a container at level 2.  You can move a block into a container block by specifying the parent block.  You need to press the Okay button to move the block."
                        ],
                        editframe
                    )
                end
            )
            patheditbox:SetCallback(
                "OnLeave",
                function()
                    GSE.ClearTooltip(editframe)
                end
            )

            patheditbox:DisableButton(true)

            patheditbox:SetText(textpath)
            layoutcontainer:AddChild(patheditbox)
        end
        return layoutcontainer
    end

    if GSE.isEmpty(editframe.Sequence.Macros[version].Actions) then
        editframe.Sequence.Macros[version].Actions = {
            [1] = {
                ["macro"] = "Need Macro Here",
                ["Type"] = Statics.Actions.Action
            }
        }
    end

    local macro = editframe.Sequence.Macros[version].Actions

    local font = CreateFont("seqPanelFont")
    font:SetFontObject(GameFontNormal)
    font:SetJustifyV("BOTTOM")

    for key, action in ipairs(macro) do
        local macroPanel = AceGUI:Create("SimpleGroup")
        macroPanel:SetFullWidth(true)
        macroPanel:SetLayout("List")
        local keyPath = {
            [1] = key
        }
        drawAction(editframe, macroPanel, action, version, keyPath, path, GetBlockToolbar, ChooseVersion, tcontainer)

        tcontainer:AddChild(macroPanel)
    end
end

function GSE.GUI.SetupActions(editframe, ChooseVersion)
    editframe.DrawSequenceEditor = function(container, version, path)
        DrawSequenceEditor(editframe, container, version, path, ChooseVersion)
    end
end
