using FluentValidation;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Validation;

internal static class TemplateValidationRules
{
    public const int PromptMaxLength = 1000;
    public const int TagMaxLength = 32;
    public const int RequirementMaxLength = 160;
    public const int RequirementMaxCount = 6;
}

public sealed class TemplateAssetCommandValidator : AbstractValidator<TemplateAssetCommand>
{
    public TemplateAssetCommandValidator()
    {
        RuleFor(x => x.Url).NotEmpty().MaximumLength(2048);
        RuleFor(x => x.FileName).NotEmpty().MaximumLength(256);
        RuleFor(x => x.ContentType).NotEmpty().MaximumLength(128);
        RuleFor(x => x.FileSizeBytes).GreaterThan(0).When(x => x.FileSizeBytes.HasValue);
        RuleFor(x => x.DurationSeconds).GreaterThan(0).When(x => x.DurationSeconds.HasValue);
    }
}

public sealed class CreateImageTemplateCommandValidator : AbstractValidator<CreateImageTemplateCommand>
{
    public CreateImageTemplateCommandValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(120);
        RuleFor(x => x.ShortDescription).NotEmpty().MaximumLength(240);
        RuleFor(x => x.Category).NotEmpty().MaximumLength(64);
        RuleFor(x => x.TokenCost).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("templates.promo_badge_mode_invalid");
        RuleFor(x => x.ImageModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.ImagePrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("templates.status_invalid");
        RuleFor(x => x.RequiredInputMediaType).Must(TemplateInputMediaTypeValidation.IsValidInputMediaType).WithMessage("templates.required_input_media_type_invalid");
        RuleFor(x => x.DefaultVariationStrength).Must(TemplateInputMediaTypeValidation.IsValidVariationStrength).WithMessage("templates.default_variation_strength_invalid");
        RuleFor(x => x.PetPhotoRequirements).Must(items => items is null || items.Count <= TemplateValidationRules.RequirementMaxCount).WithMessage("templates.pet_photo_requirements_count_invalid");
        RuleForEach(x => x.PetPhotoRequirements).NotEmpty().MaximumLength(TemplateValidationRules.RequirementMaxLength).When(x => x.PetPhotoRequirements is not null);
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(TemplateValidationRules.TagMaxLength);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ThumbnailAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ThumbnailAsset is not null);
        RuleFor(x => x.AnimatedPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.AnimatedPreviewAsset is not null);
        RuleFor(x => x.FeedLoopLowAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopLowAsset is not null);
        RuleFor(x => x.FeedLoopMediumAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopMediumAsset is not null);
        RuleFor(x => x.DetailPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.DetailPreviewAsset is not null);
    }
}

public sealed class UpdateImageTemplateCommandValidator : AbstractValidator<UpdateImageTemplateCommand>
{
    public UpdateImageTemplateCommandValidator()
    {
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(120);
        RuleFor(x => x.ShortDescription).NotEmpty().MaximumLength(240);
        RuleFor(x => x.Category).NotEmpty().MaximumLength(64);
        RuleFor(x => x.TokenCost).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("templates.promo_badge_mode_invalid");
        RuleFor(x => x.ImageModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.ImagePrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("templates.status_invalid");
        RuleFor(x => x.RequiredInputMediaType).Must(TemplateInputMediaTypeValidation.IsValidInputMediaType).WithMessage("templates.required_input_media_type_invalid");
        RuleFor(x => x.DefaultVariationStrength).Must(TemplateInputMediaTypeValidation.IsValidVariationStrength).WithMessage("templates.default_variation_strength_invalid");
        RuleFor(x => x.PetPhotoRequirements).Must(items => items is null || items.Count <= TemplateValidationRules.RequirementMaxCount).WithMessage("templates.pet_photo_requirements_count_invalid");
        RuleForEach(x => x.PetPhotoRequirements).NotEmpty().MaximumLength(TemplateValidationRules.RequirementMaxLength).When(x => x.PetPhotoRequirements is not null);
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(TemplateValidationRules.TagMaxLength);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ThumbnailAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ThumbnailAsset is not null);
        RuleFor(x => x.AnimatedPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.AnimatedPreviewAsset is not null);
        RuleFor(x => x.FeedLoopLowAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopLowAsset is not null);
        RuleFor(x => x.FeedLoopMediumAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopMediumAsset is not null);
        RuleFor(x => x.DetailPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.DetailPreviewAsset is not null);
    }
}

public sealed class CreateVideoTemplateCommandValidator : AbstractValidator<CreateVideoTemplateCommand>
{
    public CreateVideoTemplateCommandValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(120);
        RuleFor(x => x.ShortDescription).NotEmpty().MaximumLength(240);
        RuleFor(x => x.Category).NotEmpty().MaximumLength(64);
        RuleFor(x => x.TokenCost).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("templates.promo_badge_mode_invalid");
        RuleFor(x => x.MusicDescription).MaximumLength(240);
        RuleFor(x => x.PreprocessingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.PreprocessingPrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.KlingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.KlingPrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("templates.status_invalid");
        RuleFor(x => x.RequiredInputMediaType).Must(TemplateInputMediaTypeValidation.IsValidInputMediaType).WithMessage("templates.required_input_media_type_invalid");
        RuleFor(x => x.DefaultVariationStrength).Must(TemplateInputMediaTypeValidation.IsValidVariationStrength).WithMessage("templates.default_variation_strength_invalid");
        RuleFor(x => x.PetPhotoRequirements).Must(items => items is null || items.Count <= TemplateValidationRules.RequirementMaxCount).WithMessage("templates.pet_photo_requirements_count_invalid");
        RuleForEach(x => x.PetPhotoRequirements).NotEmpty().MaximumLength(TemplateValidationRules.RequirementMaxLength).When(x => x.PetPhotoRequirements is not null);
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(TemplateValidationRules.TagMaxLength);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ReferenceMotionAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ReferenceMotionAsset is not null);
        RuleFor(x => x.ThumbnailAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ThumbnailAsset is not null);
        RuleFor(x => x.AnimatedPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.AnimatedPreviewAsset is not null);
        RuleFor(x => x.FeedLoopLowAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopLowAsset is not null);
        RuleFor(x => x.FeedLoopMediumAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopMediumAsset is not null);
        RuleFor(x => x.DetailPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.DetailPreviewAsset is not null);
    }
}

public sealed class UpdateVideoTemplateCommandValidator : AbstractValidator<UpdateVideoTemplateCommand>
{
    public UpdateVideoTemplateCommandValidator()
    {
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.Title).NotEmpty().MaximumLength(120);
        RuleFor(x => x.ShortDescription).NotEmpty().MaximumLength(240);
        RuleFor(x => x.Category).NotEmpty().MaximumLength(64);
        RuleFor(x => x.TokenCost).GreaterThanOrEqualTo(0);
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("templates.promo_badge_mode_invalid");
        RuleFor(x => x.MusicDescription).MaximumLength(240);
        RuleFor(x => x.PreprocessingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.PreprocessingPrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.KlingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.KlingPrompt).NotNull().MaximumLength(TemplateValidationRules.PromptMaxLength);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("templates.status_invalid");
        RuleFor(x => x.RequiredInputMediaType).Must(TemplateInputMediaTypeValidation.IsValidInputMediaType).WithMessage("templates.required_input_media_type_invalid");
        RuleFor(x => x.DefaultVariationStrength).Must(TemplateInputMediaTypeValidation.IsValidVariationStrength).WithMessage("templates.default_variation_strength_invalid");
        RuleFor(x => x.PetPhotoRequirements).Must(items => items is null || items.Count <= TemplateValidationRules.RequirementMaxCount).WithMessage("templates.pet_photo_requirements_count_invalid");
        RuleForEach(x => x.PetPhotoRequirements).NotEmpty().MaximumLength(TemplateValidationRules.RequirementMaxLength).When(x => x.PetPhotoRequirements is not null);
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(TemplateValidationRules.TagMaxLength);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ReferenceMotionAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ReferenceMotionAsset is not null);
        RuleFor(x => x.ThumbnailAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ThumbnailAsset is not null);
        RuleFor(x => x.AnimatedPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.AnimatedPreviewAsset is not null);
        RuleFor(x => x.FeedLoopLowAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopLowAsset is not null);
        RuleFor(x => x.FeedLoopMediumAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.FeedLoopMediumAsset is not null);
        RuleFor(x => x.DetailPreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.DetailPreviewAsset is not null);
    }
}

public sealed class StartTemplateGenerationFromResultCommandValidator : AbstractValidator<StartTemplateGenerationFromResultCommand>
{
    public StartTemplateGenerationFromResultCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.ParentGenerationResultId).NotEmpty();
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.IdempotencyKey).MaximumLength(256);
    }
}

public sealed class StartSimilarTemplateGenerationCommandValidator : AbstractValidator<StartSimilarTemplateGenerationCommand>
{
    public StartSimilarTemplateGenerationCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.SourceGenerationId).NotEmpty();
        RuleFor(x => x.IdempotencyKey).NotEmpty().MaximumLength(256);
        RuleFor(x => x.VariationStrength).Must(TemplateInputMediaTypeValidation.IsValidVariationStrength).WithMessage("templates.variation_strength_invalid");
    }
}

public sealed class RefundFeedbackCreditsCommandValidator : AbstractValidator<RefundFeedbackCreditsCommand>
{
    public RefundFeedbackCreditsCommandValidator()
    {
        RuleFor(x => x.FeedbackId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0).When(x => x.Amount.HasValue);
        RuleFor(x => x.Reason).MaximumLength(500);
    }
}

public sealed class RegisterTemplatePushTokenCommandValidator : AbstractValidator<RegisterTemplatePushTokenCommand>
{
    private const int MinPushTokenLength = 20;

    public RegisterTemplatePushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(MinPushTokenLength).MaximumLength(4096);
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(32);
        RuleFor(x => x.DeviceId).MaximumLength(128);
        RuleFor(x => x.AppVersion).MaximumLength(64);
        RuleFor(x => x.Locale).MaximumLength(16);
    }
}

public sealed class UnregisterTemplatePushTokenCommandValidator : AbstractValidator<UnregisterTemplatePushTokenCommand>
{
    private const int MinPushTokenLength = 20;

    public UnregisterTemplatePushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(MinPushTokenLength).MaximumLength(4096);
    }
}

public sealed class SubmitFeedbackCommandValidator : AbstractValidator<SubmitFeedbackCommand>
{
    public SubmitFeedbackCommandValidator()
    {
        RuleFor(x => x.UserId).NotNull().NotEmpty();
        RuleFor(x => x.Type)
            .NotEmpty()
            .MaximumLength(32)
            .Must(value => value is "GenerationResult" or "GenerationFailure" or "BugReport" or "FeatureRequest" or "PaymentIssue" or "General")
            .WithMessage("templates.feedback_type_invalid");
        RuleFor(x => x.Category).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Rating).InclusiveBetween(-1, 1).When(x => x.Rating.HasValue);
        RuleFor(x => x.Message).MaximumLength(2000);
        RuleFor(x => x.SourceScreen).MaximumLength(80);
        RuleFor(x => x.AppVersion).MaximumLength(64);
        RuleFor(x => x.Platform).MaximumLength(32);
        RuleFor(x => x.DeviceModel).MaximumLength(128);
        RuleFor(x => x.Locale).MaximumLength(16);
    }
}

public sealed class UpdateFeedbackAdminCommandValidator : AbstractValidator<UpdateFeedbackAdminCommand>
{
    public UpdateFeedbackAdminCommandValidator()
    {
        RuleFor(x => x.FeedbackId).NotEmpty();
        RuleFor(x => x.AdminUserId).NotEmpty();
        RuleFor(x => x.Status)
            .Must(value => value is null or "New" or "InReview" or "Resolved" or "Dismissed")
            .WithMessage("templates.feedback_status_invalid");
        RuleFor(x => x.Priority)
            .Must(value => value is null or "Low" or "Medium" or "High" or "Critical")
            .WithMessage("templates.feedback_priority_invalid");
        RuleFor(x => x.AdminNote).MaximumLength(2000);
    }
}

internal static class TemplateInputMediaTypeValidation
{
    public static bool IsValidInputMediaType(string? raw)
    {
        return string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateType>(raw, true, out _);
    }

    public static bool IsValidVariationStrength(string? raw)
    {
        return string.IsNullOrWhiteSpace(raw)
            || string.Equals(raw, "low", StringComparison.OrdinalIgnoreCase)
            || string.Equals(raw, "medium", StringComparison.OrdinalIgnoreCase)
            || string.Equals(raw, "high", StringComparison.OrdinalIgnoreCase);
    }
}

public sealed class ChangeTemplateStatusCommandValidator : AbstractValidator<ChangeTemplateStatusCommand>
{
    public ChangeTemplateStatusCommandValidator()
    {
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.Status).NotEmpty().MaximumLength(32);
    }
}

public sealed class CreateTemplateCategoryCommandValidator : AbstractValidator<CreateTemplateCategoryCommand>
{
    public CreateTemplateCategoryCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(64);
    }
}

public sealed class UpdateTemplateCategoryCommandValidator : AbstractValidator<UpdateTemplateCategoryCommand>
{
    public UpdateTemplateCategoryCommandValidator()
    {
        RuleFor(x => x.CategoryId).NotEmpty();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(64);
    }
}

public sealed class ChangeTemplateCategoryArchiveStateCommandValidator : AbstractValidator<ChangeTemplateCategoryArchiveStateCommand>
{
    public ChangeTemplateCategoryArchiveStateCommandValidator()
    {
        RuleFor(x => x.CategoryId).NotEmpty();
    }
}

public sealed class StartTemplateGenerationCommandValidator : AbstractValidator<StartTemplateGenerationCommand>
{
    public StartTemplateGenerationCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.TemplateId).NotEmpty();
        RuleFor(x => x.IdempotencyKey).MaximumLength(256);
        RuleFor(x => x.RequestHash).MaximumLength(128);
        RuleFor(x => x.SourceImageAsset).NotNull().SetValidator(new TemplateAssetCommandValidator());
        RuleFor(x => x.SourceImageAsset.ContentType)
            .Must(contentType =>
                contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(contentType, "image/heic", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(contentType, "image/heif", StringComparison.OrdinalIgnoreCase))
            .WithMessage("templates.source_image_type_not_allowed");
    }
}
