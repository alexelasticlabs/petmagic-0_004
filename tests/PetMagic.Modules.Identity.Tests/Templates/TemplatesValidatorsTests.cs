using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Application.Validation;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesValidatorsTests
{
    [Fact]
    public void UpdateImageTemplateValidator_ShouldRejectOversizedFields_AndZeroPreviewFileSize()
    {
        var validator = new UpdateImageTemplateCommandValidator();

        var result = validator.Validate(
            new UpdateImageTemplateCommand(
                Guid.NewGuid(),
                "Portrait",
                "A portrait template",
                "Portrait",
                [new string('t', 33)],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                new TemplateAssetCommand(
                    "https://cdn.example.com/templates/preview.jpg",
                    "preview.jpg",
                    "image/jpeg",
                    0,
                    null),
                "openai/gpt-image-2/edit",
                new string('x', 20_000),
                TemplateStatus.Draft.ToString(),
                [new string('r', 161)],
                false,
                "Image"));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "PreviewAsset.FileSizeBytes");
        Assert.Contains(result.Errors, error => error.PropertyName == "ImagePrompt");
        Assert.Contains(result.Errors, error => error.PropertyName == "PetPhotoRequirements[0]");
        Assert.Contains(result.Errors, error => error.PropertyName == "Tags[0]");
    }

    [Fact]
    public void RefundFeedbackCreditsValidator_ShouldRejectNonPositiveAmount_AndAllowOptionalReason()
    {
        var validator = new RefundFeedbackCreditsCommandValidator();

        var result = validator.Validate(new RefundFeedbackCreditsCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            0,
            new string('r', 501)));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "Amount");
        Assert.Contains(result.Errors, error => error.PropertyName == "Reason");

        var missingReason = validator.Validate(new RefundFeedbackCreditsCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            null,
            null));
        var blankReason = validator.Validate(new RefundFeedbackCreditsCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            null,
            "   "));

        Assert.True(missingReason.IsValid);
        Assert.True(blankReason.IsValid);
    }

    [Fact]
    public void SubmitFeedbackValidator_ShouldRejectUnknownType_OutOfRangeRating_AndOversizedFields()
    {
        var validator = new SubmitFeedbackCommandValidator();

        var result = validator.Validate(new SubmitFeedbackCommand(
            Guid.NewGuid(),
            "Other",
            new string('c', 81),
            2,
            new string('m', 2001),
            null,
            null,
            null,
            new string('s', 81),
            new string('a', 65),
            new string('p', 33),
            new string('d', 129),
            new string('l', 17)));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "Type");
        Assert.Contains(result.Errors, error => error.PropertyName == "Category");
        Assert.Contains(result.Errors, error => error.PropertyName == "Rating");
        Assert.Contains(result.Errors, error => error.PropertyName == "Message");
        Assert.Contains(result.Errors, error => error.PropertyName == "SourceScreen");
        Assert.Contains(result.Errors, error => error.PropertyName == "AppVersion");
        Assert.Contains(result.Errors, error => error.PropertyName == "Platform");
        Assert.Contains(result.Errors, error => error.PropertyName == "DeviceModel");
        Assert.Contains(result.Errors, error => error.PropertyName == "Locale");
    }

    [Fact]
    public void UpdateFeedbackAdminValidator_ShouldRejectInvalidEnums_AndOversizedNote()
    {
        var validator = new UpdateFeedbackAdminCommandValidator();

        var result = validator.Validate(new UpdateFeedbackAdminCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "not_open",
            "urgent",
            new string('n', 2001)));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "Status");
        Assert.Contains(result.Errors, error => error.PropertyName == "Priority");
        Assert.Contains(result.Errors, error => error.PropertyName == "AdminNote");
    }

    [Fact]
    public void StartTemplateGenerationValidator_ShouldReturnSourceImageContentTypeCode()
    {
        var validator = new StartTemplateGenerationCommandValidator();

        var result = validator.Validate(new StartTemplateGenerationCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            new TemplateAssetCommand(
                "https://cdn.example.com/source.heic",
                "source.heic",
                "image/heic",
                1024,
                null)));

        var error = Assert.Single(result.Errors, item => item.PropertyName == "SourceImageAsset.ContentType");
        Assert.Equal("templates.source_image_type_not_allowed", error.ErrorMessage);
        Assert.DoesNotContain("Please upload", error.ErrorMessage, StringComparison.Ordinal);
    }
}
