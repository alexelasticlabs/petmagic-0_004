using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateGenerationService
{
    Task<Result<TemplateGenerationResponse>> StartAsync(StartTemplateGenerationCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartFromResultAsync(StartTemplateGenerationFromResultCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartSimilarAsync(StartSimilarTemplateGenerationCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartFromPetAsync(StartTemplateGenerationFromPetCommand command, CancellationToken cancellationToken);

    Task<Result<CompatibleGenerationTemplatesResponse>> GetCompatibleTemplatesAsync(Guid userId, Guid resultId, CancellationToken cancellationToken);

    Task<Result<CancelQueuedGenerationResponse>> CancelQueuedAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> StartAdminTestAsync(Guid templateId, TemplateAssetCommand sourceImageAsset, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, bool isPremium, CancellationToken cancellationToken);

    Task<Result<GalleryPageResponse>> ListPageAsync(Guid userId, TemplateGenerationHistoryQuery query, bool isPremium, CancellationToken cancellationToken);

    Task<Result<RemoveGenerationWatermarkResponse>> RemoveWatermarkAsync(RemoveGenerationWatermarkCommand command, CancellationToken cancellationToken);

    Task<Result<GalleryDownloadResponse>> GetDownloadAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken);

    Task<Result<GalleryShareResponse>> GetShareAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken);

    Task<Result<PublicGalleryShareResponse>> GetPublicShareAsync(string shareToken, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationUnreadCountResponse>> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> MarkReadAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(Guid userId, Guid generationId, CancellationToken cancellationToken);

    Task<Result> RecordFeedbackAsync(RecordTemplateGenerationFeedbackCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken);

    Task<Result<RemoveGenerationWatermarkResponse>> GrantAdminCleanDownloadAsync(Guid adminUserId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> CancelAdminQueuedAsync(Guid adminUserId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<AdminGenerationCancellationResult>> CancelAdminAsync(Guid adminUserId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> RetryAdminGenerationAsync(Guid adminUserId, Guid generationId, CancellationToken cancellationToken);

    Task<Result<TemplateGenerationResponse>> RetryAdminGenerationRefundAsync(Guid adminUserId, Guid generationId, CancellationToken cancellationToken);
}

public interface ITemplateGenerationGamificationReconciliationService
{
    Task<Result<AdminGamificationLegacyDeliveryResolutionResponse>> ResolveLegacyDeliveryAsync(
        Guid adminUserId,
        AdminGamificationLegacyDeliveryResolutionCommand command,
        CancellationToken cancellationToken);
}

public interface ITemplateGenerationQaFixtureService
{
    Task<Result<QaGenerationFixturesResponse>> CreateAsync(
        Guid userId,
        CreateQaGenerationFixturesCommand command,
        CancellationToken cancellationToken);

    Task<Result<QaGenerationFixtureCleanupResponse>> CleanupAsync(
        Guid userId,
        CancellationToken cancellationToken);
}

public interface ITemplateGenerationProviderCallbackService
{
    Task<Result<FalProviderWebhookResponse>> ProcessFalWebhookAsync(
        FalProviderWebhookCommand command,
        CancellationToken cancellationToken);
}

public interface ITemplatePushTokenService
{
    Task<Result> RegisterAsync(RegisterTemplatePushTokenCommand command, CancellationToken cancellationToken);

    Task<Result> UnregisterAsync(UnregisterTemplatePushTokenCommand command, CancellationToken cancellationToken);
}

public interface IFeedbackService
{
    Task<Result<SubmitFeedbackResponse>> SubmitAsync(SubmitFeedbackCommand command, CancellationToken cancellationToken);

    Task<Result<AdminFeedbackPageResponse>> ListAdminAsync(AdminFeedbackQuery query, CancellationToken cancellationToken);

    Task<Result<AdminFeedbackDetailsResponse>> GetAdminAsync(Guid feedbackId, CancellationToken cancellationToken);

    Task<Result<AdminFeedbackDetailsResponse>> UpdateAdminAsync(UpdateFeedbackAdminCommand command, CancellationToken cancellationToken);

    Task<Result<CreditRefundResponse>> RefundCreditsAsync(RefundFeedbackCreditsCommand command, CancellationToken cancellationToken);

    Task<Result<TemplateFeedbackSummaryResponse>> GetTemplateSummaryAsync(Guid templateId, CancellationToken cancellationToken);
}
