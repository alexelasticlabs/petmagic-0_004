using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateMediaLifecycleService
{
    Task RegisterTemporaryUploadAsync(TemplateAssetCommand asset, TemplateMediaRole role, CancellationToken cancellationToken);

    Task ClaimTemplateAssetAsync(Guid templateId, TemplateAssetCommand? asset, TemplateMediaRole role, CancellationToken cancellationToken);

    Task MarkDeletedAsync(string url, CancellationToken cancellationToken);

    Task MarkCleanupFailureAsync(string url, string errorCode, string errorMessage, CancellationToken cancellationToken);

    Task SaveChangesAsync(CancellationToken cancellationToken);
}
