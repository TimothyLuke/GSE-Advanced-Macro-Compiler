local GSE = GSE
local L = GSE.L

function GSE.GUIDisableSequence(currentSeq, iconWidget)
  GSToggleDisabledSequence(currentSeq)
  if GSEOptions.DisabledSequences[currentSeq] then
    disableSeqbutton:SetText(L["Enable Sequence"])
    viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
    local reticon = GSSE:getMacroIcon(currentSeq)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    iconWidget:SetImage(reticon)
  end
  sequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[GSE.GetCurrentClassID()][currentSeq].MacroVersions[GSGetActiveSequenceVersion(currentSeq)], (GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][currentSeq].Lang) and "enUS" or GSELibrary[GSE.GetCurrentClassID()][currentSeq].Lang), GetLocale()), currentSeq))

end

--- Format the text against the GSE Sequence Spec.
function GSE.GUIParseText(editbox)
  if GSEOptions.RealtimeParse then
    text = GSE.UnEscapeString(editbox:GetText())
    returntext = GSE.TranslateString(text , GetLocale(), GetLocale(), true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext)+2)
  end
end

function GSE.GUILoadEditor(key, incomingframe)
  local classid
  local sequenceName
  local sequence
  if GSE.isEmpty(key) then
    classid = GSE.GetCurrentClassID()
    sequenceName = "New"
    sequence = {
      ["Author"] = GSE.GetCharacterName(),
      ["Talents"] = GSE.GetCurrentTalents(),
      ["Default"] = 1,
      ["SpecID"] = GSE.GetCurrentSpecID();
      ["MacroVersions"] = {
        [1] = {
          ["PreMacro"] = {},
          ["PostMacro"] = {},
          ["KeyPress"] = {},
          ["KeyRelease"] = {},
          ["StepFunction"] = "Sequential",
          [1] = "/say Hello",
        }
      },
    }
  else
    elements = GSE.split(key, ",")
    classid = tonumber(elements[1])
    sequenceName = elements[2]
    sequence = GSELibrary[classid][sequenceName]
  end
  GSE.GUIEditFrame.SequenceName = sequenceName
  GSE.GUIEditFrame.Sequence = sequence
  GSE.GUIEditFrame.ClassID = classid
  GSE.GUIEditFrame.Default = sequence.Default
  GSE.GUIEditFrame.PVP = sequence.PVP or sequence.Default
  GSE.GUIEditFrame.Mythic = sequence.Mythic or sequence.Default
  GSE.GUIEditFrame.Raid = sequence.Raid or sequence.Default
  GSE.GUIEditorPerformLayout(GSE.GUIEditFrame)
  GSE.GUIEditFrame.ContentContainer:SelectTab("config")
  incomingframe:Hide()
  GSE.GUIEditFrame:Show()

end


function GSE.SetActiveSequence(key)
  GSSetActiveSequenceVersion(currentSequence, key)
  GSUpdateSequence(currentSequence, GSELibrary[currentSequence][key])
  activesequencebox:SetLabel(L["Active Version: "] .. GSGetActiveSequenceVersion(currentSequence) )
  activesequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], GetLocale(), GetLocale()), currentSequence))
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
end

function GSE.GUIChangeOtherSequence(key)
  otherversionlistboxvalue = key
  otherSequenceVersions:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][key], (GSE.isEmpty(GSELibrary[currentSequence][key].lang) and GetLocale() or GSELibrary[currentSequence][key].lang ), GetLocale()), currentSequence))
end

function GSE.GUIUpdateSequenceList()
  local names = GSE.GetSequenceNames()
  GSE.GUIViewFrame.SequenceListbox:SetList(names)
end


function GSE.GUIManageSequenceVersion()
  frame:Hide()
  versionframe:SetTitle(L["Manage Versions"] .. ": " .. currentSequence )
  activesequencebox:SetLabel(L["Active Version: "] .. GSGetActiveSequenceVersion(currentSequence) )
  activesequencebox:SetText(GSE.GUIViewFrame.SequenceTextbox:GetText())
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
  versionframe:Show()
end


function GSE.GUIloadTranslatedSequence(key)
  GSE.PrintDebugMessage(L["GSTranslateSequenceFromTo(GSELibrary["] .. currentSequence .. L["], (GSE.isEmpty(GSELibrary["] .. currentSequence .. L["].lang) and GSELibrary["] .. currentSequence .. L["].lang or GetLocale()), key)"] , GNOME)
  GSE.GUIViewFrame.SequenceTextbox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], (GSE.isEmpty(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang) and "enUS" or GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang ), key), currentSequence))
end

function GSE.GUILoadSequence(key)
  local elements = GSE.split(key, ",")
  classid = elements[1]
  sequenceName = elements[2]

  GSE.PrintDebugMessage(L["GSSE:loadSequence "] .. sequenceName)
  if GSEOptions.useTranslator then
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequencebySeq(GSE.TranslateSequenceFromTo(GSELibrary[classid][sequenceName], (GSE.isEmpty(GSELibrary[classid][sequenceName].Lang) and "enUS" or GSELibrary[classid][sequenceName].Lang), GetLocale()), sequenceName))
  --TODO Fix this so the translator works.
  elseif GSETranslatorAvailable then
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequencebySeq(GSE.TranslateSequenceFromTo(GSELibrary[classid][sequenceName], GetLocale(), GetLocale()), sequenceName))
  else
    GSE.GUIViewFrame.SequenceTextbox:SetText(GSE.ExportSequence(sequenceName))
  end
  if GSEOptions.DisabledSequences[SequenceName] then
    disableSeqbutton:SetText(L["Enable Sequence"])
    viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
    reticon = GSE.GetMacroIcon(classid, sequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    GSE.GUIViewFrame.Icon:SetImage(reticon)
  end

end


function GSE.GUIToggleClasses(buttonname)
  if buttonname == "class" then
    classradio:SetValue(true)
    specradio:SetValue(false)
  else
    classradio:SetValue(false)
    specradio:SetValue(true)
  end
end


function GSE.GUIUpdateSequenceDefinition(classid, SequenceName, sequence)
  -- Changes have been made so save them
  if not GSE.isEmpty(SequenceName) then
    if GSE.isEmpty(classid) then
      classid = GSE.GetCurrentClassID()
    end
    if not GSE.isEmpty(SequenceName) then
      GSELibrary[classid][SequenceName] = sequence
      GSE.UpdateSequence(SequenceName, sequence.MacroVersions[GSE.GetActiveSequenceVersion(SequenceName)])
      GSE.GUIEditFrame:SetStatusText(string.format(L["Sequence %s saved."], SequenceName))
    end
  end
end




function GSE.GUIGetColour(option)
  hex = string.gsub(option, "#","")
  return tonumber("0x".. string.sub(option,5,6))/255, tonumber("0x"..string.sub(option,7,8))/255, tonumber("0x"..string.sub(option,9,10))/255
end

function  GSE.GUISetColour(option, r, g, b)
  option = string.format("|c%02x%02x%02x%02x", 255 , r*255, g*255, b*255)
end

--- This Function enables or disables the Translator Window.
function GSE.ToggleTranslator (boole)
  if boole then
    print('|cffff0000' .. GNOME .. L[":|r The Sequence Translator allows you to use GS-E on other languages than enUS.  It will translate sequences to match your language.  If you also have the Sequence Editor you can translate sequences between languages.  The GS-E Sequence Translator is available on curse.com"])
  end
  GSEOptions.useTranslator = boole
  StaticPopup_Show ("GSEConfirmReloadUI")
end

GSE:RegisterChatCommand("gsse", "GSSlash")




-- Functions



function GSE:GSSlash(input)
    if input == "hide" then
      frame:Hide()
    elseif input == "record" then
      recordframe:Show()
    elseif input == "debug" then
      GSE.GUIShowDebugWindow()
    else
      GSE.GUIShowViewer()
    end
end



function GSE:OnInitialize()
    GSE.GUIRecordFrame:Hide()
    GSE.GUIVersionFrame:Hide()
    GSE.GUIEditFrame:Hide()
    GSE.GUIViewFrame:Hide()
    GSE.Print(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSEOptions.CommandColour .. L["/gsse |r to get started."], GNOME)
end


function GSE.OpenOptionsPanel()
  local config = LibStub:GetLibrary("AceConfigDialog-3.0")
  config:Open("GSE")
  --config:SelectGroup("GSSE", "Debug")

end
