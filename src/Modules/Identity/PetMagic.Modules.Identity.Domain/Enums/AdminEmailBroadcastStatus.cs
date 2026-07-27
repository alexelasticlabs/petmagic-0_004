namespace PetMagic.Modules.Identity.Domain.Enums;

public enum AdminEmailBroadcastStatus
{
    Legacy = 0,
    Queued = 1,
    Processing = 2,
    Completed = 3,
    PartiallyFailed = 4,
    Failed = 5
}
