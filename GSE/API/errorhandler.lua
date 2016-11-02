local GNOME, _ = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GS-E")

-- Default error handler seems to be _ERRORMESSAGE defined in BasicControls.xml
local Errors = {
	["^attempt to index global 'Sequences'"] = 'Missing mandatory first line in Sequences file: "local _, Sequences = ..."',
	--["[��]"] = 'Invalid quotes detected, replace all quote symbols in the file with normal double or single-quotes.',
}


seterrorhandler(function(message)
	local line, err = message:match('GS-%.lua:(%d+): (.+)')
	if err then
		for pattern, response in pairs(Errors) do
			if err:match(pattern) then
				err = response
				break
			end
		end
		C_Timer.After(2, function()
			print(format(GSMasterOptions.TitleColour.. L["[GNOME] syntax error on line %d of Sequences.lua:|r %s"], line, err, debuglocals(4)))
		end)
		wipe(Sequences)
		--Sequences[GNOME .. 'DEFAULT'] = ''
	end
end)
