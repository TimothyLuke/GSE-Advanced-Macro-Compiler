# GSE

## [3.3.19-18-g657a37a](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/tree/657a37aa7be5f97133d15133b1ab963fa5471e1f) (2026-06-01)
[Full Changelog](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/compare/3.3.19...657a37aa7be5f97133d15133b1ab963fa5471e1f) [Previous Releases](https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler/releases)

- #1914 More code cleanup  
- #1914 Post luacheck build errors  
- Merge pull request #1916 from TimothyLuke/dependabot/npm\_and\_yarn/ws-8.21.0  
    Bump ws from 8.18.3 to 8.21.0  
- #1914 code cleanup  
- #1914 Luacheck  
- #1914 Luacheck update  
- #1914 Second Cut removing AceGUI Dependency  
- Bump ws from 8.18.3 to 8.21.0  
    Bumps [ws](https://github.com/websockets/ws) from 8.18.3 to 8.21.0.  
    - [Release notes](https://github.com/websockets/ws/releases)  
    - [Commits](https://github.com/websockets/ws/compare/8.18.3...8.21.0)  
    ---  
    updated-dependencies:  
    - dependency-name: ws  
      dependency-version: 8.21.0  
      dependency-type: indirect  
    ...  
    Signed-off-by: dependabot[bot] <support@github.com>  
- patron publish: point embed at GSE\_Menu\_Logo.png (the wide finish)  
    The Discord build notification was still resolving to GSE\_Logo\_Dark\_512.png  
    — that's the square crop now used for the in-game app icon + the  
    Companion app icon — instead of the wide menu finish. The thumbnail  
    slot in a Discord embed reads better with the wide artwork; same for  
    the bot avatar circle (the wider crop centres the wrench head + GSE  
    letters away from the round crop edge).  
    GitHub raw URL pattern unchanged so Discord's media proxy stays happy.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- logo: refresh menu + dark icons to the new finishes  
    GSE\_Menu\_Logo gets the wide wrench framing (image #10) at 250×250 —  
    fills the top-bar slot in the in-game menu without cropping. The  
    dark icon (GSE\_Logo\_Dark\_512.png used by the welcome screen, LDB  
    minimap, editor min-widget, import-dialog header, and tracker  
    identity check) gets the square crop (image #12) at 512×512 — the  
    wrench now wraps the GSE letters fully so the icon reads at small  
    sizes too. No code paths changed; same filenames, same load  
    sites.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- Update Icon  
- #1915 Allow a modifier to be set to pause a sequence  
- patreon publish: use direct PNG URL for embed thumbnail  
    The previous gse.tools URL 302-redirected to a signed S3 url, which  
    Discord's media proxy didn't render as an embed thumbnail (though it  
    accepted it for the webhook avatar). Switch to the GitHub raw URL of  
    the committed PNG — direct image/png response, no redirects — same  
    shape forgecdn used for the original logo. Rolls back the attachment  
    plumbing; setThumbnail(url) is the right tool, the URL was wrong.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- patreon publish: attach logo file so the embed thumbnail renders  
    The previous attempt set the embed thumbnail to a gse.tools URL that  
    302-redirects to a signed S3 URL. Discord's media proxy accepts the  
    redirect for the webhook avatar (visible bot pic = new wrench, ✓) but  
    refuses it for embed thumbnails (right-side thumbnail = missing).  
    Author icon was ambiguous.  
    Switch the embed author icon + thumbnail to attachment://gse-logo.png  
    and attach GSE\_GUI/Assets/GSE\_Logo\_Dark\_512.png alongside the zip.  
    Discord renders attached images directly with no proxy fetch, so the  
    thumbnail comes back. Bot avatarURL keeps the gse.tools URL since the  
    webhook avatar fetch works fine through that path.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- patreon publish: new GSE wrench logo in Discord embed + bot avatar  
    Swap the embed author iconURL + thumbnail away from the stale forgecdn  
    gse2-logo-dark-2x.png onto a single LOGO\_URL constant pointing at the  
    new wrench logo hosted via Qik file storage at gse.tools (file id  
    6a17c04d699ec384f2773a97). Same id serves the website's header/hero,  
    so future re-brands swap the file behind the id and propagate across  
    both surfaces.  
    Also override the webhook send with username + avatarURL so the bot's  
    own profile picture matches the embed, instead of inheriting whatever  
    avatar the webhook was originally created with in the Discord server  
    settings (still the old hex logo there).  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- logo: new GSE wrench logo across in-game surfaces  
    Replaces the old GSE2 wordmark with the new GSE wrench logo wherever  
    the addon shows its brand at runtime: the welcome screen background,  
    the LDB minimap icon, the editor min-widget icon, the import-dialog  
    header, and the tracker-button identity check.  
    GSE\_Logo\_Dark\_512.blp → GSE\_Logo\_Dark\_512.png. WoW reads PNG fine  
    from addon assets, so swapping the file extension + updating the  
    Statics path in GSE/API/Statics.lua is sufficient. Deleted the old  
    BLP so the TOC IconTexture base-name lookup picks the new PNG  
    unambiguously. GSE\_Menu\_Logo.png overwritten at the same 250×250  
    the runtime already expected.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- publish: surface server-side cleanup summary  
    The /publish/mod endpoint now applies the retention rule (latest release  
    + previous release + alphas on top of latest) on every publish — see the  
    GSE-Tools-API commit. Print the cleanup summary line including the  
    latest/previous baseVersion the server picked, so CI logs show what was  
    archived.  
    Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>  
- #1913 gate sequecne recompilation behind checking for isEncounter  
