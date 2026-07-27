import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const pagePath = fileURLToPath(new URL("./support-conversation-page.tsx", import.meta.url));
const pageStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));
const drawerPath = fileURLToPath(
  new URL("./support-conversation-details-drawer.tsx", import.meta.url)
);
const drawerStylesPath = fileURLToPath(
  new URL("./support-conversation-details-drawer.module.css", import.meta.url)
);
const chatContentPath = fileURLToPath(
  new URL("./support-conversation-chat-content.tsx", import.meta.url)
);

function read(path: string) {
  return readFileSync(path, "utf8");
}

describe("support conversation details drawer", () => {
  it("keeps one details panel while compact workspaces expose it through an accessible trigger", () => {
    const page = read(pagePath);
    const pageStyles = read(pageStylesPath);
    const chatContent = read(chatContentPath);

    expect(page).toContain('window.matchMedia("(max-width: 1320px)")');
    expect(page).toContain("aria-controls={supportDetailsDrawerId}");
    expect(page).toContain("aria-expanded={isSupportDetailsDrawerOpen}");
    expect(page).toContain("<SupportConversationDetailsDrawer");
    expect(page.match(/<SupportInfoPanel\b/g)).toHaveLength(1);
    expect(chatContent).toContain("action?: ReactNode;");
    expect(chatContent).toContain("className={styles.chatHeaderAction}");

    expect(pageStyles).toContain("@media (max-width: 1320px) {");
    expect(pageStyles).toContain("grid-template-columns: minmax(13.5rem, 16rem) minmax(0, 1fr);");
    expect(pageStyles).toContain(".detailsTrigger {");
  });

  it("locks focus and scrolling only while the compact drawer is open", () => {
    const drawer = read(drawerPath);
    const drawerStyles = read(drawerStylesPath);

    expect(drawer).toContain('document.body.style.overflow = "hidden";');
    expect(drawer).toContain("previouslyFocusedElementRef.current?.focus();");
    expect(drawer).toContain('event.key === "Escape"');
    expect(drawer).toContain("focusableSelector");
    expect(drawer).toContain("aria-modal={isDialogOpen ? true : undefined}");
    expect(drawer).toContain('data-testid="support-details-backdrop"');
    expect(drawer).toContain('data-testid="support-details-drawer"');
    expect(drawerStyles).toContain(".detailsSlotDrawerOpen {");
    expect(drawerStyles).toContain("position: fixed;");
    expect(drawerStyles).toContain("@media (max-width: 1320px) {");
  });
});
