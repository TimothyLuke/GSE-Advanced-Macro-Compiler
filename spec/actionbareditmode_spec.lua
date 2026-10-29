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
    function fake:AddFrameSettingsButtons(frame, buttons) self.buttons = self.buttons or {}; self.buttons[frame] = buttons end
    function fake:RefreshFrameSettings() end
    function fake:RegisterCallback(event, callback) self.callbacks[event] = callback end
    function fake:GetActiveLayoutName() return self.layout end
    return fake
  end

  -- Blizzard's names for a bar's Edit Mode settings, which the box uses.
  local HUD = {
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION = "Orientation",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_HORIZONTAL = "Horizontal",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_VERTICAL = "Vertical",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS = "# of Rows",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS = "# of Columns",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ICONS = "# of Icons",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_SIZE = "Icon Size",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_PADDING = "Icon Padding",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING = "Bar Visible",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_ALWAYS = "Always",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_IN_COMBAT = "In Combat",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_OUT_OF_COMBAT = "Out of Combat",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_VISIBLE_SETTING_HIDDEN = "Hidden",
    HUD_EDIT_MODE_SETTING_ACTION_BAR_ALWAYS_SHOW_BUTTONS = "Always Show Buttons",
    HUD_EDIT_MODE_REVERT_CHANGES = "Revert Changes",
  }

  local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = deepCopy(v) end
    return copy
  end

  local function load(withLib)
    lem = withLib and fakeLEM() or nil
    local saved = { LibStub = _G.LibStub, hooksecurefunc = _G.hooksecurefunc, CopyTable = _G.CopyTable,
      GSE_Actionbar_Initialize = _G.GSE_Actionbar_Initialize }
    for k in pairs(HUD) do saved[k] = _G[k] end
    _G.LibStub = function(name, silent)
      assert(name == "LibEditMode" and silent)
      return lem
    end
    _G.hooksecurefunc = function(t, key, hook)
      local own = t[key]
      t[key] = function(...) own(...); hook(...) end
    end
    _G.CopyTable = deepCopy
    for k, v in pairs(HUD) do _G[k] = v end
    -- The bars' settings as they were saved when padding, empty buttons and
    -- keys were one setting for every bar, and the bars had a lock.
    options = { Spacing = 4, ShowEmpty = true, ShowKeys = true, Locked = true,
      Bars = { { Visibility = "SHOW", Scale = 1, PerRow = 12 }, { Visibility = "HIDE", Scale = 1, PerRow = 12 } } }
    _G.GSEOptions = { ActionBar = options }
    refreshed = 0
    ns = {
      deferred = {},
      bars = { {}, {} },
      DEFAULT_POINTS = { { "BOTTOM", "UIParent", "BOTTOM", 0, 230 }, { "BOTTOM", "UIParent", "BOTTOM", 0, 276 } },
      Refresh = function() refreshed = refreshed + 1 end,
      SetEditing = function(open) ns.editing = open end,
      GSE = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
      },
    }
    -- The bar's sizes, settings and line arithmetic come from Bootstrap.lua.
    assert(loadfile("GSE_Actionbar/Bootstrap.lua"))("GSE_Actionbar", ns)
    assert(loadfile("GSE_Actionbar/EditMode.lua"))("GSE_Actionbar", ns)
    ns.deferred[1]()
    ns.Options()
    -- Put back what other specs see. The settings read Blizzard's names as
    -- they are built, so those can go too.
    for k in pairs(saved) do _G[k] = saved[k] end
  end

  local function settingsOf(b)
    local byName = {}
    for _, s in ipairs(lem.settings[ns.bars[b]]) do byName[s.name] = s end
    return byName
  end

  local function move(b, layout, point, x, y)
    local bar = ns.bars[b]
    lem.frames[bar].callback(bar, layout, point, x, y)
  end

  it("registers each bar, starting where the bar starts", function()
    load(true)
    local first = lem.frames[ns.bars[1]]
    assert.are.same({ point = "BOTTOM", x = 0, y = 230 }, first.default)
    assert.are.equal("GSE Action Bar 1", first.name)
    assert.are.equal("GSE Action Bar 2", lem.frames[ns.bars[2]].name)
    assert.are.equal(8, #lem.settings[ns.bars[1]])
  end)

  it("puts the bars in Edit Mode on every client, with no lock", function()
    -- Every client has Edit Mode: no client test, only the library.
    load(false)
    assert.is_nil(ns.EditModePoint)
    load(true)
    assert.truthy(ns.EditModePoint)
    assert.is_nil(options.Locked)
  end)

  it("keeps a bar's place per layout, and has none for a layout it was never placed in", function()
    load(true)
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
    load(true)
    local before = refreshed
    lem.callbacks.layout("Raid", 4)
    assert.are.equal(before + 1, refreshed)
    lem.callbacks.enter()
    assert.is_true(ns.editing)
    lem.callbacks.exit()
    assert.is_false(ns.editing)
  end)

  it("copies, renames and drops a bar's place with its layout", function()
    load(true)
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

  it("sets a bar up from Blizzard's own action bar settings, in the settings GSE's options show", function()
    load(true)
    local set = settingsOf(2)
    assert.are.equal(8, #lem.settings[ns.bars[2]])
    assert.are.equal("HIDE", set["Bar Visible"].get("Modern"))
    set["Bar Visible"].set("Modern", "INCOMBAT")
    assert.are.equal("INCOMBAT", options.Bars[2].Visibility)
    set["Orientation"].set("Modern", "VERTICAL")
    assert.are.equal("VERTICAL", options.Bars[2].Orientation)
    -- Icon Size is the bar's Scale, in percent.
    assert.are.equal(100, set["Icon Size"].get("Modern"))
    set["Icon Size"].set("Modern", 150)
    assert.are.equal(1.5, options.Bars[2].Scale)
    set["Icon Padding"].set("Modern", 8)
    assert.are.equal(8, options.Bars[2].Spacing)
    set["Show empty buttons"].set("Modern", false)
    assert.is_false(options.Bars[2].ShowEmpty)
    set["Show keys"].set("Modern", false)
    assert.is_false(options.Bars[2].ShowKeys)
    -- The other bar is untouched.
    assert.are.equal("SHOW", options.Bars[1].Visibility)
    assert.are.equal(4, options.Bars[1].Spacing)
    assert.is_true(options.Bars[1].ShowEmpty)
    assert.is_true(options.Bars[1].ShowKeys)
  end)

  it("gives each bar the padding, empty buttons and keys once set for every bar", function()
    load(true)
    assert.is_nil(options.Spacing)
    assert.is_nil(options.ShowEmpty)
    for b = 1, 2 do
      assert.are.equal(4, options.Bars[b].Spacing)
      assert.is_true(options.Bars[b].ShowEmpty)
      assert.is_true(options.Bars[b].ShowKeys)
    end
  end)

  it("speaks in lines, as Blizzard's bars do, and keeps buttons per line for GSE's options", function()
    load(true)
    local set = settingsOf(1)
    local lines = set["# of Rows"]
    assert.are.equal(1, lines.get("Modern"))
    lines.set("Modern", 3)
    assert.are.equal(4, options.Bars[1].PerRow, "twelve buttons in three rows")
    -- Fewer buttons keep the rows they had.
    set["# of Icons"].set("Modern", 6)
    assert.are.equal(6, options.Bars[1].Icons)
    assert.are.equal(2, options.Bars[1].PerRow)
    assert.are.equal(3, lines.get("Modern"))
  end)

  it("puts the bars back as they were when Edit Mode opened", function()
    load(true)
    lem.callbacks.enter()
    settingsOf(1)["Icon Padding"].set("Modern", 12)
    settingsOf(2)["Bar Visible"].set("Modern", "SHOW")
    local revert = lem.buttons[ns.bars[1]][1]
    assert.are.equal("Revert Changes", revert.text)
    revert.click()
    assert.are.equal(4, ns.Options().Bars[1].Spacing)
    assert.are.equal("HIDE", ns.Options().Bars[2].Visibility)
  end)

  local function readSource(path)
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
  end

  it("loads LibEditMode on every client, before the bar", function()
    local toc = readSource("GSE_Actionbar/GSE_Actionbar.toc")
    local lib = toc:find("\nLib\\LibEditMode\\embed.xml\n", 1, true)
    assert.truthy(lib)
    assert.truthy(lib < toc:find("\nBootstrap.lua\n", 1, true))
    assert.truthy(toc:find("\nActionBar.lua\nEditMode.lua\n", 1, true))
    -- Not in git, as GSE's other libraries: the packager fetches it. Externals
    -- land at .release/GSE/<key>, and GSE_Actionbar sits at .release/GSE/GSE_Actionbar
    -- -- a GSE/ prefix would bury the library inside the GSE addon instead.
    assert.truthy(readSource(".pkgmeta"):find("\n  GSE_Actionbar/Lib/LibEditMode:\n", 1, true))
  end)
end)
