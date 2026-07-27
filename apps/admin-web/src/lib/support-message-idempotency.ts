import { createAdminCorrelationId } from "@/lib/admin-correlation-id";

const STORAGE_VERSION = "v2";
const STORAGE_TTL_MS = 30 * 60_000;
const MAX_KEY_LENGTH = 128;

type StoredSupportMessageIntent = {
  version: typeof STORAGE_VERSION;
  createdAtMs: number;
  draftDigest: string;
  idempotencyKey: string;
};

function getStorageKey(actorId: string, conversationId: string): string {
  return [
    "petmagic_admin_support_message_intent",
    STORAGE_VERSION,
    encodeURIComponent(actorId),
    encodeURIComponent(conversationId),
  ].join(":");
}

function getSessionStorage(): Storage | null {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    return window.sessionStorage;
  } catch {
    return null;
  }
}

function isStoredSupportMessageIntent(value: unknown): value is StoredSupportMessageIntent {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Partial<StoredSupportMessageIntent>;
  return (
    candidate.version === STORAGE_VERSION &&
    typeof candidate.createdAtMs === "number" &&
    Number.isFinite(candidate.createdAtMs) &&
    typeof candidate.draftDigest === "string" &&
    candidate.draftDigest.length === 64 &&
    typeof candidate.idempotencyKey === "string" &&
    candidate.idempotencyKey.length > 0 &&
    candidate.idempotencyKey.length <= MAX_KEY_LENGTH
  );
}

async function createDraftDigest(value: string): Promise<string | null> {
  if (!globalThis.crypto?.subtle) {
    return null;
  }

  try {
    const bytes = new TextEncoder().encode(value);
    const hash = await globalThis.crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, "0")).join("");
  } catch {
    return null;
  }
}

async function getAttachmentIntentToken(
  attachment: File,
  body: string,
  replyToMessageId?: string | null
): Promise<string | null> {
  if (!globalThis.crypto?.subtle) {
    return null;
  }

  try {
    const fileBytes = await attachment.arrayBuffer();
    const fileHash = await globalThis.crypto.subtle.digest("SHA-256", fileBytes);
    const fileDigest = Array.from(new Uint8Array(fileHash), (byte) =>
      byte.toString(16).padStart(2, "0")
    ).join("");

    return createDraftDigest(
      JSON.stringify({
        body: body.trim(),
        fileDigest,
        fileName: attachment.name,
        fileSize: attachment.size,
        fileType: attachment.type,
        lastModified: attachment.lastModified,
        replyToMessageId: replyToMessageId?.trim() || null,
      })
    );
  } catch {
    return null;
  }
}

async function getDraftDigest(
  actorId: string,
  conversationId: string,
  body: string,
  replyToMessageId?: string | null
): Promise<string | null> {
  return createDraftDigest(
    JSON.stringify({
      actorId,
      body: body.trim(),
      conversationId,
      replyToMessageId: replyToMessageId?.trim() || null,
    })
  );
}

function removeStoredIntent(storage: Storage, key: string): void {
  try {
    storage.removeItem(key);
  } catch {
    // sessionStorage is an optional recovery layer; never block a support reply when it is unavailable.
  }
}

export async function getOrCreateSupportMessageIdempotencyKey(
  actorId: string,
  conversationId: string,
  body: string,
  replyToMessageId?: string | null
): Promise<string> {
  const idempotencyKey = `support-message:${createAdminCorrelationId()}`;
  const storage = getSessionStorage();
  const normalizedActorId = actorId.trim();
  const draftDigest = await getDraftDigest(
    normalizedActorId,
    conversationId,
    body,
    replyToMessageId
  );
  if (!storage || !draftDigest || !normalizedActorId) {
    return idempotencyKey;
  }

  const storageKey = getStorageKey(normalizedActorId, conversationId);
  try {
    const rawStoredIntent = storage.getItem(storageKey);
    if (rawStoredIntent) {
      const storedIntent = JSON.parse(rawStoredIntent) as unknown;
      if (
        isStoredSupportMessageIntent(storedIntent) &&
        storedIntent.draftDigest === draftDigest &&
        Date.now() - storedIntent.createdAtMs >= 0 &&
        Date.now() - storedIntent.createdAtMs <= STORAGE_TTL_MS
      ) {
        return storedIntent.idempotencyKey;
      }
    }

    storage.setItem(
      storageKey,
      JSON.stringify({
        version: STORAGE_VERSION,
        createdAtMs: Date.now(),
        draftDigest,
        idempotencyKey,
      } satisfies StoredSupportMessageIntent)
    );
  } catch {
    // The API request is still safe within the active view even if storage is blocked or full.
  }

  return idempotencyKey;
}

export async function clearSupportMessageIdempotencyKey(
  actorId: string,
  conversationId: string,
  body: string,
  replyToMessageId?: string | null
): Promise<void> {
  const storage = getSessionStorage();
  const normalizedActorId = actorId.trim();
  const draftDigest = await getDraftDigest(
    normalizedActorId,
    conversationId,
    body,
    replyToMessageId
  );
  if (!storage || !draftDigest || !normalizedActorId) {
    return;
  }

  const storageKey = getStorageKey(normalizedActorId, conversationId);
  try {
    const rawStoredIntent = storage.getItem(storageKey);
    const storedIntent = rawStoredIntent ? (JSON.parse(rawStoredIntent) as unknown) : null;
    if (isStoredSupportMessageIntent(storedIntent) && storedIntent.draftDigest === draftDigest) {
      removeStoredIntent(storage, storageKey);
    }
  } catch {
    removeStoredIntent(storage, storageKey);
  }
}

export async function getOrCreateSupportAttachmentIdempotencyKey(
  actorId: string,
  conversationId: string,
  attachment: File,
  body: string,
  replyToMessageId?: string | null
): Promise<string> {
  const attachmentIntentToken = await getAttachmentIntentToken(attachment, body, replyToMessageId);
  if (!attachmentIntentToken) {
    return `support-attachment:${createAdminCorrelationId()}`;
  }

  return getOrCreateSupportMessageIdempotencyKey(
    actorId,
    conversationId,
    `attachment:${attachmentIntentToken}`,
    replyToMessageId
  );
}

export async function clearSupportAttachmentIdempotencyKey(
  actorId: string,
  conversationId: string,
  attachment: File,
  body: string,
  replyToMessageId?: string | null
): Promise<void> {
  const attachmentIntentToken = await getAttachmentIntentToken(attachment, body, replyToMessageId);
  if (!attachmentIntentToken) {
    return;
  }

  await clearSupportMessageIdempotencyKey(
    actorId,
    conversationId,
    `attachment:${attachmentIntentToken}`,
    replyToMessageId
  );
}
