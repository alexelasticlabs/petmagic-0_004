"use client";

import { HubConnectionBuilder, LogLevel, type HubConnection } from "@microsoft/signalr";
import { useEffect, useEffectEvent, useSyncExternalStore } from "react";

import { getAdminPublicApiBaseUrl } from "@/lib/admin-api-base-url";
import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type SupportConversationUpdatedEvent = {
  conversationId: string;
  initiatorUserId: string;
  updatedAtUtc: string;
  lastMessageAtUtc?: string | null;
  lastMessageSenderType?: string | null;
  adminUnreadCount?: number;
  userUnreadCount?: number;
};

export type SupportRealtimeStatus = "idle" | "connecting" | "connected" | "unavailable";

const supportRealtimeCooldownMs = 30_000;
const supportRealtimeIdMaxLength = 128;
const supportRealtimeTimestampMaxLength = 64;
const supportRealtimeSenderTypeMaxLength = 32;

let supportRealtimeBlockedUntil = 0;
let supportRealtimeAccessToken: string | undefined;
let supportRealtimeConnection: HubConnection | null = null;
let supportRealtimeStatus: SupportRealtimeStatus = "idle";
const supportRealtimeListeners = new Set<(event: SupportConversationUpdatedEvent) => void>();
const supportRealtimeStatusListeners = new Set<() => void>();

function getSupportRealtimeErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function useSupportRealtime(
  accessToken: string | undefined,
  onConversationUpdated: (event: SupportConversationUpdatedEvent) => void
) {
  const handleConversationUpdated = useEffectEvent(onConversationUpdated);
  const status = useSyncExternalStore(
    subscribeToSupportRealtimeStatus,
    getSupportRealtimeStatus,
    getSupportRealtimeStatus
  );

  useEffect(() => {
    if (!accessToken) {
      return;
    }

    if (Date.now() < supportRealtimeBlockedUntil) {
      setSupportRealtimeStatus("unavailable");
      return;
    }

    const listener = (event: SupportConversationUpdatedEvent) => handleConversationUpdated(event);
    supportRealtimeListeners.add(listener);
    ensureSupportRealtimeConnection(accessToken);

    return () => {
      supportRealtimeListeners.delete(listener);
      if (supportRealtimeListeners.size === 0) {
        stopSupportRealtimeConnection();
      }
    };
  }, [accessToken]);

  return status;
}

function ensureSupportRealtimeConnection(accessToken: string): void {
  if (supportRealtimeConnection && supportRealtimeAccessToken === accessToken) {
    return;
  }

  stopSupportRealtimeConnection();
  supportRealtimeAccessToken = accessToken;
  setSupportRealtimeStatus("connecting");

  const supportHubUrl = `${getAdminPublicApiBaseUrl()}/hubs/support-chat`;
  const connection = new HubConnectionBuilder()
    .withUrl(supportHubUrl, {
      accessTokenFactory: async () => accessToken,
    })
    .withAutomaticReconnect([0, 2_000, 5_000, 10_000])
    .configureLogging(LogLevel.None)
    .build();

  supportRealtimeConnection = connection;

  connection.onclose((error: Error | undefined) => {
    if (connection !== supportRealtimeConnection) {
      return;
    }

    const expectedFailure = isExpectedConnectionFailure(error);
    if (expectedFailure) {
      supportRealtimeBlockedUntil = Date.now() + supportRealtimeCooldownMs;
      setSupportRealtimeStatus("unavailable");
    } else {
      setSupportRealtimeStatus("idle");
      logUnexpectedSupportRealtimeFailure("support.realtime_closed", error);
    }

    supportRealtimeConnection = null;
    supportRealtimeAccessToken = undefined;
  });

  connection.on("conversation-updated", (payload: unknown) => {
    const event = normalizeConversationUpdated(payload);
    if (event) {
      for (const listener of [...supportRealtimeListeners]) {
        listener(event);
      }
    }
  });

  void connection
    .start()
    .then(() => {
      if (connection === supportRealtimeConnection) {
        supportRealtimeBlockedUntil = 0;
        setSupportRealtimeStatus("connected");
      }
    })
    .catch((error: unknown) => {
      if (connection !== supportRealtimeConnection) {
        return;
      }

      const expectedFailure = isExpectedConnectionFailure(error);
      if (expectedFailure) {
        supportRealtimeBlockedUntil = Date.now() + supportRealtimeCooldownMs;
        setSupportRealtimeStatus("unavailable");
      } else {
        setSupportRealtimeStatus("idle");
        logUnexpectedSupportRealtimeFailure("support.realtime_start_failed", error);
      }

      supportRealtimeConnection = null;
      supportRealtimeAccessToken = undefined;
    });
}

function setSupportRealtimeStatus(status: SupportRealtimeStatus): void {
  supportRealtimeStatus = status;
  for (const listener of [...supportRealtimeStatusListeners]) {
    listener();
  }
}

function subscribeToSupportRealtimeStatus(listener: () => void): () => void {
  supportRealtimeStatusListeners.add(listener);
  return () => {
    supportRealtimeStatusListeners.delete(listener);
  };
}

function getSupportRealtimeStatus(): SupportRealtimeStatus {
  return supportRealtimeStatus;
}

function logUnexpectedSupportRealtimeFailure(
  event:
    "support.realtime_closed" | "support.realtime_start_failed" | "support.realtime_stop_failed",
  error: unknown
): void {
  clientLogger.warn(event, {
    blockedUntil: supportRealtimeBlockedUntil,
    ...getSupportRealtimeErrorDetails(error),
  });
}

function stopSupportRealtimeConnection(): void {
  const connection = supportRealtimeConnection;
  supportRealtimeConnection = null;
  supportRealtimeAccessToken = undefined;
  setSupportRealtimeStatus("idle");

  if (!connection) {
    return;
  }

  connection.off("conversation-updated");
  void connection.stop().catch((error) => {
    if (!isExpectedConnectionFailure(error)) {
      logUnexpectedSupportRealtimeFailure("support.realtime_stop_failed", error);
    }
  });
}

function isExpectedConnectionFailure(error: unknown) {
  if (!(error instanceof Error)) {
    return true;
  }

  return /failed to (start the connection|complete negotiation)|failed to fetch|networkerror/i.test(
    error.message
  );
}

function normalizeSupportRealtimeString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = sanitizeSensitiveText(value, maxLength);
  return normalized === "—" ? null : normalized;
}

function normalizeSupportRealtimeCount(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    return undefined;
  }

  return value;
}

function normalizeConversationUpdated(payload: unknown): SupportConversationUpdatedEvent | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const candidate = payload as Partial<SupportConversationUpdatedEvent>;
  const conversationId = normalizeSupportRealtimeString(
    candidate.conversationId,
    supportRealtimeIdMaxLength
  );
  const initiatorUserId = normalizeSupportRealtimeString(
    candidate.initiatorUserId,
    supportRealtimeIdMaxLength
  );
  const updatedAtUtc = normalizeSupportRealtimeString(
    candidate.updatedAtUtc,
    supportRealtimeTimestampMaxLength
  );

  if (!conversationId || !initiatorUserId || !updatedAtUtc) {
    return null;
  }

  return {
    conversationId,
    initiatorUserId,
    updatedAtUtc,
    lastMessageAtUtc: normalizeSupportRealtimeString(
      candidate.lastMessageAtUtc,
      supportRealtimeTimestampMaxLength
    ),
    lastMessageSenderType: normalizeSupportRealtimeString(
      candidate.lastMessageSenderType,
      supportRealtimeSenderTypeMaxLength
    ),
    adminUnreadCount: normalizeSupportRealtimeCount(candidate.adminUnreadCount),
    userUnreadCount: normalizeSupportRealtimeCount(candidate.userUnreadCount),
  };
}
