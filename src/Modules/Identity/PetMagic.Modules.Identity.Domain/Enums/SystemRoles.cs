namespace PetMagic.Modules.Identity.Domain.Enums;

public static class SystemRoles
{
    public const string User = "User";
    public const string Moderator = "Moderator";
    public const string Admin = "Admin";

    public static IReadOnlySet<string> All { get; } = new HashSet<string>(StringComparer.Ordinal)
    {
        User,
        Moderator,
        Admin
    };
}
