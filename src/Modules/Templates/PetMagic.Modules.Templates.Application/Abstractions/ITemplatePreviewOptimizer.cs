using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplatePreviewOptimizer
{
    Task<Result<TemplatePreviewOptimizationResult>> OptimizeAsync(
        StoredMediaResponse original,
        double? durationSeconds,
        CancellationToken cancellationToken);
}
