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
                x.order.ExternalPaymentId,
                x.order.CreatedAtUtc,
                x.order.ConfirmedAtUtc))
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
                "Stripe reference mismatch for order verification. OrderId={OrderId} UserId={UserId} RequestedReference={RequestedReference} StoredReference={StoredReference}",
                order.Id,
                order.UserId,
                normalizedRequestedReference,
                order.ExternalPaymentId);

            stripeReferenceId = order.ExternalPaymentId;
        }

        if (string.IsNullOrWhiteSpace(stripeReferenceId))
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal))
        {
            return Result.Success(ToPurchaseOrderResponse(order));
        }

        var apiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
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
                return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }
        catch (Exception ex)
        {
            logger?.LogWarning(ex, "Stripe payment verification failed for reference {StripeReferenceId}", stripeReferenceId);
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

        order.ExternalPaymentId = string.Equals(provider, "google_play", StringComparison.Ordinal)
            ? command.ServerVerificationData
            : verification.Value.ExternalTransactionId
                ?? command.PurchaseId
                ?? order.ExternalPaymentId;
        await dbContext.SaveChangesAsync(cancellationToken);

        // Store purchase settlement is webhook-authoritative.
        return Result.Success(ToPurchaseOrderResponse(order));
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
}
