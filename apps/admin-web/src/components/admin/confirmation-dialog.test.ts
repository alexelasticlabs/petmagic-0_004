import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const dialogPath = fileURLToPath(new URL("./confirmation-dialog.tsx", import.meta.url));
const dialogCssPath = fileURLToPath(new URL("./confirmation-dialog.module.css", import.meta.url));
const buttonPath = fileURLToPath(new URL("../../components/ui/button.tsx", import.meta.url));

describe("admin confirmation dialog", () => {
  it("keeps destructive dialogs accessible and stable on small screens", () => {
    const source = readFileSync(dialogPath, "utf8");
    const css = readFileSync(dialogCssPath, "utf8");
    const buttonSource = readFileSync(buttonPath, "utf8");

    expect(buttonSource).toContain("forwardRef<HTMLButtonElement, ButtonProps>");
    expect(buttonSource).toContain("<button ref={ref}");

    expect(source).toContain("const titleId = useId();");
    expect(source).toContain("const descriptionId = useId();");
    expect(source).toContain("const cancelButtonRef = useRef<HTMLButtonElement>(null);");
    expect(source).toContain("const previouslyFocusedElementRef = useRef<HTMLElement | null>(null);");
    expect(source).toContain("document.body.style.overflow = \"hidden\";");
    expect(source).toContain("document.body.style.overflow = previousOverflow;");
    expect(source).toContain("cancelButtonRef.current?.focus();");
    expect(source).toContain("previouslyFocusedElementRef.current?.focus();");
    expect(source).toContain("aria-labelledby={titleId}");
    expect(source).toContain("aria-describedby={descriptionId}");
    expect(source).toContain("ref={cancelButtonRef}");
    expect(source).not.toContain('aria-labelledby="admin-confirmation-title"');
    expect(source).not.toContain('id="admin-confirmation-title"');

    expect(css).toContain("max-height: min(42rem, calc(100dvh - 1.8rem));");
    expect(css).toContain("overflow-y: auto;");
    expect(css).toContain("flex-wrap: wrap;");
    expect(css).toContain("background: color-mix(in srgb, var(--surface-0) 72%, transparent);");
    expect(css).toContain("box-shadow: var(--shadow-strong);");
    expect(css).not.toContain("rgba(");
    expect(css).not.toContain("0 24px 52px");
    expect(css).toContain("@media (max-width: 420px)");
    expect(css).toContain(".actions :global(.ui-button)");
  });
});
