#!/usr/bin/env node
import { spawn, spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { delimiter, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "../..");
const mobileDir = resolve(repoRoot, "apps/petmagic-mobile");
const env = { ...process.env };
augmentAndroidToolPath();

if (hasHelpArg()) {
  printUsage();
  process.exit(0);
}

const evidencePath =
  env.WATERMARK_QA_PREFLIGHT_EVIDENCE_PATH ??
  "artifacts/watermark-preflight-qa-evidence.json";
const androidEmulatorLogPath =
  env.WATERMARK_QA_ANDROID_EMULATOR_LOG ??
  "/tmp/petmagic_watermark_android_emulator.log";

const evidence = {
  generatedAtUtc: new Date().toISOString(),
  repoRoot,
  checks: [],
};

const commandTimeoutMs = positiveInteger(
  env.WATERMARK_QA_COMMAND_TIMEOUT_MS,
  10 * 60 * 1000,
);
const deviceDiscoveryTimeoutMs = positiveInteger(
  env.WATERMARK_QA_DEVICE_DISCOVERY_TIMEOUT_MS,
  30 * 1000,
);

loadOptionalEnvFile(
  env.WATERMARK_QA_USERS_ENV ?? "artifacts/watermark-qa-users.env",
);

if (env.WATERMARK_QA_SKIP_MEDIA === "1") {
  skip("media fixtures", "WATERMARK_QA_SKIP_MEDIA=1");
} else if (process.platform !== "darwin") {
  skip(
    "media fixtures",
    "scripts/qa/prepare-watermark-manual-qa-media.sh requires macOS sips and Swift/AVFoundation; provide fixtures manually or run on macOS",
  );
} else {
  run("media fixtures", "scripts/qa/prepare-watermark-manual-qa-media.sh", [], {
    cwd: repoRoot,
  });
}

const backendRequiredEnv = [
  "API_BASE_URL",
  "DATABASE_URL",
  "FREE_USER_ID",
  "NO_CREDIT_USER_ID",
  "PREMIUM_USER_ID",
  "FREE_TOKEN",
  "NO_CREDIT_TOKEN",
  "PREMIUM_TOKEN",
];

if (env.WATERMARK_QA_SKIP_BACKEND === "1") {
  skip("backend smoke", "WATERMARK_QA_SKIP_BACKEND=1");
} else {
  const missing = backendRequiredEnv.filter((name) => !env[name]);
  if (missing.length > 0) {
    skip("backend smoke", `missing env: ${missing.join(", ")}`);
  } else {
    run("backend smoke", "node", ["scripts/qa/run-watermark-backend-qa.mjs"], {
      cwd: repoRoot,
    });
  }
}

const detectedDevices =
  env.WATERMARK_QA_AUTO_DEVICES === "1" ? detectFlutterDevices() : {};
let androidDevice =
  env.WATERMARK_QA_ANDROID_DEVICE ?? detectedDevices.androidDevice;
const iosDevice = env.WATERMARK_QA_IOS_DEVICE ?? detectedDevices.iosDevice;

if (!androidDevice && env.WATERMARK_QA_ANDROID_EMULATOR) {
  await launchAndroidEmulator(env.WATERMARK_QA_ANDROID_EMULATOR);
  androidDevice = detectFlutterDevices().androidDevice;
}

runFlutterDevice("mobile integration Android", androidDevice, {
  skipReason: env.WATERMARK_QA_ANDROID_DEVICE
    ? undefined
    : "set WATERMARK_QA_ANDROID_DEVICE or WATERMARK_QA_AUTO_DEVICES=1",
});
runFlutterDevice("mobile integration iOS", iosDevice, {
  skipReason: env.WATERMARK_QA_IOS_DEVICE
    ? undefined
    : "set WATERMARK_QA_IOS_DEVICE or WATERMARK_QA_AUTO_DEVICES=1",
});

writeEvidence();

const failures = evidence.checks.filter((check) => check.status === "failed");
const skipped = evidence.checks.filter((check) => check.status === "skipped");
const strict = env.WATERMARK_QA_STRICT === "1";

console.log(`Watermark preflight evidence: ${evidencePath}`);
for (const check of evidence.checks) {
  const suffix = check.reason ? ` (${check.reason})` : "";
  console.log(`- ${check.status}: ${check.name}${suffix}`);
}

if (failures.length > 0 || (strict && skipped.length > 0)) {
  process.exit(1);
}

function runFlutterDevice(name, deviceId, { skipReason } = {}) {
  if (!deviceId) {
    skip(name, skipReason ?? "device not configured");
    return;
  }

  const extraArgs = splitArgs(env.WATERMARK_QA_FLUTTER_ARGS);
  const firebaseArgs =
    env.WATERMARK_QA_SKIP_FIREBASE === "1"
      ? ["--dart-define=PETMAGIC_SKIP_FIREBASE=true"]
      : [];
  const noPubArgs = env.WATERMARK_QA_FLUTTER_NO_PUB === "1" ? ["--no-pub"] : [];
  if (name.endsWith("iOS") && env.WATERMARK_QA_IOS_RESOLVE_PACKAGES === "1") {
    run(
      "iOS SwiftPM resolve",
      "xcodebuild",
      [
        "-resolvePackageDependencies",
        "-workspace",
        "ios/Runner.xcworkspace",
        "-scheme",
        "Runner",
        "-destination",
        `platform=iOS Simulator,id=${deviceId}`,
      ],
      { cwd: mobileDir },
    );
  }

  run(
    name,
    "flutter",
    [
      "test",
      ...noPubArgs,
      "integration_test/watermark_result_flow_test.dart",
      "-d",
      deviceId,
      ...firebaseArgs,
      ...extraArgs,
    ],
    { cwd: mobileDir },
  );
}

function hasHelpArg() {
  return process.argv.slice(2).some((arg) => arg === "--help" || arg === "-h");
}

function printUsage() {
  console.log(`
Watermark preflight QA runner.

Usage:
  node scripts/qa/run-watermark-preflight-qa.mjs

Optional environment:
  WATERMARK_QA_USERS_ENV                 Env file path, default artifacts/watermark-qa-users.env.
  WATERMARK_QA_PREFLIGHT_EVIDENCE_PATH  Evidence JSON path, default artifacts/watermark-preflight-qa-evidence.json.
  WATERMARK_QA_SKIP_MEDIA=1             Skip media fixture preparation. Non-macOS hosts skip this step automatically.
  WATERMARK_QA_SKIP_BACKEND=1           Skip backend smoke checks.
  WATERMARK_QA_STRICT=1                 Fail when any check is skipped.
  WATERMARK_QA_AUTO_DEVICES=1           Auto-select connected Flutter devices.
  WATERMARK_QA_ANDROID_DEVICE           Android device id for integration test.
  WATERMARK_QA_IOS_DEVICE               iOS device id for integration test.
  WATERMARK_QA_ANDROID_EMULATOR         Android emulator id to launch before testing.
  WATERMARK_QA_SKIP_FIREBASE=1          Pass PETMAGIC_SKIP_FIREBASE=true to Flutter.
  WATERMARK_QA_FLUTTER_NO_PUB=1         Pass --no-pub to Flutter test.
  WATERMARK_QA_FLUTTER_ARGS             Extra args forwarded to Flutter test.

Backend smoke environment, required unless WATERMARK_QA_SKIP_BACKEND=1:
  API_BASE_URL
  DATABASE_URL
  FREE_USER_ID
  NO_CREDIT_USER_ID
  PREMIUM_USER_ID
  FREE_TOKEN
  NO_CREDIT_TOKEN
  PREMIUM_TOKEN
`.trim());
}

async function launchAndroidEmulator(emulatorId) {
  const emulator = findCommand("emulator");
  const adb = findCommand("adb");
  if (!emulator || !adb) {
    skip(
      "android emulator launch",
      "Android SDK emulator/adb not found in PATH or ANDROID_HOME",
    );
    return;
  }

  evidence.checks.push({
    name: "android emulator launch",
    status: "passed",
    emulatorId,
    command: emulator,
  });
  const emulatorArgs = [
    "-avd",
    emulatorId,
    "-no-snapshot-load",
    "-no-window",
    "-no-audio",
    "-gpu",
    "swiftshader_indirect",
    "-no-boot-anim",
    ...splitArgs(env.WATERMARK_QA_ANDROID_EMULATOR_ARGS),
  ];
  const out = openSync(androidEmulatorLogPath, "a");
  const err = openSync(androidEmulatorLogPath, "a");
  spawn(emulator, emulatorArgs, {
    detached: true,
    env,
    shell: process.platform === "win32",
    stdio: ["ignore", out, err],
  }).unref();

  const maxAttempts = positiveInteger(env.WATERMARK_QA_ANDROID_BOOT_ATTEMPTS, 60);
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const boot = spawnSync(adb, ["-e", "shell", "getprop", "sys.boot_completed"], {
      env,
      encoding: "utf8",
      shell: process.platform === "win32",
      timeout: 5000,
    }).stdout.trim();

    if (boot === "1") {
      evidence.checks.push({
        name: "android emulator boot",
        status: "passed",
        emulatorId,
        attempt,
      });
      return;
    }

    await sleep(5000);
  }

  evidence.checks.push({
    name: "android emulator boot",
    status: "failed",
    emulatorId,
    logPath: androidEmulatorLogPath,
    logTail: safeReadTail(androidEmulatorLogPath),
    reason: "adb did not report sys.boot_completed=1",
  });
}

function detectFlutterDevices() {
  const result = spawnSync("flutter", ["devices", "--machine"], {
    cwd: mobileDir,
    env,
    encoding: "utf8",
    shell: process.platform === "win32",
    timeout: deviceDiscoveryTimeoutMs,
  });

  const check = recordCommand("flutter device discovery", result);
  if (check.status !== "passed") {
    return {};
  }

  try {
    const devices = JSON.parse(result.stdout);
    const android = devices.find((device) =>
      String(device.targetPlatform ?? "").toLowerCase().includes("android"),
    );
    const ios = devices.find((device) =>
      String(device.targetPlatform ?? "").toLowerCase().includes("ios"),
    );

    return {
      androidDevice: android?.id,
      iosDevice: ios?.id,
    };
  } catch (error) {
    skip("flutter device auto-select", `could not parse flutter devices: ${error}`);
    return {};
  }
}

function run(name, command, args, { cwd }) {
  const result = spawnSync(command, args, {
    cwd,
    env,
    encoding: "utf8",
    shell: process.platform === "win32",
    timeout: commandTimeoutMs,
  });
  recordCommand(name, result, { command, args, cwd });
}

function augmentAndroidToolPath() {
  const home = env.HOME || env.USERPROFILE;
  const sdkRoots = [
    env.ANDROID_HOME,
    env.ANDROID_SDK_ROOT,
    env.LOCALAPPDATA ? join(env.LOCALAPPDATA, "Android", "Sdk") : undefined,
    home ? join(home, "Library", "Android", "sdk") : undefined,
  ].filter(Boolean);
  const additions = [];
  for (const sdkRoot of sdkRoots) {
    additions.push(join(sdkRoot, "platform-tools"), join(sdkRoot, "emulator"));
  }

  env.PATH = [...additions, env.PATH].filter(Boolean).join(delimiter);
}

function findCommand(command) {
  const locator = process.platform === "win32" ? "where.exe" : "which";
  const result = spawnSync(locator, [command], {
    env,
    encoding: "utf8",
    timeout: 5000,
  });
  return result.status === 0 ? result.stdout.trim().split("\n")[0] : null;
}

function recordCommand(name, result, commandContext = {}) {
  const check = {
    name,
    status: result.status === 0 ? "passed" : "failed",
    exitCode: result.status,
    signal: result.signal,
    ...commandContext,
    stdoutTail: tail(result.stdout),
    stderrTail: tail(result.stderr),
  };

  if (result.error) {
    check.status = "failed";
    check.error = result.error.message;
  }

  evidence.checks.push(check);
  return check;
}

function skip(name, reason) {
  evidence.checks.push({
    name,
    status: "skipped",
    reason,
  });
}

function loadOptionalEnvFile(path) {
  const absolutePath = resolve(repoRoot, path);
  if (!existsSync(absolutePath)) {
    skip("QA users env", `not found: ${path}`);
    return;
  }

  const loadedKeys = [];
  for (const rawLine of readFileSync(absolutePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) {
      continue;
    }

    const [, key, rawValue] = match;
    if (env[key]) {
      continue;
    }

    env[key] = parseShellValue(rawValue);
    loadedKeys.push(key);
  }

  evidence.checks.push({
    name: "QA users env",
    status: "passed",
    path,
    loadedKeys,
  });
}

function parseShellValue(rawValue) {
  const value = rawValue.trim();
  if (value.startsWith("'") && value.endsWith("'")) {
    return value.slice(1, -1).replaceAll("'\\''", "'");
  }

  if (value.startsWith('"') && value.endsWith('"')) {
    return value.slice(1, -1).replaceAll('\\"', '"');
  }

  return value;
}

function splitArgs(value) {
  if (!value) {
    return [];
  }

  return value
    .split(/\s+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function writeEvidence() {
  evidence.overallStatus = overallStatus();
  mkdirSync(dirname(resolve(repoRoot, evidencePath)), { recursive: true });
  writeFileSync(
    resolve(repoRoot, evidencePath),
    `${JSON.stringify(evidence, null, 2)}\n`,
  );
}

function overallStatus() {
  if (evidence.checks.some((check) => check.status === "failed")) {
    return "failed";
  }

  if (evidence.checks.some((check) => check.status === "skipped")) {
    return "partial";
  }

  return "passed";
}

function tail(value, maxLength = 12000) {
  if (!value) {
    return "";
  }

  return value.length > maxLength ? value.slice(-maxLength) : value;
}

function safeReadTail(path) {
  try {
    return tail(readFileSync(path, "utf8"));
  } catch {
    return "";
  }
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
