namespace PetMagic.Modules.SupportChat.Domain.Enums;

public enum SupportConversationStatus
{
    New = 0,
    [Obsolete("Use New.")]
    Open = New,
    InProgress = 1,
    [Obsolete("Legacy status. Use Closed.")]
    Resolved = 2,
    Closed = 3,
    [Obsolete("Legacy status. Use New or InProgress.")]
    WaitingForSupport = 4,
    WaitingForUser = 5
}
