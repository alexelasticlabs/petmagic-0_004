import net from "node:net";
import { spawn } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import { withE2eBuildIsolation } from "./e2e-build-isolation.mjs";

const startPort = 3100;
const endPort = 3199;
const requestedPort = process.env.PLAYWRIGHT_PORT;
const port = requestedPort
  ? await requireAvailablePort(validatePort(requestedPort))
  : await findAvailablePort();
const appRoot = fileURLToPath(new URL("..", import.meta.url));
const playwrightCli = fileURLToPath(
  new URL("../node_modules/@playwright/test/cli.js", import.meta.url)
);
const nextCli = fileURLToPath(new URL("../node_modules/next/dist/bin/next", import.meta.url));
const buildScript = fileURLToPath(new URL("./build.mjs", import.meta.url));

await withE2eBuildIsolation(
  {
    appRoot,
    requestedBuildDirectory: process.env.NEXT_E2E_DIST_DIR,
    baseEnvironment: process.env,
  },
  async ({ environment }) => {
    const e2eEnvironment = {
      ...environment,
      PLAYWRIGHT_PORT: String(port),
      PLAYWRIGHT_EXTERNAL_SERVER: "1",
      NEXT_PUBLIC_API_BASE_URL: "https://api.petmagic.test",
      NEXT_PUBLIC_E2E_DISABLE_SUPPORT_REALTIME: "1",
      ADMIN_MEDIA_ORIGINS: "https://cdn.petgpt.app",
    };

    await runE2eLifecycle(e2eEnvironment);
  }
);

async function runE2eLifecycle(e2eEnvironment) {
  let server;
  let lifecycleError;

  try {
    await run(process.execPath, [buildScript], e2eEnvironment);

    server = spawn(
      process.execPath,
      [nextCli, "start", "--hostname", "127.0.0.1", "--port", String(port)],
      {
        stdio: ["ignore", "pipe", "pipe"],
        env: e2eEnvironment,
        shell: false,
      }
    );
    let serverSpawnError;
    server.once("error", (error) => {
      serverSpawnError = error;
    });
    const serverOutput = monitorServerOutput(server);

    await waitForServer(
      `http://127.0.0.1:${port}/en`,
      server,
      serverOutput,
      () => serverSpawnError
    );
    await run(process.execPath, [playwrightCli, "test", ...process.argv.slice(2)], e2eEnvironment);
  } catch (error) {
    lifecycleError = error;
  }

  let stopError;
  if (server) {
    try {
      await stopOwnedServer(server);
    } catch (error) {
      stopError = error;
    }
  }

  if (lifecycleError) {
    if (stopError) {
      throw new AggregateError(
        [lifecycleError, stopError],
        "The E2E lifecycle failed and its Next server could not be stopped."
      );
    }

    throw lifecycleError;
  }

  if (stopError) {
    throw stopError;
  }
}

function run(command, args, env, stdio = "inherit") {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      shell: false,
      env,
      stdio,
    });

    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(" ")} exited with code ${code}`));
    });
  });
}

async function waitForServer(url, child, output, getSpawnError, timeoutMs = 120_000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    const spawnError = getSpawnError();
    if (spawnError) {
      throw spawnError;
    }

    if (hasExited(child)) {
      throw new Error(`Next E2E server exited before becoming ready (${describeExit(child)}).`);
    }

    if (output.isReady()) {
      try {
        const response = await fetch(url, {
          redirect: "manual",
          signal: AbortSignal.timeout(2_000),
        });
        if (response.status > 0 && !hasExited(child)) {
          return;
        }
      } catch {
        // Next reported readiness, but the route is not accepting requests yet.
      }
    }

    await delay(250);
  }

  throw new Error(`Next E2E server did not become ready within ${timeoutMs}ms.`);
}

async function stopOwnedServer(child) {
  if (hasExited(child) || child.pid === undefined) {
    return;
  }

  const exited = waitForExit(child, 5_000);
  child.kill();
  if (await exited) {
    return;
  }

  if (hasExited(child)) {
    return;
  }

  child.kill("SIGKILL");
  if (!(await waitForExit(child, 5_000))) {
    throw new Error(`Unable to stop owned Next E2E server process ${child.pid}.`);
  }
}

function waitForExit(child, timeoutMs) {
  if (hasExited(child)) {
    return Promise.resolve(true);
  }

  return new Promise((resolve) => {
    const timeoutId = setTimeout(() => {
      child.removeListener("exit", handleExit);
      resolve(false);
    }, timeoutMs);

    function handleExit() {
      clearTimeout(timeoutId);
      resolve(true);
    }

    child.once("exit", handleExit);
  });
}

function monitorServerOutput(child) {
  let combinedOutput = "";

  const forward = (stream, destination) => {
    stream?.on("data", (chunk) => {
      destination.write(chunk);
      combinedOutput = `${combinedOutput}${chunk.toString("utf8")}`.slice(-32_768);
    });
  };

  forward(child.stdout, process.stdout);
  forward(child.stderr, process.stderr);

  return {
    isReady: () => /\bReady in\b/i.test(combinedOutput),
  };
}

function hasExited(child) {
  return child.exitCode !== null || child.signalCode !== null;
}

function describeExit(child) {
  if (child.exitCode !== null) {
    return `code ${child.exitCode}`;
  }

  return `signal ${child.signalCode ?? "unknown"}`;
}

function validatePort(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1024 || parsed > 65535) {
    throw new Error("PLAYWRIGHT_PORT must be a valid unprivileged TCP port.");
  }

  return parsed;
}

async function requireAvailablePort(port) {
  if (!(await isAvailable(port))) {
    throw new Error(`PLAYWRIGHT_PORT ${port} is already in use.`);
  }

  return port;
}

async function findAvailablePort() {
  for (let candidatePort = startPort; candidatePort <= endPort; candidatePort += 1) {
    if (await isAvailable(candidatePort)) {
      return candidatePort;
    }
  }

  throw new Error(`No available Playwright port was found in ${startPort}-${endPort}.`);
}

function isAvailable(candidatePort) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once("error", () => resolve(false));
    server.once("listening", () => {
      server.close(() => resolve(true));
    });
    server.listen({ host: "127.0.0.1", port: candidatePort, exclusive: true });
  });
}
