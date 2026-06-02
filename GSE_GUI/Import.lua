local GSE = GSE
local Statics = GSE.Static

local UI = GSE.UI
local L = GSE.L

local MODERN_IMPORT_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}
local MODERN_IMPORT_BG = { 0.02, 0.025, 0.028, 0.94 }
local MODERN_IMPORT_PANEL_BG = { 0.015, 0.018, 0.020, 0.92 }
local MODERN_IMPORT_BORDER = { 0.22, 0.24, 0.25, 0.95 }
local MODERN_IMPORT_MUTED_BORDER = { 0.10, 0.10, 0.10, 1 }
local MODERN_IMPORT_ACCENT = { 0.00, 0.784, 0.784, 1 }
local MODERN_IMPORT_BUTTON_BG = { 0.055, 0.055, 0.055, 0.92 }
local MODERN_IMPORT_BUTTON_HOVER_BG = { 0.10, 0.10, 0.10, 0.96 }
local MODERN_IMPORT_BUTTON_DISABLED_BG = { 0.035, 0.035, 0.035, 0.72 }
local MODERN_IMPORT_BUTTON_BORDER = { 0.18, 0.18, 0.18, 1 }
local MODERN_IMPORT_BUTTON_DISABLED_BORDER = { 0.08, 0.08, 0.08, 1 }
local MODERN_IMPORT_BUTTON_TEXT = { 0.92, 0.92, 0.92, 1 }
local MODERN_IMPORT_BUTTON_HOVER_TEXT = { 1, 0.82, 0, 1 }
local MODERN_IMPORT_BUTTON_DISABLED_TEXT = { 0.45, 0.45, 0.45, 1 }
local MODERN_IMPORT_CHEVRON = "Interface\\AddOns\\GSE_GUI\\Assets\\down-chevron.png"
local MODERN_IMPORT_CLASS_COLORS = {
  DEATHKNIGHT = {0.77, 0.12, 0.23, 1},
  DEMONHUNTER = {0.64, 0.19, 0.79, 1},
  DRUID = {1.00, 0.49, 0.04, 1},
  EVOKER = {0.20, 0.58, 0.50, 1},
  HUNTER = {0.67, 0.83, 0.45, 1},
  MAGE = {0.25, 0.78, 0.92, 1},
  MONK = {0.00, 1.00, 0.59, 1},
  PALADIN = {0.96, 0.55, 0.73, 1},
  PRIEST = {1.00, 1.00, 1.00, 1},
  ROGUE = {1.00, 0.96, 0.41, 1},
  SHAMAN = {0.00, 0.44, 0.87, 1},
  WARLOCK = {0.53, 0.53, 0.93, 1},
  WARRIOR = {0.78, 0.61, 0.43, 1},
}

local function shouldUseModernImportSkin()
  return (GSE.ShouldUseModernSkin and GSE.ShouldUseModernSkin()) or
    (GSE.ShouldUseElvUISkin and GSE.ShouldUseElvUISkin())
end

local function getImportAccent(alpha)
  if GSE.ShouldUseModernCustomColor and GSE.ShouldUseModernCustomColor() and GSE.GetModernCustomColor then
    return GSE.GetModernCustomColor(alpha or 1)
  end

  if GSE.ShouldUseModernClassColors and GSE.ShouldUseModernClassColors() and UnitClass then
    local localizedClass, classFile = UnitClass("player")
    classFile = classFile or localizedClass
    if type(classFile) == "string" then
      classFile = classFile:upper():gsub("%s+", "")
    end
    local color = classFile and MODERN_IMPORT_CLASS_COLORS[classFile]
    if color then
      return { color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, alpha or color.a or color[4] or 1 }
    end
  end

  return { MODERN_IMPORT_ACCENT[1], MODERN_IMPORT_ACCENT[2], MODERN_IMPORT_ACCENT[3], alpha or MODERN_IMPORT_ACCENT[4] }
end

local function applyModernImportBackdrop(frame, bg, border)
  if not (frame and frame.SetBackdrop) then return end
  frame:SetBackdrop(MODERN_IMPORT_BACKDROP)
  frame:SetBackdropColor(unpack(bg or MODERN_IMPORT_BG))
  frame:SetBackdropBorderColor(unpack(border or MODERN_IMPORT_BORDER))
end

local function hideImportTextures(frame)
  if not frame or frame.GSEImportTexturesHidden then return end
  for _, region in ipairs({ frame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "Texture" and not region.GSEImportOwned then
      region:Hide()
    end
  end
  frame.GSEImportTexturesHidden = true
end

local function showImportTextures(frame)
  if not frame then return end
  for _, region in ipairs({ frame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "Texture" and not region.GSEImportOwned and region.Show then
      region:Show()
    elseif region.GSEImportOwned and region.Hide then
      region:Hide()
    end
  end
  frame.GSEImportTexturesHidden = nil
end

local function createImportTexture(frame, layer)
  local texture = frame:CreateTexture(nil, layer or "BORDER")
  texture.GSEImportOwned = true
  return texture
end

local function ensureImportChrome(frame)
  if not (frame and frame.CreateTexture) then return end
  if frame.GSEImportChromeFill then return end
  frame.GSEImportChromeFill = createImportTexture(frame, "BACKGROUND")
  frame.GSEImportChromeTop = createImportTexture(frame, "BORDER")
  frame.GSEImportChromeBottom = createImportTexture(frame, "BORDER")
  frame.GSEImportChromeLeft = createImportTexture(frame, "BORDER")
  frame.GSEImportChromeRight = createImportTexture(frame, "BORDER")
end

local function layoutImportChrome(frame, fillColor, borderColor, inset)
  if not (frame and frame.GSEImportChromeFill) then return end
  inset = inset or 1
  fillColor = fillColor or MODERN_IMPORT_BUTTON_BG
  borderColor = borderColor or MODERN_IMPORT_BUTTON_BORDER

  frame.GSEImportChromeFill:ClearAllPoints()
  frame.GSEImportChromeFill:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  frame.GSEImportChromeFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
  frame.GSEImportChromeFill:SetColorTexture(unpack(fillColor))
  frame.GSEImportChromeFill:Show()

  frame.GSEImportChromeTop:ClearAllPoints()
  frame.GSEImportChromeTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.GSEImportChromeTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.GSEImportChromeTop:SetHeight(1)

  frame.GSEImportChromeBottom:ClearAllPoints()
  frame.GSEImportChromeBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  frame.GSEImportChromeBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.GSEImportChromeBottom:SetHeight(1)

  frame.GSEImportChromeLeft:ClearAllPoints()
  frame.GSEImportChromeLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.GSEImportChromeLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  frame.GSEImportChromeLeft:SetWidth(1)

  frame.GSEImportChromeRight:ClearAllPoints()
  frame.GSEImportChromeRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.GSEImportChromeRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.GSEImportChromeRight:SetWidth(1)

  frame.GSEImportChromeTop:SetColorTexture(unpack(borderColor))
  frame.GSEImportChromeBottom:SetColorTexture(unpack(borderColor))
  frame.GSEImportChromeLeft:SetColorTexture(unpack(borderColor))
  frame.GSEImportChromeRight:SetColorTexture(unpack(borderColor))
  frame.GSEImportChromeTop:Show()
  frame.GSEImportChromeBottom:Show()
  frame.GSEImportChromeLeft:Show()
  frame.GSEImportChromeRight:Show()
end

local function updateImportButtonState(button, hovered)
  if not (button and button.GSEImportChromeFill) then return end
  local enabled = not (button.IsEnabled and not button:IsEnabled())
  local fillColor = enabled and (hovered and MODERN_IMPORT_BUTTON_HOVER_BG or MODERN_IMPORT_BUTTON_BG) or MODERN_IMPORT_BUTTON_DISABLED_BG
  local borderColor = enabled and MODERN_IMPORT_BUTTON_BORDER or MODERN_IMPORT_BUTTON_DISABLED_BORDER
  layoutImportChrome(button, fillColor, borderColor, 1)

  local text = button.GetFontString and button:GetFontString()
  if text and text.SetTextColor then
    if not enabled then
      text:SetTextColor(unpack(MODERN_IMPORT_BUTTON_DISABLED_TEXT))
    elseif hovered then
      text:SetTextColor(unpack(MODERN_IMPORT_BUTTON_HOVER_TEXT))
    else
      text:SetTextColor(unpack(MODERN_IMPORT_BUTTON_TEXT))
    end
  end
end

local function styleImportButtonFrame(button)
  if not button then return end
  if not shouldUseModernImportSkin() then
    showImportTextures(button)
    return
  end
  hideImportTextures(button)
  ensureImportChrome(button)

  if button.SetNormalFontObject then button:SetNormalFontObject(GameFontNormalSmall or GameFontNormal) end
  if button.SetHighlightFontObject then button:SetHighlightFontObject(GameFontHighlightSmall or GameFontHighlight) end
  if button.SetDisabledFontObject then button:SetDisabledFontObject(GameFontDisableSmall or GameFontDisable) end
  if button.SetHighlightTexture then
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "BLEND")
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
      highlight.GSEImportOwned = true
      highlight:SetAlpha(1)
      highlight:SetVertexColor(1, 1, 1, 0.10)
    end
  end

  if not button.GSEImportButtonHooked and button.HookScript then
    button.GSEImportButtonHooked = true
    button:HookScript("OnEnter", function(self) updateImportButtonState(self, true) end)
    button:HookScript("OnLeave", function(self) updateImportButtonState(self, false) end)
    button:HookScript("OnEnable", function(self) updateImportButtonState(self, self.IsMouseOver and self:IsMouseOver()) end)
    button:HookScript("OnDisable", function(self) updateImportButtonState(self, false) end)
  end

  updateImportButtonState(button, button.IsMouseOver and button:IsMouseOver())
end

local function styleImportButton(widget, width, rightAlign)
  if not widget then return end
  if width and widget.SetWidth then widget:SetWidth(width) end
  if rightAlign and widget.SetFlowRightAlign then widget:SetFlowRightAlign(true) end
  styleImportButtonFrame(widget.frame or widget.button or widget)
end

local function setImportTextureAlpha(texture, alpha)
  if texture and texture.SetAlpha then texture:SetAlpha(alpha) end
end

local function styleImportNativeDropdown(widget)
  if not (widget and widget.nativeDropdown and widget.frame) then return end
  local nativeDropdown = widget.nativeDropdown
  local name = nativeDropdown.GetName and nativeDropdown:GetName()

  if not shouldUseModernImportSkin() then
    if widget.GSEImportDropdownChrome then widget.GSEImportDropdownChrome:Hide() end
    if name then
      setImportTextureAlpha(_G[name .. "Left"], 1)
      setImportTextureAlpha(_G[name .. "Middle"], 1)
      setImportTextureAlpha(_G[name .. "Right"], 1)
    end
    local nativeArrow = name and (_G[name .. "Button"] or _G[name .. "ButtonFrame"]) or nativeDropdown.Button
    if nativeArrow then
      setImportTextureAlpha(nativeArrow.GetNormalTexture and nativeArrow:GetNormalTexture(), 1)
      setImportTextureAlpha(nativeArrow.GetPushedTexture and nativeArrow:GetPushedTexture(), 1)
      setImportTextureAlpha(nativeArrow.GetDisabledTexture and nativeArrow:GetDisabledTexture(), 1)
      setImportTextureAlpha(nativeArrow.GetHighlightTexture and nativeArrow:GetHighlightTexture(), 1)
      if nativeArrow.GSEImportChevron then nativeArrow.GSEImportChevron:Hide() end
    end
    return
  end

  if name then
    setImportTextureAlpha(_G[name .. "Left"], 0)
    setImportTextureAlpha(_G[name .. "Middle"], 0)
    setImportTextureAlpha(_G[name .. "Right"], 0)
  end

  local chrome = widget.GSEImportDropdownChrome
  if not chrome then
    chrome = CreateFrame("Frame", nil, widget.frame)
    chrome:EnableMouse(false)
    widget.GSEImportDropdownChrome = chrome
  end
  chrome:ClearAllPoints()
  chrome:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 0, 0)
  chrome:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 0, 0)
  if chrome.SetFrameLevel and nativeDropdown.GetFrameLevel then
    chrome:SetFrameLevel(math.max(0, (nativeDropdown:GetFrameLevel() or 1) - 1))
  end
  ensureImportChrome(chrome)
  layoutImportChrome(chrome, MODERN_IMPORT_BUTTON_BG, MODERN_IMPORT_BUTTON_BORDER, 1)
  chrome:Show()

  local text = name and (_G[name .. "Text"] or _G[name .. "Text"])
  if text then
    text:ClearAllPoints()
    text:SetPoint("LEFT", chrome, "LEFT", 8, 0)
    text:SetPoint("RIGHT", chrome, "RIGHT", -28, 0)
    text:SetJustifyH("LEFT")
    if text.SetTextColor then text:SetTextColor(unpack(MODERN_IMPORT_BUTTON_TEXT)) end
  end

  local arrowButton = name and (_G[name .. "Button"] or _G[name .. "ButtonFrame"]) or nativeDropdown.Button
  if arrowButton then
    arrowButton:ClearAllPoints()
    arrowButton:SetPoint("RIGHT", chrome, "RIGHT", -3, 0)
    arrowButton:SetSize(20, 20)
    setImportTextureAlpha(arrowButton.GetNormalTexture and arrowButton:GetNormalTexture(), 0)
    setImportTextureAlpha(arrowButton.GetPushedTexture and arrowButton:GetPushedTexture(), 0)
    setImportTextureAlpha(arrowButton.GetDisabledTexture and arrowButton:GetDisabledTexture(), 0)
    setImportTextureAlpha(arrowButton.GetHighlightTexture and arrowButton:GetHighlightTexture(), 0)

    if not arrowButton.GSEImportChevron then
      arrowButton.GSEImportChevron = arrowButton:CreateTexture(nil, "OVERLAY")
      arrowButton.GSEImportChevron.GSEImportOwned = true
    end
    arrowButton.GSEImportChevron:SetTexture(MODERN_IMPORT_CHEVRON)
    arrowButton.GSEImportChevron:ClearAllPoints()
    arrowButton.GSEImportChevron:SetPoint("CENTER", arrowButton, "CENTER", 0, 0)
    arrowButton.GSEImportChevron:SetSize(14, 14)
    arrowButton.GSEImportChevron:SetVertexColor(0.92, 0.92, 0.92, 1)
    arrowButton.GSEImportChevron:Show()
  end
end

local function styleImportDropdown(widget)
  if not widget then return end
  if widget.SetDropdownStyle then widget:SetDropdownStyle(true) end
  styleImportButtonFrame(widget.button)
  styleImportNativeDropdown(widget)
  if not widget.GSEImportDropdownHooked and widget.frame and widget.frame.HookScript then
    widget.GSEImportDropdownHooked = true
    widget.frame:HookScript("OnShow", function() styleImportNativeDropdown(widget) end)
  end
end

local importframe = UI:Create("Frame")
GSE.GUIImportFrame = importframe

local function styleImportWindow()
  if not (importframe and importframe.frame) then return end

  if shouldUseModernImportSkin() then
    hideImportTextures(importframe.frame)
    if importframe.titlebar then hideImportTextures(importframe.titlebar) end
    applyModernImportBackdrop(importframe.frame, MODERN_IMPORT_BG, getImportAccent(0.95))
    if importframe.titlebar and importframe.titlebar ~= importframe.frame then
      applyModernImportBackdrop(importframe.titlebar, { 0.015, 0.018, 0.020, 0.96 }, MODERN_IMPORT_MUTED_BORDER)
    end
    if importframe.titletext and importframe.titletext.SetTextColor then
      importframe.titletext:SetTextColor(1, 1, 1, 1)
    end
    if importframe.frame.GSEBodyFill then importframe.frame.GSEBodyFill:Hide() end
    return
  end

  showImportTextures(importframe.frame)
  if importframe.titlebar then showImportTextures(importframe.titlebar) end
  if UI and UI.ApplyNativeWindowSkin then
    UI.ApplyNativeWindowSkin(importframe.frame, importframe.titlebar, importframe.titletext, importframe.closebutton)
  end
end

local function styleImportPanel(panel, height)
  if not panel then return end
  local S = UI.NativeStyle or {}
  local pad = S.padLarge or 10
  panel:SetFullWidth(true)
  if height then panel:SetHeight(height) end
  if panel.SetLeftBorderColor then panel:SetLeftBorderColor(0, 0, 0, 0, 0) end
  if panel.SetListPadding then panel:SetListPadding(pad, pad, pad, pad) end
  if panel.SetListGap then panel:SetListGap(6) end
  if panel.content and panel.frame then
    panel.content:ClearAllPoints()
    panel.content:SetPoint("TOPLEFT",     panel.frame, "TOPLEFT",     pad, -pad)
    panel.content:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", -pad,  pad)
  end
  if shouldUseModernImportSkin() then
    applyModernImportBackdrop(panel.frame, MODERN_IMPORT_PANEL_BG, MODERN_IMPORT_MUTED_BORDER)
  elseif UI and UI.ApplyNativeInsetSkin then
    UI.ApplyNativeInsetSkin(panel.frame)
  end
end

local function createImportPanel(height)
  local panel = UI:Create("InlineGroup")
  panel:SetLayout("List")
  styleImportPanel(panel, height)
  return panel
end

local function createImportToolbar()
  local toolbar = UI:Create("SimpleGroup")
  toolbar:SetFullWidth(true)
  toolbar:SetHeight(28)
  toolbar:SetLayout("Flow")
  if toolbar.SetFlowPadding then toolbar:SetFlowPadding(0, 0, 0, 0) end
  if toolbar.SetFlowGap then toolbar:SetFlowGap(8) end
  if toolbar.SetFlowVAlign then toolbar:SetFlowVAlign("CENTER") end
  return toolbar
end

local function prepareImportFrame()
  importframe:SetLayout("List")
  if importframe.SetListPadding then importframe:SetListPadding(0, 0, 0, 0) end
  if importframe.SetListGap then importframe:SetListGap(8) end
  styleImportWindow()
end

importframe:SetSize(760, 560)
importframe.frame:SetFrameStrata("MEDIUM")
importframe.frame:SetClampedToScreen(true)
importframe.frame:ClearAllPoints()
importframe.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

importframe:Hide()
importframe:SetTitle(L["GSE: Import a Macro String."])
importframe:SetStatusText(L["Import Macro from Forums"])
prepareImportFrame()
importframe:SetCallback(
  "OnClose",
  function(widget)
    if importframe.fromQueue and GSE.IncomingQueue and not GSE.isEmpty(GSE.IncomingQueue) then
      GSE.Print(
        "|cff00ccffGSE Companion:|r " ..
        #GSE.IncomingQueue ..
        " update(s) queued for import. " ..
        "Open the import dialog with " ..
        (GSEOptions and GSEOptions.CommandColour or "|cFF00FFFF") ..
        "/gse import|r " ..
        "or click the Import button in the GSE menu."
      )
    end
    importframe:Hide()
  end
)
importframe:SetLayout("List")
importframe:AddChild(UI:Create("Label"))

-- Create the scrolling content area used by both import flows. Children added to
-- the returned ScrollFrame scroll inside the fixed-height container, leaving the
-- Import button (added to `importframe` directly) anchored at the bottom.
local function setupScrollContent()
  importframe:ReleaseChildren()
  prepareImportFrame()
  local scrollContainer = createImportPanel((importframe.frame:GetHeight() or 400) - 116)
  scrollContainer:SetLayout("Fill")
  importframe:AddChild(scrollContainer)
  local scroll = UI:Create("ScrollFrame")
  scroll:SetLayout("List")
  local S = UI.NativeStyle or {}
  if scroll.SetListPadding then scroll:SetListPadding(S.listPadX or 5, S.listPadTop or 5, S.listPadX or 5, S.listPadBottom or 5) end
  if scroll.SetListGap then scroll:SetListGap(6) end
  scroll:SetFullWidth(true)
  scrollContainer:AddChild(scroll)
  return scroll
end

local function processCollection(payload)
  local scroll = setupScrollContent()
  local header = UI:Create("Heading")
  header:SetText(string.format(L["Processing Collection of %s Elements."], payload.ElementCount))
  header:SetFullWidth(true)
  local importset = {}
  local sequencesfound = false
  scroll:AddChild(header)
  for k, _ in pairs(payload.Sequences) do
    sequencesfound = true
    if GSE.isEmpty(importset["Sequences"]) then
      importset["Sequences"] = {}
    end
    importset["Sequences"][k] = true
  end
  if sequencesfound then
    local sequencelabel = UI:Create("Label")
    sequencelabel:SetText(L["Sequences"])
    sequencelabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(sequencelabel)
    for k, _ in pairs(payload.Sequences) do
      local row = UI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = UI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = UI:Create("CheckBox")
      local label = k
      if GSESequences[0][k] or GSESequences[GSE.GetCurrentClassID()][k] then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Sequences"][k])
      chkbox:SetWidth(560)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Sequences"][k] = key
        end
      )
      row:AddChild(chkbox)
      scroll:AddChild(row)
    end
  end

  local variablesfound = false
  for k, _ in pairs(payload.Variables) do
    variablesfound = true
    if GSE.isEmpty(importset["Variables"]) then
      importset["Variables"] = {}
    end
    importset["Variables"][k] = true
  end
  if variablesfound then
    local variablelabel = UI:Create("Label")
    variablelabel:SetText(L["Variables"])
    variablelabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(variablelabel)
    for k, _ in pairs(payload.Variables) do
      local row = UI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = UI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = UI:Create("CheckBox")
      local label = k
      if GSEVariables[k] then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Variables"][k])
      chkbox:SetWidth(560)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Variables"][k] = key
        end
      )
      row:AddChild(chkbox)
      scroll:AddChild(row)
    end
  end

  local macrosfound = false
  for k, _ in pairs(payload["Macros"]) do
    macrosfound = true
    if GSE.isEmpty(importset["Macros"]) then
      importset["Macros"] = {}
    end
    importset["Macros"][k] = true
  end

  if macrosfound then
    local macroLabel = UI:Create("Label")
    macroLabel:SetText(L["Macros"])
    macroLabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(macroLabel)
    local char, realm = UnitFullName("player")
    for k, _ in pairs(payload["Macros"]) do
      local row = UI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = UI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = UI:Create("CheckBox")
      local label = k
      if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
        GSEMacros[char .. "-" .. realm] = {}
      end
      if GSEMacros[k] or GSEMacros[char .. "-" .. realm][k] or GetMacroIndexByName(k) then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Macros"][k])
      chkbox:SetWidth(560)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Macros"][k] = key
        end
      )
      row:AddChild(chkbox)
      scroll:AddChild(row)
    end
  end

  local toolbarrow = createImportToolbar()
  local importbutton = UI:Create("Button")
  importbutton:SetText(L["Import"])
  styleImportButton(importbutton, 150)
  importbutton:SetCallback(
    "OnClick",
    function()
      local filteredpayload = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {},
        ["ElementCount"] = 0
      }
      -- processWAGOImport returns nil when it refuses an incompatible
      -- legacy record (Macros-only). Skip those silently — the function
      -- already printed the user-facing "upload to gse.tools" message.
      if importset["Sequences"] then
        for k, v in pairs(importset["Sequences"]) do
          if v then
            if type(payload["Sequences"][k]) == "table" then
              payload["Sequences"][k] = GSE.processWAGOImport(payload["Sequences"][k])
            end
            if payload["Sequences"][k] ~= nil then
              filteredpayload["Sequences"][k] = payload["Sequences"][k]
              filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
            end
          end
        end
      end
      if importset["Variables"] then
        for k, v in pairs(importset["Variables"]) do
          if v then
            if type(payload["Variables"][k]) == "table" then
              payload["Variables"][k] = GSE.processWAGOImport(payload["Variables"][k])
            end
            if payload["Variables"][k] ~= nil then
              filteredpayload["Variables"][k] = payload["Variables"][k]
              filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
            end
          end
        end
      end
      if importset["Macros"] then
        for k, v in pairs(importset["Macros"]) do
          if v then
            if type(payload["Macros"][k]) == "table" then
              payload["Macros"][k] = GSE.processWAGOImport(payload["Macros"][k])
            end
            if payload["Macros"][k] ~= nil then
              filteredpayload["Macros"][k] = payload["Macros"][k]
              filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
            end
          end
        end
      end
      local importstring =
        GSE.EncodeMessage(
        {
          ["type"] = "COLLECTION",
          ["payload"] = filteredpayload
        }
      )
      local success = GSE.ImportSerialisedSequence(importstring, importframe.AutoCreateIcon)
      if success then
        -- Mark imported by identity so the Companion can prune them from the bridge data
        if importframe.fromQueue then
          if GSE.IncomingQueue and GSE.CompanionMarkImported then
            for _, item in ipairs(GSE.IncomingQueue) do
              GSE.CompanionMarkImported(item)
            end
          end
          GSE.IncomingQueue = {}
          importframe.fromQueue = false
        end
        importframe:Hide()
      else
        GSE.GUIShowImportFailure()
      end
    end
  )
  toolbarrow:AddChild(importbutton)
  importframe:AddChild(toolbarrow)
end

-- Derive a display heading from what is actually inside a collection payload.
-- Falls back through: sequence names → variable names → macro names → fallback string.
local function collectionHeading(col, index)
  local seqKeys = {}
  for k in pairs(col.payload.Sequences or {}) do table.insert(seqKeys, k) end
  if #seqKeys > 0 then return table.concat(seqKeys, ", ") end

  local varKeys = {}
  for k in pairs(col.payload.Variables or {}) do table.insert(varKeys, k) end
  if #varKeys > 0 then return table.concat(varKeys, ", ") .. " (" .. L["Variables"] .. ")" end

  local macroKeys = {}
  for k in pairs(col.payload.Macros or {}) do table.insert(macroKeys, k) end
  if #macroKeys > 0 then return table.concat(macroKeys, ", ") .. " (" .. L["Macros"] .. ")" end

  return col.name or ("Collection " .. index)
end

-- Return a coloured status tag: "(Update)" if the item already exists, "(New)" if not.
local function statusTag(exists)
  if exists then
    return GSEOptions.COMMENT .. " (Update)" .. Statics.StringReset
  end
  return "|cff00ff7f (New)|r"
end

-- Truncate a string to maxLen, appending "…" if needed.
local function truncate(str, maxLen)
  if not str or str == "" then return nil end
  if #str <= maxLen then return str end
  return str:sub(1, maxLen - 1) .. "…"
end

-- Add a greyed sub-line of descriptive text under the current item.
local function addDescLabel(container, text)
  if not text or text == "" then return end
  local lbl = UI:Create("Label")
  lbl:SetText("|cff888888" .. text .. "|r")
  lbl:SetFullWidth(true)
  container:AddChild(lbl)
end

-- Per-row action helper. Replaces the old single-checkbox-per-row UI with a
-- 4-state dropdown so the user can resolve conflicts inline rather than via
-- popup interruptions:
--   Import  – default; routes through ImportSerialisedSequence (which may
--             still show a compare dialog if the item exists locally)
--   Replace – overwrite local with the incoming version, no dialog
--   Merge   – append incoming Versions to the local sequence (sequences only;
--             vars/macros treat Merge as Replace because they have no version
--             concept)
--   Ignore  – do not import; mark this entry as imported so it doesn't surface
--             again in the queue
-- includeMerge is false for Variables/Macros to keep the menu honest.
local function addActionRow(scroll, label, importsetSlot, key, includeMerge)
  local row = UI:Create("SimpleGroup")
  row:SetLayout("Flow")
  row:SetFullWidth(true)
  row:SetFlowVAlign("MIDDLE")
  local spacer = UI:Create("Label")
  spacer:SetText("") spacer:SetWidth(30)
  row:AddChild(spacer)
  local nameLabel = UI:Create("Label")
  nameLabel:SetText(label)
  nameLabel:SetWidth(460)
  row:AddChild(nameLabel)
  local dd = UI:Create("Dropdown")
  if includeMerge then
    dd:SetList({ Import = "Import", Replace = "Replace", Merge = "Merge", Ignore = "Ignore" },
               { "Import", "Replace", "Merge", "Ignore" })
  else
    dd:SetList({ Import = "Import", Replace = "Replace", Ignore = "Ignore" },
               { "Import", "Replace", "Ignore" })
  end
  dd:SetValue("Import")
  dd:SetWidth(120)
  styleImportDropdown(dd)
  dd:SetFlowRightAlign(true)
  importsetSlot[key] = "Import"
  dd:SetCallback("OnValueChanged", function(_, _, val)
    importsetSlot[key] = val
  end)
  row:AddChild(dd)
  scroll:AddChild(row)
end

-- Forward declaration so callbacks defined inside processQueueCollections,
-- renderDeletesPage, and the landing-page banner can call processQueue()
-- to advance to the next page (or phase). Assigned at the bottom of the
-- file, after renderImportsPage and renderDeletesPage are defined.
local processQueue
-- Forward-declared because LandingPage's banner button calls into it before
-- the full definition appears further down the file.
local renderQueueManager

-- Render a list of decoded collections (each with its own heading) and a single
-- Import button that re-encodes and imports each collection separately.
-- collections: array of { name=string, payload={Sequences,Variables,Macros,ElementCount} }
local function processQueueCollections(collections)
  local scroll = setupScrollContent()

  -- Per-collection, per-key per-action choice:
  --   importset[i][category][key] = "Import"|"Replace"|"Merge"|"Ignore"
  local importset = {}
  local char, realm = UnitFullName("player")

  for i, col in ipairs(collections) do
    importset[i] = { Sequences = {}, Variables = {}, Macros = {} }
    local payload = col.payload

    -- ── Collection heading ────────────────────────────────────────────────
    local header = UI:Create("Heading")
    header:SetText(collectionHeading(col, i))
    header:SetFullWidth(true)
    scroll:AddChild(header)

    -- Collect HelpTxt from all sequences in this collection for the summary line.
    -- Shows beneath the heading so the user knows what the collection is for.
    local seqDescs = {}
    for _, seqData in pairs(payload.Sequences or {}) do
      if type(seqData) == "table" and type(seqData.MetaData) == "table" then
        local txt = truncate(seqData.MetaData.HelpTxt, 120)
        if txt then table.insert(seqDescs, txt) end
      end
    end
    addDescLabel(scroll, table.concat(seqDescs, "  ·  "))

    -- ── Sequences ─────────────────────────────────────────────────────────
    local sequencesfound = next(payload.Sequences or {}) ~= nil
    if sequencesfound then
      local lbl = UI:Create("Label")
      lbl:SetText(L["Sequences"])
      lbl:SetFontObject(GameFontNormalLarge)
      scroll:AddChild(lbl)
      for k, seqData in pairs(payload.Sequences or {}) do
        local exists = false
        for cid = 0, 13 do
          if GSESequences[cid] and GSESequences[cid][k] then exists = true break end
        end
        addActionRow(scroll, k .. " " .. statusTag(exists), importset[i].Sequences, k, true)
        if type(seqData) == "table" and type(seqData.MetaData) == "table" then
          local eleDesc = truncate(seqData.MetaData.HelpTxt, 160)
          if eleDesc and (#seqDescs == 0 or #payload.Sequences > 1) then
            local drow = UI:Create("SimpleGroup")
            drow:SetLayout("Flow") drow:SetFullWidth(true)
            local dspacer = UI:Create("Label")
            dspacer:SetText("") dspacer:SetWidth(50)
            drow:AddChild(dspacer)
            local dlbl = UI:Create("Label")
            dlbl:SetText("|cff888888" .. eleDesc .. "|r")
            dlbl:SetFullWidth(true)
            drow:AddChild(dlbl)
            scroll:AddChild(drow)
          end
        end
      end
    end

    -- ── Variables ─────────────────────────────────────────────────────────
    local variablesfound = next(payload.Variables or {}) ~= nil
    if variablesfound then
      local lbl = UI:Create("Label")
      lbl:SetText(L["Variables"])
      lbl:SetFontObject(GameFontNormalLarge)
      scroll:AddChild(lbl)
      for k, _ in pairs(payload.Variables or {}) do
        addActionRow(scroll, k .. " " .. statusTag(not GSE.isEmpty(GSEVariables[k])),
                     importset[i].Variables, k, false)
      end
    end

    -- ── Macros ────────────────────────────────────────────────────────────
    local macrosfound = next(payload.Macros or {}) ~= nil
    if macrosfound then
      local lbl = UI:Create("Label")
      lbl:SetText(L["Macros"])
      lbl:SetFontObject(GameFontNormalLarge)
      scroll:AddChild(lbl)
      if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
        GSEMacros[char .. "-" .. realm] = {}
      end
      for k, _ in pairs(payload.Macros or {}) do
        local topLevel = GSEMacros[k]
        local isMacroNode = type(topLevel) == "table"
            and (type(topLevel.text) == "string" or type(topLevel.name) == "string")
        local charBucket = GSEMacros[char .. "-" .. realm]
        local macIdx = GetMacroIndexByName(k)
        local exists = isMacroNode
                    or (type(charBucket) == "table" and charBucket[k] ~= nil)
                    or (type(macIdx) == "number" and macIdx > 0)
        addActionRow(scroll, k .. " " .. statusTag(exists), importset[i].Macros, k, false)
      end
    end
  end

  -- Single Import button at the bottom — imports each collection separately
  local toolbarrow = createImportToolbar()
  local importbutton = UI:Create("Button")
  importbutton:SetText(L["Import"])
  styleImportButton(importbutton, 150)
  importbutton:SetCallback("OnClick", function()
    local anyFailed = false
    local successByName = {}
    -- Group each collection's checked items into 3 action buckets. Ignore
    -- entries are excluded from the buckets entirely — they get marked as
    -- imported (so they don't return) without producing any storage
    -- mutation. Each non-empty bucket is encoded as its own COLLECTION
    -- payload and dispatched with the matching ImportSerialisedSequence
    -- flags: forcereplace for Replace, forcemerge for Merge, neither for
    -- Import (which keeps the existing compare-on-conflict behaviour).
    for i, col in ipairs(collections) do
      local buckets = {
        Import  = { Sequences = {}, Variables = {}, Macros = {}, n = 0 },
        Replace = { Sequences = {}, Variables = {}, Macros = {}, n = 0 },
        Merge   = { Sequences = {}, Variables = {}, Macros = {}, n = 0 },
      }
      local hadAnyAction = false
      local addToBucket = function(category, k, v, action)
        local bucket = buckets[action]
        if not bucket then return end
        -- Match manual-paste path (processCollection at the top of this
        -- file): processWAGOImport WITHOUT dontencode returns the encoded
        -- string. The outer EncodeMessage wraps it, the recursive
        -- ImportSerialisedSequence DecodeMessages back. The round-trip
        -- is identical end-to-end to a user pasting the string into the
        -- import box, so any future "manual works / dialog doesn't" gap
        -- is structurally impossible — both paths are the same bytes.
        if type(v) == "table" then v = GSE.processWAGOImport(v) end
        -- processWAGOImport returns nil when it refuses (pre-#1853 Macros-
        -- only records). User-facing message already printed; skip this
        -- entry so the rest of the batch still imports.
        if v == nil then return end
        bucket[category][k] = v
        bucket.n = bucket.n + 1
      end
      for k, action in pairs(importset[i].Sequences) do
        hadAnyAction = true
        if action ~= "Ignore" and col.payload.Sequences[k] then
          addToBucket("Sequences", k, col.payload.Sequences[k], action)
        end
      end
      for k, action in pairs(importset[i].Variables) do
        hadAnyAction = true
        -- Variables/Macros have no Merge concept — fold Merge into Replace.
        local effective = (action == "Merge") and "Replace" or action
        if effective ~= "Ignore" and col.payload.Variables[k] then
          addToBucket("Variables", k, col.payload.Variables[k], effective)
        end
      end
      for k, action in pairs(importset[i].Macros) do
        hadAnyAction = true
        local effective = (action == "Merge") and "Replace" or action
        if effective ~= "Ignore" and col.payload.Macros[k] then
          addToBucket("Macros", k, col.payload.Macros[k], effective)
        end
      end

      local colSuccess = true
      for action, b in pairs(buckets) do
        if b.n > 0 then
          local payload = { Sequences = b.Sequences, Variables = b.Variables, Macros = b.Macros, ElementCount = b.n }
          -- Re-encode the outer COLLECTION as a string so the recursive
          -- decode path is identical to manual paste. ImportSerialisedSequence
          -- accepts a table form but the dialog needs to match manual
          -- byte-for-byte so the "manual works / dialog doesn't" class of
          -- bug can't recur — both paths now traverse the same EncodeMessage
          -- → DecodeMessage round-trip.
          local importstring = GSE.EncodeMessage({ ["type"] = "COLLECTION", ["payload"] = payload })
          local forcereplace = (action == "Replace") or importframe.AutoCreateIcon
          local forcemerge   = (action == "Merge")
          local ok = GSE.ImportSerialisedSequence(importstring, forcereplace, false, forcemerge)
          if not ok then colSuccess = false end
        end
      end
      -- A collection counts as "successfully resolved" (and so its
      -- IncomingQueue item gets marked) when every non-Ignore action
      -- succeeded, OR when every action was Ignore (the user explicitly
      -- dismissed the whole entry).
      if hadAnyAction and colSuccess then
        successByName[col.name or ""] = true
      end
      if not colSuccess then anyFailed = true end
    end
    if importframe.fromQueue then
      local pageSize = importframe.pageSize or 0
      if GSE.IncomingQueue and GSE.CompanionMarkImported and pageSize > 0 then
        -- Only mark the items rendered on THIS page. The rest of
        -- IncomingQueue (page 2+) must remain unmarked so it surfaces
        -- next dialog open / next /reload.
        for idx = 1, pageSize do
          local item = GSE.IncomingQueue[idx]
          if item and successByName[item.name or ""] then
            GSE.CompanionMarkImported(item)
          end
        end
      end
      -- Drop the rendered slice from the front of the queue. Anything
      -- behind it is the "next page".
      if pageSize > 0 then
        for _ = 1, pageSize do
          if GSE.IncomingQueue and GSE.IncomingQueue[1] then
            table.remove(GSE.IncomingQueue, 1)
          end
        end
      end
      importframe.fromQueue = false
      importframe.pageSize = nil
      importframe.pageTotal = nil
    end
    importframe:Hide()
    if anyFailed then
      GSE.GUIShowImportFailure()
    end
    -- Auto-advance: more imports → next imports page; otherwise fall
    -- through to deletes. processQueue() is a no-op once both queues
    -- are empty.
    if processQueue then processQueue() end
  end)
  toolbarrow:AddChild(importbutton)
  importframe:AddChild(toolbarrow)
end

-- Decode all items in GSE.IncomingQueue, keeping each as its own collection,
-- and present them grouped. Called from login notification or the landing page.
-- How many incoming items the dialog renders per pass. The Companion
-- now writes the FULL backlog into the bridge file, so pagination is the
-- addon's job: import the visible page, /reload (or wait for prune+next
-- ProcessBridgeData), see the next page.
local QUEUE_PAGE_SIZE = 20

-- Imports phase renderer — original processQueue body. Called by the
-- phase dispatcher when GSE.IncomingQueue has pending entries.
local function renderImportsPage()
  if not GSE.IncomingQueue or GSE.isEmpty(GSE.IncomingQueue) then return end
  local total = #GSE.IncomingQueue
  local pageEnd = math.min(QUEUE_PAGE_SIZE, total)

  local collections = {}
  for idx = 1, pageEnd do
    local item = GSE.IncomingQueue[idx]
    for seqName, encoded in pairs(item.sequences or {}) do
      local ok, collection = GSE.DecodeMessage(encoded)
      if ok and collection.type == "COLLECTION" then
        table.insert(collections, {
          name    = item.name or seqName,
          payload = collection.payload,
        })
      end
    end
  end

  if #collections == 0 then
    GSE.Print("|cff00ccffGSE Platform:|r No valid content found in the queue.")
    return
  end

  importframe.fromQueue = true
  importframe.pageSize = pageEnd
  importframe.pageTotal = total
  processQueueCollections(collections)
  importframe:Show()
end

-- Deletes phase: paginated review of GSE.PendingBridgeDeletes with per-
-- entry Delete/Ignore dropdowns. Auto-accept doesn't apply here; every
-- page requires explicit user confirmation. After Confirm the rendered
-- slice is drained from PendingBridgeDeletes and processQueue() runs
-- again to either show the next deletes page or close out.
local function renderDeletesPage()
  if not GSE.PendingBridgeDeletes or GSE.isEmpty(GSE.PendingBridgeDeletes) then return end
  local total = #GSE.PendingBridgeDeletes
  local pageEnd = math.min(QUEUE_PAGE_SIZE, total)

  -- Snapshot the page so the dialog renders a stable view even if other
  -- code mutates the table mid-dialog (e.g. a save-cancels-delete fires
  -- while the dialog is open).
  local pageEntries = {}
  for idx = 1, pageEnd do pageEntries[idx] = GSE.PendingBridgeDeletes[idx] end

  local scroll = setupScrollContent()
  local header = UI:Create("Heading")
  if total > QUEUE_PAGE_SIZE then
    header:SetText(string.format(
      "GSE Companion: pending deletes  1-%d of %d", pageEnd, total))
  else
    header:SetText(string.format(
      "GSE Companion: pending deletes  (%d)", total))
  end
  header:SetFullWidth(true)
  scroll:AddChild(header)

  local desc = UI:Create("Label")
  desc:SetText(
    "Pick |cFFFF6666Delete|r to remove the entry from your local SavedVariables. " ..
    "Pick |cFFAAAAAAIgnore|r to keep it (a save of the same name will also cancel " ..
    "the pending delete). Either choice closes the entry out — it won't return " ..
    "on next sync."
  )
  desc:SetFullWidth(true)
  scroll:AddChild(desc)

  local actionsByIndex = {}
  for idx, d in ipairs(pageEntries) do
    local row = UI:Create("SimpleGroup")
    row:SetLayout("Flow"); row:SetFullWidth(true)
    local sp = UI:Create("Label"); sp:SetText(""); sp:SetWidth(30)
    row:AddChild(sp)
    local nameLabel = UI:Create("Label")
    nameLabel:SetText(string.format("%s  |cFF888888(%s)|r",
      tostring(d.name or "?"), tostring(d.contentType or "sequence")))
    nameLabel:SetWidth(560)
    row:AddChild(nameLabel)
    local dd = UI:Create("Dropdown")
    dd:SetList({ Delete = "Delete", Ignore = "Ignore" }, { "Delete", "Ignore" })
    dd:SetValue("Delete")
    dd:SetWidth(120)
    styleImportDropdown(dd)
    actionsByIndex[idx] = "Delete"
    dd:SetCallback("OnValueChanged", function(_, _, val)
      actionsByIndex[idx] = val
    end)
    row:AddChild(dd)
    scroll:AddChild(row)
  end

  local toolbarrow = createImportToolbar()
  local confirmbutton = UI:Create("Button")
  confirmbutton:SetText("Confirm")
  styleImportButton(confirmbutton, 150)
  confirmbutton:SetCallback("OnClick", function()
    for idx, d in ipairs(pageEntries) do
      local act = actionsByIndex[idx] or "Ignore"
      if GSE.CompanionConfirmDelete then
        GSE.CompanionConfirmDelete(d.id, d.contentType, d.name, d.classid, act)
      end
    end
    importframe:Hide()
    -- Advance: another page of deletes or wrap up.
    if processQueue then processQueue() end
  end)
  toolbarrow:AddChild(confirmbutton)
  importframe:AddChild(toolbarrow)
  importframe:Show()
end

-- Phase dispatcher. Strict separation — never mix imports + deletes on a
-- page. Imports drain first; only after IncomingQueue is empty do deletes
-- surface. Called from the landing-page banner button, the login banner,
-- and post-page auto-advance after each Import/Confirm click.
processQueue = function()
  if GSE.IncomingQueue and not GSE.isEmpty(GSE.IncomingQueue) then
    return renderImportsPage()
  end
  if GSE.PendingBridgeDeletes and not GSE.isEmpty(GSE.PendingBridgeDeletes) then
    return renderDeletesPage()
  end
end

local function LandingPage()
  importframe:ReleaseChildren()
  prepareImportFrame()
  importframe.fromQueue = false
  local hasBanner = false

  -- If the platform queue has pending content, show a banner button at the top
  if GSE.IncomingQueue and not GSE.isEmpty(GSE.IncomingQueue) then
    hasBanner = true
    local queueBanner = createImportPanel(76)
    local queueLabel = UI:Create("Label")
    local total = #GSE.IncomingQueue
    local visible = math.min(QUEUE_PAGE_SIZE, total)
    local label
    if total > QUEUE_PAGE_SIZE then
      label = "|cff00ccffGSE Platform:|r  Showing " .. visible ..
              " of " .. total .. " queued update(s). Import this batch to see the next."
    else
      label = "|cff00ccffGSE Platform:|r  " .. total .. " queued update(s) waiting to be imported."
    end
    queueLabel:SetText(label)
    queueLabel:SetFullWidth(true)
    queueBanner:AddChild(queueLabel)
    local queueButtons = createImportToolbar()
    local queueButton = UI:Create("Button")
    queueButton:SetText("Import Platform Updates")
    styleImportButton(queueButton, 200)
    queueButton:SetCallback("OnClick", function()
      processQueue()
    end)
    queueButtons:AddChild(queueButton)
    local manageButton = UI:Create("Button")
    manageButton:SetText("Manage Queue")
    styleImportButton(manageButton, 140)
    manageButton:SetCallback("OnClick", function()
      renderQueueManager()
    end)
    queueButtons:AddChild(manageButton)
    queueBanner:AddChild(queueButtons)
    importframe:AddChild(queueBanner)
    local divider = UI:Create("Heading")
    divider:SetText("  - or paste a string below -  ")
    divider:SetFullWidth(true)
    importframe:AddChild(divider)
  elseif GSE.PendingBridgeDeletes and not GSE.isEmpty(GSE.PendingBridgeDeletes) then
    -- Imports queue is empty but deletes are pending — let the user resolve
    -- them from the same dialog they'd use for imports.
    hasBanner = true
    local delBanner = createImportPanel(76)
    local delLabel = UI:Create("Label")
    delLabel:SetText("|cff00ccffGSE Platform:|r  " .. #GSE.PendingBridgeDeletes ..
                     " pending delete(s) awaiting your review.")
    delLabel:SetFullWidth(true)
    delBanner:AddChild(delLabel)
    local delButtons = createImportToolbar()
    local delButton = UI:Create("Button")
    delButton:SetText("Review Deletes")
    styleImportButton(delButton, 200)
    delButton:SetCallback("OnClick", function() processQueue() end)
    delButtons:AddChild(delButton)
    delBanner:AddChild(delButtons)
    importframe:AddChild(delBanner)
    local divider = UI:Create("Heading")
    divider:SetText("  - or paste a string below -  ")
    divider:SetFullWidth(true)
    importframe:AddChild(divider)
  end

  local pastePanelHeight = hasBanner and 332 or 408
  local pastePanel = createImportPanel(pastePanelHeight)
  local importsequencebox = UI:Create("MultiLineEditBox")
  local recbutton = UI:Create("Button")

  importsequencebox:SetLabel(L["GSE Collection to Import."])
  importsequencebox:SetHeight(pastePanelHeight - 40)
  importsequencebox:DisableButton(true)
  importsequencebox:SetFullWidth(true)
  pastePanel:AddChild(importsequencebox)
  importframe:AddChild(pastePanel)

  GSE.GUIImportFrame = importframe
  local recButtonGroup = createImportToolbar()
  recbutton:SetText(L["Import"])
  styleImportButton(recbutton, 150)
  recbutton:SetCallback(
    "OnClick",
    function()
      local importstring = importsequencebox:GetText()
      importstring = GSE.TrimWhiteSpace(importstring)
      -- Either a compressed import or a failed copy
      local decompresssuccess, actiontable = GSE.DecodeMessage(importstring)
      if decompresssuccess and actiontable.type == "COLLECTION" then
        processCollection(actiontable.payload)
      else
        local success = GSE.ImportSerialisedSequence(importstring, importframe.AutoCreateIcon)
        if success then
          importsequencebox:SetText("")
          importframe:Hide()
        else
          GSE.GUIShowImportFailure()
        end
      end
    end
  )
  recButtonGroup:AddChild(recbutton)
  importframe:AddChild(recButtonGroup)

  importframe:Show()
end

function GSE.ShowImport()
  if importframe then
    importframe:SetSize(760, 560)
  end
  LandingPage()
  if importframe and importframe.frame then
    UI.MakePopup(importframe.frame, {center = true})
    if importframe.frame.Raise then importframe.frame:Raise() end
    importframe.frame:Show()
  end
end

-- Called by the login notification or the GSE menu to jump straight to the queue
function GSE.ShowIncomingQueue()
  processQueue()
end

-- Build a human-readable summary of one queue item for the manager view.
-- Items hold a list of encoded collections under .sequences keyed by name;
-- decode lazily and concatenate the inner sequence/variable/macro names.
local function describeQueueEntry(item)
  if type(item) ~= "table" then return "?" end
  local detailParts = {}
  for _, encoded in pairs(item.sequences or {}) do
    local ok, collection = GSE.DecodeMessage(encoded)
    if ok and collection and collection.payload then
      local p = collection.payload
      for k in pairs(p.Sequences or {}) do table.insert(detailParts, k) end
      for k in pairs(p.Variables or {}) do table.insert(detailParts, k .. " (Var)") end
      for k in pairs(p.Macros or {}) do table.insert(detailParts, k .. " (Mac)") end
    end
  end
  if #detailParts == 0 then return tostring(item.name or "?") end
  return string.format("%s  |cff888888[%s]|r",
    tostring(item.name or "?"), table.concat(detailParts, ", "))
end

renderQueueManager = function()
  importframe:ReleaseChildren()
  importframe.fromQueue = false

  local scroll = setupScrollContent()
  local total = GSE.IncomingQueue and #GSE.IncomingQueue or 0

  local header = UI:Create("Heading")
  header:SetText(string.format(
    "|cff00ccffGSE Companion:|r Incoming queue (%d)", total))
  header:SetFullWidth(true)
  scroll:AddChild(header)

  if total == 0 then
    local empty = UI:Create("Label")
    empty:SetText("Queue is empty.")
    empty:SetFullWidth(true)
    scroll:AddChild(empty)
  else
    local desc = UI:Create("Label")
    desc:SetText(
      "|cFFFF6666Remove|r drops one entry from the queue and tells the " ..
      "Companion to prune it (won't re-sync). |cFFFF6666Clear All|r does " ..
      "the same for every entry."
    )
    desc:SetFullWidth(true)
    scroll:AddChild(desc)

    -- Snapshot a stable view: render row-by-row using the original indices.
    -- Removing during iteration mutates GSE.IncomingQueue, so each Remove
    -- click re-renders rather than touching the live row list in place.
    for idx = 1, total do
      local item = GSE.IncomingQueue[idx]
      local row = UI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)

      local label = UI:Create("Label")
      label:SetText(describeQueueEntry(item))
      label:SetWidth(620)
      row:AddChild(label)

      local removeBtn = UI:Create("Button")
      removeBtn:SetText("Remove")
      styleImportButton(removeBtn, 100)
      removeBtn:SetCallback("OnClick", function()
        if GSE.RemoveIncomingQueueEntry then
          GSE.RemoveIncomingQueueEntry(idx)
        end
        renderQueueManager()
      end)
      row:AddChild(removeBtn)
      scroll:AddChild(row)
    end
  end

  local toolbar = createImportToolbar()

  local clearBtn = UI:Create("Button")
  clearBtn:SetText("Clear All")
  clearBtn:SetDisabled(total == 0)
  styleImportButton(clearBtn, 140)
  clearBtn:SetCallback("OnClick", function()
    if GSE.ClearIncomingQueue then GSE.ClearIncomingQueue() end
    importframe:Hide()
  end)
  toolbar:AddChild(clearBtn)

  local closeBtn = UI:Create("Button")
  closeBtn:SetText(L["Close"] or "Close")
  styleImportButton(closeBtn, 140)
  closeBtn:SetCallback("OnClick", function() importframe:Hide() end)
  toolbar:AddChild(closeBtn)

  importframe:AddChild(toolbar)
  importframe:Show()
end

-- Open the queue-manager dialog (list + per-row remove + clear all).
-- Different from GSE.ShowIncomingQueue, which jumps into the import flow.
function GSE.ShowIncomingQueueManager()
  renderQueueManager()
end

-- Register import frame for GSE UI scale
if importframe and importframe.frame and GSE.RegisterUIScaleFrame then
    GSE.RegisterUIScaleFrame(importframe.frame)
end
