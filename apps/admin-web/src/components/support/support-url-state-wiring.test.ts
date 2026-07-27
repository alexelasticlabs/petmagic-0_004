import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const inboxPath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));
const conversationPath = fileURLToPath(new URL("./support-conversation-page.tsx", import.meta.url));
const queuePath = fileURLToPath(new URL("./support-conversation-queue-pane.tsx", import.meta.url));

describe("support queue URL state wiring", () => {
  it("uses the restored filter for the initial inbox request and selected conversation", () => {
    const source = readFileSync(inboxPath, "utf8");

    expect(source).toContain("readSupportQueueUrlState(searchParams)");
    expect(source).toContain("resolveQueueFilter(initialQueueState.subFilter)");
    expect(source).toContain(
      "fetchSupportInbox(initialQueueStatus, initialQueueFilter.assignment, {"
    );
    expect(source).toContain("priority: initialQueuePriority");
    expect(source).toContain("page: initialQueueState.page");
    expect(source).toContain("initialQueueState={initialQueueState}");
  });

  it("replaces URL state without scroll or history spam and preserves it across route links", () => {
    const conversationSource = readFileSync(conversationPath, "utf8");
    const queueSource = readFileSync(queuePath, "utf8");

    expect(conversationSource).toContain("buildSupportQueueSearchParams(");
    expect(conversationSource).toContain("useAdminUrlStateSyncGuard({");
    expect(conversationSource).toContain("readSupportQueueUrlState(nextSearchParams)");
    expect(conversationSource).toContain("setQueueFilter(nextQueueState.subFilter)");
    expect(conversationSource).toContain("consumeUrlStateApplication(isSupportUrlStatePending)");
    expect(conversationSource).toContain(
      "router.replace(`${pathname}${supportRouteSearchSuffix}`, { scroll: false });"
    );
    expect(conversationSource).toContain("initialQueueState,");
    expect(conversationSource).toContain("queueSearchParams={queueSearchParams}");
    expect(queueSource).toContain(
      "href={`/${locale}/support/${supportConversationPathId}${supportConversationSearchSuffix}`}"
    );
  });
});
