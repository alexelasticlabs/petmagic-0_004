"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";

import { AdminNotificationsProvider } from "@/components/admin/admin-notifications";

type ProvidersProps = {
  children: ReactNode;
};

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
      <AdminNotificationsProvider>{children}</AdminNotificationsProvider>
    </QueryClientProvider>
  );
}
