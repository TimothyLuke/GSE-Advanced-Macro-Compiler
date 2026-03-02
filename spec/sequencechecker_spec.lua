---@diagnostic disable: undefined-global, duplicate-set-field
-- Tests for GSE.ScanMacrosForErrors() and GSE.FixSequenceStructure()
-- Run with: busted spec/sequencechecker_spec.lua

-- IndentationLib is a WoW addon loaded before GSE_Utils/Utils.lua in-game.
-- It must be a true global before Utils.lua is require()d.
IndentationLib = {
  tokens = {
    TOKEN_SPECIAL       = "special",
    TOKEN_KEYWORD       = "keyword",
    TOKEN_UNKNOWN       = "unknown",
    TOKEN_COMMENT_SHORT = "comment_short",
    TOKEN_COMMENT_LONG  = "comment_long",
    TOKEN_STRING        = "string",
    TOKEN_NUMBER        = "number",
  }
}

describe(
  "Sequence Error Checker",
  function()
    local printedMsgs = {}
    local replaceSeqCalls = {}
    local reloadCalls = {}

    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")   -- sets GSEOptions, GSE.OOCQueue
        require("../GSE/API/StringFunctions")  -- provides GSE.UnEscapeString

        Statics = GSE.Static

        -- AceLocale returns the key itself for enUS; replicate that here
        L = GSE.L
        setmetatable(L, {__index = function(_, k) return k end})

        -- Ace3 method used at module level in Utils.lua
        function GSE:RegisterChatCommand(command, handler) -- luacheck: ignore
          -- no-op in tests
        end

        -- Stub WoW-specific / OOC functions that Utils.lua calls
        function GSE.CompileTemplate(macro) -- luacheck: ignore
          -- Minimal stub: just return an empty action list
          return {}
        end

        function GSE.GetCurrentClassID()
          return 11  -- Druid in unit tests
        end

        function GSE.ReplaceSequence(classid, seqname, seq) -- luacheck: ignore
          table.insert(replaceSeqCalls, {classid = classid, seqname = seqname, seq = seq})
          -- Mirror what the real implementation does so Library stays in sync
          GSE.Library[classid][seqname] = seq
        end

        function GSE.ReloadSequences()
          table.insert(reloadCalls, true)
        end

        -- GSESequences must exist (indexed 0-13) for the encoding check loop
        GSESequences = {}
        for i = 0, 13 do GSESequences[i] = {} end

        require("../GSE_Utils/Utils")
      end
    )

    before_each(
      function()
        -- Fresh Library, Queue, and message capture for every test
        GSE.Library = {}
        for i = 0, 13 do GSE.Library[i] = {} end

        -- GSESequences is normally initialised by Storage.lua; provide a clean
        -- stub here so the GSESequences encoding-check loop in ScanMacrosForErrors
        -- can iterate without error.
        GSESequences = {}
        for i = 0, 13 do GSESequences[i] = {} end

        GSE.OOCQueue = {}

        printedMsgs   = {}
        replaceSeqCalls = {}
        reloadCalls   = {}

        GSE.Print = function(msg, tag)
          table.insert(printedMsgs, {msg = msg or "", tag = tag})
        end
      end
    )

    -- ----------------------------------------------------------------
    -- Helper: checks whether any captured GSE.Print message contains `text`
    -- ----------------------------------------------------------------
    local function hasMsg(text)
      for _, entry in ipairs(printedMsgs) do
        if entry.msg:find(text, 1, true) then
          return true
        end
      end
      return false
    end

    -- ----------------------------------------------------------------
    -- Helper: build a minimal structurally-valid sequence
    -- ----------------------------------------------------------------
    local function makeSeq()
      return {
        MetaData = {
          SpecID  = 11,
          Default = 1,
        },
        Macros = {
          [1] = {
            Actions = {
              [1] = {Type = "Action", macro = "/cast Fireball"}
            },
            InbuiltVariables = {}
          }
        }
      }
    end

    -- ================================================================
    -- ScanMacrosForErrors — structural checks
    -- ================================================================

    describe(
      "ScanMacrosForErrors structural checks",
      function()

        it(
          "reports no issues for a clean sequence",
          function()
            GSE.Library[0]["CleanSeq"] = makeSeq()
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("Issues found in 'CleanSeq'"))
            assert.is_true(hasMsg("no errors were found"))
          end
        )

        it(
          "reports missing MetaData table",
          function()
            GSE.Library[0]["BadSeq"] = {Macros = {[1] = {Actions = {}}}}
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("Missing MetaData table"))
            assert.is_true(hasMsg("Issues found in 'BadSeq'"))
          end
        )

        it(
          "reports missing Macros table",
          function()
            GSE.Library[0]["BadSeq"] = {MetaData = {SpecID = 11}}
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("Missing or invalid Macros table"))
          end
        )

        it(
          "reports missing MetaData.SpecID",
          function()
            local seq = makeSeq()
            seq.MetaData.SpecID = nil
            GSE.Library[0]["NoSpecID"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("MetaData.SpecID is missing"))
          end
        )

        it(
          "reports gaps in the Macros array",
          function()
            local seq = makeSeq()
            -- Macros has [1] and [3] — index 2 is missing
            seq.Macros[3] = {
              Actions = {[1] = {Type = "Action", macro = "/cast Frost Nova"}},
              InbuiltVariables = {}
            }
            GSE.Library[0]["GappedMacros"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("Macros array has gaps"))
            assert.is_true(hasMsg("1 version(s) reachable of 2 total (max index 3)"))
          end
        )

        it(
          "reports MetaData.Default pointing to a non-existent Macros index",
          function()
            local seq = makeSeq()
            seq.MetaData.Default = 5  -- only index 1 exists
            GSE.Library[0]["BadDefault"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("MetaData.Default = 5 references a non-existent Macros version"))
          end
        )

        it(
          "reports MetaData.Raid pointing to a non-existent Macros index",
          function()
            local seq = makeSeq()
            seq.MetaData.Raid = 99
            GSE.Library[0]["BadRaid"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("MetaData.Raid = 99 references a non-existent Macros version"))
          end
        )

        it(
          "reports a Macro version with missing Actions table",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions = nil
            GSE.Library[0]["NoActions"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("Macros[1].Actions is missing or not a table"))
          end
        )

        it(
          "reports gaps in a Macro version's Actions array",
          function()
            local seq = makeSeq()
            -- Actions has [1] and [3] — index 2 is missing
            seq.Macros[1].Actions[3] = {Type = "Action", macro = "/cast Frost Nova"}
            GSE.Library[0]["GappedActions"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("Macros[1].Actions has gaps"))
          end
        )

        it(
          "reports an action that is missing the Type field",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {macro = "/cast Fireball"}  -- no Type
            GSE.Library[0]["NoType"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("is missing Type field"))
          end
        )

        it(
          "reports an action with an unrecognized Type value",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "WrongType", macro = "/cast Fireball"}
            GSE.Library[0]["BadType"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("has unrecognized Type: 'WrongType'"))
          end
        )

        it(
          "reports an If action that is missing the Variable field",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "If"}  -- no Variable
            GSE.Library[0]["BadIf"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("(If) is missing the Variable field"))
          end
        )

        it(
          "does not report an If action that has a Variable",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "If", Variable = "Combat"}
            GSE.Library[0]["GoodIf"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("(If) is missing the Variable field"))
            assert.is_false(hasMsg("Issues found in 'GoodIf'"))
          end
        )

        it(
          "reports an Embed action that is missing the Sequence field",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "Embed"}  -- no Sequence
            GSE.Library[0]["BadEmbed"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("(Embed) is missing the Sequence field"))
          end
        )

        it(
          "does not report an Embed action that has a Sequence field",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "Embed", Sequence = "OtherSeq"}
            GSE.Library[0]["GoodEmbed"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("(Embed) is missing the Sequence field"))
            assert.is_false(hasMsg("Issues found in 'GoodEmbed'"))
          end
        )

        it(
          "reports a Pause action that has neither Clicks nor MS",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "Pause"}
            GSE.Library[0]["BadPause"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("(Pause) has neither Clicks nor MS"))
          end
        )

        it(
          "does not report a Pause action that specifies Clicks",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "Pause", Clicks = 3}
            GSE.Library[0]["GoodPauseClicks"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("(Pause) has neither Clicks nor MS"))
          end
        )

        it(
          "does not report a Pause action that specifies MS",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[2] = {Type = "Pause", MS = 500}
            GSE.Library[0]["GoodPauseMS"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("(Pause) has neither Clicks nor MS"))
          end
        )

        it(
          "scans the global pool (class 0) as well as class-specific libraries",
          function()
            -- Put the bad sequence in a class-specific slot, not class 0
            local seq = makeSeq()
            seq.MetaData.SpecID = nil
            GSE.Library[2]["WarriorSeq"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("MetaData.SpecID is missing"))
            assert.is_true(hasMsg("Issues found in 'WarriorSeq'"))
          end
        )

        it(
          "reports the correct total issue count across sequences",
          function()
            local seq = makeSeq()
            seq.MetaData.SpecID = nil    -- issue 1
            seq.MetaData.Default = 99   -- issue 2
            GSE.Library[0]["TwoIssues"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("2 issue(s) found"))
          end
        )

        it(
          "prints the FixSequenceStructure command for sequences with issues",
          function()
            local seq = makeSeq()
            seq.MetaData.SpecID = nil
            GSE.Library[0]["NeedsFixing"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg('GSE.FixSequenceStructure(0, "NeedsFixing")'))
          end
        )

      end
    )

    -- ================================================================
    -- ScanMacrosForErrors — content / macro text checks
    -- ================================================================

    describe(
      "ScanMacrosForErrors macro text checks",
      function()

        it(
          "reports macro text that exceeds 255 characters",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast " .. string.rep("A", 260)
            GSE.Library[0]["LongMacro"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("macro text exceeds 255 characters"))
          end
        )

        it(
          "does not report macro text within the 255-character limit",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast Fireball"
            GSE.Library[0]["ShortMacro"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("macro text exceeds 255 characters"))
            assert.is_false(hasMsg("Issues found in 'ShortMacro'"))
          end
        )

        it(
          "reports unbalanced '[' in macro text conditionals",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast [harm Fireball"  -- missing ]
            GSE.Library[0]["UnbalancedOpen"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("unbalanced brackets"))
          end
        )

        it(
          "reports unbalanced ']' in macro text conditionals",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast harm] Fireball"  -- missing [
            GSE.Library[0]["UnbalancedClose"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("unbalanced brackets"))
          end
        )

        it(
          "does not report balanced brackets",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast [harm][nodead] Fireball"
            GSE.Library[0]["BalancedBrackets"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unbalanced brackets"))
            assert.is_false(hasMsg("Issues found in 'BalancedBrackets'"))
          end
        )

        it(
          "reports an unrecognized slash command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/foobarnotreal Fireball"
            GSE.Library[0]["BadCmd"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("unrecognized slash command: /foobarnotreal"))
          end
        )

        it(
          "does not flag /cast as an unrecognized command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/cast [harm] Fireball"
            GSE.Library[0]["GoodCast"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unrecognized slash command"))
            assert.is_false(hasMsg("Issues found in 'GoodCast'"))
          end
        )

        it(
          "does not flag /use as an unrecognized command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/use 14"
            GSE.Library[0]["GoodUse"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unrecognized slash command"))
          end
        )

        it(
          "does not flag /run as an unrecognized command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/run UIErrorsFrame:Clear()"
            GSE.Library[0]["GoodRun"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unrecognized slash command"))
          end
        )

        it(
          "does not flag /console as an unrecognized command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "/console Sound_EnableSFX 0"
            GSE.Library[0]["GoodConsole"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unrecognized slash command"))
          end
        )

        it(
          "does not flag a spell name (no leading /) as an invalid command",
          function()
            local seq = makeSeq()
            seq.Macros[1].Actions[1].macro = "Fireball"  -- spell name, not macrotext
            GSE.Library[0]["SpellName"] = seq
            GSE.ScanMacrosForErrors()
            assert.is_false(hasMsg("unrecognized slash command"))
            assert.is_false(hasMsg("Issues found in 'SpellName'"))
          end
        )

      end
    )

    -- ================================================================
    -- ScanMacrosForErrors — name collision checks
    -- ================================================================

    describe(
      "ScanMacrosForErrors name collision checks",
      function()

        it(
          "warns about a sequence named 'WW'",
          function()
            GSE.Library[0]["WW"] = makeSeq()
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("WW"))
          end
        )

        it(
          "warns about a sequence named 'PVP'",
          function()
            GSE.Library[0]["PVP"] = makeSeq()
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("PVP"))
          end
        )

        it(
          "warns about WW even in a class-specific library",
          function()
            GSE.Library[5]["WW"] = makeSeq()
            GSE.ScanMacrosForErrors()
            assert.is_true(hasMsg("WW"))
          end
        )

      end
    )

    -- ================================================================
    -- FixSequenceStructure — argument validation
    -- ================================================================

    describe(
      "FixSequenceStructure argument validation",
      function()

        it(
          "reports an error for an invalid class library ID",
          function()
            GSE.FixSequenceStructure(99, "TestSeq")
            assert.is_true(hasMsg("Invalid class library ID"))
          end
        )

        it(
          "reports an error when the sequence is not found",
          function()
            GSE.FixSequenceStructure(0, "DoesNotExist")
            assert.is_true(hasMsg("not found in class library"))
          end
        )

      end
    )

    -- ================================================================
    -- FixSequenceStructure — Macros array compaction
    -- ================================================================

    describe(
      "FixSequenceStructure Macros array compaction",
      function()

        it(
          "compacts a gapped Macros array to consecutive indices",
          function()
            -- Macros[1], Macros[3], Macros[5] — two gaps
            GSE.Library[0]["GappedSeq"] = {
              MetaData = {SpecID = 11, Default = 1},
              Macros = {
                [1] = {Actions = {[1] = {Type = "Action", macro = "/cast A"}}, InbuiltVariables = {}},
                [3] = {Actions = {[1] = {Type = "Action", macro = "/cast B"}}, InbuiltVariables = {}},
                [5] = {Actions = {[1] = {Type = "Action", macro = "/cast C"}}, InbuiltVariables = {}},
              }
            }
            GSE.FixSequenceStructure(0, "GappedSeq")
            local fixed = GSE.Library[0]["GappedSeq"]
            assert.is_not_nil(fixed.Macros[1])
            assert.is_not_nil(fixed.Macros[2])
            assert.is_not_nil(fixed.Macros[3])
            assert.is_nil(fixed.Macros[4])
            assert.is_nil(fixed.Macros[5])
          end
        )

        it(
          "preserves Macro version content and order after compaction",
          function()
            GSE.Library[0]["ContentSeq"] = {
              MetaData = {SpecID = 11, Default = 1},
              Macros = {
                [1] = {Actions = {[1] = {Type = "Action", macro = "/cast A"}}, InbuiltVariables = {}},
                [3] = {Actions = {[1] = {Type = "Action", macro = "/cast B"}}, InbuiltVariables = {}},
              }
            }
            GSE.FixSequenceStructure(0, "ContentSeq")
            local fixed = GSE.Library[0]["ContentSeq"]
            -- Old [1] → new [1], old [3] → new [2]
            assert.are.equal("/cast A", fixed.Macros[1].Actions[1].macro)
            assert.are.equal("/cast B", fixed.Macros[2].Actions[1].macro)
          end
        )

        it(
          "updates MetaData.Default to match the new index after compaction",
          function()
            -- Default was pointing at old Macros[3]; after compaction that becomes [2]
            GSE.Library[0]["DefaultUpdate"] = {
              MetaData = {SpecID = 11, Default = 3},
              Macros = {
                [1] = {Actions = {[1] = {Type = "Action", macro = "/cast A"}}, InbuiltVariables = {}},
                [3] = {Actions = {[1] = {Type = "Action", macro = "/cast B"}}, InbuiltVariables = {}},
              }
            }
            GSE.FixSequenceStructure(0, "DefaultUpdate")
            local fixed = GSE.Library[0]["DefaultUpdate"]
            assert.are.equal(2, fixed.MetaData.Default)
          end
        )

        it(
          "updates MetaData.Raid to match the new index after compaction",
          function()
            GSE.Library[0]["RaidUpdate"] = {
              MetaData = {SpecID = 11, Default = 1, Raid = 3},
              Macros = {
                [1] = {Actions = {[1] = {Type = "Action", macro = "/cast A"}}, InbuiltVariables = {}},
                [3] = {Actions = {[1] = {Type = "Action", macro = "/cast B"}}, InbuiltVariables = {}},
              }
            }
            GSE.FixSequenceStructure(0, "RaidUpdate")
            local fixed = GSE.Library[0]["RaidUpdate"]
            assert.are.equal(2, fixed.MetaData.Raid)
          end
        )

        it(
          "clamps a MetaData ref that pointed to a gap to the max valid index",
          function()
            -- Raid points to index 5 which doesn't exist in a 2-entry Macros table
            GSE.Library[0]["ClampedRef"] = {
              MetaData = {SpecID = 11, Default = 1, Raid = 5},
              Macros = {
                [1] = {Actions = {[1] = {Type = "Action", macro = "/cast A"}}, InbuiltVariables = {}},
                [2] = {Actions = {[1] = {Type = "Action", macro = "/cast B"}}, InbuiltVariables = {}},
              }
            }
            GSE.FixSequenceStructure(0, "ClampedRef")
            local fixed = GSE.Library[0]["ClampedRef"]
            assert.are.equal(2, fixed.MetaData.Raid)
            assert.is_true(hasMsg("MetaData.Raid remapped from non-existent version 5 to 2"))
          end
        )

      end
    )

    -- ================================================================
    -- FixSequenceStructure — Actions array compaction
    -- ================================================================

    describe(
      "FixSequenceStructure Actions array compaction",
      function()

        it(
          "compacts a gapped Actions array to consecutive indices",
          function()
            GSE.Library[0]["GappedActions"] = {
              MetaData = {SpecID = 11, Default = 1},
              Macros = {
                [1] = {
                  Actions = {
                    [1] = {Type = "Action", macro = "/cast A"},
                    [3] = {Type = "Action", macro = "/cast B"},  -- gap at 2
                  },
                  InbuiltVariables = {}
                }
              }
            }
            GSE.FixSequenceStructure(0, "GappedActions")
            local fixed = GSE.Library[0]["GappedActions"]
            assert.is_not_nil(fixed.Macros[1].Actions[1])
            assert.is_not_nil(fixed.Macros[1].Actions[2])
            assert.is_nil(fixed.Macros[1].Actions[3])
          end
        )

        it(
          "preserves action content and order after Actions compaction",
          function()
            GSE.Library[0]["ActionsContent"] = {
              MetaData = {SpecID = 11, Default = 1},
              Macros = {
                [1] = {
                  Actions = {
                    [1] = {Type = "Action", macro = "/cast A"},
                    [4] = {Type = "Action", macro = "/cast B"},  -- large gap
                  },
                  InbuiltVariables = {}
                }
              }
            }
            GSE.FixSequenceStructure(0, "ActionsContent")
            local fixed = GSE.Library[0]["ActionsContent"]
            assert.are.equal("/cast A", fixed.Macros[1].Actions[1].macro)
            assert.are.equal("/cast B", fixed.Macros[1].Actions[2].macro)
          end
        )

        it(
          "compacts Actions in every Macro version",
          function()
            GSE.Library[0]["MultiVersionActions"] = {
              MetaData = {SpecID = 11, Default = 1},
              Macros = {
                [1] = {
                  Actions = {
                    [1] = {Type = "Action", macro = "/cast A1"},
                    [3] = {Type = "Action", macro = "/cast A2"},
                  },
                  InbuiltVariables = {}
                },
                [2] = {
                  Actions = {
                    [1] = {Type = "Action", macro = "/cast B1"},
                    [5] = {Type = "Action", macro = "/cast B2"},
                  },
                  InbuiltVariables = {}
                }
              }
            }
            GSE.FixSequenceStructure(0, "MultiVersionActions")
            local fixed = GSE.Library[0]["MultiVersionActions"]
            assert.is_nil(fixed.Macros[1].Actions[3])
            assert.is_nil(fixed.Macros[2].Actions[5])
            assert.is_not_nil(fixed.Macros[1].Actions[2])
            assert.is_not_nil(fixed.Macros[2].Actions[2])
          end
        )

      end
    )

    -- ================================================================
    -- FixSequenceStructure — OOC queue management
    -- ================================================================

    describe(
      "FixSequenceStructure OOC queue management",
      function()

        it(
          "removes sequencename-keyed OOC entries for the target sequence",
          function()
            GSE.OOCQueue = {
              {action = "Save",         sequencename = "TargetSeq", classid = 0},
              {action = "Save",         sequencename = "OtherSeq",  classid = 0},
              {action = "MergeSequence", sequencename = "TargetSeq", classid = 0},
            }
            GSE.Library[0]["TargetSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "TargetSeq")
            assert.are.equal(1, #GSE.OOCQueue)
            assert.are.equal("OtherSeq", GSE.OOCQueue[1].sequencename)
          end
        )

        it(
          "removes name-keyed OOC entries (UpdateSequence) for the target sequence",
          function()
            GSE.OOCQueue = {
              {action = "UpdateSequence", name = "TargetSeq"},
              {action = "UpdateSequence", name = "OtherSeq"},
            }
            GSE.Library[0]["TargetSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "TargetSeq")
            assert.are.equal(1, #GSE.OOCQueue)
            assert.are.equal("OtherSeq", GSE.OOCQueue[1].name)
          end
        )

        it(
          "keeps FinishReload entries (no sequence name) in the OOC queue",
          function()
            GSE.OOCQueue = {
              {action = "Save",        sequencename = "TargetSeq"},
              {action = "FinishReload"},
            }
            GSE.Library[0]["TargetSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "TargetSeq")
            assert.are.equal(1, #GSE.OOCQueue)
            assert.are.equal("FinishReload", GSE.OOCQueue[1].action)
          end
        )

        it(
          "reports how many queue entries were cleared",
          function()
            GSE.OOCQueue = {
              {action = "Save",           sequencename = "TargetSeq"},
              {action = "UpdateSequence", name          = "TargetSeq"},
            }
            GSE.Library[0]["TargetSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "TargetSeq")
            assert.is_true(hasMsg("Cleared 2 pending queue entries for 'TargetSeq'"))
          end
        )

      end
    )

    -- ================================================================
    -- FixSequenceStructure — save and recompile behaviour
    -- ================================================================

    describe(
      "FixSequenceStructure save and recompile",
      function()

        it(
          "calls ReplaceSequence with the correct class ID and sequence name",
          function()
            GSE.Library[0]["FixSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "FixSeq")
            assert.are.equal(1, #replaceSeqCalls)
            assert.are.equal(0, replaceSeqCalls[1].classid)
            assert.are.equal("FixSeq", replaceSeqCalls[1].seqname)
          end
        )

        it(
          "calls ReloadSequences when fixing a sequence in the current class library",
          function()
            GSE.Library[11]["MySeq"] = makeSeq()  -- class 11 == GetCurrentClassID()
            GSE.FixSequenceStructure(11, "MySeq")
            assert.is_true(#reloadCalls > 0)
          end
        )

        it(
          "calls ReloadSequences when fixing a global (class 0) sequence",
          function()
            GSE.Library[0]["GlobalSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "GlobalSeq")
            assert.is_true(#reloadCalls > 0)
          end
        )

        it(
          "does not call ReloadSequences for a sequence belonging to a different class",
          function()
            GSE.Library[2]["WarrSeq"] = makeSeq()  -- class 2 ≠ 11
            GSE.FixSequenceStructure(2, "WarrSeq")
            assert.are.equal(0, #reloadCalls)
            assert.is_true(hasMsg("button will update when that class is played"))
          end
        )

        it(
          "prints a repair confirmation message on success",
          function()
            GSE.Library[0]["ConfirmSeq"] = makeSeq()
            GSE.FixSequenceStructure(0, "ConfirmSeq")
            assert.is_true(
              hasMsg("has been repaired") or hasMsg("repaired")
            )
          end
        )

      end
    )

  end
)
