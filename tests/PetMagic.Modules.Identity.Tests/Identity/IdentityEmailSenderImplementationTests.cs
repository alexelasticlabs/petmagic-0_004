using System.Reflection;

using MailKit.Security;

using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityEmailSenderImplementationTests
{
    [Fact]
    public void IdentityEmailSender_ShouldUseMailKitInsteadOfLegacySystemNetMailSmtpClient()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "SmtpEmailSender.cs"));

        Assert.Contains("using MailKit.Net.Smtp;", source, StringComparison.Ordinal);
        Assert.Contains("using MimeKit;", source, StringComparison.Ordinal);
        Assert.Contains("new MimeMessage()", source, StringComparison.Ordinal);
        Assert.Contains("new BodyBuilder", source, StringComparison.Ordinal);
        Assert.Contains("await client.ConnectAsync(", source, StringComparison.Ordinal);
        Assert.Contains("await client.SendAsync(message, cancellationToken);", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(exception)", source, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("using System.Net.Mail;", source, StringComparison.Ordinal);
        Assert.DoesNotContain("SendMailAsync(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("logger.LogWarning(\r\n                exception,", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(false, 1025, SecureSocketOptions.None)]
    [InlineData(true, 465, SecureSocketOptions.SslOnConnect)]
    [InlineData(true, 587, SecureSocketOptions.StartTls)]
    [InlineData(true, 2525, SecureSocketOptions.StartTls)]
    public void IdentityEmailSender_ShouldUseStrictTls_WhenSslIsEnabled(
        bool useSsl,
        int port,
        SecureSocketOptions expected)
    {
        var method = typeof(SmtpEmailSender).GetMethod(
            "ResolveSecureSocketOptions",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var actual = method!.Invoke(null, [new EmailOptions { UseSsl = useSsl, Port = port }]);

        Assert.Equal(expected, actual);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
