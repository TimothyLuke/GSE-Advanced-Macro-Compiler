---@diagnostic disable: undefined-global
-- AceEvent keeps ONE handler per message per object. Several modules
-- registered GSE_SEQUENCE_UPDATED (and GSE_MODS_VISIBLE) on the GSE object
-- itself, so each replaced the last and only whichever loaded last ran -- the
-- QoL checksum stamp, the Tracker refresh and the editor's reload could not all
-- happen. Each module now listens through an object of its own; this keeps a
-- registration on GSE from coming back.
--
-- Reads the shipped files as text, so line endings are normalised (CLAUDE.md).
local FILES = {
  "GSE/API/Events.lua", "GSE/API/Storage.lua", "GSE/API/Init.lua",
  "GSE_GUI/Editor.lua", "GSE_GUI/Editor_Metadata.lua", "GSE_GUI/Editor_Keybind.lua",
  "GSE_GUI/Editor_Tree.lua", "GSE_GUI/DebugWindow.lua",
  "GSE_Utils/Tracker.lua", "GSE_Utils/Events.lua", "GSE_Utils/Utils.lua",
  "GSE_QoL/QoL.lua", "GSE_LDB/LDBProvider.lua", "GSE_Options/Options.lua",
}

local function readSource(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local src = fh:read("*a")
  fh:close()
  return (src:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

describe("message listeners", function()
  it("no module registers a message on the GSE object itself", function()
    local found = {}
    for _, path in ipairs(FILES) do
      local src = readSource(path)
      if src then
        local n = 0
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
          n = n + 1
          if not line:match("^%s*%-%-") and line:find("GSE:RegisterMessage(", 1, true) then
            found[#found + 1] = path .. ":" .. n
          end
        end
      end
    end
    assert.equals(0, #found, "GSE:RegisterMessage at " .. table.concat(found, ", "))
  end)
end)
