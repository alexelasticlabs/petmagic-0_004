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
  type AdminSupportInboxPage,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type SupportInboxPageProps = {
  locale: Locale;
};

export function SupportInboxPage({ locale }: SupportInboxPageProps) {
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canManageSupportWorkspace =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const text = useMemo(() => getDictionary(locale), [locale]);
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);

  useEffect(() => {
    ensureAdminSession(locale, router);
  }, [locale, router, session]);

  const inboxQuery = useQuery<AdminSupportInboxPage>({
    queryKey: adminQueryKeys.supportInbox("all", "all", { page: 1, pageSize: 50 }),
    queryFn: ({ signal }) => fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal }),
    enabled: canManageSupportWorkspace,
  });

  const sortedConversations = useMemo<AdminSupportConversationSummary[]>(
    () => sortSupportQueueItems(inboxQuery.data?.items ?? []),
    [inboxQuery.data]
  );
  const sortedConversationIdSignature = sortedConversations
    .map((conversation) => conversation.conversationId)
    .join("|");

  useEffect(() => {
    if (
      !selectedConversationId ||
      inboxQuery.isFetching ||
      sortedConversationIdSignature.split("|").includes(selectedConversationId)
    ) {
      return;
    }

    queueMicrotask(() => setSelectedConversationId(null));
  }, [inboxQuery.isFetching, selectedConversationId, sortedConversationIdSignature]);

  const activeConversationId = useMemo(() => {
    if (sortedConversations.length === 0) {
      return null;
    }

    if (
      selectedConversationId &&
      sortedConversations.some((conversation) => conversation.conversationId === selectedConversationId)
    ) {
      return selectedConversationId;
    }

    return sortedConversations[0]?.conversationId ?? null;
  }, [selectedConversationId, sortedConversations]);

  function requestInboxRetry() {
    if (!canManageSupportWorkspace || inboxQuery.isFetching) {
      return;
    }

    void inboxQuery.refetch().catch(() => undefined);
  }

  if (
    !canManageSupportWorkspace ||
    inboxQuery.isLoading ||
    (sortedConversations.length > 0 && !activeConversationId)
  ) {
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
              onClick={requestInboxRetry}
              disabled={!canManageSupportWorkspace || inboxQuery.isFetching}
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
          action={
            <Button
              variant="secondary"
              onClick={requestInboxRetry}
              disabled={!canManageSupportWorkspace || inboxQuery.isFetching}
            >
              {text.supportRefresh}
            </Button>
          }
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
