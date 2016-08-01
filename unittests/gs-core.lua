package.path = package.path .. ";./wowmock/?.lua"
local LuaUnit = require('luaunit')
local mockagne = require('mockagne')
local wowmock = require('wowmock')
local bit = require('bit')

local function setup()
	G = mockagne:getMock()
  startup = wowmock("../GS-Core/startup.lua", G)
  gscore = wowmock("../GS-Core/Core.lua", G)
end

testGScore = { setup = setup}

function testGScore:test_unknown_category()
	assertEquals(pcall(gscore.isempty(nil)), true)
end
