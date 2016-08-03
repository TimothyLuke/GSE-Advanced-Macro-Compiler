
describe('gs-core', function()


  it('Check isempty', function()
    dofile("spec/wowmock/wowlua.lua")
    dofile("spec/wowmock/wowmock.lua")
    dofile("GS-Core/startup.lua")
    dofile("GS-Core/errorhandler.lua")
    --local startup = require 'GS-Core/startup'
    local core = require 'GS-Core/Core'
    assert.equal(true, core._isempty(nil))
  end)
end)
