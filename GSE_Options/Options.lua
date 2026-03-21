local GNOME, _ = ...
local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

local function FormatSequenceNames(names)
    local returnstring = ""
    for _, v in ipairs(names) do
        returnstring = returnstring .. " - " .. v .. ",\n"
    end
    returnstring = returnstring:sub(1, -3)
    return returnstring
end

local addonName = "|cFFFFFFFFGS|r|cFF00FFFFE|r"

local registered = false

local function createAboutPanel()
    local panel = CreateFrame("Frame")
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true

        local padding = 20
        local pw = self:GetWidth()
        if pw < 100 then pw = 600 end

        -- ScrollFrame fills the panel, leaving room for the scrollbar
        local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -26, 0)

        local cw = pw - 26  -- content width (panel minus scrollbar)
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(cw)
        content:SetHeight(2000)  -- large enough; scroll handles overflow
        scrollFrame:SetScrollChild(content)

        -- Logo (top-left of content)
        local logo = content:CreateTexture(nil, "ARTWORK")
        logo:SetTexture(Statics.Icons.Logo)
        logo:SetSize(120, 120)
        logo:SetPoint("TOPLEFT", content, "TOPLEFT", padding, -padding)

        -- History header (right of logo, aligned to top)
        local histHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        histHeader:SetPoint("TOPLEFT", logo, "TOPRIGHT", padding, 0)
        histHeader:SetText(L["History"])

        -- About description text (beside logo)
        local textWidth = cw - 120 - padding * 3
        local aboutDesc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        aboutDesc:SetWidth(textWidth)
        aboutDesc:SetJustifyH("LEFT")
        aboutDesc:SetWordWrap(true)
        aboutDesc:SetPoint("TOPLEFT", histHeader, "BOTTOMLEFT", 0, -6)
        aboutDesc:SetText(L["GSE was originally forked from GnomeSequencer written by semlar.  It was enhanced by TImothyLuke to include a lot of configuration and boilerplate functionality with a GUI added.  The enhancements pushed the limits of what the original code could handle and was rewritten from scratch into GSE.\n\nGSE itself wouldn't be what it is without the efforts of the people who write sequences with it.  Check out https://discord.gg/gseunited for the things that make this mod work.  Special thanks to Lutechi for creating the original WowLazyMacros community."])

        -- Version (anchored below logo)
        local versionHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        versionHeader:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -padding)
        versionHeader:SetText(L["Version"])

        local versionText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        versionText:SetPoint("TOPLEFT", versionHeader, "BOTTOMLEFT", 0, -6)
        versionText:SetText("GSE: " .. GSE.VersionString)

        -- Link buttons row
        local linkData = {
            { name = L["GSE Discord"],     icon = Statics.Icons.Discord, url = "https://discord.gg/yUS9R4ZXZA" },
            { name = L["Report an Issue"], icon = Statics.Icons.Github,  url = "https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/issues" },
            { name = L["Support GSE"],     icon = Statics.Icons.Patreon, url = "https://www.patreon.com/TimothyLuke" },
        }
        local firstBtn, prevBtn = nil, nil
        for _, bdata in ipairs(linkData) do
            local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            btn:SetSize(170, 36)
            if prevBtn then
                btn:SetPoint("LEFT", prevBtn, "RIGHT", 12, 0)
            else
                btn:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -padding)
                firstBtn = btn
            end
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetTexture(bdata.icon)
            tex:SetSize(22, 22)
            tex:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn:SetText("  " .. bdata.name)
            local capturedUrl = bdata.url
            btn:SetScript("OnClick", function()
                StaticPopupDialogs["GSE_SEQUENCEHELP"].url = capturedUrl
                StaticPopup_Show("GSE_SEQUENCEHELP")
            end)
            prevBtn = btn
        end

        -- Supporters section (anchored to first button's bottom-left, not last)
        local supHeader = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        supHeader:SetPoint("TOPLEFT", firstBtn, "BOTTOMLEFT", 0, -padding)
        supHeader:SetText(L["Supporters"])

        local supDesc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        supDesc:SetWidth(cw - padding * 2)
        supDesc:SetJustifyH("LEFT")
        supDesc:SetWordWrap(true)
        supDesc:SetPoint("TOPLEFT", supHeader, "BOTTOMLEFT", 0, -8)
        supDesc:SetText(L["The following people donate monthly via Patreon for the ongoing maintenance and development of GSE.  Their support is greatly appreciated."])

        local patronList = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        patronList:SetWidth(cw - padding * 2)
        patronList:SetJustifyH("LEFT")
        patronList:SetWordWrap(true)
        patronList:SetPoint("TOPLEFT", supDesc, "BOTTOMLEFT", 0, -6)
        patronList:SetText(table.concat(Statics.Patrons, ", "))
    end)

    return panel
end

local function createBlizzOptions(category)

    -- Troubleshooting
    do
        local troubleOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Troubleshooting"])

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Spell Cache Editor"], tooltip = L["Common Solutions to game quirks that seem to affect some people."]}))
        end
        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(CreateSettingsButtonInitializer(
                L["Clear Spell Cache"],
                L["Clear"],
                function()
                    GSESpellCache = {}
                    GSESpellCache["enUS"] = {}
                    if GSE.isEmpty(GSESpellCache[GetLocale()]) then
                        GSESpellCache[GetLocale()] = {}
                    end
                end,
                L["This function will clear the spell cache and any mappings between individual spellIDs and spellnames."],
                true
            ))
        end
        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(CreateSettingsButtonInitializer(
                L["Edit Spell Cache"],
                L["Edit"],
                function()
                    GSE.CheckGUI()
                    if GSE.UnsavedOptions["GUI"] then
                        GSE.GUIShowSpellCacheWindow()
                    else
                        GSE.Print(L["The GSE_GUI Module needs to be enabled to edit the spell cache."], L["Options"])
                    end
                end,
                L["This function will open a window enabling you to edit the spell cache and any mappings between individual spellIDs and spellnames."],
                true
            ))
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["CVar Settings"], tooltip = L["CVar Settings"]}))
        end
        do
            local function GetValue()
                return tonumber(C_CVar.GetCVar("ActionButtonUseKeyDown")) == 1
            end
            local function SetValue(val)
                C_CVar.SetCVar("ActionButtonUseKeyDown", val and 1 or 0)
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "ActionButtonUseKeyDown", Settings.VarType.Boolean, L["ActionButtonUseKeyDown"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["This setting is a common setting used by all WoW mods.  If affects how your action buttons respond.  With this on the react when you hit the button.  With them off they react when you let them go.  In GSE's case this setting has to be off for Actionbar Overrides to work."])
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Button Settings"], tooltip = L["Button Settings"]}))
        end
        do
            local function GetValue() return GSEOptions.Multiclick end
            local function SetValue(val)
                GSEOptions.Multiclick = val
                StaticPopup_Show("GSE_ConfirmReloadUIDialog")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "useMulticlickButtons", Settings.VarType.Boolean, L["Use MultiClick Buttons"], true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["GSE Sequences are converted to a button that responds to 'Clicks' or Keyboard keypresses (WoW calls these Hardware Events).  \n\nWhen you use a KeyBind with a sequence, WoW sends two hardware events each time. With this setting on, GSE then interprets these two clicks as one and advances your sequence one step.  With this off it would advance two steps.  \n\nIn comparison Actionbar Overrides and '/click SEQUENCE' macros only sends one hardware Event.  If you primarily use Keybinds over Actionbar Overrides over Keybinds you want this set to false."])
        end

        do
            local layout = SettingsPanel:GetLayout(troubleOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Keybinding Tools"], tooltip = L["Keybinding Tools"]}))
        end
        do
            local function GetValue() return GSEOptions.DebugPrintModConditionsOnKeyPress end
            local function SetValue(val)
                GSEOptions.DebugPrintModConditionsOnKeyPress = val
                StaticPopup_Show("GSE_ConfirmReloadUIDialog")
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "printKeyPressModifiers", Settings.VarType.Boolean, L["Print Active Modifiers on Click"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Print to the chat window if the alt, shift, control modifiers as well as the button pressed on each macro keypress."])
        end
        do
            local function GetValue()
                return GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Enabled or false
            end
            local function SetValue(val)
                GSEOptions.SequenceIconFrame.Enabled = val
                if not val then
                    GSE.SequenceIconFrame:Hide()
                else
                    GSE.SequenceIconFrame:Show()
                end
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSequenceIcons", Settings.VarType.Boolean, L["Show Sequence Icons"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Show the Sequence Icon Preview Frame"])
        end
        do
            local function GetValue() return GSEOptions.SequenceIconFrame.ShowIconModifiers end
            local function SetValue(val) GSEOptions.SequenceIconFrame.ShowIconModifiers = val end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSequenceModifiers", Settings.VarType.Boolean, L["Show Sequence Modifiers"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Show the Modifiers (eg Shift, Alt, Ctrl) and Buttons (eg Left Mousebutton) that were seen by the GSE sequence at the click/press it was triggered from."])
        end
        do
            local function GetValue() return GSEOptions.SequenceIconFrame.ShowSequenceName end
            local function SetValue(val) GSEOptions.SequenceIconFrame.ShowSequenceName = val end
            local setting = Settings.RegisterProxySetting(troubleOptions, "showSequenceName", Settings.VarType.Boolean, L["Show Sequence Name"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Show the Name of the Sequence"])
        end
        do
            local function GetValue() return GSEOptions.SequenceIconFrame.IconSize or 64 end
            local function SetValue(val)
                GSEOptions.SequenceIconFrame.IconSize = val
                GSE.IconFrameResize(val)
            end
            local setting = Settings.RegisterProxySetting(troubleOptions, "iconPreviewSize", Settings.VarType.Number, L["Preview Icon Size"], 64, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(16, 256, 8)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(troubleOptions, setting, options, L["Default is 64 pixels."])
        end
        do
            local function GetValue()
                return (GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Orientation or "HORIZONTAL") == "HORIZONTAL"
            end
            local function SetValue(val) if val then GSEOptions.SequenceIconFrame.Orientation = "HORIZONTAL" end end
            local setting = Settings.RegisterProxySetting(troubleOptions, "iconOrientationH", Settings.VarType.Boolean, L["Horizontal Layout"], true, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Icon Preview Orientation: Horizontal"])
        end
        do
            local function GetValue()
                return (GSEOptions.SequenceIconFrame and GSEOptions.SequenceIconFrame.Orientation or "HORIZONTAL") == "VERTICAL"
            end
            local function SetValue(val) if val then GSEOptions.SequenceIconFrame.Orientation = "VERTICAL" end end
            local setting = Settings.RegisterProxySetting(troubleOptions, "iconOrientationV", Settings.VarType.Boolean, L["Vertical Layout"], false, GetValue, SetValue)
            Settings.CreateCheckbox(troubleOptions, setting, L["Icon Preview Orientation: Vertical"])
        end
    end

    -- Colour
    do
        local colourOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Colour"])

        -- r,g,b (0-1) → |cffRRGGBB
        local function toHex(r, g, b)
            return string.format("|c%02x%02x%02x%02x", 255, r * 255, g * 255, b * 255)
        end

        -- Label text rendered in its own colour — acts as the swatch
        local function colouredLabel(label, r, g, b)
            return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, label)
        end

        local colours = {
            { header = L["General Options"] },
            { label = L["Title Colour"],              desc = L["Picks a Custom Colour for the Mod Names."],
              get = function() return GSE.GUIGetColour(GSEOptions.TitleColour) end,
              set = function(r,g,b) GSEOptions.TitleColour    = toHex(r,g,b) end },
            { label = L["Info Colour"],               desc = L["Picks a Custom Colour for informational and debug output."],
              get = function() return GSE.GUIGetColour(GSEOptions.AuthorColour) end,
              set = function(r,g,b) GSEOptions.AuthorColour   = toHex(r,g,b) end },
            { label = L["Command Colour"],            desc = L["Picks a Custom Colour for the Commands."],
              get = function() return GSE.GUIGetColour(GSEOptions.CommandColour) end,
              set = function(r,g,b) GSEOptions.CommandColour  = toHex(r,g,b) end },
            { label = L["Emphasis Colour"],           desc = L["Picks a Custom Colour for emphasis."],
              get = function() return GSE.GUIGetColour(GSEOptions.EmphasisColour) end,
              set = function(r,g,b) GSEOptions.EmphasisColour = toHex(r,g,b) end },
            { label = L["Normal Colour"],             desc = L["Picks a Custom Colour to be used normally."],
              get = function() return GSE.GUIGetColour(GSEOptions.NormalColour) end,
              set = function(r,g,b) GSEOptions.NormalColour   = toHex(r,g,b) end },
            { header = L["Editor Colours"] },
            { label = L["Slash Commands"],            desc = L["Picks a Custom Colour for WoW macro slash commands like /cast and /use."],
              get = function() return GSE.GUIGetColour(GSEOptions.WOWSHORTCUTS) end,
              set = function(r,g,b) GSEOptions.WOWSHORTCUTS   = toHex(r,g,b) end },
            { label = L["Modifiers & Functions"],     desc = L["Picks a Custom Colour for conditional modifiers and standard functions."],
              get = function() return GSE.GUIGetColour(GSEOptions.STANDARDFUNCS) end,
              set = function(r,g,b) GSEOptions.STANDARDFUNCS  = toHex(r,g,b) end },
            { label = L["Conditionals & Comments"],   desc = L["Picks a Custom Colour for macro conditionals eg [mod:shift] and comments."],
              get = function() return GSE.GUIGetColour(GSEOptions.COMMENT) end,
              set = function(r,g,b) GSEOptions.COMMENT        = toHex(r,g,b) end },
            { label = L["Spells & Action Labels"],    desc = L["Picks a Custom Colour for spell names and action block type labels."],
              get = function() return GSE.GUIGetColour(GSEOptions.KEYWORD) end,
              set = function(r,g,b) GSEOptions.KEYWORD        = toHex(r,g,b) end },
            { label = L["Logic & Comparison"],        desc = L["Picks a Custom Colour for logic and comparison operators such as == and or."],
              get = function() return GSE.GUIGetColour(GSEOptions.EQUALS) end,
              set = function(r,g,b) GSEOptions.EQUALS         = toHex(r,g,b) end },
            { label = L["Table Operators"],           desc = L["Picks a Custom Colour for table operators such as { } and ..."],
              get = function() return GSE.GUIGetColour(GSEOptions.CONCAT) end,
              set = function(r,g,b) GSEOptions.CONCAT         = toHex(r,g,b) end },
            { label = L["Numbers & Operators"],       desc = L["Picks a Custom Colour for numbers and arithmetic operators."],
              get = function() return GSE.GUIGetColour(GSEOptions.NUMBER) end,
              set = function(r,g,b) GSEOptions.NUMBER         = toHex(r,g,b) end },
            { label = L["Bracket Operators"],         desc = L["Picks a Custom Colour for array bracket operators [ ]."],
              get = function() return GSE.GUIGetColour(GSEOptions.STRING) end,
              set = function(r,g,b) GSEOptions.STRING         = toHex(r,g,b) end },
            { label = L["Unknown Colour"],            desc = L["Picks a Custom Colour to be used for unknown terms."],
              get = function() return GSE.GUIGetColour(GSEOptions.UNKNOWN) end,
              set = function(r,g,b) GSEOptions.UNKNOWN        = toHex(r,g,b) end },
        }

        local colourInits = {}

        for _, entry in ipairs(colours) do
            if entry.header then
                do
                    local layout = SettingsPanel:GetLayout(colourOptions)
                    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
                        name = entry.header, tooltip = "",
                    }))
                end
            else
                local colEntry = entry
                do
                    local layout = SettingsPanel:GetLayout(colourOptions)
                    local r, g, b = colEntry.get()
                    local init = CreateSettingsButtonInitializer(
                        colouredLabel(colEntry.label, r, g, b),
                        L["Change"],
                        function(btnArg)
                            local btn = btnArg
                            if not btn then return end
                            local cr, cg, cb = colEntry.get()
                            local function updateLabel(nr, ng, nb)
                                local newName = colouredLabel(colEntry.label, nr, ng, nb)
                                local ci = colourInits[colEntry]
                                if ci then
                                    local d = ci:GetData()
                                    if d then d.name = newName end
                                end
                                local labelFrame = btn:GetParent()
                                if labelFrame and labelFrame.Text then
                                    labelFrame.Text:SetText(newName)
                                end
                            end
                            ColorPickerFrame:SetupColorPickerAndShow({
                                swatchFunc = function()
                                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                                    colEntry.set(nr, ng, nb)
                                    updateLabel(nr, ng, nb)
                                end,
                                cancelFunc = function(prev)
                                    colEntry.set(prev.r, prev.g, prev.b)
                                    updateLabel(prev.r, prev.g, prev.b)
                                end,
                                r = cr, g = cg, b = cb,
                                hasOpacity = false,
                            })
                        end,
                        colEntry.desc,
                        false
                    )
                    colourInits[colEntry] = init
                    layout:AddInitializer(init)
                end
            end
        end
    end

    -- Plugins
    do
        local pluginOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Plugins"])
        do
            local layout = SettingsPanel:GetLayout(pluginOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Registered Addons"], tooltip = L["GSE Plugins"]}))
        end
        if GSE.isEmpty(GSE.AddInPacks) then
            do
                local layout = SettingsPanel:GetLayout(pluginOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["No plugins are currently registered."], tooltip = ""}))
            end
        else
            for _, v in pairs(GSE.AddInPacks) do
                local packName = v.Name
                local displayName = C_AddOns.GetAddOnMetadata(packName, "Title") or packName
                local desc = C_AddOns.GetAddOnMetadata(packName, "Notes") or
                    string.format(L["Addin Version %s contained versions for the following sequences:"], packName) ..
                    string.format("\n%s", FormatSequenceNames(v.SequenceNames))
                local layout = SettingsPanel:GetLayout(pluginOptions)
                local capturedPackName = packName
                local capturedV = v

                -- Section header per plugin so each one is visually separated.
                -- This also acts as the closing boundary for the previous plugin's
                -- individual sequence items, preventing them from bleeding into the
                -- next plugin's Reload All button.
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
                    name = displayName,
                    tooltip = desc,
                }))

                layout:AddInitializer(CreateSettingsButtonInitializer(
                    L["Reload All"],
                    L["Reload All"],
                    function()
                        if capturedV.Sequences then
                            GSE.LoadPluginSequences(capturedV.Sequences)
                        else
                            GSE:SendMessage(Statics.ReloadMessage, capturedPackName)
                        end
                    end,
                    desc,
                    false
                ))

                -- Per-sequence restore buttons (only available when the plugin passes its Sequences table)
                if not GSE.isEmpty(v.Sequences) and v.SequenceNames then
                    for _, seqName in ipairs(v.SequenceNames) do
                        local encodedSeq = v.Sequences[seqName]
                        local status = GSE.GetPluginSequenceStatus(encodedSeq)

                        local compatText
                        if status.compatible then
                            compatText = L["Compatible with this version of GSE"]
                        else
                            local verStr = status.GSEVersion and tostring(status.GSEVersion) or L["unknown"]
                            compatText = string.format(L["Not compatible with this version of GSE (sequence version: %s)"], verStr)
                        end

                        local checksumText
                        if status.checksum == "valid" then
                            checksumText = L["Checksum valid"]
                        elseif status.checksum == "invalid" then
                            checksumText = L["Checksum invalid - sequence may have been modified"]
                        else
                            checksumText = L["No checksum"]
                        end

                        local seqDesc = compatText .. "\n" .. checksumText
                        local capturedSeqName = seqName
                        layout:AddInitializer(CreateSettingsButtonInitializer(
                            capturedSeqName,
                            L["Restore"],
                            function()
                                local seq = capturedV.Sequences and capturedV.Sequences[capturedSeqName]
                                if seq then
                                    GSE.ImportSerialisedSequence(seq, false)
                                    GSE.PerformReloadSequences()
                                end
                            end,
                            seqDesc,
                            false
                        ))
                    end
                end
            end
        end
    end

    -- Window Sizes
    do
        local windowOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Window Sizes"])

        do
            local layout = SettingsPanel:GetLayout(windowOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Sequence Editor"], tooltip = L["Sequence Editor"]}))
        end
        do
            local function GetValue() return GSEOptions.editorHeight or 700 end
            local function SetValue(val) if val >= 500 then GSEOptions.editorHeight = val end end
            local setting = Settings.RegisterProxySetting(windowOptions, "editorHeight", Settings.VarType.Number, L["Default Editor Height"], 700, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(500, 2000, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels high should the Editor start at.  Defaults to 700"])
        end
        do
            local function GetValue() return GSEOptions.editorWidth or 700 end
            local function SetValue(val) if val >= 700 then GSEOptions.editorWidth = val end end
            local setting = Settings.RegisterProxySetting(windowOptions, "editorWidth", Settings.VarType.Number, L["Default Editor Width"], 700, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(700, 3000, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels wide should the Editor start at.  Defaults to 700"])
        end
        do
            local function GetValue() return GSEOptions.editorTreeWidth or 150 end
            local function SetValue(val) if val >= 50 then GSEOptions.editorTreeWidth = val end end
            local setting = Settings.RegisterProxySetting(windowOptions, "editorTreeWidth", Settings.VarType.Number, L["Default Tree Panel Width"], 150, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(50, 500, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels wide should the sequence list panel on the left of the Editor be.  Defaults to 150"])
        end

        do
            local layout = SettingsPanel:GetLayout(windowOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Menu"], tooltip = L["Menu Options"]}))
        end
        do
            local function GetValue()
                local d = GSEOptions.frameLocations and GSEOptions.frameLocations.menu and GSEOptions.frameLocations.menu.direction
                return (d and d ~= "") and d or "DOWN"
            end
            local function SetValue(val)
                if GSE.UpdateMenuDirection then GSE.UpdateMenuDirection(val) end
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "menuDirection", Settings.VarType.String, L["Growth Direction"], "DOWN", GetValue, SetValue)
            local function GetOptions()
                local container = Settings.CreateControlTextContainer()
                container:Add("UP",    L["Up"])
                container:Add("DOWN",  L["Down"])
                container:Add("LEFT",  L["Left"])
                container:Add("RIGHT", L["Right"])
                return container:GetData()
            end
            Settings.CreateDropdown(windowOptions, setting, GetOptions, L["Direction the menu grows from the logo button."])
        end
        do
            local function GetValue()
                return GSEOptions.frameLocations and GSEOptions.frameLocations.menu and GSEOptions.frameLocations.menu.locked == true
            end
            local function SetValue(val)
                if GSE.isEmpty(GSEOptions.frameLocations) then GSEOptions.frameLocations = {} end
                if GSE.isEmpty(GSEOptions.frameLocations.menu) then GSEOptions.frameLocations.menu = {} end
                GSEOptions.frameLocations.menu.locked = val
                if GSE.MenuFrame then GSE.MenuFrame:SetMovable(not val) end
            end
            local setting = Settings.RegisterProxySetting(windowOptions, "menuLocked", Settings.VarType.Boolean, L["Lock Menu Position"], false, GetValue, SetValue)
            Settings.CreateCheckbox(windowOptions, setting, L["Prevent the menu from being dragged to a new position."])
        end

        do
            local layout = SettingsPanel:GetLayout(windowOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Sequence Debugger"], tooltip = L["Sequence Debugger"]}))
        end
        do
            local function GetValue() return GSEOptions.debugHeight or 500 end
            local function SetValue(val) if val >= 500 then GSEOptions.debugHeight = val end end
            local setting = Settings.RegisterProxySetting(windowOptions, "debugWindowHeight", Settings.VarType.Number, L["Default Debugger Height"], 500, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(500, 2000, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels high should the Debuger start at.  Defaults to 500"])
        end
        do
            local function GetValue() return GSEOptions.debugWidth or 700 end
            local function SetValue(val) if val >= 700 then GSEOptions.debugWidth = val end end
            local setting = Settings.RegisterProxySetting(windowOptions, "debugWindowWidth", Settings.VarType.Number, L["Default Debugger Width"], 700, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(700, 3000, 10)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(windowOptions, setting, options, L["How many pixels wide should the Debugger start at.  Defaults to 700"])
        end
    end

    -- Debug (Developer only)
    if GSE.Developer then
        local debugOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Debug"])
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Debug Mode Options"], tooltip = L["Debug Mode Options"]}))
        end
        do
            local function GetValue() return GSEOptions.debug end
            local function SetValue(val)
                GSEOptions.debug = val
                GSE.PrintDebugMessage("Debug Mode Enabled", GNOME)
            end
            local setting = Settings.RegisterProxySetting(debugOptions, "enableDebugMode", Settings.VarType.Boolean, L["Enable Mod Debug Mode"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This option dumps extra trace information to your chat window to help troubleshoot problems with the mod"])
        end
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Debug Output Options"], tooltip = L["Debug Output Options"]}))
        end
        do
            local function GetValue() return GSEOptions.sendDebugOutputToChatWindow end
            local function SetValue(val) GSEOptions.sendDebugOutputToChatWindow = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "debugChat", Settings.VarType.Boolean, L["Display debug messages in Chat Window"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This will display debug messages in the Chat window."])
        end
        do
            local function GetValue() return GSEOptions.sendDebugOutputToDebugOutput end
            local function SetValue(val) GSEOptions.sendDebugOutputToDebugOutput = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "storeDebugOutput", Settings.VarType.Boolean, L["Store Debug Messages"], false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["Store output of debug messages in a Global Variable that can be referrenced by other mods."])
        end
        do
            local layout = SettingsPanel:GetLayout(debugOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {name = L["Enable Debug for the following Modules"], tooltip = L["Enable Debug for the following Modules"]}))
        end
        for k, _ in pairs(Statics.DebugModules) do
            local modKey = k
            local function GetValue() return GSEOptions.DebugModules[modKey] end
            local function SetValue(val) GSEOptions.DebugModules[modKey] = val end
            local setting = Settings.RegisterProxySetting(debugOptions, "debug_" .. modKey, Settings.VarType.Boolean, modKey, false, GetValue, SetValue)
            Settings.CreateCheckbox(debugOptions, setting, L["This will display debug messages for the "] .. modKey)
        end
    end
end

function GSE:CreateConfigPanels()
    if not registered then
        registered = true

        local aboutPanel = createAboutPanel()
        local category = Settings.RegisterCanvasLayoutCategory(aboutPanel, addonName)
        Settings.RegisterAddOnCategory(category)
        GSE.MenuCategoryID = category:GetID()

        local generalOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["General"])

        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["General Options"] , ["tooltip"]= L["General"] }))
        end
        -- Hide Minimap icon
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "minimapIcon", "hide", GSEOptions.showMiniMap, Settings.VarType.Boolean, L["Hide Minimap Icon"], true)
            setting:SetValueChangedCallback(function ()
                if GSE.LDB then
                    GSE.MiniMapControl(GSEOptions.showMiniMap.hide)
                end
            end)
            Settings.CreateCheckbox(generalOptions, setting, L["Hide Minimap Icon for LibDataBroker (LDB) data text."])
        end
        -- Show Other Users
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showothergseusersintooltip", "showGSEUsers", GSEOptions, Settings.VarType.Boolean, L["Show GSE Users in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  List Other GSE Users and their version when in a group on the tooltip to this feed."])
        end
        -- Show OOC Queue
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showoocqueueintooltip", "showGSEoocqueue", GSEOptions, Settings.VarType.Boolean, L["Show OOC Queue in LDB"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE has a LibDataBroker (LDB) data feed.  Set this option to show queued Out of Combat events in the tooltip."])
        end
        -- Reset OOC Queue
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "resetOOC", "resetOOC", GSEOptions, Settings.VarType.Boolean, L["Reset Sequences when out of combat"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Resets sequences back to the initial state when out of combat."])
        end
        -- Hide Login Message
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "hideLogin", "HideLoginMessage", GSEOptions, Settings.VarType.Boolean, L["Hide Login Message"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Hides the message that GSE is loaded."])
        end
        -- Actionbar Override Popup (Retail only - Classic requires a different menu API)
        if GSE.GameMode > 10 then
            local setting = Settings.RegisterAddOnSetting(generalOptions, "actionbaroverpopup", "actionBarOverridePopup", GSEOptions, Settings.VarType.Boolean, L["Enable Actionbar Override Popup"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Show a sequence picker popup when right-clicking an empty actionbar button outside of combat."])
        end
        -- Actionbar Override Watermark
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "actionBarWatermark", "showActionBarWatermark", GSEOptions, Settings.VarType.Boolean, L["Show Actionbar Override Watermark"], true)
            setting:SetValueChangedCallback(function()
                GSE.SetActionBarWatermarkEnabled(GSEOptions.showActionBarWatermark ~= false)
            end)
            Settings.CreateCheckbox(generalOptions, setting, L["Show the GSE logo as a small watermark on actionbar override buttons."])
        end
        -- Hide Login Message
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "UseVerboseExportFormat", "DefaultHumanReadableExportFormat", GSEOptions, Settings.VarType.Boolean, L["Create Human Readable Exports"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["When exporting from GSE create a descriptive export for Discord/Discource forums."])
        end
        ---- OOC Queue Delay
        do
            local function GetValue()
                return GSEOptions.OOCQueueDelay or 7
            end

            local function SetValue(value)
                GSEOptions.OOCQueueDelay = value
            end

            local setting = Settings.RegisterProxySetting(generalOptions, "defaultOOCTimerDelay", Settings.VarType.Number, L["OOC Queue Delay"], 7, GetValue, SetValue)
            local options = Settings.CreateSliderOptions(1, 60, 1)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(generalOptions, setting, options, L["The delay in seconds between Out of Combat Queue Polls.  The Out of Combat Queue saves changes and updates sequences.  When you hit save or change zones, these actions enter a queue which checks that first you are not in combat before proceeding to complete their task.  After checking the queue it goes to sleep for x seconds before rechecking what is in the queue."])
        end

        ---- externalMillisecondClickRate
        do
            if GSE.Patron or GSE.Developer then
                local function GetValue()
                    return GSEOptions.msClickRate or 250
                end

                local function SetValue(value)
                    GSEOptions.msClickRate = value
                end

                local setting = Settings.RegisterProxySetting(generalOptions, "msClickRate", Settings.VarType.Number, L["MS Click Rate"], 250, GetValue, SetValue)
                local options = Settings.CreateSliderOptions(100, 1000, 1)
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                Settings.CreateSlider(generalOptions, setting, options, L["The milliseconds being used in key click delay."])
            end
        end
        do
            local layout = SettingsPanel:GetLayout(generalOptions)
            layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Filter Sequence Selection"], ["tooltip"]= L["Filter Sequence Selection"]}))
        end
        -- Show All Sequences
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showAllMacros", Statics.All, GSEOptions.filterList, Settings.VarType.Boolean, L["Show All Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["Resets sequences back to the initial state when out of combat."])
        end
        -- showClassMacros
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showClassMacros", Statics.Class, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Class Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["By setting this value the Sequence Editor will show every sequence for your class.  Turning this off will only show the class sequences for your current specialisation."])
        end
        -- HshowGlobalMacros
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showGlobalMacros", Statics.Global, GSEOptions.filterList, Settings.VarType.Boolean, L["Show Global Sequences in Editor"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["This shows the Global Sequences available as well as those for your class."])
        end
        -- showCurrentSpells
        do
            local setting = Settings.RegisterAddOnSetting(generalOptions, "showCurrentSpells", "showCurrentSpells", GSEOptions, Settings.VarType.Boolean, L["Show Current Spells"], true)
            Settings.CreateCheckbox(generalOptions, setting, L["GSE stores the base spell and asks WoW to use that ability.  WoW will then choose the current version of the spell.  This toggle switches between showing the Base Spell or the Current Spell."])
        end

        -- Character Specific Settings

        do
            local CharOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Character"])


            -- Reset OOC Queue
            do
                local setting = Settings.RegisterAddOnSetting(CharOptions, "charresetOOC", "resetOOC", GSE_C, Settings.VarType.Boolean, L["Reset Sequences when out of combat"], true)
                Settings.CreateCheckbox(CharOptions, setting, L["Resets sequences back to the initial state when out of combat."])
            end

            ---- externalMillisecondClickRate
            do
                if GSE.Patron or GSE.Developer then
                    local function GetValue()
                        return GSE_C.msClickRate or 250
                    end

                    local function SetValue(value)
                        GSE_C.msClickRate = value
                    end

                    local setting = Settings.RegisterProxySetting(CharOptions, "charmsClickRate", Settings.VarType.Number, L["MS Click Rate"], 250, GetValue, SetValue)
                    local options = Settings.CreateSliderOptions(100, 1000, 1)
                    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                    Settings.CreateSlider(CharOptions, setting, options, L["The milliseconds being used in key click delay."])
                end
            end
        end

        do
            local ResetOptions = Settings.RegisterVerticalLayoutSubcategory(category, L["Sequence Reset"])

            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Mouse Buttons."] , ["tooltip"]= L["These options combine to allow you to reset a sequence while it is running.  These options are Cumulative ie they add to each other.  Options Like LeftClick and RightClick won't work together very well."] }))
            end
            -- Reset OOC Queue
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftButton", "LeftButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightButton", "RightButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetMiddleButton", "MiddleButton", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Middle Mouse Button"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetButton4", "Button4", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Mouse Button 4"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetButton5", "Button5", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Mouse Button 5"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Alt Keys."], ["tooltip"]= L["Alt Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyAltKey", "Alt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftAltKey", "LeftAlt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightAltKey", "RightAlt", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Alt Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Control Keys."], ["tooltip"]= L["Control Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyControlKey", "Control", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftControlKey", "LeftControl", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightControlKey", "RightControl", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Control Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local layout = SettingsPanel:GetLayout(ResetOptions)
                layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {["name"] = L["Shift Keys."], ["tooltip"]= L["Shift Keys."] }))
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetAnyShiftKey", "Shift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Any Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetLeftShiftKey", "LeftShift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Left Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
            do
                local setting = Settings.RegisterAddOnSetting(ResetOptions, "resetRightShiftKey", "RightShift", GSEOptions.MacroResetModifiers, Settings.VarType.Boolean, L["Right Shift Key"], false)
                Settings.CreateCheckbox(ResetOptions, setting, "")
            end
        end

        createBlizzOptions(category)

    end

end
GSE:CreateConfigPanels()

