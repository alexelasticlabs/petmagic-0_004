import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { formatSupportMessagePreview } from "@/components/support/support-message-preview";

const adminShellPath = fileURLToPath(new URL("../admin-shell.tsx", import.meta.url));
const supportControllerHelpersPath = fileURLToPath(
  new URL("./support-conversation-controller.helpers.ts", import.meta.url)
);

describe("support message preview display", () => {
  it("masks sensitive user-generated preview text", () => {
    const preview = formatSupportMessagePreview(
      [
        "Contact alice@example.com",
        "https://cdn.example.com/pet.png?X-Amz-Signature=secret",
        "receipt=ios-secret",
        "token=raw-secret",
        "card_number=4242424242424242",
      ].join(" "),
      "Fallback",
      500
    );

    expect(preview).toContain("al***@e***.com");
    expect(preview).toContain("https://cdn.example.com/***");
    expect(preview).toContain("receipt=[redacted]");
    expect(preview).toContain("token=[redacted]");
    expect(preview).toContain("card_number=[redacted]");
    expect(preview).not.toContain("alice@example.com");
    expect(preview).not.toContain("X-Amz-Signature=secret");
    expect(preview).not.toContain("ios-secret");
    expect(preview).not.toContain("raw-secret");
    expect(preview).not.toContain("4242424242424242");
  });

  it("uses fallback and caps preview length", () => {
    expect(formatSupportMessagePreview("   ", "Fallback")).toBe("Fallback");
    expect(formatSupportMessagePreview("A ".repeat(100), "Fallback", 24)).toHaveLength(24);
  });

  it("keeps persisted admin realtime notifications free of user message previews", () => {
    const adminShellSource = readFileSync(adminShellPath, "utf8");
    const adminChromeSource = readFileSync(
      fileURLToPath(new URL("../admin/admin-chrome.content.ts", import.meta.url)),
      "utf8"
    );
    const supportControllerHelpersSource = readFileSync(supportControllerHelpersPath, "utf8");

    expect(adminShellSource).toContain("message: copy.realtimeSupport.fallback");
    expect(adminShellSource).not.toContain("formatSupportMessagePreview(event.lastMessagePreview");
    expect(adminShellSource).not.toContain("copy.realtimeSupport.withPreview");
    expect(adminChromeSource).not.toContain("withPreview");
    expect(supportControllerHelpersSource).not.toContain("lastMessagePreview");
    expect(supportControllerHelpersSource).not.toContain("realtimeMessageWithPreview");
    expect(adminShellSource).not.toContain("event.lastMessagePreview?.trim()");
  });

  it("encodes support realtime notification route ids before building hrefs", () => {
    const adminShellSource = readFileSync(adminShellPath, "utf8");

    expect(adminShellSource).toContain(
      "const supportConversationPathId = encodeURIComponent(event.conversationId);"
    );
    expect(adminShellSource).toContain("href: `/${locale}/support/${supportConversationPathId}`");
    expect(adminShellSource).not.toContain("href: `/${locale}/support/${event.conversationId}`");
  });
});
