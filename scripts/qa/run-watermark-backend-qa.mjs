#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const generationIds = {
  freeImage: "50000000-0000-4000-8000-000000000001",
  freeVideo: "50000000-0000-4000-8000-000000000002",
  noCreditImage: "50000000-0000-4000-8000-000000000003",
  premiumImage: "50000000-0000-4000-8000-000000000004",
  preparingImage: "50000000-0000-4000-8000-000000000005",
};

const requiredEnv = [
  "API_BASE_URL",
  "DATABASE_URL",
  "FREE_USER_ID",
  "NO_CREDIT_USER_ID",
  "PREMIUM_USER_ID",
  "FREE_TOKEN",
  "NO_CREDIT_TOKEN",
  "PREMIUM_TOKEN",
];

const missing = requiredEnv.filter((name) => !process.env[name]);
if (missing.length > 0) {
  fail(`Missing required env: ${missing.join(", ")}`);
}

const apiBaseUrl = process.env.API_BASE_URL.replace(/\/+$/, "");
const publicBaseUrl = (process.env.PUBLIC_BASE_URL ?? apiBaseUrl).replace(/\/+$/, "");
const evidencePath = process.env.WATERMARK_QA_EVIDENCE_PATH ?? "artifacts/watermark-backend-qa-evidence.json";
mkdirSync(dirname(evidencePath), { recursive: true });

const evidence = {
  generatedAtUtc: new Date().toISOString(),
  apiBaseUrl,
  publicBaseUrl,
  checks: [],
};

runSeed();

const free = bearer(process.env.FREE_TOKEN);
const noCredit = bearer(process.env.NO_CREDIT_TOKEN);
const premium = bearer(process.env.PREMIUM_TOKEN);

const freeImage = await getGeneration(free, generationIds.freeImage, "free image");
expect(freeImage.hasWatermark === true, "free image has watermark");
expect(freeImage.canRemoveWatermark === true, "free image can remove watermark");
expect(freeImage.userPlan === "free", "free image userPlan is free");
expect(mediaUrl(freeImage)?.includes("free-image-watermarked"), "free image returns watermarked media");

const freeVideo = await getGeneration(free, generationIds.freeVideo, "free video");
expect(freeVideo.hasWatermark === true, "free video has watermark");
expect(mediaUrl(freeVideo)?.includes("free-video-watermarked"), "free video returns watermarked media");

const premiumImage = await getGeneration(premium, generationIds.premiumImage, "premium image");
expect(premiumImage.hasWatermark === false, "premium image has no watermark");
expect(premiumImage.canRemoveWatermark === false, "premium image cannot remove watermark");
expect(premiumImage.userPlan === "premium", "premium image userPlan is premium");
expect(mediaUrl(premiumImage)?.includes("premium-image-clean"), "premium image returns clean media");

const freeDownload = await apiJson(
  "GET",
  `/api/generations/${generationIds.freeImage}/download`,
  free,
  undefined,
  "free download before unlock");
expect(freeDownload.hasWatermark === true, "free download before unlock has watermark");
expect(freeDownload.mediaUrl?.includes("free-image-watermarked"), "free download before unlock returns watermarked media");

const freeShare = await apiJson(
  "POST",
  `/api/generations/${generationIds.freeImage}/share`,
  free,
  {},
  "free share before unlock");
expect(freeShare.hasWatermark === true, "free share before unlock has watermark");
expect(freeShare.mediaUrl?.includes("free-image-watermarked"), "free share before unlock returns watermarked media");

const unlock = await apiJson(
  "POST",
  `/api/generations/${generationIds.freeImage}/remove-watermark`,
  free,
  { paymentMethod: "credit" },
  "credit unlock");
expect(unlock.watermarkRemoved === true, "credit unlock removed watermark");
expect(unlock.creditsSpent === 1, "credit unlock spent one credit");
expect(unlock.mediaUrl?.includes("free-image-clean"), "credit unlock returns clean media");

const unlockRepeat = await apiJson(
  "POST",
  `/api/generations/${generationIds.freeImage}/remove-watermark`,
  free,
  { paymentMethod: "credit" },
  "credit unlock repeat");
expect(unlockRepeat.watermarkRemoved === true, "credit unlock repeat removed watermark");
expect(unlockRepeat.creditsSpent === 1, "credit unlock repeat reports existing one credit spend");
expect(unlockRepeat.remainingCredits == null, "credit unlock repeat does not return a new remaining balance");

const cleanDownload = await apiJson(
  "GET",
  `/api/generations/${generationIds.freeImage}/download`,
  free,
  undefined,
  "free download after unlock");
expect(cleanDownload.hasWatermark === false, "free download after unlock has no watermark");
expect(cleanDownload.mediaUrl?.includes("free-image-clean"), "free download after unlock returns clean media");

const noCreditFailure = await apiProblem(
  "POST",
  `/api/generations/${generationIds.noCreditImage}/remove-watermark`,
  noCredit,
  { paymentMethod: "credit" },
  "no-credit unlock failure");
expect(noCreditFailure.status >= 400, "no-credit unlock fails");
expect(!JSON.stringify(noCreditFailure.body).includes("no-credit-clean"), "no-credit failure does not expose clean media");

const preparing = await getGeneration(free, generationIds.preparingImage, "preparing image");
expect(mediaUrl(preparing) == null, "preparing image does not expose clean media to free user");
expect(preparing.canRemoveWatermark === true, "preparing image can remove watermark");
expect(preparing.watermarkMessage === "Preparing result...", "preparing image explains pending watermark");

const preparingDownload = await apiProblem(
  "GET",
  `/api/generations/${generationIds.preparingImage}/download`,
  free,
  undefined,
  "preparing download failure");
expect(preparingDownload.status === 202 || preparingDownload.status >= 400, "preparing download does not return ready media for free user");
expect(!JSON.stringify(preparingDownload.body).includes("preparing-clean"), "preparing download does not expose clean media");

const crossUser = await apiProblem(
  "GET",
  `/api/generations/${generationIds.premiumImage}`,
  free,
  undefined,
  "cross-user generation fetch");
expect(crossUser.status === 404 || crossUser.status === 403, "cross-user generation fetch is denied");

if (process.env.ADMIN_TOKEN) {
  const admin = bearer(process.env.ADMIN_TOKEN);
  const settings = await apiJson("GET", "/api/admin/templates/monetization/watermark", admin, undefined, "admin watermark settings");
  expect(settings.enabled === true, "admin settings watermark enabled");
  expect(settings.previewImageUrl?.includes("watermark-preview-image"), "admin settings has image preview URL");
  expect(settings.previewVideoFrameUrl?.includes("watermark-preview-video-frame"), "admin settings has video preview URL");

  const grant = await apiJson(
    "POST",
    `/api/admin/templates/generations/${generationIds.noCreditImage}/grant-clean-download`,
    admin,
    {},
    "admin grant clean download");
  expect(grant.watermarkRemoved === true, "admin grant removed watermark");
  expect(grant.creditsSpent === 0, "admin grant spent zero credits");
}

writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(`Watermark backend QA passed. Evidence: ${evidencePath}`);

function runSeed() {
  const result = spawnSync(
    "psql",
    [
      process.env.DATABASE_URL,
      "-v",
      `free_user_id='${process.env.FREE_USER_ID}'`,
      "-v",
      `no_credit_user_id='${process.env.NO_CREDIT_USER_ID}'`,
      "-v",
      `premium_user_id='${process.env.PREMIUM_USER_ID}'`,
      "-v",
      `public_base_url='${publicBaseUrl}'`,
      "-f",
      "scripts/qa/seed-watermark-manual-qa.sql",
    ],
    { encoding: "utf8" });

  if (result.status !== 0) {
    fail(`Seed failed:\n${result.stdout}\n${result.stderr}`);
  }

  evidence.checks.push({
    name: "seed database rows",
    passed: true,
    stdout: trimOutput(result.stdout),
  });
}

async function getGeneration(token, id, label) {
  return await apiJson("GET", `/api/generations/${id}`, token, undefined, label);
}

async function apiJson(method, path, token, body, label) {
  const response = await api(method, path, token, body);
  const text = await response.text();
  let parsed;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    fail(`${label} returned non-JSON response (${response.status}): ${text}`);
  }

  if (!response.ok) {
    fail(`${label} failed with ${response.status}: ${JSON.stringify(parsed)}`);
  }

  evidence.checks.push({
    name: label,
    passed: true,
    status: response.status,
    body: redactMediaUrls(parsed),
  });
  return parsed;
}

async function apiProblem(method, path, token, body, label) {
  const response = await api(method, path, token, body);
  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = { raw: text };
  }

  evidence.checks.push({
    name: label,
    passed: !response.ok || response.status === 202,
    status: response.status,
    body: parsed,
  });
  return { status: response.status, body: parsed };
}

async function api(method, path, token, body) {
  return await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      Authorization: token,
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function expect(condition, name) {
  if (!condition) {
    evidence.checks.push({ name, passed: false });
    writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
    fail(`Expectation failed: ${name}`);
  }

  evidence.checks.push({ name, passed: true });
}

function mediaUrl(payload) {
  return payload.mediaUrl ?? payload.outputUrl ?? null;
}

function bearer(token) {
  return token.startsWith("Bearer ") ? token : `Bearer ${token}`;
}

function redactMediaUrls(value) {
  if (Array.isArray(value)) {
    return value.map(redactMediaUrls);
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [
      key,
      key.toLowerCase().endsWith("url") && typeof entry === "string"
        ? stripQuery(entry)
        : redactMediaUrls(entry),
    ]));
  }

  return value;
}

function stripQuery(value) {
  const index = value.indexOf("?");
  return index === -1 ? value : `${value.slice(0, index)}?[redacted]`;
}

function trimOutput(value) {
  return value
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .slice(-20);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
