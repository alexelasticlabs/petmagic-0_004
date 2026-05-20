using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;
using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed class StripePaymentGateway(EconomyOptions options) : IPaymentGateway
{
    private const string Provider = "stripe";

    public async Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);
        var checkoutOptions = new SessionCreateOptions
        {
            Mode = "payment",
            SuccessUrl = options.StripeCheckoutSuccessUrl,
            CancelUrl = options.StripeCheckoutCancelUrl,
            ClientReferenceId = request.OrderId.ToString("D"),
            Metadata = new Dictionary<string, string>
            {
                ["order_id"] = request.OrderId.ToString("D"),
                ["user_id"] = request.UserId.ToString("D")
            },
            PaymentIntentData = new SessionPaymentIntentDataOptions
            {
                Metadata = new Dictionary<string, string>
                {
                    ["order_id"] = request.OrderId.ToString("D"),
                    ["user_id"] = request.UserId.ToString("D")
                }
            },
            LineItems =
            [
                new SessionLineItemOptions
                {
                    Quantity = 1,
                    PriceData = new SessionLineItemPriceDataOptions
                    {
                        Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                        UnitAmount = amountInMinorUnits,
                        ProductData = new SessionLineItemPriceDataProductDataOptions
                        {
                            Name = $"{request.ProductName} ({request.SparkToGrant} PawSpark)"
                        }
                    }
                }
            ]
        };

        var requestOptions = new RequestOptions
        {
            IdempotencyKey = $"economy-order-{request.OrderId:D}"
        };

        try
        {
            var service = new SessionService();
            var session = await service.CreateAsync(checkoutOptions, requestOptions, cancellationToken);

            return Result.Success(new PaymentCreateResponse(
                session.Id,
                session.Url ?? string.Empty));
        }
        catch (StripeException)
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
        SubscriptionCheckoutCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);
        var metadata = new Dictionary<string, string>
        {
            ["purpose"] = "premium_subscription",
            ["user_id"] = request.UserId.ToString("D"),
            ["plan_code"] = request.PlanCode
        };

        try
        {
            var session = await new SessionService().CreateAsync(
                new SessionCreateOptions
                {
                    Mode = "subscription",
                    SuccessUrl = options.StripeCheckoutSuccessUrl,
                    CancelUrl = options.StripeCheckoutCancelUrl,
                    Customer = request.ExternalCustomerId,
                    ClientReferenceId = request.UserId.ToString("D"),
                    Metadata = metadata,
                    SubscriptionData = new SessionSubscriptionDataOptions
                    {
                        Metadata = metadata
                    },
                    LineItems =
                    [
                        new SessionLineItemOptions
                        {
                            Quantity = 1,
                            PriceData = new SessionLineItemPriceDataOptions
                            {
                                Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                                UnitAmount = amountInMinorUnits,
                                Recurring = new SessionLineItemPriceDataRecurringOptions
                                {
                                    Interval = request.BillingInterval.Trim().ToLowerInvariant()
                                },
                                ProductData = new SessionLineItemPriceDataProductDataOptions
                                {
                                    Name = request.ProductName
                                }
                            }
                        }
                    ]
                },
                new RequestOptions
                {
                    IdempotencyKey = $"economy-subscription-{request.UserId:D}-{request.PlanCode.ToLowerInvariant()}"
                },
                cancellationToken);

            return Result.Success(new SubscriptionCheckoutCreateResponse(
                session.Id,
                session.Url ?? string.Empty));
        }
        catch (StripeException)
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentCustomerCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure<PaymentCustomerCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        try
        {
            var service = new CustomerService();
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
        catch (StripeException)
        {
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

        if (!EnsureConfigured())
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        try
        {
            var session = await new Stripe.BillingPortal.SessionService().CreateAsync(
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
        catch (StripeException)
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(
        PaymentMethodSetupCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        try
        {
            var service = new SessionService();
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
        catch (StripeException)
        {
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

        if (!EnsureConfigured())
        {
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        try
        {
            var setupIntent = await new SetupIntentService().GetAsync(request.ExternalSetupId, cancellationToken: cancellationToken);
            var paymentMethodId = setupIntent.PaymentMethodId;
            if (string.IsNullOrWhiteSpace(paymentMethodId))
            {
                return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
            }

            var paymentMethod = await new PaymentMethodService().GetAsync(paymentMethodId, cancellationToken: cancellationToken);
            return Result.Success(new PaymentMethodDetailsResponse(
                paymentMethod.Id,
                paymentMethod.Card?.Brand ?? "card",
                paymentMethod.Card?.Last4 ?? string.Empty,
                paymentMethod.Card?.ExpMonth,
                paymentMethod.Card?.ExpYear));
        }
        catch (StripeException)
        {
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        try
        {
            await new PaymentMethodService().DetachAsync(request.ExternalPaymentMethodId, cancellationToken: cancellationToken);
            return Result.Success();
        }
        catch (StripeException)
        {
            return Result.Failure(EconomyErrors.PaymentGatewayFailed);
        }
    }

    public async Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(
        PaymentSavedMethodCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (!EnsureConfigured())
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe();

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);

        try
        {
            var service = new PaymentIntentService();
            var paymentIntent = await service.CreateAsync(
                new PaymentIntentCreateOptions
                {
                    Amount = amountInMinorUnits,
                    Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                    Customer = request.ExternalCustomerId,
                    PaymentMethod = request.ExternalPaymentMethodId,
                    Confirm = true,
                    OffSession = true,
                    Metadata = new Dictionary<string, string>
                    {
                        ["order_id"] = request.OrderId.ToString("D"),
                        ["user_id"] = request.UserId.ToString("D")
                    },
                    Description = $"{request.ProductName} ({request.SparkToGrant} PawSpark)"
                },
                new RequestOptions { IdempotencyKey = $"economy-order-saved-method-{request.OrderId:D}" },
                cancellationToken);

            return Result.Success(new PaymentCreateResponse(paymentIntent.Id, string.Empty));
        }
        catch (StripeException)
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    private static bool IsStripe(string provider)
    {
        return string.Equals(provider, Provider, StringComparison.OrdinalIgnoreCase);
    }

    private bool EnsureConfigured()
    {
        return !string.IsNullOrWhiteSpace(options.StripeSecretKey);
    }

    private void ConfigureStripe()
    {
        StripeConfiguration.ApiKey = options.StripeSecretKey;
    }
}
