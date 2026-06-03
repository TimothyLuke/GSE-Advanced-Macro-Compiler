-- GSE frame-skin dispatcher.
--
-- After AceGUI removal, GSE's native frames inherit Blizzard's default look.
-- This module checks for ElvUI / EllesmereUI on PLAYER_LOGIN and routes
-- skinning calls through whichever provider is present, or falls back to
-- no-op (plain Blizzard look). The widget-creation sites in NativeUI.lua
-- call GSE.Skin.<Type>(widget) at the end of each constructor; this file
-- is the dispatcher that decides what those calls do.
--
-- Providers in priority order (first match wins):
--   1. ElvUI       — calls ElvUI[1]:GetModule("Skins"):HandleX(widget)
--   2. EllesmereUI — uses EllesmereUI.PP.CreateBorder + DARK_BG/BORDER_COLOR.
--                    These are the same painters/colours EUI uses on its
--                    own character/inventory/settings panels, so the GSE
--                    skin matches the rest of EUI by construction.
--   3. nil         — no-op, GSE frames use Blizzard's default skin.
--
-- Adding a new provider: add a builder function that returns the same
-- table shape as elvUIProvider() / ellesmereUIProvider() below and add a
-- detect step in selectProvider().

local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE

GSE.Skin = GSE.Skin or {}

-- ─── No-op fallback ────────────────────────────────────────────────────
-- Default surface. All GSE.Skin.X(widget) calls hit here when no provider
-- matches, so the call sites are safe to invoke unconditionally.
local function noop() end

local function makeNoopProvider()
    return {
        name        = "none",
        Frame       = noop,
        InsetFrame  = noop,
        Button      = noop,
        CloseButton = noop,
        EditBox     = noop,
        Dropdown    = noop,
        Checkbox    = noop,
        Slider      = noop,
        StepSlider  = noop,
        ScrollBar   = noop,
        Tab         = noop,
        StatusBar   = noop,
        Icon        = noop,
        ItemButton  = noop,
        StaticPopup = noop,
    }
end

-- ─── ElvUI provider ────────────────────────────────────────────────────
-- ElvUI exposes a documented Skins module at ElvUI[1]:GetModule("Skins")
-- with HandleX(frame, ...) methods. Each entry below is a one-line
-- dispatch into that module. The widget argument is forwarded verbatim;
-- any ElvUI-specific flags (e.g. createBackdrop, template) are filled in
-- with the same defaults the in-tree ElvUI skin modules use.
local function makeElvUIProvider()
    local ElvUI = _G.ElvUI
    if type(ElvUI) ~= "table" or type(ElvUI[1]) ~= "table" then return nil end
    local E = ElvUI[1]
    if type(E.GetModule) ~= "function" then return nil end
    local ok, S = pcall(E.GetModule, E, "Skins")
    if not ok or type(S) ~= "table" then return nil end

    return {
        name        = "ElvUI",
        Frame       = function(frame, setBackdrop) S:HandleFrame(frame, setBackdrop ~= false) end,
        InsetFrame  = function(frame, setBackdrop) S:HandleFrame(frame, setBackdrop ~= false) end,
        Button      = function(btn)       S:HandleButton(btn) end,
        CloseButton = function(btn)       S:HandleCloseButton(btn) end,
        EditBox     = function(edit)      S:HandleEditBox(edit) end,
        Dropdown    = function(dd, width) S:HandleDropDownBox(dd, width) end,
        Checkbox    = function(cb)        if S.HandleCheckBox then S:HandleCheckBox(cb) end end,
        Slider      = function(sl)        S:HandleSliderFrame(sl) end,
        StepSlider  = function(sl)        S:HandleStepSlider(sl) end,
        ScrollBar   = function(sb)        if S.HandleScrollBar then S:HandleScrollBar(sb) end end,
        Tab         = function(tab)       if S.HandleTab then S:HandleTab(tab) end end,
        StatusBar   = function(bar)       if S.HandleStatusBar then S:HandleStatusBar(bar) end end,
        Icon        = function(icon)      S:HandleIcon(icon) end,
        ItemButton  = function(b)         S:HandleItemButton(b, true) end,
        StaticPopup = function(popup)     S:HandleStaticPopup(popup) end,
    }
end

-- ─── EllesmereUI provider ──────────────────────────────────────────────
-- Verified against EllesmereUI 7.9.4 (Curse #1477613). Public surface used:
--
--   EllesmereUI.PP                            — panel-painter module
--     PP.CreateBorder(frame, r, g, b, a,      — paints the 4-edge BackdropTemplate
--                     borderSize, drawLayer,    border EUI uses on its own panels
--                     subLevel)
--     PP.SetBorderColor(frame, r, g, b, a)
--   EllesmereUI.DARK_BG       = {r, g, b}      — canonical panel-bg colour
--   EllesmereUI.BORDER_COLOR  = {r, g, b, a}   — canonical border colour
--   EllesmereUI.ELLESMERE_GREEN                — accent (preserved as fallback)
--
-- NOT present in 7.9.4 (don't reach for them):
--   EllesmereUI.ApplyBorderStyle, GetAccentColor, ResolveBorderTexture,
--   GetActiveTheme. Earlier code paths referenced these speculatively.

local EUI_BORDER_SIZE = 1                    -- 1px is EUI's default thin border
local EUI_FALLBACK_BG = {0.07, 0.07, 0.07, 1}      -- only used if EUI.DARK_BG missing
local EUI_FALLBACK_BORDER = {0.0, 0.82, 0.62, 1}   -- only used if EUI.BORDER_COLOR missing

local function getEUIBackdropColor()
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.DARK_BG) == "table" then
        local c = EUI.DARK_BG
        return c.r or EUI_FALLBACK_BG[1], c.g or EUI_FALLBACK_BG[2],
               c.b or EUI_FALLBACK_BG[3], c.a or 1
    end
    return EUI_FALLBACK_BG[1], EUI_FALLBACK_BG[2], EUI_FALLBACK_BG[3], EUI_FALLBACK_BG[4]
end

-- Theme-keyed background texture (replicated from EllesmereUI.lua's private
-- THEME_BG_FILES table at line 28-37). Used so GSE panels render the same
-- textured grain EUI's own character/inventory/settings panels do, instead
-- of a flat solid colour.
local EUI_THEME_BG = {
    ["EllesmereUI"]   = "backgrounds\\eui-bg-all-compressed.png",
    ["Horde"]         = "backgrounds\\eui-bg-horde-compressed.png",
    ["Alliance"]      = "backgrounds\\eui-bg-alliance-compressed.png",
    ["Midnight"]      = "backgrounds\\eui-bg-midnight-compressed.png",
    ["Dark"]          = "backgrounds\\eui-bg-dark-compressed.png",
    ["Class Colored"] = "backgrounds\\eui-bg-all-compressed.png",
    ["Custom Color"]  = "backgrounds\\eui-bg-all-compressed.png",
}

local function getEUIBackgroundTexture()
    local EUI = _G.EllesmereUI
    if type(EUI) ~= "table" or type(EUI.MEDIA_PATH) ~= "string" then return nil end
    local db = _G.EllesmereUIDB or {}
    local theme = db.activeTheme or "EllesmereUI"
    -- "Faction (Auto)" is EUI's runtime alias for Horde/Alliance based on
    -- the player's faction; resolve it here the same way EUI does.
    if theme == "Faction (Auto)" and UnitFactionGroup then
        local _, faction = UnitFactionGroup("player")
        theme = (faction == "Horde") and "Horde" or "Alliance"
    end
    local file = EUI_THEME_BG[theme] or EUI_THEME_BG["EllesmereUI"]
    return EUI.MEDIA_PATH .. file
end

local function getEUIBorderColor()
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" then
        if type(EUI.BORDER_COLOR) == "table" then
            local c = EUI.BORDER_COLOR
            return c.r or EUI_FALLBACK_BORDER[1], c.g or EUI_FALLBACK_BORDER[2],
                   c.b or EUI_FALLBACK_BORDER[3], c.a or 1
        end
        if type(EUI.ELLESMERE_GREEN) == "table" then
            local c = EUI.ELLESMERE_GREEN
            return c.r or EUI_FALLBACK_BORDER[1], c.g or EUI_FALLBACK_BORDER[2],
                   c.b or EUI_FALLBACK_BORDER[3], c.a or 1
        end
    end
    return EUI_FALLBACK_BORDER[1], EUI_FALLBACK_BORDER[2], EUI_FALLBACK_BORDER[3], EUI_FALLBACK_BORDER[4]
end

local function stripBlizzardRegions(frame)
    if not frame then return end
    -- Strip only the gold/ornate CHROME textures Blizzard panel templates ship
    -- with, NOT the title container — hiding TitleBg / TitleContainer wipes
    -- the frame's title text. Border textures + corner pieces are safe to hide
    -- because they're the gold ornate edges we're replacing with EUI's border.
    for _, key in ipairs({
        "NineSlice", "Border", "Bg",
        "BorderTopLeft", "BorderTopRight", "BorderBottomLeft", "BorderBottomRight",
        "BorderTop", "BorderBottom", "BorderLeft", "BorderRight",
        "TopTileStreaks", "TopBorder", "BotLeftCorner", "BotRightCorner",
        "LeftBorder", "RightBorder", "BottomBorder",
        "Inset", "PortraitFrame", "TopLeftCorner", "TopRightCorner",
    }) do
        local region = frame[key]
        if region and type(region.Hide) == "function" then region:Hide() end
    end
end

local function makeEllesmereUIProvider()
    -- Detection mirrors GSE/API/Native.lua:GSE.IsEllesmereUILoaded — same
    -- dual signal (framework table OR EABButton1) the action-bar override
    -- code uses, so the skin layer and the keybind layer agree on whether
    -- EUI is present. Either signal activates this provider; the PP.CreateBorder
    -- path is only taken if the framework table is real, otherwise we
    -- degrade to the SetBackdrop edge.
    if not (GSE.IsEllesmereUILoaded and GSE.IsEllesmereUILoaded()) then return nil end
    local EUI = type(_G.EllesmereUI) == "table" and _G.EllesmereUI or {}

    local function ensureBackdropMixin(frame)
        if not frame then return end
        if type(frame.SetBackdrop) == "function" then return end
        if _G.BackdropTemplateMixin then
            Mixin(frame, _G.BackdropTemplateMixin)
            if type(frame.OnBackdropLoaded) == "function" then frame:OnBackdropLoaded() end
        end
    end

    local function paintBackdrop(frame)
        if not frame then return end
        -- ensureBackdropMixin BEFORE the SetBackdrop check: Blizzard frames
        -- created with templates like ButtonFrameTemplate / BasicFrameTemplate
        -- don't have the BackdropTemplate mixin, so frame.SetBackdrop is nil
        -- until we Mixin it. The DebugFrame is one such frame — bailing on
        -- the type check first left it without any EUI fill.
        ensureBackdropMixin(frame)
        if type(frame.SetBackdrop) ~= "function" then return end
        -- Flat dark fill via WHITE8X8 + DARK_BG. Attempted the themed
        -- background texture (eui-bg-*-compressed.png) but SetBackdrop's
        -- bgFile path resolution disagreed with that PNG on some frames,
        -- producing transparent panels — see Tim's 123812/123945 reload
        -- where the debugger main frame went see-through. Flat dark is the
        -- known-good baseline that already matches EUI closely; texture
        -- replication is a follow-up that needs a CreateTexture overlay
        -- approach rather than SetBackdrop.
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            insets = {left = 0, right = 0, top = 0, bottom = 0},
        })
        local br, bg, bb, ba = getEUIBackdropColor()
        frame:SetBackdropColor(br, bg, bb, ba)
    end

    local function paintEUIBorder(frame)
        if not frame then return end
        local r, g, b, a = getEUIBorderColor()
        -- Preferred path: EllesmereUI.PP.CreateBorder. Same call EUI's own
        -- MakeBorder helper uses on its panels (see EllesmereUI.lua:606), so
        -- the GSE frame border ends up visually identical to EUI's own
        -- character/inventory/settings panels.
        if EUI.PP and type(EUI.PP.CreateBorder) == "function" then
            local ok = pcall(EUI.PP.CreateBorder, frame, r, g, b, a, EUI_BORDER_SIZE, "BORDER", 7)
            if ok then return end
        end
        -- Degrade path: paint a 1px edge ourselves so the EUI look survives
        -- even on builds whose PP module is renamed or stripped.
        if type(frame.SetBackdrop) == "function" then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = EUI_BORDER_SIZE,
                insets = {left = 0, right = 0, top = 0, bottom = 0},
            })
            local br, bg, bb, ba = getEUIBackdropColor()
            frame:SetBackdropColor(br, bg, bb, ba)
            frame:SetBackdropBorderColor(r, g, b, a)
        end
    end

    local function paintFlatBackdrop(frame)
        if not frame then return end
        ensureBackdropMixin(frame)
        if type(frame.SetBackdrop) ~= "function" then return end
        -- Flat dark fill (no texture) for INSET surfaces inside an EUI panel
        -- — editbox scrollBG, list rows, stat boxes etc. EUI's own panels use
        -- their themed bg only on the OUTER panel; inner controls sit on a
        -- flat dark fill so the text/content is readable. Texturing the
        -- inset would compete with the outer panel's pattern.
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            insets = {left = 0, right = 0, top = 0, bottom = 0},
        })
        local br, bg, bb, ba = getEUIBackdropColor()
        frame:SetBackdropColor(br, bg, bb, ba)
    end

    local function skinFrame(frame)
        if not frame then return end
        stripBlizzardRegions(frame)
        paintBackdrop(frame)
        paintEUIBorder(frame)
    end

    local function skinInsetFrame(frame)
        if not frame then return end
        stripBlizzardRegions(frame)
        paintFlatBackdrop(frame)
        paintEUIBorder(frame)
    end

    local function blankStateTexture(getter, owner)
        if not (owner and owner[getter]) then return end
        local tex = owner[getter](owner)
        if not tex then return end
        if tex.SetTexture then pcall(tex.SetTexture, tex, "") end
        if tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
        if tex.SetAlpha then tex:SetAlpha(0) end
        if tex.Hide then tex:Hide() end
    end

    local function skinButton(btn)
        if not btn then return end
        stripBlizzardRegions(btn)
        -- Buttons get the FLAT dark fill (not the themed texture) — a button
        -- chrome with a grain pattern reads as an outer panel rather than a
        -- clickable control. EUI's own buttons sit on flat dark inside the
        -- textured outer panel; this matches that.
        -- NativeUI's createButton uses UIPanelButtonTemplate, which in retail
        -- ships a dark-red textured chrome. Just SetAlpha(0)-ing regions
        -- isn't enough — Blizzard re-applies Normal / Pushed / Highlight /
        -- Disabled textures on state transitions and the red flashes back.
        -- Retail's :SetXTexture(nil) ERRORS (needs an asset), so reach for
        -- the underlying texture object via GetXTexture() and blank+hide it
        -- there. The state machine sees a hidden texture and stops painting.
        blankStateTexture("GetNormalTexture",    btn)
        blankStateTexture("GetPushedTexture",    btn)
        blankStateTexture("GetHighlightTexture", btn)
        blankStateTexture("GetDisabledTexture",  btn)
        -- UIPanelButtonTemplate also exposes Left/Middle/Right named regions
        -- (the 3-slice chrome). Region iteration catches them, but we belt
        -- + braces it: explicitly hide the named ones too.
        for _, key in ipairs({"Left", "Middle", "Right"}) do
            local r = btn[key]
            if r and r.Hide then r:Hide() end
        end
        for _, region in ipairs({btn:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetAlpha then region:SetAlpha(0) end
            end
        end
        paintFlatBackdrop(btn)
        paintEUIBorder(btn)
        if btn.SetNormalFontObject then btn:SetNormalFontObject("GameFontNormal") end
        if btn.SetHighlightFontObject then btn:SetHighlightFontObject("GameFontHighlight") end
    end

    local function paintBlackBackdrop(frame)
        if not frame then return end
        ensureBackdropMixin(frame)
        if type(frame.SetBackdrop) ~= "function" then return end
        -- Pure black flat fill — editbox interiors. Removes any ambiguity
        -- about what the editbox area is vs the panel behind it, and matches
        -- how editors look in EUI's own panels (the search box in inventory,
        -- the editbox in the settings panel).
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            insets = {left = 0, right = 0, top = 0, bottom = 0},
        })
        frame:SetBackdropColor(0, 0, 0, 1)
    end

    local function skinEditBox(edit)
        if not edit then return end
        stripBlizzardRegions(edit)
        -- Blizzard EditBox templates expose <name>Left/Middle/Right textures.
        local name = edit.GetName and edit:GetName()
        if name then
            for _, suffix in ipairs({"Left", "Middle", "Right"}) do
                local tex = _G[name .. suffix]
                if tex and tex.SetAlpha then tex:SetAlpha(0) end
            end
        end
        paintBlackBackdrop(edit)
        -- No paintEUIBorder for editboxes — they're inside an outer EUI-
        -- bordered panel; adding their own accent border reads as a faint
        -- double-line stripe inside the box edge. The black fill alone is
        -- the EUI editbox look.
    end

    return {
        name        = "EllesmereUI",
        Frame       = skinFrame,
        InsetFrame  = skinInsetFrame,
        Button      = skinButton,
        CloseButton = skinButton,
        EditBox     = skinEditBox,
        Dropdown    = skinFrame,
        Checkbox    = skinFrame,
        Slider      = skinFrame,
        StepSlider  = skinFrame,
        -- ScrollBar deliberately a no-op: NativeUI's applyModernSlimScrollBar
        -- already paints a slim accent thumb under EUI (see NativeUI.lua:597).
        -- Calling skinFrame here would Paint a backdrop+border across the
        -- whole scrollbar frame and bury the thumb texture.
        ScrollBar   = noop,
        Tab         = skinButton,
        StatusBar   = skinFrame,
        Icon        = skinFrame,
        ItemButton  = skinFrame,
        StaticPopup = skinFrame,
    }
end

-- ─── Provider selection ────────────────────────────────────────────────
-- ElvUI takes priority because its skinning surface is far more complete
-- than the EllesmereUI replicate-and-paint path.
local function selectProvider()
    local provider = makeElvUIProvider() or makeEllesmereUIProvider() or makeNoopProvider()
    for k, v in pairs(provider) do GSE.Skin[k] = v end
    GSE.Skin.providerName = provider.name
end

-- Initialise to no-op immediately so any widget-creation calls that fire
-- before the provider is picked don't error.
for k, v in pairs(makeNoopProvider()) do GSE.Skin[k] = v end
GSE.Skin.providerName = "pending"

-- ─── Public colour helpers ─────────────────────────────────────────────
-- Any GSE file that hardcodes a colour at a paint site can replace its
-- SetTextColor / SetBackdropBorderColor call with one of these helpers.
-- Each takes the original GSE-theme colour as a fallback so non-EUI
-- sessions render identically to before. Under EUI, the helper substitutes
-- the canonical EUI colour (ELLESMERE_GREEN for accents, TEXT_WHITE for
-- body, BORDER_COLOR for border) so GSE frames match other EUI panels.
--
-- Pattern at call sites:
--   text:SetTextColor(1, 0.82, 0, 1)                      -- before
--   GSE.Skin.PaintAccentText(text, 1, 0.82, 0, 1)         -- after
--
-- All four return nothing — they paint in place.

function GSE.Skin.IsExternalProviderActive()
    local name = GSE.Skin.providerName
    return name == "ElvUI" or name == "EllesmereUI"
end

function GSE.Skin.PaintAccentText(text, fallbackR, fallbackG, fallbackB, fallbackA)
    if not (text and text.SetTextColor) then return end
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.ELLESMERE_GREEN) == "table" then
        local c = EUI.ELLESMERE_GREEN
        text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        return
    end
    if fallbackR then
        text:SetTextColor(fallbackR, fallbackG or 0, fallbackB or 0, fallbackA or 1)
    end
end

function GSE.Skin.PaintBodyText(text, fallbackR, fallbackG, fallbackB, fallbackA)
    if not (text and text.SetTextColor) then return end
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.TEXT_WHITE) == "table" then
        local c = EUI.TEXT_WHITE
        text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
        return
    end
    if fallbackR then
        text:SetTextColor(fallbackR, fallbackG or 1, fallbackB or 1, fallbackA or 1)
    end
end

function GSE.Skin.PaintAccentBorder(frame, fallbackR, fallbackG, fallbackB, fallbackA)
    if not (frame and frame.SetBackdropBorderColor) then return end
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.BORDER_COLOR) == "table" then
        local c = EUI.BORDER_COLOR
        frame:SetBackdropBorderColor(c.r or 0, c.g or 0.82, c.b or 0.62, c.a or 1)
        return
    end
    if fallbackR then
        frame:SetBackdropBorderColor(fallbackR, fallbackG or 0, fallbackB or 0, fallbackA or 1)
    end
end

-- Pick the provider. PLAYER_LOGIN only fires at fresh login — on /reload
-- it never fires again, so a code update that ships a fresh script body
-- would leave providerName stuck at "pending" after a /reload. Cover both
-- by registering PLAYER_LOGIN for the cold-login case AND running
-- selectProvider directly when IsLoggedIn() reports we're already in
-- world (the /reload case).
if IsLoggedIn and IsLoggedIn() then
    selectProvider()
else
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        selectProvider()
    end)
end
end
table.insert(ns.deferred, setup)
