using System.Data.Common;
using System.Text.Json;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListPublicDiscoveryAsync_ShouldReturnDeterministicBoundedCategorySections()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var publishedAtUtc = DateTime.UtcNow.AddHours(-1);

        var oldestAlphaId = await CreateActiveImageTemplateAsync(service, "Alpha Oldest", "Alpha", ["discovery"]);
        var middleAlphaId = await CreateActiveImageTemplateAsync(service, "Alpha Middle", "Alpha", ["discovery"]);
        var newestAlphaId = await CreateActiveImageTemplateAsync(service, "Alpha Newest", "Alpha", ["discovery"]);
        var betaId = await CreateActiveImageTemplateAsync(service, "Beta Item", "Beta", ["discovery"]);
        await CreateActiveImageTemplateAsync(service, "Zeta Item", "Zeta", ["discovery"]);

        await SetPublishedAtUtcAsync(dbContext, oldestAlphaId, publishedAtUtc);
        await SetPublishedAtUtcAsync(dbContext, middleAlphaId, publishedAtUtc.AddMinutes(1));
        await SetPublishedAtUtcAsync(dbContext, newestAlphaId, publishedAtUtc.AddMinutes(2));

        var generatedAfterUtc = DateTime.UtcNow;
        var discovery = await service.ListPublicDiscoveryAsync(
            new PublicTemplatesDiscoveryQuery(
                ItemsPerSection: 2,
                SectionLimit: 2,
                Locale: null),
            CancellationToken.None);

        Assert.True(discovery.IsSuccess);
        Assert.Equal(["Alpha", "Beta"], [.. discovery.Value.Sections.Select(section => section.Category)]);
        Assert.Equal(
            [newestAlphaId, middleAlphaId],
            [.. discovery.Value.Sections[0].Items.Select(item => item.TemplateId)]);
        var betaItem = Assert.Single(discovery.Value.Sections[1].Items);
        Assert.Equal(betaId, betaItem.TemplateId);
        Assert.Equal("Beta", betaItem.Category.Title);
        Assert.Equal(20, betaItem.TokenCost);
        Assert.Equal(betaItem.ThumbnailUrl, betaItem.Media.ThumbnailUrl);
        Assert.True(discovery.Value.GeneratedAtUtc >= generatedAfterUtc);
    }

    [Fact]
    public async Task ListPublicDiscoveryAsync_ShouldReuseFeedVisibilityAndLocalizationPolicy()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var publicId = await CreateActiveImageTemplateAsync(service, "Public Discovery", "Localized", ["discovery"]);
        var qaOnlyId = await CreateActiveImageTemplateAsync(service, "QA Discovery", "Localized", ["discovery"]);
        var publicTemplate = await dbContext.TemplateItems.SingleAsync(template => template.Id == publicId);
        var qaOnlyTemplate = await dbContext.TemplateItems.SingleAsync(template => template.Id == qaOnlyId);
        publicTemplate.LocalizedTextsJson = JsonSerializer.Serialize(
            new Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>
            {
                ["ru"] = new("Публичное открытие", "Локализованное описание", null, null, null, null)
            });
        qaOnlyTemplate.IsQaOnly = true;
        await dbContext.SaveChangesAsync();

        var publicDiscovery = await service.ListPublicDiscoveryAsync(
            new PublicTemplatesDiscoveryQuery(6, 12, "ru", IncludeQaOnly: false),
            CancellationToken.None);
        var qaDiscovery = await service.ListPublicDiscoveryAsync(
            new PublicTemplatesDiscoveryQuery(6, 12, "ru", IncludeQaOnly: true),
            CancellationToken.None);

        Assert.True(publicDiscovery.IsSuccess);
        var publicItem = Assert.Single(Assert.Single(publicDiscovery.Value.Sections).Items);
        Assert.Equal(publicId, publicItem.TemplateId);
        Assert.Equal("Публичное открытие", publicItem.Title);
        Assert.DoesNotContain(publicDiscovery.Value.Sections.SelectMany(section => section.Items), item => item.TemplateId == qaOnlyId);

        Assert.True(qaDiscovery.IsSuccess);
        Assert.Contains(qaDiscovery.Value.Sections.SelectMany(section => section.Items), item => item.TemplateId == qaOnlyId);
    }

    [Fact]
    public async Task ListPublicDiscoveryAsync_ShouldUseConstantBoundedQueryCount()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var commandCounter = new ReaderCommandCounter();
        await using var dbContext = await CreateSqliteDbContextAsync(connection, commandCounter);
        var service = CreateService(dbContext);

        for (var categoryIndex = 0; categoryIndex < 3; categoryIndex++)
        {
            for (var itemIndex = 0; itemIndex < 4; itemIndex++)
            {
                await CreateActiveImageTemplateAsync(
                    service,
                    $"Discovery {categoryIndex}-{itemIndex}",
                    $"Category {categoryIndex}",
                    ["query-count"]);
            }
        }

        commandCounter.Reset();

        var discovery = await service.ListPublicDiscoveryAsync(
            new PublicTemplatesDiscoveryQuery(2, 3, null),
            CancellationToken.None);

        Assert.True(discovery.IsSuccess);
        Assert.Equal(3, discovery.Value.Sections.Count);
        Assert.All(discovery.Value.Sections, section => Assert.Equal(2, section.Items.Count));
        Assert.Equal(4, commandCounter.ReaderCount); // One published-revision lookup plus three bounded fallback queries.
    }

    private sealed class ReaderCommandCounter : DbCommandInterceptor
    {
        private int readerCount;

        public int ReaderCount => Volatile.Read(ref readerCount);

        public void Reset() => Interlocked.Exchange(ref readerCount, 0);

        public override InterceptionResult<DbDataReader> ReaderExecuting(
            DbCommand command,
            CommandEventData eventData,
            InterceptionResult<DbDataReader> result)
        {
            Interlocked.Increment(ref readerCount);
            return base.ReaderExecuting(command, eventData, result);
        }

        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
            DbCommand command,
            CommandEventData eventData,
            InterceptionResult<DbDataReader> result,
            CancellationToken cancellationToken = default)
        {
            Interlocked.Increment(ref readerCount);
            return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
        }
    }
}
