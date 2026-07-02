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
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => x.UserId);
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
            entity.HasIndex(x => new { x.Status, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.NextAttemptAtUtc, x.QueuedAtUtc });
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => x.NextAttemptAtUtc);
            entity.HasIndex(x => x.UserId);
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
            entity.HasIndex(x => new { x.Purpose, x.ExpiresAtUtc });
            entity.HasIndex(x => x.ConsumedAtUtc);
        });
    }
}
