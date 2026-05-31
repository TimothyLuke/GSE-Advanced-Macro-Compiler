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
-- EllesmereUI exposes no public Handle* API for external addons. The
-- closest hook is EllesmereUI.GetAccentColor(), which returns the user's
-- configured accent (r, g, b). We use that to paint GSE frame borders in
-- a colour that matches the rest of the user's EllesmereUI-themed UI.
-- The backdrop is a dark fill at 85% alpha to match EllesmereUI's panel
-- aesthetic; no attempt is made to replicate their 4-texture-strip border
-- system (that's internal and would couple us to EllesmereUI's locals).
--
-- This is intentionally not as polished as the ElvUI path — it's a
-- visually compatible best-effort treatment.

local EUI_BG = {0.10, 0.10, 0.12, 0.85}     -- panel background
local EUI_EDGE_FILE = "Interface\\Buttons\\WHITE8x8"
local EUI_EDGE_SIZE = 1
local EUI_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = EUI_EDGE_FILE,
    edgeSize = EUI_EDGE_SIZE,
    insets   = {left = 0, right = 0, top = 0, bottom = 0},
}

local function getEUIAccent()
    if type(_G.EllesmereUI) == "table" and type(_G.EllesmereUI.GetAccentColor) == "function" then
        local ok, r, g, b = pcall(_G.EllesmereUI.GetAccentColor)
        if ok and r then return r, g, b end
    end
    return 1, 1, 1  -- white fallback
end

local function paintEUIBorder(frame)
    if not frame or type(frame.SetBackdrop) ~= "function" then return end
    frame:SetBackdrop(EUI_BACKDROP)
    frame:SetBackdropColor(EUI_BG[1], EUI_BG[2], EUI_BG[3], EUI_BG[4])
    local r, g, b = getEUIAccent()
    frame:SetBackdropBorderColor(r, g, b, 0.7)
end

local function stripBlizzardRegions(frame)
    -- Best-effort: hide the standard Blizzard backdrop pieces if present.
    -- BackdropTemplate / NineSlice frames usually expose these regions by
    -- name; non-Backdrop frames just no-op the SetShown calls.
    if not frame then return end
    for _, key in ipairs({"NineSlice", "Border", "Bg", "BorderTopLeft", "BorderTopRight",
                          "BorderBottomLeft", "BorderBottomRight", "BorderTop", "BorderBottom",
                          "BorderLeft", "BorderRight"}) do
        local region = frame[key]
        if region and type(region.Hide) == "function" then region:Hide() end
    end
end

local function makeEllesmereUIProvider()
    if type(_G.EllesmereUI) ~= "table" then return nil end

    -- Adopt BackdropTemplate at load time so SetBackdrop is available on
    -- frames created via the standard CreateFrame("Frame", name, parent)
    -- (no template). Reapplying it inside the skin call works because
    -- BackdropTemplateMixin's :OnBackdropLoaded is idempotent.
    local function ensureBackdropMixin(frame)
        if not frame then return end
        if type(frame.SetBackdrop) == "function" then return end
        if _G.BackdropTemplateMixin then
            Mixin(frame, _G.BackdropTemplateMixin)
            if type(frame.OnBackdropLoaded) == "function" then frame:OnBackdropLoaded() end
        end
    end

    local function skinFrame(frame)
        ensureBackdropMixin(frame)
        stripBlizzardRegions(frame)
        paintEUIBorder(frame)
    end

    local function skinButton(btn)
        if not btn then return end
        stripBlizzardRegions(btn)
        for _, region in ipairs({btn:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
        ensureBackdropMixin(btn)
        paintEUIBorder(btn)
        if btn.SetNormalFontObject then btn:SetNormalFontObject("GameFontNormal") end
        if btn.SetHighlightFontObject then btn:SetHighlightFontObject("GameFontHighlight") end
    end

    local function skinEditBox(edit)
        if not edit then return end
        stripBlizzardRegions(edit)
        for _, region in ipairs({"Left", "Middle", "Right"}) do
            local tex = _G[edit:GetName() and (edit:GetName() .. region) or ""]
            if tex and tex.SetAlpha then tex:SetAlpha(0) end
        end
        ensureBackdropMixin(edit)
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
