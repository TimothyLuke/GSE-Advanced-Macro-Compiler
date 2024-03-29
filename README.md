# GSE: Advanced Macro Compiler
GSE is an advanced macro compiler for WoW.  Unlike WoW's macros, it doesn't get hung up on the success or failure of the current actions.  It just sends the commands to WoW and moves on to the next line.  This allows for creative approaches to overcome some of the limitations of WoW's macro system.  GSE cant break the rules, but it can make them more manageable. Every command available to WoW macros is available to GSE.

GSE uses the concept of a Block of commands.  For example you may want to target an enemy if you are not targeting one, cast a spell and use a trinket.  In GSE you would arrange these as a stack and at the click send this stack to WoW to execute.  WoW will then work from the top of the stack down and attempt to execute each line.  As GSE follows all Blizzards rules it can only try One GCD ability in the stack but as it moves on to the next block on the next click you can try different things in case of an ability being on cooldown etc.

GSE started as a fork of Semlar's GnomeSequencer but has since undergone multiple rewrites and there now remains nothing of the original code.
 
# Features
- Loops
- In-game Editor
- Import Macros from the www.wowlazymacros.com website
- Syntax Highlighting
- Macro Variables and WoW API incorporation
- Share Macro In-game
- Macro Debugger
- Macro Recorder
- Localisation support
- Enable/Disable various options/annoyance fixes (use trinkets, error sounds, require target, etc.)
- Execution pauses
- And more...

# More Information
- GSE Wiki: https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/wiki
- API Docimentation: Check out the project site at https://timothyluke.github.io/GSE-Advanced-Macro-Compiler/ for API documentation.
