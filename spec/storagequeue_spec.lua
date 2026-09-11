---@diagnostic disable: undefined-global, duplicate-set-field
-- GSE.EnqueueOOC -- the out-of-combat work queue, and its priority hierarchy.
--
-- Everything the addon cannot do in combat lands here and is drained on the way
-- out. The rules are not "append": a later, heavier operation supersedes lighter
-- ones already queued for the same subject, and a lighter one is dropped when a
-- heavier is pending. Get that wrong and a save is applied after the merge that
-- was meant to replace it, or a sequence is rebuilt from a stale body.
--
-- Priority, heaviest first: MergeSequence > Save/Replace > UpdateSequence.
--
-- Run: busted spec/storagequeue_spec.lua   /   lua5.1 spec/run51.lua
describe("GSE.EnqueueOOC", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    -- Queueing arms the drain timer; there is no combat here to leave.
    GSE.StartOOCTimer = function() end
  end)

  before_each(function() GSE.OOCQueue = {} end)

  local function actions()
    local out = {}
    for _, v in ipairs(GSE.OOCQueue) do out[#out + 1] = v.action end
    return out
  end
  local function names()
    local out = {}
    for _, v in ipairs(GSE.OOCQueue) do out[#out + 1] = v.sequencename or v.name end
    return out
  end

  describe("sequence operations", function()
    it("MergeSequence supersedes every lighter op for the same sequence", function()
      GSE.EnqueueOOC({action = "Save", sequencename = "A"})
      GSE.EnqueueOOC({action = "UpdateSequence", name = "A"})
      GSE.EnqueueOOC({action = "Replace", sequencename = "A"})
      GSE.EnqueueOOC({action = "MergeSequence", sequencename = "A"})
      assert.are.same({"MergeSequence"}, actions())
    end)

    it("and leaves a different sequence's work alone", function()
      GSE.EnqueueOOC({action = "Save", sequencename = "B"})
      GSE.EnqueueOOC({action = "MergeSequence", sequencename = "A"})
      assert.are.same({"Save", "MergeSequence"}, actions())
      assert.are.same({"B", "A"}, names())
    end)

    it("drops a Save that arrives behind a queued MergeSequence", function()
      -- The merge is the heavier operation and already accounts for this
      -- sequence; letting the save through would apply an older body after it.
      GSE.EnqueueOOC({action = "MergeSequence", sequencename = "A"})
      GSE.EnqueueOOC({action = "Save", sequencename = "A"})
      GSE.EnqueueOOC({action = "Replace", sequencename = "A"})
      assert.are.same({"MergeSequence"}, actions())
    end)

    it("replaces a queued Save in place rather than queueing a second", function()
      GSE.EnqueueOOC({action = "Save", sequencename = "A", body = "first"})
      GSE.EnqueueOOC({action = "Save", sequencename = "A", body = "second"})
      assert.are.same({"Save"}, actions())
      assert.are.equal("second", GSE.OOCQueue[1].body, "the newer body wins")
    end)

    it("a Save strips an UpdateSequence already queued for the same sequence", function()
      GSE.EnqueueOOC({action = "UpdateSequence", name = "A"})
      GSE.EnqueueOOC({action = "Save", sequencename = "A"})
      assert.are.same({"Save"}, actions())
    end)

    it("drops an UpdateSequence behind any heavier op", function()
      for _, heavier in ipairs({"MergeSequence", "Save", "Replace"}) do
        GSE.OOCQueue = {}
        GSE.EnqueueOOC({action = heavier, sequencename = "A"})
        GSE.EnqueueOOC({action = "UpdateSequence", name = "A"})
        assert.are.same({heavier}, actions(), heavier .. " should absorb the update")
      end
    end)

    it("collapses repeated UpdateSequence for one sequence", function()
      GSE.EnqueueOOC({action = "UpdateSequence", name = "A"})
      GSE.EnqueueOOC({action = "UpdateSequence", name = "A"})
      GSE.EnqueueOOC({action = "UpdateSequence", name = "B"})
      assert.are.same({"UpdateSequence", "UpdateSequence"}, actions())
      assert.are.same({"A", "B"}, names())
    end)
  end)

  describe("macro operations", function()
    it("importmacro supersedes anything queued for the same macro", function()
      GSE.EnqueueOOC({action = "updatemacro", node = {name = "M"}})
      GSE.EnqueueOOC({action = "importmacro", node = {name = "M"}})
      assert.are.same({"importmacro"}, actions())
    end)

    it("drops an updatemacro behind an importmacro", function()
      GSE.EnqueueOOC({action = "importmacro", node = {name = "M"}})
      GSE.EnqueueOOC({action = "updatemacro", node = {name = "M"}})
      assert.are.same({"importmacro"}, actions())
    end)

    it("keeps a different macro's work", function()
      GSE.EnqueueOOC({action = "importmacro", node = {name = "M"}})
      GSE.EnqueueOOC({action = "importmacro", node = {name = "N"}})
      assert.are.equal(2, #GSE.OOCQueue)
    end)

    it("does not collapse entries with no node to compare", function()
      GSE.EnqueueOOC({action = "updatemacro"})
      GSE.EnqueueOOC({action = "updatemacro"})
      assert.are.equal(2, #GSE.OOCQueue, "without a name there is nothing to call a duplicate")
    end)
  end)

  describe("variables", function()
    it("replaces a queued update for the same variable in place", function()
      GSE.EnqueueOOC({action = "updatevariable", name = "V", body = "old"})
      GSE.EnqueueOOC({action = "updatevariable", name = "V", body = "new"})
      assert.are.equal(1, #GSE.OOCQueue)
      assert.are.equal("new", GSE.OOCQueue[1].body)
    end)

    it("keeps a different variable", function()
      GSE.EnqueueOOC({action = "updatevariable", name = "V"})
      GSE.EnqueueOOC({action = "updatevariable", name = "W"})
      assert.are.equal(2, #GSE.OOCQueue)
    end)
  end)

  describe("singleton actions", function()
    it("queues FinishReload, managemacros and openoptions once each", function()
      for _, a in ipairs({"FinishReload", "managemacros", "openoptions"}) do
        GSE.EnqueueOOC({action = a})
        GSE.EnqueueOOC({action = a})
      end
      assert.are.same({"FinishReload", "managemacros", "openoptions"}, actions())
    end)

    it("CheckMacroCreated is one per sequence, not one overall", function()
      GSE.EnqueueOOC({action = "CheckMacroCreated", sequencename = "A"})
      GSE.EnqueueOOC({action = "CheckMacroCreated", sequencename = "A"})
      GSE.EnqueueOOC({action = "CheckMacroCreated", sequencename = "B"})
      assert.are.same({"A", "B"}, names())
    end)
  end)

  it("appends anything it has no rule for", function()
    GSE.EnqueueOOC({action = "somethingelse", name = "X"})
    GSE.EnqueueOOC({action = "somethingelse", name = "X"})
    assert.are.equal(2, #GSE.OOCQueue, "an unknown action is not silently collapsed")
  end)

  it("preserves arrival order among unrelated work", function()
    GSE.EnqueueOOC({action = "Save", sequencename = "A"})
    GSE.EnqueueOOC({action = "updatevariable", name = "V"})
    GSE.EnqueueOOC({action = "importmacro", node = {name = "M"}})
    assert.are.same({"Save", "updatevariable", "importmacro"}, actions())
  end)
end)
