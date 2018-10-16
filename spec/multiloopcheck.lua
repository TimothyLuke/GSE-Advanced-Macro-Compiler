-- use this to test sequential loop on https://www.lua.org/cgi-bin/demo
macros = {}
macros[1] = {
  "pre1",
  "pre2",
  "pre3",
  "pre4",
  "pre5",
  Repeat = 2
}

macros[2] = {
  "main1",
  "main2",
  "main3",
  "main4",
  "main5",
  "main6",
  Repeat = 3
}

local step = 1
local stage = 1

print ("Number of stages: " .. #macros)

local function click(stage, step)

  numstages = #macros
  limit = limit or 1
  repeats = repeats or 1
  --print ("limit: " .. limit .. ", stage: " .. stage .. ", step: " .. step)
  if step == limit then
    limit = limit % #macros[stage] + 1
    if step == #macros[stage] then
      if repeats == macros[stage].Repeat then
        if stage == numstages then
          --print("stage reset")
          stage = 1
        else
          --print("stage increase")
          stage = stage + 1
        end
        repeats = 1
      else
        repeats = repeats + 1
      end
    end
    step = 1
  else
    step = step % limit + 1
  end

  return stage, step
end

print ("starting")

for i=1, 50 do
  print("return: " .. stage .. " " .. step .. " " .. macros[stage][step])
  stage, step = click(stage,step)

end
