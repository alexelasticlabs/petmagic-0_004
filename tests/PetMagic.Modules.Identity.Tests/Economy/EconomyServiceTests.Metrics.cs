using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Identity.Tests.Host;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task HandleStripeWebhookAsync_ShouldEmitFailureMetric_WhenSignatureIsInvalid()
    {
        using var recorder = new MeterMeasurementRecorder("PetMagic.Modules.Economy", "stripe_webhook_failures_total");
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.HandleStripeWebhookAsync(
            new StripeWebhookCommand("{}", "invalid-signature"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStripeSignature.Code, result.Error.Code);
        Assert.Contains(
            recorder.Measurements,
            measurement => measurement.InstrumentName == "stripe_webhook_failures_total"
                && measurement.Value == 1
                && Equals(measurement.Tags["error_code"], EconomyErrors.InvalidStripeSignature.Code)
                && Equals(measurement.Tags["stage"], "signature"));
    }
}
