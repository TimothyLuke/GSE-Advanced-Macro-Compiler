local _, GSE = ...
local L = GSE.L
local Statics = GSE.Static

-- This encodes a LUA Table for transmission
function GSE.EncodeMessage(tab)
        local result =
            "!GSE3!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tab)))
        return result
end

--- True when a stored blob carries the packed (!GSE3!+) envelope.
--
-- GSE decrypts this envelope so it can run the macro; it never produces one.
-- The key ships in Codec.lua and is symmetric, so anything that could seal
-- content here could be lifted wholesale, and a stream cipher under one fixed
-- key is unforgiving of a weak nonce. Sealing stays with gse.tools, which is
-- the only party that has somewhere safe to do it.
function GSE.IsPackedBlob(blob)
    return type(blob) == "string" and string.sub(blob, 1, 7) == "!GSE3!+"
end

--- True when a decoded body is protected content -- a copy gse.tools sent to
-- someone who does not own it. Accepts the bare object or the {name, object}
-- tuple sequences are stored as.
function GSE.IsProtectedContent(obj)
    if type(obj) ~= "table" then return false end
    local meta = obj.MetaData
    if type(meta) ~= "table" and type(obj[2]) == "table" then meta = obj[2].MetaData end
    return type(meta) == "table" and meta.noExport and true or false
end

--- The gate every at-rest write consults. True means "leave the stored blob
-- exactly as it is".
--
-- Two ways in. The blob on disk is already packed, so rewriting it plain would
-- strip the envelope -- the bug in #2054. Or the body says noExport, so it is
-- protected content that must not be written in the clear even if a shipped
-- build already downgraded it.
--
-- Callers do not lose anything by honouring this. Every at-rest write GSE makes
-- to protected content persists a DERIVED value -- the OriginKey stamp, the
-- macrotext rename migration, editor-markup sanitisation, a nil'd checksum, a
-- resolved icon -- and every one of them is recomputed from the body on the
-- next load. Real edits take the delta path instead; see GSE.ReplaceSequence.
function GSE.IsProtectedAtRest(blob, obj)
    return GSE.IsPackedBlob(blob) or GSE.IsProtectedContent(obj)
end

-- This decodes a string into a LUA Table.  This returns a bool (success) and an object that contains the results.
function GSE.DecodeMessage(data)
    if string.sub(data, 1, 7) == "!GSE3!+" then
        return pcall(GSE.DecodePackedMessage, data)
    elseif string.sub(data, 1, 6) == "!GSE3!" then
        return  pcall(function()
            local message = string.sub(data, 6, #data)
            local baseDecode = C_EncodingUtil.DecodeBase64(message)
            local decomString = C_EncodingUtil.DecompressString(baseDecode)
            return  C_EncodingUtil.DeserializeCBOR(decomString)
        end)
    else
        return false
    end
end

function GSE.sendMessage(tab, channel, target, priority)
    --@debug@
    GSE.PrintDebugMessage(tab.Command, Statics.SourceTransmission)
    --@end-debug@
    --@debug@
    if tab.Command == "GSE_TRANSMITELEMENT" then
        GSE.PrintDebugMessage(tostring(tab.Kind) .. " " .. tostring(tab.Label), Statics.SourceTransmission)
    end
    --@end-debug@
    local transmission = GSE.EncodeMessage(tab)
    --@debug@
    GSE.PrintDebugMessage("Transmission: \n" .. transmission, Statics.SourceTransmission)
    --@end-debug@
    if GSE.isEmpty(channel) then
        if IsInRaid() then
            channel =
                (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
                "RAID"
        else
            channel =
                (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or
                "PARTY"
        end
    end
    if target and not UnitIsSameServer(target) then
        if UnitInRaid(target) then
            channel = "RAID"
            transmission = ("§§%s:%s"):format(target, transmission)
        elseif UnitInParty(target) then
            channel = "PARTY"
            transmission = ("§§%s:%s"):format(target, transmission)
        end
    end
    GSE:SendCommMessage(Statics.CommPrefix, transmission, channel, target)
end

function GSE.performVersionCheck(version)
    if string.match(GSE.VersionString, "development") then
        GSE.old = false
    else
        if GSE.ParseVersion(version) ~= nil and GSE.ParseVersion(version) > GSE.VersionNumber then
            if not GSE.old then
                GSE.Print(
                    L[
                        "GSE is out of date. You can download the newest version from https://www.curseforge.com/wow/addons/gse-gnome-sequencer-enhanced-advanced-macros."
                    ],
                    Statics.SourceTransmission
                )
                GSE.old = true
                if (GSE.ParseVersion(version) - GSE.VersionNumber >= 5) then
                    GSE.GUICall("GUIShowUpdateAvailable")
                end
            end
        end
    end
end

-- ── Sharing with other GSE players ──────────────────────────────────────────
--
-- Only GSE speaks this protocol, so it is shaped for ids. Every element is
-- offered, requested and sent by its id -- a sequence's id here, a variable's
-- or macro's envelope id -- with its label beside it for people to read. The
-- label is what the receiver files it under: an id means nothing on another
-- player's machine, and a synced element's PlatformID travels inside the body
-- anyway, where the import matches it.
--
-- Protected content (sealed, or noExport) is never listed and never sent.

-- A sequence this player may share: the sequence, its class and its label.
local function shareableSequence(id, classid, label)
    if id == nil and label then id = GSE.FindSequenceId(label, tonumber(classid)) end
    local env, c = GSE.SequenceEnvelope(id)
    if not env then return nil end
    local seq = GSE.GetSequence(id, c)
    if type(seq) ~= "table" or GSE.IsProtectedAtRest(env.Body, seq) then return nil end
    return seq, c, env.Name
end

-- A variable this player may share, by id or name: the variable, its name, its id.
local function shareableVariable(ref)
    local name = GSE.StoredElementName("variable", ref) or ref
    local stored = GSE.Store("variable")[name]
    if type(stored) ~= "string" or GSE.IsPackedBlob(stored) then return nil end
    local ok, decoded = GSE.DecodeMessage(stored)
    if not ok or type(decoded) ~= "table" or GSE.IsProtectedContent(decoded) or decoded.noExport then return nil end
    return decoded, name, GSE.StoredElementId("variable", name)
end

-- A macro this player may share, by id or name: an account macro, or one of
-- this character's. Without its slot, which is this player's alone.
local function shareableMacro(ref)
    local name = GSE.StoredElementName("macro", ref) or ref
    local node = GSE.Store("macro")[name]
    if not GSE.IsStoredMacroNode(node) then
        local bucket = GSE.Store("macro")[GSE.CharacterMacroBucketKey()]
        node = type(bucket) == "table" and bucket[name] or nil
    end
    if not GSE.IsStoredMacroNode(node) or type(node.GSEProtected) == "string" or GSE.IsProtectedContent(node) then
        return nil
    end
    local copy = {}
    for k, v in pairs(node) do if k ~= "value" then copy[k] = v end end
    copy.name = copy.name or name
    return copy, name, GSE.StoredElementId("macro", name)
end

--- What this player offers: { sequence = { [classid] = { [id] = row } },
-- variable = { [id] = row }, macro = { [id] = row } }, row = { Label, Help,
-- LastUpdated }. Keyed by name where an element has no id yet.
function GSE.GetShareableSummary()
    local out = {sequence = {}, variable = {}, macro = {}}
    for classid = 0, 13 do
        for id in pairs(GSE.SequenceEnvelopes(classid)) do
            local seq, c, label = shareableSequence(id)
            if seq then
                out.sequence[c] = out.sequence[c] or {}
                out.sequence[c][id] = {Label = label, Help = seq.MetaData and seq.MetaData.Help,
                    LastUpdated = seq.LastUpdated or (seq.MetaData and seq.MetaData.LastUpdated)}
            end
        end
    end
    for name in pairs(GSE.Store("variable")) do
        local v, _, id = shareableVariable(name)
        if v then out.variable[id or name] = {Label = name, Help = v.comments, LastUpdated = v.LastUpdated} end
    end
    local macroNames = {}
    for k, v in pairs(GSE.Store("macro")) do
        if GSE.IsStoredMacroNode(v) then macroNames[k] = true end
    end
    local bucket = GSE.Store("macro")[GSE.CharacterMacroBucketKey()]
    if type(bucket) == "table" then
        for k in pairs(bucket) do macroNames[k] = true end
    end
    for name in pairs(macroNames) do
        local m, _, id = shareableMacro(name)
        if m then out.macro[id or name] = {Label = name, Help = m.comments, LastUpdated = m.LastUpdated} end
    end
    return out
end

--- Send one element to another player. kind is "sequence", "variable" or
-- "macro"; ref its id (or name). Refuses protected content.
function GSE.TransmitElement(kind, ref, channel, target, transmissionFrame)
    local element, classid, label, id
    if kind == "sequence" then
        element, classid, label = shareableSequence(ref)
        id = element and GSE.ResolveSequenceId(ref)
    elseif kind == "variable" then
        element, label, id = shareableVariable(ref)
    elseif kind == "macro" then
        element, label, id = shareableMacro(ref)
    end
    if not element then
        local shown = label or GSE.SequenceName(ref) or GSE.StoredElementName(kind, ref) or tostring(ref)
        GSE.Print(string.format(L["'%s' cannot be shared — it is protected content."], shown), "Error")
        if transmissionFrame then transmissionFrame:SetStatusText(L["Cannot share protected content"]) end
        return false
    end
    GSE.sendMessage({
        Command = "GSE_TRANSMITELEMENT",
        Kind = kind, ID = id or label, Label = label, ClassID = classid,
        Element = element,
    }, channel or "WHISPER", target)
    if transmissionFrame then transmissionFrame:SetStatusText(label .. L[" sent"]) end
    return true
end

--- Ask a player for one element: by id, or -- from a chat link, which only
-- ever had the text of the name -- by label.
function GSE.RequestElement(kind, id, label, classid, gseuser, channel)
    GSE.sendMessage({
        Command = "GSE_REQUESTELEMENT",
        Kind = kind, ID = id, Label = label, ClassID = classid,
    }, channel or "WHISPER", gseuser)
end

--- A chat link names a sequence; ask for it by that name.
function GSE.RequestSequence(ClassID, SequenceName, gseuser, channel)
    GSE.RequestElement("sequence", nil, SequenceName, ClassID, gseuser, channel)
end

-- Answer a request: find what was asked for and send it, or stay silent (the
-- requester's UI times out) when it is not ours to share.
local function answerRequest(t, sender)
    local kind = t.Kind or "sequence"
    local ref = t.ID
    if kind == "sequence" then
        if ref == nil or not GSE.SequenceEnvelope(ref) then
            ref = GSE.FindSequenceId(t.Label, tonumber(t.ClassID))
        end
    elseif ref == nil or not GSE.StoredElementName(kind, ref) then
        ref = t.Label
    end
    if ref == nil then return end
    GSE.TransmitElement(kind, ref, "WHISPER", sender)
end

--- File an element another player sent. It is filed under its label, like an
-- import; a sequence it matches by PlatformID is the same record.
function GSE.ReceiveElement(t, sender)
    local kind, label, element = t.Kind or "sequence", t.Label, t.Element
    if type(label) ~= "string" or label == "" or type(element) ~= "table" then return end
    if kind == "sequence" then
        GSE.AddSequenceToCollection(label, element, t.ClassID)
    elseif kind == "variable" then
        element.objectType = nil
        GSE.EnqueueOOC({action = "updatevariable", variable = element, name = label})
    elseif kind == "macro" then
        element.name = label
        GSE.EnqueueOOC({action = "importmacro", node = element})
    else
        return
    end
    GSE.Print(L["Received Sequence "] .. label .. L[" from "] .. sender)
end

function GSE.SendSpellCache(channel)
    local t = {}
    t.Command = "GSE_SPELLCACHE"
    t.cache = GSESpellCache
    GSE.sendMessage(t, channel)
end

function GSE.storeSender(sender, senderversion)
    if GSE.isEmpty(GSE.UnsavedOptions["PartyUsers"]) then
        GSE.UnsavedOptions["PartyUsers"] = {}
    end
    GSE.UnsavedOptions["PartyUsers"][sender] = senderversion
end

function GSE.sendVersionCheck()
    local t = {}
    t.Command = "GS-E_VERSIONCHK"
    t.Version = GSE.VersionString
    GSE.sendMessage(t)
end

function GSE.ListElements(recipient, channel)
    GSE.sendMessage({Command = "GSE_ELEMENTLIST", Elements = GSE.GetShareableSummary()},
        channel or "WHISPER", recipient)
end

function GSE.RequestElementList(gseuser, channel)
    GSE.sendMessage({Command = "GSE_LISTELEMENTS"}, channel or "WHISPER", gseuser)
end

function GSE:OnCommReceived(prefix, message, channel, sender)
    --@debug@
    GSE.PrintDebugMessage("GSE:onCommReceived", Statics.SourceTransmission)
    --@end-debug@
    --@debug@
    GSE.PrintDebugMessage(prefix .. " " .. message .. " " .. channel .. " " .. sender, Statics.SourceTransmission)
    --@end-debug@
    if channel == "PARTY" or channel == "RAID" then
        local dest, msg = string.match(message, "^§§([^:]+):(.+)$")
        if dest then
            local dName, dServer = string.match(dest, "^(.*)-(.*)$")
            local myName, myServer = UnitName("player")
            if myName == dName and myServer == dServer then
                message = msg
            end
        end
    end
    local success, t = GSE.DecodeMessage(message)
    if success and t then
        if t.Command == "GS-E_VERSIONCHK" then
            if not GSE.old then
                GSE.performVersionCheck(t.Version)
            end
            GSE.storeSender(sender, t.Version)
        elseif sender == GetUnitName("player", true) then
            -- Everything below is another player talking to us; ignore our own echo.
            --@debug@
            GSE.PrintDebugMessage("Ignoring " .. tostring(t.Command) .. " from me.", Statics.SourceTransmission)
            --@end-debug@
        elseif t.Command == "GSE_TRANSMITELEMENT" then
            GSE.ReceiveElement(t, sender)
        elseif t.Command == "GSE_LISTELEMENTS" then
            GSE.ListElements(sender, "WHISPER")
        elseif t.Command == "GSE_ELEMENTLIST" then
            GSE.ShowSequenceList(t.Elements, sender, channel)
        elseif t.Command == "GSE_REQUESTELEMENT" then
            answerRequest(t, sender)
        elseif t.Command == "GSE_SPELLCACHE" then
            do
                if GSE.isEmpty(GSESpellCache) then
                    GSESpellCache = {
                        ["enUS"] = {}
                    }
                end
                if not GSE.isEmpty(t.cache) and next(t.cache) ~= nil then
                    for locale, spells in pairs(t.cache) do
                        --@debug@
                        GSE.PrintDebugMessage("processing Locale" .. locale, Statics.SourceTransmission)
                        --@end-debug@
                        for k, v in pairs(spells) do
                            --@debug@
                            GSE.PrintDebugMessage("processing spell" .. k, Statics.SourceTransmission)
                            --@end-debug@
                            if GSE.isEmpty(GSESpellCache[locale]) then
                                GSESpellCache[locale] = {}
                            end
                            if GSE.isEmpty(GSESpellCache[locale][k]) then
                                --@debug@
                                GSE.PrintDebugMessage("Added spell" .. k .. " " .. v, Statics.SourceTransmission)
                                --@end-debug@
                                GSESpellCache[locale][k] = v
                            end
                        end
                    end
                end
            end
        end
    end
end

function GSE.SequenceChatPattern(sequenceName, classID)
    local playerName = UnitName("player")
    return "[GSE: " .. (playerName or "?") .. " - " .. (sequenceName or "?") .. " - " .. (classID or "0") .. "]"
end

function GSE.CreateSequenceLink(sequenceName, classID, playerName)
    if GSE.isEmpty(playerName) then
        playerName = UnitName("player")
    end
    local message = "GSE Sequence: " .. sequenceName .. "' (" .. GSE.GetClassName(classID) .. ")"
    local command = "seq@" .. sequenceName .. "@" .. playerName .. "@" .. classID
    local link = "|cFFFFFF00|Hgarrmission:GSE:" .. command .. "|h[" .. message .. "]|h|r"
    return link
end

-- This filter function courtesy of WeakAuras -- https://github.com/WeakAuras/WeakAuras2/blob/main/WeakAuras/Transmission.lua#L147

-- #1830 Not compatible with Midnight
local function filterFunc(_, event, msg, player, l, cs, t, flag, channelId, ...)
    if flag == "GM" or flag == "DEV" or (event == "CHAT_MSG_CHANNEL" and type(channelId) == "number" and channelId > 0) then
        return
    end

    local newMsg = ""
    local remaining = msg
    local done
    repeat
        local start, finish, characterName, sequenceName, classID =
            remaining:find("%[GSE: ([^%s]+) %- ([^%s]+) %- ([^]]+)")
        if (characterName and sequenceName and classID) then
            characterName = characterName:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
            sequenceName = sequenceName:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
            classID = classID:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
            newMsg = newMsg .. remaining:sub(1, start - 1)
            newMsg = newMsg .. GSE.CreateSequenceLink(sequenceName, classID, characterName)
            remaining = remaining:sub(finish + 1)
        else
            done = true
        end
    until (done)
    if newMsg ~= "" then
        local trimmedPlayer = Ambiguate(player, "none")
        if event == "CHAT_MSG_WHISPER" and not UnitInRaid(trimmedPlayer) and not UnitInParty(trimmedPlayer) then -- XXX: Need a guild check
            local _, num = BNGetNumFriends()
            for i = 1, num do
                if C_BattleNet then -- introduced in 8.2.5 PTR
                    local toon = C_BattleNet.GetFriendNumGameAccounts(i)
                    for j = 1, toon do
                        local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
                        if
                            gameAccountInfo and gameAccountInfo.characterName == trimmedPlayer and
                                gameAccountInfo.clientProgram == "WoW"
                         then
                            return false, newMsg, player, l, cs, t, flag, channelId, ... -- Player is a real id friend, allow it
                        end
                    end
                else -- keep old method for 8.2 and Classic
                    local toon = BNGetNumFriendGameAccounts(i)
                    for j = 1, toon do
                        local _, rName, rGame = BNGetFriendGameAccountInfo(i, j)
                        if rName == trimmedPlayer and rGame == "WoW" then
                            return false, newMsg, player, l, cs, t, flag, channelId, ... -- Player is a real id friend, allow it
                        end
                    end
                end
            end
            return true -- Filter strangers
        else
            return false, newMsg, player, l, cs, t, flag, channelId, ...
        end
    end
end
-- #1830 Not compatible with Midnight
if GSE.GameMode < 12 then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", filterFunc)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", filterFunc)
end
-- process chatlinks
hooksecurefunc(
    "SetItemRef",
    function(link)
        local linkType, addon, param1 = string.split(":", link)
        if linkType == "garrmission" and addon == "GSE" then
            local cmd, sequenceName, player, ClassID = string.split("@", param1)
            if cmd == "seq" then
                if player == UnitName("player") then
                    -- Our own link: open it. GUILoadEditor takes the tree's
                    -- "classid,spec,id" key; this used to hand it "classid,name".
                    local ownId = GSE.FindSequenceId(sequenceName, tonumber(ClassID))
                    if ownId then
                        local editor = GSE.CreateEditor()
                        editor.ManageTree()
                        GSE.GUILoadEditor(editor, ClassID .. ",0," .. ownId)
                    end
                else
                    GSE.Print("Requested " .. sequenceName .. " from " .. player, Statics.SourceTransmission)
                    GSE.RequestSequence(ClassID, sequenceName, player, "WHISPER")
                end
            end
        end
    end
)

GSE:RegisterComm("GSE")

if type(GSE.DebugProfile) == "function" then GSE.DebugProfile("Serialisation") end
