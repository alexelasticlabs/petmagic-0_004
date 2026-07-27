using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.BuildingBlocks.Observability;
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
    private const string EnabledCacheKey = "support_chat:reply_templates:enabled";
    private const string AllCacheKey = "support_chat:reply_templates:all";
    private const int MaxVersionHistoryItems = 50;
    private static readonly Error TemplateNotFound = new("support.template_not_found", "Support reply template was not found.");
    private static readonly Error TemplateVersionConflict = new("support.template_version_conflict", "Support reply template changed. Refresh and retry the action.");

    public Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(
        CancellationToken cancellationToken)
        => ListAdminTemplatesAsync(includeDisabled: false, cancellationToken);

    public async Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(
        bool includeDisabled,
        CancellationToken cancellationToken)
    {
        var cacheKey = includeDisabled ? AllCacheKey : EnabledCacheKey;
        if (memoryCache.TryGetValue(cacheKey, out IReadOnlyList<SupportReplyTemplateResponse>? cached) && cached is not null)
        {
            return Result.Success(cached);
        }

        var query = supportChatDbContext.SupportReplyTemplates.AsNoTracking();
        if (!includeDisabled)
        {
            query = query.Where(template => template.IsEnabled);
        }

        var templates = await query
            .OrderBy(template => template.SortOrder)
            .ThenBy(template => template.Title)
            .ToListAsync(cancellationToken);

        var result = (IReadOnlyList<SupportReplyTemplateResponse>)[.. templates.Select(ToResponse)];
        memoryCache.Set(cacheKey, result, TimeSpan.FromMinutes(5));
        return Result.Success(result);
    }

    public async Task<Result<IReadOnlyList<SupportReplyTemplateVersionResponse>>> ListAdminTemplateVersionsAsync(
        Guid templateId,
        CancellationToken cancellationToken)
    {
        var template = await supportChatDbContext.SupportReplyTemplates
            .AsNoTracking()
            .FirstOrDefaultAsync(candidate => candidate.Id == templateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<IReadOnlyList<SupportReplyTemplateVersionResponse>>(TemplateNotFound);
        }

        var revisions = await supportChatDbContext.SupportReplyTemplateRevisions
            .AsNoTracking()
            .Where(revision => revision.TemplateId == templateId)
            .OrderByDescending(revision => revision.Version)
            .Take(MaxVersionHistoryItems - 1)
            .Select(revision => new SupportReplyTemplateVersionResponse(
                revision.TemplateId,
                revision.Version,
                revision.Title,
                revision.Body,
                revision.IsEnabled,
                revision.SortOrder,
                revision.ActorUserId,
                revision.Reason,
                revision.CapturedAtUtc,
                IsCurrent: false))
            .ToListAsync(cancellationToken);

        revisions.Insert(0, new SupportReplyTemplateVersionResponse(
            template.Id,
            template.Version,
            template.Title,
            template.Body,
            template.IsEnabled,
            template.SortOrder,
            template.LastModifiedByUserId,
            Reason: null,
            template.UpdatedAtUtc,
            IsCurrent: true));
        return Result.Success<IReadOnlyList<SupportReplyTemplateVersionResponse>>(revisions);
    }

    public async Task<Result<SupportReplyTemplateResponse>> UpsertAdminTemplateAsync(
        UpsertSupportReplyTemplateCommand command,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var template = command.TemplateId.HasValue
            ? await supportChatDbContext.SupportReplyTemplates.FirstOrDefaultAsync(
                candidate => candidate.Id == command.TemplateId.Value,
                cancellationToken)
            : null;

        if (command.TemplateId.HasValue && template is null)
        {
            return Result.Failure<SupportReplyTemplateResponse>(TemplateNotFound);
        }

        var isNew = template is null;
        if (template is null)
        {
            template = new SupportReplyTemplate
            {
                Id = Guid.NewGuid(),
                Version = 1,
                CreatedAtUtc = now,
            };
            supportChatDbContext.SupportReplyTemplates.Add(template);
        }
        else
        {
            if (command.ExpectedVersion.HasValue && template.Version != command.ExpectedVersion.Value)
            {
                return Result.Failure<SupportReplyTemplateResponse>(TemplateVersionConflict);
            }

            CaptureRevision(template, command.AdminUserId, command.Reason, now);
            template.Version++;
        }

        var wasEnabled = template.IsEnabled;
        template.Title = command.Title.Trim();
        template.Body = command.Body.Trim();
        template.IsEnabled = command.IsEnabled;
        template.DisabledAtUtc = command.IsEnabled ? null : template.DisabledAtUtc ?? now;
        template.SortOrder = command.SortOrder;
        template.LastModifiedByUserId = command.AdminUserId;
        template.UpdatedAtUtc = now;

        var action = isNew
            ? "admin.support.template.created"
            : wasEnabled && !template.IsEnabled
                ? "admin.support.template.disabled"
                : !wasEnabled && template.IsEnabled
                    ? "admin.support.template.enabled"
                    : "admin.support.template.updated";
        EnqueueAudit(template, command.AdminUserId, action, command.Reason);

        try
        {
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return Result.Failure<SupportReplyTemplateResponse>(TemplateVersionConflict);
        }

        InvalidateCache();
        return Result.Success(ToResponse(template));
    }

    public async Task<Result> DeleteAdminTemplateAsync(
        DeleteSupportReplyTemplateCommand command,
        CancellationToken cancellationToken)
    {
        var template = await supportChatDbContext.SupportReplyTemplates
            .FirstOrDefaultAsync(candidate => candidate.Id == command.TemplateId, cancellationToken);

        if (template is null)
        {
            return Result.Failure(TemplateNotFound);
        }

        if (command.ExpectedVersion.HasValue && template.Version != command.ExpectedVersion.Value)
        {
            return Result.Failure(TemplateVersionConflict);
        }

        if (!template.IsEnabled)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        CaptureRevision(template, command.AdminUserId, command.Reason, now);
        template.IsEnabled = false;
        template.DisabledAtUtc = now;
        template.LastModifiedByUserId = command.AdminUserId;
        template.UpdatedAtUtc = now;
        template.Version++;
        EnqueueAudit(template, command.AdminUserId, "admin.support.template.disabled", command.Reason);

        try
        {
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return Result.Failure(TemplateVersionConflict);
        }

        InvalidateCache();
        return Result.Success();
    }

    private void CaptureRevision(
        SupportReplyTemplate template,
        Guid actorUserId,
        string? reason,
        DateTime capturedAtUtc)
    {
        supportChatDbContext.SupportReplyTemplateRevisions.Add(new SupportReplyTemplateRevision
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            Version = template.Version,
            Title = template.Title,
            Body = template.Body,
            IsEnabled = template.IsEnabled,
            SortOrder = template.SortOrder,
            ActorUserId = actorUserId,
            Reason = NormalizeReason(reason),
            CapturedAtUtc = capturedAtUtc,
        });
    }

    private void EnqueueAudit(
        SupportReplyTemplate template,
        Guid actorUserId,
        string action,
        string? reason)
    {
        SupportChatPushNotificationOutbox.EnqueueAdminAudit(
            supportChatDbContext,
            new AdminAuditEntry(
                action,
                "SupportReplyTemplate",
                template.Id.ToString("D"),
                NewValue: $"version:{template.Version};enabled:{template.IsEnabled}",
                Details: NormalizeReason(reason),
                EventId: Guid.NewGuid(),
                ActorUserId: actorUserId,
                CorrelationId: CorrelationContext.ResolveOrCreate()));
    }

    private void InvalidateCache()
    {
        memoryCache.Remove(EnabledCacheKey);
        memoryCache.Remove(AllCacheKey);
    }

    private static string? NormalizeReason(string? reason)
        => string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();

    private static SupportReplyTemplateResponse ToResponse(SupportReplyTemplate template)
    {
        return new SupportReplyTemplateResponse(
            template.Id,
            template.Title ?? string.Empty,
            template.Body ?? string.Empty,
            template.IsEnabled,
            template.SortOrder,
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            template.Version,
            template.DisabledAtUtc);
    }
}
