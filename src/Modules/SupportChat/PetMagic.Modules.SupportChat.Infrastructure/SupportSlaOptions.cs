using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportSlaOptions
{
    public SupportSlaTarget Low { get; init; } = new(480, 4320);

    public SupportSlaTarget Normal { get; init; } = new(240, 1440);

    public SupportSlaTarget High { get; init; } = new(60, 480);

    public SupportSlaTarget Urgent { get; init; } = new(15, 240);

    public SupportSlaTarget GetTarget(SupportConversationPriority priority)
    {
        return priority switch
        {
            SupportConversationPriority.Low => Low,
            SupportConversationPriority.High => High,
            SupportConversationPriority.Urgent => Urgent,
            _ => Normal,
        };
    }
}

public sealed record SupportSlaTarget(int FirstResponseMinutes, int ResolutionMinutes);
