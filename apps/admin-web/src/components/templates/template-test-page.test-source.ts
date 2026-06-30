import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const templateTestPageLibraryPaths = [
  fileURLToPath(new URL("./template-test-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./template-test-page.types.ts", import.meta.url)),
  fileURLToPath(new URL("./template-test-page.helpers.ts", import.meta.url)),
  fileURLToPath(new URL("./template-test-page.components.tsx", import.meta.url)),
  fileURLToPath(new URL("./template-test-page.sections.tsx", import.meta.url)),
  fileURLToPath(new URL("./template-test-page.media-actions.tsx", import.meta.url)),
];

export function readTemplateTestPageLibrarySource(): string {
  return templateTestPageLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
