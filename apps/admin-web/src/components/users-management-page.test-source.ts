import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const usersManagementPageLibraryPaths = [
  fileURLToPath(new URL("./users-management-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-actions-menu.ts", import.meta.url)),
  fileURLToPath(new URL("./users-management-page.chrome.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-page.helpers.ts", import.meta.url)),
  fileURLToPath(new URL("./users-management-page.types.ts", import.meta.url)),
  fileURLToPath(new URL("./users-management-page-overlays.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-page-workspace.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-page-overlays-composition.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-users-card.filters.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-users-card.table.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-users-card.tsx", import.meta.url)),
  fileURLToPath(new URL("./users-management-side-panel.tsx", import.meta.url)),
];

export function readUsersManagementPageLibrarySource(): string {
  return usersManagementPageLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
