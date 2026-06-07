import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));
const loginCardPath = fileURLToPath(new URL("./login-card.tsx", import.meta.url));

describe("admin auth restore hardening", () => {
  it("clears stale sessions and redirects private routes when session restore rejects", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain(".catch(() => {\n        void logout();\n        router.replace(`/${locale}`);\n      })");
  });

  it("clears stale sessions when login-page session restore rejects", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).toContain(".catch(() => {\n        void logout();\n      })");
  });
});
