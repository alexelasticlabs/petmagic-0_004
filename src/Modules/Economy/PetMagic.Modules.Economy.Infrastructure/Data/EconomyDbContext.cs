using Microsoft.EntityFrameworkCore;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure.Data;

public sealed class EconomyDbContext(DbContextOptions<EconomyDbContext> options) : DbContext(options)
{
    public DbSet<Wallet> Wallets => Set<Wallet>();

    public DbSet<WalletLedgerEntry> WalletLedgerEntries => Set<WalletLedgerEntry>();

    public DbSet<CurrencyPack> CurrencyPacks => Set<CurrencyPack>();

    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();

    public DbSet<ProcessedWebhookEvent> ProcessedWebhookEvents => Set<ProcessedWebhookEvent>();

    public DbSet<RedeemCode> RedeemCodes => Set<RedeemCode>();

    public DbSet<RedeemCodeRedemption> RedeemCodeRedemptions => Set<RedeemCodeRedemption>();

    public DbSet<ReferralProfile> ReferralProfiles => Set<ReferralProfile>();

    public DbSet<ReferralAttribution> ReferralAttributions => Set<ReferralAttribution>();

    public DbSet<PaymentCustomer> PaymentCustomers => Set<PaymentCustomer>();

    public DbSet<SavedPaymentMethod> SavedPaymentMethods => Set<SavedPaymentMethod>();

    public DbSet<SubscriptionPlan> SubscriptionPlans => Set<SubscriptionPlan>();

    public DbSet<UserSubscription> UserSubscriptions => Set<UserSubscription>();

    public DbSet<PaymentProviderConfiguration> PaymentProviderConfigurations => Set<PaymentProviderConfiguration>();

    public DbSet<SubscriptionEventLog> SubscriptionEventLogs => Set<SubscriptionEventLog>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<Wallet>(entity =>
        {
            entity.ToTable("economy_wallets");
            entity.HasKey(x => x.UserId);
            entity.Property(x => x.Balance).IsRequired();
            entity.Property(x => x.AdRewardsClaimedInWindow).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => x.UpdatedAtUtc);
        });

        builder.Entity<WalletLedgerEntry>(entity =>
        {
            entity.ToTable("economy_wallet_ledger");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Source).HasMaxLength(80).IsRequired();
            entity.Property(x => x.Reason).HasMaxLength(120).IsRequired();
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
        });

        builder.Entity<CurrencyPack>(entity =>
        {
            entity.ToTable("economy_currency_packs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Code).HasMaxLength(40).IsRequired();
            entity.Property(x => x.DisplayName).HasMaxLength(120).IsRequired();
            entity.Property(x => x.CurrencyCode).HasMaxLength(3).IsRequired();
            entity.Property(x => x.PriceAmount).HasPrecision(12, 2);
            entity.HasIndex(x => new { x.CurrencyCode, x.IsActive, x.SortOrder });
            entity.HasIndex(x => new { x.Code, x.CurrencyCode }).IsUnique();
        });

        builder.Entity<PurchaseOrder>(entity =>
        {
            entity.ToTable("economy_purchase_orders");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.PaymentProvider).HasMaxLength(24).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(24).IsRequired();
            entity.Property(x => x.CurrencyCode).HasMaxLength(3).IsRequired();
            entity.Property(x => x.ExternalPaymentId).HasMaxLength(120);
            entity.Property(x => x.CheckoutUrl).HasMaxLength(500);
            entity.Property(x => x.PriceAmount).HasPrecision(12, 2);
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasIndex(x => x.SavedPaymentMethodId);
            entity.HasIndex(x => new { x.PaymentProvider, x.ExternalPaymentId });
        });

        builder.Entity<ProcessedWebhookEvent>(entity =>
        {
            entity.ToTable("economy_processed_webhook_events");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(24).IsRequired();
            entity.Property(x => x.EventId).HasMaxLength(120).IsRequired();
            entity.Property(x => x.EventType).HasMaxLength(120).IsRequired();
            entity.HasIndex(x => new { x.Provider, x.EventId }).IsUnique();
            entity.HasIndex(x => x.ProcessedAtUtc);
        });

        builder.Entity<RedeemCode>(entity =>
        {
            entity.ToTable("economy_redeem_codes");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Code).HasMaxLength(64).IsRequired();
            entity.Property(x => x.CodeHash).HasMaxLength(96).IsRequired();
            entity.Property(x => x.CodePrefix).HasMaxLength(16).IsRequired();
            entity.Property(x => x.Description).HasMaxLength(160).IsRequired();
            entity.Property(x => x.CampaignName).HasMaxLength(120);
            entity.Property(x => x.CampaignChannel).HasMaxLength(64);
            entity.Property(x => x.MinimumSuccessfulPurchases).IsRequired();
            entity.Property(x => x.CreatedBy).HasMaxLength(120);
            entity.Property(x => x.RewardKind).HasMaxLength(32).IsRequired();
            entity.Property(x => x.RewardValue).IsRequired();
            entity.Property(x => x.MaxRedemptions).IsRequired();
            entity.Property(x => x.MaxRedemptionsPerUser).IsRequired();
            entity.Property(x => x.RedeemedCount).IsRequired();
            entity.Property(x => x.IsActive).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => x.CodeHash).IsUnique();
            entity.HasIndex(x => new { x.IsActive, x.ExpiresAtUtc });
        });

        builder.Entity<RedeemCodeRedemption>(entity =>
        {
            entity.ToTable("economy_redeem_code_redemptions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.RewardKind).HasMaxLength(32).IsRequired();
            entity.Property(x => x.RewardValue).IsRequired();
            entity.Property(x => x.RedeemedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.RedeemCodeId, x.UserId });
            entity.HasIndex(x => new { x.UserId, x.RedeemedAtUtc });
        });

        builder.Entity<ReferralProfile>(entity =>
        {
            entity.ToTable("economy_referral_profiles");
            entity.HasKey(x => x.UserId);
            entity.Property(x => x.Code).HasMaxLength(32).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => x.Code).IsUnique();
        });

        builder.Entity<ReferralAttribution>(entity =>
        {
            entity.ToTable("economy_referral_attributions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ReferrerCode).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(24).IsRequired();
            entity.Property(x => x.RewardSpark).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => x.ReferrerUserId);
            entity.HasIndex(x => x.RefereeUserId).IsUnique();
            entity.HasIndex(x => new { x.ReferrerUserId, x.Status });
        });

        builder.Entity<PaymentCustomer>(entity =>
        {
            entity.ToTable("economy_payment_customers");
            entity.HasKey(x => new { x.UserId, x.Provider });
            entity.Property(x => x.Provider).HasMaxLength(24).IsRequired();
            entity.Property(x => x.ExternalCustomerId).HasMaxLength(120).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.Provider, x.ExternalCustomerId }).IsUnique();
        });

        builder.Entity<SavedPaymentMethod>(entity =>
        {
            entity.ToTable("economy_saved_payment_methods");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(24).IsRequired();
            entity.Property(x => x.ExternalPaymentMethodId).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Brand).HasMaxLength(40).IsRequired();
            entity.Property(x => x.Last4).HasMaxLength(8).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.UserId, x.IsActive, x.IsDefault });
            entity.HasIndex(x => new { x.Provider, x.ExternalPaymentMethodId }).IsUnique();
        });

        builder.Entity<SubscriptionPlan>(entity =>
        {
            entity.ToTable("economy_subscription_plans");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Name).HasMaxLength(160).IsRequired();
            entity.Property(x => x.BillingPeriod).HasMaxLength(24).IsRequired();
            entity.Property(x => x.PriceAmount).HasPrecision(12, 2);
            entity.Property(x => x.CurrencyCode).HasMaxLength(3).IsRequired();
            entity.Property(x => x.AppleProductId).HasMaxLength(160);
            entity.Property(x => x.GoogleProductId).HasMaxLength(160);
            entity.Property(x => x.StripePriceId).HasMaxLength(160);
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.IsActive, x.DisplayOrder });
        });

        builder.Entity<UserSubscription>(entity =>
        {
            entity.ToTable("economy_user_subscriptions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(32).IsRequired();
            entity.Property(x => x.PurchaseChannel).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Region).HasMaxLength(16).IsRequired();
            entity.Property(x => x.PlanId).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(32).IsRequired();
            entity.Property(x => x.ExternalCustomerId).HasMaxLength(160);
            entity.Property(x => x.ExternalSubscriptionId).HasMaxLength(160);
            entity.Property(x => x.ExternalTransactionId).HasMaxLength(160);
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.UserId, x.UpdatedAtUtc });
            entity.HasIndex(x => new { x.UserId, x.Status, x.CurrentPeriodEndUtc });
            entity.HasIndex(x => new { x.Provider, x.ExternalSubscriptionId }).IsUnique();
        });

        builder.Entity<PaymentProviderConfiguration>(entity =>
        {
            entity.ToTable("economy_payment_provider_configs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Platform).HasMaxLength(24).IsRequired();
            entity.Property(x => x.Region).HasMaxLength(16).IsRequired();
            entity.Property(x => x.AllowedFromAppVersion).HasMaxLength(32).IsRequired();
            entity.Property(x => x.DisplayLabel).HasMaxLength(80);
            entity.Property(x => x.DisplaySubtitle).HasMaxLength(160);
            entity.Property(x => x.WarningTitle).HasMaxLength(120);
            entity.Property(x => x.WarningMessage).HasMaxLength(800);
            entity.Property(x => x.Mode).HasMaxLength(16).IsRequired();
            entity.Property(x => x.Notes).HasMaxLength(400);
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.UpdatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.Provider, x.Platform, x.Region }).IsUnique();
            entity.HasIndex(x => new { x.Platform, x.IsEnabled });
        });

        builder.Entity<SubscriptionEventLog>(entity =>
        {
            entity.ToTable("economy_subscription_event_logs");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Provider).HasMaxLength(32).IsRequired();
            entity.Property(x => x.EventType).HasMaxLength(64).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(32).IsRequired();
            entity.Property(x => x.ExternalEventId).HasMaxLength(160);
            entity.Property(x => x.ExternalSubscriptionId).HasMaxLength(160);
            entity.Property(x => x.PayloadJson).HasMaxLength(32000);
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc });
            entity.HasIndex(x => new { x.Provider, x.ExternalEventId });
            entity.HasIndex(x => new { x.Provider, x.ExternalSubscriptionId });
        });
    }
}
