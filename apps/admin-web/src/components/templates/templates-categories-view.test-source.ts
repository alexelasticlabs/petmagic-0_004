import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const templatesCategoriesViewLibraryPaths = [
  fileURLToPath(new URL("./templates-categories-view.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-categories-view.table.tsx", import.meta.url)),
];

export function readTemplatesCategoriesViewLibrarySource(): string {
  return templatesCategoriesViewLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
