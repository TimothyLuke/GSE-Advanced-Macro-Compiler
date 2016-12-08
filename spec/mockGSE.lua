GSE = {}
GSE.L = setmetatable({}, {
  __newindex = function(self, key, value)
    if not rawget(registering, key) then
      rawset(registering, key, value == true and key or value)
    end
  end,
  __index = assertfalse
})
GSE.Static = {}
GSE.VersionString = 150;

GNOME = "UnitTest"

function GSE.Print(message, title)
  print (title .. ": " .. message)
end

function GSE.PrintDebugMessage(message, title)
  GSE.Print(message, title)
end

GSE.PVPFlag = false
GSE.inRaid = false
GSE.inMythic = false

function strmatch(string, pattern, initpos)
  return string.match(string, pattern, initpos)
end

function newLocale(application, locale, isDefault, silent)
  local writedefaultproxy = setmetatable({}, {
    __newindex = function(self, key, value)
      if not rawget(registering, key) then
        rawset(registering, key, value == true and key or value)
      end
    end,
    __index = assertfalse
  })
  if isDefault then
    return writedefaultproxy
  end
end
