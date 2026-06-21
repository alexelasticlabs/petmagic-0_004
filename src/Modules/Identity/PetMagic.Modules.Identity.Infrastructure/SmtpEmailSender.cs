using System.Net;
using System.Net.Mail;
using System.Text;

using Microsoft.Extensions.Logging;

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

        using var message = new MailMessage
        {
            From = new MailAddress(options.FromAddress, options.FromName),
            Subject = job.Subject,
            SubjectEncoding = Encoding.UTF8
        };
        message.To.Add(job.RecipientEmail);

        var textBody = string.IsNullOrWhiteSpace(job.TextBody)
            ? StripHtml(job.HtmlBody)
            : job.TextBody;
        message.AlternateViews.Add(
            AlternateView.CreateAlternateViewFromString(
                textBody,
                Encoding.UTF8,
                "text/plain"));

        message.AlternateViews.Add(
            AlternateView.CreateAlternateViewFromString(
                job.HtmlBody,
                Encoding.UTF8,
                "text/html"));

        if (!string.IsNullOrWhiteSpace(job.TextBody))
        {
            message.Body = job.TextBody;
            message.IsBodyHtml = false;
            message.BodyEncoding = Encoding.UTF8;
        }
        else
        {
            message.Body = job.HtmlBody;
            message.IsBodyHtml = true;
            message.BodyEncoding = Encoding.UTF8;
        }

        using var client = new SmtpClient(options.Host, options.Port)
        {
            EnableSsl = options.UseSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        if (options.HasCredentials)
        {
            client.Credentials = new NetworkCredential(options.Username, options.Password);
        }

        try
        {
            await client.SendMailAsync(message, cancellationToken);
            return Result.Success();
        }
        catch (SmtpException exception)
        {
            logger.LogWarning(
                exception,
                "SMTP email dispatch failed. Host={EmailHost} Port={EmailPort} UseSsl={UseSsl} HasCredentials={HasCredentials} RecipientDomain={RecipientDomain}",
                options.Host,
                options.Port,
                options.UseSsl,
                options.HasCredentials,
                GetRecipientDomain(job.RecipientEmail));
            return Result.Failure(IdentityErrors.EmailDispatchFailed);
        }
        catch (InvalidOperationException exception)
        {
            logger.LogWarning(
                exception,
                "SMTP email dispatch failed before send. Host={EmailHost} Port={EmailPort} UseSsl={UseSsl} HasCredentials={HasCredentials} RecipientDomain={RecipientDomain}",
                options.Host,
                options.Port,
                options.UseSsl,
                options.HasCredentials,
                GetRecipientDomain(job.RecipientEmail));
            return Result.Failure(IdentityErrors.EmailDispatchFailed);
        }
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
