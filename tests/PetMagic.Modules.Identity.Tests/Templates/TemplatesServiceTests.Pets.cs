using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ListPetsAsync_ShouldUseFirstActivePhotoOriginalAsAvatarFallback()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var mediaId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Milo",
            Type = "dog",
            Breed = "Corgi",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        dbContext.TemplateMediaRecords.Add(new TemplateMediaRecord
        {
            Id = mediaId,
            UserId = userId,
            MediaType = "image",
            StoragePath = "users/pets/milo/original.jpg",
            Url = "https://cdn.petmagic.test/milo-original.jpg",
            FileName = "milo.jpg",
            ContentType = "image/jpeg",
            FileSizeBytes = 512,
            SourceType = "pet_photo",
            Role = TemplateMediaRole.GenerationSourceImage,
            LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration,
            UploadedAtUtc = now,
            AttachedAtUtc = now
        });
        dbContext.PetPhotos.Add(new PetPhoto
        {
            Id = Guid.NewGuid(),
            PetId = petId,
            UserId = userId,
            MediaAssetId = mediaId,
            ThumbnailStoragePath = "users/pets/milo/thumb.webp",
            Status = "active",
            SortOrder = 1,
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var storage = new RecordingMediaStorage(signReadUrls: true);
        var service = new PetsService(dbContext, storage, CreateTemplatesOptions());

        var result = await service.ListAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var pet = Assert.Single(result.Value);
        Assert.Equal("https://cdn.petmagic.test/milo-original.jpg", pet.AvatarUrl);
        Assert.Empty(storage.ReadUrls);
        Assert.Equal(1, pet.PhotosCount);
    }
}
