import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const supportConversationPageLibraryPaths = [
  fileURLToPath(new URL("./support-conversation-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-media-actions.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-chat-content.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-chat-pane.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-queue-pane.tsx", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-fullscreen-viewer.tsx", import.meta.url)),
];

export function readSupportConversationPageLibrarySource(): string {
  return supportConversationPageLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
