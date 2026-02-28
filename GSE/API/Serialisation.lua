local GSE = GSE
local L = GSE.L
local Statics = GSE.Static

-- This encodes a LUA Table for transmission
function GSE.EncodeMessage(tab)
        local result =
            "!GSE3!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tab)))
        return result
end

-- This decodes a string into a LUA Table.  This returns a bool (success) and an object that contains the results.
function GSE.DecodeMessage(data)
    if string.sub(data, 1, 6) == "!GSE3!" then
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

function GSE.TransmitSequence(key, channel, target, transmissionFrame)
    local t = {}
    t.Command = "GS-E_TRANSMITSEQUENCE"
    local elements = GSE.split(key, ",")
    local classid = tonumber(elements[1])
    local SequenceName = elements[3]
    GSE.PrintDebugMessage("Sending Seqence [" .. classid .. "][" .. SequenceName .. "]", Statics.SourceTransmission)
    t.ClassID = classid
    t.SequenceName = SequenceName
    t.Sequence = GSE.Library[classid][SequenceName]
    GSE.sendMessage(t, channel, target)
    if transmissionFrame then
        transmissionFrame:SetStatusText(SequenceName .. L[" sent"])
    end
end

function GSE.sendMessage(tab, channel, target, priority)
    local _, instanceType = IsInInstance()
    GSE.PrintDebugMessage(tab.Command, Statics.SourceTransmission)
    if tab.Command == "GS-E_TRANSMITSEQUENCE" then
        GSE.PrintDebugMessage(tab.SequenceName, Statics.SourceTransmission)
        GSE.PrintDebugMessage(GSE.isEmpty(tab.Sequence))
        GSE.PrintDebugMessage(GSE.ExportSequence(tab.Sequence, tab.SequenceName), Statics.SourceTransmission)
    end
    local transmission = GSE.EncodeMessage(tab)
    GSE.PrintDebugMessage("Transmission: \n" .. transmission, Statics.SourceTransmission)
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
        local developer = true
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
                    StaticPopup_Show("GSE_UPDATE_AVAILABLE")
                end
            end
        end
    end
end

function GSE.SendSequence(ClassID, SequenceName, recipient, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end
    local key = ClassID .. "," .. SequenceName
    GSE.TransmitSequence(key, channel, recipient)
end

function GSE.SendSequenceMeta(ClassID, SequenceName, gseuser, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end
    local t = {}
    t.Command = "GSE_SEQUENCEMETA"
    t.ClassID = ClassID
    t.SequenceName = SequenceName
    t.LastUpdated = GSE.Library[ClassID][SequenceName].MetaData.LastUpdated
    t.Help = GSE.Library[ClassID][SequenceName].MetaData.Help
    GSE.sendMessage(t, channel, gseuser)
end

function GSE.SendSpellCache(channel)
    local t = {}
    t.Command = "GSE_SPELLCACHE"
    t.cache = GSESpellCache
    GSE.sendMessage(t, channel)
end

function GSE.RequestSequence(ClassID, SequenceName, gseuser, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end
    local t = {}
    t.Command = "GSE_REQUESTSEQUENCE"
    t.ClassID = ClassID
    t.SequenceName = SequenceName
    GSE.sendMessage(t, channel, gseuser)
end

function GSE.RequestSequenceMeta(ClassID, SequenceName, gseuser, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end
    local t = {}
    t.Command = "GSE_REQUESTSEQUENCEMETA"
    t.ClassID = ClassID
    t.SequenceName = SequenceName
    GSE.sendMessage(t, channel, gseuser)
end

function GSE.ReceiveSequence(classid, SequenceName, Sequence, sender)
    GSE.AddSequenceToCollection(SequenceName, Sequence, classid)
    GSE.Print(L["Received Sequence "] .. SequenceName .. L[" from "] .. sender)
end

function GSE.storeSender(sender, senderversion)
    if GSE.isEmpty(GSE.UnsavedOptions["PartyUsers"]) then
        GSE.UnsavedOptions["PartyUsers"] = {}
    end
    GSE.UnsavedOptions["PartyUsers"][sender] = senderversion
end

function GSE.sendVersionCheck()
    local _, instanceType = IsInInstance()
    local t = {}
    t.Command = "GS-E_VERSIONCHK"
    t.Version = GSE.VersionString
    GSE.sendMessage(t)
end

function GSE.ListSequences(recipient, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end

    local sequenceTable = GSE.GetSequenceSummary()
    local t = {}
    t.Command = "GSE_SEQUENCELIST"
    t.SequenceTable = sequenceTable
    GSE.sendMessage(t, channel, recipient)
end

function GSE.RequestSequenceList(gseuser, channel)
    if GSE.isEmpty(channel) then
        channel = "WHISPER"
    end
    local t = {}
    t.Command = "GSE_LISTSEQUENCES"
    GSE.sendMessage(t, channel, gseuser)
end

function GSE:OnCommReceived(prefix, message, channel, sender)
    GSE.PrintDebugMessage("GSE:onCommReceived", Statics.SourceTransmission)
    GSE.PrintDebugMessage(prefix .. " " .. message .. " " .. channel .. " " .. sender, Statics.SourceTransmission)
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
        elseif t.Command == "GS-E_TRANSMITSEQUENCE" then
            if sender ~= GetUnitName("player", true) then
                GSE.ReceiveSequence(t.ClassID, t.SequenceName, t.Sequence, sender)
            else
                GSE.PrintDebugMessage("Ignoring Sequence from me.", Statics.SourceTransmission)
                GSE.PrintDebugMessage(GSE.ExportSequence(t.Sequence, t.SequenceName, false), Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_LISTSEQUENCES" then
            if sender ~= GetUnitName("player", true) then
                GSE.ListSequences(sender, "WHISPER")
            else
                GSE.PrintDebugMessage("Ignoring List Request from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_SEQUENCELIST" then
            if sender ~= GetUnitName("player", true) then
                GSE.ShowSequenceList(t.SequenceTable, sender, channel)
            else
                GSE.PrintDebugMessage("Ignoring SequenceList from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_REQUESTSEQUENCE" then
            if sender ~= GetUnitName("player", true) then
                if not GSE.isEmpty(GSESequences[tonumber(t.ClassID)][t.SequenceName]) then
                    GSE.SendSequence(tonumber(t.ClassID), t.SequenceName, sender, "WHISPER")
                end
            else
                GSE.PrintDebugMessage("Ignoring RequestSequence from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_REQUESTSEQUENCEMETA" then
            if sender ~= GetUnitName("player", true) then
                if not GSE.isEmpty(GSESequences[t.ClassID][t.SequenceName]) then
                    GSE.SendSequenceMeta(t.ClassID, t.SequenceName, sender, "WHISPER")
                end
            else
                GSE.PrintDebugMessage("Ignoring SequenceMeta from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_SEQUENCEMETA" then
            if sender ~= GetUnitName("player", true) then
                if not GSE.isEmpty(GSESequences[t.ClassID][t.SequenceName]) then
                    local sequence = GSE.Library[t.ClassID][t.SequenceName]
                    if sequence.MetaData.LastUpdated ~= t.LastUpdated then
                        GSE.RequestSequence(t.ClassID, t.SequenceName, sender, "WHISPER")
                    end
                end
            else
                GSE.PrintDebugMessage("Ignoring SequenceMeta data from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_SPELLCACHE" then
            if sender ~= GetUnitName("player", true) then
                if GSE.isEmpty(GSESpellCache) then
                    GSESpellCache = {
                        ["enUS"] = {}
                    }
                end
                if not GSE.isEmpty(t.cache) and #t.cache > 0 then
                    for locale, spells in pairs(t.cache) do
                        GSE.PrintDebugMessage("processing Locale" .. locale, Statics.SourceTransmission)
                        for k, v in pairs(spells) do
                            GSE.PrintDebugMessage("processing spell" .. k, Statics.SourceTransmission)
                            if GSE.isEmpty(GSESpellCache[locale]) then
                                GSESpellCache[locale] = {}
                            end
                            if GSE.isEmpty(GSESpellCache[locale][k]) then
                                GSE.PrintDebugMessage("Added spell" .. k .. " " .. v, Statics.SourceTransmission)
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
    return "[GSE: " .. playerName .. " - " .. sequenceName .. " - " .. classID .. "]"
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
            if param1 == "foo" then
                print("Processed test link foo")
            else
                local cmd, sequenceName, player, ClassID = string.split("@", param1)
                if cmd == "seq" then
                    if player == UnitName("player") then
                        local editor = GSE.CreateEditor()
                        editor.ManageTree()
                        GSE.GUILoadEditor(editor, ClassID .. "," .. sequenceName)
                    else
                        GSE.Print("Requested " .. sequenceName .. " from " .. player, Statics.SourceTransmission)
                        GSE.RequestSequence(ClassID, sequenceName, player, "WHISPER")
                    end
                end
            end
        end
    end
)

GSE:RegisterComm("GSE")
GSE.DebugProfile("Serialisation")
