using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Images;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class PetsService
{
    public async Task<Result<PetPhotoResponse>> AddPhotoAsync(UploadPetPhotoCommand command, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(command.UserId, command.PetId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photoId = Guid.NewGuid();
        var normalizedPhotoUpload = await NormalizePetPhotoUploadAsync(command.Photo, cancellationToken);
        var petPhotoUpload = normalizedPhotoUpload with
        {
            PreferredStorageKey = BuildPetPhotoStorageKey(command.UserId, command.PetId, photoId, normalizedPhotoUpload.ContentType)
        };
        var stored = await mediaStorage.StoreAsync(petPhotoUpload, cancellationToken);
        if (stored.IsFailure)
        {
            return Result.Failure<PetPhotoResponse>(stored.Error);
        }

        var thumbnail = await CreateThumbnailAsync(stored.Value, command.UserId, command.PetId, photoId, cancellationToken);

        var hasPhotos = await dbContext.PetPhotos
            .AnyAsync(x => x.UserId == command.UserId && x.PetId == command.PetId && !x.IsDeleted, cancellationToken);
        var nextSortOrder = await dbContext.PetPhotos
            .Where(x => x.UserId == command.UserId && x.PetId == command.PetId)
            .Select(x => (int?)x.SortOrder)
            .MaxAsync(cancellationToken) ?? 0;
        var now = DateTime.UtcNow;
        var media = new TemplateMediaRecord
        {
            Id = Guid.NewGuid(),
            UserId = command.UserId,
            MediaType = "image",
            StoragePath = stored.Value.StorageKey,
            PreviewUrl = thumbnail?.StorageKey,
            SourceType = "pet_photo",
            Url = stored.Value.Url,
            FileName = stored.Value.FileName,
            ContentType = stored.Value.ContentType,
            FileSizeBytes = stored.Value.FileSizeBytes,
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now,
            AttachedAtUtc = now
        };
        var photo = new PetPhoto
        {
            Id = photoId,
            PetId = command.PetId,
            UserId = command.UserId,
            MediaAssetId = media.Id,
            MediaAsset = media,
            ThumbnailUrl = thumbnail?.Url,
            ThumbnailStoragePath = thumbnail?.StorageKey,
            IsAvatar = !hasPhotos,
            SortOrder = nextSortOrder + 1,
            CreatedAtUtc = now
        };

        if (!hasPhotos)
        {
            pet.AvatarMediaAssetId = media.Id;
        }

        pet.UpdatedAtUtc = now;
        dbContext.TemplateMediaRecords.Add(media);
        dbContext.PetPhotos.Add(photo);
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoUploaded,
            petPhotoId: photo.Id,
            photosCountOverride: hasPhotos ? nextSortOrder + 1 : 1,
            cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(await MapPhotoAsync(photo, media, cancellationToken));
    }

    public async Task<Result<IReadOnlyList<PetPhotoResponse>>> ListPhotosAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken))
        {
            return Result.Failure<IReadOnlyList<PetPhotoResponse>>(TemplatesErrors.PetNotFound);
        }

        var photos = await dbContext.PetPhotos
            .AsNoTracking()
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId && x.PetId == petId && !x.IsDeleted && x.Status == "active" && !x.MediaAsset.IsDeleted)
            .OrderBy(x => x.SortOrder)
            .ThenByDescending(x => x.CreatedAtUtc)
            .ToArrayAsync(cancellationToken);

        var mapped = new List<PetPhotoResponse>(photos.Length);
        foreach (var photo in photos)
        {
            mapped.Add(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
        }

        return Result.Success<IReadOnlyList<PetPhotoResponse>>(mapped);
    }

    public async Task<Result<PetPhotoResponse>> SetAvatarAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(userId, petId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photo = await FindActivePhotoAsync(userId, petId, photoId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetPhotoNotFound);
        }

        await dbContext.PetPhotos
            .Where(x => x.UserId == userId && x.PetId == petId && !x.IsDeleted)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.IsAvatar, x => x.Id == photoId), cancellationToken);
        pet.AvatarMediaAssetId = photo.MediaAssetId;
        pet.UpdatedAtUtc = DateTime.UtcNow;
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoSetAvatar,
            petPhotoId: photo.Id,
            cancellationToken: cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        photo.IsAvatar = true;
        return Result.Success(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
    }

    public async Task<Result<PetPhotoResponse>> SetFavoriteAsync(SetPetPhotoFavoriteCommand command, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(command.UserId, command.PetId, cancellationToken);
        if (pet is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetNotFound);
        }

        var photo = await FindActivePhotoAsync(command.UserId, command.PetId, command.PhotoId, cancellationToken);
        if (photo is null)
        {
            return Result.Failure<PetPhotoResponse>(TemplatesErrors.PetPhotoNotFound);
        }

        photo.IsFavorite = command.IsFavorite;
        await AddPetAnalyticsEventAsync(
            pet,
            TemplateAnalyticsEventTypes.PhotoFavorited,
            petPhotoId: photo.Id,
            cancellationToken: cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(await MapPhotoAsync(photo, photo.MediaAsset, cancellationToken));
    }

    public async Task<Result> DeletePhotoAsync(Guid userId, Guid petId, Guid photoId, CancellationToken cancellationToken)
    {
        var pet = await FindActivePetAsync(userId, petId, cancellationToken);
        var photo = await FindActivePhotoAsync(userId, petId, photoId, cancellationToken);
        if (pet is null || photo is null)
        {
            return Result.Failure(TemplatesErrors.PetPhotoNotFound);
        }

        photo.IsDeleted = true;
        photo.Status = "deleted";
        photo.DeletedAtUtc = DateTime.UtcNow;
        photo.IsAvatar = false;
        photo.MediaAsset.IsDeleted = true;
        photo.MediaAsset.DeletedAtUtc = photo.DeletedAtUtc;
        photo.MediaAsset.LifecycleState = TemplateMediaLifecycleState.Deleted;

        if (pet.AvatarMediaAssetId == photo.MediaAssetId)
        {
            var replacement = await ResolveBestPhotoAsync(userId, petId, excludePhotoId: photoId, cancellationToken);
            pet.AvatarMediaAssetId = replacement?.MediaAssetId;
            if (replacement is not null)
            {
                replacement.IsAvatar = true;
            }
        }

        pet.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListGenerationsAsync(Guid userId, Guid petId, bool isPremium, CancellationToken cancellationToken)
    {
        if (!await dbContext.Pets.AnyAsync(
            x => x.Id == petId && x.UserId == userId && !x.IsDeleted && x.Status == "active",
            cancellationToken))
        {
            return Result.Failure<IReadOnlyList<TemplateGenerationResponse>>(TemplatesErrors.PetNotFound);
        }

        var generations = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Where(x => x.UserId == userId && x.PetId == petId && x.HiddenByUserAtUtc == null)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(50)
            .ToArrayAsync(cancellationToken);

        var cost = Math.Max(1, (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current.CostCredits);
        var mapped = new List<TemplateGenerationResponse>(generations.Length);
        foreach (var generation in generations)
        {
            var response = TemplateGenerationService.ApplyWatermarkAccess(
                TemplateGenerationService.MapResponse(generation),
                generation,
                isPremium,
                generation.WatermarkUnlocks.Any(unlock => unlock.UserId == userId),
                cost);
            mapped.Add(await TemplateGenerationService.SignUserMediaUrlsAsync(
                mediaStorage,
                options,
                response,
                cancellationToken));
        }

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(mapped);
    }

    private async Task<MediaUploadCommand> NormalizePetPhotoUploadAsync(MediaUploadCommand upload, CancellationToken cancellationToken)
    {
        byte[]? sourceBytes = upload.Content;
        if (sourceBytes is null)
        {
            sourceBytes = await ReadAllBytesAsync(upload.ContentStream, cancellationToken);
            if (sourceBytes is null)
            {
                return upload;
            }
        }

        var normalizedImage = UploadedImageNormalizer.NormalizeOrKeep(
            sourceBytes,
            upload.ContentType,
            UploadedImageProfile.PetPhoto);
        logger.LogInformation(
            "Pet photo upload processed. WasNormalized={WasNormalized} Reason={Reason} OriginalBytes={OriginalBytes} OutputBytes={OutputBytes}",
            normalizedImage.WasNormalized,
            normalizedImage.DecisionReason,
            sourceBytes.LongLength,
            normalizedImage.Content.LongLength);
        return new MediaUploadCommand(
            upload.FileName,
            normalizedImage.ContentType,
            normalizedImage.Content,
            null,
            normalizedImage.Content.LongLength,
            upload.PreferredStorageKey);
    }

    private static async Task<byte[]?> ReadAllBytesAsync(Stream? stream, CancellationToken cancellationToken)
    {
        if (stream is null)
        {
            return null;
        }

        if (stream.CanSeek)
        {
            stream.Position = 0;
        }

        using var buffer = new MemoryStream();
        await stream.CopyToAsync(buffer, cancellationToken);
        return buffer.ToArray();
    }

    private static string BuildPetPhotoStorageKey(Guid userId, Guid petId, Guid photoId, string contentType)
    {
        var extension = NormalizeContentType(contentType) switch
        {
            "image/jpeg" or "image/jpg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            "image/heic" => ".heic",
            "image/heif" => ".heif",
            _ => Path.GetExtension($"upload-{photoId:N}.jpg")
        };

        return $"users/{userId:N}/pets/{petId:N}/photos/{photoId:N}/original{extension}";
    }

    private static string BuildPetPhotoThumbnailStorageKey(Guid userId, Guid petId, Guid photoId)
    {
        return $"users/{userId:N}/pets/{petId:N}/photos/{photoId:N}/thumbnail.webp";
    }

    private static string NormalizeContentType(string contentType)
    {
        return contentType.Trim().ToLowerInvariant();
    }
}
