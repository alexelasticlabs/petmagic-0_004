using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway
{
    public async Task<Result<PaymentRefundResponse>> RefundPaymentAsync(PaymentRefundRequest request, CancellationToken cancellationToken)
    {
        if (!IsStripe(request.Provider))
        {
            return Result.Failure<PaymentRefundResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var apiKey = ResolveApiKey(request.ApiSecretKey);
        if (!EnsureConfigured(apiKey) || string.IsNullOrWhiteSpace(request.ExternalPaymentId))
        {
            return Result.Failure<PaymentRefundResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        var stripeClient = CreateStripeClient(apiKey);

        var amountInMinorUnits = (long)decimal.Round(request.Amount * 100m, 0, MidpointRounding.AwayFromZero);
        try
        {
            var paymentIntentId = request.ExternalPaymentId;
            if (paymentIntentId.StartsWith("cs_", StringComparison.OrdinalIgnoreCase))
            {
                var session = await new SessionService(stripeClient).GetAsync(
                    paymentIntentId,
                    new SessionGetOptions { Expand = ["payment_intent"] },
                    cancellationToken: cancellationToken);

                paymentIntentId = session.PaymentIntentId ?? session.PaymentIntent?.Id ?? string.Empty;
                if (string.IsNullOrWhiteSpace(paymentIntentId))
                {
                    return Result.Failure<PaymentRefundResponse>(EconomyErrors.PaymentGatewayFailed);
                }
            }

            var refund = await new RefundService(stripeClient).CreateAsync(
                new RefundCreateOptions
                {
                    PaymentIntent = paymentIntentId,
                    Amount = amountInMinorUnits,
                    Metadata = new Dictionary<string, string>
                    {
                        ["order_id"] = request.OrderId.ToString("D"),
                        ["reason"] = request.Reason ?? string.Empty
                    }
                },
                new RequestOptions
                {
                    IdempotencyKey = $"economy-order-refund-{request.OrderId:D}"
                },
                cancellationToken);

            return Result.Success(new PaymentRefundResponse(refund.Id, refund.Status));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "refund_payment",
                orderId: request.OrderId,
                externalPaymentId: request.ExternalPaymentId);
            return Result.Failure<PaymentRefundResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch (Exception exception)
        {
            LogGatewayFailure(
                exception,
                "refund_payment",
                orderId: request.OrderId,
                externalPaymentId: request.ExternalPaymentId);
            return Result.Failure<PaymentRefundResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }

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

        var stripeClient = CreateStripeClient(apiKey);

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
                        request.UserId,
                        request.OrderId,
                        "create_payment_ephemeral_key",
                        cancellationToken);

                    if (ephemeralKeyResult.IsFailure)
                    {
                        return Result.Failure<PaymentCreateResponse>(ephemeralKeyResult.Error);
                    }

                    customerEphemeralKeySecret = ephemeralKeyResult.Value;
                }

                var paymentIntent = await new PaymentIntentService(stripeClient).CreateAsync(
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
            catch (StripeException exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_payment_sheet_payment_intent",
                    request.UserId,
                    request.OrderId,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: true);
                return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }
            catch (Exception exception)
            {
                LogGatewayFailure(
                    exception,
                    "create_payment_sheet_payment_intent",
                    request.UserId,
                    request.OrderId,
                    externalCustomerId: request.ExternalCustomerId,
                    usePaymentSheet: true);
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
            var service = new SessionService(stripeClient);
            var session = await service.CreateAsync(checkoutOptions, requestOptions, cancellationToken);

            return Result.Success(new PaymentCreateResponse(
                session.Id,
                session.Url ?? string.Empty));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "create_hosted_payment_checkout",
                request.UserId,
                request.OrderId,
                externalCustomerId: request.ExternalCustomerId,
                usePaymentSheet: false);
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
        catch (Exception exception)
        {
            LogGatewayFailure(
                exception,
                "create_hosted_payment_checkout",
                request.UserId,
                request.OrderId,
                externalCustomerId: request.ExternalCustomerId,
                usePaymentSheet: false);
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
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

        var stripeClient = CreateStripeClient(apiKey);

        var amountInMinorUnits = (long)decimal.Round(request.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero);

        try
        {
            var service = new PaymentIntentService(stripeClient);
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

            if (!IsSucceededPaymentIntentStatus(paymentIntent.Status))
            {
                LogGatewayWarning(
                    "Stripe gateway operation returned non-success status.",
                    "create_saved_method_payment_intent",
                    request.UserId,
                    request.OrderId,
                    externalCustomerId: request.ExternalCustomerId,
                    externalPaymentId: paymentIntent.Id,
                    externalPaymentMethodId: request.ExternalPaymentMethodId);
                return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
            }

            return Result.Success(new PaymentCreateResponse(paymentIntent.Id, string.Empty));
        }
        catch (StripeException exception)
        {
            LogGatewayFailure(
                exception,
                "create_saved_method_payment_intent",
                request.UserId,
                request.OrderId,
                externalCustomerId: request.ExternalCustomerId,
                externalPaymentMethodId: request.ExternalPaymentMethodId,
                usePaymentSheet: false);
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }
    }
}
