import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const promoCodesViewPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const promoCodesViewChromePath = fileURLToPath(
  new URL("./promo-codes-view.chrome.tsx", import.meta.url)
);

export function readPromoCodesViewLibrarySource() {
  return [promoCodesViewPath, promoCodesViewChromePath]
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
}
