let fallbackSequence = 0;

export function createAdminCorrelationId(): string {
  if (
    typeof globalThis.crypto !== "undefined" &&
    typeof globalThis.crypto.randomUUID === "function"
  ) {
    return globalThis.crypto.randomUUID();
  }

  if (
    typeof globalThis.crypto !== "undefined" &&
    typeof globalThis.crypto.getRandomValues === "function"
  ) {
    const bytes = new Uint8Array(16);
    globalThis.crypto.getRandomValues(bytes);
    const randomHex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
    fallbackSequence = (fallbackSequence + 1) % Number.MAX_SAFE_INTEGER;
    return `admin-${Date.now().toString(36)}-${fallbackSequence.toString(36)}-${randomHex}`;
  }

  throw new Error("Secure random source is unavailable for admin correlation id generation.");
}
