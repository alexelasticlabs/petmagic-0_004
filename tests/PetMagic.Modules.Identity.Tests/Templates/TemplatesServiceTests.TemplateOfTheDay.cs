using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldReturnManualAssignmentWithOverrides()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var templateId = await CreateActiveImageTemplateAsync(service, "Cozy Magic", "Portrait", ["cozy"]);

        var created = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                templateId,
                today,
                today,
                true,
                true,
                10,
                "Featured Cozy Magic",
                "Today's magic idea",
                "Template of the Day",
                Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var result = await service.GetPublicTemplateOfTheDayAsync(today, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        var template = Assert.IsType<PublicTemplateOfTheDayItemResponse>(result.Value.Template);
        Assert.Equal(templateId, template.TemplateId);
        Assert.Equal("Featured Cozy Magic", template.Title);
        Assert.Equal("Today's magic idea", template.Subtitle);
        Assert.Equal("Template of the Day", template.BadgeText);
        Assert.Equal("Image", template.Type);
        Assert.Equal("free", template.RequiredPlan);
        Assert.Equal("manual", template.Source);
        Assert.Equal(today, template.Date);
        Assert.Equal("https://cdn.example.com/cozy-magic.jpg", template.ThumbnailUrl);
        Assert.Equal("https://cdn.example.com/cozy-magic.jpg", template.PreviewMediaUrl);
        Assert.Equal("Portrait", template.Category);
        Assert.Equal(["cozy"], template.Tags);
        Assert.Equal(20, template.TokenCost);
        Assert.NotNull(template.PreviewAsset);
        Assert.Equal("https://cdn.example.com/cozy-magic.jpg", template.PreviewAsset?.Url);
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldReturnVideoPreviewAndPremiumFields()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);

        var createdVideo = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                "Daily Motion",
                "Video pick description",
                "Video",
                ["daily", "motion"],
                true,
                60,
                TemplatePromoBadgeMode.Auto.ToString(),
                "Meme soundtrack",
                CreatePreviewAsset("https://cdn.example.com/daily-motion.mp4", "daily-motion.mp4", "video/mp4"),
                CreateReferenceAsset(5.0),
                "openai/gpt-image-2/edit",
                "keep pet",
                "fal-ai/kling-video/v3/pro/motion-control",
                "motion prompt",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(createdVideo.IsSuccess);

        var createdAssignment = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                createdVideo.Value.TemplateId,
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

        Assert.True(createdAssignment.IsSuccess);

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        var template = Assert.IsType<PublicTemplateOfTheDayItemResponse>(result.Value.Template);
        Assert.Equal(createdVideo.Value.TemplateId, template.TemplateId);
        Assert.Equal("Video", template.Type);
        Assert.Null(template.ThumbnailUrl);
        Assert.Equal("https://cdn.example.com/daily-motion.mp4", template.PreviewMediaUrl);
        Assert.True(template.IsPremium);
        Assert.Equal("premium", template.RequiredPlan);
        Assert.Equal("Video", template.Category);
        Assert.Equal(["daily", "motion"], template.Tags);
        Assert.Equal(60, template.TokenCost);
        Assert.NotNull(template.PreviewAsset);
        Assert.Equal("video/mp4", template.PreviewAsset?.ContentType);
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldNotCrashOnLegacyNullPreviewContentType()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);
        var templateId = await CreateActiveImageTemplateAsync(service, "Legacy Preview", "Portrait", ["legacy"]);

        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .SingleAsync(x => x.Id == templateId);
        template.Assets.Single(x => x.AssetKind == TemplateAssetKind.Preview).ContentType = null!;

        var createdAssignment = await service.CreateTemplateOfTheDayAsync(
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

        Assert.True(createdAssignment.IsSuccess);

        await dbContext.SaveChangesAsync();

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        var featured = Assert.IsType<PublicTemplateOfTheDayItemResponse>(result.Value.Template);
        Assert.Equal(templateId, featured.TemplateId);
        Assert.Equal("https://cdn.example.com/legacy-preview.jpg", featured.ThumbnailUrl);
        Assert.Equal("https://cdn.example.com/legacy-preview.jpg", featured.PreviewMediaUrl);
        Assert.NotNull(featured.PreviewAsset);
        Assert.Equal(string.Empty, featured.PreviewAsset!.ContentType);
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldCreateStableAutoFallback()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);
        await CreateActiveImageTemplateAsync(service, "Auto One", "Portrait", ["auto"]);
        await CreateActiveImageTemplateAsync(service, "Auto Two", "Portrait", ["auto"]);

        var first = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);
        var second = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.NotNull(first.Value.Template);
        Assert.NotNull(second.Value.Template);
        Assert.Equal(first.Value.Template.TemplateId, second.Value.Template.TemplateId);
        Assert.Equal("auto", first.Value.Template.Source);
        Assert.Equal(1, await dbContext.TemplateOfTheDay.CountAsync(x => !x.IsManual && x.StartDate == date));
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldSkipManualAssignmentWhenTemplateBecomesArchived()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(5);
        var manualTemplateId = await CreateActiveImageTemplateAsync(service, "Archived Manual Pick", "Portrait", ["daily"]);
        var activeTemplateId = await CreateActiveImageTemplateAsync(service, "Active Auto Pick", "Portrait", ["daily"]);

        var manual = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                manualTemplateId,
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

        Assert.True(manual.IsSuccess);

        var archived = await dbContext.TemplateItems.SingleAsync(x => x.Id == manualTemplateId);
        archived.Status = TemplateStatus.Archived;
        await dbContext.SaveChangesAsync();

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        var template = Assert.IsType<PublicTemplateOfTheDayItemResponse>(result.Value.Template);
        Assert.Equal(activeTemplateId, template.TemplateId);
        Assert.Equal("auto", template.Source);
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldKeepManualAssignmentWhenCategoryBecomesArchived()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(6);
        var manualTemplateId = await CreateActiveImageTemplateAsync(service, "Archived Category Daily Pick", "Seasonal", ["daily"]);
        await CreateActiveImageTemplateAsync(service, "Active Category Daily Pick", "Evergreen", ["daily"]);

        var manual = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                manualTemplateId,
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

        Assert.True(manual.IsSuccess);

        var archivedCategory = await dbContext.TemplateCategories.SingleAsync(category => category.Name == "Seasonal");
        archivedCategory.IsArchived = true;
        await dbContext.SaveChangesAsync();

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        var template = Assert.IsType<PublicTemplateOfTheDayItemResponse>(result.Value.Template);
        Assert.Equal(manualTemplateId, template.TemplateId);
        Assert.Equal("manual", template.Source);
    }

    [Fact]
    public async Task CurrentTemplateOfTheDayAsync_ShouldUseConfiguredBusinessTimeZoneWhenDateIsOmitted()
    {
        await using var dbContext = CreateDbContext();
        var (timeZoneId, businessDate) = ResolveBusinessDateDifferentFromUtc();
        var service = CreateService(
            dbContext,
            templatesOptions: CreateTemplatesServiceOptions(timeZoneId));
        var templateId = await CreateActiveImageTemplateAsync(service, "Business Time Pick", "Portrait", ["daily"]);

        var created = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                templateId,
                businessDate,
                businessDate,
                true,
                true,
                10,
                "Business Time Featured",
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);

        var publicResult = await service.GetPublicTemplateOfTheDayAsync(null, "en", CancellationToken.None);
        var adminResult = await service.GetAdminCurrentTemplateOfTheDayAsync(null, CancellationToken.None);

        Assert.True(publicResult.IsSuccess);
        var template = Assert.IsType<PublicTemplateOfTheDayItemResponse>(publicResult.Value.Template);
        Assert.Equal(templateId, template.TemplateId);
        Assert.Equal(businessDate, template.Date);
        Assert.Equal("manual", template.Source);
        Assert.True(adminResult.IsSuccess);
        Assert.NotNull(adminResult.Value);
        Assert.Equal(templateId, adminResult.Value.TemplateId);
        Assert.Equal(businessDate, adminResult.Value.StartDate);
    }

    [Fact]
    public async Task GetAdminTemplateOfTheDaySettingsAsync_ShouldReturnDefaultSettings()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.GetAdminTemplateOfTheDaySettingsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.AutoModeEnabled);
        Assert.Equal("both", result.Value.AllowedTypes);
        Assert.Equal(7, result.Value.ExcludeRecentDays);
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldNotCreateAutoFallbackWhenAutoModeDisabled()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);
        await CreateActiveImageTemplateAsync(service, "Auto Disabled", "Portrait", ["auto"]);

        var settings = await service.UpdateAdminTemplateOfTheDaySettingsAsync(
            new UpdateTemplateOfTheDaySettingsCommand(false, "both", 7, Guid.NewGuid()),
            CancellationToken.None);
        Assert.True(settings.IsSuccess);

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Null(result.Value.Template);
        Assert.Equal(0, await dbContext.TemplateOfTheDay.CountAsync(x => !x.IsManual && x.StartDate == date));
    }

    [Fact]
    public async Task GetPublicTemplateOfTheDayAsync_ShouldReturnManualAssignmentWhenAutoModeDisabled()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(2);
        var templateId = await CreateActiveImageTemplateAsync(service, "Manual While Disabled", "Portrait", ["manual"]);

        var settings = await service.UpdateAdminTemplateOfTheDaySettingsAsync(
            new UpdateTemplateOfTheDaySettingsCommand(false, "both", 7, Guid.NewGuid()),
            CancellationToken.None);
        Assert.True(settings.IsSuccess);

        var manual = await service.CreateTemplateOfTheDayAsync(
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
        Assert.True(manual.IsSuccess);

        var result = await service.GetPublicTemplateOfTheDayAsync(date, "en", CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(result.Value.Template);
        Assert.Equal(templateId, result.Value.Template.TemplateId);
        Assert.Equal("manual", result.Value.Template.Source);
    }

    [Fact]
    public async Task AutoPickTemplateOfTheDayAsync_ShouldRespectDisabledAutoModeUnlessForced()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(3);
        await CreateActiveImageTemplateAsync(service, "Disabled Worker Candidate", "Portrait", ["auto"]);

        var settings = await service.UpdateAdminTemplateOfTheDaySettingsAsync(
            new UpdateTemplateOfTheDaySettingsCommand(false, "both", 7, Guid.NewGuid()),
            CancellationToken.None);
        Assert.True(settings.IsSuccess);

        var workerResult = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(date, null, null, null),
            CancellationToken.None);
        var forcedResult = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(date, null, null, Guid.NewGuid(), Force: true),
            CancellationToken.None);

        Assert.True(workerResult.IsFailure);
        Assert.Equal("templates.template_of_the_day_auto_mode_disabled", workerResult.Error.Code);
        Assert.True(forcedResult.IsSuccess);
        Assert.Equal(1, await dbContext.TemplateOfTheDay.CountAsync(x => !x.IsManual && x.StartDate == date));
    }

    [Fact]
    public async Task CreateTemplateOfTheDayAsync_ShouldRejectInactiveTemplate()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var draft = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                "Draft Magic",
                "Draft description",
                "Portrait",
                ["draft"],
                false,
                20,
                TemplatePromoBadgeMode.Auto.ToString(),
                CreatePreviewAsset("https://cdn.example.com/draft.jpg", "draft.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet."),
            CancellationToken.None);

        Assert.True(draft.IsSuccess);

        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                draft.Value.TemplateId,
                DateOnly.FromDateTime(DateTime.UtcNow),
                null,
                true,
                true,
                0,
                null,
                null,
                null,
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_template_unavailable", result.Error.Code);
    }

    [Fact]
    public async Task CreateTemplateOfTheDayAsync_ShouldRejectDeletedTemplate()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Deleted Daily Pick", "Portrait", ["daily"]);
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        template.DeletedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                templateId,
                DateOnly.FromDateTime(DateTime.UtcNow),
                null,
                true,
                true,
                0,
                null,
                null,
                null,
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_template_unavailable", result.Error.Code);
    }

    [Fact]
    public async Task CreateTemplateOfTheDayAsync_ShouldRejectTemplateWithBlankPreviewUrl()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var templateId = await CreateActiveImageTemplateAsync(service, "Broken Daily Pick", "Portrait", ["daily"]);
        var template = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .SingleAsync(x => x.Id == templateId);
        template.Assets.Single(x => x.AssetKind == TemplateAssetKind.Preview).Url = "   ";
        await dbContext.SaveChangesAsync();

        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                templateId,
                DateOnly.FromDateTime(DateTime.UtcNow),
                null,
                true,
                true,
                0,
                null,
                null,
                null,
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_template_unavailable", result.Error.Code);
    }

    [Fact]
    public async Task AutoPickTemplateOfTheDayAsync_ShouldRejectDeletedAndBrokenCandidates()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var deletedTemplateId = await CreateActiveImageTemplateAsync(service, "Deleted Auto Pick", "Portrait", ["auto"]);
        var brokenTemplateId = await CreateActiveImageTemplateAsync(service, "Broken Auto Pick", "Portrait", ["auto"]);
        var deletedTemplate = await dbContext.TemplateItems.SingleAsync(x => x.Id == deletedTemplateId);
        var brokenTemplate = await dbContext.TemplateItems
            .Include(x => x.Assets)
            .SingleAsync(x => x.Id == brokenTemplateId);
        deletedTemplate.DeletedAtUtc = DateTime.UtcNow;
        brokenTemplate.Assets.Single(x => x.AssetKind == TemplateAssetKind.Preview).Url = "   ";
        await dbContext.SaveChangesAsync();

        var result = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(DateOnly.FromDateTime(DateTime.UtcNow).AddDays(4), "both", 7, null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_template_unavailable", result.Error.Code);
        Assert.Equal(0, await dbContext.TemplateOfTheDay.CountAsync());
    }

    [Fact]
    public async Task AutoPickTemplateOfTheDayAsync_ShouldExcludeRecentlyUsedTemplatesWhenPossible()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(2);
        var recentTemplateId = await CreateActiveImageTemplateAsync(service, "Recent Pick", "Portrait", ["auto"]);
        var freshTemplateId = await CreateActiveImageTemplateAsync(service, "Fresh Pick", "Portrait", ["auto"]);
        var recentTemplate = await dbContext.TemplateItems.SingleAsync(x => x.Id == recentTemplateId);

        dbContext.TemplateOfTheDay.Add(new TemplateOfTheDay
        {
            Id = Guid.NewGuid(),
            TemplateId = recentTemplateId,
            Template = recentTemplate,
            StartDate = date.AddDays(-1),
            EndDate = date.AddDays(-1),
            IsActive = true,
            IsManual = false,
            Priority = 0,
            CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
            UpdatedAtUtc = DateTime.UtcNow.AddDays(-1)
        });
        await dbContext.SaveChangesAsync();

        var result = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(date, "both", 7, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(freshTemplateId, result.Value.TemplateId);
    }

    [Fact]
    public async Task AutoPickTemplateOfTheDayAsync_ShouldReuseManualAssignment()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var date = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(3);
        var manualTemplateId = await CreateActiveImageTemplateAsync(service, "Manual Pick", "Portrait", ["manual"]);
        await CreateActiveImageTemplateAsync(service, "Auto Candidate", "Portrait", ["auto"]);

        var manual = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                manualTemplateId,
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

        Assert.True(manual.IsSuccess);

        var result = await service.AutoPickTemplateOfTheDayAsync(
            new AutoPickTemplateOfTheDayCommand(date, "both", 7, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(manual.Value.Id, result.Value.Id);
        Assert.Equal(manualTemplateId, result.Value.TemplateId);
        Assert.Equal(0, await dbContext.TemplateOfTheDay.CountAsync(x => !x.IsManual && x.StartDate == date));
    }

    [Fact]
    public async Task CreateTemplateOfTheDayAsync_ShouldRejectInvalidDateRange()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var startDate = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(7);
        var templateId = await CreateActiveImageTemplateAsync(service, "Invalid Range Pick", "Portrait", ["manual"]);

        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                templateId,
                startDate,
                startDate.AddDays(-1),
                true,
                true,
                10,
                null,
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_invalid_date_range", result.Error.Code);
        Assert.Equal(0, await dbContext.TemplateOfTheDay.CountAsync());
    }

    [Fact]
    public async Task CreateTemplateOfTheDayAsync_ShouldRejectOverlappingActiveManualAssignment()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var startDate = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(8);
        var firstTemplateId = await CreateActiveImageTemplateAsync(service, "First Manual Pick", "Portrait", ["manual"]);
        var secondTemplateId = await CreateActiveImageTemplateAsync(service, "Second Manual Pick", "Portrait", ["manual"]);

        var first = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                firstTemplateId,
                startDate,
                startDate.AddDays(2),
                true,
                true,
                10,
                null,
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);
        Assert.True(first.IsSuccess);

        var result = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                secondTemplateId,
                startDate.AddDays(1),
                startDate.AddDays(1),
                true,
                true,
                20,
                null,
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_date_occupied", result.Error.Code);
        Assert.Equal(1, await dbContext.TemplateOfTheDay.CountAsync(x => x.IsManual && x.IsActive));
    }

    [Fact]
    public async Task UpdateTemplateOfTheDayAsync_ShouldRejectOverlappingActiveManualAssignment()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var startDate = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(12);
        var firstTemplateId = await CreateActiveImageTemplateAsync(service, "Occupied Manual Pick", "Portrait", ["manual"]);
        var secondTemplateId = await CreateActiveImageTemplateAsync(service, "Movable Manual Pick", "Portrait", ["manual"]);

        var first = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                firstTemplateId,
                startDate,
                startDate,
                true,
                true,
                10,
                null,
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);
        var second = await service.CreateTemplateOfTheDayAsync(
            new CreateTemplateOfTheDayCommand(
                secondTemplateId,
                startDate.AddDays(2),
                startDate.AddDays(2),
                true,
                true,
                10,
                null,
                null,
                null,
                Guid.NewGuid()),
            CancellationToken.None);
        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);

        var result = await service.UpdateTemplateOfTheDayAsync(
            new UpdateTemplateOfTheDayCommand(
                second.Value.Id,
                secondTemplateId,
                startDate,
                startDate,
                true,
                true,
                20,
                null,
                null,
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.template_of_the_day_date_occupied", result.Error.Code);
        var unchanged = await dbContext.TemplateOfTheDay.SingleAsync(x => x.Id == second.Value.Id);
        Assert.Equal(startDate.AddDays(2), unchanged.StartDate);
    }

    private static (string TimeZoneId, DateOnly BusinessDate) ResolveBusinessDateDifferentFromUtc()
    {
        var utcDate = DateOnly.FromDateTime(DateTime.UtcNow);
        foreach (var timeZoneId in new[] { "Pacific/Kiritimati", "Etc/GMT+12" })
        {
            try
            {
                var timeZone = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
                var businessDate = DateOnly.FromDateTime(
                    TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, timeZone));
                if (businessDate != utcDate)
                {
                    return (timeZoneId, businessDate);
                }
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        throw new InvalidOperationException("Could not resolve a test timezone with a business date different from UTC.");
    }
}
