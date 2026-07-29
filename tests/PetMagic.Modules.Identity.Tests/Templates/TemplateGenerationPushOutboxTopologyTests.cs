using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task GenerationTerminalPush_ShouldEnqueueWithoutFirebaseCredentialsOnWorker()
    {
        await using var dbContext = CreateDbContext();
        var generationId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var generation = new TemplateGenerationResponse(
            GenerationId: generationId,
            UserId: userId,
            TemplateId: Guid.NewGuid(),
            Status: "Completed",
            TokenCost: 1,
            SourceImageAsset: null,
            NormalizedImageUrl: null,
            ReferenceMotionUrl: null,
            OutputUrl: "https://pub-123.r2.dev/generation.png",
            AttemptCount: 1,
            UsedPreprocessingModel: null,
            UsedKlingModel: null,
            PreprocessingProviderRequestId: null,
            PreprocessingInferenceTimeSeconds: null,
            MotionProviderRequestId: null,
            MotionInferenceTimeSeconds: null,
            OutputVideoDurationSeconds: null,
            MotionProviderCostUsd: null,
            FailureCode: null,
            FailureMessage: null,
            CreatedAtUtc: now,
            UpdatedAtUtc: now,
            StartedAtUtc: now,
            PreprocessingCompletedAtUtc: null,
            MotionGenerationCompletedAtUtc: null,
            MediaImportCompletedAtUtc: now,
            CompletedAtUtc: now,
            UserMediaExpired: false);
        var outbox = new TemplateGenerationPushNotificationOutbox(dbContext);

        await outbox.NotifyGenerationTerminalAsync(generation, CancellationToken.None);
        await outbox.NotifyGenerationTerminalAsync(generation, CancellationToken.None);

        var message = Assert.Single(dbContext.PushOutboxMessages.Local);
        Assert.Equal($"template_generation:{generationId:D}:Completed", message.DeduplicationKey);
        Assert.Equal("generation_terminal", message.Kind);
        Assert.Equal(userId, message.UserId);
        Assert.Equal(PushOutboxStatus.Queued, message.Status);
    }
}
