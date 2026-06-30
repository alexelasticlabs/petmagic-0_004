import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const supportConversationControllerLibraryPaths = [
  fileURLToPath(new URL("./use-support-conversation-controller.ts", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-controller.helpers.ts", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-controller.derived.ts", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-controller.subject.ts", import.meta.url)),
  fileURLToPath(new URL("./support-conversation-controller.mutations.ts", import.meta.url)),
];

export function readSupportConversationControllerLibrarySource(): string {
  return supportConversationControllerLibraryPaths
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
}
