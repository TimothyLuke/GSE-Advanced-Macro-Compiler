local gs-core = require '../GS-Core/startup.lua'

describe('gs-core', function()
  it('CHeck isempty', function()
    assert.equal(true, gs-core.isempty(nil))
  end)
end)
