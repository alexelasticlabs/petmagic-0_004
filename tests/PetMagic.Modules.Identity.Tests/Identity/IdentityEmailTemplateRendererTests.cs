using PetMagic.Modules.Identity.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityEmailTemplateRendererTests
{
    [Fact]
    public void RenderPasswordReset_ShouldIncludePersonalizedFriendlyLayout()
    {
        var renderer = CreateRenderer();
        var expiresAtUtc = new DateTime(2026, 5, 31, 10, 30, 0, DateTimeKind.Utc);

        var message = renderer.RenderPasswordReset("Anna", "739201", expiresAtUtc);

        Assert.Equal("Reset your PetMagic password", message.Subject);
        Assert.Contains("Hi Anna", message.HtmlBody);
        Assert.Contains("Password reset code", message.HtmlBody);
        Assert.Contains("739201", message.HtmlBody);
        Assert.Contains("UTC", message.HtmlBody);
        Assert.Contains("Hi Anna", message.TextBody);
        Assert.Contains("Password reset code: 739201", message.TextBody);
        Assert.Contains("UTC", message.TextBody);
    }

    [Fact]
    public void RenderEmailConfirmation_ShouldEscapeNameAndUseFallback()
    {
        var renderer = CreateRenderer();
        var expiresAtUtc = new DateTime(2026, 5, 31, 10, 30, 0, DateTimeKind.Utc);

        var withUnsafeName = renderer.RenderEmailConfirmation("<b>Alice</b>", "123456", expiresAtUtc);
        var withFallback = renderer.RenderEmailConfirmation(null, "654321", expiresAtUtc);

        Assert.Contains("Hi &lt;b&gt;Alice&lt;/b&gt;", withUnsafeName.HtmlBody);
        Assert.Contains("Email confirmation code", withUnsafeName.HtmlBody);
        Assert.Contains("Email confirmation code: 654321", withFallback.TextBody);
        Assert.Contains("Hi friend", withFallback.HtmlBody);
    }

    [Fact]
    public void RenderPasswordReset_ShouldUseRequestedLocale()
    {
        var renderer = CreateRenderer();
        var expiresAtUtc = new DateTime(2026, 5, 31, 10, 30, 0, DateTimeKind.Utc);

        var message = renderer.RenderPasswordReset("Анна", "987321", expiresAtUtc, "ru-RU");

        Assert.Equal("Сбросьте пароль в PetMagic", message.Subject);
        Assert.Contains("Здравствуйте Анна", message.HtmlBody);
        Assert.Contains("Код для сброса пароля", message.HtmlBody);
        Assert.Contains("31.05.2026", message.HtmlBody);
        Assert.Contains("Действует до", message.TextBody);
    }

    private static IIdentityEmailTemplateRenderer CreateRenderer()
    {
        var rendererType = typeof(IIdentityEmailTemplateRenderer)
            .Assembly
            .GetType("PetMagic.Modules.Identity.Infrastructure.IdentityEmailTemplateRenderer");

        Assert.NotNull(rendererType);

        var instance = Activator.CreateInstance(rendererType!, nonPublic: true);

        return Assert.IsAssignableFrom<IIdentityEmailTemplateRenderer>(instance);
    }
}
