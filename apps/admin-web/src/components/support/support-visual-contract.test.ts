import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const supportStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));
const supportConversationPagePath = fileURLToPath(
  new URL("./support-conversation-page.tsx", import.meta.url)
);
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
  it("uses shared admin icons for search and drag-drop affordances", () => {
    const pageSource = readFileSync(supportConversationPagePath, "utf8");
    const iconsSource = readFileSync(adminIconsPath, "utf8");
    const stylesSource = readSupportStyles();

    expect(pageSource).toContain("SearchIcon");
    expect(pageSource).toContain("UploadIcon");
    expect(pageSource).not.toContain("<svg");
    expect(pageSource).not.toContain('width="40"');
    expect(pageSource).not.toContain("M12.5 12.5 17 17");

    expect(iconsSource).toContain("export function SearchIcon");
    expect(iconsSource).toContain("export function UploadIcon");
    expect(stylesSource).toContain(".dropOverlayIcon {");
    expect(stylesSource).toContain("width: 40px;");
    expect(stylesSource).toContain("height: 40px;");
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
    const replyComposerLayer = sliceBetween(
      source,
      ".messageTick",
      ".attachmentPreviewCard"
    );

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
    const sidePanelListsLayer = sliceBetween(source, ".templateListItem", "@media (max-width: 1320px)");

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
});
