

describe('gs-core', function()
  it('Check isempty', function()
    --local startup = require 'GS-Core/startup'
    local core = require 'GS-Core/Core'
    assert.equal(true, core._isempty(nil))
  end)
end)
