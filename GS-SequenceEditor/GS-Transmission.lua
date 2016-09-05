local GSSE = GSSE

function GSSE:OnCommReceived(prefix, message, distribution, sender)

end



GSSE:RegisterComm("GS-E", GSSE:OnCommReceived)
