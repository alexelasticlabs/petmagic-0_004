using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService
{
    private async Task<PetResponse> BuildPetResponseAsync(Pet pet, CancellationToken cancellationToken)
    {
        var photosCount = await dbContext.PetPhotos.CountAsync(
            x => x.PetId == pet.Id
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted,
            cancellationToken);
        var generationsCount = await dbContext.TemplateGenerationJobs.CountAsync(
            x => x.PetId == pet.Id && x.HiddenByUserAtUtc == null,
            cancellationToken);
        var avatarMediaAssetId = pet.AvatarMediaAssetId;
        var avatarUrl = await dbContext.PetPhotos
            .Where(x => x.PetId == pet.Id
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted)
            .OrderByDescending(x => x.MediaAssetId == avatarMediaAssetId || x.IsAvatar)
            .ThenBy(x => x.SortOrder)
            .ThenBy(x => x.CreatedAtUtc)
            .Select(x => x.MediaAsset.Url != string.Empty ? x.MediaAsset.Url : x.MediaAsset.StoragePath)
            .FirstOrDefaultAsync(cancellationToken);
        return await MapPetAsync(pet, photosCount, generationsCount, avatarUrl, cancellationToken);
    }

    private async Task<PetResponse> MapPetAsync(Pet pet, int photosCount, int generationsCount, string? avatarUrl, CancellationToken cancellationToken)
    {
        avatarUrl = await ResolvePetMediaReadUrlAsync(avatarUrl, cancellationToken);

        return new PetResponse(
            pet.Id,
            pet.UserId,
            pet.Name,
            pet.Type,
            pet.Breed,
            pet.AvatarMediaAssetId,
            avatarUrl,
            photosCount,
            generationsCount,
            pet.Status,
            pet.CreatedAtUtc,
            pet.UpdatedAtUtc,
            pet.IsDeleted);
    }

    private async Task<PetPhotoResponse> MapPhotoAsync(PetPhoto photo, TemplateMediaRecord media, CancellationToken cancellationToken)
    {
        var url = !string.IsNullOrWhiteSpace(media.Url) ? media.Url : media.StoragePath;
        url = await ResolvePetMediaReadUrlAsync(url, cancellationToken) ?? string.Empty;

        var thumbnailUrl = !string.IsNullOrWhiteSpace(photo.ThumbnailUrl)
            ? photo.ThumbnailUrl
            : photo.ThumbnailStoragePath;
        thumbnailUrl = await ResolvePetMediaReadUrlAsync(thumbnailUrl, cancellationToken);

        return new PetPhotoResponse(
            photo.Id,
            photo.PetId,
            photo.MediaAssetId,
            url,
            thumbnailUrl,
            media.FileName,
            media.ContentType,
            media.FileSizeBytes,
            photo.IsFavorite,
            photo.IsAvatar,
            photo.SortOrder,
            photo.Status,
            photo.CreatedAtUtc,
            photo.IsDeleted);
    }

    private async Task<string?> ResolvePetMediaReadUrlAsync(string? mediaUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(mediaUrl))
        {
            return null;
        }

        var signed = await mediaStorage.CreateReadUrlAsync(
            mediaUrl.Trim(),
            TimeSpan.FromSeconds(options.UserMediaReadUrlTtlSeconds),
            cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private Task<Pet?> FindActivePetAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        return dbContext.Pets.FirstOrDefaultAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken);
    }

    private Task<PetPhoto?> FindActivePhotoAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        return dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .FirstOrDefaultAsync(
                x => x.Id == photoId
                    && x.PetId == petId
                    && x.UserId == userId
                    && !x.IsDeleted
                    && x.Status == "active"
                    && !x.MediaAsset.IsDeleted,
                cancellationToken);
    }

    private Task<PetPhoto?> ResolveBestPhotoAsync(Guid userId, Guid petId, Guid? excludePhotoId, CancellationToken cancellationToken)
    {
        var query = dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId
                && x.PetId == petId
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted);

        if (excludePhotoId is not null)
        {
            query = query.Where(x => x.Id != excludePhotoId.Value);
        }

        return query
            .OrderByDescending(x => x.IsFavorite)
            .ThenByDescending(x => x.IsAvatar)
            .ThenByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid? petPhotoId = null,
        Guid? templateId = null,
        Guid? generationId = null,
        int? photosCountOverride = null,
        string userPlan = "unknown",
        string sourceScreen = "api",
        CancellationToken cancellationToken = default)
    {
        var photosCount = photosCountOverride
            ?? await dbContext.PetPhotos.CountAsync(
                x => x.UserId == pet.UserId && x.PetId == pet.Id && !x.IsDeleted,
                cancellationToken);

        dbContext.PetAnalyticsEvents.Add(new PetAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            UserId = pet.UserId,
            PetId = pet.Id,
            PetPhotoId = petPhotoId,
            TemplateId = templateId,
            GenerationId = generationId,
            EventType = eventType,
            PetType = pet.Type,
            PhotosCount = photosCount,
            UserPlan = userPlan,
            SourceScreen = sourceScreen,
            CreatedAtUtc = DateTime.UtcNow
        });
    }
}
