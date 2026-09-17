---@diagnostic disable: undefined-global

-- The guard that stops an action block's edit boxes rewriting the wrong action
-- (#2106). Deleting one Action block rewrote 36 others from
-- {type="spell", spell=49998} into a macro carrying the localised spell name,
-- silently, with no Lua error.
--
-- Editor.lua cannot be loaded here, so this lifts the two helpers out of the
-- shipped file and runs them -- change them there and this fails.
--
-- .gitattributes marks *.lua eol=crlf, so normalise on read: a pattern anchored
-- on a line ending passes on a freshly written file and fails on a checked-out
-- one (see CLAUDE.md).
local function liftHelpers()
    local fh = assert(io.open("GSE_GUI/Editor.lua", "r"), "cannot open GSE_GUI/Editor.lua")
    local src = fh:read("*a")
    fh:close()
    src = (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local block = src:match("(local function setTextQuietly.-return false)")
    assert(block, "setTextQuietly/editIsStale block not found in Editor.lua")
    local compile = loadstring or load
    return assert(compile(block .. "\nend\nreturn setTextQuietly, editIsStale"))()
end

local setTextQuietly, editIsStale = liftHelpers()

-- A stand-in for a pooled edit box: SetText fires its handler synchronously,
-- the way WoW's OnTextChanged does.
local function fakeBox(onTextChanged)
    local box = {text = ""}
    function box:SetText(t)
        self.text = t
        if onTextChanged then onTextChanged(self, "OnTextChanged", t) end
    end
    return box
end

describe("editor write guard", function()
    describe("editIsStale", function()
        local owner = {macro = "/cast Something"}

        it("lets a real edit of the owning block through", function()
            assert.is_false(editIsStale({gseOwner = owner}, owner))
        end)

        it("blocks our own programmatic injection", function()
            assert.is_true(editIsStale({gseOwner = owner, gseProgrammaticSetText = true}, owner))
        end)

        -- The recycling case: one pooled box served several blocks in a single
        -- rebuild, and a fire carrying a previous life's handler wrote through
        -- that life's keyPath.
        it("blocks a box that now belongs to another block", function()
            local other = {macro = "/cast Other"}
            assert.is_true(editIsStale({gseOwner = other}, owner))
        end)

        it("blocks a box that never claimed an owner", function()
            assert.is_true(editIsStale({}, owner))
        end)

        it("blocks a missing widget", function()
            assert.is_true(editIsStale(nil, owner))
        end)
    end)

    describe("setTextQuietly", function()
        it("suppresses the handler for the duration of the injection", function()
            local owner = {}
            local wrote = 0
            local box
            box = fakeBox(function(sel)
                if editIsStale(sel, owner) then return end
                wrote = wrote + 1
            end)
            box.gseOwner = owner

            setTextQuietly(box, "灵界打击")
            assert.equals(0, wrote, "injected text must not count as a user edit")
            assert.equals("灵界打击", box.text, "the text is still set")

            -- and a genuine edit afterwards still writes
            box:SetText("/cast Typed")
            assert.equals(1, wrote, "a real edit still writes")
        end)

        it("clears the flag even though the fire is synchronous", function()
            local box = fakeBox(nil)
            setTextQuietly(box, "x")
            assert.is_nil(box.gseProgrammaticSetText)
        end)

        it("is safe on a widget with no SetText", function()
            assert.has_no.errors(function() setTextQuietly(nil, "x") end)
            assert.has_no.errors(function() setTextQuietly({}, "x") end)
        end)
    end)

    -- The full shape of the bug: a pooled box is handed to a second block and
    -- the first block's handler is still attached. Without the owner stamp the
    -- injection for block 2 writes through block 1's captured keyPath.
    it("does not let a recycled box rewrite the block it came from", function()
        local blockOne, blockTwo = {spell = 49998}, {spell = 12345}
        local corrupted = false
        local box
        box = fakeBox(function(sel)
            -- the handler built for blockOne, still bound
            if editIsStale(sel, blockOne) then return end
            blockOne.macro = sel.text
            blockOne.spell = nil
            corrupted = true
        end)

        box.gseOwner = blockOne          -- first life
        box.gseOwner = blockTwo          -- recycled for the next block
        setTextQuietly(box, "灵界打击")  -- block two's text injected

        assert.is_false(corrupted, "block one must not be rewritten")
        assert.equals(49998, blockOne.spell, "the spell id survives")
        assert.is_nil(blockOne.macro)
    end)
end)
