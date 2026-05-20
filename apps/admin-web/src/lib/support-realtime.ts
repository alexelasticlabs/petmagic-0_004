"use client";

import { HubConnectionBuilder, LogLevel } from "@microsoft/signalr";
import { useEffect, useEffectEvent } from "react";

export type SupportConversationUpdatedEvent = {
  conversationId: string;
  initiatorUserId: string;
  updatedAtUtc: string;
};

const supportHubUrl = `${process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000"}/hubs/support-chat`;
const supportRealtimeCooldownMs = 30_000;

let supportRealtimeBlockedUntil = 0;

export function useSupportRealtime(
  accessToken: string | undefined,
  onConversationUpdated: (event: SupportConversationUpdatedEvent) => void,
) {
  const handleConversationUpdated = useEffectEvent(onConversationUpdated);

  useEffect(() => {
    if (!accessToken || Date.now() < supportRealtimeBlockedUntil) {
      return;
    }

    const connection = new HubConnectionBuilder()
      .withUrl(supportHubUrl, {
        accessTokenFactory: async () => accessToken,
      })
      .configureLogging(LogLevel.None)
      .build();

    let isDisposed = false;

    connection.on("conversation-updated", (payload: unknown) => {
      const event = normalizeConversationUpdated(payload);
      if (event) {
        handleConversationUpdated(event);
      }
    });

    void connection.start().catch((error: unknown) => {
      if (isDisposed || isExpectedConnectionFailure(error)) {
        supportRealtimeBlockedUntil = Date.now() + supportRealtimeCooldownMs;
      }
    });

    return () => {
      isDisposed = true;
      connection.off("conversation-updated");
      void connection.stop();
    };
  }, [accessToken]);
}

function isExpectedConnectionFailure(error: unknown) {
  if (!(error instanceof Error)) {
    return true;
  }

  return /failed to (start the connection|complete negotiation)|failed to fetch|networkerror/i.test(error.message);
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
  };
}