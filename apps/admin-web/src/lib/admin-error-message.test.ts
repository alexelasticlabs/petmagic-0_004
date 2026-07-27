import { describe, expect, it } from "vitest";

import { getAdminErrorMessage, getAdminRetryAfterSeconds } from "@/lib/admin-error-message";

describe("admin-error-message", () => {
  it("uses validation errors first", () => {
    expect(
      getAdminErrorMessage({ validationErrors: [" Name is required. ", "Too long"] }, "Fallback")
    ).toBe("Name is required. Too long");
  });

  it("uses localized fallbacks for status-only and code-only errors", () => {
    expect(getAdminErrorMessage({ status: 403, message: "auth.forbidden" }, "Localized")).toBe(
      "Localized"
    );
    expect(
      getAdminErrorMessage(
        {
          code: "auth.retry_required_after_refresh",
          message: "Session was refreshed. Review and retry this action.",
        },
        "Localized retry guidance"
      )
    ).toBe("Localized retry guidance");
  });

  it("exposes a bounded Retry-After delay without trusting invalid error data", () => {
    expect(getAdminRetryAfterSeconds({ retryAfterSeconds: 12 })).toBe(12);
    expect(getAdminRetryAfterSeconds({ retryAfterSeconds: 0 })).toBeNull();
    expect(getAdminRetryAfterSeconds({ retryAfterSeconds: 3_601 })).toBeNull();
    expect(getAdminRetryAfterSeconds({ retryAfterSeconds: "12" })).toBeNull();
  });

  it("uses localized fallbacks for generic backend problem details", () => {
    expect(
      getAdminErrorMessage(
        {
          code: "auth.invalid_credentials",
          detail: "Sign-in credentials are invalid.",
          message: "Sign-in credentials are invalid.",
        },
        "Localized login error"
      )
    ).toBe("Localized login error");
    expect(
      getAdminErrorMessage(
        {
          code: "templates.not_found",
          detail: "Template was not found.",
          message: "Template was not found.",
        },
        "Localized template error"
      )
    ).toBe("Localized template error");
    expect(
      getAdminErrorMessage(
        {
          code: "templates.update_conflict",
          detail: "Template was changed while saving. Reload and try again.",
        },
        "Localized save error"
      )
    ).toBe("Localized save error");
  });

  it("does not expose raw JSON or technical messages", () => {
    expect(getAdminErrorMessage({ message: '{"token":"secret"}' }, "Fallback")).toBe("Fallback");
    expect(
      getAdminErrorMessage({ message: "API request failed with status 500" }, "Fallback")
    ).toBe("Fallback");
    expect(
      getAdminErrorMessage(
        { status: 422, validationErrors: ['{"token":"secret"}', "validation.required"] },
        "Fallback"
      )
    ).toBe("Fallback");
    expect(
      getAdminErrorMessage({ status: 401, message: "Session expired. Sign in again." }, "Localized")
    ).toBe("Localized");
  });

  it("filters technical validation errors while keeping safe backend validation copy", () => {
    expect(
      getAdminErrorMessage(
        {
          validationErrors: [
            '{"token":"secret"}',
            "Email is already used.",
            "validation.required",
            "receipt=ios-secret",
          ],
        },
        "Fallback"
      )
    ).toBe("Email is already used. receipt=[redacted]");
  });

  it("keeps concise user-facing backend messages", () => {
    expect(getAdminErrorMessage({ message: "Email is already used." }, "Fallback")).toBe(
      "Email is already used."
    );
  });

  it("sanitizes sensitive values inside backend messages and validation errors", () => {
    const message = getAdminErrorMessage(
      {
        message:
          "Upload failed for alice@example.com at https://cdn.example.com/file.png?X-Amz-Signature=secret token=raw-secret",
      },
      "Fallback"
    );
    const validationMessage = getAdminErrorMessage(
      {
        validationErrors: [
          "receipt=ios-secret card_number=4242424242424242 https://cdn.example.com/a?sig=secret",
        ],
      },
      "Fallback"
    );

    expect(message).not.toContain("alice@example.com");
    expect(message).not.toContain("X-Amz-Signature=secret");
    expect(message).not.toContain("raw-secret");
    expect(message).toContain("al***@e***.com");
    expect(message).toContain("token=[redacted]");
    expect(validationMessage).not.toContain("ios-secret");
    expect(validationMessage).not.toContain("4242424242424242");
    expect(validationMessage).not.toContain("sig=secret");
    expect(validationMessage).toContain("receipt=[redacted]");
    expect(validationMessage).toContain("card_number=[redacted]");
  });
});
