import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const moderationPagePath = fileURLToPath(new URL("./moderation-page.tsx", import.meta.url));
const moderationContentPath = fileURLToPath(
  new URL("./moderation-page.content.ts", import.meta.url)
);
const moderationStylesPath = fileURLToPath(
  new URL("./moderation-page.module.css", import.meta.url)
);

describe("moderation page sensitive display", () => {
  it("sanitizes queue messages and moderation comments before rendering or confirming", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function formatModerationText");
    expect(source).toContain("sanitizeSensitiveText(trimmed || fallback, maxLength)");
    expect(source).toContain("formatModerationText(item.message)");
    expect(source).toContain("formatModerationText(item.moderationComment)");
    expect(source).toContain("description={formatModerationText(");
    expect(source).not.toContain('<span className={styles.message}>{item.message ?? "-"}</span>');
    expect(source).not.toContain("<div className={styles.meta}>{item.moderationComment}</div>");
    expect(source).not.toContain("description={decision?.item.message");
  });

  it("sanitizes moderation template and source metadata before rendering", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain('formatModerationText(item.templateTitle, "-", 120)');
    expect(source).toContain('formatModerationText(item.source, "-", 64)');
    expect(source).toContain('formatModerationText(item.deviceClass, "-", 32)');
    expect(source).toContain('formatModerationText(item.countryCode, "-", 8)');
    expect(source).toContain("return sanitizeSensitiveText(templateType, 48);");
    expect(source).toContain('const safeValue = sanitizeSensitiveText(value?.trim() || "-", 32);');
    expect(source).toContain('return safeValue === "-" ? safeValue : safeValue.slice(0, 8);');
    expect(source).not.toContain("<strong>{item.templateTitle}</strong>");
    expect(source).not.toContain("{item.source}\n");
    expect(source).not.toContain("{item.deviceClass} / {item.countryCode}");
    expect(source).not.toContain('return value ? value.slice(0, 8) : "-";');
    expect(source).not.toContain("return templateType;");
  });

  it("keeps moderation queue error and pagination states recoverable", () => {
    const source = readFileSync(moderationPagePath, "utf8");
    const contentSource = readFileSync(moderationContentPath, "utf8");
    const stylesSource = readFileSync(moderationStylesPath, "utf8");

    expect(source).toContain("queueQuery.refetch().catch(() => undefined)");
    expect(source).toContain("disabled={!canModerate || isQueueContextLocked || queueQuery.isFetching}");
    expect(source).toContain("function requestQueueRetry()");
    expect(source).toContain(
      "if (!canModerate || isQueueContextLocked || queueQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestQueueRetry}");
    expect(source).toContain("void queueQuery.refetch().catch(() => undefined);");
    expect(source).toContain("description={getAdminErrorMessage(queueQuery.error, text.error)}");
    expect(source).toContain('aria-busy={queueQuery.isFetching ? "true" : undefined}');
    expect(source).toContain("const visibleItems = queueQuery.isPlaceholderData ? [] : items;");
    expect(source).toContain(
      "const isQueueRefreshing = queueQuery.isFetching && queueQuery.isPlaceholderData;"
    );
    expect(source).toContain("queueQuery.isLoading || isQueueRefreshing ? (");
    expect(source).toContain(") : visibleItems.length === 0 ? (");
    expect(source).toContain("visibleItems.map((item) => (");
    expect(source).not.toContain("items.map((item) => (");
    expect(source).toContain("<span className={styles.pageInfo}>");
    expect(source).toContain("const text = getModerationPageText(locale);");
    expect(contentSource).toContain('pageLabel: "Страница"');
    expect(contentSource).toContain('pageLabel: "Page"');
    expect(contentSource).toContain('previousPageLabel: "Предыдущая страница очереди"');
    expect(contentSource).toContain('previousPageLabel: "Previous queue page"');
    expect(contentSource).toContain('nextPageLabel: "Следующая страница очереди"');
    expect(contentSource).toContain('nextPageLabel: "Next queue page"');
    expect(source).toContain('import { CaretDownIcon } from "@/components/admin/admin-icons";');
    expect(source).toContain('className={`${styles.button} ${styles.pagerButton}`}');
    expect(source).toContain("{text.pageLabel} {page + 1}");
    expect(source).toContain("disabled={page === 0 || isQueueContextLocked || queueQuery.isFetching}");
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("title={text.previousPageLabel}");
    expect(source).toContain(
      "disabled={!queueQuery.data?.hasMore || isQueueContextLocked || queueQuery.isFetching}"
    );
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("title={text.nextPageLabel}");
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />'
    );
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />'
    );
    expect(source).not.toContain("{text.previous}");
    expect(source).not.toContain("{text.next}");
    expect(stylesSource).toContain("@media (max-width: 520px)");
    expect(stylesSource).toContain(".pageInfo {\n    width: 100%;\n    margin-right: 0;");
    expect(stylesSource).toContain(".pagerButton");
    expect(stylesSource).toContain(".pageIconPrevious");
    expect(stylesSource).toContain(".pageIconNext");
    expect(stylesSource).toContain(".pager .button:not(.pagerButton) {\n    flex: 1 1 8rem;");
    expect(stylesSource).toContain(".pagerButton {\n    flex: 0 0 auto;");
  });

  it("uses localized display labels for moderation actions and statuses", () => {
    const source = readFileSync(moderationPagePath, "utf8");
    const contentSource = readFileSync(moderationContentPath, "utf8");

    expect(source).toContain(
      'import {\n  getModerationPageText,\n  type ModerationPageText,\n} from "@/components/moderation-page.content";'
    );
    expect(source).toContain("const text = getModerationPageText(locale);");
    expect(contentSource).toContain('eyebrow: "Безопасность контента"');
    expect(contentSource).toContain('eyebrow: "Content safety"');
    expect(contentSource).toContain('searchPlaceholder: "шаблон, сообщение, user/generation id"');
    expect(contentSource).toContain('searchPlaceholder: "template, message, user/generation id"');
    expect(contentSource).toContain('approve: "Одобрить"');
    expect(contentSource).toContain('approve: "Approve"');
    expect(contentSource).toContain('reject: "Отклонить"');
    expect(contentSource).toContain('reject: "Reject"');
    expect(contentSource).toContain('next: "Вперёд"');
    expect(contentSource).toContain('statusPending: "Ожидает"');
    expect(contentSource).toContain('statusApproved: "Одобрено"');
    expect(contentSource).toContain('statusRejected: "Отклонено"');
    expect(contentSource).toContain('workspaceBadge: "Модератор"');
    expect(contentSource).toContain('approveItemLabel: "Одобрить элемент"');
    expect(contentSource).toContain('rejectItemLabel: "Отклонить элемент"');
    expect(source).toContain('badge={<AdminBadge tone="info">{text.workspaceBadge}</AdminBadge>}');
    expect(source).toContain(
      "aria-label={`${text.approveItemLabel}: ${formatModerationText("
    );
    expect(source).toContain(
      "aria-label={`${text.rejectItemLabel}: ${formatModerationText("
    );
    expect(source).toContain("formatModerationStatus(item.status, text)");
    expect(source).toContain("formatModerationEvent(item.eventType, text)");
    expect(source).toContain("formatTemplateType(item.templateType, text)");
    expect(source).not.toContain("function getCopy(locale: Locale)");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(source).not.toContain('? "template, message, user/generation id"');
    expect(source).not.toContain('next: isRu ? "Вперед" : "Next"');
    expect(source).not.toContain('badge={<AdminBadge tone="info">Moderator</AdminBadge>}');
  });

  it("uses theme tokens for moderation status badge colors", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain('if (status === "approved") return "var(--success)"');
    expect(source).toContain('if (status === "rejected") return "var(--danger)"');
    expect(source).toContain('return "var(--warning)"');
    expect(source).toContain("color={statusColor(item.status)}");
    expect(source).not.toContain('return "#22c55e";');
    expect(source).not.toContain('return "#ef4444";');
    expect(source).not.toContain('return "#f59e0b";');
  });

  it("guards moderation decisions against stale rows and repeated submit", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain('import { clientLogger } from "@/lib/client-logger";');
    expect(source).toContain("function getModerationDecisionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("function getModerationDecisionContext(decision: DecisionState | null)");
    expect(source).toContain("eventId: decision?.item.eventId ? sanitizeSensitiveText(decision.item.eventId, 80) : undefined");
    expect(source).toContain("templateId: decision?.item.templateId");
    expect(source).toContain('clientLogger.warn("moderation.decision_failed", {');
    expect(source).toContain("...getModerationDecisionContext(decision)");
    expect(source).toContain("...getModerationDecisionErrorDetails(error)");
    expect(source).toContain("MODERATION_SEARCH_MAX_LENGTH,");
    expect(source).toContain("MODERATION_DECISION_REASON_MAX_LENGTH,");
    expect(source).toContain(
      "const trimmedReason = reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH);"
    );
    expect(source).toContain(
      "setSearch(event.target.value.slice(0, MODERATION_SEARCH_MAX_LENGTH));"
    );
    expect(source).toContain("maxLength={MODERATION_SEARCH_MAX_LENGTH}");
    expect(source).toContain(
      "setReason(event.target.value.slice(0, MODERATION_DECISION_REASON_MAX_LENGTH));"
    );
    expect(source).toContain("maxLength={MODERATION_DECISION_REASON_MAX_LENGTH}");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("useRef,");
    expect(source).toContain(
      "const [isDecisionInFlight, setIsDecisionInFlight] = useState(false);"
    );
    expect(source).toContain("const decisionInFlightRef = useRef(false);");
    expect(source).toContain(
      "const isDecisionSubmitting = isDecisionInFlight || decisionMutation.isPending;"
    );
    expect(source).toContain("const isDecisionDraftOpen = Boolean(decision);");
    expect(source).toContain(
      "const isQueueContextLocked = isDecisionDraftOpen || isDecisionSubmitting;"
    );
    expect(source).toContain("enabled: canModerate");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain(
      'const canModerate = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("text.moderationActionsForbidden");
    expect(source).toContain("function assertCanModerate(): boolean");
    expect(source).toContain(
      'setToast({ type: "error", message: text.moderationActionsForbidden });'
    );
    expect(source).toContain(
      "if (!assertCanModerate()) throw new Error(text.moderationActionsForbidden);"
    );
    expect(source).toContain("onSettled: () => {\n      decisionInFlightRef.current = false;");
    expect(source).toContain("setIsDecisionInFlight(false);");
    expect(source).toContain(
      'if (decisionInFlightRef.current || decisionMutation.isPending || item.status !== "pending") {\n      return;'
    );
    expect(source).toContain(
      "if (!assertCanModerate()) {\n      return;\n    }\n\n    setDecision({ item, action });"
    );
    expect(source).toContain(
      "if (decisionInFlightRef.current || decisionMutation.isPending) {\n      return;"
    );
    expect(source).toContain(
      "if (!assertCanModerate()) {\n      return;\n    }\n\n    if (!isReasonValid)"
    );
    expect(source).toContain("decisionInFlightRef.current = true;");
    expect(source).toContain("setIsDecisionInFlight(true);");
    expect(source).toContain("function resetDecisionDraft()");
    expect(source).toContain(
      "if (decisionInFlightRef.current || decisionMutation.isPending) {\n      return;\n    }\n\n    setDecision(null);\n    setReason(\"\");\n    setReasonError(null);"
    );
    expect(source).toContain("function resetQueueContext(nextPage = 0)");
    expect(source).toContain("if (isQueueContextLocked) {\n      return;\n    }");
    expect(source).toContain("resetDecisionDraft();\n    setPage(nextPage);");
    expect(source).toContain("resetQueueContext();");
    expect(source).toContain("onClick={() => resetQueueContext(Math.max(0, page - 1))}");
    expect(source).toContain("onClick={() => resetQueueContext(page + 1)}");
    expect(source).toContain(
      "const visibleEventIdSignature = visibleItems.map((item) => item.eventId).join(\"|\");"
    );
    expect(source).toContain("visibleEventIdSignature.split(\"|\").includes(decision.item.eventId)");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("isSubmitting={isDecisionSubmitting}");
    expect(source).toContain("disabled={isDecisionSubmitting}");
    expect(source).toContain("if (!decisionInFlightRef.current && !decisionMutation.isPending) {");
    expect(source).toContain("confirmDisabled={!canModerate || !isReasonValid}");
    expect(source).toContain("disabled={isQueueContextLocked}");
    expect(source).toContain("await Promise.allSettled([");
    expect(source).toContain(
      'queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] })'
    );
    expect(source).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.dashboard(locale) })"
    );
    expect(source).not.toContain(
      'await queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] });\n      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.dashboard(locale) });'
    );
    expect(source).toContain("throw new Error(text.decisionMissing)");
    expect(source).toContain('!canModerate || item.status !== "pending" || isDecisionSubmitting');
    expect(source).not.toContain("setSearch(event.target.value);");
    expect(source).not.toContain("setReason(event.target.value);");
    expect(source).not.toContain('throw new Error("Missing decision")');
    expect(source).not.toContain('clientLogger.warn("moderation.decision_failed", { error');
    expect(source).not.toContain("eventId: decision.item.eventId,\n        error");
  });

  it("uses the shared admin session guard before loading the moderation API", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain('import { useRouter } from "next/navigation";');
    expect(source).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(source).toContain("const router = useRouter();");
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain("enabled: canModerate");
    expect(source).toContain("{!canModerate ? <AdminStateCard title={text.loading} /> : null}");
    expect(source).toContain("{canModerate ? (\n      <AdminCard title={text.filtersTitle}>");
    expect(source).toContain("{canModerate ? (\n        queueQuery.isLoading || isQueueRefreshing ? (");
    expect(source).not.toContain("enabled: Boolean(session)");
    expect(source).not.toContain("disabled={!session || queueQuery.isFetching}");
  });

  it("keeps local moderation form controls accessible in locked and keyboard states", () => {
    const stylesSource = readFileSync(moderationStylesPath, "utf8");

    expect(stylesSource).toContain(".input:focus-visible,\n.select:focus-visible,\n.textarea:focus-visible,\n.button:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled,\n.select:disabled,\n.textarea:disabled");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
