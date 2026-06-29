namespace PetMagic.BuildingBlocks.Images;

public sealed record UploadedMediaPolicy(
    string MediaClass,
    long MaxFileSizeBytes,
    int MaxDimension,
    int JpegQuality);

public static class UploadedMediaPolicies
{
    public static readonly UploadedMediaPolicy Avatar = new(
        "avatar",
        8 * 1024 * 1024,
        1200,
        92);

    public static readonly UploadedMediaPolicy PetPhoto = new(
        "pet_photo",
        25 * 1024 * 1024,
        2048,
        88);

    public static readonly UploadedMediaPolicy SupportImage = new(
        "support_image",
        10 * 1024 * 1024,
        1800,
        86);

    public const long SupportVideoMaxFileSizeBytes = 50 * 1024 * 1024;

    public static UploadedMediaPolicy ForProfile(UploadedImageProfile profile)
    {
        return profile switch
        {
            UploadedImageProfile.Avatar => Avatar,
            UploadedImageProfile.PetPhoto => PetPhoto,
            UploadedImageProfile.SupportImage => SupportImage,
            _ => SupportImage
        };
    }
}
