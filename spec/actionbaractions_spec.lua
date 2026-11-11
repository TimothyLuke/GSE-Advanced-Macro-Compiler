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

  it("keeps a mount by its journal id, or a companion by the spell that summons it", function()
    assert.are.same({ kind = "mount", id = 7 }, ns.ActionFromCursor("mount", 7))
    assert.are.same({ kind = "mount", spell = 6777 }, ns.ActionFromCursor("companion", 1, "MOUNT"))
  end)

  it("casts a mount by its summon spell's name, which CastSpellByID cannot", function()
    local saved = _G.C_Spell
    _G.C_Spell = { GetSpellName = function(id) return ({ [458] = "Brown Horse", [6777] = "Gray Ram" })[id] end }
    assert.are.same({ "spell", "spell", "Brown Horse" }, { ns.ActionAttributes({ kind = "mount", id = 7 }) })
    assert.are.same({ "spell", "spell", "Gray Ram" }, { ns.ActionAttributes({ kind = "mount", spell = 6777 }) })
    _G.C_Spell = saved
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

  it("drags an action or a sequence off with Lock Action Bars on and no Shift held", function()
    local fh = assert(io.open("GSE_Actionbar/Actions.lua", "r"))
    local src = fh:read("*a"):gsub("\r\n", "\n")
    fh:close()
    local body = assert(src:match("\nlocal function pickup%(button%)\n(.-)\nend\n"), "pickup not found")
    local picked, began = {}, {}
    local env = setmetatable({
      ns = { Actions = ns.Actions, PickupAction = function(a) picked[#picked + 1] = a end },
      GSE = { BeginSequenceDrag = function(id) began[#began + 1] = id end },
      changed = function() end,
      InCombatLockdown = function() return false end,
      GetCursorInfo = function() return nil end,
      GetCVarBool = function(name) return name == "lockActionBars" end,
      IsModifiedClick = function() return false end,
    }, { __index = _G })
    local pickup = assert((loadstring or load)("return function(button)\n" .. body .. "\nend"))()
    setfenv(pickup, env)
    local function button(index, sequenceId)
      return { gseIndex = index, SetChecked = function() end,
        GetAttribute = function(_, name) return name == "gse-button" and sequenceId or nil end }
    end
    ns.Actions()[1] = { kind = "macro", name = "Pull" }
    pickup(button(1))
    assert.are.same({ { kind = "macro", name = "Pull" } }, picked)
    assert.is_nil(ns.Actions()[1])
    pickup(button(2, "seqA"))
    assert.are.same({ "seqA" }, began)
  end)

  it("keeps a button's action per spec, for this character", function()
    ns.Actions()[1] = { kind = "spell", id = 100 }
    ns.Actions("1")[1] = { kind = "macro", name = "Pull" }
    assert.are.same({ kind = "spell", id = 100 }, ns.ActionOf({ gseIndex = 1 }))
    assert.are.same({ kind = "macro", name = "Pull" }, GSE_C.ActionBarActions["1"][1])
    assert.is_nil(ns.ActionOf({ gseIndex = 2 }))
  end)
end)
