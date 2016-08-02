

describe('gs-core', function()
  local seterrorhandler = function(message) print(message) end
  --setup(function()
  --  util = require("util")
  --end)
  it('Check isempty', function()
    --local startup = require 'GS-Core/startup'
    local core = require 'GS-Core/Core'
    assert.equal(true, core._isempty(nil))
  end)
end)
