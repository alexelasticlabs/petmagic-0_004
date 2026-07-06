import { describe, expect, it } from "vitest";

import { readSupportInfoPanelLibrarySource } from "./support-info-panel.test-source";

describe("support info attachment links", () => {
  it("does not expose signed attachment URLs through open links or telemetry", () => {
    const source = readSupportInfoPanelLibrarySource();

    expect(source).not.toContain("href={attachment.fileUrl}");
    expect(source).not.toContain("src={attachment.fileUrl}");
    expect(source).not.toContain("url: attachment.fileUrl");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(attachment.fileUrl");
    expect(source).toContain("support.attachment_open_failed");
    expect(source).toContain("function getSupportInfoErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("function formatSupportInfoLogText(");
    expect(source).toContain("messageId: formatSupportInfoLogText(messageId)");
    expect(source).toContain("mimeType: formatSupportInfoLogText(attachment.mimeType)");
    expect(source).toContain("...getSupportInfoErrorDetails(error)");
    expect(source).toContain("formatSafeSupportDownloadName");
    expect(source).toContain(
      "function downloadSupportInfoBlobUrl(objectUrl: string, fileName: string): void"
    );
    expect(source).toContain("link.download = fileName;");
    expect(source).toContain("function revokeSupportInfoBlobUrlOnFailure(");
    expect(source).toContain("URL.revokeObjectURL(objectUrl);");
    expect(source).toContain("scheduleSupportInfoBlobUrlRevoke(objectUrl, 1000);");
    expect(source).toContain("scheduleSupportInfoBlobUrlRevoke(objectUrl, 60_000);");
    expect(source).not.toContain("mimeType: attachment.mimeType,\n        error");
  });

  it("aborts pending attachment opens on unmount and ignores abort errors", () => {
    const source = readSupportInfoPanelLibrarySource();

    expect(source).toContain("attachmentOpenAbortControllerRef.current?.abort()");
    expect(source).toContain("const controller = new AbortController()");
    expect(source).toContain("signal: controller.signal");
    expect(source).toContain("if (controller.signal.aborted)");
  });

  it("guards attachment opens by support workspace permissions", () => {
    const source = readSupportInfoPanelLibrarySource();

    expect(source).toContain(
      "if (!canManageSupportWorkspace || pendingAttachmentOpenKey !== null)"
    );
    expect(source).toContain(
      "disabled={!canManageSupportWorkspace || pendingAttachmentOpenKey !== null}"
    );
    expect(source.match(/pendingAttachmentOpenKey !== null/g) ?? []).toHaveLength(4);
    expect(source).not.toContain(
      "pendingAttachmentOpenKey ===\n                          getAttachmentOpenKey"
    );
    expect(source).not.toContain(
      "pendingAttachmentOpenKey ===\n                            getAttachmentOpenKey"
    );
  });

  it("falls back to safe blob downloads when attachment popups are blocked", () => {
    const source = readSupportInfoPanelLibrarySource();

    expect(source).toContain(
      'const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");'
    );
    expect(source).toContain("if (!opened) {");
    expect(source).toContain(
      "downloadSupportInfoBlobUrl(objectUrl, formatSafeSupportDownloadName(attachment.fileName));"
    );
    expect(source).toContain("scheduleSupportInfoBlobUrlRevoke(objectUrl, 1000);");
    expect(source).not.toContain(
      "if (!opened) {\n        URL.revokeObjectURL(objectUrl);\n        return;\n      }"
    );
  });

  it("revokes support info blob URLs immediately if open or fallback handoff throws", () => {
    const source = readSupportInfoPanelLibrarySource();

    expect(source).toContain("function revokeSupportInfoBlobUrlOnFailure(objectUrl: string");
    expect(source).toContain("} catch (error) {\n    URL.revokeObjectURL(objectUrl);");
    expect(source).toContain("revokeSupportInfoBlobUrlOnFailure(objectUrl, () => {");
  });
});
