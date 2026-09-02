---@diagnostic disable: undefined-global
describe(
  "API StringFunctions",
  function()
    setup(
      function()
        require("../spec/mockGSE")
        require("../GSE/API/Statics")
        require("../GSE/API/InitialOptions")
        require("../GSE/API/StringFunctions")
      end
    )

    it(
      "tests positive assertions",
      function()
        assert.is_true(true)
        assert.are.equal(1, 1)
        assert.has.errors(
          function()
            error("this should fail")
          end
        )
      end
    )

    it(
      "tests isEmpty",
      function()
        assert.is_true(GSE.isEmpty(nil))
        assert.is_true(GSE.isEmpty(""))
        assert.is_false(GSE.isEmpty("String"))
      end
    )

    -- Note these are all different implementations of the same thing
    it(
      "tests GSE.SplitMeIntoLines(str)",
      function()
        assert.are.same({[1] = "a", [2] = "b"}, GSE.SplitMeIntoLines("a\nb"))
      end
    )

    it(
      "tests GSE.lines",
      function()
        local tabl = {}
        GSE.lines(tabl, "a\nb")
        assert.are.same({[1] = "a", [2] = "b"}, tabl)
      end
    )

    it(
      "tests GSE.split",
      function()
        local testring = "a,b"
        local tab1 = GSE.split(testring, ",")
        assert.are.equal(tab1[1], "a")
        assert.are.equal(tab1[2], "b")
      end
    )

    it(
      "Tests GSE.FixQuotes",
      function()
        local teststring =
          [[Sequences[‘Druid_FeralST’] = {
author=”Aaralak@Nagrand”,
specID=103,
helpTxt = ‘Talents: 3331222’,]]
        local returnstring =
          [[Sequences['Druid_FeralST'] = {
author="Aaralak@Nagrand",
specID=103,
helpTxt = 'Talents: 3331222',]]
        assert.are.equal(returnstring, GSE.FixQuotes(teststring))
      end
    )

    it(
      "Tests GSE.UnEscapeSequence, GSE.UnEscapeString and GSE.UnescapeTable",
      function()
        local testsequence = {
          KeyPress = {
            "/targetenemy [noharm][dead]"
          },
          PreMacro = {
            "/cast [nochanneling] Elemental Blast"
          },
          "|cff88bbdd/cast|r [nochanneling] Lava Burst",
          "/cast [nochanneling] Stormkeeper",
          "/cast [nochanneling] Lightning Bolt",
          PostMacro = {
            "/use 14"
          },
          KeyRelease = {}
        }

        local expectedresultsequence = {
          KeyPress = {
            "/targetenemy [noharm][dead]"
          },
          PreMacro = {
            "/cast [nochanneling] Elemental Blast"
          },
          "/cast [nochanneling] Lava Burst",
          "/cast [nochanneling] Stormkeeper",
          "/cast [nochanneling] Lightning Bolt",
          PostMacro = {
            "/use 14"
          },
          KeyRelease = {}
        }

        local resultsequence = GSE.UnEscapeSequence(testsequence)

        assert.are.same(expectedresultsequence, resultsequence)
      end
    )

    it(
      "tests GSE.CleanStrings() removes noted values",
      function()
        assert.are.same("/cast Judgement", GSE.CleanStrings("/cast Judgement"))
      end
    )

    describe(
      "#showtooltip handling",
      function()
        local savedResolver

        before_each(
          function()
            savedResolver = GSE.GetShowTooltipIconInfo
          end
        )

        after_each(
          function()
            GSE.GetShowTooltipIconInfo = savedResolver
          end
        )

        it(
          "splits the directive off the executable body",
          function()
            local body, argument, found =
              GSE.SplitShowTooltipDirectives("#showtooltip Sunfire\n/cast Sunfire")
            assert.are.equal("/cast Sunfire", body)
            assert.are.equal("Sunfire", argument)
            assert.is_true(found)
          end
        )

        it(
          "reports a bare directive as found with no argument",
          function()
            local body, argument, found = GSE.SplitShowTooltipDirectives("#showtooltip\n/cast Sunfire")
            assert.are.equal("/cast Sunfire", body)
            assert.is_nil(argument)
            assert.is_true(found)
          end
        )

        it(
          "does not mistake #showtooltip for the shorter #show",
          function()
            local _, argument = GSE.SplitShowTooltipDirectives("#showtooltip Sunfire")
            assert.are.equal("Sunfire", argument)

            local _, showArgument = GSE.SplitShowTooltipDirectives("#show Sunfire")
            assert.are.equal("Sunfire", showArgument)
          end
        )

        it(
          "leaves a body with no directive untouched",
          function()
            local body, argument, found = GSE.SplitShowTooltipDirectives("/cast Sunfire")
            assert.are.equal("/cast Sunfire", body)
            assert.is_nil(argument)
            assert.is_false(found)
          end
        )

        it(
          "reads the lead char past directives and blank lines",
          function()
            assert.are.equal("/", GSE.GetMacroBodyLeadChar("#showtooltip Sunfire\n/cast Sunfire"))
            assert.are.equal("/", GSE.GetMacroBodyLeadChar("\n  /cast Sunfire"))
            assert.are.equal("=", GSE.GetMacroBodyLeadChar("=GSE.V.Something"))
            assert.are.equal("M", GSE.GetMacroBodyLeadChar("My In Game Macro"))
            assert.are.equal("", GSE.GetMacroBodyLeadChar("#showtooltip Sunfire"))
            assert.are.equal("", GSE.GetMacroBodyLeadChar(""))
          end
        )

        it(
          "treats a #showtooltip-led body as macro text",
          function()
            assert.is_true(GSE.IsMacroTextBody("#showtooltip Sunfire\n/cast Sunfire"))
            assert.is_false(GSE.IsMacroTextBody("My In Game Macro"))
          end
        )

        it(
          "strips a bare directive from an action without touching the icon",
          function()
            local action = {Type = "Action", type = "macro", macro = "#showtooltip\n/cast Sunfire"}
            assert.is_true(GSE.ApplyShowTooltipToAction(action))
            assert.are.equal("/cast Sunfire", action.macro)
            assert.is_nil(action.Icon)
          end
        )

        it(
          "promotes a resolvable directive argument to the block icon",
          function()
            GSE.GetShowTooltipIconInfo = function(argument)
              if argument == "Sunfire" then return {name = "Sunfire", iconID = 535045} end
            end

            local action = {Type = "Action", type = "macro", macro = "#showtooltip Sunfire\n/cast Sunfire"}
            assert.is_true(GSE.ApplyShowTooltipToAction(action))
            assert.are.equal("/cast Sunfire", action.macro)
            assert.are.equal(535045, action.Icon)
            assert.is_true(action.IconUserSelected)
          end
        )

        it(
          "keeps a directive whose argument this client cannot resolve",
          function()
            GSE.GetShowTooltipIconInfo = function() return nil end

            local action = {Type = "Action", type = "macro", macro = "#showtooltip \233\152\179\231\130\142\230\156\175\n/cast Sunfire"}
            assert.is_false(GSE.ApplyShowTooltipToAction(action))
            assert.are.equal("#showtooltip \233\152\179\231\130\142\230\156\175\n/cast Sunfire", action.macro)
            assert.is_nil(action.Icon)
          end
        )

        it(
          "never strips the directive from a managed in-game macro",
          function()
            GSE.GetShowTooltipIconInfo = function() return {name = "Sunfire", iconID = 535045} end

            local macroNode = {name = "MyMacro", macro = "#showtooltip Sunfire\n/cast Sunfire"}
            assert.is_false(GSE.ApplyShowTooltipToAction(macroNode))
            assert.are.equal("#showtooltip Sunfire\n/cast Sunfire", macroNode.macro)
          end
        )

        it(
          "walks an Actions array carrying the editor's path metatable without erroring",
          function()
            -- The editor sets Statics.TableMetadataFunction on Versions[n].Actions;
            -- its __index only understands table (path) keys, so a plain
            -- `actions.Type` lookup dies inside ipairs on the game's Lua 5.1.
            local actions = setmetatable({{Type = "Action", type = "macro", macro = "/cast Sunfire"}}, GSE.Static.TableMetadataFunction)
            assert.is_false(GSE.ApplyShowTooltipToAction(actions))
          end
        )

        it(
          "does not re-flag an icon the user picked themselves",
          function()
            GSE.GetShowTooltipIconInfo = function() return {name = "Sunfire", iconID = 535045} end

            local action = {
              Type = "Action",
              type = "macro",
              macro = "#showtooltip Sunfire\n/cast Sunfire",
              Icon = 999,
              IconUserSelected = true
            }
            assert.is_true(GSE.ApplyShowTooltipToAction(action))
            assert.are.equal("/cast Sunfire", action.macro)
            assert.are.equal(999, action.Icon)
          end
        )
      end
    )

    it(
      "tests that GSE.TrimWhiteSpace(str) removes preceeding whitespace",
      function()
        local teststr = [[

     test   ]]
        local expectedstr = [[test]]

        assert.are.same(expectedstr, GSE.TrimWhiteSpace(teststr))
      end
    )
  end
)
