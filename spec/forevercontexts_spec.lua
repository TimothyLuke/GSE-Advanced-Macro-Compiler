---@diagnostic disable: undefined-global
-- WoW Forever has no Delves or Scenarios, Arenas, Heroic, Mythic or Mythic+
-- dungeons, or Timewalking. Storage.lua drops those contexts there, at load, so
-- the editor rows, the version picked in game and the delete check all lose
-- them together.
--
-- The filter runs when Storage.lua loads, so these load it again with
-- GSE.IsForever set, then put the normal load back -- spec/run51.lua runs every
-- file in one process and has no teardown.
describe(
  "Forever contexts",
  function()
    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
        require("../GSE/API/CharacterFunctions")
        require("../GSE/API/Storage")
      end
    )

    local function loadStorage(forever)
      GSE.IsForever = forever or nil
      assert(loadfile("GSE/API/Storage.lua"))("GSE", GSE)
    end

    local function onForever(fn)
      loadStorage(true)
      local ok, err = pcall(fn)
      loadStorage(false)
      if not ok then error(err, 0) end
    end

    local function keySet()
      local set = {}
      for _, key in ipairs(GSE.GetContextVersionKeys()) do set[key] = true end
      return set
    end

    it(
      "keeps only Party, Dungeon, Raid and PVP on Forever",
      function()
        onForever(function()
          local set = keySet()
          for _, key in ipairs({"Party", "Dungeon", "Raid", "PVP"}) do
            assert.is_true(set[key] == true, key .. " missing")
          end
          for _, key in ipairs({"Scenario", "Arena", "Heroic", "Mythic", "MythicPlus", "Timewalking"}) do
            assert.is_nil(set[key], key .. " still offered")
          end
          for _, entry in ipairs(GSE.GetContextVersionDisplay()) do
            assert.is_true(set[entry.key] == true, "row for " .. entry.key)
          end
        end)
      end
    )

    it(
      "ignores and drops a value set elsewhere",
      function()
        onForever(function()
          local meta = {Default = 1, Mythic = 3, Arena = 2, Raid = 2}
          -- Not picked in game, and no bar to deleting the version it names.
          GSE.inMythic, GSE.inArena = true, true
          assert.equals(1, GSE.GetActiveVersion(meta))
          GSE.inMythic, GSE.inArena = nil, nil
          assert.equals(0, #GSE.VersionReferencesInUse(meta, 3))
          GSE.DropUnusedContextVersions(meta)
          assert.is_nil(meta.Mythic)
          assert.is_nil(meta.Arena)
          assert.equals(2, meta.Raid)
        end)
      end
    )

    it(
      "keeps every context elsewhere",
      function()
        loadStorage(false)
        local set = keySet()
        for _, key in ipairs({"Scenario", "Arena", "Heroic", "Mythic", "MythicPlus", "Timewalking"}) do
          assert.is_true(set[key] == true, key .. " missing")
        end
        local meta = {Mythic = 3}
        GSE.DropUnusedContextVersions(meta)
        assert.equals(3, meta.Mythic)
      end
    )
  end
)
