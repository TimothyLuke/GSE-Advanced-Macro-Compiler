local GSE = GSE
local Statics = GSE.Static
local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local exportframe = AceGUI:Create("Frame")
exportframe:Hide()
exportframe.classid = 0
exportframe.sequencename = ""
exportframe.frame:SetFrameStrata("MEDIUM")
exportframe.frame:SetClampedToScreen(true)
exportframe:SetTitle(L["GSE: Export"])
exportframe:SetStatusText(L["Export a Sequence"])
exportframe:SetCallback(
    "OnClose",
    function(widget)
        exportframe:Hide()
    end
)
exportframe:SetLayout("List")

local function compileExport(exportTable, humanReadable)
    local exportstring =
        GSE.EncodeMessage(
        {
            type = "COLLECTION",
            payload = exportTable
        }
    )

    if humanReadable then
        exportstring = "# UPDATE PACKAGE NAME \n ```\n" .. exportstring .. "\n```\n\n"
        exportstring = exportstring .. "This package consists of " .. exportTable.ElementCount .. " elements.\n"

        local sequenceString = ""
        for k, _ in pairs(exportTable.Sequences) do
            sequenceString = sequenceString .. "- " .. k .. "\n"
        end
        if string.len(sequenceString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Sequences"] .. "\n" .. sequenceString
        end

        local macroString = ""
        for k, _ in pairs(exportTable.Macros) do
            macroString = macroString .. "- " .. k .. "\n"
        end
        if string.len(macroString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Macros"] .. "\n" .. macroString
        end

        local variableString = ""
        for k, _ in pairs(exportTable.Variables) do
            variableString = variableString .. "- " .. k .. "\n"
        end
        if string.len(variableString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Variables"] .. "\n" .. variableString
        end
    end
    return exportstring
end

GSE.GUIAdvancedExport = function(exportframe)
    exportframe:ReleaseChildren()
    exportframe:SetStatusText(L["Advanced Export"])
    local exportTable = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {},
        ["ElementCount"] = 0
    }

    local HeaderRow = AceGUI:Create("SimpleGroup")
    HeaderRow:SetLayout("Flow")
    HeaderRow:SetFullWidth(true)
    local SequenceDropDown = AceGUI:Create("Dropdown")
    local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
    for k, v in GSE.pairsByKeys(GSE.GetSequenceNames(), GSE.AlphabeticalTableSortAlgorithm) do
        local elements = GSE.split(k, ",")
        local classid, specid = tonumber(elements[1]), tonumber(elements[2])
        if cid ~= classid then
            local val = GSE.GetClassName(classid) and GSE.GetClassName(classid) or L["Global"]
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
    for k, _ in pairs(GSESequences[0]) do
        SequenceDropDown:AddItem(k, k)
    end
    SequenceDropDown:SetMultiselect(true)
    SequenceDropDown:SetLabel(L["Sequences"])

    local VariableDropDown = AceGUI:Create("Dropdown")
    if not GSE.isEmpty(GSEVariables) then
        for k, _ in pairs(GSEVariables) do
            VariableDropDown:AddItem(k, k)
        end
    end

    local MacroDropDown = AceGUI:Create("Dropdown")

    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    for macid = 1, maxmacros do
        local mname, _, _ = GetMacroInfo(macid)
        if mname then
            MacroDropDown:AddItem(mname, mname)
        end
    end
    MacroDropDown:SetMultiselect(true)
    MacroDropDown:SetLabel(L["Macros"])

    HeaderRow:AddChild(SequenceDropDown)
    HeaderRow:AddChild(MacroDropDown)
    HeaderRow:AddChild(VariableDropDown)
    exportframe:AddChild(HeaderRow)

    local humanexportcheckbox = AceGUI:Create("CheckBox")
    humanexportcheckbox:SetType("checkbox")

    humanexportcheckbox:SetLabel(L["Create Human Readable Export"])
    exportframe:AddChild(humanexportcheckbox)

    humanexportcheckbox:SetValue(GSEOptions.DefaultHumanReadableExportFormat)

    local exportsequencebox = AceGUI:Create("MultiLineEditBox")
    exportsequencebox:SetLabel(L["Variable"])
    exportsequencebox:SetNumLines(22)
    exportsequencebox:DisableButton(true)
    exportsequencebox:SetFullWidth(true)
    exportframe:AddChild(exportsequencebox)

    VariableDropDown:SetMultiselect(true)
    VariableDropDown:SetLabel(L["Variables"])
    VariableDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local localsuccess, uncompressedVersion = GSE.DecodeMessage(GSEVariables[key])
                uncompressedVersion.objectType = "VARIABLE"
                uncompressedVersion.name = key
                exportTable["Variables"][key] = GSE.EncodeMessage(uncompressedVersion)
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Variables"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    SequenceDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                print(key)
                exportTable["Sequences"][key] =
                    GSE.UnEscapeTable(
                    GSE.TranslateSequence(GSE.CloneSequence(GSE.FindSequence(key)), Statics.TranslatorMode.ID)
                )
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Sequences"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    MacroDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local category = "a"
                local source = GSEMacros[key]
                if GSE.isEmpty(source) then
                    local char, realm = UnitFullName("player")
                    if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
                        GSEMacros[char .. "-" .. realm] = {}
                    end
                    if GSE.isEmpty(GSEMacros[char .. "-" .. realm][key]) then
                        -- need to find the macro as its not managed by GSE
                        source = {}
                        local mslot = GetMacroIndexByName(key)
                        local _, micon, mbody = GetMacroInfo(mslot)
                        source.name = key
                        source.icon = micon
                        source.text = mbody
                        source.managedMacro = GSE.CompileMacroText(mbody, Statics.TranslatorMode.ID)
                        if mslot > MAX_ACCOUNT_MACROS then
                            category = "p"
                        end
                        print("made new")
                    else
                        source = GSEMacros[char .. "-" .. realm][key]
                        category = "p"
                    end
                end
                local exportobject = GSE.CloneSequence(source)
                exportobject.objectType = "MACRO"
                exportobject.category = category
                exportobject.name = key
                exportTable["Macros"][key] = exportobject
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Macros"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
    humanexportcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
        end
    )
end


function GSE.GUIExport(category, objectname, type)
    local _, _, _, tocversion = GetBuildInfo()
    GSE.GUIExportframe.classid = category
    GSE.GUIAdvancedExport(exportframe)
    GSE.GUIExportframe:Show()
end
