using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;

using IdentityModuleDbContext = PetMagic.Modules.Identity.Infrastructure.Data.IdentityDbContext;
using TemplatesContracts = PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    private const string CurrentLegalVersion = "2026-05-20";

    private static IdentityModuleDbContext CreateIdentityDbContext()
    {
        var options = new DbContextOptionsBuilder<IdentityModuleDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new IdentityModuleDbContext(options);
    }

    private static EconomyDbContext CreateEconomyDbContext()
    {
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new EconomyDbContext(options);
    }

    private static TemplatesDbContext CreateTemplatesDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new TemplatesDbContext(options);
    }

    private static async Task<IdentityService> CreateServiceAsync(
        IdentityModuleDbContext identityDbContext,
        EconomyDbContext economyDbContext,
        TemplatesDbContext templatesDbContext,
        IAvatarStorage avatarStorage,
        long maxAvatarSizeBytes = 5 * 1024 * 1024)
    {
        await identityDbContext.Database.EnsureCreatedAsync();
        await economyDbContext.Database.EnsureCreatedAsync();
        await templatesDbContext.Database.EnsureCreatedAsync();

        var identityOptions = new IdentityOptions();
        identityOptions.Password.RequiredLength = 10;
        identityOptions.Password.RequireDigit = true;
        identityOptions.Password.RequireUppercase = true;
        identityOptions.Password.RequireLowercase = true;
        identityOptions.Password.RequireNonAlphanumeric = false;
        identityOptions.User.RequireUniqueEmail = true;

        var normalizer = new UpperInvariantLookupNormalizer();
        var userStore = new UserStore<AppUser, IdentityRole<Guid>, IdentityModuleDbContext, Guid>(identityDbContext);
        var userManager = new UserManager<AppUser>(
            userStore,
            Options.Create(identityOptions),
            new PasswordHasher<AppUser>(),
            [new UserValidator<AppUser>()],
            [new PasswordValidator<AppUser>()],
            normalizer,
            new IdentityErrorDescriber(),
            new ServiceCollection().AddLogging().BuildServiceProvider(),
            NullLogger<UserManager<AppUser>>.Instance);

        var roleStore = new RoleStore<IdentityRole<Guid>, IdentityModuleDbContext, Guid>(identityDbContext);
        var roleManager = new RoleManager<IdentityRole<Guid>>(
            roleStore,
            [new RoleValidator<IdentityRole<Guid>>()],
            normalizer,
            new IdentityErrorDescriber(),
            NullLogger<RoleManager<IdentityRole<Guid>>>.Instance);

        foreach (var role in SystemRoles.All)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole<Guid>(role));
            }
        }

        var serviceProvider = new ServiceCollection()
            .AddSingleton(CreateEconomyService(economyDbContext))
            .AddSingleton<IAdminUserEconomyAnalyticsReader>(new TestAdminUserEconomyAnalyticsReader(economyDbContext))
            .AddSingleton<IAdminUserTemplateAnalyticsReader>(new TestAdminUserTemplateAnalyticsReader(templatesDbContext))
            .BuildServiceProvider();

        return new IdentityService(
            userManager,
            roleManager,
            identityDbContext,
            serviceProvider,
            new HttpContextAccessor(),
            new FakeLegalDocumentsCatalog(),
            new StubEmailTemplateRenderer(),
            avatarStorage,
            new EmailOptions
            {
                DispatchWorkerEnabled = false,
                FromAddress = "no-reply@petmagic.app",
                FromName = "PetMagic",
                VerificationCodeLength = 6,
                VerificationCodeTtlMinutes = 15,
                PasswordResetCodeTtlMinutes = 15
            },
            new AvatarStorageOptions
            {
                MaxFileSizeBytes = maxAvatarSizeBytes
            },
            Options.Create(new JwtOptions()));
    }

    private sealed class TestAdminUserEconomyAnalyticsReader(EconomyDbContext dbContext) : IAdminUserEconomyAnalyticsReader
    {
        public async Task<Result<AdminUserEconomyAnalyticsResponse>> GetAdminUserEconomyAnalyticsAsync(
            Guid userId,
            CancellationToken cancellationToken)
        {
            var wallet = await dbContext.Wallets
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

            var purchases = await dbContext.PurchaseOrders
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .ToListAsync(cancellationToken);

            var recentPurchases = purchases
                .OrderByDescending(x => x.CreatedAtUtc)
                .Take(10)
                .Select(x => new AdminUserEconomyPurchaseResponse(
                    x.Id,
                    x.Status,
                    x.PriceAmount,
                    x.CurrencyCode,
                    x.SparkToGrant,
                    x.PaymentProvider,
                    x.CreatedAtUtc,
                    x.ConfirmedAtUtc))
                .ToList();

            var ledgerEntries = await dbContext.WalletLedgerEntries
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .ToListAsync(cancellationToken);

            var recentLedgerEntries = ledgerEntries
                .OrderByDescending(x => x.CreatedAtUtc)
                .Take(12)
                .Select(x => new AdminUserEconomyWalletLedgerResponse(
                    x.Id,
                    x.Delta,
                    x.BalanceAfter,
                    x.Source,
                    x.Reason,
                    x.CreatedAtUtc))
                .ToList();

            var recentActivity = recentPurchases
                .Select(x => new AdminUserEconomyActivityResponse(
                    "purchase",
                    $"Purchase {x.Status}",
                    $"{x.SparkToGrant} spark - {x.PriceAmount} {x.CurrencyCode}",
                    x.ConfirmedAtUtc ?? x.CreatedAtUtc))
                .Concat(recentLedgerEntries.Select(x => new AdminUserEconomyActivityResponse(
                    "wallet",
                    x.Source,
                    $"{x.Delta} - {x.Reason}",
                    x.CreatedAtUtc)))
                .ToList();

            var successfulPurchases = purchases
                .Where(x => string.Equals(x.Status, "succeeded", StringComparison.OrdinalIgnoreCase))
                .ToList();

            return Result.Success(new AdminUserEconomyAnalyticsResponse(
                wallet?.Balance ?? 0,
                ledgerEntries.Where(x => x.Delta > 0).Sum(x => x.Delta),
                ledgerEntries.Where(x => x.Delta < 0).Sum(x => -x.Delta),
                ledgerEntries.Where(x => x.Delta > 0 && string.Equals(x.Source, "admin_grant", StringComparison.Ordinal)).Sum(x => x.Delta),
                ledgerEntries.Where(x => x.Delta < 0 && string.Equals(x.Source, "admin_debit", StringComparison.Ordinal)).Sum(x => -x.Delta),
                purchases.Count,
                successfulPurchases.Count,
                successfulPurchases.Sum(x => x.SparkToGrant),
                successfulPurchases.Count > 0 ? successfulPurchases.Max(x => x.ConfirmedAtUtc ?? x.CreatedAtUtc) : null,
                recentLedgerEntries.Count > 0 ? recentLedgerEntries[0].CreatedAtUtc : null,
                recentPurchases,
                recentLedgerEntries,
                recentActivity));
        }
    }

    private sealed class TestAdminUserTemplateAnalyticsReader(TemplatesDbContext dbContext) : IAdminUserTemplateAnalyticsReader
    {
        public async Task<Result<TemplatesContracts.AdminUserTemplateAnalyticsResponse>> GetAdminUserTemplateAnalyticsAsync(
            Guid userId,
            CancellationToken cancellationToken)
        {
            var templateItemsById = await dbContext.TemplateItems
                .AsNoTracking()
                .ToDictionaryAsync(x => x.Id, cancellationToken);

            var generations = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .ToListAsync(cancellationToken);

            var recentGenerations = generations
                .OrderByDescending(x => x.CreatedAtUtc)
                .Take(10)
                .Select(x =>
                {
                    templateItemsById.TryGetValue(x.TemplateId, out var template);
                    return new TemplatesContracts.AdminUserTemplateGenerationResponse(
                        x.Id,
                        x.TemplateId,
                        template?.Title ?? string.Empty,
                        template?.TemplateType.ToString() ?? string.Empty,
                        x.Status.ToString(),
                        x.TokenCost,
                        x.LastErrorCode,
                        x.LastErrorMessage,
                        x.ResultUrl,
                        x.CreatedAtUtc,
                        x.CompletedAtUtc);
                })
                .ToList();

            var failureBreakdown = generations
                .Where(x => x.Status == TemplateGenerationStatus.Failed)
                .GroupBy(x => string.IsNullOrWhiteSpace(x.LastErrorCode) ? "templates.unknown_failure" : x.LastErrorCode)
                .Select(group => new TemplatesContracts.AdminUserTemplateFailureBreakdownItemResponse(
                    group.Key,
                    group.Count(),
                    group.Max(x => x.CompletedAtUtc ?? x.UpdatedAtUtc)))
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.FailureCode)
                .ToList();

            var templateEvents = await dbContext.TemplateAnalyticsEvents
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .ToListAsync(cancellationToken);

            var recentTemplateEvents = templateEvents
                .OrderByDescending(x => x.CreatedAtUtc)
                .Take(10)
                .Select(x =>
                {
                    templateItemsById.TryGetValue(x.TemplateId, out var template);
                    return new TemplatesContracts.AdminUserTemplateEventResponse(
                        x.Id,
                        x.TemplateId,
                        template?.Title ?? string.Empty,
                        x.EventType,
                        x.Source,
                        x.DeviceClass,
                        x.CountryCode,
                        x.GenerationId,
                        x.FeedbackMessage,
                        x.CreatedAtUtc);
                })
                .ToList();

            var recentActivity = recentGenerations
                .Select(x => new TemplatesContracts.AdminUserTemplateActivityResponse(
                    "generation",
                    $"Generation {x.Status}",
                    x.TemplateTitle,
                    x.CompletedAtUtc ?? x.CreatedAtUtc))
                .Concat(recentTemplateEvents.Select(x => new TemplatesContracts.AdminUserTemplateActivityResponse(
                    "template-event",
                    x.EventType,
                    x.TemplateTitle,
                    x.CreatedAtUtc)))
                .ToList();

            return Result.Success(new TemplatesContracts.AdminUserTemplateAnalyticsResponse(
                generations.Count,
                generations.Count(x => x.Status == TemplateGenerationStatus.Completed),
                generations.Count(x => x.Status == TemplateGenerationStatus.Failed),
                generations.Count > 0 ? generations.Max(x => x.CreatedAtUtc) : null,
                templateEvents.Count(x => string.Equals(x.EventType, "view", StringComparison.OrdinalIgnoreCase)),
                templateEvents.Count(x => string.Equals(x.EventType, "video_view", StringComparison.OrdinalIgnoreCase)),
                templateEvents.Count,
                templateEvents.Count > 0 ? templateEvents.Max(x => x.CreatedAtUtc) : null,
                recentGenerations,
                recentTemplateEvents,
                failureBreakdown,
                recentActivity));
        }
    }

    private sealed class FakeLegalDocumentsCatalog : ILegalDocumentsCatalog
    {
        public string CurrentTermsOfUseVersion => CurrentLegalVersion;

        public string CurrentPrivacyPolicyVersion => CurrentLegalVersion;

        public LegalDocumentsResponse GetCurrentDocuments(string? locale)
        {
            return new LegalDocumentsResponse(
                new LegalDocumentResponse(LegalDocumentKinds.TermsOfUse, "Terms", CurrentLegalVersion, DateTime.UtcNow, "Summary", []),
                new LegalDocumentResponse(LegalDocumentKinds.PrivacyPolicy, "Privacy", CurrentLegalVersion, DateTime.UtcNow, "Summary", []));
        }

        public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
        {
            return string.Equals(termsOfUseVersion, CurrentLegalVersion, StringComparison.Ordinal)
                && string.Equals(privacyPolicyVersion, CurrentLegalVersion, StringComparison.Ordinal);
        }
    }

    private static IEconomyService CreateEconomyService(EconomyDbContext dbContext)
    {
        return new EconomyService(
            dbContext,
            new FakePaymentGateway(),
            new FakeStoreSubscriptionVerifier(),
            Options.Create(new EconomyOptions
            {
                WeeklyFreeSpark = 100,
                WeeklyPremiumSpark = 250,
                AdRewardSpark = 15,
                AdRewardDailyLimit = 5,
                StripeSecretKey = "test_stripe_secret_key",
                StripeWebhookSecret = "test_webhook_secret",
                StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
                StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
            }));
    }

    private sealed class StubEmailTemplateRenderer : IIdentityEmailTemplateRenderer
    {
        public RenderedEmailMessage RenderEmailConfirmation(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
        {
            return new RenderedEmailMessage("Confirm", $"<p>{code}</p>", code);
        }

        public RenderedEmailMessage RenderPasswordReset(string? displayName, string code, DateTime expiresAtUtc, string? locale = null)
        {
            return new RenderedEmailMessage("Reset", $"<p>{code}</p>", code);
        }
    }

    private sealed class TrackingAvatarStorage : IAvatarStorage
    {
        public List<string> DeletedUrls { get; } = [];

        public Task<Result<StoredAvatarResponse>> StoreAsync(AvatarUploadCommand avatar, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredAvatarResponse(
                $"http://localhost:5000/user-avatars/{Guid.NewGuid():N}/{avatar.FileName}",
                $"user-avatars/{avatar.FileName}",
                avatar.FileName,
                avatar.ContentType,
                avatar.Content?.LongLength ?? avatar.ContentLengthBytes ?? 0,
                null)));
        }

        public Task<Result> DeleteAsync(string? avatarUrl, CancellationToken cancellationToken)
        {
            if (!string.IsNullOrWhiteSpace(avatarUrl))
            {
                DeletedUrls.Add(avatarUrl);
            }

            return Task.FromResult(Result.Success());
        }
    }

    private sealed class FakePaymentGateway : IPaymentGateway
    {
        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCreateResponse($"cs_test_{request.OrderId:N}", $"https://checkout.stripe.com/pay/{request.OrderId:N}")));
        }

        public Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
            SubscriptionCheckoutCreateRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new SubscriptionCheckoutCreateResponse($"cs_sub_{request.UserId:N}", $"https://checkout.stripe.com/pay/{request.UserId:N}")));
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
            return Task.FromResult(Result.Success(new PaymentMethodSetupCreateResponse($"cs_setup_{request.UserId:N}", $"https://checkout.stripe.com/setup/{request.UserId:N}")));
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
        public Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
            StoreSubscriptionVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreSubscriptionVerificationResponse(true, DateTime.UtcNow.AddDays(30), "active", request.PurchaseId)));
        }

        public Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
            StoreProductVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreProductVerificationResponse(true, "purchased", request.PurchaseId)));
        }
    }
}
