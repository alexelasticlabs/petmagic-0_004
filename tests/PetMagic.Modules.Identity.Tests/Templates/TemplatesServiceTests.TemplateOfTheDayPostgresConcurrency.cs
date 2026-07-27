using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task ConcurrentTemplateOfTheDayAutoPick_ShouldPersistOneAutomaticAssignmentOnPostgres()
    {
        var options = TryCreateTemplateOfTheDayPostgresOptions();
        if (options is null)
        {
            return;
        }

        var date = CreateIsolatedTemplateOfTheDayDate();
        Guid templateId = Guid.Empty;
        Guid createdSettingsId = Guid.Empty;

        try
        {
            await using (var seedContext = new TemplatesDbContext(options))
            {
                templateId = await SeedTemplateOfTheDayCandidateAsync(seedContext);
                createdSettingsId = await EnsureTemplateOfTheDaySettingsAsync(seedContext);
            }

            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var workers = Enumerable.Range(0, 4).Select(async _ =>
            {
                await using var workerContext = new TemplatesDbContext(options);
                var service = CreateService(workerContext);
                await start.Task;
                return await service.AutoPickTemplateOfTheDayAsync(
                    new AutoPickTemplateOfTheDayCommand(date, "both", 0, null, Force: true),
                    CancellationToken.None);
            }).ToArray();

            start.TrySetResult();
            var results = await Task.WhenAll(workers);

            Assert.All(results, result => Assert.True(result.IsSuccess));
            Assert.Single(results.Select(result => result.Value.Id).Distinct());

            await using var verificationContext = new TemplatesDbContext(options);
            Assert.Equal(
                1,
                await verificationContext.TemplateOfTheDay.CountAsync(assignment =>
                    assignment.IsActive
                    && !assignment.IsManual
                    && assignment.StartDate == date
                    && assignment.EndDate == date));
        }
        finally
        {
            await CleanupTemplateOfTheDayPostgresDataAsync(options, [templateId], createdSettingsId);
        }
    }

    [Fact]
    public async Task ConcurrentTemplateOfTheDayManualCreate_ShouldAcceptOnlyOneOverlappingAssignmentOnPostgres()
    {
        var options = TryCreateTemplateOfTheDayPostgresOptions();
        if (options is null)
        {
            return;
        }

        var date = CreateIsolatedTemplateOfTheDayDate();
        Guid firstTemplateId = Guid.Empty;
        Guid secondTemplateId = Guid.Empty;

        try
        {
            await using (var seedContext = new TemplatesDbContext(options))
            {
                firstTemplateId = await SeedTemplateOfTheDayCandidateAsync(seedContext);
                secondTemplateId = await SeedTemplateOfTheDayCandidateAsync(seedContext);
            }

            var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var workers = new[] { firstTemplateId, secondTemplateId }
                .Select(async templateId =>
                {
                    await using var workerContext = new TemplatesDbContext(options);
                    var service = CreateService(workerContext);
                    await start.Task;
                    return await service.CreateTemplateOfTheDayAsync(
                        new CreateTemplateOfTheDayCommand(
                            templateId,
                            date,
                            date,
                            true,
                            true,
                            10,
                            null,
                            null,
                            null,
                            Guid.NewGuid()),
                        CancellationToken.None);
                })
                .ToArray();

            start.TrySetResult();
            var results = await Task.WhenAll(workers);

            Assert.Single(results, result => result.IsSuccess);
            var rejected = Assert.Single(results, result => result.IsFailure);
            Assert.Equal("templates.template_of_the_day_date_occupied", rejected.Error.Code);

            await using var verificationContext = new TemplatesDbContext(options);
            Assert.Equal(
                1,
                await verificationContext.TemplateOfTheDay.CountAsync(assignment =>
                    assignment.IsActive
                    && assignment.IsManual
                    && assignment.StartDate == date
                    && assignment.EndDate == date));
        }
        finally
        {
            await CleanupTemplateOfTheDayPostgresDataAsync(options, [firstTemplateId, secondTemplateId]);
        }
    }

    private static DbContextOptions<TemplatesDbContext>? TryCreateTemplateOfTheDayPostgresOptions()
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString)
            ? null
            : new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql(connectionString)
                .Options;
    }

    private static DateOnly CreateIsolatedTemplateOfTheDayDate()
    {
        return new DateOnly(2040, 1, 1)
            .AddDays((Guid.NewGuid().GetHashCode() & int.MaxValue) % 3_650);
    }

    private static async Task<Guid> SeedTemplateOfTheDayCandidateAsync(TemplatesDbContext dbContext)
    {
        var templateId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.TemplateItems.Add(new TemplateItem
        {
            Id = templateId,
            Version = 1,
            TemplateType = TemplateType.Image,
            Title = $"Template of the Day concurrency {templateId:N}",
            ShortDescription = "PostgreSQL concurrency fixture.",
            Category = "Concurrency",
            Tags = "concurrency",
            IsPremium = false,
            IsQaOnly = false,
            TokenCost = 20,
            Status = TemplateStatus.Active,
            PromoBadgeMode = TemplatePromoBadgeMode.Auto,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            PublishedAtUtc = now,
            UpdatedAtUtc = now,
            Assets =
            [
                new TemplateAsset
                {
                    Id = Guid.NewGuid(),
                    TemplateId = templateId,
                    AssetKind = TemplateAssetKind.Preview,
                    Url = $"https://cdn.example.com/{templateId:N}.jpg",
                    FileName = $"{templateId:N}.jpg",
                    ContentType = "image/jpeg",
                    FileSizeBytes = 1_024
                }
            ]
        });
        await dbContext.SaveChangesAsync();
        return templateId;
    }

    private static async Task<Guid> EnsureTemplateOfTheDaySettingsAsync(TemplatesDbContext dbContext)
    {
        if (await dbContext.TemplateOfTheDaySettings.AnyAsync())
        {
            return Guid.Empty;
        }

        var now = DateTime.UtcNow;
        var settings = new TemplateOfTheDaySettings
        {
            Id = Guid.NewGuid(),
            AutoModeEnabled = true,
            AllowedTypes = "both",
            ExcludeRecentDays = 7,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        dbContext.TemplateOfTheDaySettings.Add(settings);
        await dbContext.SaveChangesAsync();
        return settings.Id;
    }

    private static async Task CleanupTemplateOfTheDayPostgresDataAsync(
        DbContextOptions<TemplatesDbContext>? options,
        IReadOnlyCollection<Guid> templateIds,
        Guid createdSettingsId = default)
    {
        if (options is null)
        {
            return;
        }

        var ids = templateIds.Where(id => id != Guid.Empty).ToArray();
        await using var cleanupContext = new TemplatesDbContext(options);

        if (ids.Length > 0)
        {
            await cleanupContext.TemplateOfTheDay
                .Where(assignment => ids.Contains(assignment.TemplateId))
                .ExecuteDeleteAsync();
            await cleanupContext.TemplateItems
                .Where(template => ids.Contains(template.Id))
                .ExecuteDeleteAsync();
        }

        if (createdSettingsId != Guid.Empty)
        {
            await cleanupContext.TemplateOfTheDaySettings
                .Where(settings => settings.Id == createdSettingsId)
                .ExecuteDeleteAsync();
        }
    }
}
