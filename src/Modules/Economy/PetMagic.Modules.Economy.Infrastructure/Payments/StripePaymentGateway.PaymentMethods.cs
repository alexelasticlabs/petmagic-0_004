using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
    public async Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(
        PaymentMethodSetupCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        try
        {
            var service = new SessionService(stripeClient);
            var session = await service.CreateAsync(
                new SessionCreateOptions
                {
                    Mode = "setup",
                    SuccessUrl = options.StripeCheckoutSuccessUrl,
                    CancelUrl = options.StripeCheckoutCancelUrl,
                    Customer = request.ExternalCustomerId,
                    ClientReferenceId = request.UserId.ToString("D"),
                    Metadata = new Dictionary<string, string>
                    {
                        ["purpose"] = "payment_method_setup",
                        ["user_id"] = request.UserId.ToString("D")
                    },
                    SetupIntentData = new SessionSetupIntentDataOptions
                    {
                        Metadata = new Dictionary<string, string>
                        {
                            ["purpose"] = "payment_method_setup",
                            ["user_id"] = request.UserId.ToString("D")
                        }
                    },
                    PaymentMethodTypes = ["card"]
                },
                new RequestOptions { IdempotencyKey = $"economy-payment-method-setup-{request.UserId:D}-{Guid.NewGuid():N}" },
                cancellationToken);

            return Result.Success(new PaymentMethodSetupCreateResponse(session.Id, session.Url ?? string.Empty));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "create_payment_method_setup",
                request.UserId,
                externalCustomerId: request.ExternalCustomerId);
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(
        PaymentMethodResolveRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey();
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        try
        {
            var setupIntent = await new SetupIntentService(stripeClient).GetAsync(request.ExternalSetupId, cancellationToken: cancellationToken);
            var paymentMethodId = setupIntent.PaymentMethodId;
            if (string.IsNullOrWhiteSpace(paymentMethodId))
            {
                return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
            }

            var paymentMethod = await new PaymentMethodService(stripeClient).GetAsync(paymentMethodId, cancellationToken: cancellationToken);
            return Result.Success(new PaymentMethodDetailsResponse(
                paymentMethod.Id,
                paymentMethod.Card?.Brand ?? "card",
                paymentMethod.Card?.Last4 ?? string.Empty,
                paymentMethod.Card?.ExpMonth,
                paymentMethod.Card?.ExpYear));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "resolve_setup_intent_payment_method",
                externalSetupId: request.ExternalSetupId);
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey();
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        try
        {
            await new PaymentMethodService(stripeClient).DetachAsync(request.ExternalPaymentMethodId, cancellationToken: cancellationToken);
            return Result.Success();
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "detach_payment_method",
                externalPaymentMethodId: request.ExternalPaymentMethodId);
            return Result.Failure(EconomyErrors.PaymentGatewayFailed);
        }
    }
}
