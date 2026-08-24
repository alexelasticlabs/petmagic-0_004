using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalProviderRuntimeHealthCheckTests
{
    [Fact]
    public async Task CheckHealthAsync_ShouldDegradeAndExposeSafeErrorWhenBalanceIsUnknown()
    {
        await using var dbContext = CreateDbContext();
        dbContext.TemplateProviderRuntimeSnapshots.Add(new TemplateProviderRuntimeSnapshot
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Unknown,
            CurrentBalanceUsd = 16.47m,
            CheckedAtUtc = DateTime.UtcNow,
            ConsecutiveFailures = 7,
            LastErrorCode = "authentication_failed",
            StatusChangedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var result = await new FalProviderRuntimeHealthCheck(dbContext, CreateOptions())
            .CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Degraded, result.Status);
        Assert.Equal("unknown", result.Data["state"]);
        Assert.Equal("authentication_failed", result.Data["lastErrorCode"]);
        Assert.Equal(7, result.Data["consecutiveFailures"]);
        Assert.DoesNotContain("currentBalanceUsd", result.Data.Keys);
    }

    [Fact]
    public async Task CheckHealthAsync_ShouldBeHealthyForFreshSnapshotWithoutPublishingBalance()
    {
        await using var dbContext = CreateDbContext();
        dbContext.TemplateProviderRuntimeSnapshots.Add(new TemplateProviderRuntimeSnapshot
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Fresh,
            CurrentBalanceUsd = 16.47m,
            LastSuccessfulAtUtc = DateTime.UtcNow,
            CheckedAtUtc = DateTime.UtcNow,
            StatusChangedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var result = await new FalProviderRuntimeHealthCheck(dbContext, CreateOptions())
            .CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Healthy, result.Status);
        Assert.Equal("fresh", result.Data["state"]);
        Assert.DoesNotContain("currentBalanceUsd", result.Data.Keys);
    }

    [Fact]
    public async Task CheckHealthAsync_ShouldBeHealthyWhenFalProviderIsNotSelected()
    {
        await using var dbContext = CreateDbContext();

        var result = await new FalProviderRuntimeHealthCheck(
                dbContext,
                CreateOptions(aiProvider: TemplateAiProviders.Fake))
            .CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Healthy, result.Status);
        Assert.Equal("not_applicable", result.Data["state"]);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"fal-provider-runtime-health-{Guid.NewGuid():N}")
            .Options;
        return new TemplatesDbContext(options);
    }

    private static TemplatesOptions CreateOptions(string aiProvider = TemplateAiProviders.Fal) => new()
    {
        AiProvider = aiProvider,
        PublicBaseUrl = "http://localhost:5000",
        LocalMediaRootPath = "wwwroot/templates-media",
        DefaultImagePrompt = "Create a themed pet portrait.",
        DefaultPreprocessingPrompt = "Keep the same pet.",
        DefaultKlingPrompt = "Funny dance.",
        AllowedImageModels = ["openai/gpt-image-2/edit"],
        AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
        AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
        SupportedLocalizationLocales = ["ru"],
        Fal = new FalAiOptions { ApiKey = "test-fal-key" }
    };
}
