using System.Reflection;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
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

    [Fact]
    public async Task ListAdminTemplateVersionsAsync_ShouldBoundNewestHistory()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase($"support-template-history-{Guid.NewGuid():N}")
            .Options;
        await using var dbContext = new SupportChatDbContext(options);
        var templateId = Guid.NewGuid();
        var actorId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.SupportReplyTemplates.Add(new SupportReplyTemplate
        {
            Id = templateId,
            Title = "Current",
            Body = "Current body",
            IsEnabled = true,
            Version = 61,
            LastModifiedByUserId = actorId,
            CreatedAtUtc = now.AddDays(-1),
            UpdatedAtUtc = now,
        });
        dbContext.SupportReplyTemplateRevisions.AddRange(
            Enumerable.Range(1, 60).Select(version => new SupportReplyTemplateRevision
            {
                Id = Guid.NewGuid(),
                TemplateId = templateId,
                Version = version,
                Title = $"Version {version}",
                Body = $"Body {version}",
                IsEnabled = true,
                ActorUserId = actorId,
                CapturedAtUtc = now.AddMinutes(-version),
            }));
        await dbContext.SaveChangesAsync();

        using var cache = new MemoryCache(new MemoryCacheOptions());
        var service = new SupportReplyTemplateCatalogService(dbContext, cache);

        var result = await service.ListAdminTemplateVersionsAsync(templateId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(50, result.Value.Count);
        Assert.True(result.Value[0].IsCurrent);
        Assert.Equal(61, result.Value[0].Version);
        Assert.Equal(60, result.Value[1].Version);
        Assert.Equal(12, result.Value[^1].Version);
    }
}
