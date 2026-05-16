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
    }
}
