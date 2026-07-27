"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useState } from "react";

import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminTemplateCategoryDiagnostics } from "@/lib/api-client.template-category-diagnostics";
import type { AdminTemplateCategoryDiagnostics } from "@/lib/api-client.types.template-category-diagnostics";

type UseAdminTemplateCategoryDiagnosticsOptions = {
  enabled: boolean;
};

export function useAdminTemplateCategoryDiagnostics({
  enabled,
}: UseAdminTemplateCategoryDiagnosticsOptions) {
  const queryClient = useQueryClient();
  const [hadCachedDiagnosticsAtMount] = useState(
    () =>
      queryClient.getQueryData<AdminTemplateCategoryDiagnostics>(
        adminQueryKeys.templateCategoryDiagnostics
      ) !== undefined
  );
  const [hasRun, setHasRun] = useState(hadCachedDiagnosticsAtMount);
  const [isStale, setIsStale] = useState(hadCachedDiagnosticsAtMount);
  const diagnosticsQuery = useQuery<AdminTemplateCategoryDiagnostics>({
    queryKey: adminQueryKeys.templateCategoryDiagnostics,
    queryFn: ({ signal }) => fetchAdminTemplateCategoryDiagnostics(signal),
    enabled: false,
    retry: false,
    staleTime: Number.POSITIVE_INFINITY,
  });
  const diagnostics = diagnosticsQuery.data ?? null;
  const isFetching = diagnosticsQuery.isFetching;
  const refetch = diagnosticsQuery.refetch;

  const run = useCallback(async () => {
    if (!enabled || isFetching) {
      return;
    }

    setHasRun(true);
    const result = await refetch();
    setIsStale(result.isError && diagnostics !== null);
  }, [diagnostics, enabled, isFetching, refetch]);

  const markStale = useCallback(() => {
    if (hasRun && diagnostics) {
      setIsStale(true);
    }
  }, [diagnostics, hasRun]);

  return {
    diagnostics,
    error: diagnosticsQuery.error,
    hasError: hasRun && diagnosticsQuery.isError,
    hasRun,
    isFetching,
    isStale,
    markStale,
    run,
  };
}
