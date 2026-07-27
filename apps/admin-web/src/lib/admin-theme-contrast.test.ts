import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const globalsPath = fileURLToPath(new URL("../app/globals.css", import.meta.url));

function relativeLuminance(hexColor: string): number {
  const channels = hexColor
    .slice(1)
    .match(/.{2}/g)
    ?.map((channel) => Number.parseInt(channel, 16) / 255);

  if (!channels || channels.length !== 3) {
    throw new Error(`Unsupported color: ${hexColor}`);
  }

  const linearChannels = channels.map((channel) =>
    channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
  );
  const red = linearChannels[0] ?? 0;
  const green = linearChannels[1] ?? 0;
  const blue = linearChannels[2] ?? 0;

  return red * 0.2126 + green * 0.7152 + blue * 0.0722;
}

function contrastRatio(foreground: string, background: string): number {
  const foregroundLuminance = relativeLuminance(foreground);
  const backgroundLuminance = relativeLuminance(background);
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
}

describe("admin light theme contrast", () => {
  it("keeps subtle text at WCAG AA contrast on the primary light surface", () => {
    const source = readFileSync(globalsPath, "utf8");
    const lightTheme = source.match(/:root\[data-theme="light"\]\s*\{([\s\S]*?)\n\}/)?.[1];
    const textSubtle = lightTheme?.match(/--text-subtle:\s*(#[0-9a-fA-F]{6});/)?.[1];
    const surface = lightTheme?.match(/--surface-1:\s*(#[0-9a-fA-F]{6});/)?.[1];

    expect(textSubtle).toBeDefined();
    expect(surface).toBeDefined();
    expect(contrastRatio(textSubtle ?? "#000000", surface ?? "#ffffff")).toBeGreaterThanOrEqual(
      4.5
    );
  });
});
