local _, GSE = ...

-- Context menus that work in WoW Forever's gamepad mode.
--
-- Blizzard's gamepad layer reacts to every Blizzard Menu being shown by
-- calling the protected SetPreferredGamepadInteractTarget(). A menu opened
-- from addon code makes that call from tainted code, so it is blocked and
-- blamed on whichever GSE addon opened the menu (ADDON_ACTION_FORBIDDEN) --
-- every GSE right-click menu, with nothing of GSE's own involved.
--
-- GSE.OpenContextMenu(owner, generator) is the one way GSE opens a menu.
-- With keyboard and mouse it is MenuUtil.CreateContextMenu, unchanged. In
-- gamepad mode the same generator is run against a stand-in description that
-- records what it builds, and the result is drawn as a plain GSE frame, which
-- the gamepad layer does not watch.
--
-- The stand-in covers what GSE's menus use: CreateTitle, CreateButton (with
-- children, drawn as a submenu), CreateDivider, CreateCheckbox, CreateRadio,
-- SetTooltip, SetEnabled, SetIsSelected, and MenuResponse.Refresh / Close.
-- Any other description method is accepted and ignored, so a menu that uses
-- one still opens.

local function isGamepadInterface()
    local style = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    local types = Enum and Enum.InputDeviceInterfaceType
    if not style or not types or types.Gamepad == nil then return false end
    local ok, current = pcall(style)
    return ok and current == types.Gamepad
end
GSE.IsGamepadInterface = isGamepadInterface

-- ---------------------------------------------------------------------------
-- The stand-in description. Pure Lua, no frames: spec/contextmenu_spec.lua
-- runs generators against it.

local Description = {}
local function newDescription(kind, text, fields)
    local d = { kind = kind, text = text, children = {}, enabled = true }
    for k, v in pairs(fields or {}) do d[k] = v end
    return setmetatable(d, Description)
end
local function noop() end
Description.__index = function(_, key)
    local method = rawget(Description, key)
    if method then return method end
    return noop
end

function Description:CreateTitle(text)
    local d = newDescription("title", text)
    self.children[#self.children + 1] = d
    return d
end
function Description:CreateButton(text, callback, data)
    local d = newDescription("button", text, { callback = callback, data = data })
    self.children[#self.children + 1] = d
    return d
end
function Description:CreateDivider()
    local d = newDescription("divider")
    self.children[#self.children + 1] = d
    return d
end
function Description:CreateCheckbox(text, isSelected, setSelected, data)
    local d = newDescription("checkbox", text, { isSelected = isSelected, callback = setSelected, data = data })
    self.children[#self.children + 1] = d
    return d
end
function Description:CreateRadio(text, isSelected, setSelected, data)
    local d = newDescription("radio", text, { isSelected = isSelected, callback = setSelected, data = data })
    self.children[#self.children + 1] = d
    return d
end
function Description:SetTooltip(fn) self.tooltip = fn end
function Description:SetEnabled(enabled) self.enabled = enabled and true or false end
-- Blizzard takes a function; GSE also passes a plain boolean.
function Description:SetIsSelected(selected) self.isSelected = selected end

function Description:IsSelectedNow()
    local sel = self.isSelected
    if type(sel) == "function" then
        local ok, result = pcall(sel, self.data)
        return ok and result and true or false
    end
    return sel and true or false
end

-- What a click should do next: "close" or "refresh". A callback's own
-- MenuResponse wins; otherwise checkboxes stay open and everything else closes,
-- as Blizzard's menus do.
function Description:Respond()
    local response
    if self.callback then
        local ok, result = pcall(self.callback, self.data, {})
        if not ok then
            geterrorhandler()(result)
            return "close"
        end
        response = result
    end
    local MR = MenuResponse or {}
    if response ~= nil and response == MR.Refresh then return "refresh" end
    if response ~= nil and (response == MR.Close or response == MR.CloseAll) then return "close" end
    if self.kind == "checkbox" then return "refresh" end
    return "close"
end

-- Run a generator against a fresh stand-in root; returns the root.
function GSE.BuildMenuDescription(owner, generator)
    local root = newDescription("root")
    local ok, err = pcall(generator, owner, root)
    if not ok then geterrorhandler()(err) end
    return root
end

-- ---------------------------------------------------------------------------
-- Drawing.

local ROW = 20
local WIDTH = 240
local MAX_ROWS = 20
local panels = {}
local catcher
local current -- { owner, generator }

local closeMenu

local function ensureCatcher()
    if catcher then return catcher end
    -- A click anywhere outside the menu closes it, as a menu would.
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() closeMenu() end)
    catcher:Hide()
    return catcher
end

local function getPanel(level)
    if panels[level] then return panels[level] end
    local name = "GSEContextMenu" .. level
    local p = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetFrameLevel(10 + level * 5)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    if p.SetBackdrop then
        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        p:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    end
    p.scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 6, -6)
    p.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    p.content = CreateFrame("Frame", nil, p.scroll)
    p.content:SetWidth(WIDTH - 32)
    p.scroll:SetScrollChild(p.content)
    p.lines = {}
    if level == 1 then
        -- Escape closes the whole menu.
        table.insert(UISpecialFrames, name)
        p:SetScript("OnHide", function()
            for i = 2, #panels do panels[i]:Hide() end
            if catcher then catcher:Hide() end
        end)
    end
    panels[level] = p
    return p
end

local function hideFrom(level)
    for i = level, #panels do panels[i]:Hide() end
end

closeMenu = function()
    current = nil
    hideFrom(1)
    if catcher then catcher:Hide() end
end
GSE.CloseContextMenu = closeMenu

local showLevel
local reopen

local function rowLabel(d)
    local text = d.text or ""
    if d.kind == "checkbox" then
        text = (d:IsSelectedNow() and "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t " or "|TInterface\\Buttons\\UI-CheckBox-Up:14:14|t ") .. text
    elseif d.kind == "radio" then
        text = (d:IsSelectedNow() and "|cFFFFD100(o)|r " or "( ) ") .. text
    end
    if d.kind == "title" then return NORMAL_FONT_COLOR_CODE .. text .. "|r" end
    if not d.enabled then return "|cFF808080" .. text .. "|r" end
    if d.kind == "button" and #d.children > 0 then return text .. "  |cFFFFD100>|r" end
    return text
end

local function getLine(p, i)
    local line = p.lines[i]
    if line then return line end
    line = CreateFrame("Button", nil, p.content)
    line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.text:SetPoint("LEFT", 4, 0)
    line.text:SetPoint("RIGHT", -4, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)
    line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    p.lines[i] = line
    return line
end

showLevel = function(level, description, anchor)
    hideFrom(level)
    local p = getPanel(level)
    for _, line in ipairs(p.lines) do line:Hide() end
    local y = 0
    for i, d in ipairs(description.children) do
        local line = getLine(p, i)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -y)
        line:SetPoint("RIGHT", p.content, "RIGHT")
        line:SetHeight(d.kind == "divider" and ROW / 2 or ROW)
        line.text:SetText(d.kind == "divider" and "" or rowLabel(d))
        local clickable = (d.kind == "button" or d.kind == "checkbox" or d.kind == "radio")
        line:EnableMouse(d.kind ~= "divider")
        line:SetScript("OnClick", nil)
        line:SetScript("OnEnter", function(btn)
            if d.kind == "button" and #d.children > 0 and d.enabled then
                showLevel(level + 1, d, btn)
            else
                hideFrom(level + 1)
            end
            if d.tooltip then
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                pcall(d.tooltip, GameTooltip, d)
                GameTooltip:Show()
            end
        end)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        if clickable and d.enabled and not (d.kind == "button" and #d.children > 0 and not d.callback) then
            line:SetScript("OnClick", function()
                GameTooltip:Hide()
                if d:Respond() == "refresh" then reopen() else closeMenu() end
            end)
        end
        line:Show()
        y = y + line:GetHeight()
    end
    p.content:SetHeight(math.max(y, 1))
    p:SetSize(WIDTH, math.min(math.max(y, ROW), ROW * MAX_ROWS) + 12)
    p:ClearAllPoints()
    if level == 1 then
        p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    end
    p.scroll:SetVerticalScroll(0)
    p:Show()
end

-- Rebuild from the generator, in place -- MenuResponse.Refresh.
reopen = function()
    if not current then return end
    local root = GSE.BuildMenuDescription(current.owner, current.generator)
    showLevel(1, root, current.anchor)
end

local function openGamepadMenu(owner, generator)
    current = { owner = owner, generator = generator,
        anchor = (owner and owner.GetCenter and owner:GetCenter()) and owner or UIParent }
    ensureCatcher():Show()
    reopen()
end

function GSE.OpenContextMenu(owner, generator)
    if isGamepadInterface() then
        return openGamepadMenu(owner, generator)
    end
    return MenuUtil.CreateContextMenu(owner, generator)
end
