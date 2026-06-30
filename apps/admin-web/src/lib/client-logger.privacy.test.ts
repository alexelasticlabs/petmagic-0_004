import { describe, expect, it } from "vitest";

import {
  sanitizeClientLogContextForTesting,
  sanitizeClientLogTextForTesting,
} from "@/lib/client-logger";

describe("client logger privacy hardening", () => {
  it("masks absolute media and attachment URLs in structured log context", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      attachmentUrl: "https://cdn.petmagic.ai/private/user-42/support/alice@example.com-photo.png",
      previewUrl:
        "https://cdn.petmagic.ai/templates/preview/cat.png?X-Amz-Signature=preview-secret",
      nested: {
        videoUrl: "https://video.petmagic.ai/runs/private-output.mp4",
        blobUrl: "blob:https://admin.petmagic.ai/1234-5678",
      },
      items: [
        {
          fileUrl: "https://cdn.petmagic.ai/files/raw-attachment.pdf",
        },
      ],
      status: 502,
    });

    expect(sanitized).toEqual({
      attachmentUrl: "https://cdn.petmagic.ai/***",
      previewUrl: "https://cdn.petmagic.ai/***",
      nested: {
        videoUrl: "https://video.petmagic.ai/***",
        blobUrl: "blob:***",
      },
      items: [
        {
          fileUrl: "https://cdn.petmagic.ai/***",
        },
      ],
      status: 502,
    });
  });

  it("redacts local file paths and inline URLs from free-form log text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "Preview fetch failed for https://cdn.petmagic.ai/private/run/output.png " +
        "and blob:https://admin.petmagic.ai/1234-5678 " +
        "from C:\\Users\\aleks\\Downloads\\pet.png"
    );

    expect(sanitized).toContain("https://cdn.petmagic.ai/***");
    expect(sanitized).toContain("blob:***");
    expect(sanitized).not.toContain("/private/run/output.png");
    expect(sanitized).not.toContain("1234-5678");
    expect(sanitized).not.toContain("C:\\Users\\aleks\\Downloads\\pet.png");
  });

  it("keeps non-sensitive request metadata readable", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      path: "/api/templates/feed",
      method: "GET",
      status: 504,
    });

    expect(sanitized).toEqual({
      path: "/api/templates/feed",
      method: "GET",
      status: 504,
    });
  });
});
