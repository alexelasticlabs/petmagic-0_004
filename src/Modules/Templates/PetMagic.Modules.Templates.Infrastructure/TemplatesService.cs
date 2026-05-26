using System.Globalization;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IMediaMetadataReader metadataReader,
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService,
    ITemplateFeedRealtimeService templateFeedRealtimeService) : ITemplatesService
{
    private readonly TemplateCategoryAdminService _templateCategoryAdminService =
        new(dbContext, templateFeedRealtimeService);
    private readonly TemplateAdminAnalyticsService _templateAdminAnalyticsService =
        new(dbContext);

    private const int PublicFeedDefaultTake = 20;
    private const int PublicFeedMaxTake = 50;

    private sealed record PublicFeedCursor(DateTime UpdatedAtUtc, Guid TemplateId);


}

