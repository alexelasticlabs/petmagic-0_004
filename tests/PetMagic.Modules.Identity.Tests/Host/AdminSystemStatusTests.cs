using System.Text.Json;

using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class AdminSystemStatusTests
{
    [Fact]
    public void BuildResponse_ShouldExposeDeterministicSanitizedContract()
    {
        var generatedAtUtc = new DateTimeOffset(2026, 7, 27, 10, 30, 0, TimeSpan.Zero);
        var report = CreateReport(new Dictionary<string, HealthReportEntry>(StringComparer.Ordinal)
        {
            ["self"] = CreateEntry(HealthStatus.Healthy, "raw api description"),
            ["economy_subscription_plans"] = CreateEntry(
                HealthStatus.Degraded,
                "provider-plan-secret",
                new InvalidOperationException("database-password")),
            ["store_account_binding"] = CreateEntry(HealthStatus.Healthy, "compatibility details"),
            ["templates_scheduler_config"] = CreateEntry(HealthStatus.Unhealthy, "checksum-secret")
        });

        var response = AdminSystemStatusService.BuildResponse(report, generatedAtUtc);

        Assert.Equal("unhealthy", response.OverallStatus);
        Assert.Equal(generatedAtUtc, response.GeneratedAtUtc);
        Assert.Equal(60, response.StaleAfterSeconds);
        Assert.Equal(
            ["api", "subscriptionCatalog", "storeAccountBinding", "generationScheduler"],
            response.Checks.Select(check => check.Key));
        Assert.Equal(
            ["healthy", "degraded", "healthy", "unhealthy"],
            response.Checks.Select(check => check.Status));
        Assert.All(response.Checks, check => Assert.Equal(generatedAtUtc, check.CheckedAtUtc));

        var json = JsonSerializer.Serialize(response, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.DoesNotContain("provider-plan-secret", json, StringComparison.Ordinal);
        Assert.DoesNotContain("database-password", json, StringComparison.Ordinal);
        Assert.DoesNotContain("checksum-secret", json, StringComparison.Ordinal);
        Assert.DoesNotContain("economy_subscription_plans", json, StringComparison.Ordinal);

        var root = JsonSerializer.Deserialize<JsonElement>(json);
        Assert.True(root.EnumerateObject().Select(property => property.Name).ToHashSet(StringComparer.Ordinal).SetEquals(
            ["overallStatus", "generatedAtUtc", "staleAfterSeconds", "checks"]));
        Assert.All(root.GetProperty("checks").EnumerateArray(), check =>
            Assert.True(check.EnumerateObject().Select(property => property.Name).ToHashSet(StringComparer.Ordinal).SetEquals(
                ["key", "status", "summary", "checkedAtUtc"])));
    }

    [Fact]
    public void BuildResponse_ShouldTreatMissingCuratedRegistrationAsUnhealthy()
    {
        var report = CreateReport(new Dictionary<string, HealthReportEntry>(StringComparer.Ordinal)
        {
            ["self"] = CreateEntry(HealthStatus.Healthy, "ok"),
            ["economy_subscription_plans"] = CreateEntry(HealthStatus.Healthy, "ok"),
            ["store_account_binding"] = CreateEntry(HealthStatus.Healthy, "ok")
        });

        var response = AdminSystemStatusService.BuildResponse(report, DateTimeOffset.UtcNow);

        Assert.Equal("unhealthy", response.OverallStatus);
        var missing = Assert.Single(response.Checks, check => check.Key == "generationScheduler");
        Assert.Equal("unhealthy", missing.Status);
        Assert.Equal("Generation scheduler configuration check is not registered.", missing.Summary);
    }

    [Fact]
    public void Endpoint_ShouldBeAdminOnlyRateLimitedPrivateAndAlwaysReturnOk()
    {
        var repositoryRoot = FindRepositoryRoot();
        var endpoints = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Observability",
            "AdminSystemStatusEndpoints.cs"));
        var program = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Program.cs"));

        Assert.Contains("MapGet(\"/api/admin/system/status\", GetSystemStatusAsync)", endpoints, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"AdminOnly\")", endpoints, StringComparison.Ordinal);
        Assert.Contains(".RequireRateLimiting(\"admin\")", endpoints, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.CacheControl = \"no-store\";", endpoints, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.Pragma = \"no-cache\";", endpoints, StringComparison.Ordinal);
        Assert.Contains("Response.Headers.XContentTypeOptions = \"nosniff\";", endpoints, StringComparison.Ordinal);
        Assert.Contains("Task<Ok<AdminSystemStatusResponse>>", endpoints, StringComparison.Ordinal);
        Assert.Contains("TypedResults.Ok(await service.GetAsync(cancellationToken))", endpoints, StringComparison.Ordinal);
        Assert.Contains("builder.Services.AddScoped<IAdminSystemStatusService, AdminSystemStatusService>();", program, StringComparison.Ordinal);
        Assert.Contains("app.MapAdminSystemStatusEndpoints();", program, StringComparison.Ordinal);
        Assert.Contains("app.MapHealthChecks(\"/health\"", program, StringComparison.Ordinal);
    }

    [Fact]
    public void Service_ShouldRunOnlyCuratedCheapChecksWithinABoundedWindow()
    {
        var service = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Observability",
            "AdminSystemStatusService.cs"));

        Assert.Contains("TimeSpan.FromSeconds(3)", service, StringComparison.Ordinal);
        Assert.Contains("timeoutSource.CancelAfter(ExecutionTimeout);", service, StringComparison.Ordinal);
        Assert.Contains("CuratedRegistrationNames.Contains(registration.Name)", service, StringComparison.Ordinal);
        Assert.Contains("\"self\"", service, StringComparison.Ordinal);
        Assert.Contains("\"economy_subscription_plans\"", service, StringComparison.Ordinal);
        Assert.Contains("\"store_account_binding\"", service, StringComparison.Ordinal);
        Assert.Contains("\"templates_scheduler_config\"", service, StringComparison.Ordinal);
        Assert.DoesNotContain("\"templates_content\"", service, StringComparison.Ordinal);
        Assert.DoesNotContain("\"push_outbox\"", service, StringComparison.Ordinal);
        Assert.DoesNotContain("\"gamification_legacy_delivery\"", service, StringComparison.Ordinal);
        Assert.DoesNotContain("entry.Description", service, StringComparison.Ordinal);
        Assert.DoesNotContain("entry.Data", service, StringComparison.Ordinal);
        Assert.DoesNotContain("entry.Exception", service, StringComparison.Ordinal);
    }

    [Fact]
    public void OperationsResponse_ShouldAggregateBoundedSafeMetricsAndSurfaceRisk()
    {
        var now = new DateTime(2026, 7, 27, 12, 0, 0, DateTimeKind.Utc);
        var snapshot = new AdminOperationsSnapshot(
            EmailBacklogCount: 8,
            EmailDeadLetterCount: 1,
            OldestEmailQueuedAtUtc: now.AddMinutes(-3),
            LastEmailSentAtUtc: now.AddMinutes(-1),
            AuditBacklogCount: 2,
            AuditDeadLetterCount: 0,
            OldestAuditQueuedAtUtc: now.AddSeconds(-40),
            LastAuditSentAtUtc: now.AddSeconds(-10),
            PushBacklogCount: 0,
            PushDeadLetterCount: 0,
            OldestPushQueuedAtUtc: null,
            LastPushSentAtUtc: now.AddSeconds(-20),
            GenerationQueueDepth: 4,
            OldestGenerationQueuedAtUtc: now.AddMinutes(-6),
            LastGenerationCompletedAtUtc: now.AddMinutes(-2),
            OpenEconomyIncidentCount: 3,
            CriticalEconomyIncidentCount: 1,
            GenerationWorkerHeartbeatAtUtc: now.AddSeconds(-15),
            UnavailableSources: []);

        var response = AdminOperationsStatusService.BuildResponse(snapshot, now);

        Assert.Equal("unhealthy", response.OverallStatus);
        Assert.Equal("unhealthy", response.Email.Status);
        Assert.Equal("degraded", response.Generations.Status);
        Assert.Equal("unhealthy", response.Economy.Status);
        Assert.Equal(180, response.Email.OldestItemAgeSeconds);
        Assert.Equal(now.AddSeconds(-10), response.Workers.LastSuccessfulRunAtUtc);
        Assert.Empty(response.UnavailableSources);

        var json = JsonSerializer.Serialize(response, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.DoesNotContain("Exception", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Payload", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Secret", json, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void OperationsEndpoint_ShouldBeAdminOnlyPrivateCachedAndBounded()
    {
        var root = FindRepositoryRoot();
        var endpoints = File.ReadAllText(Path.Combine(
            root, "src", "Host", "PetMagic.Host.Api", "Observability", "AdminSystemStatusEndpoints.cs"));
        var service = File.ReadAllText(Path.Combine(
            root, "src", "Host", "PetMagic.Host.Api", "Observability", "AdminOperationsStatusService.cs"));
        var program = File.ReadAllText(Path.Combine(root, "src", "Host", "PetMagic.Host.Api", "Program.cs"));

        Assert.Contains("MapGet(\"/api/admin/system/operations\", GetOperationsStatusAsync)", endpoints, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"AdminOnly\")", endpoints, StringComparison.Ordinal);
        Assert.Contains(".RequireRateLimiting(\"admin\")", endpoints, StringComparison.Ordinal);
        Assert.Contains("CacheDurationSeconds = 15", service, StringComparison.Ordinal);
        Assert.Contains("TimeSpan.FromSeconds(3)", service, StringComparison.Ordinal);
        Assert.Contains(".Take(4)", service, StringComparison.Ordinal);
        Assert.DoesNotContain("PayloadJson", service, StringComparison.Ordinal);
        Assert.DoesNotContain("exception.Message", service, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("AddScoped<IAdminOperationsStatusService, AdminOperationsStatusService>()", program, StringComparison.Ordinal);
    }

    private static HealthReport CreateReport(Dictionary<string, HealthReportEntry> entries) =>
        new(entries, TimeSpan.FromMilliseconds(10));

    private static HealthReportEntry CreateEntry(
        HealthStatus status,
        string description,
        Exception? exception = null) =>
        new(
            status,
            description,
            TimeSpan.FromMilliseconds(2),
            exception,
            new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["secret"] = "must-not-leak"
            },
            []);

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
