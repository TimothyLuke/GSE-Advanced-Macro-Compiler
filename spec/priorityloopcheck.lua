---@diagnostic disable: lowercase-global
-- Use this to test sequential loop on https://www.lua.org/cgi-bin/demo
sequence = {
  PreMacro = {
    "Pre1",
    "Pre2",
  },
  "main1",
  "main2",
  "main3",
  "main4",
  "main5",
  "main6",
  PostMacro = {
    "Post1",
    "Pos2",
  },
  looplimit = 2,
}


local step = 1
local loopstart = 3
local loopiter = 1
local looplimit = 2
local macros = {}

for k,v in ipairs(sequence.PreMacro) do
  table.insert(macros, v)
end

for k,v in ipairs(sequence) do
  table.insert(macros, v)
end

local loopstop = #macros

for k,v in ipairs(sequence.PostMacro) do
  table.insert(macros, v)
end

print ("LoopStart: " .. loopstart)
print ("LoopStop: " .. loopstop)
print ("LoopLimit: " .. looplimit)
print ("Number of Macros: " .. #macros)

local function click(step)

  if step < loopstart then
    step = step + 1

  elseif step > loopstop and loopstop == #macros then
    if step >= #macros then
      loopiter = 1
      step = loopstart
      if looplimit > 0 then
        step = 1
        limit = loopstart
      end
    else
      step = step + 1
    end
  elseif step == loopstop then
    if looplimit > 0 then
      if loopiter >= looplimit then
        if loopstop >= #macros then
          step = 1
          limit = loopstart
        else
          step = step + 1
          loopiter = 1
        end
      else
        step = loopstart
        loopiter = loopiter + 1
      end
    else
      step = loopstart
    end
  elseif step >= #macros then
    loopiter = 1
    step = loopstart
    if looplimit > 0 then
      step = 1
      limit = loopstart
    end
  else
    limit = limit or loopstart
    if step == limit then
      limit = limit % loopstop + 1
      step = loopstart
      if limit == loopiter then
        loopiter = loopiter + 1
      end
    else
      step = step + 1
    end
  end
  return step
end

print ("starting")

for i=1, 50 do
  print(step .. " " .. macros[step])
  step = click(step)

end
