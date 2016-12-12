local GSE = GSE
local L = GSE.L

--- This function pops up a confirmation dialog.
function GSE.GUIDeleteSequence(currentSeq, iconWidget)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].text = string.format(L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."], GSE.GUIEditFrame.SequenceName)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
      GSE.GUIConfirmDeleteSequence(GSE.GUIEditFrame.ClassID, GSE.GUIEditFrame.SequenceName)
  end


  StaticPopup_Show ("GSE-DeleteMacroDialog")
end

--- This function then deletes the macro
function GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  GSE.DeleteSequence(classid, sequenceName)
  GSE.GUIEditFrame:Hide()
  GSE.GUIShowViewer()
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

function GSE.GUILoadEditor(key, incomingframe, recordedstring)
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
    if not GSE.isEmpty(recordedstring) then
      sequence.MacroVersions[1][1] = nil
      sequence.MacroVersions[1] = GSE.SplitMeIntolines(recordedstring)
    end
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


function GSE.GUIChangeOtherSequence(key)
  otherversionlistboxvalue = key
  otherSequenceVersions:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][key], (GSE.isEmpty(GSELibrary[currentSequence][key].lang) and GetLocale() or GSELibrary[currentSequence][key].lang ), GetLocale()), currentSequence))
end

function GSE.GUIUpdateSequenceList()
  local names = GSE.GetSequenceNames()
  GSE.GUIViewFrame.SequenceListbox:SetList(names)
end

function GSE.GUIloadTranslatedSequence(key)
  GSE.PrintDebugMessage(L["GSTranslateSequenceFromTo(GSELibrary["] .. currentSequence .. L["], (GSE.isEmpty(GSELibrary["] .. currentSequence .. L["].lang) and GSELibrary["] .. currentSequence .. L["].lang or GetLocale()), key)"] , GNOME)
  GSE.GUIViewFrame.SequenceTextbox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], (GSE.isEmpty(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang) and "enUS" or GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang ), key), currentSequence))
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
      local vals = {}
      vals.action = "Replace"
      vals.sequencename = SequenceName
      vals.sequence = sequence
      vals.classid = classid
      table.insert(GSE.OOCQueue, vals)
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


function GSE:OnInitialize()
    GSE.GUIRecordFrame:Hide()
    GSE.GUIVersionFrame:Hide()
    GSE.GUIEditFrame:Hide()
    GSE.GUIViewFrame:Hide()
    GSE.Print(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSEOptions.CommandColour .. L["/gs |r to get started."], "GSE")
end


function GSE.OpenOptionsPanel()
  local config = LibStub:GetLibrary("AceConfigDialog-3.0")
  config:Open("GSE")
  --config:SelectGroup("GSSE", "Debug")

end
