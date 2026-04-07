/* eslint-disable no-console */
const fs = require("fs");
const os = require("os");
const path = require("path");

function resolveProjectId() {
  const envProjectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID;

  if (envProjectId && envProjectId.trim()) {
    return envProjectId.trim();
  }

  const firebaseConfigPath = path.resolve(__dirname, "..", "firebase.json");
  if (fs.existsSync(firebaseConfigPath)) {
    const firebaseConfig = JSON.parse(fs.readFileSync(firebaseConfigPath, "utf8"));
    const platformConfig = firebaseConfig.flutter?.platforms;
    const candidates = [
      platformConfig?.android?.default?.projectId,
      platformConfig?.ios?.default?.projectId,
      platformConfig?.dart?.["lib/firebase_options.dart"]?.projectId,
    ];

    for (const candidate of candidates) {
      if (candidate && String(candidate).trim()) {
        return String(candidate).trim();
      }
    }
  }

  throw new Error("Unable to detect Firebase project id.");
}

function resolveAccessToken() {
  const envToken =
    process.env.FIREBASE_ACCESS_TOKEN ||
    process.env.GOOGLE_OAUTH_ACCESS_TOKEN ||
    process.env.GOOGLE_ACCESS_TOKEN;

  if (envToken && envToken.trim()) {
    return envToken.trim();
  }

  const tokenFilePath = path.join(
    os.homedir(),
    ".config",
    "configstore",
    "firebase-tools.json"
  );

  if (fs.existsSync(tokenFilePath)) {
    const tokenConfig = JSON.parse(fs.readFileSync(tokenFilePath, "utf8"));
    const storedToken = tokenConfig.tokens?.access_token;
    if (storedToken && String(storedToken).trim()) {
      return String(storedToken).trim();
    }
  }

  throw new Error("No Firebase access token found. Run `firebase login` first.");
}

function encodeFirestoreDocument(data) {
  return {
    fields: encodeFirestoreValue(data).mapValue.fields,
  };
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

  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }

  if (typeof value === "object") {
    const fields = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      fields[key] = encodeFirestoreValue(nestedValue);
    }
    return { mapValue: { fields } };
  }

  return { stringValue: String(value) };
}

function normalizeNic(rawNic) {
  return rawNic.trim().toUpperCase().replace(/[^0-9A-Z]/g, "");
}

function normalizePhoneToLocal(rawPhone) {
  const digitsOnly = rawPhone.replace(/[^0-9+]/g, "");
  if (digitsOnly.startsWith("+94")) {
    const rest = digitsOnly.slice(3);
    return rest ? `0${rest}` : "";
  }
  if (digitsOnly.startsWith("94")) {
    const rest = digitsOnly.slice(2);
    return rest ? `0${rest}` : "";
  }
  return digitsOnly;
}

function normalizeOfficerId(rawOfficerId) {
  return rawOfficerId.trim().toUpperCase();
}

async function main() {
  const projectId = resolveProjectId();
  const accessToken = resolveAccessToken();

  const officerDocId = process.env.SEED_OFFICER_DOC_ID || "officer_demo_govease";
  const officerId = normalizeOfficerId(process.env.SEED_OFFICER_ID || "GN-2026-0101");
  const officerName = process.env.SEED_OFFICER_NAME || "GovEase Demo Officer";
  const officerNic = normalizeNic(process.env.SEED_OFFICER_NIC || "199001234567");
  const officerPhone = process.env.SEED_OFFICER_PHONE || "+94701285090";

  const now = new Date().toISOString();
  const payload = {
    id: officerDocId,
    name: officerName,
    nic: officerNic,
    nicNormalized: officerNic,
    phone: officerPhone,
    phoneNormalized: normalizePhoneToLocal(officerPhone),
    role: "officer",
    officerId,
    officerIdNormalized: officerId,
    division: "Wellampitiya",
    province: "Western",
    district: "Colombo",
    pradeshiyaSabha: "Kolonnawa PS",
    gramasewaWasama: "Wellampitiya",
    preferredLanguage: "en",
    profileImageUrl: "",
    createdAt: now,
    updatedAt: now,
    seedTag: "officer-demo",
  };

  const document = encodeFirestoreDocument(payload);

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/officers/${officerDocId}`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(document),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Officer seed failed (${response.status} ${response.statusText}): ${errorText}`
    );
  }

  console.log("Officer demo seeded successfully.");
  console.log(`Project: ${projectId}`);
  console.log(`Document: officers/${officerDocId}`);
  console.log(`Officer ID: ${officerId}`);
  console.log(`Phone: ${officerPhone}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
