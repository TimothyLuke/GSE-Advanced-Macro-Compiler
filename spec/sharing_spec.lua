---@diagnostic disable: undefined-global, duplicate-set-field
-- Sharing with another GSE player: the list a player offers, the request for
-- one element, and what is sent and filed.
--
-- Only GSE speaks this protocol, so it is keyed by id: an element is offered,
-- asked for and sent by its id with its label beside it. A chat link is the
-- one exception -- it is rebuilt from the text other players read, so it asks
-- by label. Protected content must never be listed or sent.
--
-- Run: busted spec/sharing_spec.lua   /   lua5.1 spec/run51.lua
describe("Sharing with other players", function()
  local sent, filed, queued
  -- A string codec: messages and stored variables are strings on the wire
  -- and at rest, and the dispatcher logs them as such.
  local blobs = {}
  local function blob(t)
    blobs[#blobs + 1] = t
    return "!GSE3!blob" .. #blobs
  end
  -- A sealed body. The Mod CAN read one -- that is how protected macros run --
  -- so this decodes too; what must stop it being shared is the seal itself.
  local function sealed(t)
    blobs[#blobs + 1] = t
    return "!GSE3!+blob" .. #blobs
  end

  setup(function()
    require("../spec/mockGSE")
    require("../GSE/API/Statics")
    require("../GSE/API/InitialOptions")
    require("../GSE/API/StringFunctions")
    require("../GSE/API/CharacterFunctions")
    require("../GSE/API/Storage")
    -- Serialisation.lua registers chat filters and a link hook as it loads,
    -- and brings the real codec; keep the mock's pass-through codec.
    local encode = GSE.EncodeMessage
    _G.ChatFrame_AddMessageEventFilter = function() end
    _G.hooksecurefunc = function() end
    GSE.RegisterComm = function() end
    require("../GSE/API/Serialisation")
    GSE.EncodeMessage = encode
    GSE.DecodeMessage = function(s)
      local t = type(s) == "string" and blobs[tonumber(s:match("^!GSE3!%+?blob(%d+)$") or "")]
      return t ~= nil, t
    end
    GSE.CharacterMacroBucketKey = function() return "Player-1-0001" end
    _G.GetUnitName = function() return "Me-Realm" end
    GSE.Print = function() end
    -- AceLocale answers a key with itself; the mock locale is empty.
    for _, k in ipairs({"'%s' cannot be shared — it is protected content.", "Cannot share protected content",
                        "Received Sequence ", " from ", " sent"}) do GSE.L[k] = k end
  end)

  before_each(function()
    sent, filed, queued = {}, {}, {}
    GSE.sendMessage = function(t, channel, target) sent[#sent + 1] = {t = t, channel = channel, target = target} end
    GSE.AddSequenceToCollection = function(name, seq, classid) filed[#filed + 1] = {name, seq, classid} end
    GSE.EnqueueOOC = function(v) queued[#queued + 1] = v end
    _G.GSEStore = nil
    GSE.LoadStore()
    GSE.Library = {}
    for c = 0, 13 do GSE.Library[c] = {} end

    local function sequence(classid, id, name, meta)
      GSE.PutSequenceBody(classid, id, name, "!GSE3!" .. name)
      meta = meta or {}
      meta.Name, meta.Help = name, "help for " .. name
      GSE.Library[classid][id] = {MetaData = meta, Versions = {{Actions = {}}}}
    end
    sequence(0, "id-global", "Everywhere")
    sequence(2, "id-alpha", "Alpha")
    sequence(2, "id-sealed", "Sealed", {noExport = true})
    GSE.Store("variable").Var = blob({funct = "function() return 1 end", comments = "a variable"})
    -- Protected two ways: sealed at rest, and readable but marked noExport.
    GSE.Store("variable").Packed = sealed({funct = "function() return 2 end", comments = "sealed"})
    GSE.Store("variable").NotMine = blob({funct = "x", MetaData = {noExport = true}})
    GSE.Store("variable").NotMineEither = blob({funct = "x", noExport = true})
    GSE.Store("macro").Pull = {name = "Pull", text = "/cast Charge", value = 7}
    GSE.Store("macro").Hidden = {name = "Hidden", text = "", GSEProtected = "!GSE3!+X"}
  end)

  local function receive(t)
    GSE:OnCommReceived("GSE", blob(t), "WHISPER", "Them-Realm")
  end

  describe("the offered list", function()
    it("offers global sequences, variables and macros, not only class sequences", function()
      local list = GSE.GetShareableSummary()
      assert.equals("Everywhere", list.sequence[0]["id-global"].Label, "global sequences are offered")
      assert.equals("Alpha", list.sequence[2]["id-alpha"].Label)
      assert.equals("help for Alpha", list.sequence[2]["id-alpha"].Help)
      local vars, macs = {}, {}
      for _, row in pairs(list.variable) do vars[row.Label] = true end
      for _, row in pairs(list.macro) do macs[row.Label] = true end
      assert.is_true(vars.Var, "variables are offered")
      assert.is_true(macs.Pull, "macros are offered")
    end)

    it("never offers protected content", function()
      local list = GSE.GetShareableSummary()
      assert.is_nil(list.sequence[2]["id-sealed"])
      for _, row in pairs(list.variable) do
        assert.are_not.equal("Packed", row.Label)
        assert.are_not.equal("NotMine", row.Label)
        assert.are_not.equal("NotMineEither", row.Label)
      end
      for _, row in pairs(list.macro) do assert.are_not.equal("Hidden", row.Label) end
    end)

    it("is sent when another player asks for it", function()
      receive({Command = "GSE_LISTELEMENTS"})
      assert.equals(1, #sent)
      assert.equals("GSE_ELEMENTLIST", sent[1].t.Command)
      assert.equals("Them-Realm", sent[1].target)
    end)
  end)

  describe("a request", function()
    it("is answered by id, with the label beside it", function()
      receive({Command = "GSE_REQUESTELEMENT", Kind = "sequence", ID = "id-alpha"})
      assert.equals(1, #sent)
      local t = sent[1].t
      assert.equals("GSE_TRANSMITELEMENT", t.Command)
      assert.equals("sequence", t.Kind)
      assert.equals("id-alpha", t.ID)
      assert.equals("Alpha", t.Label)
      assert.equals(2, t.ClassID)
      assert.equals("help for Alpha", t.Element.MetaData.Help)
    end)

    it("finds a sequence renamed since the list was sent: the id did not change", function()
      GSE.PutSequenceBody(2, "id-alpha", "Renamed", "!GSE3!Renamed")
      receive({Command = "GSE_REQUESTELEMENT", Kind = "sequence", ID = "id-alpha", Label = "Alpha"})
      assert.equals("Renamed", sent[1].t.Label)
    end)

    it("from a chat link, which only has the name, is answered by label", function()
      receive({Command = "GSE_REQUESTELEMENT", Kind = "sequence", Label = "Alpha", ClassID = 2})
      assert.equals("id-alpha", sent[1].t.ID)
    end)

    it("is answered for a variable and a macro", function()
      receive({Command = "GSE_REQUESTELEMENT", Kind = "variable", Label = "Var"})
      receive({Command = "GSE_REQUESTELEMENT", Kind = "macro", Label = "Pull"})
      assert.equals(2, #sent)
      assert.equals("a variable", sent[1].t.Element.MetaData.Notes, "sent in the current shape")
      assert.equals("/cast Charge", sent[2].t.Element.Versions[1].text, "sent in the current shape")
      assert.is_nil(sent[2].t.Element.value, "a macro slot is this player's alone")
    end)

    it("for protected content sends nothing", function()
      receive({Command = "GSE_REQUESTELEMENT", Kind = "sequence", ID = "id-sealed"})
      receive({Command = "GSE_REQUESTELEMENT", Kind = "variable", Label = "Packed"})
      receive({Command = "GSE_REQUESTELEMENT", Kind = "variable", Label = "NotMine"})
      receive({Command = "GSE_REQUESTELEMENT", Kind = "variable", Label = "NotMineEither"})
      receive({Command = "GSE_REQUESTELEMENT", Kind = "macro", Label = "Hidden"})
      assert.equals(0, #sent)
    end)

    it("for something this player does not have sends nothing", function()
      receive({Command = "GSE_REQUESTELEMENT", Kind = "sequence", ID = "id-nope", Label = "Nope"})
      assert.equals(0, #sent)
    end)
  end)

  describe("what arrives", function()
    it("is filed under its label, as an import", function()
      local seq = {MetaData = {Name = "Alpha"}, Versions = {{Actions = {}}}}
      receive({Command = "GSE_TRANSMITELEMENT", Kind = "sequence", ID = "their-id", Label = "Alpha",
               ClassID = 2, Element = seq})
      assert.equals(1, #filed)
      assert.equals("Alpha", filed[1][1])
      assert.equals(2, filed[1][3])
    end)

    it("files a variable and a macro", function()
      receive({Command = "GSE_TRANSMITELEMENT", Kind = "variable", Label = "V2", Element = {funct = "x"}})
      receive({Command = "GSE_TRANSMITELEMENT", Kind = "macro", Label = "M2", Element = {text = "/y"}})
      assert.equals("updatevariable", queued[1].action)
      assert.equals("V2", queued[1].name)
      assert.equals("importmacro", queued[2].action)
      assert.equals("M2", queued[2].node.name)
    end)

    it("from this player is ignored", function()
      GSE:OnCommReceived("GSE", blob({Command = "GSE_REQUESTELEMENT", Kind = "sequence", ID = "id-alpha"}),
        "WHISPER", "Me-Realm")
      assert.equals(0, #sent)
    end)
  end)
end)
