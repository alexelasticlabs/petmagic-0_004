using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class IdentityAdminUserAnalyticsService(
    UserManager<AppUser> userManager,
    IdentityDbContext dbContext,
    IAdminUserEconomyAnalyticsReader economyAnalyticsReader,
    IAdminUserTemplateAnalyticsReader templateAnalyticsReader)
{
    public async Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var userExists = await userManager.Users.AnyAsync(x => x.Id == userId, cancellationToken);
        if (!userExists)
        {
            return Result.Failure<AdminUserAnalyticsResponse>(IdentityErrors.UserNotFound);
        }

        var economySliceTask = economyAnalyticsReader.GetAdminUserEconomyAnalyticsAsync(userId, cancellationToken);
        var templateSliceTask = templateAnalyticsReader.GetAdminUserTemplateAnalyticsAsync(userId, cancellationToken);
        var auditSliceTask = LoadAuditSliceAsync(userId, cancellationToken);

        await Task.WhenAll(economySliceTask, templateSliceTask, auditSliceTask);

        var economySliceResult = await economySliceTask;
        if (economySliceResult.IsFailure)
        {
            return Result.Failure<AdminUserAnalyticsResponse>(economySliceResult.Error);
        }

        var templateSliceResult = await templateSliceTask;
        if (templateSliceResult.IsFailure)
        {
            return Result.Failure<AdminUserAnalyticsResponse>(templateSliceResult.Error);
        }

        var economySlice = economySliceResult.Value;
        var templateSlice = templateSliceResult.Value;
        var auditSlice = await auditSliceTask;

        var activityMoments = new[]
        {
            auditSlice.LastAuditAtUtc,
            economySlice.LastPurchaseAtUtc,
            economySlice.LastWalletActivityAtUtc,
            templateSlice.LastGenerationAtUtc,
            templateSlice.LastTemplateEventAtUtc,
        }.Where(x => x.HasValue).Select(x => x!.Value).ToArray();

        var summary = new AdminUserAnalyticsSummaryResponse(
            economySlice.WalletBalance,
            economySlice.TotalTokensCredited,
            economySlice.TotalTokensSpent,
            economySlice.ManualTokensGranted,
            economySlice.ManualTokensDebited,
            economySlice.TotalPurchases,
            economySlice.SuccessfulPurchases,
            economySlice.TotalPurchasedSpark,
            economySlice.LastPurchaseAtUtc,
            templateSlice.TotalGenerations,
            templateSlice.CompletedGenerations,
            templateSlice.FailedGenerations,
            templateSlice.LastGenerationAtUtc,
            templateSlice.TotalViews,
            templateSlice.TotalVideoViews,
            auditSlice.SuccessfulLogins,
            auditSlice.FailedLogins,
            auditSlice.LastLoginAtUtc,
            templateSlice.TemplateAnalyticsEvents,
            auditSlice.AuditEventsCount,
            activityMoments.Length > 0 ? activityMoments.Max() : null);

        var recentActivity = auditSlice.RecentActivity
            .Concat(economySlice.RecentActivity.Select(x =>
                new AdminUserActivityItemResponse(x.Kind, x.Title, x.Details, x.OccurredAtUtc)))
            .Concat(templateSlice.RecentActivity.Select(x =>
                new AdminUserActivityItemResponse(x.Kind, x.Title, x.Details, x.OccurredAtUtc)))
            .OrderByDescending(x => x.OccurredAtUtc)
            .Take(20)
            .ToList();

        var recentPurchases = economySlice.RecentPurchases
            .Select(x => new AdminUserPurchaseResponse(
                x.OrderId,
                x.Status,
                x.PriceAmount,
                x.CurrencyCode,
                x.SparkToGrant,
                x.PaymentProvider,
                x.CreatedAtUtc,
                x.ConfirmedAtUtc))
            .ToList();

        var recentWalletLedger = economySlice.RecentWalletLedger
            .Select(x => new AdminUserWalletLedgerItemResponse(
                x.EntryId,
                x.Delta,
                x.BalanceAfter,
                x.Source,
                x.Reason,
                x.CreatedAtUtc))
            .ToList();

        var recentGenerations = templateSlice.RecentGenerations
            .Select(x => new AdminUserGenerationResponse(
                x.GenerationId,
                x.TemplateId,
                x.TemplateTitle,
                x.TemplateType,
                x.Status,
                x.TokenCost,
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
                x.CreatedAtUtc,
                x.CompletedAtUtc))
            .ToList();

        var recentTemplateEvents = templateSlice.RecentTemplateEvents
            .Select(x => new AdminUserTemplateEventResponse(
                x.EventId,
                x.TemplateId,
                x.TemplateTitle,
                x.EventType,
                x.Source,
                x.DeviceClass,
                x.CountryCode,
                x.GenerationId,
                x.FeedbackMessage,
                x.CreatedAtUtc))
            .ToList();

        var failureBreakdown = templateSlice.FailureBreakdown
            .Select(x => new AdminUserFailureBreakdownItemResponse(
                x.FailureCode,
                x.Count,
                x.LastOccurredAtUtc))
            .ToList();

        return Result.Success(new AdminUserAnalyticsResponse(
            summary,
            recentActivity,
            auditSlice.RecentAuditEvents,
            recentPurchases,
            recentGenerations,
            recentTemplateEvents,
            recentWalletLedger,
            failureBreakdown));
    }

    private async Task<AdminUserAuditSlice> LoadAuditSliceAsync(Guid userId, CancellationToken cancellationToken)
    {
        var auditSummary = await dbContext.AuditEvents
            .AsNoTracking()
            .Where(x => x.SubjectUserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                AuditEventsCount = group.Count(),
                SuccessfulLogins = group.Count(x => x.Action == "auth.login.succeeded"),
                FailedLogins = group.Count(x => x.Action == "auth.login.failed"),
                LastLoginAtUtc = group.Where(x => x.Action == "auth.login.succeeded").Max(x => (DateTime?)x.OccurredAtUtc),
                LastAuditAtUtc = group.Max(x => (DateTime?)x.OccurredAtUtc)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var recentAuditEvents = await dbContext.AuditEvents
            .AsNoTracking()
            .Where(x => x.SubjectUserId == userId)
            .OrderByDescending(x => x.OccurredAtUtc)
            .Take(12)
            .Select(x => new AdminUserAuditEventResponse(x.Id, x.Action, x.Details, x.OccurredAtUtc))
            .ToListAsync(cancellationToken);

        var recentActivity = recentAuditEvents
            .Select(x => new AdminUserActivityItemResponse("audit", x.Action, x.Details, x.OccurredAtUtc))
            .ToList();

        return new AdminUserAuditSlice(
            auditSummary?.SuccessfulLogins ?? 0,
            auditSummary?.FailedLogins ?? 0,
            auditSummary?.LastLoginAtUtc,
            auditSummary?.AuditEventsCount ?? 0,
            auditSummary?.LastAuditAtUtc,
            recentAuditEvents,
            recentActivity);
    }

    private sealed record AdminUserAuditSlice(
        int SuccessfulLogins,
        int FailedLogins,
        DateTime? LastLoginAtUtc,
        int AuditEventsCount,
        DateTime? LastAuditAtUtc,
        IReadOnlyList<AdminUserAuditEventResponse> RecentAuditEvents,
        IReadOnlyList<AdminUserActivityItemResponse> RecentActivity);
}
