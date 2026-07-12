using System.Net;

using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace PetMagic.Host.Api.Security;

public sealed record ForwardedHeadersTrustSettings(
    bool Enabled,
    bool TrustAll,
    int ForwardLimit,
    IReadOnlyList<string> KnownProxies,
    IReadOnlyList<string> KnownNetworks)
{
    public const string SectionName = "ForwardedHeaders";

    public static ForwardedHeadersTrustSettings Read(IConfiguration configuration)
    {
        var section = configuration.GetSection(SectionName);
        return new ForwardedHeadersTrustSettings(
            section.GetValue("Enabled", false),
            section.GetValue("TrustAll", false),
            Math.Max(1, section.GetValue("ForwardLimit", 1)),
            section.GetSection("KnownProxies").Get<string[]>() ?? [],
            section.GetSection("KnownNetworks").Get<string[]>() ?? []);
    }
}

public static class ForwardedHeadersTrust
{
    public static void Validate(ForwardedHeadersTrustSettings settings, IHostEnvironment environment)
    {
        if (!settings.Enabled)
        {
            if (!environment.IsDevelopment())
            {
                throw new InvalidOperationException(
                    "ForwardedHeaders must be enabled with an explicit trust policy outside Development.");
            }

            return;
        }

        if (!settings.TrustAll
            && settings.KnownProxies.Count == 0
            && settings.KnownNetworks.Count == 0
            && !environment.IsDevelopment())
        {
            throw new InvalidOperationException(
                "ForwardedHeaders is enabled outside Development, but no trusted proxy boundary is configured. "
                + "Set ForwardedHeaders:KnownProxies/KnownNetworks or explicitly set ForwardedHeaders:TrustAll=true for a closed platform proxy boundary.");
        }

        foreach (var value in settings.KnownProxies)
        {
            if (!IPAddress.TryParse(value, out _))
            {
                throw new InvalidOperationException($"ForwardedHeaders:KnownProxies contains invalid IP address '{value}'.");
            }
        }

        foreach (var value in settings.KnownNetworks)
        {
            if (!System.Net.IPNetwork.TryParse(value, out _))
            {
                throw new InvalidOperationException($"ForwardedHeaders:KnownNetworks contains invalid CIDR '{value}'.");
            }
        }
    }

    public static ForwardedHeadersOptions BuildOptions(ForwardedHeadersTrustSettings settings)
    {
        var options = new ForwardedHeadersOptions
        {
            ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
            ForwardLimit = settings.ForwardLimit,
            RequireHeaderSymmetry = true
        };

        options.KnownProxies.Clear();
        options.KnownIPNetworks.Clear();

        if (settings.TrustAll)
        {
            return options;
        }

        foreach (var value in settings.KnownProxies)
        {
            options.KnownProxies.Add(IPAddress.Parse(value));
        }

        foreach (var value in settings.KnownNetworks)
        {
            options.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(value));
        }

        return options;
    }
}
