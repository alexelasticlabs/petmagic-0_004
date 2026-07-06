using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class SafeLogValuesTests
{
    [Fact]
    public void SanitizeText_ShouldRedactProviderHeadersAndStoreSecrets()
    {
        var sanitized = SafeLogValues.SanitizeText(
            "X-Api-Key: raw-api-key "
            + "X-Fal-Key=fal-secret "
            + "Stripe-Signature: stripe-secret "
            + "X-Goog-Signature=google-secret "
            + "purchaseToken=store-token "
            + "verificationData=raw-verification-data "
            + "signedTransactionInfo=jws-secret "
            + "customerId=cus_123 "
            + "externalPaymentId=cs_test_123 "
            + "externalSubscriptionId=sub_external_123 "
            + "paymentIntentId=pi_123 "
            + "setupIntentId=seti_123 "
            + "paymentIntentClientSecret=pi_secret_123");

        Assert.Contains("X-Api-Key: ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("X-Fal-Key= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("Stripe-Signature: ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("X-Goog-Signature= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("purchaseToken= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("verificationData= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("signedTransactionInfo= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("customerId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("externalPaymentId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("externalSubscriptionId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("paymentIntentId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("setupIntentId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("paymentIntentClientSecret= ***", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-api-key", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("fal-secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("stripe-secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("google-secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("store-token", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-verification-data", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("jws-secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("cus_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("cs_test_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("sub_external_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("pi_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("seti_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("pi_secret_123", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldRedactJsonSecretPairs()
    {
        var sanitized = SafeLogValues.SanitizeText(
            """
            {"apiKey":"raw-api-key","accessToken":"raw-access-token","verificationData":"raw-verification-data","signedTransactionInfo":"raw-jws","customerId":"cus_123","externalPaymentId":"cs_test_123","externalSubscriptionId":"sub_external_123","paymentIntentId":"pi_123","setupIntentId":"seti_123","status":"failed"}
            """);

        Assert.Contains("\"apiKey\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"accessToken\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"verificationData\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"signedTransactionInfo\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"customerId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"externalPaymentId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"externalSubscriptionId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"paymentIntentId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"setupIntentId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"status\":\"failed\"", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-api-key", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-access-token", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-verification-data", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("raw-jws", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("cus_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("cs_test_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("sub_external_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("pi_123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("seti_123", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldRedactDomainIdentifiersWithoutHidingTraceMetadata()
    {
        var sanitized = SafeLogValues.SanitizeText(
            "userId=user-123 "
            + "sourceGenerationId=generation-source-123 "
            + "parent_generation_result_id: generation-parent-123 "
            + "visibleTemplateId=template-visible-123 "
            + "pendingPurchaseId=purchase-pending-123 "
            + "activeSubscriptionId: subscription-active-123 "
            + "highlightedPurchaseOrderId=order-highlighted-123 "
            + "requestId=request-123 "
            + "correlationId=correlation-123 "
            + "traceId=trace-123");

        Assert.Contains("userId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("sourceGenerationId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("parent_generation_result_id: ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("visibleTemplateId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("pendingPurchaseId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("activeSubscriptionId: ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("highlightedPurchaseOrderId= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("requestId=request-123", sanitized, StringComparison.Ordinal);
        Assert.Contains("correlationId=correlation-123", sanitized, StringComparison.Ordinal);
        Assert.Contains("traceId=trace-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("user-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("generation-source-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("generation-parent-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("template-visible-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("purchase-pending-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("subscription-active-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("order-highlighted-123", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldRedactPluralDomainIdentifiersFilenamesAndKeyedMediaUrls()
    {
        var sanitized = SafeLogValues.SanitizeText(
            "templateIds=template-123,template-456 "
            + "generationIds: generation-123 "
            + "purchaseIds=purchase-123 "
            + "requestIds=request-123 "
            + "fileName=alice-vet-bill.pdf "
            + "fileNames=\"passport-scan.png\" "
            + "mediaUrls=https://cdn.petmagic.app/private/user-42/result.png "
            + "status_url=https://queue.fal.test/fal-ai/status/fal-request-1 "
            + "originalImageUrl=\"https://cdn.petmagic.app/private/user-42/source.jpg\"");

        Assert.Contains("templateIds= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("generationIds: ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("purchaseIds= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("requestIds=request-123", sanitized, StringComparison.Ordinal);
        Assert.Contains("fileName= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("fileNames= ***", sanitized, StringComparison.Ordinal);
        Assert.Contains("mediaUrls= https://cdn.petmagic.app/***", sanitized, StringComparison.Ordinal);
        Assert.Contains("status_url= https://queue.fal.test/***", sanitized, StringComparison.Ordinal);
        Assert.Contains("originalImageUrl= \"https://cdn.petmagic.app/***\"", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("template-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("generation-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("purchase-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("alice-vet-bill", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("passport-scan", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/private/user-42/result.png", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/fal-ai/status/fal-request-1", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/private/user-42/source.jpg", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldRedactJsonDomainIdentifiers()
    {
        var sanitized = SafeLogValues.SanitizeText(
            """
            {"sourceGenerationId":"generation-source-123","activeSubscriptionId":"subscription-active-123","requestId":"request-123","status":"failed"}
            """);

        Assert.Contains("\"sourceGenerationId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"activeSubscriptionId\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"requestId\":\"request-123\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"status\":\"failed\"", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("generation-source-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("subscription-active-123", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldRedactJsonPluralDomainIdentifiersFilenamesAndKeyedMediaUrls()
    {
        var sanitized = SafeLogValues.SanitizeText(
            """
            {"templateIds":"template-123","generationIds":"generation-123","requestIds":"request-123","fileNames":"passport-scan.png","mediaUrls":"https://cdn.petmagic.app/private/user-42/result.png","response_url":"https://queue.fal.test/fal-ai/response/fal-request-1","originalImageUrl":"https://cdn.petmagic.app/private/user-42/source.jpg","status":"failed"}
            """);

        Assert.Contains("\"templateIds\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"generationIds\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"requestIds\":\"request-123\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"fileNames\":\"***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"mediaUrls\":\"https://cdn.petmagic.app/***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"response_url\":\"https://queue.fal.test/***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"originalImageUrl\":\"https://cdn.petmagic.app/***\"", sanitized, StringComparison.Ordinal);
        Assert.Contains("\"status\":\"failed\"", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("template-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("generation-123", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("passport-scan", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/private/user-42/result.png", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/fal-ai/response/fal-request-1", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/private/user-42/source.jpg", sanitized, StringComparison.Ordinal);
    }

    [Fact]
    public void SanitizeText_ShouldStripUrlPathQueryAndBoundLength()
    {
        var sanitized = SafeLogValues.SanitizeText(
            "media=https://cdn.petmagic.app/generated/user-42/result.png?signature=secret "
            + "callback=https://api.petmagic.app/auth/callback?token=secret#fragment "
            + new string('x', 64),
            maxLength: 64);

        Assert.Equal(64, sanitized.Length);
        Assert.Contains("https://cdn.petmagic.app/***", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/auth/callback", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("/generated/user-42/result.png", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("token=secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("signature=secret", sanitized, StringComparison.Ordinal);
        Assert.DoesNotContain("fragment", sanitized, StringComparison.Ordinal);
    }
}
