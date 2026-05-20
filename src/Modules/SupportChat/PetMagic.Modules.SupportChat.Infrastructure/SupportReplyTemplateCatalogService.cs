using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportReplyTemplateCatalogService(SupportChatDbContext supportChatDbContext) : ISupportReplyTemplateCatalogService
{
    private static readonly Error TemplateNotFound = new("support.template_not_found", "Support reply template was not found.");

    public async Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(CancellationToken cancellationToken)
    {
        var templates = await supportChatDbContext.SupportReplyTemplates
            .AsNoTracking()
            .OrderBy(x => x.Kind)
            .ThenBy(x => x.SortOrder)
            .ThenBy(x => x.Title)
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<SupportReplyTemplateResponse>>(templates.Select(ToResponse).ToList());
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
        template.Kind = command.Kind;
        template.IsEnabled = command.IsEnabled;
        template.SortOrder = command.SortOrder;
        template.UpdatedAtUtc = now;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
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
        return Result.Success();
    }

    private static SupportReplyTemplateResponse ToResponse(SupportReplyTemplate template)
    {
        return new SupportReplyTemplateResponse(
            template.Id,
            template.Title,
            template.Body,
            template.Kind.ToString(),
            template.IsEnabled,
            template.SortOrder,
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }
}