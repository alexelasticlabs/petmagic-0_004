import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  formatSafeSupportDownloadName,
  getMessageAttachments,
} from "@/components/support/support-conversation-helpers";

import { readSupportConversationPageLibrarySource } from "./support-conversation-page.test-source";
import { readSupportInfoPanelLibrarySource } from "./support-info-panel.test-source";

const supportHelpersPath = fileURLToPath(
  new URL("./support-conversation-helpers.ts", import.meta.url)
);
const supportContentPath = fileURLToPath(
  new URL("./support-conversation.content.ts", import.meta.url)
);
const supportSecureMediaPath = fileURLToPath(
  new URL("./support-secure-media.tsx", import.meta.url)
);

describe("support sensitive display", () => {
  it("sanitizes activity timeline values before rendering them in support panels", () => {
    const source = readFileSync(supportHelpersPath, "utf8");

    expect(source).toContain("title: formatSafeSupportDisplay(item.title, item.kind, 120)");
    expect(source).toContain(
      "subtitle: formatSafeSupportDisplay(item.details || item.kind, item.kind, 180)"
    );
    expect(source).toContain('title: formatSafeSupportDisplay(item.action, "Audit event", 120)');
    expect(source).toContain('subtitle: formatSafeSupportDisplay(item.details, "—", 180)');
    expect(source).not.toContain("title: item.title");
    expect(source).not.toContain("subtitle: item.details || item.kind");
    expect(source).not.toContain("title: item.action");
    expect(source).not.toContain("subtitle: item.details,");
  });

  it("keeps support money formatting non-throwing for backend currency codes", () => {
    const source = readFileSync(supportHelpersPath, "utf8");

    expect(source).toContain(
      'const safeCurrencyCode = formatSafeSupportDisplay(currencyCode?.toUpperCase(), "USD", 12)'
    );
    expect(source).toContain("currency: safeCurrencyCode");
    expect(source).toContain("Fall through to a non-throwing display");
    expect(source).not.toContain("currency: currencyCode");
  });

  it("sanitizes support info panel failure and purchase labels", () => {
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(infoPanelSource).toContain(
      'formatSafeSupportDisplay(purchase.paymentProvider, "—", 48)'
    );
    expect(infoPanelSource).toMatch(
      /formatSafeSupportDisplay\(\s*purchase\.currencyCode,\s*"—",\s*12\s*\)/
    );
    expect(infoPanelSource).toContain('formatSafeSupportDisplay(purchase.status, "—", 48)');
    expect(infoPanelSource).toContain('formatSafeSupportDisplay(item.failureCode, "—", 120)');
    expect(infoPanelSource).not.toContain("<strong>{purchase.paymentProvider}</strong>");
    expect(infoPanelSource).not.toContain("{`${purchase.priceAmount} ${purchase.currencyCode}");
    expect(infoPanelSource).not.toContain("<strong>{item.failureCode}</strong>");
  });

  it("sanitizes operator tags and keeps tag input bounded", () => {
    const source = readSupportInfoPanelLibrarySource();
    const contentSource = readFileSync(supportContentPath, "utf8");

    expect(source).toContain(
      "const panelText = useMemo(() => getSupportConversationCopy(locale).infoPanel, [locale]);"
    );
    expect(source).toContain("formatSafeSupportDisplay(tag, panelText.tagFallback, 40)");
    expect(source).toContain("aria-label={panelText.addTag}");
    expect(source).toContain("title={panelText.removeTag}");
    expect(source).toContain("setTagInput(event.target.value.slice(0, 40))");
    expect(source).toContain("maxLength={40}");
    expect(source).toContain("disabled={!canManageSupportWorkspace || !tagInput.trim()}");
    expect(contentSource).toContain('tagFallback: "Тег"');
    expect(contentSource).toContain('tagFallback: "Tag"');
    expect(source).not.toContain(
      'formatSafeSupportDisplay(tag, locale === "ru" ? "Тег" : "Tag", 40)'
    );
    expect(source).not.toContain('{tag} <span aria-hidden="true">×</span>');
    expect(source).not.toContain("onChange={(event) => setTagInput(event.target.value)}");
  });

  it("sanitizes support attachment download filenames", () => {
    const supportPageSource = readSupportConversationPageLibrarySource();
    const sanitized = formatSafeSupportDownloadName(
      "alice@example.com receipt=ios-secret token=raw-secret card_number=4242424242424242/../photo.png"
    );

    expect(sanitized).toContain("alxxx@exxx.com");
    expect(sanitized).toContain("receipt=[redacted]");
    expect(sanitized).toContain("token=[redacted]");
    expect(sanitized).toContain("card_number=[redacted]");
    expect(sanitized).not.toContain("alice@example.com");
    expect(sanitized).not.toContain("ios-secret");
    expect(sanitized).not.toContain("raw-secret");
    expect(sanitized).not.toContain("4242424242424242");
    expect(sanitized).not.toMatch(/[\\/:*?"<>|]/);

    expect(supportPageSource).toContain(
      "formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)"
    );
    expect(supportPageSource).toContain("formatSafeSupportDownloadName(attachment.fileName)");
    expect(supportPageSource).not.toContain(
      "link.download = fullscreenImage.fileName?.trim() || defaultFileName"
    );
    expect(supportPageSource).not.toContain(
      'link.download = attachment.fileName?.trim() || "attachment"'
    );
  });

  it("sanitizes support message bodies, reply previews, share filenames, and short ids", () => {
    const helperSource = readFileSync(supportHelpersPath, "utf8");
    const supportPageSource = readSupportConversationPageLibrarySource();
    const contentSource = readFileSync(supportContentPath, "utf8");

    expect(helperSource).toContain('const safeValue = formatSafeSupportDisplay(value, "—", 32)');
    expect(helperSource).not.toContain("return value.length > 8");
    expect(supportPageSource).toContain(
      "const safeFileName = formatSafeSupportDownloadName(\n        currentFullscreenImage.fileName,\n        defaultFileName\n      )"
    );
    expect(supportPageSource).toContain("imageViewerLabels.supportAttachmentFallback");
    expect(contentSource).toContain('supportAttachmentFallback: "Вложение поддержки"');
    expect(contentSource).toContain('supportAttachmentFallback: "Support attachment"');
    expect(supportPageSource).toMatch(/formatSafeSupportDisplay\(\s*message\.replyToPreview/);
    expect(supportPageSource).toContain('formatSafeSupportDisplay(message.body, "", 2000)');
    expect(supportPageSource).toContain("const requestInboxRetry = () => {");
    expect(supportPageSource).toContain("if (isQueueControlsLocked) {\n      return;\n    }");
    expect(supportPageSource).toContain("void inboxQuery.refetch().catch(() => undefined);");
    expect(supportPageSource).toContain("onClick={requestInboxRetry}");
    expect(supportPageSource).toMatch(
      /disabled=\{!canManageSupportWorkspace \|\| (inboxQuery\.isFetching|inboxQueryIsFetching)\}/
    );
    expect(supportPageSource).not.toContain(
      "<div className={styles.messageBody}>{message.body}</div>"
    );
    expect(supportPageSource).not.toContain(
      "const file = new File([blob], fullscreenImage.fileName?.trim() || defaultFileName"
    );
  });

  it("normalizes attachment payloads before support surfaces inspect mime types", () => {
    const attachments = getMessageAttachments({
      attachments: [
        {
          fileUrl: "https://cdn.example.com/a",
          fileName: "   ",
          type: "legacy",
          mimeType: "",
          sizeBytes: 128,
        },
      ],
      attachmentUrl: null,
      attachmentContentType: null,
      attachmentFileName: null,
      attachmentFileSizeBytes: null,
    });

    expect(attachments).toHaveLength(1);
    expect(attachments[0]?.fileName).toBe("attachment");
    expect(attachments[0]?.mimeType).toBe("application/octet-stream");
  });

  it("keeps support secure media telemetry sanitized", () => {
    const secureMediaSource = readFileSync(supportSecureMediaPath, "utf8");

    expect(secureMediaSource).toContain("import { sanitizeSensitiveText }");
    expect(secureMediaSource).toContain("const activeObjectUrlRef = useRef<string | null>(null);");
    expect(secureMediaSource).toContain("const revokeActiveObjectUrl = useCallback(");
    expect(secureMediaSource).toContain("const markRemoteMediaFailed = useCallback(");
    expect(secureMediaSource).toContain(
      "revokeActiveObjectUrl();\n        activeObjectUrlRef.current = createdObjectUrl;"
    );
    expect(secureMediaSource).toContain(
      "if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl)"
    );
    expect(secureMediaSource).toContain("onError={markRemoteMediaFailed}");
    expect(secureMediaSource).toContain("function formatSupportMediaLogText(");
    expect(secureMediaSource).toContain("function getSupportMediaErrorDetails(error: unknown)");
    expect(secureMediaSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(secureMediaSource).toContain(
      "messageId: formatSupportMediaLogText(logContext?.messageId)"
    );
    expect(secureMediaSource).toContain(
      "mimeType: formatSupportMediaLogText(logContext?.mimeType)"
    );
    expect(secureMediaSource).toContain("...getSupportMediaErrorDetails(error)");
    expect(secureMediaSource).not.toContain(
      "mimeType: logContext?.mimeType,\n          kind,\n          error"
    );
  });
});
