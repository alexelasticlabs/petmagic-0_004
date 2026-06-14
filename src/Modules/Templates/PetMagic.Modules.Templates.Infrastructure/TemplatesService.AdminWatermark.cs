using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Entities;

using Microsoft.EntityFrameworkCore;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    public async Task<Result<AdminWatermarkSettingsResponse>> GetAdminWatermarkSettingsAsync(CancellationToken cancellationToken)
    {
        var persisted = await dbContext.TemplateWatermarkSettings
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (persisted is null)
        {
            return Result.Success((watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current);
        }

        var response = MapWatermarkSettings(persisted);
        (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Replace(response);
        return Result.Success(response);
    }

    public async Task<Result<AdminWatermarkSettingsResponse>> UpdateAdminWatermarkSettingsAsync(
        UpdateAdminWatermarkSettingsCommand command,
        CancellationToken cancellationToken)
    {
        var settingsStore = watermarkSettings ?? new TemplateWatermarkSettingsStore(options);
        var response = settingsStore.Update(command);
        var now = DateTime.UtcNow;
        var row = await dbContext.TemplateWatermarkSettings
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (row is null)
        {
            row = new TemplateWatermarkSettings
            {
                Id = Guid.NewGuid(),
                CreatedAtUtc = now
            };
            dbContext.TemplateWatermarkSettings.Add(row);
        }

        row.Enabled = response.Enabled;
        row.Text = response.Text;
        row.LogoUrl = response.LogoUrl;
        row.Opacity = response.Opacity;
        row.Position = response.Position;
        row.Size = response.Size;
        row.CostCredits = response.CostCredits;
        row.ApplyToImages = response.ApplyToImages;
        row.ApplyToVideos = response.ApplyToVideos;
        row.PreviewImageUrl = response.PreviewImageUrl;
        row.PreviewVideoFrameUrl = response.PreviewVideoFrameUrl;
        row.UpdatedAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(response);
    }

    private static AdminWatermarkSettingsResponse MapWatermarkSettings(TemplateWatermarkSettings settings)
    {
        return new AdminWatermarkSettingsResponse(
            settings.Enabled,
            settings.Text,
            settings.LogoUrl,
            settings.Opacity,
            settings.Position,
            settings.Size,
            settings.CostCredits,
            settings.ApplyToImages,
            settings.ApplyToVideos,
            settings.PreviewImageUrl,
            settings.PreviewVideoFrameUrl);
    }
}
