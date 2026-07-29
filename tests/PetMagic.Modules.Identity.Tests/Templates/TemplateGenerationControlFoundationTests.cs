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
        Assert.Contains("scheduler_v2_bootstrap_legacy_admission_open", source, StringComparison.Ordinal);
        Assert.Contains("ON CONFLICT (\"GenerationJobId\", \"Stage\", \"Ordinal\") DO NOTHING", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_categories", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_items", source, StringComparison.Ordinal);
        Assert.DoesNotContain("templates_push_outbox", source, StringComparison.Ordinal);
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
}
