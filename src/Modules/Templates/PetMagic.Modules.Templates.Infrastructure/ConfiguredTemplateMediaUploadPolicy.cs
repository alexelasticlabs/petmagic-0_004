using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class ConfiguredTemplateMediaUploadPolicy(TemplatesOptions options) : ITemplateMediaUploadPolicy
{
    public long GetMaxFileSizeBytes(TemplateAssetKind assetKind)
    {
        return assetKind == TemplateAssetKind.ReferenceMotion
            ? options.ReferenceMotionMaxFileSizeBytes
            : options.PreviewMaxFileSizeBytes;
    }
}
