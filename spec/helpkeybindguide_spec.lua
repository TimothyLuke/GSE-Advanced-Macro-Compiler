-- GSE's in-game help is an AddOn of its own, GSE_Help (Tim, on #2235: "this
-- may need to go into its own mod folder eg gse_help so that the user can
-- choose for it to not be loaded from the addons list or be load on demand so
-- it doesn't add more to the loading screen"; Larry, 2026-11-22: "start a
-- gse_help folder and put the help keybind stuff in it").
--
-- It holds the keybind guide: one picture of the steps that put a sequence on
-- an action button and a key on it, in Blizzard's own portrait window. GSE
-- loads the AddOn the first time help is asked for (GSE.CheckHelp), and the
-- guide's window is built the first time it is opened.
local function readSource(path)
  local fh = assert(io.open(path, "rb"), path .. " is missing")
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function body(src, startText, endText)
  local s = assert(src:find(startText, 1, true), "start not found: " .. startText)
  local _, e = src:find(endText, s, true)
  assert(e, "end not found: " .. endText)
  return src:sub(s, e)
end

describe("GSE_Help, the AddOn GSE's help is in", function()
  local toc = readSource("GSE_Help/GSE_Help.toc")

  it("is loaded on demand and needs only GSE", function()
    assert.truthy(toc:find("\n## LoadOnDemand: 1\n", 1, true))
    assert.truthy(toc:find("\n## Dependencies: GSE\n", 1, true))
    assert.truthy(toc:find("\n## Version: @project-version@\n", 1, true))
  end)

  it("is for every client GSE is for", function()
    local interface = assert(readSource("GSE/GSE.toc"):match("## Interface: [^\n]+\n"))
    assert.truthy(toc:find(interface, 1, true), "its Interface line is not GSE's")
  end)

  it("lists files that are there, Bootstrap first", function()
    local files = {}
    for line in toc:gmatch("[^\n]+") do
      if line:find("%.lua$") then table.insert(files, line) end
    end
    assert.are.same({ "Bootstrap.lua", "KeybindGuide.lua" }, files)
    for _, file in ipairs(files) do readSource("GSE_Help/" .. file) end
  end)

  it("is packaged beside GSE's other AddOns", function()
    assert.truthy(readSource(".pkgmeta"):find("\n  GSE/GSE_Help: GSE_Help\n", 1, true))
    assert.truthy(readSource("patreonBuild.js"):find('async.apply(updateToc, "GSE_Help", "GSE_Help")', 1, true))
  end)

  it("is handed GSE's table when it loads, and loaded when help is asked for", function()
    local submodules = body(readSource("GSE/API/Init.lua"), "local SUBMODULES = {", "\n}\n")
    assert.truthy(submodules:find("\n    GSE_Help = true,\n", 1, true))
    local check = body(readSource("GSE/API/Events.lua"), "function GSE.CheckHelp()", "\nend\n")
    assert.truthy(check:find('local loaded, reason = C_AddOns.LoadAddOn("GSE_Help")', 1, true))
    assert.truthy(check:find([[GSE.Print(string.format(L["GSE's help could not be loaded: %s"], tostring(reason)))]], 1, true),
      "a help AddOn that is off or missing is said in chat")
    assert.truthy(check:find("    return loaded\n", 1, true))
    assert.truthy(readSource("GSE/Localization/ModL_enUS.lua"):find([[L["GSE's help could not be loaded: %s"] = true]], 1, true))
  end)

  it("takes GSE's table once and runs what its files queued", function()
    local ns, ran = {}, 0
    assert(loadfile("GSE_Help/Bootstrap.lua"))("GSE_Help", ns)
    table.insert(ns.deferred, function() ran = ran + 1 end)
    local gse = {}
    _G.GSE_Help_Initialize(gse)
    _G.GSE_Help_Initialize({})
    assert.are.equal(gse, ns.GSE)
    assert.are.equal(1, ran)
    _G.GSE_Help_Initialize = nil
  end)
end)

describe("the keybind guide", function()
  local guide = readSource("GSE_Help/KeybindGuide.lua")
  local pixels = tonumber(guide:match("local KEYBIND_GUIDE_PIXELS%s*=%s*(%d+)"))

  it("shows a picture that ships in GSE_Help, at the size the code says", function()
    assert.truthy(guide:find('local KEYBIND_GUIDE_TEXTURE = "Interface\\\\AddOns\\\\GSE_Help\\\\Assets\\\\KeybindGuide.png"', 1, true))
    local fh = assert(io.open("GSE_Help/Assets/KeybindGuide.png", "rb"), "the picture is not in GSE_Help/Assets")
    local head = fh:read(24)
    fh:close()
    assert.are.equal("\137PNG\r\n\26\n", head:sub(1, 8))
    local function be32(at) local a, b, c, d = head:byte(at, at + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
    assert.are.equal(pixels, be32(17), "KEYBIND_GUIDE_PIXELS is the picture's width")
    assert.are.equal(pixels, be32(21), "and its height: the picture is square")
    assert.is_nil(io.open("GSE_GUI/Assets/KeybindGuide.png", "rb"), "a second copy is left in GSE_GUI")
  end)

  it("is not in GSE's menu file any more: the menu asks GSE's help for it", function()
    local menu = readSource("GSE_GUI/Menu.lua")
    assert.is_nil(menu:find("KeybindGuide.png", 1, true))
    assert.is_nil(menu:find("PortraitFrameTemplate", 1, true))
    assert.truthy(menu:find("elseif GSE.CheckHelp() and GSE.ToggleKeybindGuide then\n                GSE.ToggleKeybindGuide()", 1, true))
  end)

  it("asks for what is not on every client's window template or client", function()
    for _, method in ipairs({ "SetPortraitToAsset", "SetPortraitTexCoord", "SetTitleOffsets", "SetTitle" }) do
      assert.truthy(guide:find("if keybindGuide." .. method .. " then keybindGuide:" .. method .. "(", 1, true),
        method .. " is not on every client's template")
    end
    assert.truthy(guide:find("if keybindGuide.CloseButton then", 1, true))
    assert.truthy(guide:find("if GetPhysicalScreenSize then", 1, true))
  end)

  -- Run with a window that records what is done to it.
  describe("opened", function()
    local gse, created, frame, saved
    local screenHeight, scale = 1440, 0.65

    local function newFrame()
      local methods = {
        IsShown = function(self) return self.shown end,
        SetShown = function(self, show)
          if show == self.shown then return end
          self.shown = show
          local script = self.scripts[show and "OnShow" or "OnHide"]
          if script then script(self) end
        end,
        Hide = function(self) self:SetShown(false) end,
        SetScript = function(self, name, fn) self.scripts[name] = fn end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetTitle = function(self, title) self.title = title end,
        CreateTexture = function(self)
          self.picture = setmetatable({ SetTexture = function(texture, path) texture.path = path or false end,
            SetSize = function(texture, width, height) texture.width, texture.height = width, height end },
            { __index = function() return function() end end })
          return self.picture
        end,
      }
      local closeButton = { SetScript = function(self, _, fn) self.click = fn end }
      return setmetatable({ shown = true, scripts = {}, CloseButton = closeButton },
        { __index = function(_, key) return methods[key] or function() end end })
    end

    before_each(function()
      saved = { CreateFrame = _G.CreateFrame, UIParent = _G.UIParent, UISpecialFrames = _G.UISpecialFrames,
        GetPhysicalScreenSize = _G.GetPhysicalScreenSize, tinsert = _G.tinsert }
      created, screenHeight = 0, 1440
      _G.CreateFrame = function(_, name, _, template)
        created = created + 1
        frame = newFrame()
        frame.name, frame.template = name, template
        return frame
      end
      _G.UIParent = { GetEffectiveScale = function() return scale end,
        GetHeight = function() return 768 / scale end }
      _G.GetPhysicalScreenSize = function() return 5120, screenHeight end
      _G.UISpecialFrames = {}
      _G.tinsert = table.insert

      local ns = {}
      assert(loadfile("GSE_Help/Bootstrap.lua"))("GSE_Help", ns)
      assert(loadfile("GSE_Help/KeybindGuide.lua"))("GSE_Help", ns)
      gse = { L = { Keybindings = "Keybindings" }, Static = { Icons = { Keybindings = "key" } } }
      assert.is_nil(gse.ToggleKeybindGuide)
      _G.GSE_Help_Initialize(gse)
    end)

    after_each(function()
      _G.CreateFrame, _G.UIParent, _G.UISpecialFrames = saved.CreateFrame, saved.UIParent, saved.UISpecialFrames
      _G.GetPhysicalScreenSize, _G.tinsert = saved.GetPhysicalScreenSize, saved.tinsert
      _G.GSE_Help_Initialize = nil
    end)

    it("builds nothing until it is asked for", function()
      assert.are.equal(0, created)
      assert.are.equal("function", type(gse.ToggleKeybindGuide))
    end)

    it("is Blizzard's portrait window, closed by Escape, with the picture one file pixel to a screen pixel", function()
      gse.ToggleKeybindGuide()
      assert.are.equal("GSEKeybindGuideFrame", frame.name)
      assert.are.equal("PortraitFrameTemplate", frame.template)
      assert.are.same({ "GSEKeybindGuideFrame" }, _G.UISpecialFrames)
      assert.are.equal("Keybindings", frame.title)
      assert.are.equal("Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png", frame.picture.path)
      local onScreen = frame.picture.width * scale * screenHeight / 768
      assert.is_true(math.abs(onScreen - pixels) < 0.001, "the game would resize the picture: " .. onScreen)
      assert.are.equal(frame.picture.width, frame.picture.height)
      assert.is_true(frame.width > frame.picture.width and frame.height > frame.picture.height)
    end)

    it("is no taller than the screen has room for", function()
      screenHeight = 600
      gse.ToggleKeybindGuide()
      assert.is_true(frame.height <= 768 / scale * 0.9 + 0.001)
    end)

    it("closes when asked for again, and holds the picture only while it is open", function()
      gse.ToggleKeybindGuide()
      gse.ToggleKeybindGuide()
      assert.is_false(frame.shown)
      assert.is_false(frame.picture.path)
      gse.ToggleKeybindGuide()
      assert.is_true(frame.shown)
      assert.truthy(frame.picture.path)
      assert.are.equal(1, created, "built once")
    end)

    it("closes on its close button", function()
      gse.ToggleKeybindGuide()
      frame.CloseButton.click()
      assert.is_false(frame.shown)
    end)
  end)
end)
