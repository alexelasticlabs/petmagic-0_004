import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const usersPagePath = fileURLToPath(new URL("./users-management-page.tsx", import.meta.url));
const usersStylesPath = fileURLToPath(
  new URL("./users-management-page.module.css", import.meta.url)
);
const userDetailPath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsStylesPath = fileURLToPath(
  new URL("./users/user-inline-analytics.module.css", import.meta.url)
);
const usersTableStylesPath = fileURLToPath(new URL("./users-table.module.css", import.meta.url));

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
    const stylesSource = readFileSync(usersStylesPath, "utf8");

    expect(usersSource).toContain("CaretDownIcon");
    expect(usersSource).toContain("aria-label={ui.previousPageLabel}");
    expect(usersSource).toContain("aria-label={ui.nextPageLabel}");
    expect(usersSource).toContain("title={ui.previousPageLabel}");
    expect(usersSource).toContain("title={ui.nextPageLabel}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(usersSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(usersSource).toContain('previousPageLabel: "Previous users page"');
    expect(usersSource).toContain('nextPageLabel: "Next users page"');
    expect(stylesSource).toContain(".pageInfo {");
    expect(stylesSource).toContain(".pageIconPrevious {");
    expect(stylesSource).toContain(".pageIconNext {");
    expect(usersSource).not.toContain("{ui.prevPage}");
    expect(usersSource).not.toContain("{ui.nextPage}");
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

  it("keeps users table action menu shadows on theme tokens", () => {
    const stylesSource = readFileSync(usersTableStylesPath, "utf8");
    const actionMenuLayer = stylesSource.slice(
      stylesSource.indexOf(".actionMenuList {"),
      stylesSource.indexOf(".actionMenuListPortal {")
    );

    expect(actionMenuLayer).toContain("box-shadow: var(--shadow-strong);");
    expect(actionMenuLayer).not.toContain("rgba(");
    expect(actionMenuLayer).not.toContain("0 14px 28px");
  });
});
