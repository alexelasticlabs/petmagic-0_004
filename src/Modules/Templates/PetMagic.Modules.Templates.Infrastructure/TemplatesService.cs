using PetMagic.BuildingBlocks.Observability;
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
    IAdminAuditLog? adminAuditLog = null,
    TemplateWatermarkSettingsStore? watermarkSettings = null) : ITemplatesService
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
    private const int PublicLegacyListMaxTake = 100;
    private const int PublicCatalogMaxDeltaChanges = 500;
    private const int PublicCategoryFilterMaxLength = 64;
    private const int PublicSearchFilterMaxLength = 120;
    private const int PublicTagFilterMaxLength = 32;
    private const int PublicTagFilterMaxCount = 12;
    private const string PublicImpossibleTagFilter = "__petmagic_invalid_public_tag_filter__";

    private sealed record PublicFeedCursor(DateTime UpdatedAtUtc, long? Version, Guid TemplateId);
}
