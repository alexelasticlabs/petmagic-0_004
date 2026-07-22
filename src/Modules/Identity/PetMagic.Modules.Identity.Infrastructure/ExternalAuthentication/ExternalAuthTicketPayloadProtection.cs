using System.Security.Cryptography;

using Microsoft.AspNetCore.DataProtection;

namespace PetMagic.Modules.Identity.Infrastructure.ExternalAuthentication;

internal static class ExternalAuthTicketPayloadProtection
{
    private const string RootPurpose = "PetMagic.Identity.ExternalAuthTicket";

    public static IDataProtector CreateProtector(IDataProtectionProvider provider, string purpose)
    {
        return provider.CreateProtector(RootPurpose, purpose, "v1");
    }

    public static string ProtectJson(IDataProtector protector, string payloadJson)
    {
        return protector.Protect(payloadJson);
    }

    public static string UnprotectJsonOrLegacy(IDataProtector protector, string persistedPayload)
    {
        try
        {
            return protector.Unprotect(persistedPayload);
        }
        catch (CryptographicException)
        {
            return persistedPayload;
        }
    }
}
