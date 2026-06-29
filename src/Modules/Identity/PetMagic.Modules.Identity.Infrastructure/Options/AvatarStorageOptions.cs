using PetMagic.BuildingBlocks.Images;

namespace PetMagic.Modules.Identity.Infrastructure.Options;

public sealed class AvatarStorageOptions
{
    public const string SectionName = "Identity:AvatarStorage";

    public string PublicBaseUrl { get; init; } = "http://localhost:5000";

    public string LocalMediaRootPath { get; init; } = Path.Combine("wwwroot", "user-avatars");

    public long MaxFileSizeBytes { get; init; } = UploadedMediaPolicies.Avatar.MaxFileSizeBytes;
}
