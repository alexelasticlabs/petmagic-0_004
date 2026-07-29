import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportInboxPagePath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));

describe("support inbox page", () => {
  it("keeps the moderator default page error state retryable", () => {
    const source = readFileSync(supportInboxPagePath, "utf8");

    expect(source).toContain('tone="danger"');
    expect(source).toContain("title={text.supportLoadError}");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain(
      'const canManageSupportWorkspace =\n    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain("enabled: canManageSupportWorkspace");
    expect(source).toContain("const supportInboxStaleTimeMs = 8_000;");
    expect(source).toContain("staleTime: supportInboxStaleTimeMs");
    expect(source).toContain("function requestInboxRetry()");
    expect(source).toContain(
      "if (!canManageSupportWorkspace || inboxQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("inboxQuery.refetch().catch(() => undefined)");
    expect(source).toContain("onClick={requestInboxRetry}");
    expect(source).toContain("disabled={!canManageSupportWorkspace || inboxQuery.isFetching}");
    expect(source).toContain("title={text.supportEmpty}");
    expect(source).toContain("{text.supportRefresh}");
    expect(source).toContain("!canManageSupportWorkspace ||\n    inboxQuery.isLoading");
    expect(source).toContain("{text.adminRetryAction}");
    expect(source).toContain("useQuery<AdminSupportInboxPage>");
    expect(source).toContain("sortSupportQueueItems(inboxQuery.data?.items ?? [])");
    expect(source).toContain("const sortedConversationIds = useMemo(");
    expect(source).toContain(
      "new Set(sortedConversations.map((conversation) => conversation.conversationId))"
    );
    expect(source).toContain("sortedConversationIds.has(selectedConversationId)");
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("if (isActive) {\n        setSelectedConversationId(null);");
    expect(source).toContain("return () => {\n      isActive = false;\n    };");
    expect(source).toContain("selectedConversationId &&");
    expect(source).toContain("sortedConversations.some(");
    expect(source).toContain(
      "(conversation) => conversation.conversationId === selectedConversationId"
    );
    expect(source).not.toContain("enabled: Boolean(session)");
    expect(source).not.toContain("disabled={!session || inboxQuery.isFetching}");
    expect(source).not.toContain("sortSupportQueueItems(inboxQuery.data ?? [])");
    expect(source).not.toContain(
      "onClick={() => {\n                if (!canManageSupportWorkspace)"
    );
  });
});
