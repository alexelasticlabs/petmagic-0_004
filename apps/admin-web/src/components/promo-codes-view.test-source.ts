import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const promoCodesViewPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const promoCodesViewChromePath = fileURLToPath(
  new URL("./promo-codes-view.chrome.tsx", import.meta.url)
);
const promoCodesViewWorkspacePath = fileURLToPath(
  new URL("./promo-codes-view-workspace.tsx", import.meta.url)
);
const promoCodesViewOverlaysPath = fileURLToPath(
  new URL("./promo-codes-view-overlays.tsx", import.meta.url)
);

export function readPromoCodesViewLibrarySource() {
  return [
    promoCodesViewPath,
    promoCodesViewChromePath,
    promoCodesViewWorkspacePath,
    promoCodesViewOverlaysPath,
  ]
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
}
