---@diagnostic disable: undefined-global
-- What a GSE Action Bar button holds (GSE_Actionbar/Actions.lua): a spell,
-- item, toy, macro or equipment set, taken off the cursor as any action bar
-- takes it, kept by GSE per character and spec, and cast through the button's
-- own secure attributes.
--
-- Loaded with a namespace of its own and its setup left queued: only the parts
-- that need no game run here.
describe("GSE Action Bar actions", function()
  local ns

  before_each(function()
    ns = { deferred = {}, GSE = { CurrentSpecKey = function() return "2" end } }
    assert(loadfile("GSE_Actionbar/Actions.lua"))("GSE_Actionbar", ns)
    _G.GSE_C = {}
    _G.PlayerHasToy = function(id) return id == 900 end
    _G.GetMacroInfo = function(index) return index == 3 and "Pull" or nil end
    _G.C_MountJournal = { GetMountInfoByID = function(id) if id == 7 then return "Horse", 458 end end }
    _G.GetCompanionInfo = function(kind, index) if kind == "MOUNT" and index == 1 then return 1, "Ram", 6777 end end
    _G.C_EquipmentSet = { GetEquipmentSetInfo = function(id) if id == 4 then return "Tank", 135 end end }
  end)

  it("keeps a spell by its base spell, so a talent's override follows it", function()
    assert.are.same({ kind = "spell", id = 100 }, ns.ActionFromCursor("spell", 12, "spell", 200, 100))
    assert.are.same({ kind = "spell", id = 200 }, ns.ActionFromCursor("spell", 12, "spell", 200))
  end)

  it("keeps a mount or companion as the spell that summons it", function()
    assert.are.same({ kind = "spell", id = 458 }, ns.ActionFromCursor("mount", 7))
    assert.are.same({ kind = "spell", id = 6777 }, ns.ActionFromCursor("companion", 1, "MOUNT"))
  end)

  it("tells a toy from an item", function()
    assert.are.same({ kind = "item", id = 5512 }, ns.ActionFromCursor("item", 5512, "|Hitem:5512|h"))
    assert.are.same({ kind = "toy", id = 900 }, ns.ActionFromCursor("item", 900))
  end)

  it("keeps a macro and an equipment set by name", function()
    assert.are.same({ kind = "macro", name = "Pull" }, ns.ActionFromCursor("macro", 3))
    assert.are.same({ kind = "equipmentset", name = "Tank" }, ns.ActionFromCursor("equipmentset", 4))
  end)

  it("holds nothing it cannot cast", function()
    assert.is_nil(ns.ActionFromCursor(nil))
    assert.is_nil(ns.ActionFromCursor("money", 100))
    assert.is_nil(ns.ActionFromCursor("battlepet", "BattlePet-0-1"))
    assert.is_nil(ns.ActionFromCursor("macro", 99))
  end)

  it("casts each kind through its secure type", function()
    assert.are.same({ "spell", "spell", 100 }, { ns.ActionAttributes({ kind = "spell", id = 100 }) })
    assert.are.same({ "item", "item", "item:5512" }, { ns.ActionAttributes({ kind = "item", id = 5512 }) })
    assert.are.same({ "toy", "toy", 900 }, { ns.ActionAttributes({ kind = "toy", id = 900 }) })
    assert.are.same({ "macro", "macro", "Pull" }, { ns.ActionAttributes({ kind = "macro", name = "Pull" }) })
    assert.are.same({ "equipmentset", "equipmentset", "Tank" },
      { ns.ActionAttributes({ kind = "equipmentset", name = "Tank" }) })
    assert.is_nil(ns.ActionAttributes(nil))
  end)

  it("keeps a button's action per spec, for this character", function()
    ns.Actions()[1] = { kind = "spell", id = 100 }
    ns.Actions("1")[1] = { kind = "macro", name = "Pull" }
    assert.are.same({ kind = "spell", id = 100 }, ns.ActionOf({ gseIndex = 1 }))
    assert.are.same({ kind = "macro", name = "Pull" }, GSE_C.ActionBarActions["1"][1])
    assert.is_nil(ns.ActionOf({ gseIndex = 2 }))
  end)
end)
