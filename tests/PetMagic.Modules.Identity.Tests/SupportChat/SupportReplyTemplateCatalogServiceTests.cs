using System.Reflection;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportReplyTemplateCatalogServiceTests
{
    [Fact]
    public void ToResponse_ShouldNormalizeLegacyNullFields()
    {
        var method = typeof(SupportReplyTemplateCatalogService).GetMethod(
            "ToResponse",
            BindingFlags.NonPublic | BindingFlags.Static);

        var response = Assert.IsType<SupportReplyTemplateResponse>(method!.Invoke(null, [
            new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                Title = null!,
                Body = null!,
                IsEnabled = true,
                SortOrder = 1,
                CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
                UpdatedAtUtc = DateTime.UtcNow,
            }
        ]));

        Assert.Equal(string.Empty, response.Title);
        Assert.Equal(string.Empty, response.Body);
    }
}
