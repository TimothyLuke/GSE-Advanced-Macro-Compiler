-- Use this to test sequential loop on https://www.lua.org/cgi-bin/demo
sequence = {
  PreMacro = {
    "Pre1",
    "Pre2",
  },
  "main1",
  "main2",
  PostMacro = {
    "Post1",
    "Pos2",
  },
  looplimit = 2,
}


local step = 1
local loopstart = #sequence.PreMacro + 1
local loopiter = 1
local macros = {}
for k,v in ipairs(sequence.PreMacro) do
  table.insert(macros, v)
end

for k,v in ipairs(sequence) do
  table.insert(macros, v)
end

local loopstop = #macros
local looplimit = 2

--for k,v in ipairs(sequence.PostMacro) do
--  table.insert(macros, v)
--end

print (loopstart)
print (loopstop)
print (looplimit)
print (#macros)

local function click(step)

  if step < loopstart then
    -- I am before the loop increment to next step.
    step = step + 1
  elseif step > loopstop then
    step = step + 1
  elseif step == loopstop then
    if looplimit > 0 then
      if loopiter >= looplimit then
        if loopstop >= #macros then
          step = 1
        else
          step = step + 1
        end
        loopiter = 1
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
    end
  else
    step = step + 1
  end
  return step
end

print ("starting")

for i=1, 15 do
  print(step .. " " .. macros[step])
  step = click(step)

end
