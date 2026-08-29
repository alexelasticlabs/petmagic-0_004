import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const detailStylesPath = fileURLToPath(new URL("./user-detail-page.module.css", import.meta.url));
const supportPanelPath = fileURLToPath(
  new URL("./user-support-tickets-panel.tsx", import.meta.url)
);

describe("user detail workspace UX", () => {
  it("uses one responsive profile masthead instead of duplicate page and profile headers", () => {
    const source = readFileSync(detailPagePath, "utf8");
    const styles = readFileSync(detailStylesPath, "utf8");

    expect(source).toContain("className={styles.profileMasthead}");
    expect(source).toContain("className={styles.profilePrimary}");
    expect(source).toContain('<h2 id="user-profile-title">{safeUserName}</h2>');
    expect(source).not.toContain("<h1");
    expect(source).toContain("{maskEmail(user.email)}");
    expect(source).not.toContain("AdminPageHero");
    expect(source).not.toContain("styles.profileCard");
    expect(styles).toContain(".profileMasthead");
    expect(styles).toContain(".profilePrimary");
    expect(styles).toContain("max-width: min(100%, 90rem);");
    expect(styles).toContain("justify-content: flex-start;");
    expect(styles).toContain("@media (max-width: 900px)");
  });

  it("keeps useful quick actions close to the profile and focuses the wallet adjustment intent", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain('query.set("action", action);');
    expect(source).toContain('searchParams.get("action") === "adjust-balance"');
    expect(source).toContain('onClick={() => selectTab("wallet", "adjust-balance")}');
    expect(source).toContain('onClick={() => selectTab("support")}');
    expect(source).toContain('onClick={() => selectTab("access")}');
    expect(source).toContain("autoFocusAdjustment={shouldFocusWalletAdjustment}");
    expect(source).toContain("function dismissWalletAdjustmentIntent()");
    expect(source).toContain('key={shouldFocusWalletAdjustment ? "wallet-adjustment" : "wallet"}');
    expect(source).toContain("onAdjustmentIntentDismissed={dismissWalletAdjustmentIntent}");
  });

  it("keeps related content in one card and uses compact empty states", () => {
    const source = readFileSync(detailPagePath, "utf8");
    const styles = readFileSync(detailStylesPath, "utf8");
    const supportSource = readFileSync(supportPanelPath, "utf8");

    expect(source).toContain("title={workspaceText.tabContent}");
    expect(source).not.toContain("<AdminCard title={workspaceText.contentGenerations}>");
    expect(source).toContain("className={styles.contentSection}");
    expect(source).toContain("className={styles.inlineEmptyState}");
    expect(styles).toContain(".contentSection + .contentSection");
    expect(styles).toContain(".contentSplit");
    expect(styles).toContain(".inlineEmptyState");
    expect(styles).toContain("@media (min-width: 860px)");
    expect(supportSource).toContain("className={styles.supportEmptyState}");
    expect(supportSource).toContain('<div key={ticket.conversationId} role="listitem">');
    expect(supportSource).not.toContain(
      'aria-label={`${text.supportOpenTicket}: ${preview}. ${updatedAt}`}\n                    role="listitem"'
    );
    expect(supportSource).toContain("const ticketAccessibleLabel = [");
    expect(supportSource).toContain("aria-label={ticketAccessibleLabel}");
    expect(styles).toContain(".supportEmptyState");
    expect(styles).toContain('.supportList > [role="listitem"]:last-child .supportTicket');
    expect(styles).not.toContain(".accessGrid");
    expect(supportSource).not.toContain("supportOpenAction");
  });
});
