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
    public async Task TemplateOfTheDayEndpoint_ShouldNotMaterializeAutoAssignmentForExplicitDate()
    {
        await using var application = await TestApplication.CreateAsync();
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Read Only Public Date",
            "Portrait",
            ["daily"]);

        var response = await GetFromJsonAsync<PublicTemplateOfTheDayResponse>(
            application.Client,
            "/api/templates/template-of-the-day?date=2030-06-14");
        var schedule = await GetFromJsonAsync<AdminTemplateOfTheDayScheduleResponse>(
            application.Client,
            "/api/admin/template-of-the-day");

        Assert.NotEqual(Guid.Empty, template.TemplateId);
        Assert.Null(response.Template);
        Assert.Empty(schedule.Items);
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
    public async Task TemplateOfTheDayAdminCreateEndpoint_ShouldAlwaysCreateManualAssignment()
    {
        await using var application = await TestApplication.CreateAsync();
        var date = new DateOnly(2030, 6, 14);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Forced Manual Daily Portrait",
            "Portrait",
            ["daily"]);

        var assignment = await PostAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            "/api/admin/template-of-the-day",
            new AdminTemplateEndpoints.TemplateOfTheDayRequest(
                template.TemplateId,
                date,
                date,
                true,
                false,
                10,
                null,
                null,
                null));

        Assert.True(assignment.IsManual);
    }

    [Fact]
    public async Task TemplateOfTheDayAdminUpdateEndpoint_ShouldPreserveAutomaticMode()
    {
        await using var application = await TestApplication.CreateAsync();
        var date = new DateOnly(2030, 6, 15);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Automatic Daily Portrait",
            "Portrait",
            ["daily"]);

        var automatic = await PostAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            "/api/admin/template-of-the-day/auto-pick",
            new AdminTemplateEndpoints.AutoPickTemplateOfTheDayRequest(date, "both", 0));
        Assert.False(automatic.IsManual);

        var updated = await PutAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            $"/api/admin/template-of-the-day/{automatic.Id}",
            new AdminTemplateEndpoints.TemplateOfTheDayRequest(
                template.TemplateId,
                date,
                date,
                true,
                true,
                10,
                "Updated automatic daily portrait",
                null,
                null));

        Assert.False(updated.IsManual);
        Assert.Equal("Updated automatic daily portrait", updated.TitleOverride);
    }

    [Fact]
    public async Task TemplateOfTheDayAdminUpdateAndDeleteEndpoints_ShouldWriteAuditWithAuthenticatedActor()
    {
        var auditLog = new RecordingAdminAuditLog();
        await using var application = await TestApplication.CreateAsync(adminAuditLog: auditLog);
        var date = new DateOnly(2030, 6, 16);
        var template = await CreateActiveImageTemplateAsync(
            application.Client,
            "Audited Daily Portrait",
            "Portrait",
            ["daily"]);

        var assignment = await PostAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            "/api/admin/template-of-the-day",
            new AdminTemplateEndpoints.TemplateOfTheDayRequest(
                template.TemplateId,
                date,
                date,
                true,
                true,
                0,
                "Initial daily portrait",
                null,
                null));
        auditLog.Entries.Clear();

        var updated = await PutAsJsonAsync<AdminTemplateOfTheDayResponse>(
            application.Client,
            $"/api/admin/template-of-the-day/{assignment.Id}",
            new AdminTemplateEndpoints.TemplateOfTheDayRequest(
                template.TemplateId,
                date,
                date,
                true,
                false,
                5,
                "Updated daily portrait",
                null,
                null));
        Assert.Equal(5, updated.Priority);

        using var deleteResponse = await application.Client.DeleteAsync(
            $"/api/admin/template-of-the-day/{assignment.Id}");
        await EnsureSuccessStatusCodeAsync(deleteResponse, "/api/admin/template-of-the-day/{id}");

        var audits = auditLog.Entries;
        Assert.Equal(
            [
                "admin.template_of_the_day.updated",
                "admin.template_of_the_day.deleted"
            ],
            audits.Select(audit => audit.Action));
        Assert.All(audits, audit => Assert.Equal(TestUserId, audit.ActorUserId));
        Assert.All(audits, audit => Assert.Equal(assignment.Id.ToString("D"), audit.TargetId));
        Assert.Contains("titleOverride=Initial daily portrait", audits[0].OldValue, StringComparison.Ordinal);
        Assert.Contains("titleOverride=Updated daily portrait", audits[0].NewValue, StringComparison.Ordinal);
        Assert.Contains("priority=5", audits[1].OldValue, StringComparison.Ordinal);
        Assert.Equal("deleted", audits[1].NewValue);
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

    [Fact]
    public async Task TemplateOfTheDaySettingsEndpoint_ShouldReturnCanonicalBusinessDate()
    {
        await using var application = await TestApplication.CreateAsync();

        var settings = await GetFromJsonAsync<AdminTemplateOfTheDaySettingsResponse>(
            application.Client,
            "/api/admin/template-of-the-day/settings");

        Assert.NotEqual(default, settings.BusinessDate);
    }
}
