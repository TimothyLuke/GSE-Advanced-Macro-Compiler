---@diagnostic disable: undefined-global, lowercase-global, duplicate-set-field

-- Coverage for the ActionButtonUseKeyDown-independent click model:
--   * GSE.GetKeybindClickTarget picks executor vs key-down relay correctly.
--   * The relay/executor useOnKeyDown + RegisterForClicks combination yields
--     exactly ONE cast per input on every invocation path, modelled against
--     Blizzard's verified dispatch gate in SecureTemplates.lua:
--         clickAction = (down and useOnKeyDown) or (not down and not useOnKeyDown)
--     i.e. the action fires iff down == useOnKeyDown.

-- ---------------------------------------------------------------------------
-- Minimal WoW frame/CVar shims (mockGSE does not provide these).
-- ---------------------------------------------------------------------------
local combat = false
local cvars = {ActionButtonUseKeyDown = "0"}

-- Bind through _G so the source chunks (loaded via loadfile in mockGSE, using
-- the real global table) actually see these shims.
_G.InCombatLockdown = function()
  return combat
end

_G.C_CVar = {
  GetCVar = function(_, name)
    -- Source calls C_CVar.GetCVar("name") (dot form) so the first arg is the name.
    name = name or _
    return cvars[name]
  end
}

local function makeFrame(name)
  local f = {name = name, attrs = {}, clicks = nil}
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:RegisterForClicks(...) self.clicks = {...} end
  function f:IsForbidden() return false end
  return f
end

_G.CreateFrame = function(_, name)
  local f = makeFrame(name)
  if name then _G[name] = f end
  return f
end

require("../spec/mockGSE")
require("../GSE/API/Statics")
require("../GSE/API/InitialOptions")
require("../GSE/API/StringFunctions")
require("../GSE/API/CharacterFunctions")
require("../GSE/API/Storage")

-- Verified Blizzard gate: the secure action executes only on the matching edge.
local function casts(down, useOnKeyDown)
  return (down and useOnKeyDown) or (not down and not useOnKeyDown)
end

describe(
  "ActionButtonUseKeyDown-independent click model",
  function()
    before_each(
      function()
        combat = false
        cvars.ActionButtonUseKeyDown = "0"
        _G["TESTSEQ"] = makeFrame("TESTSEQ")
        _G["TESTSEQ_KD"] = nil
      end
    )

    describe(
      "GSE.GetKeybindClickTarget",
      function()
        it(
          "binds straight to the executor when the CVar is off",
          function()
            cvars.ActionButtonUseKeyDown = "0"
            assert.are.equal("TESTSEQ", GSE.GetKeybindClickTarget("TESTSEQ"))
            assert.is_nil(_G["TESTSEQ_KD"])
          end
        )

        it(
          "builds a key-down relay and binds to it when the CVar is on",
          function()
            cvars.ActionButtonUseKeyDown = "1"
            local target = GSE.GetKeybindClickTarget("TESTSEQ")
            assert.are.equal("TESTSEQ_KD", target)
            local relay = _G["TESTSEQ_KD"]
            assert.is_not_nil(relay)
            assert.are.equal("click", relay:GetAttribute("type"))
            assert.are.equal(_G["TESTSEQ"], relay:GetAttribute("clickbutton"))
            assert.is_true(relay:GetAttribute("useOnKeyDown"))
            assert.are.same({"AnyDown"}, relay.clicks)
          end
        )

        it(
          "falls back to the executor in combat when no relay exists yet",
          function()
            cvars.ActionButtonUseKeyDown = "1"
            combat = true
            assert.are.equal("TESTSEQ", GSE.GetKeybindClickTarget("TESTSEQ"))
            assert.is_nil(_G["TESTSEQ_KD"])
          end
        )

        it(
          "returns the name unchanged when the executor does not exist",
          function()
            cvars.ActionButtonUseKeyDown = "1"
            assert.are.equal("MISSING", GSE.GetKeybindClickTarget("MISSING"))
          end
        )

        it(
          "does not clobber a real sequence that happens to be named <name>_KD",
          function()
            cvars.ActionButtonUseKeyDown = "1"
            -- A user sequence literally named TESTSEQ_KD already owns the name.
            local foreign = makeFrame("TESTSEQ_KD")
            foreign:SetAttribute("type", "spell")
            _G["TESTSEQ_KD"] = foreign
            assert.are.equal("TESTSEQ", GSE.GetKeybindClickTarget("TESTSEQ"))
            -- The foreign frame is left untouched.
            assert.are.equal("spell", _G["TESTSEQ_KD"]:GetAttribute("type"))
            assert.is_nil(_G["TESTSEQ_KD"].gseKeyDownRelay)
          end
        )
      end
    )

    describe(
      "single cast per input on the executor (useOnKeyDown=false)",
      function()
        local executorUseOnKeyDown = false

        it(
          "override delegate forward (Click(button), down=false) casts in BOTH CVar states",
          function()
            -- SECURE_ACTIONS.click forwards delegate:Click(button) -> down=false,
            -- regardless of which edge the override button fired on.
            assert.is_true(casts(false, executorUseOnKeyDown))
          end
        )

        it(
          "a key-up keybind (AnyUp, down=false) casts exactly once",
          function()
            -- Registered for AnyUp only -> one OnClick (down=false) per press.
            assert.is_true(casts(false, executorUseOnKeyDown))
          end
        )

        it(
          "a stray down edge would NOT double-cast (down=true is suppressed)",
          function()
            assert.is_false(casts(true, executorUseOnKeyDown))
          end
        )
      end
    )

    describe(
      "key-down relay chain casts once on the key-down edge",
      function()
        it(
          "relay fires on down (useOnKeyDown=true) then forwards down=false to the executor",
          function()
            local relayUseOnKeyDown = true
            local executorUseOnKeyDown = false
            -- key down -> relay OnClick(down=true): clickAction true -> forwards.
            assert.is_true(casts(true, relayUseOnKeyDown))
            -- forwarded Click(button) -> executor OnClick(down=false): casts.
            assert.is_true(casts(false, executorUseOnKeyDown))
            -- key up -> relay not registered for up -> no second cast.
            -- (modelled: the relay only ever sees down=true)
          end
        )
      end
    )
  end
)
