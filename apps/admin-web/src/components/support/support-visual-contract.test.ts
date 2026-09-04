import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readSupportConversationPageLibrarySource } from "./support-conversation-page.test-source";
import { readSupportInfoPanelLibrarySource } from "./support-info-panel.test-source";

const supportPageStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));
const supportInfoPanelStylesPath = fileURLToPath(
  new URL("./support-info-panel.module.css", import.meta.url)
);
const supportQueuePaneStylesPath = fileURLToPath(
  new URL("./support-conversation-queue-pane.module.css", import.meta.url)
);
const supportChatContentStylesPath = fileURLToPath(
  new URL("./support-conversation-chat-content.module.css", import.meta.url)
);
const supportChatPaneStylesPath = fileURLToPath(
  new URL("./support-conversation-chat-pane.module.css", import.meta.url)
);
const supportChatPanePath = fileURLToPath(
  new URL("./support-conversation-chat-pane.tsx", import.meta.url)
);
const supportFullscreenViewerStylesPath = fileURLToPath(
  new URL("./support-conversation-fullscreen-viewer.module.css", import.meta.url)
);
const supportFullscreenViewerPath = fileURLToPath(
  new URL("./support-conversation-fullscreen-viewer.tsx", import.meta.url)
);

const adminIconsPath = fileURLToPath(new URL("../admin/admin-icons.tsx", import.meta.url));

function readSupportPageStyles(): string {
  return readFileSync(supportPageStylesPath, "utf8");
}

function readSupportInfoPanelStyles(): string {
  return readFileSync(supportInfoPanelStylesPath, "utf8");
}

function readSupportQueuePaneStyles(): string {
  return readFileSync(supportQueuePaneStylesPath, "utf8");
}

function readSupportChatContentStyles(): string {
  return readFileSync(supportChatContentStylesPath, "utf8");
}

function readSupportChatPaneStyles(): string {
  return readFileSync(supportChatPaneStylesPath, "utf8");
}

function readSupportChatPane(): string {
  return readFileSync(supportChatPanePath, "utf8");
}

function readSupportFullscreenViewerStyles(): string {
  return readFileSync(supportFullscreenViewerStylesPath, "utf8");
}

function readSupportFullscreenViewer(): string {
  return readFileSync(supportFullscreenViewerPath, "utf8");
}

function sliceBetween(source: string, startMarker: string, endMarker: string): string {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);

  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  return source.slice(start, end);
}

describe("support visual contract", () => {
  it("names each branded Select by its field instead of the selected option", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(pageSource).toContain("ariaLabel={queueLabels.status}");
    expect(pageSource).toContain("ariaLabel={queueLabels.priority}");
    expect(pageSource).toContain("ariaLabel={queueLabels.sort}");
    expect(infoPanelSource).toContain("ariaLabel={text.supportPriorityLabel}");
  });

  it("uses shared admin icons for support controls and attachment affordances", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const iconsSource = readFileSync(adminIconsPath, "utf8");
    const stylesSource = readSupportPageStyles();
    const chatContentStylesSource = readSupportChatContentStyles();
    const chatPaneStylesSource = readSupportChatPaneStyles();
    const queueStylesSource = readSupportQueuePaneStyles();

    expect(pageSource).toContain("SearchIcon");
    expect(pageSource).toContain("UploadIcon");
    expect(pageSource).toContain("PaperclipIcon");
    expect(pageSource).toContain("FileIcon");
    expect(pageSource).toContain("ReplyIcon");
    expect(pageSource).toContain("BellIcon");
    expect(pageSource).toContain("SupportIcon");
    expect(pageSource).toContain("PlayCircleIcon");
    expect(pageSource).toContain("ClockIcon");
    expect(pageSource).toContain("CancelCircleIcon");
    expect(pageSource).toContain("CaretDownIcon");
    expect(pageSource).not.toContain("<svg");
    expect(pageSource).not.toContain('width="40"');
    expect(pageSource).not.toContain("M12.5 12.5 17 17");
    expect(pageSource).not.toContain("📎");
    expect(pageSource).not.toContain("💬");
    expect(pageSource).not.toContain("🔔");
    expect(pageSource).not.toContain("↩");
    expect(pageSource).not.toContain(">FILE<");
    expect(pageSource).not.toContain(">▶");
    expect(pageSource).not.toContain(">✦<");
    expect(pageSource).not.toContain(">⏳<");

    expect(iconsSource).toContain("export function SearchIcon");
    expect(iconsSource).toContain("export function UploadIcon");
    expect(iconsSource).toContain("export function PaperclipIcon");
    expect(iconsSource).toContain("export function FileIcon");
    expect(iconsSource).toContain("export function ReplyIcon");
    expect(iconsSource).toContain("export function CaretDownIcon");
    expect(chatPaneStylesSource).toContain(".dropOverlayIcon {");
    expect(chatPaneStylesSource).toContain("width: 40px;");
    expect(chatPaneStylesSource).toContain("height: 40px;");
    expect(chatPaneStylesSource).toContain(".composerIconSvg {");
    expect(stylesSource).toContain(".supportFileIcon {");
    expect(chatContentStylesSource).toContain(".replyThumbSvg {");
    expect(chatContentStylesSource).toContain(".messageReplyActionIcon {");
    expect(queueStylesSource).toContain(".queueBadgeIcon {");
    expect(queueStylesSource).toContain(".queueStatusIcon {");
    expect(queueStylesSource).toContain(".queuePagerIcon {");
    expect(queueStylesSource).toContain(".queuePagerIconPrevious {");
    expect(queueStylesSource).toContain(".queuePagerIconNext {");
  });

  it("uses shared file icons for support info-panel attachment placeholders", () => {
    const infoPanelSource = readSupportInfoPanelLibrarySource();
    const stylesSource = readSupportInfoPanelStyles();

    expect(infoPanelSource).toContain("FileIcon");
    expect(infoPanelSource).toContain("className={styles.supportFileIcon}");
    expect(infoPanelSource).not.toContain(">FILE<");
    expect(stylesSource).toContain(".infoPanelAttachmentPreviewIcon {");
    expect(stylesSource).toContain(".supportFileIcon {");
  });

  it("keeps the primary workspace status layer on semantic theme tokens", () => {
    const source = readSupportQueuePaneStyles();
    const primaryWorkspaceStatusLayer = sliceBetween(source, ".slaPill_good", ".queueFooter");

    expect(primaryWorkspaceStatusLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(primaryWorkspaceStatusLayer).not.toContain("rgba(");
    expect(primaryWorkspaceStatusLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(primaryWorkspaceStatusLayer).toContain(
      "background: color-mix(in srgb, var(--success) 14%, var(--surface-2));"
    );
    expect(primaryWorkspaceStatusLayer).toContain("color: var(--danger-soft-fg);");
    expect(primaryWorkspaceStatusLayer).toContain(
      "border-color: color-mix(in srgb, var(--warning) 28%, var(--border-soft));"
    );
    expect(primaryWorkspaceStatusLayer).toContain(
      "background: color-mix(in srgb, var(--warning) 12%, var(--danger-soft-bg));"
    );
    expect(primaryWorkspaceStatusLayer).toContain(
      "animation: pulseSlaRing 2s ease-in-out infinite;"
    );
  });

  it("keeps message bubbles and attachment states on semantic theme tokens", () => {
    const source = readSupportChatContentStyles();
    const messageAndAttachmentLayer = source;

    expect(messageAndAttachmentLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(messageAndAttachmentLayer).not.toContain("rgba(");
    expect(messageAndAttachmentLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(messageAndAttachmentLayer).toContain(
      "background: color-mix(in srgb, var(--surface-0) 64%, transparent);"
    );
    expect(messageAndAttachmentLayer).toContain(
      "background: color-mix(in srgb, var(--success) 18%, var(--surface-1));"
    );
    expect(messageAndAttachmentLayer).toContain(
      "background: color-mix(in srgb, var(--info) 18%, var(--surface-1));"
    );
    expect(messageAndAttachmentLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--accent) 22%, var(--border-soft));"
    );
    expect(messageAndAttachmentLayer).toContain(
      "border-color: color-mix(in srgb, var(--warning) 42%, var(--border-soft));"
    );
    expect(messageAndAttachmentLayer).toContain(
      "border-color: color-mix(in srgb, var(--danger) 50%, var(--border-soft));"
    );
  });

  it("keeps reply previews and composer reply state theme-aware", () => {
    const pageSource = readSupportChatContentStyles();
    const paneSource = readSupportChatPaneStyles();
    const replyStateLayer = sliceBetween(
      pageSource,
      ".messageTick",
      "/* ── Telegram-like support chat media/composer refinements ── */"
    );
    const composerReplyLayer = sliceBetween(
      paneSource,
      ".composerReplyPreview",
      ".closedComposerNotice"
    );

    expect(replyStateLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(replyStateLayer).not.toContain("rgba(");
    expect(replyStateLayer).not.toMatch(/letter-spacing:\s*-/);
    expect(composerReplyLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(composerReplyLayer).not.toContain("rgba(");
    expect(composerReplyLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(replyStateLayer).toContain("letter-spacing: 0;");
    expect(replyStateLayer).toContain(
      "color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(replyStateLayer).toContain(
      "background: color-mix(in srgb, var(--success) 9%, var(--surface-2));"
    );
    expect(replyStateLayer).toContain(
      "border: 1px dashed color-mix(in srgb, var(--text-muted) 42%, var(--border-soft));"
    );
    expect(composerReplyLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 22%, var(--border-soft));"
    );
    expect(composerReplyLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 36%, var(--border-soft));"
    );
  });

  it("keeps support inbox rows on compact admin radii", () => {
    const source = readSupportQueuePaneStyles();
    const conversationRowLayer = sliceBetween(
      source,
      ".conversationRow {",
      ".conversationRowButton"
    );

    expect(conversationRowLayer).toContain("border-radius: 16px;");
    expect(conversationRowLayer).toContain("border: 1px solid");
    expect(conversationRowLayer).not.toContain("border-radius: 0.9rem;");
    expect(source).not.toContain(".conversationRowButton {\n  width: 100%;\n  border: 0;");
  });

  it("keeps compact queue rows within the pane without hiding their status metadata", () => {
    const source = readSupportQueuePaneStyles();
    const queueFooterLayer = sliceBetween(source, ".queueRowFooter {", ".queueStatusPill,");
    const queuePillLayer = sliceBetween(source, ".queueStatusPill,", ".queueStatusIcon");

    expect(queueFooterLayer).toContain("max-width: 100%;");
    expect(queuePillLayer).toContain("max-width: 100%;");
    expect(queuePillLayer).toContain("line-height: 1.2;");
    expect(source).toContain(".slaPill {\n  white-space: normal;");
  });

  it("keeps attachment previews and side panel actions theme-aware", () => {
    const source = readSupportChatPaneStyles();
    const attachmentAndSidePanelLayer = sliceBetween(
      source,
      ".attachmentPreviewImage",
      ".closedComposerNotice"
    );

    expect(attachmentAndSidePanelLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(attachmentAndSidePanelLayer).not.toContain("rgba(");
    expect(attachmentAndSidePanelLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(attachmentAndSidePanelLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-inverse) 8%, var(--border-soft));"
    );
    expect(attachmentAndSidePanelLayer).toContain("background: var(--surface-2);");
    expect(attachmentAndSidePanelLayer).toContain("color: var(--text-soft);");
    expect(attachmentAndSidePanelLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 36%, var(--border-soft));"
    );
    expect(attachmentAndSidePanelLayer).toContain(
      "background: color-mix(in srgb, var(--success) 9%, var(--surface-2));"
    );
  });

  it("keeps support attachment preview tiles theme-aware", () => {
    const source = readSupportInfoPanelStyles();
    const attachmentPreviewLayer = sliceBetween(
      source,
      ".infoPanelAttachmentPreviewStrip",
      ".infoPanelTagAddChip"
    );

    expect(attachmentPreviewLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(attachmentPreviewLayer).not.toContain("rgba(");
    expect(attachmentPreviewLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(attachmentPreviewLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 34%, var(--border-soft));"
    );
    expect(attachmentPreviewLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 86%, var(--text-muted) 14%);"
    );
    expect(attachmentPreviewLayer).toContain(
      "box-shadow: 0 3px 10px color-mix(in srgb, var(--surface-0) 14%, transparent);"
    );
    expect(attachmentPreviewLayer).toContain(
      "background: color-mix(in srgb, var(--surface-0) 84%, transparent);"
    );
  });

  it("keeps support info-panel stats and action stack theme-aware", () => {
    const source = readSupportInfoPanelStyles();
    const infoPanelStatsLayer = sliceBetween(
      source,
      ".infoPanelStatsGrid",
      ':global(:root[data-theme="light"]) .timelineCardHeader span'
    );

    expect(infoPanelStatsLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(infoPanelStatsLayer).not.toContain("rgba(");
    expect(infoPanelStatsLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(infoPanelStatsLayer).toContain(
      "background: linear-gradient(180deg, var(--surface-1), var(--surface-2));"
    );
    expect(infoPanelStatsLayer).toContain(
      "box-shadow: inset 0 1px 0 color-mix(in srgb, var(--text-inverse) 7%, transparent);"
    );
    expect(infoPanelStatsLayer).toContain("color: var(--text-strong);");
    expect(infoPanelStatsLayer).toContain("width: 100%;");
    expect(infoPanelStatsLayer).toContain("grid-template-columns: repeat(2, minmax(0, 1fr));");
    expect(infoPanelStatsLayer).toContain("display: grid;");
    expect(infoPanelStatsLayer).toContain("overflow-wrap: anywhere;");
    expect(source).toContain("@container (max-width: 23rem)");
  });

  it("keeps side-panel tabs theme-aware across hover and active states", () => {
    const source = readSupportInfoPanelStyles();
    const sidePanelTabLayer = sliceBetween(source, ".sidePanelTabs", ".infoPanelFlat");

    expect(sidePanelTabLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(sidePanelTabLayer).not.toContain("rgba(");
    expect(sidePanelTabLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(sidePanelTabLayer).toContain(
      "background: color-mix(in srgb, var(--surface-1) 72%, var(--surface-2));"
    );
    expect(sidePanelTabLayer).toContain(
      "box-shadow: 0 1px 3px color-mix(in srgb, var(--surface-0) 18%, transparent);"
    );
    expect(sidePanelTabLayer).toContain(
      "0 0 0 1px color-mix(in srgb, var(--accent) 10%, transparent);"
    );
  });

  it("keeps info-panel content rows and tags tokenized", () => {
    const source = readSupportInfoPanelStyles();
    const infoPanelContentLayer = sliceBetween(
      source,
      ".infoPanelSectionTitle",
      ".infoPanelStatsGrid"
    );

    expect(infoPanelContentLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(infoPanelContentLayer).not.toContain("rgba(");
    expect(infoPanelContentLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(infoPanelContentLayer).toContain("color: var(--accent);");
    expect(infoPanelContentLayer).toContain("background: var(--surface-1);");
    expect(infoPanelContentLayer).toContain(
      "color: color-mix(in srgb, var(--accent) 66%, var(--text-strong) 34%);"
    );
    expect(infoPanelContentLayer).toContain(
      "border-color: color-mix(in srgb, var(--accent) 30%, var(--border-soft));"
    );
  });

  it("keeps support form fields accessible in keyboard and disabled states", () => {
    const source = readSupportPageStyles();
    const queueSource = readSupportQueuePaneStyles();
    const inboxFieldLayer = sliceBetween(source, ".searchInput,", ".supportFileIcon {");
    const queueToolLayer = sliceBetween(queueSource, ".queueToolField select", ".list");
    const infoPanelFieldLayer = sliceBetween(
      readSupportInfoPanelStyles(),
      ".infoPanelSelect",
      ".infoPanelStatsGrid"
    );

    expect(inboxFieldLayer).toContain(
      ".searchInput:focus-visible,\n.input:focus-visible,\n.textarea:focus-visible"
    );
    expect(inboxFieldLayer).toContain("box-shadow: var(--focus-ring);");
    expect(inboxFieldLayer).toContain(
      ".searchInput:disabled,\n.input:disabled,\n.textarea:disabled"
    );
    expect(inboxFieldLayer).toContain("cursor: not-allowed;");
    expect(inboxFieldLayer).not.toMatch(/\.(?:searchInput|input|textarea):focus(?!-visible)/);

    expect(queueToolLayer).toContain(".queueToolField select:focus-visible");
    expect(queueToolLayer).toContain("box-shadow: var(--focus-ring);");
    expect(queueToolLayer).not.toMatch(/\.queueToolField select:focus(?!-visible)/);

    expect(infoPanelFieldLayer).toContain(".infoPanelSelect:focus-visible");
    expect(infoPanelFieldLayer).toContain(".infoPanelTagInput:focus-visible");
    expect(infoPanelFieldLayer).toContain(".infoPanelSelect:disabled");
    expect(infoPanelFieldLayer).toContain(".infoPanelTagInput:disabled");
    expect(infoPanelFieldLayer).toContain("box-shadow: var(--focus-ring);");
    expect(infoPanelFieldLayer).toContain("opacity: 0.62;");
    expect(infoPanelFieldLayer).not.toMatch(
      /\.(?:infoPanelSelect|infoPanelTagInput):focus(?!-visible)/
    );
  });

  it("keeps support media viewer, keyboard focus, and local scrollbars theme-aware", () => {
    const viewerSource = readSupportFullscreenViewerStyles();
    const source = readSupportChatContentStyles();
    const mediaViewerLayer = viewerSource;
    const listScrollbarLayer = sliceBetween(
      readSupportInfoPanelStyles(),
      ".attachmentList",
      ".spConfirmBox"
    );

    expect(mediaViewerLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(mediaViewerLayer).not.toContain("rgba(");
    expect(mediaViewerLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(listScrollbarLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(listScrollbarLayer).not.toContain("rgba(");

    expect(mediaViewerLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 26%, var(--border-soft));"
    );
    expect(mediaViewerLayer).toContain(
      "box-shadow: 0 24px 60px color-mix(in srgb, var(--surface-0) 46%, transparent);"
    );
    expect(source).toContain(
      "outline: 2px solid color-mix(in srgb, var(--success) 72%, transparent);"
    );
    expect(source).toContain(
      "scrollbar-color: color-mix(in srgb, var(--success) 22%, transparent) transparent;"
    );
    expect(listScrollbarLayer).toContain(
      "scrollbar-color: color-mix(in srgb, var(--text-muted) 30%, transparent) transparent;"
    );
  });

  it("keeps the fullscreen viewer keyboard-contained and long filenames mobile-safe", () => {
    const viewerSource = readSupportFullscreenViewer();
    const viewerStyles = readSupportFullscreenViewerStyles();
    const pageSource = readSupportConversationPageLibrarySource();

    expect(viewerSource).toContain("const viewerRef = useRef<HTMLDivElement>(null);");
    expect(viewerSource).toContain("const closeButtonRef = useRef<HTMLButtonElement>(null);");
    expect(viewerSource).toContain("previouslyFocusedElementRef.current?.focus();");
    expect(viewerSource).toContain('if (event.key !== "Tab") {');
    expect(viewerSource).toContain(
      "const focusableElements = viewerRef.current?.querySelectorAll<HTMLElement>("
    );
    expect(viewerSource).toContain("ref={viewerRef}");
    expect(viewerSource).toContain("ref={closeButtonRef}");
    expect(viewerSource).toContain("className={styles.imageViewerTitle}");
    expect(pageSource).toContain("!fullscreenImage");
    expect(viewerStyles).toContain(".imageViewerTitle {");
    expect(viewerStyles).toContain("overflow-wrap: anywhere;");
    expect(viewerStyles).toContain(".imageViewerHeader :global(.ui-button)");
  });

  it("keeps redesigned support queue identity and danger actions theme-aware", () => {
    const queueIdentityActionLayer = readSupportQueuePaneStyles();

    expect(queueIdentityActionLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueIdentityActionLayer).not.toContain("rgba(");
    expect(queueIdentityActionLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueIdentityActionLayer).toContain(
      "box-shadow: 0 4px 10px color-mix(in srgb, var(--surface-0) 7%, transparent);"
    );
    expect(queueIdentityActionLayer).toContain("background: linear-gradient(");
    expect(queueIdentityActionLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 14%, var(--surface-2));"
    );
    expect(queueIdentityActionLayer).toContain(
      "background: color-mix(in srgb, var(--success) 15%, var(--surface-2));"
    );
    expect(queueIdentityActionLayer).toContain(
      "background: color-mix(in srgb, var(--warning) 17%, var(--surface-2));"
    );
    expect(queueIdentityActionLayer).toContain("color: var(--accent);");
    expect(queueIdentityActionLayer).toContain("color: var(--text-strong);");
    expect(queueIdentityActionLayer).toContain("color: var(--text-muted);");
    expect(queueIdentityActionLayer).toContain(
      "color-mix(in srgb, var(--accent) 78%, var(--text-strong))"
    );
    expect(queueIdentityActionLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--border-soft) 74%, transparent);"
    );
  });

  it("keeps final support workspace polish theme-token based", () => {
    const finalWorkspacePolishLayer = readSupportChatPaneStyles();

    expect(finalWorkspacePolishLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(finalWorkspacePolishLayer).not.toContain("rgba(");
    expect(finalWorkspacePolishLayer).not.toContain("radial-gradient");
    expect(finalWorkspacePolishLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(finalWorkspacePolishLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 34%, var(--border-soft)) !important;"
    );
    expect(finalWorkspacePolishLayer).toContain(
      "0 14px 30px color-mix(in srgb, var(--surface-0) 14%, transparent) !important;"
    );
  });

  it("keeps support workspace typography readable without decorative tracking", () => {
    const source = `${readSupportPageStyles()}\n${readSupportChatContentStyles()}`;
    const queueSource = readSupportQueuePaneStyles();
    const chatPaneSource = readSupportChatPane();
    const nonZeroLetterSpacingRules = [...source.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => value !== "0");

    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(source).not.toMatch(/letter-spacing:\s*-/);
    expect(source).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(source).toContain("letter-spacing: 0;");
    expect(source).toContain(".chatHeaderNameRow strong {");
    expect(source).toContain(".chatMetaChip {");
    expect(source).toContain(".chatMetaTimestamp {");
    expect(queueSource).toContain(".queuePaneTitle {");
    expect(chatPaneSource).toContain("className={styles.chatWorkspacePane}");
    expect(chatPaneSource).toContain('data-testid="support-chat-pane"');
  });

  it("keeps final support chat readability styles on semantic tokens", () => {
    const source = readSupportChatContentStyles();
    const finalChatReadabilityLayer = sliceBetween(
      source,
      "/* Final chat readability and alignment fixes */",
      "/* Late dark-theme support workspace overrides must stay below final polish rules. */"
    );

    expect(finalChatReadabilityLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(finalChatReadabilityLayer).not.toContain("rgba(");
    expect(finalChatReadabilityLayer).not.toContain("radial-gradient");
    expect(finalChatReadabilityLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(finalChatReadabilityLayer).toContain(
      "color-mix(in srgb, var(--surface-2) 82%, var(--surface-1))"
    );
    expect(finalChatReadabilityLayer).toContain("color: var(--text-muted);");
    expect(finalChatReadabilityLayer).toContain("color: var(--text-strong);");
    expect(finalChatReadabilityLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 38%, var(--border-soft));"
    );
    expect(finalChatReadabilityLayer).toContain(
      "background: color-mix(in srgb, var(--success) 9%, var(--surface-2));"
    );
  });

  it("keeps late support workspace height rules viewport-safe on tablet and mobile", () => {
    const source = readSupportChatPaneStyles();
    const queueSource = readSupportQueuePaneStyles();
    const workspaceSource = readSupportPageStyles();

    expect(workspaceSource).toContain(
      "--support-workspace-height: clamp(38rem, calc(100dvh - 10rem), 66rem);"
    );
    expect(source).toContain(".chatWorkspacePane {");
    expect(source).toContain("height: var(--support-workspace-height);");
    expect(queueSource).toContain("min-height: var(--support-workspace-height);");
    expect(queueSource).toContain("height: var(--support-workspace-height);");
    expect(source).toContain("@media (max-width: 1180px) {");
    expect(source).toContain(
      ".chatShell {\n    min-height: auto;\n    height: auto;\n    max-height: none;\n  }"
    );
    expect(source).toContain("@media (max-width: 780px) {");
    expect(source).toContain("border-radius: 1rem;");
    expect(source).not.toContain("height: clamp(42rem, calc(100dvh - 9rem), 52rem);");
    expect(source).not.toContain("min-height: clamp(42rem, calc(100dvh - 9rem), 52rem);");
  });

  it("keeps late light-theme support status overrides tokenized", () => {
    const source = readSupportQueuePaneStyles();
    const lateLightStatusLayer = sliceBetween(
      source,
      ':global(:root[data-theme="light"]) .paneCountBadge',
      ':global(:root:not([data-theme="light"])) .inboxPaneFlat'
    );

    expect(lateLightStatusLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(lateLightStatusLayer).not.toContain("rgba(");
    expect(lateLightStatusLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(lateLightStatusLayer).toContain("color: var(--success);");
    expect(lateLightStatusLayer).toContain("color: var(--danger-soft-fg);");
    expect(lateLightStatusLayer).toContain(
      "background: color-mix(in srgb, var(--success) 12%, var(--surface-1));"
    );
    expect(lateLightStatusLayer).toContain(
      "border-color: color-mix(in srgb, var(--danger) 22%, var(--border-soft));"
    );
    expect(lateLightStatusLayer).toContain(
      "background: color-mix(in srgb, var(--surface-1) 88%, var(--success) 12%);"
    );
  });

  it("keeps hash-based support avatar variants on semantic theme tokens", () => {
    const source = readSupportChatContentStyles();
    const avatarVariantLayer = sliceBetween(
      source,
      "/* ── Avatar Color Variants (hash-based per user) ── */",
      ".messagesWrap {"
    );

    expect(avatarVariantLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(avatarVariantLayer).not.toContain("rgba(");
    expect(avatarVariantLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(avatarVariantLayer).toContain("color: var(--accent-contrast);");
    expect(avatarVariantLayer).toContain(
      "color-mix(in srgb, var(--success) 82%, var(--surface-2))"
    );
    expect(avatarVariantLayer).toContain(
      "color-mix(in srgb, var(--magenta) 82%, var(--surface-2))"
    );
    expect(avatarVariantLayer).toContain(
      "color-mix(in srgb, var(--warning) 82%, var(--surface-2))"
    );
    expect(avatarVariantLayer).toContain("color-mix(in srgb, var(--info) 82%, var(--surface-2))");
    expect(avatarVariantLayer).toContain(
      "border-color: color-mix(in srgb, var(--neutral) 30%, var(--border-soft));"
    );
  });

  it("keeps support composer and media reply refinements theme-aware", () => {
    const pageSource = readSupportChatContentStyles();
    const paneSource = readSupportChatPaneStyles();
    const mediaReplyLayer = sliceBetween(
      pageSource,
      "/* ── Telegram-like support chat media/composer refinements ── */",
      "/* Final chat readability and alignment fixes */"
    );
    const composerPaneLayer = sliceBetween(
      paneSource,
      ".composerIconBtn {",
      "@media (min-width: 1600px) {"
    );

    expect(mediaReplyLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(mediaReplyLayer).not.toContain("rgba(");
    expect(mediaReplyLayer).not.toMatch(/letter-spacing:\s*-/);
    expect(composerPaneLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(composerPaneLayer).not.toContain("rgba(");
    expect(composerPaneLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(composerPaneLayer).toContain("color: var(--text-muted);");
    expect(composerPaneLayer).toContain("background: transparent;");
    expect(paneSource).toContain(".composerInputBar .composerIconBtn {");
    expect(paneSource).not.toMatch(/\.composerInputBar \.composerIconBtn\s*\{\s*width:\s*34px;/);
    expect(mediaReplyLayer).toContain(
      "background: color-mix(in srgb, var(--surface-0) 76%, transparent);"
    );
    expect(mediaReplyLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 78%, var(--success) 22%);"
    );
    expect(mediaReplyLayer).toContain(
      "background: color-mix(in srgb, var(--success) 10%, var(--surface-2));"
    );
  });

  it("keeps refreshed support queue panel chrome on semantic theme tokens", () => {
    const source = readSupportQueuePaneStyles();
    const queueRefreshLayer = sliceBetween(source, ".inboxPaneFlat {", ".conversationRow {");

    expect(queueRefreshLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueRefreshLayer).not.toContain("rgba(");
    expect(queueRefreshLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueRefreshLayer).toContain("color-mix(in srgb, var(--accent) 14%, var(--surface-2))");
    expect(queueRefreshLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--border-soft) 74%, transparent);"
    );
    expect(queueRefreshLayer).toContain(".queueToolField select:focus-visible");
    expect(queueRefreshLayer).toContain("box-shadow: var(--focus-ring);");
    expect(queueRefreshLayer).toContain(
      "color-mix(in srgb, var(--surface-2) 72%, var(--surface-0))"
    );
    expect(queueRefreshLayer).toContain(
      "0 16px 32px color-mix(in srgb, var(--surface-0) 20%, transparent)"
    );
    expect(queueRefreshLayer).toContain(
      "border-color: color-mix(in srgb, var(--text-muted) 72%, var(--border-soft));"
    );
  });

  it("keeps redesigned support ticket info panel on semantic theme tokens", () => {
    const source = readSupportInfoPanelStyles();
    const ticketPanelLayer = sliceBetween(source, ".infoPanelFlat", "@media (max-width: 1180px)");

    expect(ticketPanelLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(ticketPanelLayer).not.toContain("rgba(");
    expect(ticketPanelLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(ticketPanelLayer).toContain(
      "color-mix(in srgb, var(--surface-2) 95%, var(--surface-1))"
    );
    expect(ticketPanelLayer).toContain(".infoPanelSelect:focus-visible");
    expect(ticketPanelLayer).toContain(".infoPanelTagInput:focus-visible");
    expect(ticketPanelLayer).toContain("box-shadow: var(--focus-ring);");
    expect(ticketPanelLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 34%, var(--border-soft)) !important;"
    );
    expect(ticketPanelLayer).toContain(
      "color: color-mix(in srgb, var(--accent) 66%, var(--text-strong) 34%);"
    );
    expect(ticketPanelLayer).toContain(
      "border-color: color-mix(in srgb, var(--border-soft) 82%, var(--surface-0));"
    );
    expect(ticketPanelLayer).toContain(
      "box-shadow: 0 6px 16px color-mix(in srgb, var(--surface-0) 44%, transparent);"
    );
  });

  it("keeps queue search chrome on semantic theme tokens", () => {
    const source = readSupportQueuePaneStyles();
    const queueSearchLayer = sliceBetween(source, ".queueSearchField {", ".queuePaneTitleRow {");

    expect(queueSearchLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueSearchLayer).not.toContain("rgba(");
    expect(queueSearchLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueSearchLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 30%, var(--border-soft));"
    );
    expect(queueSearchLayer).toContain(
      "background: color-mix(in srgb, var(--surface-1) 96%, var(--surface-2));"
    );
    expect(queueSearchLayer).toContain("box-shadow: var(--focus-ring);");
    expect(queueSearchLayer).toContain("color: var(--text-muted);");
  });

  it("keeps support workspace queue shell chrome on semantic theme tokens", () => {
    const source = readSupportQueuePaneStyles();
    const queueShellLayer = sliceBetween(source, ".inboxPaneFlat {", ".queuePaneHeader {");

    expect(queueShellLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueShellLayer).not.toContain("rgba(");
    expect(queueShellLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueShellLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 34%, var(--border-soft));"
    );
    expect(queueShellLayer).toContain(
      "0 14px 30px color-mix(in srgb, var(--surface-0) 14%, transparent)"
    );
    expect(queueShellLayer).toContain("background: linear-gradient(");
    expect(queueShellLayer).toContain("min-height: var(--support-workspace-height);");
    expect(queueShellLayer).toContain("border-radius: 24px;");
  });

  it("keeps support queue counters and status pills on semantic theme tokens", () => {
    const source = readSupportQueuePaneStyles();
    const queueStatusLayer = sliceBetween(source, ".queueCountBadge", ".queueFooter");

    expect(queueStatusLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueStatusLayer).not.toContain("rgba(");
    expect(queueStatusLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueStatusLayer).toContain(
      "background: color-mix(in srgb, var(--success) 15%, var(--surface-2));"
    );
    expect(queueStatusLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 14%, var(--surface-2));"
    );
    expect(queueStatusLayer).toContain("color: var(--success);");
    expect(queueStatusLayer).toContain("color: var(--warning);");
    expect(queueStatusLayer).toContain(
      "border-color: color-mix(in srgb, var(--text-muted) 32%, var(--border-soft));"
    );
  });

  it("uses dynamic viewport heights for support workspace and media viewer panels", () => {
    const source = readSupportChatPaneStyles();
    const viewerSource = readSupportFullscreenViewerStyles();

    expect(source).toContain("height: clamp(38rem, calc(100dvh - 10rem), 66rem);");
    expect(source).toContain("min-height: clamp(34rem, calc(100dvh - 9rem), 52rem);");
    expect(source).not.toContain("min-height: clamp(42rem, calc(100dvh - 9rem), 52rem);");
    expect(source).not.toContain("100vh");
    expect(viewerSource).toContain("max-height: calc(100dvh - 2.4rem);");
    expect(viewerSource).toContain("max-height: calc(100dvh - 14rem);");
  });

  it("keeps late support workspace dark overrides below final polish styles", () => {
    const source = readSupportChatContentStyles();
    const queueSource = readSupportQueuePaneStyles();
    const finalChatPolishIndex = source.indexOf("/* Final chat readability and alignment fixes */");
    const lateDarkOverrideIndex = source.indexOf(
      "/* Late dark-theme support workspace overrides must stay below final polish rules. */"
    );
    const lateDarkOverrideLayer = source.slice(lateDarkOverrideIndex);
    const queueDarkOverrideStart = queueSource.indexOf(
      ':global(:root:not([data-theme="light"])) .inboxPaneFlat'
    );
    expect(queueDarkOverrideStart).toBeGreaterThanOrEqual(0);
    const queueDarkOverrideLayer = queueSource.slice(queueDarkOverrideStart);

    expect(finalChatPolishIndex).toBeGreaterThanOrEqual(0);
    expect(lateDarkOverrideIndex).toBeGreaterThan(finalChatPolishIndex);
    expect(lateDarkOverrideLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(lateDarkOverrideLayer).not.toContain("rgba(");
    expect(lateDarkOverrideLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueDarkOverrideLayer).toContain(
      ':global(:root:not([data-theme="light"])) .queueFiltersDisclosure'
    );
    expect(queueDarkOverrideLayer).toContain(
      ':global(:root:not([data-theme="light"])) .conversationRow'
    );
    expect(lateDarkOverrideLayer).toContain(
      ':global(:root:not([data-theme="light"])) .messagesWrap'
    );
    expect(lateDarkOverrideLayer).toContain(
      ':global(:root:not([data-theme="light"])) .messageAdmin'
    );
    expect(lateDarkOverrideLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 88%, var(--surface-0));"
    );
    expect(lateDarkOverrideLayer).toContain(
      "0 1px 4px color-mix(in srgb, var(--surface-0) 40%, transparent);"
    );
  });
});
