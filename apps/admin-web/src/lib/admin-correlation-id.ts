export function createAdminCorrelationId(): string {
  if (typeof globalThis.crypto !== "undefined" && typeof globalThis.crypto.randomUUID === "function") {
    return globalThis.crypto.randomUUID();
  }

  return `admin-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}
