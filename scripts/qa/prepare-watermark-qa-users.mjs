#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const apiBaseUrl = required("API_BASE_URL").replace(/\/+$/, "");
const databaseUrl = required("DATABASE_URL");
const password = process.env.WATERMARK_QA_PASSWORD ?? "PetMagicQa1!";
const emailPrefix = process.env.WATERMARK_QA_EMAIL_PREFIX ?? `watermark-qa-${Date.now()}`;
const outputPath = process.env.WATERMARK_QA_USERS_OUTPUT ?? "artifacts/watermark-qa-users.env";

const users = {
  free: {
    email: process.env.FREE_EMAIL ?? `${emailPrefix}+free@example.test`,
    displayName: "Watermark QA Free",
    isPremium: false,
  },
  noCredit: {
    email: process.env.NO_CREDIT_EMAIL ?? `${emailPrefix}+no-credit@example.test`,
    displayName: "Watermark QA No Credit",
    isPremium: false,
  },
  premium: {
    email: process.env.PREMIUM_EMAIL ?? `${emailPrefix}+premium@example.test`,
    displayName: "Watermark QA Premium",
    isPremium: true,
  },
};

const legal = await apiJson("GET", "/api/legal/current", undefined, undefined, "legal documents");
const termsVersion = legal.termsOfUse.version;
const privacyVersion = legal.privacyPolicy.version;

for (const user of Object.values(users)) {
  await registerIfNeeded(user, termsVersion, privacyVersion);
}

const rows = activateUsers();
for (const [key, user] of Object.entries(users)) {
  const row = rows.find((item) => item.Email?.toLowerCase() === user.email.toLowerCase());
  if (!row) {
    fail(`User row not found after activation: ${user.email}`);
  }

  user.userId = row.Id;
}

for (const user of Object.values(users)) {
  const login = await apiJson(
    "POST",
    "/api/auth/login",
    undefined,
    { email: user.email, password },
    `login ${user.email}`);
  user.token = login.accessToken;
  user.isPremiumFromToken = login.user?.isPremium;
}

if (users.premium.isPremiumFromToken !== true) {
  fail("Premium user token was not issued with premium=true. Check users table update and retry.");
}

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, renderEnv(), { mode: 0o600 });

console.log(`Watermark QA users ready. Env file: ${outputPath}`);
console.log(renderEnv({ redactTokens: true }));

async function registerIfNeeded(user, termsOfUseVersion, privacyPolicyVersion) {
  const response = await api("POST", "/api/auth/register", undefined, {
    email: user.email,
    password,
    displayName: user.displayName,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    termsOfUseVersion,
    privacyPolicyVersion,
    marketingEmailsEnabled: false,
  });

  if (response.status === 201) {
    return;
  }

  const text = await response.text();
  if (response.status === 400 && /duplicate|already|email/i.test(text)) {
    return;
  }

  fail(`Register failed for ${user.email}: ${response.status} ${text}`);
}

function activateUsers() {
  const sql = `
WITH target("Email", "IsPremium") AS (
  VALUES
    (${sqlLiteral(users.free.email)}, false),
    (${sqlLiteral(users.noCredit.email)}, false),
    (${sqlLiteral(users.premium.email)}, true)
)
UPDATE users AS u
SET
  "EmailConfirmed" = true,
  "AccountStatus" = 2,
  "AccountStatusUpdatedAtUtc" = now(),
  "IsActive" = true,
  "IsPremium" = target."IsPremium"
FROM target
WHERE lower(u."Email") = lower(target."Email");

SELECT json_agg(row_to_json(u)) AS users
FROM (
  SELECT "Id", "Email", "EmailConfirmed", "AccountStatus", "IsPremium"
  FROM users
  WHERE lower("Email") IN (
    lower(${sqlLiteral(users.free.email)}),
    lower(${sqlLiteral(users.noCredit.email)}),
    lower(${sqlLiteral(users.premium.email)})
  )
  ORDER BY "Email"
) AS u;
`;

  const result = spawnSync("psql", [databaseUrl, "-qAt", "-c", sql], { encoding: "utf8" });
  if (result.status !== 0) {
    fail(`User activation SQL failed:\n${result.stdout}\n${result.stderr}`);
  }

  const line = result.stdout
    .split("\n")
    .map((value) => value.trim())
    .filter(Boolean)
    .at(-1);
  if (!line) {
    fail("User activation SQL returned no user rows.");
  }

  try {
    return JSON.parse(line) ?? [];
  } catch (error) {
    fail(`Could not parse user activation SQL JSON: ${line}\n${error}`);
  }
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

  return parsed;
}

async function api(method, path, token, body) {
  return await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: bearer(token) } : {}),
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function renderEnv({ redactTokens = false } = {}) {
  return [
    `API_BASE_URL=${shellQuote(apiBaseUrl)}`,
    `DATABASE_URL=${shellQuote(databaseUrl)}`,
    `FREE_USER_ID=${shellQuote(users.free.userId)}`,
    `NO_CREDIT_USER_ID=${shellQuote(users.noCredit.userId)}`,
    `PREMIUM_USER_ID=${shellQuote(users.premium.userId)}`,
    `FREE_TOKEN=${shellQuote(redactTokens ? "[redacted]" : users.free.token)}`,
    `NO_CREDIT_TOKEN=${shellQuote(redactTokens ? "[redacted]" : users.noCredit.token)}`,
    `PREMIUM_TOKEN=${shellQuote(redactTokens ? "[redacted]" : users.premium.token)}`,
    `FREE_EMAIL=${shellQuote(users.free.email)}`,
    `NO_CREDIT_EMAIL=${shellQuote(users.noCredit.email)}`,
    `PREMIUM_EMAIL=${shellQuote(users.premium.email)}`,
    `WATERMARK_QA_PASSWORD=${shellQuote(password)}`,
    "",
  ].join("\n");
}

function bearer(token) {
  return token.startsWith("Bearer ") ? token : `Bearer ${token}`;
}

function sqlLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function required(name) {
  const value = process.env[name];
  if (!value) {
    fail(`Missing required env: ${name}`);
  }

  return value;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
