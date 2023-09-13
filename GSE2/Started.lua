local GSE2 = GSE2

function GSE2:OnInitialize()
    GSE2.GUIEditFrame:Hide()
    GSE2.GUIImportFrame:Hide()
end

if GSE.Patron then
    GSE2:RegisterChatCommand("gse2", "GSE2Slash")
    if not GSEOptions.HideLoginMessage then
        GSE.Print(L["GSE2 Retro Importer available."], "GSE2")
    end
end

function GSE2:GSE2Slash(input)
    local params = GSE.split(input, " ")
    if table.getn(params) > 1 then
        input = params[1]
    end
    local command = string.lower(input)
    if command == "edit" then
        GSE2.GUILoadEditor()
    else
        GSE2.GUIImportFrame:Show()
    end
end
