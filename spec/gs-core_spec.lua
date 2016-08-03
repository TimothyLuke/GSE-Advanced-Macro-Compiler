
describe('gs-core', function()
  local LuaUnit = require('luaunit')
  local mockagne = require('mockagne')
  local wowmock = require('/home/travis/build/TimothyLuke/GnomeSequenced-Enhanced/spec/wowmock')
  local when, verify = mockagne.when, mockagne.verify
  -- Mocks
  local globals, addon

  setup(function()
    -- Prepare an addon mock
    addon = mockagne:getMock()

    -- Prepare a globals mock
    globals = mockagne:getMock()

    -- Load the file to test
      wowmock("GS-Core/Core.lua", globals, "GS-Core", addon)
    end)


  it('Check isempty', function()

    assert.equal(true, addon._isempty(nil))
  end)
end)
