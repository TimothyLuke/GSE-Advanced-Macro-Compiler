// Push the enUS phrase list to CurseForge before the packager runs.
//
// CurseForge holds the master phrase list that translators work against. It
// only learns about a new or changed string when someone uploads it, so a
// release could ship strings the translators had never been offered. This runs
// as a pre-build step so every packaged build is preceded by the phrase list
// that produced it.
//
// Source of truth is GSE/Localization/ModL_enUS.lua, parsed rather than
// regexed: 36 of its entries wrap across lines, one key carries an escaped
// quote, and several values contain \n. A line-based match mangles all three.
//
// AceLocale writes `L["Phrase"] = true` to mean "the value IS the key".
// CurseForge's TableAdditions format wants a real value, so `true` is expanded
// to the key itself on the way out.
const fs = require('fs');

const LOCALE_FILE = 'GSE/Localization/ModL_enUS.lua';
const TOC_FILE = 'GSE/GSE.toc';
const API = 'https://wow.curseforge.com/api';

// ── Lua literal parsing ─────────────────────────────────────────────────────
const ESCAPES = { n: '\n', r: '\r', t: '\t', a: '\x07', b: '\b', f: '\f', v: '\v', '\\': '\\', '"': '"', "'": "'" };

// The file is read as latin1 so one JS char == one byte, and parsed results are
// decoded back to UTF-8 at the end. Lua's \ddd escapes are BYTES: an em dash is
// written \226\128\148, three escapes that only mean "—" once recombined.
// Decoding per-escape with fromCharCode produces "â" plus two strays instead.
function decodeBytes(s) {
  return Buffer.from(s, 'latin1').toString('utf8');
}

function skipSpace(src, i) {
  while (i < src.length) {
    if (/\s/.test(src[i])) { i++; continue; }
    if (src.startsWith('--', i)) {           // comment to end of line
      const nl = src.indexOf('\n', i);
      i = nl < 0 ? src.length : nl + 1;
      continue;
    }
    break;
  }
  return i;
}

// Reads a quoted or [[long]] Lua string starting at i. Returns {value, end} or null.
function readLuaString(src, i) {
  const q = src[i];
  if (q === '"' || q === "'") {
    let out = '';
    let p = i + 1;
    while (p < src.length) {
      const c = src[p];
      if (c === '\\') {
        const e = src[p + 1];
        if (e === 'x') { out += String.fromCharCode(parseInt(src.substr(p + 2, 2), 16)); p += 4; continue; }
        if (/[0-9]/.test(e)) {                       // \ddd — a single byte
          const m = /^[0-9]{1,3}/.exec(src.slice(p + 1))[0];
          out += String.fromCharCode(parseInt(m, 10) & 0xff); p += 1 + m.length; continue;
        }
        if (e === '\r' || e === '\n') {              // escaped line break
          p += 2;
          if (e === '\r' && src[p] === '\n') p++;     // the file is CRLF
          out += '\n';
          continue;
        }
        out += ESCAPES[e] !== undefined ? ESCAPES[e] : e;
        p += 2; continue;
      }
      if (c === q) return { value: decodeBytes(out), end: p + 1 };
      out += c; p++;
    }
    return null;                                      // unterminated
  }
  const long = /^\[(=*)\[/.exec(src.slice(i));
  if (long) {
    const close = ']' + long[1] + ']';
    const start = i + long[0].length;
    const end = src.indexOf(close, start);
    if (end < 0) return null;
    // A long string starting with a newline drops it, per Lua.
    let value = src.slice(start, end);
    if (value.startsWith('\r\n')) value = value.slice(2);
    else if (value.startsWith('\n')) value = value.slice(1);
    // Lua's lexer folds any end-of-line sequence inside a long string to a
    // single newline. Without this the CRLF checkout leaks a stray CR into
    // every line of the multi-line phrases.
    value = value.replace(/\r\n?/g, '\n');
    return { value: decodeBytes(value), end: end + close.length };
  }
  return null;
}

// Walks `L[<string>] = <string|true>` statements.
function parseAceLocale(src) {
  const entries = [];
  let i = 0;
  for (;;) {
    const at = src.indexOf('L[', i);
    if (at < 0) break;
    // Must be a statement, not a substring of another identifier (e.g. VAL[).
    const prev = at > 0 ? src[at - 1] : '\n';
    if (/[A-Za-z0-9_.]/.test(prev)) { i = at + 2; continue; }

    let p = skipSpace(src, at + 2);
    const key = readLuaString(src, p);
    if (!key) { i = at + 2; continue; }
    p = skipSpace(src, key.end);
    if (src[p] !== ']') { i = at + 2; continue; }
    p = skipSpace(src, p + 1);
    if (src[p] !== '=') { i = at + 2; continue; }
    p = skipSpace(src, p + 1);

    if (src.startsWith('true', p)) {
      entries.push([key.value, key.value]);           // AceLocale shorthand
      i = p + 4;
      continue;
    }
    const val = readLuaString(src, p);
    if (!val) { i = at + 2; continue; }
    entries.push([key.value, val.value]);
    i = val.end;
  }
  return entries;
}

function luaQuote(s) {
  return '"' + String(s)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t') + '"';
}

function projectIdFromToc() {
  const toc = fs.readFileSync(TOC_FILE, 'utf8');
  const m = /##\s*X-Curse-Project-ID:\s*(\d+)/i.exec(toc);
  return m ? m[1] : null;
}

async function main() {
  // --dry-run parses and builds the payload, prints what would be sent, and
  // stops. Lets the phrase list be checked without a key and without touching
  // the live project.
  const dryRun = process.argv.includes('--dry-run');
  const token = process.env.CF_API_KEY;
  if (!token && !dryRun) {
    console.log('[locale] CF_API_KEY not set, skipping');
    return;
  }
  const projectId = process.env.CF_PROJECT_ID || projectIdFromToc();
  if (!projectId) {
    console.error(`[locale] no X-Curse-Project-ID in ${TOC_FILE} and CF_PROJECT_ID unset`);
    process.exitCode = 1;
    return;
  }

  const src = fs.readFileSync(LOCALE_FILE, 'latin1');   // byte-wise; see decodeBytes
  const entries = parseAceLocale(src);
  if (!entries.length) {
    console.error(`[locale] parsed 0 phrases from ${LOCALE_FILE} — refusing to upload an empty list`);
    process.exitCode = 1;
    return;
  }

  const seen = new Map();
  for (const [k, v] of entries) seen.set(k, v);       // last wins, as Lua would

  // Sanity floor, and it earns its keep because the upload deletes phrases the
  // payload omits. Count `L[` statement starts with a crude scan that shares no
  // logic with the parser above: if the parser ever regresses — a quoting style
  // it does not understand, a refactor of the locale file — the two numbers
  // diverge and we stop, rather than quietly telling CurseForge that the addon
  // has three phrases and to delete the rest.
  const rawStarts = (src.match(/(^|[^A-Za-z0-9_.])L\[/g) || []).length;
  if (rawStarts && seen.size < rawStarts * 0.5) {
    console.error(`[locale] parsed only ${seen.size} phrases from ~${rawStarts} candidates in `
      + `${LOCALE_FILE} — refusing to upload a list this incomplete`);
    process.exitCode = 1;
    return;
  }
  const blob = [...seen.entries()].map(([k, v]) => `L[${luaQuote(k)}] = ${luaQuote(v)}`).join('\n');

  // DeletePhrase: the addon's enUS file is the master list, so a phrase that is
  // no longer in it should not linger on CurseForge collecting translations for
  // a string nothing displays. That makes this upload DESTRUCTIVE — anything
  // absent from `blob` is removed over there, translations included — which is
  // why the sanity check above exists. Override per-run with
  // CF_LOCALE_MISSING_HANDLING=DoNothing.
  const missingHandling = process.env.CF_LOCALE_MISSING_HANDLING || 'DeletePhrase';

  const body = JSON.stringify({
    metadata: {
      language: 'enUS',
      formatType: 'TableAdditions',
      'missing-phrase-handling': missingHandling,
    },
    localizations: blob,
  });

  if (dryRun) {
    console.log(`[locale] DRY RUN — would POST ${blob.length} bytes to project ${projectId}`);
    console.log('[locale] metadata:', JSON.parse(body).metadata);
    console.log(`[locale] ${seen.size} phrases; first three lines:`);
    for (const line of blob.split('\n').slice(0, 3)) console.log('   ' + line.slice(0, 120));
    return;
  }

  console.log(`[locale] uploading ${seen.size} enUS phrases to project ${projectId} (${missingHandling})`);
  const res = await fetch(`${API}/projects/${projectId}/localization/import`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Api-Token': token },
    body,
  });
  const text = await res.text().catch(() => '');
  if (!res.ok) {
    console.error(`[locale] upload failed: HTTP ${res.status} ${text.slice(0, 300)}`);
    process.exitCode = 1;
    return;
  }
  console.log(`[locale] uploaded ${seen.size} phrases${text ? ' — ' + text.slice(0, 200) : ''}`);
}

if (require.main === module) main();
module.exports = { parseAceLocale, luaQuote };
