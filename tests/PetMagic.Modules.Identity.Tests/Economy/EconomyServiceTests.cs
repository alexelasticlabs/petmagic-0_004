using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
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
    private static string BuildAppStoreSignedTransactionInfo(
        string productId,
        string transactionId,
        string bundleId = "com.petmagic.app",
        DateTime? expiresAtUtc = null,
        DateTime? revokedAtUtc = null,
        string environment = "production")
    {
        var payload = new Dictionary<string, object?>
        {
            ["bundleId"] = bundleId,
            ["productId"] = productId,
            ["transactionId"] = transactionId,
            ["originalTransactionId"] = transactionId,
            ["environment"] = environment
        };

        if (expiresAtUtc.HasValue)
        {
            payload["expiresDate"] = new DateTimeOffset(expiresAtUtc.Value).ToUnixTimeMilliseconds();
        }

        if (revokedAtUtc.HasValue)
        {
            payload["revocationDate"] = new DateTimeOffset(revokedAtUtc.Value).ToUnixTimeMilliseconds();
        }

        var header = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(new Dictionary<string, object?>
        {
            ["alg"] = "ES256",
            ["typ"] = "JWT"
        }));
        var body = Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(payload));
        return $"{header}.{body}.test-signature";
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static EconomyService CreateService(
        EconomyDbContext dbContext,
        FakePaymentGateway? gateway = null,
        FakeStoreSubscriptionVerifier? storeVerifier = null,
        IIdentityService? identityService = null,
        IStoreWebhookSecurityValidator? storeWebhookSecurityValidator = null,
        IAdminAuditLog? adminAuditLog = null,
        IGenerationBillingReconciliationService? generationBillingReconciliation = null)
    {
        var options = Options.Create(new EconomyOptions
        {
            WeeklyFreeSpark = 100,
            WeeklyPremiumSpark = 40,
            AdRewardSpark = 15,
            AdRewardDailyLimit = 5,
            ReferralBonusSpark = 15,
            StripeTestSecretKey = "test_stripe_secret_key",
            StripeTestWebhookSecret = "test_webhook_secret",
            StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
        });

        return new EconomyService(
            dbContext,
            gateway ?? new FakePaymentGateway(),
            storeVerifier ?? new FakeStoreSubscriptionVerifier(),
            options,
            new MemoryCache(new MemoryCacheOptions()),
            null,
            null,
            identityService,
            null,
            adminAuditLog,
            storeWebhookSecurityValidator ?? new FakeStoreWebhookSecurityValidator(Result.Success()),
            generationBillingReconciliation);
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

    private static async Task<SqliteConnection> CreateSharedSqliteEconomyDatabaseAsync()
    {
        var connection = new SqliteConnection($"Data Source=economy-wallet-{Guid.NewGuid():N};Mode=Memory;Cache=Shared");
        await connection.OpenAsync();

        await using var dbContext = CreateSqliteDbContext(connection.ConnectionString);
        await dbContext.Database.EnsureCreatedAsync();
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
        await dbContext.SaveChangesAsync();

        return connection;
    }

    private static EconomyDbContext CreateSqliteDbContext(string connectionString)
    {
        var connection = new SqliteConnection(connectionString);
        connection.Open();

        var dbOptions = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseSqlite(connection)
            .Options;

        return new EconomyDbContext(dbOptions);
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

    private static void EnableStoreProvider(
        EconomyDbContext dbContext,
        string provider,
        string platform,
        string region = "*")
    {
        if (dbContext.PaymentProviderConfigurations.Any(x =>
                x.Provider == provider
                && x.Platform == platform
                && x.Region == region))
        {
            return;
        }

        dbContext.PaymentProviderConfigurations.Add(new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = provider,
            Platform = platform,
            Region = region,
            IsEnabled = true,
            IsRecommended = true,
            IsSelectedByDefault = true,
            RequiresExternalWarning = false,
            RequiresStoreDisclosure = false,
            AllowedFromAppVersion = "0.0.0",
            ExternalCheckoutAllowed = false,
            BonusTokensPercent = 0,
            Mode = "test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.SaveChanges();
    }

    private static string BuildStoreProductId(string provider, string packCode)
    {
        var storeSegment = provider switch
        {
            "google_play" => "google",
            "app_store" => "apple",
            _ => "store"
        };

        return $"com.petmagic.app.tokens.{storeSegment}.{packCode.ToLowerInvariant()}";
    }

    private static async Task<PurchaseOrderResponse> CreateAndVerifyStorePurchaseAsync(
        EconomyDbContext dbContext,
        EconomyService service,
        Guid userId,
        Guid packId,
        string provider = "app_store")
    {
        var platform = provider == "google_play" ? "android" : "ios";
        EnableStoreProvider(dbContext, provider, platform);

        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", provider, platform, "1.0.0", "US", "en"),
            CancellationToken.None);
        Assert.True(createResult.IsSuccess);

        var packCode = await dbContext.CurrencyPacks
            .Where(x => x.Id == packId)
            .Select(x => x.Code)
            .SingleAsync();

        var verifyResult = await service.VerifyPackStorePurchaseAsync(
            new VerifyPackStorePurchaseCommand(
                userId,
                createResult.Value.OrderId,
                provider,
                BuildStoreProductId(provider, packCode),
                $"store-token-{Guid.NewGuid():N}",
                null,
                $"purchase-{Guid.NewGuid():N}",
                DateTime.UtcNow.ToString("O")),
            CancellationToken.None);
        Assert.True(verifyResult.IsSuccess);

        return verifyResult.Value;
    }

    private static PurchaseOrder CreatePendingStripeOrder(decimal priceAmount, string currencyCode)
    {
        return new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = Guid.NewGuid(),
            PackId = Guid.NewGuid(),
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = priceAmount,
            CurrencyCode = currencyCode,
            SparkToGrant = 100,
            CreatedAtUtc = DateTime.UtcNow,
        };
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
        public PaymentCreateRequest? LastPaymentCreateRequest { get; private set; }

        public SubscriptionCheckoutCreateRequest? LastSubscriptionCheckoutRequest { get; private set; }

        public List<PaymentRefundRequest> RefundRequests { get; } = [];

        public Result<PaymentRefundResponse>? RefundResult { get; set; }

        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            LastPaymentCreateRequest = request;
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

        public Task<Result<PaymentRefundResponse>> RefundPaymentAsync(PaymentRefundRequest request, CancellationToken cancellationToken)
        {
            RefundRequests.Add(request);
            return Task.FromResult(RefundResult ?? Result.Success(new PaymentRefundResponse($"re_{request.OrderId:N}", "succeeded")));
        }
    }

    private sealed class FakeStoreSubscriptionVerifier : IStoreSubscriptionVerifier
    {
        public bool IsActive { get; init; } = true;

        public DateTime? ExpiresAtUtc { get; init; } = DateTime.UtcNow.AddDays(30);

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

    private sealed class FakeStoreWebhookSecurityValidator(Result appStoreResult) : IStoreWebhookSecurityValidator
    {
        public Result ValidateAppStoreSignedPayload(string signedPayload)
        {
            return appStoreResult;
        }

        public Task<Result> ValidateGooglePlayPushAsync(string? authorizationHeader, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }
    }

    private sealed class RecordingAdminAuditLog : IAdminAuditLog
    {
        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            Entries.Add(entry);
            return Task.CompletedTask;
        }
    }

    private sealed class FakeGenerationBillingReconciliationService : IGenerationBillingReconciliationService
    {
        public Dictionary<Guid, GenerationBillingSnapshot> Snapshots { get; } = [];

        public List<(Guid GenerationId, DateTime ChargedAtUtc, string Reason)> RestoredChargeMarkers { get; } = [];

        public List<(Guid GenerationId, DateTime RefundedAtUtc, string Reason)> RefundedMarkers { get; } = [];

        public Task<Result<IReadOnlyList<GenerationBillingSnapshot>>> ListGenerationBillingSnapshotsAsync(
            DateTime changedAfterUtc,
            int take,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success<IReadOnlyList<GenerationBillingSnapshot>>(
                Snapshots.Values
                    .Where(x => x.CreatedAtUtc >= changedAfterUtc || x.UpdatedAtUtc >= changedAfterUtc || x.ChargedAtUtc is not null)
                    .Take(Math.Max(1, take))
                    .ToList()));
        }

        public Task<Result<GenerationBillingSnapshot>> GetGenerationBillingSnapshotAsync(
            Guid generationId,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Snapshots.TryGetValue(generationId, out var snapshot)
                ? Result.Success(snapshot)
                : Result.Failure<GenerationBillingSnapshot>(EconomyErrors.GenerationBillingSnapshotNotFound));
        }

        public Task<Result<GenerationBillingRecoveryResponse>> RestoreGenerationChargeMarkerAsync(
            Guid generationId,
            DateTime chargedAtUtc,
            string reason,
            CancellationToken cancellationToken)
        {
            if (!Snapshots.TryGetValue(generationId, out var snapshot))
            {
                return Task.FromResult(Result.Failure<GenerationBillingRecoveryResponse>(EconomyErrors.GenerationBillingSnapshotNotFound));
            }

            RestoredChargeMarkers.Add((generationId, chargedAtUtc, reason));
            var updated = snapshot with
            {
                ChargedAtUtc = snapshot.ChargedAtUtc ?? chargedAtUtc,
                UpdatedAtUtc = chargedAtUtc
            };
            Snapshots[generationId] = updated;
            return Task.FromResult(Result.Success(new GenerationBillingRecoveryResponse(
                updated.GenerationId,
                updated.UserId,
                updated.Status,
                updated.ChargedAtUtc,
                updated.RefundedAtUtc,
                updated.UpdatedAtUtc)));
        }

        public Task<Result<GenerationBillingRecoveryResponse>> MarkGenerationRefundedAsync(
            Guid generationId,
            DateTime refundedAtUtc,
            string reason,
            CancellationToken cancellationToken)
        {
            if (!Snapshots.TryGetValue(generationId, out var snapshot))
            {
                return Task.FromResult(Result.Failure<GenerationBillingRecoveryResponse>(EconomyErrors.GenerationBillingSnapshotNotFound));
            }

            RefundedMarkers.Add((generationId, refundedAtUtc, reason));
            var updated = snapshot with
            {
                RefundedAtUtc = snapshot.RefundedAtUtc ?? refundedAtUtc,
                UpdatedAtUtc = refundedAtUtc
            };
            Snapshots[generationId] = updated;
            return Task.FromResult(Result.Success(new GenerationBillingRecoveryResponse(
                updated.GenerationId,
                updated.UserId,
                updated.Status,
                updated.ChargedAtUtc,
                updated.RefundedAtUtc,
                updated.UpdatedAtUtc)));
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

        public List<Guid> GetCurrentUserCalls { get; } = [];

        public bool CurrentUserIsPremium { get; set; }

        public Error? GetCurrentUserError { get; set; }

        public Error? SetPremiumStatusError { get; set; }

        public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken) => NotSupported<LegalDocumentsResponse>();
        public Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result<TokenPairResponse>> VerifyEmailCodeAsync(VerifyEmailCodeCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> ResendEmailVerificationCodeAsync(ResendEmailVerificationCodeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> VerifyPasswordResetCodeAsync(VerifyPasswordResetCodeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ResetPasswordAsync(ResetPasswordCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestCurrentPasswordChangeCodeAsync(Guid userId, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmCurrentPasswordChangeAsync(Guid userId, ConfirmCurrentPasswordChangeCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> GetLinkedAccountsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> LinkExternalLoginAsync(Guid userId, ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> UnlinkExternalLoginAsync(Guid userId, string provider, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
        {
            GetCurrentUserCalls.Add(userId);
            if (GetCurrentUserError is not null)
            {
                return Task.FromResult(Result.Failure<UserProfileResponse>(GetCurrentUserError));
            }

            return Task.FromResult(Result.Success(new UserProfileResponse(
                userId,
                "premium@petmagic.app",
                "Premium User",
                CurrentUserIsPremium,
                true,
                "Active",
                true,
                false,
                false,
                DefaultLegalAcceptance,
                ["user"],
                null)));
        }

        public Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateCurrentUserProfileAsync(Guid userId, UpdateCurrentUserProfileCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserListPageResponse>> ListUsersAsync(int skip, int take, string? search, string? role, string? status, bool? isPremium, CancellationToken cancellationToken) => NotSupported<UserListPageResponse>();
        public Task<Result<AdminUserDashboardMetricsResponse>> GetAdminUserDashboardMetricsAsync(CancellationToken cancellationToken) => NotSupported<AdminUserDashboardMetricsResponse>();
        public Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserDetailResponse>();
        public Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserAnalyticsResponse>();
        public Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken) => NotSupported<AdminUserWalletOperationResponse>();
        public Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
        {
            SetPremiumStatusCalls.Add(command);
            if (SetPremiumStatusError is not null)
            {
                return Task.FromResult(Result.Failure(SetPremiumStatusError));
            }

            CurrentUserIsPremium = command.IsPremium;
            return Task.FromResult(Result.Success());
        }

        public Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteAdminUserAsync(DeleteAdminUserCommand command, CancellationToken cancellationToken) => NotSupported();

        private static Task<Result> NotSupported() => Task.FromException<Result>(new NotSupportedException());
        private static Task<Result<T>> NotSupported<T>() => Task.FromException<Result<T>>(new NotSupportedException());
    }
}
