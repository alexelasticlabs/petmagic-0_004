import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const targets = new Map([
  [
    "templates",
    {
      spec: "templates-catalog.spec.ts",
      grep: "Templates structural layout at 1536x1024",
    },
  ],
]);
const requestedArguments = process.argv.slice(2);

if (requestedArguments.includes("--help")) {
  process.stdout.write(
    "Usage: npm run ui:verify -- [templates] [Playwright options]\n" +
      "Defaults to the Templates desktop layout verification.\n"
  );
  process.exit(0);
}

const requestedTarget = requestedArguments[0]?.startsWith("--")
  ? "templates"
  : (requestedArguments.shift() ?? "templates");
const target = targets.get(requestedTarget);

if (!target) {
  throw new Error(
    `Unknown UI verification target "${requestedTarget}". Available targets: ${[
      ...targets.keys(),
    ].join(", ")}.`
  );
}

const appRoot = fileURLToPath(new URL("..", import.meta.url));
const e2eLauncher = fileURLToPath(new URL("./test-e2e.mjs", import.meta.url));
const child = spawn(
  process.execPath,
  [e2eLauncher, target.spec, "--project", "chromium", "--grep", target.grep, ...requestedArguments],
  {
    cwd: appRoot,
    env: process.env,
    shell: false,
    stdio: "inherit",
  }
);

child.once("error", (error) => {
  throw error;
});
child.once("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }

  process.exitCode = code ?? 1;
});
