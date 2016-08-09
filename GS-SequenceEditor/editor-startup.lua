

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
-- --- Assigns a color to multiple tokens at once.
-- local function Color ( Code, ... )
-- 	for Index = 1, select( "#", ... ) do
-- 		SyntaxColors[ select( Index, ... ) ] = Code;
-- 	end
-- end
-- SyntaxColors[0] = "|r"
--
-- Color( GSEditorOptions.KEYWORD, IndentationLib.tokens.TOKEN_KEYWORD ); -- Reserved words
-- Color( GSEditorOptions.UNKNOWN, IndentationLib.tokens.TOKEN_UNKNOWN );
-- Color( GSEditorOptions.CONCAT, IndentationLib.tokens.TOKEN_ASSIGNMENT, IndentationLib.tokens.TOKEN_PERIOD, IndentationLib.tokens.TOKEN_COMMA, IndentationLib.tokens.TOKEN_SEMICOLON, IndentationLib.tokens.TOKEN_COLON);
-- Color( GSEditorOptions.NUMBER, IndentationLib.tokens.TOKEN_NUMBER );
-- Color( GSEditorOptions.STRING, IndentationLib.tokens.TOKEN_STRING);
-- Color( GSEditorOptions.COMMENT, IndentationLib.tokens.TOKEN_COMMENT_SHORT, IndentationLib.tokens.TOKEN_COMMENT_LONG );
-- Color( GSEditorOptions.INDENT, IndentationLib.tokens.TOKEN_LEFTBRACKET, IndentationLib.tokens.TOKEN_RIGHTBRACKET,
-- 	IndentationLib.tokens.TOKEN_LEFTPAREN, IndentationLib.tokens.TOKEN_RIGHTPAREN );
-- Color( GSEditorOptions.EQUAL, IndentationLib.tokens.TOKEN_EQUALITY, IndentationLib.tokens.TOKEN_NOTEQUAL, IndentationLib.tokens.TOKEN_LT, IndentationLib.tokens.TOKEN_LTE, IndentationLib.tokens.TOKEN_GT, IndentationLib.tokens.TOKEN_GTE );
-- Color( GSEditorOptions.STANDARDFUNCS, -- Minimal standard Lua functions
-- 	"assert", "error", "ipairs", "next", "pairs", "pcall", "print", "select",
-- 	"tonumber", "tostring", "type", "unpack",
-- 	-- Libraries
-- 	"bit", "coroutine", "math", "string", "table" );
-- Color( GSEditorOptions.WOWSHORTCUTS, -- Some of WoW's aliases for standard Lua functions
-- 	-- math
-- 	"abs", "ceil", "floor", "max", "min",
-- 	-- string
-- 	"format", "gsub", "strbyte", "strchar", "strconcat", "strfind", "strjoin",
-- 	"strlower", "strmatch", "strrep", "strrev", "strsplit", "strsub", "strtrim",
-- 	"strupper", "tostringall",
-- 	-- table
-- 	"sort", "tinsert", "tremove", "wipe" );
--

	local SyntaxColors = {}
	SyntaxColors[IndentationLib.tokens.TOKEN_SPECIAL] = GSEditorOptions.STANDARDFUNCS
	SyntaxColors[IndentationLib.tokens.TOKEN_KEYWORD] = GSEditorOptions.KEYWORD
	SyntaxColors[IndentationLib.tokens.TOKEN_COMMENT_SHORT] = GSEditorOptions.COMMENT
	SyntaxColors[IndentationLib.tokens.TOKEN_COMMENT_LONG] = GSEditorOptions.COMMENT
	SyntaxColors[IndentationLib.tokens.TOKEN_NUMBER] = GSEditorOptions.NUMBER
	SyntaxColors[IndentationLib.tokens.TOKEN_STRING] = GSEditorOptions.STRING

	local tableColor = GSEditorOptions.INDENT
	SyntaxColors["..."] = tableColor
	SyntaxColors["{"] = tableColor
	SyntaxColors["}"] = tableColor
	SyntaxColors["["] = tableColor
	SyntaxColors["]"] = tableColor

	local arithmeticColor = GSEditorOptions.CONCAT
	SyntaxColors["+"] = arithmeticColor
	SyntaxColors["-"] = arithmeticColor
	SyntaxColors["/"] = arithmeticColor
	SyntaxColors["*"] = arithmeticColor
	SyntaxColors[".."] = arithmeticColor

	local logicColor1 = GSEditorOptions.EQUAL
	SyntaxColors["=="] = logicColor1
	SyntaxColors["<"] = logicColor1
	SyntaxColors["<="] = logicColor1
	SyntaxColors[">"] = logicColor1
	SyntaxColors[">="] = logicColor1
	SyntaxColors["~="] = logicColor1

	local logicColor2 = GSEditorOptions.EQUAL
	SyntaxColors["and"] = logicColor2
	SyntaxColors["or"] = logicColor2
	SyntaxColors["not"] = logicColor2

	SyntaxColors[0] = "|r"
