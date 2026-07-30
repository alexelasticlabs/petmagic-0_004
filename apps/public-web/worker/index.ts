/** Cloudflare Worker entry point for the PetMagic public legal site. */
import handler from "vinext/server/app-router-entry";

type VinextWorkerEnv = NonNullable<Parameters<typeof handler.fetch>[1]>;

const worker = {
  async fetch(request: Request, env: VinextWorkerEnv, ctx: ExecutionContext): Promise<Response> {
    return withSecurityHeaders(request, await handler.fetch(request, env, ctx));
  },
} satisfies ExportedHandler<VinextWorkerEnv>;

function withSecurityHeaders(request: Request, response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("Cross-Origin-Opener-Policy", "same-origin");
  headers.set("Cross-Origin-Resource-Policy", "same-origin");
  headers.set(
    "Content-Security-Policy",
    "default-src 'self'; base-uri 'none'; connect-src 'self'; font-src 'self'; "
      + "form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; object-src 'none'; "
      + "script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; upgrade-insecure-requests",
  );
  headers.set("Permissions-Policy", "camera=(), geolocation=(), microphone=(), payment=(), usb=()");
  headers.set("Referrer-Policy", "no-referrer");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("X-Frame-Options", "DENY");

  if (new URL(request.url).protocol === "https:") {
    headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  }

  return new Response(response.body, {
    headers,
    status: response.status,
    statusText: response.statusText,
  });
}

export default worker;
