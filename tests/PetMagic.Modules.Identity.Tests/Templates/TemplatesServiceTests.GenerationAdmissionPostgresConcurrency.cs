using System.Collections.Concurrent;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ConcurrentSameUserAdmission_ShouldRespectActiveQuotaOnPostgres()
    {
        var postgresOptions = TryCreateAdmissionPostgresOptions();
        if (postgresOptions is null)
        {
            return;
        }

        var templateId = await SeedAdmissionTemplateAsync(postgresOptions, "same-user");
        var userId = Guid.NewGuid();
        var billing = new ConcurrentAdmissionBilling();
        Guid[] createdJobIds = [];
        try
        {
            var baselineActive = await CountActiveGenerationsAsync(postgresOptions);
            var serviceOptions = CreateAdmissionOptions(baselineActive + 20);
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var tasks = Enumerable.Range(0, 8).Select(async index =>
            {
                await using var context = new TemplatesDbContext(postgresOptions);
                var service = CreateGenerationService(
                    context,
                    serviceOptions,
                    billing,
                    aiProviderHealthService: AdmissionAlwaysHealthy.Instance);
                await start.Task;
                return await service.StartAsync(
                    CreateAdmissionCommand(userId, templateId, index, activeLimit: 1),
                    CancellationToken.None);
            }).ToArray();

            start.TrySetResult();
            var results = await Task.WhenAll(tasks);
            createdJobIds = results.Where(result => result.IsSuccess)
                .Select(result => result.Value.GenerationId)
                .ToArray();

            Assert.Single(createdJobIds);
            Assert.Equal(7, results.Count(result =>
                result.IsFailure
                && result.Error.Code == TemplatesErrors.ActiveGenerationLimitReached.Code));
            Assert.Single(billing.ChargedGenerationIds);
        }
        finally
        {
            await CleanupAdmissionFixtureAsync(postgresOptions, templateId, createdJobIds);
        }
    }

    [Fact]
    public async Task ConcurrentAdmission_ShouldRespectGlobalQueueMaxOnPostgres()
    {
        var postgresOptions = TryCreateAdmissionPostgresOptions();
        if (postgresOptions is null)
        {
            return;
        }

        var templateId = await SeedAdmissionTemplateAsync(postgresOptions, "queue-max");
        var billing = new ConcurrentAdmissionBilling();
        Guid[] createdJobIds = [];
        try
        {
            var baselineActive = await CountActiveGenerationsAsync(postgresOptions);
            const int admittedCapacity = 3;
            var serviceOptions = CreateAdmissionOptions(baselineActive + admittedCapacity);
            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var tasks = Enumerable.Range(0, 8).Select(async index =>
            {
                await using var context = new TemplatesDbContext(postgresOptions);
                var service = CreateGenerationService(
                    context,
                    serviceOptions,
                    billing,
                    aiProviderHealthService: AdmissionAlwaysHealthy.Instance);
                await start.Task;
                return await service.StartAsync(
                    CreateAdmissionCommand(Guid.NewGuid(), templateId, index, activeLimit: 10),
                    CancellationToken.None);
            }).ToArray();

            start.TrySetResult();
            var results = await Task.WhenAll(tasks);
            createdJobIds = results.Where(result => result.IsSuccess)
                .Select(result => result.Value.GenerationId)
                .ToArray();

            Assert.Equal(admittedCapacity, createdJobIds.Length);
            Assert.Equal(5, results.Count(result =>
                result.IsFailure
                && result.Error.Code == TemplatesErrors.GenerationQueueOverloaded.Code));
            Assert.Equal(admittedCapacity, billing.ChargedGenerationIds.Count);
        }
        finally
        {
            await CleanupAdmissionFixtureAsync(postgresOptions, templateId, createdJobIds);
        }
    }

    [Fact]
    public async Task PausePolicyUpdate_ShouldLinearizeAfterInFlightAdmissionOnPostgres()
    {
        var postgresOptions = TryCreateAdmissionPostgresOptions();
        if (postgresOptions is null)
        {
            return;
        }

        var templateId = await SeedAdmissionTemplateAsync(postgresOptions, "pause-boundary");
        var actorUserId = Guid.NewGuid();
        var billing = new ConcurrentAdmissionBilling();
        Guid[] createdJobIds = [];
        TemplateGenerationControlPolicy? originalPolicy = null;
        var policyExisted = false;
        try
        {
            await using (var setupContext = new TemplatesDbContext(postgresOptions))
            {
                var current = await setupContext.TemplateGenerationControlPolicies
                    .AsNoTracking()
                    .SingleOrDefaultAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId);
                policyExisted = current is not null;
                originalPolicy = current is null ? null : ClonePolicy(current);
                var writable = current is null
                    ? TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow)
                    : await setupContext.TemplateGenerationControlPolicies
                        .SingleAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId);
                writable.AdmissionEnabled = true;
                writable.ConfirmedFalConcurrencyLimit = Math.Max(10, writable.ConfirmedFalConcurrencyLimit);
                writable.ReservedHeadroom = Math.Clamp(writable.ReservedHeadroom, 0, writable.ConfirmedFalConcurrencyLimit - 1);
                writable.ApplicationHardCeiling = Math.Max(8, writable.ApplicationHardCeiling);
                if (current is null)
                {
                    setupContext.TemplateGenerationControlPolicies.Add(writable);
                }

                await setupContext.SaveChangesAsync();
            }

            var baselineActive = await CountActiveGenerationsAsync(postgresOptions);
            var serviceOptions = CreateAdmissionOptions(baselineActive + 10);
            var enteredHealth = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var releaseHealth = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

            await using var admissionContext = new TemplatesDbContext(postgresOptions);
            await using var policyReadContext = new TemplatesDbContext(postgresOptions);
            var snapshot = new AdmissionRuntimeSnapshotService();
            var runtimePolicy = new TemplateGenerationControlService(
                policyReadContext,
                snapshot,
                serviceOptions,
                billing);
            var health = new BlockingDelegatingAdmissionHealthService(
                new FalProviderHealthService(policyReadContext, runtimePolicy, snapshot, serviceOptions),
                enteredHealth,
                releaseHealth);
            var generationService = CreateGenerationService(
                admissionContext,
                serviceOptions,
                billing,
                aiProviderHealthService: health);
            var admissionTask = generationService.StartAsync(
                CreateAdmissionCommand(Guid.NewGuid(), templateId, index: 1, activeLimit: 10),
                CancellationToken.None);

            await enteredHealth.Task.WaitAsync(TimeSpan.FromSeconds(10));

            await using var updateContext = new TemplatesDbContext(postgresOptions);
            var control = new TemplateGenerationControlService(
                updateContext,
                snapshot,
                serviceOptions,
                billing);
            var policyBeforePause = await updateContext.TemplateGenerationControlPolicies
                .AsNoTracking()
                .SingleAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId);
            var pauseTask = control.UpdatePolicyAsync(
                new UpdateAdminTemplateGenerationControlPolicyCommand(
                    actorUserId,
                    $"pause-boundary-{Guid.NewGuid():N}",
                    policyBeforePause.Revision,
                    "PostgreSQL admission boundary test",
                    AdmissionEnabled: false,
                    policyBeforePause.ConfirmedFalConcurrencyLimit,
                    policyBeforePause.ReservedHeadroom,
                    policyBeforePause.ApplicationHardCeiling,
                    ConfirmFalConcurrencyLimit: false),
                CancellationToken.None);

            await Task.Delay(200);
            Assert.False(pauseTask.IsCompleted);

            releaseHealth.TrySetResult();
            var admitted = await admissionTask;
            var paused = await pauseTask;
            Assert.True(admitted.IsSuccess);
            Assert.True(paused.IsSuccess);
            createdJobIds = [admitted.Value.GenerationId];

            await using var rejectedContext = new TemplatesDbContext(postgresOptions);
            await using var rejectedPolicyContext = new TemplatesDbContext(postgresOptions);
            var rejectedRuntimePolicy = new TemplateGenerationControlService(
                rejectedPolicyContext,
                snapshot,
                serviceOptions,
                billing);
            var rejectedHealth = new FalProviderHealthService(
                rejectedPolicyContext,
                rejectedRuntimePolicy,
                snapshot,
                serviceOptions);
            var rejectedService = CreateGenerationService(
                rejectedContext,
                serviceOptions,
                billing,
                aiProviderHealthService: rejectedHealth);
            var rejected = await rejectedService.StartAsync(
                CreateAdmissionCommand(Guid.NewGuid(), templateId, index: 2, activeLimit: 10),
                CancellationToken.None);

            Assert.True(rejected.IsFailure);
            Assert.Equal(TemplatesErrors.ProviderCapacityUnavailable.Code, rejected.Error.Code);
            Assert.Single(billing.ChargedGenerationIds);
        }
        finally
        {
            await CleanupAdmissionFixtureAsync(postgresOptions, templateId, createdJobIds);
            await RestoreAdmissionPolicyAsync(postgresOptions, policyExisted, originalPolicy, actorUserId);
        }
    }

    private static DbContextOptions<TemplatesDbContext>? TryCreateAdmissionPostgresOptions()
    {
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString)
            ? null
            : new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql(connectionString)
                .Options;
    }

    private static TemplatesOptions CreateAdmissionOptions(int queueMaxSize) => CreateTemplatesOptions(
        queueMaxSize: queueMaxSize,
        globalMaxConcurrentGenerations: 100,
        imageMaxConcurrentGenerations: 100,
        videoMaxConcurrentGenerations: 100,
        freeImageMaxEstimatedWaitSeconds: 10_000_000,
        premiumImageMaxEstimatedWaitSeconds: 10_000_000,
        freeVideoMaxEstimatedWaitSeconds: 10_000_000,
        premiumVideoMaxEstimatedWaitSeconds: 10_000_000);

    private static StartTemplateGenerationCommand CreateAdmissionCommand(
        Guid userId,
        Guid templateId,
        int index,
        int activeLimit) => new(
        userId,
        templateId,
        new TemplateAssetCommand(
            $"https://cdn.example.test/admission-source-{index}.jpg",
            $"admission-source-{index}.jpg",
            "image/jpeg",
            2_048,
            null),
        $"admission-key-{index}-{Guid.NewGuid():N}",
        $"admission-hash-{index}-{Guid.NewGuid():N}",
        activeLimit);

    private static async Task<Guid> SeedAdmissionTemplateAsync(
        DbContextOptions<TemplatesDbContext> options,
        string suffix)
    {
        await using var context = new TemplatesDbContext(options);
        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            Version = 1,
            TemplateType = TemplateType.Image,
            Title = $"Admission PostgreSQL {suffix} {Guid.NewGuid():N}",
            ShortDescription = "PostgreSQL admission concurrency fixture.",
            Category = "Concurrency",
            Tags = "admission,postgresql",
            TokenCost = 20,
            Status = TemplateStatus.Active,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            PublishedAtUtc = now,
            UpdatedAtUtc = now
        };
        context.TemplateItems.Add(template);
        await context.SaveChangesAsync();
        return template.Id;
    }

    private static async Task<int> CountActiveGenerationsAsync(DbContextOptions<TemplatesDbContext> options)
    {
        await using var context = new TemplatesDbContext(options);
        return await context.TemplateGenerationJobs.CountAsync(job =>
            TemplateGenerationJobStatusSets.Active.Contains(job.Status));
    }

    private static async Task CleanupAdmissionFixtureAsync(
        DbContextOptions<TemplatesDbContext> options,
        Guid templateId,
        IReadOnlyCollection<Guid> jobIds)
    {
        await using var context = new TemplatesDbContext(options);
        if (jobIds.Count > 0)
        {
            await context.TemplateGenerationJobs
                .Where(job => jobIds.Contains(job.Id))
                .ExecuteDeleteAsync();
        }

        await context.TemplateItems
            .Where(template => template.Id == templateId)
            .ExecuteDeleteAsync();
    }

    private static TemplateGenerationControlPolicy ClonePolicy(TemplateGenerationControlPolicy source) => new()
    {
        Id = source.Id,
        Revision = source.Revision,
        AdmissionEnabled = source.AdmissionEnabled,
        ConfirmedFalConcurrencyLimit = source.ConfirmedFalConcurrencyLimit,
        ConfirmedAtUtc = source.ConfirmedAtUtc,
        ReservedHeadroom = source.ReservedHeadroom,
        ApplicationHardCeiling = source.ApplicationHardCeiling,
        BaseGlobalMaxConcurrentGenerations = source.BaseGlobalMaxConcurrentGenerations,
        BaseImageReservedConcurrentGenerations = source.BaseImageReservedConcurrentGenerations,
        BaseImageProtectedConcurrentGenerations = source.BaseImageProtectedConcurrentGenerations,
        BaseImageMaxConcurrentGenerations = source.BaseImageMaxConcurrentGenerations,
        BaseVideoReservedConcurrentGenerations = source.BaseVideoReservedConcurrentGenerations,
        BaseVideoMaxConcurrentGenerations = source.BaseVideoMaxConcurrentGenerations,
        BaseVideoBorrowMaxConcurrentGenerations = source.BaseVideoBorrowMaxConcurrentGenerations,
        BaseVideoPreprocessingMaxConcurrentGenerations = source.BaseVideoPreprocessingMaxConcurrentGenerations,
        UpdatedAtUtc = source.UpdatedAtUtc,
        UpdatedByAdminUserId = source.UpdatedByAdminUserId,
        LastReason = source.LastReason
    };

    private static async Task RestoreAdmissionPolicyAsync(
        DbContextOptions<TemplatesDbContext> options,
        bool policyExisted,
        TemplateGenerationControlPolicy? original,
        Guid actorUserId)
    {
        await using var context = new TemplatesDbContext(options);
        var receipts = await context.TemplateGenerationControlPolicyCommandReceipts
            .Where(receipt => receipt.ActorUserId == actorUserId)
            .ToArrayAsync();
        var deduplicationKeys = receipts
            .Select(receipt => $"templates_admin_audit:{receipt.Id:D}")
            .ToArray();
        if (deduplicationKeys.Length > 0)
        {
            await context.PushOutboxMessages
                .Where(message => deduplicationKeys.Contains(message.DeduplicationKey))
                .ExecuteDeleteAsync();
            context.TemplateGenerationControlPolicyCommandReceipts.RemoveRange(receipts);
            await context.SaveChangesAsync();
        }

        var current = await context.TemplateGenerationControlPolicies
            .SingleOrDefaultAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId);
        if (!policyExisted)
        {
            if (current is not null)
            {
                context.TemplateGenerationControlPolicies.Remove(current);
                await context.SaveChangesAsync();
            }

            return;
        }

        if (current is null || original is null)
        {
            throw new InvalidOperationException("Generation control policy disappeared during PostgreSQL admission test.");
        }

        context.Entry(current).CurrentValues.SetValues(original);
        await context.SaveChangesAsync();
    }

    private sealed class ConcurrentAdmissionBilling : ITemplateGenerationBilling
    {
        public ConcurrentBag<Guid> ChargedGenerationIds { get; } = [];

        public Task<Result> ChargeAsync(
            Guid userId,
            Guid generationId,
            int tokenCost,
            CancellationToken cancellationToken)
        {
            ChargedGenerationIds.Add(generationId);
            return Task.FromResult(Result.Success());
        }

        public Task<Result> RefundAsync(
            Guid userId,
            Guid generationId,
            int tokenCost,
            CancellationToken cancellationToken) => Task.FromResult(Result.Success());

        public Task<Result<int>> SpendWatermarkUnlockAsync(
            Guid userId,
            Guid generationId,
            int creditCost,
            CancellationToken cancellationToken) => Task.FromResult(Result.Success(creditCost));
    }

    private sealed class AdmissionAlwaysHealthy : ITemplateAiProviderHealthService
    {
        public static readonly AdmissionAlwaysHealthy Instance = new();

        public Task<Result> EnsureCanAcceptGenerationAsync(
            string mediaType,
            string tier,
            CancellationToken cancellationToken) => Task.FromResult(Result.Success());
    }

    private sealed class BlockingDelegatingAdmissionHealthService(
        ITemplateAiProviderHealthService inner,
        TaskCompletionSource entered,
        TaskCompletionSource release) : ITemplateAiProviderHealthService
    {
        public async Task<Result> EnsureCanAcceptGenerationAsync(
            string mediaType,
            string tier,
            CancellationToken cancellationToken)
        {
            entered.TrySetResult();
            await release.Task.WaitAsync(cancellationToken);
            return await inner.EnsureCanAcceptGenerationAsync(mediaType, tier, cancellationToken);
        }
    }

    private sealed class AdmissionRuntimeSnapshotService : IFalProviderRuntimeSnapshotService
    {
        private readonly TemplateProviderRuntimeSnapshot snapshot = new()
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Fresh,
            StatusChangedAtUtc = DateTime.UtcNow,
            CurrentBalanceUsd = 20m,
            LastSuccessfulAtUtc = DateTime.UtcNow,
            CheckedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };

        public Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken) =>
            Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(snapshot);
    }
}
