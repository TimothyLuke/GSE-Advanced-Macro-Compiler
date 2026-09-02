---@diagnostic disable: undefined-global
describe(
  "API Storage",
  function()
    setup(
      function()
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
    describe(
      "origin key provenance",
      function()
        it(
          "mints a key from name and author",
          function()
            assert.are.equal("SBA|Bob@Realm", GSE.MintOriginKey("SBA", "Bob@Realm"))
          end
        )

        it(
          "stamps a sequence that has none",
          function()
            local seq = {MetaData = {Author = "Bob@Realm"}, Versions = {}}
            assert.is_true(GSE.StampOriginKey(seq, "SBA"))
            assert.are.equal("SBA|Bob@Realm", seq.MetaData.OriginKey)
          end
        )

        it(
          "is frozen once set -- a later rename must not move it",
          function()
            local seq = {MetaData = {Author = "Bob@Realm", OriginKey = "SBA|Bob@Realm"}, Versions = {}}
            assert.is_false(GSE.StampOriginKey(seq, "SBA-Renamed"))
            assert.are.equal("SBA|Bob@Realm", seq.MetaData.OriginKey)
          end
        )

        it(
          "is stamped on save, not only on the next load",
          function()
            -- A sequence created, exported or renamed within one session never
            -- goes through the loader; the save path must stamp it itself.
            local sent = {}
            local saveSendMessage, saveDeps = GSE.SendMessage, GSE.ComputeSequenceDependencies
            GSE.SendMessage = function(_, msg, name) sent[#sent + 1] = msg end
            GSE.ComputeSequenceDependencies = function() end
            GSESequences = {[1] = {}}
            GSE.Library = {[1] = {}}
            local seq = {MetaData = {Author = "Bob@Realm", Default = 1}, Versions = {{Actions = {}}}}
            GSE.ReplaceSequence(1, "SBA", seq)
            assert.are.equal("SBA|Bob@Realm", GSE.Library[1]["SBA"].MetaData.OriginKey)
            -- the mock codec is an identity; the real one returns ok, table
            local decoded = {GSE.DecodeMessage(GSESequences[1]["SBA"])}
            local stored = type(decoded[1]) == "table" and decoded[1] or decoded[2]
            assert.are.equal("SBA|Bob@Realm", stored[2].MetaData.OriginKey)
            -- a later save under a new name keeps the birth key
            GSE.ReplaceSequence(1, "SBA-Renamed", GSE.Library[1]["SBA"])
            assert.are.equal("SBA|Bob@Realm", GSE.Library[1]["SBA-Renamed"].MetaData.OriginKey)
            GSE.SendMessage, GSE.ComputeSequenceDependencies = saveSendMessage, saveDeps
          end
        )

        it(
          "survives the author being rewritten to a site nickname",
          function()
            -- What exportGSE does to every installed sequence. The stored key
            -- must not follow it, or the same sequence answers differently
            -- depending on which side you ask.
            local seq = {MetaData = {Author = "Bob@Realm", OriginKey = "SBA|Bob@Realm"}, Versions = {}}
            seq.MetaData.Author = "bobsnickname"
            assert.is_false(GSE.StampOriginKey(seq, "SBA"))
            assert.are.equal("SBA|Bob@Realm", seq.MetaData.OriginKey)
          end
        )

        it(
          "falls back to MetaData.Name when no name is passed",
          function()
            local seq = {MetaData = {Name = "SBA", Author = "Bob@Realm"}, Versions = {}}
            assert.is_true(GSE.StampOriginKey(seq, nil))
            assert.are.equal("SBA|Bob@Realm", seq.MetaData.OriginKey)
          end
        )

        it(
          "writes nothing when there is no name to mint from",
          function()
            local seq = {MetaData = {Author = "Bob@Realm"}, Versions = {}}
            assert.is_false(GSE.StampOriginKey(seq, nil))
            assert.is_nil(seq.MetaData.OriginKey)
          end
        )

        it(
          "ignores tables that are not sequences",
          function()
            assert.is_false(GSE.StampOriginKey(nil, "SBA"))
            assert.is_false(GSE.StampOriginKey({}, "SBA"))
          end
        )
      end
    )

  end
)
