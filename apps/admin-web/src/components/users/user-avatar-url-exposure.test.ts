import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { resolveUserMediaUrl } from "./user-secure-media";

const userAvatarPath = fileURLToPath(new URL("./user-avatar.tsx", import.meta.url));
const userAvatarStylesPath = fileURLToPath(new URL("./user-avatar.module.css", import.meta.url));
const userDetailPath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const secureMediaImagePath = fileURLToPath(
  new URL("./user-secure-media-image.tsx", import.meta.url)
);
const secureMediaHelperPath = fileURLToPath(new URL("./user-secure-media.ts", import.meta.url));

describe("user avatar URL exposure", () => {
  it("does not render backend avatar URLs directly in image src attributes", () => {
    const source = readFileSync(userAvatarPath, "utf8");
    const helperSource = readFileSync(secureMediaHelperPath, "utf8");

    expect(source).not.toContain('from "next/image"');
    expect(source).not.toContain("src={imageUrl}");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("const activeObjectUrlRef = useRef<string | null>(null);");
    expect(source).toContain("const revokeActiveObjectUrl = useCallback(");
    expect(source).toContain(
      "revokeActiveObjectUrl();\n        activeObjectUrlRef.current = createdObjectUrl;"
    );
    expect(source).toContain(
      "if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl)"
    );
    expect(source).toContain(
      "onError={() => {\n            if (imageUrl) {\n              revokeActiveObjectUrl();"
    );
    expect(source).toContain("fetchWithTimeout(imageUrl");
    expect(source).toContain("users.avatar_fetch_failed");
    expect(helperSource).toContain("import { sanitizeSensitiveText }");
    expect(helperSource).toContain("export function getUserMediaFetchErrorDetails(error: unknown)");
    expect(helperSource).toContain(
      "function getUserMediaUrlResolutionErrorDetails(rawUrl: string, error: unknown)"
    );
    expect(helperSource).toContain("function getBlockedLocalUserMediaUrlDetails(rawUrl: string)");
    expect(helperSource).toContain('"users.media_url_localhost_blocked"');
    expect(helperSource).toContain("function getBlockedUnsafeUserMediaUrlDetails(rawUrl: string)");
    expect(helperSource).toContain('"users.media_url_unsafe_host_blocked"');
    expect(helperSource).toContain("function isUnsafeUserMediaHost(hostname: string)");
    expect(helperSource).toContain("if (!isLocalDevelopmentHost(new URL(apiOrigin).hostname))");
    expect(helperSource).toContain('clientLogger.warn(\n      "users.media_url_resolve_failed",');
    expect(helperSource).toContain("rawLength: rawUrl.length");
    expect(helperSource).toContain('startsWithSlash: rawUrl.startsWith("/")');
    expect(helperSource).toContain(
      'isBlobOrData: rawUrl.startsWith("blob:") || rawUrl.startsWith("data:")'
    );
    expect(helperSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(source).toContain("getUserMediaFetchErrorDetails(error)");
    expect(source).not.toContain('clientLogger.warn("users.avatar_fetch_failed", { error })');
    expect(helperSource).not.toContain(
      'clientLogger.warn("users.media_url_resolve_failed", { rawUrl'
    );
    expect(helperSource).not.toContain(
      'clientLogger.warn("users.media_url_localhost_blocked", { rawUrl'
    );
    expect(helperSource).not.toContain(
      'clientLogger.warn("users.media_url_unsafe_host_blocked", { rawUrl'
    );
  });

  it("blocks private network and placeholder user media URLs before browser fetch", () => {
    expect(resolveUserMediaUrl("https://192.168.1.5/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://10.0.0.5/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://169.254.169.254/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://[::]/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://[::ffff:127.0.0.1]/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://[::ffff:10.0.0.5]/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://[fd00::1]/avatar.jpg")).toBeNull();
    expect(resolveUserMediaUrl("https://cdn.example.com/avatar.jpg")).toBeNull();
  });

  it("blocks local user media URLs when the admin API origin is public", () => {
    const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.petgpt.app";

    try {
      expect(resolveUserMediaUrl("https://localhost/avatar.jpg")).toBeNull();
      expect(resolveUserMediaUrl("https://api.localhost/avatar.jpg")).toBeNull();
      expect(resolveUserMediaUrl("https://host.docker.internal/avatar.jpg")).toBeNull();
      expect(resolveUserMediaUrl("https://backend:5000/avatar.jpg")).toBeNull();
      expect(resolveUserMediaUrl("https://0.0.0.0/avatar.jpg")).toBeNull();
      expect(resolveUserMediaUrl("https://[::1]/avatar.jpg")).toBeNull();
    } finally {
      if (originalPublicApiBaseUrl === undefined) {
        delete process.env.NEXT_PUBLIC_API_BASE_URL;
      } else {
        process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
      }
    }
  });

  it("does not render backend pet photo URLs directly in user detail cards", () => {
    const detailSource = readFileSync(userDetailPath, "utf8");
    const secureImageSource = readFileSync(secureMediaImagePath, "utf8");

    expect(detailSource).not.toContain('import Image from "next/image"');
    expect(detailSource).toContain("<UserSecureMediaImage");
    expect(detailSource).toContain("src={photo.thumbnailUrl ?? photo.url}");
    expect(detailSource).toContain('logEvent="users.pet_photo_fetch_failed"');
    expect(secureImageSource).not.toContain("src={imageUrl}");
    expect(secureImageSource).toContain("URL.createObjectURL(blob)");
    expect(secureImageSource).toContain("const activeObjectUrlRef = useRef<string | null>(null);");
    expect(secureImageSource).toContain("const revokeActiveObjectUrl = useCallback(");
    expect(secureImageSource).toContain(
      "revokeActiveObjectUrl();\n        activeObjectUrlRef.current = createdObjectUrl;"
    );
    expect(secureImageSource).toContain(
      "if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl)"
    );
    expect(secureImageSource).toContain(
      "onError={() => {\n        if (imageUrl) {\n          revokeActiveObjectUrl();"
    );
    expect(secureImageSource).toContain("fetchWithTimeout(imageUrl");
    expect(secureImageSource).toContain("getUserMediaFetchErrorDetails(error)");
    expect(secureImageSource).toContain("clientLogger.warn(logEvent, { status: response.status })");
    expect(secureImageSource).not.toContain("clientLogger.warn(logEvent, { error })");
  });

  it("keeps avatar fallback styling theme-token based", () => {
    const source = readFileSync(userAvatarStylesPath, "utf8");

    expect(source).toContain("border: 1px solid var(--border-soft)");
    expect(source).toContain("var(--surface-2)");
    expect(source).toContain("var(--surface-raised)");
    expect(source).toContain("color-mix(in srgb, var(--surface-2) 88%, var(--accent) 12%)");
    expect(source).toContain("box-shadow: var(--shadow-card)");
    expect(source).toContain("color: var(--text-strong)");
    expect(source).toContain("letter-spacing: 0");
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(source).not.toContain("rgba(");
    expect(source).not.toContain("radial-gradient");
  });
});
