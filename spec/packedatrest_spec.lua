---@diagnostic disable: undefined-global
-- GSE decrypts the packed (!GSE3!+) envelope so it can run a macro; it never
-- produces one. Every at-rest write therefore has to answer the same question
-- first -- "would this put protected content on disk in the clear?" -- and
-- decline if the answer is yes. #2054 is what happens when one of them does
-- not: an imported protected sequence was rewritten plain during the very
-- import that stored it sealed.
describe(
  "Packed content at rest",
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
        Statics = GSE.Static

        GSE.ComputeSequenceDependencies = function() end
        GSE.SnapshotDependentMacros = function() end
        GSE.SanitizeSequenceEditorMarkup = function() return false end
        GSE.UpdateDeltaFork = nil
        GSE.Library = GSE.Library or {}
        GSE.Library[1] = GSE.Library[1] or {}
        _G.GSESequences = _G.GSESequences or {}
        _G.GSESequences[1] = _G.GSESequences[1] or {}
        if not GSE.SendMessage then
          GSE.SendMessage = function() end
        end

        -- GSE.GetTimestamp goes through GetServerTime, which the mock does not
        -- carry. A COUNTER rather than a constant, so "keeps the first
        -- sighting's timestamp" is proving something: every call returns a
        -- different value, and the assertion only holds if the stamp was
        -- genuinely not refreshed.
        local clock = 1700000000
        _G.GetServerTime = function()
          clock = clock + 1
          return clock
        end
        -- RenameSequence walks the per-character actionbar overrides and
        -- checks combat before touching the in-game macro.
        _G.GSE_C = _G.GSE_C or {}
        if not _G.InCombatLockdown then
          _G.InCombatLockdown = function() return false end
        end
      end
    )

    before_each(
      function()
        _G.GSERepackQueue = {}
        _G.GSESequences[1] = {}
        GSE.Library[1] = {}
      end
    )

    -- A real sealed blob is a string with the packed prefix. The mock's
    -- EncodeMessage returns tables, so a string in GSESequences is unambiguous
    -- evidence about which branch ran.
    local SEALED = "!GSE3!+1SEALEDBLOBSTANDIN"

    local function protectedSeq(name)
      return {
        MetaData = {Default = 1, Name = name, noExport = true, PlatformID = "pid-" .. name},
        Versions = {{Actions = {}}},
      }
    end

    local function ownSeq(name)
      return {
        MetaData = {Default = 1, Name = name},
        Versions = {{Actions = {}}},
      }
    end

    describe(
      "GSE.ReplaceSequence",
      function()
        it(
          "leaves the sealed blob alone when the content is protected",
          function()
            local seq = protectedSeq("Prot")
            _G.GSESequences[1]["Prot"] = SEALED
            GSE.ReplaceSequence(1, "Prot", seq)
            assert.equals(SEALED, _G.GSESequences[1]["Prot"])
          end
        )

        it(
          "asks for a repack when the edit cannot be persisted",
          function()
            -- SeedDeltaFork is stubbed false in the mock, so this is the
            -- documented fallback: say so rather than write it out plain.
            local seq = protectedSeq("Prot")
            _G.GSESequences[1]["Prot"] = SEALED
            GSE.ReplaceSequence(1, "Prot", seq)
            local req = _G.GSERepackQueue["sequence:1:Prot"]
            assert.is_not_nil(req)
            assert.equals("pid-Prot", req.platformId)
            assert.equals("edit-needs-repack", req.reason)
          end
        )

        it(
          "still applies the edit in memory",
          function()
            local seq = protectedSeq("Prot")
            seq.Versions[1].Actions = {"changed"}
            _G.GSESequences[1]["Prot"] = SEALED
            GSE.ReplaceSequence(1, "Prot", seq)
            assert.equals("changed", GSE.Library[1]["Prot"].Versions[1].Actions[1])
          end
        )

        it(
          "replaces normally when the content is the author's own",
          function()
            -- The delta path is for protected content ONLY; an ordinary save
            -- must keep going straight to the store, unchanged.
            local seq = ownSeq("Mine")
            GSE.ReplaceSequence(1, "Mine", seq)
            assert.is_not_nil(_G.GSESequences[1]["Mine"])
            assert.is_nil(_G.GSERepackQueue["sequence:1:Mine"])
          end
        )

        it(
          "declines to overwrite a sealed blob even for unmarked content",
          function()
            -- The envelope alone is enough. A body whose noExport was stripped
            -- must not be able to talk GSE into rewriting the blob plain.
            local seq = ownSeq("Sealed")
            _G.GSESequences[1]["Sealed"] = SEALED
            GSE.ReplaceSequence(1, "Sealed", seq)
            assert.equals(SEALED, _G.GSESequences[1]["Sealed"])
          end
        )

        -- A fork exists only because the record was protected when the first
        -- edit landed. The record can stop being protected afterwards -- the
        -- owner's own work comes back from the server flattened and in the
        -- clear -- and the fork then describes a divergence from a base that
        -- is no longer there. Consulting it before asking about protection
        -- meant every later edit was swallowed by a fork the record had
        -- outgrown, so the owner saw local-changes controls on their own
        -- unsealed sequence and no amount of editing cleared them.
        describe(
          "once the record is no longer protected",
          function()
            local forked, forgotten

            before_each(
              function()
                forked, forgotten = false, false
                GSE.UpdateDeltaFork = function() forked = true; return true end
                GSE.ForgetDeltaFork = function() forgotten = true; return true end
              end
            )

            after_each(
              function()
                GSE.UpdateDeltaFork = nil
                GSE.ForgetDeltaFork = nil
              end
            )

            it(
              "writes the edit into the record instead of the fork",
              function()
                local seq = ownSeq("Mine")
                _G.GSESequences[1]["Mine"] = "!GSE3!PLAINRECORD"
                GSE.ReplaceSequence(1, "Mine", seq)
                assert.is_false(forked)
                assert.is_true(forgotten)
                assert.are_not.equals("!GSE3!PLAINRECORD", _G.GSESequences[1]["Mine"])
              end
            )

            it(
              "still routes the edit to the fork while the blob is sealed",
              function()
                local seq = ownSeq("Sealed")
                _G.GSESequences[1]["Sealed"] = SEALED
                GSE.ReplaceSequence(1, "Sealed", seq)
                assert.is_true(forked)
                assert.is_false(forgotten)
                assert.equals(SEALED, _G.GSESequences[1]["Sealed"])
              end
            )

            it(
              "still routes the edit to the fork while the body says noExport",
              function()
                local seq = protectedSeq("Prot")
                _G.GSESequences[1]["Prot"] = "!GSE3!PLAINRECORD"
                GSE.ReplaceSequence(1, "Prot", seq)
                assert.is_true(forked)
                assert.is_false(forgotten)
                assert.equals("!GSE3!PLAINRECORD", _G.GSESequences[1]["Prot"])
              end
            )
          end
        )
      end
    )

    describe(
      "GSE.RenameSequence",
      function()
        it(
          "asks for a repack rather than dropping a sequence with no stored blob",
          function()
            -- Assigning the missing blob across would have removed the
            -- sequence from storage entirely.
            local seq = protectedSeq("Old")
            _G.GSESequences[1]["Old"] = nil
            GSE.Library[1]["Old"] = seq
            GSE.RenameSequence(1, "Old", "New", seq)
            assert.is_nil(_G.GSESequences[1]["New"])
            assert.equals("rename-needs-repack", _G.GSERepackQueue["sequence:1:New"].reason)
          end
        )

        it(
          "moves the sealed blob to the new key untouched",
          function()
            -- A rename is a change of table key, so the blob travels as the
            -- string it already is and nothing needs encoding.
            local seq = protectedSeq("Old")
            _G.GSESequences[1]["Old"] = SEALED
            GSE.Library[1]["Old"] = seq
            GSE.RenameSequence(1, "Old", "New", seq)
            assert.equals(SEALED, _G.GSESequences[1]["New"])
            assert.is_nil(_G.GSESequences[1]["Old"])
          end
        )
      end
    )

    describe(
      "GSE.AuditProtectedAtRest",
      function()
        it(
          "reports protected content found sitting in the clear",
          function()
            -- The damage a shipped build already did. It cannot be repaired
            -- here, so it is reported for the Companion to put right.
            GSE.AuditProtectedAtRest("sequence", 1, "Bare", {"Bare", protectedSeq("Bare")},
              protectedSeq("Bare"))
            local req = _G.GSERepackQueue["sequence:1:Bare"]
            assert.is_not_nil(req)
            assert.equals("plaintext-at-rest", req.reason)
          end
        )

        it(
          "clears the request once the blob is sealed again",
          function()
            -- This is what makes the queue self-draining: after the Companion
            -- writes the sealed blob back, the next login removes the entry.
            GSE.AuditProtectedAtRest("sequence", 1, "Bare", nil, protectedSeq("Bare"))
            assert.is_not_nil(_G.GSERepackQueue["sequence:1:Bare"])
            GSE.AuditProtectedAtRest("sequence", 1, "Bare", SEALED, protectedSeq("Bare"))
            assert.is_nil(_G.GSERepackQueue["sequence:1:Bare"])
          end
        )

        it(
          "says nothing about the author's own content",
          function()
            GSE.AuditProtectedAtRest("sequence", 1, "Mine", nil, ownSeq("Mine"))
            assert.is_nil(_G.GSERepackQueue["sequence:1:Mine"])
          end
        )

        it(
          "keeps the first sighting's timestamp across repeated logins",
          function()
            GSE.AuditProtectedAtRest("sequence", 1, "Bare", nil, protectedSeq("Bare"))
            local first = _G.GSERepackQueue["sequence:1:Bare"].stamp
            GSE.AuditProtectedAtRest("sequence", 1, "Bare", nil, protectedSeq("Bare"))
            assert.equals(first, _G.GSERepackQueue["sequence:1:Bare"].stamp)
            -- and one entry, not two
            local n = 0
            for _ in pairs(_G.GSERepackQueue) do n = n + 1 end
            assert.equals(1, n)
          end
        )
      end
    )

    describe(
      "GSE.BackfillLastUpdated",
      function()
        it(
          "skips protected content instead of stamping it",
          function()
            -- There is no way to persist the stamp without rewriting the
            -- sealed blob, and an unwritten one would be re-minted to a new
            -- `now` on every load -- drift, not a backfill.
            local seq = protectedSeq("Prot")
            seq.LastUpdated = nil
            _G.GSESequences[1]["Prot"] = SEALED
            GSE.Library[1]["Prot"] = seq
            GSE.BackfillLastUpdated()
            assert.is_nil(seq.LastUpdated)
            assert.equals(SEALED, _G.GSESequences[1]["Prot"])
          end
        )
      end
    )
  end
)
