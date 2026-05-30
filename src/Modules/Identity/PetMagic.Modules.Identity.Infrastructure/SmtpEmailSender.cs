using System.Net;
using System.Net.Mail;
using System.Text;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class SmtpEmailSender(EmailOptions options) : IEmailSender
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
            Credentials = new NetworkCredential(options.Username, options.Password),
            EnableSsl = options.UseSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        try
        {
            await client.SendMailAsync(message, cancellationToken);
            return Result.Success();
        }
        catch (SmtpException)
        {
            return Result.Failure(IdentityErrors.EmailDispatchFailed);
        }
        catch (InvalidOperationException)
        {
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
}
