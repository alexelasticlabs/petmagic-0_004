import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const templatesAnalyticsHubLibraryPaths = [
  fileURLToPath(new URL("./templates-analytics-hub-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./templates-analytics-hub-page.sections.tsx", import.meta.url)),
];

export function readTemplatesAnalyticsHubPageLibrarySource(): string {
  return templatesAnalyticsHubLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
