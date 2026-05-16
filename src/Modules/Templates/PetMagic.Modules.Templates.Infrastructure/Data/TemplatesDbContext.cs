using Microsoft.EntityFrameworkCore;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

public sealed class TemplatesDbContext(DbContextOptions<TemplatesDbContext> options) : DbContext(options)
{
    public DbSet<TemplateItem> TemplateItems => Set<TemplateItem>();

    public DbSet<TemplateAsset> TemplateAssets => Set<TemplateAsset>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<TemplateItem>(entity =>
        {
            entity.ToTable("templates_items");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.ShortDescription).HasMaxLength(240).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Tags).HasMaxLength(1000).IsRequired();
            entity.Property(x => x.PromoBadgeMode).HasConversion<int>();
            entity.Property(x => x.MusicDescription).HasMaxLength(240);
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
    }
}
