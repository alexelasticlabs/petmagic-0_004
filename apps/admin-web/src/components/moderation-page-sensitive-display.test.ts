import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const moderationPagePath = fileURLToPath(new URL("./moderation-page.tsx", import.meta.url));
const moderationReviewDialogPath = fileURLToPath(
  new URL("./moderation-review-dialog.tsx", import.meta.url)
);
const moderationContentPath = fileURLToPath(
  new URL("./moderation-page.content.ts", import.meta.url)
);
const moderationStylesPath = fileURLToPath(
  new URL("./moderation-page.module.css", import.meta.url)
);

describe("moderation workspace hardening", () => {
  it("sanitizes queue, review, metadata, and error context before display or logging", () => {
    const pageSource = readFileSync(moderationPagePath, "utf8");
    const reviewSource = readFileSync(moderationReviewDialogPath, "utf8");

    expect(pageSource).toContain(
      'import { sanitizeSensitiveText } from "@/lib/sensitive-display";'
    );
    expect(pageSource).toContain("sanitizeSensitiveText(trimmed || fallback, maxLength)");
    expect(pageSource).toContain("formatModerationText(item.message");
    expect(pageSource).toContain("formatModerationText(item.moderationComment");
    expect(pageSource).toContain("formatModerationText(item.source");
    expect(pageSource).toContain("formatModerationText(item.deviceClass");
    expect(pageSource).toContain("formatModerationText(item.countryCode");
    expect(pageSource).toContain("getModerationDecisionErrorDetails(error)");
    expect(pageSource).not.toContain('clientLogger.warn("moderation.decision_failed", { error');

    expect(reviewSource).toContain(
      'import { sanitizeSensitiveText } from "@/lib/sensitive-display";'
    );
    expect(reviewSource).toContain("sanitizeSensitiveText(value?.trim() || fallback, maxLength)");
    expect(reviewSource).toContain("safeText(item.message, text.noMessage, 1_200)");
    expect(reviewSource).toContain('safeText(item.moderationComment, "-", 600)');
    expect(reviewSource).not.toContain("{item.message}");
    expect(reviewSource).not.toContain("{item.moderationComment}");
  });

  it("keeps moderation APIs behind the shared session and role guard", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain(
      'const canModerate = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("enabled: canModerate");
    expect(source).toContain("if (!assertCanModerate())");
    expect(source).toContain("text.moderationActionsForbidden");
    expect(source).not.toContain("enabled: Boolean(session)");
  });

  it("requires an evidence review and audit reason before a pending decision", () => {
    const pageSource = readFileSync(moderationPagePath, "utf8");
    const reviewSource = readFileSync(moderationReviewDialogPath, "utf8");

    expect(pageSource).toContain("function openReview(");
    expect(pageSource).toContain("item: AdminModerationQueueItem,");
    expect(pageSource).toContain("action: ModerationDecisionAction | null = null");
    expect(pageSource).toContain('item.status !== "pending"');
    expect(pageSource).toContain("hasActiveModerationLease(item)");
    expect(pageSource).toContain("item.leaseOwnerUserId !== sessionUserId");
    expect(pageSource).toContain("setDecision({ item, action });");
    expect(pageSource).toContain("if (!decision?.action)");
    expect(pageSource).toContain("if (!isReasonValid)");
    expect(pageSource).toContain("decisionInFlightRef.current = true;");
    expect(pageSource).toContain("expectedVersion: decision.item.version ?? 0");
    expect(pageSource).toContain("disabled={!canModerate || isDecisionSubmitting}");
    expect(pageSource).toContain("<AdminDetailsDrawer");

    expect(reviewSource).toContain("<ConfirmationDialog");
    expect(reviewSource).toContain("initialFocusRef={approveButtonRef}");
    expect(reviewSource).toContain('size="large"');
    expect(reviewSource).toContain('aria-pressed={action === "approve"}');
    expect(reviewSource).toContain('aria-pressed={action === "reject"}');
    expect(reviewSource).toContain("normalizedReasonLength >= 3");
    expect(reviewSource).toContain("maxLength={MODERATION_DECISION_REASON_MAX_LENGTH}");
    expect(reviewSource).toContain("aria-invalid={Boolean(reasonError)}");
    expect(reviewSource).toContain("text.reasonHint");
  });

  it("handles stale decisions as a recoverable conflict and refreshes affected data", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain(
      'const MODERATION_DECISION_CONFLICT_CODE = "templates.moderation_decision_conflict";'
    );
    expect(source).toContain(
      "getModerationDecisionErrorCode(error) === MODERATION_DECISION_CONFLICT_CODE"
    );
    expect(source).toContain('setToast({ type: "error", message: text.decisionConflict });');
    expect(source).toContain("await invalidateModerationData();");
    expect(source).toContain(
      'queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] })'
    );
    expect(source).toContain('queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] })');
    expect(source).toContain(
      "const isQueueContextLocked = isDecisionDraftOpen || isDecisionSubmitting;"
    );
    expect(source).toContain("decisionInFlightRef.current || decisionMutation.isPending");
  });

  it("renders unfiltered queue health and uses the product select control", () => {
    const pageSource = readFileSync(moderationPagePath, "utf8");
    const contentSource = readFileSync(moderationContentPath, "utf8");

    expect(pageSource).toContain(
      'import { Select, type SelectOption } from "@/components/ui/select";'
    );
    expect(pageSource).toContain("summary.pendingCount.toLocaleString(locale)");
    expect(pageSource).toContain("summary.approvedCount.toLocaleString(locale)");
    expect(pageSource).toContain("summary.rejectedCount.toLocaleString(locale)");
    expect(pageSource).toContain("summary.pendingComplaintsCount.toLocaleString(locale)");
    expect(pageSource).toContain("summary.pendingFeedbackCount.toLocaleString(locale)");
    expect(pageSource).toContain("summary.oldestPendingAtUtc");
    expect(pageSource).toContain("showSelectedDescription={false}");
    expect(pageSource).not.toContain("<select");

    expect(contentSource).toContain('summaryScope: "По всей очереди, без учёта фильтров"');
    expect(contentSource).toContain("Across the full queue, regardless of active filters");
  });

  it("switches from a keyboard-scrollable table to semantic mobile cards", () => {
    const pageSource = readFileSync(moderationPagePath, "utf8");
    const stylesSource = readFileSync(moderationStylesPath, "utf8");

    expect(pageSource).toContain('role="region"');
    expect(pageSource).toContain("aria-label={text.queueRegionLabel}");
    expect(pageSource).toContain("tabIndex={0}");
    expect(pageSource).toContain("<caption className={styles.visuallyHidden}>");
    expect(pageSource).toContain("<ul");
    expect(pageSource).toContain("className={styles.mobileQueue}");
    expect(pageSource).toContain("<article className={styles.mobileCard}>");

    expect(stylesSource).toContain("@media (max-width: 1080px)");
    expect(stylesSource).toContain("@media (max-width: 860px)");
    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain("@media (max-width: 420px)");
    expect(stylesSource).toMatch(
      /\.tableRegion\s*\{[\s\S]*?display:\s*none;[\s\S]*?\.mobileQueue\s*\{[\s\S]*?display:\s*grid;/
    );
    expect(stylesSource).toContain("min-height: 2.75rem;");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
