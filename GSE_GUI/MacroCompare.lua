local _, ns = ...
ns.deferred = ns.deferred or {}

local function setup()
local GSE = ns.GSE
local Statics = GSE.Static
local UI = GSE.UI
local L = GSE.L

local function DisableCompareColoring(widget)
  if widget and widget.editBox and IndentationLib and IndentationLib.disable then
    IndentationLib.disable(widget.editBox)
  end
end

-- Dump only the Versions of a sequence for the compare panes. Uses the same
-- translate/unescape pipeline as GSE.ExportSequence(verbose) but strips the
-- MetaData/KeyPress/etc wrapper so the comparison focuses on the actual
-- rotation. (A full upstream-style structured diff is a separate follow-up.)
local function ExportVersionsForCompare(sequence)
  if GSE.isEmpty(sequence) then return "" end
  local translated = GSE.UnEscapeTable(GSE.TranslateSequence(sequence, Statics.TranslatorMode.Current))
  return GSE.Dump(translated.Versions) .. "\n"
end

-- Queue of {id, classid, sequence} waiting for the open window to close.
local compareQueue = {}
local compareShowing = false
local showCompareWindow

--- Show the import comparison for one sequence, or queue it behind the one
--- already open.
--
-- A collection import calls this once per colliding member. Without a queue
-- they all appear at once, stacked and indistinguishable, and answering the
-- top one leaves three more underneath.
function GSE.GUIShowCompareWindow(id, classid, newsequence)
    if compareShowing then
        compareQueue[#compareQueue + 1] = {id, classid, newsequence}
        return
    end
    compareShowing = true
    showCompareWindow(id, classid, newsequence)
end

--- The open window is done with: show the next one, if any.
local function compareWindowClosed()
    compareShowing = false
    local nextUp = table.remove(compareQueue, 1)
    if nextUp then
        compareShowing = true
        showCompareWindow(nextUp[1], nextUp[2], nextUp[3])
    else
    end
end

-- id is the stored sequence the import collided with; the name shown -- and
-- offered for a rename -- is its label.
function showCompareWindow(id, classid, newsequence)
  local existing = GSE.GetSequence(id)
  local sequenceName = GSE.SequenceName(id)
    or (type(newsequence.MetaData) == "table" and newsequence.MetaData.Name) or tostring(id)
  local compareframe = UI:Create("Frame")
  -- A recycled Frame keeps the callbacks of whoever used it last, and the
  -- Hide() below fires OnHide -> OnClose. Building this window would otherwise
  -- run the PREVIOUS window's close handler, which advances the queue -- so
  -- opening one dequeued the next, which opened and dequeued the next, and the
  -- whole queue drained on a single Continue with one merge performed.
  compareframe:SetCallback("OnClose", nil)
  -- Advance the queue exactly once for this window, from whichever exit runs
  -- first. The flag lives in this closure, not on the frame: UI:Release
  -- recycles the widget table, so a field set there does not survive.
  local advanced = false
  -- Deferred by a frame, deliberately. This runs from inside OnHide, and the
  -- close handler releases the widget to the pool just before it. Building the
  -- next window synchronously hands UI:Create that very frame, and the rest of
  -- this window's teardown then keeps operating on it -- hiding it, firing the
  -- next OnClose, and draining the whole queue on one click with one merge
  -- performed. Letting the current teardown finish first breaks the chain.
  local function advanceQueue(from)
    if advanced then return end
    advanced = true
    C_Timer.After(0, compareWindowClosed)
  end
  compareframe:Hide()
  if GSE.isEmpty(GSEOptions.DefaultImportAction) then
    GSEOptions.DefaultImportAction = "MERGE"
  end
  compareframe.ChosenAction = GSEOptions.DefaultImportAction
  compareframe.classid = classid
  compareframe.id = id
  compareframe.sequenceName = sequenceName
  compareframe.frame:SetFrameStrata("MEDIUM")
  compareframe.frame:SetClampedToScreen(true)
  compareframe.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  compareframe.frame:SetSize(920, 600)

  compareframe:SetTitle(L["Sequence Compare"] .. " - " .. sequenceName)

  compareframe:SetCallback(
    "OnClose",
    function(self)
      DisableCompareColoring(compareframe.OrigText)
      DisableCompareColoring(compareframe.NewText)
      compareframe:Hide()
      -- Refresh the editor only if one is ALREADY open. ShowSequences opens it
      -- and records it as user-opened (SetSequenceEditorOpenPreference true),
      -- so calling it unconditionally meant answering an import dialog left the
      -- editor open and reopening on every reload afterwards, for a user who
      -- never opened it.
      if GSE.GUI and GSE.GUI.editors and #GSE.GUI.editors > 0 then
        GSE.ShowSequences()
      end
      UI:Release(self)
      advanceQueue("onclose")
    end
  )

  compareframe:SetLayout("List")

  local headerGroup = UI:Create("SimpleGroup")
  headerGroup:SetFullWidth(true)
  headerGroup:SetLayout("Flow")
  -- No side padding and a 10 gap: a relative width is of the row less 10, so
  -- two halves plus the gap are exactly the row -- equal boxes, edge to edge.
  if headerGroup.SetFlowPadding then headerGroup:SetFlowPadding(0, 0, 0, 0) end
  if headerGroup.SetFlowGap then headerGroup:SetFlowGap(10) end

  local leftColumn = UI:Create("MultiLineEditBox")
  compareframe.OrigText = leftColumn
  leftColumn:SetRelativeWidth(0.5)
  -- 23 lines: the stacked action block below, at its widgets' default
  -- heights, fits under them above the window's bottom edge (25 clipped
  -- Continue in game by ~16-20).
  leftColumn:SetNumLines(23)
  leftColumn:DisableButton(true)
  leftColumn:SetLabel(L["Local Sequence"])
  IndentationLib.enable(leftColumn.editBox, Statics.IndentationColorTable, 4)
  leftColumn:SetCallback("OnRelease", DisableCompareColoring)

  local rightColumn = UI:Create("MultiLineEditBox")
  compareframe.NewText = rightColumn
  rightColumn:SetRelativeWidth(0.5)
  rightColumn:SetNumLines(23)
  rightColumn:DisableButton(true)
  rightColumn:SetLabel(L["Updated Sequence"])
  IndentationLib.enable(rightColumn.editBox, Statics.IndentationColorTable, 4)
  rightColumn:SetCallback("OnRelease", DisableCompareColoring)

  headerGroup:AddChild(leftColumn)
  headerGroup:AddChild(rightColumn)

  compareframe:AddChild(headerGroup)

  -- Stacked and centred on the window: the action label beside its dropdown,
  -- then the new name (label above its box), then Continue.
  local actionButtonGroup = UI:Create("SimpleGroup")
  actionButtonGroup:SetFullWidth(true)
  actionButtonGroup:SetLayout("List")
  if actionButtonGroup.SetListPadding then actionButtonGroup:SetListPadding(0, 0, 0, 0) end
  if actionButtonGroup.SetListGap then actionButtonGroup:SetListGap(4) end
  local function centredLine()
    local line = UI:Create("SimpleGroup")
    if line.SetFlowVAlign then line:SetFlowVAlign("CENTER") end
    line:SetFullWidth(true)
    line:SetLayout("Flow")
    if line.SetFlowPadding then line:SetFlowPadding(0, 0, 0, 0) end
    if line.SetFlowGap then line:SetFlowGap(10) end
    if line.SetFlowHAlign then line:SetFlowHAlign("CENTER") end
    actionButtonGroup:AddChild(line)
    return line
  end
  local topGap = UI:Create("Spacer")
  topGap:SetHeight(8)
  actionButtonGroup:AddChild(topGap)
  local actionLine, nameLine, buttonLine = centredLine(), centredLine(), centredLine()

  local actionLabel = UI:Create("Label")
  actionLabel:SetText(L["Choose import action:"])
  if actionLabel.label then actionLabel:SetWidth(math.ceil(actionLabel.label:GetStringWidth()) + 4) end
  if actionLabel.SetJustifyV then actionLabel:SetJustifyV("MIDDLE") end

  actionLine:AddChild(actionLabel)

  local actionChoiceRadio = UI:Create("Dropdown")
  actionChoiceRadio:SetList(
    {
      ["MERGE"] = L["Merge"],
      ["REPLACE"] = L["Replace"],
      ["IGNORE"] = L["Ignore"],
      ["RENAME"] = L["Rename New Sequence"]
    }
  )
  -- Compact: no room kept above the box for a label it does not have.
  if actionChoiceRadio.SetDropdownStyle then actionChoiceRadio:SetDropdownStyle(true) end
  actionChoiceRadio:SetValue(GSEOptions.DefaultImportAction)

  actionLine:AddChild(actionChoiceRadio)

  local nameeditbox = UI:Create("EditBox")

  actionChoiceRadio:SetCallback(
    "OnValueChanged",
    function(obj, event, key)
      compareframe.ChosenAction = key
      if key == "RENAME" then
        nameeditbox:SetDisabled(false)
        nameeditbox:SetText(compareframe.sequenceName)
      else
        nameeditbox:SetDisabled(true)
      end
    end
  )

  nameeditbox:SetLabel(L["New Sequence Name"])
  nameeditbox:SetWidth(250)
  nameeditbox:SetCallback(
    "OnTextChanged",
    function(obj, event, key)
      compareframe.sequenceName = key
    end
  )

  nameeditbox:SetDisabled(true)
  nameeditbox:DisableButton(true)
  nameeditbox:SetText(compareframe.sequenceName)

  nameLine:AddChild(nameeditbox)

  local actionbutton = UI:Create("Button")
  actionbutton:SetText(L["Continue"])
  actionbutton:SetWidth(150)
  actionbutton:SetCallback(
    "OnClick",
    function()
      DisableCompareColoring(compareframe.OrigText)
      DisableCompareColoring(compareframe.NewText)
      compareframe:Hide()
      GSE.PerformMergeAction(
        compareframe.ChosenAction,
        compareframe.classid,
        compareframe.id,
        compareframe.NewSequence,
        compareframe.sequenceName
      )
      -- Explicit: OnClose does not reliably reach this window's handler on the
      -- Continue path, and the queue stalled with three windows still in it.
      -- advanceQueue is idempotent, so both exits calling it is fine.
      advanceQueue("continue")
    end
  )

  buttonLine:AddChild(actionbutton)
  compareframe:AddChild(actionButtonGroup)

  compareframe.NewSequence = newsequence

  if newsequence.MetaData.DisableEditor or not existing
    or (type(existing.MetaData) == "table" and existing.MetaData.DisableEditor) then
    GSE.PerformMergeAction("REPLACE", classid, id, newsequence)
  else
    -- Rename mints a new record (see OOCPerformMergeAction), so it is offered
    -- on the same terms as Duplicate: not for protected content. Renaming
    -- AFTER import is untouched and remains the route for someone else's
    -- sequence -- the id holds there and the edit uploads as a delta.
    local incomingProtected = GSE.IsProtectedContent and GSE.IsProtectedContent(newsequence)
    local localProtected = GSE.IsProtectedContent
      and GSE.IsProtectedContent(existing)
    if incomingProtected or localProtected then
      actionChoiceRadio:SetList(
        {
          ["MERGE"] = L["Merge"],
          ["REPLACE"] = L["Replace"],
          ["IGNORE"] = L["Ignore"]
        }
      )
    else
      actionChoiceRadio:SetList(
        {
          ["MERGE"] = L["Merge"],
          ["REPLACE"] = L["Replace"],
          ["IGNORE"] = L["Ignore"],
          ["RENAME"] = L["Rename New Sequence"]
        }
      )
    end
    compareframe.OrigText:SetText(ExportVersionsForCompare(existing))
    compareframe.NewText:SetText(ExportVersionsForCompare(newsequence))
    compareframe:Show()
    if compareframe.frame and GSE.RegisterUIScaleFrame then GSE.RegisterUIScaleFrame(compareframe.frame) end
    compareframe.sequenceName = sequenceName
  end
end
end
table.insert(ns.deferred, setup)
