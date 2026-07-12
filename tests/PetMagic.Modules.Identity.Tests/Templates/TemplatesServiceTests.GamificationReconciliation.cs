using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ResolveLegacyDeliveryAsync_ShouldQueueIdempotentReplayAndWriteAudit()
    {
        await using var dbContext = CreateDbContext();
        var job = await AddLegacyGamificationReviewJobAsync(dbContext);
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateGenerationService(dbContext, adminAuditLog: auditLog);

        var healthBeforeResolution = await new GamificationLegacyDeliveryHealthCheck(dbContext)
            .CheckHealthAsync(new HealthCheckContext());
        Assert.Equal(HealthStatus.Degraded, healthBeforeResolution.Status);

        var result = await service.ResolveLegacyDeliveryAsync(
            Guid.NewGuid(),
            new AdminGamificationLegacyDeliveryResolutionCommand(job.Id, "replay", "Verified missing event ledger entry."),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.ReplayQueued);
        Assert.Null(job.GamificationProcessedAtUtc);
        Assert.Equal(0, job.GamificationAttemptCount);
        Assert.NotNull(job.GamificationNextAttemptAtUtc);
        Assert.Null(job.GamificationLastErrorCode);
        Assert.Contains(auditLog.Entries, entry => entry.Action == "admin.templates.gamification_legacy.replay");

        var healthAfterResolution = await new GamificationLegacyDeliveryHealthCheck(dbContext)
            .CheckHealthAsync(new HealthCheckContext());
        Assert.Equal(HealthStatus.Healthy, healthAfterResolution.Status);
    }

    [Fact]
    public async Task ResolveLegacyDeliveryAsync_ShouldKeepDeliverySuppressedWhenAdminConfirmsIt()
    {
        await using var dbContext = CreateDbContext();
        var job = await AddLegacyGamificationReviewJobAsync(dbContext);
        var service = CreateGenerationService(dbContext);

        var result = await service.ResolveLegacyDeliveryAsync(
            Guid.NewGuid(),
            new AdminGamificationLegacyDeliveryResolutionCommand(job.Id, "mark_delivered", "Verified against the historical support record."),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.ReplayQueued);
        Assert.NotNull(job.GamificationProcessedAtUtc);
        Assert.Equal(0, job.GamificationAttemptCount);
        Assert.Null(job.GamificationNextAttemptAtUtc);
        Assert.Null(job.GamificationLastErrorCode);
    }

    [Fact]
    public async Task ResolveLegacyDeliveryAsync_ShouldRejectUnreviewedGeneration()
    {
        await using var dbContext = CreateDbContext();
        var job = await AddLegacyGamificationReviewJobAsync(dbContext);
        job.GamificationAttemptCount = 0;
        await dbContext.SaveChangesAsync();
        var service = CreateGenerationService(dbContext);

        var result = await service.ResolveLegacyDeliveryAsync(
            Guid.NewGuid(),
            new AdminGamificationLegacyDeliveryResolutionCommand(job.Id, "replay", "Attempted duplicate resolution."),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.GamificationLegacyReviewNotRequired.Code, result.Error.Code);
    }

    private static async Task<TemplateGenerationJob> AddLegacyGamificationReviewJobAsync(TemplatesDbContext dbContext)
    {
        var now = DateTime.UtcNow;
        var job = new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            TemplateId = Guid.NewGuid(),
            Status = TemplateGenerationStatus.Completed,
            CreatedAtUtc = now.AddMinutes(-3),
            UpdatedAtUtc = now.AddMinutes(-1),
            CompletedAtUtc = now.AddMinutes(-2),
            GamificationProcessedAtUtc = now.AddMinutes(-2),
            GamificationAttemptCount = -1,
            GamificationLastErrorCode = "templates.gamification_legacy_review_required"
        };
        dbContext.TemplateGenerationJobs.Add(job);
        await dbContext.SaveChangesAsync();
        return job;
    }
}
