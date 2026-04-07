/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");

const DEFAULT_SOURCE_URL =
  "https://raw.githubusercontent.com/dinushchathurya/srilankan-grama-niladhari-divisions/master/src/Division.php";
const DEFAULT_OUTPUT_PATH =
  "../assets/data/sri_lanka_administrative_hierarchy.generated.json";

const EXPECTED_DISTRICTS = {
  Western: ["Colombo", "Gampaha", "Kalutara"],
  Central: ["Kandy", "Matale", "Nuwara Eliya"],
  Southern: ["Galle", "Matara", "Hambantota"],
  Northern: ["Jaffna", "Kilinochchi", "Mannar", "Mullaitivu", "Vavuniya"],
  Eastern: ["Trincomalee", "Batticaloa", "Ampara"],
  "North Western": ["Kurunegala", "Puttalam"],
  "North Central": ["Anuradhapura", "Polonnaruwa"],
  Uva: ["Badulla", "Monaragala"],
  Sabaragamuwa: ["Ratnapura", "Kegalle"],
};

const DISTRICT_TO_PROVINCE = {
  Colombo: "Western",
  Gampaha: "Western",
  Kalutara: "Western",
  Kandy: "Central",
  Matale: "Central",
  "Nuwara Eliya": "Central",
  Galle: "Southern",
  Matara: "Southern",
  Hambantota: "Southern",
  Jaffna: "Northern",
  Kilinochchi: "Northern",
  Mannar: "Northern",
  Mullaitivu: "Northern",
  Vavuniya: "Northern",
  Trincomalee: "Eastern",
  Batticaloa: "Eastern",
  Ampara: "Eastern",
  Kurunegala: "North Western",
  Puttalam: "North Western",
  Anuradhapura: "North Central",
  Polonnaruwa: "North Central",
  Badulla: "Uva",
  Monaragala: "Uva",
  Ratnapura: "Sabaragamuwa",
  Kegalle: "Sabaragamuwa",
};

const DISTRICT_NAME_ALIASES = {
  Moneragala: "Monaragala",
  Mullativu: "Mullaitivu",
  Rathnapura: "Ratnapura",
};

function parseArgs(argv) {
  const args = argv.slice(2);
  const flags = new Set(args.filter((a) => a.startsWith("--")));
  const positional = args.filter((a) => !a.startsWith("--"));

  return {
    inputPath: positional[0] || DEFAULT_SOURCE_URL,
    dryRun: flags.has("--dry-run"),
    strict: flags.has("--strict"),
    outputPath: DEFAULT_OUTPUT_PATH,
  };
}

function isRemoteSource(inputPath) {
  return /^https?:\/\//i.test(inputPath);
}

function ensureDirectoryExists(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

async function materializeSource(inputPath) {
  if (!isRemoteSource(inputPath)) {
    const resolvedPath = path.resolve(__dirname, inputPath);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`File not found: ${resolvedPath}`);
    }

    return { sourcePath: inputPath, resolvedPath };
  }

  const response = await fetch(inputPath, {
    headers: {
      "user-agent": "GovEase-seed-script/1.0",
    },
  });

  if (!response.ok) {
    throw new Error(
      `Failed to fetch source (${response.status} ${response.statusText}): ${inputPath}`
    );
  }

  const body = await response.text();
  const tempDir = fs.mkdtempSync(
    path.join(os.tmpdir(), "govease-admin-hierarchy-")
  );
  const filename = path.basename(new URL(inputPath).pathname) || "source.php";
  const resolvedPath = path.join(tempDir, filename);
  fs.writeFileSync(resolvedPath, body, "utf8");

  return { sourcePath: inputPath, resolvedPath };
}

function loadJsonHierarchy(resolvedPath) {
  const raw = fs.readFileSync(resolvedPath, "utf8");
  const parsed = JSON.parse(raw);

  if (!parsed || typeof parsed !== "object") {
    throw new Error("Invalid JSON: root must be an object.");
  }

  if (parsed.provinces && typeof parsed.provinces === "object") {
    return parsed.provinces;
  }

  return normalizeDistrictHierarchy(parsed);
}

function loadPhpHierarchy(resolvedPath) {
  const phpAvailable = spawnSync("php", ["-v"], { encoding: "utf8" });
  if (phpAvailable.status !== 0) {
    throw new Error(
      "PHP CLI is required to read the upstream package source, but it is not available."
    );
  }

  const phpCode = [
    `require ${JSON.stringify(resolvedPath)};`,
    "echo json_encode(\\Dinushchathurya\\Division\\Division::$Division, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);",
  ].join(" ");

  const result = spawnSync("php", ["-r", phpCode], {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024,
  });

  if (result.status !== 0) {
    throw new Error(
      `Failed to load PHP hierarchy source: ${result.stderr || result.stdout || "unknown error"}`
    );
  }

  const parsed = JSON.parse(result.stdout);
  return normalizeDistrictHierarchy(parsed);
}

function normalizeDistrictHierarchy(raw) {
  const provinces = {};

  if (!raw || typeof raw !== "object") {
    return provinces;
  }

  for (const [district, secretariatsRaw] of Object.entries(raw)) {
    const normalizedDistrict = DISTRICT_NAME_ALIASES[district] || district;
    const province = DISTRICT_TO_PROVINCE[normalizedDistrict];
    if (!province) {
      continue;
    }

    const secretariats = {};
    if (secretariatsRaw && typeof secretariatsRaw === "object") {
      for (const [secretariat, divisionsRaw] of Object.entries(secretariatsRaw)) {
        const divisions = Array.isArray(divisionsRaw)
          ? divisionsRaw
              .map((division) => division.toString().trim())
              .filter((division) => division.length > 0)
          : [];

        if (divisions.length > 0) {
          secretariats[secretariat.toString()] = divisions;
        }
      }
    }

    if (Object.keys(secretariats).length === 0) {
      continue;
    }

    if (!provinces[province]) {
      provinces[province] = {};
    }

    provinces[province][normalizedDistrict] = secretariats;
  }

  return provinces;
}

function resolveProjectId() {
  const envProjectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID;

  if (envProjectId) {
    return envProjectId.trim();
  }

  const firebaseConfigPath = path.resolve(__dirname, "..", "firebase.json");
  if (fs.existsSync(firebaseConfigPath)) {
    try {
      const firebaseConfig = JSON.parse(
        fs.readFileSync(firebaseConfigPath, "utf8")
      );
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
    } catch (error) {
      throw new Error(`Unable to parse firebase.json: ${error.message}`);
    }
  }

  throw new Error(
    "Unable to detect a Firebase project id. Set GCLOUD_PROJECT or GOOGLE_CLOUD_PROJECT, or ensure firebase.json contains a projectId."
  );
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
    try {
      const tokenConfig = JSON.parse(fs.readFileSync(tokenFilePath, "utf8"));
      const storedToken = tokenConfig.tokens?.access_token;
      if (storedToken && String(storedToken).trim()) {
        return String(storedToken).trim();
      }
    } catch (error) {
      throw new Error(`Unable to parse Firebase CLI token file: ${error.message}`);
    }
  }

  return "";
}

function validateHierarchy(provinces) {
  const missing = [];
  const unknown = [];

  for (const [province, expectedDistricts] of Object.entries(EXPECTED_DISTRICTS)) {
    const districtMap = provinces[province];
    if (!districtMap || typeof districtMap !== "object") {
      missing.push(`${province} (entire province missing)`);
      continue;
    }

    for (const district of expectedDistricts) {
      if (!(district in districtMap)) {
        missing.push(`${province} -> ${district}`);
      }
    }

    for (const district of Object.keys(districtMap)) {
      if (!expectedDistricts.includes(district)) {
        unknown.push(`${province} -> ${district}`);
      }
    }
  }

  const expectedProvinces = new Set(Object.keys(EXPECTED_DISTRICTS));
  for (const province of Object.keys(provinces)) {
    if (!expectedProvinces.has(province)) {
      unknown.push(`${province} (unknown province)`);
    }
  }

  let districtCount = 0;
  let secretariatCount = 0;
  let divisionCount = 0;

  for (const districtMap of Object.values(provinces)) {
    if (!districtMap || typeof districtMap !== "object") continue;
    districtCount += Object.keys(districtMap).length;

    for (const secretariatMap of Object.values(districtMap)) {
      if (!secretariatMap || typeof secretariatMap !== "object") continue;
      secretariatCount += Object.keys(secretariatMap).length;

      for (const divisions of Object.values(secretariatMap)) {
        if (!Array.isArray(divisions)) continue;
        divisionCount += divisions.length;
      }
    }
  }

  return {
    missing,
    unknown,
    summary: {
      provinceCount: Object.keys(provinces).length,
      districtCount,
      secretariatCount,
      divisionCount,
    },
  };
}

async function uploadHierarchy(provinces) {
  const projectId = resolveProjectId();
  const accessToken = resolveAccessToken();

  if (!accessToken) {
    return false;
  }

  const document = encodeFirestoreDocument({
    provinces,
    updatedAt: new Date().toISOString(),
  });

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/config/administrative_hierarchy`,
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
      `Firestore REST write failed (${response.status} ${response.statusText}): ${errorText}`
    );
  }

  return true;
}

function encodeFirestoreDocument(data) {
  return {
    fields: encodeFirestoreValue(data).mapValue.fields,
  };
}

function encodeFirestoreValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((entry) => encodeFirestoreValue(entry)),
      },
    };
  }

  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }

  if (typeof value === "string") {
    return { stringValue: value };
  }

  if (typeof value === "number") {
    if (Number.isInteger(value)) {
      return { integerValue: String(value) };
    }
    return { doubleValue: value };
  }

  if (typeof value === "boolean") {
    return { booleanValue: value };
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

function writeHierarchyArtifact(provinces, outputPath) {
  const resolvedOutput = path.resolve(__dirname, outputPath);
  ensureDirectoryExists(resolvedOutput);
  fs.writeFileSync(
    resolvedOutput,
    `${JSON.stringify({ provinces }, null, 2)}\n`,
    "utf8"
  );
  return resolvedOutput;
}

async function main() {
  try {
    const { inputPath, dryRun, strict, outputPath } = parseArgs(process.argv);
    const { resolvedPath, sourcePath } = await materializeSource(inputPath);
    const provinces = path.extname(resolvedPath).toLowerCase() === ".php"
      ? loadPhpHierarchy(resolvedPath)
      : loadJsonHierarchy(resolvedPath);
    const report = validateHierarchy(provinces);
    const artifactPath = writeHierarchyArtifact(provinces, outputPath);

    console.log(`Loaded: ${sourcePath}`);
    console.log(
      `Summary: provinces=${report.summary.provinceCount}, districts=${report.summary.districtCount}, secretariats=${report.summary.secretariatCount}, divisions=${report.summary.divisionCount}`
    );
    console.log(`Normalized hierarchy written to: ${artifactPath}`);

    if (report.missing.length > 0) {
      console.warn("Missing expected districts:");
      for (const item of report.missing) {
        console.warn(`- ${item}`);
      }
    }

    if (report.unknown.length > 0) {
      console.warn("Unknown/extra entries:");
      for (const item of report.unknown) {
        console.warn(`- ${item}`);
      }
    }

    if (strict && report.missing.length > 0) {
      throw new Error("Strict mode failed: missing expected districts found.");
    }

    if (dryRun) {
      console.log("Dry run complete. No upload performed.");
      process.exit(0);
    }

    const uploaded = await uploadHierarchy(provinces);
    if (uploaded) {
      console.log(
        "Administrative hierarchy uploaded to config/administrative_hierarchy."
      );
    } else {
      console.warn(
        "No Firebase access token found. Upload skipped, but the normalized hierarchy file was generated locally."
      );
    }
    process.exit(0);
  } catch (error) {
    console.error(`Seeding failed: ${error.message}`);
    process.exit(1);
  }
}

main();
