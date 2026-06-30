using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<PremiumCheckoutResponse>> CreatePremiumCheckoutAsync(
        CreatePremiumCheckoutCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var providerConfig = await ResolveEnabledPaymentProviderConfigAsync(
            provider,
            command.Platform,
            command.Country,
            command.AppVersion,
            cancellationToken);

        if (providerConfig is null)
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        var stripeApiKey = ResolveStripeApiKey(providerConfig.Mode);
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
        }

        // The current Flutter app does not bundle Stripe PaymentSheet. Use hosted
        // Checkout for mobile too so the client always receives a checkout URL.
        var usePaymentSheet = false;
        string? stripePublishableKey = null;
        if (usePaymentSheet)
        {
            stripePublishableKey = ResolveStripePublishableKey(providerConfig.Mode);
            if (string.IsNullOrWhiteSpace(stripePublishableKey))
            {
                return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentProviderUnavailable);
            }
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(command.PlanCode, cancellationToken);
        if (plan is null)
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var customer = await GetOrCreatePaymentCustomerAsync(command.UserId, provider, providerConfig.Mode, cancellationToken);
        if (customer.IsFailure)
        {
            return Result.Failure<PremiumCheckoutResponse>(customer.Error);
        }

        var checkout = await paymentGateway.CreateSubscriptionCheckoutAsync(
            new SubscriptionCheckoutCreateRequest(
                provider,
                command.UserId,
                customer.Value.ExternalCustomerId,
                plan.PlanCode,
                plan.ProductName,
                plan.PriceAmount,
                plan.CurrencyCode,
                plan.BillingInterval,
                stripeApiKey,
                stripePublishableKey,
                usePaymentSheet,
                plan.StripePriceId),
            cancellationToken);

        if (checkout.IsFailure)
        {
            return Result.Failure<PremiumCheckoutResponse>(checkout.Error);
        }

        if (usePaymentSheet
            && string.IsNullOrWhiteSpace(checkout.Value.PaymentIntentClientSecret))
        {
            return Result.Failure<PremiumCheckoutResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        return Result.Success(new PremiumCheckoutResponse(
            provider,
            checkout.Value.CheckoutUrl,
            "pending",
            checkout.Value.ExternalCheckoutId,
            checkout.Value.PaymentIntentClientSecret,
            checkout.Value.CustomerId,
            checkout.Value.CustomerEphemeralKeySecret,
            checkout.Value.PublishableKey));
    }

    public async Task<Result<BillingPortalSessionResponse>> CreatePremiumBillingPortalAsync(
        CreatePremiumBillingPortalCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var customer = await dbContext.PaymentCustomers
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == command.UserId && x.Provider == provider, cancellationToken);

        if (customer is null)
        {
            return Result.Failure<BillingPortalSessionResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var portal = await paymentGateway.CreateBillingPortalSessionAsync(
            new BillingPortalCreateRequest(provider, command.UserId, customer.ExternalCustomerId, stripeApiKey),
            cancellationToken);

        if (portal.IsFailure)
        {
            return Result.Failure<BillingPortalSessionResponse>(portal.Error);
        }

        return Result.Success(new BillingPortalSessionResponse(provider, portal.Value.PortalUrl));
    }
}
