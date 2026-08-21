-- Run the spec suite under PUC Lua 5.1 — exactly what CI installs
-- (leafo/gh-actions-lua@v10, luaVersion 5.1.5). busted is only installed here
-- for 5.4, so specs that pass locally can still fail in CI on anything 5.2+
-- added: load(chunk, name, mode, env), goto, integer division, table.unpack,
-- bitwise operators. That cost two round trips through CI, hence this shim.
--
--   lua5.1 spec/run51.lua      <- USE THIS. Strict; matches CI.
--   luajit spec/run51.lua      <- do NOT rely on it: LuaJIT extends 5.1 and
--                                 accepts load(string, ...), so it passes the
--                                 exact bug this exists to catch.
--
-- It is deliberately NOT a busted replacement. It implements the handful of
-- globals the GSE specs use, so a spec reaching for anything richer will fail
-- here and should be run under busted as well. Run BOTH:
--
--   lua5.1 spec/run51.lua          # every spec, on the CI interpreter
--   busted                         # full assertions, on 5.4
--
-- Exits non-zero on the first failing expectation, like busted does.
local passed, failed, failures, skipped = 0, 0, {}, {}
local stack, beforeEach = {}, {}

-- CI installs luabitop, which supplies the global `bit` that GSE/API/sha512.lua
-- needs. It is not installed here and cannot be without luarocks, so classify
-- those as SKIPPED rather than failing — a runner that always shows a failure
-- is a runner nobody reads. busted (5.4) and CI both still cover them.
local function isMissingBitLib(err)
  return type(err) == "string" and err:find("global 'bit'", 1, true) ~= nil
end

local function record(name, err)
  if isMissingBitLib(err) then
    table.insert(skipped, {name = name, why = "needs luabitop for the `bit` global (CI installs it; busted covers it here)"})
  else
    failed = failed + 1
    table.insert(failures, {name = name, err = err})
  end
end

local function describe(name, fn)
  table.insert(stack, name)
  local ok, err = pcall(fn)
  if not ok then record(table.concat(stack, " "), err) end
  table.remove(stack)
end

local function it(name, fn)
  for _, hook in ipairs(beforeEach) do hook() end
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    record(table.concat(stack, " ") .. " " .. name, err)
  end
end

local function deepEqual(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local function render(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for _, item in ipairs(v) do parts[#parts + 1] = tostring(item) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- luassert is a callable table: assert(x) plus assert.equals(a, b) etc.
local luassert = setmetatable({}, {__call = function(_, v, msg) if not v then error(msg or "assertion failed", 2) end return v end})
function luassert.equals(expected, actual, msg)
  if expected ~= actual then
    error((msg or "") .. " expected " .. render(expected) .. ", got " .. render(actual), 2)
  end
end
luassert.equal = luassert.equals
luassert.are = {equal = luassert.equals, same = function(e, a) return luassert.same(e, a) end}
function luassert.same(expected, actual, msg)
  if not deepEqual(expected, actual) then
    error((msg or "") .. " expected " .. render(expected) .. ", got " .. render(actual), 2)
  end
end
function luassert.is_nil(v, msg) if v ~= nil then error((msg or "") .. " expected nil, got " .. tostring(v), 2) end end
function luassert.is_not_nil(v, msg) if v == nil then error((msg or "") .. " expected non-nil", 2) end end
function luassert.is_true(v, msg) if v ~= true then error((msg or "") .. " expected true, got " .. tostring(v), 2) end end
function luassert.is_false(v, msg) if v ~= false then error((msg or "") .. " expected false, got " .. tostring(v), 2) end end
function luassert.is_truthy(v, msg) if not v then error((msg or "") .. " expected truthy, got " .. tostring(v), 2) end end
function luassert.is_falsy(v, msg) if v then error((msg or "") .. " expected falsy, got " .. tostring(v), 2) end end
luassert.truthy, luassert.falsy = luassert.is_truthy, luassert.is_falsy

-- assert.has.errors(fn) / assert.has_no.errors(fn)
luassert.has = {
  errors = function(fn, msg)
    if pcall(fn) then error((msg or "") .. " expected the call to error, it did not", 2) end
  end,
}
luassert.has_no = {
  errors = function(fn, msg)
    local ok, err = pcall(fn)
    if not ok then error((msg or "") .. " expected no error, got " .. tostring(err), 2) end
  end,
}

_G.describe = describe
_G.it = it
_G.setup = function(fn) fn() end
_G.teardown = function() end
_G.before_each = function(fn) table.insert(beforeEach, fn) end
_G.after_each = function() end
_G.assert = luassert
_G.pending = function() end

-- Specs require("../spec/x") and require("../GSE/API/x") relative to the repo
-- root, matching how busted is invoked.
package.path = "./?.lua;./?/init.lua;" .. package.path

local targets = {...}

-- With no arguments, re-run ONE FILE PER PROCESS. Specs leak globals into each
-- other — CreateFrame is defined only by keydownbinding_spec, and a spec that
-- runs after it sees a frame mock built for a different test — so sharing one
-- interpreter makes results depend on file order. A process each removes that.
if #targets == 0 then
  local interpreter = arg and arg[-1] or "lua5.1"
  local files = {}
  local pipe = io.popen("ls spec/*_spec.lua")
  for line in pipe:lines() do table.insert(files, line) end
  pipe:close()

  local anyFailed = false
  for _, file in ipairs(files) do
    local ok = os.execute(interpreter .. " spec/run51.lua " .. file)
    -- 5.1 returns the raw exit code, 5.2+ returns a boolean first.
    if ok ~= 0 and ok ~= true then anyFailed = true end
  end
  print(anyFailed and "\nSOME SPECS FAILED (Lua 5.1)" or "\nall specs passed (Lua 5.1)")
  os.exit(anyFailed and 1 or 0)
end

for _, file in ipairs(targets) do
  beforeEach = {}
  local chunk, loadErr = loadfile(file)
  if not chunk then
    failed = failed + 1
    table.insert(failures, {name = file, err = loadErr})
  else
    local ok, err = pcall(chunk)
    if not ok then record(file, err) end
  end
end

print(("\n%d passed, %d failed, %d skipped  (%s)"):format(passed, failed, #skipped, _VERSION))
for _, s2 in ipairs(skipped) do print("SKIP  " .. s2.name .. "\n      " .. s2.why) end
for _, f in ipairs(failures) do print("FAIL  " .. f.name .. "\n      " .. tostring(f.err)) end
os.exit(failed == 0 and 0 or 1)
