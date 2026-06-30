import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const generationsPageLibraryPaths = [
  fileURLToPath(new URL("./generations-page.tsx", import.meta.url)),
  fileURLToPath(new URL("./generations-page.row.tsx", import.meta.url)),
];

export function readGenerationsPageLibrarySource(): string {
  return generationsPageLibraryPaths.map((path) => readFileSync(path, "utf8")).join("\n");
}
