import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const moderationPagePath = fileURLToPath(new URL("./moderation-page.tsx", import.meta.url));

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

    expect(source).toContain("queueQuery.refetch().catch(() => undefined)");
    expect(source).toContain("disabled={!session || queueQuery.isFetching}");
    expect(source).toContain(
      "if (!session) {\n                  return;\n                }\n\n                void queueQuery.refetch().catch(() => undefined);"
    );
    expect(source).toContain("description={getAdminErrorMessage(queueQuery.error, text.error)}");
    expect(source).toContain('aria-busy={queueQuery.isFetching ? "true" : undefined}');
    expect(source).toContain("<span className={styles.pageInfo}>");
    expect(source).toContain("disabled={page === 0 || queueQuery.isFetching}");
    expect(source).toContain("disabled={!queueQuery.data?.hasMore || queueQuery.isFetching}");
  });

  it("uses localized display labels for moderation actions and statuses", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain('approve: isRu ? "Одобрить" : "Approve"');
    expect(source).toContain('reject: isRu ? "Отклонить" : "Reject"');
    expect(source).toContain('statusPending: isRu ? "Ожидает" : "Pending"');
    expect(source).toContain('statusApproved: isRu ? "Одобрено" : "Approved"');
    expect(source).toContain('statusRejected: isRu ? "Отклонено" : "Rejected"');
    expect(source).toContain("formatModerationStatus(item.status, text)");
    expect(source).toContain("formatModerationEvent(item.eventType, text)");
    expect(source).toContain("formatTemplateType(item.templateType, text)");
  });

  it("guards moderation decisions against stale rows and repeated submit", () => {
    const source = readFileSync(moderationPagePath, "utf8");

    expect(source).toContain("MODERATION_SEARCH_MAX_LENGTH,");
    expect(source).toContain("MODERATION_DECISION_REASON_MAX_LENGTH,");
    expect(source).toContain(
      "const trimmedReason = reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH);"
    );
    expect(source).toContain("setSearch(event.target.value.slice(0, MODERATION_SEARCH_MAX_LENGTH));");
    expect(source).toContain("maxLength={MODERATION_SEARCH_MAX_LENGTH}");
    expect(source).toContain(
      "setReason(event.target.value.slice(0, MODERATION_DECISION_REASON_MAX_LENGTH));"
    );
    expect(source).toContain("maxLength={MODERATION_DECISION_REASON_MAX_LENGTH}");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("useRef,");
    expect(source).toContain("const [isDecisionInFlight, setIsDecisionInFlight] = useState(false);");
    expect(source).toContain("const decisionInFlightRef = useRef(false);");
    expect(source).toContain(
      "const isDecisionSubmitting = isDecisionInFlight || decisionMutation.isPending;"
    );
    expect(source).toContain("enabled: Boolean(session)");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain(
      'const canModerate = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("moderationActionsForbidden: isRu");
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
    expect(source).toContain("isSubmitting={isDecisionSubmitting}");
    expect(source).toContain("disabled={isDecisionSubmitting}");
    expect(source).toContain("if (!decisionInFlightRef.current && !decisionMutation.isPending) {");
    expect(source).toContain("confirmDisabled={!canModerate || !isReasonValid}");
    expect(source).toContain('await queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] });');
    expect(source).toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.dashboard(locale) });"
    );
    expect(source).toContain("throw new Error(text.decisionMissing)");
    expect(source).toContain(
      'disabled={!canModerate || item.status !== "pending" || isDecisionSubmitting}'
    );
    expect(source).not.toContain("setSearch(event.target.value);");
    expect(source).not.toContain("setReason(event.target.value);");
    expect(source).not.toContain('throw new Error("Missing decision")');
  });
});
