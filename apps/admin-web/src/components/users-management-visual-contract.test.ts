import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const usersPagePath = fileURLToPath(new URL("./users-management-page.tsx", import.meta.url));
const usersContentPath = fileURLToPath(
  new URL("./users-management-page.content.ts", import.meta.url)
);
const usersStylesPath = fileURLToPath(
  new URL("./users-management-page.module.css", import.meta.url)
);
const userDetailPath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userDetailStylesPath = fileURLToPath(
  new URL("./users/user-detail-page.module.css", import.meta.url)
);
const userInlineAnalyticsStylesPath = fileURLToPath(
  new URL("./users/user-inline-analytics.module.css", import.meta.url)
);

describe("users management visual contract", () => {
  it("keeps user badges on semantic theme tokens", () => {
    const usersSource = readFileSync(usersPagePath, "utf8");
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
    expect(detailSource).toContain('return status === "succeeded" ? "var(--success)" : "var(--warning)"');
    expect(detailSource).toContain("function getGenerationStatusColor(status: string): string");
    expect(detailSource).toContain('return "var(--danger)"');
    expect(detailSource).toContain('return "var(--text-muted)"');
    expect(usersSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(detailSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("keeps user overlays theme-aware instead of hardcoding dark rgba layers", () => {
    const stylesSource = readFileSync(usersStylesPath, "utf8");

    expect(stylesSource).toContain("box-shadow: var(--shadow-strong);");
    expect(stylesSource).toContain(
      "background: color-mix(in srgb, var(--surface-0) 64%, transparent);"
    );
    expect(stylesSource).toContain(
      "background: color-mix(in srgb, var(--surface-0) 74%, transparent);"
    );
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toContain("0 20px 40px");
    expect(stylesSource).not.toContain("0 20px 42px");
  });

  it("keeps users pagination icon-based and accessible", () => {
    const usersSource = readFileSync(usersPagePath, "utf8");
    const usersContentSource = readFileSync(usersContentPath, "utf8");
    const stylesSource = readFileSync(usersStylesPath, "utf8");

    expect(usersSource).toContain("CaretDownIcon");
    expect(usersSource).toContain("aria-label={ui.previousPageLabel}");
    expect(usersSource).toContain("aria-label={ui.nextPageLabel}");
    expect(usersSource).toContain("title={ui.previousPageLabel}");
    expect(usersSource).toContain("title={ui.nextPageLabel}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(usersContentSource).toContain('previousPageLabel: "Previous users page"');
    expect(usersContentSource).toContain('nextPageLabel: "Next users page"');
    expect(stylesSource).toContain(".pageInfo {");
    expect(stylesSource).toContain(".pageIconPrevious {");
    expect(stylesSource).toContain(".pageIconNext {");
    expect(usersSource).not.toContain("{ui.prevPage}");
    expect(usersSource).not.toContain("{ui.nextPage}");
  });

  it("keeps users page UI copy outside the client component", () => {
    const usersSource = readFileSync(usersPagePath, "utf8");
    const usersContentSource = readFileSync(usersContentPath, "utf8");

    expect(usersSource).toContain(
      'import { getUsersManagementPageText } from "@/components/users-management-page.content";'
    );
    expect(usersSource).toContain(
      "const ui = useMemo(() => getUsersManagementPageText(locale), [locale]);"
    );
    expect(usersSource).not.toContain('summaryTotal: "Total users"');
    expect(usersSource).not.toContain('summaryTotal: "Всего пользователей"');
    expect(usersContentSource).toContain("export type UsersManagementPageText = {");
    expect(usersContentSource).toContain("const usersManagementPageText: Record<Locale, UsersManagementPageText>");
    expect(usersContentSource).toContain("export function getUsersManagementPageText");
    expect(usersContentSource).toContain('summaryTotal: "Total users"');
    expect(usersContentSource).toContain('summaryTotal: "Всего пользователей"');
  });

  it("keeps inline analytics cards theme-aware", () => {
    const stylesSource = readFileSync(userInlineAnalyticsStylesPath, "utf8");

    expect(stylesSource).toContain("background: var(--accent-soft-bg);");
    expect(stylesSource).toContain("color: var(--accent-strong);");
    expect(stylesSource).toContain("border: 1px solid var(--border-soft);");
    expect(stylesSource).toContain("color-mix(in srgb, var(--surface-2) 72%, var(--surface-1))");
    expect(stylesSource).toContain("color-mix(in srgb, var(--surface-2) 88%, var(--surface-0))");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("keeps inline analytics readable on phone screens", () => {
    const stylesSource = readFileSync(userInlineAnalyticsStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".header,\n  .identity");
    expect(stylesSource).toContain(".identity h3,\n  .identity p");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain(".profileLink {\n    width: 100%;");
    expect(stylesSource).toContain("justify-content: center;");
    expect(stylesSource).toContain(".timelineHeader {\n    display: grid;");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
  });

  it("keeps user detail cards and actions usable on phone screens", () => {
    const stylesSource = readFileSync(userDetailStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".backLink,\n  .errorActions > *");
    expect(stylesSource).toContain("flex-direction: column;");
    expect(stylesSource).toContain(".profileTitle,\n  .profileEmail");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain(".timelineHeader,\n  .dataHeader");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
    expect(stylesSource).toContain(".petMediaGrid");
  });

  it("keeps users management filters and panels usable on phone screens", () => {
    const stylesSource = readFileSync(usersStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain("min-width: clamp(20rem, 30vw, 28rem);");
    expect(stylesSource).toContain("min-width: clamp(18rem, 34vw, 25rem);");
    expect(stylesSource).toContain(".filtersBar {\n    grid-template-columns: minmax(0, 1fr);");
    expect(stylesSource).toContain(".searchInput,\n  .filterSelect");
    expect(stylesSource).toContain(".searchInput:focus-visible,\n.filterSelect:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain("width: 100%;\n    min-width: 0;");
    expect(stylesSource).toContain(".paginationControls {\n    width: 100%;");
    expect(stylesSource).toContain("justify-content: space-between;");
    expect(stylesSource).toContain(".walletActions {\n    flex-direction: column;");
    expect(stylesSource).toContain(".sidePanelHeader {\n    display: grid;");
    expect(stylesSource).toContain(".closeBtn {\n    width: 100%;");
    expect(stylesSource).toContain(".actionsCell {\n    min-width: min(18rem, calc(100vw - 2rem));");
    expect(stylesSource).toContain(".quickActionBtn {\n    flex: 1 1 8rem;");
    expect(stylesSource).toContain("white-space: normal;");
    expect(stylesSource).toContain(".actionMenuPortal {\n    max-width: calc(100vw - 1rem);");
    expect(stylesSource).toContain(".actionMenuList {\n    min-width: min(15.5rem, calc(100vw - 1rem));");
    expect(stylesSource).not.toContain(".searchInput:focus,\n.filterSelect:focus");
  });

  it("keeps users panels and wallet form controls on compact admin radii", () => {
    const usersStylesSource = readFileSync(usersStylesPath, "utf8");
    const walletStylesSource = readFileSync(
      fileURLToPath(new URL("./users/user-wallet-panel.module.css", import.meta.url)),
      "utf8"
    );

    expect(usersStylesSource).toContain(".walletDialog {");
    expect(usersStylesSource).toContain(".sidePanel {");
    expect(usersStylesSource).toContain(".walletInput:focus-visible,\n.walletTextarea:focus-visible");
    expect(usersStylesSource).toContain(".walletInput:disabled,\n.walletTextarea:disabled");
    expect(walletStylesSource).toContain(".input,\n.select,\n.textarea");
    expect(walletStylesSource).toContain(".input:focus-visible,\n.select:focus-visible,\n.textarea:focus-visible");
    expect(walletStylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(walletStylesSource).toContain(".input:disabled,\n.select:disabled,\n.textarea:disabled");
    expect(usersStylesSource).toContain("border-radius: var(--radius-sm);");
    expect(walletStylesSource).toContain("border-radius: var(--radius-sm);");
    expect(usersStylesSource).not.toContain(".walletInput:focus,\n.walletTextarea:focus");
    expect(walletStylesSource).not.toContain(".input:focus,\n.select:focus,\n.textarea:focus");
    expect(`${usersStylesSource}\n${walletStylesSource}`).not.toMatch(
      /border-radius:\s*(?:0\.9rem|1rem|1[2-9]px|[2-9][0-9]px)/
    );
  });

  it("keeps users management action menu viewport-safe and theme-tokenized", () => {
    const pageSource = readFileSync(usersPagePath, "utf8");
    const stylesSource = readFileSync(usersStylesPath, "utf8");
    const actionMenuPortalLayer = stylesSource.slice(
      stylesSource.indexOf(".actionMenuPortal {"),
      stylesSource.indexOf(".actionMenuList {")
    );
    const actionMenuLayer = stylesSource.slice(
      stylesSource.indexOf(".actionMenuList {"),
      stylesSource.indexOf(".actionMenuListUpward {")
    );
    const actionMenuItemLayer = stylesSource.slice(
      stylesSource.indexOf(".actionMenuItem,\n.actionMenuLink"),
      stylesSource.indexOf(".actionMenuItem:hover")
    );

    expect(actionMenuPortalLayer).toContain("max-width: calc(100vw - 1rem);");
    expect(actionMenuPortalLayer).toContain("max-height: calc(100dvh - 1rem);");
    expect(pageSource).toContain("const ACTIONS_MENU_TARGET_WIDTH_PX = 250;");
    expect(pageSource).toContain("const ACTIONS_MENU_VIEWPORT_PADDING_PX = 8;");
    expect(pageSource).toContain(
      "const availableWidth = Math.max(0, window.innerWidth - viewportPadding * 2);"
    );
    expect(pageSource).toContain("window.innerWidth - viewportPadding * 2");
    expect(pageSource).toContain(
      "const minWidth = Math.min(ACTIONS_MENU_TARGET_WIDTH_PX, availableWidth);"
    );
    expect(pageSource).not.toContain("ACTIONS_MENU_MIN_WIDTH_PX");
    expect(pageSource).not.toContain("const minWidth = 250;");
    expect(actionMenuLayer).toContain("box-shadow: var(--shadow-strong);");
    expect(actionMenuLayer).toContain("max-width: min(17rem, calc(100vw - 1rem));");
    expect(actionMenuLayer).toContain("max-height: calc(100dvh - 1rem);");
    expect(actionMenuLayer).toContain("overflow-y: auto;");
    expect(actionMenuItemLayer).toContain("min-width: 0;");
    expect(actionMenuItemLayer).toContain("white-space: normal;");
    expect(actionMenuItemLayer).toContain("overflow-wrap: anywhere;");
    expect(actionMenuLayer).not.toContain("rgba(");
    expect(actionMenuLayer).not.toContain("0 14px 28px");
    expect(`${actionMenuPortalLayer}\n${actionMenuLayer}`).not.toContain("100vh");
  });
});
