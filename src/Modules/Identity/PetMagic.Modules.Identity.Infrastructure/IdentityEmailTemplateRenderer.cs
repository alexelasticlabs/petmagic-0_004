using System.Net;

namespace PetMagic.Modules.Identity.Infrastructure;

public interface IIdentityEmailTemplateRenderer
{
    RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc);

    RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc);
}

public sealed record RenderedEmailMessage(string Subject, string HtmlBody, string TextBody);

internal sealed class IdentityEmailTemplateRenderer : IIdentityEmailTemplateRenderer
{
    public RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc)
    {
        return RenderSecurityCodeEmail(
                displayName,
                code,
                expiresAtUtc,
                subject: "Verify your email for PetMagic",
                heading: "Confirm your email",
                intro: "Use this code to verify your PetMagic account and finish setup.",
                codeCaption: "Email confirmation code",
                footerHint: "If you did not create a PetMagic account, you can ignore this email.");
    }

    public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc)
    {
        return RenderSecurityCodeEmail(
                displayName,
                code,
                expiresAtUtc,
                subject: "Reset your PetMagic password",
                heading: "Password reset requested",
                intro: "Use this one-time code to reset your password.",
                codeCaption: "Password reset code",
                footerHint: "If you did not request a password reset, you can ignore this email and keep your password unchanged.");
    }

    private static RenderedEmailMessage RenderSecurityCodeEmail(
            string? displayName,
            string code,
            DateTime expiresAtUtc,
            string subject,
            string heading,
            string intro,
            string codeCaption,
            string footerHint)
    {
        var safeName = NormalizeDisplayName(displayName);
        var expiryText = $"{expiresAtUtc:yyyy-MM-dd HH:mm} UTC";

        var encodedName = WebUtility.HtmlEncode(safeName);
        var encodedCode = WebUtility.HtmlEncode(code);
        var encodedHeading = WebUtility.HtmlEncode(heading);
        var encodedIntro = WebUtility.HtmlEncode(intro);
        var encodedCodeCaption = WebUtility.HtmlEncode(codeCaption);
        var encodedExpiryText = WebUtility.HtmlEncode(expiryText);
        var encodedFooterHint = WebUtility.HtmlEncode(footerHint);

        var htmlBody = $"""
                        <!doctype html>
                        <html lang="en">
                        <body style="margin:0;padding:0;background-color:#f2f5f9;font-family:Segoe UI,Arial,sans-serif;color:#1f2937;">
                            <span style="display:none!important;visibility:hidden;opacity:0;color:transparent;height:0;width:0;overflow:hidden;">{encodedHeading} - your PetMagic security code</span>
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="padding:24px 12px;">
                                <tr>
                                    <td align="center">
                                        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:620px;background:#ffffff;border:1px solid #d8e1ee;border-radius:18px;overflow:hidden;">
                                            <tr>
                                                <td style="padding:24px 28px;background:#0f2742;">
                                                    <div style="font-size:12px;letter-spacing:1.5px;text-transform:uppercase;color:#9ec6ff;font-weight:600;">PetMagic</div>
                                                    <div style="margin-top:6px;font-size:24px;line-height:30px;color:#ffffff;font-weight:700;">{encodedHeading}</div>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding:28px;">
                                                    <p style="margin:0 0 12px 0;font-size:16px;line-height:24px;">Hi {encodedName},</p>
                                                    <p style="margin:0 0 18px 0;font-size:15px;line-height:24px;color:#334155;">{encodedIntro}</p>
                                                    <p style="margin:0 0 10px 0;font-size:12px;line-height:18px;letter-spacing:1px;text-transform:uppercase;color:#64748b;font-weight:600;">{encodedCodeCaption}</p>
                                                    <div style="display:inline-block;padding:14px 18px;border-radius:12px;background:#eff6ff;border:1px solid #c8defc;font-size:30px;line-height:32px;font-weight:700;letter-spacing:5px;color:#0f2742;">{encodedCode}</div>
                                                    <p style="margin:16px 0 0 0;font-size:13px;line-height:20px;color:#475569;">Valid until <strong>{encodedExpiryText}</strong>.</p>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding:18px 28px 24px 28px;border-top:1px solid #e2e8f0;background:#f8fafc;">
                                                    <p style="margin:0;font-size:13px;line-height:20px;color:#475569;">{encodedFooterHint}</p>
                                                    <p style="margin:10px 0 0 0;font-size:12px;line-height:18px;color:#64748b;">PetMagic team</p>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                        </body>
                        </html>
                        """;

        var textBody =
                $"Hi {safeName},\n\n" +
                $"{intro}\n\n" +
                $"{codeCaption}: {code}\n" +
                $"Valid until: {expiryText}\n\n" +
                $"{footerHint}\n\n" +
                "PetMagic team";

        return new RenderedEmailMessage(subject, htmlBody, textBody);
    }

    private static string NormalizeDisplayName(string? displayName)
    {
        if (string.IsNullOrWhiteSpace(displayName))
        {
            return "friend";
        }

        var normalized = displayName.Trim();
        if (normalized.Length <= 48)
        {
            return normalized;
        }

        return normalized[..48].TrimEnd();
    }
}
