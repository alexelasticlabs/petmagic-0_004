"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { sortSupportQueueItems } from "@/components/support/support-conversation-helpers";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchSupportInbox,
  useAuthSession,
  type AdminSupportConversationSummary,
  type SupportConversationStatus,
  type SupportInboxAssignmentScope,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useSupportRealtime } from "@/lib/support-realtime";

type UseSupportInboxControllerParams = {
  locale: Locale;
};

export type SupportFilter = "all" | SupportConversationStatus;
export type AssignmentFilter = SupportInboxAssignmentScope;

export function useSupportInboxController({ locale }: UseSupportInboxControllerParams) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const [status, setStatus] = useState<SupportFilter>("all");
  const [assignment, setAssignment] = useState<AssignmentFilter>("all");
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  const inboxQuery = useQuery<AdminSupportConversationSummary[]>({
    queryKey: adminQueryKeys.supportInbox(status, assignment),
    queryFn: () => fetchSupportInbox(status === "all" ? undefined : status, assignment),
    enabled: Boolean(session),
  });

  useSupportRealtime(session?.accessToken, () => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot });
  });

  const filteredConversations = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();
    const conversations = sortSupportQueueItems(inboxQuery.data ?? []);
    if (!normalizedQuery) {
      return conversations;
    }

    return conversations.filter((conversation) => {
      const searchableText = [
        conversation.userDisplayName,
        conversation.userEmail,
        conversation.lastMessagePreview,
        conversation.assignedAdminDisplayName,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return searchableText.includes(normalizedQuery);
    });
  }, [inboxQuery.data, searchQuery]);

  return {
    assignment,
    filteredConversations,
    inboxQuery,
    searchQuery,
    setAssignment,
    setSearchQuery,
    setStatus,
    status,
    text,
  };
}
