local GNOME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

GSL = L

GSMasterSequences = ns


-- Sety defaults.  THese will be overriden once the addon is marked as loaded.



--- Experimental attempt to load a WeakAuras string.
function GSLoadWeakauras(str)
  local WeakAuras = WeakAuras

  if WeakAuras then
    WeakAuras.ImportString(str)
  end
end


-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        local name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" then
          --print (name)
					local loaded = LoadAddOn(i);
          if loaded then
            local authorversion = GetAddOnMetadata(name, "Version")
            GSImportLegacyMacroCollections(name, authorversion)
            GSE.AddInPacks[name] = true
          else
            GSE.UnloadedAddInPacks[name] = true
          end
        end

    end

end
