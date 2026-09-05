import type { BrowserContext, Page } from "@playwright/test";

const captureScriptUrl = "https://mcp.figma.com/mcp/html-to-design/capture.js";
const captureScripts = new WeakMap<BrowserContext, Promise<string>>();

type CaptureMap = Record<string, string>;

type CaptureOptions = {
  delayMs?: number;
  selector?: string;
};

function getCaptureMap(): CaptureMap {
  const raw = process.env.FIGMA_CAPTURE_MAP_JSON;
  if (!raw) {
    return {};
  }

  const parsed: unknown = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("FIGMA_CAPTURE_MAP_JSON must contain a JSON object.");
  }

  return Object.fromEntries(
    Object.entries(parsed).filter(
      (entry): entry is [string, string] =>
        typeof entry[0] === "string" && typeof entry[1] === "string" && entry[1].length > 0
    )
  );
}

export function hasFigmaCaptureState(stateKey: string) {
  return Boolean(getCaptureMap()[stateKey]);
}

export async function installFigmaCaptureRouting(page: Page) {
  if (!process.env.FIGMA_CAPTURE_MAP_JSON) {
    return;
  }

  await page.route(/^https?:\/\/(?:127\.0\.0\.1|localhost)(?::\d+)?\//, async (route) => {
    if (route.request().resourceType() !== "document") {
      await route.continue();
      return;
    }

    const response = await route.fetch();
    const headers = { ...response.headers() };
    delete headers["content-security-policy"];
    delete headers["content-security-policy-report-only"];
    await route.fulfill({ response, headers });
  });
}

function getCaptureScript(context: BrowserContext) {
  const existing = captureScripts.get(context);
  if (existing) {
    return existing;
  }

  const pending = context.request.get(captureScriptUrl).then(async (response) => {
    if (!response.ok()) {
      throw new Error(`Figma capture script returned HTTP ${response.status()}.`);
    }

    return response.text();
  });
  captureScripts.set(context, pending);
  return pending;
}

export async function captureFigmaState(
  page: Page,
  stateKey: string,
  options: CaptureOptions = {}
) {
  const captureId = getCaptureMap()[stateKey];
  if (!captureId) {
    return false;
  }

  const previousViewport = page.viewportSize();
  const cdp = await page.context().newCDPSession(page);

  try {
    await page.setViewportSize({ width: 1536, height: 1024 });
    await page.evaluate(() => window.scrollTo({ left: 0, top: 0, behavior: "auto" }));
    await page.waitForTimeout(options.delayMs ?? 350);
    await cdp.send("Page.setBypassCSP", { enabled: true });

    const endpoint =
      `https://mcp.figma.com/mcp/capture/${captureId}/submit` + "?bindVariables=true";
    const captureHash = new URLSearchParams({
      figmacapture: captureId,
      figmadelay: String(options.delayMs ?? 350),
      figmaendpoint: endpoint,
      figmaselector: options.selector ?? "body",
    }).toString();
    const submissionResponse = page.waitForResponse(
      (response) =>
        response.request().method() === "POST" &&
        response.url().startsWith(`https://mcp.figma.com/mcp/capture/${captureId}/submit`),
      { timeout: 90_000 }
    );
    await page.evaluate(
      (hash) =>
        window.history.replaceState(
          null,
          "",
          `${window.location.pathname}${window.location.search}#${hash}`
        ),
      captureHash
    );
    await page.addScriptTag({ content: await getCaptureScript(page.context()) });

    const response = await submissionResponse;
    if (!response.ok()) {
      throw new Error(`Figma capture submission returned HTTP ${response.status()}.`);
    }

    const removeCaptureUi = () =>
      page.evaluate(() => {
        const removeToolbar = () =>
          document.getElementById("__figma_capture_toolbar_host__")?.remove();
        const observer = new MutationObserver(removeToolbar);
        observer.observe(document.documentElement, { childList: true, subtree: true });
        window.setTimeout(() => observer.disconnect(), 3_000);
        removeToolbar();
        window.history.replaceState(
          null,
          "",
          `${window.location.pathname}${window.location.search}`
        );
      });

    await removeCaptureUi();
    await page.waitForTimeout(250);
    await removeCaptureUi();

    return true;
  } finally {
    await cdp.send("Page.setBypassCSP", { enabled: false }).catch(() => undefined);
    await cdp.detach().catch(() => undefined);
    if (previousViewport) {
      await page.setViewportSize(previousViewport).catch(() => undefined);
      await page.waitForTimeout(250).catch(() => undefined);
    }
    await page
      .evaluate(() => {
        document.getElementById("__figma_capture_toolbar_host__")?.remove();
      })
      .catch(() => undefined);
  }
}
