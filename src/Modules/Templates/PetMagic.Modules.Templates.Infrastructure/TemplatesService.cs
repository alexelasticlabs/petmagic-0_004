using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IMediaMetadataReader metadataReader,
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService,
    ITemplateFeedRealtimeService templateFeedRealtimeService,
    IHttpClientFactory httpClientFactory) : ITemplatesService
{
    private readonly TemplateCategoryAdminService _templateCategoryAdminService =
        new(dbContext, templateFeedRealtimeService);

    private readonly TemplateAdminAnalyticsService _templateAdminAnalyticsService =
        new(dbContext);

    private const int PublicFeedDefaultTake = 20;
    private const int PublicFeedMaxTake = 50;
    private const int PublicCatalogDefaultPage = 1;
    private const int PublicCatalogDefaultPageSize = 20;
    private const int PublicCatalogMaxPageSize = 100;
    private const int PublicCatalogMaxDeltaChanges = 500;

    private sealed record PublicFeedCursor(DateTime UpdatedAtUtc, Guid TemplateId);
}
