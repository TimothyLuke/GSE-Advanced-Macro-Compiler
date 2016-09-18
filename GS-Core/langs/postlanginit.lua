
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

if GetLocale() ~= "enUS" then
  -- We need to load in temporarily the current locale translation tables.
  -- we should also look at cacheing this
  if GSisEmpty(GSAvailableLanguages[GSTRStaticKey][GetLocale()]) then
    GSAvailableLanguages[GSTRStaticKey][GetLocale()] = {}
    GSAvailableLanguages[GSTRStaticHash][GetLocale()] = {}
    GSAvailableLanguages[GSTRStaticShadow][GetLocale()] = {}
    GSPrintDebugMessage(L["Adding missing Language :"] .. GetLocale() )
    local i = 0
    for k,v in pairs(GSAvailableLanguages[GSTRStaticKey]["enUS"]) do
      GSPrintDebugMessage(i.. " " .. k .. " " ..v)
      local spellname = GetSpellInfo(k)
      if spellname then
        GSAvailableLanguages[GSTRStaticKey][GetLocale()][k] = spellname
        GSAvailableLanguages[GSTRStaticHash][GetLocale()][spellname] = k
        GSAvailableLanguages[GSTRStaticShadow][GetLocale()][spellname] = string.lower(k)
      end
      i = i + 1
    end
  end
end
