using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<OffsetPagedResponse<PurchaseHistoryItemResponse>>> GetPurchaseHistoryAsync(
        Guid userId,
        int skip,
        int take,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 20, 100);

        var items = await dbContext.PurchaseOrders
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .Join(
                dbContext.CurrencyPacks.AsNoTracking(),
                order => order.PackId,
                pack => pack.Id,
                (order, pack) => new { order, pack })
            .OrderByDescending(x => x.order.CreatedAtUtc)
            .ThenByDescending(x => x.order.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .Select(x => new PurchaseHistoryItemResponse(
                x.order.Id,
                x.order.UserId,
                x.order.PackId,
                x.pack.Code,
                x.pack.DisplayName,
                x.order.PaymentProvider,
                x.order.Status,
                x.order.PriceAmount,
                x.order.CurrencyCode,
                x.order.SparkToGrant,
                x.order.PaymentProvider == "stripe" ? x.order.ExternalPaymentId : null,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc,
                false,
                "TokenPack",
                x.order.SparkToGrant,
                x.order.Status == PurchaseOrderStatus.Refunded ? "refunded" : "none"))
            .ToListAsync(cancellationToken);

        return Result.Success(ToPaged(items, normalizedSkip, normalizedTake));
    }

    public async Task<Result<PurchaseOrderResponse>> ConfirmPackPurchaseAsync(ConfirmPackPurchaseCommand command, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure)
        {
            return Result.Failure<PurchaseOrderResponse>(confirmResult.Error);
        }

        return Result.Success(ToPurchaseOrderResponse(confirmResult.Value));
    }

    public async Task<Result<PurchaseOrderResponse>> VerifyStripeCheckoutSessionAsync(VerifyStripeCheckoutSessionCommand command, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        var normalizedRequestedReference = command.StripeReferenceId?.Trim();
        var stripeReferenceId = !string.IsNullOrWhiteSpace(normalizedRequestedReference)
            ? normalizedRequestedReference
            : order.ExternalPaymentId;

        if (!string.IsNullOrWhiteSpace(normalizedRequestedReference)
            && !string.IsNullOrWhiteSpace(order.ExternalPaymentId)
            && !string.Equals(order.ExternalPaymentId, normalizedRequestedReference, StringComparison.Ordinal))
        {
            logger?.LogWarning(
                "Stripe reference mismatch for order verification. OrderId={OrderId} UserId={UserId} RequestedReferenceType={RequestedReferenceType} StoredReferenceType={StoredReferenceType} CorrelationId={CorrelationId}",
                order.Id,
                order.UserId,
                ClassifyStripeReference(normalizedRequestedReference),
                ClassifyStripeReference(order.ExternalPaymentId),
                CurrentCorrelationId);

            stripeReferenceId = order.ExternalPaymentId;
        }

        if (string.IsNullOrWhiteSpace(stripeReferenceId))
        {
            LogPaymentFailed(order, EconomyErrors.PaymentGatewayFailed, "stripe.verify.missing_reference");
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return Result.Success(ToPurchaseOrderResponse(order));
        }

        var apiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            LogPaymentFailed(order, EconomyErrors.PaymentGatewayFailed, "stripe.verify.configuration");
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        StripeConfiguration.ApiKey = apiKey;

        try
        {
            if (stripeReferenceId.StartsWith("cs_", StringComparison.OrdinalIgnoreCase))
            {
                var sessionService = new Stripe.Checkout.SessionService();
                var session = await sessionService.GetAsync(stripeReferenceId, cancellationToken: cancellationToken);

                if (!string.Equals(session.PaymentStatus, "paid", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(session.Status, "complete", StringComparison.OrdinalIgnoreCase))
                {
                    return Result.Success(ToPurchaseOrderResponse(order));
                }
            }
            else if (stripeReferenceId.StartsWith("pi_", StringComparison.OrdinalIgnoreCase))
            {
                var paymentIntentService = new PaymentIntentService();
                var paymentIntent = await paymentIntentService.GetAsync(stripeReferenceId, cancellationToken: cancellationToken);

                if (!string.Equals(paymentIntent.Status, "succeeded", StringComparison.OrdinalIgnoreCase))
                {
                    return Result.Success(ToPurchaseOrderResponse(order));
                }
            }
            else
            {
                LogPaymentFailed(order, EconomyErrors.PaymentGatewayFailed, "stripe.verify.unsupported_reference");
                return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Stripe payment verification failed. OrderId={OrderId} UserId={UserId} ReferenceType={ReferenceType} CorrelationId={CorrelationId}",
                order.Id,
                order.UserId,
                ClassifyStripeReference(stripeReferenceId),
                CurrentCorrelationId);
            LogPaymentFailed(order, EconomyErrors.PaymentGatewayFailed, "stripe.verify.provider");
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.IsNullOrWhiteSpace(order.ExternalPaymentId))
        {
            order.ExternalPaymentId = stripeReferenceId;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        // For mobile PaymentSheet flows we can observe Stripe success before webhook delivery.
        // Settle immediately and keep webhook handling idempotent.
        var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
        if (confirmResult.IsFailure
            && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(confirmResult.Error);
        }

        if (confirmResult.IsSuccess)
        {
            return Result.Success(ToPurchaseOrderResponse(confirmResult.Value));
        }

        var refreshedOrder = await dbContext.PurchaseOrders
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.Id && x.UserId == order.UserId, cancellationToken);

        if (refreshedOrder is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        return Result.Success(ToPurchaseOrderResponse(refreshedOrder));
    }

    public async Task<Result<PurchaseOrderResponse>> VerifyPackStorePurchaseAsync(
        VerifyPackStorePurchaseCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "google_play", StringComparison.Ordinal)
            && !string.Equals(provider, "app_store", StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == command.OrderId && x.UserId == command.UserId, cancellationToken);
        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        if (!string.Equals(order.PaymentProvider, provider, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return Result.Success(ToPurchaseOrderResponse(order));
        }

        var pack = await dbContext.CurrencyPacks
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == order.PackId, cancellationToken);
        if (pack is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        var expectedProductId = ResolvePackStoreProductId(pack, provider);
        if (!string.Equals(expectedProductId, command.ProductId.Trim(), StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var verification = await storeSubscriptionVerifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                command.UserId,
                provider,
                command.ProductId,
                command.ServerVerificationData,
                command.LocalVerificationData,
                command.PurchaseId,
                command.TransactionDate),
            cancellationToken);

        if (verification.IsFailure)
        {
            return Result.Failure<PurchaseOrderResponse>(verification.Error);
        }

        if (!verification.Value.IsPurchased)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var externalPaymentId = ResolveStoreExternalPaymentId(provider, command.ServerVerificationData, verification.Value.ExternalTransactionId, command.PurchaseId);
        var confirmResult = await ConfirmStorePurchaseInternalAsync(order, externalPaymentId, cancellationToken);
        if (confirmResult.IsFailure)
        {
            return Result.Failure<PurchaseOrderResponse>(confirmResult.Error);
        }

        logger?.LogInformation(
            "Store token pack validation succeeded. Provider={Provider} UserId={UserId} ProductId={ProductId} OrderId={OrderId} TokenAmount={TokenAmount} Environment={Environment} CorrelationId={CorrelationId}",
            provider,
            command.UserId,
            command.ProductId,
            confirmResult.Value.Id,
            confirmResult.Value.SparkToGrant,
            ResolveStoreEnvironment(provider),
            CurrentCorrelationId);

        return Result.Success(ToPurchaseOrderResponse(confirmResult.Value));
    }

    public async Task<Result<StoreBillingValidationResponse>> ValidateGooglePlayBillingAsync(
        ValidateGooglePlayBillingCommand command,
        CancellationToken cancellationToken)
    {
        var configuredPackageName = options.Value.GooglePlayPackageName?.Trim();
        if (!string.IsNullOrWhiteSpace(configuredPackageName)
            && !string.Equals(configuredPackageName, command.PackageName.Trim(), StringComparison.Ordinal))
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        return await ValidateStoreBillingAsync(
            command.UserId,
            "google_play",
            command.ProductId,
            command.PurchaseToken,
            null,
            command.PurchaseToken,
            null,
            cancellationToken);
    }

    public async Task<Result<StoreBillingValidationResponse>> ValidateAppleAppStoreBillingAsync(
        ValidateAppleAppStoreBillingCommand command,
        CancellationToken cancellationToken)
    {
        if (storeWebhookSecurityValidator is null)
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StoreVerificationUnavailable);
        }

        var signatureValidation = storeWebhookSecurityValidator.ValidateAppStoreSignedPayload(command.SignedTransactionInfo);
        if (signatureValidation.IsFailure)
        {
            return Result.Failure<StoreBillingValidationResponse>(signatureValidation.Error);
        }

        var transactionInfo = EconomyWebhookParser.TryReadAppStoreTransactionInfo(command.SignedTransactionInfo);
        if (transactionInfo is null
            || string.IsNullOrWhiteSpace(transactionInfo.ProductId)
            || string.IsNullOrWhiteSpace(transactionInfo.TransactionId)
            || !string.Equals(transactionInfo.BundleId, options.Value.AppStoreBundleId, StringComparison.Ordinal)
            || transactionInfo.RevokedAtUtc.HasValue)
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var expectedEnvironment = options.Value.AppStoreEnvironment?.Trim();
        if (!string.IsNullOrWhiteSpace(expectedEnvironment)
            && !string.IsNullOrWhiteSpace(transactionInfo.Environment)
            && !string.Equals(transactionInfo.Environment, expectedEnvironment, StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        return await ValidateStoreBillingAsync(
            command.UserId,
            "app_store",
            transactionInfo.ProductId,
            command.SignedTransactionInfo,
            null,
            transactionInfo.TransactionId,
            null,
            cancellationToken);
    }

    private async Task<Result<StoreBillingValidationResponse>> ValidateStoreBillingAsync(
        Guid userId,
        string provider,
        string productId,
        string serverVerificationData,
        string? localVerificationData,
        string? purchaseId,
        string? transactionDate,
        CancellationToken cancellationToken)
    {
        var normalizedProductId = productId.Trim();
        var plan = await ResolveStorePlanByProductIdAsync(provider, normalizedProductId, cancellationToken);
        if (plan is not null)
        {
            var subscriptionVerification = await VerifyPremiumStorePurchaseAsync(
                new VerifyPremiumStorePurchaseCommand(
                    userId,
                    plan.PlanCode,
                    provider,
                    normalizedProductId,
                    serverVerificationData,
                    localVerificationData,
                    purchaseId,
                    transactionDate),
                cancellationToken);

            if (subscriptionVerification.IsFailure)
            {
                return Result.Failure<StoreBillingValidationResponse>(subscriptionVerification.Error);
            }

            return Result.Success(new StoreBillingValidationResponse(
                provider,
                "Subscription",
                normalizedProductId,
                subscriptionVerification.Value.Status,
                false,
                0,
                subscriptionVerification.Value.IsActive,
                subscriptionVerification.Value.ExpiresAtUtc));
        }

        var activePacks = await dbContext.CurrencyPacks
            .AsNoTracking()
            .Where(x => x.IsActive)
            .ToListAsync(cancellationToken);
        var pack = activePacks.FirstOrDefault(x => ResolvePackStoreProductId(x, provider) == normalizedProductId);
        if (pack is null)
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var verification = await storeSubscriptionVerifier.VerifyProductPurchaseAsync(
            new StoreProductVerificationRequest(
                userId,
                provider,
                normalizedProductId,
                serverVerificationData,
                localVerificationData,
                purchaseId,
                transactionDate),
            cancellationToken);

        if (verification.IsFailure)
        {
            return Result.Failure<StoreBillingValidationResponse>(verification.Error);
        }

        if (!verification.Value.IsPurchased)
        {
            return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
        }

        var externalPaymentId = ResolveStoreExternalPaymentId(provider, serverVerificationData, verification.Value.ExternalTransactionId, purchaseId);
        var existing = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.PaymentProvider == provider && x.ExternalPaymentId == externalPaymentId, cancellationToken);
        if (existing is not null)
        {
            if (existing.UserId != userId)
            {
                return Result.Failure<StoreBillingValidationResponse>(EconomyErrors.StorePurchaseInvalid);
            }

            return Result.Success(new StoreBillingValidationResponse(
                provider,
                "TokenPack",
                normalizedProductId,
                existing.Status,
                false,
                existing.SparkToGrant,
                false,
                null));
        }

        var now = DateTime.UtcNow;
        var order = new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PackId = pack.Id,
            PaymentProvider = provider,
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = pack.PriceAmount,
            CurrencyCode = pack.CurrencyCode,
            SparkToGrant = pack.GrantedSpark + pack.BonusSpark,
            CheckoutUrl = string.Empty,
            CreatedAtUtc = now
        };

        dbContext.PurchaseOrders.Add(order);
        var confirmResult = await ConfirmStorePurchaseInternalAsync(order, externalPaymentId, cancellationToken);
        if (confirmResult.IsFailure)
        {
            return Result.Failure<StoreBillingValidationResponse>(confirmResult.Error);
        }

        logger?.LogInformation(
            "Store token pack validation succeeded. Provider={Provider} UserId={UserId} ProductId={ProductId} OrderId={OrderId} TokenAmount={TokenAmount} Environment={Environment} CorrelationId={CorrelationId}",
            provider,
            userId,
            normalizedProductId,
            confirmResult.Value.Id,
            confirmResult.Value.SparkToGrant,
            ResolveStoreEnvironment(provider),
            CurrentCorrelationId);

        return Result.Success(new StoreBillingValidationResponse(
            provider,
            "TokenPack",
            normalizedProductId,
            confirmResult.Value.Status,
            true,
            confirmResult.Value.SparkToGrant,
            false,
            null));
    }

    private async Task<ResolvedPremiumPlan?> ResolveStorePlanByProductIdAsync(
        string provider,
        string productId,
        CancellationToken cancellationToken)
    {
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.IsActive
                    && (provider == "google_play"
                        ? x.GoogleProductId == productId
                        : x.AppleProductId == productId),
                cancellationToken);

        if (configuredPlan is not null)
        {
            return await ResolveConfiguredPremiumPlanAsync(configuredPlan.Id, cancellationToken);
        }

        return PremiumPlanCatalog.All
            .FirstOrDefault(x => string.Equals(
                provider == "google_play" ? x.GooglePlayProductId : x.AppStoreProductId,
                productId,
                StringComparison.Ordinal))
            is { } catalogPlan
                ? await ResolveConfiguredPremiumPlanAsync(catalogPlan.PlanCode, cancellationToken)
                : null;
    }

    private static string ResolveStoreExternalPaymentId(
        string provider,
        string serverVerificationData,
        string? externalTransactionId,
        string? purchaseId)
    {
        return string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? serverVerificationData.Trim()
            : (externalTransactionId ?? purchaseId ?? serverVerificationData).Trim();
    }

    private string ResolveStoreEnvironment(string provider)
    {
        return provider == "google_play"
            ? options.Value.GooglePlayEnvironment
            : options.Value.AppStoreEnvironment;
    }

    private string ResolvePackStoreProductId(CurrencyPack pack, string provider)
    {
        var code = pack.Code.Trim();
        if (string.IsNullOrWhiteSpace(code))
        {
            return string.Empty;
        }

        // Keep backward compatibility: when code already looks like an IAP SKU, use it as-is.
        if (code.Contains('.', StringComparison.Ordinal))
        {
            return code.ToLowerInvariant();
        }

        var bundleId = options.Value.AppStoreBundleId?.Trim();
        if (string.IsNullOrWhiteSpace(bundleId))
        {
            bundleId = options.Value.GooglePlayPackageName?.Trim();
        }

        if (string.IsNullOrWhiteSpace(bundleId))
        {
            bundleId = "com.petmagic.app";
        }

        var normalizedProvider = provider.Trim().ToLowerInvariant() switch
        {
            "google_play" => "google",
            "app_store" => "apple",
            _ => "store"
        };

        return $"{bundleId}.tokens.{normalizedProvider}.{code.ToLowerInvariant()}";
    }

    private static string ClassifyStripeReference(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "missing";
        }

        if (value.StartsWith("pi_", StringComparison.OrdinalIgnoreCase))
        {
            return "payment_intent";
        }

        if (value.StartsWith("cs_", StringComparison.OrdinalIgnoreCase))
        {
            return "checkout_session";
        }

        return "unknown";
    }
}
