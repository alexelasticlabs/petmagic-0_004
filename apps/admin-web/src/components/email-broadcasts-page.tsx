"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { AdminPage } from "@/components/admin/admin-primitives";
import {
  readPersistedSelection,
  selectionStoragePrefix,
} from "@/components/email-recipient-selection";
import { UsersBulkEmailDialog } from "@/components/users-bulk-email-dialog";
import { UsersEmailBroadcastsWorkspace } from "@/components/users-email-broadcasts-workspace";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { useAuthSession } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

export function EmailBroadcastsPage({ locale }: { locale: Locale }) {
  const session = useAuthSession();
  if (!session?.user.roles.includes("Admin")) return null;
  return (
    <EmailBroadcastsContent
      key={session.user.userId}
      locale={locale}
      actorId={session.user.userId}
    />
  );
}

function EmailBroadcastsContent({ locale, actorId }: { locale: Locale; actorId: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const composerOpen = searchParams.get("compose") === "1";
  const [selectedUserIds, setSelectedUserIds] = useState(() =>
    [...readPersistedSelection(selectionStoragePrefix + ":" + actorId).values()]
      .filter((item) => item.eligible)
      .map((item) => item.id)
  );
  const [queuedCount, setQueuedCount] = useState<number | null>(null);

  function closeComposer() {
    if (searchParams.has("compose")) {
      const next = new URLSearchParams(searchParams);
      next.delete("compose");
      router.replace("/" + locale + "/email-broadcasts" + (next.size ? "?" + next : ""), {
        scroll: false,
      });
    }
  }

  return (
    <AdminPage>
      {!composerOpen ? (
        <UsersEmailBroadcastsWorkspace
          locale={locale}
          onCreate={() => {
            setQueuedCount(null);
            const next = new URLSearchParams(searchParams);
            next.delete("selected");
            next.set("compose", "1");
            router.push("/" + locale + "/email-broadcasts?" + next, { scroll: false });
          }}
          queuedCount={queuedCount}
        />
      ) : null}
      {composerOpen ? (
        <UsersBulkEmailDialog
          locale={locale}
          selectedUserIds={queuedCount === null ? selectedUserIds : []}
          onClose={closeComposer}
          onQueued={(broadcast) => {
            setQueuedCount(broadcast.recipientCount);
            setSelectedUserIds([]);
            try {
              window.localStorage.removeItem(selectionStoragePrefix + ":" + actorId);
            } catch {
              /* Browser storage is optional. */
            }
            void queryClient.invalidateQueries({ queryKey: adminQueryKeys.emailBroadcastsRoot });
            router.replace(
              "/" +
                locale +
                "/email-broadcasts?selected=" +
                encodeURIComponent(broadcast.broadcastId),
              { scroll: false }
            );
          }}
        />
      ) : null}
    </AdminPage>
  );
}
