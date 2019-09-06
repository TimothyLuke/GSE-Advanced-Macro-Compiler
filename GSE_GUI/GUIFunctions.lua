local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local LibQTip = LibStub('LibQTip-1.0')


--- This function pops up a confirmation dialog.
function GSE.GUIDeleteSequence(classid, sequenceName)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].text = string.format(L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."], sequenceName)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
    GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  end


  StaticPopup_Show ("GSE-DeleteMacroDialog")
end

--- This function then deletes the macro.
function GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  GSE.GUIViewFrame:Hide()
  GSE.GUIEditFrame:Hide()
  GSE.DeleteSequence(classid, sequenceName)
  GSE.GUIShowViewer()
end


--- Format the text against the GSE Sequence Spec.
function GSE.GUIParseText(editbox)
  if GSEOptions.RealtimeParse then
    text = GSE.UnEscapeString(editbox:GetText())
    returntext = GSE.TranslateString(text , "STRING", true)
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
    sequenceName = "NEW_SEQUENCE"
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
    GSE.GUIEditFrame.NewSequence = true
  else
    elements = GSE.split(key, ",")
    classid = tonumber(elements[1])
    sequenceName = elements[2]
    sequence = GSE.CloneSequence(GSELibrary[classid][sequenceName], true)
    GSE.GUIEditFrame.NewSequence = false
  end
  GSE.GUIEditFrame:SetStatusText("GSE: " .. GSE.VersionString)
  GSE.GUIEditFrame.SequenceName = sequenceName
  GSE.GUIEditFrame.Sequence = sequence
  GSE.GUIEditFrame.ClassID = classid
  GSE.GUIEditFrame.Default = sequence.Default
  GSE.GUIEditFrame.PVP = sequence.PVP or sequence.Default
  GSE.GUIEditFrame.Mythic = sequence.Mythic or sequence.Default
  GSE.GUIEditFrame.Raid = sequence.Raid or sequence.Default
  GSE.GUIEditFrame.Dungeon = sequence.Dungeon or sequence.Default
  GSE.GUIEditFrame.Heroic = sequence.Heroic or sequence.Default
  GSE.GUIEditFrame.Party = sequence.Party or sequence.Default
  GSE.GUIEditFrame.Timewalking = sequence.Timewalking or sequence.Default
  GSE.GUIEditFrame.MythicPlus = sequence.MythicPlus or sequence.Default
  GSE.GUIEditFrame.Arena = sequence.Arena or sequence.Default
  GSE.GUIEditorPerformLayout(GSE.GUIEditFrame)
  GSE.GUIEditFrame.ContentContainer:SelectTab("config")
  incomingframe:Hide()
  if sequence.ReadOnly then
    GSE.GUIEditFrame.SaveButton:SetDisabled(true)
    GSE.GUIEditFrame:SetStatusText("GSE: " .. GSE.VersionString .. " " .. L["This sequence is Read Only and unable to be edited."])
  end
  GSE.GUIEditFrame:Show()

end


function GSE.GUIUpdateSequenceList()
  local names = GSE.GetSequenceNames()
  GSE.GUIViewFrame.SequenceListbox:SetList(names)
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
  -- Changes have been made, so save them
  for k,v in ipairs(sequence.MacroVersions) do
    sequence.MacroVersions[k] = GSE.TranslateSequence(v, SequenceName, "ID")
    sequence.MacroVersions[k] = GSE.UnEscapeSequence(sequence.MacroVersions[k])
  end

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
      if GSE.GUIEditFrame.NewSequence then
        if GSE.ObjectExists(SequenceName) then
          GSE.GUIEditFrame:SetStatusText(string.format(L["Sequence Name %s is in Use. Please choose a different name."], SequenceName))
          GSE.GUIEditFrame.nameeditbox:SetText(GSEOptions.UNKNOWN .. GSE.GUIEditFrame.nameeditbox:GetText() .. Statics.StringReset)
          GSE.GUIEditFrame.nameeditbox:SetFocus()
          return
        end
        vals.checkmacro = true
        GSE.GUIEditFrame.NewSequence = false
      end
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


function GSE:OnInitialize()
    GSE.GUIRecordFrame:Hide()
    GSE.GUIVersionFrame:Hide()
    GSE.GUIEditFrame:Hide()
    GSE.GUIViewFrame:Hide()
end


function GSE.OpenOptionsPanel()
  local config = LibStub:GetLibrary("AceConfigDialog-3.0")
  config:Open("GSE")
  --config:SelectGroup("GSSE", "Debug")

end

function GSE.CreateToolTip(title, tip, GSEFrame)
  GSE.ClearTooltip(GSEFrame)
  local tooltip = LibQTip:Acquire("GSE", 1, "CENTER")

  GSEFrame.tooltip = tooltip
  tooltip:AddHeader(GSEOptions.TitleColour .. title .. Statics.StringReset)
  tooltip:AddLine(tip)
  tooltip:SmartAnchorTo(GSEFrame.frame)

  tooltip:Show()
end

function GSE.ClearTooltip(GSEFrame)
  LibQTip:Release(GSEFrame.tooltip)
  GSEFrame.tooltip = nil
end
