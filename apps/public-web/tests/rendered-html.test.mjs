import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname, protocol = "http") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(
    new Request(`${protocol}://localhost${pathname}`, { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

async function readRoute(pathname) {
  const response = await render(pathname);
  assert.equal(response.status, 200, pathname);
  return response.text();
}

test("renders public information routes independently of the API", async () => {
  for (const [path, expected] of [
    ["/", "Clear answers for you and your pet"],
    ["/privacy", "PetMagic Privacy Policy"],
    ["/terms", "PetMagic Terms of Use"],
    ["/support", "Contact us in the app"],
    ["/account-deletion", "Delete your account"],
    ["/ru/privacy", "Политика конфиденциальности PetMagic"],
  ]) {
    const response = await render(path);
    assert.equal(response.status, 200, path);
    assert.match(await response.text(), new RegExp(expected, "i"), path);
  }
});

test("exposes keyboard and reduced-motion accessibility contracts", async () => {
  const response = await render("/privacy");
  const html = await response.text();
  assert.match(html, /class="skip-link"/);
  assert.match(html, /<main id="main-content"/);
  assert.match(html, /aria-label="Primary"/);
});

test("adds browser security headers to public responses", async () => {
  const response = await render("/privacy");

  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.equal(response.headers.get("x-frame-options"), "DENY");
  assert.equal(response.headers.get("referrer-policy"), "no-referrer");
  assert.equal(response.headers.get("cross-origin-opener-policy"), "same-origin");
  assert.equal(response.headers.get("cross-origin-resource-policy"), "same-origin");
  assert.equal(
    response.headers.get("permissions-policy"),
    "camera=(), geolocation=(), microphone=(), payment=(), usb=()",
  );
  assert.equal(response.headers.get("strict-transport-security"), null);

  const httpsResponse = await render("/privacy", "https");
  assert.equal(
    httpsResponse.headers.get("strict-transport-security"),
    "max-age=31536000; includeSubDomains",
  );
});

test("locale navigation preserves the current information route", async () => {
  const support = await readRoute("/support");
  assert.match(support, /href="\/ru\/support"/);
  assert.match(support, /href="\/de\/support"/);

  const deletion = await readRoute("/account-deletion");
  assert.match(deletion, /href="\/ru\/account-deletion"/);
  assert.match(deletion, /href="\/account-deletion"/);
});
