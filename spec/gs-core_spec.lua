
describe('gs-core', function()

  setup(function()
    local t = {
      seterrorhandler = function(msg) print(msg) end
    }
    stub(t, "seterrorhandler")
  end)

  it('Check isempty', function()

    --local startup = require 'GS-Core/startup'
    local core = require 'GS-Core/Core'
    assert.equal(true, core._isempty(nil))
  end)
end)
