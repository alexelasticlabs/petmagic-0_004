using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure.Data;

public sealed class SupportChatDbContext(DbContextOptions<SupportChatDbContext> options) : DbContext(options)
{
    public DbSet<SupportConversation> SupportConversations => Set<SupportConversation>();

    public DbSet<ConversationMessage> ConversationMessages => Set<ConversationMessage>();

    public DbSet<SupportMessageAttachment> SupportMessageAttachments => Set<SupportMessageAttachment>();

    public DbSet<SupportReplyTemplate> SupportReplyTemplates => Set<SupportReplyTemplate>();

    public DbSet<SupportReplyTemplateRevision> SupportReplyTemplateRevisions => Set<SupportReplyTemplateRevision>();

    public DbSet<SupportPushDeviceToken> SupportPushDeviceTokens => Set<SupportPushDeviceToken>();

    public DbSet<PushOutboxMessage> PushOutboxMessages => Set<PushOutboxMessage>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        ConfigurePushOutbox(builder, "support_push_outbox");

        builder.Entity<SupportConversation>(entity =>
        {
            entity.ToTable("support_conversations");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.Property(x => x.Version).HasDefaultValue(1L).IsConcurrencyToken();
            entity.Property(x => x.Priority).HasConversion<int>().IsRequired();
            entity.Property(x => x.Source).HasConversion<int>().IsRequired();
            entity.Property(x => x.TagsJson).HasMaxLength(1024);
            entity.Property(x => x.AssistantScenario).HasMaxLength(64);
            entity.Property(x => x.LastMessagePreview).HasMaxLength(280);
            entity.Property(x => x.LastMessageSenderType).HasConversion<int>();
            entity.Property(x => x.FeedbackComment).HasMaxLength(1000);
            entity.HasIndex(x => x.InitiatorUserId).IsUnique();
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.Priority, x.UpdatedAtUtc })
                .HasDatabaseName("IX_support_conversations_Status_Priority_UpdatedAtUtc");
            entity.HasIndex(x => new { x.Source, x.Status, x.UpdatedAtUtc })
                .HasDatabaseName("IX_support_conversations_Source_Status_UpdatedAtUtc");
            entity.HasIndex(x => new { x.AssignedAdminId, x.Status, x.UpdatedAtUtc })
                .HasDatabaseName("IX_support_conversations_AssignedAdminId_Status_UpdatedAtUtc");
            entity.HasIndex(x => x.LastMessageAtUtc);
            entity.HasIndex(x => x.WaitingSinceUtc);
            entity.HasIndex(x => x.ReopenUntilUtc);
        });

        builder.Entity<ConversationMessage>(entity =>
        {
            entity.ToTable("support_messages");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Body).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.ReplyToPreview).HasMaxLength(280);
            entity.Property(x => x.ClientIdempotencyKey).HasMaxLength(SupportMessageIdempotency.MaxKeyLength);
            entity.Property(x => x.SenderType).HasConversion<int>().IsRequired();
            entity.Property(x => x.AttachmentUrl).HasMaxLength(2048);
            entity.Property(x => x.AttachmentFileName).HasMaxLength(256);
            entity.Property(x => x.AttachmentContentType).HasMaxLength(128);
            entity.Property(x => x.AttachmentUploadStatus);
            entity.Property(x => x.AttachmentUploadErrorCode).HasMaxLength(128);
            entity.Property(x => x.IsInternalNote).HasDefaultValue(false);
            entity.HasIndex(x => new { x.ConversationId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.ConversationId, x.IsFromAdmin, x.ReadAtUtc });
            entity.HasIndex(x => new { x.ConversationId, x.ReplyToMessageId });
            entity.HasIndex(x => new { x.ConversationId, x.SenderUserId, x.ClientIdempotencyKey })
                .IsUnique()
                .HasDatabaseName("UX_support_messages_conversation_sender_idempotency");
            entity.HasOne(x => x.Conversation)
                .WithMany(x => x.Messages)
                .HasForeignKey(x => x.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.ReplyToMessage)
                .WithMany()
                .HasForeignKey(x => x.ReplyToMessageId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<SupportMessageAttachment>(entity =>
        {
            entity.ToTable("support_message_attachments");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FileUrl).HasMaxLength(2048).IsRequired();
            entity.Property(x => x.FileName).HasMaxLength(256).IsRequired();
            entity.Property(x => x.MimeType).HasMaxLength(128).IsRequired();
            entity.Property(x => x.StorageKey).HasMaxLength(1024);
            entity.Property(x => x.SortOrder).IsRequired();
            entity.Property(x => x.SizeBytes).IsRequired();
            entity.Property(x => x.ExpiresAtUtc).IsRequired();
            entity.Property(x => x.IsDeleted).HasDefaultValue(false);
            entity.HasIndex(x => new { x.MessageId, x.SortOrder });
            entity.HasIndex(x => new { x.IsDeleted, x.ExpiresAtUtc });
            entity.HasOne(x => x.Message)
                .WithMany(x => x.Attachments)
                .HasForeignKey(x => x.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<SupportReplyTemplate>(entity =>
        {
            entity.ToTable("support_reply_templates");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Body).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.Version).HasDefaultValue(1).IsConcurrencyToken();
            entity.HasIndex(x => new { x.SortOrder, x.IsEnabled });
        });

        builder.Entity<SupportReplyTemplateRevision>(entity =>
        {
            entity.ToTable("support_reply_template_revisions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Body).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.Reason).HasMaxLength(500);
            entity.HasIndex(x => new { x.TemplateId, x.Version }).IsUnique();
            entity.HasOne(x => x.Template)
                .WithMany(x => x.Revisions)
                .HasForeignKey(x => x.TemplateId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<SupportPushDeviceToken>(entity =>
        {
            entity.ToTable("support_push_device_tokens");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Token).HasMaxLength(4096).IsRequired();
            entity.Property(x => x.Platform).HasMaxLength(32).IsRequired();
            entity.Property(x => x.DeviceId).HasMaxLength(128);
            entity.Property(x => x.AppVersion).HasMaxLength(64);
            entity.Property(x => x.Locale).HasMaxLength(16);
            entity.HasIndex(x => x.Token).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.DisabledAtUtc });
        });
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        AdvanceConversationVersions();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default)
    {
        AdvanceConversationVersions();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private void AdvanceConversationVersions()
    {
        foreach (var entry in ChangeTracker.Entries<SupportConversation>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.Version = Math.Max(1, entry.Entity.Version);
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.Version = Math.Max(1, entry.Entity.Version + 1);
            }
        }

        foreach (var entry in ChangeTracker.Entries<SupportReplyTemplate>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.Version = Math.Max(1, entry.Entity.Version);
            }
        }
    }

    private static void ConfigurePushOutbox(ModelBuilder builder, string tableName)
    {
        builder.Entity<PushOutboxMessage>(entity =>
        {
            entity.ToTable(tableName);
            entity.HasKey(x => x.Id);
            entity.Property(x => x.DeduplicationKey).HasMaxLength(256).IsRequired();
            entity.Property(x => x.Kind).HasMaxLength(64).IsRequired();
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.Property(x => x.LockId).IsConcurrencyToken();
            entity.Property(x => x.LastErrorCode).HasMaxLength(128);
            entity.HasIndex(x => x.DeduplicationKey).IsUnique();
            entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.Status, x.LockExpiresAtUtc });
            entity.HasIndex(x => x.UserId);
        });
    }
}
