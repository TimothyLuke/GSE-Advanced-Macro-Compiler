const fs = require('fs');
const path = require('path');

const SCOPE_ID = '69c5b349738d1f112d148281';
const PUBLISH_ACTION_ID = '69c745e14106131aec21c3d7';

async function main() {
  const apiUrl = process.env.GSE_API_URL || 'https://gse.tools/api';
  const fileApiUrl = process.env.GSE_FILE_API_URL || 'https://api.qik.dev';
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

    const uploadRes = await fetch(
      `${fileApiUrl}/file/upload`,
      {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData,
      },
    );
    const uploadData = await uploadRes.json();

    if (!uploadData._id) {
      console.log(`[publish] File upload failed:`, JSON.stringify(uploadData));
      continue;
    }
    console.log(`[publish] Uploaded ${zip} -> ${uploadData._id}`);

    // Step 2: Create release record via publish action
    const pubRes = await fetch(
      `${apiUrl}/actions/${PUBLISH_ACTION_ID}`,
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
    const pubData = await pubRes.json();

    if (pubData.success) {
      console.log(`[publish] Published ${fullVersion} (${channel})`);
    } else {
      console.log(`[publish] Publish failed:`, pubData.error || JSON.stringify(pubData));
    }
  }
}

main().catch(e => {
  console.error('[publish] Fatal:', e);
  process.exit(1);
});
