using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface ITemplateDiscoveryAdminService
{
    Task<DiscoveryAdminResponse> GetAsync(CancellationToken cancellationToken);
    Task<DiscoveryHistoryResponse> HistoryAsync(int skip, int take, CancellationToken cancellationToken);
    Task<Result<DiscoveryRevisionResponse>> CreateDraftAsync(Guid actorId, CreateDiscoveryDraftRequest request, CancellationToken cancellationToken);
    Task<Result<DiscoveryRevisionResponse>> SaveDraftAsync(Guid actorId, Guid revisionId, SaveDiscoveryDraftRequest request, CancellationToken cancellationToken);
    Task<Result<DiscoveryValidationResponse>> ValidateAsync(Guid revisionId, CancellationToken cancellationToken);
    Task<Result<PublicTemplatesDiscoveryResponse>> PreviewAsync(Guid revisionId, string? locale, CancellationToken cancellationToken);
    Task<Result<DiscoveryRevisionResponse>> PublishAsync(Guid actorId, Guid revisionId, string idempotencyKey, PublishDiscoveryRequest request, CancellationToken cancellationToken);
    Task<Result<bool>> DiscardAsync(Guid actorId, Guid revisionId, DiscardDiscoveryDraftRequest request, CancellationToken cancellationToken);
}
