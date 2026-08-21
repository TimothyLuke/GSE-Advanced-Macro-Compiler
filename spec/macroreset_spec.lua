---@diagnostic disable: undefined-global
-- The manual-reset snippet is secure-environment code stamped onto the button
-- at build time, so it cannot read GSEOptions when it runs. Which form gets
-- stamped is decided here, in normal Lua — and the reset itself must keep
-- working when the announcement is off, which is the part worth a test.
describe(
  "Manual sequence reset",
  function()
    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
        require("../GSE/API/CharacterFunctions")
        require("../GSE/API/Storage")
        require("../GSE/API/translator")
        Statics = GSE.Static
      end
    )

    before_each(
      function()
        GSEOptions = GSEOptions or {}
        GSEOptions.MacroResetModifiers = {LeftButton = true}
      end
    )

    it(
      "is silent by default (#1991)",
      function()
        GSEOptions.AnnounceMacroReset = false
        local snippet = GSE.GetMacroResetImplementation()
        assert.is_nil(snippet:find("print%("))
      end
    )

    it(
      "still resets to step 1 when the announcement is off",
      function()
        GSEOptions.AnnounceMacroReset = false
        local snippet = GSE.GetMacroResetImplementation()
        assert.is_not_nil(snippet:find("SetAttribute%('step', 1%)"))
        assert.is_not_nil(snippet:find('GetMouseButtonClicked%(%) == "LeftButton"'))
      end
    )

    it(
      "announces when the option is turned on",
      function()
        GSEOptions.AnnounceMacroReset = true
        local snippet = GSE.GetMacroResetImplementation()
        assert.is_not_nil(snippet:find("print%("))
        assert.is_not_nil(snippet:find("SetAttribute%('step', 1%)"))
      end
    )

    it(
      "treats a nil option as off, not as an error",
      function()
        GSEOptions.AnnounceMacroReset = nil
        local snippet = GSE.GetMacroResetImplementation()
        assert.is_nil(snippet:find("print%("))
      end
    )

    it(
      "emits nothing at all when no reset modifier is configured",
      function()
        GSEOptions.MacroResetModifiers = {}
        GSEOptions.AnnounceMacroReset = true
        assert.equals("", GSE.GetMacroResetImplementation())
      end
    )

    it(
      "combines several modifiers into one condition",
      function()
        GSEOptions.MacroResetModifiers = {LeftButton = true, Alt = true}
        GSEOptions.AnnounceMacroReset = false
        local snippet = GSE.GetMacroResetImplementation()
        assert.is_not_nil(snippet:find(" and "))
      end
    )
  end
)
