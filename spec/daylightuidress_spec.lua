-- DaylightUI dresses a bar button by what is in its action slot: an empty
-- slot's shell (the border), key and edge shading are hidden, or see-through.
-- A sequence put on a button sits on an empty slot, so its icon sat bare
-- beside the bar's other icons (Larry, 2026-11-21). GSE puts DaylightUI's
-- filled look back wherever DaylightUI puts the empty one.
--
-- The code is run as Events.lua has it, against a skin that behaves as
-- DaylightUI 2.1.3's does (DaylightUI_ActionBars/Skin.lua: UpdateEmpty,
-- UpdateRange, GetParts and the parts' fields).
local function readSource(path)
  local fh = assert(io.open(path, "r"))
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("a sequence's icon on a DaylightUI button", function()
  local events = readSource("GSE/API/Events.lua")

  local function region(alpha)
    local r = { alpha = alpha }
    function r:SetAlpha(a) self.alpha = a end
    return r
  end

  -- A DaylightUI bar button on an empty slot, and the world GSE's code sees.
  -- opts.sequence: a sequence runs on the button now. opts.skin: false for a
  -- DaylightUI whose skin cannot be reached.
  local function world(opts)
    local w = { highlight = region(1) }
    local parts = { back = region(1), key = region(1), shade = region(1), L = {}, tintA = 1 }
    w.parts = parts
    local button = { attrs = { ["gse-button"] = opts.sequence and "SEQ" or nil, type = opts.sequence and "click" or "action" } }
    function button:GetAttribute(k) return self.attrs[k] end
    function button:GetHighlightTexture() return w.highlight end
    w.button = button
    -- DaylightUI's own: the empty look, hidden (its Hide empty buttons is on).
    local skin = {}
    function skin.GetParts(btn) return btn == button and parts or nil end
    function skin.UpdateEmpty()
      skin.UpdateRange()
      parts.egB, parts.egK, parts.egH = 0, 0, 0
      if w.fading then
        parts.emptyEasing = true
      else
        parts.eB, parts.eK, parts.eH = 0, 0, 0
        parts.back:SetAlpha(0)
        parts.key:SetAlpha(0)
        w.highlight:SetAlpha(0)
      end
    end
    function skin.UpdateRange() parts.shade:SetAlpha(0) end
    w.skin = skin
    local mod = { enabled = true, ns = { Skin = opts.skin ~= false and skin or nil } }
    local s = assert(events:find("-- Puts DaylightUI's filled look on a button running a sequence", 1, true))
    local e = assert(events:find("local function repaintGSEOverrideButton(button, defer)", s, true))
    local s2 = assert(events:find("-- DaylightUI dresses a button by what is in its action slot", e, true))
    local e2 = assert(events:find("-- EllesmereUI and DaylightUI route action-bar keybinds", s2, true))
    local code = events:sub(s, e - 1) .. events:sub(s2, e2 - 1)
      .. "\nreturn hookDaylightUIDress, function() return dressDaylightUIOverride end"
    local env = {
      type = type, pcall = pcall,
      _G = { DaylightUI = { GetModule = function(_, name) return name == "ActionBars" and mod or nil end } },
      overrideSequence = function(btn) return btn.attrs["gse-button"] end,
      hooksecurefunc = function(t, name, hook)
        local original = t[name]
        t[name] = function(...) original(...) hook(...) end
      end,
    }
    local chunk
    if loadstring then
      chunk = assert(loadstring(code))
      setfenv(chunk, env)
    else
      chunk = assert(load(code, "dress", "t", env))
    end
    w.hook, w.dress = chunk()
    return w
  end

  local function look(w)
    return { back = w.parts.back.alpha, key = w.parts.key.alpha, highlight = w.highlight.alpha, shade = w.parts.shade.alpha }
  end
  local FILLED = { back = 1, key = 1, highlight = 1, shade = 1 }
  local EMPTY = { back = 0, key = 0, highlight = 0, shade = 0 }

  it("has DaylightUI's filled look after each of DaylightUI's own paints", function()
    local w = world({ sequence = true })
    w.hook()
    w.skin.UpdateEmpty(w.button)
    assert.are.same(FILLED, look(w))
    -- A range or usable pass on its own turns the edge shading off again.
    w.skin.UpdateRange(w.button)
    assert.are.same(FILLED, look(w))
  end)

  it("gets it as the sequence goes on, with no paint by DaylightUI to wait for", function()
    local w = world({ sequence = true })
    w.skin.UpdateEmpty(w.button)
    assert.are.same(EMPTY, look(w))
    w.hook()
    w.dress()(w.button)
    assert.are.same(FILLED, look(w))
    local repaint = events:sub(assert(events:find("local function repaintGSEOverrideButton(button, defer)", 1, true)))
    local called = assert(repaint:find("if dressDaylightUIOverride then dressDaylightUIOverride(button) end", 1, true))
    assert.is_true(called < assert(repaint:find("local function repaintAllGSEOverrideIcons", 1, true)))
  end)

  it("leaves a fade DaylightUI has under way to end on the filled look", function()
    local w = world({ sequence = true })
    w.hook()
    w.fading = true
    w.skin.UpdateEmpty(w.button)
    assert.are.same({ 1, 1, 1 }, { w.parts.egB, w.parts.egK, w.parts.egH }, "the fade's ends")
    assert.are.equal(1, w.parts.back.alpha, "not written under the fade")
    assert.is_nil(w.parts.eB)
  end)

  it("keeps the key hidden where the bar's look hides keys", function()
    local w = world({ sequence = true })
    w.parts.L.keybind = false
    w.hook()
    w.skin.UpdateEmpty(w.button)
    assert.are.equal(0, w.parts.key.alpha)
    assert.are.equal(1, w.parts.back.alpha)
  end)

  it("leaves a button with no sequence running to DaylightUI", function()
    local w = world({ sequence = false })
    w.hook()
    w.skin.UpdateEmpty(w.button)
    assert.are.same(EMPTY, look(w))
    -- A sequence that is not the one running now: a stance's own bar is up.
    w = world({ sequence = true })
    w.button.attrs.type = "action"
    w.hook()
    w.skin.UpdateEmpty(w.button)
    assert.are.same(EMPTY, look(w))
  end)

  it("does nothing, and breaks nothing, with a DaylightUI whose skin cannot be reached", function()
    local w = world({ sequence = true, skin = false })
    w.hook()
    assert.is_nil(w.dress())
    -- Or one that answers GSE's asking with an error.
    w = world({ sequence = true })
    w.hook()
    w.skin.GetParts = function() error("changed") end
    assert.has_no.errors(function() w.skin.UpdateEmpty(w.button) end)
    assert.are.same(EMPTY, look(w))
  end)

  it("is hooked when a sequence goes on a DaylightUI button", function()
    assert.truthy(events:find("    if isDaylightUIButton then hookDaylightUIDress() end\n", 1, true))
  end)
end)
