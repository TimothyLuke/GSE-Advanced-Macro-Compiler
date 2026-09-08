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
      "help link sanitising",
      function()
        it(
          "refuses wowlazymacros.com in any scheme, subdomain, path or case",
          function()
            assert.is_false(GSE.HelplinkAllowed("https://wowlazymacros.com/"))
            assert.is_false(GSE.HelplinkAllowed("HTTP://WWW.WowLazyMacros.COM/some/page"))
            assert.is_false(GSE.HelplinkAllowed("wowlazymacros.com"))
            assert.is_true(GSE.HelplinkAllowed("https://discord.gg/gseunited"))
            assert.is_true(GSE.HelplinkAllowed(""))
            assert.is_true(GSE.HelplinkAllowed(nil))
          end
        )

        it(
          "heals a stored sequence to the default and reports the write",
          function()
            local seq = {MetaData = {Helplink = "https://www.wowlazymacros.com/x"}, Versions = {}}
            assert.is_true(GSE.SanitizeHelplink(seq))
            assert.are.equal(GSE.HelplinkDefault, seq.MetaData.Helplink)
            assert.is_false(GSE.SanitizeHelplink(seq))
          end
        )

        it(
          "leaves an allowed link and non-sequences alone",
          function()
            local seq = {MetaData = {Helplink = "https://example.org/help"}, Versions = {}}
            assert.is_false(GSE.SanitizeHelplink(seq))
            assert.are.equal("https://example.org/help", seq.MetaData.Helplink)
            assert.is_false(GSE.SanitizeHelplink(nil))
            assert.is_false(GSE.SanitizeHelplink({}))
          end
        )
      end
    )

  end
)
