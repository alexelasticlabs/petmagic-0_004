import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportRealtimePath = fileURLToPath(new URL("./support-realtime.ts", import.meta.url));

describe("support realtime connection policy", () => {
  it("shares one SignalR connection across admin-shell and support workspace subscribers", () => {
    const source = readFileSync(supportRealtimePath, "utf8");

    expect(source).toContain("let supportRealtimeConnection: HubConnection | null = null;");
    expect(source).toContain(
      'export type SupportRealtimeStatus = "idle" | "connecting" | "connected" | "unavailable";'
    );
    expect(source).toContain('let supportRealtimeStatus: SupportRealtimeStatus = "idle";');
    expect(source).toContain("const supportRealtimeStatusListeners = new Set<() => void>();");
    expect(source).toContain(
      "const supportRealtimeListeners = new Set<(event: SupportConversationUpdatedEvent) => void>();"
    );
    expect(source).toContain("const status = useSyncExternalStore(");
    expect(source).toContain("subscribeToSupportRealtimeStatus,");
    expect(source).toContain("getSupportRealtimeStatus,");
    expect(source).toContain("supportRealtimeStatusListeners.add(listener);");
    expect(source).toContain("supportRealtimeStatusListeners.delete(listener);");
    expect(source).toContain("supportRealtimeListeners.add(listener);");
    expect(source).toContain("supportRealtimeListeners.delete(listener);");
    expect(source).toContain("if (supportRealtimeListeners.size === 0) {");
    expect(source).toContain("stopSupportRealtimeConnection();");
    expect(source).toContain(
      "if (supportRealtimeConnection && supportRealtimeAccessToken === accessToken) {"
    );
    expect(source).toContain("return;");
    expect(source).toContain("for (const listener of [...supportRealtimeListeners]) {");
    expect(source).toContain("listener(event);");
    expect(source).toContain(".configureLogging(LogLevel.None)");
    expect(source).toContain("return status;");
    expect(source).toContain('setSupportRealtimeStatus("connecting");');
    expect(source).toContain('setSupportRealtimeStatus("connected");');
    expect(source).toContain('setSupportRealtimeStatus("unavailable");');
    expect(source).not.toContain("let isDisposed = false;");
  });

  it("logs only unexpected realtime failures with sanitized diagnostics", () => {
    const source = readFileSync(supportRealtimePath, "utf8");

    expect(source).toContain('import { sanitizeSensitiveText } from "@/lib/sensitive-display";');
    expect(source).toContain("function getSupportRealtimeErrorDetails(error: unknown)");
    expect(source).toContain("function logUnexpectedSupportRealtimeFailure(");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("...getSupportRealtimeErrorDetails(error)");
    expect(source).toContain(
      'logUnexpectedSupportRealtimeFailure("support.realtime_closed", error);'
    );
    expect(source).toContain(
      'logUnexpectedSupportRealtimeFailure("support.realtime_start_failed", error);'
    );
    expect(source).toContain(
      '} else {\n      setSupportRealtimeStatus("idle");\n      logUnexpectedSupportRealtimeFailure('
    );
    expect(source).not.toContain("blockedUntil: supportRealtimeBlockedUntil,\n      error,");
    expect(source).not.toContain("blockedUntil: supportRealtimeBlockedUntil,\n        error,");
    expect(source).not.toContain('clientLogger.warn("support.realtime_closed", {');
    expect(source).not.toContain('clientLogger.warn("support.realtime_start_failed", {');
  });

  it("bounds and validates realtime event payloads before notifying subscribers", () => {
    const source = readFileSync(supportRealtimePath, "utf8");

    expect(source).toContain("const supportRealtimeIdMaxLength = 128;");
    expect(source).toContain("function normalizeSupportRealtimeString(value: unknown");
    expect(source).toContain("sanitizeSensitiveText(value, maxLength)");
    expect(source).toContain("function normalizeSupportRealtimeCount(value: unknown)");
    expect(source).toContain("!Number.isSafeInteger(value) || value < 0");
    expect(source).toContain(
      "const conversationId = normalizeSupportRealtimeString(\n    candidate.conversationId,"
    );
    expect(source).toContain("if (!conversationId || !initiatorUserId || !updatedAtUtc) {");
    expect(source).not.toContain("lastMessagePreview?: string | null;");
    expect(source).not.toContain("supportRealtimePreviewMaxLength");
    expect(source).not.toContain("candidate.lastMessagePreview");
    expect(source).not.toContain(
      'typeof candidate.lastMessagePreview === "string" ? candidate.lastMessagePreview : null'
    );
    expect(source).not.toContain(
      'typeof candidate.adminUnreadCount === "number" ? candidate.adminUnreadCount : undefined'
    );
  });
});
