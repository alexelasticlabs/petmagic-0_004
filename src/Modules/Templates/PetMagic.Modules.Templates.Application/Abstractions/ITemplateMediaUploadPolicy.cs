using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateMediaUploadPolicy
{
    long GetMaxFileSizeBytes(TemplateAssetKind assetKind);
}
