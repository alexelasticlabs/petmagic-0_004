import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readSupportConversationPageLibrarySource } from "./support-conversation-page.test-source";
import { readSupportInfoPanelLibrarySource } from "./support-info-panel.test-source";

const supportStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));

const adminIconsPath = fileURLToPath(new URL("../admin/admin-icons.tsx", import.meta.url));

function readSupportStyles(): string {
  return readFileSync(supportStylesPath, "utf8");
}

function sliceBetween(source: string, startMarker: string, endMarker: string): string {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);

  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  return source.slice(start, end);
}

describe("support visual contract", () => {
  it("uses shared admin icons for support controls and attachment affordances", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const iconsSource = readFileSync(adminIconsPath, "utf8");
    const stylesSource = readSupportStyles();

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
    expect(stylesSource).toContain(".dropOverlayIcon {");
    expect(stylesSource).toContain("width: 40px;");
    expect(stylesSource).toContain("height: 40px;");
    expect(stylesSource).toContain(".composerIconSvg {");
    expect(stylesSource).toContain(".supportFileIcon {");
    expect(stylesSource).toContain(".replyThumbSvg {");
    expect(stylesSource).toContain(".messageReplyActionIcon {");
    expect(stylesSource).toContain(".queueBadgeIcon {");
    expect(stylesSource).toContain(".queueStatusIcon {");
    expect(stylesSource).toContain(".queuePagerIcon {");
    expect(stylesSource).toContain(".queuePagerIconPrevious {");
    expect(stylesSource).toContain(".queuePagerIconNext {");
  });

  it("uses shared file icons for support info-panel attachment placeholders", () => {
    const infoPanelSource = readSupportInfoPanelLibrarySource();
    const stylesSource = readSupportStyles();

    expect(infoPanelSource).toContain("FileIcon");
    expect(infoPanelSource).toContain("className={styles.supportFileIcon}");
    expect(infoPanelSource).not.toContain(">FILE<");
    expect(stylesSource).toContain(".infoPanelAttachmentPreviewIcon {");
    expect(stylesSource).toContain(".supportFileIcon {");
  });

  it("keeps the primary workspace status layer on semantic theme tokens", () => {
    const source = readSupportStyles();
    const primaryWorkspaceStatusLayer = sliceBetween(
      source,
      ".slaPill_good",
      ".messageVideoButton"
    );

    expect(primaryWorkspaceStatusLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(primaryWorkspaceStatusLayer).not.toContain("rgba(");
    expect(primaryWorkspaceStatusLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(primaryWorkspaceStatusLayer).toContain(
      "background: color-mix(in srgb, var(--success) 14%, var(--surface-2));"
    );
    expect(primaryWorkspaceStatusLayer).toContain("color: var(--danger-soft-fg);");
    expect(primaryWorkspaceStatusLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 65%, var(--border-soft)) !important;"
    );
    expect(primaryWorkspaceStatusLayer).toContain(
      "background: color-mix(in srgb, var(--info) 14%, var(--surface-2));"
    );
    expect(primaryWorkspaceStatusLayer).toContain(
      "background: color-mix(in srgb, var(--warning) 85%, transparent);"
    );
  });

  it("keeps message bubbles and attachment states on semantic theme tokens", () => {
    const source = readSupportStyles();
    const messageAndAttachmentLayer = sliceBetween(
      source,
      ".messageVideoButton",
      ".messageSenderWrap"
    );

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
    const source = readSupportStyles();
    const replyComposerLayer = sliceBetween(source, ".messageTick", ".attachmentPreviewCard");

    expect(replyComposerLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(replyComposerLayer).not.toContain("rgba(");
    expect(replyComposerLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(replyComposerLayer).toContain("letter-spacing: 0;");
    expect(replyComposerLayer).toContain(
      "color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(replyComposerLayer).toContain(
      "background: color-mix(in srgb, var(--success) 9%, var(--surface-2));"
    );
    expect(replyComposerLayer).toContain(
      "border: 1px dashed color-mix(in srgb, var(--text-muted) 42%, var(--border-soft));"
    );
    expect(replyComposerLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 22%, var(--border-soft));"
    );
    expect(replyComposerLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 36%, var(--border-soft));"
    );
  });

  it("keeps support inbox rows on compact admin radii", () => {
    const source = readSupportStyles();
    const conversationRowLayer = sliceBetween(
      source,
      ".conversationRow {",
      ".conversationRowButton"
    );

    expect(conversationRowLayer).toContain("border-radius: var(--radius-sm);");
    expect(conversationRowLayer).not.toContain("border-radius: 0.9rem;");
  });

  it("keeps attachment previews and side panel actions theme-aware", () => {
    const source = readSupportStyles();
    const attachmentAndSidePanelLayer = sliceBetween(
      source,
      ".attachmentPreviewImage",
      ".userSummaryHeader"
    );

    expect(attachmentAndSidePanelLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(attachmentAndSidePanelLayer).not.toContain("rgba(");
    expect(attachmentAndSidePanelLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(attachmentAndSidePanelLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-inverse) 8%, var(--border-soft));"
    );
    expect(attachmentAndSidePanelLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 86%, var(--text-muted) 14%);"
    );
    expect(attachmentAndSidePanelLayer).toContain("color: var(--danger-soft-fg);");
    expect(attachmentAndSidePanelLayer).toContain(
      "border-color: color-mix(in srgb, var(--danger) 58%, var(--border-soft)) !important;"
    );
    expect(attachmentAndSidePanelLayer).toContain(
      "background: color-mix(in srgb, var(--success) 12%, var(--surface-2));"
    );
  });

  it("keeps support template and attachment side-panel lists theme-aware", () => {
    const source = readSupportStyles();
    const sidePanelListsLayer = sliceBetween(
      source,
      ".templateListItem",
      "@media (max-width: 1320px)"
    );

    expect(sidePanelListsLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(sidePanelListsLayer).not.toContain("rgba(");
    expect(sidePanelListsLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(sidePanelListsLayer).toContain(
      "background: color-mix(in srgb, var(--surface-1) 94%, var(--surface-2));"
    );
    expect(sidePanelListsLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 72%, var(--border-soft));"
    );
    expect(sidePanelListsLayer).toContain(
      "box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--success) 24%, transparent);"
    );
    expect(sidePanelListsLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-inverse) 8%, var(--border-soft));"
    );
  });

  it("keeps side-panel identity and status controls theme-aware", () => {
    const source = readSupportStyles();
    const sidePanelIdentityLayer = sliceBetween(source, ".spAvatarMd", ".spTabNav");

    expect(sidePanelIdentityLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(sidePanelIdentityLayer).not.toContain("rgba(");
    expect(sidePanelIdentityLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(sidePanelIdentityLayer).toContain("color: var(--accent);");
    expect(sidePanelIdentityLayer).toContain(
      "color-mix(in srgb, var(--accent) 18%, var(--surface-2)) 0%,"
    );
    expect(sidePanelIdentityLayer).toContain(
      "border-color: color-mix(in srgb, var(--warning) 32%, var(--border-soft));"
    );
    expect(sidePanelIdentityLayer).toContain("color: var(--danger);");
    expect(sidePanelIdentityLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 28%, var(--border-soft));"
    );
  });

  it("keeps side-panel tabs theme-aware across hover, active, and dark overrides", () => {
    const source = readSupportStyles();
    const sidePanelTabLayer = sliceBetween(source, ".spTabNav", ".spContent");
    const darkTabOverrideLayer = sliceBetween(
      source,
      ':global(:root:not([data-theme="light"])) .queueSubFilters',
      ':global(:root:not([data-theme="light"])) .conversationRow'
    );

    expect(sidePanelTabLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(sidePanelTabLayer).not.toContain("rgba(");
    expect(sidePanelTabLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(darkTabOverrideLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(darkTabOverrideLayer).not.toContain("rgba(");
    expect(darkTabOverrideLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(sidePanelTabLayer).toContain(
      "background: color-mix(in srgb, var(--surface-1) 72%, var(--surface-2));"
    );
    expect(sidePanelTabLayer).toContain(
      "box-shadow: 0 1px 3px color-mix(in srgb, var(--surface-0) 18%, transparent);"
    );
    expect(sidePanelTabLayer).toContain(
      "0 0 0 1px color-mix(in srgb, var(--accent) 10%, transparent);"
    );
    expect(darkTabOverrideLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 88%, var(--surface-0) 12%);"
    );
    expect(darkTabOverrideLayer).toContain(
      "0 1px 2px color-mix(in srgb, var(--surface-0) 44%, transparent),"
    );
  });

  it("keeps side-panel content rows, links, and danger disclosure tokenized", () => {
    const source = readSupportStyles();
    const sidePanelContentLayer = sliceBetween(source, ".spContent", "@media (max-width: 640px)");

    expect(sidePanelContentLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(sidePanelContentLayer).not.toContain("rgba(");
    expect(sidePanelContentLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(sidePanelContentLayer).toContain("border-bottom: 1px solid var(--border-soft);");
    expect(sidePanelContentLayer).toContain("background: var(--surface-2);");
    expect(sidePanelContentLayer).toContain("color: var(--danger-soft-fg);");
    expect(sidePanelContentLayer).toContain("color: var(--danger);");
  });

  it("keeps support form fields accessible in keyboard and disabled states", () => {
    const source = readSupportStyles();
    const inboxFieldLayer = sliceBetween(source, ".searchInput,", ".inboxQueueGrid");
    const queueToolLayer = sliceBetween(source, ".queueToolField select", ".list");
    const infoPanelFieldLayer = sliceBetween(source, ".infoPanelSelect", ".infoPanelTagsWrap");

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
    const source = readSupportStyles();
    const mediaFocusScrollLayer = sliceBetween(
      source,
      ".imageViewerOverlay",
      "/* Keep support workspace fully dark when theme is dark/default-dark. */"
    );
    const lightShellLayer = sliceBetween(
      source,
      ':global(:root[data-theme="light"]) .inboxPane',
      "/* ── 4-column Full View Layout ── */"
    );
    const listScrollbarLayer = sliceBetween(
      source,
      ".templateCatalogList,\n.attachmentList",
      "/* ── prefers-reduced-motion ── */"
    );

    expect(mediaFocusScrollLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(mediaFocusScrollLayer).not.toContain("rgba(");
    expect(mediaFocusScrollLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(listScrollbarLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(listScrollbarLayer).not.toContain("rgba(");

    expect(lightShellLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(lightShellLayer).not.toContain("rgba(");

    expect(mediaFocusScrollLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 26%, var(--border-soft));"
    );
    expect(mediaFocusScrollLayer).toContain(
      "box-shadow: 0 24px 60px color-mix(in srgb, var(--surface-0) 46%, transparent);"
    );
    expect(mediaFocusScrollLayer).toContain(
      "outline: 2px solid color-mix(in srgb, var(--success) 72%, transparent);"
    );
    expect(mediaFocusScrollLayer).toContain(
      "scrollbar-color: color-mix(in srgb, var(--success) 22%, transparent) transparent;"
    );
    expect(listScrollbarLayer).toContain(
      "scrollbar-color: color-mix(in srgb, var(--text-muted) 30%, transparent) transparent;"
    );
    expect(lightShellLayer).toContain("color-mix(in srgb, var(--surface-1) 98%, transparent)");
  });

  it("keeps redesigned support queue identity and danger actions theme-aware", () => {
    const source = readSupportStyles();
    const queueIdentityActionLayer = sliceBetween(
      source,
      "/* ── Queue Sub-filter tabs ── */",
      "/* ── Responsive: Full View ── */"
    );

    expect(queueIdentityActionLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueIdentityActionLayer).not.toContain("rgba(");
    expect(queueIdentityActionLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueIdentityActionLayer).toContain(
      "box-shadow: 0 1px 3px color-mix(in srgb, var(--surface-0) 18%, transparent);"
    );
    expect(queueIdentityActionLayer).toContain("background: var(--accent);");
    expect(queueIdentityActionLayer).toContain("background: var(--info);");
    expect(queueIdentityActionLayer).toContain("background: var(--success);");
    expect(queueIdentityActionLayer).toContain("background: var(--warning);");
    expect(queueIdentityActionLayer).toContain("color: var(--danger);");
    expect(queueIdentityActionLayer).toContain(
      "scrollbar-color: color-mix(in srgb, var(--text-muted) 30%, transparent) transparent;"
    );
    expect(queueIdentityActionLayer).toContain("color: var(--accent);");
    expect(queueIdentityActionLayer).toContain("color: var(--danger-soft-fg);");
    expect(queueIdentityActionLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--danger) 30%, var(--border-soft));"
    );
  });

  it("keeps final support workspace polish theme-token based", () => {
    const source = readSupportStyles();
    const finalWorkspacePolishLayer = sliceBetween(
      source,
      "/* Final support workspace polish */",
      "/* Final chat readability and alignment fixes */"
    );

    expect(finalWorkspacePolishLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(finalWorkspacePolishLayer).not.toContain("rgba(");
    expect(finalWorkspacePolishLayer).not.toContain("radial-gradient");
    expect(finalWorkspacePolishLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(finalWorkspacePolishLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 34%, var(--border-soft)) !important;"
    );
    expect(finalWorkspacePolishLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 10%, var(--surface-2));"
    );
    expect(finalWorkspacePolishLayer).toContain("color: var(--text-muted);");
    expect(finalWorkspacePolishLayer).toContain("color: var(--text-soft);");
    expect(finalWorkspacePolishLayer).toContain("letter-spacing: 0;");
    expect(finalWorkspacePolishLayer).toContain(
      "border-color: color-mix(in srgb, var(--accent) 34%, var(--border-soft));"
    );
  });

  it("keeps support workspace typography readable without decorative tracking", () => {
    const source = readSupportStyles();
    const nonZeroLetterSpacingRules = [...source.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => value !== "0");

    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(source).not.toMatch(/letter-spacing:\s*-/);
    expect(source).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(source).toContain("letter-spacing: 0;");
    expect(source).toContain(".supportPageTitle {");
    expect(source).toContain("font-size: 1.9rem;");
    expect(source).toContain("font-size: 1.52rem;");
    expect(source).toContain(".queuePaneTitle {");
    expect(source).toContain(".chatHeaderNameRow strong {");
  });

  it("keeps final support chat readability styles on semantic tokens", () => {
    const source = readSupportStyles();
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
    expect(finalChatReadabilityLayer).toContain("letter-spacing: 0;");
    expect(finalChatReadabilityLayer).toContain("color: var(--text-strong);");
    expect(finalChatReadabilityLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 38%, var(--border-soft));"
    );
    expect(finalChatReadabilityLayer).toContain(
      "background: color-mix(in srgb, var(--success) 9%, var(--surface-2));"
    );
  });

  it("keeps late support workspace height rules viewport-safe on tablet and mobile", () => {
    const source = readSupportStyles();
    const finalChatReadabilityLayer = sliceBetween(
      source,
      "/* Final chat readability and alignment fixes */",
      "/* Late dark-theme support workspace overrides must stay below final polish rules. */"
    );

    expect(source).toContain("min-height: clamp(34rem, calc(100dvh - 9rem), 52rem);");
    expect(source).toContain("height: clamp(34rem, calc(100dvh - 9rem), 52rem);");
    expect(finalChatReadabilityLayer).toContain("@media (max-width: 1180px) {");
    expect(finalChatReadabilityLayer).toContain(
      ".inboxPaneFlat,\n  .chatShell,\n  .infoPanelFlat {\n    min-height: auto;\n    height: auto;\n    max-height: none;\n  }"
    );
    expect(finalChatReadabilityLayer).toContain("@media (max-width: 780px) {");
    expect(finalChatReadabilityLayer).toContain("border-radius: 1rem;");
    expect(finalChatReadabilityLayer).not.toContain(
      "height: clamp(42rem, calc(100dvh - 9rem), 52rem);"
    );
    expect(source).not.toContain("min-height: clamp(42rem, calc(100dvh - 9rem), 52rem);");
  });

  it("keeps late light-theme support status overrides tokenized", () => {
    const source = readSupportStyles();
    const lateLightStatusLayer = sliceBetween(
      source,
      ':global(:root[data-theme="light"]) .paneCountBadge',
      "/* ── Avatar Color Variants (hash-based per user) ── */"
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
      "background: color-mix(in srgb, var(--info) 9%, var(--surface-1));"
    );
  });

  it("keeps hash-based support avatar variants on semantic theme tokens", () => {
    const source = readSupportStyles();
    const avatarVariantLayer = sliceBetween(
      source,
      "/* ── Avatar Color Variants (hash-based per user) ── */",
      "/* ── Queue Footer ── */"
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
    const source = readSupportStyles();
    const composerMediaLayer = sliceBetween(
      source,
      "/* ── Composer Bottom Toolbar ── */",
      "/* ── Queue Panel Refresh ── */"
    );

    expect(composerMediaLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(composerMediaLayer).not.toContain("rgba(");
    expect(composerMediaLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(composerMediaLayer).toContain("color: var(--accent);");
    expect(composerMediaLayer).toContain("color: var(--danger);");
    expect(composerMediaLayer).toContain("color: var(--success);");
    expect(composerMediaLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--accent) 32%, var(--border-soft));"
    );
    expect(composerMediaLayer).toContain(
      "background: color-mix(in srgb, var(--surface-0) 76%, transparent);"
    );
    expect(composerMediaLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 78%, var(--success) 22%);"
    );
    expect(composerMediaLayer).toContain(
      "background: color-mix(in srgb, var(--text-muted) 10%, var(--surface-2));"
    );
  });

  it("keeps refreshed support queue panel chrome on semantic theme tokens", () => {
    const source = readSupportStyles();
    const queueRefreshLayer = sliceBetween(
      source,
      "/* ── Queue Panel Refresh ── */",
      "/* ── Ticket Panel Redesign ── */"
    );

    expect(queueRefreshLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueRefreshLayer).not.toContain("rgba(");
    expect(queueRefreshLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueRefreshLayer).toContain("color-mix(in srgb, var(--success) 18%, var(--surface-2))");
    expect(queueRefreshLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 34%, var(--border-soft));"
    );
    expect(queueRefreshLayer).toContain(".queueToolField select:focus-visible");
    expect(queueRefreshLayer).toContain("box-shadow: var(--focus-ring);");
    expect(queueRefreshLayer).toContain(
      "color-mix(in srgb, var(--surface-2) 78%, var(--surface-1) 22%)"
    );
    expect(queueRefreshLayer).toContain(
      "0 6px 16px color-mix(in srgb, var(--surface-0) 8%, transparent)"
    );
    expect(queueRefreshLayer).toContain(
      "border-color: color-mix(in srgb, var(--success) 62%, var(--border-soft));"
    );
  });

  it("keeps redesigned support ticket info panel on semantic theme tokens", () => {
    const source = readSupportStyles();
    const ticketPanelLayer = sliceBetween(
      source,
      "/* ── Ticket Panel Redesign ── */",
      "/* ── Support Workspace Reference Refresh ── */"
    );

    expect(ticketPanelLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(ticketPanelLayer).not.toContain("rgba(");
    expect(ticketPanelLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(ticketPanelLayer).toContain(
      "color-mix(in srgb, var(--surface-2) 82%, var(--surface-1) 18%)"
    );
    expect(ticketPanelLayer).toContain(".infoPanelSelect:focus-visible");
    expect(ticketPanelLayer).toContain(".infoPanelTagInput:focus-visible");
    expect(ticketPanelLayer).toContain("box-shadow: var(--focus-ring);");
    expect(ticketPanelLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--success) 28%, var(--border-soft));"
    );
    expect(ticketPanelLayer).toContain(
      "color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(ticketPanelLayer).toContain(
      "border-color: color-mix(in srgb, var(--accent) 38%, var(--border-soft));"
    );
    expect(ticketPanelLayer).toContain(
      "box-shadow: 0 0 0 1px color-mix(in srgb, var(--accent) 16%, transparent);"
    );
  });

  it("keeps support reference header chrome on semantic theme tokens", () => {
    const source = readSupportStyles();
    const referenceHeaderLayer = sliceBetween(
      source,
      "/* ── Support Workspace Reference Refresh ── */",
      ".workspaceFullView {\n  grid-template-columns: minmax(16rem, 17.4rem)"
    );

    expect(referenceHeaderLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(referenceHeaderLayer).not.toContain("rgba(");
    expect(referenceHeaderLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(referenceHeaderLayer).toContain(
      "color: color-mix(in srgb, var(--text-muted) 84%, var(--success) 16%);"
    );
    expect(referenceHeaderLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 68%, var(--success) 32%);"
    );
    expect(referenceHeaderLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 28%, var(--border-soft));"
    );
    expect(referenceHeaderLayer).toContain(
      "box-shadow: 0 14px 30px color-mix(in srgb, var(--surface-0) 6%, transparent);"
    );
    expect(referenceHeaderLayer).toContain("background: var(--danger);");
    expect(referenceHeaderLayer).toContain("color: var(--accent-contrast);");
  });

  it("keeps support workspace queue shell chrome on semantic theme tokens", () => {
    const source = readSupportStyles();
    const queueShellLayer = sliceBetween(
      source,
      ".workspaceFullView {\n  grid-template-columns: minmax(16rem, 17.4rem)",
      ".queueSortRow"
    );

    expect(queueShellLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(queueShellLayer).not.toContain("rgba(");
    expect(queueShellLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(queueShellLayer).toContain(
      "border: 1px solid color-mix(in srgb, var(--text-muted) 26%, var(--border-soft));"
    );
    expect(queueShellLayer).toContain(
      "box-shadow: 0 18px 40px color-mix(in srgb, var(--surface-0) 7%, transparent);"
    );
    expect(queueShellLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 14%, var(--surface-2));"
    );
    expect(queueShellLayer).toContain(
      "background: color-mix(in srgb, var(--surface-2) 95%, var(--surface-1));"
    );
    expect(queueShellLayer).toContain(
      "box-shadow: 0 6px 14px color-mix(in srgb, var(--surface-0) 8%, transparent);"
    );
    expect(queueShellLayer).toContain(
      "background: color-mix(in srgb, var(--accent) 10%, var(--surface-1));"
    );
  });

  it("keeps support queue counters and status pills on semantic theme tokens", () => {
    const source = readSupportStyles();
    const queueStatusLayer = sliceBetween(source, ".queueCountBadge", ".slaPill");

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
    const source = readSupportStyles();

    expect(source).toContain("height: clamp(38rem, calc(100dvh - 10rem), 66rem);");
    expect(source).toContain("max-height: calc(100dvh - 2.4rem);");
    expect(source).toContain("max-height: calc(100dvh - 14rem);");
    expect(source).toContain("min-height: clamp(34rem, calc(100dvh - 9rem), 52rem);");
    expect(source).not.toContain("min-height: clamp(42rem, calc(100dvh - 9rem), 52rem);");
    expect(source).not.toContain("100vh");
  });

  it("keeps late support workspace dark overrides below final polish styles", () => {
    const source = readSupportStyles();
    const finalPolishIndex = source.indexOf("/* Final support workspace polish */");
    const finalChatPolishIndex = source.indexOf("/* Final chat readability and alignment fixes */");
    const lateDarkOverrideIndex = source.indexOf(
      "/* Late dark-theme support workspace overrides must stay below final polish rules. */"
    );
    const lateDarkOverrideLayer = source.slice(lateDarkOverrideIndex);

    expect(finalPolishIndex).toBeGreaterThanOrEqual(0);
    expect(finalChatPolishIndex).toBeGreaterThan(finalPolishIndex);
    expect(lateDarkOverrideIndex).toBeGreaterThan(finalChatPolishIndex);
    expect(lateDarkOverrideLayer).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(lateDarkOverrideLayer).not.toContain("rgba(");
    expect(lateDarkOverrideLayer).not.toMatch(/letter-spacing:\s*-/);

    expect(lateDarkOverrideLayer).toContain(
      ':global(:root:not([data-theme="light"])) .queueSubFilters'
    );
    expect(lateDarkOverrideLayer).toContain(
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
      "0 14px 30px color-mix(in srgb, var(--surface-0) 46%, transparent) !important;"
    );
  });
});
