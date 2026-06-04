using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure.Data;

public sealed class IdentityDbContext(DbContextOptions<IdentityDbContext> options) : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<RefreshTokenSession> RefreshTokenSessions => Set<RefreshTokenSession>();

    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();

    public DbSet<UserEmailCode> UserEmailCodes => Set<UserEmailCode>();

    public DbSet<EmailDispatchJob> EmailDispatchJobs => Set<EmailDispatchJob>();

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
            entity.Property(x => x.AccountStatus).HasConversion<int>().HasDefaultValue(AccountStatus.PendingEmailVerification);
            entity.Property(x => x.AccountStatusUpdatedAtUtc);
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

        builder.Entity<AuditEvent>(entity =>
        {
            entity.ToTable("audit_events");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Action).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Details).HasMaxLength(2000);
            entity.HasIndex(x => x.OccurredAtUtc);
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
            entity.HasIndex(x => new { x.Status, x.UpdatedAtUtc });
            entity.HasIndex(x => x.NextAttemptAtUtc);
            entity.HasIndex(x => x.UserId);
        });
    }
}
