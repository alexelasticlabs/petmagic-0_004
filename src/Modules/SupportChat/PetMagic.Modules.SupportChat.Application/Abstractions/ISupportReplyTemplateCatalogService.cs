using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Application.Abstractions;

public interface ISupportReplyTemplateCatalogService
{
    Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<SupportReplyTemplateResponse>>> ListAdminTemplatesAsync(bool includeDisabled, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<SupportReplyTemplateVersionResponse>>> ListAdminTemplateVersionsAsync(Guid templateId, CancellationToken cancellationToken);

    Task<Result<SupportReplyTemplateResponse>> UpsertAdminTemplateAsync(UpsertSupportReplyTemplateCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteAdminTemplateAsync(DeleteSupportReplyTemplateCommand command, CancellationToken cancellationToken);
}
