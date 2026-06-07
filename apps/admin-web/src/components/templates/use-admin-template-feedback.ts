"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplateFeedback,
  TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH,
  type AdminTemplateFeedbackItem,
} from "@/lib/api-client";

type FeedbackFilterKey = "all" | "complaint" | "feedback";

type UseAdminTemplateFeedbackOptions = {
  enabled?: boolean;
  filter: FeedbackFilterKey;
  search: string;
  take?: number;
  templateId: string;
};

export function useAdminTemplateFeedback({
  enabled = true,
  filter,
  search,
  take = 50,
  templateId,
}: UseAdminTemplateFeedbackOptions) {
  const normalizedSearch = search.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH);
  const feedbackQuery = useQuery<AdminTemplateFeedbackItem[]>({
    queryKey: adminQueryKeys.templateAnalyticsFeedback(templateId, filter, normalizedSearch),
    queryFn: ({ signal }) =>
      fetchAdminTemplateFeedback(templateId, {
        search: normalizedSearch || undefined,
        take,
        type: filter === "all" ? undefined : filter,
      }, signal),
    enabled,
  });

  return {
    hasError: feedbackQuery.isError,
    isLoading: feedbackQuery.isLoading || feedbackQuery.isFetching,
    items: feedbackQuery.data ?? [],
  };
}
