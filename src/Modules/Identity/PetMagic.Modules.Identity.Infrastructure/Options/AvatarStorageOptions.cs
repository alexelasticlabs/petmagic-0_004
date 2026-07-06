using PetMagic.BuildingBlocks.Images;

namespace PetMagic.Modules.Identity.Infrastructure.Options;

public sealed class AvatarStorageOptions
{
    public const string SectionName = "Identity:AvatarStorage";

    public string PublicBaseUrl { get; init; } = string.Empty;

    public string LocalMediaRootPath { get; init; } = Path.Combine("wwwroot", "user-avatars");

    public long MaxFileSizeBytes { get; init; } = UploadedMediaPolicies.Avatar.MaxFileSizeBytes;
}
