---@diagnostic disable: undefined-global
-- Version references in MetaData — Default plus the ten context overrides —
-- are INDEXES into Versions. Deleting a version has to move them, and the
-- three cases are easy to get wrong: the old delete handler decremented
-- Default unconditionally, so deleting version 5 while Default was 4 quietly
-- moved Default to 3 and the sequence ran a macro nobody chose.
describe(
  "Version references",
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

        -- ReplaceSequence reaches for a few runtime collaborators that the
        -- mock does not carry. Stub the side effects; the aliasing behaviour
        -- is what this file is testing.
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
      end
    )

    describe(
      "GSE.GetContextVersionKeys",
      function()
        it(
          "covers every context the runtime can select, with no duplicates",
          function()
            local keys = GSE.GetContextVersionKeys()
            local seen = {}
            for _, k in ipairs(keys) do
              assert.is_nil(seen[k], "duplicate key " .. tostring(k))
              seen[k] = true
            end
            -- PVP routes to Arena in one priority entry and to PVP in another;
            -- both names must still be offered exactly once each.
            for _, expected in ipairs({
              "Scenario", "Arena", "PVP", "Raid", "Mythic",
              "MythicPlus", "Heroic", "Dungeon", "Timewalking", "Party",
            }) do
              assert.is_true(seen[expected] == true, "missing key " .. expected)
            end
            assert.equals(10, #keys)
          end
        )
      end
    )

    -- #2023: the editor kept its own list of Configuration rows, which drifted
    -- from the keys the runtime resolves against -- it had grown a row for a
    -- PVESolo context GSE does not have and lost the rows for Mythic, Heroic
    -- and Party, which GSE does honour. An author who had one of those set
    -- could not see or change it, and was refused when deleting the version it
    -- pointed at with a message naming a row that was not on screen. The rows
    -- and the message are built from GetContextVersionDisplay now, so these
    -- assert the two lists cannot come apart again.
    describe(
      "GSE.GetContextVersionDisplay",
      function()
        it(
          "covers every context key exactly once",
          function()
            local display = GSE.GetContextVersionDisplay()
            local seen = {}
            for _, entry in ipairs(display) do
              assert.is_nil(seen[entry.key], "duplicate display entry for " .. tostring(entry.key))
              seen[entry.key] = true
            end
            for _, key in ipairs(GSE.GetContextVersionKeys()) do
              assert.is_true(seen[key] == true, "no Configuration row for context key " .. key)
            end
            assert.equals(#GSE.GetContextVersionKeys(), #display)
          end
        )
        it(
          "offers no row for a context GSE cannot resolve",
          function()
            for _, entry in ipairs(GSE.GetContextVersionDisplay()) do
              assert.is_not.equals("PVESolo", entry.key)
            end
          end
        )
        it(
          "gives every row a section and a label",
          function()
            for _, entry in ipairs(GSE.GetContextVersionDisplay()) do
              assert.is_true(entry.section == "PVE" or entry.section == "PVP",
                entry.key .. " has no Configuration section")
              assert.is_true(type(entry.label) == "string" and entry.label ~= "",
                entry.key .. " has no label")
            end
          end
        )
      end
    )

    describe(
      "GSE.GetContextVersionLabel",
      function()
        it(
          "names a context the way the Configuration tab labels it",
          function()
            assert.equals("Mythic+", GSE.GetContextVersionLabel("MythicPlus"))
            assert.equals("Delves/Scenarios", GSE.GetContextVersionLabel("Scenario"))
            assert.equals("Party", GSE.GetContextVersionLabel("Party"))
          end
        )
        it(
          "falls back to the key so a message always has something to print",
          function()
            assert.equals("Nonsense", GSE.GetContextVersionLabel("Nonsense"))
          end
        )
      end
    )

    describe(
      "GSE.VersionReferencesInUse",
      function()
        it(
          "reports nothing when no entry points at the version",
          function()
            local meta = {Default = 1, Raid = 2}
            assert.equals(0, #GSE.VersionReferencesInUse(meta, 3))
          end
        )
        it(
          "names Default when it points at the version",
          function()
            local meta = {Default = 4}
            local inUse = GSE.VersionReferencesInUse(meta, 4)
            assert.equals(1, #inUse)
            assert.equals("Default", inUse[1])
          end
        )
        it(
          "names every context override pointing at the version",
          function()
            local meta = {Default = 1, Raid = 3, Arena = 3, Party = 2}
            local inUse = GSE.VersionReferencesInUse(meta, 3)
            assert.equals(2, #inUse)
            table.sort(inUse)
            assert.equals("Arena", inUse[1])
            assert.equals("Raid", inUse[2])
          end
        )
        it(
          "treats a string index the same as a number",
          function()
            local meta = {Default = 1, Raid = "4"}
            assert.equals(1, #GSE.VersionReferencesInUse(meta, 4))
          end
        )
        it(
          "is safe on rubbish input",
          function()
            assert.equals(0, #GSE.VersionReferencesInUse(nil, 1))
            assert.equals(0, #GSE.VersionReferencesInUse({}, nil))
          end
        )
      end
    )

    describe(
      "GSE.ShiftVersionReferencesAfterDelete",
      function()
        it(
          "moves a reference that sits after the deleted version",
          function()
            -- Tim's case 1: on version 4, delete version 3 -> 4 becomes 3.
            local meta = {Default = 4, Raid = 4}
            GSE.ShiftVersionReferencesAfterDelete(meta, 3)
            assert.equals(3, meta.Default)
            assert.equals(3, meta.Raid)
          end
        )
        it(
          "leaves a reference that sits before the deleted version",
          function()
            -- Tim's case 3: on version 4, delete version 5 -> no change. This
            -- is the one the unconditional decrement got wrong.
            local meta = {Default = 4, Raid = 4}
            GSE.ShiftVersionReferencesAfterDelete(meta, 5)
            assert.equals(4, meta.Default)
            assert.equals(4, meta.Raid)
          end
        )
        it(
          "leaves version 1 alone when a later version goes",
          function()
            local meta = {Default = 1}
            GSE.ShiftVersionReferencesAfterDelete(meta, 2)
            assert.equals(1, meta.Default)
          end
        )
        it(
          "moves several references independently",
          function()
            local meta = {Default = 2, Raid = 5, Arena = 1, Party = 4}
            GSE.ShiftVersionReferencesAfterDelete(meta, 3)
            assert.equals(2, meta.Default)   -- before, unchanged
            assert.equals(4, meta.Raid)      -- after, shifted
            assert.equals(1, meta.Arena)     -- before, unchanged
            assert.equals(3, meta.Party)     -- after, shifted
          end
        )
        it(
          "does not invent entries for contexts the sequence never set",
          function()
            local meta = {Default = 2}
            GSE.ShiftVersionReferencesAfterDelete(meta, 1)
            assert.is_nil(meta.Raid)
            assert.is_nil(meta.Arena)
          end
        )
        it(
          "is safe on rubbish input",
          function()
            GSE.ShiftVersionReferencesAfterDelete(nil, 1)
            local meta = {Default = 2}
            GSE.ShiftVersionReferencesAfterDelete(meta, nil)
            assert.equals(2, meta.Default)
          end
        )
      end
    )

    describe(
      "GSE.ReplaceSequence",
      function()
        it(
          "stores a copy, not the caller's own table",
          function()
            -- The editor hands its working object to Save. If the Library kept
            -- that same table, every later per-version edit ran twice: once in
            -- the editor, once through each handler's mirror-into-Library
            -- block, which was writing to the same array.
            local seq = {
              MetaData = {Default = 1, Name = "T"},
              Versions = {{Actions = {}}},
            }
            GSE.ReplaceSequence(1, "AliasTest", seq)
            local stored = GSE.Library[1] and GSE.Library[1]["AliasTest"]
            assert.is_not_nil(stored)
            assert.is_false(stored == seq, "Library must not alias the caller's table")
            assert.is_false(stored.Versions == seq.Versions, "Versions array must be a copy too")
            -- A mirror write into the Library must not touch the editor's copy.
            table.insert(stored.Versions, {Actions = {}})
            assert.equals(1, #seq.Versions)
          end
        )
      end
    )
  end
)
