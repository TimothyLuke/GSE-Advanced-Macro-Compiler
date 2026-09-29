---@diagnostic disable: undefined-global
-- Variables and macros share a sequence's shape: MetaData for identity and
-- version selection, Versions for what runs. Older content is flat. The
-- upgrade functions turn either into the new shape, and one already new comes
-- back unchanged -- they run on every read, so running twice must be a no-op.
--
-- Run: busted spec/elementshape_spec.lua   /   lua5.1 spec/run51.lua
describe("Variable and macro shape", function()
  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
  end)

  local function flatVariable()
    return {
      funct = "function() return true end", eventEnabled = true, eventNames = {"PLAYER_TARGET_CHANGED"},
      comments = "**help**", commentsHelp = "|cffhelp|r", Author = "Tim@Realm",
      Dependencies = {Variables = {"Other"}}, LastUpdated = "20260929000000", GSEVersion = 3400,
    }
  end

  describe("GSE.UpgradeVariable", function()
    it("puts what runs in Versions[1] and what describes it in MetaData", function()
      local v = GSE.UpgradeVariable(flatVariable(), "Pull")
      assert.equals("function() return true end", v.Versions[1].funct)
      assert.is_true(v.Versions[1].eventEnabled)
      assert.equals("PLAYER_TARGET_CHANGED", v.Versions[1].eventNames[1])
      assert.equals("Tim@Realm", v.MetaData.Author)
      assert.equals("**help**", v.MetaData.Notes, "help text unified on Notes")
      assert.equals("|cffhelp|r", v.MetaData.Help)
      assert.equals("Pull", v.MetaData.Name)
      assert.equals(1, v.MetaData.Default)
      for _, gone in ipairs({"funct", "eventEnabled", "eventNames", "comments", "commentsHelp", "Author"}) do
        assert.is_nil(v[gone], gone .. " left at the top")
      end
      assert.equals("20260929000000", v.LastUpdated, "bookkeeping stays at the top")
      assert.equals("Other", v.Dependencies.Variables[1])
    end)

    it("keeps a scope and PlatformID already in MetaData", function()
      local flat = flatVariable()
      flat.MetaData = {SpecID = 71, PlatformID = "pid"}
      local v = GSE.UpgradeVariable(flat)
      assert.equals(71, v.MetaData.SpecID)
      assert.equals("pid", v.MetaData.PlatformID)
    end)

    it("leaves a variable already in the new shape as it is", function()
      local v = GSE.UpgradeVariable(flatVariable(), "Pull")
      local again = GSE.UpgradeVariable(v, "Other name")
      assert.equals(1, #again.Versions, "no second wrapping")
      assert.equals("Pull", again.MetaData.Name, "an existing name is not replaced")
      assert.equals("function() return true end", again.Versions[1].funct)
    end)
  end)

  describe("GSE.UpgradeMacro", function()
    local function flatMacro()
      return { name = "Burst", icon = 134400, value = 125, Managed = true,
               text = "/cast Fireball", managedMacro = "/cast 133", manageMacro = "/cast Fireball",
               comments = "notes", Author = "Tim@Realm", LastUpdated = "20260929000000" }
    end

    it("puts the macro text in Versions[1] and keeps the node's own fields", function()
      local m = GSE.UpgradeMacro(flatMacro())
      assert.equals("/cast Fireball", m.Versions[1].text)
      assert.equals("/cast 133", m.Versions[1].managedMacro)
      assert.equals("Burst", m.name)
      assert.equals(134400, m.icon)
      assert.equals(125, m.value, "the slot stays on the node")
      assert.is_true(m.Managed)
      assert.equals("Burst", m.MetaData.Name)
      assert.equals("notes", m.MetaData.Notes)
      assert.equals("Tim@Realm", m.MetaData.Author)
      assert.is_nil(m.text)
      assert.is_nil(m.managedMacro)
      assert.is_nil(m.manageMacro, "the legacy copy of the text goes")
    end)

    it("leaves a macro already in the new shape as it is", function()
      local m = GSE.UpgradeMacro(GSE.UpgradeMacro(flatMacro()))
      assert.equals(1, #m.Versions)
      assert.equals("/cast 133", m.Versions[1].managedMacro)
    end)

    it("does not touch a sealed macro", function()
      local sealed = {GSEProtected = "!GSE3!+X"}
      assert.equals(sealed, GSE.UpgradeMacro(sealed))
      assert.is_nil(sealed.Versions)
    end)
  end)

  describe("a variable at runtime", function()
    before_each(function()
      require("../GSE_Utils/Utils")
      -- WoW is Lua 5.1; busted here is 5.4, which has neither.
      _G.loadstring = _G.loadstring or load
      _G.setfenv = _G.setfenv or function(f) return f end
      GSE.EncodeMessage = function(t) return t end
      GSE.DecodeMessage = function(t) return type(t) == "table", t end
      GSE.SendMessage = GSE.SendMessage or function() end
      GSE.IsProtectedAtRest = function() return false end
      GSE.UpdateDeltaFork = nil
      _G.GSEStore = nil
      GSE.LoadStore()
      GSE.V = setmetatable({}, getmetatable(GSE.V))
      GSE.inRaid = nil
    end)

    it("runs the version the context selects, and switches when the context does", function()
      local v = {
        MetaData = {Default = 1, Raid = 2},
        Versions = {{funct = "function() return 'solo' end"}, {funct = "function() return 'raid' end"}},
      }
      GSE.UpdateVariable(v, "Mode")
      assert.equals("solo", GSE.V.Mode())
      GSE.inRaid = true
      GSE.ReloadVariables()
      assert.equals("raid", GSE.V.Mode(), "entering a raid recompiles it")
      GSE.inRaid = nil
      GSE.ReloadVariables()
      assert.equals("solo", GSE.V.Mode())
    end)

    it("stores a flat variable saved by older code in the current shape", function()
      GSE.UpdateVariable({funct = "function() return 1 end", comments = "c"}, "Flat")
      local stored = GSE.Store("variable").Flat
      assert.equals("table", type(stored.Versions))
      assert.equals("function() return 1 end", stored.Versions[1].funct)
      assert.equals("c", stored.MetaData.Notes)
      assert.equals(1, GSE.V.Flat())
    end)

    it("depends on every variable any of its versions calls", function()
      require("../GSE_Utils/Utils")
      local v = {MetaData = {Default = 1}, Versions = {
        {funct = "function() return GSE.V['A']() end"},
        {funct = "function() return GSE.V['B']() end"},
      }}
      GSE.ComputeVariableDependencies(v)
      table.sort(v.Dependencies.Variables)
      assert.equals("A", v.Dependencies.Variables[1])
      assert.equals("B", v.Dependencies.Variables[2])
    end)
  end)

  describe("the version that runs", function()
    it("is the one the current context selects, else Default", function()
      local v = GSE.UpgradeVariable(flatVariable())
      v.Versions[2] = {funct = "function() return false end"}
      v.MetaData.Raid = 2
      assert.equals("function() return true end", GSE.ActiveElementVersion(v).funct)
      GSE.inRaid = true
      assert.equals("function() return false end", GSE.ActiveElementVersion(v).funct, "in a raid, the Raid version")
      GSE.inRaid = nil
    end)

    it("falls back to the first version when the selected one is missing", function()
      local v = GSE.UpgradeVariable(flatVariable())
      v.MetaData.Default = 5
      assert.equals("function() return true end", GSE.ActiveElementVersion(v).funct)
    end)
  end)

  -- WoW holds what ONE version of a macro is. A macro with several has to be
  -- written from GSE when the context changes; read back instead, the version
  -- WoW still held would be copied over the one that now runs.
  describe("a macro with versions, in WoW", function()
    local book
    before_each(function()
      book = {}
      _G.InCombatLockdown = function() return false end
      _G.GetMacroIndexByName = function(n)
        for slot, m in pairs(book) do if m.name == n then return slot end end
        return 0
      end
      _G.GetMacroInfo = function(slot)
        local m = book[slot]
        if m then return m.name, m.icon, m.body end
      end
      _G.EditMacro = function(slot, name, icon, body)
        book[slot] = {name = name, icon = icon or book[slot].icon, body = body or book[slot].body}
      end
      _G.CreateMacro = function(name, icon, body)
        book[#book + 1] = {name = name, icon = icon, body = body}
        return #book
      end
      GSE.RegisterEvent = GSE.RegisterEvent or function() end
      GSE.UnregisterEvent = GSE.UnregisterEvent or function() end
      GSE.SendMessage = GSE.SendMessage or function() end
      GSE.IsProtectedAtRest = function() return false end
      GSE.UpdateDeltaFork = nil
      _G.GSEStore = nil
      GSE.LoadStore()
      GSE.Library = {}
      GSE.inRaid = nil
    end)

    local function twoVersions()
      return {
        name = "Burst", icon = 1, value = 1,
        MetaData = {Name = "Burst", Default = 1, Raid = 2},
        Versions = {{text = "/cast Solo"}, {text = "/cast Raid"}},
      }
    end

    it("is driven by GSE; a single-version unmanaged macro is not", function()
      assert.is_true(GSE.MacroDrivenByGSE(twoVersions()))
      assert.is_false(GSE.MacroDrivenByGSE(GSE.NewMacroNode("One", 1, "/cast X", 1)))
      assert.is_true(GSE.MacroDrivenByGSE({Managed = true, Versions = {{managedMacro = "/cast 1"}}}))
    end)

    it("is not overwritten by what WoW holds", function()
      local store = {Burst = twoVersions()}
      GSE.SnapshotMacro(store, "Burst", "Burst", 1, "/cast Raid", 4)
      assert.equals("/cast Solo", store.Burst.Versions[1].text, "Default keeps its own text")
      assert.equals(4, store.Burst.value, "the slot is still recorded")
    end)

    it("puts the version the context selects into WoW, and switches with it", function()
      book[1] = {name = "Burst", icon = 1, body = "/cast Solo"}
      GSE.Store("macro").Burst = twoVersions()
      GSE.inRaid = true
      GSE.ManageMacros()
      assert.equals("/cast Raid", book[1].body)
      GSE.inRaid = nil
      GSE.ManageMacros()
      assert.equals("/cast Solo", book[1].body, "leaving the raid puts Default back")
      local stored = GSE.Store("macro").Burst
      assert.equals("/cast Solo", stored.Versions[1].text)
      assert.equals("/cast Raid", stored.Versions[2].text, "neither version copied over the other")
    end)

    it("still records a single-version unmanaged macro edited in /macro", function()
      book[1] = {name = "One", icon = 1, body = "/cast Edited"}
      GSE.Store("macro").One = GSE.NewMacroNode("One", 1, "/cast Old", 1)
      GSE.ManageMacros()
      assert.equals("/cast Edited", GSE.Store("macro").One.Versions[1].text)
    end)
  end)
end)
