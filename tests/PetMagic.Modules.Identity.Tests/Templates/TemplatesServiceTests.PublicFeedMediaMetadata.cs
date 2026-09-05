using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PublicFeedAndDiscovery_ShouldMeasureSelectedVideoInsteadOfThumbnail(bool useDistinctLow)
    {
        var cards = await ReadMediaMetadataCardsAsync(useDistinctLow);

        foreach (var card in cards)
        {
            Assert.Equal("video", card.MediaKind);
            Assert.Equal("video", card.Media.MediaKind);
            Assert.Equal("https://cdn.example.com/thumbnail.jpg", card.Media.ThumbnailUrl);
            Assert.Equal(
                useDistinctLow ? "https://cdn.example.com/low.mp4" : "https://cdn.example.com/preview.mp4",
                card.Media.FeedLoopLowUrl);
            Assert.Equal(useDistinctLow ? 700_000L : 3_439_810L, card.SizeBytes);
            Assert.Equal(card.SizeBytes, card.Media.SizeBytes);
            Assert.Equal(useDistinctLow ? 5_000 : 8_000, card.DurationMs);
            Assert.Equal(card.DurationMs, card.Media.DurationMs);
        }
    }

    [Fact]
    public async Task PublicFeedAndDiscovery_ShouldNotBorrowMissingLowVideoMeasurementsFromOtherAssets()
    {
        var cards = await ReadMediaMetadataCardsAsync(useDistinctLow: true, missingLowMeasurements: true);

        foreach (var card in cards)
        {
            Assert.Equal("https://cdn.example.com/low.mp4", card.Media.FeedLoopLowUrl);
            Assert.Equal("video", card.MediaKind);
            Assert.Null(card.SizeBytes);
            Assert.Null(card.Media.SizeBytes);
            Assert.Null(card.DurationMs);
            Assert.Null(card.Media.DurationMs);
        }
    }

    private static async Task<FeedTemplateCardDto[]> ReadMediaMetadataCardsAsync(
        bool useDistinctLow,
        bool missingLowMeasurements = false)
    {
        await using var dbContext = CreateDbContext();
        var template = CreatePublicFeedTemplate(Guid.NewGuid(), "Media Metadata", DateTime.UtcNow, 7);
        template.TemplateType = TemplateType.Video;
        var preview = Assert.Single(template.Assets);
        preview.Url = "https://cdn.example.com/preview.mp4";
        preview.FileName = "preview.mp4";
        preview.ContentType = "video/mp4";
        preview.FileSizeBytes = 3_439_810;
        preview.DurationSeconds = 8;
        template.Assets.Add(new TemplateAsset
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            AssetKind = TemplateAssetKind.Thumbnail,
            Url = "https://cdn.example.com/thumbnail.jpg",
            FileName = "thumbnail.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 48_000
        });
        if (useDistinctLow)
        {
            template.Assets.Add(new TemplateAsset
            {
                Id = Guid.NewGuid(),
                TemplateId = template.Id,
                AssetKind = TemplateAssetKind.FeedLoopLow,
                Url = "https://cdn.example.com/low.mp4",
                FileName = "low.mp4",
                ContentType = "video/mp4",
                FileSizeBytes = missingLowMeasurements ? null : 700_000,
                DurationSeconds = missingLowMeasurements ? null : 5
            });
        }

        dbContext.TemplateItems.Add(template);
        dbContext.TemplateCategories.Add(new TemplateCategory
        {
            Id = Guid.NewGuid(),
            Name = template.Category,
            NormalizedName = template.Category.ToUpperInvariant()
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(dbContext);
        var feed = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(null, null, [], null, null, 10, null, null),
            CancellationToken.None);
        var discovery = await service.ListPublicDiscoveryAsync(
            new PublicTemplatesDiscoveryQuery(6, 12, null),
            CancellationToken.None);

        Assert.True(feed.IsSuccess);
        Assert.True(discovery.IsSuccess);
        return [Assert.Single(feed.Value.Items), Assert.Single(Assert.Single(discovery.Value.Sections).Items)];
    }
}
