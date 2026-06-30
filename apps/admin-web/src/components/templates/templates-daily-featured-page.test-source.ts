import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const templatesDailyFeaturedPageLibraryPaths = [
  fileURLToPath(new URL("./templates-daily-featured-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-daily-featured-page.types.ts", import.meta.url)),
  fileURLToPath(new URL("./templates-daily-featured-page.helpers.ts", import.meta.url)),
  fileURLToPath(new URL("./use-templates-daily-featured-controller.ts", import.meta.url)),
  fileURLToPath(new URL("./templates-daily-featured-page.sections.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-daily-featured-page.schedule.tsx", import.meta.url)),
];

export function readTemplatesDailyFeaturedPageLibrarySource(): string {
  return templatesDailyFeaturedPageLibraryPaths
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
}
