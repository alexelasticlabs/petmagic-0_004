using System.Data.Common;
using System.Net;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Logging.Abstractions;

using Npgsql;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed class FalProviderRuntimeSnapshotPostgresConcurrencyTests
{
    private const string FoundationMigration = "20260728231704_AddGenerationControlFoundation";

    [Fact]
    public async Task ExpiredLeaseOwner_ShouldNotOverwriteNewRefreshOwnerCompletion()
    {
        var baseConnectionString = ResolvePostgresConnectionString();
        if (baseConnectionString is null)
        {
            return;
        }

        var schema = $"fal_snapshot_lease_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            var connectionString = ScopeConnectionString(baseConnectionString, schema);
            await using (var migrationContext = CreateContext(connectionString))
            {
                await migrationContext.GetService<IMigrator>().MigrateAsync(FoundationMigration);
            }

            var firstHandler = new BlockingBalanceHandler(11m);
            await using var firstContext = CreateContext(connectionString);
            var firstRefresh = CreateService(firstContext, firstHandler)
                .RefreshWithOutcomeAsync(force: true, CancellationToken.None);
            await firstHandler.WaitUntilStartedAsync();

            await using (var leaseExpiryContext = CreateContext(connectionString))
            {
                await leaseExpiryContext.TemplateProviderRuntimeSnapshots.ExecuteUpdateAsync(setters => setters
                    .SetProperty(snapshot => snapshot.RefreshLeaseExpiresAtUtc, DateTime.UtcNow.AddSeconds(-1)));
            }

            var secondHandler = new BlockingBalanceHandler(22m);
            await using var secondContext = CreateContext(connectionString);
            var secondRefresh = CreateService(secondContext, secondHandler)
                .RefreshWithOutcomeAsync(force: true, CancellationToken.None);
            await secondHandler.WaitUntilStartedAsync();

            firstHandler.Release();
            var firstResult = await firstRefresh;
            Assert.Equal(TemplateProviderRuntimeRefreshOutcome.Coalesced, firstResult.Outcome);

            await using (var overlapVerificationContext = CreateContext(connectionString))
            {
                var overlappingSnapshot = await overlapVerificationContext.TemplateProviderRuntimeSnapshots
                    .AsNoTracking()
                    .SingleAsync();
                Assert.NotNull(overlappingSnapshot.RefreshLeaseId);
                Assert.NotEqual(11m, overlappingSnapshot.CurrentBalanceUsd);
            }

            secondHandler.Release();
            var secondResult = await secondRefresh;
            Assert.Equal(TemplateProviderRuntimeRefreshOutcome.Refreshed, secondResult.Outcome);

            await using var finalContext = CreateContext(connectionString);
            var finalSnapshot = await finalContext.TemplateProviderRuntimeSnapshots.AsNoTracking().SingleAsync();
            Assert.Equal(TemplateProviderBalanceState.Fresh, finalSnapshot.BalanceState);
            Assert.Equal(22m, finalSnapshot.CurrentBalanceUsd);
            Assert.Null(finalSnapshot.RefreshLeaseId);
            Assert.Null(finalSnapshot.RefreshLeaseExpiresAtUtc);
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    [Fact]
    public async Task StaleRead_ShouldNotDowngradeConcurrentFreshSnapshotToUnknown()
    {
        var baseConnectionString = ResolvePostgresConnectionString();
        if (baseConnectionString is null)
        {
            return;
        }

        var schema = $"fal_snapshot_state_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            var connectionString = ScopeConnectionString(baseConnectionString, schema);
            await using (var migrationContext = CreateContext(connectionString))
            {
                await migrationContext.GetService<IMigrator>().MigrateAsync(FoundationMigration);
                var staleAtUtc = DateTime.UtcNow.AddMinutes(-6);
                await migrationContext.TemplateProviderRuntimeSnapshots.ExecuteUpdateAsync(setters => setters
                    .SetProperty(snapshot => snapshot.BalanceState, TemplateProviderBalanceState.Low)
                    .SetProperty(snapshot => snapshot.CurrentBalanceUsd, 8m)
                    .SetProperty(snapshot => snapshot.LastSuccessfulAtUtc, staleAtUtc)
                    .SetProperty(snapshot => snapshot.CheckedAtUtc, staleAtUtc)
                    .SetProperty(snapshot => snapshot.StatusChangedAtUtc, staleAtUtc)
                    .SetProperty(snapshot => snapshot.UpdatedAtUtc, staleAtUtc));
            }

            var selectBarrier = new SnapshotSelectBarrierInterceptor();
            await using var staleReaderContext = CreateContext(connectionString, selectBarrier);
            var staleReadTask = CreateService(
                    staleReaderContext,
                    new UnexpectedHttpMessageHandler())
                .GetSnapshotAsync(CancellationToken.None);
            await selectBarrier.WaitUntilSnapshotSelectedAsync();

            var freshAtUtc = DateTime.UtcNow;
            await using (var freshWriterContext = CreateContext(connectionString))
            {
                await freshWriterContext.TemplateProviderRuntimeSnapshots.ExecuteUpdateAsync(setters => setters
                    .SetProperty(snapshot => snapshot.BalanceState, TemplateProviderBalanceState.Fresh)
                    .SetProperty(snapshot => snapshot.CurrentBalanceUsd, 25m)
                    .SetProperty(snapshot => snapshot.LastSuccessfulAtUtc, freshAtUtc)
                    .SetProperty(snapshot => snapshot.CheckedAtUtc, freshAtUtc)
                    .SetProperty(snapshot => snapshot.StatusChangedAtUtc, freshAtUtc)
                    .SetProperty(snapshot => snapshot.UpdatedAtUtc, freshAtUtc));
            }

            selectBarrier.Release();
            var result = await staleReadTask;
            Assert.Equal(TemplateProviderBalanceState.Fresh, result.BalanceState);
            Assert.Equal(25m, result.CurrentBalanceUsd);

            await using var finalContext = CreateContext(connectionString);
            var finalSnapshot = await finalContext.TemplateProviderRuntimeSnapshots.AsNoTracking().SingleAsync();
            Assert.Equal(TemplateProviderBalanceState.Fresh, finalSnapshot.BalanceState);
            Assert.Equal(25m, finalSnapshot.CurrentBalanceUsd);
            Assert.InRange(
                finalSnapshot.LastSuccessfulAtUtc!.Value,
                freshAtUtc.AddMilliseconds(-1),
                freshAtUtc.AddMilliseconds(1));
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    private static FalProviderRuntimeSnapshotService CreateService(
        TemplatesDbContext dbContext,
        HttpMessageHandler handler) =>
        new(
            dbContext,
            new StubHttpClientFactory(handler),
            CreateOptions(),
            NullLogger<FalProviderRuntimeSnapshotService>.Instance);

    private static TemplatesDbContext CreateContext(
        string connectionString,
        params IInterceptor[] interceptors)
    {
        var builder = new DbContextOptionsBuilder<TemplatesDbContext>().UseNpgsql(connectionString);
        if (interceptors.Length > 0)
        {
            builder.AddInterceptors(interceptors);
        }

        return new TemplatesDbContext(builder.Options);
    }

    private static TemplatesOptions CreateOptions() => new()
    {
        AiProvider = TemplateAiProviders.Fal,
        PublicBaseUrl = "http://localhost:5000",
        LocalMediaRootPath = "wwwroot/templates-media",
        DefaultImagePrompt = "Create a themed pet portrait.",
        DefaultPreprocessingPrompt = "Keep the same pet.",
        DefaultKlingPrompt = "Funny dance.",
        AllowedImageModels = ["openai/gpt-image-2/edit"],
        AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
        AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
        SupportedLocalizationLocales = ["ru"],
        Fal = new FalAiOptions
        {
            ApiKey = "fal-runtime-postgres-test-key"
        }
    };

    private static string? ResolvePostgresConnectionString()
    {
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString) ? null : connectionString;
    }

    private static string ScopeConnectionString(string baseConnectionString, string schema) =>
        new NpgsqlConnectionStringBuilder(baseConnectionString)
        {
            SearchPath = schema
        }.ConnectionString;

    private static async Task CreateSchemaAsync(string connectionString, string schema)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"CREATE SCHEMA \"{schema}\"", connection);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task DropSchemaAsync(string connectionString, string schema)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"DROP SCHEMA IF EXISTS \"{schema}\" CASCADE", connection);
        await command.ExecuteNonQueryAsync();
    }

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(FalProviderRuntimeSnapshotService.HttpClientName, name);
            return new HttpClient(handler, disposeHandler: false);
        }
    }

    private sealed class BlockingBalanceHandler(decimal balanceUsd) : HttpMessageHandler
    {
        private readonly TaskCompletionSource _started = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource _release = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public Task WaitUntilStartedAsync() => _started.Task.WaitAsync(TimeSpan.FromSeconds(10));

        public void Release() => _release.TrySetResult();

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            _started.TrySetResult();
            await _release.Task.WaitAsync(cancellationToken);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(
                    $"{{\"credits\":{{\"current_balance\":{balanceUsd.ToString(System.Globalization.CultureInfo.InvariantCulture)}}}}}",
                    Encoding.UTF8,
                    "application/json")
            };
        }
    }

    private sealed class UnexpectedHttpMessageHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken) =>
            throw new InvalidOperationException("GetSnapshotAsync must not call fal billing.");
    }

    private sealed class SnapshotSelectBarrierInterceptor : DbCommandInterceptor
    {
        private readonly TaskCompletionSource _selected = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource _release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private int _intercepted;

        public Task WaitUntilSnapshotSelectedAsync() => _selected.Task.WaitAsync(TimeSpan.FromSeconds(10));

        public void Release() => _release.TrySetResult();

        public override async ValueTask<DbDataReader> ReaderExecutedAsync(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result,
            CancellationToken cancellationToken = default)
        {
            if (command.CommandText.Contains("templates_provider_runtime_snapshots", StringComparison.Ordinal)
                && !command.CommandText.Contains("FOR UPDATE", StringComparison.OrdinalIgnoreCase)
                && Interlocked.CompareExchange(ref _intercepted, 1, 0) == 0)
            {
                _selected.TrySetResult();
                await _release.Task.WaitAsync(cancellationToken);
            }

            return result;
        }
    }
}
