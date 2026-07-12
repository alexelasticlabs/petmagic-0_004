import net from "node:net";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const startPort = 3100;
const endPort = 3199;
const requestedPort = process.env.PLAYWRIGHT_PORT;
const port = requestedPort ? validatePort(requestedPort) : await findAvailablePort();
const playwrightCli = fileURLToPath(
  new URL("../node_modules/@playwright/test/cli.js", import.meta.url)
);
const child = spawn(process.execPath, [playwrightCli, "test", ...process.argv.slice(2)], {
  stdio: "inherit",
  env: { ...process.env, PLAYWRIGHT_PORT: String(port) },
});

child.once("error", (error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});

child.once("exit", (code) => {
  process.exitCode = code ?? 1;
});

function validatePort(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1024 || parsed > 65535) {
    throw new Error("PLAYWRIGHT_PORT must be a valid unprivileged TCP port.");
  }

  return parsed;
}

async function findAvailablePort() {
  for (let port = startPort; port <= endPort; port += 1) {
    if (await isAvailable(port)) {
      return port;
    }
  }

  throw new Error(`No available Playwright port was found in ${startPort}-${endPort}.`);
}

function isAvailable(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once("error", () => resolve(false));
    server.once("listening", () => {
      server.close(() => resolve(true));
    });
    server.listen({ host: "127.0.0.1", port, exclusive: true });
  });
}
