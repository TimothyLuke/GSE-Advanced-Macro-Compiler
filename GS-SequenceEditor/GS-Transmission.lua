local GSSE = GSSE

function GSSE:OnCommReceived(prefix, message, distribution, sender)
  GSPrintDebugMessage(prefix .. " " .. message .. " " .. distribution .. " " .. sender, "GS-Transmission")
end





GSSE:RegisterComm("GS-E", GSSE:OnCommReceived)
