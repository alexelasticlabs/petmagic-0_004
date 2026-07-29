using System.Net;
using System.Net.Http.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task GenerationControl_ShouldRequireAdminAndReturnCapacityForAdmin()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        using var unauthenticatedRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/admin/templates/generation-control");
        unauthenticatedRequest.Headers.Add("X-Test-Unauthenticated", "true");
        using var unauthenticated = await application.Client.SendAsync(unauthenticatedRequest);

        using var moderatorRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/admin/templates/generation-control");
        moderatorRequest.Headers.Add("X-Test-Role", "Moderator");
        using var moderator = await application.Client.SendAsync(moderatorRequest);

        using var adminRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/admin/templates/generation-control");
        adminRequest.Headers.Add("X-Test-Role", "Admin");
        using var admin = await application.Client.SendAsync(adminRequest);
        var payload = await admin.Content.ReadFromJsonAsync<AdminTemplateGenerationControlResponse>();

        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, moderator.StatusCode);
        Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal(1, payload.Revision);
        Assert.Equal(8, payload.EffectiveGlobalLimit);
        Assert.Equal(0, payload.Worker.InstanceCount);
        Assert.Null(payload.Worker.HeartbeatAtUtc);
        Assert.Null(payload.Worker.SchedulerV2Enabled);
        Assert.Null(payload.Worker.DispatchConcurrency);
        Assert.Null(payload.Worker.ReconciliationConcurrency);
        Assert.Null(payload.Worker.MediaImportConcurrency);
        Assert.Null(payload.Worker.MaintenanceConcurrency);
    }

    [Fact]
    public async Task GenerationControl_ShouldUseActiveWorkerHeartbeatRuntimeConfiguration()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.Add(CreateWorkerFingerprint(
                now,
                schedulerV2Enabled: true,
                dispatchConcurrency: 8,
                reconciliationConcurrency: 7,
                mediaImportConcurrency: 2,
                maintenanceConcurrency: 3));
            await dbContext.SaveChangesAsync();
        }

        var payload = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(payload);
        Assert.Equal(1, payload.Worker.InstanceCount);
        Assert.Equal(now, payload.Worker.HeartbeatAtUtc);
        Assert.True(payload.Worker.SchedulerV2Enabled);
        Assert.Equal(8, payload.Worker.DispatchConcurrency);
        Assert.Equal(7, payload.Worker.ReconciliationConcurrency);
        Assert.Equal(2, payload.Worker.MediaImportConcurrency);
        Assert.Equal(3, payload.Worker.MaintenanceConcurrency);
    }

    [Fact]
    public async Task GenerationControl_ShouldReturnUnknownRuntime_WhenRollingWorkersDisagree()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.AddRange(
                CreateWorkerFingerprint(now.AddSeconds(-1), false, 4, 4, 1, 1),
                CreateWorkerFingerprint(now, true, 8, 7, 2, 3));
            await dbContext.SaveChangesAsync();
        }

        var payload = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(payload);
        Assert.Equal(2, payload.Worker.InstanceCount);
        Assert.Equal(now, payload.Worker.HeartbeatAtUtc);
        Assert.Null(payload.Worker.SchedulerV2Enabled);
        Assert.Null(payload.Worker.DispatchConcurrency);
        Assert.Null(payload.Worker.ReconciliationConcurrency);
        Assert.Null(payload.Worker.MediaImportConcurrency);
        Assert.Null(payload.Worker.MaintenanceConcurrency);
        Assert.Contains(
            payload.Alerts,
            alert => alert.AlertId == "generation-worker-runtime-config-unknown"
                && alert.Severity == "critical");
    }

    [Fact]
    public async Task GenerationControl_ShouldAlert_WhenRollingWorkersDisagreeOnlyOnLaneConfiguration()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.AddRange(
                CreateWorkerFingerprint(now.AddSeconds(-1), true, 4, 4, 1, 1),
                CreateWorkerFingerprint(now, true, 8, 4, 1, 1));
            await dbContext.SaveChangesAsync();
        }

        var payload = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(payload);
        Assert.True(payload.Worker.SchedulerV2Enabled);
        Assert.Null(payload.Worker.DispatchConcurrency);
        Assert.Equal(4, payload.Worker.ReconciliationConcurrency);
        Assert.Equal(1, payload.Worker.MediaImportConcurrency);
        Assert.Equal(1, payload.Worker.MaintenanceConcurrency);
        Assert.Contains(
            payload.Alerts,
            alert => alert.AlertId == "generation-worker-runtime-config-unknown"
                && alert.Severity == "critical");
    }

    [Fact]
    public async Task GenerationControl_ShouldAlert_WhenWorkerAppliedPolicyRevisionIsStale()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var policy = TemplateGenerationControlPolicyDefaults.Create(now);
            policy.Revision = 2;
            policy.UpdatedAtUtc = now;
            dbContext.TemplateGenerationControlPolicies.Add(policy);
            dbContext.TemplateRuntimeConfigFingerprints.Add(
                CreateWorkerFingerprint(now, true, 4, 4, 1, 1));
            await dbContext.SaveChangesAsync();
        }

        var payload = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(payload);
        Assert.Equal(2, payload.Revision);
        Assert.Equal(1, payload.Worker.AppliedPolicyRevision);
        Assert.Contains(
            payload.Alerts,
            alert => alert.AlertId == "generation-worker-policy-revision-stale"
                && alert.Severity == "critical"
                && alert.StatusChangedAtUtc == now);
    }

    [Fact]
    public async Task ProviderAttemptResolution_ShouldRequireAdmin_CorrelateCanonicalRequest_AndReplayIdempotently()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var seeded = await SeedSubmissionUnknownAttemptAsync(application.Services, charged: false);
        var requestBody = CreateCorrelatedAcceptedResolutionRequest(seeded.Version, "fal-dashboard:case-accepted-1");

        using var unauthenticatedRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-accepted-auth",
            requestBody,
            unauthenticated: true);
        using var unauthenticated = await application.Client.SendAsync(unauthenticatedRequest);

        using var moderatorRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-accepted-auth",
            requestBody,
            role: "Moderator");
        using var moderator = await application.Client.SendAsync(moderatorRequest);

        using var adminRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-accepted-1",
            requestBody);
        using var admin = await application.Client.SendAsync(adminRequest);
        var firstResponse = await admin.Content.ReadFromJsonAsync<AdminTemplateProviderAttemptResolutionResponse>();

        using var replayRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-accepted-1",
            requestBody);
        using var replay = await application.Client.SendAsync(replayRequest);
        var replayResponse = await replay.Content.ReadFromJsonAsync<AdminTemplateProviderAttemptResolutionResponse>();

        using var conflictingReplayRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-accepted-1",
            CreateCorrelatedAcceptedResolutionRequest(seeded.Version, "fal-dashboard:different-case"));
        using var conflictingReplay = await application.Client.SendAsync(conflictingReplayRequest);

        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, moderator.StatusCode);
        Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, conflictingReplay.StatusCode);
        Assert.NotNull(firstResponse);
        Assert.Equal(firstResponse, replayResponse);
        Assert.Equal("correlated_accepted", firstResponse.Resolution);
        Assert.Equal(nameof(TemplateGenerationProviderAttemptState.ProviderQueued), firstResponse.AttemptState);
        Assert.False(firstResponse.RefundScheduled);

        await using var scope = application.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var attempt = await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == seeded.AttemptId);
        var job = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == seeded.GenerationId);
        Assert.Equal(TemplateGenerationProviderAttemptState.ProviderQueued, attempt.State);
        Assert.Equal("request_accepted_1", attempt.ProviderRequestId);
        Assert.Equal("https://queue.fal.run/fal-ai/nano-banana-pro/edit/requests/request_accepted_1/status", attempt.ProviderStatusUrl);
        Assert.Equal(TemplateGenerationStatus.ProviderQueued, job.Status);
        Assert.Equal(attempt.ProviderRequestId, job.PreprocessingProviderRequestId);
        Assert.Single(dbContext.TemplateGenerationControlPolicyCommandReceipts);
        Assert.Single(dbContext.PushOutboxMessages);
    }

    [Fact]
    public async Task ProviderAttemptResolution_ShouldRejectStaleVersion_AndNonCanonicalProviderUrls()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var seeded = await SeedSubmissionUnknownAttemptAsync(application.Services, charged: false);

        using var staleRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-stale-version",
            CreateCorrelatedAcceptedResolutionRequest(seeded.Version + 1, "fal-dashboard:stale-version"));
        using var stale = await application.Client.SendAsync(staleRequest);

        var invalidCorrelation = CreateCorrelatedAcceptedResolutionRequest(
            seeded.Version,
            "fal-dashboard:invalid-host") with
        {
            ProviderStatusUrl = "https://example.invalid/fal-ai/nano-banana-pro/edit/requests/request_accepted_1/status"
        };
        using var invalidHostRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-invalid-host",
            invalidCorrelation);
        using var invalidHost = await application.Client.SendAsync(invalidHostRequest);

        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, invalidHost.StatusCode);
        await using var scope = application.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var attempt = await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == seeded.AttemptId);
        Assert.Equal(TemplateGenerationProviderAttemptState.SubmissionUnknown, attempt.State);
        Assert.Empty(dbContext.TemplateGenerationControlPolicyCommandReceipts);
    }

    [Fact]
    public async Task ProviderAttemptResolution_ConfirmedNotFound_ShouldCancelAndRefundExactlyOnce()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var seeded = await SeedSubmissionUnknownAttemptAsync(application.Services, charged: true);
        var requestBody = new ProviderAttemptResolutionRequestBody(
            seeded.Version,
            "confirmed_not_found",
            "fal.ai support confirmed that the ambiguous submission was not accepted.",
            "fal-support:ticket-404",
            null,
            null,
            null,
            null);

        using var request = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-not-found-1",
            requestBody);
        using var response = await application.Client.SendAsync(request);
        var payload = await response.Content.ReadFromJsonAsync<AdminTemplateProviderAttemptResolutionResponse>();

        using var replayRequest = CreateProviderAttemptResolutionRequest(
            seeded.AttemptId,
            "resolve-not-found-1",
            requestBody);
        using var replay = await application.Client.SendAsync(replayRequest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("confirmed_not_found", payload.Resolution);
        Assert.Equal(nameof(TemplateGenerationProviderAttemptState.Cancelled), payload.AttemptState);
        Assert.True(payload.RefundScheduled);
        Assert.Equal(1, application.Billing.RefundedGenerationIds.Count(id => id == seeded.GenerationId));

        await using var scope = application.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var attempt = await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == seeded.AttemptId);
        var job = await dbContext.TemplateGenerationJobs.SingleAsync(x => x.Id == seeded.GenerationId);
        Assert.Equal(TemplateGenerationProviderAttemptState.Cancelled, attempt.State);
        Assert.Null(attempt.NextPollAtUtc);
        Assert.Equal(TemplateGenerationStatus.Cancelled, job.Status);
        Assert.Equal("SUBMISSION_CONFIRMED_NOT_FOUND", job.ProviderStatus);
        Assert.NotNull(job.RefundedAtUtc);
        Assert.Equal(1, job.RefundAttemptCount);

        var control = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");
        Assert.NotNull(control);
        Assert.Equal(0, control.Lanes.SubmissionUnknownCount);
        Assert.DoesNotContain(control.Alerts, alert => alert.AlertId == "generation-provider-submission-unknown");
    }

    [Fact]
    public async Task GenerationControl_ShouldExposeSubmissionUnknownCountAndStableCriticalAlert()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var seeded = await SeedSubmissionUnknownAttemptAsync(application.Services, charged: false);

        var first = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");
        var second = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(first);
        Assert.NotNull(second);
        Assert.Equal(1, first.Lanes.SubmissionUnknownCount);
        var firstAlert = Assert.Single(
            first.Alerts,
            alert => alert.AlertId == "generation-provider-submission-unknown");
        var secondAlert = Assert.Single(
            second.Alerts,
            alert => alert.AlertId == "generation-provider-submission-unknown");
        Assert.Equal("critical", firstAlert.Severity);
        Assert.Equal(seeded.CreatedAtUtc, firstAlert.StatusChangedAtUtc);
        Assert.Equal(firstAlert.StatusChangedAtUtc, secondAlert.StatusChangedAtUtc);
    }

    private static TemplateRuntimeConfigFingerprint CreateWorkerFingerprint(
        DateTime heartbeatAtUtc,
        bool schedulerV2Enabled,
        int dispatchConcurrency,
        int reconciliationConcurrency,
        int mediaImportConcurrency,
        int maintenanceConcurrency) => new()
        {
            Id = Guid.NewGuid(),
            Component = TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
            ProfileName = "Production",
            Checksum = Guid.NewGuid().ToString("N"),
            ConfigJson = "{}",
            StartedAtUtc = heartbeatAtUtc.AddMinutes(-1),
            LastSeenAtUtc = heartbeatAtUtc,
            MismatchDetected = false,
            AppliedPolicyRevision = 1,
            GenerationSchedulerV2Enabled = schedulerV2Enabled,
            GenerationDispatchConcurrency = dispatchConcurrency,
            ProviderReconciliationConcurrency = reconciliationConcurrency,
            MediaImportConcurrency = mediaImportConcurrency,
            GenerationMaintenanceConcurrency = maintenanceConcurrency
        };

    private static async Task<SeededSubmissionUnknownAttempt> SeedSubmissionUnknownAttemptAsync(
        IServiceProvider services,
        bool charged)
    {
        var now = DateTime.UtcNow.AddMinutes(-2);
        var generationId = Guid.NewGuid();
        var attemptId = Guid.NewGuid();
        await using var scope = services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = TestUserId,
            TemplateId = Guid.NewGuid(),
            Status = TemplateGenerationStatus.SubmittingToProvider,
            TokenCost = 5,
            QueueMediaType = TemplateGenerationQueue.MediaTypeImage,
            QueueTier = TemplateGenerationQueue.TierFree,
            SourceImageUrl = "https://cdn.example.test/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            UsedPreprocessingModel = "fal-ai/nano-banana-pro/edit",
            CurrentProviderStage = "image_generation",
            ProviderStatus = "RECONCILIATION_REQUIRED",
            ProviderSubmittedAtUtc = now,
            ProviderStatusCheckedAtUtc = now,
            ChargedAtUtc = charged ? now.AddMinutes(-1) : null,
            CreatedAtUtc = now,
            QueuedAtUtc = now,
            UpdatedAtUtc = now
        });
        dbContext.TemplateGenerationProviderAttempts.Add(new TemplateGenerationProviderAttempt
        {
            Id = attemptId,
            GenerationJobId = generationId,
            Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
            Ordinal = 1,
            State = TemplateGenerationProviderAttemptState.SubmissionUnknown,
            Provider = "fal",
            SubmissionTokenHash = new string('A', 64),
            NextPollAtUtc = now,
            SubmissionDeadlineAtUtc = now.AddSeconds(30),
            ProcessingDeadlineAtUtc = now.AddMinutes(30),
            ReconciliationDeadlineAtUtc = now.AddMinutes(60),
            SubmitAttemptCount = 1,
            LastErrorCode = "templates.provider_submission_reconciliation_required",
            Version = 4,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();
        return new SeededSubmissionUnknownAttempt(attemptId, generationId, 4, now);
    }

    private static HttpRequestMessage CreateProviderAttemptResolutionRequest(
        Guid attemptId,
        string idempotencyKey,
        ProviderAttemptResolutionRequestBody body,
        string? role = null,
        bool unauthenticated = false)
    {
        var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"/api/admin/templates/generation-control/provider-attempts/{attemptId:D}/resolve")
        {
            Content = JsonContent.Create(body)
        };
        request.Headers.Add("Idempotency-Key", idempotencyKey);
        if (role is not null)
        {
            request.Headers.Add("X-Test-Role", role);
        }

        if (unauthenticated)
        {
            request.Headers.Add("X-Test-Unauthenticated", "true");
        }

        return request;
    }

    private static ProviderAttemptResolutionRequestBody CreateCorrelatedAcceptedResolutionRequest(
        long expectedAttemptVersion,
        string evidenceReference)
    {
        const string requestId = "request_accepted_1";
        const string requestBase = "https://queue.fal.run/fal-ai/nano-banana-pro/edit/requests/" + requestId;
        return new ProviderAttemptResolutionRequestBody(
            expectedAttemptVersion,
            "correlated_accepted",
            "Correlated the ambiguous submission with the provider dashboard request.",
            evidenceReference,
            requestId,
            requestBase + "/status",
            requestBase + "/response",
            requestBase + "/cancel");
    }

    private sealed record SeededSubmissionUnknownAttempt(
        Guid AttemptId,
        Guid GenerationId,
        long Version,
        DateTime CreatedAtUtc);

    private sealed record ProviderAttemptResolutionRequestBody(
        long ExpectedAttemptVersion,
        string Resolution,
        string Reason,
        string EvidenceReference,
        string? ProviderRequestId,
        string? ProviderStatusUrl,
        string? ProviderResponseUrl,
        string? ProviderCancelUrl);
}
