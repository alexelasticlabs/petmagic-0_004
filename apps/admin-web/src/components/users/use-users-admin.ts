"use client";

import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { useSyncToastToAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchUsers, useAuthSession, type FetchUsersQuery, type UserListPage } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";

export type UsersToastState = {
  type: "success" | "error";
  message: string;
};

type RunActionOptions = {
  successMessage?: string;
  errorMessage?: string;
};

export function useUsersAdmin(locale: Locale, usersQueryParams: FetchUsersQuery) {
  const text = getDictionary(locale);
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [toast, setToast] = useState<UsersToastState | null>(null);
  const canManageRoles = session?.user.roles.includes("Admin") ?? false;

  useSyncToastToAdminNotifications(toast, {
    category: "users",
    source: "users-admin",
    title: locale === "ru" ? "Изменения пользователей" : "User updates",
    href: `/${locale}/users`,
  });

  const usersQuery = useQuery<UserListPage>({
    queryKey: adminQueryKeys.users(usersQueryParams),
    queryFn: ({ signal }) => fetchUsers(usersQueryParams, signal),
    enabled: Boolean(session),
    placeholderData: keepPreviousData,
  });

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2400);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  const isLoading = usersQuery.isLoading;
  const isFetching = usersQuery.isFetching;
  const error = actionError ?? (usersQuery.isError ? text.errorLoadingUsers : null);

  async function refreshUsers() {
    setActionError(null);
    const refreshedUsers = await usersQuery.refetch();
    if (refreshedUsers.isError) {
      throw refreshedUsers.error;
    }

    return refreshedUsers;
  }

  async function runAction(
    userId: string,
    action: () => Promise<void>,
    options?: RunActionOptions
  ): Promise<boolean> {
    setBusyUserId(userId);
    setActionError(null);

    try {
      await action();
      await refreshUsers();

      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(userId) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userAnalytics(userId) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyUserSubscriptionSummary(userId),
        }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.users({ role: "Admin", skip: 0, take: 1 }),
        }),
      ]);

      setToast({
        type: "success",
        message: options?.successMessage ?? text.usersChangesSaved,
      });
      return true;
    } catch (error) {
      clientLogger.error("users.run_action_failed", {
        userId,
        error,
      });
      const message = getAdminErrorMessage(error, options?.errorMessage ?? text.errorLoadingUsers);
      setActionError(message);
      setToast({ type: "error", message });
      return false;
    } finally {
      setBusyUserId(null);
    }
  }

  return {
    busyUserId,
    canManageRoles,
    error,
    isFetching,
    isLoading,
    refreshUsers,
    runAction,
    toast,
    users: usersQuery.data?.items ?? [],
    usersPage: usersQuery.data ?? {
      items: [],
      skip: usersQueryParams.skip ?? 0,
      take: usersQueryParams.take ?? 100,
      hasMore: false,
      totalCount: 0,
    },
  };
}
