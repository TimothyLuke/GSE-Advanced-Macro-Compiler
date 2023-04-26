local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local bytetoB64 = {
    [0] = "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "(",
    ")"
}

local B64tobyte = {
    a = 0,
    b = 1,
    c = 2,
    d = 3,
    e = 4,
    f = 5,
    g = 6,
    h = 7,
    i = 8,
    j = 9,
    k = 10,
    l = 11,
    m = 12,
    n = 13,
    o = 14,
    p = 15,
    q = 16,
    r = 17,
    s = 18,
    t = 19,
    u = 20,
    v = 21,
    w = 22,
    x = 23,
    y = 24,
    z = 25,
    A = 26,
    B = 27,
    C = 28,
    D = 29,
    E = 30,
    F = 31,
    G = 32,
    H = 33,
    I = 34,
    J = 35,
    K = 36,
    L = 37,
    M = 38,
    N = 39,
    O = 40,
    P = 41,
    Q = 42,
    R = 43,
    S = 44,
    T = 45,
    U = 46,
    V = 47,
    W = 48,
    X = 49,
    Y = 50,
    Z = 51,
    ["0"] = 52,
    ["1"] = 53,
    ["2"] = 54,
    ["3"] = 55,
    ["4"] = 56,
    ["5"] = 57,
    ["6"] = 58,
    ["7"] = 59,
    ["8"] = 60,
    ["9"] = 61,
    ["("] = 62,
    [")"] = 63
}

-- This code is based on the Encode7Bit algorithm from LibCompress
-- Credit goes to Galmok of European Stormrage (Horde), galmok@gmail.com
-- This version was lifted straight from WeakAuras 2
local encodeB64Table = {}

function GSE.encodeB64(str)
    local B64 = encodeB64Table
    local remainder = 0
    local remainder_length = 0
    local encoded_size = 0
    local l = #str
    local code
    for i = 1, l do
        code = string.byte(str, i)
        remainder = remainder + bit.lshift(code, remainder_length)
        remainder_length = remainder_length + 8
        while (remainder_length) >= 6 do
            encoded_size = encoded_size + 1
            B64[encoded_size] = bytetoB64[bit.band(remainder, 63)]
            remainder = bit.rshift(remainder, 6)
            remainder_length = remainder_length - 6
        end
    end
    if remainder_length > 0 then
        encoded_size = encoded_size + 1
        B64[encoded_size] = bytetoB64[remainder]
    end
    return table.concat(B64, "", 1, encoded_size)
end

local decodeB64Table = {}

function GSE.decodeB64(str)
    local bit8 = decodeB64Table
    local decoded_size = 0
    local ch
    local i = 1
    local bitfield_len = 0
    local bitfield = 0
    local l = #str
    while true do
        if bitfield_len >= 8 then
            decoded_size = decoded_size + 1
            bit8[decoded_size] = string.char(bit.band(bitfield, 255))
            bitfield = bit.rshift(bitfield, 8)
            bitfield_len = bitfield_len - 8
        end
        ch = B64tobyte[str:sub(i, i)]
        bitfield = bitfield + bit.lshift(ch or 0, bitfield_len)
        bitfield_len = bitfield_len + 6
        if i > l then
            break
        end
        i = i + 1
    end
    return table.concat(bit8, "", 1, decoded_size)
end

-- This encodes a LUA Table for transmission
function GSE.EncodeMessage(tab)
    local one = libS:Serialize(tab)
    GSE.PrintDebugMessage("Compress Stage 1: " .. one, Statics.SourceTransmission)
    local two = libC:Compress(one)
    GSE.PrintDebugMessage("Compress Stage 2: " .. two, Statics.SourceTransmission)
    local final = GSE.encodeB64(two)
    GSE.PrintDebugMessage("Compress Stage Result: " .. final, Statics.SourceTransmission)
    return final
end

-- This decodes a string into a LUA Table.  This returns a bool (success) and an object that contains the results.
function GSE.DecodeMessage(data)
    -- Decode the compressed data
    local one = GSE.decodeB64(data)

    -- Decompress the decoded data
    local two, message = libC:Decompress(one)
    if (not two) then
        GSE.PrintDebugMessage("Error decompressing: " .. message, Statics.SourceTransmission)
        return
    end

    -- Deserialize the decompressed data
    local success, final = libS:Deserialize(two)
    if (not success) then
        GSE.PrintDebugMessage("Error deserializing " .. final, Statics.SourceTransmission)
        return
    end

    GSE.PrintDebugMessage("Data Finalised", Statics.SourceTransmission)
    return success, final
end

function GSE.TransmitSequence(key, channel, target)
    local t = {}
    t.Command = "GS-E_TRANSMITSEQUENCE"
    local elements = GSE.split(key, ",")
    local classid = tonumber(elements[1])
    local SequenceName = elements[2]
    GSE.PrintDebugMessage("Sending Seqence [" .. classid .. "][" .. SequenceName .. "]", Statics.SourceTransmission)
    t.ClassID = classid
    t.SequenceName = SequenceName
    t.Sequence = GSE.Library[classid][SequenceName]
    GSE.sendMessage(t, channel, target)
    GSE.GUITransmissionFrame:SetStatusText(SequenceName .. L[" sent"])
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
    if success then
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
                GSE.PrintDebugMessage(
                    GSE.ExportSequence(t.Sequence, t.SequenceName, false, "ID", false),
                    Statics.SourceTransmission
                )
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
                if not GSE.isEmpty(GSE3Storage[tonumber(t.ClassID)][t.SequenceName]) then
                    GSE.SendSequence(tonumber(t.ClassID), t.SequenceName, sender, "WHISPER")
                end
            else
                GSE.PrintDebugMessage("Ignoring RequestSequence from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_REQUESTSEQUENCEMETA" then
            if sender ~= GetUnitName("player", true) then
                if not GSE.isEmpty(GSE3Storage[t.ClassID][t.SequenceName]) then
                    GSE.SendSequenceMeta(t.ClassID, t.SequenceName, sender, "WHISPER")
                end
            else
                GSE.PrintDebugMessage("Ignoring SequenceMeta from me.", Statics.SourceTransmission)
            end
        elseif t.Command == "GSE_SEQUENCEMETA" then
            if sender ~= GetUnitName("player", true) then
                if not GSE.isEmpty(GSE3Storage[t.ClassID][t.SequenceName]) then
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
                if not GSE.isEmpty(t.cache) and table.getn(t.cache) > 0 then
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
                        if gameAccountInfo.characterName == trimmedPlayer and gameAccountInfo.clientProgram == "WoW" then
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

-- process chatlinks
hooksecurefunc(
    "SetItemRef",
    function(link)
        local linkType, addon, param1 = strsplit(":", link)
        if linkType == "garrmission" and addon == "GSE" then
            if param1 == "foo" then
                print("Processed test link foo")
            else
                local cmd, sequenceName, player, ClassID = strsplit("@", param1)
                if cmd == "seq" then
                    if player == UnitName("player") then
                        GSE.GUILoadEditor(ClassID .. "," .. sequenceName, GSE.GUIViewFrame)
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
