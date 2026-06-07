import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportSidePanelPath = fileURLToPath(
  new URL("./support-conversation-side-panel.tsx", import.meta.url)
);
const supportSecureMediaPath = fileURLToPath(
  new URL("./support-secure-media.tsx", import.meta.url)
);

describe("support side panel attachment links", () => {
  it("does not expose legacy attachment URLs through image src or action links", () => {
    const source = readFileSync(supportSidePanelPath, "utf8");
    const secureMediaSource = readFileSync(supportSecureMediaPath, "utf8");

    expect(source).not.toContain("src={message.attachmentUrl");
    expect(source).not.toContain("href={message.attachmentUrl");
    expect(source).not.toContain("download={message.attachmentFileName");
    expect(source).toContain("<SupportSecureMedia");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(message.attachmentUrl");
    expect(secureMediaSource).toContain("fetchWithTimeout(url");
    expect(source).toContain("support.side_panel_attachment_fetch_failed");
  });

  it("aborts pending legacy attachment actions and does not log aborts as failures", () => {
    const source = readFileSync(supportSidePanelPath, "utf8");

    expect(source).toContain("attachmentActionAbortControllerRef.current?.abort()");
    expect(source).toContain("const controller = new AbortController()");
    expect(source).toContain("fetchAttachmentBlob(message, \"open\", controller.signal)");
    expect(source).toContain("fetchAttachmentBlob(message, \"download\", controller.signal)");
    expect(source).toContain("if (signal.aborted)");
  });
});
