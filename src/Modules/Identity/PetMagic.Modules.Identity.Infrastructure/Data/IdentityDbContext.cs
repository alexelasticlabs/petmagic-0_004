using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure.Data;

public sealed class IdentityDbContext(DbContextOptions<IdentityDbContext> options) : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<RefreshTokenSession> RefreshTokenSessions => Set<RefreshTokenSession>();

    public DbSet<ExternalAuthProvider> ExternalAuthProviders => Set<ExternalAuthProvider>();

    public DbSet<DeletedAccountBlock> DeletedAccountBlocks => Set<DeletedAccountBlock>();

    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();

    public DbSet<UserEmailCode> UserEmailCodes => Set<UserEmailCode>();

    public DbSet<EmailDispatchJob> EmailDispatchJobs => Set<EmailDispatchJob>();

    public DbSet<AdminEmailBroadcast> AdminEmailBroadcasts => Set<AdminEmailBroadcast>();

    public DbSet<AdminNotificationEvent> AdminNotificationEvents => Set<AdminNotificationEvent>();

    public DbSet<AdminNotificationReceipt> AdminNotificationReceipts => Set<AdminNotificationReceipt>();

    public DbSet<ExternalAuthTicket> ExternalAuthTickets => Set<ExternalAuthTicket>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<AppUser>(entity =>
        {
            entity.ToTable("users");
            entity.Property(x => x.DisplayName).HasMaxLength(120);
            entity.Property(x => x.TermsOfUseAccepted).HasDefaultValue(false);
            entity.Property(x => x.TermsOfUseAcceptedVersion).HasMaxLength(32);
            entity.Property(x => x.PrivacyPolicyAccepted).HasDefaultValue(false);
            entity.Property(x => x.PrivacyPolicyAcceptedVersion).HasMaxLength(32);
            entity.Property(x => x.MarketingEmailsEnabled).HasDefaultValue(false);
            entity.Property(x => x.AvatarUrl).HasMaxLength(2048);
            entity.Property(x => x.AvatarFileName).HasMaxLength(256);
            entity.Property(x => x.AvatarContentType).HasMaxLength(128);
            entity.Property(x => x.AccountStatus)
                .HasConversion<int>()
                .HasSentinel((AccountStatus)0)
                .HasDefaultValue(AccountStatus.PendingEmailVerification);
            entity.Property(x => x.AccountStatusUpdatedAtUtc);
            entity.Property(x => x.LastLoginAtUtc);
            entity.HasIndex(x => x.AccountStatus);
            entity.HasIndex(x => x.CreatedAtUtc);
            entity.HasIndex(x => new { x.AccountStatus, x.AccountStatusUpdatedAtUtc, x.CreatedAtUtc });
            entity.HasIndex(x => x.Email).IsUnique();
        });

        builder.Entity<IdentityRole<Guid>>().ToTable("roles");
        builder.Entity<IdentityUserRole<Guid>>().ToTable("user_roles");
        builder.Entity<IdentityUserClaim<Guid>>().ToTable("user_claims");
        builder.Entity<IdentityUserLogin<Guid>>().ToTable("external_logins");
        builder.Entity<IdentityRoleClaim<Guid>>().ToTable("role_claims");
        builder.Entity<IdentityUserToken<Guid>>().ToTable("user_tokens");

        builder.Entity<RefreshTokenSession>(entity =>
        {
            entity.ToTable("refresh_token_sessions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.TokenHash).HasMaxLength(200).IsRequired();
            entity.Property(x => x.AuthenticationProvider).HasMaxLength(32);
            entity.Property(x => x.RevokedAtUtc).IsConcurrencyToken();
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => new { x.UserId, x.AuthenticationProvider, x.CreatedAtUtc });
        });

        builder.Entity<ExternalAuthProvider>(entity =>
        {
            entity.ToTable("external_auth_providers");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(32).IsRequired();
            entity.Property(x => x.ProviderUserId).HasMaxLength(256).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.Property(x => x.CreatedAt).IsRequired();
            entity.Property(x => x.LastUsedAt).IsRequired();
            entity.HasIndex(x => new { x.Provider, x.ProviderUserId }).IsUnique();
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => x.Email);
            entity.HasOne(x => x.User)
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<DeletedAccountBlock>(entity =>
        {
            entity.ToTable("deleted_account_blocks");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.Property(x => x.Provider).HasMaxLength(32);
            entity.Property(x => x.ProviderUserId).HasMaxLength(256);
            entity.Property(x => x.DeletedAtUtc).IsRequired();
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => new { x.Provider, x.ProviderUserId }).IsUnique();
        });

        builder.Entity<AuditEvent>(entity =>
        {
            entity.ToTable("audit_events");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ActorRole).HasMaxLength(80);
            entity.Property(x => x.Action).HasMaxLength(120).IsRequired();
            entity.Property(x => x.TargetType).HasMaxLength(80);
            entity.Property(x => x.TargetId).HasMaxLength(160);
            entity.Property(x => x.OldValue).HasMaxLength(2000);
            entity.Property(x => x.NewValue).HasMaxLength(2000);
            entity.Property(x => x.IpAddress).HasMaxLength(64);
            entity.Property(x => x.UserAgent).HasMaxLength(512);
            entity.Property(x => x.CorrelationId).HasMaxLength(128);
            entity.Property(x => x.Details).HasMaxLength(2000);
            entity.Property(x => x.CreatedAtUtc);
            entity.HasIndex(x => x.OccurredAtUtc);
            entity.HasIndex(x => x.CreatedAtUtc);
            entity.HasIndex(x => x.CorrelationId);
            entity.HasIndex(x => new { x.ActorUserId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.SubjectUserId, x.OccurredAtUtc });
        });

        builder.Entity<UserEmailCode>(entity =>
        {
            entity.ToTable("user_email_codes");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Email).HasMaxLength(320).IsRequired();
            entity.Property(x => x.CodeHash).HasMaxLength(128).IsRequired();
            entity.Property(x => x.Purpose).HasConversion<int>().IsRequired();
            entity.HasIndex(x => new { x.UserId, x.Purpose, x.ExpiresAtUtc });
            entity.HasIndex(x => new { x.UserId, x.Purpose, x.LockedAtUtc });
            entity.HasIndex(x => new { x.Email, x.Purpose, x.ConsumedAtUtc });
        });

        builder.Entity<EmailDispatchJob>(entity =>
        {
            entity.ToTable("email_dispatch_jobs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.RecipientEmail).HasMaxLength(320).IsRequired();
            entity.Property(x => x.Subject).HasMaxLength(200).IsRequired();
            entity.Property(x => x.HtmlBody).HasMaxLength(20000).IsRequired();
            entity.Property(x => x.TextBody).HasMaxLength(20000).IsRequired();
            entity.Property(x => x.Kind).HasConversion<int>().IsRequired();
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.Property(x => x.FailureCode).HasMaxLength(120);
            entity.Property(x => x.FailureMessage).HasMaxLength(2000);
            entity.Property(x => x.LockId).IsConcurrencyToken();
            entity.HasIndex(x => new { x.Status, x.LockExpiresAtUtc, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => x.NextAttemptAtUtc);
            entity.HasIndex(x => x.UserId);
            entity.HasIndex(x => new { x.BroadcastId, x.Status });
            entity.HasOne(x => x.Broadcast)
                .WithMany(x => x.DispatchJobs)
                .HasForeignKey(x => x.BroadcastId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<AdminEmailBroadcast>(entity =>
        {
            entity.ToTable(
                "admin_email_broadcasts",
                tableBuilder =>
                {
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_email_broadcasts_counts_nonnegative",
                        "\"RecipientCount\" >= 0 AND \"SentCount\" >= 0 AND \"FailedCount\" >= 0");
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_email_broadcasts_counts_within_total",
                        "\"SentCount\" + \"FailedCount\" <= \"RecipientCount\"");
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_email_broadcasts_status",
                        "\"Status\" >= 0 AND \"Status\" <= 5");
                });
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Audience).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Subject).HasMaxLength(200);
            entity.Property(x => x.RequestHash).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Status).HasConversion<int>().IsRequired();
            entity.HasIndex(x => new { x.CreatedAtUtc, x.Id }).IsDescending();
            entity.HasIndex(x => new { x.Status, x.CreatedAtUtc }).IsDescending(false, true);
        });

        builder.Entity<AdminNotificationEvent>(entity =>
        {
            entity.ToTable(
                "admin_notification_events",
                tableBuilder =>
                {
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_notification_events_schema_version",
                        "\"SchemaVersion\" > 0");
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_notification_events_version",
                        "\"Version\" > 0");
                    tableBuilder.HasCheckConstraint(
                        "CK_admin_notification_events_acknowledgement",
                        "(\"AcknowledgedAtUtc\" IS NULL AND \"AcknowledgedByUserId\" IS NULL AND \"AcknowledgementReason\" IS NULL) OR (\"AcknowledgedAtUtc\" IS NOT NULL AND \"AcknowledgedByUserId\" IS NOT NULL AND \"AcknowledgementReason\" IS NOT NULL)");
                });
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Type).HasMaxLength(80).IsRequired();
            entity.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();
            entity.Property(x => x.Category).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Priority).HasMaxLength(16).IsRequired();
            entity.Property(x => x.AudienceRoles).HasMaxLength(128).IsRequired();
            entity.Property(x => x.Href).HasMaxLength(512);
            entity.Property(x => x.Source).HasMaxLength(80).IsRequired();
            entity.Property(x => x.DeduplicationKey).HasMaxLength(160).IsRequired();
            entity.Property(x => x.AcknowledgementReason).HasMaxLength(500);
            entity.Property(x => x.Version).HasDefaultValue(1).IsConcurrencyToken();
            entity.HasIndex(x => new { x.CreatedAtUtc, x.Id }).IsDescending();
            entity.HasIndex(x => new { x.Priority, x.AcknowledgedAtUtc, x.CreatedAtUtc })
                .HasDatabaseName("IX_admin_notif_priority_ack_created")
                .HasFilter("\"Priority\" = 'critical' AND \"AcknowledgedAtUtc\" IS NULL");
            entity.HasIndex(x => x.ExpiresAtUtc).HasFilter("\"ExpiresAtUtc\" IS NOT NULL");
            entity.HasIndex(x => new { x.Source, x.DeduplicationKey }).IsUnique();
            entity.HasIndex(x => x.TargetUserId);
        });

        builder.Entity<AdminNotificationReceipt>(entity =>
        {
            entity.ToTable("admin_notification_receipts");
            entity.HasKey(x => new { x.EventId, x.UserId });
            entity.HasIndex(x => new { x.UserId, x.ArchivedAtUtc, x.ReadAtUtc, x.EventId })
                .HasDatabaseName("IX_admin_notif_receipt_user_state");
            entity.HasOne(x => x.Event)
                .WithMany(x => x.Receipts)
                .HasForeignKey(x => x.EventId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<ExternalAuthTicket>(entity =>
        {
            entity.ToTable("external_auth_tickets");
            entity.HasKey(x => x.Ticket);
            entity.Property(x => x.Ticket).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Purpose).HasMaxLength(40).IsRequired();
            entity.Property(x => x.PayloadJson).HasMaxLength(8000).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.ExpiresAtUtc).IsRequired();
            entity.Property(x => x.ConsumedAtUtc).IsConcurrencyToken();
            entity.HasIndex(x => new { x.Purpose, x.ExpiresAtUtc });
            entity.HasIndex(x => x.ConsumedAtUtc);
        });
    }
}
