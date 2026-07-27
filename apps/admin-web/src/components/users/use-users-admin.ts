"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchUsers,
  useAuthSession,
  type FetchUsersQuery,
  type UserListPage,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

export function useUsersAdmin(locale: Locale, usersQueryParams: FetchUsersQuery) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canManageRoles = session?.user.roles.includes("Admin") ?? false;

  const usersQuery = useQuery<UserListPage>({
    queryKey: adminQueryKeys.users(usersQueryParams),
    queryFn: ({ signal }) => fetchUsers(usersQueryParams, signal),
    enabled: canManageRoles,
    placeholderData: keepPreviousData,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const isLoading = usersQuery.isLoading;
  const isFetching = usersQuery.isFetching;
  const isRefreshing = usersQuery.isFetching && usersQuery.isPlaceholderData;
  const visibleUsersPage = usersQuery.data;
  const error = usersQuery.isError ? text.errorLoadingUsers : null;

  async function refreshUsers() {
    if (!canManageRoles) {
      return usersQuery;
    }

    const refreshedUsers = await usersQuery.refetch();
    if (refreshedUsers.isError) {
      throw refreshedUsers.error;
    }

    return refreshedUsers;
  }
  return {
    canManageRoles,
    error,
    hasSession: canManageRoles,
    isFetching,
    isRefreshing,
    isLoading,
    refreshUsers,
    users: visibleUsersPage?.items ?? [],
    usersPage: visibleUsersPage ?? {
      items: [],
      skip: usersQueryParams.skip ?? 0,
      take: usersQueryParams.take ?? 100,
      hasMore: false,
      totalCount: 0,
    },
  };
}
