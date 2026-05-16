using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyServiceTests
{
    [Fact]
    public async Task CreditAsync_ShouldIncreaseWalletAndAppendLedgerEntry()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var result = await service.CreditAsync(
            new CreditBalanceCommand(userId, 60, "generation_refund", "template_generation:test"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(60, result.Value.NewBalance);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        var ledger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);

        Assert.Equal(60, wallet.Balance);
        Assert.Equal(60, ledger.Delta);
        Assert.Equal("generation_refund", ledger.Source);
        Assert.Equal("template_generation:test", ledger.Reason);
    }

    [Fact]
    public async Task ConfirmPackPurchase_ShouldCreditWalletOnce()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });

        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var confirmResult = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(userId, createResult.Value.OrderId),
            CancellationToken.None);

        Assert.True(confirmResult.IsSuccess);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(120, wallet.Balance);

        var secondConfirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(userId, createResult.Value.OrderId),
            CancellationToken.None);

        Assert.True(secondConfirm.IsFailure);
        Assert.Equal(EconomyErrors.PurchaseAlreadyProcessed.Code, secondConfirm.Error.Code);

        var walletAfterSecond = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(120, walletAfterSecond.Balance);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldBeIdempotent()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "creator",
            DisplayName = "Creator PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 9.99m,
            GrantedSpark = 200,
            BonusSpark = 50,
            IsActive = true,
            SortOrder = 2
        });

        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var eventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{createResult.Value.ExternalPaymentId}\",\"object\":\"checkout.session\",\"metadata\":{{\"order_id\":\"{createResult.Value.OrderId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var first = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);
        var second = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.True(first.Value.Processed);
        Assert.False(second.Value.Processed);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(250, wallet.Balance);
    }

    private static EconomyService CreateService(EconomyDbContext dbContext)
    {
        var options = Options.Create(new EconomyOptions
        {
            WeeklyFreeSpark = 100,
            WeeklyPremiumSpark = 250,
            AdRewardSpark = 15,
            AdRewardDailyLimit = 5,
            StripeSecretKey = "test_stripe_secret_key",
            StripeWebhookSecret = "test_webhook_secret",
            StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
        });

        var gateway = new FakePaymentGateway();
        return new EconomyService(dbContext, gateway, options);
    }

    private static EconomyDbContext CreateDbContext()
    {
        var dbOptions = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"economy-tests-{Guid.NewGuid():N}")
            .Options;

        return new EconomyDbContext(dbOptions);
    }

    private static string BuildStripeSignature(string payload, string secret)
    {
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var toSign = $"{timestamp}.{payload}";
        var signature = ComputeHmacSha256Hex(toSign, secret);
        return $"t={timestamp},v1={signature}";
    }

    private static string ComputeHmacSha256Hex(string payload, string secret)
    {
        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        using var hmac = new HMACSHA256(keyBytes);
        return Convert.ToHexString(hmac.ComputeHash(payloadBytes)).ToLowerInvariant();
    }

    private sealed class FakePaymentGateway : IPaymentGateway
    {
        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            var sessionId = $"cs_test_{request.OrderId:N}";
            var url = $"https://checkout.stripe.com/pay/{sessionId}";
            return Task.FromResult(Result.Success(new PaymentCreateResponse(sessionId, url)));
        }
    }
}
