local GSE = GSE
-- Change the 2 here to your classID.  2 = paladin.  /gse showspec will tell you your current ClassID
if GSE.GetCurrentClassID() == 2 then
    -- Change this to the name of the macro you want to load in combat.  Note this has to be unique
    local name = "NEWMACRO"

    -- Change sequence to the export from Raw Edit or compile it manually using the GSE Block Specification.
    -- this will look like
    --
    -- local sequence = {
    -- ["Variables"] = {
    --     ["After"] = {
    --        [1] = "/cast [nomod:alt/shift, combat, nochanneling] Divine Protection",
    --        [2] = "/cast [combat] Avenging Wrath"
    --    },
    -- },
    -- ["Actions"] = {
    --     [1] = {
    --         [1] = "/cast [mod:shiftalt] Wake of Ashes",
    --         [2] = "/cast [nomod:alt/shift, nochanneling] Blade of Justice",
    --         [3] = "~~After~~",
    --         ["Type"] = "Action"
    --     },
    --     [2] = {
    --         [2] = "/cast [known:Final Reckoning, mod:shiftalt] Wake of Ashes",
    --         [3] = "/cast [known:Execution Sentence, mod:shiftalt] Divine Toll",
    --         [4] = "/cast [nomod:alt/shift, combat, nochanneling] Hammer of Wrath",
    --         [5] = "~~After~~",
    --         ["Interval"] = 2,
    --         ["Type"] = "Repeat"
    --     },
    -- },
    -- ["InbuiltVariables"] = {
    --     ["Trinket1"] = true,
    --     ["Combat"] = true,
    --     ["Trinket2"] = true
    --  }
    -- }

    local sequence = {}

    -- This sets up the button in combat.
    local macro = GSE.CompileTemplate(sequence)
    GSE.CreateGSE3Button(macro, name, true)
    local key = "2"
    SetBindingClick(key, name, _G[name])
    

-- to add a second simply repeat changing name, key and sequence

-- name = "NEXTNAME"
-- sequence = {}
-- macro = GSE.CompileTemplate(sequence)
-- GSE.CreateGSE3Button(macro, name, true)
-- SetBindingClick(key, name, _G[name])
end
