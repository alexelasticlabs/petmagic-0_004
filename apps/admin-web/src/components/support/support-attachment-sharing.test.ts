import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportPagePath = fileURLToPath(
  new URL("./support-conversation-page.tsx", import.meta.url)
);

describe("support attachment sharing", () => {
  it("does not copy or share signed attachment URLs directly", () => {
    const source = readFileSync(supportPagePath, "utf8");

    expect(source).not.toContain("clipboard.writeText(fullscreenImage.url)");
    expect(source).not.toContain("url: fullscreenImage.url");
    expect(source).not.toContain("window.open(fullscreenImage.url");
    expect(source).not.toContain("href={attachment.fileUrl}");
    expect(source).not.toContain("src={attachment.fileUrl}");
    expect(source).not.toContain("src={fullscreenImage.url}");
    expect(source).toContain("files: [file]");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(image.attachmentFileUrl");
    expect(source).toContain("fetchWithTimeout(attachment.fileUrl");
  });

  it("aborts manual attachment fetches and guards fullscreen double actions", () => {
    const source = readFileSync(supportPagePath, "utf8");

    expect(source).toContain("fullscreenActionAbortControllerRef.current?.abort()");
    expect(source).toContain("attachmentActionAbortControllerRef.current?.abort()");
    expect(source).toContain("signal: controller.signal");
    expect(source).toContain("pendingFullscreenAction !== null");
    expect(source).toContain("disabled={pendingFullscreenAction !== null}");
    expect(source).toContain("if (controller.signal.aborted)");
  });
});
