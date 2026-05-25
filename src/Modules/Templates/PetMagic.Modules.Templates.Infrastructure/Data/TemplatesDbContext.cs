using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

public sealed class TemplatesDbContext(DbContextOptions<TemplatesDbContext> options) : DbContext(options)
{
    public DbSet<TemplateCategory> TemplateCategories => Set<TemplateCategory>();

    public DbSet<TemplateItem> TemplateItems => Set<TemplateItem>();

    public DbSet<TemplateAsset> TemplateAssets => Set<TemplateAsset>();

    public DbSet<TemplateGenerationJob> TemplateGenerationJobs => Set<TemplateGenerationJob>();

    public DbSet<TemplateAnalyticsEvent> TemplateAnalyticsEvents => Set<TemplateAnalyticsEvent>();

    public DbSet<TemplateGenerationFeedback> TemplateGenerationFeedback => Set<TemplateGenerationFeedback>();

    public DbSet<TemplatePushDeviceToken> TemplatePushDeviceTokens => Set<TemplatePushDeviceToken>();

    public DbSet<TemplateMediaRecord> TemplateMediaRecords => Set<TemplateMediaRecord>();

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
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.ShortDescription).HasMaxLength(240).IsRequired();
            entity.Property(x => x.PetPhotoRequirements).HasMaxLength(1000);
            entity.Property(x => x.Category).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Tags).HasMaxLength(1000).IsRequired();
            entity.Property(x => x.PromoBadgeMode).HasConversion<int>();
            entity.Property(x => x.MusicDescription).HasMaxLength(240);
            entity.Property(x => x.ImageModel).HasMaxLength(128);
            entity.Property(x => x.ImagePrompt).HasMaxLength(1000);
            entity.Property(x => x.PreprocessingModel).HasMaxLength(128);
            entity.Property(x => x.PreprocessingPrompt).HasMaxLength(1000);
            entity.Property(x => x.KlingModel).HasMaxLength(128);
            entity.Property(x => x.KlingPrompt).HasMaxLength(1000);
            entity.HasIndex(x => new { x.TemplateType, x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.Category });
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
            entity.Property(x => x.SourceImageUrl).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.SourceImageFileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.SourceImageContentType).HasMaxLength(128).IsRequired();
            entity.Property(x => x.NormalizedImageUrl).HasMaxLength(2048);
            entity.Property(x => x.ReferenceMotionUrl).HasMaxLength(2048);
            entity.Property(x => x.OutputUrl).HasMaxLength(2048);
            entity.Property(x => x.UsedPreprocessingModel).HasMaxLength(256);
            entity.Property(x => x.UsedKlingModel).HasMaxLength(256);
            entity.Property(x => x.PreprocessingProviderRequestId).HasMaxLength(128);
            entity.Property(x => x.MotionProviderRequestId).HasMaxLength(128);
            entity.Property(x => x.MotionProviderCostUsd).HasPrecision(12, 4);
            entity.Property(x => x.FailureCode).HasMaxLength(128);
            entity.Property(x => x.FailureMessage).HasMaxLength(1000);
            entity.Property(x => x.RefundLastErrorCode).HasMaxLength(128);
            entity.Property(x => x.UserMediaCleanupFailureCode).HasMaxLength(128);
            entity.HasIndex(x => x.UserMediaDeletedAtUtc);
            entity.HasIndex(x => new { x.UserId, x.Status, x.ResultViewedAtUtc });
            entity.HasIndex(x => x.LastUserMediaCleanupAttemptAtUtc);
            entity.HasIndex(x => new { x.Status, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.CompletedAtUtc });
            entity.HasIndex(x => new { x.Status, x.RefundedAtUtc, x.RefundLastAttemptedAtUtc });
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.TemplateId, x.Status, x.CreatedAtUtc });
            entity.HasOne(x => x.Template)
                .WithMany()
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<TemplateGenerationFeedback>(entity =>
        {
            entity.ToTable("templates_generation_feedback");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.SelectedReasons).HasMaxLength(1000).IsRequired();
            entity.Property(x => x.Comment).HasMaxLength(2000);
            entity.Property(x => x.ModelUsed).HasMaxLength(256);
            entity.Property(x => x.ProviderRequestId).HasMaxLength(128);
            entity.HasIndex(x => new { x.TemplateId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.GenerationId, x.UserId });
            entity.HasIndex(x => new { x.TemplateId, x.Rating, x.CreatedAtUtc });
            entity.HasOne(x => x.Generation)
                .WithMany()
                .HasForeignKey(x => x.GenerationId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Template)
                .WithMany()
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Cascade);
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
            entity.HasIndex(x => new { x.UserId, x.DisabledAtUtc, x.LastSeenAtUtc });
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
            entity.HasIndex(x => new { x.TemplateId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.TemplateId, x.EventType, x.CreatedAtUtc });
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
            entity.Property(x => x.Url).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.FileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.ContentType).HasMaxLength(128).IsRequired();
            entity.Property(x => x.Role).HasConversion<int>();
            entity.Property(x => x.LifecycleState).HasConversion<int>();
            entity.Property(x => x.FailureCode).HasMaxLength(128);
            entity.Property(x => x.FailureMessage).HasMaxLength(1000);
            entity.HasIndex(x => x.Url).IsUnique();
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
