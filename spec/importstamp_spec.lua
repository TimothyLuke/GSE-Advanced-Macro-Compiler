---@diagnostic disable: undefined-global
-- The origin key is stamped when a sequence is imported (#2045), not only on
-- the next load. Imports store through GSE.OOCPerformMergeAction, which lives
-- in GSE_Utils/Utils.lua, so this spec loads Utils the way
-- sequencechecker_spec does.
-- Run with: busted spec/importstamp_spec.lua

-- IndentationLib is a WoW addon loaded before GSE_Utils/Utils.lua in-game.
IndentationLib = {
  tokens = {
    TOKEN_SPECIAL       = "special",
    TOKEN_KEYWORD       = "keyword",
    TOKEN_UNKNOWN       = "unknown",
    TOKEN_COMMENT_SHORT = "comment_short",
    TOKEN_COMMENT_LONG  = "comment_long",
    TOKEN_STRING        = "string",
    TOKEN_NUMBER        = "number",
  }
}

describe(
  "API Storage origin key on import",
  function()
    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
        require("../GSE/API/CharacterFunctions")
        require("../GSE/API/Storage")

        Statics = GSE.Static
        L = GSE.L
        setmetatable(L, {__index = function(_, k) return k end})

        -- Ace3 method used at module level in Utils.lua
        function GSE:RegisterChatCommand(command, handler) -- luacheck: ignore
        end

        GSESequences = {}
        for i = 0, 13 do GSESequences[i] = {} end

        require("../GSE_Utils/Utils")
      end
    )

    it(
      "is stamped when imported, not only on the next load",
      function()
        -- A new or replaced import stores through OOCPerformMergeAction,
        -- which writes into the Library directly rather than through
        -- ReplaceSequence, so the stamp on save never sees it.
        local saveSendMessage, saveDeps = GSE.SendMessage, GSE.ComputeSequenceDependencies
        GSE.SendMessage = function() end
        GSE.ComputeSequenceDependencies = function() end
        _G.GSESequences = {[1] = {}}
        GSE.Library = {[1] = {}}
        local seq = {MetaData = {Author = "Bob@Realm", Default = 1}, Versions = {{Actions = {}}},
                     LastUpdated = "20260912000000"}
        GSE.OOCPerformMergeAction("REPLACE", 1, "SBA", seq)
        assert.are.equal("SBA|Bob@Realm", GSE.Library[1]["SBA"].MetaData.OriginKey)
        -- replacing it again with a body that already carries a key keeps that key
        local again = {MetaData = {Author = "Bob@Realm", Default = 1, OriginKey = "Old|Bob@Realm"},
                       Versions = {{Actions = {}}}, LastUpdated = "20260912000001"}
        GSE.OOCPerformMergeAction("REPLACE", 1, "SBA", again)
        assert.are.equal("Old|Bob@Realm", GSE.Library[1]["SBA"].MetaData.OriginKey)
        GSE.SendMessage, GSE.ComputeSequenceDependencies = saveSendMessage, saveDeps
      end
    )

  end
)
