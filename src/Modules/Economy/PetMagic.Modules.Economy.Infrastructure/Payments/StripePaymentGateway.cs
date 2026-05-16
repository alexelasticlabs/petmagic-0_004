using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;
using Stripe;
using Stripe.Checkout;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed class StripePaymentGateway(EconomyOptions options) : IPaymentGateway
{
    public async Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
    {
        if (!string.Equals(request.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (string.IsNullOrWhiteSpace(options.StripeSecretKey))
        {
            return Result.Failure<PaymentCreateResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        StripeConfiguration.ApiKey = options.StripeSecretKey;

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
}
