#!/usr/bin/env node

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';

const args = parseArgs(process.argv.slice(2));

if (args.help) {
  printHelp();
  process.exit(0);
}

const runDir = args.runDir;
if (!runDir) {
  fail('Missing --run-dir.');
}

const signoff = args.signoff || 'pending';
if (!['pending', 'weak-device', 'low-memory-emulator'].includes(signoff)) {
  fail('Unsupported --signoff. Use pending, weak-device, or low-memory-emulator.');
}

const output = args.output || join('artifacts', 'templates-feed-tz1-8-long-scroll-500-2026-07-02.md');
const deviceLabel = args.deviceLabel || readDeviceLabel(runDir);

const completion = readJson(join(runDir, 'completion-summary.json'));
const memory = readJson(join(runDir, 'memory-plateau-summary.json'));
const responseData = readJson(join(runDir, 'integration_response_data.json'));
const sampleCsv = readText(join(runDir, 'memory-plateau-samples.csv'));

const longScroll = responseData.templates_feed_backend_long_scroll_memory_profile;
if (!longScroll) {
  fail('integration_response_data.json does not contain templates_feed_backend_long_scroll_memory_profile.');
}

const mixed = longScroll.mixed || {};
const videoOnly = longScroll.video_only || {};
const trend = memory.trend || {};

const checks = [
  ['completion.exit_code_zero', completion.exit_code === 0],
  ['completion.all_tests_passed', completion.completion_marker === 'all_tests_passed_log'],
  ['memory.plateau_likely', trend.plateau_likely === true],
  ['memory.sample_count_at_least_5', Number(trend.sample_count) >= 5],
  ['long_scroll.mixed_500_plus', Number(mixed.loaded_item_count) >= 500 && mixed.target_reached === true],
  ['long_scroll.video_only_500_plus', Number(videoOnly.loaded_item_count) >= 500 && videoOnly.target_reached === true],
  [
    'active_preview.video_only_exceeds_mixed',
    Number(videoOnly.active_video_preview_average) > Number(mixed.active_video_preview_average),
  ],
];

const failedChecks = checks.filter(([, ok]) => !ok).map(([name]) => name);
if (failedChecks.length > 0) {
  fail(`Run artifacts failed validation: ${failedChecks.join(', ')}`);
}

const signoffLine = signoff === 'weak-device'
  ? 'Weak-device release signoff: PASS'
  : signoff === 'low-memory-emulator'
    ? 'Low-memory emulator signoff: PASS'
    : 'Weak-device release signoff: PENDING';

const markdown = renderMarkdown({
  runId: basename(runDir),
  runDir,
  deviceLabel,
  signoffLine,
  completion,
  trend,
  memory,
  mixed,
  videoOnly,
  sampleCsv,
});

writeFileSync(output, markdown);
console.log(`Wrote ${output}`);

function renderMarkdown({
  runId,
  runDir,
  deviceLabel,
  signoffLine,
  completion,
  trend,
  memory,
  mixed,
  videoOnly,
  sampleCsv,
}) {
  const lines = [
    '# Templates Feed Long-Scroll 500+ Runtime Artifact - 2026-07-02',
    '',
    `Run id: \`${runId}\``,
    '',
    `Device: \`${deviceLabel}\``,
    '',
    `Raw artifact dir: \`${runDir.replaceAll('\\', '/')}\``,
    '',
    signoffLine,
    '',
    'Result:',
    '',
    `- completion: \`exit_code=${completion.exit_code}\`, \`completion_marker=${completion.completion_marker}\``,
    `- memory: selected pid \`${memory.selected_pid}\`, ${trend.sample_count} selected PSS samples, \`plateau_likely=${String(trend.plateau_likely)}\``,
    `- PSS: first \`${trend.first_pss_kb}KB\`, last \`${trend.last_pss_kb}KB\`, min \`${trend.min_pss_kb}KB\`, max \`${trend.max_pss_kb}KB\`, tail delta \`${trend.tail_delta_pss_kb}KB\``,
    `- loaded items: mixed \`${mixed.loaded_item_count}\`, video-only \`${videoOnly.loaded_item_count}\``,
    `- active video preview average: mixed \`${formatDecimal(mixed.active_video_preview_average)}\`, video-only \`${formatDecimal(videoOnly.active_video_preview_average)}\``,
    `- duplicate items: mixed \`${mixed.max_duplicate_item_count}\`, video-only \`${videoOnly.max_duplicate_item_count}\``,
    '',
  ];

  if (signoffLine.endsWith('PENDING')) {
    lines.push(
      'Note: this artifact is not final Task 2 release evidence until rerun on a weak device or constrained-memory emulator and promoted with `--signoff=weak-device` or `--signoff=low-memory-emulator`.',
      ''
    );
  }

  lines.push('## Memory Samples', '', '```csv', sampleCsv.trimEnd(), '```', '');
  return lines.join('\n');
}

function readJson(path) {
  if (!existsSync(path)) {
    fail(`Missing required artifact: ${path}`);
  }

  return JSON.parse(readFileSync(path, 'utf8'));
}

function readText(path) {
  if (!existsSync(path)) {
    fail(`Missing required artifact: ${path}`);
  }

  return readFileSync(path, 'utf8');
}

function readDeviceLabel(runDir) {
  const envPath = join(runDir, 'template-feed-device-qa.env');
  if (!existsSync(envPath)) {
    return 'unknown';
  }

  const envText = readFileSync(envPath, 'utf8');
  const deviceId = envText.match(/^DEVICE_ID=(.+)$/m)?.[1]?.trim();
  const mode = envText.match(/^MODE=(.+)$/m)?.[1]?.trim();
  return [deviceId, mode].filter(Boolean).join(' / ') || 'unknown';
}

function parseArgs(argv) {
  const parsed = {};
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      parsed.help = true;
      continue;
    }

    const match = arg.match(/^--([^=]+)=(.*)$/);
    if (!match) {
      fail(`Unsupported argument: ${arg}`);
    }

    const key = match[1].replace(/-([a-z])/g, (_, char) => char.toUpperCase());
    parsed[key] = match[2];
  }
  return parsed;
}

function formatDecimal(value) {
  return Number(value).toFixed(1);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function printHelp() {
  console.log(`
Promote a raw mobile long-scroll QA run into the curated TZ1-8 Task 2 artifact.

Required:
  --run-dir=<path>                         Raw artifacts/mobile-template-feed/<run-id> directory.

Optional:
  --output=<path>                          Output markdown path. Defaults to artifacts/templates-feed-tz1-8-long-scroll-500-2026-07-02.md.
  --signoff=pending|weak-device|low-memory-emulator
                                           Use pending for ordinary-device runs. Use weak-device or low-memory-emulator only after running on that target class.
  --device-label=<text>                    Human-readable device/emulator label for the curated artifact.

Example:
  node scripts/qa/promote-template-feed-long-scroll-artifact.mjs --run-dir=artifacts/mobile-template-feed/tz1-8-long-scroll-500-low-memory-20260702 --signoff=low-memory-emulator --device-label="Pixel_3a_API_35 low-memory emulator"
`);
}
