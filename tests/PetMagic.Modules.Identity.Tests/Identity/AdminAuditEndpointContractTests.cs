using System.Text.Json;

using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminAuditEndpointContractTests
{
    [Fact]
    public void AdminAuditEndpoints_ShouldRegisterProtectedRoutesAndPrivateHeaders()
    {
        var source = ReadRepositoryFile(
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminAuditEndpoints.cs");

        Assert.Contains("endpoints.MapGroup(\"/api/admin/audit-events\")", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"\", ListAuditEventsAsync);", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/{eventId:guid}\", GetAuditEventAsync);", source, StringComparison.Ordinal);
        Assert.Contains(".RequireRateLimiting(\"admin\")", source, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"AdminOnly\")", source, StringComparison.Ordinal);
        Assert.Contains(".AddEndpointFilter(ApplyPrivateAdminAuditResponseHeadersAsync)", source, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.Pragma = \"no-cache\";", source, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.XContentTypeOptions = \"nosniff\";", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminAuditEndpoints_ShouldExposeTheAgreedQueryContract()
    {
        var source = ReadRepositoryFile(
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminAuditEndpoints.cs");

        Assert.Contains("[FromQuery] int? skip,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] int? take,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] string? search,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] string? category,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] Guid? actorUserId,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] Guid? subjectUserId,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] DateTime? fromUtc,", source, StringComparison.Ordinal);
        Assert.Contains("[FromQuery] DateTime? toUtc,", source, StringComparison.Ordinal);

        Assert.Contains("StatusCodes.Status400BadRequest", source, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminAuditEndpoints_ShouldBeMappedAndServiceRegistered()
    {
        var apiModule = ReadRepositoryFile(
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "IdentityApiModule.cs");
        var infrastructureRegistration = ReadRepositoryFile(
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "IdentityInfrastructureServiceCollectionExtensions.cs");

        Assert.Contains("app.MapAdminAuditEndpoints();", apiModule, StringComparison.Ordinal);
        Assert.Contains(
            "services.AddScoped<IAdminAuditQueryService, IdentityAdminAuditQueryService>();",
            infrastructureRegistration,
            StringComparison.Ordinal);
    }

    [Fact]
    public void AdminAuditListJson_ShouldKeepSensitiveDetailFieldsOutOfThePayload()
    {
        var item = new AdminAuditEventListItemResponse(
            Guid.NewGuid(),
            "admin.test.action",
            AdminAuditCategories.System,
            Guid.NewGuid(),
            "Actor",
            "actor@petmagic.test",
            "Admin",
            Guid.NewGuid(),
            "Subject",
            "subject@petmagic.test",
            "Target",
            "target-id",
            "correlation-id",
            DateTime.UtcNow);
        var json = JsonSerializer.SerializeToElement(item, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var propertyNames = json.EnumerateObject().Select(x => x.Name).ToHashSet(StringComparer.Ordinal);

        Assert.True(propertyNames.SetEquals(new[]
        {
            "auditEventId",
            "action",
            "category",
            "actorUserId",
            "actorDisplayName",
            "actorEmail",
            "actorRole",
            "subjectUserId",
            "subjectDisplayName",
            "subjectEmail",
            "targetType",
            "targetId",
            "correlationId",
            "occurredAtUtc",
        }));
        Assert.DoesNotContain("oldValue", propertyNames);
        Assert.DoesNotContain("newValue", propertyNames);
        Assert.DoesNotContain("details", propertyNames);
        Assert.DoesNotContain("ipAddress", propertyNames);
        Assert.DoesNotContain("userAgent", propertyNames);

        var page = new AdminAuditEventsPageResponse(
            [item],
            0,
            25,
            1,
            false,
            new AdminAuditEventsSummaryResponse(1, 1, 0, 1));
        var pageJson = JsonSerializer.SerializeToElement(page, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.True(pageJson.EnumerateObject().Select(x => x.Name).ToHashSet(StringComparer.Ordinal).SetEquals(new[]
        {
            "items",
            "skip",
            "take",
            "totalCount",
            "hasMore",
            "summary",
        }));
        Assert.True(pageJson.GetProperty("summary").EnumerateObject()
            .Select(x => x.Name)
            .ToHashSet(StringComparer.Ordinal)
            .SetEquals(new[] { "totalEvents", "uniqueActors", "accessEvents", "systemEvents" }));
    }

    [Fact]
    public void AdminAuditDetailJson_ShouldExtendTheListContractWithSanitizedFields()
    {
        var detail = new AdminAuditEventDetailResponse(
            Guid.NewGuid(),
            "admin.test.action",
            AdminAuditCategories.System,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            DateTime.UtcNow,
            null,
            null,
            string.Empty,
            null,
            null,
            DateTime.UtcNow);
        var json = JsonSerializer.SerializeToElement(detail, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var propertyNames = json.EnumerateObject().Select(x => x.Name).ToHashSet(StringComparer.Ordinal);

        Assert.True(propertyNames.SetEquals(new[]
        {
            "auditEventId",
            "action",
            "category",
            "actorUserId",
            "actorDisplayName",
            "actorEmail",
            "actorRole",
            "subjectUserId",
            "subjectDisplayName",
            "subjectEmail",
            "targetType",
            "targetId",
            "correlationId",
            "occurredAtUtc",
            "oldValue",
            "newValue",
            "details",
            "ipAddress",
            "userAgent",
            "createdAtUtc",
        }));
    }

    private static string ReadRepositoryFile(params string[] pathSegments)
    {
        return File.ReadAllText(Path.Combine([FindRepositoryRoot(), .. pathSegments]));
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
