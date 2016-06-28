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

-- Seed a first instance just to be sure an instance is loaded.
GSMasterSequences["draik01"] = {
  specID = 1000,
author = "Draik",
helpTxt = "Sample GS Macro - this macro is never to be used",
'/run print("Executing macro 1!")',
}

-- Load any Load on Demand addon packs.
-- Only load those beginning with GS-
for i=1,GetNumAddOns() do
    if not IsAddOnLoaded(i) and GetAddOnInfo(i):find("^GS%-") then
        LoadAddOn(i);
    end
end

