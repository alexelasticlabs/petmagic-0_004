using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IPetsService
{
    Task<Result<IReadOnlyList<PetResponse>>> ListAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<PetResponse>> CreateAsync(CreatePetCommand command, CancellationToken cancellationToken);

    Task<Result<PetResponse>> UpdateAsync(UpdatePetCommand command, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<Result<PetPhotoResponse>> AddPhotoAsync(UploadPetPhotoCommand command, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PetPhotoResponse>>> ListPhotosAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<Result<PetPhotoResponse>> SetAvatarAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken);

    Task<Result<PetPhotoResponse>> SetFavoriteAsync(SetPetPhotoFavoriteCommand command, CancellationToken cancellationToken);

    Task<Result> DeletePhotoAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListGenerationsAsync(Guid userId, Guid petId, bool isPremium, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<AdminPetResponse>>> ListAdminUserPetsAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<PetPhotoResponse>>> ListAdminPetPhotosAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAdminPetGenerationsAsync(Guid userId, Guid petId, CancellationToken cancellationToken);

    Task<Result<AdminPetResponse>> ChangeAdminPetStatusAsync(Guid userId, Guid petId, string? status, CancellationToken cancellationToken);

    Task<Result<PetPhotoResponse>> ChangeAdminPhotoStatusAsync(Guid userId, Guid petId, Guid photoId, string? status, CancellationToken cancellationToken);
}
