---@diagnostic disable: lowercase-global
-- Use this to test sequential loop on https://www.lua.org/cgi-bin/demo
sequence = {
  "main1",
  "main2",
  "main3",
  "main4",
  "main5",
  "main6",
}


local step = 1
local loopstart = 1
local loopiter = 1
local macros = {}
--for k,v in ipairs(sequence.PreMacro) do
--  table.insert(macros, v)
--end

for k,v in ipairs(sequence) do
  table.insert(macros, v)
end

local loopstop = #macros

--for k,v in ipairs(sequence.PostMacro) do
--  table.insert(macros, v)
--end

print ("Number of Macros: " .. #macros)

local function click(step)

  limit = limit or 1
  if step == limit then
    limit = limit % #macros + 1
    step = 1
  else
    step = step % #macros + 1
  end
  return step
end

print ("starting")

for i=1, 50 do
  print(step .. " " .. macros[step])
  step = click(step)

end
