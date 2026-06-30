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
        Assert.DoesNotContain("using System.Net.Mail;", source, StringComparison.Ordinal);
        Assert.DoesNotContain("SendMailAsync(", source, StringComparison.Ordinal);
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
