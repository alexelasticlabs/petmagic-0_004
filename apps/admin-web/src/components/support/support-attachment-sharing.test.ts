import { describe, expect, it } from "vitest";

import { readSupportConversationPageLibrarySource } from "./support-conversation-page.test-source";

describe("support attachment sharing", () => {
  it("does not copy or share signed attachment URLs directly", () => {
    const source = readSupportConversationPageLibrarySource();

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
    expect(source).toContain("function getSupportActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("function formatSupportLogText(");
    expect(source).toContain("messageId: formatSupportLogText(");
    expect(source).toContain("mimeType: formatSupportLogText(attachment.mimeType)");
    expect(source).toContain("mediaType: formatSupportLogText(image.mediaType)");
    expect(source).toContain("...getSupportActionErrorDetails(error)");
    expect(source).toContain(
      "function downloadSupportBlobUrl(objectUrl: string, fileName: string): void"
    );
    expect(source).toContain("link.download = fileName;");
    expect(source).not.toContain("mediaType: image.mediaType,\n        error");
    expect(source).not.toContain("mimeType: attachment.mimeType,\n        error");
    expect(source).not.toContain("messageId: currentFullscreenImage.messageId,\n        error");
  });

  it("aborts manual attachment fetches and guards fullscreen double actions", () => {
    const source = readSupportConversationPageLibrarySource();

    expect(source).toContain("fullscreenActionAbortControllerRef.current?.abort()");
    expect(source).toContain("attachmentActionAbortControllerRef.current?.abort()");
    expect(source).toContain("fullscreenActionAbortControllerRef.current = null;");
    expect(source).toContain("attachmentActionAbortControllerRef.current = null;");
    expect(source).toContain("signal: controller.signal");
    expect(source).toContain(
      "if (!canManageSupportWorkspace || !fullscreenImage || pendingFullscreenAction !== null)"
    );
    expect(source).toContain(
      "if (!canManageSupportWorkspace || pendingAttachmentActionKey !== null)"
    );
    expect(source).toContain("pendingFullscreenAction !== null");
    expect(source).toContain(
      "disabled={!canManageSupportWorkspace || pendingFullscreenAction !== null}"
    );
    expect(source).toMatch(/!canManageSupportWorkspace \|\|\s+pendingAttachmentActionKey !== null/);
    expect(source).not.toContain(
      "pendingAttachmentActionKey ===\n          getAttachmentActionKey"
    );
    expect(source).toContain("if (controller.signal.aborted)");
  });

  it("falls back to a safe blob download when fullscreen open is blocked", () => {
    const source = readSupportConversationPageLibrarySource();

    expect(source).toContain(
      'const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");'
    );
    expect(source).toContain("if (!opened) {");
    expect(source).toContain(
      "downloadSupportBlobUrl(\n          objectUrl,\n          formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)"
    );
    expect(source).toContain("window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);");
    expect(source).not.toContain(
      "if (!opened) {\n        URL.revokeObjectURL(objectUrl);\n        return;\n      }"
    );
  });

  it("falls back to a safe blob download when fullscreen file sharing is unavailable", () => {
    const source = readSupportConversationPageLibrarySource();

    expect(source).toContain("function fallbackToDownload(reason: string)");
    expect(source).toContain("reason: formatSupportLogText(reason)");
    expect(source).toContain("const objectUrl = URL.createObjectURL(blob);");
    expect(source).toContain("downloadSupportBlobUrl(objectUrl, safeFileName);");
    expect(source).toContain("window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);");
    expect(source).toContain(
      'if (!browserNavigator.share) {\n        fallbackToDownload("navigator_share_missing");\n        return;\n      }'
    );
    expect(source).toContain('fallbackToDownload("file_share_unsupported");');
    expect(source).not.toContain(
      'if (!browserNavigator.share) {\n        clientLogger.warn("support.fullscreen_share_unsupported"'
    );
  });

  it("defers fullscreen blob URL cleanup until after download handoff", () => {
    const source = readSupportConversationPageLibrarySource();

    expect(source).toContain(
      "downloadSupportBlobUrl(\n        objectUrl,\n        formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)\n      );"
    );
    expect(source).toContain("window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);");
    expect(source).not.toContain(
      "downloadSupportBlobUrl(\n        objectUrl,\n        formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)\n      );\n      URL.revokeObjectURL(objectUrl);"
    );
  });

  it("clears stale fullscreen and attachment action state when switching conversations", () => {
    const source = readSupportConversationPageLibrarySource();

    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("setFullscreenImage(null);");
    expect(source).toContain("setPendingFullscreenAction(null);");
    expect(source).toContain("setPendingAttachmentActionKey(null);");
    expect(source).toContain("setHighlightedMessageId(null);");
    expect(source).toContain("setIsDragging(false);");
    expect(source).toContain("}, [conversationId]);");
  });
});
