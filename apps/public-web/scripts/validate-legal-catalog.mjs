import { readFile } from "node:fs/promises";

const catalogUrl = new URL("../../../shared/legal/legal-documents.v2026-07-09.json", import.meta.url);
const catalog = JSON.parse(await readFile(catalogUrl, "utf8"));
const missing = catalog.requiredLocales.filter((locale) => !catalog.locales[locale]);

if (catalog.version !== "2026-07-09") {
  throw new Error(`Unexpected legal catalog version: ${catalog.version}`);
}
if (missing.length > 0) {
  throw new Error(
    `Approved legal translations are missing for: ${missing.join(", ")}. Public rollout is blocked.`,
  );
}
console.log(`Legal catalog ${catalog.version} includes all required locales.`);
