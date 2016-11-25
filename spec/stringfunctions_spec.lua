describe('gs-core', function()
  setup (function()

    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")

  end)

  it("tests positive assertions", function()
    assert.is_true(true)
    assert.are.equal(1, 1)
    assert.has.errors(function() error("this should fail") end)
  end)

  it("tests isEmpty", function()
    assert.is_true(GSE.isEmpty(nil))
    assert.is_true(GSE.isEmpty(''))
    assert.is_false(GSE.isEmpty("String"))
  end)

  it ("tests GSE.SplitMeIntolines(str)", function ()
     assert.are.same({[1] = "a", [2] = "b"}, GSE.SplitMeIntolines("a\nb"))
  end)
  
end)
