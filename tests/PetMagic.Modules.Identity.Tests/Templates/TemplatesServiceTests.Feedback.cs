using System.Reflection;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task SubmitFeedbackAsync_ShouldAttachGenerationContextAndRejectForeignGeneration()
    {
        await using var dbContext = CreateDbContext();
        var templateService = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var generation = await CreateCompletedImageGenerationAsync(dbContext, templateService, userId);
        generation.PetId = petId;
        generation.LastErrorCode = "templates.ai_provider_failed";
        generation.PreprocessingProviderRequestId = "provider-request-1";
        await dbContext.SaveChangesAsync();
        var feedbackService = CreateFeedbackService(dbContext);

        var forbidden = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                otherUserId,
                "GenerationFailure",
                "too_long",
                null,
                "It never finished",
                generation.Id,
                null,
                null,
                "generation_status",
                "1.2.3",
                "ios",
                "iPhone",
                "ru-RU"),
            CancellationToken.None);

        Assert.True(forbidden.IsFailure);
        Assert.Equal(TemplatesErrors.FeedbackForbidden.Code, forbidden.Error.Code);

        var submitted = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                userId,
                "GenerationFailure",
                "too_long",
                -1,
                "It never finished",
                generation.Id,
                null,
                null,
                "generation_status",
                "1.2.3",
                "ios",
                "iPhone",
                "ru-RU"),
            CancellationToken.None);

        Assert.True(submitted.IsSuccess);
        var persisted = await dbContext.TemplateGenerationFeedback.SingleAsync();
        Assert.Equal(userId, persisted.UserId);
        Assert.Equal("GenerationFailure", persisted.Type);
        Assert.Equal("too_long", persisted.Category);
        Assert.Equal(-1, persisted.Rating);
        Assert.Equal(generation.Id, persisted.GenerationId);
        Assert.Equal(generation.TemplateId, persisted.TemplateId);
        Assert.Equal(petId, persisted.PetId);
        Assert.Equal("templates.ai_provider_failed", persisted.ErrorCode);
        Assert.Equal("fal", persisted.ProviderName);
        Assert.Equal("New", persisted.Status);
        Assert.Equal("Medium", persisted.Priority);

        var details = await feedbackService.GetAdminAsync(submitted.Value.FeedbackId, CancellationToken.None);
        Assert.True(details.IsSuccess);
        Assert.Equal(generation.Id, details.Value.Generation?.GenerationId);
        Assert.Equal(generation.TemplateId, details.Value.Generation?.TemplateId);
        Assert.Equal(generation.SourceImageUrl, details.Value.Generation?.InputPreviewUrl);
        Assert.Equal(generation.WatermarkedResultUrl, details.Value.Generation?.ResultPreviewUrl);
        Assert.Equal("templates.ai_provider_failed", details.Value.Generation?.ErrorCode);

        var analytics = await dbContext.TemplateAnalyticsEvents.SingleAsync();
        Assert.Equal(TemplateAnalyticsEventTypes.FeedbackSubmitted, analytics.EventType);
        using var metadata = JsonDocument.Parse(analytics.MetadataJson!);
        Assert.Equal("GenerationFailure", metadata.RootElement.GetProperty("feedbackType").GetString());
        Assert.Equal("too_long", metadata.RootElement.GetProperty("category").GetString());
        Assert.Equal(-1, metadata.RootElement.GetProperty("rating").GetInt32());
        Assert.Equal(generation.Id, metadata.RootElement.GetProperty("generationId").GetGuid());
        Assert.Equal("ios", metadata.RootElement.GetProperty("platform").GetString());
    }

    [Fact]
    public async Task SubmitFeedbackAsync_ShouldRateLimitPerGenerationAndGeneralFeedback()
    {
        await using var dbContext = CreateDbContext();
        var templateService = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var generation = await CreateCompletedImageGenerationAsync(dbContext, templateService, userId);
        var feedbackService = CreateFeedbackService(dbContext);

        for (var i = 0; i < 3; i++)
        {
            var accepted = await feedbackService.SubmitAsync(
                new SubmitFeedbackCommand(
                    userId,
                    "GenerationResult",
                    $"quality_{i}",
                    -1,
                    null,
                    generation.Id,
                    null,
                    null,
                    "generation_result",
                    "1.2.3",
                    "android",
                    "Pixel",
                    "en-US"),
                CancellationToken.None);
            Assert.True(accepted.IsSuccess);
        }

        var generationLimited = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                userId,
                "GenerationResult",
                "quality_3",
                -1,
                null,
                generation.Id,
                null,
                null,
                "generation_result",
                "1.2.3",
                "android",
                "Pixel",
                "en-US"),
            CancellationToken.None);

        Assert.True(generationLimited.IsFailure);
        Assert.Equal(TemplatesErrors.FeedbackRateLimited.Code, generationLimited.Error.Code);

        for (var i = 0; i < 5; i++)
        {
            var accepted = await feedbackService.SubmitAsync(
                new SubmitFeedbackCommand(
                    userId,
                    "General",
                    $"suggestion_{i}",
                    null,
                    "Please improve this",
                    null,
                    null,
                    null,
                    "settings",
                    "1.2.3",
                    "android",
                    "Pixel",
                    "en-US"),
                CancellationToken.None);
            Assert.True(accepted.IsSuccess);
        }

        var generalLimited = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                userId,
                "General",
                "suggestion_5",
                null,
                "Please improve this too",
                null,
                null,
                null,
                "settings",
                "1.2.3",
                "android",
                "Pixel",
                "en-US"),
            CancellationToken.None);

        Assert.True(generalLimited.IsFailure);
        Assert.Equal(TemplatesErrors.FeedbackRateLimited.Code, generalLimited.Error.Code);
    }

    [Fact]
    public async Task RefundCreditsAsync_ShouldCreditOnceAndLogAdminContext()
    {
        await using var dbContext = CreateDbContext();
        var templateService = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var generation = await CreateCompletedImageGenerationAsync(dbContext, templateService, userId);
        generation.ChargedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        generation.TokenCost = 20;
        await dbContext.SaveChangesAsync();
        var feedbackService = CreateFeedbackService(dbContext, out var economyProxy);

        var submitted = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                userId,
                "BugReport",
                "low_quality",
                -1,
                "Bad quality",
                generation.Id,
                null,
                null,
                "result",
                "1.2.3",
                "ios",
                "iPhone",
                "en-US"),
            CancellationToken.None);
        Assert.True(submitted.IsSuccess);

        var refunded = await feedbackService.RefundCreditsAsync(
            new RefundFeedbackCreditsCommand(submitted.Value.FeedbackId, adminId, 7, "admin approved"),
            CancellationToken.None);

        Assert.True(refunded.IsSuccess);
        Assert.Equal(7, refunded.Value.Amount);
        Assert.Equal(adminId, refunded.Value.AdminId);
        Assert.Equal("admin approved", refunded.Value.Reason);
        var credit = Assert.Single(economyProxy.CreditCommands);
        Assert.Equal(userId, credit.UserId);
        Assert.Equal(7, credit.Amount);
        Assert.Equal(WalletLedgerSource.GenerationRefund, credit.Source);

        var persistedRefund = await dbContext.CreditRefunds.SingleAsync();
        Assert.Equal(submitted.Value.FeedbackId, persistedRefund.FeedbackId);
        Assert.Equal(generation.Id, persistedRefund.GenerationId);
        Assert.Equal(adminId, persistedRefund.AdminId);

        var duplicate = await feedbackService.RefundCreditsAsync(
            new RefundFeedbackCreditsCommand(submitted.Value.FeedbackId, adminId, 7, "duplicate"),
            CancellationToken.None);
        Assert.True(duplicate.IsFailure);
        Assert.Equal(TemplatesErrors.FeedbackRefundAlreadyIssued.Code, duplicate.Error.Code);

        var details = await feedbackService.GetAdminAsync(submitted.Value.FeedbackId, CancellationToken.None);
        Assert.True(details.IsSuccess);
        Assert.Equal("Resolved", details.Value.Status);
        Assert.False(details.Value.CanRefund);
        Assert.NotNull(details.Value.Refund);
    }

    [Theory]
    [InlineData("status", "not_open")]
    [InlineData("priority", "urgent")]
    [InlineData("type", "Other")]
    public async Task ListAdminAsync_ShouldRejectInvalidAdminFiltersWithoutFallback(string filterName, string filterValue)
    {
        await using var dbContext = CreateDbContext();
        var feedbackService = CreateFeedbackService(dbContext);

        var query = filterName switch
        {
            "status" => new AdminFeedbackQuery(filterValue, null, null, null, null, null, null, null, null, null, null, null),
            "priority" => new AdminFeedbackQuery(null, filterValue, null, null, null, null, null, null, null, null, null, null),
            _ => new AdminFeedbackQuery(null, null, filterValue, null, null, null, null, null, null, null, null, null)
        };

        var result = await feedbackService.ListAdminAsync(query, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal($"feedback.invalid_{filterName}", result.Error.Code);
    }

    [Fact]
    public async Task UpdateAdminAsync_ShouldRejectInvalidStatusAndPriorityWithoutFallback()
    {
        await using var dbContext = CreateDbContext();
        var templateService = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var generation = await CreateCompletedImageGenerationAsync(dbContext, templateService, userId);
        var feedbackService = CreateFeedbackService(dbContext);
        var submitted = await feedbackService.SubmitAsync(
            new SubmitFeedbackCommand(
                userId,
                "BugReport",
                "quality",
                -1,
                "Bad quality",
                generation.Id,
                null,
                null,
                "result",
                "1.2.3",
                "ios",
                "iPhone",
                "en-US"),
            CancellationToken.None);

        Assert.True(submitted.IsSuccess);

        var invalidStatus = await feedbackService.UpdateAdminAsync(
            new UpdateFeedbackAdminCommand(submitted.Value.FeedbackId, Guid.NewGuid(), "not_open", null, null),
            CancellationToken.None);
        var invalidPriority = await feedbackService.UpdateAdminAsync(
            new UpdateFeedbackAdminCommand(submitted.Value.FeedbackId, Guid.NewGuid(), null, "urgent", null),
            CancellationToken.None);

        Assert.True(invalidStatus.IsFailure);
        Assert.Equal(TemplatesErrors.InvalidFeedbackStatus.Code, invalidStatus.Error.Code);
        Assert.True(invalidPriority.IsFailure);
        Assert.Equal(TemplatesErrors.InvalidFeedbackPriority.Code, invalidPriority.Error.Code);

        var persisted = await dbContext.TemplateGenerationFeedback.SingleAsync();
        Assert.Equal("New", persisted.Status);
        Assert.Equal("Medium", persisted.Priority);
    }

    private static FeedbackService CreateFeedbackService(TemplatesDbContext dbContext)
    {
        return CreateFeedbackService(dbContext, out _);
    }

    private static FeedbackService CreateFeedbackService(
        TemplatesDbContext dbContext,
        out RecordingEconomyServiceProxy economyProxy)
    {
        var economyService = RecordingEconomyServiceProxy.Create(out economyProxy);
        return new FeedbackService(dbContext, economyService);
    }

    private class RecordingEconomyServiceProxy : DispatchProxy
    {
        public List<CreditBalanceCommand> CreditCommands { get; } = [];

        public static IEconomyService Create(out RecordingEconomyServiceProxy proxy)
        {
            var service = Create<IEconomyService, RecordingEconomyServiceProxy>();
            proxy = (RecordingEconomyServiceProxy)(object)service;
            return service;
        }

        protected override object Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(IEconomyService.CreditAsync)
                && args is [CreditBalanceCommand command, CancellationToken])
            {
                CreditCommands.Add(command);
                return Task.FromResult(Result.Success(new WalletOperationResponse(
                    command.UserId,
                    command.Amount,
                    command.Amount,
                    command.Source,
                    DateTime.UtcNow,
                    null,
                    0)));
            }

            throw new NotImplementedException(targetMethod?.Name);
        }
    }
}
