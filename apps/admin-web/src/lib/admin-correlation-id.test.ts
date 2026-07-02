import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it } from "vitest";

import { createAdminCorrelationId } from "./admin-correlation-id";

const sourcePath = fileURLToPath(new URL("./admin-correlation-id.ts", import.meta.url));
const originalCryptoDescriptor = Object.getOwnPropertyDescriptor(globalThis, "crypto");

describe("admin correlation ids", () => {
  afterEach(() => {
    if (originalCryptoDescriptor) {
      Object.defineProperty(globalThis, "crypto", originalCryptoDescriptor);
    }
  });

  it("uses Web Crypto without Math.random fallback", () => {
    const source = readFileSync(sourcePath, "utf8");
    const id = createAdminCorrelationId();

    expect(id).toBeTruthy();
    expect(source).toContain("globalThis.crypto");
    expect(source).toContain("randomUUID");
    expect(source).toContain("getRandomValues");
    expect(source).not.toContain("Math.random");
  });

  it("falls back to getRandomValues when randomUUID is unavailable", () => {
    Object.defineProperty(globalThis, "crypto", {
      configurable: true,
      value: {
        getRandomValues(values: Uint8Array) {
          values.fill(0xab);
          return values;
        },
      },
    });

    expect(createAdminCorrelationId()).toMatch(/^admin-[a-z0-9]+-[a-z0-9]+-(ab){16}$/);
  });
});
