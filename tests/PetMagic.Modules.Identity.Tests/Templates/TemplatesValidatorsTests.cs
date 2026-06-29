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
}
