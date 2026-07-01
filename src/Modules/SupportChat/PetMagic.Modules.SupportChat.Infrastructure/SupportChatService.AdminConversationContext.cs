using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        SupportConversationMessagesQuery query,
        CancellationToken cancellationToken)
    {
        var exists = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AnyAsync(x => x.Id == conversationId, cancellationToken);
        if (!exists)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId, query, cancellationToken));
    }

    public Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
        => GetAdminConversationAsync(conversationId, new SupportConversationMessagesQuery(), cancellationToken);

    public async Task<Result<SupportTicketContextResponse>> GetAdminTicketContextAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .Where(x => x.Id == conversationId)
            .Select(x => new
            {
                x.InitiatorUserId,
                x.RelatedGenerationId,
                x.RelatedPaymentId,
                x.RelatedSubscriptionId
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportTicketContextResponse>(ConversationNotFound);
        }

        var subscriptionSummaryTask = economyService?.GetSubscriptionSummaryAsync(
            conversation.InitiatorUserId,
            cancellationToken);
        var economyAnalyticsTask = adminUserEconomyAnalyticsReader?.GetAdminUserEconomyAnalyticsAsync(
            conversation.InitiatorUserId,
            cancellationToken);
        var templateAnalyticsTask = adminUserTemplateAnalyticsReader?.GetAdminUserTemplateAnalyticsAsync(
            conversation.InitiatorUserId,
            cancellationToken);
        var linkedGenerationTask = conversation.RelatedGenerationId.HasValue && templateGenerationService is not null
            ? templateGenerationService.GetAdminAsync(conversation.RelatedGenerationId.Value, cancellationToken)
            : null;

        var tokenBalance = 0;
        var plan = "Free";
        var premiumStatus = "Inactive";
        object? lastPayment = null;
        object? lastGeneration = null;
        string? lastGenerationError = null;
        var generationErrorsCount = 0;

        if (subscriptionSummaryTask is not null)
        {
            var subscriptionSummaryResult = await subscriptionSummaryTask;
            if (subscriptionSummaryResult.IsSuccess)
            {
                var summary = subscriptionSummaryResult.Value;
                tokenBalance = summary.TokensAvailable;
                plan = NormalizeSubscriptionPlanName(summary.PlanName, summary.IsPremium);
                premiumStatus = NormalizeSubscriptionStatus(summary.Status, summary.IsPremium);
            }
        }

        if (economyAnalyticsTask is not null)
        {
            var economyAnalyticsResult = await economyAnalyticsTask;
            if (economyAnalyticsResult.IsSuccess)
            {
                var analytics = economyAnalyticsResult.Value;
                tokenBalance = analytics.WalletBalance;
                var recentPurchase = analytics.RecentPurchases.FirstOrDefault();
                if (recentPurchase is not null)
                {
                    lastPayment = MapLastPayment(recentPurchase);
                }
            }
        }

        if (templateAnalyticsTask is not null)
        {
            var templateAnalyticsResult = await templateAnalyticsTask;
            if (templateAnalyticsResult.IsSuccess)
            {
                var analytics = templateAnalyticsResult.Value;
                generationErrorsCount = analytics.FailedGenerations;

                var recentGeneration = analytics.RecentGenerations.FirstOrDefault();
                if (recentGeneration is not null)
                {
                    lastGeneration = MapLastGeneration(recentGeneration);
                    lastGenerationError = recentGeneration.FailureMessage ?? recentGeneration.FailureCode;
                }
            }
        }

        if (linkedGenerationTask is not null)
        {
            var linkedGenerationResult = await linkedGenerationTask;
            if (linkedGenerationResult.IsSuccess)
            {
                var generation = linkedGenerationResult.Value;
                lastGeneration = MapLastGeneration(generation);
                lastGenerationError = generation.FailureMessage ?? generation.FailureCode;
            }
        }

        return Result.Success(new SupportTicketContextResponse(
            TokenBalance: tokenBalance,
            Plan: plan,
            PremiumStatus: premiumStatus,
            LastPayment: lastPayment,
            LinkedGeneration: conversation.RelatedGenerationId,
            LastGeneration: lastGeneration,
            LastGenerationError: lastGenerationError,
            GenerationErrorsCount: generationErrorsCount,
            RelatedPaymentId: conversation.RelatedPaymentId,
            RelatedSubscriptionId: conversation.RelatedSubscriptionId));
    }

    private static string NormalizeSubscriptionPlanName(string? planName, bool isPremium)
    {
        var normalizedPlanName = planName?.Trim();
        if (!string.IsNullOrWhiteSpace(normalizedPlanName))
        {
            return normalizedPlanName;
        }

        return isPremium ? "Premium" : "Free";
    }

    private static string NormalizeSubscriptionStatus(string? status, bool isPremium)
    {
        var normalizedStatus = status?.Trim();
        if (string.IsNullOrWhiteSpace(normalizedStatus))
        {
            return isPremium ? "Active" : "Inactive";
        }

        return !isPremium && string.Equals(normalizedStatus, "None", StringComparison.OrdinalIgnoreCase)
            ? "Inactive"
            : normalizedStatus;
    }

    private static object MapLastPayment(AdminUserEconomyPurchaseResponse purchase)
    {
        return new
        {
            purchase.OrderId,
            purchase.Status,
            purchase.PriceAmount,
            purchase.CurrencyCode,
            purchase.SparkToGrant,
            purchase.PaymentProvider,
            purchase.CreatedAtUtc,
            purchase.ConfirmedAtUtc
        };
    }

    private static object MapLastGeneration(AdminUserTemplateGenerationResponse generation)
    {
        return new
        {
            generation.GenerationId,
            generation.TemplateId,
            generation.TemplateTitle,
            generation.TemplateType,
            generation.Status,
            generation.TokenCost,
            generation.FailureCode,
            generation.FailureMessage,
            generation.OutputUrl,
            generation.CreatedAtUtc,
            generation.CompletedAtUtc
        };
    }

    private static object MapLastGeneration(TemplateGenerationResponse generation)
    {
        return new
        {
            generation.GenerationId,
            generation.TemplateId,
            generation.TemplateTitle,
            generation.TemplateType,
            generation.Status,
            generation.TokenCost,
            generation.FailureCode,
            generation.FailureMessage,
            generation.OutputUrl,
            generation.CreatedAtUtc,
            generation.CompletedAtUtc
        };
    }
}
