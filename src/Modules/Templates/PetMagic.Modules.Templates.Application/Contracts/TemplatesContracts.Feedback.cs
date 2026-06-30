using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record RecordTemplateGenerationFeedbackCommand(
    Guid UserId,
    Guid GenerationId,
    int Rating,
    string[] SelectedReasons,
    string? Comment,
    double? InputPhotoQualityScore = null);

public sealed record SubmitFeedbackCommand(
    Guid? UserId,
    string Type,
    string Category,
    int? Rating,
    string? Message,
    Guid? GenerationId,
    Guid? TemplateId,
    Guid? PetId,
    string? SourceScreen,
    string? AppVersion,
    string? Platform,
    string? DeviceModel,
    string? Locale);

public sealed record SubmitFeedbackResponse(Guid FeedbackId, string Status);

public sealed record AdminFeedbackQuery(
    string? Status,
    string? Priority,
    string? Type,
    string? Category,
    Guid? GenerationId,
    Guid? TemplateId,
    string? Platform,
    DateTime? FromUtc,
    DateTime? ToUtc,
    Guid? UserId,
    int? Skip,
    int? Take);

public sealed record AdminFeedbackListItemResponse(
    Guid Id,
    Guid? UserId,
    string Type,
    string Category,
    int? Rating,
    Guid? GenerationId,
    Guid? TemplateId,
    string? TemplateTitle,
    Guid? PetId,
    string SourceScreen,
    string? Platform,
    string Status,
    string Priority,
    string? Message,
    string? PreviewUrl,
    DateTime CreatedAtUtc);

public sealed record AdminFeedbackPageResponse(
    IReadOnlyList<AdminFeedbackListItemResponse> Items,
    int TotalCount,
    int Skip,
    int Take,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record AdminFeedbackDetailsResponse(
    Guid Id,
    Guid? UserId,
    string? UserEmail,
    string? UserPlan,
    int? UserCredits,
    string Type,
    string Category,
    int? Rating,
    string? Message,
    string SourceScreen,
    string? AppVersion,
    string? Platform,
    string? DeviceModel,
    string? Locale,
    string? ErrorCode,
    string? ProviderName,
    string Status,
    string Priority,
    DateTime CreatedAtUtc,
    DateTime? ReviewedAtUtc,
    Guid? ReviewedByAdminId,
    string? AdminNote,
    AdminFeedbackGenerationContextResponse? Generation,
    bool CanRefund,
    CreditRefundResponse? Refund);

public sealed record AdminFeedbackGenerationContextResponse(
    Guid GenerationId,
    Guid UserId,
    Guid TemplateId,
    string TemplateTitle,
    Guid? PetId,
    string? InputPreviewUrl,
    string? ResultPreviewUrl,
    string? ProviderName,
    string? ErrorCode,
    int CreditsCharged,
    DateTime? ChargedAtUtc,
    DateTime? RefundedAtUtc);

public sealed record UpdateFeedbackAdminCommand(
    Guid FeedbackId,
    Guid AdminUserId,
    string? Status,
    string? Priority,
    string? AdminNote);

public sealed record RefundFeedbackCreditsCommand(
    Guid FeedbackId,
    Guid AdminUserId,
    int? Amount,
    string? Reason);

public sealed record CreditRefundResponse(
    Guid Id,
    Guid UserId,
    Guid? FeedbackId,
    Guid? GenerationId,
    int Amount,
    string Reason,
    Guid AdminId,
    DateTime CreatedAtUtc);

public sealed record TemplateFeedbackSummaryResponse(
    Guid TemplateId,
    int PositiveCount,
    int NeutralCount,
    int NegativeCount,
    double PositiveRate,
    double NeutralRate,
    double NegativeRate,
    IReadOnlyList<TemplateFeedbackIssueResponse> TopIssues,
    bool HasNegativeWarning);

public sealed record TemplateFeedbackIssueResponse(string Category, int Count);
