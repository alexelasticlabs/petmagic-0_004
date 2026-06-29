import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';

const nextPublicApiBaseUrl =
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  'https://api.petmagic.app';

const env = {
  ...process.env,
  NEXT_PUBLIC_API_BASE_URL: nextPublicApiBaseUrl,
};

await resetGeneratedTypeArtifacts();
await run(process.execPath, [resolveTool('next/dist/bin/next'), 'typegen'], env);
await run(process.execPath, [resolveTool('typescript/bin/tsc'), '--noEmit'], env);

function run(command, args, envVars) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      shell: false,
      env: envVars,
      stdio: 'inherit',
    });

    child.on('error', reject);

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
    });
  });
}

function resolveTool(relativePath) {
  return path.join(process.cwd(), 'node_modules', relativePath);
}

async function resetGeneratedTypeArtifacts() {
  await Promise.all([
    fs.rm(path.join(process.cwd(), '.next', 'types'), {
      force: true,
      recursive: true,
    }),
    fs.rm(path.join(process.cwd(), '.next', 'dev', 'types'), {
      force: true,
      recursive: true,
    }),
    fs.rm(path.join(process.cwd(), 'tsconfig.tsbuildinfo'), {
      force: true,
    }),
  ]);
}
