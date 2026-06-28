---@diagnostic disable: undefined-global, duplicate-set-field
-- Tests for GSE.DiffDelta() — the in-game diff (edit → delta). Round-trip
-- contract: ApplyDelta(base, DiffDelta(base, target)) == target, across field
-- edits, add/remove/reorder, Loop/If nesting, top-level fields, version add/
-- remove, and non-sequence (variable/macro) shapes. Run with:
--   busted spec/sequencedeltadiff_spec.lua

require("../spec/mockGSE")
require("../GSE/API/SequenceDelta")

describe("Sequence Delta diff (edit → delta)", function()
  local function baseSD()
    return {
      LastUpdated = "20260101000000",
      Default = 1,
      VersionLabels = { [1] = "main" },
      MetaData = { Notes = "hi", ClassID = 1, SpecID = 250 },
      Versions = {
        [1] = {
          InbuiltVariables = { x = 1 },
          Actions = {
            [1] = { Type = "Action", type = "macro", macro = "/cast A", Interval = "100", Icon = 1, target = " " },
            [2] = { Type = "Loop", [1] = { Type = "Action", macro = "/cast B" }, [2] = { Type = "Action", macro = "/cast C" } },
            [3] = { Type = "If", [1] = { { Type = "Action", macro = "/cast T" } }, [2] = { { Type = "Action", macro = "/cast F" } } },
          },
        },
      },
    }
  end
  local function cp(v) return GSE.ApplyDelta(v, {}) end -- deep copy via apply with empty delta

  -- DiffDelta(base, target) then ApplyDelta must reproduce target exactly.
  local function roundtrip(name, mutate)
    it(name, function()
      local base = baseSD()
      local target = cp(base)
      mutate(target)
      local out = GSE.ApplyDelta(base, GSE.DiffDelta(base, target))
      assert.are.same(target, out)
    end)
  end

  roundtrip("identity", function() end)
  roundtrip("field edit", function(t) t.Versions[1].Actions[1].macro = "/cast EDIT"; t.Versions[1].Actions[1].Icon = 999 end)
  roundtrip("field removal", function(t) t.Versions[1].Actions[1].target = nil end)
  roundtrip("add block", function(t) t.Versions[1].Actions[4] = { Type = "Action", macro = "/cast NEW" } end)
  roundtrip("remove block", function(t) t.Versions[1].Actions = { [1] = t.Versions[1].Actions[1], [2] = t.Versions[1].Actions[3] } end)
  roundtrip("reorder", function(t) local a = t.Versions[1].Actions; local tmp = a[1]; a[1] = a[3]; a[3] = tmp end)
  roundtrip("loop child edit", function(t) t.Versions[1].Actions[2][1].macro = "/cast B2" end)
  roundtrip("loop child add", function(t) t.Versions[1].Actions[2][3] = { Type = "Action", macro = "/cast Bnew" } end)
  roundtrip("if branch edit", function(t) t.Versions[1].Actions[3][1][1].macro = "/cast T2" end)
  roundtrip("inbuiltVariables", function(t) t.Versions[1].InbuiltVariables = { x = 2, y = 3 } end)
  roundtrip("version-level field (Label/StepFunction)", function(t) t.Versions[1].Label = "renamed"; t.Versions[1].StepFunction = "Priority" end)
  roundtrip("top fields", function(t) t.LastUpdated = "20260202000000"; t.MetaData.Notes = "changed"; t.Default = 2 end)
  roundtrip("top field removal", function(t) t.LastUpdated = nil end)
  roundtrip("add version", function(t) t.Versions[2] = { Actions = { [1] = { Type = "Action", macro = "/cast V2" } } } end)
  roundtrip("remove version", function(t) t.Versions[1] = nil; t.Versions[2] = { Actions = { [1] = { Type = "Action", macro = "/cast V2" } } } end)

  it("variable shape (no Versions)", function()
    local base = { Variable = "x", value = "/cast A", MetaData = { Name = "v" } }
    local target = { Variable = "x", value = "/cast B", MetaData = { Name = "v" } }
    local out = GSE.ApplyDelta(base, GSE.DiffDelta(base, target))
    assert.are.same(target, out)
    assert.is_nil(out.Versions)
  end)

  it("macro shape (no Versions)", function()
    local base = { macro = "/cast A", icon = 1, MetaData = { Name = "m" } }
    local target = { macro = "/cast A\n/cast B", icon = 2, MetaData = { Name = "m" } }
    local out = GSE.ApplyDelta(base, GSE.DiffDelta(base, target))
    assert.are.same(target, out)
    assert.is_nil(out.Versions)
  end)

  it("does not mutate base or target", function()
    local base = baseSD()
    local target = cp(base)
    target.Versions[1].Actions[1].macro = "/cast Z"
    GSE.DiffDelta(base, target)
    assert.are.equal("/cast A", base.Versions[1].Actions[1].macro)
    assert.are.equal("/cast Z", target.Versions[1].Actions[1].macro)
  end)
end)
