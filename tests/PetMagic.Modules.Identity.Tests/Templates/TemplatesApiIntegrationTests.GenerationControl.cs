using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

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
    public async Task GenerationControlPolicy_ShouldRequireAdmin_ValidateConfirmation_AndPreserveConfirmedAt()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var initial = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");
        Assert.NotNull(initial);

        using var unauthenticatedRequest = CreateGenerationControlPolicyRequest(
            "policy-auth-unauthenticated",
            new GenerationControlPolicyRequestBody(
                1, "Pause admission safely", false, 10, 2, 38, false),
            unauthenticated: true);
        using var unauthenticated = await application.Client.SendAsync(unauthenticatedRequest);

        using var moderatorRequest = CreateGenerationControlPolicyRequest(
            "policy-auth-moderator",
            new GenerationControlPolicyRequestBody(
                1, "Pause admission safely", false, 10, 2, 38, false),
            role: "Moderator");
        using var moderator = await application.Client.SendAsync(moderatorRequest);

        using var adminRequest = CreateGenerationControlPolicyRequest(
            "policy-auth-admin",
            new GenerationControlPolicyRequestBody(
                1, "Pause admission safely", false, 10, 2, 38, false));
        using var admin = await application.Client.SendAsync(adminRequest);
        var paused = await admin.Content.ReadFromJsonAsync<AdminTemplateGenerationControlResponse>();

        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, moderator.StatusCode);
        Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
        Assert.NotNull(paused);
        Assert.False(paused.AdmissionEnabled);
        Assert.Equal(initial.ConfirmedAtUtc, paused.ConfirmedAtUtc);
        Assert.Contains(
            "no-store",
            admin.Headers.CacheControl?.ToString() ?? string.Empty,
            StringComparison.Ordinal);
        Assert.Contains(admin.Headers.Pragma, value => value.Name == "no-cache");

        using var missingConfirmationRequest = CreateGenerationControlPolicyRequest(
            "policy-limit-unconfirmed-api",
            new GenerationControlPolicyRequestBody(
                2, "Raise confirmed provider limit", false, 40, 2, 38, false));
        using var missingConfirmation = await application.Client.SendAsync(missingConfirmationRequest);
        Assert.Equal(HttpStatusCode.BadRequest, missingConfirmation.StatusCode);
        Assert.Contains(
            TemplatesErrors.GenerationControlConcurrencyConfirmationRequired.Code,
            await missingConfirmation.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);

        await Task.Delay(5);
        using var confirmedRequest = CreateGenerationControlPolicyRequest(
            "policy-limit-confirmed-api",
            new GenerationControlPolicyRequestBody(
                2, "Confirmed in the fal.ai Dashboard", false, 40, 2, 38, true));
        using var confirmed = await application.Client.SendAsync(confirmedRequest);
        var confirmedPayload = await confirmed.Content
            .ReadFromJsonAsync<AdminTemplateGenerationControlResponse>();
        Assert.Equal(HttpStatusCode.OK, confirmed.StatusCode);
        Assert.NotNull(confirmedPayload);
        Assert.Equal(40, confirmedPayload.ConfirmedFalConcurrencyLimit);
        Assert.True(confirmedPayload.ConfirmedAtUtc > initial.ConfirmedAtUtc);

        using var invalidReasonRequest = CreateGenerationControlPolicyRequest(
            "policy-invalid-reason-api",
            new GenerationControlPolicyRequestBody(3, "x", false, 40, 2, 38, false));
        using var invalidReason = await application.Client.SendAsync(invalidReasonRequest);
        Assert.Equal(HttpStatusCode.BadRequest, invalidReason.StatusCode);

        using var staleRequest = CreateGenerationControlPolicyRequest(
            "policy-stale-api",
            new GenerationControlPolicyRequestBody(
                2, "Stale policy update", false, 40, 2, 38, false));
        using var stale = await application.Client.SendAsync(staleRequest);
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
    }

    [Fact]
    public async Task GenerationControlProviderRefresh_ShouldRequireAdmin_AndReturnExplicitOutcome()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        using var unauthenticatedRequest = new HttpRequestMessage(
            HttpMethod.Post,
            "/api/admin/templates/generation-control/provider/refresh");
        unauthenticatedRequest.Headers.Add("X-Test-Unauthenticated", "true");
        using var unauthenticated = await application.Client.SendAsync(unauthenticatedRequest);

        using var moderatorRequest = new HttpRequestMessage(
            HttpMethod.Post,
            "/api/admin/templates/generation-control/provider/refresh");
        moderatorRequest.Headers.Add("X-Test-Role", "Moderator");
        using var moderator = await application.Client.SendAsync(moderatorRequest);

        using var admin = await application.Client.PostAsync(
            "/api/admin/templates/generation-control/provider/refresh",
            content: null);
        var payload = await admin.Content
            .ReadFromJsonAsync<AdminTemplateGenerationProviderRefreshResponse>();

        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, moderator.StatusCode);
        Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("refreshed", payload.Outcome);
        Assert.Null(payload.ErrorCode);
        Assert.NotNull(payload.CheckedAtUtc);
        Assert.NotNull(payload.LastSuccessfulAtUtc);
        Assert.Equal(1, payload.Control.Revision);
        Assert.Contains(
            "no-store",
            admin.Headers.CacheControl?.ToString() ?? string.Empty,
            StringComparison.Ordinal);
        Assert.Contains(admin.Headers.Pragma, value => value.Name == "no-cache");
    }

    [Fact]
    public async Task GenerationControlProviderRefresh_ShouldReturnSafeFailureOutcome()
    {
        var checkedAtUtc = DateTime.UtcNow;
        var snapshot = new TemplateProviderRuntimeSnapshot
        {
            Id = TemplateGenerationControlPolicyDefaults.FalSnapshotId,
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Unknown,
            StatusChangedAtUtc = checkedAtUtc,
            CheckedAtUtc = checkedAtUtc,
            LastErrorCode = "http_429",
            UpdatedAtUtc = checkedAtUtc
        };
        await using var application = await TestApplication.CreateAsync(
            startGenerationWorker: false,
            falProviderRuntimeSnapshotService: new FailedFalProviderRuntimeSnapshotService(snapshot));

        using var response = await application.Client.PostAsync(
            "/api/admin/templates/generation-control/provider/refresh",
            content: null);
        var payload = await response.Content
            .ReadFromJsonAsync<AdminTemplateGenerationProviderRefreshResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal("failed", payload.Outcome);
        Assert.Equal(checkedAtUtc, payload.CheckedAtUtc);
        Assert.Null(payload.LastSuccessfulAtUtc);
        Assert.Equal("http_429", payload.ErrorCode);
        Assert.DoesNotContain("fal-runtime-test-key", await response.Content.ReadAsStringAsync(), StringComparison.Ordinal);
    }

    [Fact]
    public async Task ProviderAttemptRecovery_ShouldRequireAdmin_ValidatePaging_AndReturnOnlySafeManualRows()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        var manualOldest = CreateProviderAttemptRecoveryRow(
            now.AddMinutes(-10),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: null,
            providerRequestId: null,
            ordinal: 1);
        manualOldest.SubmissionTokenHash = new string('F', 64);
        manualOldest.ProviderResponseUrl = "https://provider.invalid/response?api_key=never-return-this";
        manualOldest.LastErrorCode = "templates.provider_submission_reconciliation_required";
        var manualNewest = CreateProviderAttemptRecoveryRow(
            now.AddMinutes(-5),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: null,
            providerRequestId: "fal_request_2",
            ordinal: 2);
        var scheduled = CreateProviderAttemptRecoveryRow(
            now.AddMinutes(-20),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: now.AddSeconds(30),
            providerRequestId: null,
            ordinal: 3);
        var queued = CreateProviderAttemptRecoveryRow(
            now.AddMinutes(-30),
            TemplateGenerationProviderAttemptState.ProviderQueued,
            nextPollAtUtc: null,
            providerRequestId: "fal_request_queued",
            ordinal: 4);
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateGenerationProviderAttempts.AddRange(
                manualOldest,
                manualNewest,
                scheduled,
                queued);
            await dbContext.SaveChangesAsync();
        }

        using var unauthenticatedRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/admin/templates/generation-control/provider-attempts/recovery?skip=0&take=1");
        unauthenticatedRequest.Headers.Add("X-Test-Unauthenticated", "true");
        using var unauthenticated = await application.Client.SendAsync(unauthenticatedRequest);

        using var moderatorRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/admin/templates/generation-control/provider-attempts/recovery?skip=0&take=1");
        moderatorRequest.Headers.Add("X-Test-Role", "Moderator");
        using var moderator = await application.Client.SendAsync(moderatorRequest);

        using var admin = await application.Client.GetAsync(
            "/api/admin/templates/generation-control/provider-attempts/recovery?skip=0&take=1");
        var body = await admin.Content.ReadAsStringAsync();
        var payload = JsonSerializer.Deserialize<AdminTemplateProviderAttemptRecoveryPageResponse>(
            body,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));
        using var invalid = await application.Client.GetAsync(
            "/api/admin/templates/generation-control/provider-attempts/recovery?take=101");

        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, moderator.StatusCode);
        Assert.Equal(HttpStatusCode.OK, admin.StatusCode);
        Assert.NotNull(payload);
        Assert.Equal(2, payload.TotalCount);
        Assert.True(payload.HasMore);
        var item = Assert.Single(payload.Items);
        Assert.Equal(manualOldest.Id, item.AttemptId);
        Assert.Equal(manualOldest.GenerationJobId, item.GenerationId);
        Assert.Equal(manualOldest.Version, item.AttemptVersion);
        Assert.Equal("submission_unknown", item.State);
        Assert.Equal("correlated_accepted_or_confirmed_not_found", item.EvidenceNeeded);
        Assert.DoesNotContain(manualOldest.SubmissionTokenHash, body, StringComparison.Ordinal);
        Assert.DoesNotContain("never-return-this", body, StringComparison.Ordinal);
        Assert.DoesNotContain("providerResponseUrl", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(
            "no-store",
            admin.Headers.CacheControl?.ToString() ?? string.Empty,
            StringComparison.Ordinal);
        Assert.Contains(admin.Headers.Pragma, value => value.Name == "no-cache");
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Contains(
            TemplatesErrors.ProviderAttemptRecoveryQueryInvalid.Code,
            await invalid.Content.ReadAsStringAsync(),
            StringComparison.Ordinal);
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
    public async Task GenerationControl_ShouldAlertWithStableTransition_WhenMoreThanOneWorkerIsActive()
    {
        await using var application = await TestApplication.CreateAsync(startGenerationWorker: false);
        var now = DateTime.UtcNow;
        var firstWorker = CreateWorkerFingerprint(now.AddSeconds(-5), true, 4, 4, 1, 1);
        var secondWorker = CreateWorkerFingerprint(now, true, 4, 4, 1, 1);
        await using (var scope = application.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRuntimeConfigFingerprints.AddRange(firstWorker, secondWorker);
            await dbContext.SaveChangesAsync();
        }

        var first = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");
        var second = await application.Client.GetFromJsonAsync<AdminTemplateGenerationControlResponse>(
            "/api/admin/templates/generation-control");

        Assert.NotNull(first);
        Assert.NotNull(second);
        Assert.Equal(2, first.Worker.InstanceCount);
        var firstAlert = Assert.Single(
            first.Alerts,
            alert => alert.AlertId == "generation-worker-instance-count-unexpected");
        var secondAlert = Assert.Single(
            second.Alerts,
            alert => alert.AlertId == "generation-worker-instance-count-unexpected");
        Assert.Equal("critical", firstAlert.Severity);
        Assert.Equal(secondWorker.StartedAtUtc, firstAlert.StatusChangedAtUtc);
        Assert.Equal(firstAlert.StatusChangedAtUtc, secondAlert.StatusChangedAtUtc);
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

    private static TemplateGenerationProviderAttempt CreateProviderAttemptRecoveryRow(
        DateTime createdAtUtc,
        TemplateGenerationProviderAttemptState state,
        DateTime? nextPollAtUtc,
        string? providerRequestId,
        int ordinal) => new()
        {
            Id = Guid.NewGuid(),
            GenerationJobId = Guid.NewGuid(),
            Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
            Ordinal = ordinal,
            State = state,
            Provider = "fal",
            SubmissionTokenHash = ordinal.ToString("X64"),
            ProviderRequestId = providerRequestId,
            NextPollAtUtc = nextPollAtUtc,
            SubmissionDeadlineAtUtc = createdAtUtc.AddMinutes(3),
            ProcessingDeadlineAtUtc = createdAtUtc.AddMinutes(30),
            ReconciliationDeadlineAtUtc = createdAtUtc.AddMinutes(40),
            Version = ordinal,
            CreatedAtUtc = createdAtUtc,
            UpdatedAtUtc = createdAtUtc.AddMinutes(1)
        };

    private static HttpRequestMessage CreateGenerationControlPolicyRequest(
        string idempotencyKey,
        GenerationControlPolicyRequestBody body,
        string? role = null,
        bool unauthenticated = false)
    {
        var request = new HttpRequestMessage(
            HttpMethod.Put,
            "/api/admin/templates/generation-control/policy")
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

    private sealed record GenerationControlPolicyRequestBody(
        long ExpectedRevision,
        string Reason,
        bool AdmissionEnabled,
        int ConfirmedFalConcurrencyLimit,
        int ReservedHeadroom,
        int ApplicationHardCeiling,
        bool ConfirmFalConcurrencyLimit);

    private sealed class FailedFalProviderRuntimeSnapshotService(
        TemplateProviderRuntimeSnapshot snapshot) : IFalProviderRuntimeSnapshotService
    {
        public Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken) =>
            Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeRefreshResult> RefreshWithOutcomeAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(new TemplateProviderRuntimeRefreshResult(
                snapshot,
                TemplateProviderRuntimeRefreshOutcome.Failed,
                "http_429"));
    }

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
