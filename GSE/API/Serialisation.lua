local GSE = GSE
local Statics = GSE.Static
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

-- This encodes a LUA Table for transmission
function GSE.EncodeMessage(tab)

  local one = libS:Serialize(tab)
  GSE.PrintDebugMessage ("Compress Stage 1: " .. one, Statics.SourceTransmission)
  local two = libC:Compress(one)
  GSE.PrintDebugMessage ("Compress Stage 2: " .. two, Statics.SourceTransmission)
  local final = libCE:Encode(two)
  GSE.PrintDebugMessage ("Compress Stage Result: " .. final, Statics.SourceTransmission)
  return final
end

-- This decodes a string into a LUA Table.  This returns a bool (success) and an object that contains the results.
function GSE.DecodeMessage(data)
  -- Decode the compressed data
  local one = libCE:Decode(data)

  --Decompress the decoded data
  local two, message = libC:Decompress(one)
  if(not two) then
    GSE.PrintDebugMessage ("YourAddon: error decompressing: " .. message, Statics.SourceTransmission)
    return
  end

  -- Deserialize the decompressed data
  local success, final = libS:Deserialize(two)
  if (not success) then
    GSE.PrintDebugMessage ("YourAddon: error deserializing " .. final, Statics.SourceTransmission)
    return
  end

  GSE.PrintDebugMessage ("Data Finalised", Statics.SourceTransmission)
  return success, final
end

function GSE.TransmitSequence(key, channel, target)
  local t = {}
  t.Command = "GS-E_TRANSMITSEQUENCE"
  local elements = GSE.split(key, ",")
  local classid = tonumber(elements[1])
  local SequenceName = elements[2]
  GSE.PrintDebugMessage("Sending Seqence [" .. classid .. "][" .. SequenceName .. "]", Statics.SourceTransmission )
  t.ClassID = classid
  t.SequenceName = SequenceName
  t.Sequence = GSELibrary[classid][SequenceName]
  GSSendMessage(t, channel, target)
  GSE.GUITransmissionFrame:SetStatusText(SequenceName .. L[" sent"])
end
