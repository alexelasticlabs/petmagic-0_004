using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.BuildingBlocks.Images;

public enum UploadedImageProfile
{
    Avatar,
    PetPhoto,
    SupportImage
}

public sealed record UploadedImageNormalizationResult(
    byte[] Content,
    string ContentType,
    string FileExtension,
    int Width,
    int Height,
    bool WasNormalized,
    string DecisionReason);

public static class UploadedImageNormalizer
{
    public static UploadedImageNormalizationResult NormalizeOrKeep(
        byte[] content,
        string contentType,
        UploadedImageProfile profile)
    {
        if (content.Length == 0 || !contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return KeepOriginal(content, contentType, "not_image");
        }

        try
        {
            using var image = Image.Load(content);
            image.Mutate(context =>
            {
                context.AutoOrient();
                var maxDimension = ResolveMaxDimension(profile);
                if (Math.Max(image.Width, image.Height) > maxDimension)
                {
                    context.Resize(new ResizeOptions
                    {
                        Mode = ResizeMode.Max,
                        Size = new Size(maxDimension, maxDimension),
                        Sampler = KnownResamplers.Bicubic
                    });
                }
            });

            using var output = new MemoryStream();
            image.SaveAsJpeg(output, new JpegEncoder
            {
                Quality = ResolveJpegQuality(profile)
            });

            return new UploadedImageNormalizationResult(
                output.ToArray(),
                "image/jpeg",
                ".jpg",
                image.Width,
                image.Height,
                true,
                "normalized");
        }
        catch (UnknownImageFormatException)
        {
            return KeepOriginal(content, contentType, "decoder_unavailable");
        }
        catch (InvalidImageContentException)
        {
            return KeepOriginal(content, contentType, "decoder_unavailable");
        }
        catch (NotSupportedException)
        {
            return KeepOriginal(content, contentType, "decoder_unavailable");
        }
    }

    private static UploadedImageNormalizationResult KeepOriginal(byte[] content, string contentType, string decisionReason)
    {
        return new UploadedImageNormalizationResult(
            content,
            contentType,
            ResolveFileExtension(contentType),
            0,
            0,
            false,
            decisionReason);
    }

    private static int ResolveMaxDimension(UploadedImageProfile profile)
    {
        return profile switch
        {
            UploadedImageProfile.Avatar => 1200,
            UploadedImageProfile.PetPhoto => 2048,
            UploadedImageProfile.SupportImage => 1800,
            _ => 1800
        };
    }

    private static int ResolveJpegQuality(UploadedImageProfile profile)
    {
        return profile switch
        {
            UploadedImageProfile.Avatar => 92,
            UploadedImageProfile.PetPhoto => 88,
            UploadedImageProfile.SupportImage => 86,
            _ => 88
        };
    }

    private static string ResolveFileExtension(string contentType)
    {
        return NormalizeContentType(contentType) switch
        {
            "image/jpeg" or "image/jpg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            "image/gif" => ".gif",
            "image/heic" => ".heic",
            "image/heif" => ".heif",
            _ => string.Empty
        };
    }

    private static string NormalizeContentType(string contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return string.Empty;
        }

        var separatorIndex = contentType.IndexOf(';');
        return (separatorIndex >= 0 ? contentType[..separatorIndex] : contentType)
            .Trim()
            .ToLowerInvariant();
    }
}
