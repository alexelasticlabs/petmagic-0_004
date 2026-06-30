namespace PetMagic.Modules.Identity.Infrastructure.Options;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; init; } = "petmagic-api";

    public string Audience { get; init; } = "petmagic-clients";

    public string SigningKey { get; init; } = string.Empty;

    public int AccessTokenMinutes { get; init; } = 30;

    public int RefreshTokenDays { get; init; } = 30;
}
