"use client";

import { useQuery } from "@tanstack/react-query";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminTemplateFeedback, type AdminTemplateFeedbackItem } from "@/lib/api-client";

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
  const feedbackQuery = useQuery<AdminTemplateFeedbackItem[]>({
    queryKey: adminQueryKeys.templateAnalyticsFeedback(templateId, filter, search),
    queryFn: ({ signal }) =>
      fetchAdminTemplateFeedback(templateId, {
        search: search || undefined,
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
