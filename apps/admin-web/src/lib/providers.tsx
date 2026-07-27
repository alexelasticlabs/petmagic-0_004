"use client";

import { QueryClient, QueryClientProvider, useQueryClient } from "@tanstack/react-query";
import { useLayoutEffect, useRef, useState, type ReactNode } from "react";

import { AdminNotificationsProvider } from "@/components/admin/admin-notifications";
import { useAuthSession } from "@/lib/api-client.core";
import type { AuthSession } from "@/lib/api-client.types.auth";

type ProvidersProps = {
  children: ReactNode;
};

export type AdminQueryCachePrincipal = string | null | undefined;

export function getAdminQueryCachePrincipal(
  session: AuthSession | null | undefined
): AdminQueryCachePrincipal {
  if (session === undefined) {
    return undefined;
  }

  if (session === null) {
    return null;
  }

  return JSON.stringify([session.user.userId, [...session.user.roles].sort()]);
}

export function synchronizeAdminQueryCacheForSession(
  queryClient: Pick<QueryClient, "clear">,
  previousPrincipal: AdminQueryCachePrincipal,
  nextPrincipal: AdminQueryCachePrincipal
): AdminQueryCachePrincipal {
  if (previousPrincipal !== undefined && previousPrincipal !== nextPrincipal) {
    queryClient.clear();
  }

  return nextPrincipal;
}

function AdminQueryCacheSessionBoundary({ children }: ProvidersProps) {
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const principal = getAdminQueryCachePrincipal(session);
  const previousPrincipalRef = useRef<AdminQueryCachePrincipal>(undefined);

  useLayoutEffect(() => {
    previousPrincipalRef.current = synchronizeAdminQueryCacheForSession(
      queryClient,
      previousPrincipalRef.current,
      principal
    );
  }, [principal, queryClient]);

  return children;
}

export function Providers({ children }: ProvidersProps) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            refetchOnWindowFocus: false,
            retry: false,
            staleTime: 120_000,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <AdminQueryCacheSessionBoundary>
        <AdminNotificationsProvider>{children}</AdminNotificationsProvider>
      </AdminQueryCacheSessionBoundary>
    </QueryClientProvider>
  );
}
