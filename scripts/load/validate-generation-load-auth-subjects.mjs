#!/usr/bin/env node

const expectedTokenCount = 50;
const rawTokens = process.env.AUTH_TOKENS || '';
const tokens = rawTokens
  .split(',')
  .map(token => token.trim())
  .filter(Boolean);

if (tokens.length !== expectedTokenCount) {
  fail(`Scheduler V2 core load requires exactly ${expectedTokenCount} JWTs; received ${tokens.length}.`);
}

const subjects = new Set();
for (const token of tokens) {
  const segments = token.split('.');
  if (segments.length !== 3 || segments.some(segment => segment.length === 0)) {
    fail('Every AUTH_TOKENS entry must be a three-segment JWT.');
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(segments[1], 'base64url').toString('utf8'));
  } catch {
    fail('Every AUTH_TOKENS entry must contain a valid base64url JSON payload.');
  }

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    fail('Every AUTH_TOKENS entry must contain a JSON object payload.');
  }

  const subject = typeof payload.sub === 'string' ? payload.sub.trim() : '';
  if (!subject) {
    fail('Every AUTH_TOKENS JWT must contain a non-empty string sub claim.');
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(subject)) {
    fail('Every AUTH_TOKENS JWT sub claim must be a UUID.');
  }
  const canonicalSubject = subject.toLowerCase();
  if (subjects.has(canonicalSubject)) {
    fail('AUTH_TOKENS must represent exactly 50 unique JWT sub claims.');
  }
  subjects.add(canonicalSubject);
}

// Never print a token or subject. The runner records only this aggregate count.
process.stdout.write(String(subjects.size));

function fail(message) {
  console.error(message);
  process.exit(2);
}
