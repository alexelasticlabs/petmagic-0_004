import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const supportInfoPanelLibraryPaths = [
  fileURLToPath(new URL("./support-info-panel.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-info-panel-attachment-actions.ts", import.meta.url)),
  fileURLToPath(new URL("./support-info-panel-attachments.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-info-panel-history-sections.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-info-panel-user-tab.tsx", import.meta.url)),
];

export function readSupportInfoPanelLibrarySource(): string {
  return supportInfoPanelLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
