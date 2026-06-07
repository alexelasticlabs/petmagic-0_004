import { describe, expect, it } from "vitest";

import { getAdminErrorMessage } from "@/lib/admin-error-message";

describe("admin-error-message", () => {
  it("uses validation errors first", () => {
    expect(
      getAdminErrorMessage({ validationErrors: [" Name is required. ", "Too long"] }, "Fallback")
    ).toBe("Name is required. Too long");
  });

  it("maps common HTTP statuses to friendly messages", () => {
    expect(getAdminErrorMessage({ status: 403, message: "auth.forbidden" }, "Fallback")).toBe(
      "You do not have permission to perform this action."
    );
  });

  it("does not expose raw JSON or technical messages", () => {
    expect(getAdminErrorMessage({ message: '{"token":"secret"}' }, "Fallback")).toBe("Fallback");
    expect(getAdminErrorMessage({ message: "API request failed with status 500" }, "Fallback")).toBe(
      "Fallback"
    );
    expect(
      getAdminErrorMessage(
        { status: 422, validationErrors: ['{"token":"secret"}', "validation.required"] },
        "Fallback"
      )
    ).toBe("Request validation failed.");
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
