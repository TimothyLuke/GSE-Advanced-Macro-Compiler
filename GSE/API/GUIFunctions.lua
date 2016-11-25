local GSE = GSE

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

function GSE.GUILoadEditor(SequenceName, recordstring)
  if not GSE.isEmpty(SequenceName) then
    nameeditbox:SetText(SequenceName)
    if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].StepFunction) then
     stepdropdown:SetValue("1")
     stepvalue = 1
    else
     stepdropdown:SetValue("2")
     stepvalue = 2
    end
    GSE.PrintDebugMessage("StepValue: " .. stepvalue, GNOME)
    --TODO Fix this
    -- if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].KeyPress) then
    --   GSE.PrintDebugMessage(L["Moving on - LiveTest.KeyPress already exists."], GNOME)
    -- else
    --  KeyPressbox:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].KeyPress)
    -- end
    -- if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].KeyRelease) then
    --   GSE.PrintDebugMessage(L["Moving on - LiveTest.PosMacro already exists."], GNOME)
    -- else
    --  KeyReleasebox:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].KeyRelease)
    -- end
    spellbox:SetText(table.concat(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)],"\n"))
    reticon = GSSE:getMacroIcon(SequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].helpTxt) then
      helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
    else
      helpeditbox:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].helpTxt)
    end
    iconpicker:SetImage(reticon)
    GSE.PrintDebugMessage("SequenceName: " .. SequenceName, GNOME)
    speciddropdown:SetValue(GSSpecIDList[GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].specID])
    specdropdownvalue = GSSpecIDList[GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].specID]
    if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].loopstart) then
      loopstart:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].loopstart)
    end
    if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].loopstop) then
      loopstop:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].loopstop)
    end
    if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].looplimit) then
      looplimit:SetText(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].looplimit)
    end
  elseif not GSE.isEmpty(recordstring) then
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
    helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
    spellbox:SetText(recordstring)
  else
    GSE.PrintDebugMessage(L["No Sequence Icon setting to "] , GNOME)
    iconpicker:SetImage("Interface\\Icons\\INV_MISC_QUESTIONMARK")
    currentSequence = ""
    helpeditbox:SetText("Talents: " .. GSSE:getCurrentTalents())
  end
  frame:Hide()
  editframe:Show()

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
  activesequencebox:SetText(sequenceboxtext:GetText())
  otherversionlistbox:SetList(GSGetKnownSequenceVersions(currentSequence))
  versionframe:Show()
end


function GSE.GUIloadTranslatedSequence(key)
  GSE.PrintDebugMessage(L["GSTranslateSequenceFromTo(GSELibrary["] .. currentSequence .. L["], (GSE.isEmpty(GSELibrary["] .. currentSequence .. L["].lang) and GSELibrary["] .. currentSequence .. L["].lang or GetLocale()), key)"] , GNOME)
  remotesequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)], (GSE.isEmpty(GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang) and "enUS" or GSELibrary[currentSequence][GSGetActiveSequenceVersion(currentSequence)].lang ), key), currentSequence))
end

function GSE.GUIloadSequence(SequenceName)
  GSE.PrintDebugMessage(L["GSSE:loadSequence "] .. SequenceName)
  if GSAdditionalLanguagesAvailable and GSEOptions.useTranslator then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)], (GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].lang) and "enUS" or GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)].lang), GetLocale()), SequenceName))
  elseif GSTranslatorAvailable then
    sequenceboxtext:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSELibrary[GSE.GetCurrentClassID()][sequenceName].MacroVersions[GSGetActiveSequenceVersion(sequenceName)], GetLocale(), GetLocale()), SequenceName))
  else
    sequenceboxtext:SetText(GSExportSequence(SequenceName))
  end
  if GSEOptions.DisabledSequences[SequenceName] then
    disableSeqbutton:SetText(L["Enable Sequence"])
    viewiconpicker:SetImage(GSEOptions.DefaultDisabledMacroIcon)
  else
    disableSeqbutton:SetText(L["Disable Sequence"])
    reticon = GSSE:getMacroIcon(SequenceName)
    if not tonumber(reticon) then
      -- we have a starting
      reticon = "Interface\\Icons\\" .. reticon
    end
    viewiconpicker:SetImage(reticon)
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


function GSE.GUIUpdateSequenceDefinition(SequenceName)
  -- Changes have been made so save them
  if not GSE.isEmpty(SequenceName) then
    nextVal = GSGetNextSequenceVersion(currentSequence)
    local sequence = {}
    GSSE:lines(sequence, spellbox:GetText())
    -- update sequence
    if tonumber(stepvalue) == 2 then
      sequence.StepFunction = GSStaticPriority
      GSE.PrintDebugMessage("Setting GSStaticPriority.  Inside the Logic Point")
    else
      sequence.StepFunction = nil
    end
    GSE.PrintDebugMessage("StepValue Saved: " .. stepvalue, GNOME)
    -- sequence.KeyPress = KeyPressbox:GetText()
    sequence.author = GetUnitName("player", true) .. '@' .. GetRealmName()
    sequence.source = GSStaticSourceLocal
    sequence.specID = GSSpecIDHashList[specdropdownvalue]
    sequence.helpTxt = helpeditbox:GetText()
    if not tonumber(sequence.icon) then
      sequence.icon = "INV_MISC_QUESTIONMARK"
    end
    if not GSE.isEmpty(loopstart:GetText()) then
      sequence.loopstart = loopstart:GetText()
    end
    if not GSE.isEmpty(loopstop:GetText()) then
      sequence.loopstop = loopstop:GetText()
    end
    if not GSE.isEmpty(looplimit:GetText()) then
      sequence.looplimit = looplimit:GetText()
    end
    -- sequence.KeyRelease = KeyReleasebox:GetText()
    sequence.version = nextVal
    GSTRUnEscapeSequence(sequence)
    if GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()][sequenceName]) then
      -- this is new
      GSE.PrintDebugMessage(L["Creating New Sequence."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSELibrary[GSE.GetCurrentClassID()][sequenceName][nextVal])
      GSUpdateSequenceList()
      GSSequenceListbox:SetValue(SequenceName)
      GSE.Print(L["Sequence Saved as version "] .. nextVal, GNOME)
    else
      GSE.PrintDebugMessage(L["Updating due to new version."], GNOME)
      GSAddSequenceToCollection(SequenceName, sequence, nextVal)
      GSSE:loadSequence(SequenceName)
      GSCheckMacroCreated(SequenceName)
      GSUpdateSequence(SequenceName, GSELibrary[GSE.GetCurrentClassID()][sequenceName][nextVal])
      GSE.Print(L["Sequence Saved as version "] .. nextVal, GNOME)
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
    GSE.GUIViewframe:Hide()
    GSE.Print(L["The Sequence Editor is an addon for GnomeSequencer-Enhanced that allows you to view and edit Sequences in game.  Type "] .. GSEOptions.CommandColour .. L["/gsse |r to get started."], GNOME)
end
