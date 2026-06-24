using Microsoft.Extensions.Logging.Abstractions;

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
        var service = new PetsService(dbContext, storage, CreateTemplatesOptions(), NullLogger<PetsService>.Instance);

        var result = await service.ListAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var pet = Assert.Single(result.Value);
        Assert.Equal("https://cdn.petmagic.test/milo-original.jpg", pet.AvatarUrl);
        Assert.Empty(storage.ReadUrls);
        Assert.Equal(1, pet.PhotosCount);
    }

    [Fact]
    public async Task AddPhotoAsync_ShouldNormalizeDecodableImageBeforeStorage()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.Pets.Add(new Pet
        {
            Id = petId,
            UserId = userId,
            Name = "Nora",
            Type = "cat",
            Breed = "British",
            Status = "active",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var storage = new RecordingMediaStorage();
        var service = new PetsService(
            dbContext,
            storage,
            CreateTemplatesOptions(),
            NullLogger<PetsService>.Instance);

        var result = await service.AddPhotoAsync(
            new UploadPetPhotoCommand(
                userId,
                petId,
                new MediaUploadCommand("nora.png", "image/png", PngBytes())),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var stored = Assert.Single(storage.StoredAssets);
        Assert.Equal("image/jpeg", stored.ContentType);
        Assert.NotNull(stored.Content);
        Assert.True(stored.Content!.Take(3).SequenceEqual([0xFF, 0xD8, 0xFF]));
    }

    private static byte[] PngBytes()
    {
        return
        [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
            0x18, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82
        ];
    }
}
