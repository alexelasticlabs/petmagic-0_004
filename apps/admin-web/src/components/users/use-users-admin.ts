"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    fetchUsers,
    useAuthSession,
    type UserListItem,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

export type UsersToastState = {
  type: "success" | "error";
  message: string;
};

export function useUsersAdmin(locale: Locale) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [toast, setToast] = useState<UsersToastState | null>(null);
  const canManageRoles = session?.user.roles.includes("Admin") ?? false;

  const usersQuery = useQuery<UserListItem[]>({
    queryKey: adminQueryKeys.users,
    queryFn: fetchUsers,
    enabled: Boolean(session),
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
    };
  }, [locale, router, session]);

  const isLoading = usersQuery.isLoading || usersQuery.isFetching;
  const error = actionError ?? (usersQuery.isError ? text.errorLoadingUsers : null);

  async function runAction(userId: string, action: () => Promise<void>) {
    setBusyUserId(userId);
    setActionError(null);

    try {
      await action();
      const refreshedUsers = await usersQuery.refetch();
      if (refreshedUsers.isError) {
        throw refreshedUsers.error;
      }

      setToast({
        type: "success",
        message: text.usersChangesSaved,
      });
    } catch {
      setActionError(text.errorLoadingUsers);
      setToast({ type: "error", message: text.errorLoadingUsers });
    } finally {
      setBusyUserId(null);
    }
  }

  return {
    busyUserId,
    canManageRoles,
    error,
    isLoading,
    runAction,
    toast,
    users: usersQuery.data ?? [],
  };
}
