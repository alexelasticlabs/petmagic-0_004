using System.Net.Http.Headers;
using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;

using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed class StripePaymentGateway(
    EconomyOptions options,
    IHttpClientFactory httpClientFactory) : IPaymentGateway
{
    public const string HttpClientName = "Stripe";

    private const string Provider = "stripe";
    private const string MobileEphemeralKeyStripeVersion = "2020-03-02";

    public async Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);
        if (request.UsePaymentSheet)
        {
            try
            {
                string? customerEphemeralKeySecret = null;
                if (!string.IsNullOrWhiteSpace(request.ExternalCustomerId))
                {
                    var ephemeralKeyResult = await CreateCustomerEphemeralKeySecretAsync(
                        apiKey,
                        request.ExternalCustomerId,
                        cancellationToken);

                    if (ephemeralKeyResult.IsFailure)
                    {
                        return Result.Failure<PaymentCreateResponse>(ephemeralKeyResult.Error);
                    }

                    customerEphemeralKeySecret = ephemeralKeyResult.Value;
                }

                var paymentIntent = await new PaymentIntentService().CreateAsync(
                    new PaymentIntentCreateOptions
                    {
                        Amount = amountInMinorUnits,
                        Currency = request.CurrencyCode.Trim().ToLowerInvariant(),
                        Customer = request.ExternalCustomerId,
                        AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
                        {
                            Enabled = true,
                        },
                        Metadata = new Dictionary<string, string>
                        {
                            ["order_id"] = request.OrderId.ToString("D"),
                            ["user_id"] = request.UserId.ToString("D")
                        },
                        Description = $"{request.ProductName} ({request.SparkToGrant} PawSpark)"
                    },
                    new RequestOptions
                    {
                        IdempotencyKey = $"economy-order-mobile-{request.OrderId:D}"
                    },
                    cancellationToken);

                return Result.Success(new PaymentCreateResponse(
                    paymentIntent.Id,
                    string.Empty,
                    paymentIntent.ClientSecret,
                        request.ExternalCustomerId,
                        customerEphemeralKeySecret,
                    request.PublishableKey));
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

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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
            catch (StripeException)
            {
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
            catch
            {
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
                        var product = await new ProductService().CreateAsync(
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
                        return await new SubscriptionService().CreateAsync(
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
                        var refreshedSubscription = await new SubscriptionService().GetAsync(
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
                        var invoice = await new InvoiceService().GetAsync(
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
            catch (StripeException)
            {
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
            catch
            {
                return Result.Failure<SubscriptionCheckoutCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
        }

        return await CreateHostedCheckoutSessionAsync();
    }

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

        ConfigureStripe(apiKey);

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

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<BillingPortalCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentMethodSetupCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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

        var apiKey = ResolveApiKey();
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentMethodDetailsResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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

        var apiKey = ResolveApiKey();
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        ConfigureStripe(apiKey);

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

    private static string NormalizeRecurringInterval(string value)
    {
        return value.Trim().ToLowerInvariant() switch
        {
            "monthly" => "month",
            "yearly" => "year",
            "year" => "year",
            _ => "month"
        };
    }

    private static bool EnsureConfigured(string? apiKey)
    {
        return !string.IsNullOrWhiteSpace(apiKey);
    }

    private void ConfigureStripe(string? apiKey)
    {
        StripeConfiguration.ApiKey = apiKey;
        StripeConfiguration.StripeClient = new StripeClient(
            apiKey,
            httpClient: new SystemNetHttpClient(httpClientFactory.CreateClient(HttpClientName)));
    }

    private async Task<Result<string>> CreateCustomerEphemeralKeySecretAsync(
        string apiKey,
        string customerId,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.stripe.com/v1/ephemeral_keys");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Headers.Add("Stripe-Version", MobileEphemeralKeyStripeVersion);
        request.Content = new FormUrlEncodedContent([
            new KeyValuePair<string, string>("customer", customerId)
        ]);

        try
        {
            using var response = await httpClientFactory
                .CreateClient(HttpClientName)
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            if (document.RootElement.TryGetProperty("secret", out var secretElement)
                && secretElement.ValueKind == JsonValueKind.String)
            {
                var secret = secretElement.GetString();
                if (!string.IsNullOrWhiteSpace(secret))
                {
                    return Result.Success(secret);
                }
            }

            return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
        }
        catch
        {
            return Result.Failure<string>(EconomyErrors.PaymentGatewayFailed);
        }
    }

    private string ResolveApiKey(string? apiKey = null)
    {
        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            return apiKey;
        }

        if (!string.IsNullOrWhiteSpace(options.StripeSecretKey))
        {
            return options.StripeSecretKey;
        }

        if (!string.IsNullOrWhiteSpace(options.StripeLiveSecretKey))
        {
            return options.StripeLiveSecretKey;
        }

        return options.StripeTestSecretKey;
    }
}
