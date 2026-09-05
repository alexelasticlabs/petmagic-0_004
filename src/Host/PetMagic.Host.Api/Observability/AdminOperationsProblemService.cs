using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Host.Api.Observability;

public interface IAdminOperationsProblemService
{
    Task<AdminOperationsProblemListDto> GetAsync(string source, CancellationToken cancellationToken = default);
}

/// <summary>
/// Returns only routing and diagnostic metadata for non-complete outbox work.
/// Message payloads, recipients, and provider error messages deliberately never cross the admin API.
/// </summary>
public sealed class AdminOperationsProblemService(IServiceScopeFactory scopeFactory) : IAdminOperationsProblemService
{
    private const int Take = 100;
    private const string AuditOutboxKind = "admin_audit";

    public async Task<AdminOperationsProblemListDto> GetAsync(
        string source,
        CancellationToken cancellationToken = default)
    {
        if (source is not ("email" or "audit" or "push"))
        {
            throw new ArgumentOutOfRangeException(nameof(source));
        }

        using var scope = scopeFactory.CreateScope();
        var services = scope.ServiceProvider;
        var identity = services.GetRequiredService<IdentityDbContext>();

        if (source == "email")
        {
            var rows = await identity.EmailDispatchJobs
                .AsNoTracking()
                .Where(job => job.Status != EmailDispatchStatus.Sent)
                .OrderByDescending(job => job.Status == EmailDispatchStatus.Failed)
                .ThenBy(job => job.QueuedAtUtc)
                .Take(Take)
                .Select(job => new
                {
                    job.Id,
                    job.Kind,
                    job.Status,
                    job.AttemptCount,
                    job.QueuedAtUtc,
                    job.UpdatedAtUtc,
                    job.NextAttemptAtUtc,
                    job.FailureCode
                })
                .ToListAsync(cancellationToken);
            var emailItems = rows.Select(job => new AdminOperationsProblemDto(
                "email",
                "identity",
                job.Id.ToString(),
                job.Kind.ToString(),
                job.Status.ToString(),
                job.AttemptCount,
                job.QueuedAtUtc,
                job.UpdatedAtUtc,
                job.NextAttemptAtUtc,
                job.FailureCode)).ToArray();
            return new AdminOperationsProblemListDto(source, emailItems);
        }

        var economyTask = ReadOutboxAsync(
            services.GetRequiredService<EconomyDbContext>().PushOutboxMessages,
            source,
            "economy",
            cancellationToken);
        var templatesTask = ReadOutboxAsync(
            services.GetRequiredService<TemplatesDbContext>().PushOutboxMessages,
            source,
            "templates",
            cancellationToken);
        var supportTask = ReadOutboxAsync(
            services.GetRequiredService<SupportChatDbContext>().PushOutboxMessages,
            source,
            "support",
            cancellationToken);

        await Task.WhenAll(economyTask, templatesTask, supportTask);
        var items = economyTask.Result
            .Concat(templatesTask.Result)
            .Concat(supportTask.Result)
            .OrderByDescending(item => item.Status == PushOutboxStatus.DeadLetter.ToString())
            .ThenBy(item => item.CreatedAtUtc)
            .Take(Take)
            .ToArray();

        return new AdminOperationsProblemListDto(source, items);
    }

    private static async Task<IReadOnlyList<AdminOperationsProblemDto>> ReadOutboxAsync(
        IQueryable<PushOutboxMessage> query,
        string source,
        string module,
        CancellationToken cancellationToken)
    {
        var isAudit = source == "audit";
        var rows = await query
            .AsNoTracking()
            .Where(message => (message.Kind == AuditOutboxKind) == isAudit
                && message.Status != PushOutboxStatus.Sent
                && message.Status != PushOutboxStatus.Dismissed)
            .OrderByDescending(message => message.Status == PushOutboxStatus.DeadLetter)
            .ThenBy(message => message.CreatedAtUtc)
            .Take(Take)
            .Select(message => new
            {
                message.Id,
                message.Kind,
                message.Status,
                message.AttemptCount,
                message.CreatedAtUtc,
                message.UpdatedAtUtc,
                message.NextAttemptAtUtc,
                message.LastErrorCode
            })
            .ToListAsync(cancellationToken);
        return rows.Select(message => new AdminOperationsProblemDto(
            source,
            module,
            message.Id.ToString(),
            message.Kind,
            message.Status.ToString(),
            message.AttemptCount,
            message.CreatedAtUtc,
            message.UpdatedAtUtc,
            message.NextAttemptAtUtc,
            message.LastErrorCode)).ToArray();
    }
}
