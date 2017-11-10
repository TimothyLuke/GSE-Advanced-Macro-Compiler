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
local phasestart = 1
local phaseend = 1
local currentphase = phase
local phasecount = 1
local phaselooplimit = 1
local previousphase

local function returnphaselimits(iphase)
  local iphasestart, iphaseend, iphaselooplimit, ipreviousphase
  if iphase == "normal" then
    iphasestart = loopstart
    iphaseend = loopstop - 1
    iphaselooplimit = RepeatMacro
    ipreviousphase = "pre"
  elseif iphase == "post" then
    iphasestart = loopstop
    iphaseend = #macros
    iphaselooplimit = RepeatPostMacro
    ipreviousphase = "normal"
  else
    iphasestart = 1
    iphaseend = loopstart - 1
    iphaselooplimit = RepeatPreMacro
    ipreviousphase = "post"
  end
  return iphasestart, iphaseend, iphaselooplimit, ipreviousphase
end
local function click(step)
  -- determine phase and loop macro parameters
  if step >= loopstop then
    currentphase = "post"
  elseif step >= loopstart then
    currentphase = "normal"
  else
    currentphase = "pre"
  end
  phasestart, phaseend, phaselooplimit, previousphase = returnphaselimits(currentphase)
  if phase ~= currentphase then
    -- restart or same phase
    print(phasecount .. " " .. phaselooplimit .. " " .. step)
    phasestart, _, phaselooplimit, _ = returnphaselimits(previousphase)
    if phasecount >= phaselooplimit then
      -- next phase
      phasecount = 1
      phase = currentphase
    else
      -- repeat phase
      phasecount = phasecount + 1
      step = phasestart
    end
  else
    -- same phase
    step = step + 1
  end
  if step > #macros then
    step = 1
    phase = "pre"
  end
  return step
end
print ("starting")
for i=1, 50 do
  print(step .. " " .. macros[step] .. " " .. phase)
  step = click(step)
end
