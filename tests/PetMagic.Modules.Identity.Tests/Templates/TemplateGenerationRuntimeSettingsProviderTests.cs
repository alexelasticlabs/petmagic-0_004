using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationRuntimeSettingsProviderTests
{
    [Fact]
    public async Task RefreshAsync_ShouldAtomicallyReplaceSnapshotFromDatabaseRevision()
    {
        await using var fixture = await RuntimeSettingsFixture.CreateAsync();

        await fixture.Provider.RefreshAsync(CancellationToken.None);

        var initial = fixture.Provider.Current;
        Assert.Equal(1, initial.Version);
        Assert.Equal(8, initial.GlobalMaxConcurrent);
        Assert.Equal(2, initial.WorkerLoopsPerInstance);

        await fixture.UpdateAsync(row =>
        {
            row.Version = 2;
            row.GlobalMaxConcurrent = 6;
            row.ImageMaxConcurrent = 5;
            row.UpdatedAtUtc = DateTime.UtcNow;
        });

        await fixture.Provider.RefreshAsync(CancellationToken.None);

        var refreshed = fixture.Provider.Current;
        Assert.Equal(2, refreshed.Version);
        Assert.Equal(6, refreshed.GlobalMaxConcurrent);
        Assert.Equal(5, refreshed.ImageMaxConcurrent);
        Assert.Equal(2, refreshed.WorkerLoopsPerInstance);
    }

    [Fact]
    public async Task DrainController_ShouldAllowOnlyOwningOperationToResumeClaims()
    {
        await using var fixture = await RuntimeSettingsFixture.CreateAsync();
        var ownerOperationId = Guid.NewGuid();
        var otherOperationId = Guid.NewGuid();

        Assert.True(await fixture.Provider.TryPauseNewClaimsAsync(
            ownerOperationId,
            CancellationToken.None));
        Assert.True(fixture.Provider.Current.NewClaimsPaused);
        Assert.Equal(ownerOperationId, fixture.Provider.Current.DrainOperationId);
        Assert.Equal(2, fixture.Provider.Current.Version);

        Assert.False(await fixture.Provider.TryPauseNewClaimsAsync(
            otherOperationId,
            CancellationToken.None));
        Assert.False(await fixture.Provider.TryResumeNewClaimsAsync(
            otherOperationId,
            CancellationToken.None));
        Assert.True(fixture.Provider.Current.NewClaimsPaused);

        Assert.True(await fixture.Provider.TryResumeNewClaimsAsync(
            ownerOperationId,
            CancellationToken.None));
        Assert.False(fixture.Provider.Current.NewClaimsPaused);
        Assert.Null(fixture.Provider.Current.DrainOperationId);
        Assert.Equal(3, fixture.Provider.Current.Version);
    }

    private sealed class RuntimeSettingsFixture : IAsyncDisposable
    {
        private RuntimeSettingsFixture(
            SqliteConnection connection,
            ServiceProvider services,
            TemplateGenerationRuntimeSettingsProvider provider)
        {
            Connection = connection;
            Services = services;
            Provider = provider;
        }

        private SqliteConnection Connection { get; }

        private ServiceProvider Services { get; }

        public TemplateGenerationRuntimeSettingsProvider Provider { get; }

        public static async Task<RuntimeSettingsFixture> CreateAsync()
        {
            var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            var services = new ServiceCollection()
                .AddDbContext<TemplatesDbContext>(options => options.UseSqlite(connection))
                .BuildServiceProvider();
            var provider = new TemplateGenerationRuntimeSettingsProvider(
                services.GetRequiredService<IServiceScopeFactory>(),
                new TemplatesOptions
                {
                    PublicBaseUrl = "http://localhost:5000",
                    LocalMediaRootPath = "wwwroot/templates-media",
                    DefaultImagePrompt = "Create a themed pet portrait.",
                    DefaultPreprocessingPrompt = "Keep the same pet.",
                    DefaultKlingPrompt = "Funny dance.",
                    AllowedImageModels = ["openai/gpt-image-2/edit"],
                    AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
                    AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
                    SupportedLocalizationLocales = ["ru"],
                    GlobalMaxConcurrentGenerations = 8,
                    ImageMaxConcurrentGenerations = 7,
                    ImageProtectedConcurrentGenerations = 3,
                    VideoReservedConcurrentGenerations = 2,
                    VideoMaxConcurrentGenerations = 4,
                    VideoBorrowMaxConcurrentGenerations = 2,
                    MaxConcurrentJobsPerWorker = 2,
                    FalProviderConcurrencyLimit = 10,
                    FalProviderReservedConcurrency = 2,
                    FalProviderBalanceLowThresholdUsd = 10,
                    FalProviderBalanceCriticalThresholdUsd = 5
                },
                NullLogger<TemplateGenerationRuntimeSettingsProvider>.Instance);

            await using var scope = services.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            await dbContext.Database.EnsureCreatedAsync();
            var now = DateTime.UtcNow;
            dbContext.TemplateGenerationRuntimeSettings.Add(new TemplateGenerationRuntimeSettings
            {
                Id = TemplateGenerationRuntimeSettingsProvider.SettingsId,
                Version = 1,
                GlobalMaxConcurrent = 8,
                ImageMaxConcurrent = 7,
                ImageProtectedConcurrent = 3,
                VideoGuaranteedConcurrent = 2,
                VideoMaxConcurrent = 4,
                VideoBorrowMaxConcurrent = 2,
                WorkerLoopsPerInstance = 2,
                FalConfiguredConcurrency = 10,
                FalReservedConcurrency = 2,
                FalBalanceLowThresholdUsd = 10,
                FalBalanceCriticalThresholdUsd = 5,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
            await dbContext.SaveChangesAsync();

            return new RuntimeSettingsFixture(connection, services, provider);
        }

        public async Task UpdateAsync(Action<TemplateGenerationRuntimeSettings> update)
        {
            await using var scope = Services.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var row = await dbContext.TemplateGenerationRuntimeSettings.SingleAsync();
            update(row);
            await dbContext.SaveChangesAsync();
        }

        public async ValueTask DisposeAsync()
        {
            Provider.Dispose();
            await Services.DisposeAsync();
            await Connection.DisposeAsync();
        }
    }
}
