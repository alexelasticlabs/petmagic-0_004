import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const dashboardViewLibraryPaths = [
  fileURLToPath(new URL("./dashboard-view.tsx", import.meta.url)),
  fileURLToPath(new URL("./dashboard-view.model.ts", import.meta.url)),
];

export function readDashboardViewLibrarySource(): string {
  return dashboardViewLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
