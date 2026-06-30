using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
    public async Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
        SubscriptionCheckoutCreateRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);
        var metadata = new Dictionary<string, string>
        {
            ["purpose"] = "premium_subscription",
            ["user_id"] = request.UserId.ToString("D"),
            ["plan_code"] = request.PlanCode
        };

        async Task<Result<SubscriptionCheckoutCreateResponse>> CreateHostedCheckoutSessionAsync(bool forceInlinePrice = false)
        {
            var shouldUseCatalogPrice = !forceInlinePrice && !string.IsNullOrWhiteSpace(request.StripePriceId);
            try
            {
                var lineItem = new SessionLineItemOptions
                {
                    Quantity = 1
                };

                if (shouldUseCatalogPrice)
                {
                    lineItem.Price = request.StripePriceId;
                }
                else
                {
                    lineItem.PriceData = new SessionLineItemPriceDataOptions
                    {
                        Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                        UnitAmount = amountInMinorUnits,
                        Recurring = new SessionLineItemPriceDataRecurringOptions
                        {
                            Interval = NormalizeRecurringInterval(request.BillingInterval)
                        },
                        ProductData = new SessionLineItemPriceDataProductDataOptions
                        {
                            Name = request.ProductName
                        }
                    };
                }

                var session = await new SessionService(stripeClient).CreateAsync(
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
                        LineItems = [lineItem]
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
            catch (StripeException) when (shouldUseCatalogPrice)
            {
                return await CreateHostedCheckoutSessionAsync(forceInlinePrice: true);
            }
            catch (StripeException exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_hosted_subscription_checkout",
                    request.UserId,
                    planCode: request.PlanCode,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: false);
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
            catch (Exception exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_hosted_subscription_checkout",
                    request.UserId,
                    planCode: request.PlanCode,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: false);
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }

        if (request.UsePaymentSheet)
        {
            try
            {
                var ephemeralKeyResult = await CreateCustomerEphemeralKeySecretAsync(
                    apiKey,
                    request.ExternalCustomerId,
                    request.UserId,
                    null,
                    "create_subscription_ephemeral_key",
                    cancellationToken);

                if (ephemeralKeyResult.IsFailure)
                {
                    return Result.Failure<SubscriptionCheckoutCreateResponse>(ephemeralKeyResult.Error);
                }

                async Task<Subscription> CreateMobileSubscriptionAsync(bool forceInlinePrice = false)
                {
                    var shouldUseCatalogPrice = !forceInlinePrice && !string.IsNullOrWhiteSpace(request.StripePriceId);

                    var item = new SubscriptionItemOptions();
                    if (shouldUseCatalogPrice)
                    {
                        item.Price = request.StripePriceId;
                    }
                    else
                    {
                        var product = await new ProductService(stripeClient).CreateAsync(
                            new ProductCreateOptions
                            {
                                Name = request.ProductName,
                                Metadata = metadata
                            },
                            cancellationToken: cancellationToken);

                        item.PriceData = new SubscriptionItemPriceDataOptions
                        {
                            Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                            UnitAmount = amountInMinorUnits,
                            Recurring = new SubscriptionItemPriceDataRecurringOptions
                            {
                                Interval = NormalizeRecurringInterval(request.BillingInterval)
                            },
                            Product = product.Id
                        };
                    }

                    try
                    {
                        return await new SubscriptionService(stripeClient).CreateAsync(
                            new SubscriptionCreateOptions
                            {
                                Customer = request.ExternalCustomerId,
                                Items = [item],
                                PaymentBehavior = "default_incomplete",
                                PaymentSettings = new SubscriptionPaymentSettingsOptions
                                {
                                    SaveDefaultPaymentMethod = "on_subscription"
                                },
                                Metadata = metadata,
                                Expand = ["latest_invoice.payment_intent", "latest_invoice.confirmation_secret"]
                            },
                            requestOptions: null,
                            cancellationToken);
                    }
                    catch (StripeException) when (shouldUseCatalogPrice)
                    {
                        return await CreateMobileSubscriptionAsync(forceInlinePrice: true);
                    }
                }

                var subscription = await CreateMobileSubscriptionAsync();

                var clientSecret = subscription.LatestInvoice?
                    .Payments?
                    .Data?
                    .FirstOrDefault()?
                    .Payment?
                    .PaymentIntent?
                    .ClientSecret
                    ?? subscription.LatestInvoice?.ConfirmationSecret?.ClientSecret;

                // Stripe invoice shape differs across API versions/SDKs; explicitly re-fetch invoice as fallback.
                if (string.IsNullOrWhiteSpace(clientSecret))
                {
                    var latestInvoiceId = subscription.LatestInvoice?.Id ?? subscription.LatestInvoiceId;
                    if (string.IsNullOrWhiteSpace(latestInvoiceId))
                    {
                        var refreshedSubscription = await new SubscriptionService(stripeClient).GetAsync(
                            subscription.Id,
                            new SubscriptionGetOptions
                            {
                                Expand = ["latest_invoice.confirmation_secret", "latest_invoice.payments.data.payment.payment_intent"]
                            },
                            requestOptions: null,
                            cancellationToken);

                        clientSecret = refreshedSubscription.LatestInvoice?
                            .ConfirmationSecret?
                            .ClientSecret
                            ?? refreshedSubscription.LatestInvoice?
                                .Payments?
                                .Data?
                                .FirstOrDefault()?
                                .Payment?
                                .PaymentIntent?
                                .ClientSecret;
                        latestInvoiceId = refreshedSubscription.LatestInvoice?.Id ?? refreshedSubscription.LatestInvoiceId;
                    }

                    if (!string.IsNullOrWhiteSpace(latestInvoiceId))
                    {
                        var invoice = await new InvoiceService(stripeClient).GetAsync(
                            latestInvoiceId,
                            new InvoiceGetOptions
                            {
                                Expand = ["payment_intent", "confirmation_secret", "payments.data.payment.payment_intent"]
                            },
                            requestOptions: null,
                            cancellationToken);

                        clientSecret = invoice.ConfirmationSecret?.ClientSecret
                            ?? invoice.Payments?
                                .Data?
                                .FirstOrDefault()?
                                .Payment?
                                .PaymentIntent?
                                .ClientSecret;
                    }
                }

                if (string.IsNullOrWhiteSpace(clientSecret))
                {
                    return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
                }

                return Result.Success(new SubscriptionCheckoutCreateResponse(
                    subscription.Id,
                    string.Empty,
                    clientSecret,
                    request.ExternalCustomerId,
                    ephemeralKeyResult.Value,
                    request.PublishableKey));
            }
            catch (StripeException exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_mobile_subscription_checkout",
                    request.UserId,
                    planCode: request.PlanCode,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: true);
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
            catch (Exception exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_mobile_subscription_checkout",
                    request.UserId,
                    planCode: request.PlanCode,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: true);
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }

        return await CreateHostedCheckoutSessionAsync();
    }
}
