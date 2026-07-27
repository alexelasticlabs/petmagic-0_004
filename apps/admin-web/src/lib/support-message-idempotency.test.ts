import { webcrypto } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  clearSupportAttachmentIdempotencyKey,
  clearSupportMessageIdempotencyKey,
  getOrCreateSupportAttachmentIdempotencyKey,
  getOrCreateSupportMessageIdempotencyKey,
} from "@/lib/support-message-idempotency";

class MemoryStorage {
  private readonly values = new Map<string, string>();

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }

  removeItem(key: string): void {
    this.values.delete(key);
  }

  get entries(): readonly [string, string][] {
    return [...this.values.entries()];
  }
}

function createTestAttachment(contents: string, name: string): File {
  const bytes = new TextEncoder().encode(contents);
  return {
    arrayBuffer: async () => bytes.slice().buffer as ArrayBuffer,
    lastModified: 1_727_000_000_000,
    name,
    size: bytes.byteLength,
    type: "image/png",
  } as File;
}

describe("support message idempotency", () => {
  beforeEach(() => {
    vi.stubGlobal("crypto", webcrypto);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("reuses a short-lived key for the same text intent without storing the reply body", async () => {
    const storage = new MemoryStorage();
    vi.stubGlobal("window", { sessionStorage: storage });

    const firstKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "A private reply for user@example.com",
      "message-1"
    );
    const secondKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "A private reply for user@example.com",
      "message-1"
    );

    expect(secondKey).toBe(firstKey);
    const serializedStorage = JSON.stringify(storage.entries);
    expect(serializedStorage).not.toContain("A private reply");
    expect(serializedStorage).not.toContain("user@example.com");

    await clearSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "A private reply for user@example.com",
      "message-1"
    );
    expect(storage.entries).toEqual([]);
  });

  it("creates a distinct key when the reply intent changes", async () => {
    const storage = new MemoryStorage();
    vi.stubGlobal("window", { sessionStorage: storage });

    const firstKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "First reply"
    );
    const secondKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "Second reply"
    );

    expect(secondKey).not.toBe(firstKey);
  });

  it("does not reuse a pending reply key after the support operator changes", async () => {
    const storage = new MemoryStorage();
    vi.stubGlobal("window", { sessionStorage: storage });

    const firstKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-a",
      "ticket-1",
      "Same reply"
    );
    const secondKey = await getOrCreateSupportMessageIdempotencyKey(
      "admin-b",
      "ticket-1",
      "Same reply"
    );

    expect(secondKey).not.toBe(firstKey);
    expect(storage.entries).toHaveLength(2);

    await clearSupportMessageIdempotencyKey("admin-a", "ticket-1", "Same reply");
    expect(storage.entries).toHaveLength(1);
  });

  it("reuses a short-lived attachment key after reload without storing file data or name", async () => {
    const storage = new MemoryStorage();
    vi.stubGlobal("window", { sessionStorage: storage });
    const firstAttachment = createTestAttachment(
      "private attachment bytes",
      "customer-medical-photo.png"
    );
    const secondAttachment = createTestAttachment(
      "private attachment bytes",
      "customer-medical-photo.png"
    );

    const firstKey = await getOrCreateSupportAttachmentIdempotencyKey(
      "admin-a",
      "ticket-1",
      firstAttachment,
      "Please see the attachment",
      "message-1"
    );
    const secondKey = await getOrCreateSupportAttachmentIdempotencyKey(
      "admin-a",
      "ticket-1",
      secondAttachment,
      "Please see the attachment",
      "message-1"
    );

    expect(secondKey).toBe(firstKey);
    const serializedStorage = JSON.stringify(storage.entries);
    expect(serializedStorage).not.toContain("private attachment bytes");
    expect(serializedStorage).not.toContain("customer-medical-photo.png");
    expect(serializedStorage).not.toContain("Please see the attachment");

    await clearSupportAttachmentIdempotencyKey(
      "admin-a",
      "ticket-1",
      secondAttachment,
      "Please see the attachment",
      "message-1"
    );
    expect(storage.entries).toEqual([]);
  });
});
