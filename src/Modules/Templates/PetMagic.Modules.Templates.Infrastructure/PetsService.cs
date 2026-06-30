using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService(
    TemplatesDbContext dbContext,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    ILogger<PetsService> logger,
    TemplateWatermarkSettingsStore? watermarkSettings = null) : IPetsService
{
    private static readonly HashSet<string> ValidPetTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "dog",
        "cat",
        "other"
    };

    private static readonly HashSet<string> ValidAdminStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "active",
        "hidden",
        "flagged",
        "deleted"
    };

    private sealed record PetListProjection(Pet Pet, int PhotosCount, int GenerationsCount, string? AvatarUrl);
}
