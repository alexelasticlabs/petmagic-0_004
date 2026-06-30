import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const feedbackPageLibraryPaths = [
  fileURLToPath(new URL("./feedback-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./feedback-page.sections.tsx", import.meta.url)),
];

export function readFeedbackPageLibrarySource(): string {
  return feedbackPageLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
