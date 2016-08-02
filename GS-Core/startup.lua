local GNOME, ns = ...
GSMasterSequences = ns
GSStaticCastCmds = {}

GSStaticCastCmds = { use = true, cast = true, spell = true, cancelaura = true }

GSStaticCleanStrings = {}
GSStaticCleanStrings = {
  [1] = "/console Sound_EnableSFX 0\;\n",
  [2] = "/console Sound_EnableSFX 1\;\n",
  [3] = "/script UIErrorsFrame:Hide%(%)\;\n",
  [4] = "/run UIErrorsFrame:Clear%(%)\;\n",
  [5] = "/script UIErrorsFrame:Clear%(%)\;\n",
  [6] = "/run UIErrorsFrame:Hide%(%)\;\n",

  [11] = "/console Sound_EnableSFX 0\n",
  [12] = "/console Sound_EnableSFX 1\n",
  [13] = "/script UIErrorsFrame:Hide%(%)\n",
  [14] = "/run UIErrorsFrame:Clear%(%)\n",
  [15] = "/script UIErrorsFrame:Clear%(%)\n",
  [16] = "/run UIErrorsFrame:Hide%(%)\n",

  [20] = "/stopmacro [@playertarget, noexists]\n",

  [101] = "\n\n",
}

-- Sety defaults.  THese will be overriden once the addon is marked as loaded.
GSMasterOptions = {}
GSMasterOptions.AddInPacks = {}
GSMasterOptions.cleanTempMacro = true
GSMasterOptions.hideSoundErrors = false
GSMasterOptions.hideUIErrors = false
GSMasterOptions.clearUIErrors = false
GSMasterOptions.seedInitialMacro = false
GSMasterOptions.initialised = true
GSMasterOptions.AddInPacks = {}
GSMasterOptions.deleteOrphansOnLogout = false
GSMasterOptions.debug = false
GSMasterOptions.debugSequence = true
GSMasterOptions.sendDebugOutputToChat = true
GSMasterOptions.sendDebugOutputGSDebugOutput = false
GSMasterOptions.useTranslator = false
GSMasterOptions.requireTarget = false

GSDebugOutput = ""

GSStaticSequenceDebug = "SEQUENCEDEBUG"

-- Seed a first instance just to be sure an instance is loaded if we need to.
if GSMasterOptions.seedInitialMacro then
	GSMasterSequences["Draik01"] = {
	specID = 0,
	author = "Draik",
	helpTxt = "Sample GS Hellow World Macro.",
	'/run print("Hellow World!")',
	}
end

-------------------------------------------------------------------------------------
-- GSStaticPriority is a static step function that goes 1121231234123451234561234567
-- use this like StepFunction = GSStaticPriority, in a macro
-- This overides the sequential behaviour that is standard in GS
-------------------------------------------------------------------------------------
GSStaticPriority = [[
	limit = limit or 1
	if step == limit then
		limit = limit % #macros + 1
		step = 1
	else
		step = step % #macros + 1
	end
]]

local function isempty(s)
  return s == nil or s == ''
end


-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        local name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" and name ~= "GS-SequenceTranslator" then
          --print (name)
					LoadAddOn(i);
        end
				GSMasterOptions.AddInPacks[name] = true
    end

end
