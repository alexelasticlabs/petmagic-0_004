using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
    public async Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentCustomerCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentCustomerCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        try
        {
            var service = new CustomerService(stripeClient);
            var customer = await service.CreateAsync(
                new CustomerCreateOptions
                {
                    Description = $"PetMagic user {request.UserId:D}",
                    Metadata = new Dictionary<string, string>
                    {
                        ["user_id"] = request.UserId.ToString("D")
                    }
                },
                new RequestOptions { IdempotencyKey = $"economy-customer-{request.UserId:D}" },
                cancellationToken);

            return Result.Success(new PaymentCustomerCreateResponse(customer.Id));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "create_customer",
                request.UserId);
            return Result.Failure<PaymentCustomerCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
        BillingPortalCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        try
        {
            var session = await new Stripe.BillingPortal.SessionService(stripeClient).CreateAsync(
                new Stripe.BillingPortal.SessionCreateOptions
                {
                    Customer = request.ExternalCustomerId,
                    ReturnUrl = options.StripeBillingPortalReturnUrl
                },
                new RequestOptions
                {
                    IdempotencyKey = $"economy-billing-portal-{request.UserId:D}"
                },
                cancellationToken);

            return Result.Success(new BillingPortalCreateResponse(session.Url));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "create_billing_portal_session",
                request.UserId,
                externalCustomerId: request.ExternalCustomerId);
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch (Exception exception)
        {
            LogGatewayFailure(
                exception,
                "create_billing_portal_session",
                request.UserId,
                externalCustomerId: request.ExternalCustomerId);
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }
}
