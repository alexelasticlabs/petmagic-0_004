import { QueryClient } from "@tanstack/react-query";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import type { AuthSession } from "@/lib/api-client.types.auth";
import { getAdminQueryCachePrincipal, synchronizeAdminQueryCacheForSession } from "@/lib/providers";

const providersPath = fileURLToPath(new URL("./providers.tsx", import.meta.url));

function createSession(userId: string, roles: string[]): AuthSession {
  return {
    accessToken: "access-token",
    expiresAtUtc: "2026-07-25T12:00:00.000Z",
    user: {
      userId,
      email: `${userId}@example.com`,
      isPremium: false,
      emailConfirmed: true,
      roles,
    },
  };
}

describe("admin query cache session boundary", () => {
  it("does not clear cache before the auth snapshot has resolved", () => {
    const queryClient = new QueryClient();
    queryClient.setQueryData(["admin", "users"], { items: ["bootstrap"] });

    const nextPrincipal = synchronizeAdminQueryCacheForSession(
      queryClient,
      undefined,
      getAdminQueryCachePrincipal(null)
    );

    expect(nextPrincipal).toBeNull();
    expect(queryClient.getQueryData(["admin", "users"])).toEqual({ items: ["bootstrap"] });
  });

  it("clears cached admin data across logout and a different principal or role", () => {
    const queryClient = new QueryClient();
    const adminPrincipal = getAdminQueryCachePrincipal(createSession("admin-1", ["Admin"]));
    const moderatorPrincipal = getAdminQueryCachePrincipal(
      createSession("moderator-2", ["Moderator"])
    );
    const downgradedPrincipal = getAdminQueryCachePrincipal(
      createSession("admin-1", ["Moderator"])
    );

    let currentPrincipal = synchronizeAdminQueryCacheForSession(
      queryClient,
      undefined,
      adminPrincipal
    );
    queryClient.setQueryData(["admin", "users"], { items: ["admin-only"] });

    currentPrincipal = synchronizeAdminQueryCacheForSession(queryClient, currentPrincipal, null);
    expect(queryClient.getQueryData(["admin", "users"])).toBeUndefined();

    queryClient.setQueryData(["admin", "feedback"], { items: ["old-principal"] });
    synchronizeAdminQueryCacheForSession(queryClient, currentPrincipal, moderatorPrincipal);
    expect(queryClient.getQueryData(["admin", "feedback"])).toBeUndefined();

    queryClient.setQueryData(["admin", "support"], { items: ["admin-role"] });
    synchronizeAdminQueryCacheForSession(queryClient, moderatorPrincipal, downgradedPrincipal);
    expect(queryClient.getQueryData(["admin", "support"])).toBeUndefined();
  });

  it("runs cache isolation in a layout effect before a new principal can see a stale paint", () => {
    const source = readFileSync(providersPath, "utf8");

    expect(source).toContain("function AdminQueryCacheSessionBoundary");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("useLayoutEffect(() => {");
    expect(source).toContain("synchronizeAdminQueryCacheForSession(");
    expect(source).toContain("<AdminQueryCacheSessionBoundary>");
  });
});
