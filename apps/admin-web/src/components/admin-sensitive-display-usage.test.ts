import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplatesAnalyticsHubPageLibrarySource } from "@/components/templates/templates-analytics-hub-page.test-source";
import { readUsersManagementPageLibrarySource } from "@/components/users-management-page.test-source";

const userDetailPagePath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsPath = fileURLToPath(
  new URL("./users/user-inline-analytics.tsx", import.meta.url)
);
const userSupportTicketsPanelPath = fileURLToPath(
  new URL("./users/user-support-tickets-panel.tsx", import.meta.url)
);
const userAccessControlPanelPath = fileURLToPath(
  new URL("./users/user-access-control-panel.tsx", import.meta.url)
);
const userActivityPresentationPath = fileURLToPath(
  new URL("./users/user-activity-presentation.ts", import.meta.url)
);
const templateAnalyticsDetailSectionsPath = fileURLToPath(
  new URL("./templates/template-analytics-detail-sections.tsx", import.meta.url)
);

describe("admin sensitive display usage", () => {
  it("does not render raw activity details or feedback messages", () => {
    const source = [
      readUsersManagementPageLibrarySource(),
      readTemplatesAnalyticsHubPageLibrarySource(),
      readFileSync(userDetailPagePath, "utf8"),
      readFileSync(userInlineAnalyticsPath, "utf8"),
      readFileSync(userActivityPresentationPath, "utf8"),
      readFileSync(templateAnalyticsDetailSectionsPath, "utf8"),
    ].join("\n");

    expect(source).not.toContain("{item.details}");
    expect(source).not.toContain("{event.feedbackMessage}");
    expect(source).not.toContain("{item.feedbackMessage?.trim() || text.feedbackMessageMissing}");
    expect(source).toContain('sanitizeSensitiveText(item.details ?? "", 180)');
    expect(source).toContain("sanitizeSensitiveText(item.feedbackMessage");
  });

  it("sanitizes user identity and user-scoped labels in the new dossier", () => {
    const usersManagementSource = readUsersManagementPageLibrarySource();
    const userDetailSource = readFileSync(userDetailPagePath, "utf8");
    const userInlineAnalyticsSource = readFileSync(userInlineAnalyticsPath, "utf8");
    const userSupportSource = readFileSync(userSupportTicketsPanelPath, "utf8");
    const userAccessSource = readFileSync(userAccessControlPanelPath, "utf8");
    const userActivityPresentationSource = readFileSync(userActivityPresentationPath, "utf8");

    expect(usersManagementSource).not.toContain("shortIdentifier(");
    expect(usersManagementSource).toContain("sanitizeSensitiveText(user.displayName, 96)");
    expect(usersManagementSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(user.userId)}`}"
    );
    expect(usersManagementSource).not.toContain(
      '<td data-label="userId" className={adminTableStyles.mono}>\n                          {user.userId}\n                        </td>'
    );
    expect(usersManagementSource).not.toContain('{user.displayName ?? "—"}');
    expect(usersManagementSource).not.toContain("href={`/${locale}/users/${user.userId}`}");

    expect(userDetailSource).toContain(
      "const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96)"
    );
    expect(userDetailSource).not.toContain("shortIdentifier(");
    expect(userDetailSource).toContain("sanitizeSensitiveText(generation.templateTitle, 120)");
    expect(userDetailSource).toContain("sanitizeSensitiveText(purchase.currencyCode, 12)");
    expect(userDetailSource).toContain("getUserActivityPresentation(item, workspaceText)");
    expect(userActivityPresentationSource).toContain(
      'sanitizeSensitiveText(item.details ?? "", 180)'
    );
    expect(userActivityPresentationSource).toContain("return { title: text.activitySystem };");
    expect(userDetailSource).not.toContain("title={getAdminUserDisplayName(user)}");

    expect(userSupportSource).toContain("statusLabel(ticket.status, dictionary)");
    expect(userSupportSource).toContain("priorityLabel(ticket.priority, dictionary)");
    expect(userSupportSource).toContain("sanitizeSensitiveText(ticket.lastMessagePreview, 220)");
    expect(userSupportSource).toContain(
      "href={`/${locale}/support/${encodeURIComponent(ticket.conversationId)}`}"
    );
    expect(userSupportSource).not.toContain("href={`/${locale}/support/${ticket.conversationId}`}");

    expect(userAccessSource).toContain("sanitizeSensitiveText(user.userId, 80)");
    expect(userAccessSource).not.toContain(
      'clientLogger.error("users.access_action_failed", {\n        userId: user.userId'
    );

    expect(userInlineAnalyticsSource).toContain(
      "const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96)"
    );
    expect(userInlineAnalyticsSource).toContain(
      "href={`/${locale}/users/${encodeURIComponent(user.userId)}`}"
    );
    expect(userInlineAnalyticsSource).toContain(
      "sanitizeSensitiveText(generation.templateTitle, 120)"
    );
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
