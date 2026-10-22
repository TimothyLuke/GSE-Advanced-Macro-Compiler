---@diagnostic disable: undefined-global
-- The GSE Action Bar in WoW's Edit Mode (GSE_Actionbar/EditMode.lua): each bar
-- is registered with LibEditMode, its place kept per Edit Mode layout, and
-- copied, renamed or dropped with the layout.
--
-- Run: busted spec/actionbareditmode_spec.lua   /   lua5.1 spec/run51.lua
describe("GSE Action Bar in Edit Mode", function()
  local ns, options, lem, refreshed

  -- Just enough of LibEditMode to record what the bar hands it.
  local function fakeLEM()
    local fake = { frames = {}, settings = {}, callbacks = {}, layout = "Modern",
      SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 } }
    function fake:AddFrame(frame, callback, default, name)
      self.frames[frame] = { callback = callback, default = default, name = name }
    end
    function fake:AddFrameSettings(frame, settings) self.settings[frame] = settings end
    function fake:RegisterCallback(event, callback) self.callbacks[event] = callback end
    function fake:GetActiveLayoutName() return self.layout end
    return fake
  end

  local function load(withLib, usesEditMode)
    lem = withLib and fakeLEM() or nil
    local savedLibStub = _G.LibStub
    _G.LibStub = function(name, silent)
      assert(name == "LibEditMode" and silent)
      return lem
    end
    options = { Spacing = 4, Bars = { { Visibility = "SHOW", Scale = 1, PerRow = 12 },
      { Visibility = "HIDE", Scale = 1, PerRow = 12 } } }
    refreshed = 0
    ns = {
      deferred = {}, BUTTON_COUNT = 24, BAR_SIZE = 12,
      bars = { {}, {} },
      DEFAULT_POINTS = { { "BOTTOM", "UIParent", "BOTTOM", 0, 230 }, { "BOTTOM", "UIParent", "BOTTOM", 0, 276 } },
      Options = function() return options end,
      Refresh = function() refreshed = refreshed + 1 end,
      SetEditing = function(open) ns.editing = open end,
      GSE = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        ActionBarUsesEditMode = function() return usesEditMode end,
      },
    }
    assert(loadfile("GSE_Actionbar/EditMode.lua"))("GSE_Actionbar", ns)
    ns.deferred[1]()
    -- Only the setup asks for it: put back the one other specs see.
    _G.LibStub = savedLibStub
  end

  local function move(b, layout, point, x, y)
    local bar = ns.bars[b]
    lem.frames[bar].callback(bar, layout, point, x, y)
  end

  it("registers each bar, starting where the bar starts", function()
    load(true, true)
    assert.is_true(ns.editMode)
    local first = lem.frames[ns.bars[1]]
    assert.are.same({ point = "BOTTOM", x = 0, y = 230 }, first.default)
    assert.are.equal("GSE Action Bar 1", first.name)
    assert.are.equal("GSE Action Bar 2", lem.frames[ns.bars[2]].name)
    assert.are.equal(4, #lem.settings[ns.bars[1]])
  end)

  it("stays out of the way where the client has no Edit Mode, or the library did not load", function()
    load(true, false)
    assert.is_nil(ns.editMode)
    assert.is_nil(ns.EditModePoint)
    assert.is_nil(next(lem.frames))
    load(false, true)
    assert.is_nil(ns.editMode)
  end)

  it("keeps a bar's place per layout, and has none for a layout it was never placed in", function()
    load(true, true)
    move(1, "Modern", "BOTTOMLEFT", 100, 50)
    assert.are.same({ "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 100, 50 }, ns.EditModePoint(1))
    lem.layout = "Raid"
    assert.is_nil(ns.EditModePoint(1), "falls back to the bar's old place")
    move(1, "Raid", "TOP", 0, -40)
    assert.are.same({ "TOP", "UIParent", "TOP", 0, -40 }, ns.EditModePoint(1))
    lem.layout = "Modern"
    assert.are.same({ "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 100, 50 }, ns.EditModePoint(1))
    assert.is_nil(ns.EditModePoint(2))
  end)

  it("lays the bars out again on a change of layout, and shows them all while editing", function()
    load(true, true)
    local before = refreshed
    lem.callbacks.layout("Raid", 4)
    assert.are.equal(before + 1, refreshed)
    lem.callbacks.enter()
    assert.is_true(ns.editing)
    lem.callbacks.exit()
    assert.is_false(ns.editing)
  end)

  it("copies, renames and drops a bar's place with its layout", function()
    load(true, true)
    move(1, "Modern", "LEFT", 10, 20)
    move(2, "Modern", "RIGHT", -10, 0)
    lem.callbacks.create("Copy", 4, "Modern")
    assert.are.same({ "LEFT", 10, 20 }, options.Bars[1].Layouts.Copy)
    assert.are.same({ "RIGHT", -10, 0 }, options.Bars[2].Layouts.Copy)
    lem.callbacks.create("Fresh", 5, nil)
    assert.is_nil(options.Bars[1].Layouts.Fresh)
    lem.callbacks.rename("Copy", "Raid", 4)
    assert.is_nil(options.Bars[1].Layouts.Copy)
    assert.are.same({ "LEFT", 10, 20 }, options.Bars[1].Layouts.Raid)
    lem.callbacks.delete("Raid")
    assert.is_nil(options.Bars[1].Layouts.Raid)
    assert.are.same({ "LEFT", 10, 20 }, options.Bars[1].Layouts.Modern)
  end)

  it("sets a bar up from its Edit Mode dialog in the same settings GSE's options show", function()
    load(true, true)
    local settings = lem.settings[ns.bars[2]]
    local byName = {}
    for _, s in ipairs(settings) do byName[s.name] = s end
    assert.are.equal("HIDE", byName["Show the bar"].get("Modern"))
    byName["Show the bar"].set("Modern", "MOUSEOVER")
    byName["Buttons per row"].set("Modern", 6)
    byName["Scale"].set("Modern", 1.25)
    byName["Button spacing"].set("Modern", 8)
    assert.are.equal("MOUSEOVER", options.Bars[2].Visibility)
    assert.are.equal(6, options.Bars[2].PerRow)
    assert.are.equal(1.25, options.Bars[2].Scale)
    assert.are.equal(8, options.Spacing)
    assert.are.equal("SHOW", options.Bars[1].Visibility, "the other bar is untouched")
  end)

  local function readSource(path)
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
  end

  it("loads LibEditMode on Retail and Forever only, before the bar", function()
    local toc = readSource("GSE_Actionbar/GSE_Actionbar.toc")
    local lib = toc:find("Lib\\LibEditMode\\embed.xml [AllowLoadGameType standard, camelot]\n", 1, true)
    assert.truthy(lib)
    assert.truthy(lib < toc:find("\nBootstrap.lua\n", 1, true))
    assert.truthy(toc:find("\nActionBar.lua\nEditMode.lua\n", 1, true))
    -- Not in git, as GSE's other libraries: the packager fetches it.
    assert.truthy(readSource(".pkgmeta"):find("GSE/GSE_Actionbar/Lib/LibEditMode:", 1, true))
  end)
end)
