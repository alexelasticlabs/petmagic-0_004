using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private SupportConversationSlaResponse BuildSla(
        SupportConversationPriority priority,
        DateTime createdAtUtc,
        DateTime? firstResponseAtUtc,
        DateTime? resolvedAtUtc,
        DateTime? resolutionSlaPausedAtUtc,
        long resolutionSlaPausedSeconds,
        DateTime now)
    {
        var target = slaOptions.GetTarget(priority);
        var terminalAtUtc = resolvedAtUtc ?? now;
        var activePauseSeconds = resolutionSlaPausedAtUtc.HasValue && !resolvedAtUtc.HasValue
            ? Math.Max(0, (long)Math.Floor((now - resolutionSlaPausedAtUtc.Value).TotalSeconds))
            : 0;
        var totalPauseSeconds = Math.Max(0, resolutionSlaPausedSeconds) + activePauseSeconds;
        var firstResponseDueAtUtc = createdAtUtc.AddMinutes(target.FirstResponseMinutes);
        var resolutionDueAtUtc = createdAtUtc
            .AddMinutes(target.ResolutionMinutes)
            .AddSeconds(totalPauseSeconds);

        var firstResponseStatus = firstResponseAtUtc.HasValue
            ? firstResponseAtUtc.Value <= firstResponseDueAtUtc ? "Met" : "Breached"
            : terminalAtUtc <= firstResponseDueAtUtc ? "Pending" : "Breached";
        var resolutionStatus = resolvedAtUtc.HasValue
            ? resolvedAtUtc.Value <= resolutionDueAtUtc ? "Met" : "Breached"
            : resolutionSlaPausedAtUtc.HasValue
                ? "Paused"
                : now <= resolutionDueAtUtc ? "Pending" : "Breached";

        return new SupportConversationSlaResponse(
            firstResponseDueAtUtc,
            resolutionDueAtUtc,
            firstResponseAtUtc,
            firstResponseStatus,
            resolutionStatus,
            resolutionSlaPausedAtUtc.HasValue && !resolvedAtUtc.HasValue,
            CalculateRemainingMinutes(firstResponseDueAtUtc, firstResponseAtUtc ?? terminalAtUtc),
            CalculateRemainingMinutes(resolutionDueAtUtc, terminalAtUtc));
    }

    private static int CalculateRemainingMinutes(DateTime dueAtUtc, DateTime referenceAtUtc)
    {
        return (int)Math.Clamp(
            Math.Ceiling((dueAtUtc - referenceAtUtc).TotalMinutes),
            int.MinValue,
            int.MaxValue);
    }
}
