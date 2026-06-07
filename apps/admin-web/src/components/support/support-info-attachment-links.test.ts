import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportInfoPanelPath = fileURLToPath(
  new URL("./support-info-panel.tsx", import.meta.url)
);

describe("support info attachment links", () => {
  it("does not expose signed attachment URLs through open links or telemetry", () => {
    const source = readFileSync(supportInfoPanelPath, "utf8");

    expect(source).not.toContain("href={attachment.fileUrl}");
    expect(source).not.toContain("src={attachment.fileUrl}");
    expect(source).not.toContain("url: attachment.fileUrl");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(attachment.fileUrl");
    expect(source).toContain("support.attachment_open_failed");
  });

  it("aborts pending attachment opens on unmount and ignores abort errors", () => {
    const source = readFileSync(supportInfoPanelPath, "utf8");

    expect(source).toContain("attachmentOpenAbortControllerRef.current?.abort()");
    expect(source).toContain("const controller = new AbortController()");
    expect(source).toContain("signal: controller.signal");
    expect(source).toContain("if (controller.signal.aborted)");
  });
});
