#!/usr/bin/env node

import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const prepareUsersPath = join(scriptDir, 'prepare-watermark-qa-users.mjs');
const preflightPath = join(scriptDir, 'run-watermark-preflight-qa.mjs');
const backendPath = join(scriptDir, 'run-watermark-backend-qa.mjs');
const psqlPath = join(scriptDir, 'psql');
const psqlDockerWrapperPath = join(scriptDir, 'psql-docker-wrapper.sh');
const psqlCmdPath = join(scriptDir, 'psql.cmd');
const psqlPs1Path = join(scriptDir, 'psql.ps1');

try {
  await assertPrepareUsersHelpHasNoSideEffects();
  await assertPreflightHelpHasNoSideEffects();
  await assertPreflightSkipsMacOnlyMediaHelperOffMacOs();
  await assertPreflightFindsAndroidSdkTools();
  await assertBackendHelpHasNoSideEffects();
  assertLocalPsqlWrappersAreDocumentedAndReachable();
  await assertWindowsPsqlWrapperForwardsDockerExec();
  await assertWindowsPsqlPowerShellWrapperForwardsDockerExec();
  console.log('watermark QA help self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertPrepareUsersHelpHasNoSideEffects() {
  const fixture = mkdtempSync(join(tmpdir(), 'watermark-prepare-users-help-'));
  try {
    const outputPath = join(fixture, 'watermark-qa-users.env');
    const result = await spawnNode([prepareUsersPath, '--help'], {
      WATERMARK_QA_USERS_OUTPUT: outputPath,
    });

    assertExitCode(result, 0);
    assert(result.stdout.includes('Watermark QA user preparation.'), 'prepare-users help missing title');
    assert(result.stdout.includes('WATERMARK_QA_PASSWORD'), 'prepare-users help missing password env');
    assert(result.stdout.includes('WATERMARK_QA_PSQL_COMMAND'), 'prepare-users help missing psql command env');
    assert(result.stdout.includes('scripts\\qa\\psql.cmd'), 'prepare-users help missing Windows psql wrapper');
    assert(!existsSync(outputPath), 'prepare-users help wrote env file');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertPreflightHelpHasNoSideEffects() {
  const fixture = mkdtempSync(join(tmpdir(), 'watermark-preflight-help-'));
  try {
    const evidencePath = join(fixture, 'preflight-evidence.json');
    const result = await spawnNode([preflightPath, '--help'], {
      WATERMARK_QA_PREFLIGHT_EVIDENCE_PATH: evidencePath,
    });

    assertExitCode(result, 0);
    assert(result.stdout.includes('Watermark preflight QA runner.'), 'preflight help missing title');
    assert(result.stdout.includes('WATERMARK_QA_SKIP_BACKEND=1'), 'preflight help missing skip-backend option');
    assert(result.stdout.includes('API_BASE_URL'), 'preflight help missing backend env');
    assert(!existsSync(evidencePath), 'preflight help wrote evidence');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertPreflightSkipsMacOnlyMediaHelperOffMacOs() {
  if (process.platform === 'darwin') {
    return;
  }

  const fixture = mkdtempSync(join(tmpdir(), 'watermark-preflight-media-platform-'));
  try {
    const sdkRoot = join(fixture, 'AndroidSdk');
    const evidencePath = join(fixture, 'preflight-evidence.json');
    const emulatorLogPath = join(fixture, 'emulator.log');
    const platformToolsDir = join(sdkRoot, 'platform-tools');
    const emulatorDir = join(sdkRoot, 'emulator');
    const binDir = join(fixture, 'bin');
    mkdirSync(platformToolsDir, { recursive: true });
    mkdirSync(emulatorDir, { recursive: true });
    mkdirSync(binDir, { recursive: true });
    writeFakeCommand(platformToolsDir, 'adb', fakeAdbScript());
    writeFakeCommand(emulatorDir, 'emulator', fakeEmulatorScript());
    writeFakeCommand(binDir, 'flutter', fakeFlutterScript());

    const result = await spawnNode([preflightPath], {
      ANDROID_HOME: sdkRoot,
      ANDROID_SDK_ROOT: '',
      PATH: `${binDir}${delimiter}${process.env.PATH ?? ''}`,
      WATERMARK_QA_ANDROID_EMULATOR: 'PetMagicFakeApi35',
      WATERMARK_QA_ANDROID_BOOT_ATTEMPTS: '1',
      WATERMARK_QA_ANDROID_EMULATOR_LOG: emulatorLogPath,
      WATERMARK_QA_SKIP_BACKEND: '1',
      WATERMARK_QA_PREFLIGHT_EVIDENCE_PATH: evidencePath,
      WATERMARK_QA_COMMAND_TIMEOUT_MS: '30000',
    });

    assertExitCode(result, 0);
    const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
    const mediaCheck = evidence.checks.find(item => item.name === 'media fixtures');
    assert(mediaCheck, 'missing media fixtures evidence check');
    assert(
      mediaCheck.status === 'skipped',
      `expected media fixtures to be skipped, got ${JSON.stringify(mediaCheck)}`
    );
    assert(
      String(mediaCheck.reason).includes('requires macOS'),
      `media fixtures skip reason should mention macOS, got ${JSON.stringify(mediaCheck)}`
    );
    assertHasPassedCheck(evidence, 'mobile integration Android');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertPreflightFindsAndroidSdkTools() {
  const fixture = mkdtempSync(join(tmpdir(), 'watermark-preflight-android-sdk-'));
  try {
    const sdkRoot = join(fixture, 'AndroidSdk');
    const evidencePath = join(fixture, 'preflight-evidence.json');
    const emulatorLogPath = join(fixture, 'emulator.log');
    const platformToolsDir = join(sdkRoot, 'platform-tools');
    const emulatorDir = join(sdkRoot, 'emulator');
    const binDir = join(fixture, 'bin');
    mkdirSync(platformToolsDir, { recursive: true });
    mkdirSync(emulatorDir, { recursive: true });
    mkdirSync(binDir, { recursive: true });
    writeFakeCommand(platformToolsDir, 'adb', fakeAdbScript());
    writeFakeCommand(emulatorDir, 'emulator', fakeEmulatorScript());
    writeFakeCommand(binDir, 'flutter', fakeFlutterScript());

    const result = await spawnNode([preflightPath], {
      ANDROID_HOME: sdkRoot,
      ANDROID_SDK_ROOT: '',
      PATH: `${binDir}${delimiter}${process.env.PATH ?? ''}`,
      WATERMARK_QA_ANDROID_EMULATOR: 'PetMagicFakeApi35',
      WATERMARK_QA_ANDROID_BOOT_ATTEMPTS: '1',
      WATERMARK_QA_ANDROID_EMULATOR_LOG: emulatorLogPath,
      WATERMARK_QA_SKIP_MEDIA: '1',
      WATERMARK_QA_SKIP_BACKEND: '1',
      WATERMARK_QA_PREFLIGHT_EVIDENCE_PATH: evidencePath,
      WATERMARK_QA_COMMAND_TIMEOUT_MS: '30000',
    });

    assertExitCode(result, 0);
    const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
    assertHasPassedCheck(evidence, 'android emulator launch');
    assertHasPassedCheck(evidence, 'android emulator boot');
    assertHasPassedCheck(evidence, 'flutter device discovery');
    assertHasPassedCheck(evidence, 'mobile integration Android');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertBackendHelpHasNoSideEffects() {
  const fixture = mkdtempSync(join(tmpdir(), 'watermark-backend-help-'));
  try {
    const evidencePath = join(fixture, 'backend-evidence.json');
    const result = await spawnNode([backendPath, '-h'], {
      WATERMARK_QA_EVIDENCE_PATH: evidencePath,
    });

    assertExitCode(result, 0);
    assert(result.stdout.includes('Watermark backend QA runner.'), 'backend help missing title');
    assert(result.stdout.includes('DATABASE_URL'), 'backend help missing database env');
    assert(result.stdout.includes('WATERMARK_QA_EVIDENCE_PATH'), 'backend help missing evidence env');
    assert(result.stdout.includes('WATERMARK_QA_PSQL_COMMAND'), 'backend help missing psql command env');
    assert(result.stdout.includes('scripts\\qa\\psql.cmd'), 'backend help missing Windows psql wrapper');
    assert(!existsSync(evidencePath), 'backend help wrote evidence');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

function assertLocalPsqlWrappersAreDocumentedAndReachable() {
  assert(existsSync(psqlPath), 'missing POSIX psql wrapper');
  assert(existsSync(psqlDockerWrapperPath), 'missing POSIX Docker psql wrapper target');
  assert(existsSync(psqlCmdPath), 'missing Windows cmd psql wrapper');
  assert(existsSync(psqlPs1Path), 'missing Windows PowerShell psql wrapper');

  const prepareUsersSource = readFileSync(prepareUsersPath, 'utf8');
  const backendSource = readFileSync(backendPath, 'utf8');
  const expectedResolver = 'return { command: "bash", args: [command] };';

  assert(
    prepareUsersSource.includes(expectedResolver),
    'prepare-users should run scripts/qa/psql through bash on non-Windows'
  );
  assert(
    backendSource.includes(expectedResolver),
    'backend QA should run scripts/qa/psql through bash on non-Windows'
  );
}

async function assertWindowsPsqlWrapperForwardsDockerExec() {
  if (process.platform !== 'win32') {
    return;
  }

  const fixture = mkdtempSync(join(tmpdir(), 'watermark-psql-wrapper-'));
  try {
    const binDir = join(fixture, 'bin');
    const argsPath = join(fixture, 'docker-args.txt');
    const stdinPath = join(fixture, 'docker-stdin.sql');
    const sqlPath = join(fixture, 'seed.sql');
    mkdirSync(binDir, { recursive: true });
    writeFileSync(sqlPath, 'select 1;\n');
    writeFakeCommand(binDir, 'docker', fakeDockerScript());

    const result = await spawnCommand(psqlCmdPath, [
      'postgresql://petmagic_user:unused@docker/petmagic_db',
      '-v',
      "public_base_url='http://localhost:5001'",
      '-f',
      sqlPath,
    ], {
      PATH: `${binDir}${delimiter}${process.env.PATH ?? ''}`,
      WATERMARK_QA_FAKE_DOCKER_ARGS: argsPath,
      WATERMARK_QA_FAKE_DOCKER_STDIN: stdinPath,
    });

    assertExitCode(result, 0);
    const dockerArgs = readFileSync(argsPath, 'utf8');
    const stdin = readFileSync(stdinPath, 'utf8');
    assert(dockerArgs.includes('compose -f'), `docker args missing compose invocation: ${dockerArgs}`);
    assert(dockerArgs.includes(' exec -T '), `docker args missing docker compose exec: ${dockerArgs}`);
    assert(dockerArgs.includes(' psql '), `docker args missing psql invocation: ${dockerArgs}`);
    assert(dockerArgs.includes('-v'), `docker args missing -v passthrough: ${dockerArgs}`);
    assert(dockerArgs.includes('public_base_url'), `docker args missing variable passthrough: ${dockerArgs}`);
    assert(!dockerArgs.includes('postgresql://'), `docker args should not forward DATABASE_URL: ${dockerArgs}`);
    assert(stdin.includes('select 1;'), `docker stdin missing SQL file contents: ${stdin}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertWindowsPsqlPowerShellWrapperForwardsDockerExec() {
  if (process.platform !== 'win32') {
    return;
  }

  const fixture = mkdtempSync(join(tmpdir(), 'watermark-psql-ps-wrapper-'));
  try {
    const binDir = join(fixture, 'bin');
    const argsPath = join(fixture, 'docker-args.txt');
    const stdinPath = join(fixture, 'docker-stdin.sql');
    const sqlPath = join(fixture, 'seed.sql');
    mkdirSync(binDir, { recursive: true });
    writeFileSync(sqlPath, 'select 2;\n');
    writeFakeCommand(binDir, 'docker', fakeDockerScript());

    const result = await spawnCommand('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      psqlPs1Path,
      'postgresql://petmagic_user:unused@docker/petmagic_db',
      '-v',
      "public_base_url='http://localhost:5001'",
      '-f',
      sqlPath,
    ], {
      PATH: `${binDir}${delimiter}${process.env.PATH ?? ''}`,
      WATERMARK_QA_FAKE_DOCKER_ARGS: argsPath,
      WATERMARK_QA_FAKE_DOCKER_STDIN: stdinPath,
    });

    assertExitCode(result, 0);
    const dockerArgs = readFileSync(argsPath, 'utf8');
    const stdin = readFileSync(stdinPath, 'utf8');
    assert(dockerArgs.includes('-v'), `PowerShell wrapper docker args missing -v: ${dockerArgs}`);
    assert(dockerArgs.includes('public_base_url'), `PowerShell wrapper docker args missing variable: ${dockerArgs}`);
    assert(!dockerArgs.includes('postgresql://'), `PowerShell wrapper should not forward DATABASE_URL: ${dockerArgs}`);
    assert(stdin.includes('select 2;'), `PowerShell wrapper stdin missing SQL file contents: ${stdin}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

function writeFakeCommand(directory, name, content) {
  const extension = process.platform === 'win32' ? '.cmd' : '';
  const path = join(directory, `${name}${extension}`);
  writeFileSync(path, content);
  if (process.platform !== 'win32') {
    chmodSync(path, 0o755);
  }
}

function fakeAdbScript() {
  return process.platform === 'win32'
    ? '@echo off\r\necho 1\r\n'
    : '#!/bin/sh\necho 1\n';
}

function fakeEmulatorScript() {
  return process.platform === 'win32'
    ? '@echo off\r\nexit /b 0\r\n'
    : '#!/bin/sh\nexit 0\n';
}

function fakeFlutterScript() {
  if (process.platform === 'win32') {
    return [
      '@echo off',
      'if "%1"=="devices" (',
      '  echo [{"id":"android-fake-device","targetPlatform":"android-arm64"}]',
      '  exit /b 0',
      ')',
      'if "%1"=="test" exit /b 0',
      'exit /b 1',
      '',
    ].join('\r\n');
  }

  return [
    '#!/bin/sh',
    'if [ "$1" = "devices" ]; then',
    '  echo \'[{"id":"android-fake-device","targetPlatform":"android-arm64"}]\'',
    '  exit 0',
    'fi',
    'if [ "$1" = "test" ]; then',
    '  exit 0',
    'fi',
    'exit 1',
    '',
  ].join('\n');
}

function fakeDockerScript() {
  return process.platform === 'win32'
    ? [
        '@echo off',
        'echo %* > "%WATERMARK_QA_FAKE_DOCKER_ARGS%"',
        'more > "%WATERMARK_QA_FAKE_DOCKER_STDIN%"',
        'exit /b 0',
        '',
      ].join('\r\n')
    : [
        '#!/bin/sh',
        'printf "%s\\n" "$*" > "$WATERMARK_QA_FAKE_DOCKER_ARGS"',
        'cat > "$WATERMARK_QA_FAKE_DOCKER_STDIN"',
        '',
      ].join('\n');
}

function assertHasPassedCheck(evidence, name) {
  const check = evidence.checks.find(item => item.name === name);
  assert(check, `missing evidence check: ${name}`);
  assert(
    check.status === 'passed',
    `expected ${name} to pass, got ${JSON.stringify(check)}`
  );
}

function spawnNode(args, extraEnv = {}) {
  return spawnCommand(process.execPath, args, extraEnv);
}

function spawnCommand(command, args, extraEnv = {}) {
  return new Promise((resolvePromise) => {
    const commandLine = resolveSpawnCommand(command, args);
    const child = spawn(commandLine.command, commandLine.args, {
      cwd: repoRoot,
      env: { ...process.env, ...extraEnv },
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

function resolveSpawnCommand(command, args) {
  if (process.platform !== 'win32' || !command.toLowerCase().endsWith('.cmd')) {
    return { command, args };
  }

  return {
    command: process.env.ComSpec || 'cmd.exe',
    args: ['/d', '/c', command, ...args],
  };
}

function assertExitCode(result, expected) {
  assert(
    result.code === expected,
    `expected exit ${expected}, got ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
