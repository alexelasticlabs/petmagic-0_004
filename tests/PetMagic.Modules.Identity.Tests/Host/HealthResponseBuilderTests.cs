using System.Security.Claims;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.Host.Api.Observability;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class HealthResponseBuilderTests
{
    [Fact]
    public void Build_ShouldRedactSensitiveDiagnostics_ForAnonymousHealthRequests()
    {
        var services = new ServiceCollection()
            .AddSingleton(CreateRuntimeState(
                initialized: true,
                component: "api",
                profileName: "staging",
                checksum: "checksum-123",
                isMismatchDetected: true,
                mismatchDetails: "current=api:checksum-123; other=worker:checksum-999"))
            .BuildServiceProvider();
        var context = new DefaultHttpContext
        {
            RequestServices = services
        };

        var report = new HealthReport(
            new Dictionary<string, HealthReportEntry>(StringComparer.Ordinal)
            {
                ["templates_content"] = new HealthReportEntry(
                    HealthStatus.Unhealthy,
                    "broken preview",
                    TimeSpan.FromMilliseconds(12),
                    null,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["checkedTemplates"] = 17,
                        ["problemCount"] = 2,
                        ["problems"] = new[] { "template-id:Template Title:missing_preview" },
                        ["truncated"] = false
                    },
                    []),
                ["templates_scheduler_config"] = new HealthReportEntry(
                    HealthStatus.Unhealthy,
                    "config mismatch",
                    TimeSpan.FromMilliseconds(4),
                    null,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["initialized"] = true,
                        ["component"] = "api",
                        ["profileName"] = "staging",
                        ["checksum"] = "checksum-123",
                        ["mismatchDetails"] = "current=api:checksum-123; other=worker:checksum-999"
                    },
                    [])
            },
            TimeSpan.FromMilliseconds(16));

        var payload = HealthResponseBuilder.Build(
            context,
            report,
            new { version = "test-build" });

        var scheduler = Assert.IsType<PublicSchedulerConfigPayload>(payload.SchedulerConfig);
        Assert.True(scheduler.Initialized);
        Assert.True(scheduler.IsMismatchDetected);

        var contentCheck = Assert.Single(payload.Checks, x => x.Name == "templates_content");
        Assert.NotNull(contentCheck.Data);
        Assert.Equal(17, Assert.IsType<int>(contentCheck.Data["checkedTemplates"]));
        Assert.Equal(2, Assert.IsType<int>(contentCheck.Data["problemCount"]));
        Assert.False(Assert.IsType<bool>(contentCheck.Data["truncated"]));
        Assert.DoesNotContain("problems", contentCheck.Data.Keys, StringComparer.Ordinal);

        var schedulerCheck = Assert.Single(payload.Checks, x => x.Name == "templates_scheduler_config");
        Assert.NotNull(schedulerCheck.Data);
        Assert.True(Assert.IsType<bool>(schedulerCheck.Data["initialized"]));
        Assert.DoesNotContain("checksum", schedulerCheck.Data.Keys, StringComparer.Ordinal);
        Assert.DoesNotContain("component", schedulerCheck.Data.Keys, StringComparer.Ordinal);
        Assert.DoesNotContain("profileName", schedulerCheck.Data.Keys, StringComparer.Ordinal);
        Assert.DoesNotContain("mismatchDetails", schedulerCheck.Data.Keys, StringComparer.Ordinal);
    }

    [Fact]
    public void Build_ShouldKeepDetailedDiagnostics_ForAdminHealthRequests()
    {
        var services = new ServiceCollection()
            .AddSingleton(CreateRuntimeState(
                initialized: true,
                component: "api",
                profileName: "staging",
                checksum: "checksum-123",
                isMismatchDetected: false,
                mismatchDetails: null))
            .BuildServiceProvider();
        var context = new DefaultHttpContext
        {
            RequestServices = services,
            User = new ClaimsPrincipal(
                new ClaimsIdentity(
                    [
                        new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString("D")),
                        new Claim(ClaimTypes.Role, "Admin")
                    ],
                    "Test"))
        };

        var report = new HealthReport(
            new Dictionary<string, HealthReportEntry>(StringComparer.Ordinal)
            {
                ["templates_content"] = new HealthReportEntry(
                    HealthStatus.Unhealthy,
                    "broken preview",
                    TimeSpan.FromMilliseconds(12),
                    null,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["checkedTemplates"] = 17,
                        ["problemCount"] = 2,
                        ["problems"] = new[] { "template-id:Template Title:missing_preview" },
                        ["truncated"] = false
                    },
                    [])
            },
            TimeSpan.FromMilliseconds(12));

        var payload = HealthResponseBuilder.Build(
            context,
            report,
            new { version = "test-build" });

        var scheduler = Assert.IsType<DetailedSchedulerConfigPayload>(payload.SchedulerConfig);
        Assert.Equal("api", scheduler.Component);
        Assert.Equal("staging", scheduler.ProfileName);
        Assert.Equal("checksum-123", scheduler.Checksum);

        var contentCheck = Assert.Single(payload.Checks);
        Assert.NotNull(contentCheck.Data);
        Assert.Contains("problems", contentCheck.Data.Keys, StringComparer.Ordinal);
    }

    private static TemplateSchedulerConfigRuntimeState CreateRuntimeState(
        bool initialized,
        string component,
        string profileName,
        string checksum,
        bool isMismatchDetected,
        string? mismatchDetails)
    {
        var state = new TemplateSchedulerConfigRuntimeState();
        if (!initialized)
        {
            return state;
        }

        if (isMismatchDetected)
        {
            state.MarkMismatch(component, profileName, checksum, mismatchDetails ?? string.Empty);
            return state;
        }

        state.MarkHealthy(component, profileName, checksum);
        return state;
    }
}
