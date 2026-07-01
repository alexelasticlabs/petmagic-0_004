namespace PetMagic.Modules.Identity.Infrastructure;

public static class LegalAcceptanceRequirementCache
{
    public static string BuildKey(Guid userId)
    {
        return $"legal_acceptance:{userId:D}";
    }
}
