import { spawn } from "node:child_process";
import path from "node:path";

const nextPublicApiBaseUrl =
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() || "https://api.petmagic.app";

const env = {
  ...process.env,
  NEXT_PUBLIC_API_BASE_URL: nextPublicApiBaseUrl,
};

await run(process.execPath, [resolveTool("next/dist/bin/next"), "build", "--webpack"], env);

function run(command, args, envVars) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      shell: false,
      env: envVars,
      stdio: "inherit",
    });

    child.on("error", reject);

    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(" ")} exited with code ${code}`));
    });
  });
}

function resolveTool(relativePath) {
  return path.join(process.cwd(), "node_modules", relativePath);
}
