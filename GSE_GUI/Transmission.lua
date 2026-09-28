local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local L = GSE.L

function GSE.GUIShowTransmissionGui(inckey, editframe)
  local UI = GSE.UI

  local transauthor = GetUnitName("player", true) .. "@" .. GetRealmName()

  local transmissionFrame = UI:Create("Frame")
  transmissionFrame.frame:SetFrameStrata("MEDIUM")
  transmissionFrame.frame:SetClampedToScreen(true)

  --@debug@
  GSE.PrintDebugMessage("GSE Version " .. GSE.VersionString, Statics.SourceTransmission)
  --@end-debug@

  local transSequencevalue = ""

  transmissionFrame:SetTitle(L["Send To"])
  transmissionFrame:SetCallback(
    "OnClose",
    function(widget)
      transmissionFrame:Hide()
    end
  )
  transmissionFrame:SetLayout("List")
  transmissionFrame:SetWidth(290)
  transmissionFrame:SetHeight(190)
  transmissionFrame:Hide()

  local SequenceListbox = UI:Create("Dropdown")
  --SequenceListbox:SetLabel(L["Load Sequence"])
  SequenceListbox:SetWidth(250)
  SequenceListbox:SetCallback(
    "OnValueChanged",
    function(obj, event, key)
      transSequencevalue = key
    end
  )
  transmissionFrame.SequenceListbox = SequenceListbox
  transmissionFrame:AddChild(SequenceListbox)

  local playereditbox = UI:Create("EditBoxExampleAll")
  playereditbox:SetLabel(L["Send To"])
  playereditbox:SetWidth(250)
  playereditbox:DisableButton(true)
  transmissionFrame:AddChild(playereditbox)

  local sendbutton = UI:Create("Button")
  sendbutton:SetText(L["Send"])
  sendbutton:SetWidth(250)
  sendbutton:SetCallback(
    "OnClick",
    function()
      -- The key is "kind:ref" -- see the list built below.
      local kind, ref = string.match(transSequencevalue or "", "^(%a+):(.+)$")
      if kind then
        GSE.TransmitElement(kind, ref, "WHISPER", playereditbox:GetText(), transmissionFrame)
      end
    end
  )
  transmissionFrame:AddChild(sendbutton)

  if editframe then
    -- editframe:GetPoint() returns are unused; dropped

    transmissionFrame:ClearAllPoints()
    transmissionFrame:SetPoint("TOPLEFT", editframe.frame, editframe.Width + 10, 0)
  end

  -- Everything this player can send: sequences, variables and macros, keyed
  -- "kind:ref" (ref is the id, or the name of one not yet filed) and shown by
  -- label. Protected content is left out; TransmitElement would refuse it.
  -- inckey preselects a sequence: its id, its label, or a tree key.
  local offered = GSE.GetShareableSummary()
  local names, order = {}, {}
  local preselect
  local function offer(key, label)
    names[key] = label
    order[#order + 1] = key
  end
  local classIds = {}
  for c in pairs(offered.sequence) do classIds[#classIds + 1] = c end
  table.sort(classIds)
  for _, c in ipairs(classIds) do
    local rows = offered.sequence[c]
    for id, row in pairs(rows) do
      local key = "sequence:" .. id
      offer(key, row.Label)
      if inckey ~= nil and (inckey == id or inckey == row.Label
          or GSE.split(tostring(inckey), ",")[3] == id) then
        preselect = key
      end
    end
  end
  for id, row in pairs(offered.variable) do offer("variable:" .. id, L["Variable"] .. ": " .. row.Label) end
  for id, row in pairs(offered.macro) do offer("macro:" .. id, L["Macro"] .. ": " .. row.Label) end
  table.sort(order, function(a, b)
    local ka, kb = a:match("^%a+"), b:match("^%a+")
    if ka ~= kb then return ka == "sequence" or (ka == "variable" and kb == "macro") end
    return tostring(names[a]):lower() < tostring(names[b]):lower()
  end)
  transmissionFrame.SequenceListbox:SetList(names, order)
  if preselect then
    transmissionFrame.SequenceListbox:SetValue(preselect)
    transSequencevalue = preselect
  end
  transmissionFrame:Show()
  if transmissionFrame.frame and GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(transmissionFrame.frame) end
end
end
table.insert(ns.deferred, setup)
