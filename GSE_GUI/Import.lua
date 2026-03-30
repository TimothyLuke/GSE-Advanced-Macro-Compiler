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
  for k, _ in pairs(payload["Macros"]) do
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
    for k, _ in pairs(payload["Macros"]) do
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
      if GSEMacros[k] or GSEMacros[char .. "-" .. realm][k] or GetMacroIndexByName(k) then
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
              payload["Sequences"][k] = GSE.processWAGOImport(payload["Sequences"][k])
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
              payload["Variables"][k] = GSE.processWAGOImport(payload["Variables"][k])
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
              payload["Macros"][k] = GSE.processWAGOImport(payload["Macros"][k])
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
        -- Clear the platform incoming queue now that the user has imported it
        if importframe._fromQueue then
          GSEIncomingQueue = {}
          importframe._fromQueue = false
        end
        importframe:Hide()
      else
        StaticPopup_Show("GSE-MacroImportFailure")
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
local function addDescLabel(text)
  if not text or text == "" then return end
  local lbl = AceGUI:Create("Label")
  lbl:SetText("|cff888888" .. text .. "|r")
  lbl:SetFullWidth(true)
  importframe:AddChild(lbl)
end

-- Render a list of decoded collections (each with its own heading) and a single
-- Import button that re-encodes and imports each collection separately.
-- collections: array of { name=string, payload={Sequences,Variables,Macros,ElementCount} }
local function processQueueCollections(collections)
  importframe:ReleaseChildren()
  importframe:SetLayout("List")

  -- Per-collection, per-key checkbox state: importset[i][category][key] = bool
  local importset = {}
  local char, realm = UnitFullName("player")

  for i, col in ipairs(collections) do
    importset[i] = { Sequences = {}, Variables = {}, Macros = {} }
    local payload = col.payload

    -- ── Collection heading ────────────────────────────────────────────────
    local header = AceGUI:Create("Heading")
    header:SetText(collectionHeading(col, i))
    header:SetFullWidth(true)
    importframe:AddChild(header)

    -- Collect HelpTxt from all sequences in this collection for the summary line.
    -- Shows beneath the heading so the user knows what the collection is for.
    local seqDescs = {}
    for _, seqData in pairs(payload.Sequences or {}) do
      if type(seqData) == "table" and type(seqData.MetaData) == "table" then
        local txt = truncate(seqData.MetaData.HelpTxt, 120)
        if txt then table.insert(seqDescs, txt) end
      end
    end
    addDescLabel(table.concat(seqDescs, "  ·  "))

    -- ── Sequences ─────────────────────────────────────────────────────────
    local sequencesfound = false
    for k, _ in pairs(payload.Sequences or {}) do
      sequencesfound = true
      importset[i].Sequences[k] = true
    end
    if sequencesfound then
      local lbl = AceGUI:Create("Label")
      lbl:SetText(L["Sequences"])
      lbl:SetFontObject(GameFontNormalLarge)
      importframe:AddChild(lbl)
      for k, seqData in pairs(payload.Sequences or {}) do
        local exists = (GSESequences[0] and GSESequences[0][k])
                    or (GSESequences[GSE.GetCurrentClassID()] and GSESequences[GSE.GetCurrentClassID()][k])
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("") spacer:SetWidth(30)
        row:AddChild(spacer)
        local chkbox = AceGUI:Create("CheckBox")
        chkbox:SetLabel(k .. " " .. statusTag(exists))
        chkbox:SetValue(true)
        chkbox:SetWidth(400)
        local ci, ck = i, k
        chkbox:SetCallback("OnValueChanged", function(_, _, val)
          importset[ci].Sequences[ck] = val
        end)
        row:AddChild(chkbox)
        importframe:AddChild(row)
        -- Per-element description (HelpTxt from MetaData, only if collection has >1 sequence
        -- or the collection-level desc would otherwise be absent)
        if type(seqData) == "table" and type(seqData.MetaData) == "table" then
          local eleDesc = truncate(seqData.MetaData.HelpTxt, 160)
          if eleDesc and (#seqDescs == 0 or #payload.Sequences > 1) then
            local drow = AceGUI:Create("SimpleGroup")
            drow:SetLayout("Flow") drow:SetFullWidth(true)
            local dspacer = AceGUI:Create("Label")
            dspacer:SetText("") dspacer:SetWidth(50)
            drow:AddChild(dspacer)
            local dlbl = AceGUI:Create("Label")
            dlbl:SetText("|cff888888" .. eleDesc .. "|r")
            dlbl:SetFullWidth(true)
            drow:AddChild(dlbl)
            importframe:AddChild(drow)
          end
        end
      end
    end

    -- ── Variables ─────────────────────────────────────────────────────────
    local variablesfound = false
    for k, _ in pairs(payload.Variables or {}) do
      variablesfound = true
      importset[i].Variables[k] = true
    end
    if variablesfound then
      local lbl = AceGUI:Create("Label")
      lbl:SetText(L["Variables"])
      lbl:SetFontObject(GameFontNormalLarge)
      importframe:AddChild(lbl)
      for k, _ in pairs(payload.Variables or {}) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("") spacer:SetWidth(30)
        row:AddChild(spacer)
        local chkbox = AceGUI:Create("CheckBox")
        chkbox:SetLabel(k .. " " .. statusTag(not GSE.isEmpty(GSEVariables[k])))
        chkbox:SetValue(true)
        chkbox:SetWidth(400)
        local ci, ck = i, k
        chkbox:SetCallback("OnValueChanged", function(_, _, val)
          importset[ci].Variables[ck] = val
        end)
        row:AddChild(chkbox)
        importframe:AddChild(row)
      end
    end

    -- ── Macros ────────────────────────────────────────────────────────────
    local macrosfound = false
    for k, _ in pairs(payload.Macros or {}) do
      macrosfound = true
      importset[i].Macros[k] = true
    end
    if macrosfound then
      local lbl = AceGUI:Create("Label")
      lbl:SetText(L["Macros"])
      lbl:SetFontObject(GameFontNormalLarge)
      importframe:AddChild(lbl)
      if GSE.isEmpty(GSEMacros[char .. "-" .. realm]) then
        GSEMacros[char .. "-" .. realm] = {}
      end
      for k, _ in pairs(payload.Macros or {}) do
        local exists = GSEMacros[k]
                    or GSEMacros[char .. "-" .. realm][k]
                    or GetMacroIndexByName(k)
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        local spacer = AceGUI:Create("Label")
        spacer:SetText("") spacer:SetWidth(30)
        row:AddChild(spacer)
        local chkbox = AceGUI:Create("CheckBox")
        chkbox:SetLabel(k .. " " .. statusTag(exists))
        chkbox:SetValue(true)
        chkbox:SetWidth(400)
        local ci, ck = i, k
        chkbox:SetCallback("OnValueChanged", function(_, _, val)
          importset[ci].Macros[ck] = val
        end)
        row:AddChild(chkbox)
        importframe:AddChild(row)
      end
    end
  end

  -- Single Import button at the bottom — imports each collection separately
  local toolbarrow = AceGUI:Create("SimpleGroup")
  toolbarrow:SetFullWidth(true)
  local spacerx = AceGUI:Create("Label")
  spacerx:SetWidth(500)
  spacerx:SetText()
  toolbarrow:AddChild(spacerx)
  local importbutton = AceGUI:Create("Button")
  importbutton:SetText(L["Import"])
  importbutton:SetCallback("OnClick", function()
    local allSuccess = true
    for i, col in ipairs(collections) do
      local filtered = {
        ["Sequences"] = {}, ["Variables"] = {}, ["Macros"] = {}, ["ElementCount"] = 0,
      }
      for k, v in pairs(importset[i].Sequences) do
        if v then
          local val = col.payload.Sequences[k]
          if type(val) == "table" then val = GSE.processWAGOImport(val) end
          filtered.Sequences[k] = val
          filtered.ElementCount = filtered.ElementCount + 1
        end
      end
      for k, v in pairs(importset[i].Variables) do
        if v then
          local val = col.payload.Variables[k]
          if type(val) == "table" then val = GSE.processWAGOImport(val) end
          filtered.Variables[k] = val
          filtered.ElementCount = filtered.ElementCount + 1
        end
      end
      for k, v in pairs(importset[i].Macros) do
        if v then
          local val = col.payload.Macros[k]
          if type(val) == "table" then val = GSE.processWAGOImport(val) end
          filtered.Macros[k] = val
          filtered.ElementCount = filtered.ElementCount + 1
        end
      end
      if filtered.ElementCount > 0 then
        local importstring = GSE.EncodeMessage({ ["type"] = "COLLECTION", ["payload"] = filtered })
        local success = GSE.ImportSerialisedSequence(importstring, importframe.AutoCreateIcon)
        if not success then allSuccess = false end
      end
    end
    if allSuccess then
      if importframe._fromQueue then
        GSEIncomingQueue = {}
        importframe._fromQueue = false
      end
      importframe:Hide()
    else
      StaticPopup_Show("GSE-MacroImportFailure")
    end
  end)
  toolbarrow:AddChild(importbutton)
  importframe:AddChild(toolbarrow)
end

-- Decode all items in GSEIncomingQueue, keeping each as its own collection,
-- and present them grouped. Called from login notification or the landing page.
local function processQueue()
  if GSE.isEmpty(GSEIncomingQueue) then return end

  local collections = {}
  for _, item in ipairs(GSEIncomingQueue) do
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
    GSE.Print(L["No valid content found in the GSE Platform queue."])
    return
  end

  importframe._fromQueue = true
  processQueueCollections(collections)
  importframe:Show()
end

local function LandingPage()
  importframe:ReleaseChildren()
  importframe._fromQueue = false

  -- If the platform queue has pending content, show a banner button at the top
  if not GSE.isEmpty(GSEIncomingQueue) then
    local queueBanner = AceGUI:Create("SimpleGroup")
    queueBanner:SetLayout("Flow")
    queueBanner:SetFullWidth(true)
    local queueLabel = AceGUI:Create("Label")
    queueLabel:SetText(
      "|cff00ccffGSE Platform:|r  " ..
      #GSEIncomingQueue ..
      " queued update(s) waiting to be imported."
    )
    queueLabel:SetWidth(400)
    queueBanner:AddChild(queueLabel)
    local queueButton = AceGUI:Create("Button")
    queueButton:SetText("Import Platform Updates")
    queueButton:SetWidth(200)
    queueButton:SetCallback("OnClick", function()
      processQueue()
    end)
    queueBanner:AddChild(queueButton)
    importframe:AddChild(queueBanner)
    local divider = AceGUI:Create("Heading")
    divider:SetText("  — or paste a string below —  ")
    divider:SetFullWidth(true)
    importframe:AddChild(divider)
  end

  local importsequencebox = AceGUI:Create("MultiLineEditBox")
  local recbutton = AceGUI:Create("Button")

  importsequencebox:SetLabel(L["GSE Collection to Import."])
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

-- Called by the login notification or the GSE menu to jump straight to the queue
function GSE.ShowIncomingQueue()
  processQueue()
end
