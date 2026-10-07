---@diagnostic disable: undefined-global
-- GSE.OpenContextMenu draws Blizzard-menu generators itself in WoW Forever's
-- gamepad mode, because opening Blizzard's menu from addon code there trips
-- ADDON_ACTION_FORBIDDEN. That only works if the stand-in description records
-- what the generators build, and answers clicks the way Blizzard's menu does.
describe(
  "API ContextMenu description",
  function()
    setup(
      function()
        require("../spec/mockGSE")
        -- busted sandboxes spec globals; the module reads the real _G.
        _G.MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }
        require("../GSE/API/ContextMenu")
      end
    )

    it(
      "records titles, buttons, dividers and submenus",
      function()
        local root = GSE.BuildMenuDescription(nil, function(_, desc)
          desc:CreateTitle("Pick")
          local sub = desc:CreateButton("More")
          sub:CreateButton("Inner", function() end)
          desc:CreateDivider()
          desc:CreateButton("Go", function() end)
        end)
        assert.are.equal(4, #root.children)
        assert.are.equal("title", root.children[1].kind)
        assert.are.equal("More", root.children[2].text)
        assert.are.equal(1, #root.children[2].children)
        assert.are.equal("Inner", root.children[2].children[1].text)
        assert.are.equal("divider", root.children[3].kind)
      end
    )

    it(
      "accepts description methods it does not draw",
      function()
        local root = GSE.BuildMenuDescription(nil, function(_, desc)
          desc:SetScrollMode(200)
          local b = desc:CreateButton("x")
          b:AddInitializer(function() end)
          b:SetResponse(_G.MenuResponse.Open)
        end)
        assert.are.equal(1, #root.children)
      end
    )

    it(
      "answers clicks like Blizzard's menu",
      function()
        local hit, chosen = false, nil
        local root = GSE.BuildMenuDescription(nil, function(_, desc)
          desc:CreateButton("close", function() hit = true end)
          desc:CreateButton("keep", function() return _G.MenuResponse.Refresh end)
          desc:CreateCheckbox("cb", function() return true end, function() end)
          desc:CreateRadio("r", function(v) return v == chosen end, function(v) chosen = v end, "b")
        end)
        assert.are.equal("close", root.children[1]:Respond())
        assert.is_true(hit)
        assert.are.equal("refresh", root.children[2]:Respond())
        assert.are.equal("refresh", root.children[3]:Respond(), "a checkbox stays open")
        assert.is_true(root.children[3]:IsSelectedNow())
        assert.is_false(root.children[4]:IsSelectedNow())
        assert.are.equal("close", root.children[4]:Respond())
        assert.are.equal("b", chosen)
        assert.is_true(root.children[4]:IsSelectedNow())
      end
    )

    it(
      "honours SetEnabled and a boolean SetIsSelected",
      function()
        local root = GSE.BuildMenuDescription(nil, function(_, desc)
          local b = desc:CreateButton("off")
          b:SetEnabled(false)
          local c = desc:CreateCheckbox("c", function() return false end, function() end)
          c:SetIsSelected(true)
        end)
        assert.is_false(root.children[1].enabled)
        assert.is_true(root.children[2]:IsSelectedNow())
      end
    )
  end
)
