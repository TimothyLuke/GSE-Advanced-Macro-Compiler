local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI

-- Initialise GUI namespace
if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

--- Attach tooltip OnEnter/OnLeave callbacks to a widget.
-- @param widget  GSE.UI widget
-- @param title   string  Tooltip title
-- @param text    string  Tooltip body
-- @param editframe  the editor frame (for GSE.CreateToolTip / ClearTooltip)
-- @return widget (chainable)
function GSE.GUI.WithTooltip(widget, title, text, editframe)
    widget:SetCallback("OnEnter", function()
        GSE.CreateToolTip(title, text, editframe)
    end)
    widget:SetCallback("OnLeave", function()
        GSE.ClearTooltip(editframe)
    end)
    return widget
end

--- Create a standard icon button (InteractiveLabel used as icon button).
-- @param iconPath  string  texture path or Statics.ActionsIcons.Xxx
-- @param size      number  image size (default 20)
-- @param onClick   function
-- @param title     string  tooltip title (optional)
-- @param text      string  tooltip body (optional)
-- @param editframe  (optional, needed for tooltip)
-- @return GSE.UI InteractiveLabel widget
function GSE.GUI.MakeIconButton(iconPath, size, onClick, title, text, editframe)
    size = size or 20
    local btn = UI:Create("InteractiveLabel")
    btn:SetImageSize(size, size)
    btn:SetImage(iconPath)
    btn:SetCallback("OnClick", onClick)
    if title and editframe then
        GSE.GUI.WithTooltip(btn, title, text or "", editframe)
    end
    return btn
end

--- Path utilities for the "\001"-delimited tree path strings used by ManageTree.
GSE.GUI.PathUtils = {}

function GSE.GUI.PathUtils.split(path)
    local parts = {}
    for part in string.gmatch(path, "([^\001]+)") do
        parts[#parts + 1] = part
    end
    return parts
end

function GSE.GUI.PathUtils.join(parts)
    return table.concat(parts, "\001")
end

function GSE.GUI.PathUtils.child(path, key)
    return path .. "\001" .. tostring(key)
end
end
table.insert(ns.deferred, setup)
