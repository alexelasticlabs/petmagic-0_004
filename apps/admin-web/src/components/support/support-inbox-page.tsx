"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { sortSupportQueueItems } from "@/components/support/support-conversation-helpers";
import { SupportConversationPage } from "@/components/support/support-conversation-page";
import styles from "@/components/support/support-page.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchSupportInbox,
  useAuthSession,
  type AdminSupportConversationSummary,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type SupportInboxPageProps = {
  locale: Locale;
};

export function SupportInboxPage({ locale }: SupportInboxPageProps) {
  const router = useRouter();
  const session = useAuthSession();
  const text = getDictionary(locale);
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
    queryKey: adminQueryKeys.supportInbox("all", "all", { page: 1, pageSize: 50 }),
    queryFn: ({ signal }) => fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal }),
    enabled: Boolean(session),
  });

  const sortedConversations = useMemo(
    () => sortSupportQueueItems(inboxQuery.data ?? []),
    [inboxQuery.data]
  );

  const activeConversationId = useMemo(() => {
    if (sortedConversations.length === 0) {
      return null;
    }

    if (selectedConversationId) {
      return selectedConversationId;
    }

    return sortedConversations[0]?.conversationId ?? null;
  }, [selectedConversationId, sortedConversations]);

  if (inboxQuery.isLoading || (sortedConversations.length > 0 && !activeConversationId)) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="info"
          title={text.loading}
          description={text.supportConversationDescription}
        />
      </AdminPage>
    );
  }

  if (inboxQuery.isError) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="danger"
          title={text.supportLoadError}
          description={text.supportDescription}
          action={
            <Button
              variant="secondary"
              onClick={() => void inboxQuery.refetch().catch(() => undefined)}
              disabled={inboxQuery.isFetching}
            >
              {text.adminRetryAction}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  if (sortedConversations.length === 0 || !activeConversationId) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="info"
          title={text.supportEmpty}
          description={text.supportDescription}
        />
      </AdminPage>
    );
  }

  return (
    <SupportConversationPage
      key={activeConversationId}
      locale={locale}
      conversationId={activeConversationId}
      navigationMode="local"
      onConversationSelect={setSelectedConversationId}
    />
  );
}
