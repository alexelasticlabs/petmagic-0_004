"use client";

import { HubConnectionBuilder, LogLevel } from "@microsoft/signalr";
import { useEffect, useEffectEvent } from "react";

import { getAdminPublicApiBaseUrl } from "@/lib/admin-api-base-url";
import { clientLogger } from "@/lib/client-logger";

const realtimeDisabled = process.env.NEXT_PUBLIC_E2E_DISABLE_ADMIN_NOTIFICATIONS_REALTIME === "1";

export function useAdminNotificationsRealtime(
  accessToken: string | undefined,
  onChanged: () => void
) {
  const handleChanged = useEffectEvent(onChanged);

  useEffect(() => {
    if (!accessToken || realtimeDisabled) return;

    const connection = new HubConnectionBuilder()
      .withUrl(`${getAdminPublicApiBaseUrl()}/hubs/admin-notifications`, {
        accessTokenFactory: async () => accessToken,
      })
      .withAutomaticReconnect([0, 2_000, 5_000, 10_000])
      .configureLogging(LogLevel.None)
      .build();
    connection.on("notifications-changed", handleChanged);

    void connection.start().catch((error: unknown) => {
      clientLogger.warn("admin.notifications_realtime_unavailable", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
    });

    return () => {
      connection.off("notifications-changed", handleChanged);
      void connection.stop().catch(() => undefined);
    };
  }, [accessToken]);
}
