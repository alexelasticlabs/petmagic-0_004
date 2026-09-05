import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readUsersManagementPageLibrarySource } from "@/components/users-management-page.test-source";

const usersPagePath = fileURLToPath(new URL("./users-management-page.tsx", import.meta.url));
const usersChromePath = fileURLToPath(
  new URL("./users-management-page.chrome.tsx", import.meta.url)
);
const usersContentPath = fileURLToPath(
  new URL("./users-management-page.content.ts", import.meta.url)
);
const usersFiltersPath = fileURLToPath(
  new URL("./users-management-users-card.filters.tsx", import.meta.url)
);
const usersTablePath = fileURLToPath(
  new URL("./users-management-users-card.table.tsx", import.meta.url)
);
const usersStylesPath = fileURLToPath(
  new URL("./users-management-page.module.css", import.meta.url)
);
const bulkEmailDialogPath = fileURLToPath(
  new URL("./users-bulk-email-dialog.tsx", import.meta.url)
);
const bulkEmailDialogStylesPath = fileURLToPath(
  new URL("./users-bulk-email-dialog.module.css", import.meta.url)
);
const userDetailPath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userDetailStylesPath = fileURLToPath(
  new URL("./users/user-detail-page.module.css", import.meta.url)
);
const walletStylesPath = fileURLToPath(
  new URL("./users/user-wallet-panel.module.css", import.meta.url)
);

describe("users management visual contract", () => {
  it("keeps user badges on semantic theme tokens", () => {
    const usersSource = readUsersManagementPageLibrarySource();
    const detailSource = readFileSync(userDetailPath, "utf8");

    expect(usersSource).toContain("const accountStatusColors: Record<AccountStatus, string>");
    expect(usersSource).toContain('active: "var(--success)"');
    expect(usersSource).toContain('blocked: "var(--danger)"');
    expect(usersSource).toContain('unconfirmed: "var(--warning)"');
    expect(usersSource).toContain('premium: "var(--success)"');
    expect(usersSource).toContain('free: "var(--text-muted)"');
    expect(usersSource).toContain("color={accountStatusColors[status]}");
    expect(usersSource).toContain("premiumStatusColors.premium");
    expect(usersSource).toContain("premiumStatusColors.free");
    expect(detailSource).toContain("function getPurchaseStatusColor(status: string): string");
    expect(detailSource).toContain(
      'return status.toLowerCase() === "succeeded" ? "var(--success)" : "var(--warning)"'
    );
    expect(detailSource).toContain("function getGenerationStatusColor(status: string): string");
    expect(detailSource).toContain('return "var(--danger)"');
    expect(detailSource).toContain('return "var(--text-muted)"');
    expect(usersSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(detailSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("keeps the registry lightweight and uses the project Select for filters and the period", () => {
    const pageSource = readFileSync(usersPagePath, "utf8");
    const chromeSource = readFileSync(usersChromePath, "utf8");
    const filtersSource = readFileSync(usersFiltersPath, "utf8");

    expect(pageSource).toContain("const PAGE_SIZE = 24;");
    expect(pageSource).toContain("const [rangeDays, setRangeDays] = useState<RangeDays>(30);");
    expect(pageSource).not.toContain("UsersManagementHero");
    expect(chromeSource).not.toContain("AdminPageHero");
    expect(chromeSource).toContain("<AdminMetricStrip");
    expect(chromeSource).toContain("className={styles.summaryGrid}");
    expect(chromeSource).toContain("className={styles.summaryHeader}");
    expect(chromeSource).toContain("className={styles.summaryTitle}");
    expect(chromeSource).toContain("<Select");
    expect(chromeSource).toContain("ariaLabel={ui.periodLabel}");
    expect(chromeSource).toContain(
      "onChange={(value) => setRangeDays(Number.parseInt(value, 10) as RangeDays)}"
    );
    expect(filtersSource).toContain("AdminFilterBar");
    expect(filtersSource).toContain("Select, type SelectOption");
    expect(filtersSource).not.toContain("<select");
    expect(filtersSource).toContain("setStatusFilter");
    expect(filtersSource).toContain("resetUsersPage();");
    expect(filtersSource).toContain('id: "search"');
    expect(filtersSource).toContain('id: "sort"');
    expect(filtersSource).toContain("const hasResettableControls = activeFilters.length > 0;");
    expect(filtersSource).not.toContain("ActivityFilter");
    expect(filtersSource).not.toContain("RangeDays");
    expect(filtersSource).not.toContain("setRangeDays");
  });

  it("keeps destructive per-user mutations out of the registry and routes them to the dossier", () => {
    const usersSource = readUsersManagementPageLibrarySource();
    const tableSource = readFileSync(usersTablePath, "utf8");

    expect(tableSource).toContain("<span>{ui.userColumn}</span>");
    expect(tableSource).toContain("<th>{ui.accountAndAccess}</th>");
    expect(tableSource).toContain("<th>{ui.plan}</th>");
    expect(tableSource).toContain("<th>{ui.registeredAt}</th>");
    expect(tableSource).toContain("<th>{ui.quickActions}</th>");
    expect(tableSource).toContain("data-label={ui.quickActions}");
    expect(tableSource).toContain("data-label={ui.registeredAt}");
    expect(tableSource).toContain("href={`/${locale}/users/${encodeURIComponent(user.userId)}`}");
    expect(tableSource).toContain("?tab=wallet");
    expect(tableSource).toContain("?tab=support");
    expect(tableSource).toContain('role="group"');

    for (const legacyRegistryConcern of [
      "ActivityFilter",
      "fetchUserRowEnrichment",
      "UsersManagementSidePanel",
      "UsersManagementActionsMenu",
      "adjustAdminUserWallet",
      "setActive(user.userId",
      "revokePremium(user.userId",
      "assignRole(user.userId",
      "revokeRole(user.userId",
      "deleteAdminUser(user.userId",
      "quickCredit",
      "quickDebit",
    ]) {
      expect(usersSource).not.toContain(legacyRegistryConcern);
    }
  });

  it("adds a deliberate, auditable bulk email workflow for eligible recipients", () => {
    const usersSource = readUsersManagementPageLibrarySource();
    const tableSource = readFileSync(usersTablePath, "utf8");
    const dialogSource = readFileSync(bulkEmailDialogPath, "utf8");
    const dialogStylesSource = readFileSync(bulkEmailDialogStylesPath, "utf8");
    const contentSource = readFileSync(usersContentPath, "utf8");

    expect(usersSource).toContain("UsersBulkEmailDialog");
    expect(usersSource).toContain("/email-broadcasts?compose=1");
    expect(usersSource).not.toContain("<UsersEmailBroadcastsWorkspace");
    expect(tableSource).toContain("user.isActive && user.emailConfirmed");
    expect(tableSource).toContain("selectAllRef.current.indeterminate");
    expect(tableSource).toContain("onTogglePageSelection(eligibleUserIds");
    expect(dialogSource).toContain('type DialogStage = "compose" | "review";');
    expect(dialogSource).toContain("await queueAdminBulkEmail(");
    expect(dialogSource).toContain("policyConfirmed");
    expect(dialogSource).toContain("ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH");
    expect(dialogSource).toContain("ADMIN_BULK_EMAIL_BODY_MAX_LENGTH");
    expect(dialogSource).toContain("deliveryIdempotencyKeyRef");
    expect(dialogSource).toContain("`bulk-email:${createAdminCorrelationId()}`");
    expect(dialogSource).toContain("markCampaignPayloadChanged");
    expect(dialogSource).toContain("copy.reviewDescription");
    expect(contentSource).toContain("Перед отправкой проверьте аудиторию и текст письма");
    expect(dialogStylesSource).toContain("@media (max-width: 680px)");
    expect(dialogStylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
  });

  it("keeps registry copy localized outside client components", () => {
    const usersSource = readUsersManagementPageLibrarySource();
    const usersContentSource = readFileSync(usersContentPath, "utf8");
    const ruUsersContentSource = usersContentSource.slice(0, usersContentSource.indexOf("  en: {"));

    expect(usersSource).toContain(
      'import { getUsersManagementPageText } from "@/components/users-management-page.content";'
    );
    expect(usersSource).toContain(
      "const ui = useMemo(() => getUsersManagementPageText(locale), [locale]);"
    );
    expect(usersSource).not.toContain('openProfile: "Открыть досье"');
    expect(usersContentSource).toContain("export type UsersManagementPageText = {");
    expect(usersContentSource).toContain(
      "const usersManagementPageText: Record<Locale, UsersManagementPageText>"
    );
    expect(usersContentSource).toContain('searchPlaceholder: "Поиск по имени, email или ID"');
    expect(usersContentSource).toContain('openProfile: "Открыть досье"');
    expect(usersContentSource).toContain('openProfile: "Open dossier"');
    expect(usersContentSource).toContain('quickActions: "Быстрые действия"');
    expect(usersContentSource).toContain('quickProfile: "Досье"');
    expect(usersContentSource).toContain('quickWallet: "Баланс"');
    expect(usersContentSource).toContain('quickWallet: "Balance"');
    expect(usersContentSource).toContain('filterStatus: "Состояние аккаунта"');
    expect(ruUsersContentSource).not.toContain('openProfile: "Open dossier"');
  });

  it("keeps users pagination icon-based and accessible", () => {
    const usersSource = readUsersManagementPageLibrarySource();
    const usersContentSource = readFileSync(usersContentPath, "utf8");
    const stylesSource = readFileSync(usersStylesPath, "utf8");
    const tableSource = readFileSync(usersTablePath, "utf8");

    expect(usersSource).toContain("CaretDownIcon");
    expect(usersSource).toContain("aria-label={ui.previousPageLabel}");
    expect(usersSource).toContain("aria-label={ui.nextPageLabel}");
    expect(usersSource).toContain("title={ui.previousPageLabel}");
    expect(usersSource).toContain("title={ui.nextPageLabel}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(usersSource).toContain("className={styles.identityArrow}");
    expect(tableSource).toContain(
      "const shouldShowPagination = totalPages > 1 || currentPage > 1;"
    );
    expect(tableSource).toContain("{shouldShowPagination ? (");
    expect(tableSource).not.toContain("usersPageTotalCount");
    expect(usersContentSource).toContain('previousPageLabel: "Previous users page"');
    expect(usersContentSource).toContain('nextPageLabel: "Next users page"');
    expect(stylesSource).toContain(".pageInfo {");
    expect(stylesSource).toContain(".pageIconPrevious {");
    expect(stylesSource).toContain(".pageIconNext {");
    expect(usersSource).not.toContain("{ui.prevPage}");
    expect(usersSource).not.toContain("{ui.nextPage}");
  });

  it("keeps the compact registry usable on phone screens without hidden overlays", () => {
    const stylesSource = readFileSync(usersStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain("@media (max-width: 900px)");
    expect(stylesSource).toContain(".tableWrap :global(thead) {");
    expect(stylesSource).toContain("clip-path: inset(50%);");
    expect(stylesSource).not.toContain(".tableWrap :global(thead) {\n    display: none;");
    expect(stylesSource).toContain(".summaryGrid,\n  .filtersBar,\n  .advancedFilters {");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
    expect(stylesSource).toContain(".searchField,\n.selectField {");
    expect(stylesSource).toContain(".selectField :global(button[class*=");
    expect(stylesSource).toContain(".searchInput:focus-visible {");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain("grid-template-columns: repeat(3, minmax(0, 1fr));");
    expect(stylesSource).toContain(".quickActionLink {\n    width: 100%;");
    expect(stylesSource).toContain(".paginationControls {\n    width: 100%;");
    expect(stylesSource).toContain("justify-content: space-between;");
    expect(stylesSource).not.toContain(".walletDialog");
    expect(stylesSource).not.toContain(".sidePanel");
    expect(stylesSource).not.toContain(".actionMenu");
    expect(stylesSource).not.toContain(".searchInput:focus,\n.filterSelect:focus");
  });

  it("keeps the dossier tabbed and its access and wallet controls responsive", () => {
    const detailSource = readFileSync(userDetailPath, "utf8");
    const detailStylesSource = readFileSync(userDetailStylesPath, "utf8");
    const walletStylesSource = readFileSync(walletStylesPath, "utf8");

    expect(detailSource).toContain("UserSupportTicketsPanel");
    expect(detailSource).toContain("UserWalletPanel");
    expect(detailSource).toContain("UserAccessControlPanel");
    expect(detailSource).toContain('activeTab === "overview"');
    expect(detailSource).toContain('activeTab === "wallet"');
    expect(detailSource).toContain('activeTab === "support"');
    expect(detailSource).toContain('activeTab === "content"');
    expect(detailSource).toContain('activeTab === "access"');
    expect(detailSource).toContain(
      'function selectTab(nextTab: UserDetailTab, action?: "adjust-balance")'
    );
    expect(detailSource).toContain("getUserActivityPresentation(item, workspaceText)");
    expect(detailSource).toContain(
      "<nav className={styles.tabs} aria-label={workspaceText.tabsLabel}>"
    );
    expect(detailSource).toContain("href={getUserDetailHref(locale, userId, tab.id)}");
    expect(detailSource).toContain('aria-current={activeTab === tab.id ? "page" : undefined}');
    expect(detailSource).toContain("options={tabOptions}");
    expect(detailSource).not.toContain('role="tablist"');
    expect(detailSource).not.toContain('role="tabpanel"');
    expect(detailSource).toContain("quickActionsTitle");
    expect(detailStylesSource).toContain(".tabs {");
    expect(detailStylesSource).toContain("overflow-x: auto;");
    expect(detailStylesSource).toContain(".quickActions {");
    expect(detailStylesSource).toContain(".tabSelect {");
    expect(detailStylesSource).toContain(".tabs {\n    display: none;");
    expect(detailStylesSource).toContain(".tabSelect {\n    display: grid;");
    expect(detailStylesSource).toContain(".accessLayout {");
    expect(detailStylesSource).toContain(".accessInformationRail {");
    expect(detailStylesSource).toContain(".supportPagination > :global(.ui-button)");
    expect(detailStylesSource).toContain(".deleteZone > :global(.ui-button)");
    expect(walletStylesSource).toContain(".input,\n.textarea");
    expect(walletStylesSource).toContain(".input:focus-visible,\n.textarea:focus-visible");
    expect(walletStylesSource).toContain(".operationField :global(button[class*=");
    expect(walletStylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(walletStylesSource).not.toContain(".input:focus,\n.select:focus,\n.textarea:focus");
  });
});
