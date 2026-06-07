import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportInboxPagePath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));

describe("support inbox page", () => {
  it("keeps the moderator default page error state retryable", () => {
    const source = readFileSync(supportInboxPagePath, "utf8");

    expect(source).toContain("tone=\"danger\"");
    expect(source).toContain("title={text.supportLoadError}");
    expect(source).toContain("inboxQuery.refetch().catch(() => undefined)");
    expect(source).toContain("disabled={inboxQuery.isFetching}");
    expect(source).toContain("{text.adminRetryAction}");
  });
});
