using FluentValidation;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Validation;

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
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("Promo badge mode is invalid.");
        RuleFor(x => x.ImageModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.ImagePrompt).MaximumLength(1000);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("Template status is invalid.");
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(32);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
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
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("Promo badge mode is invalid.");
        RuleFor(x => x.ImageModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.ImagePrompt).MaximumLength(1000);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("Template status is invalid.");
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(32);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
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
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("Promo badge mode is invalid.");
        RuleFor(x => x.MusicDescription).MaximumLength(240);
        RuleFor(x => x.PreprocessingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.PreprocessingPrompt).MaximumLength(1000);
        RuleFor(x => x.KlingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.KlingPrompt).MaximumLength(1000);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("Template status is invalid.");
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(32);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ReferenceMotionAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ReferenceMotionAsset is not null);
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
        RuleFor(x => x.PromoBadgeMode).Must(raw => Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out _)).WithMessage("Promo badge mode is invalid.");
        RuleFor(x => x.MusicDescription).MaximumLength(240);
        RuleFor(x => x.PreprocessingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.PreprocessingPrompt).MaximumLength(1000);
        RuleFor(x => x.KlingModel).NotEmpty().MaximumLength(128);
        RuleFor(x => x.KlingPrompt).MaximumLength(1000);
        RuleFor(x => x.Status).MaximumLength(32);
        RuleFor(x => x.Status).Must(raw => string.IsNullOrWhiteSpace(raw) || Enum.TryParse<TemplateStatus>(raw, true, out _)).WithMessage("Template status is invalid.");
        RuleForEach(x => x.Tags).NotEmpty().MaximumLength(32);
        RuleFor(x => x.PreviewAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.PreviewAsset is not null);
        RuleFor(x => x.ReferenceMotionAsset!).SetValidator(new TemplateAssetCommandValidator()).When(x => x.ReferenceMotionAsset is not null);
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
        RuleFor(x => x.SourceImageAsset).NotNull().SetValidator(new TemplateAssetCommandValidator());
        RuleFor(x => x.SourceImageAsset.ContentType)
            .Must(contentType => contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            .WithMessage("Source image content type is invalid.");
    }
}
