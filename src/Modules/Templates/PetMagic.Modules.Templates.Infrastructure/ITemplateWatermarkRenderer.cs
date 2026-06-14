using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface ITemplateWatermarkRenderer
{
    Task<Result<StoredMediaResponse>> CreateWatermarkedCopyAsync(
        StoredMediaResponse original,
        TemplateType mediaType,
        Guid generationId,
        CancellationToken cancellationToken);
}
