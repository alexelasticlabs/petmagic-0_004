"use client";

import { ensureAdminSession } from "@/components/admin/admin-session";
import {
    fetchUsers,
    useAuthSession,
    type UserListItem,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

export type UsersToastState = {
  type: "success" | "error";
  message: string;
};

export function useUsersAdmin(locale: Locale) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [toast, setToast] = useState<UsersToastState | null>(null);
  const canManageRoles = session?.user.roles.includes("Admin") ?? false;

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2400);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    let isCancelled = false;

    async function initialize() {
      setIsLoading(true);
      setError(null);

      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        const response = await fetchUsers();
        if (!isCancelled) {
          setUsers(response);
        }
      } catch {
        if (!isCancelled) {
          setError(text.errorLoadingUsers);
          setToast({ type: "error", message: text.errorLoadingUsers });
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false);
        }
      }
    }

    void initialize();

    return () => {
      isCancelled = true;
    };
  }, [locale, router, text.errorLoadingUsers]);

  async function refreshUsers() {
    const response = await fetchUsers();
    setUsers(response);
  }

  async function runAction(userId: string, action: () => Promise<void>) {
    setBusyUserId(userId);
    setError(null);

    try {
      await action();
      await refreshUsers();
      setToast({
        type: "success",
        message: text.usersChangesSaved,
      });
    } catch {
      setError(text.errorLoadingUsers);
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
    users,
  };
}
