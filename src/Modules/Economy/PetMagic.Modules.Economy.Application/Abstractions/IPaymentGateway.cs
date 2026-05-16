using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IPaymentGateway
{
    Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken);
}

public sealed record PaymentCreateRequest(
    string Provider,
    Guid OrderId,
    Guid UserId,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string ProductName);

public sealed record PaymentCreateResponse(string ExternalPaymentId, string CheckoutUrl);
