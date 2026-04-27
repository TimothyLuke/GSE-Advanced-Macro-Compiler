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
    if importframe._fromQueue and GSE.IncomingQueue and not GSE.isEmpty(GSE.IncomingQueue) then
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
importframe:AddChild(AceGUI:Create("Label"))

-- Create the scrolling content area used by both import flows. Children added to
-- the returned ScrollFrame scroll inside the fixed-height container, leaving the
-- Import button (added to `importframe` directly) anchored at the bottom.
local function setupScrollContent()
  importframe:ReleaseChildren()
  importframe:SetLayout("List")
  local scrollContainer = AceGUI:Create("SimpleGroup")
  scrollContainer:SetFullWidth(true)
  scrollContainer:SetLayout("Fill")
  scrollContainer:SetHeight((importframe.frame:GetHeight() or 400) - 120)
  importframe:AddChild(scrollContainer)
  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  scroll:SetFullWidth(true)
  scrollContainer:AddChild(scroll)
  return scroll
end

local function processCollection(payload)
  local scroll = setupScrollContent()
  local header = AceGUI:Create("Heading")
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
    local sequencelabel = AceGUI:Create("Label")
    sequencelabel:SetText(L["Sequences"])
    sequencelabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(sequencelabel)
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
    local variablelabel = AceGUI:Create("Label")
    variablelabel:SetText(L["Variables"])
    variablelabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(variablelabel)
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
    local macroLabel = AceGUI:Create("Label")
    macroLabel:SetText(L["Macros"])
    macroLabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(macroLabel)
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
      scroll:AddChild(row)
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
        if importframe._fromQueue then
          if GSE.IncomingQueue and GSE.CompanionMarkImported then
            for _, item in ipairs(GSE.IncomingQueue) do
              GSE.CompanionMarkImported(item)
            end
          end
          GSE.IncomingQueue = {}
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
local function addDescLabel(container, text)
  if not text or text == "" then return end
  local lbl = AceGUI:Create("Label")
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
  local row = AceGUI:Create("SimpleGroup")
  row:SetLayout("Flow")
  row:SetFullWidth(true)
  local spacer = AceGUI:Create("Label")
  spacer:SetText("") spacer:SetWidth(30)
  row:AddChild(spacer)
  local nameLabel = AceGUI:Create("Label")
  nameLabel:SetText(label)
  nameLabel:SetWidth(380)
  row:AddChild(nameLabel)
  local dd = AceGUI:Create("Dropdown")
  if includeMerge then
    dd:SetList({ Import = "Import", Replace = "Replace", Merge = "Merge", Ignore = "Ignore" },
               { "Import", "Replace", "Merge", "Ignore" })
  else
    dd:SetList({ Import = "Import", Replace = "Replace", Ignore = "Ignore" },
               { "Import", "Replace", "Ignore" })
  end
  dd:SetValue("Import")
  dd:SetWidth(120)
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
    local header = AceGUI:Create("Heading")
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
      local lbl = AceGUI:Create("Label")
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
            local drow = AceGUI:Create("SimpleGroup")
            drow:SetLayout("Flow") drow:SetFullWidth(true)
            local dspacer = AceGUI:Create("Label")
            dspacer:SetText("") dspacer:SetWidth(50)
            drow:AddChild(dspacer)
            local dlbl = AceGUI:Create("Label")
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
      local lbl = AceGUI:Create("Label")
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
      local lbl = AceGUI:Create("Label")
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
  local toolbarrow = AceGUI:Create("SimpleGroup")
  toolbarrow:SetFullWidth(true)
  local spacerx = AceGUI:Create("Label")
  spacerx:SetWidth(500)
  spacerx:SetText()
  toolbarrow:AddChild(spacerx)
  local importbutton = AceGUI:Create("Button")
  importbutton:SetText(L["Import"])
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
        if type(v) == "table" then v = GSE.processWAGOImport(v) end
        -- processWAGOImport returns nil when it refuses (incompatible
        -- legacy format). It already printed the user-facing message;
        -- skip this entry so the rest of the batch still imports.
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
    if importframe._fromQueue then
      local pageSize = importframe._pageSize or 0
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
      importframe._fromQueue = false
      importframe._pageSize = nil
      importframe._pageTotal = nil
    end
    importframe:Hide()
    if anyFailed then
      StaticPopup_Show("GSE-MacroImportFailure")
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

  importframe._fromQueue = true
  importframe._pageSize = pageEnd
  importframe._pageTotal = total
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
  local header = AceGUI:Create("Heading")
  if total > QUEUE_PAGE_SIZE then
    header:SetText(string.format(
      "GSE Companion: pending deletes  1-%d of %d", pageEnd, total))
  else
    header:SetText(string.format(
      "GSE Companion: pending deletes  (%d)", total))
  end
  header:SetFullWidth(true)
  scroll:AddChild(header)

  local desc = AceGUI:Create("Label")
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
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow"); row:SetFullWidth(true)
    local sp = AceGUI:Create("Label"); sp:SetText(""); sp:SetWidth(30)
    row:AddChild(sp)
    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText(string.format("%s  |cFF888888(%s)|r",
      tostring(d.name or "?"), tostring(d.contentType or "sequence")))
    nameLabel:SetWidth(380)
    row:AddChild(nameLabel)
    local dd = AceGUI:Create("Dropdown")
    dd:SetList({ Delete = "Delete", Ignore = "Ignore" }, { "Delete", "Ignore" })
    dd:SetValue("Delete")
    dd:SetWidth(120)
    actionsByIndex[idx] = "Delete"
    dd:SetCallback("OnValueChanged", function(_, _, val)
      actionsByIndex[idx] = val
    end)
    row:AddChild(dd)
    scroll:AddChild(row)
  end

  local toolbarrow = AceGUI:Create("SimpleGroup")
  toolbarrow:SetFullWidth(true)
  local sp2 = AceGUI:Create("Label"); sp2:SetWidth(500); sp2:SetText("")
  toolbarrow:AddChild(sp2)
  local confirmbutton = AceGUI:Create("Button")
  confirmbutton:SetText("Confirm")
  confirmbutton:SetCallback("OnClick", function()
    for idx, d in ipairs(pageEntries) do
      local act = actionsByIndex[idx] or "Ignore"
      if GSE.CompanionConfirmDelete then
        GSE.CompanionConfirmDelete(d._id, d.contentType, d.name, d.classid, act)
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
  importframe._fromQueue = false

  -- If the platform queue has pending content, show a banner button at the top
  if GSE.IncomingQueue and not GSE.isEmpty(GSE.IncomingQueue) then
    local queueBanner = AceGUI:Create("SimpleGroup")
    queueBanner:SetLayout("Flow")
    queueBanner:SetFullWidth(true)
    local queueLabel = AceGUI:Create("Label")
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
  elseif GSE.PendingBridgeDeletes and not GSE.isEmpty(GSE.PendingBridgeDeletes) then
    -- Imports queue is empty but deletes are pending — let the user resolve
    -- them from the same dialog they'd use for imports.
    local delBanner = AceGUI:Create("SimpleGroup")
    delBanner:SetLayout("Flow")
    delBanner:SetFullWidth(true)
    local delLabel = AceGUI:Create("Label")
    delLabel:SetText("|cff00ccffGSE Platform:|r  " .. #GSE.PendingBridgeDeletes ..
                     " pending delete(s) awaiting your review.")
    delLabel:SetWidth(400)
    delBanner:AddChild(delLabel)
    local delButton = AceGUI:Create("Button")
    delButton:SetText("Review Deletes")
    delButton:SetWidth(200)
    delButton:SetCallback("OnClick", function() processQueue() end)
    delBanner:AddChild(delButton)
    importframe:AddChild(delBanner)
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
