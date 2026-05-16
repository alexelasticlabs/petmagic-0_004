using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed class EconomyService(
    EconomyDbContext dbContext,
    IPaymentGateway paymentGateway,
    IOptions<EconomyOptions> options) : IEconomyService
{
    public async Task<Result<WalletStateResponse>> GetWalletAsync(Guid userId, bool isPremium, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
        return Result.Success(ToWalletState(wallet, isPremium));
    }

    public async Task<Result<WalletOperationResponse>> ClaimWeeklyGrantAsync(ClaimWeeklyGrantCommand command, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        if (wallet.LastWeeklyGrantAtUtc is DateTime lastWeeklyGrantAtUtc)
        {
            var nextWeeklyAtUtc = lastWeeklyGrantAtUtc.AddDays(7);
            if (nextWeeklyAtUtc > now)
            {
                return Result.Failure<WalletOperationResponse>(EconomyErrors.WeeklyGrantCooldown);
            }
        }

        var amount = command.IsPremium ? options.Value.WeeklyPremiumSpark : options.Value.WeeklyFreeSpark;
        var response = ApplyWalletDelta(wallet, amount, WalletLedgerSource.WeeklyGrant, "weekly payout", now);
        wallet.LastWeeklyGrantAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> ClaimAdRewardAsync(ClaimAdRewardCommand command, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        if (wallet.AdRewardWindowStartedAtUtc is null || wallet.AdRewardWindowStartedAtUtc.Value.Date != now.Date)
        {
            wallet.AdRewardWindowStartedAtUtc = now;
            wallet.AdRewardsClaimedInWindow = 0;
        }

        if (wallet.AdRewardsClaimedInWindow >= options.Value.AdRewardDailyLimit)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.AdRewardLimitReached);
        }

        var response = ApplyWalletDelta(wallet, options.Value.AdRewardSpark, WalletLedgerSource.AdReward, "rewarded ad", now);
        wallet.AdRewardsClaimedInWindow += 1;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(response);
    }

    public async Task<Result<WalletOperationResponse>> SpendAsync(SpendBalanceCommand command, CancellationToken cancellationToken)
    {
        var wallet = await GetOrCreateWalletAsync(command.UserId, cancellationToken);
        if (wallet.Balance < command.Amount)
        {
            return Result.Failure<WalletOperationResponse>(EconomyErrors.InsufficientBalance);
        }

        var now = DateTime.UtcNow;
        var response = ApplyWalletDelta(wallet, -command.Amount, WalletLedgerSource.GenerationSpend, command.Reason, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(response);
    }

    public async Task<Result<IReadOnlyList<CurrencyPackResponse>>> ListPacksAsync(CancellationToken cancellationToken)
    {
        var packs = await dbContext.CurrencyPacks
            .Where(x => x.IsActive)
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .Select(x => new CurrencyPackResponse(
                x.Id,
                x.Code,
                x.DisplayName,
                x.CurrencyCode,
                x.PriceAmount,
                x.GrantedSpark,
                x.BonusSpark,
                x.GrantedSpark + x.BonusSpark))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<CurrencyPackResponse>>(packs);
    }

    public async Task<Result<PurchaseCheckoutResponse>> CreatePackPurchaseAsync(CreatePackPurchaseCommand command, CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var currencyCode = command.CurrencyCode.Trim().ToUpperInvariant();
        var pack = await dbContext.CurrencyPacks
            .FirstOrDefaultAsync(x => x.Id == command.PackId && x.IsActive && x.CurrencyCode == currencyCode, cancellationToken);

        if (pack is null)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        var order = new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            PackId = pack.Id,
            PaymentProvider = provider,
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = pack.PriceAmount,
            CurrencyCode = pack.CurrencyCode,
            SparkToGrant = pack.GrantedSpark + pack.BonusSpark,
            CreatedAtUtc = DateTime.UtcNow
        };

        var paymentResult = await paymentGateway.CreatePaymentAsync(
            new PaymentCreateRequest(
                provider,
                order.Id,
                order.UserId,
                order.PriceAmount,
                order.CurrencyCode,
                order.SparkToGrant,
                pack.DisplayName),
            cancellationToken);

        if (paymentResult.IsFailure)
        {
            return Result.Failure<PurchaseCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        order.ExternalPaymentId = paymentResult.Value.ExternalPaymentId;
        order.CheckoutUrl = paymentResult.Value.CheckoutUrl;

        dbContext.PurchaseOrders.Add(order);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(ToPurchaseCheckoutResponse(order));
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

    public async Task<Result<PurchaseOrderResponse>> GetPurchaseAsync(Guid userId, Guid orderId, CancellationToken cancellationToken)
    {
        var order = await dbContext.PurchaseOrders
            .FirstOrDefaultAsync(x => x.Id == orderId && x.UserId == userId, cancellationToken);

        if (order is null)
        {
            return Result.Failure<PurchaseOrderResponse>(EconomyErrors.PurchaseNotFound);
        }

        return Result.Success(ToPurchaseOrderResponse(order));
    }

    public async Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken)
    {
        string? eventId;
        string? eventType;
        try
        {
            var stripeEvent = EventUtility.ConstructEvent(command.RawBody, command.StripeSignature, options.Value.StripeWebhookSecret);
            eventId = stripeEvent.Id;
            eventType = stripeEvent.Type;
        }
        catch
        {
            if (!VerifyStripeSignatureFallback(command.RawBody, command.StripeSignature, options.Value.StripeWebhookSecret))
            {
                return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidStripeSignature);
            }

            var envelope = ParseStripeEnvelope(command.RawBody);
            if (!envelope.Success)
            {
                return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
            }

            eventId = envelope.EventId;
            eventType = envelope.EventType;
        }

        if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
        {
            return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var parsedEvent = ParseStripeEvent(command.RawBody);
        if (!parsedEvent.Success)
        {
            return Result.Failure<StripeWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "stripe" && x.EventId == eventId, cancellationToken);

        if (alreadyProcessed)
        {
            return Result.Success(new StripeWebhookResultResponse(eventId, false, "ignored_duplicate"));
        }

        dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            EventId = eventId,
            EventType = eventType,
            ProcessedAtUtc = DateTime.UtcNow
        });

        if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
            || string.Equals(eventType, "payment_intent.succeeded", StringComparison.Ordinal))
        {
            var order = await ResolveOrderAsync(parsedEvent.OrderId, parsedEvent.ObjectId, cancellationToken);
            if (order is not null)
            {
                var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
                if (confirmResult.IsFailure && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
                {
                    return Result.Failure<StripeWebhookResultResponse>(confirmResult.Error);
                }
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(new StripeWebhookResultResponse(eventId, true, "processed"));
    }

    private async Task<Wallet> GetOrCreateWalletAsync(Guid userId, CancellationToken cancellationToken)
    {
        var wallet = await dbContext.Wallets.FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (wallet is not null)
        {
            return wallet;
        }

        wallet = new Wallet
        {
            UserId = userId,
            Balance = 0,
            AdRewardsClaimedInWindow = 0,
            UpdatedAtUtc = DateTime.UtcNow
        };

        dbContext.Wallets.Add(wallet);
        await dbContext.SaveChangesAsync(cancellationToken);
        return wallet;
    }

    private WalletOperationResponse ApplyWalletDelta(Wallet wallet, int delta, string source, string reason, DateTime now)
    {
        wallet.Balance += delta;
        wallet.UpdatedAtUtc = now;

        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = wallet.UserId,
            Delta = delta,
            BalanceAfter = wallet.Balance,
            Source = source,
            Reason = reason,
            CreatedAtUtc = now
        });

        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);
        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletOperationResponse(
            wallet.UserId,
            delta,
            wallet.Balance,
            source,
            now,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday);
    }

    private WalletStateResponse ToWalletState(Wallet wallet, bool isPremium)
    {
        var nextWeeklyGrantAtUtc = wallet.LastWeeklyGrantAtUtc?.AddDays(7);

        if (wallet.AdRewardWindowStartedAtUtc is null || wallet.AdRewardWindowStartedAtUtc.Value.Date != DateTime.UtcNow.Date)
        {
            return new WalletStateResponse(
                wallet.UserId,
                wallet.Balance,
                nextWeeklyGrantAtUtc,
                options.Value.AdRewardDailyLimit,
                isPremium,
                wallet.UpdatedAtUtc);
        }

        var adRewardsRemainingToday = Math.Max(0, options.Value.AdRewardDailyLimit - wallet.AdRewardsClaimedInWindow);

        return new WalletStateResponse(
            wallet.UserId,
            wallet.Balance,
            nextWeeklyGrantAtUtc,
            adRewardsRemainingToday,
            isPremium,
            wallet.UpdatedAtUtc);
    }

    private async Task<Result<PurchaseOrder>> ConfirmPurchaseInternalAsync(PurchaseOrder order, CancellationToken cancellationToken)
    {
        if (string.Equals(order.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
            || !string.Equals(order.Status, PurchaseOrderStatus.Pending, StringComparison.Ordinal))
        {
            return Result.Failure<PurchaseOrder>(EconomyErrors.PurchaseAlreadyProcessed);
        }

        var wallet = await GetOrCreateWalletAsync(order.UserId, cancellationToken);
        var now = DateTime.UtcNow;

        ApplyWalletDelta(wallet, order.SparkToGrant, WalletLedgerSource.PackPurchase, $"purchase:{order.Id:D}", now);

        order.Status = PurchaseOrderStatus.Succeeded;
        order.ConfirmedAtUtc = now;
        wallet.UpdatedAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(order);
    }

    private async Task<PurchaseOrder?> ResolveOrderAsync(Guid? orderId, string? externalPaymentId, CancellationToken cancellationToken)
    {
        if (orderId.HasValue)
        {
            var byId = await dbContext.PurchaseOrders.FirstOrDefaultAsync(x => x.Id == orderId.Value, cancellationToken);
            if (byId is not null)
            {
                return byId;
            }
        }

        if (!string.IsNullOrWhiteSpace(externalPaymentId))
        {
            return await dbContext.PurchaseOrders.FirstOrDefaultAsync(
                x => x.PaymentProvider == "stripe" && x.ExternalPaymentId == externalPaymentId,
                cancellationToken);
        }

        return null;
    }

    private static PurchaseCheckoutResponse ToPurchaseCheckoutResponse(PurchaseOrder order)
    {
        return new PurchaseCheckoutResponse(
            order.Id,
            order.UserId,
            order.PaymentProvider,
            order.ExternalPaymentId ?? string.Empty,
            order.CheckoutUrl ?? string.Empty,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.CreatedAtUtc);
    }

    private static PurchaseOrderResponse ToPurchaseOrderResponse(PurchaseOrder order)
    {
        return new PurchaseOrderResponse(
            order.Id,
            order.UserId,
            order.PackId,
            order.PaymentProvider,
            order.Status,
            order.PriceAmount,
            order.CurrencyCode,
            order.SparkToGrant,
            order.ExternalPaymentId,
            order.CreatedAtUtc,
            order.ConfirmedAtUtc);
    }

    private static (bool Success, Guid? OrderId, string? ObjectId) ParseStripeEvent(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("data", out var dataElement)
                || dataElement.ValueKind != JsonValueKind.Object
                || !dataElement.TryGetProperty("object", out var objectElement)
                || objectElement.ValueKind != JsonValueKind.Object)
            {
                return (false, null, null);
            }

            string? objectId = null;
            if (objectElement.TryGetProperty("id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
            {
                objectId = idElement.GetString();
            }

            Guid? orderId = null;
            if (objectElement.TryGetProperty("metadata", out var metadataElement)
                && metadataElement.ValueKind == JsonValueKind.Object
                && metadataElement.TryGetProperty("order_id", out var orderIdElement)
                && orderIdElement.ValueKind == JsonValueKind.String)
            {
                var rawOrderId = orderIdElement.GetString();
                if (Guid.TryParse(rawOrderId, out var parsedOrderId))
                {
                    orderId = parsedOrderId;
                }
            }

            return (true, orderId, objectId);
        }
        catch
        {
            var orderIdMatch = Regex.Match(rawBody, "\"order_id\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant);
            Guid? orderId = null;
            if (orderIdMatch.Success)
            {
                var rawOrderId = orderIdMatch.Groups["value"].Value;
                if (Guid.TryParse(rawOrderId, out var parsedOrderId))
                {
                    orderId = parsedOrderId;
                }
            }

            string? objectId = null;
            var objectIdMatch = Regex.Match(
                rawBody,
                "\"data\"\\s*:\\s*\\{\\s*\"object\"\\s*:\\s*\\{.*?\"id\"\\s*:\\s*\"(?<value>[^\"]+)\"",
                RegexOptions.CultureInvariant | RegexOptions.Singleline);

            if (objectIdMatch.Success)
            {
                objectId = objectIdMatch.Groups["value"].Value;
            }

            if (!orderId.HasValue && string.IsNullOrWhiteSpace(objectId))
            {
                return (false, null, null);
            }

            return (true, orderId, objectId);
        }
    }

    private static (bool Success, string? EventId, string? EventType) ParseStripeEnvelope(string rawBody)
    {
        try
        {
            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("id", out var idElement)
                || idElement.ValueKind != JsonValueKind.String
                || !root.TryGetProperty("type", out var typeElement)
                || typeElement.ValueKind != JsonValueKind.String)
            {
                return (false, null, null);
            }

            var eventId = idElement.GetString();
            var eventType = typeElement.GetString();
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
        catch
        {
            var idMatch = Regex.Match(rawBody, "\"id\"\\s*:\\s*\"(?<value>evt_[^\"]+)\"", RegexOptions.CultureInvariant);
            var typeMatch = Regex.Match(rawBody, "\"type\"\\s*:\\s*\"(?<value>[^\"]+)\"", RegexOptions.CultureInvariant);

            if (!idMatch.Success || !typeMatch.Success)
            {
                return (false, null, null);
            }

            var eventId = idMatch.Groups["value"].Value;
            var eventType = typeMatch.Groups["value"].Value;
            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
            {
                return (false, null, null);
            }

            return (true, eventId, eventType);
        }
    }

    private static bool VerifyStripeSignatureFallback(string rawBody, string signatureHeader, string secret)
    {
        if (string.IsNullOrWhiteSpace(signatureHeader) || string.IsNullOrWhiteSpace(secret))
        {
            return false;
        }

        string? timestamp = null;
        string? expectedSignature = null;

        var parts = signatureHeader.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var part in parts)
        {
            if (part.StartsWith("t=", StringComparison.Ordinal))
            {
                timestamp = part[2..];
            }
            else if (part.StartsWith("v1=", StringComparison.Ordinal))
            {
                expectedSignature = part[3..];
            }
        }

        if (string.IsNullOrWhiteSpace(timestamp) || string.IsNullOrWhiteSpace(expectedSignature))
        {
            return false;
        }

        var signedPayload = $"{timestamp}.{rawBody}";
        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var payloadBytes = Encoding.UTF8.GetBytes(signedPayload);

        using var hmac = new HMACSHA256(keyBytes);
        var computed = Convert.ToHexString(hmac.ComputeHash(payloadBytes)).ToLowerInvariant();
        return string.Equals(computed, expectedSignature, StringComparison.OrdinalIgnoreCase);
    }
}
