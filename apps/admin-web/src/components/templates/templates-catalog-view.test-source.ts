import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const templatesCatalogViewLibraryPaths = [
  fileURLToPath(new URL("./templates-catalog-view.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-catalog-view.card.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-catalog-view.list.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-catalog-view.dialogs.tsx", import.meta.url)),
];

export function readTemplatesCatalogViewLibrarySource(): string {
  return templatesCatalogViewLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
