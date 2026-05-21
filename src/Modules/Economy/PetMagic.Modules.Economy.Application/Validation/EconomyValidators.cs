using FluentValidation;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;

namespace PetMagic.Modules.Economy.Application.Validation;

public sealed class ClaimWeeklyGrantCommandValidator : AbstractValidator<ClaimWeeklyGrantCommand>
{
    public ClaimWeeklyGrantCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class ClaimAdRewardCommandValidator : AbstractValidator<ClaimAdRewardCommand>
{
    public ClaimAdRewardCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class SpendBalanceCommandValidator : AbstractValidator<SpendBalanceCommand>
{
    public SpendBalanceCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(120);
    }
}

public sealed class CreditBalanceCommandValidator : AbstractValidator<CreditBalanceCommand>
{
    public CreditBalanceCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Source).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(120);
    }
}

public sealed class CreatePackPurchaseCommandValidator : AbstractValidator<CreatePackPurchaseCommand>
{
    public CreatePackPurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PackId).NotEmpty();
        RuleFor(x => x.CurrencyCode).NotEmpty().Length(3);
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(24);
        RuleFor(x => x.AppVersion).NotEmpty().MaximumLength(32);
        RuleFor(x => x.Country).NotEmpty().MaximumLength(16);
        RuleFor(x => x.Locale).NotEmpty().MaximumLength(16);
    }
}

public sealed class CreatePremiumCheckoutCommandValidator : AbstractValidator<CreatePremiumCheckoutCommand>
{
    public CreatePremiumCheckoutCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PlanCode).NotEmpty().MaximumLength(40);
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(24);
        RuleFor(x => x.AppVersion).NotEmpty().MaximumLength(32);
        RuleFor(x => x.Country).NotEmpty().MaximumLength(16);
        RuleFor(x => x.Locale).NotEmpty().MaximumLength(16);
    }
}

public sealed class CreatePremiumBillingPortalCommandValidator : AbstractValidator<CreatePremiumBillingPortalCommand>
{
    public CreatePremiumBillingPortalCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
    }
}

public sealed class VerifyPremiumStorePurchaseCommandValidator : AbstractValidator<VerifyPremiumStorePurchaseCommand>
{
    public VerifyPremiumStorePurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PlanCode).NotEmpty().MaximumLength(40);
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
        RuleFor(x => x.ProductId).NotEmpty().MaximumLength(160);
        RuleFor(x => x.ServerVerificationData).NotEmpty().MaximumLength(8192);
        RuleFor(x => x.LocalVerificationData).MaximumLength(32768);
        RuleFor(x => x.PurchaseId).MaximumLength(160);
        RuleFor(x => x.TransactionDate).MaximumLength(64);
    }
}

public sealed class CreatePaymentMethodSetupCommandValidator : AbstractValidator<CreatePaymentMethodSetupCommand>
{
    public CreatePaymentMethodSetupCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider).NotEmpty().MaximumLength(24);
    }
}

public sealed class RemovePaymentMethodCommandValidator : AbstractValidator<RemovePaymentMethodCommand>
{
    public RemovePaymentMethodCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentMethodId).NotEmpty();
    }
}

public sealed class ConfirmPackPurchaseCommandValidator : AbstractValidator<ConfirmPackPurchaseCommand>
{
    public ConfirmPackPurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.OrderId).NotEmpty();
    }
}

public sealed class StripeWebhookCommandValidator : AbstractValidator<StripeWebhookCommand>
{
    public StripeWebhookCommandValidator()
    {
        RuleFor(x => x.RawBody).NotEmpty();
        RuleFor(x => x.StripeSignature).NotEmpty();
    }
}

public sealed class AppStoreServerNotificationCommandValidator : AbstractValidator<AppStoreServerNotificationCommand>
{
    public AppStoreServerNotificationCommandValidator()
    {
        RuleFor(x => x.SignedPayload).NotEmpty();
    }
}

public sealed class GooglePlayDeveloperNotificationCommandValidator : AbstractValidator<GooglePlayDeveloperNotificationCommand>
{
    public GooglePlayDeveloperNotificationCommandValidator()
    {
        RuleFor(x => x.MessageData).NotEmpty();
        RuleFor(x => x.MessageId).MaximumLength(160);
    }
}

public sealed class UpdateCurrencyPackCommandValidator : AbstractValidator<UpdateCurrencyPackCommand>
{
    public UpdateCurrencyPackCommandValidator()
    {
        RuleFor(x => x.PackId).NotEmpty();
        RuleFor(x => x.DisplayName).NotEmpty().MaximumLength(120);
        RuleFor(x => x.PriceAmount).GreaterThan(0);
        RuleFor(x => x.GrantedSpark).GreaterThan(0);
        RuleFor(x => x.BonusSpark).GreaterThanOrEqualTo(0);
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
    }
}

public sealed class UpdateSubscriptionPlanCommandValidator : AbstractValidator<UpdateSubscriptionPlanCommand>
{
    public UpdateSubscriptionPlanCommandValidator()
    {
        RuleFor(x => x.PlanId).NotEmpty().MaximumLength(40);
        RuleFor(x => x.Name).NotEmpty().MaximumLength(120);
        RuleFor(x => x.PriceAmount).GreaterThan(0);
        RuleFor(x => x.CurrencyCode).NotEmpty().Length(3);
        RuleFor(x => x.MonthlyTokenLimit).GreaterThan(0);
        RuleFor(x => x.AppleProductId).MaximumLength(160);
        RuleFor(x => x.GoogleProductId).MaximumLength(160);
        RuleFor(x => x.StripePriceId).MaximumLength(160);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo(0);
    }
}

public sealed class UpdatePaymentProviderConfigurationCommandValidator : AbstractValidator<UpdatePaymentProviderConfigurationCommand>
{
    public UpdatePaymentProviderConfigurationCommandValidator()
    {
        RuleFor(x => x.ConfigurationId).NotEmpty();
        RuleFor(x => x.Region).NotEmpty().MaximumLength(16);
        RuleFor(x => x.AllowedFromAppVersion).NotEmpty().MaximumLength(32);
        RuleFor(x => x.BonusTokensPercent).InclusiveBetween(0, 100);
        RuleFor(x => x.DisplayLabel).MaximumLength(80);
        RuleFor(x => x.DisplaySubtitle).MaximumLength(160);
        RuleFor(x => x.WarningTitle).MaximumLength(120);
        RuleFor(x => x.WarningMessage).MaximumLength(800);
        RuleFor(x => x.Mode).NotEmpty().MaximumLength(24);
        RuleFor(x => x.Notes).MaximumLength(240);
    }
}

public sealed class ApplyRedeemCodeCommandValidator : AbstractValidator<ApplyRedeemCodeCommand>
{
    public ApplyRedeemCodeCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(48);
    }
}

public sealed class ApplyReferralCodeCommandValidator : AbstractValidator<ApplyReferralCodeCommand>
{
    public ApplyReferralCodeCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(32);
    }
}

public sealed class CreateRedeemCodeCommandValidator : AbstractValidator<CreateRedeemCodeCommand>
{
    public CreateRedeemCodeCommandValidator()
    {
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(48);
        RuleFor(x => x.Description).MaximumLength(160);
        RuleFor(x => x.RewardKind)
            .NotEmpty()
            .Must(raw => RedeemCodeRewardKind.All.Contains(raw.Trim().ToLowerInvariant()));
        RuleFor(x => x.RewardValue).GreaterThan(0);
        RuleFor(x => x.MaxRedemptions).GreaterThan(0);
        RuleFor(x => x.MaxRedemptionsPerUser).GreaterThan(0);
        RuleFor(x => x.CampaignName).MaximumLength(120);
        RuleFor(x => x.CampaignChannel).MaximumLength(64);
        RuleFor(x => x.MinimumSuccessfulPurchases).GreaterThanOrEqualTo(0);
        RuleFor(x => x.CreatedBy).MaximumLength(120);
        RuleFor(x => x.ExpiresAtUtc)
            .GreaterThan(x => x.StartsAtUtc)
            .When(x => x.StartsAtUtc.HasValue && x.ExpiresAtUtc.HasValue);
    }
}

public sealed class UpdateRedeemCodeCommandValidator : AbstractValidator<UpdateRedeemCodeCommand>
{
    public UpdateRedeemCodeCommandValidator()
    {
        RuleFor(x => x.RedeemCodeId).NotEmpty();
        RuleFor(x => x.Description).MaximumLength(160);
        RuleFor(x => x.RewardKind)
            .NotEmpty()
            .Must(raw => RedeemCodeRewardKind.All.Contains(raw.Trim().ToLowerInvariant()));
        RuleFor(x => x.RewardValue).GreaterThan(0);
        RuleFor(x => x.MaxRedemptions).GreaterThan(0);
        RuleFor(x => x.MaxRedemptionsPerUser).GreaterThan(0);
        RuleFor(x => x.CampaignName).MaximumLength(120);
        RuleFor(x => x.CampaignChannel).MaximumLength(64);
        RuleFor(x => x.MinimumSuccessfulPurchases).GreaterThanOrEqualTo(0);
        RuleFor(x => x.CreatedBy).MaximumLength(120);
        RuleFor(x => x.ExpiresAtUtc)
            .GreaterThan(x => x.StartsAtUtc)
            .When(x => x.StartsAtUtc.HasValue && x.ExpiresAtUtc.HasValue);
    }
}
