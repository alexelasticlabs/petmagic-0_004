using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure.Data;

internal static class TemplateDiscoveryModel
{
    internal static void Configure(ModelBuilder builder)
    {
        builder.Entity<TemplateDiscoveryRevision>(entity =>
        {
            entity.ToTable("templates_discovery_revisions");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.Number).IsUnique();
            entity.Property(x => x.EditVersion).IsConcurrencyToken();
            entity.Property(x => x.State).HasMaxLength(16).IsRequired();
            entity.Property(x => x.DocumentJson).HasColumnType("text").IsRequired();
            entity.Property(x => x.Reason).HasMaxLength(500);
            entity.HasOne<TemplateDiscoveryRevision>().WithMany().HasForeignKey(x => x.BasedOnRevisionId).OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<TemplateDiscoveryPage>(entity =>
        {
            entity.ToTable("templates_discovery_pages");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).ValueGeneratedNever();
            entity.Property(x => x.Version).IsConcurrencyToken();
            entity.HasOne<TemplateDiscoveryRevision>().WithMany().HasForeignKey(x => x.PublishedRevisionId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<TemplateDiscoveryRevision>().WithMany().HasForeignKey(x => x.DraftRevisionId).OnDelete(DeleteBehavior.Restrict);
            entity.HasData(new TemplateDiscoveryPage());
        });
        builder.Entity<TemplateDiscoveryCommandReceipt>(entity =>
        {
            entity.ToTable("templates_discovery_command_receipts");
            entity.HasKey(x => new { x.ActorId, x.IdempotencyKey });
            entity.Property(x => x.IdempotencyKey).HasMaxLength(128);
            entity.Property(x => x.RequestHash).HasMaxLength(64).IsRequired();
            entity.HasOne<TemplateDiscoveryRevision>().WithMany().HasForeignKey(x => x.RevisionId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
