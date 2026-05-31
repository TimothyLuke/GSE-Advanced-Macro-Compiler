GSE PatronBuild — Release Package
=================================

Contents
--------

  GSE-3_3_19-10-g7e2a200-PatronBuild.zip
      The built addon (six sub-addon folders: GSE, GSE_GUI, GSE_LDB,
      GSE_Options, GSE_QoL, GSE_Utils, plus .luacheckrc).
      To use in WoW: unzip and place the GSE* folders in Interface/AddOns.

  GSE_remove-ace3_changes.diff
      Full first-party unified diff. Baseline (a/) = the prior build that
      still bundled Ace3; proposed (b/) = Ace3 removed + native UI +
      release-prep. Vendored Ace3 libraries and binary assets are catalogued
      in CHANGE_SUMMARY.md rather than dumped into the patch. Review file.

  CHANGE_SUMMARY.md
      Comparison basis, full manifest (files removed / added / modified),
      and this session's specific release-prep edits broken out.

  PULL_REQUEST.md
      Paste-ready pull-request title ("#1914 Remove Ace3 GUI dependency")
      and body, targeting:
      https://github.com/TimothyLuke/GSE-Advanced-Macro-Compiler  (branch: master)

  OUTSTANDING_ITEMS.md
      In-game checks still needed (fresh install, upgrade, native-UI smoke
      test, Tracker frames), a known non-regression note (C_EncodingUtil),
      and deferred/optional items.

Static checks at packaging time
-------------------------------
  - All 127 first-party Lua files compile (luac5.1 -p).
  - luacheck: 15 warnings / 0 errors.
