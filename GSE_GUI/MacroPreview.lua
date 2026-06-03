local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local L = GSE.L
local PREVIEW_WIDTH_OFFSET = 18
local PREVIEW_HEIGHT_OFFSET = 66
local MIN_PREVIEW_HEIGHT = 300
local DEFAULT_PREVIEW_HEIGHT = 700

local function GetEditorPreviewHeight(editframe)
    local editorFrame = editframe and editframe.frame
    local height = editorFrame and editorFrame.GetHeight and editorFrame:GetHeight()
    if not height or height <= 0 then
        height = editframe and editframe.Height
    end
    return math.max(MIN_PREVIEW_HEIGHT, height or DEFAULT_PREVIEW_HEIGHT)
end

local function DisablePreviewColoring(widget)
    if widget and widget.editBox and IndentationLib and IndentationLib.disable then
        IndentationLib.disable(widget.editBox)
    end
end

function GSE.GUIShowCompiledMacroGui(spelllist, title, editframe)
  local UI = GSE.UI

  -- Reuse an existing preview frame for this editor rather than leaking a new
  -- one on every button click.
  local PreviewFrame = editframe.PreviewFrame
  if GSE.isEmpty(PreviewFrame) then
    PreviewFrame = UI:Create("Frame")
    PreviewFrame.frame:SetFrameStrata("MEDIUM")
    PreviewFrame.frame:SetClampedToScreen(true)
    PreviewFrame:SetTitle(L["Compiled Template"])
    PreviewFrame:SetCallback(
      "OnClose",
      function(widget)
        PreviewFrame:Hide()
        -- Editor's macro blocks render the inline side panel only when this
        -- preview frame is visible, so a refresh is needed on close to drop
        -- the panel and let the multiline take full width again.
        if editframe and editframe.RefreshCurrentVersion then
          editframe.RefreshCurrentVersion()
        end
      end
    )
    PreviewFrame:SetLayout("List")
    PreviewFrame.frame:SetClampRectInsets(10, 0, 0, 0)
    PreviewFrame:SetWidth(280)
    PreviewFrame:SetHeight(GetEditorPreviewHeight(editframe))
    PreviewFrame:SetResizeBounds(280, MIN_PREVIEW_HEIGHT)
    PreviewFrame:SetResizable(true)
    PreviewFrame:Hide()

    local PreviewLabel = UI:Create("MultiLineEditBox")
    PreviewLabel:SetWidth(280 - PREVIEW_WIDTH_OFFSET)
    PreviewLabel:SetNumLines(40)
    PreviewLabel:DisableButton(true)

    PreviewFrame.PreviewLabel = PreviewLabel
    PreviewFrame:AddChild(PreviewLabel)

    IndentationLib.enable(PreviewLabel.editBox, Statics.IndentationColorTable, 4)
    PreviewLabel:SetCallback("OnRelease", DisablePreviewColoring)

    PreviewFrame.frame:SetScript(
      "OnSizeChanged",
      function(self, width, height)
        PreviewLabel:SetWidth(width - PREVIEW_WIDTH_OFFSET)
        PreviewLabel:SetHeight(height - PREVIEW_HEIGHT_OFFSET)
      end
    )

    -- Store on the editor so OnClose can dismiss it and repeat clicks reuse it.
    editframe.PreviewFrame = PreviewFrame
  end

  local PreviewLabel = PreviewFrame.PreviewLabel
  PreviewFrame.text = IndentationLib.encode(GSE.Dump(spelllist))

  local count = #spelllist
  PreviewLabel:SetLabel(L["Compiled"] .. " " .. count .. " " .. L["Actions"])
  if editframe:IsVisible() then
    PreviewFrame:SetHeight(GetEditorPreviewHeight(editframe))
    PreviewLabel:SetHeight(PreviewFrame.frame:GetHeight() - PREVIEW_HEIGHT_OFFSET)
    PreviewFrame:ClearAllPoints()
    PreviewFrame:SetPoint("TOPLEFT", editframe.frame, editframe.Width + 10, 0)
  end

  if not GSE.isEmpty(spelllist) then
    PreviewLabel:SetText(PreviewFrame.text)
  end
  PreviewFrame:SetStatusText(title)
  local wasShown = PreviewFrame:IsShown()
  PreviewFrame:Show()
  if PreviewFrame.frame and GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(PreviewFrame.frame) end
  -- the multiline editor whenever this preview frame becomes visible.
  if not wasShown and editframe and editframe.RefreshCurrentVersion then
    editframe.RefreshCurrentVersion()
  end
end
end
table.insert(ns.deferred, setup)
