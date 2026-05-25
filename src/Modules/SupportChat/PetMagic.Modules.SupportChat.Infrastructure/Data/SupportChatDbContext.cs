using Microsoft.EntityFrameworkCore;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure.Data;

public sealed class SupportChatDbContext(DbContextOptions<SupportChatDbContext> options) : DbContext(options)
{
    public DbSet<SupportConversation> SupportConversations => Set<SupportConversation>();

    public DbSet<ConversationMessage> ConversationMessages => Set<ConversationMessage>();

    public DbSet<SupportReplyTemplate> SupportReplyTemplates => Set<SupportReplyTemplate>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<SupportConversation>(entity =>
        {
            entity.ToTable("support_conversations");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.Property(x => x.Priority).HasConversion<int>().IsRequired();
            entity.HasIndex(x => x.InitiatorUserId).IsUnique();
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => new { x.AssignedAdminId, x.Status });
            entity.HasIndex(x => x.LastMessageAtUtc);
        });

        builder.Entity<ConversationMessage>(entity =>
        {
            entity.ToTable("support_messages");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Body).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.AttachmentUrl).HasMaxLength(2048);
            entity.Property(x => x.AttachmentFileName).HasMaxLength(256);
            entity.Property(x => x.AttachmentContentType).HasMaxLength(128);
            entity.Property(x => x.AttachmentUploadStatus);
            entity.Property(x => x.AttachmentUploadErrorCode).HasMaxLength(128);
            entity.HasIndex(x => new { x.ConversationId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.ConversationId, x.IsFromAdmin, x.ReadAtUtc });
            entity.HasOne(x => x.Conversation)
                .WithMany(x => x.Messages)
                .HasForeignKey(x => x.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<SupportReplyTemplate>(entity =>
        {
            entity.ToTable("support_reply_templates");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Body).HasMaxLength(4000).IsRequired();
            entity.HasIndex(x => new { x.SortOrder, x.IsEnabled });
        });
    }
}
