--- Checks for nil or empty.
function GSisEmpty(s)
  return s == nil or s == ''
end

GSTRStaticKey = "KEY"
GSTRStaticHash = "HASH"
GSTRStaticShadow = "SHADOW"

GSAvailableLanguages = {}
GSAvailableLanguages[GSTRStaticKey] = {}
GSAvailableLanguages[GSTRStaticHash] = {}
GSAvailableLanguages[GSTRStaticShadow] = {}
