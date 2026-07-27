import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const feedbackPagePath = fileURLToPath(new URL("./feedback-page.tsx", import.meta.url));
const usersCardPath = fileURLToPath(new URL("./users-management-users-card.tsx", import.meta.url));
const usersTablePath = fileURLToPath(
  new URL("./users-management-users-card.table.tsx", import.meta.url)
);
const userSupportTicketsPath = fileURLToPath(
  new URL("./users/user-support-tickets-panel.tsx", import.meta.url)
);

describe("admin pagination recovery", () => {
  it("keeps a previous-page control available after an empty out-of-range response", () => {
    const feedbackSource = readFileSync(feedbackPagePath, "utf8");
    const usersCardSource = readFileSync(usersCardPath, "utf8");
    const usersTableSource = readFileSync(usersTablePath, "utf8");
    const userSupportTicketsSource = readFileSync(userSupportTicketsPath, "utf8");

    expect(feedbackSource).toContain("const shouldShowFeedbackPager =");
    expect(feedbackSource).toContain(
      "visibleFeedbackItems.length > 0 || page > 0 || Boolean(visiblePageData?.hasMore)"
    );
    expect(feedbackSource).toContain("{shouldShowFeedbackPager ? (");
    expect(feedbackSource).toContain("disabled={page === 0 || isFeedbackFetching}");
    expect(feedbackSource).toContain("function requestPreviousFeedbackPage()");
    expect(feedbackSource).toContain(
      "requestFeedbackPageChange(Math.max(0, Math.min(page - 1, lastPage)));"
    );

    expect(usersCardSource).toContain(
      "usersPageTotalCount > 0 && (totalPages > 1 || currentPage > 1);"
    );
    expect(usersCardSource).toContain("{hasUsers || hasRecoverablePagination ? (");
    expect(usersTableSource).toContain("hidden={pagedUsers.length === 0}");
    expect(usersTableSource).toContain(
      "const shouldShowPagination = totalPages > 1 || currentPage > 1;"
    );
    expect(usersTableSource).toContain("{shouldShowPagination ? (");
    expect(usersTableSource).toContain("disabled={currentPage <= 1 || isUsersFetching}");
    expect(usersTableSource).toMatch(
      /resetUsersPage\(\s*Math\.max\(1, Math\.min\(totalPages, currentPage - 1\)\)\s*\)/
    );

    expect(userSupportTicketsSource).toContain("const hasRecoverablePagination =");
    expect(userSupportTicketsSource).toContain("{hasTickets || hasRecoverablePagination ? (");
    expect(userSupportTicketsSource).toContain("hidden={!hasTickets}");
    expect(userSupportTicketsSource).toContain("{totalPages > 1 || currentPage > 1 ? (");
    expect(userSupportTicketsSource).toMatch(
      /updatePage\(\(current\) =>\s*Math\.max\(1, Math\.min\(totalPages, current - 1\)\)\s*\)/
    );
  });
});
