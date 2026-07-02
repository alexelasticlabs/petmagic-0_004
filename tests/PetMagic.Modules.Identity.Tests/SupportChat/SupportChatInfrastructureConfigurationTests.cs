using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.SupportChat.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatInfrastructureConfigurationTests
{
    [Fact]
    public void AddSupportChatInfrastructure_ShouldFailFast_WhenProductionPushIsEnabledWithoutFirebaseCredentials()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["SupportChat:FirebasePush:Enabled"] = "true",
            ["SupportChat:FirebasePush:ProjectId"] = "petmagic-production",
            ["ConnectionStrings:DefaultConnection"] = "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
        });

        var exception = Assert.Throws<InvalidOperationException>(() =>
            new ServiceCollection().AddSupportChatInfrastructure(configuration, isProduction: true));

        Assert.Contains("SupportChat Firebase push is enabled", exception.Message);
    }

    [Fact]
    public void AddSupportChatInfrastructure_ShouldAllowProduction_WhenPushIsDisabled()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["SupportChat:FirebasePush:Enabled"] = "false",
            ["ConnectionStrings:DefaultConnection"] = "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
        });

        new ServiceCollection().AddSupportChatInfrastructure(configuration, isProduction: true);
    }

    [Fact]
    public void AddSupportChatInfrastructure_ShouldAllowProduction_WhenPushCredentialsAreConfigured()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["SupportChat:FirebasePush:Enabled"] = "true",
            ["SupportChat:FirebasePush:ProjectId"] = "petmagic-production",
            ["SupportChat:FirebasePush:ServiceAccountJson"] = """{"type":"service_account"}""",
            ["ConnectionStrings:DefaultConnection"] = "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
        });

        new ServiceCollection().AddSupportChatInfrastructure(configuration, isProduction: true);
    }

    [Fact]
    public void AddSupportChatInfrastructure_ShouldConfigureFcmHttpClientTimeout()
    {
        var repositoryRoot = FindRepositoryRoot();
        var source = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "SupportChatInfrastructureServiceCollectionExtensions.cs"));

        Assert.Contains("private static readonly TimeSpan PushHttpClientTimeout = TimeSpan.FromSeconds(30);", source, StringComparison.Ordinal);
        Assert.Contains("services.AddHttpClient<FcmSupportChatPushNotificationSender>(client =>", source, StringComparison.Ordinal);
        Assert.Contains("client.Timeout = PushHttpClientTimeout", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AddSupportChatInfrastructure_ShouldUseShortLivedSupportAttachmentReadUrlsByDefault()
    {
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            ["Jwt:SigningKey"] = new string('s', 64),
        });

        var services = new ServiceCollection();
        services.AddSupportChatInfrastructure(configuration, isProduction: false);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<SupportAttachmentReadUrlSigningOptions>();

        Assert.Equal(60, options.ReadUrlTtlMinutes);
    }

    private static IConfiguration CreateConfiguration(IReadOnlyDictionary<string, string?> values) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Repository root was not found.");
    }
}
