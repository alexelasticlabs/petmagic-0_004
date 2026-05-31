using System.Globalization;
using System.Net;

namespace PetMagic.Modules.Identity.Infrastructure;

public interface IIdentityEmailTemplateRenderer
{
    RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc, string? locale = null);

    RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc, string? locale = null);
}

public sealed record RenderedEmailMessage(string Subject, string HtmlBody, string TextBody);

internal sealed class IdentityEmailTemplateRenderer : IIdentityEmailTemplateRenderer
{
    private enum EmailTemplateKind
    {
        EmailConfirmation,
        PasswordReset
    }

    private sealed record LocalizedEmailCopy(
        string Subject,
        string Heading,
        string Intro,
        string CodeCaption,
        string ValidUntilLabel,
        string FooterHint,
        string Greeting,
        string TeamSignature,
        string Preheader,
        string FallbackName);

    public RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
    {
        return RenderSecurityCodeEmail(
            displayName,
            code,
            expiresAtUtc,
            locale,
            EmailTemplateKind.EmailConfirmation);
    }

    public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
    {
        return RenderSecurityCodeEmail(
            displayName,
            code,
            expiresAtUtc,
            locale,
            EmailTemplateKind.PasswordReset);
    }

    private static RenderedEmailMessage RenderSecurityCodeEmail(
        string? displayName,
        string code,
        DateTime expiresAtUtc,
        string? locale,
        EmailTemplateKind templateKind)
    {
        var language = ResolveLanguage(locale);
        var copy = BuildLocalizedCopy(language, templateKind);

        var safeName = NormalizeDisplayName(displayName, copy.FallbackName);
        var expiryText = FormatExpiryText(expiresAtUtc, language);

        var encodedLanguage = WebUtility.HtmlEncode(language);
        var encodedName = WebUtility.HtmlEncode(safeName);
        var encodedCode = WebUtility.HtmlEncode(code);
        var encodedHeading = WebUtility.HtmlEncode(copy.Heading);
        var encodedIntro = WebUtility.HtmlEncode(copy.Intro);
        var encodedCodeCaption = WebUtility.HtmlEncode(copy.CodeCaption);
        var encodedExpiryText = WebUtility.HtmlEncode(expiryText);
        var encodedFooterHint = WebUtility.HtmlEncode(copy.FooterHint);
        var encodedValidUntilLabel = WebUtility.HtmlEncode(copy.ValidUntilLabel);
        var encodedGreeting = WebUtility.HtmlEncode(copy.Greeting);
        var encodedTeamSignature = WebUtility.HtmlEncode(copy.TeamSignature);
        var encodedPreheader = WebUtility.HtmlEncode(copy.Preheader);

        var htmlBody = $"""
            <!doctype html>
            <html lang="{encodedLanguage}">
            <body style="margin:0;padding:0;background-color:#f2f5f9;font-family:Segoe UI,Arial,sans-serif;color:#1f2937;">
              <span style="display:none!important;visibility:hidden;opacity:0;color:transparent;height:0;width:0;overflow:hidden;">{encodedPreheader}</span>
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
                          <p style="margin:0 0 12px 0;font-size:16px;line-height:24px;">{encodedGreeting} {encodedName},</p>
                          <p style="margin:0 0 18px 0;font-size:15px;line-height:24px;color:#334155;">{encodedIntro}</p>
                          <p style="margin:0 0 10px 0;font-size:12px;line-height:18px;letter-spacing:1px;text-transform:uppercase;color:#64748b;font-weight:600;">{encodedCodeCaption}</p>
                          <div style="display:inline-block;padding:14px 18px;border-radius:12px;background:#eff6ff;border:1px solid #c8defc;font-size:30px;line-height:32px;font-weight:700;letter-spacing:5px;color:#0f2742;">{encodedCode}</div>
                          <p style="margin:16px 0 0 0;font-size:13px;line-height:20px;color:#475569;">{encodedValidUntilLabel} <strong>{encodedExpiryText}</strong>.</p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:18px 28px 24px 28px;border-top:1px solid #e2e8f0;background:#f8fafc;">
                          <p style="margin:0;font-size:13px;line-height:20px;color:#475569;">{encodedFooterHint}</p>
                          <p style="margin:10px 0 0 0;font-size:12px;line-height:18px;color:#64748b;">{encodedTeamSignature}</p>
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
            $"{copy.Greeting} {safeName},\n\n" +
            $"{copy.Intro}\n\n" +
            $"{copy.CodeCaption}: {code}\n" +
            $"{copy.ValidUntilLabel}: {expiryText}\n\n" +
            $"{copy.FooterHint}\n\n" +
            copy.TeamSignature;

        return new RenderedEmailMessage(copy.Subject, htmlBody, textBody);
    }

    private static LocalizedEmailCopy BuildLocalizedCopy(string language, EmailTemplateKind templateKind)
    {
        return (language, templateKind) switch
        {
            ("ru", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Подтвердите email в PetMagic",
                "Подтверждение email",
                "Используйте этот код, чтобы подтвердить аккаунт PetMagic и завершить регистрацию.",
                "Код подтверждения",
                "Действует до",
                "Если вы не создавали аккаунт в PetMagic, просто проигнорируйте это письмо.",
                "Здравствуйте",
                "Команда PetMagic",
                "Подтвердите email с помощью этого кода безопасности",
                "друг"),
            ("ru", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Сбросьте пароль в PetMagic",
                "Запрос на сброс пароля",
                "Используйте этот одноразовый код, чтобы сбросить пароль.",
                "Код для сброса пароля",
                "Действует до",
                "Если вы не запрашивали сброс пароля, просто проигнорируйте это письмо.",
                "Здравствуйте",
                "Команда PetMagic",
                "Сбросьте пароль с помощью этого кода безопасности",
                "друг"),
            ("de", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Bestätige deine E-Mail für PetMagic",
                "E-Mail bestätigen",
                "Verwende diesen Code, um dein PetMagic-Konto zu bestätigen und die Einrichtung abzuschließen.",
                "Bestätigungscode",
                "Gültig bis",
                "Wenn du kein PetMagic-Konto erstellt hast, kannst du diese E-Mail ignorieren.",
                "Hallo",
                "Dein PetMagic-Team",
                "Bestätige deine E-Mail mit diesem Sicherheitscode",
                "Freund"),
            ("de", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Setze dein PetMagic-Passwort zurück",
                "Passwort zurücksetzen",
                "Verwende diesen Einmalcode, um dein Passwort zurückzusetzen.",
                "Code zum Zurücksetzen",
                "Gültig bis",
                "Wenn du kein Zurücksetzen angefordert hast, kannst du diese E-Mail ignorieren.",
                "Hallo",
                "Dein PetMagic-Team",
                "Setze dein Passwort mit diesem Sicherheitscode zurück",
                "Freund"),
            ("es", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Verifica tu correo en PetMagic",
                "Confirma tu correo",
                "Usa este código para verificar tu cuenta de PetMagic y completar la configuración.",
                "Código de confirmación",
                "Válido hasta",
                "Si no creaste una cuenta en PetMagic, puedes ignorar este correo.",
                "Hola",
                "Equipo de PetMagic",
                "Confirma tu correo con este código de seguridad",
                "amigo"),
            ("es", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Restablece tu contraseña de PetMagic",
                "Solicitud de restablecimiento",
                "Usa este código de un solo uso para restablecer tu contraseña.",
                "Código de restablecimiento",
                "Válido hasta",
                "Si no solicitaste este restablecimiento, puedes ignorar este correo.",
                "Hola",
                "Equipo de PetMagic",
                "Restablece tu contraseña con este código de seguridad",
                "amigo"),
            ("fr", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Vérifiez votre e-mail sur PetMagic",
                "Confirmez votre e-mail",
                "Utilisez ce code pour vérifier votre compte PetMagic et terminer la configuration.",
                "Code de confirmation",
                "Valable jusqu'au",
                "Si vous n'avez pas créé de compte PetMagic, vous pouvez ignorer cet e-mail.",
                "Bonjour",
                "L'équipe PetMagic",
                "Confirmez votre e-mail avec ce code de sécurité",
                "ami"),
            ("fr", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Réinitialisez votre mot de passe PetMagic",
                "Demande de réinitialisation",
                "Utilisez ce code à usage unique pour réinitialiser votre mot de passe.",
                "Code de réinitialisation",
                "Valable jusqu'au",
                "Si vous n'avez pas demandé cette réinitialisation, vous pouvez ignorer cet e-mail.",
                "Bonjour",
                "L'équipe PetMagic",
                "Réinitialisez votre mot de passe avec ce code de sécurité",
                "ami"),
            ("it", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Verifica la tua email su PetMagic",
                "Conferma la tua email",
                "Usa questo codice per verificare il tuo account PetMagic e completare la configurazione.",
                "Codice di conferma",
                "Valido fino al",
                "Se non hai creato un account PetMagic, puoi ignorare questa email.",
                "Ciao",
                "Team PetMagic",
                "Conferma la tua email con questo codice di sicurezza",
                "amico"),
            ("it", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Reimposta la tua password PetMagic",
                "Richiesta di reimpostazione password",
                "Usa questo codice monouso per reimpostare la password.",
                "Codice di reimpostazione",
                "Valido fino al",
                "Se non hai richiesto questa reimpostazione, puoi ignorare questa email.",
                "Ciao",
                "Team PetMagic",
                "Reimposta la tua password con questo codice di sicurezza",
                "amico"),
            ("pl", EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Zweryfikuj e-mail w PetMagic",
                "Potwierdź e-mail",
                "Użyj tego kodu, aby zweryfikować konto PetMagic i dokończyć konfigurację.",
                "Kod potwierdzający",
                "Ważny do",
                "Jeśli nie zakładano konta PetMagic, możesz zignorować tę wiadomość.",
                "Cześć",
                "Zespół PetMagic",
                "Potwierdź e-mail za pomocą tego kodu bezpieczeństwa",
                "przyjaciel"),
            ("pl", EmailTemplateKind.PasswordReset) => new LocalizedEmailCopy(
                "Zresetuj hasło PetMagic",
                "Prośba o reset hasła",
                "Użyj tego jednorazowego kodu, aby zresetować hasło.",
                "Kod resetowania",
                "Ważny do",
                "Jeśli nie proszono o reset hasła, możesz zignorować tę wiadomość.",
                "Cześć",
                "Zespół PetMagic",
                "Zresetuj hasło za pomocą tego kodu bezpieczeństwa",
                "przyjaciel"),
            (_, EmailTemplateKind.EmailConfirmation) => new LocalizedEmailCopy(
                "Verify your email for PetMagic",
                "Confirm your email",
                "Use this code to verify your PetMagic account and finish setup.",
                "Email confirmation code",
                "Valid until",
                "If you did not create a PetMagic account, you can ignore this email.",
                "Hi",
                "PetMagic team",
                "Confirm your email with this security code",
                "friend"),
            _ => new LocalizedEmailCopy(
                "Reset your PetMagic password",
                "Password reset requested",
                "Use this one-time code to reset your password.",
                "Password reset code",
                "Valid until",
                "If you did not request a password reset, you can ignore this email and keep your password unchanged.",
                "Hi",
                "PetMagic team",
                "Reset your password with this security code",
                "friend")
        };
    }

    private static string ResolveLanguage(string? locale)
    {
        if (string.IsNullOrWhiteSpace(locale))
        {
            return "en";
        }

        var normalized = locale.Trim();
        var commaIndex = normalized.IndexOf(',');
        if (commaIndex >= 0)
        {
            normalized = normalized[..commaIndex];
        }

        var semicolonIndex = normalized.IndexOf(';');
        if (semicolonIndex >= 0)
        {
            normalized = normalized[..semicolonIndex];
        }

        normalized = normalized.Replace('_', '-').Trim().ToLowerInvariant();
        var dashIndex = normalized.IndexOf('-');
        var language = dashIndex >= 0 ? normalized[..dashIndex] : normalized;

        return language switch
        {
            "ru" => "ru",
            "en" => "en",
            "de" => "de",
            "es" => "es",
            "fr" => "fr",
            "it" => "it",
            "pl" => "pl",
            _ => "en"
        };
    }

    private static string FormatExpiryText(DateTime expiresAtUtc, string language)
    {
        var cultureName = language switch
        {
            "ru" => "ru-RU",
            "de" => "de-DE",
            "es" => "es-ES",
            "fr" => "fr-FR",
            "it" => "it-IT",
            "pl" => "pl-PL",
            _ => "en-US"
        };

        var culture = CultureInfo.GetCultureInfo(cultureName);
        return $"{expiresAtUtc.ToString("g", culture)} UTC";
    }

    private static string NormalizeDisplayName(string? displayName, string fallbackName)
    {
        if (string.IsNullOrWhiteSpace(displayName))
        {
            return fallbackName;
        }

        var normalized = displayName.Trim();
        if (normalized.Length <= 48)
        {
            return normalized;
        }

        return normalized[..48].TrimEnd();
    }
}
