-- $Id: LibStub.lua 47499 2007-08-27 07:51:33Z ammo $
-- LicenseText
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 1
local LibStub = _G[LIBSTUB_MAJOR]

function strmatch(string, pattern, initpos)
  return string.match(string, pattern, initpos)
end



-- Check to see is this version of the stub is obsolete
if not LibStub or LibStub.minor < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {} }
	_G[LIBSTUB_MAJOR] = LibStub
	LibStub.minor = LIBSTUB_MINOR

	-- LibStub:NewLibrary(major, minor)
	-- major (string) - the major version of the library
	-- minor (string or number ) - the minor version of the library
	--
	-- returns nil if a newer or same version of the lib is already present
	-- returns empty library object or old library object if upgrade is needed
	function LibStub:NewLibrary(major, minor)
		assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
		minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")

		if self.minors[major] and self.minors[major] >= minor then return nil end
		local oldminor = self.minors[major]
		self.minors[major], self.libs[major] = minor, self.libs[major] or {}
		return self.libs[major], oldminor
	end

	-- LibStub:GetLibrary(major, [silent])
	-- major (string) - the major version of the library
	-- silent (boolean) - if true, library is optional, silently return nil if its not found
	--
	-- throws an error if the library can not be found (except silent is set)
	-- returns the library object if found
	function LibStub:GetLibrary(major, silent)
		if not self.libs[major] then
			self:NewLibrary(major, major)
		end

		return self.libs[major], self.minors[major]
	end

	-- LibStub:IterateLibraries()
	--
	-- Returns an iterator for the currently registered libraries
	function LibStub:IterateLibraries()
		return pairs(self.libs)
	end

  -- Mock AceLocale
  function LibStub:NewLocale(application, locale, isDefault, silent)
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
	setmetatable(LibStub, { __call = LibStub.GetLibrary })
end
