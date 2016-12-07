local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local GSELegacyAdaptor = LibStub("AceAddon-3.0"):NewAddon("GSELegacyAdaptor", "AceEvent-3.0")

local GSMasterOptions = {}
local GSMasterOptions.SequenceLibrary = {}

local GSStaticSourceLocal = Statics.SourceLocal

--- Return the next version value for a sequence.
--    a <code>last</code> value of true means to get the last remaining version
local function GSGetNextSequenceVersion(SequenceName, last)
  local nextv = table.getn(GSMasterOptions.SequenceLibrary[SequenceName]) + 1
  return nextv

end


--- Load sequences found in addon Mods.  authorversion is the version of hte mod where the collection was loaded from.
local function GSImportLegacyMacroCollections(str, authorversion)
  for k,v in pairs(GSMasterSequences) do
    if GSisEmpty(v.version) then
      v.version = 1
    end
    if GSisEmpty(authorversion) then
      authorversion = 1
    end
    v.source = str
    v.authorversion = authorversion
    GSAddSequenceToCollection(k, v, v.version)
    GSMasterSequences[k] = nil
  end
end

--- Add a sequence to the library
local function GSAddSequenceToCollection(sequenceName, sequence, version)
  --Perform some validation checks on the Sequence.
  if GSisEmpty(sequence.specID) then
    -- set to currentSpecID
    sequence.specID = tonumber(GSE.GetCurrentSpecID())
  end
  if GSisEmpty(sequence.author) then
    -- set to unknown author
    sequence.author = "Unknown Author"
  end
  -- CHeck for colissions
  local found = false
  if not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
    if not GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      found = true
    end
  end
  if found then
    -- check if source the same.  If so ignore
    if sequence.source ~= GSMasterOptions.SequenceLibrary[sequenceName][version].source then
      -- different source.  if local Ignore
      if sequence.source == GSStaticSourceLocal then
        -- local version - add as new version
        GSAddSequenceToCollection(sequenceName, sequence, GSGetNextSequenceVersion(sequenceName))
      end
    end
  else
    -- New Sequence
    if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
      -- Sequence is new
      GSMasterOptions.SequenceLibrary[sequenceName] = {}
    end
    if GSisEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      GSMasterOptions.SequenceLibrary[sequenceName][version] = {}
    end

    GSMasterOptions.SequenceLibrary[sequenceName][version] = sequence
  end
end


local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(self, event, addon)
  if event == 'ADDON_LOADED' then

    local name = "GS-Core"
    local authorversion = "Legacy 2.0 Adaptor"

    GSMasterSequences = GnomeOptions.SequenceLibrary
    GSImportLegacyMacroCollections(name, authorversion)


    -- Load any Load on Demand addon packs.
    -- Only load those beginning with GS-
    for i=1,GetNumAddOns() do
      if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" then
          --print (name)
					local loaded = LoadAddOn(i);
          if loaded then
            authorversion = GetAddOnMetadata(name, "Version")
            GSImportLegacyMacroCollections(name, authorversion)
          end
        end
      end
    end

    local sequenceNames = {}
    for k,_ in pairs(GSMasterOptions.SequenceLibrary) do
      table.insert(sequenceNames, k)
    end

    local loadseqs = GSE.RegisterAddon(name, authorversion, sequencenames)

    if loadseqs then
      processReload("GS-Core")
    end
    -- Check loaded in GSE

  end
end

local function processReload(arg)
  if arg == "GS-Core" then
    for k,v in pairs(GSMasterOptions.SequenceLibrary) do
      for i,j in ipairs(v) do
        local seq = GSE.ConvertLegacySequence(v)
        GSE.AddSequenceToCollection(k, seq)
      end
    end
  end

end

GSELegacyAdaptor:RegisterMessage(Statics.ReloadMessage, processReload, arg)

f:RegisterEvent('ADDON_LOADED')
