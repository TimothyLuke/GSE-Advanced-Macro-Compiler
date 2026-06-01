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
--   2. EllesmereUI — applies a dark backdrop + 1px border in EllesmereUI's
--                    accent color (read via EllesmereUI.GetAccentColor()).
--                    EllesmereUI does NOT expose a public Handle* API, so
--                    this is a detect-and-replicate pass — visually
--                    compatible, not a 1:1 mimic.
--   3. nil         — no-op, GSE frames use Blizzard's default skin.
--
-- Adding a new provider: add a builder function that returns the same
-- table shape as elvUIProvider() / ellesmereUIProvider() below and add a
-- detect step in selectProvider().

local GSE = GSE

GSE.Skin = GSE.Skin or {}

-- ─── No-op fallback ────────────────────────────────────────────────────
-- Default surface. All GSE.Skin.X(widget) calls hit here when no provider
-- matches, so the call sites are safe to invoke unconditionally.
local function noop() end

local function makeNoopProvider()
    return {
        name        = "none",
        Frame       = noop,
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
-- EllesmereUI doesn't ship a HandleX surface like ElvUI, but its public
-- API is richer than first appeared. We use:
--
--   EllesmereUI.ApplyBorderStyle(frame, size, r, g, b, a, textureKey)
--       Their canonical border painter. Handles both the "solid" 4-strip
--       PP system (their default) and BackdropTemplate-based textured
--       borders. Auto-resolves the texture path from the texture key.
--   EllesmereUI.GetAccentColor()  -> r, g, b
--       User's configured accent (or class-color / preset).
--   EllesmereUI.GetActiveTheme()  -> string
--   EllesmereUI.ResolveBorderTexture(key) -> texture path
--   EllesmereUI.PP                -- exposed panel-painter
--       PP.CreateBorder(frame, r, g, b, a, size, drawLayer, subLevel)
--       PP.SetBorderColor(frame, r, g, b, a)
--
-- We call ApplyBorderStyle to paint the same 4-strip borders EllesmereUI
-- paints on its own panels, in the same accent colour. NativeUI's own
-- chrome (CreateTexture overlays for the GSE orange/teal theme) remains
-- on top of this — fully suppressing it requires per-widget knowledge of
-- which textures NativeUI created. That's the next refactor; for now the
-- EUI borders sit at the frame edge and the GSE theme fills the body.

local EUI_BG = {0.10, 0.10, 0.12, 0.85}     -- panel background (EUI doesn't expose a panel-bg colour API)
local EUI_BORDER_SIZE = 1                    -- 1px is EUI's default thin border
local EUI_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,                          -- borders come from EUI's PP system, not from our backdrop
    edgeSize = 0,
    insets = {left = 0, right = 0, top = 0, bottom = 0},
}

local function getEUIAccent()
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.GetAccentColor) == "function" then
        local ok, r, g, b = pcall(EUI.GetAccentColor)
        if ok and r then return r, g, b end
    end
    return 1, 1, 1
end

local function getEUITextureKey()
    -- Default texture key for the user's active theme. EUI doesn't expose
    -- a "get the current border texture for an arbitrary addon" — that's
    -- per-addon registered with RegisterBorderDefaults. We default to
    -- "solid" which is their 4-strip system and matches most users'
    -- panels out of the box.
    return "solid"
end

local function stripBlizzardRegions(frame)
    if not frame then return end
    for _, key in ipairs({"NineSlice", "Border", "Bg", "BorderTopLeft", "BorderTopRight",
                          "BorderBottomLeft", "BorderBottomRight", "BorderTop", "BorderBottom",
                          "BorderLeft", "BorderRight"}) do
        local region = frame[key]
        if region and type(region.Hide) == "function" then region:Hide() end
    end
end

local function makeEllesmereUIProvider()
    local EUI = _G.EllesmereUI
    if type(EUI) ~= "table" then return nil end
    -- Require the public painters — bail if EUI is too old.
    if type(EUI.ApplyBorderStyle) ~= "function" then return nil end

    local function ensureBackdropMixin(frame)
        if not frame then return end
        if type(frame.SetBackdrop) == "function" then return end
        if _G.BackdropTemplateMixin then
            Mixin(frame, _G.BackdropTemplateMixin)
            if type(frame.OnBackdropLoaded) == "function" then frame:OnBackdropLoaded() end
        end
    end

    local function paintBackdrop(frame)
        if not frame or type(frame.SetBackdrop) ~= "function" then return end
        ensureBackdropMixin(frame)
        frame:SetBackdrop(EUI_BACKDROP)
        frame:SetBackdropColor(EUI_BG[1], EUI_BG[2], EUI_BG[3], EUI_BG[4])
    end

    local function paintEUIBorder(frame)
        if not frame then return end
        local r, g, b = getEUIAccent()
        local ok = pcall(EUI.ApplyBorderStyle, frame, EUI_BORDER_SIZE, r, g, b, 0.85, getEUITextureKey())
        if not ok and EUI.PP and EUI.PP.CreateBorder then
            -- Fallback: drop straight into the panel-painter
            pcall(EUI.PP.CreateBorder, frame, r, g, b, 0.85, EUI_BORDER_SIZE, "OVERLAY", 7)
        end
    end

    local function skinFrame(frame)
        if not frame then return end
        stripBlizzardRegions(frame)
        paintBackdrop(frame)
        paintEUIBorder(frame)
    end

    local function skinButton(btn)
        if not btn then return end
        stripBlizzardRegions(btn)
        -- Suppress the Blizzard UIPanelButton chrome that NativeUI's createButton
        -- left in place — those bright textures defeat the EUI look.
        for _, region in ipairs({btn:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                if region.SetAlpha then region:SetAlpha(0) end
            end
        end
        paintBackdrop(btn)
        paintEUIBorder(btn)
        if btn.SetNormalFontObject then btn:SetNormalFontObject("GameFontNormal") end
        if btn.SetHighlightFontObject then btn:SetHighlightFontObject("GameFontHighlight") end
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
        paintBackdrop(edit)
        paintEUIBorder(edit)
    end

    return {
        name        = "EllesmereUI",
        Frame       = skinFrame,
        Button      = skinButton,
        CloseButton = skinButton,
        EditBox     = skinEditBox,
        Dropdown    = skinFrame,
        Checkbox    = skinFrame,
        Slider      = skinFrame,
        StepSlider  = skinFrame,
        ScrollBar   = skinFrame,
        Tab         = skinButton,
        StatusBar   = skinFrame,
        Icon        = skinFrame,
        ItemButton  = skinFrame,
        StaticPopup = skinFrame,
    }
end

-- ─── Provider selection ────────────────────────────────────────────────
-- Run on PLAYER_LOGIN so both addons have fully loaded. ElvUI takes
-- priority because its skinning surface is far more complete than the
-- EllesmereUI detect-and-replicate path.
local function selectProvider()
    local provider = makeElvUIProvider() or makeEllesmereUIProvider() or makeNoopProvider()
    for k, v in pairs(provider) do GSE.Skin[k] = v end
    GSE.Skin.providerName = provider.name
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    selectProvider()
end)

-- Initialise to no-op immediately so any widget-creation calls that fire
-- before PLAYER_LOGIN don't error. PLAYER_LOGIN will then overwrite this
-- table with the resolved provider's methods.
for k, v in pairs(makeNoopProvider()) do GSE.Skin[k] = v end
GSE.Skin.providerName = "pending"
