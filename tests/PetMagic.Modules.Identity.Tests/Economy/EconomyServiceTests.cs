using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{

    private static EconomyService CreateService(
        EconomyDbContext dbContext,
        FakePaymentGateway? gateway = null,
        FakeStoreSubscriptionVerifier? storeVerifier = null,
        IIdentityService? identityService = null)
    {
        var options = Options.Create(new EconomyOptions
        {
            WeeklyFreeSpark = 100,
            WeeklyPremiumSpark = 40,
            AdRewardSpark = 15,
            AdRewardDailyLimit = 5,
            ReferralBonusSpark = 15,
            StripeSecretKey = "test_stripe_secret_key",
            StripeWebhookSecret = "test_webhook_secret",
            StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
        });

        return new EconomyService(
            dbContext,
            gateway ?? new FakePaymentGateway(),
            storeVerifier ?? new FakeStoreSubscriptionVerifier(),
            options,
            identityService);
    }

    private static EconomyDbContext CreateDbContext()
    {
        var dbOptions = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"economy-tests-{Guid.NewGuid():N}")
            .Options;

        var dbContext = new EconomyDbContext(dbOptions);
        dbContext.PaymentProviderConfigurations.Add(new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            Platform = "web",
            Region = "*",
            IsEnabled = true,
            IsRecommended = true,
            IsSelectedByDefault = true,
            RequiresExternalWarning = false,
            RequiresStoreDisclosure = false,
            AllowedFromAppVersion = "0.0.0",
            ExternalCheckoutAllowed = true,
            BonusTokensPercent = 0,
            Mode = "test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.SaveChanges();

        return dbContext;
    }

    private static Guid AddStarterPack(EconomyDbContext dbContext)
    {
        var packId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = $"starter-{Guid.NewGuid():N}",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        dbContext.SaveChanges();
        return packId;
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

    private static string CreateUnsignedJws(string json)
    {
        return $"{Base64UrlEncode("{\"alg\":\"none\",\"typ\":\"JWT\"}")}.{Base64UrlEncode(json)}.signature";
    }

    private static string Base64UrlEncode(string value)
    {
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private sealed class FakePaymentGateway : IPaymentGateway
    {
        public SubscriptionCheckoutCreateRequest? LastSubscriptionCheckoutRequest { get; private set; }

        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            var sessionId = $"cs_test_{request.OrderId:N}";
            var url = $"https://checkout.stripe.com/pay/{sessionId}";
            return Task.FromResult(Result.Success(new PaymentCreateResponse(sessionId, url)));
        }

        public Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
            SubscriptionCheckoutCreateRequest request,
            CancellationToken cancellationToken)
        {
            LastSubscriptionCheckoutRequest = request;
            var sessionId = $"cs_sub_{request.UserId:N}_{request.PlanCode}";
            var url = $"https://checkout.stripe.com/pay/{sessionId}";
            return Task.FromResult(Result.Success(new SubscriptionCheckoutCreateResponse(sessionId, url)));
        }

        public Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCustomerCreateResponse($"cus_{request.UserId:N}")));
        }

        public Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
            BillingPortalCreateRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new BillingPortalCreateResponse("https://billing.stripe.com/session/test")));
        }

        public Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(PaymentMethodSetupCreateRequest request, CancellationToken cancellationToken)
        {
            var sessionId = $"cs_setup_{request.UserId:N}";
            return Task.FromResult(Result.Success(new PaymentMethodSetupCreateResponse(sessionId, $"https://checkout.stripe.com/setup/{sessionId}")));
        }

        public Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(PaymentMethodResolveRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentMethodDetailsResponse($"pm_{request.ExternalSetupId}", "visa", "4242", 12, 2030)));
        }

        public Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(PaymentSavedMethodCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCreateResponse($"pi_{request.OrderId:N}", string.Empty)));
        }
    }

    private sealed class FakeStoreSubscriptionVerifier : IStoreSubscriptionVerifier
    {
        public bool IsActive { get; init; } = true;

        public DateTime ExpiresAtUtc { get; init; } = DateTime.UtcNow.AddDays(30);

        public string Status { get; init; } = "active";

        public Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
            StoreSubscriptionVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreSubscriptionVerificationResponse(IsActive, ExpiresAtUtc, Status, request.PurchaseId)));
        }

        public Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
            StoreProductVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreProductVerificationResponse(true, "purchased", request.PurchaseId)));
        }
    }

    private sealed class FakeIdentityService : IIdentityService
    {
        private static readonly LegalAcceptanceStatusResponse DefaultLegalAcceptance = new(
            true,
            "2026-05-20",
            DateTime.UtcNow,
            true,
            "2026-05-20",
            DateTime.UtcNow,
            "2026-05-20",
            "2026-05-20",
            false);

        public List<SetPremiumStatusCommand> SetPremiumStatusCalls { get; } = [];

        public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken) => NotSupported<LegalDocumentsResponse>();
        public Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> GetLinkedAccountsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> LinkExternalLoginAsync(Guid userId, ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> UnlinkExternalLoginAsync(Guid userId, string provider, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new UserProfileResponse(
                userId,
                "premium@petmagic.app",
                "Premium User",
                false,
                true,
                true,
                false,
                false,
                DefaultLegalAcceptance,
                ["user"],
                null)));
        }

        public Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken) => NotSupported<IReadOnlyList<UserListItemResponse>>();
        public Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserDetailResponse>();
        public Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserAnalyticsResponse>();
        public Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken) => NotSupported<AdminUserWalletOperationResponse>();
        public Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
        {
            SetPremiumStatusCalls.Add(command);
            return Task.FromResult(Result.Success());
        }

        public Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteAdminUserAsync(DeleteAdminUserCommand command, CancellationToken cancellationToken) => NotSupported();

        private static Task<Result> NotSupported() => Task.FromException<Result>(new NotSupportedException());
        private static Task<Result<T>> NotSupported<T>() => Task.FromException<Result<T>>(new NotSupportedException());
    }
}
