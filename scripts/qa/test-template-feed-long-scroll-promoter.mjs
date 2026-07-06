#!/usr/bin/env node

import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const promoterPath = join(scriptDir, 'promote-template-feed-long-scroll-artifact.mjs');

try {
  await assertPendingPromotion();
  await assertLowMemoryPromotion();
  await assertReleaseSignoffRejectsOrdinaryDeviceLabel();
  console.log('template feed long-scroll promoter self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertPendingPromotion() {
  const fixture = createFixture('pending');
  const output = join(fixture, 'curated.md');
  const result = await runPromoter(fixture, output, 'pending', 'ordinary device');

  assert(result.code === 0, `pending promotion failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
  const markdown = readFileSync(output, 'utf8');
  assert(markdown.includes('Weak-device release signoff: PENDING'), 'pending signoff missing');
  assert(markdown.includes('active video preview average: mixed `2.0`, video-only `3.0`'), 'active preview summary missing');
}

async function assertLowMemoryPromotion() {
  const fixture = createFixture('low-memory');
  const output = join(fixture, 'curated.md');
  const result = await runPromoter(fixture, output, 'low-memory-emulator', 'Pixel_3a_API_35 low-memory emulator');

  assert(result.code === 0, `low-memory promotion failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
  const markdown = readFileSync(output, 'utf8');
  assert(markdown.includes('Low-memory emulator signoff: PASS'), 'low-memory signoff missing');
  assert(!markdown.includes('not final Task 2 release evidence'), 'PASS artifact must not include pending note');
}

async function assertReleaseSignoffRejectsOrdinaryDeviceLabel() {
  const fixture = createFixture('ordinary-signoff');
  const output = join(fixture, 'curated.md');
  const result = await runPromoter(fixture, output, 'low-memory-emulator', 'ordinary device');

  assert(result.code !== 0, 'release signoff with ordinary device label should fail');
  assert(
    result.stderr.includes('Release signoff requires a concrete weak-device or low-memory device label.'),
    `missing concrete device-label failure\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );
}

function createFixture(label) {
  const root = mkdtempSync(join(tmpdir(), `template-feed-long-scroll-${label}-`));
  mkdirSync(root, { recursive: true });

  writeJson(join(root, 'completion-summary.json'), {
    exit_code: 0,
    completion_marker: 'all_tests_passed_log',
    integration_response_data: true,
  });

  writeJson(join(root, 'memory-plateau-summary.json'), {
    selected_pid: 1234,
    trend: {
      sample_count: 6,
      first_pss_kb: 101000,
      last_pss_kb: 102000,
      min_pss_kb: 100900,
      max_pss_kb: 103000,
      tail_delta_pss_kb: 512,
      plateau_likely: true,
    },
  });

  writeJson(join(root, 'integration_response_data.json'), {
    templates_feed_backend_long_scroll_memory_profile: {
      mixed: {
        loaded_item_count: 520,
        target_reached: true,
        max_duplicate_item_count: 0,
        active_video_preview_average: 2,
      },
      video_only: {
        loaded_item_count: 520,
        target_reached: true,
        max_duplicate_item_count: 0,
        active_video_preview_average: 3,
      },
    },
  });

  writeFileSync(
    join(root, 'memory-plateau-samples.csv'),
    [
      'phase,pid,total_pss_kb,total_rss_kb',
      'during-01,1234,101000,201000',
      'during-02,1234,102000,202000',
    ].join('\n') + '\n'
  );

  writeFileSync(join(root, 'template-feed-device-qa.env'), 'DEVICE_ID=test-device\nMODE=profile\n');
  return root;
}

function runPromoter(runDir, output, signoff, deviceLabel) {
  return new Promise(resolvePromise => {
    const child = spawn(process.execPath, [
      resolve(promoterPath),
      `--run-dir=${runDir}`,
      `--output=${output}`,
      `--signoff=${signoff}`,
      `--device-label=${deviceLabel}`,
    ], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', chunk => {
      stdout += chunk;
    });
    child.stderr.on('data', chunk => {
      stderr += chunk;
    });
    child.on('exit', code => {
      resolvePromise({ code, stdout, stderr });
    });
  });
}

function writeJson(path, value) {
  writeFileSync(path, JSON.stringify(value, null, 2));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
