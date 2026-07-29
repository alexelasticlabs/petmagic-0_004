import { NextRequest, NextResponse } from "next/server";

import { buildNonceContentSecurityPolicy } from "@/lib/content-security-policy";

export function proxy(request: NextRequest) {
  const nonce = btoa(crypto.randomUUID());
  const contentSecurityPolicy = buildNonceContentSecurityPolicy(nonce);
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("Content-Security-Policy", contentSecurityPolicy);

  const response = NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });
  response.headers.set("Content-Security-Policy", contentSecurityPolicy);
  if (/^\/(?:ru|en)\/generations\/?$/.test(request.nextUrl.pathname)) {
    // The authenticated page is client-gated, so its body marker is intentionally absent
    // from an unauthenticated server response. Expose a non-sensitive route identity for
    // Render's read-only postdeploy check instead of depending on hydrated browser state.
    response.headers.set("X-PetMagic-Admin-Route", "generations");
  }
  return response;
}

export const config = {
  matcher: [
    {
      source: "/((?!api|_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
      missing: [
        { type: "header", key: "next-router-prefetch" },
        { type: "header", key: "purpose", value: "prefetch" },
      ],
    },
  ],
};
