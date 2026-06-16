import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportRealtimePath = fileURLToPath(new URL("./support-realtime.ts", import.meta.url));

describe("support realtime connection policy", () => {
  it("shares one SignalR connection across admin-shell and support workspace subscribers", () => {
    const source = readFileSync(supportRealtimePath, "utf8");

    expect(source).toContain("let supportRealtimeConnection: HubConnection | null = null;");
    expect(source).toContain(
      "const supportRealtimeListeners = new Set<(event: SupportConversationUpdatedEvent) => void>();"
    );
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
    expect(source).not.toContain("let isDisposed = false;");
  });

  it("logs realtime failures with sanitized diagnostics", () => {
    const source = readFileSync(supportRealtimePath, "utf8");

    expect(source).toContain('import { sanitizeSensitiveText } from "@/lib/sensitive-display";');
    expect(source).toContain("function getSupportRealtimeErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("...getSupportRealtimeErrorDetails(error)");
    expect(source).toContain('clientLogger.warn("support.realtime_closed", {');
    expect(source).toContain('clientLogger.warn("support.realtime_start_failed", {');
    expect(source).not.toContain("blockedUntil: supportRealtimeBlockedUntil,\n      error,");
    expect(source).not.toContain("blockedUntil: supportRealtimeBlockedUntil,\n        error,");
  });
});
