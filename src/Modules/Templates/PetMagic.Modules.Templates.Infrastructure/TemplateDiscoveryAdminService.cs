using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using Npgsql;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateDiscoveryAdminService(TemplatesDbContext dbContext) : ITemplateDiscoveryAdminService
{
    private static readonly Error Conflict = new("discovery.conflict", "The discovery configuration changed. Reload before saving again.");
    private static readonly Error Missing = new("discovery.not_found", "The requested discovery revision was not found.");

    public async Task<DiscoveryAdminResponse> GetAsync(CancellationToken cancellationToken)
    {
        var page = await dbContext.TemplateDiscoveryPages.AsNoTracking().SingleAsync(cancellationToken);
        var revisions = await dbContext.TemplateDiscoveryRevisions.AsNoTracking()
            .Where(revision => revision.Id == page.PublishedRevisionId || revision.Id == page.DraftRevisionId)
            .ToArrayAsync(cancellationToken);
        return new(page.Version,
            MapOrNull(revisions.SingleOrDefault(revision => revision.Id == page.PublishedRevisionId)),
            MapOrNull(revisions.SingleOrDefault(revision => revision.Id == page.DraftRevisionId)));
    }

    public async Task<DiscoveryHistoryResponse> HistoryAsync(int skip, int take, CancellationToken cancellationToken)
    {
        take = Math.Clamp(take, 1, 50);
        var rows = await dbContext.TemplateDiscoveryRevisions.AsNoTracking().OrderByDescending(revision => revision.Number)
            .Skip(Math.Max(0, skip)).Take(take + 1)
            .Select(revision => new DiscoveryRevisionSummary(revision.Id, revision.Number, revision.State,
                revision.UpdatedAtUtc, revision.PublishedAtUtc, revision.UpdatedBy, revision.Reason)).ToArrayAsync(cancellationToken);
        return new(rows.Take(take).ToArray(), rows.Length > take);
    }

    public async Task<Result<DiscoveryRevisionResponse>> CreateDraftAsync(
        Guid actorId, CreateDiscoveryDraftRequest request, CancellationToken cancellationToken)
    {
        var page = await dbContext.TemplateDiscoveryPages.SingleAsync(cancellationToken);
        if (page.Version != request.ExpectedPageVersion || page.DraftRevisionId is not null)
            return Result.Failure<DiscoveryRevisionResponse>(Conflict);
        var sourceId = request.SourceRevisionId ?? page.PublishedRevisionId;
        var source = sourceId is null ? null : await dbContext.TemplateDiscoveryRevisions.AsNoTracking()
            .SingleOrDefaultAsync(revision => revision.Id == sourceId && revision.State == "Published", cancellationToken);
        if (sourceId is not null && source is null) return Result.Failure<DiscoveryRevisionResponse>(Missing);
        var document = source is null ? await CreateInitialDocumentAsync(cancellationToken) : Read(source);
        var now = DateTime.UtcNow;
        var draft = new TemplateDiscoveryRevision
        {
            Id = Guid.NewGuid(),
            Number = ++page.LastRevisionNumber,
            BasedOnRevisionId = source?.Id,
            DocumentJson = TemplateDiscoveryDocument.Serialize(document),
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            CreatedBy = actorId,
            UpdatedBy = actorId
        };
        page.DraftRevisionId = draft.Id;
        page.Version++;
        dbContext.TemplateDiscoveryRevisions.Add(draft);
        Audit("draft_created", draft, actorId);
        return await SaveAsync(cancellationToken) ? Result.Success(Map(draft)) : Result.Failure<DiscoveryRevisionResponse>(Conflict);
    }

    public async Task<Result<DiscoveryRevisionResponse>> SaveDraftAsync(
        Guid actorId, Guid revisionId, SaveDiscoveryDraftRequest request, CancellationToken cancellationToken)
    {
        var issues = TemplateDiscoveryDocument.ShapeIssues(request.Document);
        if (issues.Count > 0) return Result.Failure<DiscoveryRevisionResponse>(Invalid(issues));
        var draft = await dbContext.TemplateDiscoveryRevisions.SingleOrDefaultAsync(revision => revision.Id == revisionId, cancellationToken);
        if (draft is null) return Result.Failure<DiscoveryRevisionResponse>(Missing);
        if (draft.State != "Draft" || draft.EditVersion != request.ExpectedVersion)
            return Result.Failure<DiscoveryRevisionResponse>(Conflict);
        draft.DocumentJson = TemplateDiscoveryDocument.Serialize(request.Document);
        draft.EditVersion++;
        draft.UpdatedAtUtc = DateTime.UtcNow;
        draft.UpdatedBy = actorId;
        Audit("draft_updated", draft, actorId);
        return await SaveAsync(cancellationToken) ? Result.Success(Map(draft)) : Result.Failure<DiscoveryRevisionResponse>(Conflict);
    }

    public async Task<Result<DiscoveryValidationResponse>> ValidateAsync(Guid revisionId, CancellationToken cancellationToken)
    {
        var revision = await dbContext.TemplateDiscoveryRevisions.AsNoTracking().SingleOrDefaultAsync(row => row.Id == revisionId, cancellationToken);
        return revision is null ? Result.Failure<DiscoveryValidationResponse>(Missing)
            : Result.Success(new DiscoveryValidationResponse(await ValidateDocumentAsync(Read(revision), cancellationToken)));
    }

    public async Task<Result<PublicTemplatesDiscoveryResponse>> PreviewAsync(Guid revisionId, string? locale, CancellationToken cancellationToken)
    {
        var revision = await dbContext.TemplateDiscoveryRevisions.AsNoTracking().SingleOrDefaultAsync(row => row.Id == revisionId, cancellationToken);
        return revision is null ? Result.Failure<PublicTemplatesDiscoveryResponse>(Missing)
            : Result.Success(await new TemplateDiscoveryResolver(dbContext).ResolveAsync(Read(revision), revision.Number, locale, cancellationToken));
    }

    public async Task<Result<DiscoveryRevisionResponse>> PublishAsync(
        Guid actorId, Guid revisionId, string idempotencyKey, PublishDiscoveryRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(idempotencyKey) || idempotencyKey.Length > 128 ||
            string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 500)
            return Result.Failure<DiscoveryRevisionResponse>(new("discovery.invalid", "An idempotency key and a publication reason (1–500 characters) are required."));
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            JsonSerializer.Serialize(new { revisionId, request }, TemplateDiscoveryDocument.JsonOptions))));
        var replay = await ReplayAsync(actorId, idempotencyKey, hash, cancellationToken);
        if (replay is not null) return replay;
        var page = await dbContext.TemplateDiscoveryPages.SingleAsync(cancellationToken);
        var draft = await dbContext.TemplateDiscoveryRevisions.SingleOrDefaultAsync(row => row.Id == revisionId, cancellationToken);
        if (draft is null) return Result.Failure<DiscoveryRevisionResponse>(Missing);
        if (page.Version != request.ExpectedPageVersion || page.DraftRevisionId != revisionId ||
            draft.State != "Draft" || draft.EditVersion != request.ExpectedVersion)
            return Result.Failure<DiscoveryRevisionResponse>(Conflict);
        var issues = await ValidateDocumentAsync(Read(draft), cancellationToken);
        if (issues.Count > 0) return Result.Failure<DiscoveryRevisionResponse>(Invalid(issues));
        var now = DateTime.UtcNow;
        draft.State = "Published";
        draft.EditVersion++;
        draft.PublishedAtUtc = draft.UpdatedAtUtc = now;
        draft.PublishedBy = draft.UpdatedBy = actorId;
        draft.Reason = request.Reason.Trim();
        page.PublishedRevisionId = draft.Id;
        page.DraftRevisionId = null;
        page.Version++;
        dbContext.TemplateDiscoveryCommandReceipts.Add(new()
        {
            ActorId = actorId,
            IdempotencyKey = idempotencyKey,
            RequestHash = hash,
            RevisionId = draft.Id,
            CreatedAtUtc = now
        });
        Audit("published", draft, actorId);
        // Save the invalidation in the same transaction; the existing event pump delivers it.
        dbContext.TemplateRealtimeEvents.Add(new()
        {
            Id = Guid.NewGuid(),
            Topic = TemplateFeedRealtimeTopics.TemplatesFeedInvalidated,
            CreatedAtUtc = now,
            Data = JsonSerializer.Serialize(new TemplateFeedInvalidationPayload(
                TemplateFeedInvalidationScopes.Full, IsCritical: true, Reason: "discovery_published"), TemplateDiscoveryDocument.JsonOptions)
        });
        if (await SaveAsync(cancellationToken)) return Result.Success(Map(draft));
        return await ReplayAsync(actorId, idempotencyKey, hash, cancellationToken) ?? Result.Failure<DiscoveryRevisionResponse>(Conflict);
    }

    public async Task<Result<bool>> DiscardAsync(Guid actorId, Guid revisionId, DiscardDiscoveryDraftRequest request, CancellationToken cancellationToken)
    {
        var page = await dbContext.TemplateDiscoveryPages.SingleAsync(cancellationToken);
        var draft = await dbContext.TemplateDiscoveryRevisions.SingleOrDefaultAsync(row => row.Id == revisionId, cancellationToken);
        if (draft is null) return Result.Failure<bool>(Missing);
        if (page.Version != request.ExpectedPageVersion || page.DraftRevisionId != revisionId ||
            draft.State != "Draft" || draft.EditVersion != request.ExpectedVersion) return Result.Failure<bool>(Conflict);
        draft.State = "Discarded";
        draft.EditVersion++;
        draft.UpdatedAtUtc = DateTime.UtcNow;
        draft.UpdatedBy = actorId;
        page.DraftRevisionId = null;
        page.Version++;
        Audit("draft_discarded", draft, actorId);
        return await SaveAsync(cancellationToken) ? Result.Success(true) : Result.Failure<bool>(Conflict);
    }

    private async Task<Result<DiscoveryRevisionResponse>?> ReplayAsync(Guid actorId, string key, string hash, CancellationToken cancellationToken)
    {
        var receipt = await dbContext.TemplateDiscoveryCommandReceipts.AsNoTracking()
            .SingleOrDefaultAsync(row => row.ActorId == actorId && row.IdempotencyKey == key, cancellationToken);
        if (receipt is null) return null;
        if (receipt.RequestHash != hash) return Result.Failure<DiscoveryRevisionResponse>(Conflict);
        var revision = await dbContext.TemplateDiscoveryRevisions.AsNoTracking().SingleAsync(row => row.Id == receipt.RevisionId, cancellationToken);
        return Result.Success(Map(revision));
    }

    private async Task<bool> SaveAsync(CancellationToken cancellationToken)
    {
        try { await dbContext.SaveChangesAsync(cancellationToken); return true; }
        catch (DbUpdateConcurrencyException) { dbContext.ChangeTracker.Clear(); return false; }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        { dbContext.ChangeTracker.Clear(); return false; }
    }

    private void Audit(string action, TemplateDiscoveryRevision revision, Guid actorId)
    {
        TemplateAdminAuditOutbox.Enqueue(dbContext, new AdminAuditEntry(
            $"templates.discovery.{action}", "TemplateDiscoveryRevision", revision.Id.ToString(),
            NewValue: JsonSerializer.Serialize(new { revision.Number, revision.EditVersion, revision.State }),
            Details: revision.Reason ?? action, EventId: Guid.NewGuid(), ActorUserId: actorId));
    }

    private static DiscoveryDocument Read(TemplateDiscoveryRevision revision) =>
        TemplateDiscoveryDocument.Read(revision.DocumentJson) ?? throw new InvalidOperationException("Invalid stored discovery document.");
    private static DiscoveryRevisionResponse? MapOrNull(TemplateDiscoveryRevision? revision) => revision is null ? null : Map(revision);
    private static DiscoveryRevisionResponse Map(TemplateDiscoveryRevision revision) => new(
        revision.Id, revision.Number, revision.EditVersion, revision.State, Read(revision), revision.BasedOnRevisionId,
        revision.CreatedAtUtc, revision.UpdatedAtUtc, revision.PublishedAtUtc, revision.CreatedBy,
        revision.UpdatedBy, revision.PublishedBy, revision.Reason);
    private static Error Invalid(IReadOnlyList<DiscoveryValidationIssue> issues) =>
        new("discovery.invalid", "The discovery configuration needs attention.", new Dictionary<string, object?>
        { ["issues"] = issues, ["validationErrors"] = issues.Select(issue => $"{issue.Path}: {issue.Message}").ToArray() });
}
