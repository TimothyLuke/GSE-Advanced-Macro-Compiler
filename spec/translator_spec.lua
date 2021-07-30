describe('API Translator', function()
  setup (function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/translator")
    GSE.GameMode = 9
  end)

  it("Passes through non spell commands and adds the things", function()
    assert.are.equal("|cffddaaff/targetenemy|r", GSE.TranslateString("/targetenemy", "STRING"))

  end)

  it("Passes through unknown spell commands ", function()
    assert.are.equal("/somethingsomethingdarkside", GSE.TranslateString("/somethingsomethingdarkside", "STRING"))

  end)


  it("checks that comments are processed", function()
    local originalstring = '-- This is a comment'
    local newstring = GSE.TranslateString(originalstring, "STRING")
    assert.are.equal("|cffcc7777-- This is a comment|r",newstring)

    originalstring = "/cast Eye of Tyr"
    newstring = GSE.TranslateString(originalstring, "STRING")
    assert.are_not.equals("|cffcc7777/cast Eye of Tyr|r", newstring)
  end)

  it("checks that ctrl:mods are retained", function()
    local originalstring = '/castsequence [mod:ctrl] !Eye of Tyr, Eye of Tyr, Eye of Tyr, Eye of Tyr; [nomod] Eye of Tyr, !Eye of Tyr, Eye of Tyr, Eye of Tyr, Eye of Tyr'
    local newstring = GSE.TranslateString(originalstring, "STRING")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

  --it("checks that [talent:123] choices are kept within a cast sequence]", function()
  --  local originalstring = '/castsequence reset=combat Frost Strike, Obliterate, [talent:6/1] Frostscythe'
  --  local newstring = GSE.TranslateString(originalstring, "enUS", "enUS")
  --  local finalstring = GSE.UnEscapeString(newstring)
  --  assert.are.equal(originalstring, finalstring)
  --end)

  it ("checks that pet stuff is not weird", function()
    local originalstring = '/petautocaston [nogroup] Eye of Tyr; [@focus,noexists] Eye of Tyr'
    local newstring = GSE.TranslateString(originalstring, "STRING")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)
  end)

  it("checks for weird macro translations that break things", function ()
    local originalstring = "/cast [mod:alt, talent:6/1, talent:7/1, nochanneling:Void Torrent] [mod:alt, talent:6/1, talent:7/2, nochanneling:Void Torrent] Eye of Tyr"
    local newstring = GSE.TranslateString(originalstring, "STRING")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)

  end)

  it ("tests other unusual modifier cases", function ()
    local originalstring = "/castsequence [@mouseover,help,nodead] [@player] Eye of Tyr, Eye of Tyr"
    local newstring = GSE.TranslateString(originalstring, "STRING")
    local finalstring = GSE.UnEscapeString(newstring)
    assert.are.equal(originalstring, finalstring)

  end)

--  it ("tests that statics are sane", function ()
--     assert.are.equal("Global", GSE.Static.SpecIDList[0])
--     assert.are.equal("Outlaw", GSE.Static.SpecIDList[260])
--     assert.are.equal(193316, GSE.Static.BaseSpellTable[5171])
--     assert.are.equal("|r", GSE.Static.StringReset)
--   end)

end)
