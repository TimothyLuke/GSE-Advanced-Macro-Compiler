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

    describe(
      "macro rest shape",
      function()
        local realDecode, realImport, realManage, imported
        before_each(
          function()
            realDecode, realImport, realManage = GSE.DecodeMessage, GSE.ImportMacro, GSE.ManageMacros
            imported = nil
            -- The sealed path refreshes the macro book afterwards; that is
            -- the WoW API's business, not this test's.
            GSE.ManageMacros = function() end
            if not GSE.SendMessage then GSE.SendMessage = function() end end
            -- "encoded" strings decode to the table they name, so a case can
            -- hand StoreEncodedMacro whatever content it wants to test.
            GSE.DecodeMessage = function(blob)
              if blob == "own" then return true, {name = "Own", text = "/cast X", icon = 1} end
              if blob == "sealed" then return true, {name = "Sealed", text = "/cast Y", MetaData = {noExport = true}} end
              return false
            end
            GSE.ImportMacro = function(node) imported = node end
            GSEMacros = {}
          end
        )
        after_each(
          function()
            GSE.DecodeMessage, GSE.ImportMacro, GSE.ManageMacros = realDecode, realImport, realManage
          end
        )

        it(
          "stores the author's own macro plain, however it arrived",
          function()
            assert.is_true(GSE.StoreEncodedMacro("Own", "own"))
            assert.is_not_nil(imported)
            assert.are.equal("Own", imported.name)
            assert.are.equal("/cast X", imported.text)
            assert.is_nil(GSEMacros["Own"])
          end
        )

        it(
          "keeps protected content sealed",
          function()
            assert.is_true(GSE.StoreEncodedMacro("Sealed", "sealed"))
            assert.is_nil(imported)
            assert.are.same({GSEProtected = "sealed"}, GSEMacros["Sealed"])
          end
        )

        it(
          "refuses a blob it cannot read",
          function()
            assert.is_false(GSE.StoreEncodedMacro("Bad", "garbage"))
            assert.is_nil(imported)
            assert.is_nil(GSEMacros["Bad"])
          end
        )
      end
    )

  end
)
