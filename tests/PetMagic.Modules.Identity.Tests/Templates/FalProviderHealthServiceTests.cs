using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FalProviderHealthServiceTests
{
    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenAdmissionIsPaused()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(admissionEnabled: false),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("admission_paused", result.Error.Metadata!["reason"]);
    }

    [Theory]
    [InlineData(false, TemplateAiProviders.Fal)]
    [InlineData(true, TemplateAiProviders.Fake)]
    public async Task EnsureCanAcceptGenerationAsync_ShouldRejectPausedAdmission_RegardlessOfSchedulerOrProvider(
        bool schedulerV2Enabled,
        string aiProvider)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(admissionEnabled: false),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m),
            CreateOptions(schedulerV2Enabled: schedulerV2Enabled, aiProvider: aiProvider));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "admin", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("admission_paused", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenEffectiveCapacityIsZero()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(effectiveGlobal: 0),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("effective_capacity_zero", result.Error.Metadata!["reason"]);
    }

    [Theory]
    [InlineData(TemplateProviderBalanceState.Critical, "balance_critical")]
    [InlineData(TemplateProviderBalanceState.Unknown, "balance_unknown")]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_ForBlockingBalanceState(
        TemplateProviderBalanceState balanceState,
        string expectedReason)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(),
            CreateSnapshot(balanceState, balanceUsd: balanceState == TemplateProviderBalanceState.Unknown ? null : 5m));

        var result = await service.EnsureCanAcceptGenerationAsync("video", "premium", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.Equal(expectedReason, result.Error.Metadata!["reason"]);
    }

    [Theory]
    [InlineData(TemplateProviderBalanceState.Fresh)]
    [InlineData(TemplateProviderBalanceState.Low)]
    [InlineData(TemplateProviderBalanceState.Stale)]
    public async Task EnsureCanAcceptGenerationAsync_ShouldPass_ForUsableBalanceState(
        TemplateProviderBalanceState balanceState)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(),
            CreateSnapshot(balanceState, balanceUsd: 9m, lastSuccessfulAtUtc: DateTime.UtcNow.AddMinutes(-4)));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenStaleBalanceExceededGracePeriod()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(),
            CreateSnapshot(
                TemplateProviderBalanceState.Stale,
                balanceUsd: 20m,
                lastSuccessfulAtUtc: DateTime.UtcNow.AddMinutes(-6)));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("balance_unknown", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldReject_WhenLastKnownStaleBalanceIsCritical()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(),
            CreateSnapshot(
                TemplateProviderBalanceState.Stale,
                balanceUsd: 5m,
                lastSuccessfulAtUtc: DateTime.UtcNow.AddMinutes(-1)));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("balance_critical", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldPass_WhenProviderSlotsAreAlreadyFull()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        for (var index = 0; index < 8; index++)
        {
            dbContext.TemplateGenerationProviderAttempts.Add(new TemplateGenerationProviderAttempt
            {
                Id = Guid.NewGuid(),
                GenerationJobId = Guid.NewGuid(),
                Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
                Ordinal = 1,
                State = TemplateGenerationProviderAttemptState.ProviderProcessing,
                Provider = "fal",
                SubmissionTokenHash = $"token-{index}",
                SubmissionDeadlineAtUtc = now.AddMinutes(1),
                ProcessingDeadlineAtUtc = now.AddMinutes(10),
                ReconciliationDeadlineAtUtc = now.AddMinutes(15),
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
        }
        await dbContext.SaveChangesAsync();

        var service = CreateService(
            dbContext,
            CreatePolicy(effectiveGlobal: 8),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldKeepRemainingCapacity_WhenOneSubmissionRequiresManualReconciliation()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        dbContext.TemplateGenerationProviderAttempts.Add(new TemplateGenerationProviderAttempt
        {
            Id = Guid.NewGuid(),
            GenerationJobId = Guid.NewGuid(),
            Stage = TemplateGenerationProviderAttemptStage.VideoGeneration,
            Ordinal = 1,
            State = TemplateGenerationProviderAttemptState.SubmissionUnknown,
            Provider = "fal",
            SubmissionTokenHash = "manual-reconciliation-token",
            NextPollAtUtc = null,
            SubmissionDeadlineAtUtc = now.AddMinutes(-10),
            ProcessingDeadlineAtUtc = now.AddMinutes(-5),
            ReconciliationDeadlineAtUtc = now.AddMinutes(-1),
            CreatedAtUtc = now.AddMinutes(-15),
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(
            dbContext,
            CreatePolicy(effectiveGlobal: 8),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldFailClosed_WhenManualReconciliationExhaustsCapacity()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        for (var index = 0; index < 8; index++)
        {
            dbContext.TemplateGenerationProviderAttempts.Add(new TemplateGenerationProviderAttempt
            {
                Id = Guid.NewGuid(),
                GenerationJobId = Guid.NewGuid(),
                Stage = TemplateGenerationProviderAttemptStage.VideoGeneration,
                Ordinal = 1,
                State = TemplateGenerationProviderAttemptState.SubmissionUnknown,
                Provider = "fal",
                SubmissionTokenHash = $"manual-reconciliation-token-{index}",
                NextPollAtUtc = null,
                SubmissionDeadlineAtUtc = now.AddMinutes(-10),
                ProcessingDeadlineAtUtc = now.AddMinutes(-5),
                ReconciliationDeadlineAtUtc = now.AddMinutes(-1),
                CreatedAtUtc = now.AddMinutes(-15),
                UpdatedAtUtc = now
            });
        }
        await dbContext.SaveChangesAsync();

        var service = CreateService(
            dbContext,
            CreatePolicy(effectiveGlobal: 8),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "premium", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, result.Error.Code);
        Assert.Equal("provider_reconciliation_required", result.Error.Metadata!["reason"]);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldContinue_WhenUnknownSubmissionHasScheduledReconciliation()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        dbContext.TemplateGenerationProviderAttempts.Add(new TemplateGenerationProviderAttempt
        {
            Id = Guid.NewGuid(),
            GenerationJobId = Guid.NewGuid(),
            Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
            Ordinal = 1,
            State = TemplateGenerationProviderAttemptState.SubmissionUnknown,
            Provider = "fal",
            SubmissionTokenHash = "scheduled-reconciliation-token",
            NextPollAtUtc = now.AddSeconds(30),
            SubmissionDeadlineAtUtc = now.AddMinutes(-1),
            ProcessingDeadlineAtUtc = now.AddMinutes(5),
            ReconciliationDeadlineAtUtc = now.AddMinutes(10),
            CreatedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(
            dbContext,
            CreatePolicy(effectiveGlobal: 8),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m));

        var result = await service.EnsureCanAcceptGenerationAsync("video", "premium", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldUseStaticConcurrency_WhenSchedulerV2IsDisabled()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(admissionEnabled: true, effectiveGlobal: 0),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m),
            CreateOptions(schedulerV2Enabled: false, falProviderConcurrencyLimit: 10));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task EnsureCanAcceptGenerationAsync_ShouldFailClosedWithoutStaticConcurrency_WhenSchedulerV2IsDisabled()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            CreatePolicy(),
            CreateSnapshot(TemplateProviderBalanceState.Fresh, balanceUsd: 20m),
            CreateOptions(schedulerV2Enabled: false, falProviderConcurrencyLimit: 0));

        var result = await service.EnsureCanAcceptGenerationAsync("image", "free", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("concurrency_unknown", result.Error.Metadata!["reason"]);
    }

    private static FalProviderHealthService CreateService(
        TemplatesDbContext dbContext,
        TemplateGenerationRuntimePolicySnapshot policy,
        TemplateProviderRuntimeSnapshot snapshot,
        TemplatesOptions? options = null)
    {
        return new FalProviderHealthService(
            dbContext,
            new StaticRuntimePolicyProvider(policy),
            new StaticRuntimeSnapshotService(snapshot),
            options ?? CreateOptions());
    }

    private static TemplateGenerationRuntimePolicySnapshot CreatePolicy(
        bool admissionEnabled = true,
        int effectiveGlobal = 8)
    {
        var profile = new TemplateGenerationConcurrencyProfile(
            effectiveGlobal,
            Math.Min(3, effectiveGlobal),
            Math.Min(3, effectiveGlobal),
            Math.Min(7, effectiveGlobal),
            Math.Min(2, effectiveGlobal),
            Math.Min(4, effectiveGlobal),
            Math.Min(2, effectiveGlobal),
            effectiveGlobal == 0 ? 0 : 1);
        return new TemplateGenerationRuntimePolicySnapshot(
            Revision: 1,
            AdmissionEnabled: admissionEnabled,
            ConfirmedFalConcurrencyLimit: 10,
            ConfirmedAtUtc: DateTime.UtcNow,
            ReservedHeadroom: 2,
            ApplicationHardCeiling: 38,
            BaseProfile: profile,
            EffectiveProfile: profile);
    }

    private static TemplateProviderRuntimeSnapshot CreateSnapshot(
        TemplateProviderBalanceState balanceState,
        decimal? balanceUsd,
        DateTime? lastSuccessfulAtUtc = null)
    {
        return new TemplateProviderRuntimeSnapshot
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            BalanceState = balanceState,
            CurrentBalanceUsd = balanceUsd,
            LastSuccessfulAtUtc = lastSuccessfulAtUtc ?? DateTime.UtcNow,
            CheckedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };
    }

    private static TemplatesOptions CreateOptions(
        bool schedulerV2Enabled = true,
        int falProviderConcurrencyLimit = 10,
        string aiProvider = TemplateAiProviders.Fal)
    {
        return new TemplatesOptions
        {
            AiProvider = aiProvider,
            GenerationSchedulerV2Enabled = schedulerV2Enabled,
            FalProviderConcurrencyLimit = falProviderConcurrencyLimit,
            FalProviderReservedConcurrency = 2,
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru"],
            FalProviderBalanceLowThresholdUsd = 10m,
            FalProviderBalanceCriticalThresholdUsd = 5m,
            Fal = new FalAiOptions { ApiKey = "test-fal-key" }
        };
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"fal-provider-health-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private sealed class StaticRuntimePolicyProvider(TemplateGenerationRuntimePolicySnapshot policy)
        : ITemplateGenerationRuntimePolicyProvider
    {
        public Task<TemplateGenerationRuntimePolicySnapshot> GetRuntimePolicyAsync(
            CancellationToken cancellationToken) => Task.FromResult(policy);
    }

    private sealed class StaticRuntimeSnapshotService(TemplateProviderRuntimeSnapshot snapshot)
        : IFalProviderRuntimeSnapshotService
    {
        public Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken) =>
            Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(snapshot);
    }
}
