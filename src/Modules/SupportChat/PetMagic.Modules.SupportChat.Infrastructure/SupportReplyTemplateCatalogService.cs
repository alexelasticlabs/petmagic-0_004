using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportReplyTemplateCatalogService(
    SupportChatDbContext supportChatDbContext,
    IMemoryCache memoryCache) : ISupportReplyTemplateCatalogService
{
    private static readonly Error TemplateNotFound = new("support.template_not_found", "Support reply template was not found.");

    public async Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(CancellationToken cancellationToken)
    {
        const string cacheKey = "support_chat:reply_templates";
        if (memoryCache.TryGetValue(cacheKey, out IReadOnlyList<SupportReplyTemplateResponse>? cached) && cached is not null)
        {
            return Result.Success(cached);
        }

        var templates = await supportChatDbContext.SupportReplyTemplates
            .AsNoTracking()
            .OrderBy(x => x.SortOrder)
            .ThenBy(x => x.Title)
            .ToListAsync(cancellationToken);

        var result = (IReadOnlyList<SupportReplyTemplateResponse>)[.. templates.Select(ToResponse)];
        memoryCache.Set(cacheKey, result, TimeSpan.FromMinutes(5));
        return Result.Success(result);
    }

    public async Task<Result<SupportReplyTemplateResponse>> UpsertAdminTemplateAsync(UpsertSupportReplyTemplateCommand command, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var template = command.TemplateId.HasValue
            ? await supportChatDbContext.SupportReplyTemplates.FirstOrDefaultAsync(x => x.Id == command.TemplateId.Value, cancellationToken)
            : null;

        if (command.TemplateId.HasValue && template is null)
        {
            return Result.Failure<SupportReplyTemplateResponse>(TemplateNotFound);
        }

        if (template is null)
        {
            template = new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                CreatedAtUtc = now,
            };
            supportChatDbContext.SupportReplyTemplates.Add(template);
        }

        template.Title = command.Title.Trim();
        template.Body = command.Body.Trim();
        template.IsEnabled = command.IsEnabled;
        template.SortOrder = command.SortOrder;
        template.UpdatedAtUtc = now;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        memoryCache.Remove("support_chat:reply_templates");
        return Result.Success(ToResponse(template));
    }

    public async Task<Result> DeleteAdminTemplateAsync(DeleteSupportReplyTemplateCommand command, CancellationToken cancellationToken)
    {
        var template = await supportChatDbContext.SupportReplyTemplates
            .FirstOrDefaultAsync(x => x.Id == command.TemplateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure(TemplateNotFound);
        }

        supportChatDbContext.SupportReplyTemplates.Remove(template);
        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        memoryCache.Remove("support_chat:reply_templates");
        return Result.Success();
    }

    private static SupportReplyTemplateResponse ToResponse(SupportReplyTemplate template)
    {
        return new SupportReplyTemplateResponse(
            template.Id,
            template.Title,
            template.Body,
            template.IsEnabled,
            template.SortOrder,
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }
}
