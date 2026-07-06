using MailKit.Net.Smtp;
using MailKit.Security;

using Microsoft.Extensions.Logging;

using MimeKit;
using MimeKit.Text;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class SmtpEmailSender(EmailOptions options, ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public async Task<Result> SendAsync(EmailDispatchJob job, CancellationToken cancellationToken)
    {
        if (!options.IsConfigured)
        {
            return Result.Failure(IdentityErrors.EmailProviderNotConfigured);
        }

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(options.FromName, options.FromAddress));
        message.To.Add(MailboxAddress.Parse(job.RecipientEmail));
        message.Subject = job.Subject;

        var textBody = string.IsNullOrWhiteSpace(job.TextBody)
            ? StripHtml(job.HtmlBody)
            : job.TextBody;

        message.Body = new BodyBuilder
        {
            TextBody = textBody,
            HtmlBody = job.HtmlBody
        }.ToMessageBody();

        try
        {
            using var client = new SmtpClient();
            await client.ConnectAsync(
                options.Host,
                options.Port,
                ResolveSecureSocketOptions(options),
                cancellationToken);

            if (options.HasCredentials)
            {
                await client.AuthenticateAsync(options.Username, options.Password, cancellationToken);
            }

            await client.SendAsync(message, cancellationToken);
            await client.DisconnectAsync(true, cancellationToken);
            return Result.Success();
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning(
                "SMTP email dispatch failed. Host={EmailHost} Port={EmailPort} UseSsl={UseSsl} HasCredentials={HasCredentials} RecipientDomain={RecipientDomain} ExceptionType={ExceptionType}",
                options.Host,
                options.Port,
                options.UseSsl,
                options.HasCredentials,
                GetRecipientDomain(job.RecipientEmail),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure(IdentityErrors.EmailDispatchFailed);
        }
    }

    private static SecureSocketOptions ResolveSecureSocketOptions(EmailOptions options)
    {
        if (!options.UseSsl)
        {
            return SecureSocketOptions.None;
        }

        return options.Port == 465
            ? SecureSocketOptions.SslOnConnect
            : SecureSocketOptions.StartTls;
    }

    private static string StripHtml(string html)
    {
        if (string.IsNullOrWhiteSpace(html))
        {
            return string.Empty;
        }

        return html
            .Replace("<p>", string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("</p>", "\n", StringComparison.OrdinalIgnoreCase)
            .Replace("<br>", "\n", StringComparison.OrdinalIgnoreCase)
            .Replace("<br/>", "\n", StringComparison.OrdinalIgnoreCase)
            .Replace("<br />", "\n", StringComparison.OrdinalIgnoreCase)
            .Trim();
    }

    private static string GetRecipientDomain(string email)
    {
        var atIndex = email.LastIndexOf('@');
        if (atIndex < 0 || atIndex == email.Length - 1)
        {
            return "unknown";
        }

        return email[(atIndex + 1)..];
    }
}
