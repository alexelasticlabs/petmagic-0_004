using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Options;

using Microsoft.Extensions.Logging;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public sealed partial class StripePaymentGateway : IPaymentGateway
{
    public const string HttpClientName = "Stripe";

    private const string Provider = "stripe";
    private const string MobileEphemeralKeyStripeVersion = "2020-03-02";
    private readonly EconomyOptions options;
    private readonly IHttpClientFactory httpClientFactory;
    private readonly ILogger<StripePaymentGateway>? logger;

    public StripePaymentGateway(
        EconomyOptions options,
        IHttpClientFactory httpClientFactory,
        ILogger<StripePaymentGateway>? logger = null)
    {
        this.options = options;
        this.httpClientFactory = httpClientFactory;
        this.logger = logger;
    }
}
