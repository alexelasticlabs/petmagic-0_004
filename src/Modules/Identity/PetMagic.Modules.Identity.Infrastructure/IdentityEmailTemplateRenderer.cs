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
        var safeName = NormalizeDisplayName(displayName);
        var subject = "PetMagic email confirmation";
        var expiryText = $"{expiresAtUtc:yyyy-MM-dd HH:mm} UTC";
        var htmlBody = $"""
            <p>Hello {WebUtility.HtmlEncode(safeName)},</p>
            <p>Your PetMagic email confirmation code is:</p>
            <p style="font-size:24px;font-weight:bold;letter-spacing:4px;">{WebUtility.HtmlEncode(code)}</p>
            <p>This code expires at {WebUtility.HtmlEncode(expiryText)}.</p>
            """;
        var textBody = $"Hello {safeName},\n\nYour PetMagic email confirmation code is: {code}\nIt expires at {expiryText}.";

        return new RenderedEmailMessage(subject, htmlBody, textBody);
    }

    public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc)
    {
        var safeName = NormalizeDisplayName(displayName);
        var subject = "PetMagic password reset";
        var expiryText = $"{expiresAtUtc:yyyy-MM-dd HH:mm} UTC";
        var htmlBody = $"""
            <p>Hello {WebUtility.HtmlEncode(safeName)},</p>
            <p>Your PetMagic password reset code is:</p>
            <p style="font-size:24px;font-weight:bold;letter-spacing:4px;">{WebUtility.HtmlEncode(code)}</p>
            <p>This code expires at {WebUtility.HtmlEncode(expiryText)}.</p>
            """;
        var textBody = $"Hello {safeName},\n\nYour PetMagic password reset code is: {code}\nIt expires at {expiryText}.";

        return new RenderedEmailMessage(subject, htmlBody, textBody);
    }

    private static string NormalizeDisplayName(string? displayName)
    {
        return string.IsNullOrWhiteSpace(displayName) ? "there" : displayName.Trim();
    }
}
