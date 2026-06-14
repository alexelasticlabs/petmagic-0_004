using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateWatermarkSettingsStore(TemplatesOptions options)
{
    private readonly object _lock = new();
    private AdminWatermarkSettingsResponse _current = Map(options.Watermark);

    public AdminWatermarkSettingsResponse Current
    {
        get
        {
            lock (_lock)
            {
                return _current;
            }
        }
    }

    public AdminWatermarkSettingsResponse Update(UpdateAdminWatermarkSettingsCommand command)
    {
        var updated = new AdminWatermarkSettingsResponse(
            command.Enabled,
            NormalizeText(command.Text),
            string.IsNullOrWhiteSpace(command.LogoUrl) ? null : command.LogoUrl.Trim(),
            Math.Clamp(command.Opacity, 0.45, 0.65),
            NormalizePosition(command.Position),
            NormalizeSize(command.Size),
            Math.Max(1, command.CostCredits),
            command.ApplyToImages,
            command.ApplyToVideos,
            Current.PreviewImageUrl,
            Current.PreviewVideoFrameUrl);

        lock (_lock)
        {
            _current = updated;
            return _current;
        }
    }

    public AdminWatermarkSettingsResponse Replace(AdminWatermarkSettingsResponse settings)
    {
        var updated = new AdminWatermarkSettingsResponse(
            settings.Enabled,
            NormalizeText(settings.Text),
            string.IsNullOrWhiteSpace(settings.LogoUrl) ? null : settings.LogoUrl.Trim(),
            Math.Clamp(settings.Opacity, 0.45, 0.65),
            NormalizePosition(settings.Position),
            NormalizeSize(settings.Size),
            Math.Max(1, settings.CostCredits),
            settings.ApplyToImages,
            settings.ApplyToVideos,
            settings.PreviewImageUrl,
            settings.PreviewVideoFrameUrl);

        lock (_lock)
        {
            _current = updated;
            return _current;
        }
    }

    private static AdminWatermarkSettingsResponse Map(TemplateWatermarkOptions options)
    {
        return new AdminWatermarkSettingsResponse(
            options.Enabled,
            NormalizeText(options.Text),
            string.IsNullOrWhiteSpace(options.LogoUrl) ? null : options.LogoUrl,
            Math.Clamp(options.Opacity, 0.45, 0.65),
            NormalizePosition(options.Position),
            NormalizeSize(options.Size),
            Math.Max(1, options.CostCredits),
            options.ApplyToImages,
            options.ApplyToVideos,
            options.PreviewImageUrl,
            options.PreviewVideoFrameUrl);
    }

    private static string NormalizeText(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? "Made with PetMagic" : trimmed;
    }

    private static string NormalizePosition(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is "top-left" or "top-right" or "bottom-left" or "bottom-right"
            ? normalized
            : "bottom-right";
    }

    private static string NormalizeSize(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is "small" or "medium" or "large"
            ? normalized
            : "small";
    }
}
