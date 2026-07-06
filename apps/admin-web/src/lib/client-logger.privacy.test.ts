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

  it("redacts transport payload and header context by key", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      payload: { prompt: "Draw Alice's private pet photo", petName: "Rover" },
      rawBody: '{"message":"plain user text without obvious secrets"}',
      requestBody: '{"email":"alice@example.com","note":"billing question"}',
      responseBody: '{"detail":"upstream copied user prompt"}',
      providerPayload: "provider returned customer message body",
      serverVerificationData: "google-play-receipt-token",
      localVerificationData: '{"signedData":"raw-local-jws"}',
      verificationData: "raw-verification-data",
      signedTransactionInfo: "eyJhbGciOiJIUzI1NiJ9.payload.signature",
      signedPayload: "app-store-notification-jws",
      purchaseToken: "google-play-purchase-token",
      customerId: "cus_raw_customer",
      externalPaymentId: "cs_test_raw_checkout",
      externalSubscriptionId: "sub_raw_external",
      paymentIntentId: "pi_raw_intent",
      setupIntentId: "seti_raw_intent",
      checkoutSessionId: "cs_test_raw_session",
      stripeSessionId: "cs_test_raw_stripe_session",
      headers: { "x-request-id": "request-123", authorization: "Bearer raw-token" },
      payloadSize: 128,
      status: 502,
    });

    expect(sanitized).toMatchObject({
      payload: "[redacted-payload]",
      rawBody: "[redacted-payload]",
      requestBody: "[redacted-payload]",
      responseBody: "[redacted-payload]",
      providerPayload: "[redacted-payload]",
      serverVerificationData: "[redacted-payload]",
      localVerificationData: "[redacted-payload]",
      verificationData: "[redacted-payload]",
      signedTransactionInfo: "[redacted-payload]",
      signedPayload: "[redacted-payload]",
      purchaseToken: "[redacted-payload]",
      customerId: "***",
      externalPaymentId: "***",
      externalSubscriptionId: "***",
      paymentIntentId: "***",
      setupIntentId: "***",
      checkoutSessionId: "***",
      stripeSessionId: "***",
      headers: "[redacted-payload]",
      payloadSize: 128,
      status: 502,
    });

    const serialized = JSON.stringify(sanitized);
    expect(serialized).not.toContain("Alice");
    expect(serialized).not.toContain("Rover");
    expect(serialized).not.toContain("plain user text");
    expect(serialized).not.toContain("alice@example.com");
    expect(serialized).not.toContain("raw-token");
    expect(serialized).not.toContain("google-play-receipt-token");
    expect(serialized).not.toContain("raw-local-jws");
    expect(serialized).not.toContain("raw-verification-data");
    expect(serialized).not.toContain("eyJhbGciOiJIUzI1NiJ9");
    expect(serialized).not.toContain("app-store-notification-jws");
    expect(serialized).not.toContain("google-play-purchase-token");
    expect(serialized).not.toContain("cus_raw_customer");
    expect(serialized).not.toContain("cs_test_raw_checkout");
    expect(serialized).not.toContain("sub_raw_external");
    expect(serialized).not.toContain("pi_raw_intent");
    expect(serialized).not.toContain("seti_raw_intent");
    expect(serialized).not.toContain("cs_test_raw_session");
    expect(serialized).not.toContain("cs_test_raw_stripe_session");
  });

  it("redacts stable domain identifiers without hiding trace metadata", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      userId: "user-123",
      profileUserId: "profile-user-123",
      accountScope: "account-scope-123",
      userScope: "user-scope-123",
      scope: "scope-user-123",
      templateId: "template-123",
      assignmentId: "assignment-123",
      generationId: "generation-123",
      sourceGenerationId: "source-generation-123",
      relatedGenerationId: "related-generation-123",
      parentGenerationResultId: "parent-generation-result-123",
      conversationId: "conversation-123",
      messageId: "message-123",
      attachmentId: "attachment-123",
      purchaseId: "purchase-123",
      pendingPurchaseId: "pending-purchase-123",
      subscriptionId: "subscription-123",
      activeSubscriptionId: "active-subscription-123",
      feedbackId: "feedback-123",
      orderId: "order-123",
      highlightedPurchaseOrderId: "highlighted-purchase-order-123",
      visibleTemplateId: "visible-template-123",
      requestId: "request-123",
      correlationId: "correlation-123",
      traceId: "trace-123",
    });

    expect(sanitized).toMatchObject({
      userId: "***",
      profileUserId: "***",
      accountScope: "***",
      userScope: "***",
      scope: "***",
      templateId: "***",
      assignmentId: "***",
      generationId: "***",
      sourceGenerationId: "***",
      relatedGenerationId: "***",
      parentGenerationResultId: "***",
      conversationId: "***",
      messageId: "***",
      attachmentId: "***",
      purchaseId: "***",
      pendingPurchaseId: "***",
      subscriptionId: "***",
      activeSubscriptionId: "***",
      feedbackId: "***",
      orderId: "***",
      highlightedPurchaseOrderId: "***",
      visibleTemplateId: "***",
      requestId: "request-123",
      correlationId: "correlation-123",
      traceId: "trace-123",
    });
    expect(JSON.stringify(sanitized)).not.toContain("user-123");
    expect(JSON.stringify(sanitized)).not.toContain("scope-user-123");
    expect(JSON.stringify(sanitized)).not.toContain("generation-123");
    expect(JSON.stringify(sanitized)).not.toContain("source-generation-123");
    expect(JSON.stringify(sanitized)).not.toContain("parent-generation-result-123");
    expect(JSON.stringify(sanitized)).not.toContain("subscription-123");
    expect(JSON.stringify(sanitized)).not.toContain("active-subscription-123");
    expect(JSON.stringify(sanitized)).not.toContain("purchase-123");
    expect(JSON.stringify(sanitized)).not.toContain("highlighted-purchase-order-123");
    expect(JSON.stringify(sanitized)).not.toContain("visible-template-123");
  });

  it("redacts plural domain identifiers and user filenames in structured log context", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      templateIds: ["template-123", "template-456"],
      generationIds: ["generation-123"],
      conversationIds: ["conversation-123"],
      purchaseIds: ["purchase-123"],
      requestIds: ["request-123"],
      fileName: "alice-vet-bill.pdf",
      fileNames: ["passport-scan.png", "home-address-dog.jpeg"],
    });

    expect(sanitized).toMatchObject({
      templateIds: ["***", "***"],
      generationIds: ["***"],
      conversationIds: ["***"],
      purchaseIds: ["***"],
      requestIds: ["request-123"],
      fileName: "***",
      fileNames: ["***", "***"],
    });
    const serialized = JSON.stringify(sanitized);
    expect(serialized).not.toContain("template-123");
    expect(serialized).not.toContain("generation-123");
    expect(serialized).not.toContain("conversation-123");
    expect(serialized).not.toContain("purchase-123");
    expect(serialized).not.toContain("alice-vet-bill");
    expect(serialized).not.toContain("passport-scan");
    expect(serialized).not.toContain("home-address-dog");
  });

  it("redacts cookie, JWT, credential, and signature assignments in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "Request failed with cookie=raw-cookie jwt=eyJhbGciOi.raw.payload credential=raw-credential signature=raw-signature"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("raw-cookie");
    expect(sanitized).not.toContain("eyJhbGciOi.raw.payload");
    expect(sanitized).not.toContain("raw-credential");
    expect(sanitized).not.toContain("raw-signature");
  });

  it("redacts provider api key and signature headers in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "Request failed with X-Api-Key: raw-api-key x_fal_key=fal-secret Stripe-Signature: stripe-secret X-Goog-Signature=google-secret"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("raw-api-key");
    expect(sanitized).not.toContain("fal-secret");
    expect(sanitized).not.toContain("stripe-secret");
    expect(sanitized).not.toContain("google-secret");
  });

  it("redacts store verification payload assignments in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "serverVerificationData=google-play-receipt-token localVerificationData=raw-local-jws " +
        "signedTransactionInfo=eyJhbGciOiJIUzI1NiJ9.payload.signature " +
        "signedPayload=app-store-notification-jws purchaseToken=google-play-purchase-token"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("google-play-receipt-token");
    expect(sanitized).not.toContain("raw-local-jws");
    expect(sanitized).not.toContain("eyJhbGciOiJIUzI1NiJ9");
    expect(sanitized).not.toContain("app-store-notification-jws");
    expect(sanitized).not.toContain("google-play-purchase-token");
  });

  it("redacts payment provider identifiers in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "customerId=cus_raw_customer externalPaymentId=cs_test_raw_checkout " +
        "externalSubscriptionId=sub_raw_external paymentIntentId=pi_raw_intent " +
        "setupIntentId=seti_raw_intent checkoutSessionId=cs_test_raw_session " +
        "stripeSessionId=cs_test_raw_stripe_session"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("cus_raw_customer");
    expect(sanitized).not.toContain("cs_test_raw_checkout");
    expect(sanitized).not.toContain("sub_raw_external");
    expect(sanitized).not.toContain("pi_raw_intent");
    expect(sanitized).not.toContain("seti_raw_intent");
    expect(sanitized).not.toContain("cs_test_raw_session");
    expect(sanitized).not.toContain("cs_test_raw_stripe_session");
  });

  it("redacts stable domain identifiers in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "generationId=generation-123 sourceGenerationId=source-generation-123 parent_generation_result_id=parent-generation-result-123 template_id=template-123 visibleTemplateId=visible-template-123 activeSubscriptionId=subscription-123 pendingPurchaseId=purchase-123 highlightedPurchaseOrderId=order-123 userScope=user-scope-123 scope=scope-user-123"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("generation-123");
    expect(sanitized).not.toContain("source-generation-123");
    expect(sanitized).not.toContain("parent-generation-result-123");
    expect(sanitized).not.toContain("template-123");
    expect(sanitized).not.toContain("visible-template-123");
    expect(sanitized).not.toContain("subscription-123");
    expect(sanitized).not.toContain("purchase-123");
    expect(sanitized).not.toContain("order-123");
    expect(sanitized).not.toContain("user-scope-123");
    expect(sanitized).not.toContain("scope-user-123");
  });

  it("redacts plural domain identifiers and filenames in free-form text", () => {
    const sanitized = sanitizeClientLogTextForTesting(
      "message",
      "templateIds=template-123,template-456 generationIds=generation-123 fileName=alice-vet-bill.pdf fileNames=passport-scan.png,home-address-dog.jpeg requestIds=request-123"
    );

    expect(sanitized).toBe("[redacted]");
    expect(sanitized).not.toContain("template-123");
    expect(sanitized).not.toContain("template-456");
    expect(sanitized).not.toContain("generation-123");
    expect(sanitized).not.toContain("alice-vet-bill");
    expect(sanitized).not.toContain("passport-scan");
    expect(sanitized).not.toContain("home-address-dog");
  });

  it("bounds deeply nested and wide structured log context", () => {
    const sanitized = sanitizeClientLogContextForTesting({
      wide: Object.fromEntries(
        Array.from({ length: 40 }, (_, index) => [`field${index}`, `value-${index}`])
      ),
      array: Array.from({ length: 25 }, (_, index) => `item-${index}`),
      nested: {
        level1: {
          level2: {
            level3: {
              level4: {
                secret: "raw-secret",
              },
            },
          },
        },
      },
    });

    expect(sanitized?.wide).toMatchObject({ __truncated_keys: 8 });
    expect(Object.keys(sanitized?.wide as Record<string, unknown>)).toHaveLength(33);
    expect(sanitized?.array).toHaveLength(21);
    expect(sanitized?.array).toContain("[truncated:5]");
    expect(JSON.stringify(sanitized)).not.toContain("raw-secret");
    expect(JSON.stringify(sanitized)).toContain("[truncated-depth]");
  });
});
