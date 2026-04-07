/* eslint-disable no-console */
const fs = require('fs');
const os = require('os');
const path = require('path');

const SOURCE_COLLECTION = 'users';
const CITIZENS_COLLECTION = 'citizens';
const OFFICERS_COLLECTION = 'officers';
const DEFAULT_PAGE_SIZE = 250;
const FIREBASE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function parseArgs(argv) {
  const args = argv.slice(2);
  const flags = new Set(args.filter((arg) => arg.startsWith('--')));
  const pageSizeArg = args.find((arg) => arg.startsWith('--page-size='));
  const parsedPageSize = pageSizeArg ? Number(pageSizeArg.split('=')[1]) : NaN;

  return {
    dryRun: flags.has('--dry-run'),
    keepSource: flags.has('--keep-source'),
    pageSize:
      Number.isInteger(parsedPageSize) && parsedPageSize > 0
        ? parsedPageSize
        : DEFAULT_PAGE_SIZE,
  };
}

function resolveProjectId() {
  const envProjectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID;

  if (envProjectId && envProjectId.trim()) {
    return envProjectId.trim();
  }

  const firebaseConfigPath = path.resolve(__dirname, '..', 'firebase.json');
  if (fs.existsSync(firebaseConfigPath)) {
    const firebaseConfig = JSON.parse(fs.readFileSync(firebaseConfigPath, 'utf8'));
    const platformConfig = firebaseConfig.flutter?.platforms;
    const candidates = [
      platformConfig?.android?.default?.projectId,
      platformConfig?.ios?.default?.projectId,
      platformConfig?.dart?.['lib/firebase_options.dart']?.projectId,
    ];

    for (const candidate of candidates) {
      if (candidate && String(candidate).trim()) {
        return String(candidate).trim();
      }
    }
  }

  throw new Error('Unable to detect a Firebase project id.');
}

async function resolveAccessToken() {
  const envToken =
    process.env.FIREBASE_ACCESS_TOKEN ||
    process.env.GOOGLE_OAUTH_ACCESS_TOKEN ||
    process.env.GOOGLE_ACCESS_TOKEN;

  if (envToken && envToken.trim()) {
    return envToken.trim();
  }

  const tokenFilePath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json'
  );

  if (fs.existsSync(tokenFilePath)) {
    const tokenConfig = JSON.parse(fs.readFileSync(tokenFilePath, 'utf8'));
    const refreshToken = tokenConfig.tokens?.refresh_token;
    if (refreshToken && String(refreshToken).trim()) {
      return exchangeRefreshToken(String(refreshToken).trim());
    }
  }

  throw new Error('No Firebase refresh token found. Run `firebase login` first.');
}

async function exchangeRefreshToken(refreshToken) {
  const body = new URLSearchParams({
    refresh_token: refreshToken,
    client_id: FIREBASE_CLIENT_ID,
    client_secret: FIREBASE_CLIENT_SECRET,
    grant_type: 'refresh_token',
  });

  const response = await fetch('https://www.googleapis.com/oauth2/v3/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to exchange refresh token (${response.status} ${response.statusText}): ${errorText}`
    );
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new Error('Token exchange did not return an access token.');
  }

  return data.access_token;
}

function decodeFirestoreValue(value) {
  if (value === null || value === undefined) return null;

  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return Number(value.doubleValue);
  if (Object.prototype.hasOwnProperty.call(value, 'timestampValue')) return value.timestampValue;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;

  if (Object.prototype.hasOwnProperty.call(value, 'arrayValue')) {
    return (value.arrayValue.values || []).map((entry) => decodeFirestoreValue(entry));
  }

  if (Object.prototype.hasOwnProperty.call(value, 'mapValue')) {
    const nested = value.mapValue.fields || {};
    const result = {};
    for (const [key, nestedValue] of Object.entries(nested)) {
      result[key] = decodeFirestoreValue(nestedValue);
    }
    return result;
  }

  return null;
}

function decodeDocumentFields(fields) {
  const decoded = {};
  for (const [key, value] of Object.entries(fields || {})) {
    decoded[key] = decodeFirestoreValue(value);
  }
  return decoded;
}

function encodeFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((entry) => encodeFirestoreValue(entry)),
      },
    };
  }

  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };

  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }

  if (typeof value === 'object') {
    const fields = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      fields[key] = encodeFirestoreValue(nestedValue);
    }
    return { mapValue: { fields } };
  }

  return { stringValue: String(value) };
}

function encodeFirestoreDocument(data) {
  return {
    fields: encodeFirestoreValue(data).mapValue.fields,
  };
}

function resolveTargetCollection(role) {
  const normalizedRole = String(role || 'citizen').toLowerCase();
  return normalizedRole === 'officer' || normalizedRole === 'admin'
    ? OFFICERS_COLLECTION
    : CITIZENS_COLLECTION;
}

async function listSourceDocuments(projectId, accessToken, pageSize, pageToken) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${SOURCE_COLLECTION}`
  );
  url.searchParams.set('pageSize', String(pageSize));
  if (pageToken) url.searchParams.set('pageToken', pageToken);

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to list source documents (${response.status} ${response.statusText}): ${errorText}`
    );
  }

  return response.json();
}

async function upsertDocument(projectId, accessToken, collection, documentId, fields) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`
  );
  url.searchParams.set('currentDocument.exists', 'true');

  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(encodeFirestoreDocument(fields)),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to upsert ${collection}/${documentId} (${response.status} ${response.statusText}): ${errorText}`
    );
  }
}

async function deleteDocument(projectId, accessToken, collection, documentId) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`,
    {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to delete ${collection}/${documentId} (${response.status} ${response.statusText}): ${errorText}`
    );
  }
}

async function main() {
  const { dryRun, keepSource, pageSize } = parseArgs(process.argv);
  const projectId = resolveProjectId();
  const accessToken = await resolveAccessToken();

  const summary = {
    scanned: 0,
    migrated: 0,
    deleted: 0,
  };

  let pageToken;

  while (true) {
    const page = await listSourceDocuments(projectId, accessToken, pageSize, pageToken);
    const documents = page.documents || [];

    if (documents.length === 0) {
      break;
    }

    for (const doc of documents) {
      summary.scanned += 1;

      const documentId = path.basename(doc.name);
      const sourceFields = decodeDocumentFields(doc.fields || {});
      const targetCollection = resolveTargetCollection(sourceFields.role);
      const targetFields = {
        ...sourceFields,
        id: documentId,
      };

      if (dryRun) {
        summary.migrated += 1;
        if (!keepSource) summary.deleted += 1;
        console.log(`[dry-run] ${SOURCE_COLLECTION}/${documentId} -> ${targetCollection}/${documentId}`);
        continue;
      }

      await upsertDocument(projectId, accessToken, targetCollection, documentId, targetFields);
      summary.migrated += 1;

      if (!keepSource) {
        await deleteDocument(projectId, accessToken, SOURCE_COLLECTION, documentId);
        summary.deleted += 1;
      }

      console.log(`${SOURCE_COLLECTION}/${documentId} -> ${targetCollection}/${documentId}`);
    }

    pageToken = page.nextPageToken;
    if (!pageToken) break;
  }

  console.log('Migration complete.');
  console.log(`Scanned: ${summary.scanned}`);
  console.log(`Migrated: ${summary.migrated}`);
  console.log(`Deleted source docs: ${summary.deleted}`);
  console.log(`Dry run: ${dryRun ? 'yes' : 'no'}`);
  console.log(`Keep source docs: ${keepSource ? 'yes' : 'no'}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});