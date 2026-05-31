local GSE = GSE
local _UI = GSE.UI

if GSE.isEmpty(GSE.GUI) then GSE.GUI = {} end

local MAX_UNDO_STEPS = 30
local UNDO_CHECK_INTERVAL = 0.35
local TYPING_COALESCE_SECONDS = 1.25

-- SetPropagateKeyboardInput is protected during combat lockdown — calling it in
-- combat triggers ADDON_ACTION_BLOCKED. Patrons can open the editor mid-combat,
-- so run such work immediately when safe, otherwise queue it until combat ends.
local combatWatcher
local pendingSafeFns = {}
local function RunWhenSafe(fn)
    if not fn then return end
    if not (InCombatLockdown and InCombatLockdown()) then
        fn()
        return
    end
    pendingSafeFns[#pendingSafeFns + 1] = fn
    if not combatWatcher then
        combatWatcher = CreateFrame("Frame")
        combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatWatcher:SetScript("OnEvent", function()
            if InCombatLockdown and InCombatLockdown() then return end
            local fns = pendingSafeFns
            pendingSafeFns = {}
            for _, f in ipairs(fns) do pcall(f) end
        end)
    end
end

local function SetPropagateSafe(frame, value)
    if not (frame and frame.SetPropagateKeyboardInput) then return end
    RunWhenSafe(function()
        if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(value) end
    end)
end

-- Shared so other GSE_GUI files (e.g. the editor's macro-block keyboard setup)
-- can defer protected keyboard calls past combat lockdown the same way.
GSE.GUI.RunWhenCombatSafe = RunWhenSafe
GSE.GUI.SetPropagateKeyboardSafe = SetPropagateSafe

local function IsSequenceLoaded(editor)
    return type(editor) == "table" and type(editor.Sequence) == "table" and type(editor.Sequence.Versions) == "table"
end

local function GetSelectedPath(editor)
    local tree = editor and editor.treeContainer
    local status = tree and (tree.status or tree.localstatus)
    return status and status.selected
end

local function StableValue(value, seen)
    local valueType = type(value)
    if valueType ~= "table" then return valueType .. ":" .. tostring(value) end

    seen = seen or {}
    if seen[value] then return "table:<cycle>" end
    seen[value] = true

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    local parts = {"table:{"}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = StableValue(key, seen)
        parts[#parts + 1] = "="
        parts[#parts + 1] = StableValue(value[key], seen)
        parts[#parts + 1] = ";"
    end
    parts[#parts + 1] = "}"

    seen[value] = nil
    return table.concat(parts)
end

local function Fingerprint(editor)
    if not IsSequenceLoaded(editor) then return nil end
    return StableValue(editor.Sequence)
end

local function GetUndoState(editor)
    if not editor then return nil end
    editor.GSEUndo = editor.GSEUndo or {
        undoStack = {},
        redoStack = {},
        elapsed = 0,
    }
    return editor.GSEUndo
end

local function MakeSnapshot(editor, reason)
    if not IsSequenceLoaded(editor) or not GSE.CloneSequence then return nil end

    return {
        sequence = GSE.CloneSequence(editor.Sequence),
        hash = Fingerprint(editor),
        sequenceName = editor.SequenceName,
        origSequenceName = editor.OrigSequenceName,
        classID = editor.ClassID,
        selectedPath = GetSelectedPath(editor),
        currentVersion = editor.currentMacroLimitVersion,
        scrollValue = editor.scrollStatus and editor.scrollStatus.scrollvalue,
        reason = reason or "Edit",
    }
end

local function SetBaseline(editor, reason)
    local state = GetUndoState(editor)
    if not state then return end

    state.baseline = MakeSnapshot(editor, reason)
    state.baselineHash = Fingerprint(editor)
end

local function PushUndoSnapshot(editor, snapshot)
    local state = GetUndoState(editor)
    if not (state and snapshot and snapshot.sequence) then return end

    local last = state.undoStack[#state.undoStack]
    if last and last.hash and snapshot.hash and last.hash == snapshot.hash then return end

    state.undoStack[#state.undoStack + 1] = snapshot
    while #state.undoStack > MAX_UNDO_STEPS do
        table.remove(state.undoStack, 1)
    end
    state.redoStack = {}
end

function GSE.GUI.CaptureUndoCheckpoint(editor, reason, coalesceKey)
    local state = GetUndoState(editor)
    if not (state and IsSequenceLoaded(editor)) or state.restoring then return end

    local now = GetTime and GetTime() or 0
    if coalesceKey and state.coalesceKey == coalesceKey and state.coalesceUntil and now < state.coalesceUntil then
        return
    end

    local snapshot = MakeSnapshot(editor, reason or "Edit")
    if not snapshot then return end

    PushUndoSnapshot(editor, snapshot)
    state.pendingCheckpointHash = snapshot.hash
    if coalesceKey then
        state.coalesceKey = coalesceKey
        state.coalesceUntil = now + TYPING_COALESCE_SECONDS
    end
end

local function MirrorEditorSequenceForTree(editor)
    if not IsSequenceLoaded(editor) then return end
    if not (GSE.Library and editor.ClassID and editor.SequenceName) then return end

    GSE.Library[editor.ClassID] = GSE.Library[editor.ClassID] or {}
    GSE.Library[editor.ClassID][editor.SequenceName] = GSE.CloneSequence(editor.Sequence)
end

local function RestoreSelection(editor, snapshot)
    if not (editor and snapshot) then return end

    local path = snapshot.selectedPath
    if path and GSE.GUI.SelectEditorTreePath then
        GSE.GUI.SelectEditorTreePath(editor, path)
    elseif path and editor.treeContainer then
        editor.treeContainer:SelectByValue(path)
    elseif editor.RefreshCurrentVersion then
        editor:RefreshCurrentVersion()
    end
end

function GSE.GUI.ResetUndo(editor)
    local state = GetUndoState(editor)
    if not state then return end

    state.undoStack = {}
    state.redoStack = {}
    state.elapsed = 0
    state.restoring = nil
    SetBaseline(editor, "Loaded")
end

function GSE.GUI.ClearUndo(editor)
    local state = editor and editor.GSEUndo
    if not state then return end

    state.undoStack = {}
    state.redoStack = {}
    state.baseline = nil
    state.baselineHash = nil
    state.elapsed = 0
    state.restoring = nil
end

function GSE.GUI.ClearAllUndo()
    local editors = GSE.GUI and GSE.GUI.editors
    if not editors then return end

    for _, editor in ipairs(editors) do
        if GSE.GUI.ClearUndo then GSE.GUI.ClearUndo(editor) end
    end
end

function GSE.GUI.ClearUndoIfNoVisibleEditors()
    local editors = GSE.GUI and GSE.GUI.editors
    if not editors then return end

    for _, editor in ipairs(editors) do
        if editor and editor.frame and editor.frame.IsShown and editor.frame:IsShown() then
            return
        end
    end

    GSE.GUI.ClearAllUndo()
end

function GSE.GUI.RestoreUndo(editor)
    local state = GetUndoState(editor)
    if not (state and state.undoStack and #state.undoStack > 0) then
        return false
    end

    local snapshot = table.remove(state.undoStack)
    state.redoStack[#state.redoStack + 1] = MakeSnapshot(editor, "Redo")
    state.restoring = true

    editor.Sequence = GSE.CloneSequence(snapshot.sequence)
    editor.SequenceName = snapshot.sequenceName
    editor.OrigSequenceName = snapshot.origSequenceName
    editor.ClassID = snapshot.classID
    editor.currentMacroLimitVersion = snapshot.currentVersion
    if editor.scrollStatus then editor.scrollStatus.scrollvalue = snapshot.scrollValue or 0 end

    MirrorEditorSequenceForTree(editor)
    if editor.ManageTree then editor.ManageTree() end
    RestoreSelection(editor, snapshot)

    SetBaseline(editor, "Undo")
    state.restoring = nil

    return true
end

local function OnUndoUpdate(frame, elapsed)
    local editor = frame and frame.GSEUndoEditor
    local state = GetUndoState(editor)
    if not (state and IsSequenceLoaded(editor)) or state.restoring then return end

    state.elapsed = (state.elapsed or 0) + (elapsed or 0)
    if state.elapsed < UNDO_CHECK_INTERVAL then return end
    state.elapsed = 0

    local currentHash = Fingerprint(editor)
    if not currentHash then return end

    if not state.baselineHash then
        SetBaseline(editor, "Loaded")
        return
    end

    if currentHash ~= state.baselineHash then
        if state.pendingCheckpointHash == state.baselineHash then
            state.pendingCheckpointHash = nil
        else
            PushUndoSnapshot(editor, state.baseline or MakeSnapshot(editor, "Edit"))
        end
        SetBaseline(editor, "Edit")
    end
end

local function IsUndoKey(key)
    return (key == "Z" or key == "z" or key == "CTRL-Z") and IsControlKeyDown and IsControlKeyDown() and
        not (IsAltKeyDown and IsAltKeyDown())
end

local function IsModifierOnlyKey(key)
    return key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or
        key == "LSHIFT" or key == "RSHIFT" or key == "LMETA" or key == "RMETA"
end

local function BindKeyboardFrame(editor, frame, keepPropagating)
    if not (editor and frame and frame.SetScript) then return end
    if frame.GSEUndoBound then return end

    frame.GSEUndoBound = true
    frame.GSEUndoEditor = editor

    local previousOnKeyDown = frame.GetScript and frame:GetScript("OnKeyDown")

    frame:SetScript("OnKeyDown", function(self, key)
        if IsUndoKey(key) then
            SetPropagateSafe(self, false)
            GSE.GUI.RestoreUndo(editor)
            return
        end
        if not IsModifierOnlyKey(key) and not keepPropagating and GSE.GUI.CaptureUndoCheckpoint then
            GSE.GUI.CaptureUndoCheckpoint(editor, "Typing", "typing")
        end
        if previousOnKeyDown then previousOnKeyDown(self, key) end
    end)

    if keepPropagating then
        -- Main editor frame: enable keyboard capture AND key propagation together,
        -- and defer both out of combat. SetPropagateKeyboardInput is protected in
        -- combat, and enabling capture without propagation would swallow the
        -- player's combat keybinds (patrons can open the editor mid-combat).
        RunWhenSafe(function()
            if frame.EnableKeyboard then frame:EnableKeyboard(true) end
            if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
        end)
    else
        -- Edit boxes consume their own typing; no propagation needed and
        -- EnableKeyboard is not protected, so apply immediately.
        if frame.EnableKeyboard then frame:EnableKeyboard(true) end
    end
end

function GSE.GUI.BindUndoWidget(editor, widget)
    if not (editor and widget) then return end

    BindKeyboardFrame(editor, widget.editBox or widget.editbox or widget.frame)
end

function GSE.GUI.SetupUndo(editor)
    if not (editor and editor.frame) then return end
    if editor.GSEUndoInstalled then return end

    editor.GSEUndoInstalled = true
    BindKeyboardFrame(editor, editor.frame, true)

    if editor.frame.HookScript then
        editor.frame.GSEUndoEditor = editor
        editor.frame:HookScript("OnUpdate", OnUndoUpdate)
        editor.frame:HookScript("OnShow", function()
            if not GetUndoState(editor).baselineHash then SetBaseline(editor, "Loaded") end
        end)
    end
end
