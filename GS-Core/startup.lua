local GNOME, ns = ...
GSMasterSequences = ns


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

-- Initialiase Options.  These are overrideen by the GS-E Options Plugin but in case that is not used
if not GnomeOptions.initialised then
	GnomeOptions.cleanTempMacro = true
	GnomeOptions.hideSoundErrors = false
	GnomeOptions.hideUIErrors = true
	GnomeOptions.clearUIErrors = false
	GnomeOptions.seedInitialMacro = false
	GnomeOptions.initialised = true
	GnomeOptions.AddInPacks
end

-- Expose Globally to be edited by GS-E Options addon
GSMasterOptions = GnomeOptions

-- Seed a first instance just to be sure an instance is loaded if we need to.
if GnomeOptions.seedInitialMacro then
  GSMasterSequences["Draik01"] = {
  specID = 0,
  author = "Draik",
  helpTxt = "Sample GS Hellow World Macro.",
  '/run print("Hellow World!")',
  }
end

-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        local name, _, _, _, _, _ = GetAddOnInfo(i)
        if name ~= "GS-SequenceEditor" then
				  GnomeOptions.AddInPacks[i] = true
					LoadAddOn(i);
        end
    end
end
