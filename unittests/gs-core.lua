package.path = package.path .. ";./wowmock/?.lua"
local LuaUnit = require('luaunit')
local mockagne = require('mockagne')
local wowmock = require('wowmock')
local bit = require('bit')

local function setup()
	G = mockagne:getMock()
  startup = wowmock("../GS-Core/startup.lua", G)
  gs-core = wowmock("../GS-Core/core.lua", G)
end

testGS-core = { setup = setup}

function testGS-core:test_unknown_category()
	assertEquals(pcall(gs-core.isempty(nil)), true)
end
