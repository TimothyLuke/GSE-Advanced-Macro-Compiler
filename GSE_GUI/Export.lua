local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

local exportframe = UI:Create("Frame")
local uncompressedVersion = nil
exportframe:SetSize(760, 560)
exportframe:Hide()
exportframe.classid = 0
exportframe.sequencename = ""
exportframe.frame:SetFrameStrata("MEDIUM")
exportframe.frame:SetClampedToScreen(true)
exportframe.frame:ClearAllPoints()
exportframe.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
        local pkgName = (exportframe and exportframe.packageName) or ""
        local pkgDate = (exportframe and exportframe.packageDate) or date("%m/%d/%Y/%H:%M")
        -- No name given -> fall back to the literal "UPDATE PACKAGE NAME"
        -- so the H1 line stays well-formed in either case.
        local nameForHeader = (pkgName ~= "" and pkgName) or "UPDATE PACKAGE NAME"
        local header = "# " .. nameForHeader .. "    Date: " .. pkgDate
        exportstring = header .. "\n```\n" .. exportstring .. "\n```\n\n"

        -- Sequence-export footer: only shown when at least one Sequence is in the package.
        if next(exportTable.Sequences) then
            local seen, authors = {}, {}
            for _, seq in pairs(exportTable.Sequences) do
                local a = seq and seq.MetaData and seq.MetaData.Author
                if type(a) == "string" then a = strtrim(a) else a = nil end
                if a and a ~= "" and not seen[a] then
                    seen[a] = true
                    table.insert(authors, a)
                end
            end
            local authorLine = table.concat(authors, ", ")
            if authorLine == "" then
                local pname = UnitName and UnitName("player") or nil
                authorLine = (pname and pname ~= "" and pname) or "[AUTHORNAME]"
            end
            exportstring = exportstring ..
                "## Note:\n" ..
                "**Unless otherwise stated RECOMMENDED Talents can be found at the links below:**\n" ..
                "Refer to: [Wowhead](https://www.wowhead.com/) | [Icy-Veins](https://www.icy-veins.com/) | " ..
                "[Archon](https://www.archon.gg/wow) | [MaxRoll](https://maxroll.gg/wow)\n\n" ..
                "Thank you,\n" .. authorLine .. "\n\n"
        end

        exportstring = exportstring .. "This package consists of " .. exportTable.ElementCount .. " elements.\n"

        local sequenceString = ""
        for k, _ in pairs(exportTable.Sequences) do
            sequenceString = sequenceString .. "- " .. k .. "\n"
        end
        if string.len(sequenceString) > 0 then
            exportstring = exportstring .. "\n## " .. L["Sequences"] .. "\n" .. sequenceString
        end

        local macroString = ""
        for k, _ in pairs(exportTable["Macros"]) do
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

local function isStoredMacroNode(node)
    return type(node) == "table" and (
        node.text ~= nil
        or node.value ~= nil
        or node.icon ~= nil
        or node.Managed ~= nil
        or node.managedMacro ~= nil
        or node.manageMacro ~= nil
    )
end

local function currentCharacterMacroBucket()
    local char, realm = UnitFullName("player")
    if GSE.isEmpty(realm) then
        realm = string.gsub(GetRealmName(), "%s*", "")
    end
    return char .. "-" .. realm
end

local function findStoredMacro(name)
    if GSE.isEmpty(GSEMacros) then return nil, "a" end
    if isStoredMacroNode(GSEMacros[name]) then
        return GSEMacros[name], "a"
    end

    local currentBucket = currentCharacterMacroBucket()
    if type(GSEMacros[currentBucket]) == "table" and isStoredMacroNode(GSEMacros[currentBucket][name]) then
        return GSEMacros[currentBucket][name], "p"
    end

    for _, bucket in pairs(GSEMacros) do
        if type(bucket) == "table" and isStoredMacroNode(bucket[name]) then
            return bucket[name], "p"
        end
    end

    return nil, "a"
end

GSE.GUIAdvancedExport = function(exportframe, objectname, exportCategory)
    exportframe:ReleaseChildren()
    exportframe:SetStatusText(L["Advanced Export"])
    local exportTable = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {},
        ["ElementCount"] = 0
    }

    local HeaderRow = UI:Create("SimpleGroup")
    HeaderRow:SetLayout("Flow")
    HeaderRow:SetFullWidth(true)
    local SequenceDropDown = UI:Create("Dropdown")
    local cid, sid = GSE.GetCurrentClassID(), GSE.GetCurrentSpecID()
    -- Sort sections alphabetically by class name (Death Knight first, Warrior last).
    -- Spec / sequence-name ordering preserved within each class.
    local seqEntries = {}
    for k, v in pairs(GSE.GetSequenceNames()) do
        local elements  = GSE.split(k, ",")
        local classid   = tonumber(elements[1]) or 0
        local specid    = tonumber(elements[2]) or 0
        local seqName   = elements[3] or ""
        local className = GSE.GetClassName(classid) or L["Global"] or ""
        table.insert(seqEntries, {
            v         = v,
            classid   = classid,
            specid    = specid,
            seqName   = seqName,
            className = className,
        })
    end
    table.sort(seqEntries, function(a, b)
        local an, bn = (a.className or ""):lower(), (b.className or ""):lower()
        if an ~= bn then return an < bn end
        if a.specid ~= b.specid then return a.specid < b.specid end
        return (a.seqName or ""):lower() < (b.seqName or ""):lower()
    end)
    for _, e in ipairs(seqEntries) do
        local classid, specid, v = e.classid, e.specid, e.v
        if cid ~= classid then
            local val = e.className
            local key = classid .. val

            SequenceDropDown:AddItem(key, val)
            SequenceDropDown:SetItemDisabled(key, true)
            cid = classid
        end
        if specid then
            if sid ~= specid and sid > 13 and specid > 13 then
                local val = select(2, GetSpecializationInfoByID(specid))
                local key = val and (specid .. val)

                if key then
                    SequenceDropDown:AddItem(key, val)
                    SequenceDropDown:SetItemDisabled(key, true)
                    sid = specid
                end
            end
        end
        local seqName = e.seqName
        GSE.EnsureSequenceLoaded(classid, seqName)
        local seqObj = GSE.Library[classid] and GSE.Library[classid][seqName]
        if not (seqObj and seqObj.MetaData and seqObj.MetaData.noExport) then
            SequenceDropDown:AddItem(v, v)
        end
    end
    for k, _ in pairs(GSESequences[0]) do
        GSE.EnsureSequenceLoaded(0, k)
        local globalSeq = GSE.Library[0] and GSE.Library[0][k]
        if not (globalSeq and globalSeq.MetaData and globalSeq.MetaData.noExport) then
            SequenceDropDown:AddItem(k, k)
        end
    end
    SequenceDropDown:SetMultiselect(true)
    SequenceDropDown:SetLabel(L["Sequences"])
    if SequenceDropDown.SetMaxVisibleItems then SequenceDropDown:SetMaxVisibleItems(20) end

    local VariableDropDown = UI:Create("Dropdown")
    if not GSE.isEmpty(GSEVariables) then
        local varOrder = {}
        for k, _ in pairs(GSEVariables) do
            local varOk, varDecoded = GSE.DecodeMessage(GSEVariables[k])
            if varOk and not (varDecoded and varDecoded.MetaData and varDecoded.MetaData.noExport) then
                table.insert(varOrder, k)
            end
        end
        table.sort(varOrder, function(a, b) return (a or ""):lower() < (b or ""):lower() end)
        for _, k in ipairs(varOrder) do
            VariableDropDown:AddItem(k, k)
        end
    end

    local MacroDropDown = UI:Create("Dropdown")

    local macroList, macroOrder = {}, {}
    local function addMacroName(name)
        if not GSE.isEmpty(name) and not macroList[name] then
            macroList[name] = name
            table.insert(macroOrder, name)
        end
    end

    local maxmacros = MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS + 2
    for macid = 1, maxmacros do
        local mname, _, _ = GetMacroInfo(macid)
        addMacroName(mname)
    end

    if not GSE.isEmpty(GSEMacros) then
        for k, v in pairs(GSEMacros) do
            if isStoredMacroNode(v) then
                addMacroName(k)
            end
        end

        for _, bucket in pairs(GSEMacros) do
            if type(bucket) == "table" and not isStoredMacroNode(bucket) then
                for k, v in pairs(bucket) do
                    if isStoredMacroNode(v) then
                        addMacroName(k)
                    end
                end
            end
        end
    end

    table.sort(macroOrder, function(a, b) return (a or ""):lower() < (b or ""):lower() end)
    for _, name in ipairs(macroOrder) do
        MacroDropDown:AddItem(name, name)
    end
    MacroDropDown:SetMultiselect(true)
    MacroDropDown:SetLabel(L["Macros"])
    if MacroDropDown.SetMaxVisibleItems then MacroDropDown:SetMaxVisibleItems(20) end

    SequenceDropDown:SetRelativeWidth(0.31)
    MacroDropDown:SetRelativeWidth(0.31)
    VariableDropDown:SetRelativeWidth(0.31)
    HeaderRow:AddChild(SequenceDropDown)
    HeaderRow:AddChild(MacroDropDown)
    HeaderRow:AddChild(VariableDropDown)
    exportframe:AddChild(HeaderRow)

    local humanexportcheckbox = UI:Create("CheckBox")
    humanexportcheckbox:SetType("checkbox")

    humanexportcheckbox:SetLabel(L["Create Human Readable Export"] .. " |cFF808080[markdown formating]|r")
    if humanexportcheckbox.SetFlowOffset then humanexportcheckbox:SetFlowOffset(10, 3) end
    exportframe:AddChild(humanexportcheckbox)

    humanexportcheckbox:SetValue(GSEOptions.DefaultHumanReadableExportFormat)

    local exportsequencebox = UI:Create("MultiLineEditBox")
    exportsequencebox:SetLabel(L["Variable"])
    exportsequencebox:SetNumLines(22)
    exportsequencebox:DisableButton(true)
    exportsequencebox:SetFullWidth(true)
    exportframe:AddChild(exportsequencebox)

    -- Live character counter above the Variable box's top-right corner.
    -- AceGUI puts the "Variable" label at top-left; we mirror it on the right
    -- with the current byte count of the export string.  HookScript on the
    -- underlying editbox catches both user typing and SetText() calls, so the
    -- four sites below (humanexportcheckbox, the dropdowns, etc.) don't need
    -- to call any update fn explicitly.
    --
    -- Colour thresholds match the Discord paste limits, since users often
    -- export GSE sequences to share via Discord:
    --   ≤2000  : grey, just the number
    --   2001+  : red number + "Over Discord- Normal Text Limit" note (regular Discord cap exceeded)
    --   4001+  : orange number + "Over Discord-Nitro Text Limit" note (Nitro cap exceeded)
    local charCountLabel = exportsequencebox.frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall")
    charCountLabel:SetPoint("TOPRIGHT", exportsequencebox.frame, "TOPRIGHT", -20, 0)
    -- Base white so embedded |cffRRGGBB...|r colour codes render true.
    charCountLabel:SetTextColor(1, 1, 1, 1)
    local function updateCharCount()
        local edit = exportsequencebox.editBox or exportsequencebox.editbox
        local text = (edit and edit.GetText) and edit:GetText() or ""
        local n = #text
        local display
        if n >= 4001 then
            display = string.format(
                "|cffb0b0b0Over Discord-Nitro Text Limit  |r|cffff8800%d|r", n)
        elseif n >= 2001 then
            display = string.format(
                "|cffb0b0b0Over Discord- Normal Text Limit  |r|cffff3030%d|r", n)
        else
            display = string.format("|cffd9d9d9%d|r", n)
        end
        charCountLabel:SetText(display)
    end
    do
        local edit = exportsequencebox.editBox or exportsequencebox.editbox
        if edit and edit.HookScript then
            edit:HookScript("OnTextChanged", updateCharCount)
        end
    end
    updateCharCount()  -- initial empty state

    -- Shared "focus + select all" helper. Used by the Copy button and by the
    -- Human Readable checkbox so toggling the checkbox also leaves the text
    -- ready for Ctrl+C. Deferred via C_Timer.After(0, ...) so WoW does not
    -- strip focus when the originating event finishes (DebugWindow.lua L4386).
    local function highlightAllExportText()
        local function focusAndSelect()
            local edit = exportsequencebox and (exportsequencebox.editBox or exportsequencebox.editbox)
            if not edit then return end
            edit:SetFocus()
            if edit.SetCursorPosition then edit:SetCursorPosition(0) end
            if edit.HighlightText then edit:HighlightText(0, -1) end
            if exportframe.SetStatusText then
                exportframe:SetStatusText("Text selected. Press Ctrl+C to Copy")
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, focusAndSelect)
        else
            focusAndSelect()
        end
    end

    -- One-shot highlight: fires the first time a dropdown populates the export
    -- box. Skips on subsequent toggles so the user can keep adding items without
    -- losing scroll/cursor position. Reset every time GUIAdvancedExport runs.
    local firstTextLoadHighlighted = false
    local function highlightOnFirstLoad()
        if firstTextLoadHighlighted then return end
        firstTextLoadHighlighted = true
        highlightAllExportText()
    end

    -- Defensive: any old Copy button (legacy field name) created in a previous
    -- session of this addon needs to disappear before the new Close button shows.
    if exportframe.copyButton and exportframe.copyButton.Hide then
        exportframe.copyButton:Hide()
        if exportframe.copyButton.SetScript then
            exportframe.copyButton:SetScript("OnClick", nil)
        end
    end

    -- Close button: centered at the bottom, same position the Copy button used.
    -- Click hides the export window (matches the X-button OnClose behaviour).
    local closeBtn = exportframe.bottomCloseButton
    if not closeBtn then
        closeBtn = CreateFrame("Button", nil, exportframe.frame, "UIPanelButtonTemplate")
        closeBtn:SetSize(90, 22)
        closeBtn:SetPoint("BOTTOM", exportframe.frame, "BOTTOM", 0, 14)
        closeBtn:SetText(L["Close"] or "Close")
        if GSE.StyleDebugTextButton then GSE.StyleDebugTextButton(closeBtn) end
        if closeBtn.SetFrameLevel and exportframe.frame.GetFrameLevel then
            closeBtn:SetFrameLevel((exportframe.frame:GetFrameLevel() or 0) + 5)
        end
        exportframe.bottomCloseButton = closeBtn
    end
    closeBtn:SetScript("OnClick", function()
        exportframe:Hide()
    end)
    closeBtn:Show()

    VariableDropDown:SetMultiselect(true)
    VariableDropDown:SetLabel(L["Variables"])
    VariableDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                uncompressedVersion.objectType = "VARIABLE"
                uncompressedVersion.name = key
                exportTable["Variables"][key] = GSE.EncodeMessage(uncompressedVersion)
                exportTable.ElementCount = exportTable.ElementCount + 1
            else
                exportTable["Variables"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
            highlightOnFirstLoad()
        end
    )
    SequenceDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local seq = GSE.FindSequence(key)
                exportTable["Sequences"][key] =
                    GSE.UnEscapeTable(
                    GSE.TranslateSequence(GSE.CloneSequence(seq), Statics.TranslatorMode.ID)
                )
                -- Stamp the current GSEVersion and checksum on the export clone only.
                -- The local copy (seq) is intentionally left unchanged.
                -- Updating GSEVersion on export prevents false "older version" warnings
                -- when re-importing sequences that were originally created in an earlier
                -- GSE build but have been running fine in the current one.
                local exportedSeq = exportTable["Sequences"][key]
                if exportedSeq and exportedSeq.MetaData then
                    exportedSeq.MetaData.GSEVersion = GSE.VersionNumber
                    if GSE.ComputeSequenceChecksum then
                        exportedSeq.MetaData.Checksum = GSE.ComputeSequenceChecksum(exportedSeq)
                    end
                end
                exportTable.ElementCount = exportTable.ElementCount + 1

                -- Auto-include transitive variable dependencies
                local deps = seq and seq.MetaData and seq.MetaData.Dependencies
                if deps and type(deps.Variables) == "table" and #deps.Variables > 0 then
                    local allDeps = GSE.GetTransitiveVariableDeps(deps.Variables)
                    local missing, included = {}, {}
                    for vname in pairs(allDeps) do
                        if not GSE.isEmpty(GSEVariables) and not GSE.isEmpty(GSEVariables[vname]) then
                            if not exportTable["Variables"][vname] then
                                local ok, decoded = GSE.DecodeMessage(GSEVariables[vname])
                                if ok and decoded then
                                    exportTable["Variables"][vname] = decoded
                                    exportTable.ElementCount = exportTable.ElementCount + 1
                                    table.insert(included, vname)
                                end
                            end
                        else
                            table.insert(missing, vname)
                        end
                    end
                    if #included > 0 then
                        table.sort(included)
                        GSE.Print(
                            string.format(
                                L["Auto-included %d variable(s) required by %s: %s"],
                                #included, key, table.concat(included, ", ")
                            )
                        )
                    end
                    if #missing > 0 then
                        table.sort(missing)
                        GSE.Print(
                            string.format(
                                L["WARNING: %s depends on variable(s) that do not exist and cannot be exported: %s"],
                                key, table.concat(missing, ", ")
                            ),
                            "Error"
                        )
                    end
                end

                -- Warn about missing embedded sequence dependencies
                if deps and type(deps.Sequences) == "table" and #deps.Sequences > 0 then
                    local missingSeqs = {}
                    for _, sname in ipairs(deps.Sequences) do
                        if not exportTable["Sequences"][sname] then
                            local found = false
                            for chkclass = 0, 13 do
                                if GSESequences[chkclass] and not GSE.isEmpty(GSESequences[chkclass][sname]) then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                table.insert(missingSeqs, sname)
                            else
                                GSE.Print(
                                    string.format(
                                        L["%s embeds sequence '%s' — add it to the export if needed."],
                                        key, sname
                                    )
                                )
                            end
                        end
                    end
                    if #missingSeqs > 0 then
                        table.sort(missingSeqs)
                        GSE.Print(
                            string.format(
                                L["WARNING: %s embeds sequence(s) that do not exist: %s"],
                                key, table.concat(missingSeqs, ", ")
                            ),
                            "Error"
                        )
                    end
                end
            else
                exportTable["Sequences"][key] = nil
                exportTable.ElementCount = exportTable.ElementCount - 1
            end
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
            highlightOnFirstLoad()
        end
    )
    MacroDropDown:SetCallback(
        "OnValueChanged",
        function(obj, event, key, checked)
            if checked then
                local source, category = findStoredMacro(key)
                if GSE.isEmpty(source) then
                    if GSE.isEmpty(GSEMacros) then
                        GSEMacros = {}
                    end
                    local currentBucket = currentCharacterMacroBucket()
                    if GSE.isEmpty(GSEMacros[currentBucket]) then
                        GSEMacros[currentBucket] = {}
                    end
                    if GSE.isEmpty(GSEMacros[currentBucket][key]) then
                        -- need to find the macro as its not managed by GSE
                        source = {}
                        local mslot = GetMacroIndexByName(key)
                        if not mslot or mslot == 0 then return end
                        local _, micon, mbody = GetMacroInfo(mslot)
                        source.name = key
                        source.icon = micon
                        source.text = mbody
                        source.managedMacro = GSE.CompileMacroText(mbody or "", Statics.TranslatorMode.ID)
                        if mslot > MAX_ACCOUNT_MACROS then
                            category = "p"
                        end
                    else
                        source = GSEMacros[currentBucket][key]
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
            highlightOnFirstLoad()
        end
    )
    humanexportcheckbox:SetCallback(
        "OnValueChanged",
        function(sel, object, value)
            exportsequencebox:SetText(compileExport(exportTable, humanexportcheckbox:GetValue()))
            highlightAllExportText()
        end
    )

    -- Pre-select the sequence / macro / variable the user was on when they opened
    -- Export (passed through from the editor tree node or the open sequence) so the
    -- window opens already populated with that object instead of an empty box. This
    -- mirrors a manual click on the matching dropdown item: SetValue() ticks it
    -- (shown as "1 Selected", and the dropdown list scrolls to it the first time it
    -- is opened) and Fire("OnValueChanged", ...) runs the exact same callback path
    -- that builds the export text. Skipped when no object was passed (e.g. the
    -- options-driven re-render from Utils.lua) or when the object is not a
    -- selectable item in its dropdown (e.g. a noExport sequence), so those paths
    -- keep the previous empty-window behaviour.
    if not GSE.isEmpty(objectname) then
        local preselectDropDown
        if exportCategory == "SEQUENCE" then
            preselectDropDown = SequenceDropDown
        elseif exportCategory == "MACRO" then
            preselectDropDown = MacroDropDown
        elseif exportCategory == "VARIABLE" then
            preselectDropDown = VariableDropDown
        end
        if preselectDropDown and preselectDropDown.list and preselectDropDown.list[objectname] ~= nil
            and not (preselectDropDown.disabledItems and preselectDropDown.disabledItems[objectname]) then
            preselectDropDown:SetValue(objectname, true)
            preselectDropDown:Fire("OnValueChanged", objectname, true)
        end
    end
end


function GSE.GUIExport(category, objectname, exportCategory)
    exportframe.classid = category
    local function openExportWindow(pkgName)
        exportframe.packageName = pkgName or ""
        exportframe.packageDate = date("%m/%d/%Y/%H:%M")
        exportframe:SetSize(760, 560)
        GSE.GUIAdvancedExport(exportframe, objectname, exportCategory)
        UI.MakePopup(exportframe.frame, {center = true})
        if exportframe.frame.Raise then exportframe.frame:Raise() end
        exportframe:Show()
    end
    GSE.UI.ShowInputDialog({
        title      = L["Export"],
        prompt     = L["Enter Export Package Name"],
        default    = "UPDATE PACKAGE NAME",
        acceptText = L["Export"],
        maxLetters = 80,
        onAccept   = function(name)
            local trimmed = name and name ~= "" and name or nil
            openExportWindow(trimmed)
        end,
    })
end

-- Register for GSE UI scale
if exportframe and exportframe.frame and GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(exportframe.frame)
end
end
table.insert(ns.deferred, setup)
