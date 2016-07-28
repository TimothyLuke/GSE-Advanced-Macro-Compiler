This Standalone adding iterates through a list of spellID's and saves to the wow\wtf\somewhere\SavedVariables\GSE-LanguageExtractor.lua file two tables and a string.

langs = {} is a table of spellid = "localised spell name"
revlangs = {} is a table of "localised spell name" = Value
locale = the result of GetLocale()

This Lua file will be used to cache the translations of spells for the translator.
