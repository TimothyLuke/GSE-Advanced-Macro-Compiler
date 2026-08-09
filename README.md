# GSE: Advanced Macro Compiler
GSE is an advanced macro compiler for WoW.  Unlike WoW's macros, it doesn't get hung up on the success or failure of the current actions.  It just sends the commands to WoW and moves on to the next line.  This allows for creative approaches to overcome some of the limitations of WoW's macro system.  GSE cant break the rules, but it can make them more manageable. Every command available to WoW macros is available to GSE.

GSE uses the concept of a Block of commands.  For example you may want to target an enemy if you are not targeting one, cast a spell and use a trinket.  In GSE, you would arrange these as a stack and, at the click, send this stack to WoW to execute.  WoW will then work from the top of the stack down and attempt to execute each line.  As GSE follows all Blizzard's rules, it can only try One GCD ability in the stack, but as it moves on to the next block on the next click, you can try different things in case an ability is on cooldown, etc.

GSE started as a fork of Semlar's GnomeSequencer but has since undergone multiple rewrites and there now remains nothing of the original code.
 
# Features
- Loops
- In-game Editor
- Syntax Highlighting
- Macro Variables and WoW API incorporation
- Share Macro In-game
- Macro Debugger
- Macro Recorder
- Localisation support
- And more...

# Popular Destinations
- GSE Official - For issues with GSE - https://discord.com/invite/yUS9R4ZXZA
- GSE Tools - https://gse.tools 
- GSE United - For Sequences and help creating in GSE - https://discord.gg/gseunited
- GSE United Websites - For Sequences and help creating in GSE - https://gseunited.com
  
# More Information
- GSE Wiki: https://gse.tools/help
