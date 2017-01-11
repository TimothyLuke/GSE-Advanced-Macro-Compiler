local GSE = GSE
local L = GSE.L
local Statics = GSE.Static
local GSELegacyAdaptor = LibStub("AceAddon-3.0"):NewAddon("GSELegacyAdaptor", "AceEvent-3.0")

GSMasterOptions = {}
GSMasterOptions.SequenceLibrary = {}
GSMasterOptions.AlreadyLoaded = {}

GSMasterSequences = {}

local GSStaticSourceLocal = Statics.SourceLocal

--- Return the next version value for a sequence.
--    a <code>last</code> value of true means to get the last remaining version
local function GSGetNextSequenceVersion(SequenceName, last)
  local nextv = table.getn(GSMasterOptions.SequenceLibrary[SequenceName]) + 1
  return nextv

end

--- Add a sequence to the library
local function GSAddSequenceToCollection(sequenceName, sequence, version)
  --Perform some validation checks on the Sequence.
  if GSE.isEmpty(sequence.specID) then
    -- set to currentSpecID
    sequence.specID = tonumber(GSE.GetCurrentSpecID())
  end
  if GSE.isEmpty(sequence.author) then
    -- set to unknown author
    sequence.author = "Unknown Author"
  end
  -- CHeck for colissions
  local found = false
  if not GSE.isEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
    if not GSE.isEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
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
    if GSE.isEmpty(GSMasterOptions.SequenceLibrary[sequenceName]) then
      -- Sequence is new
      GSMasterOptions.SequenceLibrary[sequenceName] = {}
    end
    if GSE.isEmpty(GSMasterOptions.SequenceLibrary[sequenceName][version]) then
      GSMasterOptions.SequenceLibrary[sequenceName][version] = {}
    end

    GSMasterOptions.SequenceLibrary[sequenceName][version] = sequence
  end
end


--- Load sequences found in addon Mods.  authorversion is the version of hte mod where the collection was loaded from.
local function GSImportLegacyMacroCollections(str, authorversion)
  if GSE.isEmpty(authorversion) then
    authorversion = 1
  end
  for k,v in pairs(GSMasterSequences) do
    if not GSMasterOptions.AlreadyLoaded[k] then
      if GSE.isEmpty(v.version) then
        v.version = 1
      end
      v.source = str
      v.authorversion = authorversion
      GSAddSequenceToCollection(k, v, v.version)
      GSMasterOptions.AlreadyLoaded[k] = true
    end
  end
end


local f = CreateFrame('Frame')
f:SetScript('OnEvent', function(self, event, addon)
  if event == 'ADDON_LOADED' and addon == "GS-Core" then
    if not GSE.isEmpty(GnomeOptions) then
      local name = "GS-Core"
      local authorversion = "Legacy 2.0 Adaptor"







      -- Load any Load on Demand addon packs.
      -- Only load those beginning with GS-
      for i=1,GetNumAddOns() do
        if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
          name, _, _, _, _, _ = GetAddOnInfo(i)
          if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" and name ~= "GS-HighPerformanceMacros" then
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

      local loadseqs = GSE.RegisterAddon("Legacy GSE 1", authorversion, sequenceNames)

      if loadseqs then
        GSELegacyAdaptor:processReload("Load", "GS-Core")
        GnomeOptions.imported = true
      end
      -- Check loaded in GSE
    end
  end
end)

function GSELegacyAdaptor:processReload(event, arg)
  if event == "Load" or arg == "Legacy GSE 1"  then
    if not GnomeOptions.imported then
      for k,v in pairs(GSMasterOptions.SequenceLibrary) do
        for i,j in ipairs(v) do
          local seq = GSE.ConvertLegacySequence(j)
          GSE.AddSequenceToCollection(k, seq)
        end
      end
    end
    for k,v in pairs(GnomeOptions.SequenceLibrary) do
      for i,j in ipairs(v) do
        local seq = GSE.ConvertLegacySequence(j)
        GSE.AddSequenceToCollection(k, seq)
      end
    end

    if event == "Load" then
      GnomeOptions.imported = true
    end
  end
end

GSELegacyAdaptor:RegisterMessage(Statics.ReloadMessage, "processReload")
--GSELegacyAdaptor:RegisterMessage(Statics.CoreLoadedMessage,  "processReload")
f:RegisterEvent('ADDON_LOADED')
