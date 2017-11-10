-- use this to test sequential loop on https://www.lua.org/cgi-bin/demo
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
    "Post2",
  },
}
local step = 1
local loopstart = 3
local loopiter = 1
local RepeatMacro = 2
local RepeatPreMacro = 2
local RepeatPostMacro = 2
local macros = {}
for k,v in ipairs(sequence.PreMacro) do
  table.insert(macros, v)
end
for k,v in ipairs(sequence) do
  table.insert(macros, v)
end
local loopstop = #macros
local phase = "pre"
local currentphase = phase
for k,v in ipairs(sequence.PostMacro) do
  table.insert(macros, v)
end
print ("LoopStart: " .. loopstart)
print ("LoopStop: " .. loopstop)
local phasestart = 1
local phaseend = 1
local currentphase = phase
local phasecount = 1
local phaselooplimit = 1
local function click(step)
  -- determine phase and loop macro parameters
  if step >= loopstop then
    currentphase = "post"
    phasestart = loopstop
    phaseend = #macros
    phaselooplimit = RepeatPostMacro
  elseif step >= loopstart then
    currentphase = "normal"
    phasestart = loopstart
    phaseend = loopstop - 1
    phaselooplimit = RepeatMacro
  else
    currentphase = "pre"
    phasestart = 1
    phaseend = loopstart - 1
    phaselooplimit = RepeatPreMacro
  end
  if phase == currentphase then
    -- same phase
    step = step + 1
  else
    -- restart or same phase
    print(phasecount .. " " .. phaselooplimit .. " " .. step)
    if phasecount >= phaselooplimit then
      -- next phase
      phasecount = 1
      phase = currentphase
    else
      -- repeat phase
      phasecount = phasecount + 1
      if phase == "normal" then
        step = loopstart - 1
      elseif phase == "post" then
        step = loopstop
      else
        step = 1
      end
    end
  end
  if step > #macros then
    step = 1
    phase = "pre"
  end
  return step
end
print ("starting")
for i=1, 50 do
  print(step .. " " .. macros[step])
  step = click(step)
end
