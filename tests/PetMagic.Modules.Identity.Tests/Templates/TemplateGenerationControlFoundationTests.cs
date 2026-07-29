using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationControlFoundationTests
{
    [Fact]
    public void BootstrapPolicy_ShouldPreserveLegacyAdmissionUntilExplicitPause()
    {
        var policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);

        Assert.True(policy.AdmissionEnabled);
    }

    [Fact]
    public void RuntimePolicy_ShouldUseEightSlots_WhenFalLimitIsTen()
    {
        var snapshot = TemplateGenerationRuntimePolicyCalculator.Calculate(CreatePolicy(10));

        Assert.Equal(
            new TemplateGenerationConcurrencyProfile(8, 3, 3, 7, 2, 4, 2, 1),
            snapshot.EffectiveProfile);
    }

    [Fact]
    public void RuntimePolicy_ShouldScaleBalancedProfile_WhenFalLimitIsForty()
    {
        var snapshot = TemplateGenerationRuntimePolicyCalculator.Calculate(CreatePolicy(40));

        Assert.Equal(
            new TemplateGenerationConcurrencyProfile(38, 14, 14, 33, 10, 19, 10, 5),
            snapshot.EffectiveProfile);
    }

    [Fact]
    public void RuntimePolicy_ShouldApplyDecreasedLimitWithoutInvalidLaneCaps()
    {
        var snapshot = TemplateGenerationRuntimePolicyCalculator.Calculate(CreatePolicy(5));
        var profile = snapshot.EffectiveProfile;

        Assert.Equal(3, profile.GlobalMaxConcurrentGenerations);
        Assert.InRange(profile.ImageReservedConcurrentGenerations, 1, profile.ImageMaxConcurrentGenerations);
        Assert.InRange(profile.ImageProtectedConcurrentGenerations, 1, profile.ImageMaxConcurrentGenerations);
        Assert.InRange(profile.ImageMaxConcurrentGenerations, 1, profile.GlobalMaxConcurrentGenerations);
        Assert.InRange(profile.VideoReservedConcurrentGenerations, 1, profile.VideoMaxConcurrentGenerations);
        Assert.InRange(profile.VideoBorrowMaxConcurrentGenerations, 1, profile.VideoMaxConcurrentGenerations);
        Assert.InRange(profile.VideoPreprocessingMaxConcurrentGenerations, 1, profile.VideoMaxConcurrentGenerations);
    }

    [Fact]
    public void PersistenceModel_ShouldExposeDurableAttemptAndWebhookConcurrencyContracts()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseNpgsql("Host=localhost;Database=petmagic_model;Username=postgres;Password=postgres")
            .Options;
        using var dbContext = new TemplatesDbContext(options);
        var designTimeModel = dbContext.GetService<IDesignTimeModel>().Model;
        var attempt = Assert.IsAssignableFrom<IReadOnlyEntityType>(
            designTimeModel.FindEntityType(typeof(TemplateGenerationProviderAttempt)));
        var generation = Assert.IsAssignableFrom<IReadOnlyEntityType>(
            designTimeModel.FindEntityType(typeof(TemplateGenerationJob)));
        var webhook = Assert.IsAssignableFrom<IReadOnlyEntityType>(
            designTimeModel.FindEntityType(typeof(TemplateProviderWebhookInbox)));
        var workerFingerprint = Assert.IsAssignableFrom<IReadOnlyEntityType>(
            designTimeModel.FindEntityType(typeof(TemplateRuntimeConfigFingerprint)));

        Assert.Contains(
            attempt.GetIndexes(),
            index => index.GetDatabaseName() == "UX_tgpa_JobId_Stage_Ordinal" && index.IsUnique);
        Assert.Contains(
            attempt.GetIndexes(),
            index => index.GetDatabaseName() == "UX_tgpa_SubmissionTokenHash" && index.IsUnique);
        Assert.Contains(
            attempt.GetIndexes(),
            index => index.GetDatabaseName() == "UX_tgpa_Provider_RequestId" && index.IsUnique);
        Assert.Contains(
            attempt.GetIndexes(),
            index => index.GetDatabaseName() == "IX_tgpa_State_NextPollAtUtc"
                && index.GetFilter() == "\"State\" IN (1, 2, 3, 4, 5)");
        Assert.Contains(
            attempt.GetCheckConstraints(),
            constraint => constraint.Name == "CK_tgpa_Deadlines");
        Assert.Contains(
            webhook.GetIndexes(),
            index => index.GetDatabaseName() == "UX_tpwbi_Provider_Dedupe" && index.IsUnique);
        Assert.Contains(
            webhook.GetForeignKeys(),
            foreignKey => foreignKey.PrincipalEntityType.ClrType == typeof(TemplateGenerationProviderAttempt)
                && foreignKey.DeleteBehavior == DeleteBehavior.SetNull);
        Assert.True(workerFingerprint.FindProperty(nameof(TemplateRuntimeConfigFingerprint.GenerationSchedulerV2Enabled))!.IsNullable);
        Assert.True(workerFingerprint.FindProperty(nameof(TemplateRuntimeConfigFingerprint.GenerationDispatchConcurrency))!.IsNullable);
        Assert.True(workerFingerprint.FindProperty(nameof(TemplateRuntimeConfigFingerprint.ProviderReconciliationConcurrency))!.IsNullable);
        Assert.True(workerFingerprint.FindProperty(nameof(TemplateRuntimeConfigFingerprint.MediaImportConcurrency))!.IsNullable);
        Assert.True(workerFingerprint.FindProperty(nameof(TemplateRuntimeConfigFingerprint.GenerationMaintenanceConcurrency))!.IsNullable);

        AssertSchedulerHotPathIndex(
            attempt,
            "IX_tgpa_Completed_Stage_ProviderCompletedAtUtc",
            [nameof(TemplateGenerationProviderAttempt.Stage), nameof(TemplateGenerationProviderAttempt.ProviderCompletedAtUtc)],
            [false, true],
            "\"State\" = 6 AND \"SubmittedAtUtc\" IS NOT NULL AND \"ProviderCompletedAtUtc\" IS NOT NULL",
            [nameof(TemplateGenerationProviderAttempt.SubmittedAtUtc)]);
        AssertSchedulerHotPathIndex(
            generation,
            "IX_tgj_Completed_MediaType_ImportCompletedAtUtc",
            [nameof(TemplateGenerationJob.QueueMediaType), nameof(TemplateGenerationJob.MediaImportCompletedAtUtc)],
            [false, true],
            "\"Status\" = 3 AND \"ImportStartedAtUtc\" IS NOT NULL AND \"MediaImportCompletedAtUtc\" IS NOT NULL",
            [nameof(TemplateGenerationJob.ImportStartedAtUtc)]);
        AssertSchedulerHotPathIndex(
            generation,
            "IX_tgj_UserId_QueueTier_LastAttemptAtUtc",
            [nameof(TemplateGenerationJob.UserId), nameof(TemplateGenerationJob.QueueTier), nameof(TemplateGenerationJob.LastAttemptAtUtc)],
            [false, false, true],
            "\"LastAttemptAtUtc\" IS NOT NULL",
            []);
        AssertSchedulerHotPathIndex(
            webhook,
            "IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc",
            [nameof(TemplateProviderWebhookInbox.LockedAtUtc), nameof(TemplateProviderWebhookInbox.NextAttemptAtUtc)],
            null,
            "\"Status\" = 2 AND \"LockedAtUtc\" IS NOT NULL",
            []);
    }

    [Fact]
    public void Migration_ShouldRemainAdditive_AndBackfillActiveLegacyAttempts()
    {
        var repositoryRoot = FindRepositoryRoot();
        var migrationDirectory = Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations");
        var migrationPath = Assert.Single(
            Directory.GetFiles(migrationDirectory, "*_AddGenerationControlFoundation.cs"),
            path => !path.EndsWith(".Designer.cs", StringComparison.Ordinal));
        var source = File.ReadAllText(migrationPath);

        Assert.Equal(5, CountOccurrences(source, "migrationBuilder.CreateTable("));
        Assert.Equal(12, CountOccurrences(source, "migrationBuilder.AddColumn<"));
        Assert.Contains("active_legacy_jobs", source, StringComparison.Ordinal);
        Assert.Contains("legacy-provider-token", source, StringComparison.Ordinal);
        Assert.Contains(
            "Scheduler V2 provider-attempt backfill found duplicate active fal request ids.",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "reconcile duplicate active generation provider ids before rerunning the migration",
            source,
            StringComparison.Ordinal);
        Assert.Contains("scheduler_v2_bootstrap_legacy_admission_open", source, StringComparison.Ordinal);
        Assert.Contains("ON CONFLICT (\"GenerationJobId\", \"Stage\", \"Ordinal\") DO NOTHING", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_categories", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_items", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_push_outbox", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SchedulerHotPathMigration_ShouldCreateOnlyTheExpectedIndexes()
    {
        var repositoryRoot = FindRepositoryRoot();
        var migrationDirectory = Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations");
        var migrationPath = Assert.Single(
            Directory.GetFiles(migrationDirectory, "*_AddGenerationSchedulerHotPathIndexes.cs"),
            path => !path.EndsWith(".Designer.cs", StringComparison.Ordinal));
        var source = File.ReadAllText(migrationPath);

        Assert.Equal(4, CountOccurrences(source, "migrationBuilder.CreateIndex("));
        Assert.Contains("IX_tgpa_Completed_Stage_ProviderCompletedAtUtc", source, StringComparison.Ordinal);
        Assert.Contains("IX_tgj_Completed_MediaType_ImportCompletedAtUtc", source, StringComparison.Ordinal);
        Assert.Contains("IX_tgj_UserId_QueueTier_LastAttemptAtUtc", source, StringComparison.Ordinal);
        Assert.Contains("IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc", source, StringComparison.Ordinal);
        Assert.Equal(2, CountOccurrences(source, ".Annotation(\"Npgsql:IndexInclude\""));
        Assert.Equal(3, CountOccurrences(source, "descending: new[]"));
        Assert.DoesNotContain("migrationBuilder.AddColumn", source, StringComparison.Ordinal);
        Assert.DoesNotContain("migrationBuilder.DropColumn", source, StringComparison.Ordinal);
        Assert.DoesNotContain("migrationBuilder.CreateTable", source, StringComparison.Ordinal);
        Assert.DoesNotContain("migrationBuilder.DropTable", source, StringComparison.Ordinal);
    }

    private static TemplateGenerationControlPolicy CreatePolicy(int confirmedFalLimit)
    {
        var policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);
        policy.ConfirmedFalConcurrencyLimit = confirmedFalLimit;
        return policy;
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

    private static int CountOccurrences(string source, string pattern)
    {
        var count = 0;
        var offset = 0;
        while ((offset = source.IndexOf(pattern, offset, StringComparison.Ordinal)) >= 0)
        {
            count++;
            offset += pattern.Length;
        }

        return count;
    }

    private static void AssertSchedulerHotPathIndex(
        IReadOnlyEntityType entityType,
        string databaseName,
        IReadOnlyList<string> propertyNames,
        IReadOnlyList<bool>? descending,
        string filter,
        IReadOnlyList<string> includedPropertyNames)
    {
        var index = Assert.Single(
            entityType.GetIndexes(),
            candidate => candidate.GetDatabaseName() == databaseName);

        Assert.Equal(propertyNames, index.Properties.Select(property => property.Name));
        Assert.Equal(descending, index.IsDescending);
        Assert.Equal(filter, index.GetFilter());

        var includeAnnotation = index.FindAnnotation("Npgsql:IndexInclude");
        if (includedPropertyNames.Count == 0)
        {
            Assert.Null(includeAnnotation);
            return;
        }

        var actualIncludedPropertyNames = Assert.IsAssignableFrom<IReadOnlyList<string>>(includeAnnotation?.Value);
        Assert.Equal(includedPropertyNames, actualIncludedPropertyNames);
    }
}
