local GSE = GSE



function GSE.GUI.DisableSequence(currentSeq, iconWidget)
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
  sequencebox:SetText(GSExportSequencebySeq(GSTranslateSequenceFromTo(GSEOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)], (GSE.isEmpty(GSEOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)].lang) and "enUS" or GSEOptions.SequenceLibrary[currentSeq][GSGetActiveSequenceVersion(currentSeq)].lang), GetLocale()), currentSeq))

end
