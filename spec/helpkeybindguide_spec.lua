-- GSE's in-game help is an AddOn of its own, GSE_Help (Tim, on #2235: "this
-- may need to go into its own mod folder eg gse_help so that the user can
-- choose for it to not be loaded from the addons list or be load on demand so
-- it doesn't add more to the loading screen"; Larry, 2026-11-22: "start a
-- gse_help folder and put the help keybind stuff in it").
--
-- It holds the keybind guide: one picture of the steps that put a sequence on
-- an action button and a key on it, shown in the Editor's Keybind tab. GSE
-- loads the AddOn the first time help is asked for (GSE.CheckHelp), and the
-- guide is built the first time it is shown.
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
  local largePixels = tonumber(guide:match("local KEYBIND_GUIDE_LARGE_PIXELS%s*=%s*(%d+)"))
  local LARGE = "Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuideLarge.png"

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

  -- A lit step is drawn from the picture as it was made, a quarter larger
  -- (Larry, 2026-11-23: "can we make the area grow some and bit less fuzzy?").
  it("ships the larger picture a lit step is drawn from, at the size the code says", function()
    assert.truthy(guide:find('local KEYBIND_GUIDE_LARGE_TEXTURE = "Interface\\\\AddOns\\\\GSE_Help\\\\Assets\\\\KeybindGuideLarge.png"', 1, true))
    local fh = assert(io.open("GSE_Help/Assets/KeybindGuideLarge.png", "rb"), "the larger picture is not in GSE_Help/Assets")
    local head = fh:read(24)
    fh:close()
    local function be32(at) local a, b, c, d = head:byte(at, at + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
    assert.are.equal(largePixels, be32(17))
    assert.are.equal(largePixels, be32(21))
    assert.is_true(largePixels > pixels)
  end)

  -- A tab opens no window of its own (Larry, 2026-11-23): the guide is a
  -- picture in the Editor's Keybind tab.
  it("has no window of its own", function()
    assert.is_nil(guide:find("PortraitFrameTemplate", 1, true))
    assert.is_nil(guide:find("UISpecialFrames", 1, true))
    assert.is_nil(guide:find("ToggleKeybindGuide", 1, true))
    assert.truthy(guide:find("if GetPhysicalScreenSize then", 1, true), "not on every client")
  end)

  -- Run with frames that record what is done to them.
  describe("shown in a page", function()
    local gse, created, frame, lines, parts, saved
    local screenHeight, scale = 1440, 0.65

    local function newFrame(parent)
      local f = { shown = true, scripts = {}, parent = parent, spots = {} }
      function f:SetScript(name, fn) self.scripts[name] = fn end
      function f:SetParent(p) self.parent = p end
      function f:ClearAllPoints() end
      function f:EnableMouse(on) self.mouse = on end
      function f:EnableMouseWheel(on) self.wheel = on end
      function f:SetPoint(...) self.point = { ... } end
      function f:SetSize(width, height) self.width, self.height = width, height end
      function f:SetAllPoints(p) self.fills = p end
      function f:SetFrameLevel(level) self.level = level end
      function f:GetWidth() return self.fills and self.fills.w or 0 end
      function f:GetHeight() return self.fills and self.fills.h or 0 end
      function f:GetEffectiveScale() return scale end
      -- Where the page is on the screen, in its units: set by a test.
      function f:GetLeft() return self.left end
      function f:GetTop() return self.top end
      function f:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
      end
      function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
      end
      function f:CreateTexture(_, layer, _, sublevel)
        local texture = { layer = layer, shown = true, ClearAllPoints = function() end,
          SetPoint = function(t, ...) t.point = { ... } end,
          SetAllPoints = function(t, over) t.fills = over or true end,
          SetColorTexture = function(t, r, g, b, a) t.colour = { r, g, b, a } end,
          SetTexture = function(t, path) t.path = path or false end,
          SetTexCoord = function(t, ...) t.coords = { ... } end,
          SetSize = function(t, width, height) t.width, t.height = width, height end,
          GetWidth = function(t) return t.width end,
          GetHeight = function(t) return t.height end,
          SetShown = function(t, on) t.shown = on end,
          Show = function(t) t.shown = true end,
          Hide = function(t) t.shown = false end }
        if layer == "BACKGROUND" then self.ground = texture
        elseif layer == "OVERLAY" then table.insert(self.spots, texture)
        elseif sublevel then self.dim = texture
        else self.picture = texture end
        return texture
      end
      return f
    end
    -- What is lit: each lit spot's box, in the pixels of the file it is drawn from.
    local function litBoxes()
      local boxes = {}
      for _, spot in ipairs(frame.spots) do
        if spot.shown then
          local c = spot.coords
          local filePixels = spot.path == LARGE and largePixels or pixels
          local function px(v) return math.floor(v * filePixels * 100 + 0.5) / 100 end
          table.insert(boxes, { px(c[1]), px(c[3]), px(c[2]), px(c[4]) })
        end
      end
      return boxes
    end
    local function page(w, h) return { w = w, h = h, GetFrameLevel = function() return 5 end } end

    before_each(function()
      saved = { CreateFrame = _G.CreateFrame, UIParent = _G.UIParent, GetPhysicalScreenSize = _G.GetPhysicalScreenSize }
      created, screenHeight, lines, parts = 0, 1440, {}, {}
      _G.CreateFrame = function(_, _, parent)
        local f = newFrame(parent)
        -- The guide's own children: the eight lines of its list, then the
        -- steps' parts of the picture.
        if created > 0 and parent == frame then
          table.insert(#lines < 8 and lines or parts, f)
        else
          created = created + 1
          frame = f
        end
        return f
      end
      _G.UIParent = { name = "UIParent" }
      _G.GetPhysicalScreenSize = function() return 5120, screenHeight end

      local ns = {}
      assert(loadfile("GSE_Help/Bootstrap.lua"))("GSE_Help", ns)
      assert(loadfile("GSE_Help/KeybindGuide.lua"))("GSE_Help", ns)
      gse = {}
      _G.GSE_Help_Initialize(gse)
    end)

    after_each(function()
      _G.CreateFrame, _G.UIParent, _G.GetPhysicalScreenSize = saved.CreateFrame, saved.UIParent, saved.GetPhysicalScreenSize
      _G.GSE_Help_Initialize = nil
    end)

    it("builds nothing until it is asked for", function()
      assert.are.equal(0, created)
      assert.are.equal("function", type(gse.ShowKeybindGuideIn))
      gse.HideKeybindGuide()
      assert.are.equal(0, created)
    end)

    it("fills the page that asks for it, the picture one file pixel to a screen pixel where there is room", function()
      local big = page(2000, 2000)
      gse.ShowKeybindGuideIn(big)
      assert.are.equal(big, frame.parent)
      assert.are.equal(big, frame.fills)
      assert.are.equal(6, frame.level)
      assert.are.equal("Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png", frame.picture.path)
      local onScreen = frame.picture.width * scale * screenHeight / 768
      assert.is_true(math.abs(onScreen - pixels) < 0.001, "the game would resize the picture: " .. onScreen)
      assert.are.equal(frame.picture.width, frame.picture.height)
    end)

    it("fills what the page has beyond the picture with black", function()
      gse.ShowKeybindGuideIn(page(2000, 1200))
      assert.is_true(frame.ground.fills)
      assert.are.same({ 0, 0, 0, 1 }, frame.ground.colour)
    end)

    it("is no larger than the page has room for, and follows the page's size", function()
      local small = page(500, 300)
      gse.ShowKeybindGuideIn(small)
      assert.are.equal(300 - 16, frame.picture.width)
      assert.are.equal(frame.picture.width, frame.picture.height)
      small.w, small.h = 200, 400
      frame.scripts.OnSizeChanged(frame)
      assert.are.equal(200 - 16, frame.picture.width)
    end)

    it("leaves the page when told to, holding the picture only while it shows, and is built once", function()
      local first, second = page(900, 900), page(700, 700)
      gse.ShowKeybindGuideIn(first)
      gse.HideKeybindGuide()
      assert.is_false(frame.shown)
      assert.is_false(frame.picture.path)
      assert.are.equal(_G.UIParent, frame.parent, "not left on a page that is reused")
      gse.ShowKeybindGuideIn(second)
      assert.is_true(frame.shown)
      assert.are.equal(second, frame.parent)
      assert.truthy(frame.picture.path)
      assert.are.equal(1, created)
    end)

    -- Larry, 2026-11-23: "when I mouse over a line highlight that step".
    it("has a line to point at for each step of the picture's list, placed on the picture", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      assert.are.equal(8, #lines)
      local s = frame.picture.width / pixels
      for step, line in ipairs(lines) do
        assert.is_true(line.mouse)
        assert.are.equal(frame.picture, line.point[2])
        assert.is_true(math.abs(line.point[4] - 40 * s) < 0.001)
        assert.is_true(math.abs(line.point[5] + (542 + (step - 1) * 27.25) * s) < 0.001, "line " .. step)
        assert.is_true(math.abs(line.width - 420 * s) < 0.001)
        assert.is_true(math.abs(line.height - 27.25 * s) < 0.001)
      end
      assert.is_false(frame.dim.shown, "nothing is dark until a line is pointed at")
      assert.are.same({}, litBoxes())
    end)

    it("pointing at a line darkens the picture and lights that line and its step", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      lines[6].scripts.OnEnter()
      assert.is_true(frame.dim.shown)
      assert.are.equal(frame.picture, frame.dim.fills)
      assert.are.same({ 0, 0, 0, 0.6 }, frame.dim.colour)
      -- The line as it is in the picture; the step's two boxes from the larger
      -- file, a quarter larger (260,366,405,452 and 405,372,562,418 there).
      assert.are.same({
        { 40, 542 + 5 * 27.25, 460, 542 + 6 * 27.25 },
        { 325, 458, 506, 565 },
        { 506, 465, 703, 523 },
      }, litBoxes())
      local s = frame.picture.width / pixels
      local function near(want, got, what) assert.is_true(math.abs(want - got) < 0.001, what .. ": " .. got) end
      local line, first, second = frame.spots[1], frame.spots[2], frame.spots[3]
      assert.are.equal("Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png", line.path)
      assert.are.equal(LARGE, first.path)
      assert.are.equal(LARGE, second.path)
      for _, spot in ipairs(frame.spots) do
        assert.are.equal("OVERLAY", spot.layer)
        assert.are.equal(frame.picture, spot.point[2])
      end
      near(40 * s, line.point[4], "the line stays where it is")
      near(420 * s, line.width, "and the size it is")
      -- The step grows about its middle: 260..562 becomes 222..600.
      near(222 * s, first.point[4], "left")
      near(-356 * s, first.point[5], "top")
      near(403 * s, second.point[4], "the second box still meets the first")
      near(-363 * s, second.point[5], "top of the second")
      near(181, first.width * scale * screenHeight / 768, "one file pixel to a screen pixel")
      near(107, first.height * scale * screenHeight / 768, "one file pixel to a screen pixel, down")
    end)

    it("lights only what the step has, and puts the picture back when the line is left", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      lines[1].scripts.OnEnter()
      assert.are.same({ { 40, 542, 460, 569.25 }, { 18, 190, 356, 283 } }, litBoxes())
      assert.is_false(frame.spots[3].shown, "a spot not in use is not shown")
      assert.are.equal(0, frame.spots[2].point[4], "a step at the picture's edge grows inward, not off it")
      lines[1].scripts.OnLeave()
      assert.is_false(frame.dim.shown)
      assert.are.same({}, litBoxes())
    end)

    it("keeps the next line lit when the one before is left after it", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      lines[1].scripts.OnEnter()
      lines[2].scripts.OnEnter()
      lines[1].scripts.OnLeave()
      assert.is_true(frame.dim.shown)
      assert.are.equal(390, litBoxes()[2][1])
    end)

    -- Larry, 2026-11-23: "add mouseover effect also if the user mouses over
    -- that part of the image".
    it("lights a step from its own part of the picture too, where it is drawn", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      assert.are.equal(11, #parts, "one for each box of each step")
      local s = frame.picture.width / pixels
      local function near(want, got, what) assert.is_true(math.abs(want - got) < 0.001, what .. ": " .. got) end
      -- Step 2 has two boxes, its menu and the hand under it.
      local menu, hand = parts[2], parts[3]
      assert.is_true(menu.mouse)
      assert.are.equal(frame.picture, menu.point[2])
      near(312 * s, menu.point[4], "left")
      near(-34 * s, menu.point[5], "top")
      near((457 - 312) * s, menu.width, "width: not grown")
      near((222 - 34) * s, menu.height, "height")
      menu.scripts.OnEnter()
      assert.are.equal(390, litBoxes()[2][1], "step 2 is lit")
      -- On to the step's other box, which may be entered before the first is left.
      hand.scripts.OnEnter()
      menu.scripts.OnLeave()
      assert.is_true(frame.dim.shown, "still lit on the step's other box")
      hand.scripts.OnLeave()
      assert.is_false(frame.dim.shown)
      parts[1].scripts.OnEnter()
      assert.are.same({ { 40, 542, 460, 569.25 }, { 18, 190, 356, 283 } }, litBoxes())
    end)

    it("every step's boxes are inside the picture, clear of its list, and drawn on the picture in whole pixels", function()
      gse.ShowKeybindGuideIn(page(2000, 2000))
      local s = frame.picture.width / pixels
      local grow = largePixels / pixels
      for step, line in ipairs(lines) do
        line.scripts.OnEnter()
        local boxes = litBoxes()
        assert.is_true(#boxes >= 2, "step " .. step .. " lights nothing in the picture")
        for i, box in ipairs(boxes) do
          local what = "step " .. step .. " box " .. i
          local filePixels = i == 1 and pixels or largePixels
          assert.is_true(box[1] >= 0 and box[1] < box[3] and box[3] <= filePixels, what)
          assert.is_true(box[2] >= 0 and box[2] < box[4] and box[4] <= filePixels, what)
          if i > 1 then
            assert.is_true(box[4] <= 542 * grow or box[1] >= 460 * grow, what .. " lights part of the list")
            local spot = frame.spots[i]
            local left, top = spot.point[4] / s, -spot.point[5] / s
            local right, bottom = left + spot.width / s, top + spot.height / s
            assert.is_true(left > -0.001 and top > -0.001 and right < pixels + 0.001 and bottom < pixels + 0.001, what .. " is drawn off the picture")
            for _, edge in ipairs({ left, top, right, bottom }) do
              assert.is_true(math.abs(edge - math.floor(edge + 0.5)) < 0.001, what .. " is drawn between pixels: " .. edge)
            end
          end
        end
      end
    end)

    it("follows the page's size while a step is lit, and goes out when the guide is hidden", function()
      local small = page(900, 900)
      gse.ShowKeybindGuideIn(small)
      lines[8].scripts.OnEnter()
      small.w, small.h = 416, 416
      frame.scripts.OnSizeChanged(frame)
      assert.are.equal(400, frame.picture.width)
      assert.are.equal(454 / 2, frame.spots[2].point[4])
      assert.are.equal(340 / 2, frame.spots[2].width)
      gse.HideKeybindGuide()
      assert.is_false(frame.dim.shown)
      assert.are.same({}, litBoxes())
      for _, spot in ipairs(frame.spots) do assert.is_false(spot.path) end
    end)

    -- Larry, 2026-11-24: "when the user mouses over it when its small they can
    -- zoom in on the image parts and move it around as needed", and "the black
    -- sides should go way when small".
    describe("zoomed and dragged", function()
      local cursor, buttonDown, savedCursor, savedButton
      local SMALL = "Interface\\AddOns\\GSE_Help\\Assets\\KeybindGuide.png"
      local function near(want, got, what) assert.is_true(math.abs(want - got) < 0.001, (what or "") .. ": " .. tostring(got)) end
      local function viewBox()
        local c = frame.picture.coords
        return { c[1] * pixels, c[3] * pixels, c[2] * pixels, c[4] * pixels }
      end
      local function sameBox(want, got, what)
        for i = 1, 4 do near(want[i], got[i], (what or "view") .. " " .. i) end
      end
      -- The picture hangs from the middle of the page's top, 8 down.
      local function pictureCorner()
        return frame.left + (500 - frame.picture.width) / 2, frame.top - 8
      end
      -- The cursor at a share across and down the picture.
      local function pointAt(across, down)
        local left, top = pictureCorner()
        cursor.x, cursor.y = left + across * frame.picture.width, top - down * frame.picture.height
      end
      -- The file's pixel under the cursor.
      local function underCursor()
        local left, top = pictureCorner()
        local box = viewBox()
        return box[1] + (cursor.x - left) / frame.picture.width * (box[3] - box[1]),
          box[2] + (top - cursor.y) / frame.picture.height * (box[4] - box[2])
      end
      local function wheel(delta) frame.scripts.OnMouseWheel(frame, delta) end
      local function show()
        gse.ShowKeybindGuideIn(page(500, 300))
        frame.left, frame.top = 100, 500
      end

      before_each(function()
        cursor, buttonDown = { x = 0, y = 0 }, false
        savedCursor, savedButton = _G.GetCursorPosition, _G.IsMouseButtonDown
        -- The game gives the cursor in screen units, the page's times its scale.
        _G.GetCursorPosition = function() return cursor.x * scale, cursor.y * scale end
        _G.IsMouseButtonDown = function(button) return button == "LeftButton" and buttonDown end
      end)

      after_each(function()
        _G.GetCursorPosition, _G.IsMouseButtonDown = savedCursor, savedButton
      end)

      it("takes the wheel and the mouse, and is whole until zoomed", function()
        show()
        assert.is_true(frame.wheel)
        assert.is_true(frame.mouse)
        sameBox({ 0, 0, 800, 800 }, viewBox())
        assert.are.same({ 284, 284 }, { frame.picture.width, frame.picture.height })
      end)

      it("zooms about the point under the cursor, spreading across the page before it is cut", function()
        show()
        pointAt(0.5, 0.5)
        wheel(1)
        -- A quarter larger: 355 wide, still the whole width of the picture;
        -- the page's height cuts it.
        near(355, frame.picture.width, "wider")
        near(284, frame.picture.height, "as high as the page has room for")
        sameBox({ 0, 80, 800, 720 }, viewBox())
        assert.are.equal(LARGE, frame.picture.path)
        -- Wider still, until the page's width holds it; while the whole width
        -- of the picture shows, the point across can only stay where it is.
        wheel(1)
        pointAt(0.3, 0.7)
        local x, y = underCursor()
        wheel(1)
        near(484, frame.picture.width, "the page's whole width: no black sides")
        local x2, y2 = underCursor()
        near(x, x2, "the same point across")
        near(y, y2, "and down")
      end)

      it("goes no further in than one pixel of the larger file to a screen pixel, and back out to the whole picture", function()
        show()
        pointAt(0.5, 0.5)
        for _ = 1, 30 do wheel(1) end
        local box = viewBox()
        local screenPerFilePixel = frame.picture.width / (box[3] - box[1]) * scale * screenHeight / 768
        near(largePixels / pixels, screenPerFilePixel, "screen pixels to a pixel of the picture")
        for _ = 1, 30 do wheel(-1) end
        sameBox({ 0, 0, 800, 800 }, viewBox())
        assert.are.same({ 284, 284 }, { frame.picture.width, frame.picture.height })
        assert.are.equal(SMALL, frame.picture.path)
      end)

      it("leaves the wheel alone off the picture", function()
        show()
        cursor.x, cursor.y = 0, 0
        wheel(1)
        sameBox({ 0, 0, 800, 800 }, viewBox())
      end)

      it("drags with the left button while zoomed, no further than the picture's edge", function()
        show()
        pointAt(0.5, 0.5)
        frame.scripts.OnMouseDown(frame, "LeftButton")
        assert.is_nil(frame.scripts.OnUpdate, "not while the whole picture shows")
        for _ = 1, 3 do wheel(1) end
        local before = viewBox()
        local perUnit = (before[3] - before[1]) / frame.picture.width
        buttonDown = true
        pointAt(0.5, 0.5)
        frame.scripts.OnMouseDown(frame, "LeftButton")
        local drag = assert(frame.scripts.OnUpdate)
        -- 10 left and 5 down on the page moves the view right and up.
        cursor.x, cursor.y = cursor.x - 10, cursor.y - 5
        drag(frame)
        near(before[1] + 10 * perUnit, viewBox()[1], "left")
        near(before[2] - 5 * perUnit, viewBox()[2], "top")
        cursor.x = cursor.x - 1000
        drag(frame)
        near(800, viewBox()[3], "stops at the right edge")
        frame.scripts.OnMouseUp(frame, "LeftButton")
        assert.is_nil(frame.scripts.OnUpdate)
        -- From a step's part of the picture too; a button let go anywhere ends it.
        pointAt(0.5, 0.5)
        parts[1].scripts.OnMouseDown(parts[1], "LeftButton")
        assert.truthy(frame.scripts.OnUpdate)
        buttonDown = false
        frame.scripts.OnUpdate(frame)
        assert.is_nil(frame.scripts.OnUpdate)
        frame.scripts.OnMouseDown(frame, "RightButton")
        assert.is_nil(frame.scripts.OnUpdate, "the right button drags nothing")
      end)

      it("puts the lines and the steps' parts where they are, cut to what shows", function()
        show()
        pointAt(0.5, 0.5)
        wheel(1)
        sameBox({ 0, 80, 800, 720 }, viewBox())
        local s = frame.picture.width / 800
        near(40 * s, lines[1].point[4], "left")
        near(-(542 - 80) * s, lines[1].point[5], "top")
        near(420 * s, lines[1].width, "width")
        near((720 - 705.5) * s, lines[7].height, "cut at the bottom")
        assert.is_false(lines[8].shown, "out of view")
        wheel(-1)
        assert.is_true(lines[8].shown, "back in view")
      end)

      it("draws a lit step's part that shows, at the size it is shown", function()
        show()
        pointAt(0, 0)
        for _ = 1, 3 do wheel(1) end
        local box = viewBox()
        near(0, box[1], "left")
        near(0, box[2], "top")
        local s = frame.picture.width / (box[3] - box[1])
        for step, line in ipairs(lines) do
          line.scripts.OnEnter()
          for i, spot in ipairs(frame.spots) do
            if spot.shown then
              local what = "step " .. step .. " spot " .. i
              local c = spot.coords
              local filePixels = spot.path == LARGE and largePixels or pixels
              near((c[2] - c[1]) * filePixels * s, spot.width, what .. " width")
              near((c[4] - c[3]) * filePixels * s, spot.height, what .. " height")
              assert.is_true(spot.point[4] > -0.001 and spot.point[4] + spot.width < frame.picture.width + 0.001, what .. " across")
              assert.is_true(spot.point[5] < 0.001 and -spot.point[5] + spot.height < frame.picture.height + 0.001, what .. " down")
            end
          end
          line.scripts.OnLeave()
        end
        -- Step 4's grown box runs past the view's right edge: it is cut there.
        lines[4].scripts.OnEnter()
        near(frame.picture.width, frame.spots[2].point[4] + frame.spots[2].width, "cut at the right")
      end)

      it("comes back whole after it is hidden", function()
        show()
        pointAt(0.5, 0.5)
        wheel(2)
        gse.HideKeybindGuide()
        show()
        sameBox({ 0, 0, 800, 800 }, viewBox())
        assert.are.same({ 284, 284 }, { frame.picture.width, frame.picture.height })
        assert.are.equal(SMALL, frame.picture.path)
      end)
    end)
  end)
end)
