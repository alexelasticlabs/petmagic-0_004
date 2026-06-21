using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Application.Validation;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesValidatorsTests
{
    [Fact]
    public void UpdateImageTemplateValidator_ShouldAllowLegacyPromptAndUnknownPreviewFileSize()
    {
        var validator = new UpdateImageTemplateCommandValidator();

        var result = validator.Validate(
            new UpdateImageTemplateCommand(
                Guid.NewGuid(),
                "Portrait",
                "A portrait template",
                "Portrait",
                ["pet"],
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
                ["Clear face"],
                false,
                "Image"));

        Assert.True(result.IsValid);
    }
}
