local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

StaticPopupDialogs["GS-DebugOutput"] = {
    text = "Dump of GS Debug messages",
    button1 = L["Update"],
    button2 = L["Close"],
    OnAccept = function(self, data)
        self.EditBox:SetText(GSE.DebugOutput)
    end,
    OnShow = function(self, data)
        self.EditBox:SetText(GSE.DebugOutput)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, -- Avoid some UI taint, see https://www.wowace.com/news/376-how-to-avoid-some-ui-taint
    hasEditBox = true
}

StaticPopupDialogs["GSE_UPDATE_AVAILABLE"] = {
    text = L[
        "GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."
    ],
    hasEditBox = 1,
    OnShow = function(self)
        self.EditBox:SetAutoFocus(false)
        self.EditBox:SetWidth(220)
        self.EditBox:SetText("https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros")
        self.EditBox:HighlightText()
        ChatEdit_FocusActiveWindow()
    end,
    OnHide = function(self)
        self.EditBox:SetWidth(self.EditBox.width or 50)
    end,
    hideOnEscape = 1,
    button1 = OKAY,
    EditBoxOnEnterPressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnTextChanged = function(self)
        if (self:GetText() ~= "https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros") then
            self:SetText("https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros")
        end
        self:HighlightText()
        self:ClearFocus()
        ChatEdit_FocusActiveWindow()
    end,
    OnEditFocusGained = function(self)
        self:HighlightText()
    end,
    showAlert = 1
}

StaticPopupDialogs["GSE_SEQUENCEHELP"] = {
    text = L["Copy this link and open it in a Browser."],
    hasEditBox = 1,
    url = "https://discord.gg/gseunited",
    OnShow = function(self)
        self.EditBox:SetAutoFocus(false)
        self.EditBox.width = self.EditBox:GetWidth()
        self.EditBox:SetWidth(220)
        self.EditBox:SetText(StaticPopupDialogs["GSE_SEQUENCEHELP"].url)
        self.EditBox:HighlightText()
        ChatEdit_FocusActiveWindow()
    end,
    OnHide = function(self)
        self.EditBox:SetWidth(self.EditBox.width or 50)
        self.EditBox.width = nil
    end,
    hideOnEscape = 1,
    button1 = OKAY,
    EditBoxOnEnterPressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnTextChanged = function(self)
        if (self:GetText() ~= StaticPopupDialogs["GSE_SEQUENCEHELP"].url) then
            self:SetText(StaticPopupDialogs["GSE_SEQUENCEHELP"].url)
        end
        self:HighlightText()
        self:ClearFocus()
        ChatEdit_FocusActiveWindow()
    end,
    OnEditFocusGained = function(self)
        self:HighlightText()
    end,
    showAlert = 1
}

StaticPopupDialogs["GSE-MacroImportSuccess"] = {
    text = L["GSE Import Successful."],
    button1 = L["Close"],
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Avoid some UI taint, see https://www.wowace.com/news/376-how-to-avoid-some-ui-taint
}

StaticPopupDialogs["GSE-GenericMessage"] = {
    text = L["GSE Import Successful."],
    button1 = L["Close"],
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Avoid some UI taint, see https://www.wowace.com/news/376-how-to-avoid-some-ui-taint
}

StaticPopupDialogs["GSE-MacroImportFailure"] = {
    text = L["Import String Not Recognised."],
    button1 = L["Close"],
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3 -- Avoid some UI taint, see https://www.wowace.com/news/376-how-to-avoid-some-ui-taint
}

StaticPopupDialogs["GSE_NEW_SEQUENCE_NAME"] = {
    text = L["Enter a name for the new sequence:"],
    button1 = L["Create"],
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 60,
    OnShow = function(self)
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText())
        if not GSE.isEmpty(name) then
            GSE.GUICreateNewSequence(data.editor, name, data.recordedstring)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = strtrim(self.EditBox:GetText())
        if not GSE.isEmpty(name) then
            GSE.GUICreateNewSequence(parent.data.editor, name, parent.data.recordedstring)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GSE_NEW_VARIABLE_NAME"] = {
    text = L["Enter a name for the new variable:"],
    button1 = L["Create"],
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 60,
    OnShow = function(self)
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText())
        if not GSE.isEmpty(name) then
            GSE.GUICreateNewVariable(data.editor, name)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = strtrim(self.EditBox:GetText())
        if not GSE.isEmpty(name) then
            GSE.GUICreateNewVariable(parent.data.editor, name)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GSE-DeleteMacroDialog"] = {
    text = "",
    button1 = L["Delete"],
    button2 = L["Cancel"],
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUPS_NUMDIALOGS,
    showAlert = true,
    exclusive = true
}

StaticPopupDialogs["GSE_ChatLink"] = {
    text = L["Copy this link and paste it into a chat window."],
    hasEditBox = 1,
    link = "",
    OnShow = function(self)
        self.EditBox:SetAutoFocus(false)
        self.EditBox.width = self.EditBox:GetWidth()
        self.EditBox:SetWidth(220)
        self.EditBox:SetText(StaticPopupDialogs["GSE_ChatLink"].link)
        self.EditBox:HighlightText()
        ChatEdit_FocusActiveWindow()
    end,
    OnHide = function(self)
        self.EditBox:SetWidth(self.EditBox.width or 50)
        self.EditBox.width = nil
    end,
    hideOnEscape = 1,
    button1 = OKAY,
    EditBoxOnEnterPressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        ChatEdit_FocusActiveWindow()
        self:GetParent():Hide()
    end,
    EditBoxOnTextChanged = function(self)
        if (self:GetText() ~= StaticPopupDialogs["GSE_ChatLink"].link) then
            self:SetText(StaticPopupDialogs["GSE_ChatLink"].link)
        end
        self:HighlightText()
        self:ClearFocus()
        ChatEdit_FocusActiveWindow()
    end,
    OnEditFocusGained = function(self)
        self:HighlightText()
    end,
    showAlert = 1
}
