namespace PetMagic.Modules.Identity.Infrastructure.Options;

public sealed class ExternalAuthOptions
{
    public const string SectionName = "ExternalAuth";

    public GoogleOAuthOptions Google { get; init; } = new();

    public OAuthProviderOptions Apple { get; init; } = new();

    public sealed class GoogleOAuthOptions
    {
        public string ClientId { get; init; } = string.Empty;

        public string ClientSecret { get; init; } = string.Empty;
    }

    public sealed class OAuthProviderOptions
    {
        public string ClientId { get; init; } = string.Empty;

        public string ClientSecret { get; init; } = string.Empty;

        public string AuthorizationEndpoint { get; init; } = string.Empty;

        public string TokenEndpoint { get; init; } = string.Empty;
    }
}
