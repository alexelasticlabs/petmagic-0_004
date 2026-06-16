"use client";

import { HubConnectionBuilder, LogLevel, type HubConnection } from "@microsoft/signalr";
import { useEffect, useEffectEvent } from "react";

import { getAdminPublicApiBaseUrl } from "@/lib/admin-api-base-url";
import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type SupportConversationUpdatedEvent = {
  conversationId: string;
  initiatorUserId: string;
  updatedAtUtc: string;
  lastMessagePreview?: string | null;
  lastMessageAtUtc?: string | null;
  lastMessageSenderType?: string | null;
  adminUnreadCount?: number;
  userUnreadCount?: number;
};

const supportRealtimeCooldownMs = 30_000;

let supportRealtimeBlockedUntil = 0;
let supportRealtimeAccessToken: string | undefined;
let supportRealtimeConnection: HubConnection | null = null;
const supportRealtimeListeners = new Set<(event: SupportConversationUpdatedEvent) => void>();

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

  useEffect(() => {
    if (!accessToken || Date.now() < supportRealtimeBlockedUntil) {
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
}

function ensureSupportRealtimeConnection(accessToken: string): void {
  if (supportRealtimeConnection && supportRealtimeAccessToken === accessToken) {
    return;
  }

  stopSupportRealtimeConnection();
  supportRealtimeAccessToken = accessToken;

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
    }

    clientLogger.warn("support.realtime_closed", {
      expectedFailure,
      blockedUntil: supportRealtimeBlockedUntil,
      ...getSupportRealtimeErrorDetails(error),
    });

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
      }
    })
    .catch((error: unknown) => {
      if (connection !== supportRealtimeConnection) {
        return;
      }

      const expectedFailure = isExpectedConnectionFailure(error);
      if (expectedFailure) {
        supportRealtimeBlockedUntil = Date.now() + supportRealtimeCooldownMs;
      }

      clientLogger.warn("support.realtime_start_failed", {
        expectedFailure,
        blockedUntil: supportRealtimeBlockedUntil,
        ...getSupportRealtimeErrorDetails(error),
      });

      supportRealtimeConnection = null;
      supportRealtimeAccessToken = undefined;
    });
}

function stopSupportRealtimeConnection(): void {
  const connection = supportRealtimeConnection;
  supportRealtimeConnection = null;
  supportRealtimeAccessToken = undefined;

  if (!connection) {
    return;
  }

  connection.off("conversation-updated");
  void connection.stop();
}

function isExpectedConnectionFailure(error: unknown) {
  if (!(error instanceof Error)) {
    return true;
  }

  return /failed to (start the connection|complete negotiation)|failed to fetch|networkerror/i.test(
    error.message
  );
}

function normalizeConversationUpdated(payload: unknown): SupportConversationUpdatedEvent | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const candidate = payload as Partial<SupportConversationUpdatedEvent>;
  if (!candidate.conversationId || !candidate.initiatorUserId || !candidate.updatedAtUtc) {
    return null;
  }

  return {
    conversationId: candidate.conversationId,
    initiatorUserId: candidate.initiatorUserId,
    updatedAtUtc: candidate.updatedAtUtc,
    lastMessagePreview:
      typeof candidate.lastMessagePreview === "string" ? candidate.lastMessagePreview : null,
    lastMessageAtUtc:
      typeof candidate.lastMessageAtUtc === "string" ? candidate.lastMessageAtUtc : null,
    lastMessageSenderType:
      typeof candidate.lastMessageSenderType === "string" ? candidate.lastMessageSenderType : null,
    adminUnreadCount:
      typeof candidate.adminUnreadCount === "number" ? candidate.adminUnreadCount : undefined,
    userUnreadCount:
      typeof candidate.userUnreadCount === "number" ? candidate.userUnreadCount : undefined,
  };
}
