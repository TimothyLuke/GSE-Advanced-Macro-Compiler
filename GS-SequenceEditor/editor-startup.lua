

GSEditorOptions = {}
GSEditorOptions.KEYWORD = "|cff88bbdd"
GSEditorOptions.UNKNOWN = "|cffff6666"
GSEditorOptions.CONCAT = "|cffcc7777"
GSEditorOptions.NUMBER = "|cffffaa00"
GSEditorOptions.STRING = "|cff888888"
GSEditorOptions.COMMENT = "|cff55cc55"
GSEditorOptions.INDENT = "|cffccaa88"
GSEditorOptions.EQUALS = "|cffccddee"
GSEditorOptions.STANDARDFUNCS = "|cff55ddcc"
GSEditorOptions.WOWSHORTCUTS = "|cffddaaff"

SyntaxColors = {};
--- Assigns a color to multiple tokens at once.
local function Color ( Code, ... )
	for Index = 1, select( "#", ... ) do
		SyntaxColors[ select( Index, ... ) ] = Code;
	end
end
Color( GSEditorOptions.KEYWORD, IndentationLib.Tokens.KEYWORD ); -- Reserved words
Color( GSEditorOptions.UNKNOWN, IndentationLib.Tokens.UNKNOWN );
Color( GSEditorOptions.CONCAT, IndentationLib.Tokens.CONCAT, IndentationLib.Tokens.VARARG,
	IndentationLib.Tokens.ASSIGNMENT, IndentationLib.Tokens.PERIOD, IndentationLib.Tokens.COMMA, IndentationLib.Tokens.SEMICOLON, IndentationLib.Tokens.COLON, IndentationLib.Tokens.SIZE );
Color( GSEditorOptions.NUMBER, IndentationLib.Tokens.NUMBER );
Color( GSEditorOptions.STRING, IndentationLib.Tokens.STRING, IndentationLib.Tokens.STRING_LONG );
Color( GSEditorOptions.COMMENT, IndentationLib.Tokens.COMMENT_SHORT, IndentationLib.Tokens.COMMENT_LONG );
Color( GSEditorOptions.INDENT, IndentationLib.Tokens.LEFTCURLY, IndentationLib.Tokens.RIGHTCURLY,
	IndentationLib.Tokens.LEFTBRACKET, IndentationLib.Tokens.RIGHTBRACKET,
	IndentationLib.Tokens.LEFTPAREN, IndentationLib.Tokens.RIGHTPAREN,
	IndentationLib.Tokens.ADD, IndentationLib.Tokens.SUBTRACT, IndentationLib.Tokens.MULTIPLY, IndentationLib.Tokens.DIVIDE, IndentationLib.Tokens.POWER, IndentationLib.Tokens.MODULUS );
Color( GSEditorOptions.EQUAL, IndentationLib.Tokens.EQUALITY, IndentationLib.Tokens.NOTEQUAL, IndentationLib.Tokens.LT, IndentationLib.Tokens.LTE, IndentationLib.Tokens.GT, IndentationLib.Tokens.GTE );
Color( GSEditorOptions.STANDARDFUNCS, -- Minimal standard Lua functions
	"assert", "error", "ipairs", "next", "pairs", "pcall", "print", "select",
	"tonumber", "tostring", "type", "unpack",
	-- Libraries
	"bit", "coroutine", "math", "string", "table" );
Color( GSEditorOptions.WOWSHORTCUTS, -- Some of WoW's aliases for standard Lua functions
	-- math
	"abs", "ceil", "floor", "max", "min",
	-- string
	"format", "gsub", "strbyte", "strchar", "strconcat", "strfind", "strjoin",
	"strlower", "strmatch", "strrep", "strrev", "strsplit", "strsub", "strtrim",
	"strupper", "tostringall",
	-- table
	"sort", "tinsert", "tremove", "wipe" );
