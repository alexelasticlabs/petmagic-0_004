using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task TemplateOfTheDayEndpoint_ShouldReturnNullTemplateWhenNoAssignmentExists()
    {
        await using var application = await TestApplication.CreateAsync();

        var response = await GetFromJsonAsync<PublicTemplateOfTheDayResponse>(
            application.Client,
            "/api/templates/template-of-the-day?date=2026-06-14");

        Assert.Null(response.Template);
    }

    [Fact]
    public async Task TemplateOfTheDayEndpoint_ShouldReturnMobileContractForManualAssignment()
    {
        await using var application = await TestApplication.CreateAsync();
        var date = new DateOnly(2026, 6, 14);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Daily Portrait",
            "Portrait",
            ["daily", "portrait"]);

        var assignment = await PostAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            "/api/admin/template-of-the-day",
            new AdminTemplateEndpoints.TemplateOfTheDayRequest(
                template.TemplateId,
                date,
                date,
                true,
                true,
                10,
                "Featured Daily Portrait",
                "Today's magic idea",
                "Template of the Day"));

        Assert.Equal(template.TemplateId, assignment.TemplateId);

        var response = await GetFromJsonAsync<PublicTemplateOfTheDayResponse>(
            application.Client,
            "/api/templates/template-of-the-day?date=2026-06-14&locale=en");

        var featured = Assert.IsType<PublicTemplateOfTheDayItemResponse>(response.Template);
        Assert.Equal(template.TemplateId, featured.TemplateId);
        Assert.Equal("Featured Daily Portrait", featured.Title);
        Assert.Equal("Today's magic idea", featured.Subtitle);
        Assert.Equal("Template of the Day", featured.BadgeText);
        Assert.Equal("Image", featured.Type);
        Assert.Equal(template.PreviewAsset?.Url, featured.ThumbnailUrl);
        Assert.Equal(template.PreviewAsset?.Url, featured.PreviewMediaUrl);
        Assert.False(featured.IsPremium);
        Assert.Equal("free", featured.RequiredPlan);
        Assert.Equal(date, featured.Date);
        Assert.Equal("manual", featured.Source);
        Assert.Equal("Portrait", featured.Category);
        Assert.Equal(["daily", "portrait"], featured.Tags);
        Assert.Equal(20, featured.TokenCost);
        Assert.NotNull(featured.PreviewAsset);
        Assert.Equal(template.PreviewAsset?.Url, featured.PreviewAsset?.Url);
    }

    [Fact]
    public async Task TemplateOfTheDayAdminCollectionEndpoint_ShouldWorkWithoutTrailingSlash()
    {
        await using var application = await TestApplication.CreateAsync();

        var schedule = await GetFromJsonAsync<AdminTemplateOfTheDayScheduleResponse>(
            application.Client,
            "/api/admin/template-of-the-day");

        Assert.Empty(schedule.Items);
        Assert.Equal(0, schedule.Skip);
        Assert.True(schedule.Take > 0);
    }
}
