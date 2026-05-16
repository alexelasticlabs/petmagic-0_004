using System.Net;
using System.Net.Mail;
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
            Body = job.HtmlBody,
            IsBodyHtml = true
        };
        message.To.Add(job.RecipientEmail);

        if (!string.IsNullOrWhiteSpace(job.TextBody))
        {
            var plainView = AlternateView.CreateAlternateViewFromString(job.TextBody, null, "text/plain");
            message.AlternateViews.Add(plainView);
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
}