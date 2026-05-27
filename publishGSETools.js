const fs = require('fs');
const path = require('path');

const SCOPE_ID = '69c5b349738d1f112d148281';

async function main() {
  // File uploads still go through Qik (gse.tools/api/file/upload). The
  // release-record write moved to the Node API at api.gse.tools/publish/mod
  // (was Qik action 69c745e14106131aec21c3d7).
  const apiUrl = process.env.GSE_API_URL || 'https://gse.tools/api';
  const fileApiUrl = process.env.GSE_FILE_API_URL || apiUrl;
  const publishApiUrl = process.env.GSE_PUBLISH_API_URL || 'https://api.gse.tools';
  const token = process.env.GSE_ACTION_TOKEN;
  const isTag = (process.env.GITHUB_REF || '').startsWith('refs/tags/');

  if (!token) {
    console.log('[publish] GSE_ACTION_TOKEN not set, skipping');
    return;
  }

  const zips = fs.readdirSync('.').filter(f => f.startsWith('GSE-') && f.endsWith('.zip'));
  if (!zips.length) {
    console.log('[publish] No GSE-*.zip files found, skipping');
    return;
  }

  for (const zip of zips) {
    const fullVersion = path.basename(zip, '.zip').replace(/^GSE-/, '');
    const isPatronBuild = fullVersion.includes('-PatronBuild');
    const channel = isTag ? 'release' : 'alpha';

    console.log(`[publish] ${zip} (version: ${fullVersion}, channel: ${channel})`);

    // Step 1: Upload zip to Qik file storage
    const fileBuffer = fs.readFileSync(zip);
    const metadata = JSON.stringify({
      title: zip,
      meta: { type: 'file', security: 'public', scopes: [SCOPE_ID] },
    });
    const formData = new FormData();
    formData.append('json', metadata);
    formData.append('file', new Blob([fileBuffer]), zip);

    const uploadUrl = `${fileApiUrl}/file/upload`;
    console.log(`[publish] Uploading to ${uploadUrl} (${(fileBuffer.length / 1024).toFixed(0)} KB)`);
    const uploadRes = await fetch(
      uploadUrl,
      {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData,
      },
    );

    if (!uploadRes.ok) {
      const errText = await uploadRes.text();
      console.log(`[publish] File upload HTTP ${uploadRes.status}: ${errText.slice(0, 300)}`);
      continue;
    }

    const uploadData = await uploadRes.json();

    if (!uploadData._id) {
      console.log(`[publish] File upload failed:`, JSON.stringify(uploadData));
      continue;
    }
    console.log(`[publish] Uploaded ${zip} -> ${uploadData._id}`);

    // Step 2: Create release record via Node API
    const pubRes = await fetch(
      `${publishApiUrl}/publish/mod`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fileId: uploadData._id,
          version: fullVersion,
          channel,
          isPatronBuild,
        }),
      },
    );

    if (!pubRes.ok) {
      const errText = await pubRes.text();
      console.log(`[publish] Action HTTP ${pubRes.status}: ${errText.slice(0, 300)}`);
      continue;
    }

    const pubData = await pubRes.json();

    if (pubData.success) {
      console.log(`[publish] Published ${fullVersion} (${channel})`);
      if (pubData.cleanup) {
        const { scanned = 0, targeted = 0, deleted = [], failed = [], latestBase, previousBase } = pubData.cleanup;
        console.log(`[publish] Cleanup: scanned ${scanned}, archived ${deleted.length}/${targeted} (kept latest=${latestBase ?? '-'}, previous=${previousBase ?? '-'})`);
        if (failed.length) console.log(`[publish] Cleanup failures:`, failed.slice(0, 5));
      } else if (pubData.cleanupError) {
        console.log(`[publish] Cleanup failed (non-fatal): ${pubData.cleanupError}`);
      }
    } else {
      console.log(`[publish] Publish failed:`, pubData.error || JSON.stringify(pubData));
    }
  }
}

main().catch(e => {
  console.error('[publish] Fatal:', e);
  process.exit(1);
});
