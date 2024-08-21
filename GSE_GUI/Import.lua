local GSE = GSE
local Statics = GSE.Static

local AceGUI = LibStub("AceGUI-3.0")
local L = GSE.L

local importframe = AceGUI:Create("Frame")
GSE.GUIImportFrame = importframe

importframe.frame:SetFrameStrata("MEDIUM")
importframe.frame:SetClampedToScreen(true)

importframe:Hide()
importframe:SetTitle(L["GSE: Import a Macro String."])
importframe:SetStatusText(L["Import Macro from Forums"])
importframe:SetCallback(
  "OnClose",
  function(widget)
    importframe:Hide()
  end
)
importframe:SetLayout("List")
importframe:AddChild(AceGUI:Create("Label"))

local function fixContainer(v)
  local fixedTable = {}
  for k, val in pairs(v) do
    if type(v[k]) == "table" then
      if tonumber(k) then
        fixedTable[tonumber(k)] = {}
        fixedTable[tonumber(k)] = fixContainer(val)
      else
        fixedTable[k] = fixContainer(val)
      end
    else
      fixedTable[k] = val
    end
  end
  for k, val in ipairs(v) do
    if type(v[k]) == "table" then
      fixedTable[k] = fixContainer(val)
    else
      fixedTable[k] = val
    end
  end
  return fixedTable
end

local function processWAGOImport(input)
  for k, v in ipairs(input) do
    if type(v) == "table" then
      print("fixing ipair " .. k)
      input[k] = fixContainer(v)
    end
  end
  for k, v in pairs(input) do
    if type(v) == "table" then
      print("fixing pair " .. k)
      input[k] = fixContainer(v)
    end
  end
  return GSE.EncodeMessage(input)
end

local function processCollection(payload)
  importframe:ReleaseChildren()
  importframe:SetLayout("List")
  local header = AceGUI:Create("Heading")
  header:SetText(string.format(L["Processing Collection of %s Elements."], payload.ElementCount))
  header:SetFullWidth(true)
  local importset = {}
  local sequencesfound = false
  importframe:AddChild(header)
  for k, _ in pairs(payload.Sequences) do
    sequencesfound = true
    if GSE.isEmpty(importset["Sequences"]) then
      importset["Sequences"] = {}
    end
    importset["Sequences"][k] = true
  end
  if sequencesfound then
    local sequencelabel = AceGUI:Create("Label")
    sequencelabel:SetText(L["Sequences"])
    sequencelabel:SetFontObject(GameFontNormalLarge)
    importframe:AddChild(sequencelabel)
    for k, _ in pairs(payload.Sequences) do
      local row = AceGUI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = AceGUI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = AceGUI:Create("CheckBox")
      local label = k
      if GSESequences[0][k] or GSESequences[GSE.GetCurrentClassID()][k] then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Sequences"][k])
      chkbox:SetWidth(400)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Sequences"][k] = key
        end
      )
      row:AddChild(chkbox)
      importframe:AddChild(row)
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
    local variablelabel = AceGUI:Create("Label")
    variablelabel:SetText(L["Variables"])
    variablelabel:SetFontObject(GameFontNormalLarge)
    importframe:AddChild(variablelabel)
    for k, _ in pairs(payload.Variables) do
      local row = AceGUI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = AceGUI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = AceGUI:Create("CheckBox")
      local label = k
      if GSEVariables[k] then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Variables"][k])
      chkbox:SetWidth(400)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Variables"][k] = key
        end
      )
      row:AddChild(chkbox)
      importframe:AddChild(row)
    end
  end

  local macrosfound = false
  for k, _ in pairs(payload.Macros) do
    macrosfound = true
    if GSE.isEmpty(importset["Macros"]) then
      importset["Macros"] = {}
    end
    importset["Macros"][k] = true
  end

  if macrosfound then
    local macroLabel = AceGUI:Create("Label")
    macroLabel:SetText(L["Macros"])
    macroLabel:SetFontObject(GameFontNormalLarge)
    importframe:AddChild(macroLabel)
    local char, realm = UnitFullName("player")
    for k, _ in pairs(payload.Macros) do
      local row = AceGUI:Create("SimpleGroup")
      row:SetLayout("Flow")
      row:SetFullWidth(true)
      local spacer = AceGUI:Create("Label")
      spacer:SetText("")
      spacer:SetWidth(30)
      row:AddChild(spacer)
      local chkbox = AceGUI:Create("CheckBox")
      local label = k
      if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
        GSEMacros[char .. "-" .. realm] = {}
      end
      if GSEMacros[k] or GSEMacros[char .. "-" .. realm][k] then
        label = label .. GSEOptions.COMMENT .. " (" .. L["Already Known"] .. ") " .. Statics.StringReset
      end
      chkbox:SetLabel(label)
      chkbox:SetValue(importset["Macros"][k])
      chkbox:SetWidth(400)
      chkbox:SetCallback(
        "OnValueChanged",
        function(obj, event, key)
          importset["Macros"][k] = key
        end
      )
      row:AddChild(chkbox)
      importframe:AddChild(row)
    end
  end

  local toolbarrow = AceGUI:Create("SimpleGroup")
  toolbarrow:SetFullWidth(true)
  local spacerx = AceGUI:Create("Label")
  spacerx:SetWidth(500)
  spacerx:SetText()
  toolbarrow:AddChild(spacerx)
  local importbutton = AceGUI:Create("Button")
  importbutton:SetText(L["Import"])
  importbutton:SetCallback(
    "OnClick",
    function()
      local filteredpayload = {
        ["Sequences"] = {},
        ["Variables"] = {},
        ["Macros"] = {},
        ["ElementCount"] = 0
      }
      if importset["Sequences"] then
        for k, v in pairs(importset["Sequences"]) do
          if v then
            if type(payload["Sequences"][k]) == "table" then
              payload["Sequences"][k] = processWAGOImport(payload["Sequences"][k])
            end
            filteredpayload["Sequences"][k] = payload["Sequences"][k]
            filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
          end
        end
      end
      if importset["Variables"] then
        for k, v in pairs(importset["Variables"]) do
          if v then
            if type(payload["Variables"][k]) == "table" then
              payload["Variables"][k] = processWAGOImport(payload["Variables"][k])
            end
            filteredpayload["Variables"][k] = payload["Variables"][k]
            filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
          end
        end
      end
      if importset["Macros"] then
        for k, v in pairs(importset["Macros"]) do
          if v then
            if type(payload["Macros"][k]) == "table" then
              payload["Macros"][k] = processWAGOImport(payload["Macros"][k])
            end
            filteredpayload["Macros"][k] = payload["Macros"][k]
            filteredpayload["ElementCount"] = filteredpayload["ElementCount"] + 1
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
        importframe:Hide()
      else
        StaticPopup_Show("GSE-MacroImportFailure")
      end
    end
  )
  toolbarrow:AddChild(importbutton)
  importframe:AddChild(toolbarrow)
end

local function LandingPage()
  importframe:ReleaseChildren()
  local importsequencebox = AceGUI:Create("MultiLineEditBox")
  local recbutton = AceGUI:Create("Button")

  importsequencebox:SetLabel(L["Macro Collection to Import."])
  importsequencebox:SetNumLines(20)
  importsequencebox:DisableButton(true)
  importsequencebox:SetFullWidth(true)
  importframe:AddChild(importsequencebox)

  GSE.GUIImportFrame = importframe
  local recButtonGroup = AceGUI:Create("SimpleGroup")
  recButtonGroup:SetLayout("Flow")
  recbutton:SetText(L["Import"])
  recbutton:SetWidth(150)
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
          StaticPopup_Show("GSE-MacroImportFailure")
        end
      end
    end
  )
  recButtonGroup:AddChild(recbutton)
  importframe:AddChild(recButtonGroup)

  importframe:Show()
end

function GSE.ShowImport()
  LandingPage()
end
