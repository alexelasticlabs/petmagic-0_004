using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

public sealed class TemplatesDbContext(DbContextOptions<TemplatesDbContext> options) : DbContext(options)
{
    public DbSet<TemplateCategory> TemplateCategories => Set<TemplateCategory>();

    public DbSet<TemplateItem> TemplateItems => Set<TemplateItem>();

    public DbSet<TemplateAsset> TemplateAssets => Set<TemplateAsset>();

    public DbSet<TemplateGenerationJob> TemplateGenerationJobs => Set<TemplateGenerationJob>();

    public DbSet<Pet> Pets => Set<Pet>();

    public DbSet<PetPhoto> PetPhotos => Set<PetPhoto>();

    public DbSet<PetAnalyticsEvent> PetAnalyticsEvents => Set<PetAnalyticsEvent>();

    public DbSet<TemplateGenerationWatermarkUnlock> TemplateGenerationWatermarkUnlocks => Set<TemplateGenerationWatermarkUnlock>();

    public DbSet<TemplateWatermarkSettings> TemplateWatermarkSettings => Set<TemplateWatermarkSettings>();

    public DbSet<TemplateAnalyticsEvent> TemplateAnalyticsEvents => Set<TemplateAnalyticsEvent>();

    public DbSet<TemplateGenerationFeedback> TemplateGenerationFeedback => Set<TemplateGenerationFeedback>();

    public DbSet<CreditRefund> CreditRefunds => Set<CreditRefund>();

    public DbSet<TemplatePushDeviceToken> TemplatePushDeviceTokens => Set<TemplatePushDeviceToken>();

    public DbSet<TemplateMediaRecord> TemplateMediaRecords => Set<TemplateMediaRecord>();

    public DbSet<TemplateCatalogChange> TemplateCatalogChanges => Set<TemplateCatalogChange>();

    public DbSet<TemplateOfTheDay> TemplateOfTheDay => Set<TemplateOfTheDay>();

    public DbSet<TemplateOfTheDaySettings> TemplateOfTheDaySettings => Set<TemplateOfTheDaySettings>();

    public DbSet<TemplateAiProviderRequestPermit> TemplateAiProviderRequestPermits => Set<TemplateAiProviderRequestPermit>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<TemplateCategory>(entity =>
        {
            entity.ToTable("templates_categories");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(64).IsRequired();
            entity.Property(x => x.NormalizedName).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => x.NormalizedName).IsUnique();
            entity.HasIndex(x => new { x.IsArchived, x.Name });
        });

        builder.Entity<TemplateItem>(entity =>
        {
            entity.ToTable("templates_items");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Version).HasDefaultValue(0L);
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.ShortDescription).HasMaxLength(240).IsRequired();
            entity.Property(x => x.LocalizedTextsJson).HasColumnType("text");
            entity.Property(x => x.PetPhotoRequirements).HasMaxLength(1000);
            entity.Property(x => x.Category).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Tags).HasMaxLength(1000).IsRequired();
            entity.Property(x => x.PromoBadgeMode).HasConversion<int>();
            entity.Property(x => x.RequiredInputMediaType).HasConversion<int>();
            entity.Property(x => x.DefaultVariationStrength).HasMaxLength(16).HasDefaultValue("medium");
            entity.Property(x => x.MusicDescription).HasMaxLength(240);
            entity.Property(x => x.ImageModel).HasMaxLength(128);
            entity.Property(x => x.ImagePrompt).HasMaxLength(1000);
            entity.Property(x => x.PreprocessingModel).HasMaxLength(128);
            entity.Property(x => x.PreprocessingPrompt).HasMaxLength(1000);
            entity.Property(x => x.KlingModel).HasMaxLength(128);
            entity.Property(x => x.KlingPrompt).HasMaxLength(1000);
            entity.HasIndex(x => x.Version);
            entity.HasIndex(x => x.DeletedAtUtc);
            entity.HasIndex(x => new { x.TemplateType, x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.Category });
            entity.HasIndex(x => new { x.SupportsGenerationResultInput, x.RequiredInputMediaType, x.Status })
                .HasDatabaseName("IX_templates_items_generation_result_input");
            entity.HasIndex(x => new { x.SupportsGenerateSimilar, x.Status })
                .HasDatabaseName("IX_templates_items_generate_similar");
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc, x.Id })
                .HasDatabaseName("IX_templates_items_Status_UpdatedAtUtc_Id")
                .HasFilter(""" "DeletedAtUtc" IS NULL """);
            entity.HasIndex(x => new { x.Status, x.TemplateType, x.IsPremium, x.UpdatedAtUtc, x.Version, x.Id })
                .HasDatabaseName("IX_templates_items_PublicFeedFilters")
                .HasFilter(""" "DeletedAtUtc" IS NULL """);
            entity.HasIndex(x => new { x.Status, x.Category, x.UpdatedAtUtc, x.Version, x.Id })
                .HasDatabaseName("IX_templates_items_PublicFeedCategoryOrder")
                .HasFilter(""" "DeletedAtUtc" IS NULL """);
        });

        builder.Entity<TemplateCatalogChange>(entity =>
        {
            entity.ToTable("templates_catalog_changes");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ChangeType).HasConversion<int>();
            entity.HasIndex(x => x.Version).IsUnique();
            entity.HasIndex(x => x.TemplateId);
            entity.HasIndex(x => new { x.TemplateId, x.Version });
        });

        builder.Entity<TemplateOfTheDay>(entity =>
        {
            entity.ToTable("templates_of_the_day");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.StartDate).HasColumnType("date");
            entity.Property(x => x.EndDate).HasColumnType("date");
            entity.Property(x => x.TitleOverride).HasMaxLength(120);
            entity.Property(x => x.SubtitleOverride).HasMaxLength(240);
            entity.Property(x => x.BadgeTextOverride).HasMaxLength(64);
            entity.HasIndex(x => new { x.IsActive, x.IsManual, x.StartDate, x.EndDate })
                .HasDatabaseName("IX_templates_otd_active_manual_dates");
            entity.HasIndex(x => new { x.TemplateId, x.StartDate })
                .HasDatabaseName("IX_templates_otd_template_start_date");
            entity.HasOne(x => x.Template)
                .WithMany()
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<TemplateOfTheDaySettings>(entity =>
        {
            entity.ToTable("templates_of_the_day_settings");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.AllowedTypes).HasMaxLength(16).IsRequired();
        });

        builder.Entity<TemplateAsset>(entity =>
        {
            entity.ToTable("templates_assets");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Url).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.FileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.ContentType).HasMaxLength(128).IsRequired();
            entity.HasIndex(x => new { x.TemplateId, x.AssetKind }).IsUnique();
            entity.HasOne(x => x.Template)
                .WithMany(x => x.Assets)
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<TemplateGenerationJob>(entity =>
        {
            entity.ToTable("templates_generation_jobs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Status).HasConversion<int>();
            entity.Property(x => x.GenerationMode).HasConversion<int>();
            entity.Property(x => x.VariationStrength).HasMaxLength(16);
            entity.Property(x => x.PromptBeforeVariation).HasMaxLength(2000);
            entity.Property(x => x.PromptAfterVariation).HasMaxLength(2000);
            entity.Property(x => x.InputSourceType).HasMaxLength(32).HasDefaultValue("user_upload");
            entity.Property(x => x.SourceImageUrl).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.SourceImageFileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.SourceImageContentType).HasMaxLength(128).IsRequired();
            entity.Property(x => x.NormalizedImageUrl).HasMaxLength(2048);
            entity.Property(x => x.ReferenceMotionUrl).HasMaxLength(2048);
            entity.Property(x => x.ResultUrl).HasMaxLength(2048);
            entity.Property(x => x.WatermarkedResultUrl).HasMaxLength(2048);
            entity.Property(x => x.WatermarkFailureCode).HasMaxLength(128);
            entity.Property(x => x.LockedBy).HasMaxLength(128).IsConcurrencyToken();
            entity.Property(x => x.IdempotencyKey).HasMaxLength(256);
            entity.Property(x => x.RequestHash).HasMaxLength(128);
            entity.Property(x => x.CorrelationId).HasMaxLength(128);
            entity.Property(x => x.UsedPreprocessingModel).HasMaxLength(256);
            entity.Property(x => x.UsedKlingModel).HasMaxLength(256);
            entity.Property(x => x.PreprocessingProviderRequestId).HasMaxLength(128);
            entity.Property(x => x.MotionProviderRequestId).HasMaxLength(128);
            entity.Property(x => x.MotionProviderCostUsd).HasPrecision(12, 4);
            entity.Property(x => x.LastErrorCode).HasMaxLength(128);
            entity.Property(x => x.LastErrorMessage).HasMaxLength(1000);
            entity.Property(x => x.RefundLastErrorCode).HasMaxLength(128);
            entity.Property(x => x.UserMediaCleanupFailureCode).HasMaxLength(128);
            entity.HasIndex(x => x.HiddenByUserAtUtc);
            entity.HasIndex(x => x.UserMediaDeletedAtUtc);
            entity.HasIndex(x => new { x.UserId, x.Status, x.ResultViewedAtUtc });
            entity.HasIndex(x => new { x.UserId, x.Status })
                .HasDatabaseName("IX_templates_generation_jobs_UserId_Status");
            entity.HasIndex(x => x.LastUserMediaCleanupAttemptAtUtc);
            entity.HasIndex(x => new { x.Status, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.LockedAtUtc })
                .HasDatabaseName("IX_templates_generation_jobs_Status_LockedAtUtc");
            entity.HasIndex(x => new { x.Status, x.CompletedAtUtc });
            entity.HasIndex(x => new { x.Status, x.RefundedAtUtc, x.RefundLastAttemptedAtUtc })
                .HasDatabaseName("IX_tgj_Status_RefundedAtUtc_RefundLastAttemptedAtUtc");
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.UserId, x.HiddenByUserAtUtc, x.CreatedAtUtc })
                .HasDatabaseName("IX_tgj_UserId_HiddenByUserAtUtc_CreatedAtUtc");
            entity.HasIndex(x => new { x.TemplateId, x.Status, x.CreatedAtUtc });
            entity.HasIndex(x => x.ParentGenerationId);
            entity.HasIndex(x => x.ParentGenerationResultId);
            entity.HasIndex(x => x.SimilarToGenerationId);
            entity.HasIndex(x => new { x.UserId, x.PetId, x.CreatedAtUtc })
                .HasDatabaseName("IX_tgj_UserId_PetId_CreatedAtUtc");
            entity.HasIndex(x => x.PetPhotoId);
            entity.HasIndex(x => x.InputMediaAssetId);
            entity.HasIndex(x => x.ResultMediaAssetId);
            entity.HasIndex(x => new { x.UserId, x.IsWatermarkRequired, x.IsWatermarkRemoved })
                .HasDatabaseName("IX_tgj_UserId_WatermarkState");
            entity.HasIndex(x => new { x.UserId, x.IdempotencyKey })
                .IsUnique()
                .HasDatabaseName("UX_templates_generation_jobs_UserId_IdempotencyKey_active")
                .HasFilter(""" "Status" IN (1, 2) AND "IdempotencyKey" IS NOT NULL """);
            entity.HasIndex(x => new { x.UserId, x.RequestHash })
                .IsUnique()
                .HasDatabaseName("UX_templates_generation_jobs_UserId_RequestHash_active")
                .HasFilter(""" "Status" IN (1, 2) AND "RequestHash" IS NOT NULL """);
            entity.HasOne(x => x.Template)
                .WithMany()
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Pet>(entity =>
        {
            entity.ToTable("templates_pets");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(40).IsRequired();
            entity.Property(x => x.Type).HasMaxLength(16).IsRequired();
            entity.Property(x => x.Breed).HasMaxLength(60);
            entity.Property(x => x.Status).HasMaxLength(32).HasDefaultValue("active");
            entity.HasIndex(x => new { x.UserId, x.IsDeleted, x.CreatedAtUtc })
                .HasDatabaseName("IX_templates_pets_UserId_IsDeleted_CreatedAtUtc");
            entity.HasIndex(x => x.AvatarMediaAssetId);
        });

        builder.Entity<PetPhoto>(entity =>
        {
            entity.ToTable("templates_pet_photos");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ThumbnailUrl).HasMaxLength(2048);
            entity.Property(x => x.ThumbnailStoragePath).HasMaxLength(2048);
            entity.Property(x => x.Status).HasMaxLength(32).HasDefaultValue("active");
            entity.HasIndex(x => new { x.PetId, x.IsDeleted, x.SortOrder })
                .HasDatabaseName("IX_templates_pet_photos_PetId_IsDeleted_SortOrder");
            entity.HasIndex(x => new { x.UserId, x.IsDeleted, x.CreatedAtUtc })
                .HasDatabaseName("IX_templates_pet_photos_UserId_IsDeleted_CreatedAtUtc");
            entity.HasIndex(x => x.MediaAssetId).IsUnique();
            entity.HasOne(x => x.Pet)
                .WithMany(x => x.Photos)
                .HasForeignKey(x => x.PetId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.MediaAsset)
                .WithMany()
                .HasForeignKey(x => x.MediaAssetId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<PetAnalyticsEvent>(entity =>
        {
            entity.ToTable("templates_pet_analytics_events");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.EventType).HasMaxLength(64).IsRequired();
            entity.Property(x => x.PetType).HasMaxLength(16).IsRequired();
            entity.Property(x => x.UserPlan).HasMaxLength(32).IsRequired();
            entity.Property(x => x.SourceScreen).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc })
                .HasDatabaseName("IX_tpae_UserId_CreatedAtUtc");
            entity.HasIndex(x => new { x.PetId, x.CreatedAtUtc })
                .HasDatabaseName("IX_tpae_PetId_CreatedAtUtc");
            entity.HasIndex(x => new { x.EventType, x.CreatedAtUtc })
                .HasDatabaseName("IX_tpae_EventType_CreatedAtUtc");
            entity.HasIndex(x => x.TemplateId);
            entity.HasIndex(x => x.GenerationId);
        });

        builder.Entity<TemplateGenerationWatermarkUnlock>(entity =>
        {
            entity.ToTable("templates_generation_watermark_unlocks");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UnlockMethod).HasConversion<int>();
            entity.HasIndex(x => new { x.UserId, x.GenerationJobId })
                .IsUnique()
                .HasDatabaseName("UX_tgwu_UserId_GenerationJobId");
            entity.HasIndex(x => new { x.GenerationJobId, x.CreatedAtUtc })
                .HasDatabaseName("IX_tgwu_GenerationJobId_CreatedAtUtc");
            entity.HasOne(x => x.GenerationJob)
                .WithMany(x => x.WatermarkUnlocks)
                .HasForeignKey(x => x.GenerationJobId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<TemplateWatermarkSettings>(entity =>
        {
            entity.ToTable("templates_watermark_settings");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Text).HasMaxLength(80).IsRequired();
            entity.Property(x => x.LogoUrl).HasMaxLength(2048);
            entity.Property(x => x.Position).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Size).HasMaxLength(32).IsRequired();
            entity.Property(x => x.PreviewImageUrl).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.PreviewVideoFrameUrl).HasMaxLength(2048).IsRequired();
            entity.HasIndex(x => x.UpdatedAtUtc);
        });

        builder.Entity<TemplateAiProviderRequestPermit>(entity =>
        {
            entity.ToTable("templates_ai_provider_request_permits");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => new { x.Provider, x.BucketUtc, x.PermitNumber })
                .IsUnique()
                .HasDatabaseName("UX_templates_ai_provider_permits_provider_bucket_slot");
            entity.HasIndex(x => x.CreatedAtUtc)
                .HasDatabaseName("IX_templates_ai_provider_permits_CreatedAtUtc");
        });

        builder.Entity<TemplateGenerationFeedback>(entity =>
        {
            entity.ToTable("templates_generation_feedback");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Type).HasMaxLength(32).HasDefaultValue("GenerationResult").IsRequired();
            entity.Property(x => x.Category).HasMaxLength(80).HasDefaultValue("").IsRequired();
            entity.Property(x => x.Message).HasMaxLength(2000);
            entity.Property(x => x.SourceScreen).HasMaxLength(80).HasDefaultValue("").IsRequired();
            entity.Property(x => x.AppVersion).HasMaxLength(64);
            entity.Property(x => x.Platform).HasMaxLength(32);
            entity.Property(x => x.DeviceModel).HasMaxLength(128);
            entity.Property(x => x.Locale).HasMaxLength(16);
            entity.Property(x => x.ErrorCode).HasMaxLength(128);
            entity.Property(x => x.ProviderName).HasMaxLength(128);
            entity.Property(x => x.Status).HasMaxLength(24).HasDefaultValue("New").IsRequired();
            entity.Property(x => x.Priority).HasMaxLength(24).HasDefaultValue("Low").IsRequired();
            entity.Property(x => x.SelectedReasons).HasMaxLength(1000).IsRequired();
            entity.Property(x => x.Comment).HasMaxLength(2000);
            entity.Property(x => x.AdminNote).HasMaxLength(2000);
            entity.Property(x => x.ModelUsed).HasMaxLength(256);
            entity.Property(x => x.ProviderRequestId).HasMaxLength(128);
            entity.HasIndex(x => new { x.TemplateId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.GenerationId, x.UserId });
            entity.HasIndex(x => new { x.TemplateId, x.Rating, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.Priority, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.Type, x.Category, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasOne(x => x.Generation)
                .WithMany()
                .HasForeignKey(x => x.GenerationId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Template)
                .WithMany()
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<CreditRefund>(entity =>
        {
            entity.ToTable("templates_credit_refunds");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Reason).HasMaxLength(500).IsRequired();
            entity.HasIndex(x => x.FeedbackId).IsUnique()
                .HasDatabaseName("UX_templates_credit_refunds_FeedbackId")
                .HasFilter(""" "FeedbackId" IS NOT NULL """);
            entity.HasIndex(x => x.GenerationId).IsUnique()
                .HasDatabaseName("UX_templates_credit_refunds_GenerationId")
                .HasFilter(""" "GenerationId" IS NOT NULL """);
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasOne(x => x.Feedback)
                .WithMany()
                .HasForeignKey(x => x.FeedbackId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Generation)
                .WithMany()
                .HasForeignKey(x => x.GenerationId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<TemplatePushDeviceToken>(entity =>
        {
            entity.ToTable("templates_push_device_tokens");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Token).HasMaxLength(4096).IsRequired();
            entity.Property(x => x.Platform).HasMaxLength(32).IsRequired();
            entity.Property(x => x.DeviceId).HasMaxLength(128);
            entity.Property(x => x.AppVersion).HasMaxLength(64);
            entity.Property(x => x.Locale).HasMaxLength(16);
            entity.HasIndex(x => x.Token).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.DisabledAtUtc, x.LastSeenAtUtc })
                .HasDatabaseName("IX_tpdt_UserId_DisabledAtUtc_LastSeenAtUtc");
        });

        builder.Entity<TemplateAnalyticsEvent>(entity =>
        {
            entity.ToTable("templates_analytics_events");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.EventType).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Source).HasMaxLength(64).IsRequired();
            entity.Property(x => x.DeviceClass).HasMaxLength(32).IsRequired();
            entity.Property(x => x.CountryCode).HasMaxLength(8).IsRequired();
            entity.Property(x => x.FeedbackMessage).HasMaxLength(2000);
            entity.Property(x => x.MetadataJson).HasMaxLength(2000);
            entity.Property(x => x.ModerationStatus).HasMaxLength(32).IsRequired();
            entity.Property(x => x.ModerationComment).HasMaxLength(500);
            entity.HasIndex(x => new { x.TemplateId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.TemplateId, x.EventType, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.ModerationStatus, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.TemplateId, x.Source });
            entity.HasIndex(x => new { x.TemplateId, x.DeviceClass });
            entity.HasIndex(x => new { x.TemplateId, x.CountryCode });
            entity.HasOne(x => x.Template)
            .WithMany()
            .HasForeignKey(x => x.TemplateId)
            .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<TemplateMediaRecord>(entity =>
        {
            entity.ToTable("templates_media_records");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.MediaType).HasMaxLength(16).HasDefaultValue("image");
            entity.Property(x => x.StoragePath).HasMaxLength(2048);
            entity.Property(x => x.WatermarkedStoragePath).HasMaxLength(2048);
            entity.Property(x => x.PreviewUrl).HasMaxLength(2048);
            entity.Property(x => x.WatermarkedPreviewUrl).HasMaxLength(2048);
            entity.Property(x => x.SourceType).HasMaxLength(32).HasDefaultValue("user_upload");
            entity.Property(x => x.Url).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.FileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.ContentType).HasMaxLength(128).IsRequired();
            entity.Property(x => x.Role).HasConversion<int>();
            entity.Property(x => x.LifecycleState).HasConversion<int>();
            entity.Property(x => x.FailureCode).HasMaxLength(128);
            entity.Property(x => x.FailureMessage).HasMaxLength(1000);
            entity.HasIndex(x => x.Url).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.MediaType, x.IsDeleted });
            entity.HasIndex(x => x.GenerationId);
            entity.HasIndex(x => new { x.LifecycleState, x.ExpiresAtUtc });
            entity.HasIndex(x => new { x.TemplateId, x.LifecycleState });
            entity.HasIndex(x => new { x.GenerationJobId, x.LifecycleState });
            entity.HasOne(x => x.Template)
                .WithMany(x => x.MediaRecords)
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.GenerationJob)
                .WithMany(x => x.MediaRecords)
                .HasForeignKey(x => x.GenerationJobId)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}
