namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private const int PasswordLockoutThreshold = 8;
    private const int PasswordLockoutBaseMinutes = 15;
    private const int PasswordLockoutMaxHours = 24;
}
