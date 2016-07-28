local GNOME, language = ...
GSTranslatorAvailable = true

GSTRStaticKey = "KEY"
GSTRStaticHash = "HASH"

if GSCore then
  GSPrintDebugMessage("Translator Initialised and Global GSTranslatorAvailable marked as True", GNOME)
end

language[GSTRStaticKey] = {}
language[GSTRStaticHash] = {}
