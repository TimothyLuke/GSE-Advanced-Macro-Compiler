local GNOME, ns = ...
GSMasterSequences = ns

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

