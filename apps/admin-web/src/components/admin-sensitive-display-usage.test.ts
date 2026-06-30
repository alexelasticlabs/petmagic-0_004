import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplatesAnalyticsHubPageLibrarySource } from "@/components/templates/templates-analytics-hub-page.test-source";
import { readUsersManagementPageLibrarySource } from "@/components/users-management-page.test-source";

const files = [
  fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./users/user-inline-analytics.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates/template-analytics-detail-sections.tsx", import.meta.url)),
];

describe("admin sensitive display usage", () => {
  it("does not render raw audit/activity details or feedback messages", () => {
    const source = [
      readUsersManagementPageLibrarySource(),
      readTemplatesAnalyticsHubPageLibrarySource(),
      ...files.map((file) => readFileSync(file, "utf8")),
    ].join("\n");

    expect(source).not.toContain("{event.details}");
    expect(source).not.toContain("<strong>{event.action}</strong>");
    expect(source).not.toContain("{item.details}");
    expect(source).not.toContain("{event.feedbackMessage}");
    expect(source).not.toContain("{item.feedbackMessage?.trim() || text.feedbackMessageMissing}");
    expect(source).toContain("sanitizeSensitiveText(event.details");
    expect(source).toContain("sanitizeSensitiveText(event.action");
    expect(source).toContain("sanitizeSensitiveText(item.details");
    expect(source).toContain("sanitizeSensitiveText(event.feedbackMessage");
    expect(source).toContain("sanitizeSensitiveText(item.feedbackMessage");
  });

  it("sanitizes user identity, role, and generation labels in user-facing admin views", () => {
    const usersManagementSource = readUsersManagementPageLibrarySource();
    const userDetailSource = readFileSync(files[0], "utf8");
    const userInlineAnalyticsSource = readFileSync(files[1], "utf8");

    expect(usersManagementSource).toContain("shortIdentifier(user.userId)");
    expect(usersManagementSource).toContain("shortIdentifier(selectedUser.userId)");
    expect(usersManagementSource).toContain("sanitizeSensitiveText(user.displayName, 96)");
    expect(usersManagementSource).toContain("sanitizeSensitiveText(generation.templateTitle, 120)");
    expect(usersManagementSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(user.userId)}`}"
    );
    expect(usersManagementSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(openActionsUser.userId)}`}"
    );
    expect(usersManagementSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(selectedUser.userId)}`}"
    );
    expect(usersManagementSource).toContain(
      "sanitizeSensitiveText(selectedSubscription.status, 48)"
    );
    expect(usersManagementSource).toContain("sanitizeSensitiveText(ticket.status, 48)");
    expect(usersManagementSource).toContain("sanitizeSensitiveText(purchase.currencyCode, 12)");
    expect(usersManagementSource).not.toContain(
      '<td data-label="userId" className={adminTableStyles.mono}>\n                          {user.userId}\n                        </td>'
    );
    expect(usersManagementSource).not.toContain(
      "<p className={styles.profileSub}>{selectedUser.userId}</p>"
    );
    expect(usersManagementSource).not.toContain('{user.displayName ?? "—"}');
    expect(usersManagementSource).not.toContain("{selectedSubscriptionQuery.data.status} •");
    expect(usersManagementSource).not.toContain("<strong>{ticket.status}</strong>");
    expect(usersManagementSource).not.toContain("{purchase.priceAmount} {purchase.currencyCode}");
    expect(usersManagementSource).not.toContain("href={`/${locale}/users/${user.userId}`}");
    expect(usersManagementSource).not.toContain(
      "href={`/${locale}/users/${openActionsUser.userId}`}"
    );
    expect(usersManagementSource).not.toContain("href={`/${locale}/users/${selectedUser.userId}`}");

    expect(userDetailSource).toContain(
      "const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96)"
    );
    expect(userDetailSource).toContain("sanitizeSensitiveText(role, 32)");
    expect(userDetailSource).toContain("sanitizeSensitiveText(generation.templateTitle, 120)");
    expect(userDetailSource).toContain("sanitizeSensitiveText(item.failureCode, 120)");
    expect(userDetailSource).not.toContain("title={getAdminUserDisplayName(user)}");
    expect(userDetailSource).not.toContain("<AdminBadge key={role}>{role}</AdminBadge>");

    expect(userInlineAnalyticsSource).toContain(
      "const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96)"
    );
    expect(userInlineAnalyticsSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(user.userId)}`}"
    );
    expect(userInlineAnalyticsSource).toContain(
      "sanitizeSensitiveText(generation.templateTitle, 120)"
    );
    expect(userInlineAnalyticsSource).toContain("sanitizeSensitiveText(item.failureCode, 120)");
    expect(userInlineAnalyticsSource).not.toContain("<h3>{getAdminUserDisplayName(user)}</h3>");
    expect(userInlineAnalyticsSource).not.toContain("href={`/${locale}/users/${user.userId}`}");
  });

  it("encodes template analytics route ids before building hrefs", () => {
    const hubSource = readTemplatesAnalyticsHubPageLibrarySource();

    expect(hubSource).toContain(
      'href={`/${locale}/templates/${row.templateType === "Video" ? "video" : "image"}/analytics/${encodeURIComponent(row.templateId)}`}'
    );
    expect(hubSource).toContain("const encodedTemplateId = encodeURIComponent(item.templateId);");
    expect(hubSource).toContain("? `/${locale}/templates/video/analytics/${encodedTemplateId}`");
    expect(hubSource).toContain(": `/${locale}/templates/image/analytics/${encodedTemplateId}`");
    expect(hubSource).not.toContain(
      'href={`/${locale}/templates/${row.templateType === "Video" ? "video" : "image"}/analytics/${row.templateId}`}'
    );
    expect(hubSource).not.toContain("analytics/${item.templateId}");
  });
});
