using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class FeedbackService : IFeedbackService
{
    private const int DefaultTake = 50;
    private const int MaxTake = 100;
    private readonly TemplatesDbContext dbContext;
    private readonly IEconomyService economyService;
    private readonly IMediaStorage mediaStorage;
    private readonly TemplatesOptions options;
    private readonly IAdminAuditLog? adminAuditLog;

    public FeedbackService(
        TemplatesDbContext dbContext,
        IEconomyService economyService,
        IMediaStorage mediaStorage,
        TemplatesOptions options,
        IAdminAuditLog? adminAuditLog = null)
    {
        this.dbContext = dbContext;
        this.economyService = economyService;
        this.mediaStorage = mediaStorage;
        this.options = options;
        this.adminAuditLog = adminAuditLog;
    }
}
