---@diagnostic disable: undefined-global
describe(
  "API Storage",
  function()
    setup(
      function()
        StaticPopupDialogs = {}
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
        require("../GSE/API/CharacterFunctions")
        require("../GSE/API/Storage")
        require("../GSE/API/translator")

        L = GSE.L
        L["No Help Information Available"] = "No Help Information Available"
        L["A new version of %s has been added."] = "A new version of %s has been added."
        L[" was imported with the following errors."] = " was imported with the following errors."
        L["This Sequence was exported from GSE %s."] = "This Sequence was exported from GSE %s."
        L["Extra Macro Versions of %s has been added."] = "Extra Macro Versions of %s has been added."
        L["No changes were made to "] = "No changes were made to "
        L[" was updated to new version."] = " was updated to new version."
        L["Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."] =
          "Sequence Named %s was not specifically designed for this version of the game.  It may need adjustments."
        L["WARNING ONLY"] = "WARNING ONLY"

        Statics = GSE.Static

        -- OOC Queue Overrides
        function GSE.PerformMergeAction(action, classid, sequenceName, newSequence)
          GSE.OOCPerformMergeAction(action, classid, sequenceName, newSequence)
        end

        function GSE.AddSequenceToCollection(sequenceName, sequence, classid)
          print("SequenceName: " .. sequenceName)
          print("classid: " .. classid)
          print("Sequence: " .. GSE.Dump(sequence))

          GSE.OOCAddSequenceToCollection(sequenceName, sequence, classid)
        end

        function GetAddOnMetadata(name, ver)
          return "3000"
        end
      end
    )
  end
)
