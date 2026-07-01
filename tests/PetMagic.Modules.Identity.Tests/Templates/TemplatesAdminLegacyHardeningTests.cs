using System.Reflection;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatesAdminLegacyHardeningTests
{
    [Fact]
    public void AdminTemplateMappers_ShouldNormalizeLegacyNullFields()
    {
        var templatesServiceType = typeof(TemplateItem).Assembly.GetType(
            "PetMagic.Modules.Templates.Infrastructure.TemplatesService",
            throwOnError: true)!;
        var mapAdminListItem = templatesServiceType.GetMethod(
            "MapAdminListItem",
            BindingFlags.NonPublic | BindingFlags.Static);
        var mapAdminResponse = templatesServiceType.GetMethod(
            "MapAdminResponse",
            BindingFlags.NonPublic | BindingFlags.Static);

        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = null!,
            ShortDescription = null!,
            Category = null!,
            Tags = null!,
            Status = TemplateStatus.Active,
            PromoBadgeMode = TemplatePromoBadgeMode.Auto,
            DefaultVariationStrength = null!,
            CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
            UpdatedAtUtc = DateTime.UtcNow,
        };

        var listItem = Assert.IsType<AdminTemplateListItemResponse>(mapAdminListItem!.Invoke(null, [template]));
        var response = Assert.IsType<AdminTemplateResponse>(mapAdminResponse!.Invoke(null, [template]));

        Assert.Equal(string.Empty, listItem.Title);
        Assert.Equal(string.Empty, listItem.ShortDescription);
        Assert.Equal(string.Empty, listItem.Category);
        Assert.Equal("medium", listItem.DefaultVariationStrength);
        Assert.Empty(listItem.Tags);

        Assert.Equal(string.Empty, response.Title);
        Assert.Equal(string.Empty, response.ShortDescription);
        Assert.Equal(string.Empty, response.Category);
        Assert.Equal("medium", response.DefaultVariationStrength);
        Assert.Empty(response.Tags);
    }

    [Fact]
    public void ModerationQueueMapper_ShouldNormalizeLegacyNullFields()
    {
        var templatesServiceType = typeof(TemplateItem).Assembly.GetType(
            "PetMagic.Modules.Templates.Infrastructure.TemplatesService",
            throwOnError: true)!;
        var mapModerationQueueItem = templatesServiceType.GetMethod(
            "MapModerationQueueItem",
            BindingFlags.NonPublic | BindingFlags.Static);

        var response = Assert.IsType<AdminModerationQueueItemResponse>(mapModerationQueueItem!.Invoke(null, [
            new TemplateAnalyticsEvent
            {
                Id = Guid.NewGuid(),
                TemplateId = Guid.NewGuid(),
                Template = new TemplateItem
                {
                    Id = Guid.NewGuid(),
                    TemplateType = TemplateType.Video,
                    Title = null!,
                },
                EventType = null!,
                ModerationStatus = null!,
                Source = null!,
                DeviceClass = null!,
                CountryCode = null!,
                CreatedAtUtc = DateTime.UtcNow,
            }
        ]));

        Assert.Equal(string.Empty, response.TemplateTitle);
        Assert.Equal("Video", response.TemplateType);
        Assert.Equal(string.Empty, response.EventType);
        Assert.Equal(string.Empty, response.Status);
        Assert.Equal(string.Empty, response.Source);
        Assert.Equal(string.Empty, response.DeviceClass);
        Assert.Equal(string.Empty, response.CountryCode);
    }

    [Fact]
    public void TemplateOfTheDayMappers_ShouldNormalizeLegacyNullFields()
    {
        var templatesServiceType = typeof(TemplateItem).Assembly.GetType(
            "PetMagic.Modules.Templates.Infrastructure.TemplatesService",
            throwOnError: true)!;
        var mapAdminTemplateOfTheDay = templatesServiceType.GetMethod(
            "MapAdminTemplateOfTheDay",
            BindingFlags.NonPublic | BindingFlags.Static);
        var mapPublicTemplateOfTheDay = templatesServiceType.GetMethod(
            "MapPublicTemplateOfTheDay",
            BindingFlags.NonPublic | BindingFlags.Static);

        var assignment = new TemplateOfTheDay
        {
            Id = Guid.NewGuid(),
            TemplateId = Guid.NewGuid(),
            Template = new TemplateItem
            {
                Id = Guid.NewGuid(),
                TemplateType = TemplateType.Image,
                Title = null!,
                ShortDescription = null!,
                Category = null!,
                Tags = null!,
                Status = TemplateStatus.Active,
                Assets =
                [
                    new TemplateAsset
                    {
                        Id = Guid.NewGuid(),
                        TemplateId = Guid.NewGuid(),
                        AssetKind = TemplateAssetKind.Preview,
                        Url = "https://cdn.example.com/legacy-totd.jpg",
                        FileName = "legacy-totd.jpg",
                        ContentType = "image/jpeg",
                    }
                ]
            },
            StartDate = DateOnly.FromDateTime(DateTime.UtcNow),
            IsActive = true,
            IsManual = true,
            CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
            UpdatedAtUtc = DateTime.UtcNow,
        };

        var adminResponse = Assert.IsType<AdminTemplateOfTheDayResponse>(mapAdminTemplateOfTheDay!.Invoke(null, [assignment]));
        var publicResponse = Assert.IsType<PublicTemplateOfTheDayItemResponse>(mapPublicTemplateOfTheDay!.Invoke(null, [
            assignment,
            assignment.StartDate,
            "en"
        ]));

        Assert.Equal(string.Empty, adminResponse.TemplateTitle);
        Assert.Equal(string.Empty, adminResponse.Category);
        Assert.Equal(string.Empty, publicResponse.Title);
        Assert.Equal(string.Empty, publicResponse.Subtitle);
        Assert.Equal(string.Empty, publicResponse.Category);
        Assert.Empty(publicResponse.Tags);
    }

    [Fact]
    public void TemplateCategoryMapper_ShouldNormalizeLegacyNullName()
    {
        var serviceType = typeof(TemplateCategory).Assembly.GetType(
            "PetMagic.Modules.Templates.Infrastructure.TemplateCategoryAdminService",
            throwOnError: true)!;
        var method = serviceType.GetMethod(
            "MapAdminCategory",
            BindingFlags.NonPublic | BindingFlags.Static);
        var snapshotParameterType = method!.GetParameters()[1].ParameterType;
        var emptySnapshots = Array.CreateInstance(snapshotParameterType.GenericTypeArguments[0], 0);

        var response = Assert.IsType<AdminTemplateCategoryListItemResponse>(method.Invoke(null, [
            new TemplateCategory
            {
                Id = Guid.NewGuid(),
                Name = null!,
                CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
                UpdatedAtUtc = DateTime.UtcNow,
            },
            emptySnapshots
        ]));

        Assert.Equal(string.Empty, response.Name);
    }

    [Fact]
    public void TemplateCategoryAdminList_ShouldNormalizeLegacyNullLookupKeys()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateCategoryAdminService.cs"));

        Assert.Contains("NormalizeCategoryLookupKey(category.Name)", source, StringComparison.Ordinal);
        Assert.Contains("NormalizeCategoryLookupKey(template.Category)", source, StringComparison.Ordinal);
        Assert.Contains("includesEmptyCategory && (template.Category == null || template.Category == string.Empty)", source, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
